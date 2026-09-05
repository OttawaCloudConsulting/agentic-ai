#!/usr/bin/env bash
# Feature 01.1 test command. Checks policy/*.yaml for well-formedness only -- it does NOT
# validate governance records (docs/records/), which are inspection tests (T42, T43), not lint
# targets. Requires yq (mikefarah/yq).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_DIR="$REPO_ROOT/policy"
ALLOWLIST="$POLICY_DIR/allowlist.base.yaml"
DENYLIST="$POLICY_DIR/denylist.base.yaml"
RECORDS_DIR="$REPO_ROOT/docs/records"

fail() { echo "lint-policy: FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "yq is required (https://github.com/mikefarah/yq)"

# --- both policy YAML files parse ---
yq eval '.' "$ALLOWLIST" >/dev/null 2>&1 || fail "$ALLOWLIST does not parse as YAML"
yq eval '.' "$DENYLIST" >/dev/null 2>&1 || fail "$DENYLIST does not parse as YAML"

# --- denylist.base.yaml contains all five required ranges (R5.6) ---
for cidr in 169.254.0.0/16 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
  yq eval ".deny_cidrs[] | select(. == \"$cidr\")" "$DENYLIST" | grep -qx "$cidr" \
    || fail "$DENYLIST missing required range $cidr"
done

# --- allowlist.base.yaml carries provisional: true ---
[[ "$(yq eval '.provisional' "$ALLOWLIST")" == "true" ]] \
  || fail "$ALLOWLIST must carry provisional: true (D17)"

# --- keyed per agent; every agent key exposes both allow_fqdns and allow_cidrs ---
AGENTS="$(yq eval '.agents | keys | .[]' "$ALLOWLIST")"
[[ -n "$AGENTS" ]] || fail "$ALLOWLIST has no agents"
while IFS= read -r agent; do
  yq eval ".agents.${agent} | has(\"allow_fqdns\")" "$ALLOWLIST" | grep -qx "true" \
    || fail "agent '$agent' missing allow_fqdns"
  yq eval ".agents.${agent} | has(\"allow_cidrs\")" "$ALLOWLIST" | grep -qx "true" \
    || fail "agent '$agent' missing allow_cidrs"
done <<< "$AGENTS"

# --- every allowlist entry carries a source annotation ---
while IFS= read -r agent; do
  count="$(yq eval ".agents.${agent}.allow_fqdns | length" "$ALLOWLIST")"
  for ((i = 0; i < count; i++)); do
    src_len="$(yq eval ".agents.${agent}.allow_fqdns[$i].source | length" "$ALLOWLIST")"
    [[ "$src_len" =~ ^[0-9]+$ ]] && ((src_len > 0)) \
      || fail "agent '$agent' allow_fqdns[$i] missing a non-empty source list"
  done
done <<< "$AGENTS"

# --- the pins: reference resolves to the SF-2 record ---
PINS_REF="$(yq eval '.pins' "$ALLOWLIST")"
[[ -f "$RECORDS_DIR/$PINS_REF" ]] || fail "pins: '$PINS_REF' does not resolve under $RECORDS_DIR"

echo "lint-policy: OK"
