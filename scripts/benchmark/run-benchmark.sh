#!/usr/bin/env bash
# run-benchmark.sh — Compare two Claude Code skill definitions head-to-head.
# Usage: bash scripts/benchmark/run-benchmark.sh --challenger <skill> [options]
# Drives skill creation and scoring via claude -p, then compiles results.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ─── resolve_skill ──────────────────────────────────────────────────────────────
# Converts a skill reference to an absolute SKILL.md path. Does not check existence.
# Forms:
#   *.md path   → use as-is (absolute) or relative to REPO_ROOT
#   directory   → <dir>/SKILL.md (resolved to absolute)
#   bare name   → $REPO_ROOT/.claude/skills/<name>/SKILL.md
resolve_skill() {
  local ref="$1"
  if [[ "$ref" == *.md ]]; then
    if [[ "$ref" == /* ]]; then echo "$ref"; else echo "$REPO_ROOT/$ref"; fi
  elif [[ -d "$ref" ]]; then
    local abs; abs="$(cd "$ref" && pwd)"; echo "$abs/SKILL.md"
  else
    echo "$REPO_ROOT/.claude/skills/$ref/SKILL.md"
  fi
}

# ─── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: bash scripts/benchmark/run-benchmark.sh --challenger <skill> [options]

Compares two skill definitions using standardised test briefs and a scoring rubric.
Produces a compiled results report with a threshold-based verdict.

Required:
  --challenger <skill>   Skill under evaluation.

Optional:
  --champion <skill>        Explicit champion. Mutually exclusive with --compare-main.
  --compare-main            Extract champion from same path on git main branch.
  --label <string>          Run directory label (default: comparison).
  --threshold <int>         Minimum point delta required to act (default: 3).
  --creation-model <model>  Model for Phase 2 skill creation (default: sonnet).
  --scoring-model <model>   Model for Phase 3 scoring and Phase 4 decision (default: sonnet).

Skill reference formats:
  bare name    occ-skill-creator     -> .claude/skills/occ-skill-creator/SKILL.md
  directory    path/to/skill/        -> path/to/skill/SKILL.md
  .md path     path/to/SKILL.md      -> path/to/SKILL.md

Modes:
  Champion vs Challenger   --champion provided (explicit comparison between two skills)
  Git main comparison      --compare-main (champion extracted from main branch)
  Baseline                 Neither flag (challenger vs model with no skill loaded)

Environment:
  BENCHMARK_SKIP_PERMISSIONS=1   Use --dangerously-skip-permissions instead of
                                  --permission-mode dontAsk
EOF
}

# ─── Arg parsing ───────────────────────────────────────────────────────────────

CHALLENGER_REF=""
CHAMPION_REF=""
COMPARE_MAIN=false
LABEL="comparison"
THRESHOLD=3
CREATION_MODEL="sonnet"
SCORING_MODEL="sonnet"

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --challenger)       CHALLENGER_REF="$2";    shift 2 ;;
    --champion)         CHAMPION_REF="$2";      shift 2 ;;
    --compare-main)     COMPARE_MAIN=true;       shift 1 ;;
    --label)            LABEL="$2";             shift 2 ;;
    --threshold)        THRESHOLD="$2";         shift 2 ;;
    --creation-model)   CREATION_MODEL="$2";    shift 2 ;;
    --scoring-model)    SCORING_MODEL="$2";     shift 2 ;;
    --help|-h)          usage; exit 0 ;;
    *) echo "ERROR: Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ─── Validation ────────────────────────────────────────────────────────────────

if [[ -z "$CHALLENGER_REF" ]]; then
  echo "ERROR: --challenger is required" >&2
  exit 1
fi

if [[ "$COMPARE_MAIN" == true && -n "$CHAMPION_REF" ]]; then
  echo "ERROR: --champion and --compare-main are mutually exclusive" >&2
  exit 1
fi

# ─── Mode detection and skill path resolution ───────────────────────────────────

CHALLENGER_MD="$(resolve_skill "$CHALLENGER_REF")"
CHALLENGER_NAME="${CHALLENGER_REF##*/}"
CHALLENGER_NAME="${CHALLENGER_NAME%.md}"

if [[ ! -f "$CHALLENGER_MD" ]]; then
  echo "ERROR: SKILL.md not found at $CHALLENGER_MD" >&2
  exit 1
fi

if [[ -n "$CHAMPION_REF" ]]; then
  MODE="champion-vs-challenger"
  CHAMPION_MD="$(resolve_skill "$CHAMPION_REF")"
  CHAMPION_NAME="${CHAMPION_REF##*/}"
  CHAMPION_NAME="${CHAMPION_NAME%.md}"
  if [[ ! -f "$CHAMPION_MD" ]]; then
    echo "ERROR: SKILL.md not found at $CHAMPION_MD" >&2
    exit 1
  fi
elif [[ "$COMPARE_MAIN" == true ]]; then
  MODE="compare-main"
  CHAMPION_MD=""   # resolved in Phase 1 after RUN_DIR is created
  CHAMPION_NAME="${CHALLENGER_NAME} (main branch)"
  CHALLENGER_RELATIVE="${CHALLENGER_MD#"$REPO_ROOT/"}"
else
  MODE="baseline"
  CHAMPION_MD=""
  CHAMPION_NAME="baseline (no skill)"
fi

PERM_FLAG="--permission-mode dontAsk"
if [[ "${BENCHMARK_SKIP_PERMISSIONS:-}" == "1" ]]; then
  PERM_FLAG="--dangerously-skip-permissions"
fi

# ─── Directory setup ───────────────────────────────────────────────────────────

TIMESTAMP="$(date -u '+%Y%m%d-%H%M%S')"
BASE="$REPO_ROOT/benchmark/runs/${LABEL}__${TIMESTAMP}"

mkdir -p "$BASE/logs"
exec > >(tee -a "$BASE/run.log") 2>&1

# ─── Git main extraction (--compare-main mode) ─────────────────────────────────
# Must run after mkdir so we have a directory to write the extracted file into,
# and before SKILL_MD_PATHS is built so CHAMPION_MD is set correctly.

if [[ "$MODE" == "compare-main" ]]; then
  mkdir -p "$BASE/champion"
  CHAMPION_MD="$BASE/champion/main-branch-SKILL.md"
  echo "==> Extracting champion from main branch: $CHALLENGER_RELATIVE"
  if ! git -C "$REPO_ROOT" show "main:$CHALLENGER_RELATIVE" >"$CHAMPION_MD" 2>/dev/null; then
    echo "ERROR: $CHALLENGER_RELATIVE not found on main branch — use --champion for an explicit path or omit for baseline mode" >&2
    exit 1
  fi
  echo "    Written to: $CHAMPION_MD"
  echo ""
fi

declare -A INPUT_FILES=(
  [T1]="T1-simple.md"
  [T2]="T2-medium.md"
  [T3]="T3-complex.md"
)
INPUTS=("T1" "T2" "T3")
SLOTS=("champion" "challenger")

declare -A SKILL_MD_PATHS=(
  [champion]="$CHAMPION_MD"
  [challenger]="$CHALLENGER_MD"
)
declare -A SKILL_NAMES=(
  [champion]="$CHAMPION_NAME"
  [challenger]="$CHALLENGER_NAME"
)

# In baseline mode the champion slot directory is named "baseline/" not "champion/"
declare -A SLOT_DIRS
SLOT_DIRS[challenger]="challenger"
if [[ "$MODE" == "baseline" ]]; then
  SLOT_DIRS[champion]="baseline"
else
  SLOT_DIRS[champion]="champion"
fi

# ─── Preflight checks ──────────────────────────────────────────────────────────

echo "==> Preflight checks"

if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH. Install Claude Code first." >&2
  exit 1
fi

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

echo "==> Phase 1: Setup — run: ${LABEL}__${TIMESTAMP} | mode: $MODE"
echo "    Output: $BASE"
echo ""

for slot in "${SLOTS[@]}"; do
  for input_id in "${INPUTS[@]}"; do
    mkdir -p "$BASE/${SLOT_DIRS[$slot]}/$input_id"
    mkdir -p "$BASE/scores/${SLOT_DIRS[$slot]}/$input_id"
  done
done

GIT_HASH=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
MANIFEST="$BASE/manifest.md"

{
  echo "# Benchmark Manifest"
  echo ""
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| Run label | ${LABEL}__${TIMESTAMP} |"
  echo "| Date (UTC) | $(date -u '+%Y-%m-%d %H:%M:%S') |"
  echo "| Git hash | $GIT_HASH |"
  echo "| Mode | $MODE |"
  echo "| Champion | $CHAMPION_NAME |"
  [[ -n "$CHAMPION_MD" ]] && echo "| Champion path | $CHAMPION_MD |"
  echo "| Challenger | $CHALLENGER_NAME |"
  echo "| Challenger path | $CHALLENGER_MD |"
  echo "| Threshold | $THRESHOLD |"
  echo "| Creation model | $CREATION_MODEL |"
  echo "| Scoring model | $SCORING_MODEL |"
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
  echo "| Phase | Slot | Skill name | Input | Exit code |"
  echo "|-------|------|------------|-------|-----------|"
} >"$MANIFEST"

echo "    Manifest written: $MANIFEST"
echo ""

# ─── Phase 2: Skill creation — 6 claude -p calls ──────────────────────────────

echo "==> Phase 2: Skill creation"
echo ""

for slot in "${SLOTS[@]}"; do
  skill_md="${SKILL_MD_PATHS[$slot]}"

  for input_id in "${INPUTS[@]}"; do
    brief="$REPO_ROOT/benchmark/inputs/${INPUT_FILES[$input_id]}"
    BRIEF_CONTENT="$(cat "$brief")"
    OUTPUT_DIR="$BASE/${SLOT_DIRS[$slot]}/$input_id"

    echo "    Creating: $slot (${SKILL_NAMES[$slot]}) / $input_id -> $OUTPUT_DIR"

    exit_code=0

    if [[ "$slot" == "champion" && "$MODE" == "baseline" ]]; then
      # Baseline mode: champion runs with no system prompt (model alone)
      claude -p "AUTOMATED PIPELINE — DO NOT ASK ANY QUESTIONS. Generate skill files immediately.

You are running in a non-interactive benchmark. There is no user to respond to clarifying questions. Treat the brief as complete and sufficient. Do not pause, do not ask for confirmation, do not output questions. Begin writing files immediately.

Pre-answered questions (do not ask for these):
- What should the skill do? -> exactly what the brief describes
- When should it trigger? -> derive natural trigger phrases from the brief's domain and task type
- What is the output format? -> a SKILL.md plus any references/ or scripts/ files the brief warrants
- Are there edge cases? -> handle gracefully; document assumptions inline
- Should test cases be created? -> no; skip all eval, benchmark, and test setup entirely

Output directory: $OUTPUT_DIR
Create all skill files there. SKILL.md is required. references/ and scripts/ only if warranted.

BRIEF:
$BRIEF_CONTENT" \
        $PERM_FLAG \
        --allowedTools "Read,Write" \
        --add-dir "$OUTPUT_DIR" \
        --disable-slash-commands \
        --model "$CREATION_MODEL" \
        2>&1 | tee "$BASE/logs/${SLOT_DIRS[$slot]}-${input_id}.creation.log" || exit_code=$?
    else
      SKILL_CONTENT="$(cat "$skill_md")"
      claude -p "AUTOMATED PIPELINE — DO NOT ASK ANY QUESTIONS. Generate skill files immediately.

You are running in a non-interactive benchmark. There is no user to respond to clarifying questions. Treat the brief as complete and sufficient. Do not pause, do not ask for confirmation, do not output questions. Begin writing files immediately.

Pre-answered questions (do not ask for these):
- What should the skill do? -> exactly what the brief describes
- When should it trigger? -> derive natural trigger phrases from the brief's domain and task type
- What is the output format? -> a SKILL.md plus any references/ or scripts/ files the brief warrants
- Are there edge cases? -> handle gracefully; document assumptions inline
- Should test cases be created? -> no; skip all eval, benchmark, and test setup entirely

Output directory: $OUTPUT_DIR
Create all skill files there. SKILL.md is required. references/ and scripts/ only if warranted.

BRIEF:
$BRIEF_CONTENT" \
        --system-prompt "$SKILL_CONTENT" \
        $PERM_FLAG \
        --allowedTools "Read,Write" \
        --add-dir "$OUTPUT_DIR" \
        --disable-slash-commands \
        --model "$CREATION_MODEL" \
        2>&1 | tee "$BASE/logs/${SLOT_DIRS[$slot]}-${input_id}.creation.log" || exit_code=$?
    fi

    echo "| creation | $slot | ${SKILL_NAMES[$slot]} | $input_id | $exit_code |" >>"$MANIFEST"
    echo "    Exit code: $exit_code"
    echo ""
  done
done

# ─── Post-phase 2 check ────────────────────────────────────────────────────────

echo "==> Post-phase 2 check: verifying SKILL.md exists in each output dir"
echo ""

creation_failures=0
for slot in "${SLOTS[@]}"; do
  for input_id in "${INPUTS[@]}"; do
    output_dir="$BASE/${SLOT_DIRS[$slot]}/$input_id"
    if [[ ! -f "$output_dir/SKILL.md" ]]; then
      echo "    WARN: No SKILL.md found — $slot / $input_id (creation likely asked a question or failed)"
      echo "| warn: missing SKILL.md | $slot | ${SKILL_NAMES[$slot]} | $input_id | — |" >>"$MANIFEST"
      creation_failures=$((creation_failures + 1))
    else
      echo "    OK: $slot (${SKILL_NAMES[$slot]}) / $input_id"
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

for slot in "${SLOTS[@]}"; do
  for input_id in "${INPUTS[@]}"; do
    SKILL_OUTPUT_DIR="$BASE/${SLOT_DIRS[$slot]}/$input_id"
    SCORE_FILE="$BASE/scores/${SLOT_DIRS[$slot]}/$input_id/scores.md"

    echo "    Scoring: $slot (${SKILL_NAMES[$slot]}) / $input_id -> $SCORE_FILE"

    # Build style context for this slot
    if [[ "$slot" == "champion" && "$MODE" == "baseline" ]]; then
      STYLE_CONTEXT="Style adherence: Score this dimension 0. No skill was loaded for this slot (baseline run). By definition there are no skill conventions to follow."
    else
      LOADED_SKILL_CONTENT="$(cat "${SKILL_MD_PATHS[$slot]}")"
      STYLE_CONTEXT="Style adherence: The following skill was loaded during creation. Score how consistently the output follows its conventions (frontmatter format, section structure, prose style, trigger phrase style).

LOADED SKILL:
$LOADED_SKILL_CONTENT"
    fi

    exit_code=0
    claude -p "Score the skill at: $SKILL_OUTPUT_DIR
Read SKILL.md and any reference files in that directory.
Apply the rubric below. Write your scores to: $SCORE_FILE

$STYLE_CONTEXT

$RUBRIC_CONTENT" \
      --system-prompt "You are a skill quality evaluator. Score strictly and objectively. Output only the scores.md file — no other commentary." \
      $PERM_FLAG \
      --allowedTools "Read,Write" \
      --add-dir "$BASE" \
      --model "$SCORING_MODEL" \
      2>&1 | tee "$BASE/logs/${SLOT_DIRS[$slot]}-${input_id}.scoring.log" || exit_code=$?

    echo "| scoring | $slot | ${SKILL_NAMES[$slot]} | $input_id | $exit_code |" >>"$MANIFEST"
    echo "    Exit code: $exit_code"
    echo ""
  done
done

# ─── Phase 4: Decision — 1 claude -p call ─────────────────────────────────────

echo "==> Phase 4: Decision -> $BASE/decision.md"
echo ""

exit_code=0
claude -p "You are a benchmark decision agent. Complete all steps below in order.

## Run context

- Run label: ${LABEL}__${TIMESTAMP}
- Mode: $MODE
- Champion: ${SKILL_NAMES[champion]}
- Challenger: ${SKILL_NAMES[challenger]}
- Threshold: $THRESHOLD points (delta must reach or exceed this to act)

## Step 1 — Read all 6 score files

Read each file listed below. Each scores.md contains per-dimension scores (integer 0–3, 7 dimensions, max 21 per file).

Champion scores:
  $BASE/scores/${SLOT_DIRS[champion]}/T1/scores.md
  $BASE/scores/${SLOT_DIRS[champion]}/T2/scores.md
  $BASE/scores/${SLOT_DIRS[champion]}/T3/scores.md

Challenger scores:
  $BASE/scores/challenger/T1/scores.md
  $BASE/scores/challenger/T2/scores.md
  $BASE/scores/challenger/T3/scores.md

## Step 2 — Compute totals and delta

- champion_total = sum of all champion dimension scores across T1+T2+T3 (max 63)
- challenger_total = sum of all challenger dimension scores across T1+T2+T3 (max 63)
- delta = |champion_total - challenger_total| (absolute difference)
- leading = whichever has the higher total; if equal, delta = 0

## Step 3 — Determine verdict

Apply the correct verdict table based on mode.

If mode = baseline:
  - delta < $THRESHOLD                            → NO VALUE
  - delta >= $THRESHOLD AND challenger_total > champion_total → PROMOTE
  - delta >= $THRESHOLD AND champion_total > challenger_total → REJECT

If mode = champion-vs-challenger OR compare-main:
  - delta < $THRESHOLD                            → NO CHANGE
  - delta >= $THRESHOLD AND challenger_total > champion_total → SWITCH RECOMMENDED
  - delta >= $THRESHOLD AND champion_total > challenger_total → CHAMPION CONFIRMED

## Step 4 — Write $BASE/decision.md

Use exactly this structure:

\`\`\`
# Benchmark Decision

| Field | Value |
|-------|-------|
| Run | ${LABEL}__${TIMESTAMP} |
| Mode | $MODE |
| Champion | ${SKILL_NAMES[champion]} |
| Challenger | ${SKILL_NAMES[challenger]} |
| Threshold | $THRESHOLD / 63 |

## Verdict

**<VERDICT KEYWORD>**

<One paragraph: state the delta, which skill led, whether the threshold was met, and the key reason for the verdict.>

## Score Summary

| Skill | Score | Delta |
|-------|-------|-------|
| ${SKILL_NAMES[champion]} | <champion_total>/63 | <show delta with + or - relative to challenger> |
| ${SKILL_NAMES[challenger]} | <challenger_total>/63 | <show delta with + or - relative to champion> |

## Score Matrix

| Dimension | Champion T1 | Champion T2 | Champion T3 | Champion Total | Challenger T1 | Challenger T2 | Challenger T3 | Challenger Total |
|-----------|-------------|-------------|-------------|----------------|---------------|---------------|---------------|-----------------|
| Frontmatter quality | | | | | | | | |
| Trigger specificity | | | | | | | | |
| Instruction quality | | | | | | | | |
| Progressive disclosure | | | | | | | | |
| Structure compliance | | | | | | | | |
| Conciseness | | | | | | | | |
| Style adherence | | | | | | | | |
| **TOTAL** | | | | **<champion_total>/63** | | | | **<challenger_total>/63** |

## Per-Dimension Analysis

For each of the 7 dimensions, one sentence: which skill scored higher and why (or \"tied\" if equal).

## Next Steps

Based on the verdict, one to three concrete recommendations.
\`\`\`

## Step 5 — Append one table row to $REPO_ROOT/docs/benchmark-run-history.md

Read the file first. If it contains a markdown table with columns:
  Run timestamp | Label | Champion | Challenger | Champion score | Challenger score | Verdict

Append a new row:
  | ${TIMESTAMP} | ${LABEL} | ${SKILL_NAMES[champion]} | ${SKILL_NAMES[challenger]} | <champion_total>/63 | <challenger_total>/63 | <VERDICT KEYWORD> |

If no such table exists yet, append the following block at the end of the file:

## Run History

| Run timestamp | Label | Champion | Challenger | Champion score | Challenger score | Verdict |
|---------------|-------|----------|------------|----------------|------------------|---------|
| ${TIMESTAMP} | ${LABEL} | ${SKILL_NAMES[champion]} | ${SKILL_NAMES[challenger]} | <champion_total>/63 | <challenger_total>/63 | <VERDICT KEYWORD> |" \
  --system-prompt "You are a benchmark decision agent. Follow all steps exactly. Do not ask questions. Do not summarize — write the files." \
  $PERM_FLAG \
  --allowedTools "Read,Write" \
  --add-dir "$BASE" \
  --add-dir "$REPO_ROOT/docs" \
  --model "$SCORING_MODEL" \
  2>&1 | tee "$BASE/logs/decision.log" || exit_code=$?

echo "| decision | — | — | — | $exit_code |" >>"$MANIFEST"
echo "    Exit code: $exit_code"
echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "==> Done — run: ${LABEL}__${TIMESTAMP}"
echo ""
echo "    Decision: $BASE/decision.md"
echo "    History:  $REPO_ROOT/docs/benchmark-run-history.md"
echo "    Outputs:  $BASE"
echo "    Manifest: $MANIFEST"
