# Phase 5: /plan (Gate 4) - Research

**Researched:** 2026-04-02
**Domain:** Claude Code skill authoring -- per-feature implementation planning with gate approval
**Confidence:** HIGH

## Summary

Phase 5 builds the `/plan` skill, which produces per-feature implementation plans and manages Gate 4 approval. This is the fifth skill in the `/project` orchestrated workflow, following the well-established pattern from `/define` (Phase 2), `/design` (Phase 3), and `/milestone` (Phase 4). The skill reads milestone README, PRD, architecture doc, and state files as inputs, produces a feature plan file and review checklist, and updates `milestone-status.txt` on approval.

The implementation follows the same structural pattern as `/milestone` -- a flow-controller SKILL.md (~150-180 lines) that delegates gate logic to reference files, with its own copy of shared references (progress-format.md, review-checklist-template.md). Key differentiators from `/milestone`: (1) operates at feature granularity rather than milestone granularity, (2) includes sub-feature sizing validation with split proposals, (3) spawns a targeted codebase scan sub-agent (like `/design`), and (4) writes to `milestone-status.txt` only (never to `progress.txt`).

**Primary recommendation:** Model the skill directory structure on `/milestone` (closest predecessor), the sub-agent scan on `/design`, and the revision mode on `/define`. All patterns are established and proven in prior phases.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Auto-select next unplanned feature -- read `milestone-status.txt`, find first feature at `[ ]` pending or needs-replanning status. User can override with explicit feature name argument.
- **D-02:** Auto-detect active milestone -- read `progress.txt` for the first milestone at `[ ]` or `[~]` status. User can override with explicit milestone name/number.
- **D-03:** When no plannable features remain, report and exit cleanly -- "All features in milestone X are planned or complete. Run /project to check status."
- **D-04:** Auto-detect re-plan mode -- if target feature already has a plan file, enter re-plan mode automatically (consistent with /milestone D-10).
- **D-05:** Re-plan uses diff-focused revision -- read existing plan, ask "What changed?", revise only affected sections. Fresh review checklist after revision. Consistent with /define D-15 and /milestone D-12.
- **D-06:** Heuristic estimation -- Claude estimates sub-feature complexity based on files to touch, logic scope, and integration surface. No hard metric; it's a judgment call against the ~120k-token guideline (DD-1).
- **D-07:** Oversized sub-features get inline split proposals -- flag the sub-feature, propose 2-3 smaller items, present revised plan. User approves or adjusts the split during review.
- **D-08:** Test command: Claude proposes based on feature scope and existing test patterns, user confirms during review. Per DD-12, user can adjust mid-build without gate re-approval.
- **D-09:** Interface contracts at signatures + shapes depth -- function/method signatures, data shapes (types/schemas), event formats. Enough for /build to implement without guessing interfaces.
- **D-10:** Targeted codebase scan via sub-agent -- spawn a sub-agent to read files relevant to the feature being planned. Informs approach, files to modify, and integration points. Consistent with /design D-05.
- **D-11:** Spike artifacts user-referenced only -- /plan reads spike docs only when user explicitly references them. No auto-detection. Consistent with /milestone Phase 4 D-04.
- **D-12:** Whole-plan approve/revise -- present full plan, offer Approve / Revise. If Revise, ask what should change, fix, re-present. Simpler than section-by-section since plans are single-feature scope.
- **D-13:** 1-2 tradeoff callouts before approval prompt -- highlight the most significant approach/sizing decisions. Lighter than /design (2-4 callouts) since plans are narrower in scope.
- **D-14:** After Gate 4 approval, offer to plan the next feature -- "Feature X planned. Next unplanned feature: Y. Plan it now?" User can continue or exit. Streamlines multi-feature planning sessions.

