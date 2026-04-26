---
name: project-plan-feature
description: Explicit Project feature planning phase. Produces or revises one Gate 4 feature implementation plan and updates only milestone-status.txt. Use only when the user explicitly invokes $project-plan-feature.
---

# Project Plan Feature

Use this skill only when explicitly invoked as `$project-plan-feature`. It owns
Gate 4 planning for one feature at a time and updates only the corresponding
`milestone-status.txt`.

## Core Rules

- Read `progress.txt` and the active `milestone-status.txt` fresh from disk.
- Require at least one milestone directory with `milestone-status.txt`.
- Write only `milestone-status.txt`; do not update `progress.txt`.
- Produce the feature plan, present it for review, and record approval only after
  checklist items are `[x]` or `[-]` with a reason.
- Read spike docs only when the user explicitly references them.
- Ask concise chat questions for user choices; use structured input tools when
  available.
- Do not invoke the next skill automatically. Recommend the next explicit skill.
- Read the referenced workflow files before executing their corresponding steps;
  they contain required edge-case handling, review criteria, and artifact formats.

## Workflow

1. Auto-detect the active milestone from `progress.txt` or use the user's explicit
   milestone override.
2. Read the milestone status file and choose the first pending feature, unless
   the user names another feature.
3. Normal mode: read `references/gate-4-plan.md`, load required inputs, perform a
   targeted codebase scan, and create
   `milestones/<NN>-<name>/plans/<feature>.md` using
   `assets/feature-plan-template.md`.
4. Re-plan mode: read `references/revision-mode.md`, load the existing plan, ask
   what changed, and apply focused revisions.
5. Create/update the Gate 4 review file using
   `references/review-checklist-template.md`.
6. Update the feature entry in `milestone-status.txt` to `[~] planned, awaiting
   build` with the plan path.

## Reference Files

- `references/gate-4-plan.md`
- `references/revision-mode.md`
- `references/progress-format.md`
- `references/review-checklist-template.md`
- `assets/feature-plan-template.md`

## Completion

Report created/updated artifacts and recommend `$project-build` for a planned
feature or `$project-plan-feature` for the next pending feature.
