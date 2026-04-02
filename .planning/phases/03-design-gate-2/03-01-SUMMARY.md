---
phase: 03-design-gate-2
plan: 01
subsystem: design
tags: [gate-2, architecture, review-checklist, refresh-mode, skill-authoring]

# Dependency graph
requires:
  - phase: 02-define-gates-0-wb-1
    provides: reference file patterns (gate specs, review checklist template, progress format, asset templates)
provides:
  - Gate 2 normal-mode specification (gate-2-design.md)
  - Refresh mode specification (refresh-mode.md)
  - Gate 2 review checklist template (review-checklist-template.md)
  - Progress format spec copy (progress-format.md)
  - Architecture document template (architecture-template.md)
affects: [03-design-gate-2 plan 02 (SKILL.md), milestone, plan, build]

# Tech tracking
tech-stack:
  added: []
  patterns: [architecture-focused agent scan, tradeoff callouts, deviation consolidation, section-by-section partial approval]

key-files:
  created:
    - skills/project/design/references/gate-2-design.md
    - skills/project/design/references/refresh-mode.md
    - skills/project/design/references/progress-format.md
    - skills/project/design/references/review-checklist-template.md
    - skills/project/design/assets/architecture-template.md
  modified: []

key-decisions:
  - "Architecture agent scans 15-30 files through architecture lens (component boundaries, data flow, interface contracts) -- distinct from Gate 0 convention-focused scan"
  - "Tradeoff callouts capped at 2-4 with heuristic: viable alternatives, multi-component impact, expensive reversal"
  - "Refresh mode uses per-deviation review with multiSelect consolidation, not batch apply"
  - "progress-format.md is verbatim copy per D-03 (no cross-directory reads between skills)"

patterns-established:
  - "Gate spec reference files: self-contained specs that an executor can run from a single file read"
  - "Architecture template: 6 mandatory sections matching DESIGN.md spec (no omit comment)"
  - "Gate 2 review checklist: 4 static items from DD-13 + auto-generated content items"

requirements-completed: [DES-01, DES-02, DES-03, DES-04, DES-05, DES-06, DES-07, DES-08]

# Metrics
duration: 5min
completed: 2026-04-02
---

# Phase 03 Plan 01: Design Gate 2 References Summary

**Self-contained Gate 2 reference files covering normal-mode architecture generation, refresh-mode deviation consolidation, review checklist template, progress format, and architecture document template**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-02T23:38:29Z
- **Completed:** 2026-04-02T23:43:45Z
- **Tasks:** 2
- **Files created:** 5

## Accomplishments

- Created gate-2-design.md (~150 lines) covering the complete Gate 2 normal-mode flow: input loading, architecture agent scan with 15-30 file heuristics, document production using 6-section template, tradeoff callouts, produce-then-review cycle with partial approval, checklist validation, and gate approval
- Created refresh-mode.md (~80 lines) covering deviation scan from feature plans, zero-deviation early exit, per-deviation review with multiSelect consolidation, and architecture doc re-review
- Created review-checklist-template.md with Gate 2 static items (4 from DD-13) and auto-generated item pattern
- Copied progress-format.md byte-identical from /define (verified via diff)
- Created architecture-template.md with exactly 6 sections matching DESIGN.md spec

## Task Commits

Each task was committed atomically:

1. **Task 1: Create reference files** - `50b997a` (feat)
2. **Task 2: Create architecture template asset** - `8a5b3d8` (feat)

## Files Created/Modified

- `skills/project/design/references/gate-2-design.md` - Complete Gate 2 normal-mode specification
- `skills/project/design/references/refresh-mode.md` - Refresh mode deviation consolidation specification
- `skills/project/design/references/progress-format.md` - Progress file format (verbatim copy from /define)
- `skills/project/design/references/review-checklist-template.md` - Gate 2 review checklist template
- `skills/project/design/assets/architecture-template.md` - Template for ARCHITECTURE_AND_DESIGN.md

## Decisions Made

- Architecture agent heuristics focus on component boundaries, data flow patterns, interface contracts, technology choices, and infrastructure -- distinct from Gate 0's convention-focused heuristics
- Tradeoff callout heuristic: (a) alternatives genuinely viable, (b) tradeoff affects multiple components or long-term evolution, (c) reversal expensive; capped at 2-4
- Refresh mode presents deviations individually with original design decision context before multiSelect consolidation
- Zero-deviation path exits cleanly with no revision offer per D-14

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All reference files and the architecture template are in place for Plan 02 (SKILL.md creation)
- SKILL.md can load each reference at the step that needs it following the established pattern from /define

## Self-Check: PASSED

All 5 created files verified on disk. Both task commits (50b997a, 8a5b3d8) verified in git log.

---
*Phase: 03-design-gate-2*
*Completed: 2026-04-02*
