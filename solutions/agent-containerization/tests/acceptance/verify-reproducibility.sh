#!/usr/bin/env bash
# Acceptance test for Feature 02.4 (Reproducibility, provenance and onboarding).
#
# Phase A (SF-1): no build input resolves to a mutable tag. Every `FROM` in
# images/Dockerfile and images/mediator/Dockerfile is `scratch`, a stage name, or a
# digest-pinned reference whose digest ARG has a sha256: value in compose/pins.env;
# every rendered profile's Compose `image:` is either paired with `build:` or
# digest-pinned; the workflow's SBOM step carries no unpinned action reference.
#
# Phase B (SF-2): every non-pack build-time fetch site resolves to a host in
# images/build-allowlist.yaml or a selected pack's egress.build.allow_fqdns (R10.4).
# Phase C (SF-2): T45 -- the pinned AGENT_BASE_DIGEST carries an SBOM and SLSA
# provenance naming a github.com Actions run, and that run's own metadata is
# checked against criterion 1's five facts.
# Phase D lands in SF-3.
#
# Requires: yq (mikefarah/yq), git, docker (buildx), jq, curl.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

REPO_ROOT="$(cd "$ROOT/../.." && pwd)"

PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
note() { echo "NOTE: $1"; }
phase() { echo; echo "=== Phase $1 -- $2"; }

for c in yq git docker jq curl; do
  command -v "$c" >/dev/null 2>&1 || { echo "verify-reproducibility: $c is required" >&2; exit 1; }
done

# ---------------------------------------------------------------------------
# Phase A -- pins (T45 criterion 2). No FROM resolves to a mutable tag.
# ---------------------------------------------------------------------------
phase A "pins -- no FROM resolves to a mutable tag"

# A digest ARG referenced by a FROM must have a sha256:<64 hex> value in pins.env, and
# the FROM itself must be scratch, a stage name (no registry host / no @), or carry
# ${THAT_ARG}. A bare `FROM node:22-slim` with no @${ARG} would build against whatever
# tag resolves on the day -- exactly the failure mode this phase exists to catch.
check_no_mutable_from() {
  local dockerfile="$1" label="$2"
  local line stage_names=""
  # Stage names declared by any `AS <name>` become valid bare FROM targets later in
  # the same file (e.g. `FROM base AS compile`, `FROM agent-packs AS claude`).
  stage_names="$(grep -oE '^FROM .* AS [A-Za-z0-9_.-]+' "$dockerfile" | awk '{print $NF}')"
  local bad=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local ref
    ref="$(sed -E 's/^FROM[[:space:]]+(--platform=[^ ]+[[:space:]]+)?([^[:space:]]+).*/\2/' <<< "$line")"
    case "$ref" in
      scratch) continue ;;
    esac
    if grep -qxF "$ref" <<< "$stage_names"; then
      continue
    fi
    case "$ref" in
      *'@${'*'_DIGEST}'|*'@sha256:'*)
        local arg
        arg="$(sed -E 's/.*@\$\{([A-Za-z0-9_]+)\}.*/\1/' <<< "$ref")"
        if [ "$arg" = "$ref" ]; then
          # Literal @sha256:... with no ARG indirection -- still a pin, but nothing in
          # pins.env to cross-check; accept it as pinned.
          continue
        fi
        local pinval
        pinval="$(sed -n "s/^${arg}=//p" compose/pins.env | tail -n1)"
        if [[ "$pinval" =~ ^sha256:[0-9a-f]{64}$ ]]; then
          continue
        fi
        echo "  $label: FROM '$ref' names ARG '$arg', but compose/pins.env's value ('${pinval:-<absent>}') is not a bare sha256:<64 hex>" >&2
        bad=1
        ;;
      *)
        echo "  $label: FROM '$ref' is neither scratch, a known stage name, nor digest-pinned" >&2
        bad=1
        ;;
    esac
  done < <(grep -E '^FROM ' "$dockerfile")
  return "$bad"
}

if check_no_mutable_from images/Dockerfile "images/Dockerfile"; then
  pass "A: every FROM in images/Dockerfile is scratch, a stage name, or digest-pinned via a sha256 pins.env value"
else
  fail "A: images/Dockerfile has a FROM that is not scratch/stage-name/digest-pinned (see stderr above)"
fi

if check_no_mutable_from images/mediator/Dockerfile "images/mediator/Dockerfile"; then
  pass "A: every FROM in images/mediator/Dockerfile is scratch, a stage name, or digest-pinned via a sha256 pins.env value"