### Claude's Discretion
- Plan generation approach and section ordering
- Sub-agent prompt and file selection heuristics for codebase scan
- Exact sub-feature granularity within sizing guidelines
- Edge case identification depth
- Documentation section content
- Exact phrasing of approval prompts and tradeoff callouts
- How to detect "key tradeoffs" worth calling out
- Review checklist item generation from plan contents
- Progress.txt interaction details (reads for validation, does not write -- Gate 4 approval goes to milestone-status.txt only)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PLAN-01 | `/plan` reads milestone README, prd.md, ARCHITECTURE_AND_DESIGN.md, progress.txt, milestone-status.txt as primary inputs | Follows same input-loading pattern as gate-3-milestone.md; all input files are established artifacts from prior phases |
| PLAN-02 | `/plan` validates the target feature exists in milestone README and is in pending or needs-replanning status | milestone-status.txt format documented in progress-format.md; feature status uses `[ ]` pending marker; re-plan detected by existing plan file (D-04) |
| PLAN-03 | `/plan` produces feature plan with all required sections including empty Architectural Deviations and test command | Full section list defined in DESIGN.md `milestones/<NN>-<name>/plans/<feature>.md (Gate 4)` specification; template needed in assets/ |
| PLAN-04 | `/plan` sizes sub-features to ~120k tokens; flags oversized and proposes splits | DD-1 defines the 120k-token guideline; D-06 establishes heuristic estimation; D-07 defines inline split proposal pattern |
| PLAN-05 | `/plan` produces gate-4-<feature>-review.md checklist | DD-13 defines Gate 4 static checklist items (5 items); review-checklist-template.md pattern from prior skills |
| PLAN-06 | `/plan` updates milestone-status.txt with plan file path on plan creation | progress-format.md documents feature entry format with `Plan:` field |
| PLAN-07 | `/plan` presents plan for review focused on implementation correctness, edge case coverage, sub-feature sizing, test command appropriateness | DD-8 Gate 4 review context defined; D-12 specifies whole-plan approve/revise pattern; D-13 specifies 1-2 tradeoff callouts |
| PLAN-08 | `/plan` supports in-session revision before approval | Standard produce-then-review cycle; D-12 whole-plan Approve/Revise pattern (simpler than section-by-section) |
| PLAN-09 | `/plan` records Gate 4 approval by updating feature entry in milestone-status.txt from `[ ]` to `[~] planned, awaiting build` | /plan writes to milestone-status.txt ONLY -- does NOT write to progress.txt (unlike /milestone which writes both) |
</phase_requirements>

## Standard Stack

This phase is pure prompt engineering (Markdown skill authoring). No application code, no package dependencies.

### Core Artifacts to Create

| File | Purpose | Model From |
|------|---------|------------|
| `skills/project/plan/SKILL.md` | Flow controller (~150-180 lines) | `skills/project/milestone/SKILL.md` (163 lines) |
| `skills/project/plan/references/gate-4-plan.md` | Complete Gate 4 specification | `skills/project/milestone/references/gate-3-milestone.md` |
| `skills/project/plan/references/revision-mode.md` | Re-plan mode specification | `skills/project/milestone/references/revision-mode.md` |
| `skills/project/plan/references/review-checklist-template.md` | Gate 4 review checklist template | `skills/project/milestone/references/review-checklist-template.md` |
| `skills/project/plan/references/progress-format.md` | Own copy of progress format spec | `skills/project/milestone/references/progress-format.md` (verbatim copy) |
| `skills/project/plan/assets/feature-plan-template.md` | Template with all required sections | DESIGN.md Gate 4 section spec |
| `docs/skills/plan.md` | Detail doc | `docs/skills/milestone.md` pattern |
| `docs/SKILLS.md` | Catalog entry (add Plan row) | Existing pattern |

**Confidence:** HIGH -- all patterns established in Phases 2-4.

## Architecture Patterns

### Recommended Directory Structure

```
skills/project/plan/
├── SKILL.md                    # Flow controller (~150-180 lines)
├── references/
│   ├── gate-4-plan.md          # Complete Gate 4 normal-mode spec
│   ├── revision-mode.md        # Re-plan mode spec
│   ├── review-checklist-template.md  # Gate 4 review checklist
│   └── progress-format.md      # Own copy of state file format
└── assets/
    └── feature-plan-template.md  # Feature plan section template
```

### Pattern 1: Flow Controller SKILL.md

**What:** SKILL.md serves as a lightweight dispatcher (~150-180 lines) that detects mode, validates prerequisites, and delegates to reference files for detailed gate logic.

**When to use:** Always -- this is the established pattern for all Phase 2-4 skills.

**Structure (from /milestone precedent):**

```markdown
---
name: plan
description: >
  Per-feature implementation plan with sub-feature sizing, interface contracts,
  and test commands. Supports re-plan mode for scope changes.
  Use when planning a feature, creating implementation plan, or re-planning.
disable-model-invocation: true
---

# /plan -- Feature Implementation Plan (Gate 4)

## Rules
[Standard rules: fresh read, produce-then-review, checklist resolution,
 write-ordering, interactive prompts, no auto-dispatch]

## Prerequisites
[progress.txt must exist, Gate 3 must be [~] or active milestone must exist]

## Step 1 -- Detect Mode and State
[Read progress.txt, detect active milestone, find target feature,
 branch into normal/re-plan/all-planned modes]

## Step 2 -- Load Inputs and Scan Codebase
[Read reference, load inputs, spawn sub-agent for targeted scan]

## Step 3 -- Generate and Review Plan
[Follow gate-4-plan.md spec for plan generation and review]

## Step 4 -- Re-plan Mode
[Follow revision-mode.md spec for diff-focused revision]

## Step 5 -- Completion Report
[Summary, artifacts, next action offer]

## Error Handling
[Standard error cases]
```

