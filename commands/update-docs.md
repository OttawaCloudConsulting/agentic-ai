---
name: update-docs
description: Refresh project documentation (README, ARCHITECTURE) to match current codebase state. Use after multiple features have been completed, before creating a PR, or when documentation feels stale.
disable-model-invocation: true
---

# /update-docs — Refresh Project Documentation

Synchronize README.md and docs/ARCHITECTURE.md with the current state of the codebase. These files contain counts, tables, and summaries that drift as features are added.

Not for use in CDK or Terraform projects — use `/update-docs-cdk` or `/update-docs-terraform` instead.

## Execution Steps

### Step 1 — Gather current state

Read these sources to understand what's current:

1. **`progress.txt`** — which features are complete
2. **`CHANGELOG.md`** — recent feature entries
3. **Project source files** — scan for components, modules, configuration, and structure

### Step 2 — Update README.md

Check and update these sections:

| Section | What to check |
|---------|---------------|
| Architecture Overview | Matches current component structure |
| Project Structure (tree) | File paths match actual structure |
| Configuration | Parameters/settings present with correct defaults |
| Setup / Installation | Prerequisites and steps are current |
| Usage | Commands and examples reflect current behavior |
| Tech Stack | Version numbers current |

### Step 3 — Update docs/ARCHITECTURE.md

Check and update these sections:

| Section | What to check |
|---------|---------------|
| Header metadata | Version number, Last Updated date |
| Component Design | All components documented |
| Configuration | Parameter tables match source of truth |
| Data Flow / Request Flow | Diagrams and descriptions current |
| Dependencies | External dependencies listed and accurate |

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
