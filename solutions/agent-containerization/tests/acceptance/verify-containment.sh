#!/usr/bin/env bash
# Acceptance test for Feature 02.5 (Containment, response and the authorization gate).
#
# Phase F (SF-2): T37. The authorization gate, proven in both directions -- one compile
# negative per row of the feature plan's Interface Contract 2, the Interface Contract 1 and 3
# shape rules, every shipped profile still compiling, and the runtime half under the `default`
# profile: the credentials a classified action would need are ABSENT from every agent, and a
# CONNECT to github.com from `claude` and `agy` is refused with an audit line carrying `agent`
# and `identity_source`.
#
# Phases A-E arrive with SF-3 and SF-4 (feature plan Interface Contract 8): A static, B T40,
# C the pod-wide cut, D R12.5, E the T41 mechanical steps. The teardown contract below is
# written for them: `down -v --remove-orphans` runs ONLY in the trap, under this script's own
# project name, because the phases that follow assert what SURVIVES a `down` and a harness that
# volume-pruned between phases would destroy the evidence it is measuring.
#
# There is no skip variable, following `retry_cold_peer`'s reasoning: a phase that can be turned
# off is a phase whose red state has an accepted excuse.
#
# Requires: yq (mikefarah/yq), docker, jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROJECT="containment-$$"
PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
note() { echo "      $*"; }
phase() { echo; echo "=== Phase $1 -- $2"; }

for c in yq docker jq; do
  command -v "$c" >/dev/null 2>&1 || { echo "verify-containment: $c is required" >&2; exit 1; }
done

# The `default` topology, not the fixture one: phase F's runtime half is a statement about what
# the SHIPPED profile denies, and the fixture allowlist would refuse github.com for every agent
# including `codex`, turning the measurement into a tautology. Phases B-E take the fixture
# topology when they land (Interface Contract 8), and add their own array beside this one.
COMPOSE=(docker compose --env-file compose/pins.env
         -f compose/compose.yaml
         -f compose/overrides/default.yaml
         -p "$PROJECT")

FIXTURES="tests/fixtures/authorization"
PROBE_PACK_DIR="packs/authz-probe"
STACK_UP=0

