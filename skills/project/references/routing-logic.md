# Routing Logic Specification

## Overview

`/project` determines the next recommended action based on gate states, milestone states, and user intent. After reading `progress.txt` and any relevant `milestone-status.txt` files, the skill evaluates the current project state against this routing table, performs validation checks, and outputs a single recommended action with context-sensitive alternatives (per D-03, D-04). This file is the complete routing decision table.

## Routing Table

The state-to-action table below covers every reachable project state. The skill evaluates rows top-to-bottom and selects the first matching state. The "Alternatives" column lists actions valid for the current state that appear under "Also available" in the status report (per D-04 -- only actions valid for the current state are shown).

| State | Recommended Action | Alternatives |
|-------|-------------------|--------------|
| No `progress.txt` | Bootstrap (internal -- do not route to another skill) | -- |
| Gate WB is `[ ] Pending` | Resolve Gate WB: offer Yes/Skip/Defer (per D-08) | -- |
| No gates approved (all `[ ]`) | Run `/define` to begin codebase assessment | -- |
| Gate 0 approved, Gate WB not offered yet, no `docs/working-backwards.md`, customer outcome unclear | Offer Gate WB (per D-08, DD-11) | `/define` (continue to Gate 1) |
| Gate 0 approved, Gate WB resolved (`[x]` or `[-]`), no Gate 1 | Run `/define` to continue PRD interview | -- |
| Gate 1 approved, no Gate 2 | Run `/design` to create architecture | `/spike` |
| Gate 2 approved, no milestones defined | Run `/milestone` to define first milestone | `/spike` |
| Gate 3 `[~]` in progress, unplanned features exist | Run `/plan` for next unplanned feature | `/milestone` (define another), `/spike` |
| Feature planned (`[~]` planned, awaiting build) | Run `/build` for planned feature | `/plan` (next feature), `/spike` |
| Feature in progress (sub-features partially complete) | Run `/build` to continue feature | `/spike` |
| All features complete in active milestone, more milestones to define | Run `/milestone` for next milestone | `/design` (refresh) |
| All milestones complete | Project complete -- celebrate | `/design` (refresh) |
| User says "goals changed" / "revise PRD" / similar | Run `/define` in revision mode (per D-05, PROJ-08) | -- |
| User says "re-plan" / "revise milestone" / similar | Run `/milestone` in revision mode (per D-05, PROJ-09) | -- |
| Open spikes exist (any state) | `/spike` appears in alternatives when contextually relevant | -- |

Notes:

- The "Alternatives" column implements D-04 -- only actions valid for the current state appear. Do not show `/plan` if no milestone exists. Do not show `/build` if no planned features exist.
- "Bootstrap" is an internal action performed by `/project` itself -- it does not route to another skill.
- "Offer Gate WB" is also handled internally by `/project` via `AskUserQuestion`.
- When open spikes exist, `/spike` is added to the alternatives list for any state where it is contextually relevant (post-Gate 1 states).
- The "customer outcome unclear" condition for Gate WB offer is evaluated by Claude based on available project context -- if the project's purpose and target customer are well-defined from existing artifacts, Gate WB may not be offered.

## Re-planning Intent Detection

Per D-05, `/project` detects natural language keywords that signal the user wants to revise existing artifacts rather than proceed forward.

**PRD revision triggers:**

- "goals changed"
- "revise PRD"
- "pivot"
- "change direction"
- "update requirements"
- "scope change"

When detected, route to `/define` in revision mode. State explicitly: "Run `/define` in revision mode to update the PRD based on changed goals."

**Milestone revision triggers:**

- "re-plan"
- "revise milestone"
- "regroup features"
- "change milestone"
- "re-scope"

When detected, route to `/milestone` in revision mode. State explicitly: "Run `/milestone` in revision mode to revise the milestone breakdown."

**Detection behavior:** These keywords are matched case-insensitively against the user's input to `/project`. Partial matches are acceptable (e.g., "I need to re-plan the milestones" matches "re-plan"). When in doubt, ask the user to clarify their intent before routing.

