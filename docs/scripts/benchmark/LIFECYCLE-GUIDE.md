# Benchmark Lifecycle Guide

Prerequisites: complete SETUP.md before using this guide. For command syntax and flags, see USER-GUIDE.md and REFERENCE.md.

When to run the benchmark, which mode to use, how to read the verdict, and how to fit this into a team workflow.

For command flags, output formats, and scoring details, see [USER-GUIDE.md](USER-GUIDE.md) and [REFERENCE.md](REFERENCE.md).

---

## Core Principle

**Promotion decisions are evidence gates, not gut-feel checks.**

A skill that feels well-written is a belief, not a signal. The benchmark converts that belief into a measured delta: skill-guided output vs. baseline or vs. the previous version. Promotion requires a verdict, not an impression.

Two questions the benchmark answers:

1. **New skill:** Does this skill produce measurably better outputs than the unguided model?
2. **Revised skill:** Does this revision produce measurably better outputs than what it replaces?

---

## The Skill Lifecycle

Every skill passes through three stages. The benchmark gates each transition.

```
DRAFT ──[baseline gate]──▶ ACTIVE ──[revision gate]──▶ UPDATED
```

| Stage | Gate | Required verdict |
|-------|------|-----------------|
| DRAFT → ACTIVE | Skill vs. no skill | `PROMOTE` |
| ACTIVE → UPDATED | Revision vs. current version | `SWITCH RECOMMENDED` |

A skill that does not clear its gate stays at the current stage. Revise and rerun.

---

## Stage 1: Draft → Active (Baseline Gate)

Run this before promoting any skill for the first time. It measures whether the skill produces better output than the model operating without any skill.

**Script:** `scripts/benchmark/run-benchmark.sh`
**Mode:** Baseline (no `--champion`; the baseline is the unguided model)
**Recommended model:** `--creation-model haiku`

Haiku has weaker priors than Sonnet and relies more on skill guidance. The gap between guided and unguided output is wider and the verdict more reliable. Use haiku for all baseline promotion gates.

**Quick signal (single run):**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger <your-skill> \
  --label <skill-name>-v1-baseline \
  --creation-model haiku \
  --threshold 5
```

**Before first promotion (multi-run recommended):**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger <your-skill> \
  --label <skill-name>-v1-baseline \
  --creation-model haiku \
  --runs 3
```

**Decision rule:**

| Result | Action |
|--------|--------|
| `PROMOTE`, delta ≥ 5 | Promote the skill |
| `PROMOTE`, delta 3–4 | Run variance analysis before deciding |
| `NO VALUE` | Do not promote; the skill is not adding measurable value |
| `REJECT` | Do not promote; the skill is actively degrading output quality |

The `--threshold 5` flag tells the decision agent to require a 5-point delta before issuing `PROMOTE`. This is the recommended setting for baseline promotion gates (the default of 3 is permissive for single runs). For revision gates, a single `SWITCH RECOMMENDED` at the default threshold is typically sufficient — revisions are reversible.

---

## Stage 2: Active → Updated (Revision Gate)

Run this after editing an existing skill. Choose the mode based on what is available.

**Script:** `scripts/benchmark/run-benchmark.sh`

### Mode selection

| Situation | Mode | Flags |
|-----------|------|-------|
| Skill is on a feature branch; main has the previous version | Git main comparison | `--challenger <skill> --compare-main` |
| You have both old and new SKILL.md files | Champion vs. Challenger | `--champion <old-skill> --challenger <new-skill>` |
| You want to confirm the revised skill still clears baseline | Baseline re-validation | `--challenger <skill> --creation-model haiku` |

**Git main comparison (most common):**

> **Prerequisites for `--compare-main`:**
> - The skill must already be committed to the `main` branch at the same path as `--challenger`
> - The branch must be named `main` — if your default branch uses a different name (master, trunk, develop), use `--champion` with an explicit path to the previous SKILL.md instead
> - Must be run from inside a git repository
> - If `--compare-main` fails with "not found on main branch", fall back to Workflow 3 in USER-GUIDE.md

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger <your-skill> \
  --compare-main \
  --label <skill-name>-revision-<date>
```

**Champion vs. Challenger:**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --champion <path/to/old-SKILL.md> \
  --challenger <path/to/new-SKILL.md> \
  --label <skill-name>-v2-vs-v1
```

**Decision rule:**

| Verdict | Meaning | Action |
|---------|---------|--------|
| `SWITCH RECOMMENDED` | Challenger scores meaningfully above current version | Merge the revision |
| `NO CHANGE` | Delta below threshold | Revision is not a measurable improvement; keep current version or revise further |
| `CHAMPION CONFIRMED` | Current version scores above the revision | The changes made things worse; discard or rework the revision |

