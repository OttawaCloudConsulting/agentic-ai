# Phase 4: /milestone (Gate 3) - Research

**Researched:** 2026-04-02
**Domain:** Claude Code skill authoring (Markdown prompt engineering, state file management, flow controller pattern)
**Confidence:** HIGH

## Summary

Phase 4 delivers the `/milestone` skill -- a flow controller that breaks an approved PRD and architecture document into milestone-scoped feature breakdowns. The skill follows established patterns from `/define` (Phase 2) and `/design` (Phase 3): SKILL.md as a flow controller under 200 lines, gate references in `references/`, review checklist template, and produce-then-review cycles with `AskUserQuestion`.

The key complexity in this phase is the two-phase flow (propose all milestones first, then define one at a time) and revision mode (auto-detect existing milestone, present feature checklist for selective reset, preserve completed features). Gate 3 has unique behavior: it stays `[~] In progress` across multiple invocations and only closes when `/project` detects all milestones have completed reviews.

**Primary recommendation:** Follow the `/design` SKILL.md structure as the closest predecessor (single gate, reference loading, produce-then-review), adding the two-phase flow and revision mode as step variants.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Analyze and propose -- Claude reads PRD + architecture doc, proposes full milestone breakdown, user reviews/revises. Consistent with produce-then-review pattern from prior phases.
- **D-02:** Direct reading of inputs -- no sub-agent needed. Inputs are focused docs (PRD, architecture), not a sprawling codebase.
- **D-03:** Tradeoff callouts before approval checklist -- call out 2-3 key grouping/ordering decisions before the approval flow. Consistent with /design Phase 3 D-09.
- **D-04:** Spike artifacts user-referenced only -- don't auto-detect spike docs from PRD. User cites relevant spikes explicitly.
- **D-05:** /project detects closure -- /project offers to close Gate 3 when milestones exist with approved reviews. User explicitly confirms. Keeps /project as routing authority, maintains HITL principle.
- **D-06:** Closure checks -- milestones exist AND each has a completed gate-3-review.md. Ensures every milestone was reviewed before gate closes.
- **D-07:** Propose all, define one -- first invocation proposes milestone plan (count, summaries, order). User approves overall plan. Then Claude generates detailed README for milestone #1. Subsequent invocations auto-select the next undefined milestone.
- **D-08:** Milestone plan persisted in prd.md Milestones section -- natural home alongside requirements.
- **D-09:** Auto-select next undefined milestone on subsequent invocations. User can override to target a specific milestone.
- **D-10:** Auto-detect revision mode -- if milestone directory already exists, enter revision mode automatically. No flag needed.
- **D-11:** Feature checklist with multiSelect for affected features -- show all features with current status, user selects which are affected by scope change. Selected features reset to [ ] pending, completed features preserved.
- **D-12:** Load and revise existing README -- read existing content, ask what changed, revise only affected sections. Consistent with /define revision mode Phase 2 D-15.
- **D-13:** Fresh gate-3-review.md after revision -- prior review is no longer valid after milestone changes.

### Claude's Discretion
- Milestone grouping heuristics and ordering rationale
- Feature sizing estimation approach within DD-1 constraints
- Exact phrasing of approval prompts and tradeoff callouts
- How to handle edge cases when PRD has ambiguous feature boundaries
- Review checklist item generation from milestone contents
- Detection of "key tradeoffs" worth calling out in grouping/ordering
- README format and section structure for individual milestones

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIL-01 | Validates Gate 2 is approved in progress.txt before proceeding | Prerequisite check pattern from /design Step 1 (DES-01 implementation) |
| MIL-02 | Reads prd.md, ARCHITECTURE_AND_DESIGN.md, progress.txt as primary inputs; reads spike artifacts when referenced | Direct reading (D-02), no sub-agent; spike loading is user-referenced (D-04) |
| MIL-03 | Auto-increments milestone sequence number from existing milestones/ directories | Bash `ls milestones/` to count existing dirs, zero-pad next number |
| MIL-04 | Produces milestones/NN-name/README.md with Goal, Features, Dependencies, Ordering, Sizing, Configuration, Definition of Done | New asset: milestone-readme-template.md; DD-1 sizing constraints apply |
| MIL-05 | Produces milestones/NN-name/milestone-status.txt with feature entries at [ ] pending | progress-format.md milestone-status.txt section defines format |
| MIL-06 | Produces milestones/NN-name/reviews/gate-3-review.md checklist | Gate 3 static items from DD-13; review-checklist-template.md pattern |
| MIL-07 | Adds milestone summary line to progress.txt | progress-format.md Milestone Summary Line Format section |
| MIL-08 | Presents milestone breakdown for review focused on grouping, ordering, sizing, acceptance criteria | Produce-then-review pattern; DD-8 Gate 3 review focus areas |
| MIL-09 | Records Gate 3 as [~] In progress in progress.txt | Unique to Gate 3 -- stays open across invocations; closure via /project (D-05) |
| MIL-10 | Revision mode loads existing artifacts, offers revise rather than overwrite | Auto-detect by existing milestone dir (D-10); load-and-revise pattern (D-12) |
| MIL-11 | Revision mode identifies affected features, presents list for user confirmation before resetting | multiSelect feature checklist (D-11) |
| MIL-12 | Revision mode preserves completed features' status | Only reset features user explicitly identifies as affected (D-11, DD-6) |
| MIL-13 | Revision mode updates milestone summary in progress.txt and prd.md | Dual-file update with STATE-04 ordering (milestone-status.txt first, then progress.txt) |