## Gate WB Offer Logic

Per D-08 and DD-11, Gate WB (Working Backwards) is an optional stage that `/project` offers when appropriate.

**Evaluation sequence:**

1. Check if `docs/working-backwards.md` exists on disk.
2. Check the Gate WB line in `progress.txt`.
3. Apply the appropriate action based on state:

| Gate WB State | `working-backwards.md` exists? | Action |
|---------------|-------------------------------|--------|
| No Gate WB line in progress.txt | No | Evaluate whether customer outcome is unclear. If unclear, offer Gate WB with `AskUserQuestion`. |
| No Gate WB line in progress.txt | Yes | No action -- Working Backwards was done outside the pipeline. |
| `[ ] Pending -- offered, awaiting decision` | Either | Show gentle reminder at top of status report (per D-09). Do NOT hard-block. Still display full status report below the reminder. |
| `[x]` approved | Either | No action -- Gate WB is resolved. Proceed with normal routing. |
| `[-]` skipped | Either | No action -- Gate WB is resolved. Proceed with normal routing. |

**Offering Gate WB:**

When offering, provide a 2-3 sentence explanation of the Working Backwards value, then use `AskUserQuestion` with three options:

- **Yes** -- Proceed with Working Backwards exercise. Route to `/define` which will conduct Gate WB.
- **Skip** -- Record `[-] Gate WB: Working Backwards  Skipped` in progress.txt. Continue routing.
- **Defer** -- Record `[ ] Gate WB: Working Backwards  Pending -- offered, awaiting decision` in progress.txt. Continue routing with a note that this can be revisited.

**D-09 override:** When Gate WB is `[ ] Pending`, the strict reading of PROJ-07 would hard-block status display. D-09 explicitly overrides this: show a gentle reminder at the top of the report, but still display the full status report. The pending decision is highlighted but does not suppress status output.

## Artifact Validation

Per PROJ-04 and DESIGN.md DD-3, `/project` validates that artifacts referenced by approved gates exist on disk.

**Process:**

1. For each gate marked `[x]` in `progress.txt`, extract the artifact path from the gate entry line (the path following the date).
2. Check if the file exists on disk at the extracted path.
3. If the file is missing, emit an inline warning (per D-06) directly after the gate entry in the status report:

```
[x] Gate 1: Scope Review          Approved: 2026-03-16  prd.md
     Warning: Artifact not found: prd.md
```

**Severity:** Informational only -- missing artifact warnings do NOT block routing. The user is informed but can continue. This is consistent with D-07 (severity-based blocking: missing artifacts are informational).

## Consistency Validation

Per PROJ-05 and D-07, `/project` validates that milestone summaries in `progress.txt` are consistent with their corresponding `milestone-status.txt` files.

**Process:**

1. For each milestone entry in the `## Milestones` section of `progress.txt`, extract the milestone directory path and the `N/M features complete` count.
2. Read the corresponding `milestones/<NN>-<name>/milestone-status.txt`.
3. Count the `[x]` feature entries in `milestone-status.txt`. Compare to the `N` (completed) and `M` (total) values in the `progress.txt` milestone summary line.
4. If the counts diverge, emit an inline warning after the milestone entry in the status report:

```
[~] Milestone 01: Core Auth  milestones/01-core-auth/  2/3 features complete
     Warning: Milestone status divergence detected -- progress.txt says 2/3, milestone-status.txt shows 1/3. Please acknowledge to continue routing.
```

**Severity:** Consistency divergence BLOCKS routing until the user acknowledges the discrepancy. This is more severe than missing artifacts (per D-07). When a consistency warning is active:

- The status report is displayed in full (gates, milestones, spikes).
- The RECOMMENDED section is replaced with a request for the user to acknowledge the divergence.
- After acknowledgment, normal routing resumes.

**Why blocking:** Divergent state files mean the project's progress tracking is unreliable. Routing based on incorrect state could send the user to the wrong skill. The user must confirm which count is correct before proceeding.
