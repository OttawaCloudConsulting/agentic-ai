# Update Docs

**Source:** `commands/update-docs.md`
**Command:** `/update-docs`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "refresh documentation," "update the docs")

## Description

Synchronizes `README.md` and `docs/ARCHITECTURE.md` with the current state of the codebase. These files contain counts, tables, and summaries that drift as features are added. This is the generic documentation refresh command — not for CDK or Terraform projects, which have their own specialized variants.

## Usage

```
/update-docs
```

No arguments. The command reads from the current project's source files and documentation.

## Inputs

| Input | Source | Required |
|---|---|---|
| Feature status | `progress.txt` | Yes |
| Recent feature entries | `CHANGELOG.md` | Yes |
| Project source files | File system scan (components, modules, configuration, structure) | Yes |
| Existing README | `README.md` | Yes |
| Existing architecture doc | `docs/ARCHITECTURE.md` | Yes |

## Outputs

| Output | Location | Description |
|---|---|---|
| Updated README | `README.md` (in-place edit) | Sections updated to match current codebase state |
| Updated architecture doc | `docs/ARCHITECTURE.md` (in-place edit) | Sections updated to match current codebase state |
| Change report | Console (stdout) | Summary of what was updated in each file |

## Workflow

### Step 1 — Gather current state

Reads these sources to understand what is current:

1. `progress.txt` — which features are complete
2. `CHANGELOG.md` — recent feature entries
3. Project source files — scans for components, modules, configuration, and structure

### Step 2 — Update README.md

Checks and updates the following sections:

| Section | What to check |
|---|---|
| Architecture Overview | Matches current component structure |
| Project Structure (tree) | File paths match actual structure |
| Configuration | Parameters/settings present with correct defaults |
| Setup / Installation | Prerequisites and steps are current |
| Usage | Commands and examples reflect current behavior |
| Tech Stack | Version numbers current |

### Step 3 — Update docs/ARCHITECTURE.md

Checks and updates the following sections:

| Section | What to check |
|---|---|
| Header metadata | Version number, Last Updated date |
| Component Design | All components documented |
| Configuration | Parameter tables match source of truth |
| Data Flow / Request Flow | Diagrams and descriptions current |
| Dependencies | External dependencies listed and accurate |

### Step 4 — Report changes

Summarizes what was updated:

```
DOCUMENTATION REFRESH COMPLETE

README.md:
  - [list of changes, or "No changes needed"]

docs/ARCHITECTURE.md:
  - [list of changes, or "No changes needed"]
```

## When to Use

- After multiple features have been completed and documentation has drifted
- Before creating a pull request, to ensure documentation is current
- When documentation feels stale or out of sync with the codebase
- As a periodic maintenance task

## When Not to Use

- For CDK projects — use `/update-docs-cdk` instead, which also handles `docs/TESTING.md` and CDK-specific sources like `cdk.json`
- For Terraform projects — use `/update-docs-terraform` instead, which handles Terraform-specific sources like `variables.tf` and `modules/`
- If documentation structure needs reorganization — this command only updates values within existing sections, not the structure itself

## Related Commands and Skills

- `/update-docs-cdk` — CDK-specific variant that additionally updates `docs/TESTING.md` and reads from CDK-specific sources (`cdk.json`, `lib/`, `test/`).
- `/update-docs-terraform` — Terraform-specific variant that reads from Terraform-specific sources (`variables.tf`, `locals.tf`, `modules/`).
- `/create-prd` — Creates the initial documentation that this command later refreshes.
- `/start-feature` — After features are implemented via `/start-feature`, documentation drifts and needs refreshing with this command.
