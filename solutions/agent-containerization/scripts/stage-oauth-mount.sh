#!/usr/bin/env bash
# oauth-mount credential staging (01.4 SF-4, R4.13-R4.15, R4.17) -- HOST-SIDE, run BEFORE the
# one-shot bootstrap invocation. The host-side counterpart of scripts/scrub-gitconfig.sh, and
# for the same reason: the filtering happens before the material crosses the boundary, so there
# is no unfiltered copy inside the container for a compromised agent to read.
#
# It writes exactly TWO files into compose/generated/oauth-src/ -- the dedicated directory
# R4.14 requires, never the operator's ~/.codex:
#
#   auth.json           the host credential set with OPENAI_API_KEY REMOVED
#   accepted-risk.yaml  the profile's oauth_mount.codex.accepted_risk record (R4.17)
#
# WHY THE KEY IS STRIPPED -- test validity before security. The host auth.json's top-level keys
# are OPENAI_API_KEY, auth_mode, last_refresh and tokens: one file carrying BOTH an OAuth token
# set and a raw API key. Mounted as-is, the oauth-mount cell could authenticate off the API key
# and pass green while the OAuth path is broken -- which is precisely the cell this exists to
# prove. It also keeps E2's blast radius (an unexpiring API key) out of row V3's.
#
# WHY THE RISK RECORD IS STAGED TOO. Interface Contract 3 requires bootstrap-auth to refuse a
# credential source that carries no accepted_risk record, but the profile does not exist inside
# the container. This script is the bridge: it reads the record from the named profile, validates
# its five fields, and writes it alongside the credential. The acknowledgement therefore travels
# WITH the material it is about, and 01.5's build-time refusal (T27) validates the same shape in
# the same profile.
#
# Usage:
#   bash scripts/stage-oauth-mount.sh [--profile NAME] [--source PATH]
#
#   --profile   profile carrying oauth_mount.codex.accepted_risk. Default: oauth-mount
#   --source    host credential file. Default: $CODEX_HOME/auth.json, else ~/.codex/auth.json
#
# THIS SCRIPT NEVER PRINTS CREDENTIAL MATERIAL. It reports paths and key names, never values.
set -euo pipefail

SOLUTION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$SOLUTION_ROOT/compose/generated/oauth-src"

PROFILE="oauth-mount"
SRC="${CODEX_HOME:-$HOME/.codex}/auth.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile needs a name}"; shift 2 ;;
    --source)  SRC="${2:?--source needs a path}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "stage-oauth-mount: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

