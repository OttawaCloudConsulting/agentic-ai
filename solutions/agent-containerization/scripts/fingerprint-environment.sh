#!/usr/bin/env bash
# Environment fingerprint for one profile (Feature 02.4, Decision 4, Interface Contract 5).
#
# Emits one normalised JSON document to stdout, covering what is actually installed in a
# profile's already-built images, plus the rendered compose config and resolved policy that
# selected them. It never starts the pod (R12.9) -- it inspects built images with
# `docker run --rm --entrypoint /bin/sh` and reads on-disk artifacts (policy/resolved,
# compose/pins.env).
#
# T18's fingerprint half passes when the build host's and the second Mac's documents diff
# clean with `commit` excluded: `diff <(jq -S 'del(.commit)' ref) <(jq -S 'del(.commit)' clean)`.
# `commit` is carried but excluded from the comparison so a README-only fix landing between
# the reference and the re-run does not register as a difference (Decision 4). Volatile
# per-build values (image IDs, created timestamps, container IDs) are never emitted.
#
# Usage:
#   bash scripts/fingerprint-environment.sh <profile>
#
# Requires the profile's images to already be built (`docker compose ... build` for that
# profile's override). Requires: docker, jq, yq, git.
#
# Exit codes: 0 ok  1 usage/missing tool  2 profile not found  3 an image is not built

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

die_usage() { echo "fingerprint-environment: $*" >&2; exit 1; }
die_profile() { echo "fingerprint-environment: $*" >&2; exit 2; }
die_image() { echo "fingerprint-environment: $*" >&2; exit 3; }

for c in docker jq yq git; do
  command -v "$c" >/dev/null 2>&1 || die_usage "$c is required"
done

PROFILE="${1:-}"
[[ -n "$PROFILE" ]] || die_usage "usage: fingerprint-environment.sh <profile>"
[[ -f "profiles/${PROFILE}.yaml" ]] || die_profile "no such profile: profiles/${PROFILE}.yaml"
[[ -f "compose/overrides/${PROFILE}.yaml" ]] \
  || die_profile "no compose/overrides/${PROFILE}.yaml -- this profile layers no same-named override"

AGENTS=(claude codex agy)
AGENT_IMAGE() { echo "sandboxed-agent/$1:local"; }
MEDIATOR_IMAGE="sandboxed-agent/mediator:local"

for img in "$(AGENT_IMAGE claude)" "$(AGENT_IMAGE codex)" "$(AGENT_IMAGE agy)" "$MEDIATOR_IMAGE"; do
  docker image inspect "$img" >/dev/null 2>&1 \
    || die_image "$img is not built -- build the '${PROFILE}' profile first"
done

sha() { sha256sum | awk '{print $1}'; }

in_image() {
  # in_image <image> <sh -c command>
  docker run --rm --entrypoint /bin/sh "$1" -c "$2"
}

# The final agent image has no `dpkg`/`dpkg-query` binary (R7.19 condition 3 --
# images/remove-package-managers.sh strips them). `/var/lib/dpkg/status` is deliberately
# kept for exactly this reason (SF-6's SBOM attestation reads it too), so fall back to
# parsing it directly when the binary is gone. The mediator image keeps its package
# manager, so `dpkg-query` there is the normal path.
DPKG_LIST_CMD="if command -v dpkg-query >/dev/null 2>&1; then dpkg-query -W -f='\${Package} \${Version}\n'; else awk '/^Package: /{p=\$2} /^Version: /{print p, \$2}' /var/lib/dpkg/status; fi | sort"

# --- commit ------------------------------------------------------------------------------

COMMIT="$(git rev-parse HEAD)"

# --- pins.env base digests (Contract 5's *_digest fields) --------------------------------

AGENT_BASE_DIGEST="$(grep -m1 '^AGENT_BASE_DIGEST=' compose/pins.env | cut -d= -f2-)"
MEDIATOR_BASE_DIGEST="$(grep -m1 '^MEDIATOR_BASE_DIGEST=' compose/pins.env | cut -d= -f2-)"
NODE_BASE_DIGEST="$(grep -m1 '^NODE_BASE_DIGEST=' compose/pins.env | cut -d= -f2-)"

# --- resolved policy hash -----------------------------------------------------------------

[[ -f "policy/resolved/${PROFILE}.yaml" ]] \
  || die_profile "policy/resolved/${PROFILE}.yaml missing -- run scripts/compile-policy-build.sh first"
RESOLVED_POLICY_SHA256="$(sha < "policy/resolved/${PROFILE}.yaml")"

# --- rendered compose config hash, checkout root normalised to <ROOT> --------------------

REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
COMPOSE_CONFIG_SHA256="$(
  docker compose --env-file compose/pins.env \
    -f compose/compose.yaml -f "compose/overrides/${PROFILE}.yaml" config \
    | sed "s#${REPO_ROOT}#<ROOT>#g" \
    | sha
)"

