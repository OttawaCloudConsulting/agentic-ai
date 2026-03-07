#!/usr/bin/env bash
# Benchmark runner for skill creator comparison.
# Usage: bash scripts/run-benchmark.sh [run-label]
# Drives skill creation and scoring via claude -p, then compiles results.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_LABEL="${1:-$(date -u +%Y%m%dT%H%M%SZ)}"
BASE="$REPO_ROOT/temp/benchmark/$RUN_LABEL"

# Create base dir early so run.log has a directory to land in.
mkdir -p "$BASE"
exec > >(tee -a "$BASE/run.log") 2>&1

# Skill A: project-local. Skill B: globally installed plugin.
# Plugin path resolved dynamically to avoid pinning version hashes.
_plugin_skill_b() {
  local stable="$HOME/.claude/plugins/marketplaces/claude-plugins-official/plugins/skill-creator/skills/skill-creator/SKILL.md"
  if [[ -f "$stable" ]]; then echo "$stable"; return; fi
  # Fall back to cache (version-hashed path)
  local cached
  cached=$(find "$HOME/.claude/plugins/cache" -path "*/skill-creator/*/skills/skill-creator/SKILL.md" 2>/dev/null | sort | tail -1)
  echo "$cached"
}

declare -A SKILL_MD_PATHS=(
  ["skill-A"]="$REPO_ROOT/.claude/skills/occ-skill-creator/SKILL.md"
  ["skill-B"]="$(_plugin_skill_b)"
)

declare -A INPUT_FILES=(
  ["T1"]="T1-simple.md"
  ["T2"]="T2-medium.md"
  ["T3"]="T3-complex.md"
)

INPUTS=("T1" "T2" "T3")
SKILLS=("skill-A" "skill-B")

declare -A SKILL_NAMES=(
  ["skill-A"]="occ-skill-creator"
  ["skill-B"]="skill-creator (Anthropic plugin)"
)

# ─── Preflight checks ──────────────────────────────────────────────────────────

echo "==> Preflight checks"

if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH. Install Claude Code first." >&2
  exit 1
fi

for skill_id in "${SKILLS[@]}"; do
  skill_md="${SKILL_MD_PATHS[$skill_id]}"
  if [[ -z "$skill_md" || ! -f "$skill_md" ]]; then
    echo "ERROR: Missing SKILL.md for $skill_id at: ${skill_md:-<not found>}" >&2
    exit 1
  fi
done

for input_id in "${INPUTS[@]}"; do
  brief="$REPO_ROOT/benchmark/inputs/${INPUT_FILES[$input_id]}"
  if [[ ! -f "$brief" ]]; then
    echo "ERROR: Missing input brief: $brief" >&2
    exit 1
  fi
done

if [[ ! -f "$REPO_ROOT/benchmark/rubric.md" ]]; then
  echo "ERROR: Missing rubric: $REPO_ROOT/benchmark/rubric.md" >&2
  exit 1
fi

echo "    All skill files and inputs found."
echo ""

# ─── Phase 1: Setup ────────────────────────────────────────────────────────────

echo "==> Phase 1: Setup — run: $RUN_LABEL"
echo "    Output: $BASE"
echo ""

for skill_id in "${SKILLS[@]}"; do
  for input_id in "${INPUTS[@]}"; do
    mkdir -p "$BASE/$skill_id/$input_id"
    mkdir -p "$BASE/scores/$skill_id/$input_id"
  done
done

GIT_HASH=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
MANIFEST="$BASE/manifest.md"

{
  echo "# Benchmark Manifest"
  echo ""
  echo "| Field         | Value |"
  echo "|---------------|-------|"
  echo "| Run label     | $RUN_LABEL |"
  echo "| Date (UTC)    | $(date -u '+%Y-%m-%d %H:%M:%S') |"
  echo "| Git hash      | $GIT_HASH |"
  echo "| Skill A       | occ-skill-creator |"
  echo "| Skill B       | skill-creator |"
  echo ""
  echo "## Input hashes"
  echo ""
  echo "| Input | File | SHA256 |"
  echo "|-------|------|--------|"
  for input_id in "${INPUTS[@]}"; do
    brief="$REPO_ROOT/benchmark/inputs/${INPUT_FILES[$input_id]}"
    hash=$(shasum -a 256 "$brief" 2>/dev/null | awk '{print $1}' || echo "unknown")
    echo "| $input_id | ${INPUT_FILES[$input_id]} | $hash |"
  done
  echo ""
  echo "## Run log"
  echo ""
  echo "| Phase | Skill | Skill name | Input | Exit code |"
  echo "|-------|-------|------------|-------|-----------|"
} >"$MANIFEST"

echo "    Manifest written: $MANIFEST"
echo ""

# ─── Phase 2: Skill creation — 6 claude -p calls ──────────────────────────────

echo "==> Phase 2: Skill creation"
echo ""

for skill_id in "${SKILLS[@]}"; do
  SKILL_CONTENT="$(cat "${SKILL_MD_PATHS[$skill_id]}")"

  for input_id in "${INPUTS[@]}"; do
    brief="$REPO_ROOT/benchmark/inputs/${INPUT_FILES[$input_id]}"
    BRIEF_CONTENT="$(cat "$brief")"
    OUTPUT_DIR="$BASE/$skill_id/$input_id"

    echo "    Creating: $skill_id (${SKILL_NAMES[$skill_id]}) / $input_id → $OUTPUT_DIR"

    exit_code=0
    claude -p "AUTOMATED PIPELINE — DO NOT ASK ANY QUESTIONS. Generate skill files immediately.

