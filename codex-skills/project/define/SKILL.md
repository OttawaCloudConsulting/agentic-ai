---
name: project-define
description: Explicit Project definition phase. Runs Codebase Alignment, optional Working Backwards, and Scope Review gates while producing docs/codebase-assessment.md, docs/working-backwards.md, and prd.md. Use only when the user explicitly invokes $project-define.
---

# Project Define

Use this skill only when explicitly invoked as `$project-define`. It owns Gates
0, WB, and 1, producing the codebase assessment, optional Working Backwards
artifact, and PRD in one continuous session.

## Core Rules

- Read `progress.txt` fresh from disk before acting.
- Require a bootstrapped project. If `progress.txt` is missing, tell the user to
  run `$project` first.
- Produce each gate artifact, present it for review, and record approval only
  after all checklist items are `[x]` or `[-]` with a reason.
- Ask concise chat questions for user choices; use structured input tools when
  available.
- Use Codex filesystem editing tools for artifacts and `progress.txt`.
- Use Codex sub-agents only when available and appropriate; otherwise perform the
  scan locally.
- Do not invoke the next skill automatically. Recommend the next explicit skill.
- Read the referenced workflow files before executing their corresponding steps;
  they contain required edge-case handling, review criteria, and artifact formats.

## Workflow

1. Detect mode from `progress.txt`, `prd.md`, and the user request. Revision mode
   applies when Gate 1 is approved and the user asks to revise/update the PRD.
2. For brownfield projects, read `references/gate-0-codebase.md` and produce
   `docs/codebase-assessment.md`. For greenfield projects, record Gate 0 as
   skipped using the compatible notation.
3. Read `references/gate-wb-working-backwards.md` and offer Working Backwards.
   Gate WB can be approved, skipped, or deferred; deferred state does not block
   Gate 1.
4. Read `references/gate-1-prd.md` and create or revise `prd.md` using
   `assets/prd-template.md`.
5. Create/update review files under `docs/reviews/` using
   `references/review-checklist-template.md`.
6. Update `progress.txt` using `references/progress-format.md`.

## Reference Files

- `references/gate-0-codebase.md`
- `references/gate-wb-working-backwards.md`
- `references/gate-1-prd.md`
- `references/progress-format.md`
- `references/review-checklist-template.md`
- `assets/prd-template.md`

## Completion

Report created/updated artifacts and recommend `$project` for status, then
`$project-design` when Gate 1 is approved.
