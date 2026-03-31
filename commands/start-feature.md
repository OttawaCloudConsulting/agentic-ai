---
name: start-feature
description: Start working on the next feature. Only invoke when the user explicitly asks to start a new feature or says to begin the next feature. Never invoke proactively.
---

# /start-feature — Begin Next Feature

Start work on the next feature in the project roadmap.

## Execution Steps

### Step 1 — Read progress.txt

If `progress.txt` does not exist, stop and tell the user to run `/create-prd` first.

Read `progress.txt` and identify:

- Any feature currently marked `[~]` (in progress) — if found, resume that feature
- The next feature marked `[ ]` (pending) — if no `[~]` exists

If all features are marked `[x]`, report that all planned features are complete and stop.

**Resuming a `[~]` feature:** Read the NOTES field for the feature. Surface any recorded start
date, code-complete status, or open questions from NOTES in the Step 4 report. Skip marking the
feature `[~]` in Step 3 (it is already marked).

### Step 2 — Read requirements

If `prd.md` does not exist, stop and tell the user to run `/create-prd` first.

Read `prd.md` and locate the section for the identified feature. Then read
`docs/ARCHITECTURE_AND_DESIGN.md` if it exists, and extract any Design Decisions, Component
Inventory entries, File Organization details, and Deployment Workflow steps relevant to this
feature.

Extract from both documents:

- What needs to be built
- Acceptance criteria
- Any dependencies on other features
- Relevant design decisions and component details

### Step 3 — Scan the codebase

Use Glob and Grep to identify files likely to be created or modified for this feature. Base the
search on component names, file paths, and naming patterns from `docs/ARCHITECTURE_AND_DESIGN.md`
(File Organization section) and the feature's acceptance criteria.

For greenfield features where no matching files exist yet, list the files that will be created
based on the architecture doc's File Organization section.

### Step 4 — Mark feature as in progress

Skip this step if resuming a `[~]` feature.

Update `progress.txt`:

- Change the feature status from `[ ]` to `[~]`
- Add start date to NOTES (format: `Started YYYY-MM-DD`)

### Step 5 — Report

Present a summary to the user:

```
STARTING: Feature X.Y — [Title from progress.txt]
[If resuming: "RESUMING — started YYYY-MM-DD. [Summary of NOTES content.]"]

REQUIREMENTS:
- [Key requirement 1]
- [Key requirement 2]
- [...]

KEY DESIGN DECISIONS:
- [Relevant decisions from docs/ARCHITECTURE_AND_DESIGN.md]

FILES LIKELY AFFECTED:
- [Observed via codebase scan — files found or files to be created]

DEPENDENCIES:
- [Any cross-stack or cross-feature dependencies]

Ready to begin implementation.
```

## Important Rules

- **Never skip reading progress.txt** — it is the source of truth for what to work on
- **Never start a feature if another is `[~]`** — one feature at a time
- **Do not begin implementation** — this skill only sets up context. Wait for user direction after reporting.
- **Follow `docs/ARCHITECTURE_AND_DESIGN.md` for design decisions** — it is the authoritative spec; `prd.md` defines requirements and acceptance criteria
