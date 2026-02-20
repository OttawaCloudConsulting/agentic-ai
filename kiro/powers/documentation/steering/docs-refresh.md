# Documentation Refresh Workflow

Synchronize README.md and docs/ARCHITECTURE.md with the current state of the codebase. These files contain counts, tables, and summaries that drift as features are added.

## Step 1 — Gather Current State

Read these sources to understand what is current:

1. **`progress.txt`** — which features are complete
2. **`CHANGELOG.md`** — recent feature entries
3. **Project source files** — scan for components, modules, configuration, and structure

## Step 2 — Update README.md

Check and update these sections:

| Section | What to check |
|---------|---------------|
| Architecture Overview | Matches current component structure |
| Project Structure (tree) | File paths match actual structure |
| Configuration | Parameters/settings present with correct defaults |
| Setup / Installation | Prerequisites and steps are current |
| Usage | Commands and examples reflect current behavior |
| Tech Stack | Version numbers current |

## Step 3 — Update docs/ARCHITECTURE.md

Check and update these sections:

| Section | What to check |
|---------|---------------|
| Header metadata | Version number, Last Updated date |
| Component Design | All components documented |
| Configuration | Parameter tables match source of truth |
| Data Flow / Request Flow | Diagrams and descriptions current |
| Dependencies | External dependencies listed and accurate |

## Step 4 — Report Changes

Summarize what was updated:

```text
DOCUMENTATION REFRESH COMPLETE

README.md:
  - [list of changes, or "No changes needed"]

docs/ARCHITECTURE.md:
  - [list of changes, or "No changes needed"]
```

## Rules

- **Read before writing** — always read the current file content before making edits
- **Preserve structure** — update values within existing sections, do not reorganize
- **Accuracy over speed** — verify by reading source files, do not guess
- **No new sections** — only update existing content. If new sections are needed, note it in the report