fail() { echo "stage-oauth-mount: FAILED -- $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq is required (bash scripts/install-deps.sh checks for it)"
command -v yq >/dev/null 2>&1 || fail "yq is required (bash scripts/install-deps.sh checks for it)"

PROFILE_FILE="$SOLUTION_ROOT/profiles/${PROFILE}.yaml"
[ -f "$PROFILE_FILE" ] || fail "no profile at $PROFILE_FILE"

# --------------------------------------------------------------------------- the host source
#
# A Keychain-backed install has no usable auth.json to stage, and the failure to catch is the
# STALE one: a file left behind by an earlier file-backed login reads as valid here and copies a
# dead credential into the pod. Checked against the host config.toml rather than inferred.
HOST_CFG="${CODEX_HOME:-$HOME/.codex}/config.toml"
if [ -f "$HOST_CFG" ] \
   && grep -Eq '^[[:space:]]*cli_auth_credentials_store[[:space:]]*=[[:space:]]*"keyring"' "$HOST_CFG"; then
  fail "$HOST_CFG sets cli_auth_credentials_store = \"keyring\", so $SRC is not this install's \
live credential. Set it to \"file\" (or unset it, if file is your install's default), log in \
again on the host, then re-run this script."
fi

[ -f "$SRC" ] || fail "no credential at $SRC. Log in on the HOST first: codex login"
jq -e . "$SRC" >/dev/null 2>&1 || fail "$SRC does not parse as JSON"
jq -e '.tokens.refresh_token | strings | length > 0' "$SRC" >/dev/null 2>&1 \
  || fail "$SRC carries no tokens.refresh_token -- it is not an OAuth credential set. \
A file holding only OPENAI_API_KEY is an API key, which is AUTH_MODE=apikey, not oauth-mount."

# --------------------------------------------------------------------------- the risk record
#
# Five fields, all required, and mount_mode is the one with a fixed value: R4.13 permits `ro`
# and nothing else. A missing field fails HERE rather than at bootstrap, because the operator
# who can fix it is standing at this terminal.
RISK_PATH='.oauth_mount.codex.accepted_risk'
[ "$(yq eval "has(\"oauth_mount\")" "$PROFILE_FILE")" = "true" ] \
  || fail "$PROFILE_FILE has no oauth_mount block. R4.17 requires the risk to be recorded in the \
profile before the credential is staged -- see profiles/oauth-mount.yaml for the shape."

for field in file mount_mode revocation_path blast_radius rotation; do
  [ "$(yq eval "$RISK_PATH | has(\"$field\")" "$PROFILE_FILE")" = "true" ] \
    || fail "$PROFILE_FILE: ${RISK_PATH#.}.$field is missing (R4.17)"
  v="$(yq eval "$RISK_PATH.$field" "$PROFILE_FILE")"
  [ -n "$v" ] && [ "$v" != "null" ] || fail "$PROFILE_FILE: ${RISK_PATH#.}.$field is empty (R4.17)"
done

mount_mode="$(yq eval "$RISK_PATH.mount_mode" "$PROFILE_FILE")"
[ "$mount_mode" = "ro" ] \
  || fail "$PROFILE_FILE: ${RISK_PATH#.}.mount_mode is '$mount_mode'; 'ro' is the only permitted \
value (R4.13). The Compose fragment mounts :ro regardless -- a profile claiming otherwise would \
be a record that does not describe what happens."

# The profile's auth_mode must actually select the mode, or the operator stages a credential for
# a pod that will never read it. compose/overrides/oauth-mount.bootstrap.yaml sets AUTH_MODE for
# the bootstrap invocation itself; this catches the steady-state half.
codex_mode="$(yq eval '.auth_mode.codex' "$PROFILE_FILE")"
[ "$codex_mode" = "oauth-mount" ] \
  || fail "$PROFILE_FILE sets auth_mode.codex: $codex_mode, not oauth-mount. Staging a credential \
for a profile that does not select the mode leaves it unused on the host side of the boundary."

# --------------------------------------------------------------------------- write the staging
mkdir -p "$OUT_DIR"
chmod 700 "$SOLUTION_ROOT/compose/generated" "$OUT_DIR"

# `del`, not a whitelist of keys to keep: an unrecognised future key belongs to the OAuth set
# until shown otherwise, and dropping it silently would break the mode on a version bump. The
# key that must not cross is named explicitly, and the self-check below proves it did not.
jq 'del(.OPENAI_API_KEY)' "$SRC" > "$OUT_DIR/auth.json"
chmod 600 "$OUT_DIR/auth.json"

{
  printf '%s\n' \
    '# Generated by scripts/stage-oauth-mount.sh (R4.17). Do not edit; do not commit.' \
    "# Source profile: profiles/${PROFILE}.yaml" \
    '#' \
    '# bootstrap-auth.sh refuses to copy the credential beside this file if this record is' \
    '# absent or incomplete (exit 3). 01.5 moves the same refusal to build time (T27).'
  yq eval "$RISK_PATH" "$PROFILE_FILE"
} > "$OUT_DIR/accepted-risk.yaml"
chmod 600 "$OUT_DIR/accepted-risk.yaml"

# --------------------------------------------------------------------------- self-verification
#
# The artifact is checked, not the intent. SF-5 asserts the same property on the MOUNTED source;
# failing here is cheaper, and a staged file carrying the API key would make that cell pass for
# the wrong reason.
fail_count=0

if jq -e 'has("OPENAI_API_KEY")' "$OUT_DIR/auth.json" >/dev/null 2>&1; then
  echo "stage-oauth-mount: FAILED -- OPENAI_API_KEY survived the strip" >&2
  fail_count=1
fi
if ! jq -e '.tokens.refresh_token | strings | length > 0' "$OUT_DIR/auth.json" >/dev/null 2>&1; then
  echo "stage-oauth-mount: FAILED -- the staged credential carries no tokens.refresh_token" >&2
  fail_count=1
fi
if [ "$fail_count" -ne 0 ]; then
  rm -f "$OUT_DIR/auth.json" "$OUT_DIR/accepted-risk.yaml"
  exit 1
fi

echo "stage-oauth-mount: staged $OUT_DIR/auth.json (OPENAI_API_KEY removed) and accepted-risk.yaml"
echo "stage-oauth-mount: this is a ONE-SHOT bootstrap source. codex ROLLS its refresh token, so the"
echo "stage-oauth-mount: container's first refresh supersedes the host copy -- expect to run"
echo "stage-oauth-mount: 'codex login' on the host again. See profiles/${PROFILE}.yaml, accepted_risk.rotation."
