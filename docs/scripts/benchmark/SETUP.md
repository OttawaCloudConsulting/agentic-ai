# Benchmark Setup Guide

Installation and first-run guide for the benchmark bundle. This document is the complete resource — no support is provided.

---

## Documentation Map

| # | Document | Purpose |
|---|----------|---------|
| 1 | SETUP.md *(this file)* | Install and first run |
| 2 | LIFECYCLE-GUIDE.md | When to run and what verdicts mean for promotion decisions |
| 3 | USER-GUIDE.md | How to run each workflow with concrete commands |
| 4 | REFERENCE.md | Complete flag, mode, output, and scoring reference |
| 5 | RUBRIC-GUIDE.md | Rubric customisation — read only if you need to adapt scoring |

Read in this order unless you have a specific reference question.

---

## 1. Prerequisites

All dependencies must be present before the first run.

| Dependency | Required by | Verify |
|------------|-------------|--------|
| `bash` 4.0+ | both scripts | `bash --version` |
| `claude` CLI | `run-benchmark.sh` | `claude --version` |
| `git` | `run-benchmark.sh` | `git --version` |
| `awk` | `run-variance.sh` | `awk --version` |
| `shasum` | `run-benchmark.sh` | `shasum --version` |

**macOS — bash version:** macOS ships with bash 3.2. The scripts use associative arrays (`declare -A`) which require bash 4+. Install via Homebrew:

```bash
brew install bash
```

Invoke explicitly until your shell resolves `bash` to 4+:

```bash
/opt/homebrew/bin/bash scripts/benchmark/run-benchmark.sh --challenger <skill>
```

**Linux — shasum:** `shasum` is a macOS default. On Linux, `shasum -a 256` may be absent; `sha256sum` is the equivalent. The script detects `sha256sum` automatically on Linux — no manual configuration required. This only affects the input hash recorded in `manifest.md` and does not affect scoring.

---

## 2. What to Copy

Copy the following into your repository, preserving the directory structure:

```
scripts/
  benchmark/
    run-benchmark.sh
    run-variance.sh

benchmark/
  rubric.md
  inputs/
    T1-simple.md
    T2-medium.md
    T3-complex.md
```

**Do not copy:**

- `benchmark/runs/` — gitignored run output; never distributed
- `benchmark/prd.md` — internal product requirements
- `benchmark/test-fixtures/` — internal fixtures; not required for operation
- `docs/` — link to source rather than copy

**Add to `.gitignore`:**

```
benchmark/runs/
```

Run output accumulates locally and is never committed. The committed audit trail is `docs/benchmark-run-history.md`, which the script appends to automatically after each run.

---

## 3. Verify the Install

Confirm the scripts are reachable and the bash version is sufficient:

```bash
bash scripts/benchmark/run-benchmark.sh --help
bash scripts/benchmark/run-variance.sh --help
shasum --version 2>/dev/null || sha256sum --version
```

Then run a smoke test against any skill in the repository:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger .claude/skills/<any-skill>/SKILL.md \
  --label smoke-test \
  --creation-model haiku
```

Replace `<any-skill>` with an actual skill directory name from `.claude/skills/` in your repository. For example, if you have `occ-skill-creator` installed the argument would be `--challenger .claude/skills/occ-skill-creator/SKILL.md`.

A successful smoke test produces `benchmark/runs/smoke-test__<timestamp>/decision.md`. Open it and confirm the verdict section is populated.

---

## 4. Running Inside Claude Code

Claude Code blocks nested sessions by default. Running `run-benchmark.sh` from within a Claude Code terminal will fail:

```
Claude Code cannot be launched inside another Claude Code session.
```

**Solution — unset the session variable:**

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger <skill>
```

`env -u CLAUDECODE` removes the variable that triggers the nested-session guard. `BENCHMARK_SKIP_PERMISSIONS=1` passes `--dangerously-skip-permissions` to all internal `claude -p` calls, bypassing interactive permission prompts. Both are required for unattended execution inside Claude Code.

**Alternative — external terminal:** Run benchmarks from a separate terminal outside the Claude Code session. The scripts are standard bash and require no IDE integration.

---

## 5. First Run Checklist

```
[ ] bash 4+ available (bash --version shows 4.x or higher)
[ ] claude CLI installed and authenticated (claude --version)
[ ] git available (git --version)
[ ] scripts/benchmark/run-benchmark.sh copied to repository
[ ] scripts/benchmark/run-variance.sh copied to repository
[ ] benchmark/rubric.md copied to repository
[ ] benchmark/inputs/T1-simple.md, T2-medium.md, T3-complex.md copied
[ ] benchmark/runs/ added to .gitignore
[ ] --help flag returns usage for both scripts
[ ] Smoke test completed: decision.md produced with a populated verdict
```

Read [LIFECYCLE-GUIDE.md](LIFECYCLE-GUIDE.md) next to understand when to run the benchmark and how to use verdicts in your skill development process.
