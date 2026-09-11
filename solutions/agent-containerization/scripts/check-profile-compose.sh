#!/usr/bin/env bash
# Assert a profile's hand-authored Compose override against `default` (Feature 02.3,
# Decision 2, Interface Contract 4).
#
# A Compose fragment cannot read the profile it is layered under (build-cache.yaml's own
# limit, 01.5), so `compose/overrides/<profile>.yaml` is hand-authored rather than
# compiler-generated, and this script is the host-side check that a hand-authored file did
# not drift. It asserts two things about the RENDERED `docker compose config`, not the
# source YAML -- a rendered comparison catches an anchor/merge mistake a source diff would
# not:
#
#   (a) each agent's secret set, minus the default baseline, equals EXACTLY the set
#       derived from the selected packs' `credentials` (Interface Contract 1), in both
#       directions. A missing secret fails; an extra one is residue and fails (R7.5).
#   (b) every other part of each rendered agent service equals default's. The only
#       permitted differences are `secrets` and the `PROFILE` build argument, and for the
#       mediator only `MEDIATOR_PROFILE`. This also catches a drifted workspace mount or
#       resource limit in a hand-authored override.
#
# Usage:
#   bash scripts/check-profile-compose.sh --profile NAME [--credentials-dir DIR]
#
# Exit codes: 0 ok  1 usage  2 an unrenderable profile or override
#             3 a secret-set mismatch (missing or residue)
#             4 any other service difference from `default` (naming the path)
#
# `--credentials-dir` points PACK_CREDENTIALS_DIR at a scratch tree of dummy secret files,
# so a profile with a pack credential renders with no real operator secret staged. Compose
# does not validate a `file:` secret source at `config` time (only at `up`), so this needs
# no dummy file to actually exist -- but a caller that also intends to `up` against the
# same render should point it at real dummy files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

die_usage()   { echo "check-profile-compose: $*" >&2; exit 1; }
die_render()  { echo "check-profile-compose: $*" >&2; exit 2; }
die_secrets() { echo "check-profile-compose: $*" >&2; exit 3; }
die_drift()   { echo "check-profile-compose: $*" >&2; exit 4; }

PROFILE=""
CREDS_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; [[ -n "$PROFILE" ]] || die_usage "--profile needs a value"; shift 2 ;;
    --credentials-dir) CREDS_DIR="${2:-}"; [[ -n "$CREDS_DIR" ]] || die_usage "--credentials-dir needs a value"; shift 2 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done
[[ -n "$PROFILE" ]] || die_usage "--profile is required"

command -v docker >/dev/null 2>&1 || die_usage "docker is required"
command -v yq     >/dev/null 2>&1 || die_usage "yq is required"

[[ -f "profiles/${PROFILE}.yaml" ]] || die_usage "no such profile: profiles/${PROFILE}.yaml"
[[ -f "compose/overrides/${PROFILE}.yaml" ]] \
  || die_usage "no compose/overrides/${PROFILE}.yaml -- this profile layers no same-named override"

AGENTS=(claude codex agy)

