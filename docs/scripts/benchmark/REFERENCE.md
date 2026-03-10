# Benchmark Tool Reference

Comprehensive technical reference for `scripts/benchmark/run-benchmark.sh` and `scripts/benchmark/run-variance.sh`.

---

## run-benchmark.sh

Compares two skill definitions head-to-head. Drives skill creation and scoring via `claude -p`, then produces a `decision.md` with a threshold-based verdict.

```
bash scripts/benchmark/run-benchmark.sh --challenger <skill> [options]
```

### Flag Reference

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--challenger <skill>` | Yes | — | Skill under evaluation. |
| `--champion <skill>` | No | _(baseline mode)_ | Explicit champion skill. Mutually exclusive with `--compare-main`. |
| `--compare-main` | No | false | Extract champion from the same file path on the `main` branch. Mutually exclusive with `--champion`. |
| `--label <string>` | No | `comparison` | Prefix for the run directory name. Appears in output paths as `benchmark/runs/<label>__<timestamp>/`. |
| `--threshold <int>` | No | `3` | Minimum point delta (out of 63) required for a verdict to act. Deltas below this produce `NO CHANGE` or `NO VALUE`. |
| `--creation-model <model>` | No | `sonnet` | Model used in Phase 2 to generate skill files for both slots. Use `haiku` in baseline mode to widen the skill-vs-baseline gap. |
| `--scoring-model <model>` | No | `sonnet` | Model used in Phase 3 scoring and Phase 4 decision. |

### Skill Reference Formats

All three forms are accepted by both `--challenger` and `--champion`. Resolution is performed by `resolve_skill()` relative to the repository root.

| Form | Example | Resolves to |
|------|---------|-------------|
| Bare name | `occ-skill-creator` | `$REPO_ROOT/.claude/skills/occ-skill-creator/SKILL.md` |
| Directory | `path/to/my-skill/` | `path/to/my-skill/SKILL.md` (resolved to absolute path) |
| Direct `.md` path | `path/to/SKILL.md` | Used as-is if absolute; otherwise `$REPO_ROOT/path/to/SKILL.md` |

The script exits with an error if the resolved `SKILL.md` does not exist on disk.

### Environment Variables

| Variable | Effect |
|----------|--------|
| `BENCHMARK_SKIP_PERMISSIONS=1` | Passes `--dangerously-skip-permissions` to all `claude -p` calls instead of `--permission-mode dontAsk`. Required when running inside Claude Code. |
| `CLAUDECODE` (unset) | Unset with `env -u CLAUDECODE` when running inside a Claude Code session to allow the claude CLI to launch nested invocations. Not a value to set — a variable to unset. |

### Modes

Mode is determined solely by which flags are provided. The flags are mutually exclusive where noted.

| Mode | Flags | Champion slot | Typical use |
|------|-------|---------------|-------------|
| **Baseline** | `--challenger` only | Model with no system prompt (no skill loaded) | Validating a new skill — does it improve on the unguided model? |
| **Git main comparison** | `--challenger --compare-main` | Same file path extracted from `git main` via `git show main:<path>` | Testing a revision against the last committed version |
| **Champion vs Challenger** | `--challenger --champion` | Explicit skill file | Comparing any two skills directly |

In baseline mode the champion slot directory is named `baseline/` instead of `champion/`.

In git-main mode, the champion SKILL.md is written to `benchmark/runs/<run-dir>/champion/main-branch-SKILL.md` before Phase 2 begins. The script exits with an error if the challenger's path does not exist on `main`.

#### --compare-main failure modes

| Condition | Behaviour |
|-----------|-----------|
| Challenger path does not exist on `main` branch | Script exits with an error message suggesting `--champion` with an explicit path or omitting `--compare-main` for baseline mode. |
| Default branch is not named `main` (e.g. `master`, `trunk`) | The `git show main:<path>` command will fail. Rename the branch reference locally or use `--champion` with an explicit path instead. |
| Working directory is not a git repository | All `git` commands will fail. The script must be run from inside a git repository. |
| Skill has not been committed to `main` | `git show` will find no file. Commit the skill to `main` before using this mode. |

### Execution Phases

| Phase | Description | `claude -p` calls |
|-------|-------------|-------------------|
| **Phase 1 — Setup** | Creates run directory tree, writes `manifest.md` with run metadata and input SHA256s. | 0 |
| **Phase 2 — Skill creation** | Generates skill files for both slots against all three inputs (T1, T2, T3). Baseline champion slot runs with no system prompt; all other slots inject the slot's SKILL.md as the system prompt. After this phase, the script checks that each output directory contains a `SKILL.md` and warns (but does not abort) for any that are missing. When a creation agent produces no SKILL.md — for example because it asked a question or encountered an error — Phase 3 scores an empty directory. This produces zero scores for that slot/input combination with no explicit failure message. To diagnose, inspect the creation log at `logs/<slot>-<input>.creation.log` for questions or errors from the creation agent. | 6 |
| **Phase 3 — Scoring** | Scores each generated skill against the rubric. Baseline champion slot receives an explicit instruction to score Style adherence as 0; other slots receive the loaded skill's content for style comparison. | 6 |
| **Phase 4 — Decision** | Reads all 6 score files, computes totals and delta, applies the verdict table, writes `decision.md`, and appends a row to `docs/benchmark-run-history.md`. | 1 |

### Verdicts

Exactly one verdict keyword appears bolded in `decision.md`. Six keywords exist — three per mode group.

#### Baseline mode

| Verdict | Condition |
|---------|-----------|
| `PROMOTE` | Delta ≥ threshold and challenger total > champion total — skill demonstrates clear improvement over the unguided model. |
| `NO VALUE` | Delta < threshold — skill shows no measurable improvement over natural language alone. |
| `REJECT` | Delta ≥ threshold and champion total > challenger total — the unguided model outperforms the skill. |

#### Champion vs Challenger and Git main modes

| Verdict | Condition |
|---------|-----------|
| `SWITCH RECOMMENDED` | Delta ≥ threshold and challenger total > champion total — challenger is meaningfully better. |
| `NO CHANGE` | Delta < threshold — insufficient evidence to switch. |
| `CHAMPION CONFIRMED` | Delta ≥ threshold and champion total > challenger total — champion is meaningfully better. |

Delta is always the absolute difference: `|champion_total - challenger_total|`. If totals are equal, delta is 0 and the threshold is not met.

### Outputs

Every run produces a directory at `benchmark/runs/<label>__<YYYYMMDD-HHMMSS>/`.

| Path | Description |
|------|-------------|
| `decision.md` | Primary output. Contains verdict keyword, one-paragraph rationale, score summary table, full 7-dimension score matrix (champion and challenger across T1/T2/T3), per-dimension analysis, and next steps. |
| `manifest.md` | Run metadata: label, timestamp, git hash, mode, champion/challenger names and paths, threshold, creation model, scoring model, input SHA256s, and a per-phase exit code log. |
| `run.log` | Full stdout and stderr for the entire run (all phases). |
| `champion/T1/`, `champion/T2/`, `champion/T3/` | Skill files generated for the champion slot per input. In baseline mode these directories are named `baseline/T1/` etc. |
| `challenger/T1/`, `challenger/T2/`, `challenger/T3/` | Skill files generated for the challenger slot per input. |
| `scores/<champion\|baseline>/{T1,T2,T3}/scores.md` | Per-slot per-input rubric scores (6 files). Each file contains a 7-dimension table with integer scores 0–3 and a TOTAL row out of 21. The slot directory is named `baseline/` in baseline mode and `champion/` in all other modes. |
| `logs/<slot>-<input>.creation.log` | Raw `claude -p` output for each Phase 2 creation call (6 files). |
| `logs/<slot>-<input>.scoring.log` | Raw `claude -p` output for each Phase 3 scoring call (6 files). |
| `logs/decision.log` | Raw `claude -p` output for the Phase 4 decision call. |

`benchmark/runs/` is gitignored. Run directories accumulate locally and are never committed.

The decision agent also appends one row to `docs/benchmark-run-history.md` at the end of every run. If no run history table exists in that file, it creates one.

---

## run-variance.sh

Wraps `run-benchmark.sh` and executes it N times, then aggregates the results into a statistical summary.

```
bash scripts/benchmark/run-variance.sh --challenger <skill> [--runs N] [options]
```

**When to use:** A single-run delta of 1–5 points can flip on re-run due to model non-determinism. Use this script when you want a statistically reliable verdict before acting on a result.

### Flag Reference

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--challenger <skill>` | Yes | — | Skill under evaluation. Passed through to `run-benchmark.sh`. |
| `--runs <N>` | No | `3` | Number of times to run `run-benchmark.sh`. Minimum: 2. Consumed by this script; not forwarded. |
| `--champion <skill>` | No | — | Passed through unchanged. |
| `--compare-main` | No | — | Passed through unchanged. |
| `--label <string>` | No | `comparison` | Used as the label prefix for each sub-run (`<label>__var1`, `<label>__var2`, …) and for the variance output directory. Passed through to each `run-benchmark.sh` invocation with the `var<N>` suffix appended. |
| `--threshold <int>` | No | `3` | Passed through unchanged. |
| `--creation-model <model>` | No | `sonnet` | Passed through unchanged. |
| `--scoring-model <model>` | No | `sonnet` | Passed through unchanged. |

