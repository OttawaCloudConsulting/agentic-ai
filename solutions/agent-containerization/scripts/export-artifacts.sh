#!/usr/bin/env bash
# Export-artifact producer (02.1 SF-4, R9.9, Decision 6, Interface Contract 6).
#
# Copies the two FILE exports -- resolved_policy and image_digest_sbom -- into DIR when
# their toggle is true, and writes DIR/MANIFEST naming the state of both. The other two
# exports (egress_audit_log, agent_action_log) are RELAYS, not files: their toggle is
# read and gated at their own producer (images/mediator/entrypoint.sh,
# images/recorder/recorder.sh) and this script has nothing to copy for them.
#
#   bash scripts/export-artifacts.sh --resolved PATH --out DIR
#
# Exit codes: 0 ok  1 usage error  2 unreadable or invalid resolved artifact, or an
#             enabled file export with nothing to ship
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

[[ "${1:-}" != "-h" && "${1:-}" != "--help" ]] \
  || { awk 'NR>1 && /^#/ {print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"; exit 0; }

RESOLVED=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resolved) RESOLVED="${2:-}"; shift 2 ;;
    --out)      OUT="${2:-}"; shift 2 ;;
    *) echo "export-artifacts: unknown argument: $1 (try --help)" >&2; exit 1 ;;
  esac
done

[[ -n "$RESOLVED" ]] || { echo "export-artifacts: --resolved PATH is required" >&2; exit 1; }
[[ -n "$OUT" ]]      || { echo "export-artifacts: --out DIR is required" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "export-artifacts: yq is required" >&2; exit 1; }

[[ -f "$RESOLVED" ]] || { echo "export-artifacts: $RESOLVED does not exist" >&2; exit 2; }
yq eval '.' "$RESOLVED" >/dev/null 2>&1 \
  || { echo "export-artifacts: $RESOLVED does not parse as YAML" >&2; exit 2; }

PROFILE="$(yq eval '.profile' "$RESOLVED")"
[[ -n "$PROFILE" && "$PROFILE" != "null" ]] \
  || { echo "export-artifacts: $RESOLVED has no 'profile' field" >&2; exit 2; }

for k in resolved_policy image_digest_sbom; do
  v="$(yq eval ".exports.$k" "$RESOLVED" 2>/dev/null || echo '')"
  [[ "$v" == "true" || "$v" == "false" ]] \
    || { echo "export-artifacts: $RESOLVED: exports.$k must be true or false, found '$v'" >&2; exit 2; }
done

mkdir -p "$OUT"
MANIFEST="$OUT/MANIFEST"
: > "$MANIFEST"

# resolved_policy: a copy of the artifact itself. It is already the reviewed,
# committed record (SC-6); this export just puts a copy where an operator collecting
# artifacts for a run would look.
if [[ "$(yq eval '.exports.resolved_policy' "$RESOLVED")" == "true" ]]; then
  cp "$RESOLVED" "$OUT/resolved-policy.yaml"
  sha="$(sha256sum "$OUT/resolved-policy.yaml" | cut -d' ' -f1)"
  echo "resolved_policy enabled ${sha} resolved-policy.yaml" >> "$MANIFEST"
else
  echo "resolved_policy disabled" >> "$MANIFEST"
fi

# image_digest_sbom: the build record scripts/build.sh writes for this profile, plus
# any SBOM file that exists beside it. No SBOM is produced locally today (build.sh's
# header: the Docker driver cannot carry an attestation) -- this ships one the moment
# that changes, with no edit here.
if [[ "$(yq eval '.exports.image_digest_sbom' "$RESOLVED")" == "true" ]]; then
  BUILD_RECORD=".build-scratch/build/${PROFILE}.images.txt"
  [[ -f "$BUILD_RECORD" ]] \
    || { echo "export-artifacts: exports.image_digest_sbom is enabled but ${BUILD_RECORD} does not exist -- run 'bash scripts/build.sh --profile ${PROFILE}' first" >&2; exit 2; }
  cp "$BUILD_RECORD" "$OUT/image-digests.txt"
  sha="$(sha256sum "$OUT/image-digests.txt" | cut -d' ' -f1)"
  echo "image_digest_sbom enabled ${sha} image-digests.txt" >> "$MANIFEST"
  shopt -s nullglob
  for sbom in ".build-scratch/build/${PROFILE}."*.sbom.json; do
    cp "$sbom" "$OUT/"
  done
  shopt -u nullglob
else
  echo "image_digest_sbom disabled" >> "$MANIFEST"
fi

echo "export-artifacts: wrote ${MANIFEST}"