render() {
  local profile="$1" out="$2"
  local -a env=(AGENT_PROFILE="$profile")
  [[ -z "$CREDS_DIR" ]] || env+=(PACK_CREDENTIALS_DIR="$CREDS_DIR")
  env "${env[@]}" docker compose --env-file compose/pins.env \
    -f compose/compose.yaml -f "compose/overrides/${profile}.yaml" config \
    > "$out" 2> "${out}.err" \
    || { cat "${out}.err" >&2; die_render "profile '${profile}' does not render (see above)"; }
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

render default   "$TMP/default.yaml"
render "$PROFILE" "$TMP/profile.yaml"

# --- (a) secret-set delta, derived from the manifests, not hardcoded -------------------
expected_secrets() {
  # pack-<pack>-<cred> for every credential of every pack the profile selects. Interface
  # Contract 1's naming rule, applied here the same way the pack-install plan applies it.
  local pcount pname ccount cname i j
  pcount="$(yq eval '.packs | length' "profiles/${PROFILE}.yaml")"
  for ((i = 0; i < pcount; i++)); do
    pname="$(yq eval ".packs[$i]" "profiles/${PROFILE}.yaml")"
    local mf="packs/${pname}/pack.yaml"
    [[ -f "$mf" ]] || die_usage "profile '${PROFILE}' selects pack '${pname}', which does not resolve to ${mf}"
    ccount="$(yq eval '.credentials | length' "$mf")"
    for ((j = 0; j < ccount; j++)); do
      cname="$(yq eval ".credentials[$j].name" "$mf")"
      echo "pack-${pname}-${cname}"
    done
  done
}
EXPECTED_SECRETS="$(expected_secrets | LC_ALL=C sort -u)"

secrets_of() {
  # `docker compose config` normalizes EVERY secret reference -- short-syntax entries in
  # compose.yaml included -- to the long {source, target} form (measured against Compose
  # v2.38.2). A bare `yq eval '...secrets[]'` therefore emits each entry as a two-line
  # mapping, and comm/sort downstream would treat each of those lines as its own set member
  # rather than as one secret name. Extract just `.source` (falling back to the scalar
  # itself for a hypothetical short-form render) so this stays one name per line regardless
  # of which form the installed Compose version renders (Feature 02.3 SF-5 fix).
  local rendered="$1" agent="$2"
  yq eval -o=json ".services.${agent}.secrets // []" "$rendered" 2>/dev/null \
    | jq -r '.[] | if type == "object" then .source else . end' \
    | LC_ALL=C sort -u
}

secrets_ok=1
for a in "${AGENTS[@]}"; do
  base="$(secrets_of "$TMP/default.yaml" "$a")"
  prof="$(secrets_of "$TMP/profile.yaml" "$a")"
  # base is a SUBSET of prof for every profile: the default identity secrets are never
  # removed, only added to. The delta -- prof minus base -- is what is compared to the
  # expected pack-derived set.
  delta="$(comm -13 <(printf '%s\n' "$base") <(printf '%s\n' "$prof") 2>/dev/null || true)"
  missing="$(comm -23 <(printf '%s\n' "$EXPECTED_SECRETS") <(printf '%s\n' "$delta") 2>/dev/null || true)"
  residue="$(comm -13 <(printf '%s\n' "$EXPECTED_SECRETS") <(printf '%s\n' "$delta") 2>/dev/null || true)"
  if [[ -n "$missing" || -n "$residue" ]]; then
    secrets_ok=0
    echo "check-profile-compose: agent '${a}': secret-set mismatch" >&2
    [[ -z "$missing" ]] || { echo "  missing (expected, not present):" >&2; sed 's/^/    /' <<< "$missing" >&2; }
    [[ -z "$residue" ]] || { echo "  residue (present, not expected):" >&2; sed 's/^/    /' <<< "$residue" >&2; }
  fi
done
[[ "$secrets_ok" == 1 ]] \
  || die_secrets "profile '${PROFILE}' secret set does not equal the default baseline plus exactly the selected packs' credentials (R7.5, R8.2)"

# --- (b) every other field equals default's, apart from secrets and the two named
#         build args -----------------------------------------------------------------
normalise() {
  local rendered="$1" service="$2"
  yq eval ".services.${service} | del(.secrets) | del(.build.args.PROFILE) | del(.environment.MEDIATOR_PROFILE) | (.. | select(tag == \"!!seq\")) |= sort" "$rendered"
}

drift_found=0
for a in "${AGENTS[@]}" egress-mediator; do
  if ! diff -u <(normalise "$TMP/default.yaml" "$a") <(normalise "$TMP/profile.yaml" "$a") > "$TMP/${a}.diff"; then
    drift_found=1
    echo "check-profile-compose: services.${a} differs from default beyond secrets/PROFILE/MEDIATOR_PROFILE:" >&2
    sed 's/^/  /' "$TMP/${a}.diff" >&2
  fi
done
[[ "$drift_found" == 0 ]] \
  || die_drift "profile '${PROFILE}' diverges from default outside the permitted fields (Decision 2 (b))"

echo "check-profile-compose: profile '${PROFILE}' ok -- secret set matches the manifests, no other drift from default"