### Pattern 2: Targeted Codebase Sub-Agent (from /design)

**What:** Spawn a sub-agent to scan files specifically relevant to the feature being planned. Narrower scope than /design's architecture scan (feature-targeted, not project-wide).

**When to use:** During plan generation (Step 2), before synthesizing the feature plan.

**Key differences from /design sub-agent:**
- /design scans 15-30 files for architecture-wide understanding
- /plan scans files relevant to ONE feature -- likely 5-15 files
- Selection heuristic: files listed in milestone README acceptance criteria, files matching feature name patterns, existing implementation files the feature will modify

### Pattern 3: Feature Auto-Selection (from /milestone)

**What:** Auto-detect the active milestone from progress.txt, then auto-select the next unplanned feature from milestone-status.txt.

**When to use:** On every normal-mode invocation (Step 1).

**Logic (D-01, D-02):**
1. Read `progress.txt` -> find first milestone at `[ ]` or `[~]`
2. Read that milestone's `milestone-status.txt` -> find first feature at `[ ]` pending
3. User can override with explicit feature name or milestone number
4. If no plannable features remain, report and exit (D-03)

### Pattern 4: State File Write Scope

**What:** `/plan` writes ONLY to `milestone-status.txt`. It does NOT write to `progress.txt`.

**Critical distinction from /milestone:** `/milestone` writes to BOTH milestone-status.txt and progress.txt (milestone summary line). `/plan` writes only to milestone-status.txt because Gate 4 approval is a feature-level event, not a milestone-level event. The progress.txt milestone summary line is only updated when features are completed by `/build`.

**What /plan writes to milestone-status.txt:**
1. On plan creation (PLAN-06): update the feature's `Plan:` line from `(not yet planned)` to the plan file path
2. On Gate 4 approval (PLAN-09): update the feature marker from `[ ]` to `[~] planned, awaiting build`

### Pattern 5: Whole-Plan Approve/Revise (D-12)

**What:** Simpler review pattern than section-by-section. Present the complete plan, offer Approve / Revise. If Revise, ask what should change, apply edits, re-present.

**Why simpler than /design and /milestone:** Plans are single-feature scope (narrower). Section-by-section adds overhead without proportional value at this granularity.

### Anti-Patterns to Avoid

- **Writing to progress.txt:** /plan NEVER writes to progress.txt. Only milestone-status.txt. This is a critical distinction from /milestone.
- **Auto-scanning spikes:** D-11 is explicit -- read spike docs ONLY when user references them. No auto-detection.
- **Architecture-wide scan:** The sub-agent scans feature-relevant files only, not the full project architecture. That was /design's job.
- **Hard token counting for sizing:** D-06 says heuristic estimation, not precise token counting. Claude estimates based on files to touch, logic scope, and integration surface.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Review checklist format | Custom checklist structure | `references/review-checklist-template.md` with Gate 4 static items from DD-13 | Consistency across all gates |
| Progress file parsing | Ad-hoc text parsing | `references/progress-format.md` spec (verbatim copy) | Same format across all skills |
| Revision mode flow | Unique re-plan flow | Adapt `/milestone/references/revision-mode.md` pattern for feature scope | Proven pattern, consistent UX |
| Feature plan sections | Custom section list | Template from DESIGN.md Gate 4 artifact specification | Authoritative section list |

## Common Pitfalls

### Pitfall 1: Writing to progress.txt

**What goes wrong:** /plan accidentally writes to progress.txt (e.g., updating Gate 3 or milestone summary lines).
**Why it happens:** Prior skills (/milestone, /define, /design) all write to progress.txt. Easy to cargo-cult.
**How to avoid:** SKILL.md rules section must explicitly state "/plan does NOT write to progress.txt". The gate-4-plan.md reference should only reference milestone-status.txt writes.
**Warning signs:** Any mention of `progress.txt` in write operations.

### Pitfall 2: Prerequisite Check -- What Gate to Validate

