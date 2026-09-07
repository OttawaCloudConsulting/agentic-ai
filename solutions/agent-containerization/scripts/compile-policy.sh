#!/usr/bin/env bash
# Policy compiler, zero-pack form (01.3 SF-2).
#
# Reads policy/allowlist.base.yaml, policy/denylist.base.yaml and profiles/<profile>.yaml and
# emits policy/resolved/<profile>.yaml -- the committed SC-6 artifact the mediator loads. The
# artifact is GENERATED and never hand-edited; `--check` is what enforces that.
#
# 01.5 moves this invocation into a build stage of the mediator image (D10) and adds pack
# composition. The schema emitted here is what it must continue to emit -- see the 01.3 feature
# plan, Interface Contract 1.
#
# Modes:
#   compile (default)      bash scripts/compile-policy.sh [--profile NAME] [--out PATH]
#   validate               bash scripts/compile-policy.sh --validate PATH
#                          Schema check only. This is what the mediator's stage-1 self-check
#                          calls before it renders any proxy configuration (T17).
#   check                  bash scripts/compile-policy.sh --check [--profile NAME]
#                          Recompile to a temp file and diff against the committed artifact,
#                          ignoring compiled_at. Non-zero if they differ.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="default"
MODE="compile"
OUT=""
VALIDATE_TARGET=""

fail() { echo "compile-policy: FAIL: $*" >&2; exit 1; }
note() { echo "compile-policy: $*" >&2; }

# These names do not stay data. The mediator's entrypoint interpolates every allowed
# FQDN and every agent key into the Lua configuration that IS the pod's DNS policy
# (01.3 SF-5), so a name carrying a quote, an escape or a newline would become
# policy CODE inside the enforcement point. The wildcard rejection below already
# accepts that allowlist content is security-relevant input; these are the rest of
# that argument, and they matter more once 01.5 composes PACK-supplied entries into
# the same field.
#
# Hostname: labels of letters, digits and hyphens, no leading or trailing hyphen,
# 63 bytes per label, 253 for the name.
FQDN_RE='^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$'
# Agent key: becomes part of a Lua VARIABLE name, so an identifier, not merely
# something quotable.
AGENT_RE='^[a-z][a-z0-9_]{0,31}$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)  PROFILE="${2:?--profile needs a value}"; shift 2 ;;
    --out)      OUT="${2:?--out needs a value}"; shift 2 ;;
    --validate) MODE="validate"; VALIDATE_TARGET="${2:?--validate needs a path}"; shift 2 ;;
    --check)    MODE="check"; shift ;;
    -h|--help)  sed -n '2,22p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)          fail "unknown argument: $1" ;;
  esac
done

command -v yq >/dev/null 2>&1 || fail "yq is required (https://github.com/mikefarah/yq)"

ALLOWLIST="$REPO_ROOT/policy/allowlist.base.yaml"
DENYLIST="$REPO_ROOT/policy/denylist.base.yaml"
PROFILE_FILE="$REPO_ROOT/profiles/${PROFILE}.yaml"
RESOLVED_DIR="$REPO_ROOT/policy/resolved"
[[ -n "$OUT" ]] || OUT="$RESOLVED_DIR/${PROFILE}.yaml"

