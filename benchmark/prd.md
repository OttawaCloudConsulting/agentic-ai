# PRD: Skill Benchmark Tool — Champion vs Challenger

## Summary

A general-purpose bash script (`scripts/run-benchmark.sh`) for comparing two Claude Code skill definitions head-to-head. Accepts any two SKILL.md files and runs them through three standardised test briefs, scores the outputs, and produces a `decision.md` with an actionable Champion vs Challenger verdict. Designed to run fully unattended and to accumulate a searchable history of comparison runs.

## Goals

- Any two skills can be compared without modifying the script
- Three selection modes cover all practical workflows: explicit, git-branch-diff, and new-skill validation
- Every run produces a standalone, human-readable decision with a defined verdict
- Runs accumulate in a labelled directory structure without manual housekeeping
- Fully unattended execution — no prompts, no interactive steps

## Non-Goals

| Item | Rationale |
|------|-----------|
| Automated test coverage measurement | Skills are prompt-driven; behaviour can't be unit-tested |
| Multi-model comparison in a single run | Comparing models is a separate concern; one creation model per run keeps outputs consistent |
| Continuous integration integration | Manual invocation is sufficient at current frequency |
| Scoring across more than 3 test inputs | T1/T2/T3 complexity spread is sufficient for rubric coverage |

## Architecture

```
scripts/run-benchmark.sh
    ├── Phase 1: Arg parsing + setup
    │       Resolve skills → build RUN_DIR → write manifest → start run.log
    ├── Phase 2: Skill creation (6× claude -p)
    │       champion/{T1,T2,T3}/    ← clean skill output
    │       challenger/{T1,T2,T3}/  ← clean skill output
    │       logs/*.creation.log     ← benchmark artifacts
    ├── Phase 3: Scoring (6× claude -p)
    │       scores/{champion,challenger}/{T1,T2,T3}/scores.md
    │       logs/*.scoring.log
    └── Phase 4: Decision (1× claude -p)
            decision.md  ←  primary output
            docs/benchmark-run-history.md  ←  history row appended

benchmark/
    ├── inputs/          ← fixed test briefs (T1/T2/T3)
    ├── rubric.md        ← 7-dimension scoring rubric (Feature 8)
    └── runs/            ← gitignored; accumulates run dirs

docs/
    └── benchmark-run-history.md  ← run history table
```

## Features

### Feature 1: Generalized CLI Interface

Replace hardcoded skill paths with named flags. `--challenger` is always required. `--champion` is optional. `--label` names the run for directory and history purposes. `--threshold` sets the minimum point delta needed to act (default: 3 out of 54).

Skill resolution is applied to both `--champion` and `--challenger`:
1. If the value ends in `.md` — use as a direct path to SKILL.md
2. If the value is a directory — use `<dir>/SKILL.md`
3. If the value is a bare name — resolve to `$REPO_ROOT/.claude/skills/<name>/SKILL.md`

**Acceptance Criteria:**

- `bash scripts/run-benchmark.sh` with no args prints a usage message listing `--challenger` as required and describes all three modes
- Each skill form (bare name, directory, direct .md path) resolves correctly in preflight
- A missing or unresolvable skill path produces: `ERROR: SKILL.md not found at <resolved-path>`
- `--label` and `--threshold` default to `comparison` and `3` respectively when omitted

---

### Feature 2: Git Main Comparison Mode

`--compare-main` flag: the script resolves the champion automatically by extracting the same skill path from the `main` branch via `git show main:<relative-path>`. Enables "current work vs last stable" without requiring the user to locate the old file.

**Acceptance Criteria:**

- `bash scripts/run-benchmark.sh --challenger occ-skill-creator --compare-main` extracts the champion from main and writes it to `<RUN_DIR>/champion/main-branch-SKILL.md` before Phase 2 begins
- Champion name displays as `<skill-name> (main branch)` in all output
- If the skill path does not exist on main: `ERROR: <path> not found on main branch — use --champion for an explicit path or omit for baseline mode`
- `--champion` and `--compare-main` are mutually exclusive; passing both prints an error

---

### Feature 3: Baseline Mode

When neither `--champion` nor `--compare-main` is provided, the champion slot runs with no `--system-prompt` — pure natural language with no skill loaded. Validates whether a new skill produces measurably better output than the model alone. Use before promoting a skill for the first time.

**Acceptance Criteria:**

- Omitting `--champion` and `--compare-main` launches Phase 2 champion creation with no `--system-prompt` flag
- Champion displays as `baseline (no skill)` in manifest, run.log, and decision.md
- Champion slot directory is named `baseline/` in the run directory
- Decision report uses baseline-mode verdict keywords: PROMOTE / NO VALUE / REJECT (not SWITCH RECOMMENDED / NO CHANGE / CHAMPION CONFIRMED)

