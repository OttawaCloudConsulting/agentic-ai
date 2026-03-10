#!/usr/bin/env bash
# run-variance.sh — Multi-run benchmark wrapper with statistical aggregation.
# Usage: bash scripts/benchmark/run-variance.sh --challenger <skill> [--runs N] [options]
# All flags except --runs pass through to run-benchmark.sh unchanged.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: bash scripts/benchmark/run-variance.sh --challenger <skill> [--runs N] [options]

Runs run-benchmark.sh N times and writes a variance-report.md with mean/stddev
per dimension per slot, verdict distribution, and individual run results.

Required:
  --challenger <skill>   Skill under evaluation.

Variance:
  --runs <N>             Number of runs (default: 3, minimum: 2).

Passthrough (forwarded to run-benchmark.sh unchanged):
  --champion <skill>        Explicit champion.
  --compare-main            Champion from git main branch.
  --label <string>          Run label prefix (default: comparison).
  --threshold <int>         Minimum delta (default: 3).
  --creation-model <model>  Model for skill creation (default: sonnet).
  --scoring-model <model>   Model for scoring and decision (default: sonnet).

Environment:
  BENCHMARK_SKIP_PERMISSIONS=1   Passed through to each run-benchmark.sh call.

Output:
  benchmark/runs/variance__<label>__<timestamp>/variance-report.md
EOF
}

# ─── Arg parsing ──────────────────────────────────────────────────────────────

RUNS=3
LABEL="comparison"
CHALLENGER_REF=""
HAS_CHAMPION=false
HAS_COMPARE_MAIN=false
PASSTHROUGH_ARGS=()

if [[ $# -eq 0 ]]; then usage; exit 0; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)           RUNS="$2";                                   shift 2 ;;
    --label)          LABEL="$2";                                  shift 2 ;;
    --challenger)     CHALLENGER_REF="$2"; PASSTHROUGH_ARGS+=("$1" "$2"); shift 2 ;;
    --champion)       HAS_CHAMPION=true;   PASSTHROUGH_ARGS+=("$1" "$2"); shift 2 ;;
    --compare-main)   HAS_COMPARE_MAIN=true; PASSTHROUGH_ARGS+=("$1");    shift 1 ;;
    --threshold)      PASSTHROUGH_ARGS+=("$1" "$2");               shift 2 ;;
    --creation-model) PASSTHROUGH_ARGS+=("$1" "$2");               shift 2 ;;
    --scoring-model)  PASSTHROUGH_ARGS+=("$1" "$2");               shift 2 ;;
    --help|-h)        usage; exit 0 ;;
    *)                PASSTHROUGH_ARGS+=("$1");                    shift 1 ;;
  esac
done

# ─── Validation ───────────────────────────────────────────────────────────────

if [[ -z "$CHALLENGER_REF" ]]; then
  echo "ERROR: --challenger is required" >&2; exit 1
fi

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || (( RUNS < 2 )); then
  echo "ERROR: --runs must be an integer >= 2 (got: $RUNS)" >&2; exit 1
fi

# ─── Mode detection ───────────────────────────────────────────────────────────
# Determines the slot directory name for the champion/baseline slot.

if [[ "$HAS_CHAMPION" == true || "$HAS_COMPARE_MAIN" == true ]]; then
  CHAMP_SLOT_DIR="champion"
else
  CHAMP_SLOT_DIR="baseline"
fi

# ─── Variance parent directory ────────────────────────────────────────────────

TIMESTAMP="$(date -u '+%Y%m%d-%H%M%S')"
VARIANCE_DIR="$REPO_ROOT/benchmark/runs/variance__${LABEL}__${TIMESTAMP}"
mkdir -p "$VARIANCE_DIR"

echo "==> Variance analysis: $RUNS runs — label: $LABEL"
echo "    Parent: $VARIANCE_DIR"
echo ""

# ─── Execute N runs ────────────────────────────────────────────────────────────

declare -a RUN_DIRS=()
declare -a VERDICTS=()

