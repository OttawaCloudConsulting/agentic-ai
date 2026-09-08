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
#                                                       [--allowlist PATH] [--denylist PATH]
#                          --allowlist/--denylist select a different BASE. They exist for the
#                          test-scoped artifacts 01.3 SF-8 compiles (policy/allowlist.test.yaml),
#                          so fixture hostnames never enter the shipped, discovery-derived base.
#                          The artifact records whichever file it was built from in
#                          `compiled_from`, so its provenance is still readable from the artifact.
#   validate               bash scripts/compile-policy.sh --validate PATH
#                          Schema check only. This is what the mediator's stage-1 self-check
#                          calls before it renders any proxy configuration (T17).
#   check                  bash scripts/compile-policy.sh --check [--profile NAME]
#                          Recompile to a temp file and diff against the committed artifact,
#                          ignoring compiled_at. Non-zero if they differ.
#
# Exit codes (01.5 SF-2): 0 success  1 usage error  2 input validation failure
#                         3 refusal gate tripped (R4.17/T27, R2.8/T21, R7.6, SC-3)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="default"
MODE="compile"
ALLOWLIST_IN=""
DENYLIST_IN=""
OUT=""
VALIDATE_TARGET=""

# Exit codes (01.5 Interface Contract 6). The shipped 01.3 form exited 1 for everything; 2 and 3
# are added here because SF-2's gates need them -- a REFUSAL is a recorded policy decision the
# operator must make, not a syntax error, and the acceptance harness distinguishes them. Exit 1
# is retained for invocation errors only, so a mistyped flag keeps the shell-conventional code
# callers already assume. Exit 4 (--check drift) is SF-4's, with the drift check it belongs to.
#
# No caller inspects a specific value: entrypoint.sh:180 tests non-zero, verify-egress-mediator.sh
# does not invoke the compiler at all, and README.md documents an operator command.
#   1  usage / invocation error        fail()
#   2  input validation failure        invalid()
#   3  refusal gate tripped            refuse()
#   4  --check found drift             SF-4
fail()    { echo "compile-policy: FAIL: $*" >&2; exit 1; }
invalid() { echo "compile-policy: INVALID: $*" >&2; exit 2; }
refuse()  { echo "compile-policy: REFUSED: $*" >&2; exit 3; }
note()    { echo "compile-policy: $*" >&2; }

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
    --allowlist) ALLOWLIST_IN="${2:?--allowlist needs a path}"; shift 2 ;;
    --denylist)  DENYLIST_IN="${2:?--denylist needs a path}"; shift 2 ;;
    --validate) MODE="validate"; VALIDATE_TARGET="${2:?--validate needs a path}"; shift 2 ;;
    --check)    MODE="check"; shift ;;
    -h|--help)  sed -n '2,25p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)          fail "unknown argument: $1" ;;
  esac
done

command -v yq >/dev/null 2>&1 || fail "yq is required (https://github.com/mikefarah/yq)"

