# Project Codex Skills

## Overview

The Project Codex skill suite in `codex-skills/project/` is a manual, gated delivery workflow for Codex. It keeps project context in repository files, routes the user through explicit phase skills, and prevents later phases from starting before their prerequisite artifacts are approved.

The suite is intentionally explicit. Codex should not auto-trigger these skills from conversational hints. The user invokes a specific skill such as `$project` or `$project-build`, and that skill either performs its owned phase or recommends the next explicit skill to run.

## Skills

| Skill | Source | Responsibility |
|---|---|---|
| `$project` | `codex-skills/project/SKILL.md` | Orchestrates status, bootstrap, validation, and routing |
| `$project-define` | `codex-skills/project/define/SKILL.md` | Owns Gates 0, WB, and 1 |
| `$project-design` | `codex-skills/project/design/SKILL.md` | Owns Gate 2 and architecture refresh |
| `$project-milestone` | `codex-skills/project/milestone/SKILL.md` | Owns Gate 3 milestone definition and revision |
| `$project-plan-feature` | `codex-skills/project/plan-feature/SKILL.md` | Owns Gate 4 feature planning |
| `$project-build` | `codex-skills/project/build/SKILL.md` | Implements approved feature plans |
| `$project-spike` | `codex-skills/project/spike/SKILL.md` | Runs isolated technical research and red-team review |

Each skill includes an `agents/openai.yaml` file with display metadata and `allow_implicit_invocation: false`, matching the manual-only behavior described by each `SKILL.md`.

## Lifecycle

The normal flow is:

1. `$project` bootstraps `progress.txt` or reports current project status.
2. `$project-define` performs Codebase Alignment, optional Working Backwards, and Scope Review.
3. `$project-design` creates or refreshes `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`.
4. `$project-milestone` defines the next milestone and milestone status file.
5. `$project-plan-feature` creates an implementation plan for one feature.
6. `$project-build` implements the approved plan sub-feature by sub-feature.
7. `$project` validates state and routes to the next valid action.

`$project-spike` can be used after bootstrap whenever a technical question needs investigation. Post-Gate 1 spikes appear as alternatives in `$project` routing when contextually relevant.

## Gates

| Gate | Owned By | Meaning | Typical Artifact |
|---|---|---|---|
| Gate 0: Codebase Alignment | `$project-define` | Brownfield codebase assessment, or skipped for greenfield projects | `.project/{slug}/docs/codebase-assessment.md` |
| Gate WB: Working Backwards | `$project-define` and `$project` state decisions | Optional customer-outcome exercise | `.project/{slug}/docs/working-backwards.md` |
| Gate 1: Scope Review | `$project-define` | Approved PRD | `prd.md` |
| Gate 2: Design Review | `$project-design` | Approved architecture and design | `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md` |
| Gate 3: Milestone Review | `$project-milestone`, closed by `$project` | Milestone sequence and one or more approved milestones | `.project/{slug}/milestones/<NN>-<name>/README.md` |
| Gate 4: Feature Planning | `$project-plan-feature` | One approved implementation plan | `.project/{slug}/milestones/<NN>-<name>/plans/<feature>.md` |

Gate 4 is represented in milestone status rather than the top-level `progress.txt` gate list. A feature marked `[~] planned, awaiting build` is ready for `$project-build`.

## State Files

### `progress.txt`

`progress.txt` is the project-level state file. `$project` creates it during bootstrap and every project skill reads it fresh before acting.

The bootstrap shape is:

```text
# Progress: <Project Name>
# Project-ID: <slug>
# Created: <ISO date>
# Status: [ ] pending  [~] in progress  [x] complete  [-] skipped

## Gates

[ ] Gate 0: Codebase Alignment
[ ] Gate WB: Working Backwards
[ ] Gate 1: Scope Review
[ ] Gate 2: Design Review
[ ] Gate 3: Milestone Review

## Milestones

(none yet)

## Spikes

(none yet)
```

For greenfield projects, Gate 0 is recorded as:

```text
[-] Gate 0: Codebase Alignment  Skipped (greenfield)
```

### `milestone-status.txt`

Each milestone has a detailed status file at `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt`. It tracks feature status, plan paths, sub-feature counts, and notes:

```text
# Milestone 01: Core Auth
# Status: [~] in progress  3 features, 1 complete

## Features

[x] Feature 01.1: User Registration
    Plan: .project/{slug}/milestones/01-core-auth/plans/user-registration.md
    Sub-features: 3/3 complete

[~] Feature 01.2: Session Management
    Plan: .project/{slug}/milestones/01-core-auth/plans/session-management.md
    Sub-features: 1/4 complete
```

### Output Artifact Layout

All generated documentation and milestone artifacts are grouped under `.project/{slug}/`. `progress.txt` and `prd.md` remain at the project root.

