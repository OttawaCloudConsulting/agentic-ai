---
name: plan-feature
description: >
  Per-feature implementation plan with sub-feature sizing, interface contracts,
  and test commands. Supports re-plan mode for scope changes.
  Use when planning a feature, creating implementation plan, or re-planning.
  Phrases like "plan feature", "implementation plan", "re-plan feature",
  "create plan" are good triggers.
disable-model-invocation: true
---

# /plan-feature -- Feature Implementation Plan (Gate 4)

Produces per-feature implementation plans from an approved milestone definition,
PRD, and architecture document. Each invocation plans one feature. Supports
re-plan mode for already-planned features. Gate 4 approval updates the feature
entry in `milestone-status.txt` from `[ ]` to `[~] planned, awaiting build`.

## Rules

- **Read fresh every time.** Read `progress.txt` from disk on every invocation --
  never rely on conversation memory (STATE-03).
- **Produce-then-review at every plan.** Produce the full feature plan, present
  it, offer Approve / Revise (D-12).
- **All checklist items must be resolved.** Every review checklist item must be
  `[x]` or `[-]` (N/A with reason) before recording approval.
- **Write-ordering contract.** /plan-feature writes ONLY to `milestone-status.txt`. It
  does NOT write to `progress.txt`. This is a critical distinction from
  `/milestone`.
- **Interactive prompts.** Use `AskUserQuestion` for all user-facing choices
  (2-4 options, max 12-character headers).
- **No auto-dispatch.** Tell the user what to run next after completion. Never
  auto-invoke another skill.
- **Spike artifacts are user-referenced only.** Do not auto-detect or auto-scan
  `docs/spikes/`. Read spike docs only when the user explicitly references them
  (D-11).

## Prerequisites

- Working directory is the project root (where `progress.txt` lives).
- `progress.txt` must exist. If not, instruct user to run `/project` first.
- An active milestone must exist. Validate: at least one milestone directory
  exists under `.project/<slug>/milestones/` with a `milestone-status.txt` file. Do NOT check
  for `[x] Gate 3` -- Gate 3 stays `[~] In progress` and is never marked `[x]`
  until `/project` closes it.

## Step 1 -- Detect Mode and State

Read `progress.txt` from the project root. Parse `# Project-ID: <slug>` from the
header and construct the artifact base path: `.project/<slug>/`. If the header is
missing, report the error and tell the user to run `/project` first.

Prerequisite check: Verify an active milestone exists. If no milestone
directories exist under `.project/<slug>/milestones/`, inform user: "No milestones have been
defined. Run /milestone to create a milestone first." Do not proceed.

Auto-detect active milestone (D-02): Read `progress.txt`, find first milestone
at `[ ]` or `[~]` status. User can override with explicit milestone name/number.

Read that milestone's `milestone-status.txt`.

Mode detection -- 3 branches:

1. **Normal mode:** Target feature is at `[ ]` pending and has no plan file, OR
   user explicitly targets a pending feature --> proceed to Step 2.
2. **Re-plan mode (D-04):** Target feature already has a plan file on disk
   (auto-detected by checking `.project/<slug>/milestones/<NN>-<name>/plans/<feature-slug>.md`
   existence) --> proceed to Step 4.
3. **All features planned (D-03):** All features in the active milestone are at
   `[~]` planned or `[x]` complete. Report: "All features in milestone {NN}:
   {Name} are planned or complete. Run /project to check status." End session.

Auto-select next unplanned feature (D-01): Find first feature at `[ ]` pending
in milestone-status.txt. User can override with explicit feature name argument.

## Step 2 -- Load Inputs and Scan Codebase

Read `references/gate-4-plan.md` for the complete Gate 4 specification.

Follow the Input Loading and Codebase Scan Sub-Agent sections of the
gate-4-plan specification to:

1. Read all primary inputs (PLAN-01): milestone README, prd.md,
   `.project/<slug>/docs/ARCHITECTURE_AND_DESIGN.md`, progress.txt, milestone-status.txt.
2. Spawn sub-agent for targeted codebase scan (D-10): scan files relevant to
   the target feature (5-15 files, not architecture-wide).
3. If user referenced spike artifacts: read those specific files (D-11).

## Step 3 -- Generate and Review Plan

Follow the Plan Generation, Sub-Feature Sizing, Tradeoff Callouts, Review
Phase, Checklist Generation, Checklist Validation, and State File Updates
sections of `references/gate-4-plan.md` to:

1. Generate feature plan using `assets/feature-plan-template.md` (PLAN-03).
2. Validate sub-feature sizing (PLAN-04, D-06, D-07).
3. Present 1-2 tradeoff callouts (D-13).
4. Whole-plan Approve/Revise cycle (PLAN-07, PLAN-08, D-12).
5. Generate and validate review checklist using
   `references/review-checklist-template.md` (PLAN-05).
6. Update `milestone-status.txt` with plan path (PLAN-06) and Gate 4 approval
   status (PLAN-09).

Proceed to Step 5.

## Step 4 -- Re-plan Mode

Read `references/revision-mode.md` for the complete re-plan specification.

Follow the revision-mode specification to:

1. Load existing plan from disk (D-04).
2. Ask "What changed?" -- diff-focused interview (D-05).
3. Apply targeted revisions using Edit tool (D-05).
4. Present revised plan for whole-plan Approve/Revise (D-12).
5. Generate fresh review checklist.
6. Update `milestone-status.txt` (PLAN-06, PLAN-09).

Proceed to Step 5.

## Step 5 -- Completion Report

Display summary:

```
FEATURE PLANNED: [Feature NN.N: Name]  (or FEATURE RE-PLANNED)

ARTIFACTS CREATED:  (or ARTIFACTS UPDATED)
- .project/<slug>/milestones/<NN>-<name>/plans/<feature-slug>.md
- .project/<slug>/milestones/<NN>-<name>/reviews/gate-4-<feature-slug>-review.md

STATE UPDATED:
- milestone-status.txt (feature: [~] planned, awaiting build)

NEXT: Plan next feature, or run /project to check status.
```

For re-plan mode, also show:

```
SECTIONS REVISED: {list of changed sections}
SECTIONS PRESERVED: {count} unchanged
```

Then offer to plan the next unplanned feature (D-14): "Next unplanned feature:
{Y}. Plan it now?" If user accepts, return to Step 1 with the next feature. If
user declines or no unplanned features remain, end session.

## Error Handling

- **Missing progress.txt:** Do not proceed. Tell user to run `/project` first.
- **No active milestone:** Do not proceed. Tell user to run `/milestone` first.
- **Missing milestone README:** Report inconsistency -- milestone directory
  exists but README is missing. Suggest running `/project` to check state.
- **Missing ARCHITECTURE_AND_DESIGN.md:** Report inconsistency -- Gate 2 should
  be approved but architecture doc is missing. Suggest running `/project` to
  check state.
- **Feature not found:** If user specifies a feature name that doesn't exist in
  milestone-status.txt, report available features and ask to select one.
- **Interrupted session:** User can re-invoke `/plan-feature`. Skill re-reads
  `progress.txt` and `milestone-status.txt` to detect correct mode and resume
  from appropriate state.
