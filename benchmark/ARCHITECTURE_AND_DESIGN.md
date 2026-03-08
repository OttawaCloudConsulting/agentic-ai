# Architecture and Design: Skill Benchmark Tool — Champion vs Challenger

## Overview

`scripts/run-benchmark.sh` is a bash orchestrator that compares two Claude Code skill definitions by running them through standardised test briefs, scoring the outputs with a rubric, and producing a `decision.md` with a threshold-based verdict. The script drives all work through `claude -p` (headless Claude Code invocations) — it writes no skill logic itself; it only coordinates agents.

Three comparison modes are supported: explicit path comparison, current-branch vs git-main, and new-skill validation against a natural language baseline. All modes produce the same output structure. The script is designed to run unattended — all file I/O is handled by agents with `--permission-mode dontAsk`.

## Component Diagram

```
scripts/run-benchmark.sh
│
├── Phase 1: Setup
│   ├── resolve_skill() — bare name / dir / .md path → absolute SKILL.md path
│   ├── Mode b: git show main:<path> → benchmark/runs/<run>/champion/main-branch-SKILL.md
│   └── mkdir + exec > >(tee run.log) — all output captured from this point
│
├── Phase 2: Creation (6× claude -p, --system-prompt = SKILL.md content)
│   ├── champion × {T1, T2, T3} → benchmark/runs/<run>/champion/{T1,T2,T3}/SKILL.md
│   └── challenger × {T1, T2, T3} → benchmark/runs/<run>/challenger/{T1,T2,T3}/SKILL.md
│         Mode c (baseline): champion calls omit --system-prompt
│
├── Phase 3: Scoring (6× claude -p, --system-prompt = rubric evaluator)
│   ├── champion × {T1, T2, T3} → scores/champion/{T1,T2,T3}/scores.md
│   └── challenger × {T1, T2, T3} → scores/challenger/{T1,T2,T3}/scores.md
│
└── Phase 4: Decision (1× claude -p)
    ├── Reads all 6 scores.md → computes totals → applies threshold
    ├── Writes benchmark/runs/<run>/decision.md
    └── Appends 1 row to docs/benchmark-run-history.md

benchmark/
    ├── inputs/T1-simple.md, T2-medium.md, T3-complex.md  ← fixed test briefs
    ├── rubric.md                                          ← 6-dimension scoring rubric
    └── runs/                                             ← gitignored; accumulates runs

    benchmark/runs/<label>__<YYYYMMDD-HHMMSS>/
        ├── champion/{T1,T2,T3}/     ← clean skill output
        ├── challenger/{T1,T2,T3}/   ← clean skill output  (or baseline/)
        ├── scores/{champion,challenger}/{T1,T2,T3}/scores.md
        ├── logs/                    ← all benchmark artifacts isolated here
        │   ├── champion-T1.creation.log ... challenger-T3.creation.log
        │   ├── champion-T1.scoring.log  ... challenger-T3.scoring.log
        │   └── decision.log
        ├── manifest.md
        ├── run.log
        └── decision.md              ← primary output
```

## Data Flow

1. User invokes script with `--challenger`, optional `--champion` / `--compare-main`, `--label`, `--threshold`
2. Phase 1 resolves skill paths, extracts champion from git if mode b, builds `RUN_DIR`, writes manifest, redirects all output to `run.log`
3. Phase 2 reads each SKILL.md as the `--system-prompt` and sends each creation brief as the user message; agent writes skill files to the designated output directory
4. Phase 3 reads each Phase 2 output directory; scoring agent applies the rubric and writes `scores.md`
5. Phase 4 reads all six `scores.md` files, applies the threshold rule, writes `decision.md`, and appends one row to the history doc

## Component Inventory