```
progress.txt                            (project root)
prd.md                                  (project root)

.project/{slug}/
  docs/
    codebase-assessment.md             ($project-define, Gate 0)
    working-backwards.md               ($project-define, Gate WB)
    ARCHITECTURE_AND_DESIGN.md         ($project-design, Gate 2)
    spikes/
      {topic}.md                       ($project-spike)
    reviews/
      gate-0-review.md
      gate-wb-review.md
      gate-1-review.md
      gate-2-review.md
  milestones/
    {NN}-{name}/
      README.md                        ($project-milestone)
      milestone-status.txt             ($project-milestone, $project-build)
      plans/
        {feature}.md                   ($project-plan-feature, $project-build)
      reviews/
        gate-3-review.md
        gate-4-{feature}-review.md
```

The `Project-ID` slug is set during bootstrap and stored in `progress.txt` as `# Project-ID: <slug>`. Every skill reads this header to derive the base path at runtime — no path is hardcoded in any skill.

### Status Markers

Only these four markers are valid:

| Marker | Meaning |
|---|---|
| `[x]` | Complete |
| `[~]` | In progress |
| `[ ]` | Pending |
| `[-]` | Skipped or not applicable |

Skills must not introduce alternate status notation such as `[done]`, `[complete]`, or `[in-progress]`.

## Write Rules

The suite is designed around conservative state writes:

- `$project` writes only during bootstrap, Gate WB state decisions, and Gate 3 closure.
- `$project-define` updates `progress.txt` for Gates 0, WB, and 1.
- `$project-design` updates `progress.txt` for Gate 2.
- `$project-milestone` writes milestone artifacts and updates `progress.txt`.
- `$project-plan-feature` writes only the active `milestone-status.txt`.
- `$project-build` updates `milestone-status.txt` first, then `progress.txt`.
- `$project-spike` writes or updates `.project/{slug}/docs/spikes/<topic>.md` and spike entries in `progress.txt`.

When both milestone-level and project-level state change, `milestone-status.txt` is written first. This preserves the detailed source of truth and lets `$project` detect any divergence during the next status read.

## `$project` Orchestrator

`$project` is the entry point. It bootstraps missing state, reads existing state, validates artifacts, displays a status report, and recommends one next action.

It does not dispatch other skills. It tells the user which explicit skill to run next:

- `$project-define`
- `$project-design`
- `$project-milestone`
- `$project-plan-feature`
- `$project-build`
- `$project-spike`

### Bootstrap

If `progress.txt` is missing, `$project` creates it using `references/progress-format.md`. It determines whether the project is greenfield or brownfield and records Gate 0 accordingly.

If `progress.txt` exists but is empty, incomplete, or malformed, `$project` reports the malformed state and stops. It does not overwrite or re-bootstrap existing state.

### Validation

On every non-bootstrap run, `$project` validates:

- Approved gate artifact paths exist on disk.
- Milestone counts in `progress.txt` match each milestone's `milestone-status.txt`.

Missing approved artifacts are informational warnings. Milestone count divergence blocks routing until the user acknowledges the discrepancy because routing based on inconsistent state can send the user to the wrong phase.

### Routing

Routing is first-match based on `references/routing-logic.md`. Key decisions include:

- No approved gates: recommend `$project-define`.
- Gate 1 approved but Gate 2 missing: recommend `$project-design`.
- Gate 2 approved with no milestones: recommend `$project-milestone`.
- Active milestone has unplanned features: recommend `$project-plan-feature`.
- A feature is planned and awaiting build: recommend `$project-build`.
- All active milestone features are complete: recommend another `$project-milestone` or Gate 3 closure, depending on state.
- Goals changed or PRD revision intent: route to `$project-define` revision mode.
- Milestone re-planning intent: route to `$project-milestone` revision mode.

## `$project-define`

`$project-define` owns project definition. It requires a bootstrapped `progress.txt`.

Modes:

- Brownfield: creates `.project/{slug}/docs/codebase-assessment.md` for Gate 0.
- Greenfield: records Gate 0 as skipped.
- Gate WB resume: resolves a previously deferred Working Backwards decision.
- PRD revision: revises an approved `prd.md` when project goals change.

Outputs:

- `.project/{slug}/docs/codebase-assessment.md`
- `.project/{slug}/docs/working-backwards.md` when Gate WB is accepted
- `prd.md`
- `.project/{slug}/docs/reviews/gate-0-review.md`
- `.project/{slug}/docs/reviews/gate-wb-review.md`
- `.project/{slug}/docs/reviews/gate-1-review.md`

Each gate uses a produce-then-review pattern. Approval is recorded only after checklist items are marked `[x]` or `[-]` with a reason.

## `$project-design`

`$project-design` owns Gate 2. It requires Gate 1 approval.

Normal mode creates `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md` from the PRD and available context using `assets/architecture-template.md`.

