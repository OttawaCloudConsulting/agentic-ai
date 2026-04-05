# /define

**Source:** `skills/project/define/`
**Command:** `/define`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Single-session project definition skill that runs Gates 0, WB, and 1 as one continuous conversation. Produces a codebase assessment (brownfield projects), an optional Working Backwards document, and an approved Product Requirements Document (PRD). All three gates use a produce-then-review pattern where Claude creates the full artifact, presents it for review, and supports in-session revision before gate approval. Each gate has a structured review checklist that must be fully resolved before approval is recorded in `progress.txt`.

## When to Use

- Starting project definition for a new or existing project
- Creating a PRD from scratch
- Assessing an existing codebase before planning changes
- Running a Working Backwards exercise to validate customer outcomes
- Revising an existing PRD when project goals change

## When NOT to Use

- When you want to check project status or get routing (use `/project`)
- When you want to design architecture (use `/design` -- requires Gate 1 approved)
- When you want to plan milestones (use `/milestone` -- requires Gate 2 approved)
- When you want to implement code (use `/build`)

## Behavior

### 1. Mode Detection

On invocation, `/define` reads `progress.txt` and determines the entry mode:

- **Fresh brownfield:** Gate 0 not yet approved, existing codebase detected -- starts at Gate 0
- **Fresh greenfield:** No src/app/lib directories, no dependency manifests, fewer than 5 non-config files -- skips Gate 0, proceeds to Gate WB offer
- **Gate WB resume:** Gate WB is in Pending state from a previous session -- re-prompts for WB decision
- **Revision mode:** `prd.md` exists and Gate 1 is approved and user signals revision intent -- jumps directly to Gate 1 revision flow

### 2. Gate 0: Codebase Assessment (brownfield only)

Spawns a sub-agent to scan 20-40 codebase files, synthesizes findings into `docs/codebase-assessment.md` with sections covering project overview, file organization, detected patterns, dependency graph, assumptions, patterns to deviate from, open questions, and recent changes. User reviews and can revise before approval.

### 3. Gate WB: Working Backwards (optional)

Offers the user a Working Backwards exercise with three options: proceed, skip, or defer. When accepted, conducts a 3-round interview (customer/problem, solution/experience, internal feasibility) and produces `docs/working-backwards.md` with Press Release, External FAQ, and Internal FAQ sections.

### 4. Gate 1: Scope Review (PRD)

Silently re-reads `docs/codebase-assessment.md` from disk to mitigate context rot. If Working Backwards was completed, reads that document as context (does not auto-populate PRD sections). Conducts a 5-round interview covering Scope, Inputs/Outputs, Security, Operational concerns, and Milestone Scoping. Produces `prd.md` using an adapted template (no Architecture or Features sections -- those are handled by /design and /milestone respectively).

Supports partial approval: user can approve individual PRD sections while requesting revision on others. Sections are independently approvalable via a checklist.

### 5. Revision Mode

When invoked on a project with an existing approved PRD, reads the current `prd.md` and conducts a focused interview on what changed. Revises only affected sections. After approval, surfaces a list of downstream artifacts that may need re-review (architecture doc, milestone READMEs, feature plans) but does not automatically reset any of them -- the user decides which need attention.

### Review Checklists

Each gate produces a review checklist file at `docs/reviews/gate-{0,wb,1}-review.md`. Checklists combine gate-specific static items with auto-generated content-specific items. All items must be resolved (`[x]` verified or `[-]` N/A with reason) before gate approval is recorded.

## Artifacts

| File | Read/Write | When |
|------|-----------|------|
| `progress.txt` | Read | Every invocation (mode detection) |
| `progress.txt` | Write | Gate 0, WB, and 1 approval recording |
| `docs/codebase-assessment.md` | Write | Gate 0 (brownfield) |
| `docs/codebase-assessment.md` | Read | Gate 1 start (context refresh, DEF-16) |
| `docs/working-backwards.md` | Write | Gate WB (when approved) |
| `docs/working-backwards.md` | Read | Gate 1 start (context, when exists) |
| `prd.md` | Write | Gate 1 |
| `prd.md` | Read | Revision mode |
| `docs/reviews/gate-0-review.md` | Write | Gate 0 checklist |
| `docs/reviews/gate-wb-review.md` | Write | Gate WB checklist |
| `docs/reviews/gate-1-review.md` | Write | Gate 1 checklist |

## Skill Files

- `skills/project/define/SKILL.md` -- Main workflow (entry point, flow control)
- `skills/project/define/references/gate-0-codebase.md` -- Gate 0 full specification
- `skills/project/define/references/gate-wb-working-backwards.md` -- Gate WB full specification
- `skills/project/define/references/gate-1-prd.md` -- Gate 1 full specification
- `skills/project/define/references/review-checklist-template.md` -- Shared review checklist format
- `skills/project/define/references/progress-format.md` -- Progress.txt format specification (local copy)
- `skills/project/define/assets/prd-template.md` -- Adapted PRD output template

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/project` | Routes to /define; must be run first to create progress.txt |
| `/design` | Next skill after /define; reads prd.md and codebase-assessment.md |
| `/milestone` | Downstream; reads prd.md for milestone breakdown |
| `/spike` | Can be used alongside /define for technical research |
| `/create-prd` | Predecessor skill; /define's Gate 1 is forked from create-prd |
