# Revision Mode: Feature Re-Plan

Handles changes to an existing feature plan by selectively revising affected sections while preserving the rest. This reference contains the complete revision mode specification -- an executor reading only this file can run the full re-plan flow.

## Entry Condition (D-04)

Revision mode is entered when the target feature already has a plan file on disk. SKILL.md auto-detects this by checking whether `.project/{slug}/milestones/<NN>-<name>/plans/<feature-slug>.md` exists.

If the plan file does not exist, this is not re-plan mode -- use `references/gate-4-plan.md` for normal mode.

## Load Existing Plan (D-05)

Read the existing feature plan and related artifacts from disk:

1. **Read `.project/{slug}/milestones/<NN>-<name>/plans/<feature-slug>.md`** -- the existing feature plan with all 12 sections.
2. **Read `.project/{slug}/milestones/<NN>-<name>/README.md`** -- the current milestone definition with acceptance criteria.
3. **Read `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt`** -- the current feature status (pending, planned, in progress, complete).

All three files are required. If any is missing, report the error and stop.

## Diff-Focused Interview (D-05)

Ask "What changed?" to understand the nature of the re-plan. Do NOT discard and regenerate the entire plan. Understand the specific change before modifying anything.

Common change types:

- **Acceptance criteria changed** -- milestone revision updated the feature's acceptance criteria
- **Approach needs revision** -- implementation discovery revealed a better approach or the original approach is not feasible
- **Sub-feature sizing wrong** -- sub-features are too large or too small after closer analysis
- **New edge cases discovered** -- testing or review surfaced edge cases not in the original plan
- **Dependencies changed** -- a dependency was added, removed, or changed
- **Interface contracts need updating** -- existing codebase interfaces differ from what was planned

## Targeted Revision (D-05)

Revise ONLY affected sections using the Edit tool. Do NOT use the Write tool to replace the entire file.

Based on the change type:

- **If acceptance criteria changed:** Update the Acceptance Criteria section. May also affect Approach and Test Strategy.
- **If approach changed:** Update the Approach, Sub-Features, and Files to Create/Modify sections. May also affect Interface Contracts and Edge Cases.
- **If sub-features changed:** Update the Sub-Features section. Re-validate sizing per `references/gate-4-plan.md` Sub-Feature Sizing Validation. May also affect Files to Create/Modify.
- **If edge cases discovered:** Update the Edge Cases section. May also affect Test Strategy.
- **If dependencies changed:** Update the Dependencies section. May also affect Files to Create/Modify.
- **If interfaces changed:** Update the Interface Contracts section. May also affect Approach and Files to Create/Modify.

**Preserve unaffected sections exactly as they are.** The goal is minimal, targeted edits -- not a full rewrite.

## Review

Present the revised plan using the same whole-plan Approve/Revise pattern as normal mode (D-12):

1. **Present the revised plan** -- show the full contents of the updated plan file
2. **Highlight what changed** vs. what was preserved (e.g., "Updated: Approach, Sub-Features, Files to Create/Modify. Preserved: Summary, Acceptance Criteria, Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Dependencies, Architectural Deviations.")
3. **Present 1-2 tradeoff callouts** focused on the revision (D-13)
4. **Use `AskUserQuestion`** with options:
   - **Approve** -- revised plan is accepted
   - **Revise** -- ask what needs further changes, apply edits, re-present

5. **Generate a fresh `gate-4-<feature-slug>-review.md` checklist** using `references/review-checklist-template.md`. The prior review checklist is no longer valid after re-planning -- a new review must be conducted against the revised plan.

6. **Checklist validation** -- follow the same process as normal mode: Claude pre-checks programmatically verifiable items, presents remaining items to the user, all items must be `[x]` or `[-]` before re-approval.

## State File Updates

Update `milestone-status.txt` based on the feature's current status:

### If Feature Was Previously `[~] planned, awaiting build`

1. **Reset to `[ ]` pending** in `milestone-status.txt` -- the plan has changed, it needs re-approval:

   ```
   [ ] Feature 01.1: User Registration
       Plan: .project/{slug}/milestones/01-core-auth/plans/user-registration.md
   ```

2. **After re-approval:** Update back to `[~] planned, awaiting build`:

   ```
   [~] Feature 01.1: User Registration
       Plan: .project/{slug}/milestones/01-core-auth/plans/user-registration.md
       Sub-features: 0/3 complete
   ```

3. **If sub-feature count changed:** Update the `Sub-features: 0/N complete` line with the new count from the revised plan.

### If Feature Was Previously `[ ]` Pending

The feature was already pending -- no status reset needed. After re-plan approval, update to `[~] planned, awaiting build` with the new sub-feature count as in normal mode.

**CRITICAL: Do NOT write to progress.txt.** Re-plan is a feature-level event. Only `milestone-status.txt` is updated. Follow the exact format from `references/progress-format.md`.