All flags except `--runs` and `--label` are forwarded to `run-benchmark.sh` unchanged. `--label` is consumed by `run-variance.sh` and forwarded as `<label>__var<N>` for each sub-run. Unknown flags are also forwarded.

### Environment Variables

| Variable | Effect |
|----------|--------|
| `BENCHMARK_SKIP_PERMISSIONS=1` | Forwarded to each `run-benchmark.sh` call. |

### Outputs

The script creates a parent directory at `benchmark/runs/variance__<label>__<timestamp>/` and writes:

| Path | Description |
|------|-------------|
| `variance-report.md` | Aggregated statistical report (see contents below). |
| `run-1.log`, `run-2.log`, … | Full stdout/stderr from each `run-benchmark.sh` invocation. |

Each sub-run also creates its own directory under `benchmark/runs/<label>__var<N>__<timestamp>/` with the full single-run output structure.

#### variance-report.md Contents

| Section | Contents |
|---------|----------|
| Header table | Run count, champion/baseline name, challenger name, timestamp. |
| Verdict Distribution | Count of each verdict keyword across all N runs. |
| Recommendation | One line with confidence level (see below). |
| Score Summary (Mean ± Stddev) | Per-slot: mean, stddev, min, max across all N runs. Mean delta (challenger minus champion, with sign). |
| Per-Dimension Analysis | Per-slot table of mean and stddev for each of the 7 dimensions across all N runs. For each run, per-dimension scores are summed across T1+T2+T3 first; those per-run totals are then averaged across all N runs to produce the mean and stddev. |
| Individual Run Results | Table of champion total, challenger total, delta, and verdict for each run. |
| Run Directories | Absolute paths to each sub-run directory. |