for i in $(seq 1 "$RUNS"); do
  VAR_LABEL="${LABEL}__var${i}"
  echo "==> Run $i / $RUNS  (label: $VAR_LABEL)"

  bash "$REPO_ROOT/scripts/benchmark/run-benchmark.sh" \
    --label "$VAR_LABEL" \
    "${PASSTHROUGH_ARGS[@]}" \
    2>&1 | tee "$VARIANCE_DIR/run-${i}.log"

  # Locate the run directory created by this invocation
  run_dir=$(ls -dt "$REPO_ROOT/benchmark/runs/${VAR_LABEL}__"* 2>/dev/null | head -1 || true)
  if [[ -z "$run_dir" ]]; then
    echo "ERROR: Run directory not found for label $VAR_LABEL" >&2; exit 1
  fi
  RUN_DIRS+=("$run_dir")

  # Extract verdict keyword from decision.md
  verdict=$(grep -oE '\*\*(PROMOTE|NO VALUE|REJECT|SWITCH RECOMMENDED|NO CHANGE|CHAMPION CONFIRMED)\*\*' \
    "$run_dir/decision.md" 2>/dev/null | head -1 | sed 's/\*\*//g' || true)
  [[ -z "$verdict" ]] && verdict="UNKNOWN"
  VERDICTS+=("$verdict")

  echo "    -> Verdict: $verdict"
  echo ""
done

# ─── Score parsing ────────────────────────────────────────────────────────────
# parse_scores_file <path>
# Prints 7 integer scores (one per line) then "TOTAL:<n>".
# Outputs zeros if file is missing.

parse_scores_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf '0\n0\n0\n0\n0\n0\n0\nTOTAL:0\n'
    return
  fi
  awk 'BEGIN { FS="|"; count=0 }
    /\*\*TOTAL\*\*/ {
      t=$3; gsub(/[^0-9\/]/, "", t)
      n=split(t, a, "/"); printf "TOTAL:%d\n", (n>0 ? a[1]+0 : 0); next
    }
    /^\|/ && count<7 {
      score=$3; gsub(/[^0-9]/, "", score)
      if (length(score)==1 && score+0>=0 && score+0<=3) {
        printf "%d\n", score+0; count++
      }
    }
  ' "$path"
}

# ─── Data collection ──────────────────────────────────────────────────────────
# Per run: sum dimension scores across T1+T2+T3 for each slot.
# Flat array indexed by: run_idx * N_DIMS + dim_idx (both 0-based).

DIMS=("Frontmatter quality" "Trigger specificity" "Instruction quality" \
      "Progressive disclosure" "Structure compliance" "Conciseness" "Style adherence")
N_DIMS=7
INPUTS=("T1" "T2" "T3")

declare -a CHAMP_DIM_SUMS=()
declare -a CHALL_DIM_SUMS=()
declare -a CHAMP_RUN_TOTALS=()
declare -a CHALL_RUN_TOTALS=()

for i in $(seq 0 $(( RUNS * N_DIMS - 1 ))); do
  CHAMP_DIM_SUMS[$i]=0
  CHALL_DIM_SUMS[$i]=0
done
for i in $(seq 0 $(( RUNS - 1 ))); do
  CHAMP_RUN_TOTALS[$i]=0
  CHALL_RUN_TOTALS[$i]=0
done

for run_idx in "${!RUN_DIRS[@]}"; do
  run_dir="${RUN_DIRS[$run_idx]}"
  for slot_dir in "$CHAMP_SLOT_DIR" "challenger"; do
    for input in "${INPUTS[@]}"; do
      scores_file="$run_dir/scores/$slot_dir/$input/scores.md"
      readarray -t parsed < <(parse_scores_file "$scores_file")

      for dim_idx in $(seq 0 $(( N_DIMS - 1 ))); do
        score="${parsed[$dim_idx]:-0}"
        flat_idx=$(( run_idx * N_DIMS + dim_idx ))
        if [[ "$slot_dir" == "$CHAMP_SLOT_DIR" ]]; then
          CHAMP_DIM_SUMS[$flat_idx]=$(( ${CHAMP_DIM_SUMS[$flat_idx]} + score ))
        else
          CHALL_DIM_SUMS[$flat_idx]=$(( ${CHALL_DIM_SUMS[$flat_idx]} + score ))
        fi
      done

      total_line="${parsed[$N_DIMS]:-TOTAL:0}"
      t="${total_line#TOTAL:}"
      if [[ "$slot_dir" == "$CHAMP_SLOT_DIR" ]]; then
        CHAMP_RUN_TOTALS[$run_idx]=$(( ${CHAMP_RUN_TOTALS[$run_idx]} + t ))
      else
        CHALL_RUN_TOTALS[$run_idx]=$(( ${CHALL_RUN_TOTALS[$run_idx]} + t ))
      fi
    done
  done
