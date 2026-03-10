# Benchmarking Strategy: Skill Quality Gates

This document defines where benchmarking fits in the skill development lifecycle — when to run it, which mode to use, and how verdicts gate promotion decisions. It is the entry point for teams adopting the benchmark tooling.

For technical reference, see [BENCHMARK.md](BENCHMARK.md). For a walkthrough of specific workflows, see [benchmark-user-guide.md](benchmark-user-guide.md).

---

## The Core Principle

**Promotion decisions are gating decisions. They need evidence, not intuition.**

A skill you wrote feels good. That's not a signal. Run the benchmark, collect the verdict, act on data.

The benchmark answers two questions:

1. **New skill:** Does this skill produce measurably better outputs than the unguided model?
2. **Revised skill:** Does this revision produce measurably better outputs than what it replaces?

---

## The Skill Lifecycle

Every skill passes through three stages. Benchmarking gates the transitions.

```
DRAFT → [baseline gate] → ACTIVE → [revision gate] → UPDATED
```

### Stage 1: Draft → Active (baseline gate)

Run before promoting a skill for the first time.

**Mode:** Baseline — skill vs. no skill
**Script:** `run-benchmark.sh` or `run-variance.sh`
**Required verdict:** `PROMOTE`

```bash
# Single run (quick signal)
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger <your-skill> --label <skill-name>-v1 --creation-model haiku

# Multi-run (before first promotion — recommended)
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger <your-skill> --label <skill-name>-v1 --creation-model haiku --runs 3
```

Use `--creation-model haiku`. Haiku has weaker priors than Sonnet and needs skill guidance more — the gap between guided and unguided outputs is wider and more reliable.

**Decision rule:**
- `PROMOTE` with delta ≥ 5 → ship the skill
- `PROMOTE` with delta 3–4 → run variance analysis before deciding
- `NO VALUE` or `REJECT` → do not promote; revise the skill

### Stage 2: Active → Updated (revision gate)

Run after editing an existing skill. Choose the mode based on what you have available.

| Situation | Mode | Flags |
|-----------|------|-------|
| Skill is on a feature branch; main has the previous version | Git main comparison | `--challenger <skill> --compare-main` |
| You have both the old and new SKILL.md files | Champion vs Challenger | `--champion <old> --challenger <new>` |
| You want to confirm the revised skill still beats baseline | Baseline | `--challenger <skill>` (no champion) |

**Decision rule:**
- `SWITCH RECOMMENDED` → merge the revision
- `NO CHANGE` → revision is not meaningfully better; keep the current version
- `CHAMPION CONFIRMED` → revision is worse; discard it

---

## When to Use Variance Analysis

Single-run results are unreliable when the delta is small. Use `run-variance.sh` when:

- Delta from a single run is in the 3–5 range
- You are making a first-promotion decision (higher stakes)
- You want a confidence level, not just a direction

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger <skill> --label <label> --creation-model haiku --runs 3
```

**Interpreting the recommendation:**

| Label | Meaning | Action |
|-------|---------|--------|
| Unanimous | All runs agree | Act on the verdict |
| Majority | >50% agree | Likely correct; review outlier run before acting |
| Split | No majority | Do not act; investigate individual run decisions |

---

## Recommended Thresholds

These are defaults calibrated to the 63-point rubric. Teams may tighten them for higher-stakes skills.

| Decision point | Recommended threshold |
|----------------|----------------------|
| Minimum delta to act (single run) | ≥ 5 points |
| Minimum delta to act (variance mean) | ≥ 5 points mean |
| Confidence required for first promotion | Unanimous or majority (≥ 2/3 runs) |
| Confidence required for revision | Single-run SWITCH RECOMMENDED is sufficient |
| `--threshold` flag value | `5` (override the default of 3) |

The `--threshold` flag sets the minimum delta the decision agent uses to determine PROMOTE vs NO VALUE. Set it to 5 for promotion gates:

```bash
bash scripts/benchmark/run-benchmark.sh --challenger <skill> --threshold 5 --creation-model haiku
```

---

## Installation

The benchmark is a full bundle — copy it into any repository where skills live.

**Files to copy:**

```
scripts/benchmark/run-benchmark.sh       ← core benchmark script
scripts/benchmark/run-variance.sh        ← multi-run variance wrapper
benchmark/rubric.md            ← scoring rubric
benchmark/inputs/              ← T1, T2, T3 test briefs
```

**Add to `.gitignore`:**

```
benchmark/runs/
```

Run directories accumulate locally. They are not committed. The run history table (`docs/benchmark-run-history.md`) is the committed record.

**Verify the install:**

```bash
bash scripts/benchmark/run-benchmark.sh --help
```

---

## Team Workflow

For teams with a shared skill library:

1. **Author** writes or revises a skill on a feature branch
2. **Author** runs the baseline gate (or revision gate) and pastes the verdict into the PR description
3. **Reviewer** checks the verdict: delta, confidence, individual run results for variance runs
4. **Merge policy:** `PROMOTE` or `SWITCH RECOMMENDED` required to merge a skill change; `NO VALUE`, `NO CHANGE`, or `CHAMPION CONFIRMED` blocks merge
5. Verdict and run label are recorded — `docs/benchmark-run-history.md` is the audit trail

---

## What the Benchmark Does Not Cover

| Gap | Implication |
|-----|-------------|
| Runtime trigger accuracy | A skill that scores well may still trigger on wrong inputs or fail to trigger when invoked. Test trigger phrases separately. |
| Human preference | Rubric scores structural quality, not whether the output is pleasant or appropriate for your specific domain. |
| Model regressions | Rubric scores are relative (skill vs. baseline). A model update that degrades both equally is invisible. Run periodic baselines against a fixed reference if this matters. |
| Multi-step agentic quality | The benchmark evaluates single-pass skill output. Complex agentic workflows that span multiple steps are not covered. |
