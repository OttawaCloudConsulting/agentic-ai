# Start Feature (Auto)

**Source:** `commands/start-feature-auto.md`
**Command:** `/start-feature-auto`
**Activation:** Manual — invoked via slash command only. Never auto-triggered.

## Description

Automated counterpart to `/start-feature`. Executes the same pre-work (reads `progress.txt`,
`prd.md`, and `docs/ARCHITECTURE_AND_DESIGN.md`, scans the codebase) but writes the context to
`progress.txt` NOTES rather than presenting it for human review, then implements the feature
without a confirmation checkpoint.

Before writing any code, the command persists a structured NOTES entry covering the feature
summary, files identified, relevant design decisions, dependencies, and chosen execution model.
This ensures the record is complete regardless of outcome.

The command dynamically selects an execution model based on feature complexity: inline for simple
changes, a single isolated sub-agent for self-contained features, or a parallel agent team for
features with independent work streams.

## Usage

```
/start-feature-auto
```

No arguments. The command determines which feature to implement from `progress.txt` automatically.

## Inputs

| Input | Source | Required |
|---|---|---|
| Feature status | `progress.txt` | Yes |
| Feature requirements and acceptance criteria | `prd.md` | Yes |
| Design decisions, component inventory, file organization | `docs/ARCHITECTURE_AND_DESIGN.md` | No — proceeds with `prd.md` alone if absent |
| Current codebase structure | Glob and Grep scan | Yes |

## Outputs

| Output | Location | Description |
|---|---|---|
| NOTES entry | `progress.txt` (in-place edit) | Structured pre-work record written before implementation |
| Completed feature | Codebase | Files created or modified per the feature requirements |
| Completion record | `progress.txt` (in-place edit) | CODE COMPLETE appended to NOTES; status changed to `[x]` |
| Summary report | Console (stdout) | Execution model used, files changed, next feature pointer |

## Workflow

### Step 1 — Read progress.txt

Validates `progress.txt` exists and identifies the target feature:

- `[~]` (in progress): resumes. If NOTES already has `FILES IDENTIFIED`, `KEY DECISIONS`, and
  `EXECUTION` fields, skips pre-work and proceeds directly to Step 6 (Implement) using the
  recorded `EXECUTION` value without modifying it.
- `[ ]` (pending): picks the next feature in order.
- All `[x]`: reports completion and stops.

### Step 2 — Read requirements

Reads `prd.md` for the feature's requirements and acceptance criteria. Reads
`docs/ARCHITECTURE_AND_DESIGN.md` for Design Decisions, Component Inventory, File Organization,
and Deployment Workflow relevant to the feature.

### Step 3 — Scan the codebase

Uses Glob and Grep to identify files to create or modify, based on component names and naming
patterns from the architecture doc's File Organization section. For greenfield features, lists
files to be created.

### Step 4 — Write NOTES entry

Marks the feature `[~]` and writes a structured NOTES block to `progress.txt`:

```
NOTES: Started YYYY-MM-DD.
       SUMMARY: [What this feature builds and why].
       FILES IDENTIFIED: [list from codebase scan]
       KEY DECISIONS: [relevant decisions from ARCHITECTURE_AND_DESIGN.md]
       DEPENDENCIES: [feature and external deps]
       EXECUTION: [TBD — filled by Step 5]
```

### Step 5 — Assess complexity and route

Selects an execution model and updates the `EXECUTION:` field in NOTES:

| Signal | Execution model |
|---|---|
| 1–3 files, single component, straightforward criteria | Inline |
| 4–8 files, self-contained concern, or unfamiliar area | Sub-agent (isolated worktree) |
| Multiple independent components, no shared state | Team (parallel agents, one per stream) |

The chosen model and rationale are recorded in NOTES before execution begins.

### Step 6 — Implement

Executes using the recorded model. Inline proceeds directly. Sub-agent launches a single isolated
agent in a worktree with the full feature context. Team launches one agent per work stream in
parallel, then merges results.