Refresh mode applies when Gate 2 is already approved or the user asks to refresh architecture. The skill scans feature plans for recorded architectural deviations, asks which deviations to consolidate, and updates the architecture document without overwriting existing content unless approved.

Outputs:

- `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`
- `.project/{slug}/docs/reviews/gate-2-review.md`
- Updated Gate 2 entry in `progress.txt`

## `$project-milestone`

`$project-milestone` owns Gate 3 planning and revision. It requires Gate 2 approval.

On first invocation, it proposes the full milestone sequence and writes the approved sequence into the PRD Milestones section. It then defines one milestone at a time.

Outputs:

- `.project/{slug}/milestones/<NN>-<name>/README.md`
- `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt`
- Gate 3 review file
- Updated Gate 3 and milestone summary entries in `progress.txt`

It never closes Gate 3. `$project` offers Gate 3 closure when all milestones are complete.

## `$project-plan-feature`

`$project-plan-feature` owns Gate 4 planning for one feature. It requires at least one milestone directory with `milestone-status.txt`.

The skill chooses the first pending feature in the active milestone unless the user names a specific feature. It creates or revises a feature implementation plan and updates only `milestone-status.txt`.

Outputs:

- `.project/{slug}/milestones/<NN>-<name>/plans/<feature>.md`
- Gate 4 review file
- Updated feature entry marked `[~] planned, awaiting build`

It does not update `progress.txt`; project-level feature counts change during build completion.

## `$project-build`

`$project-build` implements a Gate 4-approved feature. It reads `progress.txt`, the active `milestone-status.txt`, and the feature plan fresh from disk.

The build skill:

- Auto-resumes from the first unchecked sub-feature.
- Requires one commit per completed sub-feature.
- Refreshes codebase assessment before reading the feature plan.
- Records architectural deviations when implementation contradicts the plan or architecture document.
- Runs the feature's test command once all sub-features are complete.
- Updates `milestone-status.txt` first, then `progress.txt`.

Outputs include code changes, commits, status updates, test results, and any recorded deviation notes.

## `$project-spike`

`$project-spike` handles technical research. It requires a bootstrapped project and writes spike artifacts under `.project/{slug}/docs/spikes/`.

The skill intentionally separates research and red-team review into different Codex sub-agent contexts. If isolated sub-agent delegation is unavailable, the skill stops rather than collapsing the two passes into one local context.

Outputs:

- `.project/{slug}/docs/spikes/<topic>.md`
- New or updated spike entries in `progress.txt`
- Dated follow-up entries when revisiting an existing spike

Resolved spikes remain in `progress.txt` for auditability.

## Review Checklists

Definition, design, milestone, and feature planning gates use review checklist files under `.project/{slug}/docs/reviews/`. Checklists combine static gate requirements with content-specific review items.

Approval requires every checklist item to be:

- `[x]` verified, or
- `[-]` not applicable with a reason.

This rule prevents a gate from being approved while unresolved review concerns remain.

## Status Report

`$project` reports status directly in chat. It includes:

- Project status header
- Optional Gate WB pending reminder
- Gates with approval dates and artifact paths
- Active milestone with per-feature status
- Completed milestone summaries
- Upcoming milestone summaries
- Open and resolved spikes
- One recommended action plus valid alternatives

Missing artifact warnings appear inline and do not block routing. Milestone divergence warnings appear inline and replace the recommendation with an action-required message until acknowledged.

## File Map

| Path | Role |
|---|---|
| `codex-skills/project/SKILL.md` | Main orchestrator workflow |
| `codex-skills/project/references/progress-format.md` | `progress.txt` and `milestone-status.txt` format |
| `codex-skills/project/references/routing-logic.md` | Routing table, Gate WB handling, Gate 3 closure, validation behavior |
| `codex-skills/project/references/status-report-format.md` | User-facing status report format |
| `codex-skills/project/define/` | Gate 0, WB, and 1 workflow and PRD template |
| `codex-skills/project/design/` | Gate 2 workflow and architecture template |
| `codex-skills/project/milestone/` | Gate 3 workflow and milestone template |
| `codex-skills/project/plan-feature/` | Gate 4 workflow and feature plan template |
| `codex-skills/project/build/` | Implementation workflow, codebase refresh, and deviation recording |
| `codex-skills/project/spike/` | Research, red-team review, and spike artifact format |

## Operating Principles

- Read state fresh from disk before acting.
- Route explicitly; do not auto-invoke the next skill.
- Preserve artifact formats defined in reference files.
- Prefer source-of-truth-first writes for milestone state.
- Block routing on state divergence, not on missing optional artifacts.
- Keep resolved spikes and completed milestones visible for audit history.
- Use revision and refresh modes for changed requirements, architecture drift, and milestone re-planning instead of rewriting unrelated artifacts.