# --------------------------------------------------------------------------------------------
# validate -- the mediator's stage-1 self-check (T17)
#
# Every failure names the file and the field, because that is what T17 asserts: a corrupt
# resolved policy aborts startup with an error an operator can act on, not a stack trace.
# --------------------------------------------------------------------------------------------
validate_resolved() {
  local f="$1"
  [[ -f "$f" ]] || fail "$f: does not exist"
  yq eval '.' "$f" >/dev/null 2>&1 || fail "$f: does not parse as YAML"

  local schema; schema="$(yq eval '.schema' "$f")"
  [[ "$schema" == "1" ]] || fail "$f: field 'schema' must be 1, found '$schema'"

  # has(), not `// "null"`: yq's alternative operator treats a legitimate `false` as absent,
  # so `provisional: false` would read as a missing field.
  for field in profile compiled_at provisional pins; do
    [[ "$(yq eval "has(\"$field\")" "$f")" == "true" ]] \
      || fail "$f: field '$field' is missing"
    local v; v="$(yq eval ".$field" "$f")"
    [[ -n "$v" ]] || fail "$f: field '$field' is empty"
  done

  for field in allowlist denylist profile; do
    [[ "$(yq eval ".compiled_from | has(\"$field\")" "$f")" == "true" ]] \
      || fail "$f: field 'compiled_from.$field' is missing"
  done
  [[ "$(yq eval '.compiled_from | has("packs")' "$f")" == "true" ]] \
    || fail "$f: field 'compiled_from.packs' is missing (must be present and empty at this milestone)"

  for field in deny_cidrs deny_fqdns exclusions; do
    [[ "$(yq eval "has(\"$field\")" "$f")" == "true" ]] \
      || fail "$f: field '$field' is missing (must be present, may be empty)"
  done

  # deny_fqdns closes R5.1's FQDN term; deny_cidrs closes its address and range terms. An
  # unmasked address here would be an ambiguous deny, so the compiler normalises and the
  # validator refuses anything it did not normalise.
  local n i
  n="$(yq eval '.deny_cidrs | length' "$f")"
  for ((i = 0; i < n; i++)); do
    local cidr; cidr="$(yq eval ".deny_cidrs[$i]" "$f")"
    [[ "$cidr" == */* ]] || fail "$f: deny_cidrs[$i] '$cidr' has no prefix length (expected /32 or /128 for a single address)"
  done

  local agents; agents="$(yq eval '.agents | keys | .[]' "$f")"
  [[ -n "$agents" ]] || fail "$f: field 'agents' is empty"
  while IFS= read -r agent; do
    [[ "$agent" =~ $AGENT_RE ]] \
      || fail "$f: agent key '$agent' is not a valid identifier. It is interpolated into the mediator's Lua policy as a variable name."
    for field in identity listener_port allow_fqdns allow_cidrs limits listener; do
      [[ "$(yq eval ".agents.${agent} | has(\"$field\")" "$f")" == "true" ]] \
        || fail "$f: agents.${agent} is missing field '$field'"
    done
    # `connections_per_minute` is deliberately NOT in this list. Squid 6.13 has no
    # per-client connection-rate directive (docs/records/mediator-selection.md, P3),
    # so the field was dropped at 01.3 SF-6 rather than shipped as a policy key that
    # silently enforces nothing. It is also refused below, so an artifact carrying it
    # fails loudly instead of implying a ceiling that does not exist.
    for field in max_concurrent bytes_per_second; do
      [[ "$(yq eval ".agents.${agent}.limits | has(\"$field\")" "$f")" == "true" ]] \
        || fail "$f: agents.${agent}.limits.$field is missing"
      local v; v="$(yq eval ".agents.${agent}.limits.$field" "$f")"
      [[ "$v" =~ ^[0-9]+$ ]] || fail "$f: agents.${agent}.limits.$field must be a non-negative integer, found '$v'"
    done
    [[ "$(yq eval ".agents.${agent}.limits | has(\"connections_per_minute\")" "$f")" == "false" ]] \
      || fail "$f: agents.${agent}.limits carries 'connections_per_minute', which no longer exists. The selected proxy has no per-client connection-rate mechanism (01.3 SF-6, deviation 4); recompile from a profile that does not declare it."
    local scheme; scheme="$(yq eval ".agents.${agent}.listener.scheme" "$f")"
    [[ "$scheme" == "https" || "$scheme" == "http" ]] \
      || fail "$f: agents.${agent}.listener.scheme must be 'https' or 'http', found '$scheme'"
    local tls; tls="$(yq eval ".agents.${agent}.listener.tls" "$f")"
    [[ "$tls" == "true" || "$tls" == "false" ]] \
      || fail "$f: agents.${agent}.listener.tls must be true or false, found '$tls'"
    # criterion 6: the scheme and the TLS flag are two spellings of one fact and must agree.
    if [[ "$scheme" == "https" && "$tls" != "true" ]] || [[ "$scheme" == "http" && "$tls" != "false" ]]; then
      fail "$f: agents.${agent}.listener scheme '$scheme' contradicts tls '$tls'"
    fi

    local fq_n j
    fq_n="$(yq eval ".agents.${agent}.allow_fqdns | length" "$f")"
    for ((j = 0; j < fq_n; j++)); do
      local fqdn port
      fqdn="$(yq eval ".agents.${agent}.allow_fqdns[$j].fqdn" "$f")"
      port="$(yq eval ".agents.${agent}.allow_fqdns[$j].port" "$f")"
      [[ -n "$fqdn" && "$fqdn" != "null" ]] || fail "$f: agents.${agent}.allow_fqdns[$j] has no fqdn"
      [[ "$port" =~ ^[0-9]+$ ]] || fail "$f: agents.${agent}.allow_fqdns[$j].port must be an integer, found '$port'"
      # The resolver is a closed forwarder and matches names exactly; a wildcard would make it
      # an open forwarder for everything under the suffix, which is the DNS exfiltration channel
      # R5.4 exists to close. Refused at compile time, not at run time.
      [[ "$fqdn" != *"*"* ]] || fail "$f: agents.${agent}.allow_fqdns[$j].fqdn '$fqdn' is a wildcard; exact names only"
      # Not merely "non-empty": this value becomes Lua source in the enforcement
      # point, so it has to be a hostname and nothing else.
      [[ "${#fqdn}" -le 253 && "$fqdn" =~ $FQDN_RE ]] \
        || fail "$f: agents.${agent}.allow_fqdns[$j].fqdn '$fqdn' is not a valid hostname. It is interpolated into the mediator's Lua policy, so quotes, escapes or newlines would become policy code."
      # A non-443 port is a design question, not a config detail (criterion 3).
      [[ "$port" == "443" ]] || note "WARNING: agents.${agent}.allow_fqdns[$j] '$fqdn' uses port $port, not 443 -- review before shipping"
    done
  done <<< "$agents"

  for field in allowed denied offline; do
    [[ "$(yq eval ".startup_check | has(\"$field\")" "$f")" == "true" ]] \
      || fail "$f: startup_check.$field is missing"
  done
  local offline; offline="$(yq eval '.startup_check.offline' "$f")"
  [[ "$offline" == "true" || "$offline" == "false" ]] \
    || fail "$f: startup_check.offline must be true or false, found '$offline'"

  echo "compile-policy: $f validates against schema 1"
}

if [[ "$MODE" == "validate" ]]; then
  validate_resolved "$VALIDATE_TARGET"
  exit 0
fi

# --------------------------------------------------------------------------------------------
# compile
# --------------------------------------------------------------------------------------------
for f in "$ALLOWLIST" "$DENYLIST" "$PROFILE_FILE"; do
  [[ -f "$f" ]] || fail "input not found: $f"
  yq eval '.' "$f" >/dev/null 2>&1 || fail "$f does not parse as YAML"
done

# Relative paths in compiled_from, so the artifact says what it was built from without leaking
# the operator's directory layout into a committed file.
REL_ALLOWLIST="policy/allowlist.base.yaml"
REL_DENYLIST="policy/denylist.base.yaml"
REL_PROFILE="profiles/${PROFILE}.yaml"

PACKS_LEN="$(yq eval '.packs | length' "$PROFILE_FILE")"
[[ "$PACKS_LEN" == "0" ]] \
  || fail "$REL_PROFILE declares $PACKS_LEN pack(s); pack composition is 01.5's, this compiler is zero-pack only"

PROVISIONAL="$(yq eval '.provisional' "$ALLOWLIST")"
PINS="$(yq eval '.pins' "$ALLOWLIST")"
COMPILED_AT="${COMPILED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

# normalise_cidr: a bare address becomes an explicit single-address mask (criterion 10, R5.1).
# An operator who writes 169.254.169.254 gets the behaviour R5.1 promises, not a schema error.
normalise_cidr() {
  local c="$1"
  if [[ "$c" == */* ]]; then printf '%s' "$c"; return; fi
  if [[ "$c" == *:* ]]; then printf '%s/128' "$c"; else printf '%s/32' "$c"; fi
}

TMP="$(mktemp)"
trap 'rm -f "$TMP" "$TMP.cmp" 2>/dev/null || true' EXIT

{
  echo "# GENERATED by scripts/compile-policy.sh -- do not hand-edit (SC-6)."
  echo "# Edit policy/allowlist.base.yaml, policy/denylist.base.yaml or ${REL_PROFILE}, then recompile."
  echo "# Verify with: bash scripts/compile-policy.sh --check"
  echo "schema: 1"
  echo "profile: ${PROFILE}"
  echo "compiled_at: ${COMPILED_AT}"
  echo "compiled_from:"
  echo "  allowlist: ${REL_ALLOWLIST}"
  echo "  denylist: ${REL_DENYLIST}"
  echo "  profile: ${REL_PROFILE}"
  echo "  packs: []"
  echo "provisional: ${PROVISIONAL}"
  echo "pins: ${PINS}"
  echo ""
  echo "agents:"

  AGENTS="$(yq eval '.agents | keys | .[]' "$ALLOWLIST")"
  while IFS= read -r agent; do
    [[ "$agent" =~ $AGENT_RE ]] \
      || fail "$REL_ALLOWLIST: agent key '$agent' is not a valid identifier; it becomes a Lua variable name in the mediator's policy"
    # has(), not `// "null"`: `tls: false` is the codex listener's correct value and yq's
    # alternative operator would report it as absent.
    for k in scheme tls port; do
      [[ "$(yq eval ".listeners.${agent} | has(\"$k\")" "$PROFILE_FILE")" == "true" ]] \
        || fail "$REL_PROFILE has no listeners.${agent}.${k}"
    done
    LISTENER_SCHEME="$(yq eval ".listeners.${agent}.scheme" "$PROFILE_FILE")"
    LISTENER_TLS="$(yq eval ".listeners.${agent}.tls" "$PROFILE_FILE")"
    LISTENER_PORT="$(yq eval ".listeners.${agent}.port" "$PROFILE_FILE")"

    for k in max_concurrent bytes_per_second; do
      [[ "$(yq eval ".rate_limits.${agent} | has(\"$k\")" "$PROFILE_FILE")" == "true" ]] \
        || fail "$REL_PROFILE has no rate_limits.${agent}.${k}"
    done

    echo "  ${agent}:"
    echo "    identity: ${agent}"
    echo "    listener_port: ${LISTENER_PORT}"
    echo "    listener: {scheme: ${LISTENER_SCHEME}, tls: ${LISTENER_TLS}, port: ${LISTENER_PORT}}"
    echo "    allow_fqdns:"

    FQ_N="$(yq eval ".agents.${agent}.allow_fqdns | length" "$ALLOWLIST")"
    EMITTED=0
    for ((i = 0; i < FQ_N; i++)); do
      FQDN="$(yq eval ".agents.${agent}.allow_fqdns[$i].fqdn" "$ALLOWLIST")"
      PORT="$(yq eval ".agents.${agent}.allow_fqdns[$i].port" "$ALLOWLIST")"
      if [[ "$(yq eval ".agents.${agent}.allow_fqdns[$i] | has(\"upgrade\")" "$ALLOWLIST")" == "true" ]]; then
        UPGRADE="$(yq eval ".agents.${agent}.allow_fqdns[$i].upgrade" "$ALLOWLIST")"
      else
        UPGRADE="false"
      fi
      [[ "$FQDN" != *"*"* ]] \
        || fail "$REL_ALLOWLIST: agents.${agent}.allow_fqdns[$i].fqdn '$FQDN' is a wildcard; the pod resolver matches exactly and a wildcard would reopen DNS exfiltration (R5.4)"
      [[ "${#FQDN}" -le 253 && "$FQDN" =~ $FQDN_RE ]] \
        || fail "$REL_ALLOWLIST: agents.${agent}.allow_fqdns[$i].fqdn '$FQDN' is not a valid hostname; it would be interpolated into the mediator's Lua policy (01.3 SF-5)"
      # Exclusions are declared, not hardcoded: an entry present in the base allowlist and named
      # in the profile's egress_exclusions is NOT copied through, and the reason travels into the
      # artifact (criterion 12, R10.3).
      EX_REASON="$(yq eval ".egress_exclusions[] | select(.agent == \"${agent}\" and .fqdn == \"${FQDN}\") | .reason // \"null\"" "$PROFILE_FILE")"
      if [[ -n "$EX_REASON" && "$EX_REASON" != "null" ]]; then
        continue
      fi
      echo "      - {fqdn: ${FQDN}, port: ${PORT}, upgrade: ${UPGRADE}}"
      EMITTED=$((EMITTED + 1))
    done
    [[ "$EMITTED" -gt 0 ]] || echo "      []"

    CIDR_N="$(yq eval ".agents.${agent}.allow_cidrs | length" "$ALLOWLIST")"
    if [[ "$CIDR_N" == "0" ]]; then
      echo "    allow_cidrs: []"
    else
      echo "    allow_cidrs:"
      for ((i = 0; i < CIDR_N; i++)); do
        C="$(yq eval ".agents.${agent}.allow_cidrs[$i]" "$ALLOWLIST")"
        echo "      - $(normalise_cidr "$C")"
      done
    fi

    MC="$(yq eval ".rate_limits.${agent}.max_concurrent" "$PROFILE_FILE")"
    BPS="$(yq eval ".rate_limits.${agent}.bytes_per_second" "$PROFILE_FILE")"
    echo "    limits: {max_concurrent: ${MC}, bytes_per_second: ${BPS}}"
  done <<< "$AGENTS"

  echo ""
  echo "deny_cidrs:"
  DC_N="$(yq eval '.deny_cidrs | length' "$DENYLIST")"
  for ((i = 0; i < DC_N; i++)); do
    C="$(yq eval ".deny_cidrs[$i]" "$DENYLIST")"
    echo "  - $(normalise_cidr "$C")"
  done

  DF_N="$(yq eval '.deny_fqdns | length' "$DENYLIST")"
  if [[ "$DF_N" == "0" ]]; then
    echo "deny_fqdns: []"
  else
    echo "deny_fqdns:"
    for ((i = 0; i < DF_N; i++)); do
      echo "  - $(yq eval ".deny_fqdns[$i]" "$DENYLIST")"
    done
  fi

  echo ""
  echo "# Entries present in ${REL_ALLOWLIST} and deliberately NOT granted by this profile."
  echo "# Recorded rather than dropped silently, so the decision is auditable (criterion 12)."
  EX_N="$(yq eval '.egress_exclusions | length' "$PROFILE_FILE")"
  if [[ "$EX_N" == "0" || "$EX_N" == "null" ]]; then
    echo "exclusions: []"
  else
    echo "exclusions:"
    for ((i = 0; i < EX_N; i++)); do
      EA="$(yq eval ".egress_exclusions[$i].agent" "$PROFILE_FILE")"
      EF="$(yq eval ".egress_exclusions[$i].fqdn" "$PROFILE_FILE")"
      ER="$(yq eval ".egress_exclusions[$i].reason" "$PROFILE_FILE")"
      echo "  - {agent: ${EA}, fqdn: ${EF}, reason: \"${ER}\"}"
    done
  fi

  echo ""
  echo "startup_check:"
  echo "  allowed: {agent: $(yq eval '.startup_check.allowed.agent' "$PROFILE_FILE"), fqdn: $(yq eval '.startup_check.allowed.fqdn' "$PROFILE_FILE"), port: $(yq eval '.startup_check.allowed.port' "$PROFILE_FILE")}"
  echo "  denied: {ip: $(yq eval '.startup_check.denied.ip' "$PROFILE_FILE"), port: $(yq eval '.startup_check.denied.port' "$PROFILE_FILE")}"
  echo "  offline: $(yq eval '.startup_check.offline' "$PROFILE_FILE")"
} > "$TMP"

if [[ "$MODE" == "check" ]]; then
  [[ -f "$OUT" ]] || fail "$OUT does not exist; run the compiler first"
  # compiled_at is the one line that legitimately differs between two runs of the same inputs.
  if diff -u <(grep -v '^compiled_at:' "$OUT") <(grep -v '^compiled_at:' "$TMP") > "$TMP.cmp"; then
    echo "compile-policy: $OUT is current"
    exit 0
  fi
  echo "compile-policy: FAIL: $OUT does not match a fresh compile of its inputs." >&2
  echo "compile-policy: the artifact is generated (SC-6) -- recompile rather than hand-editing it." >&2
  cat "$TMP.cmp" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
cp "$TMP" "$OUT"
# mktemp creates 0600 and `cp` carries that onto the artifact. This file is
# generated, committed and carries no secret -- and the mediator image COPYs it and
# reads it as uid 13, so a 0600 artifact produces an enforcement point that cannot
# read its own policy. Since git records only the executable bit, that failure
# appears only for whoever last ran this compiler and not for a fresh clone.
chmod 0644 "$OUT"
validate_resolved "$OUT"
echo "compile-policy: wrote $OUT"
