# Gate 3: Milestone Planning

Produces milestone-scoped feature breakdowns from an approved PRD and architecture document. This reference contains the complete Gate 3 specification for normal mode (first invocation and subsequent invocations) -- an executor reading only this file can run the full Gate 3 flow.

## Input Loading (MIL-02, D-02, D-04)

Read the primary inputs from disk:

1. **Read `prd.md`** from the project root. This is required -- if it does not exist, report the error and stop.
2. **Read `docs/ARCHITECTURE_AND_DESIGN.md`** from the project root. This is required -- if it does not exist, report the error and stop.
3. **Read `progress.txt`** from the project root. This is required -- if it does not exist, report the error and stop.

All three files are primary inputs per D-02. The PRD provides goals, non-goals, scope, risk assessment, and milestone intent. The architecture document provides component inventory, data flow, design decisions, and technical constraints. The progress file provides current gate status.

**Spike artifacts (D-04):** Do not auto-detect or auto-scan `docs/spikes/`. If the user explicitly references a spike during the session (e.g., "see the websocket auth spike"), read `docs/spikes/<topic>.md` on request. Spike artifacts are user-referenced only.

## Mode Detection

After loading inputs, determine which mode to enter:

1. **First invocation:** `prd.md` Milestones section contains `(to be defined)` AND no `milestones/` directories exist on disk. Proceed to Section 4 (Propose Milestone Plan).
2. **Subsequent invocation:** `prd.md` Milestones section is populated with an approved milestone plan AND at least one milestone still lacks a directory under `milestones/`. Proceed to Section 5 (Auto-Select Next Milestone).
3. **Revision mode:** The target milestone directory already exists under `milestones/`. This is handled by `references/revision-mode.md`, not this file. SKILL.md routes to revision mode directly.

Detection logic:

- Check `prd.md` Milestones section content (is it `(to be defined)` or populated?)
- Run `ls milestones/` to see which milestone directories exist
- Compare the milestone plan in `prd.md` against existing directories to identify the next undefined milestone

## First Invocation: Propose Milestone Plan (D-07, D-01)

On first invocation, propose the full milestone breakdown before defining any individual milestone.

### Analysis

1. Read the PRD goals, non-goals, risk assessment, and any existing milestone intent
2. Read the architecture document's component inventory, data flow, and design decisions
3. Analyze the work implied by the PRD and architecture to identify natural grouping boundaries

### Milestone Plan Proposal

Propose a complete milestone plan with:

- **Sequence number** for each milestone (NN, zero-padded two digits)
- **Kebab-case name** for the directory (e.g., `01-core-auth`)
- **1-2 sentence summary** describing what the milestone delivers as customer-visible value

Apply DD-1 sizing constraints:

- 2-5 features per milestone
- Each milestone represents a deployable increment of user-visible value
- Features should be testable, reviewable units of delivery

Present the milestone plan with ordering rationale explaining why milestones are sequenced the way they are (dependencies, incremental value delivery, risk reduction).

### Tradeoff Callouts (D-03)

Before requesting approval, present 2-3 tradeoff callouts highlighting key grouping or ordering decisions:

- What was grouped together and why
- Alternative groupings that were considered
- Ordering choices and their tradeoffs (e.g., "putting auth before dashboard means users can't see anything until login works, but avoids building UI without real data")

### Approval

Use `AskUserQuestion` with options:

- **Approve** -- milestone plan is accepted
- **Revise** -- plan needs changes (ask what should change, revise, re-present)

### Persist Milestone Plan (D-08)

On Approve: update `prd.md` Milestones section using the Edit tool. Replace `(to be defined)` with the approved milestone plan formatted as a numbered list:

```
1. **Core Auth** -- User registration, login, session management. First deployable increment.
2. **Dashboard** -- User dashboard with activity feed and settings. Builds on auth foundation.
3. **Notifications** -- Email and in-app notifications for key events. Enhances existing features.
```

### Post-Approval Flow

After persisting the milestone plan in `prd.md`:

- Default: proceed to define milestone #1 (Section 6 below)
- If the user says "I'll define milestones later" or similar deferral, stop here. The `prd.md` is updated with the plan but no milestone directories are created yet.

## Subsequent Invocation: Auto-Select Next Milestone (D-09)

On subsequent invocations (milestone plan exists in `prd.md` but not all milestones have directories):

1. Read `prd.md` Milestones section for the approved milestone plan
2. Run `ls milestones/` to identify which milestones already have directories
3. Auto-select the next milestone in sequence that lacks a directory
4. Report the selection: "Next undefined milestone: Milestone NN: Name"

**User override:** The user can target a specific milestone by saying "define milestone 3" or "skip to milestone 3". Honor the override if the target milestone is in the approved plan and does not yet have a directory.

Proceed to Section 6 (Define Individual Milestone).

## Define Individual Milestone (MIL-03, MIL-04, MIL-05, MIL-06, MIL-07)