done

# ─── Statistics ───────────────────────────────────────────────────────────────
# mean_std <space-separated integers> → prints "mean std" (floats)

mean_std() {
  echo "$@" | tr ' ' '\n' | awk '
    { v=$1+0; sum+=v; sum2+=v*v; n++ }
    END {
      if (n==0) { print "0.0 0.0"; exit }
      mean=sum/n
      var=(n>1) ? (sum2 - sum*sum/n)/(n-1) : 0
      printf "%.1f %.1f\n", mean, sqrt(var<0?0:var)
    }'
}

read -r CHAMP_MEAN CHAMP_STD < <(mean_std "${CHAMP_RUN_TOTALS[@]}")
read -r CHALL_MEAN CHALL_STD < <(mean_std "${CHALL_RUN_TOTALS[@]}")

CHAMP_MIN="${CHAMP_RUN_TOTALS[0]}"; CHAMP_MAX="${CHAMP_RUN_TOTALS[0]}"
CHALL_MIN="${CHALL_RUN_TOTALS[0]}"; CHALL_MAX="${CHALL_RUN_TOTALS[0]}"
for v in "${CHAMP_RUN_TOTALS[@]}"; do
  (( v < CHAMP_MIN )) && CHAMP_MIN=$v
  (( v > CHAMP_MAX )) && CHAMP_MAX=$v
done
for v in "${CHALL_RUN_TOTALS[@]}"; do
  (( v < CHALL_MIN )) && CHALL_MIN=$v
  (( v > CHALL_MAX )) && CHALL_MAX=$v
done

MEAN_DELTA=$(awk "BEGIN { printf \"%+.1f\", $CHALL_MEAN - $CHAMP_MEAN }")

declare -a CHAMP_DIM_MEANS=()
declare -a CHAMP_DIM_STDS=()
declare -a CHALL_DIM_MEANS=()
declare -a CHALL_DIM_STDS=()

for dim_idx in $(seq 0 $(( N_DIMS - 1 ))); do
  champ_vals=""
  chall_vals=""
  for run_idx in $(seq 0 $(( RUNS - 1 ))); do
    flat_idx=$(( run_idx * N_DIMS + dim_idx ))
    champ_vals+="${CHAMP_DIM_SUMS[$flat_idx]} "
    chall_vals+="${CHALL_DIM_SUMS[$flat_idx]} "
  done
  read -r m s < <(mean_std $champ_vals)
  CHAMP_DIM_MEANS[$dim_idx]="$m"; CHAMP_DIM_STDS[$dim_idx]="$s"
  read -r m s < <(mean_std $chall_vals)
  CHALL_DIM_MEANS[$dim_idx]="$m"; CHALL_DIM_STDS[$dim_idx]="$s"
done

# ─── Verdict distribution and recommendation ──────────────────────────────────

declare -A VERDICT_COUNTS=()
for v in "${VERDICTS[@]}"; do
  VERDICT_COUNTS["$v"]=$(( ${VERDICT_COUNTS["$v"]:-0} + 1 ))
done

WINNING_VERDICT=""
MAX_COUNT=0
for v in "${!VERDICT_COUNTS[@]}"; do
  c="${VERDICT_COUNTS[$v]}"
  (( c > MAX_COUNT )) && { MAX_COUNT=$c; WINNING_VERDICT="$v"; }
done

MAJORITY_THRESHOLD=$(( RUNS / 2 + 1 ))
if (( MAX_COUNT == RUNS )); then
  RECOMMENDATION="**${WINNING_VERDICT}** — unanimous across ${RUNS} runs (high confidence)"
elif (( MAX_COUNT >= MAJORITY_THRESHOLD )); then
  RECOMMENDATION="**${WINNING_VERDICT}** — majority ${MAX_COUNT}/${RUNS} runs (moderate confidence)"
else
  RECOMMENDATION="**Split result** — low confidence; review individual run decisions before acting"
