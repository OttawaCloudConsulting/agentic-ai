# Gate 4: Feature Implementation Plan

Produces per-feature implementation plans from an approved milestone definition and architecture document. This reference contains the complete Gate 4 specification for normal mode -- an executor reading only this file can run the full Gate 4 flow.

## Input Loading (PLAN-01)

Read the primary inputs from disk:

1. **Read `progress.txt`** from the project root. This is required -- if it does not exist, report the error and stop. Used to validate that an active milestone exists.
2. **Read milestone `README.md`** at `milestones/<NN>-<name>/README.md`. This is required -- primary source of feature details, acceptance criteria, and milestone context.
3. **Read `milestones/<NN>-<name>/milestone-status.txt`**. This is required -- provides current feature statuses (pending, planned, in progress, complete).
4. **Read `prd.md`** from the project root. This is required -- provides project context, goals, non-goals, and scope.
5. **Read `docs/ARCHITECTURE_AND_DESIGN.md`** from the project root. This is required -- provides architecture constraints, component inventory, data flow, and design decisions.

All five files are primary inputs. The milestone README provides feature descriptions and acceptance criteria. The PRD provides project-level context. The architecture document provides technical constraints and patterns. The progress and milestone-status files provide current state.

**Spike artifacts (D-11):** Do not auto-detect or auto-scan `docs/spikes/`. Read spike docs ONLY when the user explicitly references them (e.g., "see the websocket auth spike"). Spike artifacts are user-referenced only.

## Milestone and Feature Detection (PLAN-02, D-01, D-02, D-03)

Three possible outcomes from state detection:

### Auto-Detect Active Milestone (D-02)

Read `progress.txt` and find the first milestone at `[ ]` (pending) or `[~]` (in progress) status. This is the active milestone.

**User override:** The user can target a specific milestone by saying "plan a feature in milestone 3" or similar. Honor the override if the target milestone directory exists on disk with a `milestone-status.txt`.

**Important:** Do NOT check for `[x] Gate 3` in progress.txt. Gate 3 stays `[~] In progress` -- it is never `[x]` until `/project` closes it. Validate that an active milestone exists (milestone directory exists with `milestone-status.txt`), not that Gate 3 is approved.

### Auto-Select Next Unplanned Feature (D-01)

Read the active milestone's `milestone-status.txt` and find the first feature at `[ ]` pending status. This is the next feature to plan.

Also accept features needing re-plan: features whose plan file exists but the user explicitly requests re-plan. These are routed to `references/revision-mode.md`, not this file.

**User override:** The user can target a specific feature by name (e.g., "plan the Password Reset feature"). Honor the override if the feature exists in the milestone's `milestone-status.txt`.

### No Plannable Features (D-03)

When all features in the active milestone are `[~]` planned or `[x]` complete (no `[ ]` pending features remain), report:

> "All features in milestone {NN}: {Name} are planned or complete. Run /project to check status."

End the session. Do not proceed to plan generation.

## Codebase Scan Sub-Agent (D-10)

Spawn a sub-agent to scan files relevant to the feature being planned. This is a targeted, feature-scoped scan -- narrower than `/design`'s 15-30 file architecture scan.

**Sub-agent instructions:**

1. Read the feature's acceptance criteria from the milestone README
2. Identify files the feature will likely touch (by name patterns, directory structure, imports)
3. Read 5-15 files relevant to this specific feature (NOT architecture-wide)
4. Return:
   - File inventory (paths and brief descriptions)
   - Relevant code patterns found
   - Existing interfaces the feature will interact with
   - Integration points with other features or modules

The sub-agent results inform the Approach, Files to Create/Modify, Interface Contracts, and Edge Cases sections of the feature plan.

## Plan Generation (PLAN-03)

Generate the feature plan file at `milestones/<NN>-<name>/plans/<feature-slug>.md` using `assets/feature-plan-template.md`.

**Feature slug:** Kebab-case derived from the feature name. Examples:
- "User Registration" -> `user-registration.md`
- "Session Management" -> `session-management.md`
- "Password Reset" -> `password-reset.md`

**Create the plans directory if it does not exist:**

```bash
mkdir -p milestones/<NN>-<name>/plans/
```

Populate all 12 sections of the template using information from:

- **Milestone README** -- acceptance criteria, feature description, dependencies, ordering context
- **PRD** -- project goals, non-goals, scope boundaries, risk assessment
- **Architecture document** -- component inventory, design decisions, data flow, technical constraints
- **Sub-agent scan results** -- files to modify, existing interfaces, integration points, code patterns

**Section-specific guidance:**

- **Summary:** One paragraph derived from the milestone README feature description
- **Acceptance Criteria:** Start from the milestone README criteria and refine with implementation-specific detail
- **Approach:** Describe algorithms, patterns, and flow. Reference architecture decisions where relevant.
- **Sub-Features:** Break the feature into committable units of work. Each sub-feature should be completable within a single `/build` session (~120k tokens on a 200k model). See sizing validation below.
- **Interface Contracts:** Function/method signatures, data shapes (types/schemas), event formats. Enough detail for `/build` to implement without guessing interfaces (D-09).
- **Edge Cases:** Identify known edge cases from acceptance criteria, architecture constraints, and codebase scan
- **Test Command:** A single command to validate this feature. Claude proposes based on feature scope and existing test patterns; user confirms during review (D-08). Per DD-12, the user can adjust this mid-build without gate re-approval.
- **Test Strategy:** What to test, how to test, coverage expectations
- **Documentation:** What docs to create or update for this feature
- **Files to Create/Modify:** Specific file paths and what changes in each, informed by sub-agent scan
- **Dependencies:** Other features, libraries, services this feature needs
- **Architectural Deviations:** Default to `(none)`. This section is populated by `/build` during implementation, not by `/plan`.

