---
name: update-docs-terraform
description: Refresh project documentation (README, ARCHITECTURE) to match current codebase state. Use after multiple features have been completed, before creating a PR, or when documentation feels stale.
disable-model-invocation: true
---

# /update-docs-terraform — Refresh Project Documentation

Synchronize README.md and docs/ARCHITECTURE.md with the current state of the codebase. These files contain tables, diagrams, and summaries that drift as features are added.

## Execution Steps

### Step 1 — Gather current state

Read these sources to understand what's current:

1. **`progress.txt`** — which features are complete
2. **`CHANGELOG.md`** — recent feature entries
3. **`variables.tf`** — input variable definitions (names, types, defaults, descriptions)
4. **`locals.tf`** — computed local values and naming conventions
5. **`terraform.tfvars`** — current variable values for the environment
6. **`backend.tf`** — state backend configuration
7. **`modules/`** — scan module directories for purpose, inputs, outputs, and resources

### Step 2 — Update README.md

Check and update these sections:

| Section | What to check |
|---------|---------------|
| Architecture Overview | Matches current module and environment structure |
| Module table | All modules listed with purpose and key resources |
| Project Structure (tree) | File paths match actual structure |
| Configuration variables | All variables from `variables.tf` present with types and defaults |
| Deployment instructions | Commands reflect current backend and provider setup |
| Environment layout | `envs/` directories match reality |

### Step 3 — Update docs/ARCHITECTURE.md

Check and update these sections:

| Section | What to check |
|---------|---------------|
| Header metadata | Version number, Last Updated date |
| Module Design | All modules documented with inputs/outputs |
| Environment Layout | `envs/` structure and purpose of each environment |
| Provider Configuration | Provider versions, required_providers block |
| State Management | Backend type, locking mechanism |
| Validation | Tools used (fmt, validate, tflint, tfsec), what each checks |
| Variable Catalog | All variables with types, constraints, validation rules |

### Step 4 — Report changes

Summarize what was updated:

```
DOCUMENTATION REFRESH COMPLETE

README.md:
  - [list of changes, or "No changes needed"]

docs/ARCHITECTURE.md:
  - [list of changes, or "No changes needed"]
```

## Important Rules

- **Read before writing** — always read the current file content before making edits
- **Preserve structure** — update values within existing sections, don't reorganize
- **Accuracy over speed** — verify by reading source files, don't guess
- **No new sections** — only update existing content. If new sections are needed, note it in the report
- **Variable source of truth** — `variables.tf` (definitions) and `terraform.tfvars` (values) are authoritative for configuration
- **Module source of truth** — `modules/` directory structure and each module's `variables.tf`/`outputs.tf` are authoritative for module design
