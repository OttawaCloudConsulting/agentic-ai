# Skill Benchmark

Measures whether a Claude Code skill produces better output than a baseline or a previous version, and issues a promotion verdict based on a scored rubric.

---

## What It Does

- Runs a skill definition against three standardised test briefs (simple / medium / complex) using `claude -p`
- Scores outputs across seven dimensions using a rubric — max 63 points total
- Computes the delta between two slots (skill vs. baseline, or challenger vs. champion) and applies a threshold
- Produces `decision.md` with a single verdict keyword and supporting score breakdown
- `run-variance.sh` wraps `run-benchmark.sh` N times and aggregates results into a statistical confidence report

---

## Requirements

| Dependency | Required by | Verify |
|------------|-------------|--------|
| `bash` 4.0+ | both scripts | `bash --version` |
| `claude` CLI | `run-benchmark.sh` | `claude --version` |
| `git` | `run-benchmark.sh` | `git --version` |
| `awk` | `run-variance.sh` | `awk --version` |
| `shasum` | `run-benchmark.sh` | `shasum --version` |

macOS ships with bash 3.2. Install bash 4+ via Homebrew (`brew install bash`) and invoke with an explicit path until your shell resolves `bash` to 4+.

---

## Quick Start

Validate a new skill against the unguided model (baseline mode, haiku):

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger .claude/skills/<your-skill>/SKILL.md \
  --label <skill-name>-v1-baseline \
  --creation-model haiku \
  --threshold 5
```

For statistical confidence before a first promotion, run variance analysis:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger .claude/skills/<your-skill>/SKILL.md \
  --label <skill-name>-v1-baseline \
  --creation-model haiku \
  --runs 3
```

Output: `benchmark/runs/<label>__<timestamp>/decision.md` (relative to repository root) — contains the verdict keyword, delta, and full score breakdown.

---

## Modes at a Glance

| Mode | Flags | When to use |
|------|-------|-------------|
| Baseline | `--challenger` only | New skill — does it improve on the unguided model? |
| Git main comparison | `--challenger --compare-main` | Revised skill on a branch — compare against the last committed version |
| Champion vs. Challenger | `--challenger --champion` | Compare any two explicit skill files |

---

## Verdicts at a Glance

| Verdict | Action |
|---------|--------|
| `PROMOTE` | Promote the skill — challenger clears the threshold above baseline |
| `NO VALUE` | Do not promote — no measurable improvement over the unguided model |
| `REJECT` | Do not promote — the unguided model outperforms the skill |
| `SWITCH RECOMMENDED` | Merge the revision — challenger meaningfully beats the current version |
| `NO CHANGE` | Hold — delta below threshold, insufficient evidence to switch |
| `CHAMPION CONFIRMED` | Discard the revision — current version outperforms the challenger |

---

## Documentation

| Document | Description | Read when |
|----------|-------------|-----------|
| [SETUP.md](SETUP.md) | Dependencies, install steps, first-run checklist | Before the first run |
| [LIFECYCLE-GUIDE.md](LIFECYCLE-GUIDE.md) | When to run, which mode to use, promotion decision rules, team workflow | After setup — understand how to use verdicts |
| [USER-GUIDE.md](USER-GUIDE.md) | Concrete commands for each workflow, running inside Claude Code | Looking up a specific invocation |
| [REFERENCE.md](REFERENCE.md) | Complete flag, mode, output, and scoring reference | Looking up exact flag behaviour or output format |
| [RUBRIC-GUIDE.md](RUBRIC-GUIDE.md) | Rubric customisation and dimension definitions | Only if you need to adapt the scoring criteria |

---

Free distribution. No support provided. The documentation above is the complete resource.