cleanup() {
  rm -f "$FIXTURES"/probe-*.yaml
  rm -rf "$PROBE_PACK_DIR"
  if [ "$STACK_UP" = 1 ]; then
    echo
    echo "--- tearing down $PROJECT ---"
    AGENT_PROFILE=default "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

[ ! -e "$PROBE_PACK_DIR" ] || {
  echo "verify-containment: $PROBE_PACK_DIR already exists; remove it before running" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Phase F -- T37: the authorization gate
# ---------------------------------------------------------------------------
phase F "T37 -- the authorization gate (compile negatives, then the runtime half)"

# expect <want-exit> <message fragment> <label> -- <command...>
# The exit code AND the message. A gate that fires for the wrong reason is a gate that will stop
# firing when that reason is fixed, so every negative names the token the operator has to read.
expect() {
  local want="$1" frag="$2" label="$3"; shift 3
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: expected exit $want, got $rc"
    printf '%s\n' "$out" | grep -v '^compile-policy: NOTE' | head -4 | sed 's/^/      /'
    return
  fi
  if [ -n "$frag" ] && ! printf '%s' "$out" | grep -qF -- "$frag"; then
    fail "$label: exit $want as expected, but the message did not name '$frag'"
    printf '%s\n' "$out" | grep -v '^compile-policy: NOTE' | head -4 | sed 's/^/      /'
    return
  fi
  pass "$label"
}

# A probe profile is a one-key mutation of a SHIPPED profile, generated here and compiled
# through --profile-file so nothing is written to profiles/ or policy/resolved/. See
# tests/fixtures/authorization/README.md for why these are not committed.
make_probe() { # <name> <source profile> <yq expression>
  yq eval "$3" "profiles/$2.yaml" > "$FIXTURES/probe-$1.yaml"
}
compile_probe() { # <name>
  bash scripts/compile-policy.sh --profile "authz-probe-$1" \
    --profile-file "$FIXTURES/probe-$1.yaml" --out "$(mktemp)"
}

# --- every shipped profile still compiles (the positive direction) -------------------------
for p in profiles/*.yaml; do
  base="$(basename "$p" .yaml)"
  expect 0 "" "F: shipped profile '$base' compiles under the T37 gate" \
    bash scripts/compile-policy.sh --profile "$base" --out "$(mktemp)"
done

# --- Interface Contract 2, row by row ------------------------------------------------------

# Row 1 -- the whole-profile waiver stands alone.
make_probe waiver-and-classify default '.authorization.waiver = "a reason"'
expect 2 "The whole-profile waiver stands alone" \
  "F: row 1 -- 'waiver' together with 'classify' is refused" \
  compile_probe waiver-and-classify

make_probe waiver-and-waive test-fixtures '.authorization.waive."git-push" = "a reason"'
expect 2 "The whole-profile waiver stands alone" \
  "F: row 1 -- 'waiver' together with 'waive' is refused" \
  compile_probe waiver-and-waive

# Row 2 -- an action no committed manifest declares.
make_probe unknown-action default '.authorization.classify += ["git-pusk"]'
expect 2 "no committed pack declares it" \
  "F: row 2 -- a classified action outside the vocabulary is refused, and the message says why" \
  compile_probe unknown-action

make_probe unknown-waive default '.authorization.waive."git-pusk" = "a reason"'
expect 2 "no committed pack declares it" \
  "F: row 2 -- a WAIVED action outside the vocabulary is refused too" \
  compile_probe unknown-waive

# Row 3 -- the same action classified and waived.
make_probe both default '.authorization.waive."git-push" = "a reason"'
expect 2 "both 'classify' and 'waive'" \
  "F: row 3 -- an action in both classify and waive is refused" \
  compile_probe both

# Row 4 -- a known action accounted for nowhere.
make_probe unaccounted default 'del(.authorization.classify[] | select(. == "infrastructure-apply"))'
expect 2 "neither classifies nor waives it" \
  "F: row 4 -- a known action in neither classify nor waive is refused" \
  compile_probe unaccounted
if grep -qF "packs/kubernetes/pack.yaml" <<< "$(compile_probe unaccounted 2>&1 || true)"; then
  pass "F: row 4 -- the message names the manifest that declares the action"
else
  fail "F: row 4 -- the message does not name packs/kubernetes/pack.yaml"
fi

# Row 5 -- a waiver with no reason, and a `waive` that is not a map.
make_probe empty-waive-reason github '.authorization.waive."git-push" = ""'
expect 2 "has no recorded reason" \
  "F: row 5 -- an empty waive reason is refused" \
  compile_probe empty-waive-reason

make_probe waive-not-map github '.authorization.waive = ["git-push"]'
expect 2 "must be a mapping of action -> recorded reason" \
  "F: row 5 -- a 'waive' list is refused; a waiver without a reason is not a waiver" \
  compile_probe waive-not-map

# Row 6 -- THE REFUSAL (exit 3). `github` loads packs/github-cli, which enables git-push.
# This is the negative control the Test Strategy names: move the action back to classify.
make_probe refusal github \
  'del(.authorization.waive."git-push") | .authorization.classify += ["git-push"]'
expect 3 "packs/github-cli/pack.yaml" \
  "F: row 6 -- classifying an action a LOADED pack enables is a refusal (exit 3)" \
  compile_probe refusal
REFUSAL_OUT="$(compile_probe refusal 2>&1 || true)"
if grep -qF "remove the pack" <<< "$REFUSAL_OUT" && grep -qF "'waive' with a recorded reason" <<< "$REFUSAL_OUT"; then
  pass "F: row 6 -- the refusal names both remedies"
else
  fail "F: row 6 -- the refusal does not name both remedies"
  printf '%s\n' "$REFUSAL_OUT" | grep -v '^compile-policy: NOTE' | head -3 | sed 's/^/      /'
fi

# A classified action enabled by a pack the profile does NOT load is allowed to stand: the
# classification is a statement about the profile, not about its pack list (Decision 1).
if bash scripts/compile-policy.sh --profile kubernetes --out "$(mktemp)" >/dev/null 2>&1; then
  pass "F: 'kubernetes' classifies git-push while loading no pack that enables it -- allowed"
else
  fail "F: 'kubernetes' should compile: it classifies an action none of its packs enables"
fi

# --- Interface Contract 3: MCP entries -----------------------------------------------------
MCP_SERVER_BASE='{
  "name": "authz-probe-srv", "agents": ["claude"], "version": "1.0.0",
  "artifact": "n/a: fixture",
  "transport": "stdio", "enforcement_point": "none",
  "egress": {"allow_fqdns": [], "allow_cidrs": []},
  "mounts": [], "env": [], "credentials": [],
  "needs_write_access": false, "risk_tier": "irreversible",
  "capability_baseline": {"config_sha256": "'"$(printf 'authz-probe' | shasum -a 256 | cut -d' ' -f1)"'", "tools": []}
}'

# R7.16: a non-empty mcp.servers needs a pinned registry, so every probe below sets one.
MCP_REG='.mcp.registry = {"type": "npm-tarball", "url": "https://example.test", "pinned": "1"}'

make_probe mcp-irreversible default ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG"
expect 2 "declares no enables_actions" \
  "F: Contract 3 -- an 'irreversible' server with no enables_actions is refused" \
  compile_probe mcp-irreversible

make_probe mcp-unaccounted default \
  ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG | .mcp.servers[0].enables_actions = [\"cluster-drain\"]"
expect 2 "neither classifies nor waives it" \
  "F: Contract 3 -- a server's action joins the vocabulary and must be accounted for" \
  compile_probe mcp-unaccounted

make_probe mcp-refusal default \
  ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG | .mcp.servers[0].enables_actions = [\"git-push\"]"
expect 3 "authz-probe-srv" \
  "F: Contract 3 -- classifying an action an INVENTORIED server enables is a refusal (exit 3)" \
  compile_probe mcp-refusal

make_probe mcp-bad-action default \
  ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG | .mcp.servers[0].enables_actions = [\"Git-Push\"]"
expect 2 "is not a valid action name" \
  "F: Contract 3 -- a malformed action name on a server is refused" \
  compile_probe mcp-bad-action

# --- Interface Contract 1: pack manifests, INCLUDING ones no profile selects ----------------
# The vocabulary is the union over every committed manifest, so a malformed manifest nothing
# loads must still fail the compile rather than contribute a name silently.
mkdir -p "$PROBE_PACK_DIR"
probe_pack() { # <fixture suffix>
  cp "$FIXTURES/pack-$1.yaml" "$PROBE_PACK_DIR/pack.yaml"
}

probe_pack bad-name
expect 2 "is not a valid action name" \
  "F: Contract 1 -- a malformed action name in an UNSELECTED manifest fails the compile" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

probe_pack duplicate
expect 2 "more than once" \
  "F: Contract 1 -- a duplicated action in a manifest is refused" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

probe_pack not-list
expect 2 "must be a list of action names" \
  "F: Contract 1 -- a scalar enables_actions is refused" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

rm -rf "$PROBE_PACK_DIR"
expect 0 "" "F: the tree compiles again once the probe manifest is removed" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

# --- R7.8: enables_actions is a KNOWN key, and the unknown-key gate still refuses others ----
if grep -qF 'enables_actions' <<< "$(grep '^KNOWN_PACK_KEYS=' scripts/compile-policy.sh)"; then
  pass "F: 'enables_actions' is in the compiler's known-pack-key set (R7.8)"
else
  fail "F: 'enables_actions' is not in KNOWN_PACK_KEYS; a manifest declaring it would be refused"
fi

# --- the runtime half: capability absence under `default` -----------------------------------
# Decision 1's claim is that a classified action is structurally unavailable, not merely written
# down. Under `default` that means: no GitHub credential and no `gh`, no kubeconfig and no
# `kubectl`/`helm`, in any agent -- and github.com refused at the mediator for the two agents
# whose base allowlist does not carry it.
phase F "T37 runtime -- capability absence and the refused CONNECT (profile 'default')"

# The generated probe profiles go BEFORE the build, not at EXIT: the solution root is the image
# build context, so leaving them in place churns the context hash for no reason.
rm -f "$FIXTURES"/probe-*.yaml


AGENT_PROFILE=default "${COMPOSE[@]}" build egress-mediator claude codex agy \
  >"${TMPDIR:-/tmp}/containment-build.$$.log" 2>&1 || {
  fail "F: image build failed under profile 'default'"
  tail -20 "${TMPDIR:-/tmp}/containment-build.$$.log" | sed 's/^/      /'
}
STACK_UP=1
AGENT_PROFILE=default "${COMPOSE[@]}" up -d --force-recreate egress-mediator \
  >"${TMPDIR:-/tmp}/containment-up.$$.log" 2>&1 || {
  fail "F: the mediator failed to start under profile 'default'"
  tail -20 "${TMPDIR:-/tmp}/containment-up.$$.log" | sed 's/^/      /'
}

in_agent() { # <agent> <sh -c script>
  AGENT_PROFILE=default "${COMPOSE[@]}" run --rm --no-deps "$1" sh -c "$2" 2>/dev/null || true
}

for a in claude codex agy; do
  ABSENT=1
  for probe in 'printf "%s" "${GH_TOKEN:-}${GITHUB_TOKEN:-}"' \
               'printf "%s" "${KUBECONFIG:-}"' \
               'command -v gh || true' \
               'command -v kubectl || true' \
               'command -v helm || true' \
               'cat "$HOME/.git-credentials" 2>/dev/null || true'; do
    OUT="$(in_agent "$a" "$probe")"
    if [ -n "${OUT//[[:space:]]/}" ]; then
      ABSENT=0
      note "$a: '$probe' produced: $OUT"
    fi
  done
  [ "$ABSENT" = 1 ] \
    && pass "F: '$a' under 'default' carries no push or apply capability (no token, no kubeconfig, no gh/kubectl/helm)" \
    || fail "F: '$a' under 'default' carries a capability a classified action needs"
done

# The CONNECT. `codex`'s base allowlist carries github.com for the reasons recorded at 01.1
# (Edge Case 16), so it is deliberately NOT asserted as refused -- its only barrier is the
# absent credential, which the block above measured.
med_audit() { docker exec "${PROJECT}-egress-mediator-1" cat /var/log/mediator/egress-audit.log 2>/dev/null; }

connect_probe='
ca=/run/secrets/mediator-ca.crt
args="--proxy-cacert $ca"
if [ -r /run/secrets/claude-client.crt ]; then
  args="$args --proxy-cert /run/secrets/claude-client.crt --proxy-key /run/secrets/claude-client.key"
fi
curl -sS -o /dev/null $args --max-time 20 https://github.com/ 2>&1 || true
'

for a in claude agy; do
  OUT="$(in_agent "$a" "$connect_probe")"
  case "$OUT" in
    *"response 403"*|*"code 403 from proxy"*)
      pass "F: '$a' is refused CONNECT github.com by the mediator under 'default'" ;;
    *)
      fail "F: '$a' was not refused CONNECT github.com under 'default'"
      note "curl said: ${OUT:-<nothing>}" ;;
  esac
  LINE="$(med_audit | jq -c --arg a "$a" \
    'select(.verdict == "deny" and .dest_host == "github.com" and .agent == $a)' | tail -1)"
  if [ -z "$LINE" ]; then
    fail "F: no deny line for ($a, github.com) on the audit trail"
  elif printf '%s' "$LINE" | jq -e '.agent != null and .identity_source != null and .ts != null' >/dev/null; then
    pass "F: the ($a, github.com) deny line carries agent and identity_source ($(printf '%s' "$LINE" | jq -r '.identity_source'))"
  else
    fail "F: the ($a, github.com) deny line is missing agent or identity_source"
    note "$LINE"
  fi
done

# ---------------------------------------------------------------------------
echo
echo "=== verify-containment: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] || exit 1