ALLOWLIST="${ALLOWLIST_IN:-$REPO_ROOT/policy/allowlist.base.yaml}"
DENYLIST="${DENYLIST_IN:-$REPO_ROOT/policy/denylist.base.yaml}"
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
  [[ -f "$f" ]] || invalid "$f: does not exist"
  yq eval '.' "$f" >/dev/null 2>&1 || invalid "$f: does not parse as YAML"

  local schema; schema="$(yq eval '.schema' "$f")"
  [[ "$schema" == "1" ]] || invalid "$f: field 'schema' must be 1, found '$schema'"

  # has(), not `// "null"`: yq's alternative operator treats a legitimate `false` as absent,
  # so `provisional: false` would read as a missing field.
  for field in profile compiled_at provisional pins; do
    [[ "$(yq eval "has(\"$field\")" "$f")" == "true" ]] \
      || invalid "$f: field '$field' is missing"
    local v; v="$(yq eval ".$field" "$f")"
    [[ -n "$v" ]] || invalid "$f: field '$field' is empty"
  done

  for field in allowlist denylist profile; do
    [[ "$(yq eval ".compiled_from | has(\"$field\")" "$f")" == "true" ]] \
      || invalid "$f: field 'compiled_from.$field' is missing"
  done
  [[ "$(yq eval '.compiled_from | has("packs")' "$f")" == "true" ]] \
    || invalid "$f: field 'compiled_from.packs' is missing (must be present and empty at this milestone)"

  for field in deny_cidrs deny_fqdns exclusions; do
    [[ "$(yq eval "has(\"$field\")" "$f")" == "true" ]] \
      || invalid "$f: field '$field' is missing (must be present, may be empty)"
  done

  # deny_fqdns closes R5.1's FQDN term; deny_cidrs closes its address and range terms. An
  # unmasked address here would be an ambiguous deny, so the compiler normalises and the
  # validator refuses anything it did not normalise.
  local n i
  n="$(yq eval '.deny_cidrs | length' "$f")"
  for ((i = 0; i < n; i++)); do
    local cidr; cidr="$(yq eval ".deny_cidrs[$i]" "$f")"
    [[ "$cidr" == */* ]] || invalid "$f: deny_cidrs[$i] '$cidr' has no prefix length (expected /32 or /128 for a single address)"
  done

  local agents; agents="$(yq eval '.agents | keys | .[]' "$f")"
  [[ -n "$agents" ]] || invalid "$f: field 'agents' is empty"
  while IFS= read -r agent; do
    [[ "$agent" =~ $AGENT_RE ]] \
      || invalid "$f: agent key '$agent' is not a valid identifier. It is interpolated into the mediator's Lua policy as a variable name."
    for field in identity listener_port allow_fqdns allow_cidrs limits listener; do
      [[ "$(yq eval ".agents.${agent} | has(\"$field\")" "$f")" == "true" ]] \
        || invalid "$f: agents.${agent} is missing field '$field'"
    done
    # `connections_per_minute` is deliberately NOT in this list. Squid 6.13 has no
    # per-client connection-rate directive (docs/records/mediator-selection.md, P3),
    # so the field was dropped at 01.3 SF-6 rather than shipped as a policy key that
    # silently enforces nothing. It is also refused below, so an artifact carrying it
    # fails loudly instead of implying a ceiling that does not exist.
    for field in max_concurrent bytes_per_second; do
      [[ "$(yq eval ".agents.${agent}.limits | has(\"$field\")" "$f")" == "true" ]] \
        || invalid "$f: agents.${agent}.limits.$field is missing"
      local v; v="$(yq eval ".agents.${agent}.limits.$field" "$f")"
      [[ "$v" =~ ^[0-9]+$ ]] || invalid "$f: agents.${agent}.limits.$field must be a non-negative integer, found '$v'"
    done
    [[ "$(yq eval ".agents.${agent}.limits | has(\"connections_per_minute\")" "$f")" == "false" ]] \
      || invalid "$f: agents.${agent}.limits carries 'connections_per_minute', which no longer exists. The selected proxy has no per-client connection-rate mechanism (01.3 SF-6, deviation 4); recompile from a profile that does not declare it."
    local scheme; scheme="$(yq eval ".agents.${agent}.listener.scheme" "$f")"
    [[ "$scheme" == "https" || "$scheme" == "http" ]] \
      || invalid "$f: agents.${agent}.listener.scheme must be 'https' or 'http', found '$scheme'"
    local tls; tls="$(yq eval ".agents.${agent}.listener.tls" "$f")"
    [[ "$tls" == "true" || "$tls" == "false" ]] \
      || invalid "$f: agents.${agent}.listener.tls must be true or false, found '$tls'"
    # criterion 6: the scheme and the TLS flag are two spellings of one fact and must agree.
    if [[ "$scheme" == "https" && "$tls" != "true" ]] || [[ "$scheme" == "http" && "$tls" != "false" ]]; then
      invalid "$f: agents.${agent}.listener scheme '$scheme' contradicts tls '$tls'"
    fi

    local fq_n j
    fq_n="$(yq eval ".agents.${agent}.allow_fqdns | length" "$f")"
    for ((j = 0; j < fq_n; j++)); do
      local fqdn port
      fqdn="$(yq eval ".agents.${agent}.allow_fqdns[$j].fqdn" "$f")"
      port="$(yq eval ".agents.${agent}.allow_fqdns[$j].port" "$f")"
      [[ -n "$fqdn" && "$fqdn" != "null" ]] || invalid "$f: agents.${agent}.allow_fqdns[$j] has no fqdn"
      [[ "$port" =~ ^[0-9]+$ ]] || invalid "$f: agents.${agent}.allow_fqdns[$j].port must be an integer, found '$port'"
      # The resolver is a closed forwarder and matches names exactly; a wildcard would make it
      # an open forwarder for everything under the suffix, which is the DNS exfiltration channel
      # R5.4 exists to close. Refused at compile time, not at run time.
      [[ "$fqdn" != *"*"* ]] || invalid "$f: agents.${agent}.allow_fqdns[$j].fqdn '$fqdn' is a wildcard; exact names only"
      # Not merely "non-empty": this value becomes Lua source in the enforcement
      # point, so it has to be a hostname and nothing else.
      [[ "${#fqdn}" -le 253 && "$fqdn" =~ $FQDN_RE ]] \
        || invalid "$f: agents.${agent}.allow_fqdns[$j].fqdn '$fqdn' is not a valid hostname. It is interpolated into the mediator's Lua policy, so quotes, escapes or newlines would become policy code."
      # A non-443 port is a design question, not a config detail (criterion 3).
      [[ "$port" == "443" ]] || note "WARNING: agents.${agent}.allow_fqdns[$j] '$fqdn' uses port $port, not 443 -- review before shipping"
    done
  done <<< "$agents"

  for field in allowed denied offline; do
    [[ "$(yq eval ".startup_check | has(\"$field\")" "$f")" == "true" ]] \
      || invalid "$f: startup_check.$field is missing"
  done
  local offline; offline="$(yq eval '.startup_check.offline' "$f")"
  [[ "$offline" == "true" || "$offline" == "false" ]] \
    || invalid "$f: startup_check.offline must be true or false, found '$offline'"

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
  [[ -f "$f" ]] || invalid "input not found: $f"
  yq eval '.' "$f" >/dev/null 2>&1 || invalid "$f does not parse as YAML"
done

# Relative paths in compiled_from, so the artifact says what it was built from without leaking
# the operator's directory layout into a committed file.
REL_ALLOWLIST="${ALLOWLIST#$REPO_ROOT/}"
REL_DENYLIST="${DENYLIST#$REPO_ROOT/}"
REL_PROFILE="profiles/${PROFILE}.yaml"

# --------------------------------------------------------------------------------------------
# Profile schema validation (exit 2) and the build-refusal gates (exit 3) -- 01.5 SF-2
#
# This runs on the PROFILE, before anything is emitted, and before the zero-pack refusal below:
# a profile that selects a pack must still reach the R7.6 gate, otherwise the gate is unreachable
# on exactly the input it exists to judge.
#
# The split between the two exit codes is the point of this section. A malformed profile is an
# INPUT error (2). A well-formed profile asking for something the operator has not recorded a
# decision about is a REFUSAL (3) -- the operator's job, not the author's typo.
# --------------------------------------------------------------------------------------------

# The agent set is the base allowlist's, which is what the emitted artifact is keyed by. Any
# per-agent map in the profile is checked against it rather than against a hardcoded list.
ALLOW_AGENTS="$(yq eval '.agents | keys | .[]' "$ALLOWLIST")"
[[ -n "$ALLOW_AGENTS" ]] || invalid "$REL_ALLOWLIST has no agents"

# ---- R12.7: exactly one of authorization.classify or authorization.waiver -------------------
# Shape only at this milestone. NOTHING enforces the classification: T37 is 02.5's, and that is
# recorded as a residual rather than presented as satisfying R12.7. Requiring the waiver as the
# explicit alternative is what stops the field from being quietly omitted.
[[ "$(yq eval 'has("authorization")' "$PROFILE_FILE")" == "true" ]] \
  || invalid "$REL_PROFILE: field 'authorization' is missing (R12.7). Declare either 'classify' (a non-empty list of actions requiring human authorization) or 'waiver' (a recorded reason this profile waives it)"
HAS_CLASSIFY="$(yq eval '.authorization | has("classify")' "$PROFILE_FILE")"
HAS_WAIVER="$(yq eval '.authorization | has("waiver")' "$PROFILE_FILE")"
if [[ "$HAS_CLASSIFY" == "true" && "$HAS_WAIVER" == "true" ]]; then
  invalid "$REL_PROFILE: authorization declares both 'classify' and 'waiver'; exactly one is required (R12.7). A profile that classifies actions has not waived the requirement"
elif [[ "$HAS_CLASSIFY" == "true" ]]; then
  CLASSIFY_N="$(yq eval '.authorization.classify | length' "$PROFILE_FILE")"
  [[ "$CLASSIFY_N" =~ ^[0-9]+$ ]] && ((CLASSIFY_N > 0)) \
    || invalid "$REL_PROFILE: authorization.classify is empty. An empty classification is a waiver written so it does not look like one -- declare 'waiver' instead"
  for ((i = 0; i < CLASSIFY_N; i++)); do
    v="$(yq eval ".authorization.classify[$i]" "$PROFILE_FILE")"
    [[ -n "$v" && "$v" != "null" ]] \
      || invalid "$REL_PROFILE: authorization.classify[$i] is empty"
  done
elif [[ "$HAS_WAIVER" == "true" ]]; then
  v="$(yq eval '.authorization.waiver' "$PROFILE_FILE")"
  [[ -n "$v" && "$v" != "null" ]] \
    || invalid "$REL_PROFILE: authorization.waiver is empty. R12.7 requires the waiver to be explicit AND recorded; an empty one is neither"
else
  invalid "$REL_PROFILE: authorization declares neither 'classify' nor 'waiver'; exactly one is required (R12.7)"
fi

# ---- packs: every selected name must resolve to a manifest --------------------------------
PACKS_LEN="$(yq eval '.packs | length' "$PROFILE_FILE")"
[[ "$PACKS_LEN" =~ ^[0-9]+$ ]] \
  || invalid "$REL_PROFILE: field 'packs' is missing or is not a list (declare 'packs: []' where a profile selects none)"
PACK_FILES=()
PACK_NAMES=()
for ((i = 0; i < PACKS_LEN; i++)); do
  PN="$(yq eval ".packs[$i]" "$PROFILE_FILE")"
  # The name becomes a directory path. Constrained at the boundary for the same reason the
  # hostnames are: it is third-party-supplied content that this script turns into a file read.
  [[ "$PN" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] \
    || invalid "$REL_PROFILE: packs[$i] '$PN' is not a valid pack name (lowercase letters, digits and hyphens); it is resolved as a directory under packs/"
  [[ -f "$REPO_ROOT/packs/$PN/pack.yaml" ]] \
    || invalid "$REL_PROFILE: packs[$i] '$PN' does not resolve to packs/$PN/pack.yaml"
  yq eval '.' "$REPO_ROOT/packs/$PN/pack.yaml" >/dev/null 2>&1 \
    || invalid "packs/$PN/pack.yaml does not parse as YAML"
  PACK_FILES+=("$REPO_ROOT/packs/$PN/pack.yaml")
  PACK_NAMES+=("$PN")
done

# ---- R7.18: package_repository, required only where packs are selected ---------------------
# A snapshot, NOT a suite. `suite: bookworm` plus name=version resolves today and fails in six
# months -- Debian rotates the archive and drops superseded versions, and SC-8 measures exactly
# the clean rebuild that happens later. The timestamped path is what makes the pin stable in
# time, so its shape is asserted rather than assumed from the operator's intent.
if ((PACKS_LEN > 0)); then
  [[ "$(yq eval 'has("package_repository")' "$PROFILE_FILE")" == "true" ]] \
    || invalid "$REL_PROFILE: field 'package_repository' is missing, but the profile selects $PACKS_LEN pack(s) whose apt items are sourced from it (R7.18)"
  for field in url suite signed_by fingerprint; do
    v="$(yq eval ".package_repository.apt.$field // \"\"" "$PROFILE_FILE")"
    [[ -n "$v" ]] || invalid "$REL_PROFILE: field 'package_repository.apt.$field' is missing or empty (R7.18)"
  done
  REPO_URL="$(yq eval '.package_repository.apt.url' "$PROFILE_FILE")"
  [[ "$REPO_URL" == https://* ]] \
    || invalid "$REL_PROFILE: package_repository.apt.url '$REPO_URL' is not https"
  [[ "$REPO_URL" =~ /[0-9]{8}T[0-9]{6}Z/?$ ]] \
    || invalid "$REL_PROFILE: package_repository.apt.url '$REPO_URL' carries no snapshot timestamp. A suite URL resolves today and fails on the clean rebuild SC-8 measures (Edge Case 8) -- use a snapshot.debian.org archive path ending in <YYYYMMDD>T<HHMMSS>Z"
  REPO_FPR="$(yq eval '.package_repository.apt.fingerprint' "$PROFILE_FILE")"
  [[ "$REPO_FPR" =~ ^[0-9A-F]{40}$ ]] \
    || invalid "$REL_PROFILE: package_repository.apt.fingerprint must be a full 40-character uppercase hex key fingerprint, found '$REPO_FPR'. A short id is forgeable and a key substitution is exactly what this asserts against"
fi

# ---- mounts: shape (exit 2) then the R2.8 key allowlist (exit 3, GATE) ----------------------
[[ "$(yq eval 'has("mounts")' "$PROFILE_FILE")" == "true" ]] \
  || invalid "$REL_PROFILE: field 'mounts' is missing (declare at least mounts.project)"
for field in path mode; do
  v="$(yq eval ".mounts.project.$field // \"\"" "$PROFILE_FILE")"
  [[ -n "$v" ]] || invalid "$REL_PROFILE: field 'mounts.project.$field' is missing or empty"
done
PROJECT_MODE="$(yq eval '.mounts.project.mode' "$PROFILE_FILE")"
[[ "$PROJECT_MODE" == "rw" || "$PROJECT_MODE" == "ro" ]] \
  || invalid "$REL_PROFILE: mounts.project.mode must be 'rw' or 'ro' (R2.3, R2.7), found '$PROJECT_MODE'"

# R2.10: false | true | a per-agent map. A SINGLE SHARED cache is not expressible in this schema,
# which is how the cross-agent write channel is closed -- by the shape, not by a check on a value.
BC_TAG="$(yq eval '.mounts.build_cache | tag' "$PROFILE_FILE")"
case "$BC_TAG" in
  '!!bool') : ;;
  '!!map')
    BC_KEYS="$(yq eval '.mounts.build_cache | keys | .[]' "$PROFILE_FILE")"
    [[ -n "$BC_KEYS" ]] || invalid "$REL_PROFILE: mounts.build_cache is an empty map; use false to disable it for every agent"
    while IFS= read -r bca; do
      grep -qx "$bca" <<< "$ALLOW_AGENTS" \
        || invalid "$REL_PROFILE: mounts.build_cache names agent '$bca', which is not an agent in $REL_ALLOWLIST"
      bcv="$(yq eval ".mounts.build_cache.${bca}" "$PROFILE_FILE")"
      [[ "$bcv" == "true" || "$bcv" == "false" ]] \
        || invalid "$REL_PROFILE: mounts.build_cache.${bca} must be true or false, found '$bcv'"
    done <<< "$BC_KEYS"
    ;;
  *) invalid "$REL_PROFILE: mounts.build_cache must be true, false or a per-agent map of booleans (R2.10), found a $BC_TAG" ;;
esac

# GATE (R2.8, T21) -- the mount key set is CLOSED and fails closed. A profile asking for
# `ssh_auth_sock: true` that is silently ignored is indistinguishable from one correctly
# refused, right up to the day the key is implemented. That is how R2.8 gets defeated in
# practice, so an unrecognised key is a refusal and never a warning.
#
# The set is R2's enumeration, not this compiler's invention: the project directory (R2.1),
# the build cache (R2.10) and the host git config (R2.9). The per-agent state volumes are not
# optional and are not declared here. The oauth-mount credential source is deliberately absent:
# it is declared under `oauth_mount` and mounted only by a one-shot bootstrap (R4.15).
MOUNT_KEYS="$(yq eval '.mounts | keys | .[]' "$PROFILE_FILE")"
while IFS= read -r mk; do
  case "$mk" in
    project|build_cache|host_git_config) : ;;
    *) refuse "$REL_PROFILE: mounts.$mk is not a mount this system offers. Only mounts enumerated in R2 are available to enable -- project, build_cache, host_git_config -- and forwarded sockets are not among them (R2.8, T21). Remove the key; it is refused rather than ignored, because an ignored key looks identical to a refused one until the day it is implemented" ;;
  esac
done <<< "$MOUNT_KEYS"

# ---- GATE (R4.17, T27) -- oauth-mount without a recorded accepted-risk decision -------------
# The same five fields scripts/stage-oauth-mount.sh validates host-side at bootstrap, so the
# build-time and bootstrap-time refusals agree rather than each enforcing half a record.
# 01.4's bootstrap-auth.sh exits 3 for the same condition; T27 requires the refusal at BUILD.
#
# `rotation` must carry 01.4 SF-3's MEASURED per-provider result (Edge Case 7). That is not
# mechanically checkable from here -- non-empty is what this enforces, and saying so is better
# than implying the compiler verified the measurement.
AUTH_AGENTS="$(yq eval '.auth_mode | keys | .[]' "$PROFILE_FILE")"
[[ -n "$AUTH_AGENTS" ]] || invalid "$REL_PROFILE: field 'auth_mode' is empty"
while IFS= read -r aa; do
  [[ "$(yq eval ".auth_mode.${aa}" "$PROFILE_FILE")" == "oauth-mount" ]] || continue
  [[ "$(yq eval ".oauth_mount.${aa} | has(\"accepted_risk\")" "$PROFILE_FILE")" == "true" ]] \
    || refuse "$REL_PROFILE: auth_mode.${aa} is 'oauth-mount' but oauth_mount.${aa}.accepted_risk is absent. R4.17 requires the decision to be RECORDED before the credential crosses the boundary: file, mount_mode, revocation_path, blast_radius and rotation"
  for field in file mount_mode revocation_path blast_radius rotation; do
    v="$(yq eval ".oauth_mount.${aa}.accepted_risk.$field // \"\"" "$PROFILE_FILE")"
    [[ -n "$v" ]] \
      || refuse "$REL_PROFILE: oauth_mount.${aa}.accepted_risk.$field is missing or empty (R4.17, T27)"
  done
  MM="$(yq eval ".oauth_mount.${aa}.accepted_risk.mount_mode" "$PROFILE_FILE")"
  [[ "$MM" == "ro" ]] \
    || refuse "$REL_PROFILE: oauth_mount.${aa}.accepted_risk.mount_mode is '$MM'; 'ro' is the only permitted value (R4.13). The bootstrap fragment mounts :ro regardless, so a profile claiming otherwise records a risk the system does not take"
done <<< "$AUTH_AGENTS"

# ---- GATE (R7.6, T31) -- a pack claiming runtime egress without declaring runtime install ---
# Runtime installation requires package-registry egress, which widens the boundary. It is off by
# default and explicitly declared where used -- and "explicitly" means both halves: the flag and
# a recorded reason. The two must also agree in the other direction: `runtime_install: true` with
# no runtime egress declares a widening that the policy does not actually carry.
#
# `runtime_install` is re-checked for shape here rather than trusted from lint-policy.sh. A pack
# manifest is third-party content and this is the enforcement point the build passes through.
for ((i = 0; i < PACKS_LEN; i++)); do
  PF="${PACK_FILES[$i]}"; PN="${PACK_NAMES[$i]}"
  RI="$(yq eval '.runtime_install' "$PF")"
  [[ "$RI" == "true" || "$RI" == "false" ]] \
    || invalid "packs/$PN/pack.yaml: field 'runtime_install' must be true or false, found '$RI' (R7.6)"
  RT_N=$(( $(yq eval '.egress.runtime.allow_fqdns | length' "$PF") + $(yq eval '.egress.runtime.allow_cidrs | length' "$PF") ))
  if [[ "$RI" == "false" ]] && ((RT_N > 0)); then
    refuse "packs/$PN/pack.yaml declares $RT_N runtime egress entr(y|ies) with runtime_install: false. Runtime egress to a package registry is what makes runtime installation possible, so R7.6 requires it declared: set runtime_install: true WITH runtime_install_reason, or remove the entries. Note that registry egress also re-enables arbitrary 'npx <server>' and breaks T31 on every profile loading this pack"
  fi
  if [[ "$RI" == "true" ]]; then
    RIR="$(yq eval '.runtime_install_reason // ""' "$PF")"
    [[ -n "$RIR" ]] \
      || refuse "packs/$PN/pack.yaml sets runtime_install: true without 'runtime_install_reason'. R7.6 requires the exception to be explicitly declared, and a flag with no recorded reason is a default flipped rather than a decision taken"
    ((RT_N > 0)) \
      || refuse "packs/$PN/pack.yaml sets runtime_install: true but declares no egress.runtime entries. Runtime installation without registry egress cannot work, so this records a widening the resolved policy does not carry -- declare the registries or set runtime_install: false"
  fi
done

# ---- GATE (SC-3, R5.14) -- project-mount containment ----------------------------------------
# An agent whose project mount contains the solution tree can rewrite allowlist.base.yaml,
# mediator/config/*.tmpl or this script, and widen its own policy at the next build. That threat
# is sharper in this feature than in 01.3, because those same files are now BUILD INPUTS.
#
# LEXICAL, NOT `realpath`. Edge Case 18 puts this gate host-side on the grounds that a build
# stage cannot resolve a host path -- and that is true of `realpath`, so the check is written to
# need it: an absolute path is compared lexically against the solution root and the gate behaves
# identically in the compile stage and on the host. What it therefore CANNOT catch is a symlink
# or a relative path resolving into the tree.
#
# LIMIT, STATED. Every shipped profile carries the literal placeholder `<host path>` here and the
# real bind comes from compose/overrides/<profile>.yaml, so on today's profiles this gate has no
# absolute path to judge and warns instead. The mount that actually exists is asserted at test
# time against `docker inspect` on the running container (SF-7 Phase A, extending 01.3's
# control-plane assertion). Recorded rather than presented as full coverage of SC-3.
PROJECT_PATH="$(yq eval '.mounts.project.path' "$PROFILE_FILE")"
if [[ "$PROJECT_PATH" == /* ]]; then
  PP="${PROJECT_PATH%/}"; ROOT="${REPO_ROOT%/}"
  [[ "$PP" != "$ROOT" ]] \
    || refuse "$REL_PROFILE: mounts.project.path is the solution root ($ROOT). That mounts the policy files, the mediator configuration and the identity material inside the agent's own project mount, so the agent can widen its policy at the next build (SC-3, R5.14). Use a sibling directory"
  [[ "$ROOT/" != "$PP"/* ]] \
    || refuse "$REL_PROFILE: mounts.project.path '$PP' is an ancestor of the solution root ($ROOT), so the whole control plane is inside the agent's project mount (SC-3, R5.14). Use a sibling directory -- D19's copied sandbox tree is a SIBLING of the project directory, never a parent of this one"
  if [[ "$PP/" == "$ROOT"/* ]]; then
    REL_PP="${PP#$ROOT/}"
    case "${REL_PP%%/*}" in
      policy|packs|profiles|compose|images|mediator|scripts|.dockerignore)
        refuse "$REL_PROFILE: mounts.project.path '$PP' exposes the control-plane directory '${REL_PP%%/*}' to the agent. These are the compiler's own inputs and the mediator's configuration; an agent that can rewrite them widens its policy at the next build (SC-3, R5.14)" ;;
    esac
  fi
else
  note "NOTE: $REL_PROFILE mounts.project.path is '$PROJECT_PATH', not an absolute path -- the SC-3 containment gate has nothing to resolve and did not run. The mount that actually exists is asserted against the running container (SF-7)."
fi

# ---- zero-pack refusal, LAST -----------------------------------------------------------------
# Deliberately after the gates: a profile selecting a pack must still be judged by them, or the
# R7.6 gate is unreachable on the only input it exists for. Composition itself is SF-3's.
[[ "$PACKS_LEN" == "0" ]] \
  || invalid "$REL_PROFILE declares $PACKS_LEN pack(s); pack COMPOSITION is 01.5 SF-3's and is not built yet. The schema, the manifest resolution and the refusal gates above accept a populated list already"

PROVISIONAL="$(yq eval '.provisional' "$ALLOWLIST")"
PINS="$(yq eval '.pins' "$ALLOWLIST")"
COMPILED_AT="${COMPILED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

# The artifact's own header tells an operator how to re-verify THIS artifact, which for a
# test-scoped one means repeating the bases and the profile. A header naming the default
# invocation would be a check that silently verifies a different file.
CHECK_HINT=""
[[ "$PROFILE" == "default" ]] || CHECK_HINT=" --profile ${PROFILE}"
[[ -z "$ALLOWLIST_IN" ]] || CHECK_HINT="${CHECK_HINT} --allowlist ${REL_ALLOWLIST}"
[[ -z "$DENYLIST_IN" ]]  || CHECK_HINT="${CHECK_HINT} --denylist ${REL_DENYLIST}"

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
  echo "# Edit ${REL_ALLOWLIST}, ${REL_DENYLIST} or ${REL_PROFILE}, then recompile."
  echo "# Verify with: bash scripts/compile-policy.sh --check${CHECK_HINT}"
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
      || invalid "$REL_ALLOWLIST: agent key '$agent' is not a valid identifier; it becomes a Lua variable name in the mediator's policy"
    # has(), not `// "null"`: `tls: false` is the codex listener's correct value and yq's
    # alternative operator would report it as absent.
    for k in scheme tls port; do
      [[ "$(yq eval ".listeners.${agent} | has(\"$k\")" "$PROFILE_FILE")" == "true" ]] \
        || invalid "$REL_PROFILE has no listeners.${agent}.${k}"
    done
    LISTENER_SCHEME="$(yq eval ".listeners.${agent}.scheme" "$PROFILE_FILE")"
    LISTENER_TLS="$(yq eval ".listeners.${agent}.tls" "$PROFILE_FILE")"
    LISTENER_PORT="$(yq eval ".listeners.${agent}.port" "$PROFILE_FILE")"

    for k in max_concurrent bytes_per_second; do
      [[ "$(yq eval ".rate_limits.${agent} | has(\"$k\")" "$PROFILE_FILE")" == "true" ]] \
        || invalid "$REL_PROFILE has no rate_limits.${agent}.${k}"
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
        || invalid "$REL_ALLOWLIST: agents.${agent}.allow_fqdns[$i].fqdn '$FQDN' is a wildcard; the pod resolver matches exactly and a wildcard would reopen DNS exfiltration (R5.4)"
      [[ "${#FQDN}" -le 253 && "$FQDN" =~ $FQDN_RE ]] \
        || invalid "$REL_ALLOWLIST: agents.${agent}.allow_fqdns[$i].fqdn '$FQDN' is not a valid hostname; it would be interpolated into the mediator's Lua policy (01.3 SF-5)"
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
