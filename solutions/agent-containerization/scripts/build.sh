#!/usr/bin/env bash
# Build one profile's pod images and record what was built (01.5 SF-6, R9.9, Edge Case 19).
#
#   bash scripts/build.sh                        # the `default` profile
#   bash scripts/build.sh --profile test-fixtures
#   bash scripts/build.sh --profile default --out .build-scratch/build
#
# WHY THIS EXISTS ALONGSIDE CI. The workflow publishes `agent-base`, which is
# profile-INDEPENDENT, and attests it. But D10 makes "the image" per-profile: the three
# agent images layer that profile's pack OS packages on the base, and those images have
# digests no CI run ever sees. R9.9 and the PRD's Outputs table make "image digest +
# SBOM" a default-produced artifact, so the per-profile half needs a producer here.
# 02.4's T18 and T45 verify the property; this script produces what they verify.
#
# IT DRIVES COMPOSE RATHER THAN `docker build`. The images an operator actually runs are
# the ones `docker compose up --build` produces. A second build path with its own
# argument list would record digests for images nobody runs the moment the two drifted --
# and the arguments are not trivial (six pins per agent, interpolated from pins.env).
# So this calls the same Compose files the README's entry point calls, with AGENT_PROFILE
# set, and re-tags the result.
#
# SBOM: NOT EMITTED LOCALLY, AND THE REASON IS MEASURED, NOT ASSUMED.
# Edge Case 13 recorded local buildx attestation as UNVERIFIED and pre-committed to this
# fallback if it did not hold. It does not hold on the pinned Docker Desktop:
#
#     $ docker buildx build --sbom=true --load ...
#     ERROR: failed to build: Attestation is not supported for the docker driver.
#     Switch to a different driver, or turn on the containerd image store, and try again.
#
# Docker Desktop's default `docker` driver cannot carry an attestation, and the two ways
# out both cost more than the MAY they satisfy: a `docker-container` builder drops
# attestations again on `--load` (the classic image store cannot hold them), and exporting
# an OCI tarball instead would produce an SBOM for an image Compose could not then run.
# So R10.7's SBOM half stays with the CI-published `agent-base`, and this script records
# identity only. If the operator turns on the containerd image store, `--sbom=true`
# becomes available and this decision is worth revisiting -- it is a driver limitation,
# not a missing tool.
#
# WHAT "DIGEST" MEANS HERE. A locally built image that was never pushed has no registry
# manifest digest -- it has an image ID, the sha256 of its config blob. That is what the
# record below carries, and it is labelled as such. It is stable and comparable across
# rebuilds on the same host, which is what SC-8 needs from it; it is NOT the same kind of
# identifier as MEDIATOR_BASE_DIGEST or AGENT_BASE_DIGEST, which name registry indexes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

[[ "${1:-}" != "-h" && "${1:-}" != "--help" ]] || { awk 'NR>1 && /^#/ {print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"; exit 0; }

PROFILE=default
OUT=.build-scratch/build

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; [[ -n "$PROFILE" ]] || { echo "build: --profile needs a value" >&2; exit 1; }; shift 2 ;;
    --out)     OUT="${2:-}";     [[ -n "$OUT" ]]     || { echo "build: --out needs a value" >&2; exit 1; };     shift 2 ;;
    *) echo "build: unknown argument: $1 (try --help)" >&2; exit 1 ;;
  esac
done

# The profile must exist before anything is built. `docker compose build` would happily
# accept AGENT_PROFILE=typo and fail deep inside the pack-plan stage with an error about
# a missing manifest path, which names the symptom rather than the mistake.
[[ -f "profiles/${PROFILE}.yaml" ]] \
  || { echo "build: no such profile: profiles/${PROFILE}.yaml" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || { echo "build: docker is required" >&2; exit 1; }

COMPOSE=(docker compose --env-file compose/pins.env -f compose/compose.yaml)

# Only the AGENT images vary by profile -- the pack set is theirs. The mediator image
# carries every committed resolved artifact (images/mediator/compile-stage.sh compiles
# them all) and selects among them at runtime via MEDIATOR_PROFILE, so it is built once
# and recorded once rather than rebuilt per profile under a name that would imply
# otherwise.
AGENTS=(claude codex agy)

echo "build: profile ${PROFILE}"
AGENT_PROFILE="$PROFILE" "${COMPOSE[@]}" build egress-mediator "${AGENTS[@]}"

mkdir -p "$OUT"
RECORD="${OUT}/${PROFILE}.images.txt"

# `docker image inspect --format {{.Id}}` and not `docker images -q`: the short form
# truncates, and a truncated identifier is not one you can compare against a registry.
record_one() {
  local tag="$1" name="$2" id
  id="$(docker image inspect --format '{{.Id}}' "$tag")" \
    || { echo "build: ${tag} was not built" >&2; exit 2; }
  printf '%-28s %s\n' "$name" "$id"
}

{
  echo "# Per-profile image identity for profile '${PROFILE}'."
  echo "# Produced by scripts/build.sh. These are image IDs (config blob sha256) for"
  echo "# locally built images, NOT registry manifest digests -- see the script header."
  echo "# No SBOM: the Docker driver cannot carry an attestation (Edge Case 13, measured)."
  echo "# Built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  for a in "${AGENTS[@]}"; do
    docker tag "sandboxed-agent/${a}:local" "sandboxed-agent/${a}:${PROFILE}"
    record_one "sandboxed-agent/${a}:${PROFILE}" "sandboxed-agent/${a}"
  done
  record_one "sandboxed-agent/mediator:local" "sandboxed-agent/mediator"
} | tee "$RECORD"

echo
echo "build: recorded ${RECORD}"
echo "build: the agent images are also tagged :${PROFILE}, so a second profile's build does not"
echo "build: silently replace this one's -- Compose's own :local tag is reused by every profile."
echo
# AGENT_PROFILE now selects the mediator's runtime profile as well as the agents' pack
# set (compose.yaml, 01.5 SF-6), so the run command carries the same variable this build
# used. Printing it is not decoration: the pairing is the thing that was previously
# possible to get wrong, and a build that names the profile but not the run leaves the
# operator to re-derive it.
echo "build: run this profile with"
echo "build:   AGENT_PROFILE=${PROFILE} docker compose --env-file compose/pins.env \\"
echo "build:     -f compose/compose.yaml -f compose/overrides/default.yaml up -d"
