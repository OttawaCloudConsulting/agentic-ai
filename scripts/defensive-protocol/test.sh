#!/usr/bin/env bash
# F6.1 — Mechanical test entry point (Tier 1).
# Runs bats hook tests, installer tests, and rule-sync check.
# Usage: bash scripts/defensive-protocol/test.sh
# Behavioral eval (Tier 2): bash scripts/defensive-protocol/eval/run-trials.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

_header() { printf '\n=== %s ===\n' "$1"; }
_ok()     { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
_fail()   { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ── Prereqs ───────────────────────────────────────────────────────────────────

_header "Prerequisite check"

if ! command -v bats >/dev/null 2>&1; then
  printf 'ERROR: bats not found. Install bats-core: https://github.com/bats-core/bats-core\n' >&2
  exit 1
fi
_ok "bats: $(bats --version)"

if ! command -v jq >/dev/null 2>&1; then
  printf 'ERROR: jq not found. Install jq first.\n' >&2
  exit 1
fi
_ok "jq: $(jq --version)"

# ── Tier 1a: Hook tests ───────────────────────────────────────────────────────

_header "Tier 1a: Hook tests (tests/hooks.bats)"
if bats "$PROJECT_ROOT/tests/hooks.bats"; then
  _ok "hooks.bats"
else
  _fail "hooks.bats"
fi

# ── Tier 1b: Installer tests ──────────────────────────────────────────────────

_header "Tier 1b: Installer tests (tests/installer.bats)"
if bats "$PROJECT_ROOT/tests/installer.bats"; then
  _ok "installer.bats"
else
  _fail "installer.bats"
fi

# ── Tier 1c: Rule-sync check ──────────────────────────────────────────────────

_header "Tier 1c: Rule-sync (rules/ == .claude/rules/ for dp2 files)"
RULES_SRC="$PROJECT_ROOT/rules"
RULES_DST="$PROJECT_ROOT/.claude/rules"
SYNC_FAIL=0

if [ ! -d "$RULES_SRC" ]; then
  _fail "rules/ directory missing at $RULES_SRC"
elif [ ! -d "$RULES_DST" ]; then
  _fail ".claude/rules/ directory missing at $RULES_DST"
else
  while IFS= read -r fname; do
    src="$RULES_SRC/$fname"
    dst="$RULES_DST/$fname"
    if [ ! -f "$dst" ]; then
      printf 'MISSING in .claude/rules/: %s\n' "$fname"
      SYNC_FAIL=1
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      printf 'DIFFERS: %s\n' "$fname"
      diff "$src" "$dst" || true
      SYNC_FAIL=1
    fi
  done < <(find "$RULES_SRC" -maxdepth 1 -name 'defensive-protocol-v2-*.md' -exec basename {} \; | sort)

  if [ "$SYNC_FAIL" -eq 0 ]; then
    _ok "rules/ and .claude/rules/ dp2 files are byte-identical"
  else
    _fail "rule-sync: rules/ and .claude/rules/ differ"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

_header "Summary"
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"
printf '\nBehavioral eval (Tier 2, run on demand):\n'
printf '  bash scripts/defensive-protocol/eval/run-trials.sh [--trials N]\n'

if [ "$FAIL" -gt 0 ]; then
  printf '\nResult: FAIL\n'
  exit 1
fi
printf '\nResult: PASS\n'
exit 0
