# /milestone

**Source:** `skills/project/milestone/`
**Command:** `/milestone`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Milestone planning skill that breaks an approved PRD and architecture document into milestone-scoped feature breakdowns with acceptance criteria, ordering, and sizing. First invocation proposes the overall milestone plan; subsequent invocations define individual milestones one at a time. Supports revision mode for scope changes to existing milestones with selective feature reset. Gate 3 stays open (`[~] In progress`) across invocations -- closure is handled by `/project` when all milestones have completed reviews.

## When to Use

- Planning milestones after architecture approval (Gate 2 complete)
- Breaking PRD scope into deployable increments
- Defining features and acceptance criteria for a specific milestone
- Revising an existing milestone after scope changes
- Continuing milestone definition (subsequent invocations auto-select next)

## When NOT to Use

- When you want to check project status or get routing (use `/project`)
- When you want to define project scope or create a PRD (use `/define` -- runs Gates 0/WB/1)
- When you want to design system architecture (use `/design` -- Gate 2)
- When you want to plan a specific feature's implementation (use `/plan-feature`)
- When you want to implement code (use `/build`)

## Behavior

### 1. Mode Detection

On invocation, `/milestone` reads `progress.txt` and `prd.md` to determine entry mode:

- **Gate 2 not approved:** Declines with prerequisite message (run `/design` first)
- **First invocation:** prd.md Milestones section is "(to be defined)" and no milestone directories exist -- proposes overall milestone plan
- **Subsequent invocation:** Milestone plan exists but some milestones lack directories -- auto-selects next undefined milestone
- **Revision mode:** Target milestone directory already exists -- loads existing artifacts for focused revision
- **All milestones defined:** All milestones have directories -- suggests `/project` for gate status

### 2. First Invocation: Milestone Plan

Reads `prd.md` and `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`. Proposes full milestone breakdown with sequence numbers, names, summaries, and ordering rationale. Calls out 2-3 key tradeoffs in grouping/ordering decisions. After approval, persists the plan in `prd.md` Milestones section and defines milestone #1.

### 3. Subsequent Invocation

Reads the approved milestone plan from `prd.md`. Auto-selects the next milestone that lacks a directory. User can override to target a specific milestone.

### 4. Milestone Definition

For each milestone: generates `.project/{slug}/milestones/<NN>-<name>/README.md` (goal, features with acceptance criteria, dependencies, ordering, sizing, definition of done), `milestone-status.txt` (features at pending status), and `reviews/gate-3-review.md` (checklist with DD-13 static items plus auto-generated content items). Updates `progress.txt` with milestone summary line and Gate 3 as in-progress. Presents for review with Approve/Revise/Partial options.

### 5. Revision Mode

Loads existing milestone README and status file. Presents feature checklist with current statuses via multiSelect -- user selects which features are affected by scope change. Only selected features are reset to pending; completed features retain their status. Asks what changed and applies focused revision to the README. Generates fresh review checklist (prior review invalidated). Updates milestone-status.txt, progress.txt, and prd.md.

### 6. Completion Report

Displays summary of artifacts created/updated, state file changes, and suggests next step (`/milestone` for next milestone or `/project` for gate status).

## Artifacts

| File | Purpose | Gate |
|------|---------|------|
| `.project/{slug}/milestones/<NN>-<name>/README.md` | Milestone feature breakdown with acceptance criteria | Gate 3 |
| `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt` | Per-feature status tracking | Gate 3 |
| `.project/{slug}/milestones/<NN>-<name>/reviews/gate-3-review.md` | Milestone review checklist for offline reviewers | Gate 3 |
| `prd.md` (updated) | Milestones section populated with plan | Gate 3 |
| `progress.txt` (updated) | Gate 3 in-progress, milestone summary lines | Gate 3 |

## Skill Files

```
skills/project/milestone/
+-- SKILL.md                              # Flow controller (~150-180 lines)
+-- references/
|   +-- gate-3-milestone.md               # Complete Gate 3 specification
|   +-- revision-mode.md                  # Revision mode specification
|   +-- progress-format.md               # Progress file format (verbatim copy)
|   +-- review-checklist-template.md     # Gate 3 review checklist template
+-- assets/
    +-- milestone-readme-template.md     # README.md template per milestone
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/project` | Routes users to `/milestone` when Gate 2 is approved; detects Gate 3 closure when all milestones have completed reviews |
| `/define` | Produces `prd.md` that `/milestone` reads as primary input; `/milestone` updates prd.md Milestones section |
| `/design` | Produces `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md` that `/milestone` reads as secondary input |
| `/plan-feature` | Consumes milestone `README.md` and `milestone-status.txt` as inputs for feature planning |
| `/build` | Consumes feature plans produced by `/plan-feature`; updates `milestone-status.txt` on feature completion |
