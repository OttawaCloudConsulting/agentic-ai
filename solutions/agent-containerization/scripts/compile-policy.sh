#!/usr/bin/env bash
# Policy compiler (01.3 SF-2; pack composition added at 01.5 SF-3).
#
# Reads policy/allowlist.base.yaml, policy/denylist.base.yaml and profiles/<profile>.yaml and
# emits policy/resolved/<profile>.yaml -- the committed SC-6 artifact the mediator loads. The
# artifact is GENERATED and never hand-edited; `--check` is what enforces that.
#
# 01.5 moves this invocation into a build stage of the mediator image (D10) -- still SF-4's --
# and adds pack composition, which is SF-3's and is BUILT. The schema emitted here is what it must
# continue to emit: 01.3 Interface Contract 1 is unchanged, and pack composition populates exactly
# two things inside it -- `compiled_from.packs`, and the per-agent `allow_fqdns`/`allow_cidrs`.
#
# Every emitted list is LC_ALL=C sorted and deduplicated. That is not tidiness: SF-4's drift check
# is a BYTE comparison against the committed artifact, and an emitter whose output depends on the
# order its inputs happened to be written in makes that check fire on identical policy
# (Edge Case 2). The host is macOS and the compile stage is Debian, so the collation is pinned too.
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
#                         3 refusal gate tripped (R4.17/T27, R2.8/T21, R7.6, SC-3, and at SF-3
#                           a pack's unconsumable mounts/env/credentials, and an upgrade collision)
#                         4 --check found drift (01.5 SF-4)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="default"
MODE="compile"
ALLOWLIST_IN=""
DENYLIST_IN=""
OUT=""
VALIDATE_TARGET=""
PROFILE_FILE_IN=""

# Exit codes (01.5 Interface Contract 6). The shipped 01.3 form exited 1 for everything; 2 and 3
# are added here because SF-2's gates need them -- a REFUSAL is a recorded policy decision the
# operator must make, not a syntax error, and the acceptance harness distinguishes them. Exit 1
# is retained for invocation errors only, so a mistyped flag keeps the shell-conventional code
# callers already assume. Exit 4 is added at SF-4, with the drift check it belongs to: a build
# stage compiles authoritatively and refuses to produce an image whose committed artifact does
# not match, so `--check` needs a code the build can tell apart from a mistyped flag.
#
# No caller inspects a specific value: entrypoint.sh:180 tests non-zero, verify-egress-mediator.sh
# does not invoke the compiler at all, and README.md documents an operator command.
#   1  usage / invocation error        fail()
#   2  input validation failure        invalid()
#   3  refusal gate tripped            refuse()
#   4  --check found drift             drift()
#
# A MISSING committed artifact under --check also exits 4, not 1. It is not a usage error --
# the invocation is well formed -- and the condition the caller cares about is the same one:
# the committed artifact does not match a fresh compile of its inputs. Absent is the limiting
# case of different, and the drift stage of images/mediator/Dockerfile must fail on it.
fail()    { echo "compile-policy: FAIL: $*" >&2; exit 1; }
invalid() { echo "compile-policy: INVALID: $*" >&2; exit 2; }
refuse()  { echo "compile-policy: REFUSED: $*" >&2; exit 3; }
drift()   { echo "compile-policy: DRIFT: $*" >&2; exit 4; }
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
# Pack name: resolved as a DIRECTORY under packs/, and echoed into the artifact's provenance
# record. Constrained at both ends -- the producer (profile `packs:`) and the consumer
# (validate_resolved reading compiled_from.packs), because 01.5 makes that field a channel from
# third-party content into the mediator's render.
PACK_RE='^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)  PROFILE="${2:?--profile needs a value}"; shift 2 ;;
    # 02.1 SF-4 (Decision 7 trigger, docs/records/agent-action-log.md "Compiler
    # measurement"): --profile compiles profiles/<name>.yaml only. T36's harness
    # compiles four scratch variants under .build-scratch/t36/, outside profiles/,
    # so this reads the PROFILE FILE from an explicit path while --profile still
    # names the artifact ('profile:' field, default OUT path). Not a general
    # profile-directory feature -- the one caller this exists for is named above.
    --profile-file) PROFILE_FILE_IN="${2:?--profile-file needs a path}"; shift 2 ;;
    --out)      OUT="${2:?--out needs a value}"; shift 2 ;;
    --allowlist) ALLOWLIST_IN="${2:?--allowlist needs a path}"; shift 2 ;;
    --denylist)  DENYLIST_IN="${2:?--denylist needs a path}"; shift 2 ;;
    --validate) MODE="validate"; VALIDATE_TARGET="${2:?--validate needs a path}"; shift 2 ;;
    --check)    MODE="check"; shift ;;
    -h|--help)  sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)          fail "unknown argument: $1" ;;
  esac
done

command -v yq >/dev/null 2>&1 || fail "yq is required (https://github.com/mikefarah/yq)"

ALLOWLIST="${ALLOWLIST_IN:-$REPO_ROOT/policy/allowlist.base.yaml}"
DENYLIST="${DENYLIST_IN:-$REPO_ROOT/policy/denylist.base.yaml}"
PROFILE_FILE="${PROFILE_FILE_IN:-$REPO_ROOT/profiles/${PROFILE}.yaml}"
RESOLVED_DIR="$REPO_ROOT/policy/resolved"
[[ -n "$OUT" ]] || OUT="$RESOLVED_DIR/${PROFILE}.yaml"

# --------------------------------------------------------------------------------------------
# Shared helpers.
#
# These sit ABOVE validate_resolved rather than beside the gates that first needed them, because
# --validate exits before the gate section is ever reached: a helper defined below it would be an
# unbound command in exactly the path the mediator calls at stage 1 (T17). Moved here at 01.5 SF-3,
# when validate_resolved began using require_tag for compiled_from.packs.
# --------------------------------------------------------------------------------------------

# scalar_nonblank -- "is this field actually RECORDED?", not "does yq print something".
# yq renders an empty collection as the two-character strings `[]` and `{}`, so a `-n` test on
# `yq eval .field` accepts `file: []` as a filled-in field. Every gate below asks whether an
# OPERATOR WROTE SOMETHING, and an empty list satisfying R4.17's accepted-risk record is exactly
# the hollow record the requirement exists to prevent. So the tag is checked, not the rendering.
# Found by the Codex adversarial pass, 2026-09-08.
scalar_nonblank() {
  local f="$1" path="$2" tag v
  tag="$(yq eval "$path | tag" "$f" 2>/dev/null)" || return 1
  case "$tag" in
    '!!str'|'!!int'|'!!float'|'!!bool') : ;;
    *) return 1 ;;
  esac
  v="$(yq eval "$path" "$f")"
  [[ -n "${v//[[:space:]]/}" ]] || return 1
  printf '%s' "$v"
}

# lower -- DNS names are case-insensitive, so the collision key is case-folded before entries from
# the base and from a pack are compared. `${v,,}` would be shorter and is what this first used, but
# it is a bash-4 parameter expansion and stock macOS /bin/bash is 3.2 -- and README.md tells a
# fresh-clone operator to run this compiler on the host directly. `tr` costs a subprocess per entry
# and works everywhere this script is invoked.
lower() { tr '[:upper:]' '[:lower:]' <<< "$1"; }

# require_tag -- a `yq | keys` or `| has()` call on the wrong node type is a RAW yq failure under
# `set -e`: exit 1 with yq's own message, which is the usage code, and the invalid() handler that
# was meant to catch it never runs. Every structural traversal below is guarded first.
require_tag() {
  local f="$1" path="$2" want="$3" msg="$4" tag
  tag="$(yq eval "$path | tag" "$f" 2>/dev/null)" || tag="(unreadable)"
  [[ "$tag" == "$want" ]] || invalid "$msg (found $tag)"
}