## Sub-Feature Sizing Validation (PLAN-04, D-06, D-07)

After generating the plan, evaluate each sub-feature for sizing:

### Heuristic Estimation (D-06)

Estimate complexity based on:
- **Files to touch:** How many files will this sub-feature create or modify?
- **Logic scope:** How much new logic is required? Simple CRUD vs. complex algorithms?
- **Integration surface:** How many existing interfaces does this sub-feature interact with?

Judge each sub-feature against the ~120k-token guideline (DD-1). This is a judgment call -- no hard metric or token counting is required.

### Oversized Sub-Feature Handling (D-07)

If any sub-feature appears oversized (e.g., touches many files, involves multiple complex algorithms, has a large integration surface):

1. **Flag it inline** in the Sub-Features section with a note: `[OVERSIZED]`
2. **Propose 2-3 smaller sub-features** that together cover the same scope
3. **Include the revised list** in the plan presented to the user

The user approves or adjusts the split during the review phase.

## Tradeoff Callouts (PLAN-07, D-13)

Before presenting the plan for review, identify 1-2 key tradeoff callouts:

- **Most significant approach decision:** e.g., "Using X pattern because Y. Alternative Z was considered but rejected because W."
- **Most significant sizing decision:** e.g., "SF-3 is the largest sub-feature -- could be split further but kept together because the changes are tightly coupled."

These are lighter than `/design`'s 2-4 callouts since plans are narrower in scope (single feature vs. full architecture).

## Review Phase (PLAN-07, PLAN-08, D-12)

Present the complete plan for user review using the whole-plan approve/revise pattern:

1. **Present the complete plan** -- show the full contents of the generated feature plan file
2. **Present the 1-2 tradeoff callouts** identified above
3. **Use `AskUserQuestion`** with options:
   - **Approve** -- plan is accepted, proceed to checklist validation
   - **Revise** -- plan needs changes

4. **If Revise:** Ask "What should change?" Apply edits to the plan file using the Edit tool. Re-present the revised plan. Repeat until the user selects **Approve**.

This is simpler than the section-by-section approval used in `/design` and `/milestone` because plans are single-feature scope.

## Review Checklist Generation (PLAN-05)

Generate the review checklist at `milestones/<NN>-<name>/reviews/gate-4-<feature-slug>-review.md` using `references/review-checklist-template.md`.

The feature slug in the filename matches the plan file slug (e.g., if the plan is `user-registration.md`, the review is `gate-4-user-registration-review.md`).

## Checklist Validation (PLAN-05)

Claude pre-checks items it can verify programmatically:

- Plan file exists at expected path (`milestones/<NN>-<name>/plans/<feature-slug>.md`)
- All 12 required sections present in the plan (Summary, Acceptance Criteria, Approach, Sub-Features, Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Files to Create/Modify, Dependencies, Architectural Deviations)
- `milestone-status.txt` exists for the target milestone
- Feature exists in `milestone-status.txt`

Present remaining unchecked items to the user. All items must be `[x]` (verified) or `[-]` (N/A with reason) before Gate 4 approval is recorded.

## State File Updates (PLAN-06, PLAN-09)

Two-phase update to `milestone-status.txt`. Follow the exact format from `references/progress-format.md`.

### On Plan Creation (PLAN-06)

Update the feature's `Plan:` line in `milestone-status.txt` from `(not yet planned)` to the plan file path:

Before:
```
[ ] Feature 01.1: User Registration
    Plan: (not yet planned)
```

After:
```
[ ] Feature 01.1: User Registration
    Plan: milestones/01-core-auth/plans/user-registration.md
```

### On Gate 4 Approval (PLAN-09)

Update the feature marker in `milestone-status.txt` from `[ ]` to `[~] planned, awaiting build`. Also add the `Sub-features:` count line:

```
[~] Feature 01.1: User Registration
    Plan: milestones/01-core-auth/plans/user-registration.md
    Sub-features: 0/3 complete
```

Where `3` is the number of sub-features defined in the plan.

**CRITICAL: /plan does NOT write to progress.txt.** Unlike `/milestone` which writes to both `milestone-status.txt` and `progress.txt`, `/plan` writes ONLY to `milestone-status.txt`. Gate 4 is a feature-level event, not a milestone-level event. The `progress.txt` milestone summary line is only updated when features are completed by `/build`.

**Write-ordering (STATE-04):** Since `/plan` writes only to `milestone-status.txt`, there is no multi-file write ordering concern. Write `milestone-status.txt` and stop.

## Next Feature Offer (D-14)

After Gate 4 approval and state file updates are complete:

> "Feature {X} planned. Next unplanned feature: {Y}. Plan it now?"

Check `milestone-status.txt` for the next feature at `[ ]` pending status. If one exists, offer to continue planning. If no pending features remain, report:

> "All features in milestone {NN}: {Name} are planned or complete."

The user can continue (return to Milestone and Feature Detection with the next feature) or exit.

## Anti-Patterns

- **NEVER write to progress.txt** -- /plan writes ONLY to milestone-status.txt
- **Do NOT check for `[x] Gate 3`** -- Gate 3 stays `[~] In progress`. Validate that an active milestone exists instead.
- **Do NOT auto-scan spike artifacts** -- read ONLY when the user explicitly references them (D-11)
- **Do NOT perform architecture-wide codebase scans** -- the sub-agent scans feature-relevant files only (5-15 files, not 15-30)
- **Do NOT use hard token counting for sizing** -- use heuristic estimation per D-06
- **Do NOT use section-by-section approval** -- use whole-plan Approve/Revise pattern per D-12
