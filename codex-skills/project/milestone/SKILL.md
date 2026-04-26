---
name: project-milestone
description: Explicit Project milestone phase. Defines one milestone at a time from an approved PRD and architecture document, updates milestone artifacts, and keeps Gate 3 in progress. Use only when the user explicitly invokes $project-milestone.
---

# Project Milestone

Use this skill only when explicitly invoked as `$project-milestone`. It owns Gate
3 planning and milestone revision, but never closes Gate 3; `$project` handles
closure when all milestones are complete.

## Core Rules

- Read `progress.txt` fresh from disk before acting.
- Require Gate 2 `[x]` approval. If missing, tell the user to run
  `$project-design`.
- Produce the milestone README/status files, present them for review, and record
  approval only after checklist items are `[x]` or `[-]` with a reason.
- When both state files change, write `milestone-status.txt` first and
  `progress.txt` second.
- Ask concise chat questions for user choices; use structured input tools when
  available.
- Do not invoke the next skill automatically. Recommend the next explicit skill.
- Read the referenced workflow files before executing their corresponding steps;
  they contain required edge-case handling, review criteria, and artifact formats.

## Workflow

1. Detect first invocation, subsequent invocation, revision mode, or all
   milestones-defined state from `prd.md`, `progress.txt`, and `milestones/`.
2. Read `references/gate-3-milestone.md`.
3. On first invocation, propose the full milestone sequence and write the
   approved sequence into the PRD Milestones section.
4. Define one milestone using `assets/milestone-readme-template.md`, creating:
   `milestones/<NN>-<name>/README.md`,
   `milestones/<NN>-<name>/milestone-status.txt`, and a Gate 3 review file.
5. In revision mode, read `references/revision-mode.md`, preserve completed
   features, and update affected milestone artifacts.
6. Update `progress.txt` with Gate 3 `[~] In progress` and the milestone summary
   line, using `references/progress-format.md`.

## Reference Files

- `references/gate-3-milestone.md`
- `references/revision-mode.md`
- `references/progress-format.md`
- `references/review-checklist-template.md`
- `assets/milestone-readme-template.md`

## Completion

Report created/updated artifacts and recommend `$project-plan-feature` for the
next unplanned feature or `$project` for status.
