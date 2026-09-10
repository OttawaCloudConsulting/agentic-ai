#!/usr/bin/env bash
# Acceptance test for Feature 02.3 (Tool pack set, use-case profiles and MCP inventory).
#
# Phase A (this file, SF-1): the pack manifest schema additions -- `env`, `credentials`,
# `third_parties`, and the unknown-top-level-key refusal. Host-only: no docker, no pod.
# Later sub-features append Phases B-G to this same file, following 01.5's
# verify-pack-composition.sh idiom of one growing harness rather than one script per SF.
#
# Requires: yq (mikefarah/yq), git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
phase() { echo; echo "=== Phase $1 -- $2"; }

command -v yq  >/dev/null 2>&1 || { echo "verify-tool-packs: yq is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "verify-tool-packs: git is required" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Scaffolding -- the sf7-probe idiom from verify-pack-composition.sh (01.5)
# ---------------------------------------------------------------------------

PACK_SRC="packs/language-runtimes/pack.yaml"
PROBE_PACK_DIR="packs/sf7-probe"
PROBE_PACK="${PROBE_PACK_DIR}/pack.yaml"
PROBE_PACK2_DIR="packs/sf7-probe-2"
PROBE_PACK2="${PROBE_PACK2_DIR}/pack.yaml"
PROBE_PROFILE="profiles/sf7-probe.yaml"

for p in "$PROBE_PACK_DIR" "$PROBE_PACK2_DIR" "$PROBE_PROFILE"; do
  [ ! -e "$p" ] || {
    echo "verify-tool-packs: $p already exists; remove it before running" >&2
    exit 1
  }
done

cleanup() { rm -rf "$PROBE_PACK_DIR" "$PROBE_PACK2_DIR" "$PROBE_PROFILE"; }
trap cleanup EXIT

expect() {
  local want="$1" frag="$2" label="$3"; shift 3
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: expected exit $want, got $rc"
    printf '%s\n' "$out" | head -3 | sed 's/^/      /'
    return
  fi
  if [ -n "$frag" ] && ! printf '%s' "$out" | grep -qF -- "$frag"; then
    fail "$label: exit $want as expected, but the message did not name '$frag'"
    printf '%s\n' "$out" | head -3 | sed 's/^/      /'
    return
  fi
  pass "$label"
}

make_probe_pack() {
  local expr="$1" dir="${2:-$PROBE_PACK_DIR}" name="${3:-sf7-probe}"
  mkdir -p "$dir"
  yq eval "$expr" "$PACK_SRC" > "$dir/pack.yaml"
  if [ "$(yq eval 'has("name")' "$dir/pack.yaml")" = "true" ]; then
    yq eval -i ".name = \"$name\"" "$dir/pack.yaml"
  fi
}

make_probe_profile() {
  local expr="$1"
  yq eval "$expr" "profiles/default.yaml" > "$PROBE_PROFILE"
}

compile_probe() {
  bash scripts/compile-policy.sh --profile sf7-probe --out "$(mktemp)" "$@"
}

# ---------------------------------------------------------------------------
# Phase A -- SF-1: env, credentials, third_parties, unknown-key refusal
# ---------------------------------------------------------------------------
phase A "pack manifest schema: env, credentials, third_parties, unknown-key refusal"

expect 0 "" "A: lint-policy.sh accepts the tree as shipped (env/credentials/third_parties well-formed)" \
  bash scripts/lint-policy.sh

# Acceptance Criterion 1: `third_parties` joins the mandatory field set.
make_probe_pack 'del(.third_parties)'
expect 1 "packs/sf7-probe/pack.yaml: mandatory field 'third_parties' is missing" \
  "A: manifest without 'third_parties' is refused, naming file and field" \
  bash scripts/lint-policy.sh
rm -rf "$PROBE_PACK_DIR"

# Criterion 2 -- mounts: still refused, message corrected (no longer claims a stale
# "land at 01.5 SF-5"; now names the R2.8 review path).
make_probe_pack '.mounts = [{"project": null}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "is a design change reviewed against R2.8's enumeration" \
  "A: a populated 'mounts' is still refused, with the corrected message" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# Criterion 2 -- env: reserved name refused (Interface Contract 1).
make_probe_pack '.env = [{"name": "PATH", "value": "x", "reason": "probe"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "which the pod contract already sets" \
  "A: an env entry naming a reserved variable (PATH) is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# env: name not matching the schema regex is an input-validation failure (exit 2), not a
# policy refusal (exit 3) -- it is malformed, not a decision the operator made.
make_probe_pack '.env = [{"name": "not-a-valid-name", "value": "x", "reason": "probe"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "does not match" \
  "A: an env entry with a malformed name is an input-validation failure" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# env: missing 'reason' is refused.
make_probe_pack '.env = [{"name": "SF7_PROBE_VAR", "value": "x"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "env[0].reason is missing" \
  "A: an env entry with no 'reason' is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# env: the same variable declared by two selected packs is refused (Interface Contract 1's
# duplicate rule), not silently resolved by whichever pack composed last.
make_probe_pack '.env = [{"name": "SF7_DUP_VAR", "value": "a", "reason": "probe one"}]' "$PROBE_PACK_DIR" sf7-probe
make_probe_pack '.env = [{"name": "SF7_DUP_VAR", "value": "b", "reason": "probe two"}]' "$PROBE_PACK2_DIR" sf7-probe-2
make_probe_profile '.packs = ["sf7-probe", "sf7-probe-2"]'
expect 3 "already declared by packs/sf7-probe/pack.yaml" \
  "A: an env variable declared by two selected packs is refused, naming both sources" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PACK2_DIR" "$PROBE_PROFILE"

# credentials: both delivery forms at once is refused (exactly one of env|path_env).
make_probe_pack '.credentials = [{"name": "sf7-probe-cred", "delivery": {"env": "SF7_TOK", "path_env": "SF7_PATH"}, "description": "d", "blast_radius": "b", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "delivery must be exactly one of" \
  "A: a credential declaring both 'env' and 'path_env' delivery is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# credentials: a missing prose field (blast_radius) is refused.
make_probe_pack '.credentials = [{"name": "sf7-probe-cred", "delivery": {"env": "SF7_TOK"}, "description": "d", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "credentials[0].blast_radius is missing" \
  "A: a credential missing 'blast_radius' is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# credentials: a name duplicated within one pack is refused.
make_probe_pack '.credentials = [{"name": "dup", "delivery": {"env": "SF7_A"}, "description": "d", "blast_radius": "b", "revocation": "r"}, {"name": "dup", "delivery": {"env": "SF7_B"}, "description": "d", "blast_radius": "b", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "declares 'dup' twice" \
  "A: a credential name duplicated within a pack is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# third_parties: required non-empty iff egress.runtime is non-empty (R14.1).
make_probe_pack '.egress.runtime.allow_fqdns = [{"fqdn": "sf7-probe.example", "port": 443, "upgrade": false}] | .runtime_install = true | .runtime_install_reason = "probe"'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "but an empty third_parties" \
  "A: non-empty egress.runtime with an empty third_parties is refused (R14.1)" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# third_parties: an unresolvable record anchor is refused by lint-policy.sh (well-formedness
# of the reference, not a compile-time policy decision).
make_probe_pack '.third_parties = [{"party": "Nobody", "record": "docs/records/third-party-assessments.md#sf7-nonexistent-anchor"}]'
expect 1 "does not resolve -- no id=\"sf7-nonexistent-anchor\" anchor" \
  "A: a third_parties record whose anchor does not exist is refused" \
  bash scripts/lint-policy.sh
rm -rf "$PROBE_PACK_DIR"

# Unknown top-level key (R7.8): a pack manifest cannot carry cap_add, privileged or devices
# by adding an unrecognised key, silently or otherwise.
make_probe_pack '.cap_add = ["NET_ADMIN"]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "unrecognised top-level key 'cap_add'" \
  "A: an unrecognised top-level manifest key (cap_add) is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"


# ---------------------------------------------------------------------------
# Phase B -- SF-2: pack env/credential delivery (entrypoint export + map,
#            check-profile-compose.sh)
# ---------------------------------------------------------------------------
phase B "pack env/credential delivery -- entrypoint, check-profile-compose.sh"

command -v docker >/dev/null 2>&1 || { echo "verify-tool-packs: docker is required for Phase B" >&2; exit 1; }
grep -n '^AGENT_BASE_DIGEST=' compose/pins.env >/dev/null \
  || { echo "verify-tool-packs: AGENT_BASE_DIGEST not found in compose/pins.env" >&2; exit 1; }
AGENT_BASE_DIGEST="$(sed -n 's/^AGENT_BASE_DIGEST=//p' compose/pins.env | tail -n1)"

B_TMP="$(mktemp -d)"
B_CREDS_DIR="$B_TMP/credentials"
B_IMAGE="verify-tool-packs-sf7-probe:agent-packs"
mkdir -p "$B_CREDS_DIR/sf7-probe/sf7-probe"
printf 'probe-secret-value' > "$B_CREDS_DIR/sf7-probe/sf7-probe/probe-cred"

b_cleanup() {
  docker rmi -f "$B_IMAGE" >/dev/null 2>&1 || true
  rm -rf "$B_TMP"
}
trap 'cleanup; b_cleanup' EXIT

make_probe_pack '.env = [{"name": "SF7_PROBE_ENV", "value": "probe-value", "reason": "Phase B probe"}] | .credentials = [{"name": "probe-cred", "delivery": {"env": "SF7_PROBE_CRED"}, "description": "d", "blast_radius": "b", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'

expect 1 "no compose/overrides/sf7-probe.yaml" \
  "B: check-profile-compose.sh refuses a profile with no same-named override" \
  bash scripts/check-profile-compose.sh --profile sf7-probe

expect 0 "ok -- secret set matches the manifests, no other drift from default" \
  "B: check-profile-compose.sh accepts 'default' against itself" \
  bash scripts/check-profile-compose.sh --profile default

if docker build -f images/Dockerfile --target agent-packs \
     --build-arg "AGENT_BASE_DIGEST=${AGENT_BASE_DIGEST}" --build-arg PROFILE=sf7-probe \
     -t "$B_IMAGE" . > "$B_TMP/build.log" 2>&1; then
  pass "B: agent-packs image builds for a profile carrying a pack env + credential"
else
  fail "B: agent-packs image failed to build for the probe profile"
  tail -20 "$B_TMP/build.log" | sed 's/^/      /'
fi

# The variable is exported, and the credential's CONTENT lands in the delivery.env
# variable -- from a secret this run mounts, never from the plan file itself (the
# plan carries only the delivery FORM, never a value).
OUT="$(docker run --rm -v "$B_CREDS_DIR/sf7-probe/sf7-probe/probe-cred:/run/secrets/pack-sf7-probe-probe-cred:ro" "$B_IMAGE" env 2>&1)" || true
if grep -qF 'SF7_PROBE_ENV=probe-value' <<< "$OUT" && grep -qF 'SF7_PROBE_CRED=probe-secret-value' <<< "$OUT"; then
  pass "B: the pack env variable and the mapped credential are present under the loading profile"
else
  fail "B: expected SF7_PROBE_ENV and SF7_PROBE_CRED in the container environment"
  grep -E 'SF7_PROBE' <<< "$OUT" | sed 's/^/      found: /' || echo "      (neither found)"
fi

# The entrypoint asserts presence a second time, at the point of use: a declared
# credential with no mounted secret refuses the start rather than running without it.
RC=0
NO_SECRET_OUT="$(docker run --rm "$B_IMAGE" env 2>&1)" || RC=$?
if [ "$RC" -eq 3 ] && grep -qF "declared credential secret 'pack-sf7-probe-probe-cred' is absent" <<< "$NO_SECRET_OUT"; then
  pass "B: starting the profile with the declared secret unmounted refuses at exit 3, naming the secret"
else
  fail "B: expected exit 3 naming the absent secret, got exit $RC"
  printf '%s\n' "$NO_SECRET_OUT" | head -3 | sed 's/^/      /'
fi

# And under a profile that does not load the pack, neither name resolves at all --
# the reference pack (`default`) carries no env and no credential, so this is the
# `default` build already on disk, not a rebuild.
DEFAULT_OUT="$(docker run --rm sandboxed-agent/claude:local env 2>&1)" || true
if grep -qF 'SF7_PROBE_ENV' <<< "$DEFAULT_OUT" || grep -qF 'SF7_PROBE_CRED' <<< "$DEFAULT_OUT"; then
  fail "B: SF7_PROBE_ENV/SF7_PROBE_CRED leaked into the default profile's image, which loads no pack declaring them"
else
  pass "B: neither name resolves under 'default', which does not load the probe pack"
fi

rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

echo
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ]