### Step 7 — Codex review of the completed change set

> **Requires** `.claude/scripts/codex-review.sh` from the Claude Toolkit bundle
> (`bash scripts/claude-toolkit/install.sh <target-repo-path>`) plus the `codex` CLI. When either is
> absent the step records `CODEX REVIEW: skipped (codex unavailable — <reason>)` and the feature
> still closes.

After implementation finishes and local tests/linters pass, reviews the work with Codex before
closing: assembles the change set and acceptance criteria, writes a review brief, runs the
hardened wrapper (`bash .claude/scripts/codex-review.sh --diff` — never a hand-rolled
`codex exec`; exit 0 = PASS, 1 = FAIL, 2 = no verdict and never inferred as PASS), then triages
every finding as VALID (confirmed against the code) or REJECTED (with a one-line reason).
Codex unavailability is non-fatal — recorded and reported, never blocking.

### Step 8 — Refactor on valid findings (conditional)

Clean review (or only REJECTED findings) skips straight to close. Valid findings are addressed
using the same execution model recorded in NOTES, staying within feature scope, HIGH before LOW;
tests and linters re-run, with at most one confirming Codex re-review. An unresolved valid HIGH
finding leaves the feature `[~]` and reports instead of closing.

### Step 9 — Close the feature

Appends `CODE COMPLETE`, `CODEX REVIEW`, `REFACTOR`, and `Completed YYYY-MM-DD` to NOTES,
changes status to `[x]`, and reports to the user with execution model, files changed, review
outcome, and the next feature.

## NOTES Structure

The NOTES block has a consistent structure written in two passes:

| Field | Written | Content |
|---|---|---|
| `Started` | Step 4 — before implementation | Start date |
| `SUMMARY` | Step 4 — before implementation | 1–2 sentence feature description |
| `FILES IDENTIFIED` | Step 4 — before implementation | Files from codebase scan |
| `KEY DECISIONS` | Step 4 — before implementation | Relevant design decisions |
| `DEPENDENCIES` | Step 4 — before implementation | Feature and external deps |
| `EXECUTION` | Step 5 — before implementation | Chosen model and rationale |
| `CODE COMPLETE` | Step 9 — after implementation | Files changed, test and lint status |
| `CODEX REVIEW` | Step 9 — after review | Finding counts (H/M/L), valid vs rejected with reasons |
| `REFACTOR` | Step 9 — after refactor | What changed to resolve valid findings, or "none (review clean)" |
| `Completed` | Step 9 — after implementation | Completion date |

## Error Handling

| Failure | Recovery |
|---|---|
| `progress.txt` missing | Stops. Tells user to run `/create-prd` first. |
| `prd.md` missing | Stops. Tells user to run `/create-prd` first. |
| Dependency feature not `[x]` | Stops. Reports which feature must be completed first. |
| Sub-agent or team agent fails | Leaves feature `[~]`. Writes failure detail to NOTES. Reports to user. |
| Implementation does not satisfy acceptance criteria | Does not mark `[x]`. Records gap in NOTES. Reports to user. |
| `docs/ARCHITECTURE_AND_DESIGN.md` missing | Proceeds using `prd.md` only. Notes absence in NOTES. |

## When to Use

- Implementing a well-defined feature where requirements and architecture are clear
- When you trust the context in `prd.md` and `docs/ARCHITECTURE_AND_DESIGN.md` and want hands-off execution
- Batch-processing multiple features without manual checkpoints between each

## When Not to Use

- When you want to review the plan before implementation begins — use `/start-feature` instead
- When the feature has significant ambiguity in requirements or architecture
- When the feature touches shared infrastructure or has irreversible side effects warranting a human checkpoint

## Related Commands

- `/start-feature` — interactive version: presents plan for review, waits for confirmation before implementing
- `/create-prd` — produces the `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, and `progress.txt` that this command consumes
- `/catchup` — reads project state at the start of a session; often invoked before `/start-feature-auto`
- `/handoff` — captures in-progress state at the end of a session
