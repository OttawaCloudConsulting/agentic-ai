#!/usr/bin/env bash
# check.sh — syntax checks + fixture tests for every script in this toolkit.
# Run after any change:
#   bundle layout   : bash scripts/claude-toolkit/check.sh
#   installed layout: bash .claude/scripts/check.sh
#
# shellcheck disable=SC2015,SC2181,SC2016
# Test assertions use the `cond && ok "..." || bad "..."` idiom throughout.
# ok() always returns 0, so the A&&B||C caveat (SC2015) does not apply here,
# and checking $? after a subshell (SC2181) is deliberate for readability.
# SC2016: the single-quoted JSON fixtures are intentionally literal (fake
# command strings fed to the hook) — no expansion is wanted.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# Hook dir: an installed toolkit keeps hooks at .claude/hooks (sibling of
# .claude/scripts/); the template bundle keeps them at scripts/claude-toolkit/hooks/
# (subdir of the scripts). Support both.
HOOK_DIR="$HERE/../hooks"
[[ -f "$HOOK_DIR/block-heredoc-commit.js" ]] || HOOK_DIR="$HERE/hooks"
PASS=0
FAIL=0

ok()   { echo "  ok: $1"; PASS=$((PASS + 1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "== syntax =="
for f in "$HERE"/*.sh "$HERE"/gcommit; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n $(basename "$f")"; else bad "bash -n $(basename "$f")"; fi
done
if node --check "$HOOK_DIR/block-heredoc-commit.js" 2>/dev/null; then
  ok "node --check block-heredoc-commit.js"
else
  bad "node --check block-heredoc-commit.js"
fi

echo "== codex-review verdict parsing (jq fixture, no codex call) =="
JQ_EXPR='[.[] | select(.item.type? == "agent_message") | .item.text] | last // empty'
T="$(printf '%s\n' '{"item":{"type":"agent_message","text":"finding\nVERDICT: PASS"}}' | jq -rs "$JQ_EXPR")"
grep -q '^VERDICT: PASS[[:space:]]*$' <<< "$T" && ok "PASS verdict recognized" || bad "PASS verdict recognized"
T="$(printf '%s\n' '{"item":{"type":"agent_message","text":"finding\nVERDICT: FAIL"}}' | jq -rs "$JQ_EXPR")"
grep -q '^VERDICT: FAIL[[:space:]]*$' <<< "$T" && ok "FAIL verdict recognized" || bad "FAIL verdict recognized"
T="$(printf '%s\n' '{"item":{"type":"agent_message","text":"no verdict here"}}' | jq -rs "$JQ_EXPR")"
if ! grep -qE '^VERDICT: (PASS|FAIL)' <<< "$T"; then ok "missing verdict detected"; else bad "missing verdict detected"; fi
T="$(printf '%s\n' '{"item":{"type":"other"}}' | jq -rs "$JQ_EXPR")"
[[ -z "$T" ]] && ok "non-agent events ignored" || bad "non-agent events ignored"

echo "== state-status fixtures (real milestone-status schema) =="
D="$(mktemp -d "${TMPDIR:-/tmp}/check-state.XXXXXX")"
trap 'rm -rf "$D"' EXIT
mkdir -p "$D/milestones/09-mixed"
cat > "$D/progress.txt" <<'EOF'
## Gates
[x] Gate 3: Milestone Review  Approved
## Milestones
[~] Milestone 09: Mixed  milestones/09-mixed/  1/2 features complete
EOF
cat > "$D/milestones/09-mixed/milestone-status.txt" <<'EOF'
# Milestone 09: Mixed

## Features

[x] Feature 09.1: completed thing
    Notes: Gate 4 approved earlier (planned, awaiting build) — since completed.
    Completed 2026-07-01

[~] Feature 09.2: planned thing
    Plan: plans/planned-thing.md
    Notes: Gate-4 (2026-07-04): planned, awaiting build.

[ ] Feature 09.3: unplanned thing
    Plan: (not yet planned)
EOF

bash "$HERE/state-status.sh" --check-buildable "Feature 09.2" "$D" >/dev/null 2>&1 \
  && ok "planned feature is BUILDABLE" || bad "planned feature is BUILDABLE"
bash "$HERE/state-status.sh" --check-buildable "Feature 09.1" "$D" >/dev/null 2>&1 \
  && bad "completed feature rejected (false positive!)" || ok "completed feature rejected"
bash "$HERE/state-status.sh" --check-buildable "Feature 09.3" "$D" >/dev/null 2>&1 \
  && bad "unplanned feature rejected (false positive!)" || ok "unplanned feature rejected"
bash "$HERE/state-status.sh" --check-buildable "Feature 09.9" "$D" >/dev/null 2>&1 \
  && bad "unknown slug rejected (false positive!)" || ok "unknown slug rejected"
# capture first: grep -q's early exit would SIGPIPE the script under pipefail
DIGEST="$(bash "$HERE/state-status.sh" "$D")"
grep -q 'Feature 09.2' <<< "$DIGEST" \
  && ok "digest lists awaiting-build feature" || bad "digest lists awaiting-build feature"

echo "== state-status namespaced layout (.project/<slug>/milestones) =="
N="$(mktemp -d "${TMPDIR:-/tmp}/check-state-ns.XXXXXX")"
mkdir -p "$N/.project/robin/milestones/01-alpha"
cat > "$N/progress.txt" <<'EOF'
## Gates
[x] Gate 3: Milestone Review  Approved
## Milestones
[~] Milestone 01: Alpha  .project/robin/milestones/01-alpha/  0/1 features complete
EOF
cat > "$N/.project/robin/milestones/01-alpha/milestone-status.txt" <<'EOF'
# Milestone 01: Alpha

## Features

[~] Feature 01.1: namespaced planned thing
    Notes: Gate-4 (2026-07-05): planned, awaiting build.
EOF
bash "$HERE/state-status.sh" --check-buildable "Feature 01.1" "$N" >/dev/null 2>&1 \
  && ok "namespaced: planned feature is BUILDABLE" || bad "namespaced: planned feature is BUILDABLE"
NDIGEST="$(bash "$HERE/state-status.sh" "$N")"
grep -q '.project/robin/milestones/01-alpha' <<< "$NDIGEST" \
  && ok "namespaced: digest labels by relative path" || bad "namespaced: digest labels by relative path"
grep -q 'Feature 01.1' <<< "$NDIGEST" \
  && ok "namespaced: awaiting-build listed" || bad "namespaced: awaiting-build listed"
# override glob still works
CC_MILESTONE_GLOB=".project/*/milestones/*/milestone-status.txt" \
  bash "$HERE/state-status.sh" --check-buildable "Feature 01.1" "$N" >/dev/null 2>&1 \
  && ok "CC_MILESTONE_GLOB override resolves" || bad "CC_MILESTONE_GLOB override resolves"
rm -rf "$N"

echo "== block-heredoc-commit hook =="
OUT="$(printf '%s' '{"tool_input":{"command":"git commit -m \"$(cat <<EOF\nx\nEOF\n)\""}}' | node "$HOOK_DIR/block-heredoc-commit.js")"
grep -q '"permissionDecision":"deny"' <<< "$OUT" && ok "heredoc commit denied" || bad "heredoc commit denied"
OUT="$(printf '%s' '{"tool_input":{"command":"git commit -F .git/msg"}}' | node "$HOOK_DIR/block-heredoc-commit.js")"
[[ -z "$OUT" ]] && ok "file-based commit allowed" || bad "file-based commit allowed"
OUT="$(printf '%s' '{"tool_input":{"command":"cat <<EOF\nhello\nEOF"}}' | node "$HOOK_DIR/block-heredoc-commit.js")"
[[ -z "$OUT" ]] && ok "non-commit heredoc allowed" || bad "non-commit heredoc allowed"

echo "== run-quiet =="
bash "$HERE/run-quiet.sh" true >/dev/null 2>&1 && ok "success path rc=0" || bad "success path rc=0"
bash "$HERE/run-quiet.sh" bash -c 'echo "Error: boom"; exit 3' >/dev/null 2>&1
[[ $? -eq 3 ]] && ok "failure rc preserved" || bad "failure rc preserved"

echo "== branch-sync base-branch resolution =="
# Mirror the resolver: env → .cc-base-branch → remote HEAD. Test the first two precedences
# in a throwaway git repo (no remote needed; we never reach the destructive reset).
BR_D="$(mktemp -d "${TMPDIR:-/tmp}/check-bsync.XXXXXX")"
( cd "$BR_D" && git init -q && git checkout -q -b feat-x 2>/dev/null )
printf 'integration-base\n' > "$BR_D/.cc-base-branch"
RESOLVED="$(cd "$BR_D" && TOP="$(git rev-parse --show-toplevel)"
  if [[ -n "${CC_BASE_BRANCH:-}" ]]; then echo "$CC_BASE_BRANCH"
  elif [[ -f "$TOP/.cc-base-branch" ]]; then head -n1 "$TOP/.cc-base-branch" | tr -d '[:space:]'
  fi)"
[[ "$RESOLVED" == "integration-base" ]] && ok ".cc-base-branch resolves to integration-base" || bad ".cc-base-branch resolves to integration-base (got '$RESOLVED')"
RESOLVED_ENV="$(cd "$BR_D" && CC_BASE_BRANCH=override bash -c 'echo "${CC_BASE_BRANCH}"')"
[[ "$RESOLVED_ENV" == "override" ]] && ok "CC_BASE_BRANCH env wins" || bad "CC_BASE_BRANCH env wins"
# branch-sync must refuse when feature branch == base (guard), not attempt a reset.
( cd "$BR_D" && git checkout -q -b integration-base 2>/dev/null; bash "$HERE/branch-sync.sh" integration-base >/dev/null 2>&1 )
[[ $? -ne 0 ]] && ok "refuses reset when on integration branch" || bad "refuses reset when on integration branch"
rm -rf "$BR_D"

echo
echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
