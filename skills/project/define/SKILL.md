---
name: define
description: >
  Codebase assessment, optional Working Backwards, and PRD creation in a single
  session. Runs Gates 0, WB, and 1 continuously. Use when starting project
  definition, creating a PRD, assessing an existing codebase, or running the
  Working Backwards exercise. Phrases like "define the project", "create PRD",
  "assess codebase", "working backwards" are good triggers.
disable-model-invocation: true
---

# /define -- Project Definition (Gates 0, WB, 1)

Single-session skill that produces codebase assessment (Gate 0), optional Working
Backwards document (Gate WB), and an approved PRD (Gate 1). All three gates run as
one continuous conversation -- the user does not leave between gates.

## Rules

- **Read fresh every time.** Read `progress.txt` from disk on every invocation --
  never rely on conversation memory or cached values (STATE-03).
- **Single continuous session.** Gates 0, WB, and 1 run in one conversation. The
  user does not leave between gates (DEF-14).
- **Produce-then-review at every gate.** Produce the full artifact, present it,
  offer Approve / Revise. Rejection = revision request (D-06, D-08).
- **All checklist items must be resolved.** Every review checklist item must be
  `[x]` or `[-]` (N/A with reason) before recording gate approval (DEF-06, D-07).
- **Write-ordering contract.** When writing to state files, follow STATE-04
  ordering. For `/define`, only `progress.txt` is modified (gate entries).
- **Interactive prompts.** Use `AskUserQuestion` for all user-facing choices
  (2-4 options, max 12-character headers).
- **No auto-dispatch.** Tell the user what to run next after completion. Never
  auto-invoke another skill.

## Prerequisites

- Working directory is the project root (where `progress.txt` lives or will be
  created by `/project`).
- `progress.txt` must exist. If it does not, instruct the user to run `/project`
  first to bootstrap project state.
- Gate 0 must not already be approved (unless this is a revision mode invocation).

## Step 1 -- Detect Mode and State

Read `progress.txt` from the project root.

**Revision mode detection (DEF-15):**
Check ALL of the following:
- `prd.md` exists on disk
- Gate 1 is already `[x]` approved in `progress.txt`
- The user's message signals revision intent (keywords: "revise", "update PRD",
  "goals changed", "pivot", "change direction", "scope change")

If ALL true: jump to Step 6 (Revision Mode).

**Greenfield detection (DEF-01, D-11):**
Check ALL of the following (all must be true to classify as greenfield):
- No `src/`, `app/`, or `lib/` directories exist
- No dependency manifests exist (`package.json`, `pyproject.toml`, `Cargo.toml`,
  `go.mod`, `requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`)
- Fewer than 5 non-config files
- Only boilerplate files (README, license, gitignore pattern)

If ALL true: record Gate 0 as `[-] Gate 0: Codebase Alignment  Skipped (greenfield)`
in `progress.txt`. Skip to Step 4 (Gate WB Offer).
If ANY false: proceed to Step 2 (Gate 0).

**Gate WB resume detection:**
- If Gate WB is `[ ] Pending` in `progress.txt` (from a previous session where the
  user deferred): proceed to Step 4 (Gate WB Offer) with re-prompt context.
- If Gate 0 is not yet started `[ ]`: proceed to Step 2 (Gate 0).

**Already-approved detection:**
- If Gate 0 is `[x]` and Gate WB is `[x]` or `[-]` or `[ ] Pending`: proceed to
  Step 5 (Gate 1) or Step 4 if Gate WB is Pending.
- If Gate 1 is `[x]` and no revision intent: inform the user that Gate 1 is already
  complete. Ask if they want to revise (enters revision mode) or check status
  (run `/project`).

## Step 2 -- Gate 0: Codebase Assessment

Read `references/gate-0-codebase.md` for the complete Gate 0 specification.

Follow the gate-0-codebase specification to:
1. Spawn a sub-agent to scan the codebase (20-40 files).
2. Synthesize findings into `docs/codebase-assessment.md`.
3. Present findings and enter produce-then-review cycle.
4. Generate review checklist (`docs/reviews/gate-0-review.md`) using
   `references/review-checklist-template.md`.
5. Validate checklist completeness before recording approval.
6. Record Gate 0 approval in `progress.txt` per `references/progress-format.md`.

Proceed to Step 3.

## Step 3 -- Gate 0 Transition

Gate 0 is complete. Proceed to Step 4 (Gate WB Offer).

