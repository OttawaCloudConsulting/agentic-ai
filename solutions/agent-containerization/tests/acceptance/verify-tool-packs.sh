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

echo
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ]