# normalise_abs -- collapse `//`, `/./` and `/x/../` LEXICALLY. No realpath: the gate below must
# behave identically inside the compile stage, which cannot see the host filesystem. Without this
# `<root>/./policy` and `<root>/../<root-name>/policy` are different strings from `<root>/policy`
# and walk straight past a string comparison. Found by the Codex adversarial pass, 2026-09-08.
# What it still cannot see is a SYMLINK -- that needs the filesystem, and is asserted at SF-7.
normalise_abs() {
  local p="$1" out=() seg
  # The IFS split below drops empty segments, so `//` collapses without a separate pass.
  local IFS='/'
  for seg in $p; do
    case "$seg" in
      ''|'.') : ;;
      '..') [[ "${#out[@]}" -eq 0 ]] || unset 'out[${#out[@]}-1]' ;;
      *) out+=("$seg") ;;
    esac
  done
  printf '/%s' "${out[*]}"
}

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
  # `packs` is present at every milestone and populated from 01.5 SF-3 onward. It is the
  # artifact's provenance record: a reviewer reading a resolved file must be able to tell that it
  # was compiled from THESE manifests and not from a later edit of one, which is what the
  # per-entry sha256 carries. Shape is checked here because this validator is what the mediator
  # calls at stage 1 (T17), and pack composition makes the artifact a channel from third-party
  # content into that render.
  [[ "$(yq eval '.compiled_from | has("packs")' "$f")" == "true" ]] \
    || invalid "$f: field 'compiled_from.packs' is missing (must be present, may be empty)"
  require_tag "$f" '.compiled_from.packs' '!!seq' \
    "$f: field 'compiled_from.packs' must be a list"
  local pn i
  pn="$(yq eval '.compiled_from.packs | length' "$f")"
  for ((i = 0; i < pn; i++)); do
    local pname ppath psha
    # The TAG, not the rendering. `name: null` renders as the four characters "null", which
    # PACK_RE matches quite happily -- so a provenance entry carrying YAML's null passes a check
    # written against printed text. The same failure shape the SF-2 pass found four times.
    local pfield ptag
    for pfield in name path sha256; do
      ptag="$(yq eval ".compiled_from.packs[$i].$pfield | tag" "$f" 2>/dev/null || echo '(unreadable)')"
      [[ "$ptag" == "!!str" ]] \
        || invalid "$f: compiled_from.packs[$i].$pfield must be a string (found $ptag)"
    done
    pname="$(yq eval ".compiled_from.packs[$i].name" "$f")"
    ppath="$(yq eval ".compiled_from.packs[$i].path" "$f")"
    psha="$(yq eval ".compiled_from.packs[$i].sha256" "$f")"
    [[ "$pname" =~ $PACK_RE ]] \
      || invalid "$f: compiled_from.packs[$i].name '$pname' is not a valid pack name (lowercase letters, digits and hyphens)"
    [[ "$ppath" == "packs/${pname}/pack.yaml" ]] \
      || invalid "$f: compiled_from.packs[$i].path '$ppath' must be 'packs/${pname}/pack.yaml'"
    [[ "$psha" =~ ^[0-9a-f]{64}$ ]] \
      || invalid "$f: compiled_from.packs[$i].sha256 '$psha' is not a 64-character lowercase hex digest"
  done

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
    # 01.6 SF-2. Checked HERE as well as on the profile side because this validator is what the
    # mediator's startup self-check runs against the artifact it is about to enforce (stage 1,
    # T17) -- an artifact compiled before this key existed would otherwise render a listener with
    # no client authentication and an audit line that could not say so.
    local client_auth; client_auth="$(yq eval ".agents.${agent}.listener.client_auth" "$f")"
    case "$client_auth" in
      mtls|proxy_auth|none) : ;;
      *) invalid "$f: agents.${agent}.listener.client_auth must be one of mtls, proxy_auth or none, found '$client_auth'. It is required, not defaulted: recompile from a profile that declares it." ;;
    esac
    [[ "$client_auth" != "mtls" || "$tls" == "true" ]] \
      || invalid "$f: agents.${agent}.listener.client_auth is 'mtls' but tls is '$tls'. A client certificate can only be requested on a TLS listener."

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
      # RFC 6761 special-use TLDs. `unbound` -- the re-originating stage -- carries built-in local
      # zones for these names, answers them ITSELF and never forwards them, whatever the policy
      # says. Such an entry compiles, is audited as `allow`, and still never resolves: every
      # surface reports success and the only signal is the absent answer. Measured at 01.3 SF-8
      # (docs/records/resolver-verification.md, addendum), where the harness fixtures had to move
      # off `.test` for exactly this reason. A WARNING, not a refusal -- the operator may run a
      # local resolver that does serve one. Assigned here by the Gate 2 refresh because this is
      # where the allowlist is validated.
      case "$(tr '[:upper:]' '[:lower:]' <<< "$fqdn")" in
        *.test|*.invalid|*.localhost|*.example|test|invalid|localhost|example)
          note "WARNING: agents.${agent}.allow_fqdns[$j] '$fqdn' is under an RFC 6761 special-use TLD. The pod resolver answers these names itself and never forwards them, so this entry will be audited as allowed and will still not resolve (docs/records/resolver-verification.md, addendum)" ;;
      esac
    done

    # A CIDR allow entry has no name for the SNI equality control to compare a ClientHello
    # against, so the shipped mediator render REFUSES a non-empty list at start rather than
    # punching through control 1b (images/mediator/entrypoint.sh). The field is emitted here --
    # Interface Contract 3 composes pack-supplied entries into it -- and the refusal stays on the
    # consumer side, which is where 01.3 deliberately put it. Warning rather than refusal keeps
    # one behaviour for one field: base-supplied CIDRs have never been refused at compile either.
    local nc; nc="$(yq eval ".agents.${agent}.allow_cidrs | length" "$f")"
    [[ "$nc" == "0" ]] \
      || note "WARNING: agents.${agent}.allow_cidrs has $nc entr(y|ies). The shipped mediator render implements hostname allowlisting only and REFUSES a non-empty list at start (control 1b). This artifact will not load until that render is deliberately extended -- express the destination as an allow_fqdns entry, or extend the render"
  done <<< "$agents"

  for field in allowed denied offline; do
    [[ "$(yq eval ".startup_check | has(\"$field\")" "$f")" == "true" ]] \
      || invalid "$f: startup_check.$field is missing"
  done
  local offline; offline="$(yq eval '.startup_check.offline' "$f")"
  [[ "$offline" == "true" || "$offline" == "false" ]] \
    || invalid "$f: startup_check.offline must be true or false, found '$offline'"

  # 02.1 SF-4: required, exactly the four keys. A resolved artifact compiled before this key
  # existed must fail --validate loudly (T17's path) rather than let the mediator or a recorder
  # assume a default the artifact never recorded.
  [[ "$(yq eval 'has("exports")' "$f")" == "true" ]] \
    || invalid "$f: field 'exports' is missing (R9.9). Recompile with scripts/compile-policy.sh"
  require_tag "$f" '.exports' '!!map' "$f: field 'exports' must be a mapping"
  local export_keys="egress_audit_log agent_action_log resolved_policy image_digest_sbom"
  local ek
  for ek in $export_keys; do
    [[ "$(yq eval ".exports | has(\"$ek\")" "$f")" == "true" ]] \
      || invalid "$f: field 'exports.$ek' is missing"
    local ev; ev="$(yq eval ".exports.$ek" "$f")"
    [[ "$ev" == "true" || "$ev" == "false" ]] \
      || invalid "$f: field 'exports.$ek' must be true or false, found '$ev'"
  done
  local export_count; export_count="$(yq eval '.exports | keys | length' "$f")"
  [[ "$export_count" == "4" ]] \
    || invalid "$f: field 'exports' must carry exactly the four keys ($export_keys), found $export_count"

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
REL_PROFILE="${PROFILE_FILE_IN:-profiles/${PROFILE}.yaml}"

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
require_tag "$PROFILE_FILE" '.authorization' '!!map' \
  "$REL_PROFILE: field 'authorization' must be a mapping declaring 'classify' or 'waiver' (R12.7)"
HAS_CLASSIFY="$(yq eval '.authorization | has("classify")' "$PROFILE_FILE")"
HAS_WAIVER="$(yq eval '.authorization | has("waiver")' "$PROFILE_FILE")"
if [[ "$HAS_CLASSIFY" == "true" && "$HAS_WAIVER" == "true" ]]; then
  invalid "$REL_PROFILE: authorization declares both 'classify' and 'waiver'; exactly one is required (R12.7). A profile that classifies actions has not waived the requirement"
elif [[ "$HAS_CLASSIFY" == "true" ]]; then
  require_tag "$PROFILE_FILE" '.authorization.classify' '!!seq' \
    "$REL_PROFILE: authorization.classify must be a list of actions (R12.7)"
  CLASSIFY_N="$(yq eval '.authorization.classify | length' "$PROFILE_FILE")"
  [[ "$CLASSIFY_N" =~ ^[0-9]+$ ]] && ((CLASSIFY_N > 0)) \
    || invalid "$REL_PROFILE: authorization.classify is empty. An empty classification is a waiver written so it does not look like one -- declare 'waiver' instead"
  for ((i = 0; i < CLASSIFY_N; i++)); do
    scalar_nonblank "$PROFILE_FILE" ".authorization.classify[$i]" >/dev/null \
      || invalid "$REL_PROFILE: authorization.classify[$i] is empty or is not a scalar"
  done
elif [[ "$HAS_WAIVER" == "true" ]]; then
  scalar_nonblank "$PROFILE_FILE" '.authorization.waiver' >/dev/null \
    || invalid "$REL_PROFILE: authorization.waiver is empty. R12.7 requires the waiver to be explicit AND recorded; an empty one is neither"
else
  invalid "$REL_PROFILE: authorization declares neither 'classify' nor 'waiver'; exactly one is required (R12.7)"
fi

# ---- egress_exclusions: shape, before anything reads it -------------------------------------
# A profile that writes this as a MAP instead of a list is the worst case in the file, because it
# fails SILENTLY in the direction that grants access: `.egress_exclusions[]` iterates a map's
# VALUES, the per-entry select matches nothing, and every exclusion lapses -- including the R10.3
# auto-updater exclusion the default profile carries. The compile then dies much later with
# "startup_check.offline must be true or false, found 'null'", which names neither the field nor
# the cause. Optional, because a profile may legitimately exclude nothing; shape-checked whenever
# present. Found by the Codex adversarial pass, 2026-09-08.
if [[ "$(yq eval 'has("egress_exclusions")' "$PROFILE_FILE")" == "true" ]]; then
  require_tag "$PROFILE_FILE" '.egress_exclusions' '!!seq' \
    "$REL_PROFILE: field 'egress_exclusions' must be a list of {agent, fqdn, reason} entries"
  EXC_N="$(yq eval '.egress_exclusions | length' "$PROFILE_FILE")"
  for ((i = 0; i < EXC_N; i++)); do
    require_tag "$PROFILE_FILE" ".egress_exclusions[$i]" '!!map' \
      "$REL_PROFILE: egress_exclusions[$i] must be a map with agent, fqdn and reason"
    for EK in agent fqdn reason; do
      scalar_nonblank "$PROFILE_FILE" ".egress_exclusions[$i].$EK" >/dev/null \
        || invalid "$REL_PROFILE: egress_exclusions[$i].$EK is missing, empty or not a scalar. An exclusion withdraws a destination the base allowlist grants, so all three -- who, what and why -- are required (criterion 12, R10.3)"
    done
    EXC_A="$(yq eval ".egress_exclusions[$i].agent" "$PROFILE_FILE")"
    grep -Fxq "$EXC_A" <<< "$ALLOW_AGENTS" \
      || invalid "$REL_PROFILE: egress_exclusions[$i].agent '$EXC_A' is not an agent the base allowlist keys. An exclusion naming an agent that does not exist withdraws nothing and reads as though it did"
  done
fi

# ---- mcp: R7.14 inventory, R7.16 registry gate, T30 transport/enforcement_point pairing ------
# 02.3 SF-6, Interface Contract 5. The block is REQUIRED and explicit on every profile -- an
# absent `mcp:` is an input error (exit 2), the same posture as `exports` (02.1 SF-4): a resolved
# artifact says nothing was omitted, not that MCP was never considered. `servers`, `plugins` and
# `skills` default to an empty list only in the sense that an empty list IS the explicit "none";
# the key itself is never optional.
[[ "$(yq eval 'has("mcp")' "$PROFILE_FILE")" == "true" ]] \
  || invalid "$REL_PROFILE: field 'mcp' is missing (R7.14). Every profile carries an explicit mcp: block -- 'registry: none, servers: [], plugins: [], skills: []' if it inventories nothing"
require_tag "$PROFILE_FILE" '.mcp' '!!map' "$REL_PROFILE: field 'mcp' must be a mapping"
for MK in registry servers plugins skills; do
  [[ "$(yq eval ".mcp | has(\"$MK\")" "$PROFILE_FILE")" == "true" ]] \
    || invalid "$REL_PROFILE: field 'mcp.$MK' is missing"
done
require_tag "$PROFILE_FILE" '.mcp.servers' '!!seq' "$REL_PROFILE: field 'mcp.servers' must be a list"
require_tag "$PROFILE_FILE" '.mcp.plugins' '!!seq' "$REL_PROFILE: field 'mcp.plugins' must be a list"
require_tag "$PROFILE_FILE" '.mcp.skills'  '!!seq' "$REL_PROFILE: field 'mcp.skills' must be a list"

MCP_SRV_N="$(yq eval '.mcp.servers | length' "$PROFILE_FILE")"

# R7.16: a registry is required whenever servers is non-empty; `none` is only valid when it is
# empty. `registry` is either the scalar `none` or a map naming type/url/pinned.
MCP_REG_TAG="$(yq eval '.mcp.registry | tag' "$PROFILE_FILE" 2>/dev/null)" || MCP_REG_TAG="(unreadable)"
if ((MCP_SRV_N > 0)); then
  if [[ "$MCP_REG_TAG" == "!!str" ]]; then
    [[ "$(yq eval '.mcp.registry' "$PROFILE_FILE")" != "none" ]] \
      || invalid "$REL_PROFILE: mcp.servers is non-empty but mcp.registry is 'none'. R7.16 requires a declared, pinned registry for every inventoried server"
    invalid "$REL_PROFILE: mcp.registry must be 'none' or a mapping {type, url, pinned}, found scalar '$(yq eval '.mcp.registry' "$PROFILE_FILE")'"
  fi
  [[ "$MCP_REG_TAG" == "!!map" ]] \
    || invalid "$REL_PROFILE: mcp.registry must be 'none' or a mapping {type, url, pinned}, found $MCP_REG_TAG"
  for RK in type url pinned; do
    scalar_nonblank "$PROFILE_FILE" ".mcp.registry.$RK" >/dev/null \
      || invalid "$REL_PROFILE: mcp.registry.$RK is missing, empty or blank (R7.16 -- installed only from a declared, pinned registry)"
  done
else
  [[ "$MCP_REG_TAG" == "!!str" && "$(yq eval '.mcp.registry' "$PROFILE_FILE")" == "none" ]] \
    || invalid "$REL_PROFILE: mcp.servers is empty, so mcp.registry must be the literal 'none' -- an empty inventory names no registry to pin"
fi

declare -A SEEN_MCP_SERVER_NAMES=()
for ((m = 0; m < MCP_SRV_N; m++)); do
  MS=".mcp.servers[$m]"
  require_tag "$PROFILE_FILE" "$MS" '!!map' "$REL_PROFILE: mcp.servers[$m] must be a mapping"
  MNAME="$(scalar_nonblank "$PROFILE_FILE" "$MS.name")" \
    || invalid "$REL_PROFILE: mcp.servers[$m].name is missing, empty or blank"
  if [[ -n "${SEEN_MCP_SERVER_NAMES[$MNAME]+x}" ]]; then
    invalid "$REL_PROFILE: mcp.servers declares '$MNAME' twice"
  fi
  SEEN_MCP_SERVER_NAMES[$MNAME]=1

  # agents: non-empty subset of the base allowlist's keys (Interface Contract 5).
  require_tag "$PROFILE_FILE" "$MS.agents" '!!seq' "$REL_PROFILE: mcp.servers[$m] ('$MNAME').agents must be a list"
  MAG_N="$(yq eval "$MS.agents | length" "$PROFILE_FILE")"
  ((MAG_N > 0)) \
    || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').agents is empty. A server inventoried for no agent is not inventoried"
  for ((a = 0; a < MAG_N; a++)); do
    MAG="$(yq eval "$MS.agents[$a]" "$PROFILE_FILE")"
    grep -Fxq "$MAG" <<< "$ALLOW_AGENTS" \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').agents[$a] '$MAG' is not an agent the base allowlist keys"
  done

  scalar_nonblank "$PROFILE_FILE" "$MS.version" >/dev/null \
    || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').version is missing, empty or blank"

  # artifact: either the literal n/a note for a remote server, or {path, sha256}.
  MART_TAG="$(yq eval "$MS.artifact | tag" "$PROFILE_FILE" 2>/dev/null)" || MART_TAG="(unreadable)"
  if [[ "$MART_TAG" == "!!map" ]]; then
    scalar_nonblank "$PROFILE_FILE" "$MS.artifact.path" >/dev/null \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').artifact.path is missing, empty or blank"
    MASHA="$(yq eval "$MS.artifact.sha256" "$PROFILE_FILE")"
    [[ "$MASHA" =~ ^[0-9a-f]{64}$ ]] \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').artifact.sha256 '$MASHA' is not a 64-character lowercase hex digest"
  elif [[ "$MART_TAG" == "!!str" ]]; then
    scalar_nonblank "$PROFILE_FILE" "$MS.artifact" >/dev/null \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').artifact is blank"
  else
    invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').artifact must be a string note or a mapping {path, sha256}, found $MART_TAG"
  fi

  # T30 -- transport and enforcement_point, enforced as a pair.
  MTRANS="$(yq eval "$MS.transport" "$PROFILE_FILE")"
  case "$MTRANS" in
    stdio|http|sse) : ;;
    *) invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').transport must be one of stdio, http or sse, found '$MTRANS' (R7.15, T30)" ;;
  esac
  MENF="$(yq eval "$MS.enforcement_point" "$PROFILE_FILE")"
  if [[ "$MTRANS" == "stdio" ]]; then
    [[ "$MENF" == "none" ]] \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME') is transport 'stdio' but enforcement_point is '$MENF', not 'none'. A stdio server is a subprocess of the agent and reaches no network enforcement point (R7.15, T30)"
  else
    [[ "$MENF" == "mediator" ]] \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME') is transport '$MTRANS' but enforcement_point is '$MENF', not 'mediator'. An http/sse server's traffic must cross the mediator to be covered (R7.15, T30)"
  fi

  # egress: required shape always present; entries required only for http/sse (composed into the
  # per-agent allowlist below, under the same checks and collision rule packs use).
  require_tag "$PROFILE_FILE" "$MS.egress" '!!map' "$REL_PROFILE: mcp.servers[$m] ('$MNAME').egress must be a mapping"
  for EGK in allow_fqdns allow_cidrs; do
    [[ "$(yq eval "$MS.egress | has(\"$EGK\")" "$PROFILE_FILE")" == "true" ]] \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').egress.$EGK is missing"
  done
  MEGN="$(yq eval "$MS.egress.allow_fqdns | length" "$PROFILE_FILE")"
  if [[ "$MTRANS" == "stdio" ]]; then
    ((MEGN == 0)) \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME') is transport 'stdio' but declares $MEGN egress.allow_fqdns entr(y|ies). A subprocess's own traffic inherits the agent's proxy environment; a stdio server does not compose its own egress entries"
  fi
  for ((g = 0; g < MEGN; g++)); do
    MFQDN="$(yq eval "$MS.egress.allow_fqdns[$g].fqdn" "$PROFILE_FILE")"
    MPORT="$(yq eval "$MS.egress.allow_fqdns[$g].port" "$PROFILE_FILE")"
    [[ "$MFQDN" != *"*"* ]] \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').egress.allow_fqdns[$g].fqdn '$MFQDN' is a wildcard; exact names only (R5.4)"
    [[ "${#MFQDN}" -le 253 && "$MFQDN" =~ $FQDN_RE ]] \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').egress.allow_fqdns[$g].fqdn '$MFQDN' is not a valid hostname"
    [[ "$MPORT" =~ ^[0-9]+$ ]] \
      || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').egress.allow_fqdns[$g].port must be an integer, found '$MPORT'"
  done
  MEGC="$(yq eval "$MS.egress.allow_cidrs | length" "$PROFILE_FILE")"
  ((MEGC == 0)) \
    || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').egress.allow_cidrs has $MEGC entr(y|ies). No requirement names an MCP CIDR entry, and the mediator refuses a non-empty allow_cidrs at start regardless"

  # mounts/env/credentials: present and correctly typed. No shipped or fixture server populates
  # these; deeper validation (Interface Contract 1's name regexes, reserved-name gate) is not
  # built here because no requirement or Interface Contract text asks for it yet -- flagged for a
  # future SF if a server needs one, rather than built speculatively (over-engineering gate).
  for LK in mounts env credentials; do
    require_tag "$PROFILE_FILE" "$MS.$LK" '!!seq' "$REL_PROFILE: mcp.servers[$m] ('$MNAME').$LK must be a list"
  done

  MWRITE="$(yq eval "$MS.needs_write_access" "$PROFILE_FILE")"
  [[ "$MWRITE" == "true" || "$MWRITE" == "false" ]] \
    || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').needs_write_access must be true or false, found '$MWRITE'"

  MTIER="$(yq eval "$MS.risk_tier" "$PROFILE_FILE")"
  case "$MTIER" in
    read-only|write|irreversible) : ;;
    *) invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').risk_tier must be one of read-only, write or irreversible, found '$MTIER'" ;;
  esac

  require_tag "$PROFILE_FILE" "$MS.capability_baseline" '!!map' "$REL_PROFILE: mcp.servers[$m] ('$MNAME').capability_baseline must be a mapping"
  MCFG="$(yq eval "$MS.capability_baseline.config_sha256" "$PROFILE_FILE")"
  [[ "$MCFG" =~ ^[0-9a-f]{64}$ ]] \
    || invalid "$REL_PROFILE: mcp.servers[$m] ('$MNAME').capability_baseline.config_sha256 '$MCFG' is not a 64-character lowercase hex digest"
  require_tag "$PROFILE_FILE" "$MS.capability_baseline.tools" '!!seq' \
    "$REL_PROFILE: mcp.servers[$m] ('$MNAME').capability_baseline.tools must be a list (recorded for review; not machine-checked)"
done
unset SEEN_MCP_SERVER_NAMES

# plugins and skills share one shape: {name, agents, version, sha256, risk_tier}.
for MPK in plugins skills; do
  MPN="$(yq eval ".mcp.$MPK | length" "$PROFILE_FILE")"
  for ((p = 0; p < MPN; p++)); do
    MP=".mcp.$MPK[$p]"
    require_tag "$PROFILE_FILE" "$MP" '!!map' "$REL_PROFILE: mcp.$MPK[$p] must be a mapping"
    MPNAME="$(scalar_nonblank "$PROFILE_FILE" "$MP.name")" \
      || invalid "$REL_PROFILE: mcp.$MPK[$p].name is missing, empty or blank"
    require_tag "$PROFILE_FILE" "$MP.agents" '!!seq' "$REL_PROFILE: mcp.$MPK[$p] ('$MPNAME').agents must be a list"
    MPAG_N="$(yq eval "$MP.agents | length" "$PROFILE_FILE")"
    ((MPAG_N > 0)) \
      || invalid "$REL_PROFILE: mcp.$MPK[$p] ('$MPNAME').agents is empty"
    for ((a = 0; a < MPAG_N; a++)); do
      MPAG="$(yq eval "$MP.agents[$a]" "$PROFILE_FILE")"
      grep -Fxq "$MPAG" <<< "$ALLOW_AGENTS" \
        || invalid "$REL_PROFILE: mcp.$MPK[$p] ('$MPNAME').agents[$a] '$MPAG' is not an agent the base allowlist keys"
    done
    scalar_nonblank "$PROFILE_FILE" "$MP.version" >/dev/null \
      || invalid "$REL_PROFILE: mcp.$MPK[$p] ('$MPNAME').version is missing, empty or blank"
    MPSHA="$(yq eval "$MP.sha256" "$PROFILE_FILE")"
    [[ "$MPSHA" =~ ^[0-9a-f]{64}$ ]] \
      || invalid "$REL_PROFILE: mcp.$MPK[$p] ('$MPNAME').sha256 '$MPSHA' is not a 64-character lowercase hex digest"
    MPTIER="$(yq eval "$MP.risk_tier" "$PROFILE_FILE")"
    case "$MPTIER" in
      read-only|write|irreversible) : ;;
      *) invalid "$REL_PROFILE: mcp.$MPK[$p] ('$MPNAME').risk_tier must be one of read-only, write or irreversible, found '$MPTIER'" ;;
    esac
  done
done

# ---- packs: every selected name must resolve to a manifest --------------------------------
# The tag, not the length: `yq '.packs | length'` returns 0 for a missing key, for `packs: ""`
# and for `packs: {}` alike, so a length test reads three malformed shapes as a zero-pack profile
# and skips every pack gate below (Codex adversarial pass, 2026-09-08).
require_tag "$PROFILE_FILE" '.packs' '!!seq' \
  "$REL_PROFILE: field 'packs' must be a list (declare 'packs: []' where a profile selects none)"
PACKS_LEN="$(yq eval '.packs | length' "$PROFILE_FILE")"
PACK_FILES=()
PACK_NAMES=()
for ((i = 0; i < PACKS_LEN; i++)); do
  PN="$(yq eval ".packs[$i]" "$PROFILE_FILE")"
  # The name becomes a directory path. Constrained at the boundary for the same reason the
  # hostnames are: it is third-party-supplied content that this script turns into a file read.
  # PACK_RE, not a second inline regex: the producer and validate_resolved's consumer check must
  # be the SAME shape, or a name this accepts emits an artifact its own validator rejects.
  [[ "$PN" =~ $PACK_RE ]] \
    || invalid "$REL_PROFILE: packs[$i] '$PN' is not a valid pack name (lowercase letters, digits and hyphens); it is resolved as a directory under packs/"
  # A name YAML reads as something other than a string. The emitter writes pack names UNQUOTED
  # into compiled_from.packs, so a pack directory called `null`, `true`, `no` or `0755` would
  # round-trip out of the artifact as a null, a boolean or an integer -- and PACK_RE, which
  # matches the RENDERED text, would accept it again on the way back in. Refused at the producer
  # so the artifact can never carry one. Found by the Codex adversarial pass, 2026-09-08.
  case "$PN" in
    null|true|false|yes|no|on|off|y|n) invalid "$REL_PROFILE: packs[$i] '$PN' is a YAML boolean or null literal and cannot be used as a pack name; it would not survive a round trip through the resolved artifact" ;;
  esac
  [[ ! "$PN" =~ ^[0-9]+$ ]] \
    || invalid "$REL_PROFILE: packs[$i] '$PN' is all digits and would round-trip out of the resolved artifact as an integer; give the pack a name YAML reads as a string"
  [[ -f "$REPO_ROOT/packs/$PN/pack.yaml" ]] \
    || invalid "$REL_PROFILE: packs[$i] '$PN' does not resolve to packs/$PN/pack.yaml"
  yq eval '.' "$REPO_ROOT/packs/$PN/pack.yaml" >/dev/null 2>&1 \
    || invalid "packs/$PN/pack.yaml does not parse as YAML"
  PACK_FILES+=("$REPO_ROOT/packs/$PN/pack.yaml")
  PACK_NAMES+=("$PN")

  PF="$REPO_ROOT/packs/$PN/pack.yaml"
  REL_PF="packs/$PN/pack.yaml"

  # A duplicate selection would compose the same entries twice and put the same manifest in the
  # provenance record twice. Caught here rather than absorbed by the dedup below, because a
  # profile listing one pack twice is an editing mistake, not a composition to resolve.
  for PREV in "${PACK_NAMES[@]:0:${#PACK_NAMES[@]}-1}"; do
    [[ "$PREV" != "$PN" ]] || invalid "$REL_PROFILE: packs[$i] '$PN' is selected more than once"
  done

  # ---- deny_* in a manifest is a validation failure, not a merge ---------------------------
  # Deny wins post-resolution and no pack may remove, narrow OR EXTEND a deny entry: the deny
  # lists are copied from the base unmodified. A pack that could write them would be able to
  # deny a destination another pack needs, from inside third-party content.
  #
  # Searched RECURSIVELY, not at the two nesting levels a reader would think to check. A probe
  # put `deny_cidrs` under `egress.runtime` -- a level neither the top-level nor the `egress`
  # test looked at -- and it sailed through. A key that must not appear ANYWHERE must be looked
  # for anywhere.
  for DK in deny_fqdns deny_cidrs; do
    # COUNT, not the rendered path: a match at the document ROOT has an empty path, so a test on
    # the joined string alone reads the most obvious violation of all as no match.
    DN="$(yq eval "[.. | select(has(\"$DK\"))] | length" "$PF" 2>/dev/null || echo 0)"
    DPATH="$(yq eval "[.. | select(has(\"$DK\")) | path | join(\".\") | select(. != \"\")] | .[]" "$PF" 2>/dev/null || true)"
    [[ -n "$DPATH" ]] || DPATH="(document root)"
    [[ "$DN" == "0" ]] \
      || invalid "$REL_PF declares '$DK' (at: $(tr '\n' ' ' <<< "$DPATH")). Deny entries come from the denylist base and are copied to the resolved artifact unmodified; a pack cannot add, remove or narrow one"
  done

  # ---- the manifest's composed surfaces must be lists before anything traverses them --------
  require_tag "$PF" '.egress.runtime.allow_fqdns' '!!seq' \
    "$REL_PF: field 'egress.runtime.allow_fqdns' must be a list (declare '[]' where the pack needs none)"
  require_tag "$PF" '.egress.runtime.allow_cidrs' '!!seq' \
    "$REL_PF: field 'egress.runtime.allow_cidrs' must be a list (declare '[]' where the pack needs none)"
  for MK in mounts env credentials; do
    require_tag "$PF" ".$MK" '!!seq' \
      "$REL_PF: field '$MK' must be a list (declare '[]' where the pack requires none)"
  done

  # ---- GATE (R2.8, T21) -- a pack mount key outside the closed set ---------------------------
  # SF-2's Codex pass deferred the pack-manifest mount entry shape here rather than inventing one
  # a sub-feature early. The shape defined is the MINIMUM the R2.8 gate needs and no more: an
  # entry names a mount key, either as a bare scalar or as a single-key map whose key is the mount
  # name. Source, target and mode semantics are NOT defined here -- they belong with the composition
  # that consumes them, and inventing them now would pre-empt SF-5 the same way SF-2 would have
  # pre-empted SF-3. The key is gated against the same closed set the profile's `mounts` is gated
  # against: fail closed, because a pack asking for a mount that is silently ignored is
  # indistinguishable from one correctly refused right up to the day the key is implemented.
  PM_N="$(yq eval '.mounts | length' "$PF")"
  for ((m = 0; m < PM_N; m++)); do
    MTAG="$(yq eval ".mounts[$m] | tag" "$PF" 2>/dev/null)" || MTAG="(unreadable)"
    case "$MTAG" in
      '!!str')
        MKEY="$(yq eval ".mounts[$m]" "$PF")" ;;
      '!!map')
        [[ "$(yq eval ".mounts[$m] | keys | length" "$PF")" == "1" ]] \
          || invalid "$REL_PF: mounts[$m] is a map with more than one key. A pack mount entry names exactly one mount key"
        MKEY="$(yq eval ".mounts[$m] | keys | .[0]" "$PF")" ;;
      *)
        invalid "$REL_PF: mounts[$m] must be a mount key, either as a string or as a single-key map (found $MTAG)" ;;
    esac
    # The same closed set the profile's `mounts` is gated against below, written the same way.
    # It is a literal here rather than a variable read from the profile: the profile's keys are
    # what that gate JUDGES, not the set it judges them against, and a pack must be measured
    # against the project's mount set, not against whichever mounts one profile happens to name.
    case "$MKEY" in
      project|build_cache|host_git_config) : ;;
      *) refuse "$REL_PF: mounts[$m] names '$MKEY', which is not a mount this system offers. Only mounts enumerated in R2 are available to enable -- project, build_cache, host_git_config -- and forwarded sockets, SSH_AUTH_SOCK above all, are not among them (R2.8, T21)" ;;
    esac
  done

