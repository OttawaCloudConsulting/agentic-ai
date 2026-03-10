# Skill Benchmark

Measures whether a Claude Code skill produces better output than a baseline or a previous version. Runs both through three standardised test briefs, scores outputs across seven dimensions, and produces a `decision.md` with a threshold-based verdict.

---

## Quick Start

```bash
# Validate a new skill against the unguided model (baseline mode)
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger your-skill-name \
  --label your-skill-v1-baseline \
  --creation-model haiku \
  --threshold 5

# Test a revision against the main branch version
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger your-skill-name \
  --compare-main \
  --label your-skill-after-revision

# Compare two explicit skill files
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --champion path/to/old-SKILL.md \
  --challenger path/to/new-SKILL.md \
  --label head-to-head

# Multi-run variance analysis (statistical confidence)
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger your-skill-name \
  --label your-skill-variance \
  --creation-model haiku \
  --runs 3
```

Output lands at `benchmark/runs/<label>__<timestamp>/decision.md` (relative to repository root).

---

## Documentation

| Document | Read when |
|----------|-----------|
| [docs/SETUP.md](docs/SETUP.md) | Before the first run — dependencies, install steps, first-run checklist |
| [docs/LIFECYCLE-GUIDE.md](docs/LIFECYCLE-GUIDE.md) | After setup — when to run, which mode, how to act on verdicts, team workflow |
| [docs/USER-GUIDE.md](docs/USER-GUIDE.md) | Looking up a specific workflow or invocation |
| [docs/REFERENCE.md](docs/REFERENCE.md) | Complete flag, mode, output, and scoring reference |
| [docs/RUBRIC-GUIDE.md](docs/RUBRIC-GUIDE.md) | Only if you need to adapt the scoring criteria |

Read in order for first-time setup. Use REFERENCE.md and RUBRIC-GUIDE.md as lookup references only.