fi

# ─── Extract skill names from first run's manifest ────────────────────────────

CHAMP_NAME="champion"
CHALL_NAME="challenger"
if [[ -f "${RUN_DIRS[0]}/manifest.md" ]]; then
  CHAMP_NAME=$(awk -F'|' '$2 ~ /^ *Champion *$/ { gsub(/^ +| +$/, "", $3); print $3; exit }' \
    "${RUN_DIRS[0]}/manifest.md")
  CHALL_NAME=$(awk -F'|' '$2 ~ /^ *Challenger *$/ { gsub(/^ +| +$/, "", $3); print $3; exit }' \
    "${RUN_DIRS[0]}/manifest.md")
fi

# ─── Write variance-report.md ─────────────────────────────────────────────────

REPORT="$VARIANCE_DIR/variance-report.md"

{
  cat <<EOF
# Variance Report: ${LABEL}

| Field | Value |
|-------|-------|
| Runs | ${RUNS} |
| Champion / Baseline | ${CHAMP_NAME} |
| Challenger | ${CHALL_NAME} |
| Timestamp | ${TIMESTAMP} |

## Verdict Distribution

| Verdict | Count |
|---------|-------|
EOF

  for v in "${!VERDICT_COUNTS[@]}"; do
    echo "| ${v} | ${VERDICT_COUNTS[$v]} |"
  done

  echo ""
  echo "**Recommendation:** ${RECOMMENDATION}"
  echo ""

  cat <<EOF
## Score Summary (Mean ± Stddev)

| Slot | Mean | Stddev | Min | Max |
|------|------|--------|-----|-----|
| ${CHAMP_NAME} | ${CHAMP_MEAN} | ${CHAMP_STD} | ${CHAMP_MIN} | ${CHAMP_MAX} |
| ${CHALL_NAME} | ${CHALL_MEAN} | ${CHALL_STD} | ${CHALL_MIN} | ${CHALL_MAX} |
| **Mean delta** | **${MEAN_DELTA}** | | | |

## Per-Dimension Analysis

### ${CHAMP_NAME}

| Dimension | Mean | Stddev |
|-----------|------|--------|
EOF

  for dim_idx in $(seq 0 $(( N_DIMS - 1 ))); do
    echo "| ${DIMS[$dim_idx]} | ${CHAMP_DIM_MEANS[$dim_idx]} | ${CHAMP_DIM_STDS[$dim_idx]} |"
  done

  echo ""
  echo "### ${CHALL_NAME}"
  echo ""
  echo "| Dimension | Mean | Stddev |"
  echo "|-----------|------|--------|"

  for dim_idx in $(seq 0 $(( N_DIMS - 1 ))); do
    echo "| ${DIMS[$dim_idx]} | ${CHALL_DIM_MEANS[$dim_idx]} | ${CHALL_DIM_STDS[$dim_idx]} |"
  done

  echo ""
  echo "## Individual Run Results"
  echo ""
  echo "| Run | Champion total | Challenger total | Delta | Verdict |"
  echo "|-----|---------------|-----------------|-------|---------|"

  for run_idx in "${!RUN_DIRS[@]}"; do
    run_num=$(( run_idx + 1 ))
    ct="${CHAMP_RUN_TOTALS[$run_idx]}"
    xt="${CHALL_RUN_TOTALS[$run_idx]}"
    delta=$(( xt - ct ))
    if (( delta >= 0 )); then delta_str="+${delta}"; else delta_str="${delta}"; fi
    echo "| var${run_num} | ${ct}/63 | ${xt}/63 | ${delta_str} | ${VERDICTS[$run_idx]} |"
  done

  echo ""
  echo "## Run Directories"
  echo ""

  for run_idx in "${!RUN_DIRS[@]}"; do
    run_num=$(( run_idx + 1 ))
    echo "- var${run_num}: ${RUN_DIRS[$run_idx]}"
  done

} > "$REPORT"

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "==> Variance analysis complete"
echo ""
echo "    Runs:           $RUNS"
echo "    Verdicts:       ${VERDICTS[*]}"
echo "    Recommendation: $RECOMMENDATION"
echo ""
echo "    Report:     $REPORT"
echo "    Parent dir: $VARIANCE_DIR"
