# Benchmark User Guide

New to the benchmark? Start with SETUP.md to install, then LIFECYCLE-GUIDE.md to understand when to run and what verdicts mean before using this guide.

How to accomplish real tasks with the benchmark tooling. For flag and output reference, see [REFERENCE.md](REFERENCE.md).

---

## Contents

- [Running inside Claude Code](#running-inside-claude-code)
- [Workflow 1: Validating a new skill for the first time](#workflow-1-validating-a-new-skill-for-the-first-time)
- [Workflow 2: Testing a revision against main](#workflow-2-testing-a-revision-against-main)
- [Workflow 3: Comparing two skills directly](#workflow-3-comparing-two-skills-directly)
- [Workflow 4: Multi-run variance analysis](#workflow-4-multi-run-variance-analysis)
- [Reading a decision.md](#reading-a-decisionmd)
- [Interpreting scores](#interpreting-scores)

---

## Running inside Claude Code

The `claude` CLI blocks nested invocations by default. Running the benchmark from inside a Claude Code session without the prefix produces:

```
Error: Claude Code cannot be launched inside another Claude Code session.
```

Prefix every benchmark command with `env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1` to unset the blocking variable and switch to the correct permissions mode for interactive sessions:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger occ-skill-creator --label my-run
```

All examples in this guide include this prefix. If you are running from a plain terminal outside Claude Code (CI, cron, shell), the prefix is harmless and safe to include anyway.

---

## Workflow 1: Validating a new skill for the first time

**When to use:** You have written or imported a skill and want to know whether it produces better outputs than the model with no skill loaded at all.

This is the baseline gate — the hurdle every new skill must clear before being promoted to active use.

### Step 1: Quick single run

Start with one run to get a directional signal.

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger your-skill-name \
  --label your-skill-v1-baseline \
  --creation-model haiku \
  --threshold 5
```

Use `--creation-model haiku` for baseline runs. Haiku has weaker priors than Sonnet and relies more on skill guidance, which widens the gap between guided and unguided outputs. On the same skill, haiku typically produces deltas of +7 to +11 where sonnet may produce +2 to +4. The wider gap makes the verdict more reliable and easier to interpret.

**What to look at in the output:**

- The `VERDICT` line in `benchmark/runs/<label>__<timestamp>/decision.md`
- The delta in the Score Summary table
- The Per-Dimension Analysis section for where points were gained or lost

### Step 2: Confirm with variance analysis

If the single-run delta is under 7, run variance analysis before deciding to promote. See [Workflow 4](#workflow-4-multi-run-variance-analysis).

### Verdict guide for baseline runs

| Verdict | Delta | Action |
|---------|-------|--------|
| `PROMOTE` with delta ≥ 7 | Strong signal | Promote the skill — safe to ship |
| `PROMOTE` with delta 5–6 | Moderate signal | Run variance before promoting |
| `PROMOTE` with delta 3–4 | Weak signal | Run variance; if majority, promote cautiously |
| `NO VALUE` | Below threshold | Do not promote; revisit the skill or the briefs |
| `REJECT` | Baseline leads | The skill is actively hurting quality; revise before promoting |

---

## Workflow 2: Testing a revision against main

**When to use:** You have edited an existing skill on a feature branch and want to confirm the revision improves on what is currently in `main`.

The `--compare-main` flag extracts the champion automatically from the `main` branch at the same skill path. You do not need to manage file copies.

**Requirement:** The skill must already exist at the same path on `main`. If it is new and not yet merged, use [Workflow 1](#workflow-1-validating-a-new-skill-for-the-first-time) or [Workflow 3](#workflow-3-comparing-two-skills-directly) instead.

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger occ-skill-creator \
  --compare-main \
  --label occ-skill-creator-after-refactor
```

**What to look at in the output:**

- The verdict: did the challenger (your revision) lead the champion (main)?
- The Per-Dimension Analysis: which dimensions improved and which regressed?
- The Score Matrix: compare totals per dimension across all three test inputs

### Verdict guide for revision runs

| Verdict | What it means | Action |
|---------|--------------|--------|
| `SWITCH RECOMMENDED` | Revision scores ≥ threshold above main | Your edit is a meaningful improvement — safe to merge |
| `NO CHANGE` | Delta is below threshold | Revision is neutral; decide based on qualitative review |
| `CHAMPION CONFIRMED` | Main scores ≥ threshold above revision | Your changes made things worse; review the diff |

A single-run `SWITCH RECOMMENDED` is sufficient to merge a revision. Variance analysis is optional for revisions unless the delta is close to the threshold.

### If --compare-main fails

**"not found on main branch" error:** The skill path does not exist on the `main` branch. This happens when the skill is new and has not been merged yet. Use [Workflow 3](#workflow-3-comparing-two-skills-directly) with explicit `--champion` and `--challenger` paths instead.

**Wrong default branch name:** `--compare-main` looks for a branch named exactly `main`. If your repository's default branch is `master`, `trunk`, or anything else, the extraction will fail. Use [Workflow 3](#workflow-3-comparing-two-skills-directly) with an explicit `--champion` path pointing to the version you want as the champion.

**Not inside a git repository:** The flag requires `git show` to work. Run the benchmark from inside the repository root.

---

## Workflow 3: Comparing two skills directly

**When to use:** Comparing two independent implementations, evaluating a third-party skill against your own, or running a comparison from a specific known state that is not tied to git history.

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --champion .claude/skills/occ-skill-creator \
  --challenger path/to/candidate-skill \
  --label candidate-vs-current \
  --threshold 5
```

Both `--champion` and `--challenger` accept three reference formats:

```bash
--champion occ-skill-creator              # bare name → .claude/skills/<name>/SKILL.md
--champion path/to/skill-dir/             # directory → <dir>/SKILL.md
--champion path/to/skill-dir/SKILL.md     # direct .md path
```

**What to look at in the output:**

- The Score Summary table: which skill led and by how much?
- The Per-Dimension Analysis: where does the challenger win, and where does the champion hold?
- Next Steps: the decision agent's concrete recommendations

The verdict values are identical to revision mode: `SWITCH RECOMMENDED`, `NO CHANGE`, or `CHAMPION CONFIRMED`.

---

## Workflow 4: Multi-run variance analysis

**When to use:** After any single run where the delta is in the 3–6 range, or before a first-promotion decision where higher confidence is needed.

A single benchmark run invokes the model 13 times. Scores can shift by 1–2 points between runs of identical inputs due to model non-determinism. A 3-point delta from one run might be real signal or might be noise. Three runs collapse that uncertainty into a mean and a confidence level.

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger occ-skill-creator \
  --label occ-skill-creator-variance \
  --creation-model haiku \
  --runs 3
```

All `run-benchmark.sh` flags work with `run-variance.sh`. Add `--runs N` to control how many runs to execute (default 3, minimum 2). Three runs is the standard; five runs is appropriate for high-stakes promotion decisions.

Each run writes its own `decision.md` and appends a row to `docs/benchmark-run-history.md`. The variance wrapper also produces a summary at:

```
benchmark/runs/variance__<label>__<timestamp>/variance-report.md
```

### Reading the variance report

| Section | What to look at |
|---------|----------------|
| Verdict Distribution | How many runs produced each verdict. Unanimous = most reliable. |
| Recommendation | Confidence label based on unanimity: Unanimous, Majority, or Split. |
| Mean delta | Direction and magnitude across all runs. A mean of +7 is a stronger signal than any single +7. |
| Stddev (totals) | Standard deviation of total scores. Above 3 means high variance — review individual run decisions before acting. |
| Per-Dimension Analysis | Which dimensions are consistent across runs vs which fluctuate. Fluctuating dimensions signal rubric sensitivity or ambiguous skill content. |

### Confidence levels

| Label | What it means | Action |
|-------|--------------|--------|
| Unanimous | All N runs agree on the verdict | Act on the verdict |
| Majority | More than half agree | Likely correct; read the outlier run's decision.md before acting |
| Split | No majority agreement | Do not act; investigate individual run decisions to find what is causing divergence |

### Example output (abbreviated)

```
## Verdict Distribution

| Verdict  | Count |
|----------|-------|
| PROMOTE  | 2     |
| NO VALUE | 1     |

**Recommendation:** **PROMOTE** — majority 2/3 runs (moderate confidence)

## Score Summary (Mean ± Stddev)

| Slot                | Mean | Stddev | Min | Max |
|---------------------|------|--------|-----|-----|
| baseline (no skill) | 49.0 | 3.6    | 45  | 52  |
| occ-skill-refactor  | 54.7 | 2.5    | 52  | 57  |
| **Mean delta**      | **+5.7** |    |     |     |
```

A mean delta of +5.7 with majority verdict is actionable with low risk. The stddev of 3.6 on the baseline slot is elevated — review the var3 run decision.md to understand what drove the outlier before promoting.

---

## Reading a decision.md

Every run produces a `decision.md` at `benchmark/runs/<label>__<YYYYMMDD-HHMMSS>/decision.md`. This is the primary output of every run.

### Metadata table

The table at the top records run label, mode, champion, challenger, model, threshold, and timestamp. Verify these match what you intended before reading further — a wrong model or mode invalidates the comparison.

### Verdict section

The verdict keyword is bolded. It is one of six fixed values:

- Baseline mode: `PROMOTE`, `NO VALUE`, `REJECT`
- Revision and champion-vs-challenger mode: `SWITCH RECOMMENDED`, `NO CHANGE`, `CHAMPION CONFIRMED`

The paragraph below the keyword explains the delta, which skill led, and why the threshold was or was not met. Read this before looking at the numbers — it summarizes what matters.

### Score Summary table

```
| Skill      | Score  | Delta |
|------------|--------|-------|
| baseline   | 51/63  | -3    |
| my-skill   | 54/63  | +3    |
```

Delta is challenger minus champion. Positive means the challenger led. The `/63` denominator is the rubric maximum: 7 dimensions × 3 inputs × 3 points.

### Score Matrix

The full per-dimension, per-input breakdown. Columns are the three test inputs (T1, T2, T3) plus a total for each skill. Use this table to diagnose which dimensions drove the delta. A skill that leads on Instruction quality but trails on Conciseness tells a specific story about what to fix.

### Per-Dimension Analysis

One sentence per dimension. The decision agent explains which skill scored higher on that dimension and why. This is the fastest way to understand what the skill is doing well and what needs work.

### Next Steps

One to three concrete recommendations based on the verdict. These are the decision agent's interpretation of the data — treat them as a starting point for your own review.

This tooling is provided as-is with no support — if you encounter an undocumented failure, inspect run.log and the creation/scoring logs in the logs/ directory for diagnostics.

### Example output (abbreviated)

```
## Verdict

**PROMOTE**

The challenger (occ-skill-refactor) outscored the baseline by 10 points (55/63 vs
45/63), comfortably exceeding the 3-point threshold. The skill delivered consistent
gains across all three test inputs, with the largest improvements in Instruction
quality and Style adherence.

## Score Summary

| Skill               | Score  | Delta |
|---------------------|--------|-------|
| baseline (no skill) | 45/63  | -10   |
| occ-skill-refactor  | 55/63  | +10   |
```

Delta is challenger minus champion. Positive means the challenger led.

---

## Interpreting scores

### The rubric

Scores are 0–63. Seven dimensions, three test inputs (T1 simple, T2 moderate, T3 complex), maximum 3 points per dimension per input.

### What each dimension rewards

| Dimension | What earns points |
|-----------|------------------|
| Frontmatter quality | `name` field is set; `description` contains specific, non-generic trigger phrases |
| Trigger specificity | Triggers are multi-phrase, precise, low false-positive risk, under 1024 characters |
| Instruction quality | Clear steps, error handling, at least one concrete end-to-end example |
| Progressive disclosure | SKILL.md is under ~500 lines; large reference content is in `references/` files |
| Structure compliance | Forbidden files absent (README.md, CHANGELOG.md, examples/) |
| Conciseness | Every line is doing work; no filler, boilerplate, or repeated content |
| Style adherence | Output follows conventions defined in the loaded skill. Always 0 in baseline runs — no skill was loaded. This dimension creates a systematic gap between skill-guided and unguided runs. |

### What delta sizes mean in practice

| Delta | Reliability | Interpretation |
|-------|-------------|----------------|
| 0–2 points | Low — within single-run noise | Do not act on a single run. Run variance analysis. |
| 3–4 points | Moderate | Likely real but not definitive. Run variance before a promotion decision. |
| 5–6 points | Good | Consistent signal in most cases. Variance analysis optional. |
| 7+ points | Strong | Robust signal. Act on a single run with confidence. |

### Common drop patterns

| Drop | Typical cause | Fix |
|------|--------------|-----|
| Instruction quality T3 −1 | No concrete end-to-end example for complex inputs | Add a narrative block: "When X is said, Claude does Y, producing Z" |
| Trigger specificity T1 −1 | Phrases are too broad or lack a false-positive guard | Replace generic phrases; add a "do not trigger when" clause |
| Conciseness −1 | Duplicated trigger phrases; padded assumptions section | Deduplicate; trim prose to imperative sentences |
| Structure compliance −1 | README.md or CHANGELOG.md present in skill output | Remove auxiliary doc requests from skill instructions |

### The threshold flag

`--threshold` sets the minimum delta the decision agent uses to distinguish a meaningful result from noise. The default is 3. For promotion gates, use `--threshold 5`:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger your-skill \
  --creation-model haiku \
  --threshold 5
```

A higher threshold raises the bar for a positive verdict and reduces false positives at the cost of requiring a larger real improvement to register. The threshold does not change the scores — it only changes which verdict label is assigned to a given delta.

### Diagnosing unexpected low scores

If challenger scores are anomalously low — for example, near zero when you expected a competitive result — the creation agent likely asked a question instead of producing files. The benchmark prompt instructs the agent not to ask questions, but this can still occur.

**Check the creation logs:** `benchmark/runs/<label>/logs/<slot>-<input>.creation.log`. Look for question marks, "I need to know", or error messages at the end of the file.

**Check run.log for missing SKILL.md warnings:** The script checks for SKILL.md after Phase 2 and emits `WARN: No SKILL.md found — <slot> / <input>` lines. Scoring then runs against an empty directory and produces near-zero scores for those slots.

**What to do:** Re-run the benchmark. The failed run directory remains in `benchmark/runs/` for inspection. If creation failures repeat, check whether the brief content is being passed correctly and whether the model is hitting a context or rate limit.

---

## See Also

- [REFERENCE.md](REFERENCE.md) — complete flag documentation and output file reference
- [LIFECYCLE-GUIDE.md](LIFECYCLE-GUIDE.md) — when to run each workflow and how to act on verdicts