</phase_requirements>

## Architecture Patterns

### Recommended Skill Bundle Structure

```
skills/project/milestone/
├── SKILL.md              # Flow controller (~180-200 lines)
├── references/
│   ├── gate-3-milestone.md         # Complete Gate 3 spec (first-invocation + subsequent)
│   ├── revision-mode.md            # Revision mode spec
│   ├── progress-format.md          # Verbatim copy from skills/project/references/
│   └── review-checklist-template.md # Gate 3 specific checklist template
└── assets/
    └── milestone-readme-template.md # README.md template for each milestone
```

### Pattern 1: Flow Controller SKILL.md

**What:** SKILL.md acts as a lightweight orchestrator (under 200 lines) that delegates complex gate logic to reference files loaded lazily at each step.

**When to use:** Always -- this is the established pattern from Phase 2 (/define at 197 lines) and Phase 3 (/design at 143 lines).

**Structure:**
```markdown
---
name: milestone
description: >
  Milestone breakdown from approved PRD and architecture doc. Supports
  defining milestones one at a time and revision mode for scope changes.
  Phrases like "define milestones", "milestone planning", "break into
  milestones", "revise milestone" are good triggers.
disable-model-invocation: true
---

# /milestone -- Milestone Planning (Gate 3)

## Rules
[standard rules: read fresh, produce-then-review, checklist completion,
 write-ordering, interactive prompts, no auto-dispatch]

## Prerequisites
[progress.txt exists, Gate 2 approved]

## Step 1 -- Detect Mode and State
[Read progress.txt, detect first-invocation vs subsequent vs revision mode]

## Step 2 -- First Invocation: Propose Milestone Plan
[Read gate-3-milestone.md reference, propose all milestones]

## Step 3 -- Define Individual Milestone
[Generate README, milestone-status.txt, gate-3-review.md for one milestone]

## Step 4 -- Review and Approval
[Produce-then-review cycle for the defined milestone]

## Step 5 -- Revision Mode
[Read revision-mode.md reference]

## Step 6 -- Completion Report
[Summary of artifacts created, next steps]

## Error Handling
[Standard error cases]
```

### Pattern 2: Two-Phase Flow (D-07)

**What:** First invocation proposes the overall milestone plan; subsequent invocations define individual milestones one at a time.

**How it works:**
1. First invocation: Read PRD + architecture doc. Propose milestone plan (count, summaries, order). Persist approved plan in `prd.md` Milestones section (D-08). Define milestone #1 in detail.
2. Subsequent invocations: Read `prd.md` Milestones section for the plan. Auto-select next undefined milestone (D-09) by scanning `milestones/` for existing dirs. User can override to target a specific one.

**Detection logic:**
- `prd.md` Milestones section is "(to be defined)" AND no `milestones/` dirs exist --> first invocation
- `prd.md` Milestones section is populated AND some milestones lack directories --> subsequent invocation
- Target milestone directory already exists --> revision mode (D-10)

### Pattern 3: Revision Mode Auto-Detection (D-10)

**What:** If the target milestone directory already exists when `/milestone` is invoked, enter revision mode automatically.

**Flow:**
1. Read existing `milestones/<NN>-<name>/README.md`
2. Read existing `milestones/<NN>-<name>/milestone-status.txt`
3. Present feature checklist with current status using multiSelect (D-11)
4. User selects affected features -- only those reset to `[ ]` pending
5. Ask "What changed?" -- focused revision on affected sections only (D-12)
6. Generate fresh `gate-3-review.md` (D-13 -- prior review invalidated)
7. Update `milestone-status.txt` (affected features reset)
8. Update `progress.txt` milestone summary line
9. Update `prd.md` milestone summary (1-2 sentence summary sync)