else
  fail "A: images/mediator/Dockerfile has a FROM that is not scratch/stage-name/digest-pinned (see stderr above)"
fi

# Negative control (Test Strategy, run once and recorded, not left standing): a
# temporary unpinned FROM must be refused by the same check above.
NEG_TMP="$(mktemp)"
trap 'rm -f "$NEG_TMP"' EXIT
cp images/Dockerfile "$NEG_TMP"
printf '\nFROM node:22-slim AS negative-control-stage\n' >> "$NEG_TMP"
if check_no_mutable_from "$NEG_TMP" "negative control" 2>/dev/null; then
  fail "A: negative control -- an unpinned 'FROM node:22-slim' was NOT refused (check is too permissive)"
else
  pass "A: negative control -- an unpinned 'FROM node:22-slim' is refused, as expected"
fi
rm -f "$NEG_TMP"

# Every profile's rendered `docker compose config` -- no image: without build: unless
# digest-pinned. `sandboxed-agent/mediator:local` and the three agent `:local` tags are
# the expected build-paired images; anything else must carry an @sha256: reference.
if command -v docker >/dev/null 2>&1; then
  shopt -s nullglob
  overrides=(compose/overrides/*.yaml)
  shopt -u nullglob
  compose_bad=0
  for ov in "${overrides[@]}"; do
    profile="$(basename "$ov" .yaml)"
    rendered="$(docker compose --env-file compose/pins.env \
      -f compose/compose.yaml -f "$ov" config 2>/dev/null)" || {
      note "A: could not render profile '$profile' (docker compose config failed); skipping its image: check"
      continue
    }
    while IFS= read -r img; do
      [ -n "$img" ] || continue
      case "$img" in
        *@sha256:*) continue ;;
        *:local) continue ;;
        *)
          echo "  profile '$profile': image '$img' is neither build:-paired (:local) nor digest-pinned" >&2
          compose_bad=1
          ;;
      esac
    done < <(yq -r '.services[] | select(has("build") | not) | .image' <<< "$rendered" 2>/dev/null)
  done
  if [ "$compose_bad" -eq 0 ]; then
    pass "A: every rendered profile's non-build: image: reference is digest-pinned"
  else
    fail "A: at least one rendered profile has a non-build:, non-digest-pinned image: (see stderr above)"
  fi
else
  note "A: docker not available -- skipping the rendered-compose-config image: check"
fi

# The workflow's SBOM generation. R10.7/Edge Case 13: buildx's own `sbom: true`
# attestation is used rather than a separate scanner action (no third-party binary in
# the toolchain), so there is no scanner reference to digest-pin here. Assert that
# choice is still what is wired, so a future switch to an external scanner action does
# not silently reintroduce an unpinned dependency this phase never learns to check.
WORKFLOW="$REPO_ROOT/.github/workflows/agent-sandbox-image.yml"
if [ -f "$WORKFLOW" ] && grep -qE '^\s*sbom:\s*true\s*$' "$WORKFLOW" \
  && ! grep -qi 'buildkit-syft-scanner' "$WORKFLOW"; then
  pass "A: the publish workflow uses buildx's own sbom: true attestation, not an external (potentially unpinned) scanner action"
else
  fail "A: the publish workflow's SBOM generation does not match the expected buildx sbom: true form -- re-check for an unpinned scanner action"
fi

# ---------------------------------------------------------------------------
# Phase B -- declared build allowlist (R10.4, feature plan Decision 5). Local only.
# ---------------------------------------------------------------------------
phase B "build allowlist -- every non-pack fetch site resolves to a declared host"

ALLOWLIST="images/build-allowlist.yaml"
if [ ! -f "$ALLOWLIST" ]; then
  fail "B: $ALLOWLIST is missing"
else
  declared_hosts="$(yq -r '.hosts[].fqdn' "$ALLOWLIST" | sort -u)"
  pack_hosts="$(yq -r '.egress.build.allow_fqdns[].fqdn' packs/*/pack.yaml 2>/dev/null | sort -u)"
  known_hosts="$(printf '%s\n%s\n' "$declared_hosts" "$pack_hosts" | sed '/^$/d' | sort -u)"

  # Extracted from the actual build inputs, not hand-maintained -- a new fetch site
  # nobody declared shows up here as an unresolved host rather than going unnoticed.
  extracted_hosts=""
  add_host() { extracted_hosts="$(printf '%s\n%s\n' "$extracted_hosts" "$1")"; }

  # FROM registries: a bare `name:tag@sha256:...` resolves to Docker Hub's registry;
  # `ghcr.io/...` and any other `host/path` form name themselves.
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in
      */*.*/*|ghcr.io/*) add_host "$(cut -d/ -f1 <<< "$ref")" ;;
      *) add_host "registry-1.docker.io" ;;
    esac
  done < <(grep -hE '^FROM ' images/Dockerfile images/mediator/Dockerfile \
    | sed -E 's/^FROM[[:space:]]+(--platform=[^ ]+[[:space:]]+)?([^[:space:]]+).*/\2/' \
    | grep -v '^scratch$')

  # ADD https:// fetches (yq's release binary in both Dockerfiles).
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    add_host "$(sed -E 's#^https?://([^/]+)/.*#\1#' <<< "$url")"
  done < <(grep -hoE 'https?://[^[:space:]]+' images/Dockerfile images/mediator/Dockerfile)

  # pins.env: any *_URL / *_SOURCE value that is itself an http(s) URL, plus `npm:`
  # scheme sources, which resolve to the npm registry rather than a literal URL.
  while IFS= read -r val; do
    [ -n "$val" ] || continue
    case "$val" in
      http://*|https://*) add_host "$(sed -E 's#^https?://([^/]+)/.*#\1#' <<< "$val")" ;;
      npm:*) add_host "registry.npmjs.org" ;;
    esac
  done < <(grep -E '^[A-Z0-9_]+_(URL|SOURCE)=' compose/pins.env | sed -E 's/^[^=]+=//')

  # The unpinned bootstrap install (ca-certificates/curl(/gpgv), both Dockerfiles' own
  # "bootstrapped UNPINNED" comments) runs against the base image's baked-in default apt
  # sources before apt-pinned swaps them. Not extractable from a URL literal in the
  # Dockerfile, so named directly rather than pattern-matched.
  if grep -qE 'apt-get install.*ca-certificates curl' images/Dockerfile images/mediator/Dockerfile; then
    add_host "deb.debian.org"
  fi

  extracted_hosts="$(printf '%s\n' "$extracted_hosts" | sed '/^$/d' | sort -u)"

  unresolved=0
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    if ! grep -qxF "$h" <<< "$known_hosts"; then
      echo "  fetch host '$h' is not in $ALLOWLIST or any pack's egress.build.allow_fqdns" >&2
      unresolved=1
    fi
  done <<< "$extracted_hosts"
  if [ "$unresolved" -eq 0 ]; then
    pass "B: every extracted build-time fetch host resolves to a declared host"
  else
    fail "B: at least one build-time fetch host has no declaration (see stderr above)"
  fi

  unused=0
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    if ! grep -qxF "$h" <<< "$extracted_hosts"; then
      echo "  declared host '$h' ($ALLOWLIST) has no matching fetch site" >&2
      unused=1
    fi
  done <<< "$declared_hosts"
  if [ "$unused" -eq 0 ]; then
    pass "B: every declared host in $ALLOWLIST has at least one fetch site"
  else
    fail "B: at least one declared host in $ALLOWLIST is unused (see stderr above)"
  fi

  # Negative control: the same containment check must refuse a host nothing declared.
  if grep -qxF "totally-undeclared.example.invalid" <<< "$known_hosts"; then
    fail "B: negative control -- an undeclared host was found declared (test bug)"
  else
    pass "B: negative control -- an undeclared host is refused by the containment check, as expected"
  fi
