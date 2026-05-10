# Status Report Format Specification

## Overview

Per D-01, `/project` produces a structured summary with clean sections: gates as a checklist with dates, the active milestone with per-feature status, one-line summaries for completed and upcoming milestones, all spikes (open and resolved), and a prioritized recommended action with context-sensitive alternatives. Warnings appear inline (D-06), and blocking behavior follows severity rules (D-07).

## Status Report Structure

The status report is output directly to the user (not written to a file). Sections appear in the following order:

### 1. PROJECT STATUS Header

```
PROJECT STATUS: <Project Name>
```

The project name is extracted from the `# Progress: <Project Name>` header line in `progress.txt`.

### 2. Gate WB Pending Reminder (conditional)

Per D-09, if Gate WB is `[ ] Pending -- offered, awaiting decision`, show a reminder at the TOP of the report before the gates section:

```
NOTE: You previously deferred the Working Backwards decision. Would you like to resolve it now?
(This does not block status display -- full report follows below.)
```

This reminder is informational. It does NOT suppress or block the rest of the status report. The user can choose to address it or ignore it.

### 3. GATES Section

Checklist of all gates with their current status, approval dates, and artifact paths. Inline warnings (per D-06) appear directly after affected entries:

```
GATES:
  [x] Gate 0: Codebase Alignment    Approved: 2026-03-15  .project/my-project/docs/codebase-assessment.md
  [-] Gate WB: Working Backwards    Skipped
  [x] Gate 1: Scope Review          Approved: 2026-03-16  prd.md
       Warning: Artifact not found: prd.md
  [x] Gate 2: Design Review         Approved: 2026-03-17  .project/my-project/docs/ARCHITECTURE_AND_DESIGN.md
  [~] Gate 3: Milestone Review      In progress
```

Notes:

- Gates are listed in order: 0, WB, 1, 2, 3.
- Approved gates show the approval date and artifact path.
- Skipped gates show "Skipped" (with optional reason).
- In-progress gates show "In progress".
- Pending gates show no suffix (just the gate name).
- Artifact validation warnings appear indented under the affected gate entry.

### 4. ACTIVE MILESTONE Section

Expanded view of the current in-progress milestone with per-feature status:

```
ACTIVE MILESTONE: 01 - Core Auth (2/3 features complete)
  [x] Feature 01.1: User Registration     Complete
  [x] Feature 01.2: Session Management    Complete
  [~] Feature 01.3: Password Reset        In progress
```

If a consistency divergence is detected between `progress.txt` and `milestone-status.txt`, an inline warning appears after the milestone header:

```
ACTIVE MILESTONE: 01 - Core Auth (2/3 features complete)
  Warning: Milestone status divergence detected -- progress.txt says 2/3, milestone-status.txt shows 1/3. Please acknowledge to continue routing.
  [x] Feature 01.1: User Registration     Complete
  [~] Feature 01.2: Session Management    In progress
  [ ] Feature 01.3: Password Reset        Pending
```

If no milestone is active (no milestones defined yet), this section is omitted entirely.

### 5. COMPLETED MILESTONES Section (conditional)

One-line summaries for milestones marked `[x]` complete. Only shown if at least one milestone is complete:

```
COMPLETED:
  [x] Milestone 01: Core Auth (3/3 features complete)
```

### 6. UPCOMING MILESTONES Section (conditional)

One-line summaries for milestones marked `[ ]` pending. Only shown if upcoming milestones exist:

```
UPCOMING:
  [ ] Milestone 02: Dashboard  (0/2 features complete)
```

### 7. SPIKES Section

Per D-02, show ALL spikes (both open and resolved). Never remove resolved spikes -- they remain for reference:

```
SPIKES:
  [x] WebSocket Auth Compatibility    Resolved 2026-03-17
  [ ] SQLite to Postgres Migration    Open
```

If no spikes exist, show:

```
SPIKES: (none yet)
```

### 8. RECOMMENDED Section

Per D-03, one bold recommended action plus alternatives. Per D-04, only show alternatives valid for the current state:

```
RECOMMENDED: Run `/plan-feature` to create the implementation plan for Feature 01.3: Password Reset
Also available:
  - `/spike` -- research a technical question
  - `/milestone` -- define the next milestone
```

The recommended action is determined by the routing table in `routing-logic.md`. The alternatives list is context-sensitive -- only actions that are valid for the current project state appear.

If no alternatives are valid for the current state, the "Also available" section is omitted.

## Empty Project Report

When only bootstrap has run (all gates pending, no milestones, no spikes):

```
PROJECT STATUS: <Project Name>

GATES:
  [ ] Gate 0: Codebase Alignment
  [ ] Gate WB: Working Backwards
  [ ] Gate 1: Scope Review
  [ ] Gate 2: Design Review
  [ ] Gate 3: Milestone Review

MILESTONES: (none yet)

SPIKES: (none yet)

RECOMMENDED: Run `/define` to begin project definition
```

This is the simplest possible report. No alternatives are shown because `/define` is the only valid next action.

## Blocking Behavior

Per D-07, warnings have severity-based blocking behavior:

**Missing artifact warnings: INFORMATIONAL ONLY**

- Do NOT block routing.
- The warning is displayed inline after the affected gate entry.
- The RECOMMENDED section is shown normally.
- The user is informed but can proceed with the recommended action.

**Consistency divergence warnings: BLOCK ROUTING**

- The warning is displayed inline after the affected milestone entry.
- The RECOMMENDED section is replaced with a request for user acknowledgment:

```
ACTION REQUIRED: Milestone status divergence detected (see warning above). Please acknowledge the discrepancy before routing can continue.
```

- After the user acknowledges, normal routing resumes and the RECOMMENDED section is displayed.
- The full status report (gates, milestones, spikes) is still shown -- only the routing recommendation is blocked, not the status display.