**What goes wrong:** Checking Gate 3 as `[x]` approved, but Gate 3 is NEVER `[x]` -- it stays `[~] In progress` until /project closes it.
**Why it happens:** Other skills check for `[x]` on their prerequisite gate. Gate 3 is different per Phase 4 D-05.
**How to avoid:** /plan should validate that an active milestone exists (milestone directory exists with milestone-status.txt), NOT that Gate 3 is `[x]`. The prerequisite is "an approved milestone exists" which is evidenced by the milestone directory and milestone-status.txt existing.
**Warning signs:** SKILL.md checking `[x] Gate 3` in progress.txt.

### Pitfall 3: Re-plan Mode vs. Fresh Plan Distinction

**What goes wrong:** Re-plan mode overwrites the entire plan file instead of performing diff-focused revision.
**Why it happens:** Easier to regenerate than to edit.
**How to avoid:** D-05 is explicit: "read existing plan, ask 'What changed?', revise only affected sections." The revision-mode.md reference should enforce targeted edits using Edit tool, not Write.
**Warning signs:** Re-plan mode reading existing plan but producing a full replacement.

### Pitfall 4: milestone-status.txt Feature Entry Format

**What goes wrong:** Writing incorrect format for the `[~] planned, awaiting build` status line.
**Why it happens:** The milestone-status.txt format has specific indentation and field structure.
**How to avoid:** Reference progress-format.md for the exact format. The approved feature entry should look like:
```
[~] Feature 01.1: User Registration
    Plan: milestones/01-core-auth/plans/user-registration.md
    Sub-features: 0/3 complete
```
**Warning signs:** Missing indentation, wrong field ordering, inconsistent notation.

### Pitfall 5: Feature Plan File Naming

**What goes wrong:** Using inconsistent naming for the plan file (e.g., spaces, wrong casing, feature number instead of name).
**Why it happens:** The DESIGN.md specifies `plans/<feature>.md` but doesn't prescribe the exact slug format.
**How to avoid:** Use kebab-case derived from the feature name (consistent with milestone directory naming). Example: "User Registration" -> `plans/user-registration.md`.
**Warning signs:** Feature names with spaces, underscores, or CamelCase in file paths.

### Pitfall 6: Gate 4 Review Checklist Path

**What goes wrong:** Placing the review checklist in the wrong location.
**Why it happens:** DD-13 specifies `milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md` -- the feature slug is part of the filename (unlike Gate 3 which has one review per milestone).
**How to avoid:** Use same kebab-case slug from plan file naming. Path pattern: `milestones/<NN>-<name>/reviews/gate-4-<feature-slug>-review.md`.
**Warning signs:** Reviews placed in `docs/reviews/` instead of per-milestone `reviews/` directory.

## Code Examples

### Gate 4 Static Checklist Items (from DD-13)

```markdown
# Gate 4 Review -- Feature Plan: {Feature Name}

**Artifact:** milestones/<NN>-<name>/plans/<feature>.md
**Status:** [ ] Pending
**Reviewer(s):**
**Date:**

## Checklist

- [ ] Does the approach handle known edge cases?
- [ ] Are the sub-features correctly scoped for single-session work?
- [ ] Is the test command appropriate for this feature?
- [ ] Are the files to create/modify correct?
- [ ] Are interface contracts compatible with existing code?
- [ ] [Auto] Content-specific items based on plan...

## Reviewer Comments

(none)
```

Source: DESIGN.md DD-13

### Feature Plan Template Sections (from DESIGN.md Gate 4 spec)

```markdown
# Feature Plan: {Feature Name}

**Milestone:** {NN} - {Milestone Name}
**Feature:** {Feature Number}: {Feature Name}
**Status:** Planned
**Date:** {ISO date}

## Summary

{One paragraph describing what this feature does}

## Acceptance Criteria

{Pulled from milestone README, refined with implementation detail}

## Approach

{How the feature will be implemented -- algorithms, patterns, flow}

## Sub-Features

- [ ] **SF-1: {Name}** -- {Description and scope}
- [ ] **SF-2: {Name}** -- {Description and scope}
- [ ] **SF-3: {Name}** -- {Description and scope}

## Interface Contracts

{Function/method signatures, data shapes (types/schemas), event formats}

## Edge Cases

{Known edge cases and how they're handled}

## Test Command

```
{single command to validate this feature}
```

## Test Strategy

{What to test, how to test, coverage expectations}

## Documentation

{What documentation to create or update}

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| {path} | Create/Modify | {what changes} |

## Dependencies

{Other features, libraries, services this feature needs}

## Architectural Deviations

(none)
```

Source: DESIGN.md `milestones/<NN>-<name>/plans/<feature>.md (Gate 4)` specification

### milestone-status.txt Update on Plan Creation (PLAN-06)

