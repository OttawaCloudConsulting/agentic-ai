#!/usr/bin/env bash
# Refresh the committed resolved-policy artifacts THROUGH the mediator's build stage
# (01.5 SF-4, Edge Case 17).
#
#   bash scripts/compile-policy-build.sh
#
# Why this exists rather than "just run scripts/compile-policy.sh". The authoritative
# compile happens inside the mediator image; the committed artifacts under
# policy/resolved/ are compared against it, and the build FAILS on any difference
# (Interface Contract 4). Two emitters -- a Homebrew yq on the host and the pinned yq
# in the image -- would make that check fire on identical policy the first time the
# two versions disagreed about quoting or ordering. Edge Case 17 chose the resolution:
# run the HOST invocation through the build stage, so there is exactly one emitter.
#
# The measured position on 2026-09-08 was that the two yq versions produce
# byte-identical output on this schema, packs included -- so the divergence this
# closes is latent, not active. That is an argument for the check being cheap today,
# not for the second emitter being safe tomorrow.
#
# scripts/compile-policy.sh keeps its CLI unchanged and stays the inner
# implementation: this is the wrapper Edge Case 17's first obligation left to SF-4,
# taken in the form the plan called its default reading, so no host-surface deviation
# is recorded. Running the compiler directly still works and is still what
# policy/resolved/README.md documents for a fresh clone -- it just compiles with
# whatever yq the host has.
#
# The refreshed artifact is a REVIEWED change (R5.14, SC-6): this script writes it and
# prints the diff, and committing it is deliberately still the operator's act.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

[[ "${1:-}" != "-h" && "${1:-}" != "--help" ]] || { sed -n '2,28p' "${BASH_SOURCE[0]}"; exit 0; }
[[ $# -eq 0 ]] || { echo "compile-policy-build: unknown argument: $1" >&2; exit 1; }

command -v docker >/dev/null 2>&1 \
  || { echo "compile-policy-build: docker is required. To compile with the host's own yq instead: bash scripts/compile-policy.sh --profile <name>" >&2; exit 1; }

# The same pins Compose passes, so the refresh runs against the image the pod runs.
# Absent, the Dockerfile's own ARG defaults apply and are the same values -- which is
# what keeps a bare `docker build` reproducible.
BUILD_ARGS=()
if [[ -f compose/pins.env ]]; then
  # shellcheck disable=SC1091
  set -a; . compose/pins.env; set +a
  for a in MEDIATOR_BASE_DIGEST YQ_VERSION YQ_SHA256_ARM64 YQ_SHA256_AMD64; do
    [[ -z "${!a:-}" ]] || BUILD_ARGS+=(--build-arg "$a=${!a}")
  done
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# --target artifact, NOT the default target: `artifact` depends on the compile stage
# only. The drift stage sits between compile and runtime, and building through it here
# would fail on exactly the condition this script exists to fix.
docker build \
  -f images/mediator/Dockerfile \
  --target artifact \
  --output "type=local,dest=$STAGE" \
  "${BUILD_ARGS[@]}" \
  . >&2

shopt -s nullglob
emitted=("$STAGE"/*.yaml)
[[ ${#emitted[@]} -gt 0 ]] \
  || { echo "compile-policy-build: the build stage emitted no artifact" >&2; exit 2; }

changed=0
for f in "${emitted[@]}"; do
  target="policy/resolved/$(basename "$f")"
  # compiled_at changes on every compile by design, so an artifact whose policy is
  # unchanged is LEFT ALONE rather than rewritten with a fresh timestamp. Rewriting it
  # would dirty the working tree on every refresh with a change that says nothing, and
  # would make `git status` stop being a usable answer to "did the policy move?".
  # `compiled_at` in the committed copy therefore records when the policy last
  # CHANGED, which is the only reading under which it is worth reviewing.
  if [[ -f "$target" ]] && diff -q <(grep -v '^compiled_at:' "$target") <(grep -v '^compiled_at:' "$f") >/dev/null; then
    echo "compile-policy-build: $target unchanged"
    continue
  fi
  echo "compile-policy-build: $target CHANGED"
  diff -u "$target" "$f" 2>/dev/null || true
  changed=1
  install -m 0644 "$f" "$target"
done

if [[ "$changed" == 1 ]]; then
  echo "compile-policy-build: review the diff above and commit policy/resolved/ -- the build refuses an artifact nobody reviewed (R5.14)." >&2
fi
