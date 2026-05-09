---
name: milestone
description: >
  Milestone breakdown from approved PRD and architecture doc. Supports
  defining milestones one at a time and revision mode for scope changes.
  Use when planning milestones, breaking work into milestones, or revising
  an existing milestone. Phrases like "define milestones", "milestone
  planning", "break into milestones", "revise milestone" are good triggers.
disable-model-invocation: true
---

# /milestone -- Milestone Planning (Gate 3)

Breaks an approved PRD and architecture document into milestone-scoped feature
breakdowns with acceptance criteria, ordering, and sizing. Each invocation
defines one milestone. Supports revision mode for scope changes to existing
milestones. Gate 3 stays `[~] In progress` across invocations -- closure is
handled by `/project`.

## Rules

- **Read fresh every time.** Read `progress.txt` from disk on every invocation --
  never rely on conversation memory (STATE-03).
- **Produce-then-review at every milestone.** Produce the full milestone README,
  present it, offer Approve / Revise / Partial (D-01).
- **All checklist items must be resolved.** Every review checklist item must be
  `[x]` or `[-]` (N/A with reason) before recording approval.
- **Write-ordering contract.** When updating state files: write
  `milestone-status.txt` first, then `progress.txt` (STATE-04).
- **Interactive prompts.** Use `AskUserQuestion` for all user-facing choices
  (2-4 options, max 12-character headers).
- **No auto-dispatch.** Tell the user what to run next after completion. Never
  auto-invoke another skill.
- **Gate 3 stays open.** /milestone NEVER writes `[x]` to Gate 3 in
  `progress.txt` -- only `[~] In progress`. Gate 3 closure is `/project`'s
  responsibility (D-05).

## Prerequisites

- Working directory is the project root (where `progress.txt` lives).
- `progress.txt` must exist. If it does not, instruct the user to run `/project`
  first to bootstrap project state.
- Gate 2 must be `[x]` approved in `progress.txt` (MIL-01).

## Step 1 -- Detect Mode and State

Read `progress.txt` from the project root. Parse `# Project-ID: <slug>` from the
header and construct the artifact base path: `.project/<slug>/`. If the header is
missing, report the error and tell the user to run `/project` first to bootstrap
a Project-ID.

**Prerequisite check (MIL-01):**
If Gate 2 is not `[x]` approved in `progress.txt`, inform the user:
"Gate 2 (Design Review) must be approved before milestone planning. Run /design
to complete the architecture document first."
Do not proceed. End the session.

Read the `prd.md` Milestones section.

**Mode detection -- 4 branches:**

1. **First invocation:** `prd.md` Milestones section is `(to be defined)` AND no
   `.project/<slug>/milestones/` directories exist --> proceed to Step 2.
2. **Subsequent invocation:** `prd.md` Milestones section is populated AND some
   milestones lack directories under `.project/<slug>/milestones/` --> proceed to Step 3.
3. **Revision mode:** Target milestone directory already exists under
   `.project/<slug>/milestones/` (D-10) --> proceed to Step 5. If the user specified
   a milestone number or name, use that. Otherwise use `AskUserQuestion` to ask
   which milestone to revise.
4. **All milestones defined:** `prd.md` Milestones section is populated AND all
   milestones have directories under `.project/<slug>/milestones/` --> inform the
   user all milestones are defined. Suggest running `/project` to check gate status
   or specify a milestone number for revision.

## Step 2 -- First Invocation: Propose Milestone Plan

Read `references/gate-3-milestone.md` for the complete Gate 3 specification.

Follow the "First Invocation" section of the gate-3-milestone specification to:

1. Read `prd.md` and `.project/<slug>/docs/ARCHITECTURE_AND_DESIGN.md` (MIL-02).
2. Propose full milestone plan with summaries and ordering (D-07, D-01).
3. Present tradeoff callouts (D-03).
4. Approve/Revise cycle.
5. Persist approved plan in `prd.md` Milestones section (D-08).
6. Define milestone #1 (Step 4) or allow user to defer.

## Step 3 -- Subsequent Invocation: Select Milestone

Read `references/gate-3-milestone.md` for the complete Gate 3 specification.

Follow the "Subsequent Invocation" section to:

1. Auto-select next undefined milestone (D-09).
2. User can override to target a specific milestone.
3. Proceed to Step 4 (Define Milestone).

## Step 4 -- Define and Review Milestone

Follow the "Define Individual Milestone" and "Review Phase" sections of
gate-3-milestone.md to:

1. Generate `README.md`, `milestone-status.txt`, `gate-3-review.md`
   (MIL-03, MIL-04, MIL-05, MIL-06).
2. Update `progress.txt` -- write `milestone-status.txt` first, then
   `progress.txt` (STATE-04, MIL-07, MIL-09).
3. Present for review (MIL-08).
4. Validate checklist (MIL-06).

Proceed to Step 6.

## Step 5 -- Revision Mode

Read `references/revision-mode.md` for the complete revision mode specification.

Follow the revision-mode specification to:

1. Load existing milestone artifacts (MIL-10).
2. Present feature checklist for impact assessment (MIL-11, D-11).
3. Preserve completed features (MIL-12).
4. Apply focused revision (D-12).
5. Update `milestone-status.txt`, `progress.txt`, `prd.md` -- write
   `milestone-status.txt` first (STATE-04, MIL-13).
6. Generate fresh `gate-3-review.md` (D-13).

Proceed to Step 6.

## Step 6 -- Completion Report

Display summary:

```
MILESTONE DEFINED: [Milestone NN: Name]  (or MILESTONE REVISED)

ARTIFACTS CREATED:  (or ARTIFACTS UPDATED)
- .project/<slug>/milestones/<NN>-<name>/README.md
- .project/<slug>/milestones/<NN>-<name>/milestone-status.txt
- .project/<slug>/milestones/<NN>-<name>/reviews/gate-3-review.md

STATE UPDATED:
- progress.txt (Gate 3: [~] In progress, milestone summary line)
- prd.md (Milestones section)

NEXT: Run /milestone for the next milestone, or /project to check gate status.
```

For revision mode, also show:

```
FEATURES AFFECTED: N reset to pending
FEATURES PRESERVED: M unchanged
```

## Error Handling

- **Missing progress.txt:** Do not proceed. Tell the user to run `/project`
  first to bootstrap project state.
- **Gate 2 not approved:** Do not proceed. Tell the user to run `/design` first
  (MIL-01).
- **Missing prd.md:** Report inconsistency -- Gate 2 is marked approved but
  `prd.md` is missing. Suggest running `/project` to check state.
- **Missing ARCHITECTURE_AND_DESIGN.md:** Report inconsistency -- Gate 2 is
  marked approved but architecture doc is missing. Suggest running `/project` to
  check state.
- **Interrupted session:** User can re-invoke `/milestone`. Skill re-reads
  `progress.txt` and `prd.md` to detect correct mode and resume from appropriate
  state.