done

# ---- R7.18: package_repository, required only where packs are selected ---------------------
# A snapshot, NOT a suite. `suite: bookworm` plus name=version resolves today and fails in six
# months -- Debian rotates the archive and drops superseded versions, and SC-8 measures exactly
# the clean rebuild that happens later. The timestamped path is what makes the pin stable in
# time, so its shape is asserted rather than assumed from the operator's intent.
if ((PACKS_LEN > 0)); then
  [[ "$(yq eval 'has("package_repository")' "$PROFILE_FILE")" == "true" ]] \
    || invalid "$REL_PROFILE: field 'package_repository' is missing, but the profile selects $PACKS_LEN pack(s) whose apt items are sourced from it (R7.18)"
  require_tag "$PROFILE_FILE" '.package_repository.apt' '!!map' \
    "$REL_PROFILE: field 'package_repository.apt' must be a mapping (R7.18)"
  for field in url suite signed_by fingerprint; do
    scalar_nonblank "$PROFILE_FILE" ".package_repository.apt.$field" >/dev/null \
      || invalid "$REL_PROFILE: field 'package_repository.apt.$field' is missing, empty or not a scalar (R7.18)"
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
require_tag "$PROFILE_FILE" '.mounts' '!!map' \
  "$REL_PROFILE: field 'mounts' must be a mapping"