Generate the complete set of artifacts for a single milestone.

### Sequence Number (MIL-03)

Auto-increment the sequence number from existing `milestones/` directories:

- Run `ls milestones/` to count existing milestone directories
- Use the milestone's position in the approved plan (from `prd.md`) for the sequence number
- Zero-pad to two digits (e.g., `01`, `02`, `03`)

### Directory Creation

```bash
mkdir -p milestones/<NN>-<kebab-name>/reviews/
```

### README.md Generation (MIL-04)

Read `assets/milestone-readme-template.md` for the template structure. Generate `milestones/<NN>-<name>/README.md` with all required sections populated:

- **Goal** -- 1-3 sentences describing customer-visible outcome (not internal refactoring)
- **Features** -- 2-5 features per milestone (DD-1), each with specific, testable acceptance criteria
- **Dependencies** -- other milestones, external systems, or prerequisites
- **Ordering** -- why this milestone is sequenced at this position
- **Sizing** -- confirm 2-5 features, note any large features that may need sub-feature splitting at `/plan-feature` time
- **Configuration** -- milestone-specific config parameters (omit if none beyond `prd.md` Configuration section)
- **Definition of Done** -- completion checklist

### milestone-status.txt Generation (MIL-05)

Generate `milestones/<NN>-<name>/milestone-status.txt` with all features at `[ ]` pending status. Follow the format from `references/progress-format.md`:

```
# Milestone NN: Name
# Status: [ ] pending  N features, 0 complete

## Features

[ ] Feature NN.1: Feature Name
    Plan: (not yet planned)

[ ] Feature NN.2: Feature Name
    Plan: (not yet planned)
```

### gate-3-review.md Generation (MIL-06)

Generate `milestones/<NN>-<name>/reviews/gate-3-review.md` using the format from `references/review-checklist-template.md`. This checklist is per-milestone (not at `docs/reviews/` like Gates 0-2).

### progress.txt Updates (MIL-07, MIL-09)

**Write-ordering (STATE-04):** Write `milestone-status.txt` FIRST, then update `progress.txt`. This ensures the source-of-truth file is updated before the summary file.

After writing `milestone-status.txt`, update `progress.txt`:

1. **Gate 3 line (MIL-09):** If not already in-progress, update the Gate 3 line to:

   ```
   [~] Gate 3: Milestone Review  In progress
   ```

   **Important:** `/milestone` NEVER writes `[x]` to the Gate 3 line. Only `/project` closes Gate 3 (D-05).

2. **Milestone summary line (MIL-07):** Add a new line in the `## Milestones` section:

   ```
   [ ] Milestone NN: Name  milestones/<NN>-<name>/  0/N features complete
   ```

   Follow the Milestone Summary Line Format from `references/progress-format.md`.

## Review Phase (MIL-08, D-03)

Present the milestone breakdown for user review. Focus the review on Gate 3 concerns (DD-8):

- **Feature grouping coherence** -- are features correctly grouped? Any that belong in a different milestone?
- **Ordering** -- is the ordering correct given dependencies?
- **Sizing realism** -- is each feature sized appropriately? Too large? Too small?
- **Acceptance criteria specificity** -- are acceptance criteria specific and testable?

### Tradeoff Callouts (D-03)

Present 2-3 key grouping or ordering decisions with alternatives considered. Focus on decisions where reasonable people might disagree.

### Approval Flow

Use `AskUserQuestion` with options:

- **Approve** -- milestone definition is accepted, proceed to Checklist Validation
- **Revise** -- ask what needs changing, apply edits to README.md, re-present
- **Partial** -- present a multiSelect of README sections for section-by-section approval:
  - [ ] Goal
  - [ ] Features
  - [ ] Dependencies
  - [ ] Ordering
  - [ ] Sizing
  - [ ] Definition of Done

  User checks sections they approve. For each unchecked section, ask "What should change in [Section Name]?" Apply edits. Re-present unchecked sections. Repeat until all sections are approved or user does a full Approve.

## Checklist Validation (MIL-06)

Generate and validate the review checklist for this milestone.

1. Read `references/review-checklist-template.md` for the Gate 3 template structure.

2. The checklist was generated during Section 6 at `milestones/<NN>-<name>/reviews/gate-3-review.md`. Read it now.

3. **Claude pre-checks** items that can be verified programmatically:
   - `milestones/<NN>-<name>/README.md` exists
   - All required sections present in README.md (Goal, Features, Dependencies, Ordering, Sizing, Definition of Done)
   - `milestones/<NN>-<name>/milestone-status.txt` exists
   - Feature count in `milestone-status.txt` matches feature count in README.md
   - Each feature has at least one acceptance criterion

4. **Present remaining unchecked items** to the user for resolution.

5. **All items must be `[x]` (verified) or `[-]` (N/A with reason)** before the milestone is considered approved. No item may remain as `[ ]`.

6. Update the checklist `**Status:**` to `[x] Approved` with the current date.
