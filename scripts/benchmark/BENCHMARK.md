# Benchmark Reference

`scripts/benchmark/run-benchmark.sh` compares two Claude Code skill definitions head-to-head. It runs both through three standardised test briefs, scores the outputs against a rubric, and produces a `decision.md` with a threshold-based verdict.

For a walkthrough of common workflows, see [benchmark-user-guide.md](benchmark-user-guide.md).

---

## Quick Reference

```bash
# Validate a new skill before first use (baseline mode)
# --creation-model haiku widens the skill-vs-baseline gap for clearer results
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger occ-skill-creator --label my-skill-v1 --creation-model haiku

# Compare current work against the main branch version (git-main mode)
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger occ-skill-creator --compare-main --label after-refactor

# Compare two explicit skills (champion vs challenger mode)
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --champion occ-skill-creator --challenger path/to/new-skill --label head-to-head
```

> **Running inside Claude Code?** Prefix every invocation with `env -u CLAUDECODE` — see [User Guide](benchmark-user-guide.md#running-inside-claude-code).

---

## Modes

Three modes are determined by which flags are provided.

| Mode | Flags | Champion slot | Use when |
|------|-------|---------------|----------|
| Baseline | `--challenger` only | Model with no skill loaded | Validating a new skill for the first time |
| Git main comparison | `--challenger --compare-main` | Same skill path extracted from `main` branch | Testing a revision against the last stable version |
| Champion vs Challenger | `--challenger --champion` | Explicit skill file | Comparing any two skills directly |

`--champion` and `--compare-main` are mutually exclusive.

---

## Flags

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--challenger <skill>` | Yes | — | Skill under evaluation |
| `--champion <skill>` | No | _(baseline mode)_ | Explicit champion. Mutually exclusive with `--compare-main` |
| `--compare-main` | No | false | Extract champion from the same path on `git main` |
| `--label <string>` | No | `comparison` | Prefix for the run directory name |
| `--threshold <int>` | No | `3` | Minimum point delta (out of 63) required to act |
| `--creation-model <model>` | No | `sonnet` | Model used for Phase 2 skill creation. Use `haiku` in baseline mode to widen the skill-vs-baseline gap. |
| `--scoring-model <model>` | No | `sonnet` | Model used for Phase 3 scoring and Phase 4 decision. |

### Skill reference formats

All three forms work for both `--challenger` and `--champion`:

| Form | Example | Resolves to |
|------|---------|-------------|
| Bare name | `occ-skill-creator` | `.claude/skills/occ-skill-creator/SKILL.md` |
| Directory | `path/to/my-skill/` | `path/to/my-skill/SKILL.md` |
| Direct path | `path/to/SKILL.md` | `path/to/SKILL.md` |

### Environment variables

| Variable | Description |
|----------|-------------|
| `BENCHMARK_SKIP_PERMISSIONS=1` | Use `--dangerously-skip-permissions` instead of `--permission-mode dontAsk` on all `claude -p` calls |

---

## Verdicts

Six possible outcomes — three per mode. Exactly one appears bolded in `decision.md`.

### Baseline mode

| Verdict | Condition |
|---------|-----------|
| `PROMOTE` | Delta ≥ threshold and challenger leads — skill demonstrates clear improvement over the unguided model |
| `NO VALUE` | Delta < threshold — skill shows no measurable improvement over natural language |
| `REJECT` | Delta ≥ threshold and baseline leads — the unguided model outperforms the skill |

### Champion vs Challenger and Git main modes

| Verdict | Condition |
|---------|-----------|
| `SWITCH RECOMMENDED` | Delta ≥ threshold and challenger leads — challenger is meaningfully better |
| `NO CHANGE` | Delta < threshold — insufficient evidence to switch |
| `CHAMPION CONFIRMED` | Delta ≥ threshold and champion leads — champion is meaningfully better |

---

## Scoring

The rubric has 7 dimensions scored 0–3 each. Scores are applied per-input (T1, T2, T3), so the maximum per skill is 63 (7 × 3 inputs × max 3 points).

| Dimension | What is measured |
|-----------|-----------------|
| Frontmatter quality | `name`, `description`, and trigger phrases present and well-formed |
| Trigger specificity | Phrases specific, multi-phrase, low false-positive risk, <1024 chars |
| Instruction quality | Steps + error handling + at least one concrete example |
| Progressive disclosure | SKILL.md lean (<500 lines), detail offloaded to `references/` |
| Structure compliance | No forbidden auxiliary files (README, CHANGELOG, examples/) |
| Conciseness | No filler or boilerplate — every line justified |
| Style adherence | Output follows the conventions of the loaded skill. Always 0 for baseline runs (no skill loaded). |

Rubric definition: [`benchmark/rubric.md`](../benchmark/rubric.md)

Test inputs: [`benchmark/inputs/`](../benchmark/inputs/) — T1 (simple), T2 (medium), T3 (complex)

---

## Outputs

Every run produces a directory at `benchmark/runs/<label>__<YYYYMMDD-HHMMSS>/`.

| File | Description |
|------|-------------|
| `decision.md` | Primary output — verdict, score summary, score matrix, per-dimension analysis, next steps |
| `manifest.md` | Run metadata — mode, skill names and paths, git hash, input SHA256s, threshold, creation model, scoring model |
| `run.log` | Full stdout/stderr for the entire run |
| `champion/` or `baseline/` | Skill files generated by the champion/baseline agent, one subdir per input |
| `challenger/` | Skill files generated by the challenger agent, one subdir per input |
| `scores/{champion,challenger}/{T1,T2,T3}/scores.md` | Per-skill per-input rubric scores (6 files) |
| `logs/` | All benchmark artifacts — 6 creation logs, 6 scoring logs, 1 decision log |

`benchmark/runs/` is gitignored. Run directories accumulate locally and are never committed.

The decision agent also appends one row to [`docs/benchmark-run-history.md`](benchmark-run-history.md) at the end of every run.

---

## Multi-Run Variance Analysis

`scripts/benchmark/run-variance.sh` wraps `run-benchmark.sh` and runs it N times, then aggregates the results into a statistical summary.

```bash
# Run 3 times and report mean/stddev (baseline mode, haiku)
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger occ-skill-creator \
  --label my-skill-baseline \
  --creation-model haiku \
  --runs 3
```

**When to use:** Deltas of 1–5 points from a single run may flip on re-run. Use this script when you want a statistically reliable verdict rather than a single-point estimate.

**Output:** `benchmark/runs/variance__<label>__<timestamp>/variance-report.md` — verdict distribution, score summary with mean/stddev/min/max per slot, per-dimension mean/stddev table, and individual run results.

All flags except `--runs` are forwarded to `run-benchmark.sh` unchanged. `--runs` defaults to 3; minimum is 2.

---

## Supporting Files

| File | Purpose |
|------|---------|
| `scripts/benchmark/run-variance.sh` | Multi-run wrapper — runs N benchmarks and writes a variance-report.md |
| `benchmark/prd.md` | Product requirements — goals, features, acceptance criteria |
| `benchmark/ARCHITECTURE_AND_DESIGN.md` | Technical design — component diagram, data flow, design decisions |
| `benchmark/rubric.md` | Scoring rubric used by the Phase 3 scoring agent |
| `benchmark/inputs/T1-simple.md` | Test brief — conventional commit messages (single-concern) |
| `benchmark/inputs/T2-medium.md` | Test brief — database migrations (multi-step workflow) |
| `benchmark/inputs/T3-complex.md` | Test brief — cloud deployment across AWS/GCP/Azure (branching, variant-based) |
| `docs/benchmark-run-history.md` | Cumulative run history table |
| `docs/benchmark-test-run-report.md` | Validation reports — Session 1 (2026-03-08) and Session 2 (2026-03-08) |