### Pattern 4: Gate 3 Unique Behavior

**What:** Gate 3 stays `[~] In progress` across multiple `/milestone` invocations. Closure is handled by `/project`, not by `/milestone`.

**Key differences from Gates 0-2:**
- Gates 0-2: single skill invocation produces artifact, review, approval. Gate transitions to `[x]`.
- Gate 3: each `/milestone` invocation produces ONE milestone's artifacts. Gate stays `[~]` until `/project` detects closure conditions (D-05, D-06).

**Closure conditions (checked by /project, NOT by /milestone):**
1. At least one milestone exists in `milestones/`
2. Every milestone has a completed `reviews/gate-3-review.md` (all items `[x]` or `[-]`)

**What /milestone writes to progress.txt:**
- First milestone created: Gate 3 line becomes `[~] Gate 3: Milestone Review  In progress`
- Each milestone created: adds/updates milestone summary line in `## Milestones` section
- /milestone NEVER writes `[x]` to Gate 3 -- only `/project` does this

### Anti-Patterns to Avoid

- **Closing Gate 3 from /milestone:** Gate 3 closure is /project's responsibility (D-05). /milestone only sets `[~]` In progress.
- **Auto-detecting spike artifacts:** Spikes are user-referenced only (D-04). Do not scan `docs/spikes/` automatically.
- **Spawning sub-agents for input reading:** No sub-agent needed (D-02). PRD and architecture doc are focused documents that fit in context.
- **Overwriting in revision mode:** Load and revise existing content (D-12). Never discard and regenerate.
- **Resetting all features on revision:** Only reset features the user explicitly identifies as affected (D-11, D-12, MIL-12).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Review checklist | Custom checklist format | review-checklist-template.md pattern | Consistent format across all gates; auto-generated items supplement static items |
| Progress file updates | Ad-hoc format strings | progress-format.md specification | Exact format matters for cross-skill parsing |
| milestone-status.txt | Custom status format | progress-format.md milestone-status.txt section | Four canonical markers only; format must match /plan and /build expectations |
| Milestone README structure | Freeform markdown | milestone-readme-template.md asset | Sections defined by MIL-04; consistent structure for /plan to consume |

## Common Pitfalls

### Pitfall 1: Write-Ordering Violation (STATE-04)

**What goes wrong:** Writing `progress.txt` before `milestone-status.txt` when both need updates. If a crash occurs mid-write, the summary file is updated but the source-of-truth is stale.
**Why it happens:** Natural inclination to update the "main" file first.
**How to avoid:** SKILL.md and reference files must specify: write `milestone-status.txt` first, then `progress.txt`. This is the STATE-04 contract.
**Warning signs:** Any step that updates both files without explicit ordering.

### Pitfall 2: Gate 3 Premature Closure

**What goes wrong:** /milestone writes `[x]` to Gate 3 in progress.txt after defining a milestone.
**Why it happens:** Following the pattern from Gates 0-2 where the skill that runs the gate also records its approval.
**How to avoid:** Gate 3 is explicitly `[~] In progress` only. Closure is /project's responsibility (D-05). SKILL.md must make this clear.
**Warning signs:** Any `[x]` write to the Gate 3 line from /milestone.

### Pitfall 3: Revision Mode Feature Reset Blast Radius

**What goes wrong:** Resetting all features to pending when only some are affected by a scope change.
**Why it happens:** Simpler to reset everything than to selectively reset.
**How to avoid:** multiSelect checklist presents ALL features with current status. Only features explicitly selected by the user are reset. Completed features not selected retain their `[x]` status (MIL-12).
**Warning signs:** Any code path that resets features without user confirmation.

### Pitfall 4: Milestone Plan Not Persisted in prd.md

**What goes wrong:** The overall milestone plan (count, summaries, order) exists only in conversation memory, not on disk.
**Why it happens:** Forgetting D-08 -- the plan must be written to the prd.md Milestones section.
**How to avoid:** After user approves the milestone plan on first invocation, use Edit to update prd.md Milestones section from "(to be defined)" to the approved plan.
**Warning signs:** prd.md Milestones section still says "(to be defined)" after first /milestone invocation.

### Pitfall 5: Inconsistent Directory Naming

