# /design

**Source:** `skills/project/design/`
**Command:** `/design`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Architecture and design specification skill that produces `docs/ARCHITECTURE_AND_DESIGN.md` from an approved PRD and optional codebase assessment. Uses an agent-based deep codebase scan (15-30 files through an architecture lens) to inform design decisions. Supports section-by-section partial approval with tradeoff callouts before the approval checklist. Gate 2 approval is recorded in `progress.txt`. Refresh mode consolidates accumulated architectural deviations from feature plans into an updated architecture document.

## When to Use

- Designing system architecture after PRD approval (Gate 1 complete)
- Creating the architecture and design document
- Reviewing technical choices and tradeoffs
- Refreshing the architecture doc after implementation deviations accumulate
- Updating design decisions based on what was learned during build

## When NOT to Use

- When you want to check project status or get routing (use `/project`)
- When you want to define project scope or create a PRD (use `/define` -- runs Gates 0/WB/1)
- When you want to plan milestones (use `/milestone` -- requires Gate 2 approved)
- When you want to plan a specific feature (use `/plan-feature`)
- When you want to implement code (use `/build`)

## Behavior

### 1. Mode Detection

On invocation, `/design` reads `progress.txt` and determines entry mode:

- **Gate 1 not approved:** Declines with prerequisite message (run `/define` first)
- **Gate 2 not approved:** Normal mode -- proceeds to architecture generation (integrates into existing doc if one is found, or creates from scratch)
- **Gate 2 approved + architecture doc exists + refresh intent:** Refresh mode
- **Gate 2 approved + no refresh intent:** Offers Refresh or Status check

### 2. Architecture Generation (Normal Mode)

Reads `prd.md` and `docs/codebase-assessment.md` (if exists). Spawns an architecture sub-agent to scan 15-30 files focusing on component boundaries, data flow patterns, interface contracts, and technology choices. Always spawns the agent, even on greenfield projects.

**If `docs/ARCHITECTURE_AND_DESIGN.md` does not exist:** Creates the document from scratch using the template with 6 sections: Design Decisions (numbered table), Component Inventory, Data Flow, File Organization, Deployment & Operations, Security Considerations.

**If `docs/ARCHITECTURE_AND_DESIGN.md` already exists:** Treats the existing document as authoritative and integrates new content into it. Preserves all existing entries, adds new design decisions and components identified from the PRD and scan, and uses the Edit tool (not Write) to avoid overwriting prior content. Contradictions with the current PRD are surfaced as tradeoff callouts for user review.

### 3. Design Review

Presents the full architecture document, then calls out 2-4 design decisions with the most significant tradeoffs. Offers three review options: Approve (proceed to checklist), Revise (focused changes), or Partial Approve (section-by-section checklist where unchecked sections get focused revision). Generates `docs/reviews/gate-2-review.md` with static checklist items plus content-specific auto-generated items. All items must be resolved before gate approval.

### 4. Refresh Mode

Scans `milestones/*/plans/*.md` for Architectural Deviations sections. If zero deviations found, reports the doc is current and exits. Otherwise presents each deviation with its original design decision, lets the user select which to consolidate via multiSelect, applies changes, and presents the updated doc for section-by-section review.

### 5. Completion Report

Displays summary of artifacts created/updated and suggests next step (`/milestone` for Gate 3 after normal mode, or `/project` after refresh).

## Artifacts

| File | Purpose | Gate |
|------|---------|------|
| `docs/ARCHITECTURE_AND_DESIGN.md` | System-level architecture and design specification | Gate 2 |
| `docs/reviews/gate-2-review.md` | Design review checklist for offline reviewers | Gate 2 |
| `progress.txt` (updated) | Gate 2 approval entry with date and artifact path | Gate 2 |

## Skill Files

```
skills/project/design/
├── SKILL.md                              # Flow controller (~150 lines)
├── references/
│   ├── gate-2-design.md                  # Complete Gate 2 specification
│   ├── refresh-mode.md                   # Refresh mode specification
│   ├── progress-format.md                # Progress file format (verbatim copy)
│   └── review-checklist-template.md      # Gate 2 review checklist template
└── assets/
    └── architecture-template.md          # Template for ARCHITECTURE_AND_DESIGN.md
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/project` | Reads `progress.txt` to route users to `/design` when Gate 1 is approved |
| `/define` | Produces `prd.md` and `docs/codebase-assessment.md` that `/design` reads as inputs |
| `/milestone` | Consumes `docs/ARCHITECTURE_AND_DESIGN.md` as input for milestone planning |
| `/plan-feature` | Consumes `docs/ARCHITECTURE_AND_DESIGN.md` for feature implementation plans |
| `/build` | Records architectural deviations that `/design` refresh mode consolidates |