You are running in a non-interactive benchmark. There is no user to respond to clarifying questions. Treat the brief as complete and sufficient. Do not pause, do not ask for confirmation, do not output questions. Begin writing files immediately.

Pre-answered questions (do not ask for these):
- What should the skill do? → exactly what the brief describes
- When should it trigger? → derive natural trigger phrases from the brief's domain and task type
- What is the output format? → a SKILL.md plus any references/ or scripts/ files the brief warrants
- Are there edge cases? → handle gracefully; document assumptions inline
- Should test cases be created? → no; skip all eval, benchmark, and test setup entirely

Output directory: $OUTPUT_DIR
Create all skill files there. SKILL.md is required. references/ and scripts/ only if warranted.

BRIEF:
$BRIEF_CONTENT" \
      --system-prompt "$SKILL_CONTENT" \
      --permission-mode dontAsk \
      --allowedTools "Read,Write" \
      --add-dir "$OUTPUT_DIR" \
      --disable-slash-commands \
      --model sonnet \
      2>&1 | tee "$OUTPUT_DIR/creation.log" || exit_code=$?

    echo "| creation | $skill_id | ${SKILL_NAMES[$skill_id]} | $input_id | $exit_code |" >>"$MANIFEST"
    echo "    Exit code: $exit_code"
    echo ""
  done
done

# ─── Post-phase 2 check ────────────────────────────────────────────────────────

echo "==> Post-phase 2 check: verifying SKILL.md exists in each output dir"
echo ""

creation_failures=0
for skill_id in "${SKILLS[@]}"; do
  for input_id in "${INPUTS[@]}"; do
    output_dir="$BASE/$skill_id/$input_id"
    if [[ ! -f "$output_dir/SKILL.md" ]]; then
      echo "    WARN: No SKILL.md found — $skill_id / $input_id (creation likely asked a question or failed)"
      echo "| warn: missing SKILL.md | $skill_id | ${SKILL_NAMES[$skill_id]} | $input_id | — |" >>"$MANIFEST"
      creation_failures=$((creation_failures + 1))
    else
      echo "    OK: $skill_id (${SKILL_NAMES[$skill_id]}) / $input_id"
    fi
  done
done

if [[ $creation_failures -gt 0 ]]; then
  echo ""
  echo "    $creation_failures output(s) missing SKILL.md — scoring will produce empty results for those."
fi
echo ""

# ─── Phase 3: Scoring — 6 claude -p calls ─────────────────────────────────────

echo "==> Phase 3: Scoring"
echo ""

RUBRIC_CONTENT="$(cat "$REPO_ROOT/benchmark/rubric.md")"

for skill_id in "${SKILLS[@]}"; do
  for input_id in "${INPUTS[@]}"; do
    SKILL_OUTPUT_DIR="$BASE/$skill_id/$input_id"
    SCORE_FILE="$BASE/scores/$skill_id/$input_id/scores.md"

    echo "    Scoring: $skill_id (${SKILL_NAMES[$skill_id]}) / $input_id → $SCORE_FILE"

    exit_code=0
    claude -p "Score the skill at: $SKILL_OUTPUT_DIR
Read SKILL.md and any reference files in that directory.
Apply the rubric below. Write your scores to: $SCORE_FILE

$RUBRIC_CONTENT" \
      --system-prompt "You are a skill quality evaluator. Score strictly and objectively. Output only the scores.md file — no other commentary." \
      --permission-mode dontAsk \
      --allowedTools "Read,Write" \
      --add-dir "$BASE" \
      --model sonnet \
      2>&1 | tee "$BASE/scores/$skill_id/$input_id/scoring.log" || exit_code=$?

    echo "| scoring | $skill_id | ${SKILL_NAMES[$skill_id]} | $input_id | $exit_code |" >>"$MANIFEST"
    echo "    Exit code: $exit_code"
    echo ""
  done
done

# ─── Phase 4: Compilation — 1 claude -p call ──────────────────────────────────

echo "==> Phase 4: Compilation → docs/MVP-SKILL-vs-SKILL.md"
echo ""

exit_code=0
claude -p "Read all score files under $BASE/scores/.
Compile a results matrix and append it to $REPO_ROOT/docs/MVP-SKILL-vs-SKILL.md.
Follow the template already in that file (Run, Results Matrix, Winner, Notable findings).
Run label: $RUN_LABEL

Skill identity:
- skill-A = ${SKILL_NAMES[skill-A]}
- skill-B = ${SKILL_NAMES[skill-B]}" \
  --permission-mode dontAsk \
  --allowedTools "Read,Write" \
  --add-dir "$BASE" \
  --add-dir "$REPO_ROOT/docs" \
  --model sonnet \
  2>&1 | tee "$BASE/compilation.log" || exit_code=$?

echo "| compilation | — | — | — | $exit_code |" >>"$MANIFEST"
echo "    Exit code: $exit_code"
echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "==> Done — run: $RUN_LABEL"
echo ""
echo "    Outputs:  $BASE"
echo "    Results:  $REPO_ROOT/docs/MVP-SKILL-vs-SKILL.md"
echo "    Manifest: $MANIFEST"
