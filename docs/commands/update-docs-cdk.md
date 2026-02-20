# Update Docs CDK

**Source:** `commands/update-docs-cdk.md`
**Command:** `/update-docs-cdk`
**Activation:** Manual — invoked via slash command or trigger phrase matching

## Description

Synchronizes `README.md`, `docs/ARCHITECTURE.md`, and `docs/TESTING.md` with the current state of a CDK project. These files contain counts, tables, and summaries that drift as features are added. This is the CDK-specific documentation refresh command — it reads from CDK-specific sources like `cdk.json`, `lib/`, and `test/`, and runs tests to get exact counts.

## Usage

```
/update-docs-cdk
```

No arguments. The command reads from the current CDK project's source files and documentation.

## Inputs

| Input | Source | Required |
|---|---|---|
| Feature status | `progress.txt` | Yes |
| Recent feature entries | `CHANGELOG.md` | Yes |
| CDK context and feature flags | `cdk.json` | Yes |
| Stack and construct source code | `lib/` directory | Yes |
| Configuration definitions | `lib/config.ts`, `lib/constants.ts`, or stack/construct props | Yes (whichever exists) |
| Test results | `npm test -- --verbose` output | Yes |
| Test source files | `test/` directory | Yes |
| Existing README | `README.md` | Yes |
| Existing architecture doc | `docs/ARCHITECTURE.md` | Yes |
| Existing testing doc | `docs/TESTING.md` | Yes |

## Outputs

| Output | Location | Description |
|---|---|---|
| Updated README | `README.md` (in-place edit) | Sections updated to match current CDK project state |
| Updated architecture doc | `docs/ARCHITECTURE.md` (in-place edit) | Sections updated to match current CDK project state |
| Updated testing doc | `docs/TESTING.md` (in-place edit) | Test suite and count information updated to match current test results |
| Change report | Console (stdout) | Summary of what was updated in each file |

## Workflow

### Step 1 — Gather current state

Reads these sources to understand what is current:

1. `progress.txt` — which features are complete
2. `CHANGELOG.md` — recent feature entries
3. `cdk.json` — CDK context values and feature flags
4. `lib/` — scans stack and construct files for components, resources, and configuration
5. `npm test -- --verbose` — runs tests to get exact suite and test counts
6. `test/` — scans test files for describe blocks and test counts per suite

If a dedicated config file exists (e.g., `lib/config.ts`, `lib/constants.ts`), reads it for parameter definitions and defaults. Otherwise, extracts configuration from stack/construct props and `cdk.json` context.

### Step 2 — Update README.md

Checks and updates the following sections:

| Section | What to check |
|---|---|
| Architecture Overview | Matches current stack structure |
| Configuration table | All configurable params present with correct defaults |
| Project Structure (tree) | File paths match actual structure |
| Stacks table | Stack names, purposes, key resources accurate |
| Monitoring section | Alarm count, dashboard reference, metric lists |
| Testing section | Suite count, total test count, suite descriptions |
| Cost Estimate | Reflects current infrastructure |
| Tech Stack | Version numbers current |

### Step 3 — Update docs/ARCHITECTURE.md

Checks and updates the following sections:

| Section | What to check |
|---|---|
| Header metadata | Version number, Last Updated date |
| What It Provides | Feature count matches reality |
| Optional Features list | All feature flags listed |
| Stack Architecture | Diagram and dependency graph current |
| Component Design | All constructs, services, and resources documented |
| Configuration Management | Parameter tables match actual configurable values |
| Monitoring and Observability | Alarm count, dashboard, metric lists |
| Cost Profile | Breakdown matches current resources |
| Testing section | Total test count, suite count |

### Step 4 — Update docs/TESTING.md

This file documents unit tests and CDK assertions (not validation shell scripts). Checks and updates the following sections:

| Section | What to check |
|---|---|
| Header metadata | Total test count, suite count |
| Suite Summary table | Test counts per file, describe block counts |
| Test Inventory | Each suite's test list matches actual test names |
| Coverage by resource type | Reflects current resource coverage |

### Step 5 — Report changes

Summarizes what was updated:

```
DOCUMENTATION REFRESH COMPLETE

README.md:
  - [list of changes, or "No changes needed"]

docs/ARCHITECTURE.md:
  - [list of changes, or "No changes needed"]

docs/TESTING.md:
  - [list of changes, or "No changes needed"]
```

## When to Use

- After multiple CDK features have been completed and documentation has drifted
- Before creating a pull request for a CDK project
- When test counts, alarm counts, or configuration tables are out of date
- As a periodic maintenance task for CDK projects

## When Not to Use

- For non-CDK projects — use `/update-docs` (generic) or `/update-docs-terraform` (Terraform) instead
- If documentation structure needs reorganization — this command only updates values within existing sections
- If new documentation sections are needed — the command will note them in the report but will not create them

## Related Commands and Skills

- `/update-docs` — Generic variant for projects that are not CDK or Terraform.
- `/update-docs-terraform` — Terraform-specific variant that reads from `variables.tf`, `modules/`, and other Terraform sources.
- `/create-prd` — Creates the initial documentation that this command later refreshes.
- `/start-feature` — After features are implemented, documentation drifts and needs refreshing with this command.