---

## When to Use Variance Analysis

Single-run results carry noise. A 1–2 point delta in a single run may reverse in the next run. Use `run-variance.sh` when the signal needs confirmation.

**Use variance analysis when:**

- Single-run delta is in the 3–5 range
- Making a first-promotion decision (higher stakes, higher confidence required)
- A revision produced `NO CHANGE` and you want to confirm it is not a false negative

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger <your-skill> \
  --label <skill-name>-variance \
  --creation-model haiku \
  --runs 3
```

**Interpreting the recommendation:**

| Recommendation label | Meaning | Action |
|---------------------|---------|--------|
| Unanimous | All runs agree on the verdict | Act on the verdict |
| Majority | More than 50% of runs agree | Likely correct; review the minority run before acting |
| Split | No majority verdict | Do not act; investigate individual run decisions |

A split result means the delta is too small to trust. Either the skill needs more work or the rubric dimensions are near their natural variance floor for this skill type.

---

## Recommended Thresholds

These thresholds are calibrated for the 63-point rubric (7 dimensions × 3 inputs × 3 points each). Teams with higher-stakes skill libraries may tighten them.

| Decision point | Recommended value | Rationale |
|----------------|------------------|-----------|
| Minimum delta to act on a single run | ≥ 5 points | A delta of 1–2 is within single-run variance; 3–4 warrants multi-run confirmation; 5+ is a consistent signal |
| Minimum mean delta to act on a variance run | ≥ 5 points | Same floor; use the mean across runs rather than any individual result |
| Confidence for first promotion | Unanimous or majority (≥ 2/3 runs) | First promotion is a one-way gate; higher confidence reduces the cost of a bad promote |
| Confidence for revision gate | Single-run `SWITCH RECOMMENDED` is sufficient | Revisions are reversible; the previous version is on main and recoverable |
| `--threshold` flag for promotion gates | `5` | Overrides the default of `3`; the decision agent uses this value to determine PROMOTE vs. NO VALUE |

**Setting the threshold:**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger <skill> \
  --creation-model haiku \
  --threshold 5
```

The default `--threshold 3` is appropriate for quick development checks. Use `--threshold 5` when the result will be used as a formal promotion gate.

---

## Team Workflow

For teams maintaining a shared skill library, the benchmark integrates into the PR process as a required evidence step.

**5-step PR process:**

1. **Author** writes or revises a skill on a feature branch
2. **Author** runs the appropriate gate (baseline for new skills, revision gate for changes) and pastes the full verdict block from `decision.md` into the PR description
3. **Reviewer** checks: verdict keyword, delta value, threshold used, and — for variance runs — the recommendation label and individual run breakdown
4. **Merge policy:** `PROMOTE` or `SWITCH RECOMMENDED` required to merge a skill change; `NO VALUE`, `NO CHANGE`, or `CHAMPION CONFIRMED` blocks merge
5. **Audit trail:** Verdict and run label are recorded in `docs/benchmark-run-history.md` as the committed record of the decision

> **No support:** This tooling is provided as-is with no support. If a run produces unexpected results or fails mid-execution, inspect `benchmark/runs/<label>/run.log` and the files in `logs/` for diagnostics. The documentation in this bundle is the complete resource.

**What goes in the PR description:**

Paste the `## Verdict` and `## Score Summary` sections from `benchmark/runs/<label>/decision.md`. Include the run label so the history entry is traceable.

**What the reviewer checks:**

- Verdict keyword matches the required gate result
- Delta meets the threshold (≥ 5 for promotion gates)
- For variance runs: recommendation is Unanimous or Majority, not Split
- Run label is recorded in `docs/benchmark-run-history.md`

The run directory itself (`benchmark/runs/`) is gitignored and stays local. The history table is the only committed artifact.

---

## What the Benchmark Does Not Cover

| Gap | Implication |
|-----|-------------|
| Runtime trigger accuracy | A skill that scores well may still trigger on wrong inputs or fail to trigger when expected. Test trigger phrases separately. |
| Human preference | The rubric scores structural quality against defined criteria. It does not measure whether the output is well-suited to your specific domain or audience. |
| Model regressions | Scores are relative. A model update that degrades both skill-guided and baseline output equally is invisible to the benchmark. Run periodic baselines against a fixed reference if model stability matters. |
| Multi-step agentic quality | The benchmark evaluates single-pass output. Complex workflows that span multiple tool calls or session turns are not covered. |

**Next Steps:** To run your first benchmark, follow the workflows in USER-GUIDE.md. For complete flag and output documentation, see REFERENCE.md.