for field in path mode; do
  scalar_nonblank "$PROFILE_FILE" ".mounts.project.$field" >/dev/null \
    || invalid "$REL_PROFILE: field 'mounts.project.$field' is missing, empty or not a scalar"
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
      # -F, and a quoted yq path. A key is arbitrary YAML text: `[c]odex` is a REGEX that matches
      # the agent `codex` under plain grep, and then walks into an unquoted yq path expression
      # where it is a lexer error -- a raw exit 1 wearing none of this script's error format
      # (Codex adversarial pass, 2026-09-08).
      grep -qFx "$bca" <<< "$ALLOW_AGENTS" \
        || invalid "$REL_PROFILE: mounts.build_cache names agent '$bca', which is not an agent in $REL_ALLOWLIST"
      bcv="$(yq eval ".mounts.build_cache[\"${bca}\"]" "$PROFILE_FILE")"
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
require_tag "$PROFILE_FILE" '.auth_mode' '!!map' \
  "$REL_PROFILE: field 'auth_mode' must be a mapping keyed by agent (R4.12)"
AUTH_AGENTS="$(yq eval '.auth_mode | keys | .[]' "$PROFILE_FILE")"
[[ -n "$AUTH_AGENTS" ]] || invalid "$REL_PROFILE: field 'auth_mode' is empty"
while IFS= read -r aa; do
  [[ "$(yq eval ".auth_mode.${aa}" "$PROFILE_FILE")" == "oauth-mount" ]] || continue
  [[ "$(yq eval ".oauth_mount.${aa} | has(\"accepted_risk\")" "$PROFILE_FILE")" == "true" ]] \
    || refuse "$REL_PROFILE: auth_mode.${aa} is 'oauth-mount' but oauth_mount.${aa}.accepted_risk is absent. R4.17 requires the decision to be RECORDED before the credential crosses the boundary: file, mount_mode, revocation_path, blast_radius and rotation"
  for field in file mount_mode revocation_path blast_radius rotation; do
    scalar_nonblank "$PROFILE_FILE" ".oauth_mount.${aa}.accepted_risk.$field" >/dev/null \
      || refuse "$REL_PROFILE: oauth_mount.${aa}.accepted_risk.$field is missing, empty, blank or an empty collection (R4.17, T27). yq renders '[]' and '{}' as text, so this asks whether the field was RECORDED, not whether it prints"
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
    refuse "packs/$PN/pack.yaml declares $RT_N runtime egress entr(y|ies) with runtime_install: false. Any runtime egress is what makes runtime installation possible -- a package registry is the common case, but a cluster API server, or any other named destination, can serve arbitrary bytes just as well (02.3). R7.6 requires the widening declared: set runtime_install: true WITH runtime_install_reason, or remove the entries. Where the destination IS a package registry, declaring it also re-enables arbitrary 'npx <server>' and breaks T31 on every profile loading this pack"
  fi
  if [[ "$RI" == "true" ]]; then
    scalar_nonblank "$PF" '.runtime_install_reason' >/dev/null \
      || refuse "packs/$PN/pack.yaml sets runtime_install: true without 'runtime_install_reason'. R7.6 requires the exception to be explicitly declared, and a flag with no recorded reason is a default flipped rather than a decision taken"
    ((RT_N > 0)) \
      || refuse "packs/$PN/pack.yaml sets runtime_install: true but declares no egress.runtime entries. Runtime installation without registry egress cannot work, so this records a widening the resolved policy does not carry -- declare the registries or set runtime_install: false"
  fi
done


# ---- mounts: still refused, message corrected (02.3 Decision 1) -----------------------------
# Interface Contract 3 fixes the resolved schema and names exactly two things packs populate:
# compiled_from.packs, and the per-agent allow_fqdns/allow_cidrs. There is no resolved-policy
# field for a pack mount, and no shipped pack needs one: Terraform, kubectl, helm and gh keep
# their state and caches under /home/agent on the state volume. A pack mount is REFUSED rather
# than ignored, for the reason the mount-key gate above exists: a declared requirement that is
# silently dropped is indistinguishable from one that was honoured. Building a mount landing
# point with no consumer fails the over-engineering discriminator in any case; when a pack does
# need one, that is a design change reviewed against R2.8's enumeration, not a default a
# manifest can opt into.
for ((i = 0; i < PACKS_LEN; i++)); do
  PN="${PACK_NAMES[$i]}"; PF="${PACK_FILES[$i]}"; REL_PF="packs/$PN/pack.yaml"
  PM_N="$(yq eval '.mounts | length' "$PF")"
  [[ "$PM_N" == "0" ]] \
    || refuse "$REL_PF declares $PM_N mount(s), and the resolved policy schema (01.3 Interface Contract 1) has no field for one. No shipped pack needs a host mount -- state and caches land under /home/agent, credentials land as Compose secrets, and non-secret configuration is baked into the per-profile image. A pack mount is a design change reviewed against R2.8's enumeration, never a default a manifest can opt into"
done

# ---- env / credentials / third_parties: Interface Contract 1 (02.3 Decision 1) --------------
# 01.5's SF-3 refused both unconditionally, naming no landing point. 02.3 gives each one:
# `env` rides the per-profile image (R7.5 holds by construction -- remove the pack, rebuild,
# and the variable is gone); `credentials` become Compose `file:` secrets, never baked into an
# image layer (R8.1). Both are validated here, not trusted from lint-policy.sh's well-formedness
# pass, because a pack manifest is third-party content and this is the build's enforcement point.
ENV_NAME_RE='^[A-Z_][A-Z0-9_]*$'
CRED_NAME_RE='^[a-z0-9-]+$'
# The pod contract's own variables. A pack overriding one would silently change the proxy, auth
# or identity behaviour an operator did not choose (Interface Contract 1).
is_reserved_env() {
  case "$1" in
    PATH|HOME|USER|SHELL|LD_*) return 0 ;;
    HTTP_PROXY|http_proxy|HTTPS_PROXY|https_proxy|NO_PROXY|no_proxy) return 0 ;;
    AUTH_MODE|AGENT_NAME) return 0 ;;
    *_API_KEY|CLAUDE_*|CODEX_*|GEMINI_*) return 0 ;;
    NODE_EXTRA_CA_CERTS|SSL_CERT_FILE) return 0 ;;
    GIT_CONFIG_*) return 0 ;;
    *) return 1 ;;
  esac
}