### Confidence Levels

The recommendation line in `variance-report.md` applies one of three confidence labels:

| Label | Condition |
|-------|-----------|
| `— unanimous across N runs (high confidence)` | All N runs produced the same verdict. |
| `— majority M/N runs (moderate confidence)` | More than half but not all runs produced the same verdict (M > N/2). |
| `Split result — low confidence; review individual run decisions before acting` | No single verdict holds a majority. |

---

## Scoring

This is the authoritative scoring reference. USER-GUIDE.md and RUBRIC-GUIDE.md contain summaries — if descriptions differ, this document takes precedence.

### Dimensions

Seven dimensions, each scored 0–3 per input. Max score per input: 21. Max total per skill (across T1+T2+T3): 63.

| Dimension | 0 | 1 | 2 | 3 |
|-----------|---|---|---|---|
| **Frontmatter quality** | Missing `name` or `description` | Incomplete triggers in description | Triggers present, could be more specific | Complete: `name`, `description` with specific trigger phrases |
| **Trigger specificity** | No triggers | Vague/generic phrases only | Specific but narrow coverage | Multi-phrase, covers edge cases, no false positives, <1024 chars |
| **Instruction quality** | No actionable steps | Steps present but no error handling | Steps + error handling | Steps + error handling + at least one concrete example |
| **Progressive disclosure** | SKILL.md >500 lines or no reference splits | Oversized, references missing | Appropriate size with some references | SKILL.md lean (<500 lines), references loaded on demand |
| **Structure compliance** | Forbidden files present (README, CHANGELOG, etc.) | Incorrect directory structure | Correct structure | Correct structure, no auxiliary docs, only what the agent needs |
| **Conciseness** | Heavy filler / boilerplate | Noticeable padding | Mostly lean | Every line justified — no wasted tokens |
| **Style adherence** | _(see below)_ | _(see below)_ | _(see below)_ | _(see below)_ |