| # | Component | Type | Purpose |
|---|-----------|------|---------|
| 1 | `scripts/run-benchmark.sh` | Bash orchestrator | Arg parsing, mode detection, directory setup, phase coordination |
| 2 | `resolve_skill()` | Bash function | Converts bare name / dir / .md path to absolute SKILL.md path |
| 3 | Phase 2 creation agent | `claude -p` | Reads a SKILL.md as system prompt, creates skill files from a brief |
| 4 | Phase 3 scoring agent | `claude -p` | Reads skill output + rubric, writes `scores.md` |
| 5 | Phase 4 decision agent | `claude -p` | Reads 6 `scores.md`, computes totals, writes `decision.md` and history row |
| 6 | `benchmark/inputs/` | Static files | T1-simple.md, T2-medium.md, T3-complex.md — fixed test briefs, unchanged across runs |
| 7 | `benchmark/rubric.md` | Static file | 7-dimension scoring rubric (0–3 per dimension, max 21 per skill per input, max 63 total) |
| 8 | `benchmark/runs/` | Directory | Gitignored; accumulates one subdirectory per run |
| 9 | `docs/benchmark-run-history.md` | History doc | Lightweight run history table; one row appended per run |

## File Organization

```
agentic-ai/
├── scripts/
│   └── run-benchmark.sh         # Orchestrator — only file changed by this project
├── benchmark/
│   ├── inputs/
│   │   ├── T1-simple.md         # Fixed — single-concern brief
│   │   ├── T2-medium.md         # Fixed — multi-step operational workflow
│   │   └── T3-complex.md        # Fixed — branching, variant-based
│   ├── rubric.md                # Updated — scorer note added
│   ├── runs/                    # Gitignored — run outputs accumulate here
│   ├── prd.md                   # This project's PRD
│   └── ARCHITECTURE_AND_DESIGN.md  # This file
├── docs/
│   └── benchmark-run-history.md    # Updated — reformatted as run history table
└── .gitignore                   # Updated — benchmark/runs/ added
```

## Configuration

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `--challenger` | skill reference | Skill under evaluation. Resolved as: `.md` path → `<dir>/SKILL.md` → `.claude/skills/<name>/SKILL.md` |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--champion` | skill reference | _(baseline mode)_ | Explicit champion. Mutually exclusive with `--compare-main` |
| `--compare-main` | flag | false | Extract champion from the same path on `git main` branch |
| `--label` | string | `comparison` | Prefixes the run directory name |
| `--threshold` | integer | `3` | Minimum point delta (out of 63) required to change verdict from status-quo |
| `--creation-model` | string | `sonnet` | Model for Phase 2 creation agents |
| `--scoring-model` | string | `sonnet` | Model for Phase 3 scoring agents and Phase 4 decision agent |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BENCHMARK_SKIP_PERMISSIONS` | unset | `1` switches all `claude -p` calls to `--dangerously-skip-permissions`; default is `--permission-mode dontAsk` |

## Outputs