## Step 4 -- Gate WB: Working Backwards (Optional)

Read `references/gate-wb-working-backwards.md` for the complete Gate WB specification.

Check current Gate WB state in `progress.txt`:
- If already `[x]` or `[-]`: skip to Step 5 (Gate 1).
- If `[ ] Pending`: re-prompt the user for their decision.
- If `[ ]` (not yet offered): offer Gate WB per the specification.

Follow the gate-wb specification to handle the 3-outcome offer:
- **Yes**: run WB interview, produce `docs/working-backwards.md`, review cycle,
  record approval.
- **Skip**: record `[-] Gate WB: Working Backwards  Skipped` in `progress.txt`.
  Proceed to Step 5.
- **Defer**: record `[ ] Gate WB: Working Backwards  Pending -- offered, awaiting
  decision` in `progress.txt`. Proceed to Step 5.

Gate WB Pending does NOT block Gate 1. The Pending state is tracked for `/project`
to remind the user later (D-09 overrides PROJ-07).

Proceed to Step 5.

## Step 5 -- Gate 1: Scope Review

Read `references/gate-1-prd.md` for the complete Gate 1 specification.

Follow the gate-1 specification to:
1. Silently re-read `docs/codebase-assessment.md` from disk for context (DEF-16).
   Do NOT recap or summarize it to the user -- use internally only.
2. Read `docs/working-backwards.md` if it exists (D-14 -- context only, does not
   auto-populate PRD sections).
3. Gather the initial project concept (seed the PRD).
4. Conduct the 5-round interview (Scope, Inputs/Outputs, Security, Operational,
   Milestone Scoping). One round at a time via `AskUserQuestion`.
5. Produce `prd.md` using `assets/prd-template.md`.
6. Present PRD for review (produce-then-review cycle: Approve / Revise /
   Partial Approve).
7. Handle partial approval if needed (DEF-12 -- section checklist for focused
   revision of unchecked sections).
8. Generate review checklist (`docs/reviews/gate-1-review.md`) using
   `references/review-checklist-template.md`.
9. Validate checklist completeness.
10. Record Gate 1 approval in `progress.txt`.

Proceed to Step 7 (Completion Report).

## Step 6 -- Revision Mode

Read `references/gate-1-prd.md` for the revision mode specification.
Read existing `prd.md` from disk.
Re-read `docs/codebase-assessment.md` from disk if it exists (DEF-16 silent
re-read -- no recap to user).

Follow the revision mode specification to:
1. Ask "What changed?" -- focused interview on affected sections only.
2. Revise `prd.md` with edits. Show each change before and after.
3. Present for review (produce-then-review cycle).
4. Generate or update review checklist (`docs/reviews/gate-1-review.md`).
5. Surface downstream artifact impacts without auto-resetting (DD-6). List
   affected artifacts and ask the user which need re-review.
6. Record Gate 1 re-approval with updated date in `progress.txt`.

Proceed to Step 7.

## Step 7 -- Completion Report

Display a summary of what was produced:

```
DEFINITION COMPLETE: [Project Title]

ARTIFACTS CREATED:
- docs/codebase-assessment.md (Gate 0) [or "Skipped (greenfield)"]
- docs/working-backwards.md (Gate WB) [or "Skipped" / "Pending"]
- prd.md (Gate 1)

REVIEW CHECKLISTS:
- docs/reviews/gate-0-review.md [if applicable]
- docs/reviews/gate-wb-review.md [if applicable]
- docs/reviews/gate-1-review.md

NEXT: Run /project to see updated status, then /design for Gate 2.
```

## Error Handling

- **Missing progress.txt:** Do not proceed. Tell the user to run `/project` first
  to bootstrap project state.
- **Gate 0 already approved:** Skip Gate 0 (it was already done in a previous
  session). Proceed from the appropriate gate based on `progress.txt` state.
- **Gate 1 already approved without revision intent:** Inform the user that Gate 1
  is already complete. Use `AskUserQuestion` with options: **Revise** (enters
  revision mode) or **Status** (suggests running `/project`).
- **Interrupted session:** If the conversation is interrupted mid-gate, the user
  can re-invoke `/define`. The skill re-reads `progress.txt` and resumes from the
  appropriate gate based on which gates are already approved.
- **Agent scan failure:** If the codebase scan agent fails or returns empty results,
  report the failure to the user and offer to proceed with a manual assessment (user
  describes the codebase) or retry.