declare -A SEEN_ENV_NAMES=()   # name -> "packs/<pn>/pack.yaml", for the cross-pack duplicate gate

for ((i = 0; i < PACKS_LEN; i++)); do
  PN="${PACK_NAMES[$i]}"; PF="${PACK_FILES[$i]}"; REL_PF="packs/$PN/pack.yaml"

  EV_N="$(yq eval '.env | length' "$PF")"
  for ((e = 0; e < EV_N; e++)); do
    EN="$(yq eval ".env[$e].name" "$PF")"
    [[ "$EN" =~ $ENV_NAME_RE ]] \
      || invalid "$REL_PF: env[$e].name '$EN' does not match $ENV_NAME_RE (Interface Contract 1)"
    if is_reserved_env "$EN"; then
      refuse "$REL_PF: env[$e] declares '$EN', which the pod contract already sets. A pack overriding it would silently change the proxy, auth or identity behaviour an operator did not choose (Interface Contract 1)"
    fi
    VTAG="$(yq eval ".env[$e].value | tag" "$PF" 2>/dev/null)" || VTAG="(unreadable)"
    [[ "$VTAG" == "!!str" ]] \
      || invalid "$REL_PF: env[$e].value must be a literal string scalar, found $VTAG. A pack env value is never a secret (Interface Contract 1)"
    scalar_nonblank "$PF" ".env[$e].reason" >/dev/null \
      || invalid "$REL_PF: env[$e].reason is missing, empty or blank. Every pack env variable records why it is needed (Interface Contract 1)"
    if [[ -n "${SEEN_ENV_NAMES[$EN]+x}" ]]; then
      refuse "$REL_PF: env[$e] declares '$EN', already declared by ${SEEN_ENV_NAMES[$EN]}. A variable declared by two selected packs is refused rather than silently letting one win (Interface Contract 1)"
    fi
    SEEN_ENV_NAMES[$EN]="$REL_PF"
  done

  declare -A SEEN_CRED_NAMES_IN_PACK=()
  CR_N="$(yq eval '.credentials | length' "$PF")"
  for ((c = 0; c < CR_N; c++)); do
    CN="$(yq eval ".credentials[$c].name" "$PF")"
    [[ "$CN" =~ $CRED_NAME_RE ]] \
      || invalid "$REL_PF: credentials[$c].name '$CN' does not match $CRED_NAME_RE (Interface Contract 1)"
    if [[ -n "${SEEN_CRED_NAMES_IN_PACK[$CN]+x}" ]]; then
      refuse "$REL_PF: credentials declares '$CN' twice. A credential name duplicated within a pack is refused (Interface Contract 1)"
    fi
    SEEN_CRED_NAMES_IN_PACK[$CN]=1
    DELIV_TAG="$(yq eval ".credentials[$c].delivery | tag" "$PF" 2>/dev/null)" || DELIV_TAG="(unreadable)"
    [[ "$DELIV_TAG" == "!!map" ]] \
      || invalid "$REL_PF: credentials[$c].delivery must be a mapping, found $DELIV_TAG"
    HAS_ENV_D="$(yq eval ".credentials[$c].delivery | has(\"env\")" "$PF")"
    HAS_PATH_ENV_D="$(yq eval ".credentials[$c].delivery | has(\"path_env\")" "$PF")"
    DELIV_KEY_N="$(yq eval ".credentials[$c].delivery | keys | length" "$PF")"
    [[ "$DELIV_KEY_N" == "1" && ( "$HAS_ENV_D" == "true" || "$HAS_PATH_ENV_D" == "true" ) ]] \
      || invalid "$REL_PF: credentials[$c].delivery must be exactly one of {env: VAR} or {path_env: VAR}, found keys: $(yq eval ".credentials[$c].delivery | keys | .[]" "$PF" | tr '\n' ' ')"
    for field in description blast_radius revocation; do
      scalar_nonblank "$PF" ".credentials[$c].$field" >/dev/null \
        || invalid "$REL_PF: credentials[$c].$field is missing, empty or blank (Interface Contract 1, R8.4/R7.12)"
    done
  done
  unset SEEN_CRED_NAMES_IN_PACK

  # third_parties: required non-empty iff egress.runtime is non-empty (R14.1). The anchor
  # itself is resolved by lint-policy.sh, not here -- the compile stage's job is to require the
  # field was answered, not to reach into docs/records/ from inside the mediator build.
  TP_N="$(yq eval '.third_parties | length' "$PF")"
  RT_N=$(( $(yq eval '.egress.runtime.allow_fqdns | length' "$PF") + $(yq eval '.egress.runtime.allow_cidrs | length' "$PF") ))
  if ((RT_N > 0)); then
    ((TP_N > 0)) \
      || refuse "$REL_PF declares $RT_N runtime egress entr(y|ies) but an empty third_parties. R14.1 requires a record for every party the agent's traffic can reach before that traffic is possible, named here, not after the fact"
    for ((t = 0; t < TP_N; t++)); do
      scalar_nonblank "$PF" ".third_parties[$t].party" >/dev/null \
        || invalid "$REL_PF: third_parties[$t].party is missing, empty or blank"
      scalar_nonblank "$PF" ".third_parties[$t].record" >/dev/null \
        || invalid "$REL_PF: third_parties[$t].record is missing, empty or blank"
    done
  fi