| Output | Path | Description |
|--------|------|-------------|
| `decision.md` | `<RUN_DIR>/decision.md` | Primary output — verdict, scores, rationale, next steps |
| `run.log` | `<RUN_DIR>/run.log` | Full stdout/stderr for the entire run |
| `manifest.md` | `<RUN_DIR>/manifest.md` | Mode, skill names+paths, git hash, input SHA256s, threshold |
| `scores.md` ×6 | `<RUN_DIR>/scores/{champion,challenger}/{T1,T2,T3}/` | Per-skill per-input rubric scores |
| `*.creation.log` ×6 | `<RUN_DIR>/logs/` | Creation agent output per skill per input |
| `*.scoring.log` ×6 | `<RUN_DIR>/logs/` | Scoring agent output per skill per input |
| `decision.log` | `<RUN_DIR>/logs/` | Decision agent output |
| History row | `docs/benchmark-run-history.md` | One-line summary appended to run history table |

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | `--challenger` required; `--champion` optional | Optional champion enables baseline mode without a separate script. Challenger is always the subject under test. |
| 2 | Three modes in one script (not three separate scripts) | Single entry point reduces cognitive overhead; all modes share setup, phases, and output structure. |
| 3 | Skill resolution: `.md` → directory → bare name | Handles all practical invocation styles without requiring full paths. Bare name is the most common case when working within the repo. |
| 4 | Label-first directory naming: `<label>__<timestamp>` | Groups same-comparison runs together when sorted alphabetically. Timestamp ensures uniqueness within a label. |
| 5 | `benchmark/runs/` not `temp/benchmark/` | `temp/` is semantically throwaway. Benchmark runs are historical records intended to persist until manually cleaned. |
| 6 | Artifact isolation: all logs in `logs/`, skill output dirs are clean | Prevents benchmark runner artifacts from being scored as part of the skill (first run: `creation.log` caused false −1 on Structure Compliance for both skills). |
| 7 | `exec > >(tee run.log)` placed after `mkdir -p "$RUN_DIR"` | `exec` redirect requires the directory to exist. Placing it immediately after mkdir ensures preflight output is captured. |
| 8 | `--permission-mode dontAsk` as default; `BENCHMARK_SKIP_PERMISSIONS` env var for override | Avoids accidental use of `--dangerously-skip-permissions`. Opt-in via env var documents intent and keeps the normal path safe. |
| 9 | Default threshold: 3 points (out of 54) | Empirically validated: first run produced 52 vs 53 (1-point delta) with no qualitative difference. Threshold of 3 (~5.5%) filters noise while remaining sensitive to real improvements. |
| 10 | Phase 4 (decision) folds in Phase 4 (compilation) | Reduces total `claude -p` calls from 14 to 13. The decision agent reading raw score files is simpler than a compilation step feeding a separate decision step. |
| 11 | Six verdict keywords — three per mode | Unambiguous machine-readable outcomes. No "maybe" or "inconclusive". Baseline mode uses different keywords (PROMOTE/NO VALUE/REJECT) to distinguish from Champion vs Challenger (SWITCH RECOMMENDED/NO CHANGE/CHAMPION CONFIRMED). |
| 12 | Scorer system prompt explicitly says "ignore non-skill files" | Belt-and-suspenders for artifact isolation. Even if an artifact leaks into an output directory, the scorer is instructed to disregard it. |
| 13 | Champion slot named `baseline/` in baseline mode | Maintains consistent run directory structure regardless of mode. Decision agent and any future tooling always find champion output at a predictable path. |
| 14 | `git show main:<path>` for champion extraction | Non-destructive — does not modify the working tree, create branches, or require stashing. Safe to run mid-development. |
| 15 | `--champion` and `--compare-main` are mutually exclusive | Two ways of specifying the champion that would produce conflicting behaviour if combined. Explicit error message guides the user. |
| 16 | History doc receives one lightweight row (not full report) | `decision.md` is the primary output. The history doc is an index — a quick summary across runs. Duplicating the full report would make the file unwieldy. |
| 17 | `manifest.md` includes input SHA256s | Reproducibility. If a brief changes between runs, the SHA256 mismatch shows that scores are not directly comparable. |
| 18 | `--disable-slash-commands` on all creation calls | Prevents the skill under test from auto-triggering its own invocation during the benchmark run, which would corrupt the output. |
| 19 | One scoring agent per output directory (not one agent scoring all six) | Isolates scoring — the agent for champion/T1 cannot be influenced by seeing challenger output. Consistent with blind scoring principles. |

## Measurement Reliability Changes (Features 7–10)

### Context

End-to-end validation on 2026-03-08 confirmed the script infrastructure is correct but revealed two measurement failures: (1) the bad-skill fixture scored 54/54 because the model ignores bad system-prompt instructions; (2) rubric saturation caused all runs to converge at 51–54/54, making the benchmark unable to distinguish a good skill from no skill. Features 7–10 address both.

See `benchmark/PROBLEM-STATEMENT-01.md` and `benchmark/MVP-PROBLEM-STATEMENT-01.md` for full analysis.

### Updated Component Diagram

