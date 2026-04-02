# Testing Patterns

## Overview

This repo has no automated test suite. "Testing" takes two forms:

1. **Skill benchmarking** — manual runs documented in `skills/<name>/review/BENCHMARK.md`
2. **Markdown linting** — automated via `bash cicd/lint-markdown.sh`

## Markdown Linting (Automated)

The only CI-enforced quality gate is markdown linting.

**Tool:** `markdownlint-cli2` (installed via npx if not present)

**Config files:**
- `.markdownlint.jsonc` — rules enforced as errors (5 rules disabled as repo-intentional)
- `.markdownlint-fix.markdownlint.jsonc` — rules applied as auto-fixes silently

**Run:**
```bash
bash cicd/lint-markdown.sh              # lint current directory
bash cicd/lint-markdown.sh -r           # lint recursively
bash cicd/lint-markdown.sh README.md    # lint specific file
bash cicd/lint-markdown.sh --no-fix     # report only, no auto-fix
```

**Three-tier rule handling:**
1. Ignored rules — disabled in `.markdownlint.jsonc` (never checked)
2. Auto-fix rules — enabled in `.markdownlint-fix.markdownlint.jsonc` (fixed silently)
3. Error rules — everything else (reported as failures)

## Skill Benchmarking (Manual)

Each skill directory contains `review/BENCHMARK.md` documenting quality evaluation.

**Pattern:** `skills/<name>/review/BENCHMARK.md`

**Typical content:**
- Test scenarios run
- Pass/fail observations
- Edge cases explored
- Known limitations

**Also present:**
- `review/FEEDBACK.md` — human reviewer feedback
- `review/PLAN.md` — improvement plan based on feedback

## No Automated Skill Tests

Skills are prompt-engineering artifacts executed by Claude. There is no framework for unit testing prompts. Correctness is validated through:
- Manual benchmark runs documented in `review/BENCHMARK.md`
- The GSD `/gsd:validate-phase` workflow for phase verification
- The `occ-skill-creator` and `occ-skill-refactor` skills for peer review

## Adding Tests for New Skills

When creating a new skill, populate `review/BENCHMARK.md` with:
1. At least 3 representative test scenarios
2. Expected vs observed outputs
3. Edge cases (empty state, re-run on existing artifacts, user rejection flow)
4. Observed failure modes

The GSD `/gsd:add-tests` skill can generate test scenarios for completed phases.
