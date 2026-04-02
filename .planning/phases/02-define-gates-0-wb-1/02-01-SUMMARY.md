---
phase: 02-define-gates-0-wb-1
plan: 01
subsystem: define-skill
tags: [gate-0, gate-wb, codebase-assessment, working-backwards, review-checklist, progress-format]

# Dependency graph
requires:
  - phase: 01-project-router
    provides: "Reference-loading pattern from /project SKILL.md, progress-format.md source"
provides:
  - "Gate 0 codebase assessment specification (gate-0-codebase.md)"
  - "Gate WB working backwards specification (gate-wb-working-backwards.md)"
  - "Shared review checklist template for all /define gates"
  - "Local copy of progress-format.md for /define skill"
affects: [02-02, 02-03, 02-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-gate reference file pattern: self-contained gate spec loaded by SKILL.md at runtime"
    - "Review checklist two-tier structure: static items per gate plus [Auto] content-specific items"
    - "Produce-then-review cycle: produce artifact, present, Approve/Revise, checklist validation, gate approval"

key-files:
  created:
    - "skills/project/define/references/gate-0-codebase.md"
    - "skills/project/define/references/gate-wb-working-backwards.md"
    - "skills/project/define/references/review-checklist-template.md"
    - "skills/project/define/references/progress-format.md"
  modified: []

key-decisions:
  - "Verbatim copy of progress-format.md per D-04 (no cross-directory reads between skills)"
  - "Gate WB uses 3-round interview structure (Customer/Problem, Solution/Experience, Internal Feasibility)"
  - "Agent-based codebase scan writes to temp scratch file, then synthesized into final assessment"

patterns-established:
  - "Self-contained gate reference: executor reading only the gate file can run the complete gate flow"
  - "Review checklist completion rules: all items must be [x] or [-] N/A with reason before gate approval"
  - "Gate WB 3-outcome offer: Yes/Skip/Defer with Pending state persistence"

requirements-completed: [DEF-01, DEF-02, DEF-03, DEF-04, DEF-05, DEF-06, DEF-07, DEF-08, DEF-09]

# Metrics
duration: 3min
completed: 2026-04-02
---

# Phase 02 Plan 01: Define Gates 0/WB References Summary

**Gate 0 codebase assessment and Gate WB working backwards specifications with shared review checklist template and progress-format copy**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-02T19:44:15Z
- **Completed:** 2026-04-02T19:47:40Z
- **Tasks:** 2
- **Files created:** 4

## Accomplishments
- Gate 0 reference covering greenfield detection heuristics, agent-based codebase scan, assessment production, produce-then-review cycle, checklist validation, and gate approval recording
- Gate WB reference covering 3-outcome offer (Yes/Skip/Defer), 3-round interview, PR/FAQ document production, review cycle, and gate approval
- Shared review checklist template with gate-specific static items and two-tier completion rules
- Verbatim copy of progress-format.md for /define skill isolation (D-04)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared references** - `9ae11d7` (feat)
2. **Task 2: Create Gate 0 and Gate WB reference files** - `94a7109` (feat)

## Files Created/Modified
- `skills/project/define/references/progress-format.md` - Verbatim copy of progress.txt format spec (187 lines)
- `skills/project/define/references/review-checklist-template.md` - Shared review checklist format for all 3 gates with static items and completion rules
- `skills/project/define/references/gate-0-codebase.md` - Complete Gate 0 specification: greenfield detection, agent scan, assessment, review, approval
- `skills/project/define/references/gate-wb-working-backwards.md` - Complete Gate WB specification: 3-outcome offer, interview, PR/FAQ production, review, approval

## Decisions Made
- Verbatim copy of progress-format.md (not partial extract) per D-04 -- format correctness is critical, 187-line cost acceptable
- Gate WB interview structured as 3 rounds mapping to PR/FAQ sections: Customer/Problem feeds Press Release, Solution/Experience feeds External FAQ, Internal Feasibility feeds Internal FAQ
- Agent-based scan writes to /tmp scratch file then cleaned up after synthesis -- keeps docs/ clean

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- progress-format.md source file not present in worktree (worktree branched from main, file exists only on development/project-feature) -- resolved by extracting from git branch via `git show`

## User Setup Required

None - no external service configuration required.

## Known Stubs

None - all 4 reference files are complete specifications.

## Next Phase Readiness
- Gate 0 and Gate WB references ready for SKILL.md to load at runtime (Plan 03)
- Review checklist template ready for all 3 gates to reference
- Gate 1 reference (gate-1-prd.md) needed from Plan 02 before SKILL.md can be written

## Self-Check: PASSED

All 4 created files verified on disk. Both task commits (9ae11d7, 94a7109) verified in git log.

---
*Phase: 02-define-gates-0-wb-1*
*Completed: 2026-04-02*