**What goes wrong:** Milestone directory name doesn't match the format expected by downstream skills (/plan, /build, /project).
**Why it happens:** Using spaces, inconsistent casing, or forgetting zero-padding.
**How to avoid:** Format is always `milestones/<NN>-<kebab-case-name>/` where NN is zero-padded two digits. This matches the progress-format.md Milestone Summary Line Format.
**Warning signs:** Directories like `milestones/1-auth/` (no zero-pad) or `milestones/01-Core Auth/` (spaces).

### Pitfall 6: Review Checklist Path Differs from Other Gates

**What goes wrong:** Placing gate-3-review.md at `docs/reviews/gate-3-review.md` (like Gates 0-2).
**Why it happens:** Following the pattern from earlier gates without checking DD-13.
**How to avoid:** Gate 3 review goes at `milestones/<NN>-<name>/reviews/gate-3-review.md` (per-milestone, per DD-13 table). This is different from Gates 0-2 which use `docs/reviews/`.
**Warning signs:** Any reference to `docs/reviews/gate-3-review.md`.

## Code Examples

### Milestone Summary Line in progress.txt

```
[ ] Milestone 01: Core Auth  milestones/01-core-auth/  0/3 features complete
```

Source: `skills/project/references/progress-format.md` Milestone Summary Line Format section.

### milestone-status.txt Initial Content

```
# Milestone 01: Core Auth
# Status: [ ] pending  0 features, 0 complete

## Features

[ ] Feature 01.1: User Registration
    Plan: (not yet planned)

[ ] Feature 01.2: Session Management
    Plan: (not yet planned)

[ ] Feature 01.3: Password Reset
    Plan: (not yet planned)
```

Source: `skills/project/references/progress-format.md` milestone-status.txt Format section.

### Gate 3 In-Progress Line in progress.txt

```
[~] Gate 3: Milestone Review  In progress
```

Source: `skills/project/references/progress-format.md` Gate Entry Format section.

### Gate 3 Review Checklist Static Items (from DD-13)

```
- [ ] Does the milestone represent a coherent, deployable increment?
- [ ] Are features correctly grouped? Any that belong in a different milestone?
- [ ] Is the ordering correct given dependencies?
- [ ] Are the acceptance criteria specific and testable?
- [ ] Is the sizing realistic?
```

Source: `skills/project/DESIGN.md` DD-13 Gate 3 section.

### Prerequisite Check Pattern (from /design)

```markdown
## Prerequisites

- Working directory is the project root (where progress.txt lives).
- progress.txt must exist. If it does not, instruct the user to run /project
  first to bootstrap project state.
- Gate 2 must be [x] approved in progress.txt (MIL-01).
```

Source: `skills/project/design/SKILL.md` Prerequisites section.

### Revision Mode Feature Checklist (multiSelect pattern)

```markdown
Present the feature checklist using multiSelect:

- [x] Feature 01.1: User Registration (complete)
- [~] Feature 01.2: Session Management (in progress)
- [ ] Feature 01.3: Password Reset (pending)

"Which features are affected by this scope change? Select all that apply."

Only selected features will be reset to [ ] pending. Unselected features
retain their current status.
```

Source: Decision D-11 from CONTEXT.md.

## Artifacts to Create

This is the complete list of files this phase must produce:

| File | Purpose | Template/Pattern Source |
|------|---------|----------------------|
| `skills/project/milestone/SKILL.md` | Flow controller entry point | `/design` SKILL.md pattern (143 lines) |
| `skills/project/milestone/references/gate-3-milestone.md` | Complete Gate 3 spec for normal flow | `/design` `gate-2-design.md` pattern |
| `skills/project/milestone/references/revision-mode.md` | Revision mode spec | `/design` `refresh-mode.md` pattern |
| `skills/project/milestone/references/progress-format.md` | Verbatim copy of progress format | `skills/project/references/progress-format.md` (per D-04 Phase 2 decision) |
| `skills/project/milestone/references/review-checklist-template.md` | Gate 3 checklist template | `/design` `review-checklist-template.md` pattern |
| `skills/project/milestone/assets/milestone-readme-template.md` | README.md template per milestone | New -- sections from MIL-04 |
| `docs/skills/milestone.md` | Detail doc | Existing detail doc pattern |
| `docs/SKILLS.md` | Catalog entry update | Add row after Design |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual verification (Markdown skill, no application code) |
| Config file | none |
| Quick run command | `bash cicd/lint-markdown.sh` |
| Full suite command | `bash cicd/lint-markdown.sh` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIL-01 | Gate 2 prerequisite check | manual-only | Invoke /milestone without Gate 2 approved | N/A |
| MIL-02 | Reads prd.md, architecture doc, progress.txt | manual-only | Invoke /milestone with all inputs present | N/A |
| MIL-03 | Auto-increment sequence number | manual-only | Invoke /milestone with existing milestones/ dirs | N/A |
| MIL-04 | Produces milestone README.md with required sections | manual-only | Check README.md sections after invocation | N/A |
| MIL-05 | Produces milestone-status.txt with pending features | manual-only | Check milestone-status.txt after invocation | N/A |
| MIL-06 | Produces gate-3-review.md checklist | manual-only | Check reviews/gate-3-review.md after invocation | N/A |
| MIL-07 | Adds milestone summary line to progress.txt | manual-only | Check progress.txt after invocation | N/A |
| MIL-08 | Presents milestone for review | manual-only | Observe produce-then-review cycle | N/A |
| MIL-09 | Gate 3 stays [~] In progress | manual-only | Check progress.txt Gate 3 line after invocation | N/A |
| MIL-10 | Revision mode loads existing artifacts | manual-only | Invoke /milestone on existing milestone | N/A |
| MIL-11 | Revision mode presents feature checklist | manual-only | Invoke revision mode, observe multiSelect | N/A |
| MIL-12 | Revision mode preserves completed features | manual-only | Complete a feature, revise milestone, verify preserved | N/A |
| MIL-13 | Revision mode updates progress.txt and prd.md | manual-only | Check both files after revision | N/A |