---

### Feature 4: Structured Run Output Directory

Each run lands in `benchmark/runs/<label>__<YYYYMMDD-HHMMSS>/`. Label-first ordering groups same-comparison runs together when sorted. Benchmark artifacts (creation logs, scoring logs, decision log) are isolated in `logs/` so skill output directories contain only skill files.

**Acceptance Criteria:**

- Run directory name follows `<label>__<YYYYMMDD-HHMMSS>` format
- Skill output dirs (`champion/T1/`, `challenger/T1/`, etc.) contain only skill-generated files — no `.log` files
- All creation, scoring, and decision logs are in `<RUN_DIR>/logs/`
- `run.log` captures all stdout/stderr for the entire script via `exec > >(tee ...)`
- `benchmark/runs/` is gitignored
- `manifest.md` records: mode, champion name+path, challenger name+path, git hash, input SHA256s, threshold

---

### Feature 5: Decision Report

Phase 4 produces `decision.md` — the primary output of every run. The decision agent reads all 6 score files, computes totals, applies the threshold, and writes a structured report with one of six verdict keywords depending on mode and outcome.

**Champion vs Challenger mode verdicts:**

| Condition | Verdict |
|-----------|---------|
| Delta < threshold | NO CHANGE — champion retained |
| Delta ≥ threshold, challenger ahead | SWITCH RECOMMENDED |
| Delta ≥ threshold, champion ahead | CHAMPION CONFIRMED |

**Baseline mode verdicts:**

| Condition | Verdict |
|-----------|---------|
| Delta < threshold | NO VALUE — insufficient improvement over natural language |
| Delta ≥ threshold, challenger ahead | PROMOTE — skill demonstrates clear improvement |
| Delta ≥ threshold, baseline ahead | REJECT — natural language outperforms the skill |

**Acceptance Criteria:**

- `decision.md` contains exactly one bolded verdict keyword from the six above
- Report includes: run metadata, champion/challenger names, scores (X/54 each), delta, rationale paragraph, full score matrix, per-dimension analysis, and next steps
- `docs/benchmark-run-history.md` receives one new row appended to the history table
- Decision log written to `logs/decision.log`

---

### Feature 6: Supporting Updates

Three supporting changes required to make the tool correct and self-contained:

**Rubric scorer instruction:** Add an explicit note instructing the scoring agent to score only skill bundle files (SKILL.md, references/, scripts/) and ignore any other files present. This is belt-and-suspenders for the artifact separation in Feature 4.

**`.gitignore`:** Add `benchmark/runs/` so accumulated run directories are never committed.

**History doc format:** Replace `docs/benchmark-run-history.md` header block with a table-based run history format. Convert the existing run (20260307T002147Z) into the first row.

**Acceptance Criteria:**

- `benchmark/rubric.md` Agent Instructions section includes: "Score only files that are part of the skill bundle. Ignore any other files in the directory."
- `benchmark/runs/` is present in `.gitignore` (root)
- `docs/benchmark-run-history.md` opens with a run history table with columns: Run timestamp, Label, Champion, Challenger, Champion score, Challenger score, Verdict
- The 20260307T002147Z run appears as the first data row

## Configuration

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `--challenger` | skill reference | Skill being evaluated. Accepts bare name, directory, or `.md` path |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--champion` | skill reference | _(none — baseline mode)_ | Explicit champion skill. Mutually exclusive with `--compare-main` |
| `--compare-main` | flag | false | Extract champion from same skill path on git `main` branch |
| `--label` | string | `comparison` | Human-readable label; prefixes the run directory name |
| `--threshold` | integer | `3` | Minimum point delta (out of 63) required to act on the comparison |
| `--creation-model` | string | `sonnet` | Model used for Phase 2 skill creation. Affects skill output quality and skill-vs-baseline gap. |
| `--scoring-model` | string | `sonnet` | Model used for Phase 3 scoring and Phase 4 decision. |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BENCHMARK_SKIP_PERMISSIONS` | unset | Set to `1` to use `--dangerously-skip-permissions` instead of `--permission-mode dontAsk` on all `claude -p` calls |

## Outputs