Before plan:
```
[ ] Feature 01.1: User Registration
    Plan: (not yet planned)
```

After plan creation:
```
[ ] Feature 01.1: User Registration
    Plan: milestones/01-core-auth/plans/user-registration.md
```

After Gate 4 approval (PLAN-09):
```
[~] Feature 01.1: User Registration
    Plan: milestones/01-core-auth/plans/user-registration.md
    Sub-features: 0/3 complete
```

Source: progress-format.md milestone-status.txt format specification

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Section-by-section approval | Whole-plan approve/revise (D-12) | Phase 5 context | Simpler UX for single-feature scope |
| 2-4 tradeoff callouts | 1-2 tradeoff callouts (D-13) | Phase 5 context | Lighter review since plans are narrower |
| Architecture-wide scan | Feature-targeted scan (D-10) | Phase 5 context | More focused, fewer files read |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual validation (Markdown skill -- no automated test framework) |
| Config file | none |
| Quick run command | `bash cicd/lint-markdown.sh` |
| Full suite command | `bash cicd/lint-markdown.sh` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLAN-01 | Reads correct input files | manual-only | Manual: invoke /plan, verify it reads all 5 inputs | N/A |
| PLAN-02 | Validates feature exists and is pending | manual-only | Manual: invoke /plan with invalid feature name | N/A |
| PLAN-03 | Plan file has all required sections | manual-only | Manual: review generated plan against template | N/A |
| PLAN-04 | Oversized sub-features flagged | manual-only | Manual: create feature with large scope, verify split proposal | N/A |
| PLAN-05 | Review checklist produced | manual-only | Manual: verify gate-4-<feature>-review.md created | N/A |
| PLAN-06 | milestone-status.txt updated with plan path | manual-only | Manual: verify Plan: field updated after plan creation | N/A |
| PLAN-07 | Plan presented with correct review focus | manual-only | Manual: verify tradeoff callouts and review prompts | N/A |
| PLAN-08 | In-session revision works | manual-only | Manual: request revision, verify targeted edit | N/A |
| PLAN-09 | Gate 4 approval updates status to [~] | manual-only | Manual: approve plan, verify milestone-status.txt marker change | N/A |

**Justification for manual-only:** This is a Markdown-based skill (prompt engineering). There is no application code to unit-test. Validation requires invoking the skill in a Claude Code session and verifying behavior against requirements. Markdown lint (`bash cicd/lint-markdown.sh`) validates formatting compliance.

### Sampling Rate

- **Per task commit:** `bash cicd/lint-markdown.sh`
- **Per wave merge:** `bash cicd/lint-markdown.sh` + manual review of SKILL.md structure
- **Phase gate:** Full manual walkthrough of /plan in a test project

### Wave 0 Gaps

None -- existing markdown lint infrastructure covers formatting validation. Functional validation is inherently manual for prompt-engineering skills.

## Sources

### Primary (HIGH confidence)

- `skills/project/DESIGN.md` -- DD-1, DD-4, DD-7, DD-8, DD-12, DD-13; Gate 4 artifact specification
- `skills/project/milestone/SKILL.md` -- flow controller pattern (163 lines), closest structural model
- `skills/project/design/SKILL.md` -- sub-agent codebase scan pattern (143 lines)
- `skills/project/define/SKILL.md` -- diff-focused revision mode pattern (197 lines)
- `skills/project/milestone/references/` -- reference file organization pattern (gate spec, progress-format, review-checklist-template, revision-mode)
- `skills/project/references/progress-format.md` -- state file format specification
- `.planning/phases/05-plan-gate-4/05-CONTEXT.md` -- locked decisions D-01 through D-14
- `.planning/REQUIREMENTS.md` -- PLAN-01 through PLAN-09 requirements

### Secondary (MEDIUM confidence)

- `.planning/codebase/CONVENTIONS.md` -- SKILL.md frontmatter, naming patterns
- `.planning/codebase/STRUCTURE.md` -- directory layout, skill bundle structure

## Project Constraints (from CLAUDE.md)

- Use `<br/>` for line breaks inside Mermaid node labels (not `\n`)
- `disable-model-invocation: true` is mandatory on all skills
- Scripts always invoked with explicit interpreter (`bash script.sh`, never `./script.sh`)
- Never set executable bit on scripts

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all patterns established in Phases 2-4, no new technology
- Architecture: HIGH -- direct structural model from /milestone (163 lines), sub-agent from /design
- Pitfalls: HIGH -- identified from actual differences between /plan and predecessor skills (state write scope, prerequisite check, review pattern)

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable -- internal Markdown skill with no external dependencies)
