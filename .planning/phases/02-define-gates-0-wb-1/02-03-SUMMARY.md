---
phase: 02-define-gates-0-wb-1
plan: 03
subsystem: define-skill
tags: [skill-md, flow-control, gate-sequencing, greenfield-detection, revision-mode]

# Dependency graph
requires:
  - phase: 02-define-gates-0-wb-1
    plan: 01
    provides: "Gate 0 and Gate WB reference files, review checklist template, progress-format.md"
  - phase: 02-define-gates-0-wb-1
    plan: 02
    provides: "Gate 1 reference file (gate-1-prd.md) and PRD template (prd-template.md)"
  - phase: 01-project-router
    provides: "Reference-loading SKILL.md pattern from /project SKILL.md"
provides:
  - "Complete /define SKILL.md entry point orchestrating Gates 0, WB, and 1"
  - "Mode detection: greenfield skip, revision mode, Gate WB resume, already-approved"
  - "Flow control across 7 steps with gate-to-gate transitions"
affects: [02-04, 03-design]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SKILL.md as flow controller: handles mode detection and gate sequencing, delegates gate logic to reference files"
    - "Multi-mode entry: same skill handles fresh run, greenfield, revision, resume, and already-approved states"

key-files:
  created:
    - skills/project/define/SKILL.md
  modified: []

key-decisions:
  - "SKILL.md at 197 lines -- well under 350-line limit, with all flow control and error handling"
  - "Added already-approved detection beyond plan spec (if Gate 1 already [x] without revision intent)"

patterns-established:
  - "Multi-gate SKILL.md pattern: single file orchestrating multiple gates with delegated reference files"
  - "Mode detection in Step 1: all entry-state routing in one step before any gate execution"

requirements-completed: [DEF-01, DEF-02, DEF-03, DEF-04, DEF-05, DEF-06, DEF-07, DEF-08, DEF-09, DEF-10, DEF-11, DEF-12, DEF-13, DEF-14, DEF-15, DEF-16]

# Metrics
duration: 2min
completed: 2026-04-02
---

# Phase 02 Plan 03: /define SKILL.md Summary

**/define SKILL.md entry point with 7-step flow control orchestrating Gates 0, WB, and 1 as a single continuous session**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-02T19:50:31Z
- **Completed:** 2026-04-02T19:53:04Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created complete /define SKILL.md (197 lines) with frontmatter, rules, prerequisites, 7 steps, and error handling
- Mode detection handles all entry states: fresh brownfield, fresh greenfield, Gate WB pending resume, revision mode, already-approved
- Each gate delegates to its reference file via Read instruction -- SKILL.md contains zero gate-specific logic
- All 20 acceptance criteria verified passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Create /define SKILL.md with flow control and gate sequencing** - `555d5ee` (feat)

## Files Created/Modified
- `skills/project/define/SKILL.md` - Complete /define skill entry point with mode detection, gate sequencing, and error handling

## Decisions Made
- Added already-approved detection for Gate 1 (when user re-invokes /define after Gate 1 is already approved without revision intent) -- not explicitly in plan but necessary for correct behavior
- SKILL.md at 197 lines provides room for future additions while staying well under the 350-line limit

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - SKILL.md is complete and references all required gate files.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- /define SKILL.md is complete and ready for invocation (once reference files from Plans 01 and 02 are merged)
- Plan 04 (documentation) can proceed to create catalog entry and detail doc for /define
- The skill can be tested end-to-end once all files are on the same branch

## Self-Check: PASSED

- FOUND: skills/project/define/SKILL.md
- FOUND: .planning/phases/02-define-gates-0-wb-1/02-03-SUMMARY.md
- FOUND: commit 555d5ee

---
*Phase: 02-define-gates-0-wb-1*
*Completed: 2026-04-02*