### Style Adherence

Style adherence is scored differently depending on the slot.

**Baseline slot:** Always scored 0. No skill was loaded, so there are no conventions to follow. The scoring prompt instructs the model explicitly — it does not infer this from the output.

**Skill-guided slots (champion and challenger in non-baseline modes):** The loaded skill's full content is provided to the scoring agent. The agent scores how consistently the generated output follows that skill's conventions.

| Score | Condition |
|-------|-----------|
| 0 | No skill loaded (baseline), OR skill loaded but output ignores all its conventions |
| 1 | Output follows some conventions from the loaded skill (e.g. has frontmatter but structure diverges) |
| 2 | Output follows most conventions — correct frontmatter format, appropriate section structure, similar prose style |
| 3 | Output fully consistent with loaded skill — frontmatter matches exactly, trigger phrase style matches, structure and prose style match throughout |

### Score Files

Each scoring agent writes to `benchmark/runs/<run>/scores/<slot>/<input>/scores.md`:

```markdown
# Scores: <skill-id> / <input-id>

| Dimension              | Score (0-3) | Notes |
|------------------------|-------------|-------|
| Frontmatter quality    |             |       |
| Trigger specificity    |             |       |
| Instruction quality    |             |       |
| Progressive disclosure |             |       |
| Structure compliance   |             |       |
| Conciseness            |             |       |
| Style adherence        |             |       |
| **TOTAL**              | **/21**     |       |
```

The decision agent (Phase 4) and the variance aggregator both parse these files to extract dimension scores and totals.

### Scoring Scope

The scoring agent scores only files that are part of the skill bundle: `SKILL.md`, `references/`, `scripts/`. Any other files present in the output directory are ignored.

> **Dimension ordering is a structural invariant.** `run-variance.sh` parses `scores.md` files by position — the Nth score line maps to the Nth dimension in the `DIMS` array. If you add, remove, or reorder dimensions, you must update the `DIMS` array in `run-variance.sh` at the same position. An order mismatch silently corrupts per-dimension statistics. See [RUBRIC-GUIDE.md](RUBRIC-GUIDE.md#structural-changes) for the full coordination checklist.

---

## Supporting Files

| File | Purpose |
|------|---------|
| `benchmark/rubric.md` | Authoritative scoring rubric passed to each Phase 3 scoring agent. |
| `benchmark/inputs/T1-simple.md` | Test brief — simple, single-concern skill domain. |
| `benchmark/inputs/T2-medium.md` | Test brief — medium complexity, multi-step workflow. |
| `benchmark/inputs/T3-complex.md` | Test brief — complex, branching, variant-based domain. |
| `docs/benchmark-run-history.md` | Cumulative run history table, appended by each Phase 4 decision agent. |

---

## See Also

- **USER-GUIDE.md** — workflow commands, invocation examples, and running inside Claude Code.
- **LIFECYCLE-GUIDE.md** — promotion decision guidance: when to promote, hold, or reject based on benchmark results.