```
Phase 1: Setup
  └── parse --creation-model, --scoring-model (new)
      └── write to manifest: | Creation model | ... | Scoring model | ...

Phase 2: Creation (6× claude -p --model $CREATION_MODEL)
  └── unchanged structure; model now variable

Phase 3: Scoring (6× claude -p --model $SCORING_MODEL)
  └── style_context injection (new):
      ├── skill-guided slot → embed loaded skill content → scorer checks adherence
      └── baseline slot → explicit "score Style adherence as 0" instruction

Phase 4: Decision (1× claude -p --model $SCORING_MODEL)
  └── max scores updated: 18→21 per input, 54→63 total
      score matrix includes Style adherence row
```

### New Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 20 | Two separate model flags: `--creation-model` and `--scoring-model` | Creation and scoring are distinct roles with different quality requirements. A weaker creation model (Haiku) surfaces the skill's impact more clearly. A stronger scoring model (Opus) produces more discriminating scores. Separating the flags allows each to be tuned independently. |
| 21 | Both model flags default to `sonnet` | Zero behavioural change for existing invocations. Defaults are explicit in arg parsing, not buried in `claude -p` calls. |
| 22 | Model vars recorded in manifest | Runs using different models are not directly comparable on scores. Recording the model in the manifest makes this visible when reviewing history. |
| 23 | Style adherence dimension scores 0 for baseline by design, not by scorer inference | Explicitly instructing the scorer to score baseline = 0 is more reliable than asking it to infer that "no conventions were loaded". The instruction is injected directly into the scoring prompt. |
| 24 | Loaded skill content embedded in scoring prompt (not via `--add-dir`) | Consistent with Phase 2 pattern. Avoids adding `--add-dir` paths for skill files that may be outside `$BASE`. The scorer does not need write access to the skill directory. |
| 25 | Style context built per-slot from `SKILL_MD_PATHS[$slot]` | This variable is already populated correctly for all three modes (champion-vs-challenger, compare-main, baseline). Reusing it requires no new mode-detection logic. Empty string for baseline champion slot → zero-score instruction path. |
| 26 | Score max changes from 54 to 63; threshold unchanged at 3 | 3/63 (~4.8%) is proportionally similar to 3/54 (~5.6%). The threshold was empirically validated at 3 points; the relative meaning is preserved. |
| 27 | History header updated with scoring-change note; historical rows unchanged | Pre-Feature 8 runs scored on 6 dimensions (max 54). They are not directly comparable on the Style adherence dimension. The note makes this visible without deleting historical data. |
| 28 | bad-skill fixture uses structural anti-quality instructions, not verbosity instructions | Verbosity instructions are ignored by the model (validated on 2026-03-08). Structural instructions — no headers, single prose paragraph, forbidden files, no name field — target specific rubric criteria the scorer checks mechanically. |
| 29 | Rubric Agent Instructions generalised: no specific skill name hardcoded | The benchmark works for any skill. The scoring agent receives the relevant skill's content at runtime; hardcoding a skill name in the rubric would break this for all non-creator skills. |
| 30 | Brief hardening (Feature 10) is conditional, not automatic | Hardened briefs require maintaining reference answers and reduce domain neutrality. Apply only after confirming that Features 7, 8, and 9 are insufficient on both Sonnet and Haiku. |

## Out of Scope

| Item | Rationale |
|------|-----------|
| Multi-model comparison in a single run | Each run uses one creation model and one scoring model. Comparing the same skills across model configurations is done by running the benchmark multiple times with different `--creation-model` values. |
| Automated CI integration | Manual invocation sufficient; CI would require non-interactive auth setup outside this scope. |
| Scoring across more than 3 test inputs | T1/T2/T3 complexity spread (simple/medium/complex) provides adequate rubric coverage. |
| FedRAMP, ITSG, or other compliance skills | Separate skill domains; this tool is skill-creator specific in its test inputs and rubric. |
| HTML/PDF report generation | `decision.md` in markdown is sufficient for current workflow. |
