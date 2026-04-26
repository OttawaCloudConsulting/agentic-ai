---
name: project-design
description: Explicit Project design phase. Produces or refreshes docs/ARCHITECTURE_AND_DESIGN.md from an approved PRD and records Gate 2. Use only when the user explicitly invokes $project-design.
---

# Project Design

Use this skill only when explicitly invoked as `$project-design`. It owns Gate 2
and refresh mode for consolidating implementation deviations into the architecture
document.

## Core Rules

- Read `progress.txt` fresh from disk before acting.
- Require Gate 1 `[x]` approval. If missing, tell the user to run
  `$project-define`.
- Produce the design artifact, present it for review, and record approval only
  after all checklist items are `[x]` or `[-]` with a reason.
- Ask concise chat questions for user choices; use structured input tools when
  available.
- Use Codex filesystem editing tools. Preserve existing architecture docs by
  integrating unless the user approves overwrite.
- Do not invoke the next skill automatically. Recommend the next explicit skill.
- Read the referenced workflow files before executing their corresponding steps;
  they contain required edge-case handling, review criteria, and artifact formats.

## Workflow

1. Detect normal vs. refresh mode. Refresh mode applies when Gate 2 is already
   approved and `docs/ARCHITECTURE_AND_DESIGN.md` exists, or the user asks to
   refresh/update architecture.
2. Normal mode: read `references/gate-2-design.md`, load `prd.md` and available
   context, then produce `docs/ARCHITECTURE_AND_DESIGN.md` using
   `assets/architecture-template.md`.
3. Refresh mode: read `references/refresh-mode.md`, scan feature plans for
   Architectural Deviations, ask which to consolidate, and update the design doc.
4. Create/update `docs/reviews/gate-2-review.md` using
   `references/review-checklist-template.md`.
5. Update Gate 2 in `progress.txt` using `references/progress-format.md`.

## Reference Files

- `references/gate-2-design.md`
- `references/refresh-mode.md`
- `references/progress-format.md`
- `references/review-checklist-template.md`
- `assets/architecture-template.md`

## Completion

Report created/updated artifacts and recommend `$project` for status, then
`$project-milestone` when Gate 2 is approved.