done

# ---- GATE (R7.8) -- unknown top-level pack manifest keys are refused, not ignored -----------
# The same philosophy as the mount-key gate above: an ignored key is indistinguishable from an
# honoured one until the day it is implemented. A third-party pack manifest carrying `cap_add`,
# `privileged` or `devices` must fail here, not be silently dropped on the floor.
KNOWN_PACK_KEYS="name description schema blast_radius needs_write_access packages egress runtime_install runtime_install_reason mounts env credentials third_parties"
for ((i = 0; i < PACKS_LEN; i++)); do
  PN="${PACK_NAMES[$i]}"; PF="${PACK_FILES[$i]}"; REL_PF="packs/$PN/pack.yaml"
  PACK_KEYS="$(yq eval 'keys | .[]' "$PF")"
  while IFS= read -r pk; do
    [[ -n "$pk" ]] || continue
    grep -qFx "$pk" <<< "$(tr ' ' '\n' <<< "$KNOWN_PACK_KEYS")" \
      || invalid "$REL_PF: unrecognised top-level key '$pk'. A pack manifest may declare only: $KNOWN_PACK_KEYS -- an unknown key such as cap_add, privileged or devices is refused rather than ignored (R7.8), because a schema field this compiler does not read is a capability request nothing enforces"
  done <<< "$PACK_KEYS"
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
  PP="$(normalise_abs "$PROJECT_PATH")"; ROOT="$(normalise_abs "$REPO_ROOT")"
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

# ---- pack provenance: the manifest digest that makes compiled_from a record ------------------
# The per-pack sha256 is what turns `compiled_from.packs` from a list of names into provenance: it
# tells a reviewer that this artifact was compiled from THIS manifest and not from a later edit of
# it. Digest of the manifest FILE, not of a canonicalisation of its content -- a reformatted
# manifest is a changed input, and the drift check should say so.
#
# sha256sum on Debian, `shasum -a 256` on macOS. Both are present on the host and inside the
# mediator image (checked, not assumed), and both emit the same lowercase hex, so the emitted
# artifact does not depend on which side compiled it -- which is the property Edge Case 17's
# byte-identical requirement rests on.
sha256_of() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | cut -d' ' -f1
  else
    fail "no sha256 tool found (need sha256sum or shasum)"
  fi
}

# Sorted by name so the provenance block's order is a property of the pack SET and not of the
# order the profile happened to list them in. LC_ALL=C throughout this script: the host is macOS
# and the compile stage is Debian, and a locale-dependent collation would make the two sides
# disagree on ordering alone (Edge Case 17).
PACK_PROVENANCE=""
for ((i = 0; i < PACKS_LEN; i++)); do
  PACK_PROVENANCE+="${PACK_NAMES[$i]}|$(sha256_of "${PACK_FILES[$i]}")"$'\n'
