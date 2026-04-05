# /plan

**Source:** `skills/project/plan/`
**Command:** `/plan`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Per-feature implementation planning skill that produces detailed feature plans with sub-feature breakdown, interface contracts, sizing validation, and test commands. Each invocation plans one feature from an approved milestone. Supports re-plan mode for already-planned features with diff-focused revision. Gate 4 approval updates the feature entry in `milestone-status.txt` from `[ ]` to `[~] planned, awaiting build`. After approval, offers to plan the next unplanned feature in the same session.

## When to Use

- Planning a specific feature after milestone definition (Gate 3 in progress)
- Creating implementation plans with sub-feature breakdown
- Re-planning a feature after scope changes or implementation discovery
- Continuing feature planning across a milestone (auto-selects next unplanned)

## When NOT to Use

- When you want to check project status or get routing (use `/project`)
- When you want to define project scope or create a PRD (use `/define` -- runs Gates 0/WB/1)
- When you want to design system architecture (use `/design` -- Gate 2)
- When you want to define milestones and features (use `/milestone` -- Gate 3)
- When you want to implement code (use `/build`)

## Behavior

### 1. Mode Detection

On invocation, `/plan` reads `progress.txt` and `milestone-status.txt` to determine entry mode:

- **No active milestone:** Declines with prerequisite message (run `/milestone` first)
- **Auto-detect active milestone:** Finds the first milestone at `[ ]` or `[~]` status in `progress.txt`. User can override with an explicit milestone name or number.
- **Auto-select next feature:** Finds the first feature at `[ ]` (pending) status in `milestone-status.txt`. User can override with an explicit feature name.
- **Re-plan mode:** Target feature already has a plan file -- enters diff-focused revision automatically.
- **All features planned:** Reports that all features in the milestone are planned or complete and suggests running `/project` for status.

### 2. Input Loading and Codebase Scan

Reads milestone README, `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `progress.txt`, and `milestone-status.txt` as primary inputs. Spawns a sub-agent for a feature-targeted codebase scan (5-15 files relevant to the feature being planned, not architecture-wide). Reads spike artifacts only when the user explicitly references them -- no auto-detection of `docs/spikes/`.

### 3. Plan Generation and Review

Generates a feature plan with 12 sections: Summary, Acceptance Criteria, Approach, Sub-Features, Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Files to Create/Modify, Dependencies, and Architectural Deviations. Validates sub-feature sizing against the ~120k-token guideline and proposes inline splits for oversized sub-features. Presents 1-2 tradeoff callouts highlighting the most significant approach or sizing decisions. Uses a whole-plan Approve/Revise cycle (not section-by-section) since plans are single-feature scope. Generates a Gate 4 review checklist with 5 static items plus auto-generated content-specific items.

### 4. Re-plan Mode

Auto-detected when the target feature already has a plan file on disk. Asks "What changed?" and applies diff-focused revision to only the affected sections using the Edit tool. Generates a fresh review checklist (prior review is invalidated). Uses the same Approve/Revise approval flow as normal mode.

### 5. Completion

Updates `milestone-status.txt` with the plan path and `[~] planned, awaiting build` status. Does NOT write to `progress.txt` -- Gate 4 approval is recorded only in `milestone-status.txt`. Offers to plan the next unplanned feature: "Feature X planned. Next unplanned feature: Y. Plan it now?"

## Artifacts

| Artifact | Path | Created By |
|----------|------|------------|
| Feature plan | `milestones/<NN>-<name>/plans/<feature-slug>.md` | /plan |
| Gate 4 review | `milestones/<NN>-<name>/reviews/gate-4-<feature-slug>-review.md` | /plan |
| milestone-status.txt | `milestones/<NN>-<name>/milestone-status.txt` | /plan (updates only) |

## Skill Files

```
skills/project/plan/
+-- SKILL.md                           # Flow controller (~150-180 lines)
+-- references/
|   +-- gate-4-plan.md                 # Complete Gate 4 normal-mode spec
|   +-- revision-mode.md               # Re-plan mode spec
|   +-- review-checklist-template.md   # Gate 4 review checklist template
|   +-- progress-format.md            # State file format spec (own copy)
+-- assets/
    +-- feature-plan-template.md       # Feature plan section template
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/project` | Reads `progress.txt` for milestone status; routes users to `/plan` |
| `/milestone` | Produces milestone README and `milestone-status.txt` that `/plan` reads |
| `/design` | Produces architecture doc that `/plan` reads; sub-agent scan pattern origin |
| `/build` | Consumes feature plans produced by `/plan`; implements sub-features |
