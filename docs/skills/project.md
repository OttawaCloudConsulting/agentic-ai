# /project

**Source:** `skills/project/`
**Command:** `/project`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Project orchestrator that bootstraps state on first run and routes users to the correct next skill on every subsequent invocation. `/project` is the single entry point to the project skill suite. It reads `progress.txt` and all `milestone-status.txt` files, validates artifact existence and milestone consistency, displays a structured status report, and recommends what to do next. Read-only after bootstrap -- the initial creation of `progress.txt` is the only time `/project` writes to disk.

## When to Use

- Starting a new project (triggers bootstrap -- creates `progress.txt` with gate entries)
- Checking project status ("where am I?", "project status")
- Deciding what to do next ("what's next?")
- After completing a phase and needing routing to the next skill
- When project goals have changed and you need re-planning routing

## When NOT to Use

- When you want to create or revise a PRD (use `/define`)
- When you want to implement code (use `/build`)
- When you want to research a technical question (use `/spike`)
- When you want to design architecture (use `/design`)

## Behavior

### 1. Bootstrap (first run)

On the very first invocation, if `progress.txt` does not exist, `/project` creates it with gate entries and empty milestone/spike sections. This is the only time `/project` writes to disk.

- **Greenfield projects:** Gate 0 (Codebase Alignment) is recorded as `[-] Skipped (greenfield)` since there is no existing codebase to assess.
- **Brownfield projects:** Gate 0 is recorded as `[ ]` (not started), ready for `/define` to perform codebase assessment.

Gate WB (Working Backwards) is included as a gate entry in Pending or Not Started state depending on whether the customer outcome is clear.

### 2. Status Report (subsequent runs)

Reads `progress.txt` and all `milestones/*/milestone-status.txt` files. Displays a structured summary:

- **Gates:** Checklist with completion dates (e.g., `[x] Gate 0: Codebase Alignment -- 2026-03-15`)
- **Active milestone:** Expanded view with per-feature status, sub-feature progress, and notes
- **Completed milestones:** One-line summaries with completion dates
- **Upcoming milestones:** One-line summaries showing they are not yet started
- **Spikes:** All spikes (both open and resolved) in a dedicated section

**Validation checks run on every invocation:**

- **Artifact existence:** For each approved gate, checks that the expected artifact file exists on disk. Missing artifacts produce an inline warning directly after the affected gate entry. These warnings are informational only and do not block routing.
- **Milestone consistency:** Compares `progress.txt` milestone summary lines against the corresponding `milestone-status.txt` files. Divergence (e.g., feature count mismatch, status disagreement) blocks routing until the user acknowledges the inconsistency.

### 3. Routing

Recommends the next skill to run based on current project state. Displays one primary recommendation (highlighted) plus 2-3 context-sensitive alternatives. Only actions valid for the current project state are shown.

- Routes to `/define` for Gates 0, WB, and 1
- Routes to `/design` for Gate 2
- Routes to `/milestone` for Gate 3
- Routes to `/plan` for Gate 4
- Routes to `/build` for implementation
- Routes to `/spike` when technical research is needed

**Re-planning detection:** When the user signals that goals have changed (e.g., "goals changed", "re-plan", "revise PRD"), `/project` detects the intent and routes to `/define` in revision mode. When the user signals milestone re-planning, routes to `/milestone` in revision mode.

## Gate WB Handling

Working Backwards is an optional gate offered when the customer outcome is unclear. When no `working-backwards.md` exists and customer outcome is unclear, `/project` offers Gate WB with a brief explanation of the Working Backwards approach (2-3 sentences) plus three options:

- **Yes** -- proceed with Working Backwards via `/define`
- **Skip** -- mark Gate WB as skipped and continue
- **Defer** -- mark Gate WB as Pending for later decision

When Gate WB is in Pending state on a subsequent invocation, `/project` shows a gentle reminder at the top of the status report but still displays the full status report. The pending decision is highlighted but does not suppress or block status output.

## Artifacts

| File | Read/Write | When |
|------|-----------|------|
| `progress.txt` | Write (once) | Bootstrap only |
| `progress.txt` | Read | Every invocation after bootstrap |
| `milestones/*/milestone-status.txt` | Read | Every invocation (for consistency validation) |
| Gate artifact files | Read (existence check) | Every invocation (for artifact validation) |

## Skill Files

- `skills/project/SKILL.md` -- Main workflow (entry point)
- `skills/project/references/progress-format.md` -- State file format specification
- `skills/project/references/routing-logic.md` -- Routing decision tables
- `skills/project/references/status-report-format.md` -- Output format specification
- `skills/project/DESIGN.md` -- Design decisions (13 decisions, DD-1 through DD-14)

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/define` | Routed to for Gates 0, WB, 1 |
| `/design` | Routed to for Gate 2 |
| `/milestone` | Routed to for Gate 3 |
| `/plan` | Routed to for Gate 4 |
| `/build` | Routed to for implementation |
| `/spike` | Routed to for technical research |
