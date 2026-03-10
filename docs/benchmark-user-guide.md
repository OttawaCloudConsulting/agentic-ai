# Benchmark User Guide

Step-by-step guidance for running skill benchmarks. For a concise flags/verdicts/outputs reference, see [BENCHMARK.md](BENCHMARK.md).

---

## Contents

- [Running inside Claude Code](#running-inside-claude-code)
- [Choosing a mode](#choosing-a-mode)
- [Workflow: validating a new skill](#workflow-validating-a-new-skill)
- [Workflow: testing a revision](#workflow-testing-a-revision)
- [Workflow: comparing two skills directly](#workflow-comparing-two-skills-directly)
- [Workflow: multi-run variance analysis](#workflow-multi-run-variance-analysis)
- [Reading a decision.md](#reading-a-decisionmd)
- [Interpreting scores](#interpreting-scores)
- [Known limitations](#known-limitations)

---

## Running inside Claude Code

The `claude` CLI blocks nested invocations by default. If you run the script from within a Claude Code session you will see:

```
Error: Claude Code cannot be launched inside another Claude Code session.
Nested sessions share runtime resources and will crash all active sessions.
To bypass this check, unset the CLAUDECODE environment variable.
```

Prefix every benchmark invocation with `env -u CLAUDECODE` to unset that variable for the subprocess:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/run-benchmark.sh \
  --challenger occ-skill-creator --label my-run
```

`BENCHMARK_SKIP_PERMISSIONS=1` is also needed in interactive Claude Code sessions (it switches from `--permission-mode dontAsk` to `--dangerously-skip-permissions`). Both are harmless to include habitually.

If you are running from a terminal outside Claude Code (a CI job, a cron, a plain shell), neither prefix is needed.

---

## Choosing a mode

| You want to... | Use |
|---------------|-----|
| Check if a new skill is worth using at all | [Baseline mode](#workflow-validating-a-new-skill) |
| Check whether your recent edits improved the skill | [Git main mode](#workflow-testing-a-revision) |
| Compare two specific skill files directly | [Champion vs Challenger mode](#workflow-comparing-two-skills-directly) |

---

## Workflow: validating a new skill

Use this before promoting any skill for the first time. It compares your skill against the model with no skill loaded (natural language baseline).

**When to use:** You have written or imported a new skill and want to know whether it actually improves output quality over the model's default behaviour.

**Run:**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/run-benchmark.sh \
  --challenger your-skill-name \
  --label your-skill-v1-baseline \
  --creation-model haiku \
  --threshold 3
```

`--creation-model haiku` is recommended for baseline runs. Haiku has weaker priors and relies more on skill guidance, which widens the score gap and makes the verdict more reliable. Omit it for champion-vs-challenger and git-main runs where both slots use the same model anyway.

**Interpret the verdict:**

| Verdict | What it means | Action |
|---------|--------------|--------|
| `PROMOTE` | Skill scores ≥3 points above baseline | Proceed — the skill adds real value |
| `NO VALUE` | Delta below threshold | Investigate — the skill may be redundant, or the rubric/briefs may need harder inputs |
| `REJECT` | Baseline scores ≥3 points above the skill | The skill is actively making outputs worse — review and revise before promoting |

---

## Workflow: testing a revision

Use this after editing an existing skill. It automatically extracts the version on `main` as the champion and compares it against your working-tree version.

**When to use:** You have edited a skill on a feature branch and want to confirm the changes are improvements.

**Requirements:** The skill must already exist at the same path on the `main` branch. If it is new (not yet merged to `main`), use baseline mode or champion vs challenger mode instead.

**Run:**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/run-benchmark.sh \
  --challenger occ-skill-creator \
  --compare-main \
  --label occ-skill-creator-after-refactor
```

**Interpret the verdict:**

| Verdict | What it means | Action |
|---------|--------------|--------|
| `SWITCH RECOMMENDED` | Challenger scores ≥3 above main | Your revision is a meaningful improvement — safe to merge |
| `NO CHANGE` | Delta below threshold | The change is neutral — decide based on qualitative review |
| `CHAMPION CONFIRMED` | Main scores ≥3 above your revision | Your changes made things worse — review the diff |

---

## Workflow: comparing two skills directly

Use this to compare any two skill files regardless of git history.

**When to use:** Comparing two independent implementations, evaluating a third-party skill against your own, or re-running a comparison from a specific previous state.

**Run:**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/run-benchmark.sh \
  --champion .claude/skills/occ-skill-creator \
  --challenger path/to/candidate-skill \
  --label candidate-vs-current \
  --threshold 3
```

Skill references accept a bare name, a directory path, or a direct `.md` path:

```bash
--champion occ-skill-creator                        # bare name
--champion path/to/skill-dir/                       # directory
--champion path/to/skill-dir/SKILL.md               # direct path
```

**Interpret the verdict:** Same as git main mode — `SWITCH RECOMMENDED`, `NO CHANGE`, or `CHAMPION CONFIRMED`.

---

## Workflow: multi-run variance analysis

Use this when a single-run result falls in the uncertain range (delta 3–6) or when you want a statistically reliable signal before a promotion decision.

**When to use:** After any single-run benchmark where the delta is close to the threshold. Three runs take ~3× as long but reduce noise from model non-determinism to a reliable mean/stddev.

**Run:**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/run-variance.sh \
  --challenger occ-skill-creator \
  --label my-skill-variance \
  --creation-model haiku \
  --runs 3
```

All `run-benchmark.sh` flags work; add `--runs N` to set the run count (default 3, minimum 2).

**Output:** `benchmark/runs/variance__<label>__<timestamp>/variance-report.md`

**Interpreting the variance report:**

| Field | What to look at |
|-------|----------------|
| Verdict Distribution | How many runs agree — unanimous is most reliable |
| Recommendation | Confidence level based on unanimity |
| Mean delta | Positive = challenger leads. Magnitude matters more than any single run |
| Stddev (totals) | >3 means high variance — consider more runs or check individual decisions |
| Per-Dimension Analysis | Which dimensions are consistent vs noisy across runs |

**Confidence levels:**

| Recommendation label | Meaning |
|---------------------|---------|
| Unanimous | All N runs agree — act on the verdict |
| Majority | >50% agree — likely correct; review minority runs |
| Split | No majority — do not act; investigate individual runs |

Each individual run still appends its row to `docs/benchmark-run-history.md` via the core script.

---

## Reading a decision.md

Every run produces `benchmark/runs/<label>__<YYYYMMDD-HHMMSS>/decision.md`. This is the primary output. It contains:

```
# Benchmark Decision

| Field  | Value          |
|--------|----------------|
| Run    | <label>__<ts>  |
| Mode   | baseline       |
| ...    | ...            |

## Verdict

**PROMOTE**

<One paragraph: delta, which skill led, whether threshold was met, key reason.>

## Score Summary

| Skill     | Score  | Delta |
|-----------|--------|-------|
| baseline  | 51/63  | -3    |
| my-skill  | 54/63  | +3    |

## Score Matrix

| Dimension              | Champ T1 | Champ T2 | Champ T3 | Champ Total | Chall T1 | ... |
|------------------------|----------|----------|----------|-------------|----------|-----|
| Frontmatter quality    | 3        | 3        | 3        | 9           | ...      |     |
| ...                    |          |          |          |             |          |     |

## Per-Dimension Analysis

One sentence per dimension explaining which skill scored higher and why.

## Next Steps

1–3 concrete recommendations based on the verdict.
```

The verdict keyword is always bolded. It is one of six fixed values — see [BENCHMARK.md — Verdicts](BENCHMARK.md#verdicts).

---

## Interpreting scores

**Score range:** 0–63. Seven dimensions × three inputs × max 3 points each.

**What the dimensions reward:**

- **Frontmatter quality** — Is `name` set? Does `description` contain specific, non-generic trigger phrases?
- **Trigger specificity** — Are triggers multi-phrase, precise, low false-positive, and under 1024 characters?
- **Instruction quality** — Does the skill have clear steps, error handling, and at least one concrete example showing trigger → actions → result?
- **Progressive disclosure** — Is `SKILL.md` under ~500 lines, with large reference content split into `references/`?
- **Structure compliance** — Are forbidden files absent? (README.md, CHANGELOG.md, examples/)
- **Conciseness** — Is every line doing work? No filler, no boilerplate, no repeated information?
- **Style adherence** — Does the output follow the conventions defined in the loaded skill? Always 0 for baseline runs (no skill was loaded). This dimension creates a systematic gap between skill-guided and baseline runs.

**Common drop patterns and fixes:**

| Drop | Typical cause | Fix |
|------|--------------|-----|
| Instruction quality T3 −1 | Missing concrete end-to-end example in complex scenarios | Add a narrative block: "When X is said, Claude does Y, producing Z" |
| Trigger specificity T1 −1 | Phrases too broad or no false-positive guard | Replace generic phrases; add a "do not trigger when" clause |
| Conciseness −1 | Duplicated trigger phrases; padded assumptions section | Deduplicate; trim prose to imperative sentences |
| Structure compliance −1 | README.md or CHANGELOG.md present in skill output | Ensure skill instructions do not ask for auxiliary docs |

**On the threshold (default: 3):**

A delta of 1–2 points is within normal single-run variance — the same run repeated may produce a different 1-point outcome. A delta of 3+ (~4.8% of 63) represents a consistent, meaningful difference. If you need more confidence on a 1–2 point delta, run the benchmark multiple times with different labels and check whether the same skill leads consistently.

---

## Known limitations

### Single-run variance

Each run invokes 13 `claude -p` calls. Scores can vary by 1–2 points between runs of identical inputs due to model non-determinism. Do not act on a 1-point delta from a single run. Run the benchmark 3 times with different labels and look for a consistent leader and a stable delta before acting on the result.

### Baseline mode: use haiku for clearer results

With `sonnet` as the creation model, baseline and skill-guided runs may converge near the top of the rubric, producing a narrow delta. Using `--creation-model haiku` in baseline mode produces reliably wider deltas (observed: +7 to +11 across three runs) because haiku benefits more from skill guidance. Champion-vs-challenger and git-main runs are unaffected — both slots use the same model.

### Running inside Claude Code

As described above, the `CLAUDECODE` environment variable must be unset. See [Running inside Claude Code](#running-inside-claude-code).

### `benchmark/runs/` is local only

Run directories are gitignored and never committed. They accumulate on your local machine. The only persistent record is the one-row entry in `docs/benchmark-run-history.md`, which is committed.