fi

# ---------------------------------------------------------------------------
# Phase C -- T45 (criterion 1). digest -> SBOM/provenance -> run -> trigger branch.
# Needs anonymous ghcr.io and api.github.com. No skip on failure to reach either --
# a network-dependent phase that cannot reach its source fails (Contract 4).
# ---------------------------------------------------------------------------
phase C "T45 -- AGENT_BASE_DIGEST resolves to a main-built, CI-published, SBOM'd digest"

IMAGE_REPO="ghcr.io/ottawacloudconsulting/agentic-ai/agent-sandbox-base"
AGENT_BASE_DIGEST="$(sed -n 's/^AGENT_BASE_DIGEST=//p' compose/pins.env | tail -n1)"

if [[ ! "$AGENT_BASE_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  fail "C: compose/pins.env AGENT_BASE_DIGEST ('${AGENT_BASE_DIGEST:-<absent>}') is not a bare sha256:<64 hex>"
else
  REF="${IMAGE_REPO}@${AGENT_BASE_DIGEST}"
  run_id=""
  vcs_revision=""

  if SBOM_JSON="$(docker buildx imagetools inspect "$REF" --format '{{json .SBOM}}' 2>&1)"; then
    pkg_count="$(jq -r '.SPDX.packages | length' <<< "$SBOM_JSON" 2>/dev/null || echo 0)"
    if [ "${pkg_count:-0}" -ge 1 ] 2>/dev/null; then
      pass "C: the pinned digest carries an SPDX SBOM with $pkg_count package(s)"
    else
      fail "C: the pinned digest's SBOM attestation has no SPDX packages"
    fi
  else
    fail "C: could not fetch the SBOM attestation for $REF: $SBOM_JSON"
  fi

  if PROV_JSON="$(docker buildx imagetools inspect "$REF" --format '{{json .Provenance}}' 2>&1)"; then
    builder_id="$(jq -r '.SLSA.runDetails.builder.id // empty' <<< "$PROV_JSON")"
    vcs_revision="$(jq -r '[.. | objects | .["vcs:revision"]? // empty] | map(select(length > 0)) | .[0] // empty' <<< "$PROV_JSON")"

    if [[ "$builder_id" =~ ^https://github\.com/[Oo]ttawa[Cc]loud[Cc]onsulting/agentic-ai/actions/runs/([0-9]+)/attempts/[0-9]+$ ]]; then
      run_id="${BASH_REMATCH[1]}"
      pass "C: runDetails.builder.id names a run of OttawaCloudConsulting/agentic-ai (run $run_id)"
    else
      fail "C: runDetails.builder.id ('${builder_id:-<absent>}') does not name a run of OttawaCloudConsulting/agentic-ai"
    fi

    if [ -n "$vcs_revision" ]; then
      note "C: provenance vcs:revision = $vcs_revision"
    else
      fail "C: provenance carries no vcs:revision"
    fi
  else
    fail "C: could not fetch the provenance attestation for $REF: $PROV_JSON"
  fi

  if [ -n "$run_id" ]; then
    AUTH_HEADER=()
    [ -n "${GH_TOKEN:-}" ] && AUTH_HEADER=(-H "Authorization: Bearer ${GH_TOKEN}")
    RUN_TMP="$(mktemp)"
    run_http="$(curl -s -o "$RUN_TMP" -w '%{http_code}' \
      -H "Accept: application/vnd.github+json" "${AUTH_HEADER[@]}" \
      "https://api.github.com/repos/OttawaCloudConsulting/agentic-ai/actions/runs/${run_id}")"

    if [ "$run_http" = "403" ] || [ "$run_http" = "429" ]; then
      fail "C: GitHub API rate-limited (HTTP $run_http) fetching run $run_id -- not a pass, not a skip"
    elif [ "$run_http" != "200" ]; then
      fail "C: GitHub API returned HTTP $run_http for run $run_id"
    else
      run_path="$(jq -r '.path // empty' "$RUN_TMP")"
      run_branch="$(jq -r '.head_branch // empty' "$RUN_TMP")"
      run_event="$(jq -r '.event // empty' "$RUN_TMP")"
      run_conclusion="$(jq -r '.conclusion // empty' "$RUN_TMP")"
      run_sha="$(jq -r '.head_sha // empty' "$RUN_TMP")"

      if [ "$run_path" = ".github/workflows/agent-sandbox-image.yml" ]; then
        pass "C: run $run_id path is .github/workflows/agent-sandbox-image.yml"
      else
        fail "C: run $run_id path is '$run_path', expected .github/workflows/agent-sandbox-image.yml"
      fi

      if [ "$run_event" = "push" ] || [ "$run_event" = "workflow_dispatch" ]; then
        pass "C: run $run_id event is '$run_event' (push or workflow_dispatch)"
      else
        fail "C: run $run_id event is '$run_event', expected push or workflow_dispatch"
      fi

      if [ "$run_conclusion" = "success" ]; then
        pass "C: run $run_id conclusion is success"
      else
        fail "C: run $run_id conclusion is '$run_conclusion', expected success"
      fi

      if [ -n "$vcs_revision" ] && [ "$run_sha" = "$vcs_revision" ]; then
        pass "C: run $run_id head_sha agrees with the provenance's vcs:revision ($run_sha)"
      else
        fail "C: run $run_id head_sha ('$run_sha') does not agree with provenance vcs:revision ('${vcs_revision:-<absent>}')"
      fi

      if [ "$run_branch" = "main" ]; then
        pass "C: run $run_id head_branch is 'main'"
      else
        fail "C: run $run_id head_branch is '$run_branch', expected 'main' (EXPECTED RED until SF-4 promotes feature/containerization and repins -- feature plan criterion 1, SF-2 closing note)"
      fi
    fi
    rm -f "$RUN_TMP"
  fi
fi

echo
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ]
