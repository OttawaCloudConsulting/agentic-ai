---
name: update-docs-cdk
description: Refresh CDK project documentation (README, ARCHITECTURE, TESTING) to match current codebase state. Use after multiple features have been completed, before creating a PR, or when documentation feels stale.
disable-model-invocation: true
---

# /update-docs-cdk — Refresh CDK Project Documentation

Synchronize README.md, docs/ARCHITECTURE.md, and docs/TESTING.md with the current state of the codebase. These files contain counts, tables, and summaries that drift as features are added.

## Execution Steps

### Step 1 — Gather current state

Read these sources to understand what's current:

1. **`progress.txt`** — which features are complete
2. **`CHANGELOG.md`** — recent feature entries
3. **`cdk.json`** — CDK context values and feature flags
4. **`lib/`** — scan stack and construct files for components, resources, configuration
5. **`npm test -- --verbose`** — run tests to get exact suite/test counts
6. **`test/`** — scan test files for describe blocks and test counts per suite

If a dedicated config file exists (e.g., `lib/config.ts`, `lib/constants.ts`), read it for parameter definitions and defaults. Otherwise, extract configuration from stack/construct props and `cdk.json` context.

### Step 2 — Update README.md

Check and update these sections:

| Section                          | What to check                                           |
| -------------------------------- | ------------------------------------------------------- |
| Architecture Overview            | Matches current stack structure                         |
| Configuration table              | All configurable params present with correct defaults   |
| Project Structure (tree)         | File paths match actual structure                       |
| Stacks table                     | Stack names, purposes, key resources accurate           |
| Monitoring section               | Alarm count, dashboard reference, metric lists          |
| Testing section                  | Suite count, total test count, suite descriptions       |
| Cost Estimate                    | Reflects current infrastructure                         |
| Tech Stack                       | Version numbers current                                 |

### Step 3 — Update docs/ARCHITECTURE.md

Check and update these sections:

| Section                          | What to check                                           |
| -------------------------------- | ------------------------------------------------------- |
| Header metadata                  | Version number, Last Updated date                       |
| What It Provides                 | Feature count matches reality                           |
| Optional Features list           | All feature flags listed                                |
| Stack Architecture               | Diagram and dependency graph current                    |
| Component Design                 | All constructs, services, and resources documented      |
| Configuration Management         | Parameter tables match actual configurable values       |
| Monitoring and Observability     | Alarm count, dashboard, metric lists                    |
| Cost Profile                     | Breakdown matches current resources                     |
| Testing section                  | Total test count, suite count                           |

### Step 4 — Update docs/TESTING.md

This file documents **unit tests and CDK assertions** (not the validation shell script).

Check and update these sections:

| Section                          | What to check                                           |
| -------------------------------- | ------------------------------------------------------- |
| Header metadata                  | Total test count, suite count                           |
| Suite Summary table              | Test counts per file, describe block counts             |
| Test Inventory                   | Each suite's test list matches actual test names        |
| Coverage by resource type        | Reflects current resource coverage                      |

### Step 5 — Report changes

Summarize what was updated:

```text
DOCUMENTATION REFRESH COMPLETE

README.md:
  - [list of changes, or "No changes needed"]

docs/ARCHITECTURE.md:
  - [list of changes, or "No changes needed"]

docs/TESTING.md:
  - [list of changes, or "No changes needed"]
```

## Important Rules

- **Read before writing** — always read the current file content before making edits
- **Preserve structure** — update values within existing sections, don't reorganize
- **Accuracy over speed** — verify counts by running tests and reading source files, don't guess
- **No new sections** — only update existing content. If new sections are needed, note it in the report
- **Config source of truth** — `cdk.json` (context), stack/construct props, and any dedicated config file in `lib/` are authoritative for configuration
- **Test source of truth** — `npm test --verbose` output is authoritative for test counts