**Justification for manual-only:** This project's "code" is Markdown prompt engineering -- there is no application runtime to test programmatically. Validation is done by invoking the skill in a Claude Code session and observing behavior. The markdown linter validates formatting compliance.

### Sampling Rate
- **Per task commit:** `bash cicd/lint-markdown.sh`
- **Per wave merge:** `bash cicd/lint-markdown.sh`
- **Phase gate:** Full manual walkthrough of /milestone (first invocation, subsequent invocation, revision mode)

### Wave 0 Gaps
None -- existing markdown linting infrastructure covers formatting validation. No additional test framework needed.

## Open Questions

1. **Milestone README.md exact sections**
   - What we know: MIL-04 specifies Goal, Features, Dependencies, Ordering, Sizing, Configuration, Definition of Done
   - What's unclear: Whether "Configuration" means milestone-specific config or references back to prd.md Configuration
   - Recommendation: Milestone Configuration = any milestone-specific config parameters not in prd.md. If none, omit the section (per prd-template.md "Omit sections that don't apply" pattern).

2. **First invocation: define milestone #1 in same session or separate?**
   - What we know: D-07 says "Then Claude generates detailed README for milestone #1" implying same session
   - What's unclear: Whether this is mandatory or if the user can stop after approving the overall plan
   - Recommendation: Default to defining #1 in the same session (per D-07), but allow the user to defer ("I'll define milestones later") by leaving the Milestones section populated but no directories created yet.

3. **prd.md Milestones section format for the plan**
   - What we know: D-08 says milestone plan persists in prd.md Milestones section
   - What's unclear: Exact format of the plan entries
   - Recommendation: Use a numbered list with 1-2 sentence summary per milestone, matching the "milestone summaries" language from the PRD template and DD-1. Example: `1. **Core Auth** -- User registration, login, session management. First deployable increment.`

## Sources

### Primary (HIGH confidence)
- `skills/project/DESIGN.md` DD-1, DD-4, DD-6, DD-7, DD-8, DD-13 -- authoritative design decisions
- `skills/project/references/progress-format.md` -- state file format specification
- `skills/project/define/SKILL.md` -- flow controller pattern (197 lines)
- `skills/project/design/SKILL.md` -- flow controller pattern (143 lines)
- `skills/project/define/references/review-checklist-template.md` -- review checklist template pattern
- `skills/project/design/references/review-checklist-template.md` -- gate-specific checklist adaptation
- `skills/project/define/references/gate-1-prd.md` -- gate reference file pattern
- `skills/project/design/references/gate-2-design.md` -- gate reference file pattern
- `.planning/codebase/CONVENTIONS.md` -- skill file conventions
- `.planning/codebase/STRUCTURE.md` -- directory layout, skill bundle structure
- `.planning/phases/04-milestone-gate-3/04-CONTEXT.md` -- locked implementation decisions

### Secondary (MEDIUM confidence)
- None -- all findings come from primary project sources

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no external libraries; all patterns established in prior phases
- Architecture: HIGH -- direct extension of /define and /design patterns with well-documented decisions
- Pitfalls: HIGH -- pitfalls derived from concrete design constraints (STATE-04, DD-13 paths, D-05 closure)

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable -- internal project conventions, no external dependencies)
