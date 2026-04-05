# Phase 6: /build - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement features sub-feature by sub-feature from Gate 4-approved plans. Each sub-feature leaves the codebase in a committable state. State files (`milestone-status.txt`, `progress.txt`) are updated incrementally. Codebase assessment is refreshed at feature start. Test command must pass before feature completion. Architectural deviations are recorded when the approved design cannot be followed.

</domain>

<decisions>
## Implementation Decisions

### Sub-feature execution flow
- **D-01:** Auto-resume — each `/build` invocation reads the feature plan, finds the first unchecked `[ ]` sub-feature, and continues from there. One invocation can complete multiple sub-features until context fills or feature completes.
- **D-02:** State-file handoff on context limits — mark completed sub-features `[x]` in the feature plan, commit, update `milestone-status.txt`. Next `/build` invocation auto-resumes from the first unchecked item. The plan checklist IS the continuity mechanism.
- **D-03:** Commit per sub-feature — each completed sub-feature gets its own commit. Matches BUILD-03's "committable state" requirement. Clean git history, easy to bisect.
- **D-04:** Checklist recap after each sub-feature — after completing each sub-feature, show the full checklist with `[x]` marks and announce what's next. Keeps the user oriented within the session.

### Codebase assessment refresh
- **D-05:** Incremental git-diff update — check git history since last assessment date. Read only changed/new files. Update the Recent Changes section and any affected sections. Fast and focused, preserves existing assessment structure.
- **D-06:** Refresh timing — refresh `docs/codebase-assessment.md` BEFORE reading the feature plan. Ensures implementation decisions are grounded in current codebase state.
- **D-07:** Standalone commit for assessment refresh — commit the updated assessment before starting implementation. Clean separation between "understood the codebase" and "started building".

### Test execution & failure handling
- **D-08:** Test runs at feature completion only — run the feature's test command once after all sub-features are done. Per BUILD-05, test pass gates feature completion. Sub-features are validated by committable state, not test runs.
- **D-09:** Hard stop with diagnosis on test failure — stop implementation, show the test output, diagnose the failure, and present options: fix and re-run, update test command (BUILD-06), or exit for user to investigate. No automatic retry loop.
- **D-10:** Test command update via inline failure handling — when tests fail, one of the options is "Update test command". User provides corrected command, `/build` writes it to the feature plan, re-runs. Natural flow within the failure handling UX, no separate proactive step.

### Deviation recording
- **D-11:** Claude detects + user confirms — when `/build`'s implementation diverges from what the plan or architecture doc specified, Claude flags it: "This deviates from the plan because X. Record as deviation?" User confirms or dismisses.
- **D-12:** Structured 4-field entry per DESIGN.md — each deviation records: what changed, what was originally planned, why the change was necessary, and impact on other components. Enough for `/design` refresh mode to consolidate intelligently.
- **D-13:** Write deviations immediately when detected — write the deviation entry to the feature plan as soon as it's confirmed. Gets committed with the sub-feature that caused it. Deviation is never lost even if session ends unexpectedly.

### Claude's Discretion
- Exact sub-agent prompt for incremental codebase assessment refresh
- How to detect which files changed since last assessment (git log strategy)
- Commit message format for sub-feature commits
- How to detect deviations from the architecture doc (comparison heuristics)
- Internal session progress tracking approach
- How to handle edge cases when plan has ambiguous sub-feature boundaries

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Build requirements and design
- `skills/project/DESIGN.md` — Authoritative design decisions DD-1 through DD-13; feature plan lifecycle (line ~810-836), milestone-status.txt format, progress.txt format
- `.planning/REQUIREMENTS.md` — BUILD-01 through BUILD-09 acceptance criteria

### Prior skill implementations (pattern reference)
- `skills/project/plan/SKILL.md` — Most recent skill; flow controller pattern, reference file loading, state reading
- `skills/project/plan/references/gate-4-plan.md` — Gate 4 spec; defines the feature plan structure that /build consumes
- `skills/project/plan/assets/feature-plan-template.md` — Feature plan template; defines sub-feature checklist format /build marks as complete

### Shared references
- `skills/project/plan/references/progress-format.md` — Progress.txt format spec (to be copied into /build's own references/)
- `skills/project/plan/references/review-checklist-template.md` — Review checklist template pattern

### State file formats
- `skills/project/DESIGN.md` §milestone-status.txt — Feature entry format, status transitions, sub-feature checklists
- `skills/project/DESIGN.md` §progress.txt — Milestone summary format, completion counting

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/project/plan/SKILL.md` — Flow controller pattern (~160 lines) with reference file loading, prerequisite validation, state reading. Direct template for `/build`'s SKILL.md.
- `skills/project/plan/references/` — Reference file structure: gate spec, progress format, review checklist template, revision mode. `/build` will follow the same decomposition.
- `skills/project/define/references/gate-0-codebase.md` — Gate 0 codebase scan spec. Informs how to structure the incremental refresh approach.

### Established Patterns
- SKILL.md as flow controller (~150-300 lines) loading reference files from `references/` and templates from `assets/`
- Own copy of `progress-format.md` per skill — no cross-directory reads
- Sub-agent spawning for codebase analysis (used in `/define` Gate 0, `/design` Gate 2, `/plan` Gate 4)
- `AskUserQuestion` for all interactive prompts (2-4 options, max 12-char headers)
- Produce-then-review for review checklists; all items `[x]` or `[-]` before approval

### Integration Points
- Reads: `progress.txt`, `milestone-status.txt`, feature plan (`milestones/<NN>-<name>/plans/<feature>.md`), `docs/codebase-assessment.md`, `docs/ARCHITECTURE_AND_DESIGN.md`
- Writes: `docs/codebase-assessment.md` (refresh), feature plan (sub-feature `[x]` marks, architectural deviations), `milestone-status.txt` (feature status), `progress.txt` (milestone summary on feature completion)
- `/build` is the first skill that writes to BOTH `milestone-status.txt` AND `progress.txt`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following the established skill patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-build*
*Context gathered: 2026-04-03*