| Output | Location | Description |
|--------|----------|-------------|
| `decision.md` | `<RUN_DIR>/decision.md` | Primary output: verdict, scores, rationale, next steps |
| `run.log` | `<RUN_DIR>/run.log` | Full stdout/stderr for the entire run |
| `manifest.md` | `<RUN_DIR>/manifest.md` | Run metadata: mode, skill names, paths, git hash, input hashes, threshold, creation model, scoring model |
| `scores.md` | `<RUN_DIR>/scores/{champion,challenger}/{T1,T2,T3}/scores.md` | Per-skill per-input rubric scores (6 files) |
| `*.creation.log` | `<RUN_DIR>/logs/` | Per-skill per-input creation agent output (6 files) |
| `*.scoring.log` | `<RUN_DIR>/logs/` | Per-skill per-input scoring agent output (6 files) |
| `decision.log` | `<RUN_DIR>/logs/decision.log` | Decision agent output |
| History row | `docs/benchmark-run-history.md` | One-line summary appended to run history table |

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Rubric saturation — skills and baseline all score near-max, leaving only noise to differentiate | Feature 8 (Style adherence) and Feature 7 (model selection) address this; Feature 10 (brief hardening) is the conditional fallback |
| `creation.log` artifact written into skill output dir (false Structure Compliance penalty) | Feature 4: separate `logs/` directory for all artifacts |
| `--dangerously-skip-permissions` used without isolation | `BENCHMARK_SKIP_PERMISSIONS` requires explicit opt-in; default uses `--permission-mode dontAsk` |
| `git show main:<path>` fails silently in detached HEAD or shallow clone | Explicit error message with actionable fallback instructions |

## External Dependencies

| Dependency | Owner | Status |
|------------|-------|--------|
| `claude` CLI | Anthropic | Available; required in PATH |
| `git` | System | Standard; required for `--compare-main` mode |
| `shasum` | System | Used for input SHA256s in manifest; macOS/Linux standard |

## Success Criteria

- All three modes (explicit, git-main, baseline) execute from invocation to `decision.md` without human intervention
- Skill output directories contain no benchmark artifacts
- `decision.md` verdict is unambiguous: one keyword, score delta, one-paragraph rationale
- Re-running the same comparison produces a second directory alongside the first (history accumulates correctly)
- A deliberately anti-quality skill scores materially lower than baseline (≤ 20/63) — `REJECT` verdict is producible
- A well-designed skill scores materially above baseline (≥ baseline + 3) — `PROMOTE` verdict is producible
- Manifest records creation model and scoring model for every run

---

### Feature 7: Configurable Model Selection

Add `--creation-model` and `--scoring-model` flags to `run-benchmark.sh`. Both default to `sonnet`, preserving existing behaviour. Each can be overridden independently, enabling diagnostic testing (e.g. `--creation-model haiku` to widen the skill-vs-baseline gap) and higher-quality scoring (e.g. `--scoring-model opus`).

Both models are recorded in `manifest.md` so runs are reproducible and scores from different model configurations are not conflated.

**Motivation:** Rubric saturation was observed when `sonnet` is used for creation — the model is capable enough that skill-guided and baseline outputs converge near the top of the rubric. Haiku has weaker priors and needs more guidance, making a well-designed skill's impact more visible.

**Acceptance Criteria:**

- `--creation-model haiku --scoring-model sonnet` runs without error; Phase 2 uses `haiku`, Phases 3 and 4 use `sonnet`
- Omitting both flags behaves identically to previous versions (no regression)
- `manifest.md` contains `| Creation model |` and `| Scoring model |` rows with the correct values
- `--help` output documents both flags with their defaults

---

### Feature 8: Style Adherence Rubric Dimension

Add a 7th dimension — **Style adherence** — to `benchmark/rubric.md`. This dimension scores how consistently the output follows the conventions of the skill that was loaded during creation. Baseline runs score 0 by definition (no skill was loaded; no conventions to follow). This creates a systematic gap between skill-guided and baseline runs that the six existing structural dimensions cannot produce.

The scoring agent receives the loaded skill's content at runtime via the scoring prompt. No specific skill name is hardcoded — the dimension works for any skill.

Maximum score changes from 54 (6 × 3 inputs × max 3pts) to **63** (7 × 3 inputs × max 3pts).

**Style adherence scoring criteria:**

| Score | Criteria |
|-------|----------|
| 0 | No skill was loaded (baseline run), OR skill loaded but output ignores all its conventions |
| 1 | Output follows some conventions from the loaded skill (e.g. has frontmatter but structure diverges) |
| 2 | Output follows most conventions — correct frontmatter format, appropriate section structure, similar prose style |
| 3 | Output fully consistent with loaded skill — frontmatter matches exactly, trigger phrase style matches, structure and prose style match throughout |

**Acceptance Criteria:**

- `benchmark/rubric.md` contains a Style adherence row in the scoring table with 0–3 criteria
- `benchmark/rubric.md` Agent Instructions section is generalised — no specific skill name appears
- Stale output path in rubric.md Output Format corrected: `temp/benchmark/...` → `benchmark/runs/...`
- Phase 3 scoring prompt dynamically injects loaded skill content for skill-guided slots, and explicit zero-score instruction for baseline slots
- Phase 4 decision agent references max 63 (not 54) throughout; score matrix includes Style adherence row
- `docs/benchmark-run-history.md` header updated: `Scores are out of 63 (7 dimensions from [date]; prior runs max 54)`
- Running the benchmark with `--challenger <any-skill>` in baseline mode: Style adherence scores 0 for baseline slot and > 0 for skill-guided slot

