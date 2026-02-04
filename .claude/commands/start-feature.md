---
name: start-feature
description: Start working on the next feature. Only invoke when the user explicitly asks to start a new feature or says to begin the next feature. Never invoke proactively.
---

# /start-feature — Begin Next Feature

Start work on the next feature in the project roadmap.

## Execution Steps

### Step 1 — Read progress.txt

Read `progress.txt` and identify:
- Any feature currently marked `[~]` (in progress) — if found, resume that feature
- The next feature marked `[ ]` (pending) — if no `[~]` exists

If all features are marked `[x]`, report that all planned features are complete and stop.

### Step 2 — Read requirements

Read `prd.md` and locate the section for the identified feature. Extract:
- What needs to be built
- Acceptance criteria
- Any dependencies on other features

### Step 3 — Mark feature as in progress

Update `progress.txt`:
- Change the feature status from `[ ]` to `[~]`
- Add start date to NOTES (format: `Started YYYY-MM-DD`)

### Step 4 — Report

Present a summary to the user:

```
STARTING: Feature X.Y — [Title from progress.txt]

REQUIREMENTS:
- [Key requirement 1]
- [Key requirement 2]
- [...]

FILES LIKELY AFFECTED:
- [Based on requirements and existing codebase structure]

DEPENDENCIES:
- [Any cross-stack or cross-feature dependencies]

Ready to begin implementation.
```

## Important Rules

- **Never skip reading progress.txt** — it is the source of truth for what to work on
- **Never start a feature if another is `[~]`** — one feature at a time
- **Do not begin implementation** — this skill only sets up context. Wait for user direction after reporting.
- **Follow prd.md exactly** — architecture decisions are defined there, not improvised
