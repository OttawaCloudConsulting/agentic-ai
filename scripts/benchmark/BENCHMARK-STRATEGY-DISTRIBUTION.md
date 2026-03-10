# Benchmarking Strategy: Distribution and Consumption

This document defines how the benchmark tooling is packaged, what consumers receive, and how to set it up in a target repository. It is written for a self-service model — no support is provided; this documentation is the complete resource.

---

## Distribution Model

The benchmark is distributed as a directory bundle. Consumers copy it directly into their repository. There is no installer, no package manager dependency, and no network requirement beyond the `claude` CLI itself.

**Distribution is one-way.** Updates to the benchmark do not propagate automatically. When a consumer copies the bundle, they own that copy. Upgrading means re-copying and reconciling any local changes.

---

## What Is Included

Copy the following from this repository into the consuming repository, preserving the directory structure:

```
scripts/
    run-benchmark.sh        ← core comparison script
    run-variance.sh         ← multi-run statistical wrapper

benchmark/
    rubric.md               ← 7-dimension scoring rubric
    inputs/
        T1-simple.md        ← test brief: single-concern task
        T2-medium.md        ← test brief: multi-step workflow
        T3-complex.md       ← test brief: branching/variant task
```

**Do not copy:**
- `benchmark/runs/` — gitignored run output; never distributed
- `benchmark/prd.md` — internal product requirements, not consumer-facing
- `benchmark/test-fixtures/` — internal test fixtures; not required for operation
- `docs/` — reference documentation; link to source rather than copy

**Add to the consuming repository's `.gitignore`:**

```
benchmark/runs/
```

Run output accumulates locally and is never committed. The run history table is the committed record.

---

## Dependencies

All dependencies must be present in the consumer's environment before the first run.

| Dependency | Required by | How to verify | Notes |
|------------|-------------|---------------|-------|
| `bash` 4.0+ | Both scripts | `bash --version` | macOS ships bash 3.2; install 4+ via Homebrew: `brew install bash` |
| `claude` CLI | `run-benchmark.sh` | `claude --version` | Claude Code must be installed and authenticated |
| `git` | `run-benchmark.sh` | `git --version` | Required for `--compare-main` mode and git hash in manifest |
| `awk` | `run-variance.sh` | `awk --version` | Standard on macOS and Linux; no additional install needed |
| `shasum` | `run-benchmark.sh` | `shasum --version` | Standard on macOS; on Linux use `sha256sum` (see note below) |

**Linux note:** `shasum` is a Perl utility present on macOS by default. On Linux, `shasum -a 256` may need to be replaced with `sha256sum`. This only affects the input hash recorded in `manifest.md` — it does not affect scoring.

**bash 4+ on macOS:** The scripts use associative arrays (`declare -A`) which require bash 4+. macOS ships with bash 3.2 due to licensing. Install via Homebrew and invoke explicitly:

```bash
/opt/homebrew/bin/bash scripts/benchmark/run-benchmark.sh --challenger my-skill
```

Or set the shebang path in your shell profile so `bash` resolves to 4+.

---

## Verify the Install

After copying the bundle, run the help flag to confirm the script is reachable and bash version is sufficient:

```bash
bash scripts/benchmark/run-benchmark.sh --help
bash scripts/benchmark/run-variance.sh --help
```

Then run a smoke test against any skill in the repository:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger .claude/skills/<any-skill>/SKILL.md \
  --label smoke-test \
  --creation-model haiku
```

A successful smoke test produces `benchmark/runs/smoke-test__<timestamp>/decision.md`. Open it and confirm the verdict section is populated.

---

## Running Inside Claude Code

Claude Code blocks nested sessions by default. Running `bash scripts/benchmark/run-benchmark.sh` from within a Claude Code terminal will fail with:

```
Claude Code cannot be launched inside another Claude Code session.
```

**Solution:** Prefix every invocation with `env -u CLAUDECODE`:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh --challenger <skill>
```

`BENCHMARK_SKIP_PERMISSIONS=1` uses `--dangerously-skip-permissions` on all internal `claude -p` calls, bypassing interactive permission prompts. This is required for unattended execution. Do not use this in environments where filesystem access should be restricted.

Alternatively, run benchmarks from a separate terminal outside the Claude Code session — all scripts are standard bash and require no IDE integration.

---

## Environment Variables

| Variable | Effect | When to set |
|----------|--------|-------------|
| `BENCHMARK_SKIP_PERMISSIONS=1` | Uses `--dangerously-skip-permissions` on all `claude -p` calls | Required for unattended runs; required when running inside Claude Code |
| `CLAUDECODE` (unset) | Allows `claude` CLI to launch inside an existing session | Unset with `env -u CLAUDECODE` when running inside Claude Code |

---

## First Run Checklist

```
[ ] bash 4+ is available and on PATH (check: bash --version)
[ ] claude CLI is installed and authenticated (check: claude --version)
[ ] git is available (check: git --version)
[ ] Bundle copied: scripts/benchmark/run-benchmark.sh, scripts/benchmark/run-variance.sh
[ ] Bundle copied: benchmark/rubric.md, benchmark/inputs/T1–T3
[ ] benchmark/runs/ added to .gitignore
[ ] Smoke test completed: decision.md produced with a populated verdict
```

---

## Skill Reference Formats

All `--challenger` and `--champion` flags accept three reference formats:

| Format | Example | Resolves to |
|--------|---------|-------------|
| Bare name | `my-skill` | `.claude/skills/my-skill/SKILL.md` |
| Directory | `path/to/my-skill/` | `path/to/my-skill/SKILL.md` |
| Direct path | `path/to/SKILL.md` | `path/to/SKILL.md` |

Bare name resolution assumes skills live at `.claude/skills/<name>/SKILL.md` relative to the repository root. If your repository uses a different convention, use the directory or direct path form.

---

## What Is Not Provided

This is a free distribution. The following are explicitly out of scope:

- Bug fixes or patches after distribution
- Support for non-standard environments (Windows, unusual bash configurations)
- Customised rubrics or test briefs
- Integration with CI/CD pipelines
- Training or onboarding assistance

The documentation in this repository — this file, `BENCHMARK.md`, `benchmark-user-guide.md`, and `BENCHMARK-STRATEGY-LIFECYCLE.md` — is the complete resource. If the documentation does not answer a question, the answer is to read the scripts directly: `run-benchmark.sh` is thoroughly commented and its phases are clearly delineated.
