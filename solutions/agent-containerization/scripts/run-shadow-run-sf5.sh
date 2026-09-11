#!/usr/bin/env bash
# Operator convenience runner for Feature 02.2 SF-5's live shadow run (Phase 9 of
# tests/acceptance/validate-boundary.sh, BOUNDARY_SHADOW_RUN=1). Not part of the committed
# acceptance suite -- it does not drive the agent sessions themselves (Decision 8: the harness
# must not do that), it only issues one real request per agent (images/Dockerfile's default CMD
# is `<agent> --version`, which makes NO network call -- a bare `run --rm claude` produces no
# egress at all, so this overrides the command explicitly) and then greps the default-project
# mediator's trail for the four single-source hosts. Bash it, don't chmod it:
#   bash scripts/run-shadow-run-sf5.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HOSTS=(api.anthropic.com chatgpt.com api.github.com github.com)
COMPOSE=(docker compose --env-file compose/pins.env -f compose/compose.yaml -f compose/overrides/default.yaml)

echo "=== SF-5 shadow run: bringing up the default profile (egress-mediator is not a claude/codex"
echo "depends_on -- 'run --rm' alone would leave it down and produce no mediated egress) ==="
"${COMPOSE[@]}" up -d egress-mediator
sleep 2

echo
echo "=== SF-5 shadow run: claude leg (api.anthropic.com) ==="
"${COMPOSE[@]}" run --rm claude claude -p "Say OK and nothing else."

echo
echo "=== SF-5 shadow run: codex leg (chatgpt.com via codex exec, github.com/api.github.com via curl) ==="
"${COMPOSE[@]}" run --rm codex codex exec "say hi" --sandbox danger-full-access
# --sandbox danger-full-access disables codex's OWN nested Bubblewrap sandbox, which cannot
# create a user namespace inside this already-hardened container (SF-4's finding,
# docs/records/boundary-validation.md). The outer container is the boundary under test (R1.2).
#
# /workspace holds no checked-out repo (only .gitkeep -- verified 2026-09-11), so a `git fetch`
# against it fails with "not a git repository" before any egress happens. curl exercises the same
# proxy credential/identity from inside the same container at no model-token cost.
"${COMPOSE[@]}" run --rm codex bash -lc \
  "curl -sS -o /dev/null -w 'github.com -> %{http_code}\n' https://github.com; \
   curl -sS -o /dev/null -w 'api.github.com -> %{http_code}\n' https://api.github.com"

echo
echo "=== SF-5 shadow run: reading the default-project mediator's egress trail ==="
MED_CTR="$(docker ps --filter name=egress-mediator-1 --format '{{.Names}}' | head -1)"
if [ -z "$MED_CTR" ]; then
  echo "No running container matched name=egress-mediator-1 -- 'up -d egress-mediator' above" >&2
  echo "should have started it. Check: docker compose ${COMPOSE[*]:2} ps" >&2
  exit 1
fi
echo "mediator container: $MED_CTR"
echo

PATTERN="$(IFS='|'; echo "${HOSTS[*]}")"
for f in /var/log/mediator/egress-audit.log /var/log/mediator/dns-audit.log; do
  echo "--- $f ---"
  docker exec "$MED_CTR" sh -c "grep -hE '${PATTERN//./\\.}' '$f' 2>/dev/null" \
    || echo "(no matching lines)"
  echo
done

echo "=== Compare each of the four hosts above against its existing 'source:' entry in"
echo "policy/allowlist.base.yaml, then apply Decision 7's outcome (see the feature plan's"
echo "Interface Contract 6 and Phase 9's printed instructions in validate-boundary.sh)."
