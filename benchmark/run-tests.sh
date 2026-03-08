#!/usr/bin/env bash
# run-tests.sh — Validate run-benchmark.sh behaviour.
# Usage: bash benchmark/run-tests.sh [--live]
#
# Without --live: runs fast CLI/validation tests only (no claude calls).
# With --live:    also runs one full benchmark (requires claude in PATH).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/run-benchmark.sh"

PASS=0
FAIL=0
LIVE=false

if [[ "${1:-}" == "--live" ]]; then
  LIVE=true
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────

pass() { echo "  PASS  $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; FAIL=$((FAIL+1)); }

assert_exit() {
  local desc="$1" expected="$2"; shift 2
  local actual
  actual=$(bash "$SCRIPT" "$@" 2>&1; echo "EXIT:$?") || true
  local code="${actual##*EXIT:}"
  if [[ "$code" == "$expected" ]]; then pass "$desc"; else fail "$desc" "expected exit $expected, got $code"; fi
}

assert_contains() {
  local desc="$1" needle="$2"; shift 2
  local output
  output=$(bash "$SCRIPT" "$@" 2>&1) || true
  if echo "$output" | grep -qF -- "$needle"; then pass "$desc"; else fail "$desc" "expected output to contain: $needle"; fi
}

assert_not_contains() {
  local desc="$1" needle="$2"; shift 2
  local output
  output=$(bash "$SCRIPT" "$@" 2>&1) || true
  if ! echo "$output" | grep -qF -- "$needle"; then pass "$desc"; else fail "$desc" "expected output NOT to contain: $needle"; fi
}

# ─── Suite 1: Arg parsing + error handling ───────────────────────────────────

echo ""
echo "Suite 1: Arg parsing + error handling"
echo "────────────────────────────────────────────────────"

assert_exit   "no args → exit 0 (prints usage)"            0
assert_exit   "--challenger missing → exit 1"              1  --label test
assert_exit   "--champion + --compare-main → exit 1"       1  --challenger occ-skill-creator --champion occ-skill-creator --compare-main
assert_exit   "unknown arg → exit 1"                       1  --challenger occ-skill-creator --bogus-flag
assert_contains "no args → usage contains --challenger"   "--challenger"
assert_contains "--help shows --creation-model"           "--creation-model"  --help
assert_contains "--help shows --scoring-model"            "--scoring-model"   --help
assert_contains "--help shows default sonnet"             "sonnet"            --help

# ─── Suite 2: Skill path resolution ──────────────────────────────────────────

echo ""
echo "Suite 2: Skill path resolution"
echo "────────────────────────────────────────────────────"

# Bad bare name → clear error
assert_contains "missing bare name → ERROR with resolved path" \
  "ERROR: SKILL.md not found at" \
  --challenger nonexistent-skill-xyz

# Bad .md path → clear error
assert_contains "missing .md path → ERROR with resolved path" \
  "ERROR: SKILL.md not found at" \
  --challenger benchmark/test-fixtures/nonexistent/SKILL.md

# Existing bare name → passes preflight (fails at claude, but not at resolution)
{
  output=$(bash "$SCRIPT" --challenger occ-skill-creator 2>&1 || true)
  if echo "$output" | grep -qF "ERROR: SKILL.md not found"; then
    fail "bare name resolves correctly (occ-skill-creator)" "got resolution error unexpectedly"
  else
    pass "bare name resolves correctly (occ-skill-creator)"
  fi
}

# Existing directory path → passes resolution
{
  output=$(bash "$SCRIPT" --challenger "$REPO_ROOT/.claude/skills/occ-skill-creator" 2>&1 || true)
  if echo "$output" | grep -qF "ERROR: SKILL.md not found"; then
    fail "directory path resolves correctly" "got resolution error unexpectedly"
  else
    pass "directory path resolves correctly"
  fi
}

# Existing .md path → passes resolution
{
  output=$(bash "$SCRIPT" --challenger "$REPO_ROOT/.claude/skills/occ-skill-creator/SKILL.md" 2>&1 || true)
  if echo "$output" | grep -qF "ERROR: SKILL.md not found"; then
    fail "direct .md path resolves correctly" "got resolution error unexpectedly"
  else
    pass "direct .md path resolves correctly"
  fi
}

# Test fixtures resolve
{
  output=$(bash "$SCRIPT" --challenger benchmark/test-fixtures/anti-quality 2>&1 || true)
  if echo "$output" | grep -qF "ERROR: SKILL.md not found"; then
    fail "anti-quality fixture resolves" "got resolution error"
  else
    pass "anti-quality fixture resolves"
  fi
}

{
  output=$(bash "$SCRIPT" --challenger benchmark/test-fixtures/bad-skill 2>&1 || true)
  if echo "$output" | grep -qF "ERROR: SKILL.md not found"; then
    fail "bad-skill fixture resolves" "got resolution error"
  else
    pass "bad-skill fixture resolves"
  fi
}

# ─── Suite 3: Default values ──────────────────────────────────────────────────

echo ""
echo "Suite 3: Default flag values"
echo "────────────────────────────────────────────────────"

assert_contains "--threshold default documented as 3"     "default: 3"  --help
assert_contains "--label default documented as comparison" "comparison"  --help

# ─── Suite 4: Feature 8 — model flag plumbing ────────────────────────────────

echo ""
echo "Suite 4: Feature 8 — model flag plumbing"
echo "────────────────────────────────────────────────────"

# Unknown flags don't interfere with known ones (parsing order)
assert_exit "--creation-model accepted without error (exits at preflight, not parse)" \
  1 \
  --challenger occ-skill-creator --creation-model haiku --bogus-after

# Validate --creation-model and --scoring-model parsed cleanly alongside other flags
{
  output=$(bash "$SCRIPT" \
    --challenger nonexistent-xyz \
    --creation-model haiku \
    --scoring-model opus \
    2>&1 || true)
  if echo "$output" | grep -qF "Unknown argument"; then
    fail "--creation-model and --scoring-model accepted by parser" "parser rejected them: $output"
  elif echo "$output" | grep -qF "ERROR: SKILL.md not found"; then
    pass "--creation-model and --scoring-model accepted by parser (reached skill resolution)"
  else
    pass "--creation-model and --scoring-model accepted by parser"
  fi
}

# ─── Suite 5: Live benchmark run ─────────────────────────────────────────────

if [[ "$LIVE" == "false" ]]; then
  echo ""
  echo "Suite 5: Live benchmark run (skipped — pass --live to enable)"
  echo "────────────────────────────────────────────────────"
else
  echo ""
  echo "Suite 5: Live benchmark run — anti-quality vs baseline"
  echo "────────────────────────────────────────────────────"
  echo "  This run uses --creation-model haiku (fast + validates Feature 8)."
  echo "  Expected verdict: REJECT or NO VALUE (anti-quality skill should score low)."
  echo ""

  RUN_LABEL="test-anti-quality-baseline"
  TIMESTAMP_BEFORE="$(date -u '+%Y%m%d-%H%M%S')"

  # Unset CLAUDECODE so nested claude -p calls are not blocked when run from inside a Claude Code session
  env -u CLAUDECODE bash "$SCRIPT" \
    --challenger benchmark/test-fixtures/anti-quality \
    --label "$RUN_LABEL" \
    --creation-model haiku \
    --scoring-model sonnet \
    --threshold 3

  # Find the run dir created
  RUN_DIR=$(find "$REPO_ROOT/benchmark/runs" -maxdepth 1 -name "${RUN_LABEL}__*" -type d | sort | tail -1)

  if [[ -z "$RUN_DIR" ]]; then
    fail "live run: run directory created" "no directory found matching ${RUN_LABEL}__*"
  else
    pass "live run: run directory created"

    # Check decision.md exists
    if [[ -f "$RUN_DIR/decision.md" ]]; then
      pass "live run: decision.md produced"
    else
      fail "live run: decision.md produced" "file missing: $RUN_DIR/decision.md"
    fi

    # Check manifest has model rows
    if grep -qF "| Creation model |" "$RUN_DIR/manifest.md" 2>/dev/null; then
      pass "live run: manifest records Creation model"
    else
      fail "live run: manifest records Creation model" "row missing from manifest.md"
    fi

    if grep -qF "| Scoring model |" "$RUN_DIR/manifest.md" 2>/dev/null; then
      pass "live run: manifest records Scoring model"
    else
      fail "live run: manifest records Scoring model" "row missing from manifest.md"
    fi

    # Check model values in manifest
    if grep -qF "haiku" "$RUN_DIR/manifest.md" 2>/dev/null; then
      pass "live run: manifest records haiku as creation model"
    else
      fail "live run: manifest records haiku as creation model" "haiku not found in manifest.md"
    fi

    # Check logs directory exists (artifact separation — Feature 4)
    if [[ -d "$RUN_DIR/logs" ]]; then
      pass "live run: logs/ directory exists"
    else
      fail "live run: logs/ directory exists" "missing $RUN_DIR/logs"
    fi

    # Check no .log files leaked into skill output dirs
    leaked=$(find "$RUN_DIR/baseline" "$RUN_DIR/challenger" -name "*.log" 2>/dev/null | head -3)
    if [[ -z "$leaked" ]]; then
      pass "live run: no .log files in skill output dirs"
    else
      fail "live run: no .log files in skill output dirs" "found: $leaked"
    fi

    # Check verdict — anti-quality skill should not get PROMOTE
    if [[ -f "$RUN_DIR/decision.md" ]]; then
      verdict=$(grep -oE '\*\*(PROMOTE|REJECT|NO VALUE|NO CHANGE|SWITCH RECOMMENDED|CHAMPION CONFIRMED)\*\*' "$RUN_DIR/decision.md" | head -1 | tr -d '*')
      if [[ -n "$verdict" ]]; then
        echo "  INFO  Verdict: $verdict"
        if [[ "$verdict" == "PROMOTE" ]]; then
          fail "live run: anti-quality skill did not receive PROMOTE verdict" "got PROMOTE — skill is not scoring low enough"
        else
          pass "live run: verdict is not PROMOTE ($verdict)"
        fi
      else
        fail "live run: verdict keyword found in decision.md" "no bolded verdict keyword found"
      fi
    fi

    echo ""
    echo "  Run directory: $RUN_DIR"
    echo "  Decision:      $RUN_DIR/decision.md"
  fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "════════════════════════════════════════════════════"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