# --- per-agent versions and content hashes -------------------------------------------------

agent_json() {
  local a="$1" img
  img="$(AGENT_IMAGE "$a")"

  local version dpkg_sha256 bin_sha256 npm_tree_sha256 pack_roots_sha256

  version="$(in_image "$img" "$a --version" | tr -d '\r\n')"

  dpkg_sha256="$(in_image "$img" "$DPKG_LIST_CMD" | sha)"

  # The agent's own installed entry point, resolved through any npm-created symlink so the
  # hash covers the real file content, not a symlink target path.
  bin_sha256="$(in_image "$img" "readlink -f \"\$(command -v $a)\" | xargs cat" | sha)"

  # npm itself is stripped from the final image (R7.19 condition 4), so `npm ls` cannot
  # run there. Hash the global install root's content directly instead -- claude and codex
  # land under /usr/local/lib/node_modules; agy is a standalone binary (no npm tree), so
  # this is the well-defined empty hash for that agent.
  npm_tree_sha256="$(in_image "$img" "tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - /usr/local/lib/node_modules 2>/dev/null || true" | sha)"

  # /opt/agent-pack is every shipped pack's install root (images/Dockerfile). Sorted tar
  # content (not just names) so a same-named, different-content file is caught.
  pack_roots_sha256="$(in_image "$img" "tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - /opt/agent-pack 2>/dev/null || true" | sha)"

  jq -n \
    --arg version "$version" \
    --arg dpkg_sha256 "$dpkg_sha256" \
    --arg bin_sha256 "$bin_sha256" \
    --arg npm_tree_sha256 "$npm_tree_sha256" \
    --arg pack_roots_sha256 "$pack_roots_sha256" \
    '{version: $version, dpkg_sha256: $dpkg_sha256, bin_sha256: $bin_sha256,
      npm_tree_sha256: $npm_tree_sha256, pack_roots_sha256: $pack_roots_sha256}'
}

CLAUDE_JSON="$(agent_json claude)"
CODEX_JSON="$(agent_json codex)"
AGY_JSON="$(agent_json agy)"

# --- mediator versions and package hash ----------------------------------------------------

MEDIATOR_SQUID_VERSION="$(in_image "$MEDIATOR_IMAGE" "dpkg-query -W -f='\${Version}' squid-openssl 2>/dev/null || dpkg-query -W -f='\${Version}' squid 2>/dev/null || true")"
MEDIATOR_UNBOUND_VERSION="$(in_image "$MEDIATOR_IMAGE" "dpkg-query -W -f='\${Version}' unbound 2>/dev/null || true")"
MEDIATOR_DNSDIST_VERSION="$(in_image "$MEDIATOR_IMAGE" "dpkg-query -W -f='\${Version}' dnsdist 2>/dev/null || true")"
MEDIATOR_DPKG_SHA256="$(in_image "$MEDIATOR_IMAGE" "$DPKG_LIST_CMD" | sha)"

MEDIATOR_JSON="$(jq -n \
  --arg squid "$MEDIATOR_SQUID_VERSION" \
  --arg unbound "$MEDIATOR_UNBOUND_VERSION" \
  --arg dnsdist "$MEDIATOR_DNSDIST_VERSION" \
  --arg dpkg_sha256 "$MEDIATOR_DPKG_SHA256" \
  '{squid: $squid, unbound: $unbound, dnsdist: $dnsdist, dpkg_sha256: $dpkg_sha256}')"

# --- assemble -------------------------------------------------------------------------------

jq -n \
  --argjson schema 1 \
  --arg profile "$PROFILE" \
  --arg commit "$COMMIT" \
  --arg agent_base_digest "$AGENT_BASE_DIGEST" \
  --arg mediator_base_digest "$MEDIATOR_BASE_DIGEST" \
  --arg node_base_digest "$NODE_BASE_DIGEST" \
  --arg resolved_policy_sha256 "$RESOLVED_POLICY_SHA256" \
  --arg compose_config_sha256 "$COMPOSE_CONFIG_SHA256" \
  --argjson claude "$CLAUDE_JSON" \
  --argjson codex "$CODEX_JSON" \
  --argjson agy "$AGY_JSON" \
  --argjson mediator "$MEDIATOR_JSON" \
  '{schema: $schema, profile: $profile, commit: $commit,
    agent_base_digest: $agent_base_digest, mediator_base_digest: $mediator_base_digest,
    node_base_digest: $node_base_digest, resolved_policy_sha256: $resolved_policy_sha256,
    compose_config_sha256: $compose_config_sha256,
    agents: {claude: $claude, codex: $codex, agy: $agy},
    mediator: $mediator}'
