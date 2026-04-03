---
phase: 04-milestone-gate-3
plan: 01
subsystem: skills
tags: [milestone, gate-3, skill-bundle, reference-files, templates]

# Dependency graph
requires:
  - phase: 03-design-gate-2
    provides: Gate 2 skill bundle pattern (gate spec, refresh mode, review checklist, progress format)
provides:
  - Gate 3 normal-mode specification (gate-3-milestone.md)
  - Revision mode specification (revision-mode.md)
  - Gate 3 review checklist template (review-checklist-template.md)
  - Progress format verbatim copy (progress-format.md)
  - Milestone README template (milestone-readme-template.md)
affects: [04-02, 04-03, milestone-skill]

# Tech tracking
tech-stack:
  added: []
  patterns: [two-phase-flow, revision-mode-auto-detect, selective-feature-reset, write-ordering-STATE-04]

key-files:
  created:
    - skills/project/milestone/references/gate-3-milestone.md
    - skills/project/milestone/references/revision-mode.md
    - skills/project/milestone/references/progress-format.md
    - skills/project/milestone/references/review-checklist-template.md
    - skills/project/milestone/assets/milestone-readme-template.md
  modified: []

key-decisions:
  - "Gate 3 spec uses two-phase flow: first invocation proposes all milestones (D-07), subsequent invocations auto-select next (D-09)"
  - "Revision mode auto-detected by existing milestone directory (D-10), uses selective feature reset preserving completed work (MIL-12)"
  - "Verbatim copy of progress-format.md per D-04 (no cross-directory reads between skills)"

patterns-established:
  - "Two-phase flow: propose-all-then-define-one pattern for multi-artifact gates"
  - "Revision mode with selective reset: multiSelect feature checklist preserving unaffected work"
  - "Per-milestone review checklist at milestones/NN-name/reviews/ (not docs/reviews/ like Gates 0-2)"

requirements-completed: [MIL-01, MIL-02, MIL-03, MIL-04, MIL-05, MIL-06, MIL-07, MIL-08, MIL-09, MIL-10, MIL-11, MIL-12, MIL-13]

# Metrics
duration: 5min
completed: 2026-04-02
---

# Phase 04 Plan 01: Gate 3 References and Templates Summary

**Self-contained Gate 3 specs for normal mode (two-phase milestone planning) and revision mode (selective feature reset), plus review checklist template and milestone README template**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-03T00:52:37Z
- **Completed:** 2026-04-03T00:58:13Z
- **Tasks:** 2
- **Files created:** 5

## Accomplishments

- Created gate-3-milestone.md with complete normal-mode spec covering first invocation (propose all milestones, D-07), subsequent invocation (auto-select next, D-09), individual milestone definition (MIL-03 through MIL-09), review phase, and checklist validation
- Created revision-mode.md with complete revision spec covering auto-detection (D-10), feature impact assessment with selective reset (D-11, MIL-11, MIL-12), focused revision (D-12), and artifact updates with STATE-04 write-ordering
- Created review-checklist-template.md with all 5 DD-13 Gate 3 static items and Auto item examples
- Created milestone-readme-template.md with all MIL-04 sections (Goal, Features, Dependencies, Ordering, Sizing, Configuration, Definition of Done)
- Copied progress-format.md verbatim from skills/project/references/ per D-04

## Task Commits

Each task was committed atomically:

1. **Task 1: Gate 3 normal-mode spec and review checklist template** - `36b5cd8` (feat)
2. **Task 2: Revision mode spec and milestone README template** - `27ad280` (feat)
3. **Lint fix: markdown auto-fixes** - `7462242` (chore)

## Files Created/Modified

- `skills/project/milestone/references/gate-3-milestone.md` - Complete Gate 3 normal-mode specification (223 lines)
- `skills/project/milestone/references/revision-mode.md` - Complete revision mode specification (106 lines)
- `skills/project/milestone/references/progress-format.md` - Verbatim copy of shared progress format spec
- `skills/project/milestone/references/review-checklist-template.md` - Gate 3 review checklist template (82 lines)
- `skills/project/milestone/assets/milestone-readme-template.md` - README.md template per milestone (49 lines)

## Decisions Made

- Gate 3 spec uses two-phase flow: first invocation proposes all milestones (D-07), subsequent invocations auto-select next (D-09)
- Revision mode auto-detected by existing milestone directory (D-10), uses selective feature reset preserving completed work (MIL-12)
- Verbatim copy of progress-format.md per D-04 (no cross-directory reads between skills)
- Per-milestone review checklists at milestones/NN-name/reviews/ (different from Gates 0-2 which use docs/reviews/)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added progress-format.md reference to revision-mode.md**
- **Found during:** Task 2 (revision mode spec)
- **Issue:** Plan's must_haves key_links require revision-mode.md to reference progress-format.md, but initial version lacked this cross-reference
- **Fix:** Added reference line in the milestone-status.txt update section
- **Files modified:** skills/project/milestone/references/revision-mode.md
- **Verification:** grep confirmed progress-format.md reference present
- **Committed in:** 27ad280 (Task 2 commit, amended)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Cross-reference was required by plan's must_haves. No scope creep.

## Issues Encountered

- Markdown linter flags `<NN>` and `<Name>` in milestone-readme-template.md as inline HTML (MD033). These are intentional template placeholders specified verbatim in the plan. The lint script's default non-recursive mode passes; the issue only surfaces when targeting the specific file. This is consistent with template files having placeholder syntax.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 5 reference and asset files are ready for SKILL.md (Plan 02) to reference
- Gate 3 spec is self-contained: an executor reading only gate-3-milestone.md can run the full flow
- Revision mode spec is self-contained: an executor reading only revision-mode.md can run the full revision flow
- Directory structure established: skills/project/milestone/references/ and skills/project/milestone/assets/

---
*Phase: 04-milestone-gate-3*
*Completed: 2026-04-02*
