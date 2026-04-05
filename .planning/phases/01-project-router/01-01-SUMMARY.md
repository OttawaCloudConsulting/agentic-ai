---
phase: 01-project-router
plan: 01
subsystem: state-management
tags: [progress-txt, milestone-status, checkbox-notation, routing-table, status-report]

# Dependency graph
requires: []
provides:
  - "progress.txt bootstrap template and format specification"
  - "Four-marker status notation contract ([x], [~], [ ], [-])"
  - "State-to-action routing decision table for all project states"
  - "Status report output format with inline warnings"
  - "milestone-status.txt per-milestone format specification"
  - "Write-ordering contract (milestone-status.txt before progress.txt)"
affects: [01-project-router, 02-define, 03-design, 04-milestone, 05-plan, 06-build, 07-spike-docs]

# Tech tracking
tech-stack:
  added: []
  patterns: [plain-text-checkbox-notation, two-tier-state-files, reference-file-loading]

key-files:
  created:
    - skills/project/references/progress-format.md
    - skills/project/references/routing-logic.md
    - skills/project/references/status-report-format.md
  modified: []

key-decisions:
  - "Four canonical markers ([x], [~], [ ], [-]) are the ONLY permitted status notation -- no alternatives like [in-progress] allowed"
  - "Greenfield bootstrap records Gate 0 as [-] Skipped (greenfield) rather than omitting it, preserving uniform gate structure"
  - "Consistency divergence blocks routing (per D-07) while missing artifact warnings are informational only"
  - "Gate WB Pending shows gentle reminder but does NOT hard-block status display (D-09 overrides strict PROJ-07)"

patterns-established:
  - "Reference file pattern: detailed specs in skills/<name>/references/*.md, loaded on demand by SKILL.md"
  - "Status notation consistency: all state files use the same four markers, no per-entity-type variations"
  - "Inline warning pattern: warnings appear directly after the affected entry, not in a separate section"

requirements-completed: [STATE-01, STATE-02, STATE-04, PROJ-03, PROJ-04, PROJ-05, PROJ-06, PROJ-07, PROJ-08, PROJ-09]

# Metrics
duration: 30min
completed: 2026-04-02
---

# Phase 01 Plan 01: Reference Specifications Summary

**Three reference files defining progress.txt bootstrap template, four-marker status notation, complete routing decision table, and structured status report format with inline warnings**

## Performance

- **Duration:** 30 min
- **Started:** 2026-04-02T16:59:34Z
- **Completed:** 2026-04-02T17:29:49Z
- **Tasks:** 2
- **Files created:** 3

## Accomplishments

- Defined the exact bootstrap template for `progress.txt` with gates, milestones, and spikes sections, plus greenfield variant
- Created complete state-to-action routing table covering all gate/milestone combinations, re-planning intent detection, Gate WB offer logic, artifact validation, and consistency validation
- Specified structured status report output format with 8 ordered sections, inline warnings, blocking behavior, and empty project variant
- Established the write-ordering contract (milestone-status.txt before progress.txt) and four-marker notation as the universal standard

## Task Commits

Each task was committed atomically:

1. **Task 1: Create progress file format specification** - `a83f3b1` (feat)
2. **Task 2: Create routing logic and status report format specifications** - `f4fbcc2` (feat)

## Files Created/Modified

- `skills/project/references/progress-format.md` - Bootstrap template, status notation, gate/milestone/spike entry formats, milestone-status.txt format, write-ordering contract, parsing notes
- `skills/project/references/routing-logic.md` - Complete routing decision table, re-planning intent detection, Gate WB offer logic, artifact validation, consistency validation
- `skills/project/references/status-report-format.md` - Structured status report format (8 sections), empty project report, blocking behavior rules

## Decisions Made

- Four canonical markers are the ONLY permitted notation -- prevents the inconsistency risk identified in TEXT_vs_YAML_REPORT.md
- Greenfield Gate 0 recorded as `[-] Skipped (greenfield)` (not omitted) -- every progress.txt has uniform gate structure per RESEARCH.md recommendation
- D-09 override of PROJ-07 explicitly documented in both routing-logic.md and status-report-format.md -- Gate WB Pending shows reminder but does not suppress status
- Consistency divergence blocks routing per D-07, while missing artifact warnings remain informational only

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - all three reference files are complete specifications with no placeholder content.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three reference files are ready for SKILL.md to reference via `Read` instructions
- Plan 02 (SKILL.md creation) can load these references at the appropriate workflow steps
- The routing table, status report format, and progress file format are the contracts that SKILL.md will depend on

## Self-Check: PASSED

- FOUND: skills/project/references/progress-format.md
- FOUND: skills/project/references/routing-logic.md
- FOUND: skills/project/references/status-report-format.md
- FOUND: .planning/phases/01-project-router/01-01-SUMMARY.md
- FOUND: commit a83f3b1 (Task 1)
- FOUND: commit f4fbcc2 (Task 2)

---
*Phase: 01-project-router*
*Completed: 2026-04-02*
