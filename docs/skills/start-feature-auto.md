# Start Feature (Auto)

**Source:** `skills/start-feature-auto/`
**Command:** `/start-feature-auto`
**Activation:** Manual only (`disable-model-invocation: true`) — invoked via slash command.

## Description

Automated counterpart to `/start-feature`. Executes the same pre-work (reads `progress.txt`,
`prd.md`, and `docs/ARCHITECTURE_AND_DESIGN.md`, scans the codebase) but writes the context to
`progress.txt` NOTES rather than presenting it for human review, then implements the feature
without a confirmation checkpoint.

Before writing any code, the skill persists a structured NOTES entry covering the feature
summary, files identified, relevant design decisions, dependencies, and chosen execution model.
This ensures the record is complete regardless of outcome.

The skill dynamically selects an execution model based on feature complexity: inline for simple
changes, a single isolated sub-agent for self-contained features, or a parallel agent team for
features with independent work streams.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with 7-step workflow, complexity routing table, and NOTES format |

## Usage

```
/start-feature-auto
```

Invoke when you want the next feature implemented without a review checkpoint. The skill
identifies the next pending feature automatically — no arguments needed.

## Workflow

### Step 1 — Read progress.txt

Validates `progress.txt` exists and identifies the next feature to work on:

- `[~]` (in progress): resumes that feature. If the NOTES entry is complete (has `FILES
  IDENTIFIED`, `KEY DECISIONS`, `EXECUTION` fields), skips to Step 5.
- `[ ]` (pending): picks the next feature in order.
- All `[x]`: reports completion and stops.

### Step 2 — Read requirements

Reads `prd.md` for the feature's requirements and acceptance criteria. Reads
`docs/ARCHITECTURE_AND_DESIGN.md` for Design Decisions, Component Inventory, File Organization,
and Deployment Workflow sections relevant to the feature.

### Step 3 — Scan the codebase

Uses Glob and Grep to identify files to create or modify, based on component names and naming
patterns from the architecture doc's File Organization section. For greenfield features, lists
files to be created.

### Step 4 — Write NOTES entry

Marks the feature `[~]` and writes a structured NOTES block to `progress.txt` before any
implementation begins:

```
NOTES: Started YYYY-MM-DD.
       SUMMARY: [What this feature builds and why].
       FILES IDENTIFIED: [list from codebase scan]
       KEY DECISIONS: [relevant decisions from ARCHITECTURE_AND_DESIGN.md]
       DEPENDENCIES: [feature and external deps]
       EXECUTION: [inline | sub-agent | team] — [rationale]
```

### Step 5 — Assess complexity and route

Selects an execution model based on the codebase scan and requirements:

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

### Step 7 — Close the feature

Appends completion record to NOTES, changes status to `[x]`, and reports to the user:

```
COMPLETED: Feature X.Y — [Title]
EXECUTION MODEL: [inline | sub-agent | team]
FILES CHANGED: [list]
NEXT FEATURE: Feature X.Z — [Title]
```

## Output

All context and outcomes are persisted to `progress.txt` under the feature's NOTES field. The
NOTES block has a consistent structure across all features:

| Field | When written |
|---|---|
| `Started` | Step 4 — before implementation |
| `SUMMARY` | Step 4 — before implementation |
| `FILES IDENTIFIED` | Step 4 — before implementation |
| `KEY DECISIONS` | Step 4 — before implementation |
| `DEPENDENCIES` | Step 4 — before implementation |
| `EXECUTION` | Step 5 — before implementation |
| `CODE COMPLETE` | Step 7 — after implementation |
| `Completed` | Step 7 — after implementation |

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
- Batch processing multiple features without manual checkpoints between each
- When you trust the context in `prd.md` and `docs/ARCHITECTURE_AND_DESIGN.md` and want hands-off execution

## When Not to Use

- When you want to review the plan before implementation begins — use `/start-feature` instead
- When the feature has significant ambiguity in requirements or architecture
- When the feature touches shared infrastructure or has irreversible side effects that warrant a human checkpoint

## Related

- **`/start-feature`** — interactive version with a human-in-the-loop review checkpoint before implementation
- **`/create-prd`** — produces the `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, and `progress.txt` that this skill consumes
