# Update Docs Terraform

**Source:** `commands/update-docs-terraform.md`
**Command:** `/update-docs-terraform`
**Activation:** Manual — invoked via slash command or trigger phrase matching

## Description

Synchronizes `README.md` and `docs/ARCHITECTURE.md` with the current state of a Terraform project. These files contain tables, diagrams, and summaries that drift as features are added. This is the Terraform-specific documentation refresh command — it reads from Terraform-specific sources like `variables.tf`, `locals.tf`, `terraform.tfvars`, `backend.tf`, and `modules/`.

## Usage

```
/update-docs-terraform
```

No arguments. The command reads from the current Terraform project's source files and documentation.

## Inputs

| Input | Source | Required |
|---|---|---|
| Feature status | `progress.txt` | Yes |
| Recent feature entries | `CHANGELOG.md` | Yes |
| Input variable definitions | `variables.tf` (names, types, defaults, descriptions) | Yes |
| Computed local values | `locals.tf` | Yes |
| Current variable values | `terraform.tfvars` | Yes |
| State backend configuration | `backend.tf` | Yes |
| Module directories | `modules/` (purpose, inputs, outputs, resources per module) | Yes |
| Existing README | `README.md` | Yes |
| Existing architecture doc | `docs/ARCHITECTURE.md` | Yes |

## Outputs

| Output | Location | Description |
|---|---|---|
| Updated README | `README.md` (in-place edit) | Sections updated to match current Terraform project state |
| Updated architecture doc | `docs/ARCHITECTURE.md` (in-place edit) | Sections updated to match current Terraform project state |
| Change report | Console (stdout) | Summary of what was updated in each file |

## Workflow

### Step 1 — Gather current state

Reads these sources to understand what is current:

1. `progress.txt` — which features are complete
2. `CHANGELOG.md` — recent feature entries
3. `variables.tf` — input variable definitions (names, types, defaults, descriptions)
4. `locals.tf` — computed local values and naming conventions
5. `terraform.tfvars` — current variable values for the environment
6. `backend.tf` — state backend configuration
7. `modules/` — scans module directories for purpose, inputs, outputs, and resources

### Step 2 — Update README.md

Checks and updates the following sections:

| Section | What to check |
|---|---|
| Architecture Overview | Matches current module and environment structure |
| Module table | All modules listed with purpose and key resources |
| Project Structure (tree) | File paths match actual structure |
| Configuration variables | All variables from `variables.tf` present with types and defaults |
| Deployment instructions | Commands reflect current backend and provider setup |
| Environment layout | `envs/` directories match reality |

### Step 3 — Update docs/ARCHITECTURE.md

Checks and updates the following sections:

| Section | What to check |
|---|---|
| Header metadata | Version number, Last Updated date |
| Module Design | All modules documented with inputs/outputs |
| Environment Layout | `envs/` structure and purpose of each environment |
| Provider Configuration | Provider versions, required_providers block |
| State Management | Backend type, locking mechanism |
| Validation | Tools used (fmt, validate, tflint, tfsec), what each checks |
| Variable Catalog | All variables with types, constraints, validation rules |

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

- After multiple Terraform features have been completed and documentation has drifted
- Before creating a pull request for a Terraform project
- When variable tables, module listings, or architecture diagrams are out of date
- As a periodic maintenance task for Terraform projects

## When Not to Use

- For non-Terraform projects — use `/update-docs` (generic) or `/update-docs-cdk` (CDK) instead
- If documentation structure needs reorganization — this command only updates values within existing sections
- If new documentation sections are needed — the command will note them in the report but will not create them

## Related Commands and Skills

- `/update-docs` — Generic variant for projects that are not CDK or Terraform.
- `/update-docs-cdk` — CDK-specific variant that additionally handles `docs/TESTING.md` and CDK-specific sources.
- `/create-prd` — Creates the initial documentation that this command later refreshes.
- `/start-feature` — After features are implemented, documentation drifts and needs refreshing with this command.