done
[[ -z "$PACK_PROVENANCE" ]] || PACK_PROVENANCE="$(LC_ALL=C sort <<< "${PACK_PROVENANCE%$'\n'}")"

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
  if [[ -z "$PACK_PROVENANCE" ]]; then
    echo "  packs: []"
  else
    echo "  packs:"
    while IFS='|' read -r pkn pksha; do
      echo "    - {name: ${pkn}, path: packs/${pkn}/pack.yaml, sha256: ${pksha}}"
    done <<< "$PACK_PROVENANCE"
  fi
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
    #
    # `client_auth` (01.6 SF-2) is REQUIRED, not defaulted. An absent key is a compile error
    # rather than a silent `none`, because a listener that quietly stops requesting a client
    # certificate because a key was dropped is precisely the failure the field exists to make
    # visible. The cost is stated rather than discovered: a required key added to one profile
    # fails every other profile's compile, and four profiles declare a `listeners:` block.
    for k in scheme tls port client_auth; do
      [[ "$(yq eval ".listeners.${agent} | has(\"$k\")" "$PROFILE_FILE")" == "true" ]] \
        || invalid "$REL_PROFILE has no listeners.${agent}.${k}"
    done
    LISTENER_SCHEME="$(yq eval ".listeners.${agent}.scheme" "$PROFILE_FILE")"
    LISTENER_TLS="$(yq eval ".listeners.${agent}.tls" "$PROFILE_FILE")"
    LISTENER_PORT="$(yq eval ".listeners.${agent}.port" "$PROFILE_FILE")"
    LISTENER_CLIENT_AUTH="$(yq eval ".listeners.${agent}.client_auth" "$PROFILE_FILE")"
    case "$LISTENER_CLIENT_AUTH" in
      mtls|proxy_auth|none) : ;;
      *) invalid "$REL_PROFILE: listeners.${agent}.client_auth must be one of mtls, proxy_auth or none, found '$LISTENER_CLIENT_AUTH'" ;;
    esac
    # Squid cannot request a client certificate on a listener that does not speak TLS, so this
    # combination compiles to a mediator that refuses its own agent at the handshake -- with no
    # audit line, because the connection dies before there is a request to log.
    [[ "$LISTENER_CLIENT_AUTH" != "mtls" || "$LISTENER_TLS" == "true" ]] \
      || invalid "$REL_PROFILE: listeners.${agent}.client_auth is 'mtls' but tls is '$LISTENER_TLS'. A client certificate can only be requested on a TLS listener."

    for k in max_concurrent bytes_per_second; do
      [[ "$(yq eval ".rate_limits.${agent} | has(\"$k\")" "$PROFILE_FILE")" == "true" ]] \
        || invalid "$REL_PROFILE has no rate_limits.${agent}.${k}"
    done

    echo "  ${agent}:"
    echo "    identity: ${agent}"
    echo "    listener_port: ${LISTENER_PORT}"
    echo "    listener: {scheme: ${LISTENER_SCHEME}, tls: ${LISTENER_TLS}, port: ${LISTENER_PORT}, client_auth: ${LISTENER_CLIENT_AUTH}}"
    # ---- composition, per agent (01.5 SF-3) -------------------------------------------------
    # Base entries and every selected pack's runtime entries are collected into ONE set, keyed
    # per agent and never flattened across agents (the composition model's first property: 01.1
    # SF-3 keys the capture per agent precisely so the compiler inherits a per-agent policy
    # rather than a union). The profile's `packs:` list is flat, so a selected pack applies to
    # every agent the base allowlist keys.
    #
    # Each line is fqdn|port|upgrade|source. The source travels only so a collision can name both
    # sides; it is cut off before anything is emitted.
    ENTRIES=""

    FQ_N="$(yq eval ".agents.${agent}.allow_fqdns | length" "$ALLOWLIST")"
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
      # PORT and UPGRADE are shape-checked HERE, before they enter the accumulator, and not only
      # in validate_resolved on the way out. The accumulator is pipe-delimited and newline-
      # separated, so a base `port` carrying either character does not merely emit a malformed
      # entry -- it emits an EXTRA, well-formed one. A port of "443|false\nevil.example.com|443"
      # yielded a second allowed destination the base allowlist never contained, and the artifact
      # then validated. The pack-supplied branch below already checked both; the base branch,
      # which predates SF-3's encoding, did not. Found by the Codex adversarial pass, 2026-09-08.
      [[ "$PORT" =~ ^[0-9]+$ ]] \
        || invalid "$REL_ALLOWLIST: agents.${agent}.allow_fqdns[$i].port must be an integer, found '$PORT'"
      [[ "$UPGRADE" == "true" || "$UPGRADE" == "false" ]] \
        || invalid "$REL_ALLOWLIST: agents.${agent}.allow_fqdns[$i].upgrade must be true or false, found '$UPGRADE'"
      ENTRIES+="$(lower "$FQDN")|${PORT}|${UPGRADE}|${REL_ALLOWLIST}"$'\n'
    done

    # Pack-supplied entries reach the SAME checks, named against the manifest that supplied them
    # rather than against the base file. That is the point of validating here as well as in
    # validate_resolved: an operator reading "packs/foo/pack.yaml declares a wildcard" can fix it;
    # an operator reading it against policy/resolved/default.yaml has to work out where it came
    # from. `upgrade` defaults to false exactly as it does for a base entry.
    for ((k = 0; k < PACKS_LEN; k++)); do
      PN="${PACK_NAMES[$k]}"; PF="${PACK_FILES[$k]}"; REL_PF="packs/$PN/pack.yaml"
      PFQ_N="$(yq eval '.egress.runtime.allow_fqdns | length' "$PF")"
      for ((i = 0; i < PFQ_N; i++)); do
        PFQDN="$(yq eval ".egress.runtime.allow_fqdns[$i].fqdn" "$PF")"
        PPORT="$(yq eval ".egress.runtime.allow_fqdns[$i].port" "$PF")"
        if [[ "$(yq eval ".egress.runtime.allow_fqdns[$i] | has(\"upgrade\")" "$PF")" == "true" ]]; then
          PUPG="$(yq eval ".egress.runtime.allow_fqdns[$i].upgrade" "$PF")"
        else
          PUPG="false"
        fi
        [[ "$PUPG" == "true" || "$PUPG" == "false" ]] \
          || invalid "$REL_PF: egress.runtime.allow_fqdns[$i].upgrade must be true or false, found '$PUPG'"
        [[ "$PPORT" =~ ^[0-9]+$ ]] \
          || invalid "$REL_PF: egress.runtime.allow_fqdns[$i].port must be an integer, found '$PPORT'"
        [[ "$PFQDN" != *"*"* ]] \
          || invalid "$REL_PF: egress.runtime.allow_fqdns[$i].fqdn '$PFQDN' is a wildcard; the pod resolver matches exactly and a wildcard would reopen DNS exfiltration (R5.4)"
        [[ "${#PFQDN}" -le 253 && "$PFQDN" =~ $FQDN_RE ]] \
          || invalid "$REL_PF: egress.runtime.allow_fqdns[$i].fqdn '$PFQDN' is not a valid hostname; it would be interpolated into the mediator's Lua policy (01.3 SF-5)"
        ENTRIES+="$(lower "$PFQDN")|${PPORT}|${PUPG}|${REL_PF}"$'\n'
      done
    done

    # MCP http/sse servers compose their own declared egress into the listed agents' allowlists
    # (D18, Decision 8), under the same checks and the same collision rule as a pack's runtime
    # entries -- already validated above (shape, hostname, port), so this reads rather than
    # re-checks. `upgrade` is not a field MCP servers declare (Interface Contract 5); every
    # composed entry is `upgrade: false`. Source is `mcp:<server>` so a collision names it, and is
    # cut before emit exactly like a pack's source (`cut -d'|' -f1-3` below).
    for ((k = 0; k < MCP_SRV_N; k++)); do
      MS=".mcp.servers[$k]"
      MTRANS_K="$(yq eval "$MS.transport" "$PROFILE_FILE")"
      [[ "$MTRANS_K" == "http" || "$MTRANS_K" == "sse" ]] || continue
      MNAME_K="$(yq eval "$MS.name" "$PROFILE_FILE")"
      MAGENTS_K="$(yq eval "$MS.agents[]" "$PROFILE_FILE")"
      grep -Fxq "$agent" <<< "$MAGENTS_K" || continue
      MFQ_N="$(yq eval "$MS.egress.allow_fqdns | length" "$PROFILE_FILE")"
      for ((i = 0; i < MFQ_N; i++)); do
        MFQDN_K="$(yq eval "$MS.egress.allow_fqdns[$i].fqdn" "$PROFILE_FILE")"
        MPORT_K="$(yq eval "$MS.egress.allow_fqdns[$i].port" "$PROFILE_FILE")"
        ENTRIES+="$(lower "$MFQDN_K")|${MPORT_K}|false|${REL_PROFILE}#mcp:${MNAME_K}"$'\n'
      done
    done

    # Exclusions are declared, not hardcoded: an entry named in the profile's egress_exclusions is
    # NOT copied through, and the reason travels into the artifact (criterion 12, R10.3). Applied
    # to the MERGED set rather than to the base alone -- "entries this profile deliberately does
    # not grant" reads the same whichever input supplied the entry, and a profile that could
    # exclude a base entry but not the identical pack-supplied one would be a hole with no reason
    # behind it.
    KEPT=""
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      EF="${line%%|*}"
      # The allow entry was case-folded on the way into the accumulator, so the exclusion has to
      # be folded too or an uppercase `fqdn:` in the profile silently stops excluding anything.
      # DNS is case-insensitive; a comparison that is not would let a profile believe it had
      # withdrawn a destination it had not. Found by the Codex adversarial pass, 2026-09-08.
      EX_REASON="$(yq eval ".egress_exclusions[] | select(.agent == \"${agent}\" and (.fqdn | downcase) == \"${EF}\") | .reason // \"null\"" "$PROFILE_FILE")"
      [[ -z "$EX_REASON" || "$EX_REASON" == "null" ]] || continue
      KEPT+="${line}"$'\n'
    done <<< "$ENTRIES"
    ENTRIES="$KEPT"

    # Deterministic output, because SF-4's drift check is meaningless otherwise (Edge Case 2).
    # LC_ALL=C: the host is macOS and the compile stage is Debian, and a locale-dependent
    # collation would make the two sides disagree on ordering alone.
    UNIQ=""
    [[ -z "${ENTRIES//[[:space:]]/}" ]] \
      || UNIQ="$(cut -d'|' -f1-3 <<< "${ENTRIES%$'\n'}" | LC_ALL=C sort -u)"

    # A collision on (agent, fqdn, port) whose `upgrade` differs is REFUSED, naming both sources.
    # It is not merged in either direction: base-wins silently drops a pack's declared need,
    # pack-wins and OR let third-party content overwrite the base record for a destination the
    # base already governs (R5.14). `upgrade` is R5.9 metadata that the current render does not
    # read, so this is a contradictory POLICY RECORD rather than a live widening -- which is what
    # the message says, rather than claiming an enforcement consequence that does not exist yet.
    if [[ -n "$UNIQ" ]]; then
      DUPES="$(cut -d'|' -f1-2 <<< "$UNIQ" | LC_ALL=C sort | uniq -d)"
      if [[ -n "$DUPES" ]]; then
        while IFS= read -r dk; do
          [[ -n "$dk" ]] || continue
          # PREFIX match on the first two fields, done with awk rather than a regex. The previous
          # attempt built an ERE from the key and escaped only the dots -- but the key itself
          # contains a pipe, so `^api.example.com|443\|` was an ALTERNATION and matched anything
          # containing `443|`. An unanchored grep -F has the converse problem: `xapi.example.com`
          # contains `api.example.com`. Neither breaks the refusal; both mislead the operator
          # about which sources collided. Found by the Codex adversarial pass, 2026-09-08.
          SRCS="$(awk -F'|' -v k="$dk" '$1 "|" $2 == k {print $3 "|" $4}' <<< "${ENTRIES%$'\n'}" | LC_ALL=C sort -u | tr '\n' ' ')"
          refuse "agents.${agent}: conflicting R5.9 upgrade metadata for the same resolved destination ${dk%%|*} port ${dk##*|}. Sources (upgrade|origin): ${SRCS}-- one destination carries one record. Reconcile the base allowlist entry and the pack manifest rather than letting either silently overwrite the other"
        done <<< "$DUPES"
      fi
    fi

    echo "    allow_fqdns:"
    if [[ -z "$UNIQ" ]]; then
      echo "      []"
    else
      while IFS='|' read -r ef ep eu; do
        echo "      - {fqdn: ${ef}, port: ${ep}, upgrade: ${eu}}"
      done <<< "$UNIQ"
    fi

    # CIDRs compose the same way and dedup the same way, but there is no second field to conflict
    # over: normalise_cidr first, so `169.254.169.254` and `169.254.169.254/32` are one entry and
    # not two. The shipped mediator render REFUSES a non-empty list at start (control 1b) --
    # validate_resolved warns about that below; the refusal deliberately stays on the consumer
    # side, where 01.3 put it.
    CIDRS=""
    CIDR_N="$(yq eval ".agents.${agent}.allow_cidrs | length" "$ALLOWLIST")"
    for ((i = 0; i < CIDR_N; i++)); do
      C="$(yq eval ".agents.${agent}.allow_cidrs[$i]" "$ALLOWLIST")"
      CIDRS+="$(normalise_cidr "$C")"$'\n'
    done
    for ((k = 0; k < PACKS_LEN; k++)); do
      PF="${PACK_FILES[$k]}"
      PC_N="$(yq eval '.egress.runtime.allow_cidrs | length' "$PF")"
      for ((i = 0; i < PC_N; i++)); do
        C="$(yq eval ".egress.runtime.allow_cidrs[$i]" "$PF")"
        [[ -n "$C" && "$C" != "null" ]] \
          || invalid "packs/${PACK_NAMES[$k]}/pack.yaml: egress.runtime.allow_cidrs[$i] is empty"
        CIDRS+="$(normalise_cidr "$C")"$'\n'
      done
    done
    if [[ -z "${CIDRS//[[:space:]]/}" ]]; then
      echo "    allow_cidrs: []"
    else
      echo "    allow_cidrs:"
      LC_ALL=C sort -u <<< "${CIDRS%$'\n'}" | while IFS= read -r c; do echo "      - $c"; done
    fi

    MC="$(yq eval ".rate_limits.${agent}.max_concurrent" "$PROFILE_FILE")"
    BPS="$(yq eval ".rate_limits.${agent}.bytes_per_second" "$PROFILE_FILE")"
    echo "    limits: {max_concurrent: ${MC}, bytes_per_second: ${BPS}}"
  done <<< "$AGENTS"

  echo ""
  # The deny lists are copied from the base UNMODIFIED -- no pack contributes to them and a
  # manifest declaring a deny_* key is refused at resolution. Sorted and deduplicated for the same
  # reason every other list here is (Edge Case 2): the drift check is a byte comparison.
  echo "deny_cidrs:"
  DC=""
  DC_N="$(yq eval '.deny_cidrs | length' "$DENYLIST")"
  for ((i = 0; i < DC_N; i++)); do
    C="$(yq eval ".deny_cidrs[$i]" "$DENYLIST")"
    DC+="$(normalise_cidr "$C")"$'\n'
  done
  [[ -z "${DC//[[:space:]]/}" ]] \
    || LC_ALL=C sort -u <<< "${DC%$'\n'}" | while IFS= read -r c; do echo "  - $c"; done

  DF_N="$(yq eval '.deny_fqdns | length' "$DENYLIST")"
  if [[ "$DF_N" == "0" ]]; then
    echo "deny_fqdns: []"
  else
    echo "deny_fqdns:"
    DF=""
    for ((i = 0; i < DF_N; i++)); do
      DF+="$(yq eval ".deny_fqdns[$i]" "$DENYLIST")"$'\n'
    done
    LC_ALL=C sort -u <<< "${DF%$'\n'}" | while IFS= read -r d; do echo "  - $d"; done
  fi

  echo ""
  echo "# Entries present in ${REL_ALLOWLIST} and deliberately NOT granted by this profile."
  echo "# Recorded rather than dropped silently, so the decision is auditable (criterion 12)."
  EX_N="$(yq eval '.egress_exclusions | length' "$PROFILE_FILE")"
  if [[ "$EX_N" == "0" || "$EX_N" == "null" ]]; then
    echo "exclusions: []"
  else
    echo "exclusions:"
    # Sorted by (agent, fqdn) like every other list, so a reordering of the profile's own
    # `egress_exclusions` block does not move the artifact. The reason is free text and can
    # contain anything, so it is carried as the tail of the line rather than as a sort key.
    EXL=""
    for ((i = 0; i < EX_N; i++)); do
      EA="$(yq eval ".egress_exclusions[$i].agent" "$PROFILE_FILE")"
      EF="$(yq eval ".egress_exclusions[$i].fqdn" "$PROFILE_FILE")"
      ER="$(yq eval ".egress_exclusions[$i].reason" "$PROFILE_FILE")"
      # The reason is folded to one line: it is emitted inside a double-quoted YAML scalar, and a
      # literal newline there would produce an artifact that does not parse.
      ER="$(tr '\n' ' ' <<< "$ER" | sed -e 's/  */ /g' -e 's/ *$//')"
      EXL+="  - {agent: ${EA}, fqdn: ${EF}, reason: \"${ER}\"}"$'\n'
    done
    LC_ALL=C sort -u <<< "${EXL%$'\n'}"
  fi

  echo ""
  echo "startup_check:"
  echo "  allowed: {agent: $(yq eval '.startup_check.allowed.agent' "$PROFILE_FILE"), fqdn: $(yq eval '.startup_check.allowed.fqdn' "$PROFILE_FILE"), port: $(yq eval '.startup_check.allowed.port' "$PROFILE_FILE")}"
  echo "  denied: {ip: $(yq eval '.startup_check.denied.ip' "$PROFILE_FILE"), port: $(yq eval '.startup_check.denied.port' "$PROFILE_FILE")}"
  echo "  offline: $(yq eval '.startup_check.offline' "$PROFILE_FILE")"

  # ---- exports (02.1 SF-4, R9.9/D11) -----------------------------------------------------
  # A missing block resolves to all four true -- an operator who never heard of exports still
  # gets every export, the pre-02.1 default. An unknown key or a non-boolean is an INPUT error:
  # the toggle set is closed, because entrypoint.sh and recorder.sh each branch on exactly these
  # four names and a fifth key would be read by nothing, silently.
  echo ""
  echo "exports:"
  EXPORT_KEYS="egress_audit_log agent_action_log resolved_policy image_digest_sbom"
  HAS_EXPORTS_BLOCK="$(yq eval 'has("exports")' "$PROFILE_FILE")"
  if [[ "$HAS_EXPORTS_BLOCK" == "true" ]]; then
    require_tag "$PROFILE_FILE" '.exports' '!!map' \
      "$REL_PROFILE: field 'exports' must be a mapping of the four export toggles"
    PROFILE_EXPORT_KEYS="$(yq eval '.exports | keys | .[]' "$PROFILE_FILE")"
    while IFS= read -r pk; do
      [[ -z "$pk" ]] && continue
      case " $EXPORT_KEYS " in
        *" $pk "*) : ;;
        *) invalid "$REL_PROFILE: exports.${pk} is not a recognised export. The four exports are: ${EXPORT_KEYS}" ;;
      esac
    done <<< "$PROFILE_EXPORT_KEYS"
  fi
  for ek in $EXPORT_KEYS; do
    if [[ "$HAS_EXPORTS_BLOCK" == "true" && "$(yq eval ".exports | has(\"$ek\")" "$PROFILE_FILE")" == "true" ]]; then
      EV="$(yq eval ".exports.${ek}" "$PROFILE_FILE")"
      [[ "$EV" == "true" || "$EV" == "false" ]] \
        || invalid "$REL_PROFILE: exports.${ek} must be true or false, found '$EV'"
    else
      EV="true"
    fi
    echo "  ${ek}: ${EV}"
  done
} > "$TMP"

if [[ "$MODE" == "check" ]]; then
  [[ -f "$OUT" ]] || drift "$OUT does not exist. It is a committed artifact and the build refuses to ship without it -- run the compiler and commit the result."
  # compiled_at is the one line that legitimately differs between two runs of the same inputs.
  if diff -u <(grep -v '^compiled_at:' "$OUT") <(grep -v '^compiled_at:' "$TMP") > "$TMP.cmp"; then
    echo "compile-policy: $OUT is current"
    exit 0
  fi
  echo "compile-policy: DRIFT: $OUT does not match a fresh compile of its inputs." >&2
  echo "compile-policy: the artifact is generated (SC-6) -- recompile rather than hand-editing it." >&2
  cat "$TMP.cmp" >&2
  exit 4
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