---

### Feature 9: Revised bad-skill Test Fixture

Rewrite `benchmark/test-fixtures/bad-skill/SKILL.md` to produce outputs that score near 0 on every rubric dimension. The current fixture scores 54/54 because it contains structural cues the model uses to produce quality output regardless of the degrading instructions.

The revision removes all structural scaffolding and replaces each instruction with an explicit anti-quality directive targeting a specific rubric dimension.

**Target score:** ≤ 14/63 per run (allowing for partial model override at 0–2 per dimension)

| Instruction | Dimension targeted |
|-------------|-------------------|
| No `name` field in frontmatter | Frontmatter quality |
| `description: skill` (one word, no trigger phrases) | Trigger specificity |
| Single prose paragraph, no steps or error handling | Instruction quality |
| No references/ directory; 600+ word monolith | Progressive disclosure |
| Create README.md and CHANGELOG.md alongside SKILL.md | Structure compliance |
| 600+ words with repetition, no concision | Conciseness |
| Incoherent conventions, no recognisable style | Style adherence |

**Acceptance Criteria:**

- `benchmark/test-fixtures/bad-skill/SKILL.md` contains no headers, no bullet lists, no step-by-step instructions
- Running `--challenger benchmark/test-fixtures/bad-skill` in baseline mode produces verdict `REJECT`
- Running `--champion <any-skill> --challenger benchmark/test-fixtures/bad-skill` produces verdict `CHAMPION CONFIRMED`
- bad-skill scores ≤ 20/63; baseline scores ≥ 40/63

---

### Feature 10: Brief Hardening (Conditional)

**Precondition:** Apply only if Features 7, 8, and 9 do not produce a `PROMOTE` verdict for TC-3 (a well-designed skill vs baseline) on both `sonnet` and `haiku` creation models.

Augment `benchmark/inputs/T1-simple.md` with explicit convention requirements a baseline model would not know without skill guidance. The skill-guided model, following a well-designed skill's conventions, produces the correct name, trigger phrases, example, and error handling. The baseline model produces a valid-but-generic skill that misses them.

**Acceptance Criteria (conditional on precondition being met):**

- `benchmark/inputs/T1-simple.md` includes a Required Conventions section specifying: `name` field value, minimum trigger phrases, example format, and error handling requirements
- Running `--challenger <well-designed-skill>` in baseline mode with the updated T1 produces verdict `PROMOTE`
- Running `--challenger baseline` (no skill) misses at least two of the required conventions

---

### Feature 12: Multi-Run Variance Analysis

Single benchmark runs have 1–2 point variance due to model non-determinism. A `--runs N` wrapper script runs the benchmark N times and produces a statistical summary — mean and stddev per dimension per skill — reducing noise to a reliable signal.

Implemented as a separate wrapper script `scripts/run-variance.sh` that calls `run-benchmark.sh` N times, parses scores from each run's score files using awk, computes statistics in bash, and writes a `variance-report.md` to a parent directory. No changes to `run-benchmark.sh`.

**Acceptance Criteria:**

- `bash scripts/run-variance.sh --challenger <skill> --runs 3` executes 3 complete benchmark runs and writes a `variance-report.md`
- `variance-report.md` contains: verdict distribution table, score summary with mean/stddev/min/max per slot, per-dimension mean/stddev table per slot, individual run results table with links to run directories
- Recommendation line states confidence level: unanimous (all agree), majority (>50% agree), or split
- Each individual run still appends its own row to `docs/benchmark-run-history.md` via the core script
- `--runs` defaults to 3; minimum value is 2; passing 1 is an error
- All flags accepted by `run-benchmark.sh` pass through to each run unchanged
- No `claude -p` calls in the variance script itself — statistics computed in awk

**Outputs:**

| File | Location | Description |
|------|----------|-------------|
| `variance-report.md` | `benchmark/runs/variance__<label>__<ts>/` | Aggregated statistical summary |
| Individual run dirs | `benchmark/runs/<label>__var<N>__<ts>/` | One per run, standard structure |

---

## Future Enhancements

| Enhancement | Description |
|-------------|-------------|
| Multi-run variance analysis | ~~Run N times, compute mean/stddev per skill — reduces single-run noise to a reliable signal~~ Implemented as Feature 12 |
| Configurable test inputs | `--inputs <dir>` flag to use a custom brief set instead of the fixed T1/T2/T3 |
| HTML decision report | Render `decision.md` as a formatted HTML summary for sharing |
| Score trend tracking | Parse history table to plot score delta over successive iterations of a skill |
