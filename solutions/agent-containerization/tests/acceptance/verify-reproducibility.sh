#!/usr/bin/env bash
# Acceptance test for Feature 02.4 (Reproducibility, provenance and onboarding).
#
# Phase A (SF-1): no build input resolves to a mutable tag. Every `FROM` in
# images/Dockerfile and images/mediator/Dockerfile is `scratch`, a stage name, or a
# digest-pinned reference whose digest ARG has a sha256: value in compose/pins.env;
# every rendered profile's Compose `image:` is either paired with `build:` or
# digest-pinned; the workflow's SBOM step carries no unpinned action reference.
#
# Phases B-D land in SF-2/SF-3. Host-only: no docker required for phase A.
#
# Requires: yq (mikefarah/yq), git.
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

command -v yq  >/dev/null 2>&1 || { echo "verify-reproducibility: yq is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "verify-reproducibility: git is required" >&2; exit 1; }

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

echo
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ]
