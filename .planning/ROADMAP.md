# Roadmap: Project Skill Suite

## Overview

Seven Claude Code skills built in gate order — `/project` first as the state contract foundation, then each downstream skill in the sequence a user would invoke them (`/define` → `/design` → `/milestone` → `/plan` → `/build`), with `/spike` last as the architecturally distinct non-blocking research tool. Documentation is bundled into each phase rather than deferred. Every phase delivers one complete, invokable skill with observable behavior verifiable by running it.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: /project Router** - Bootstraps state files, validates project state, routes user to correct next skill (completed 2026-04-02)
- [x] **Phase 2: /define (Gates 0/WB/1)** - Single-session codebase assessment, optional Working Backwards, and PRD creation (completed 2026-04-02)
- [x] **Phase 3: /design (Gate 2)** - Architecture and design document from approved PRD (completed 2026-04-02)
- [x] **Phase 4: /milestone (Gate 3)** - Per-milestone feature breakdown with acceptance criteria and revision support (completed 2026-04-02)
- [x] **Phase 5: /plan (Gate 4)** - Per-feature implementation plans with sub-feature sizing and interface contracts (completed 2026-04-03)
- [x] **Phase 6: /build** - Sub-feature-by-sub-feature implementation with state file updates and deviation tracking (completed 2026-04-03)
- [x] **Phase 7: /spike + Docs** - Adversarial research tool with red-team validation, plus suite documentation (completed 2026-04-03)
- [ ] **Phase 8: Fix Greenfield Routing** - Close routing ambiguity for Gate 0 `[-]` state on second `/project` invocation
- [ ] **Phase 9: Nyquist Compliance** - Complete Wave 0 test strategy for all 7 phases
- [ ] **Phase 10: Tech Debt Sweep** - Fix 4 low-severity documentation and attribution issues
- [ ] **Phase 11: Gate 3 Closure Pathway** - Resolve structural contradiction between PROJ-10 read-only rule and D-05 Gate 3 closure design

## Phase Details

### Phase 1: /project Router
**Goal**: Users can bootstrap a new project and get routed to the correct next skill on every subsequent invocation
**Depends on**: Nothing (first phase)
**Requirements**: PROJ-01, PROJ-02, PROJ-03, PROJ-04, PROJ-05, PROJ-06, PROJ-07, PROJ-08, PROJ-09, PROJ-10, STATE-01, STATE-02, STATE-03, STATE-04
**Success Criteria** (what must be TRUE):
  1. Running `/project` on an empty directory produces a valid `progress.txt` with gate stubs and no milestones, then becomes read-only
  2. Running `/project` on an existing project reports gate approval status, active milestone, and a plain-language instruction for the next skill to invoke
  3. Running `/project` when `progress.txt` references artifact paths that do not exist on disk produces a visible warning (does not block)
  4. Running `/project` when `progress.txt` and any `milestone-status.txt` are inconsistent produces a visible divergence warning
  5. Running `/project` when Gate WB is `[ ] Pending` prompts for resolution before reporting any other status
**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Reference specifications (progress format, routing logic, status report format)
- [x] 01-02-PLAN.md — SKILL.md main workflow file
- [ ] 01-03-PLAN.md — Documentation (detail doc + catalog entry)

### Phase 2: /define (Gates 0/WB/1)
**Goal**: Users can run a single continuous session that produces codebase assessment, optional Working Backwards doc, and an approved PRD
**Depends on**: Phase 1
**Requirements**: DEF-01, DEF-02, DEF-03, DEF-04, DEF-05, DEF-06, DEF-07, DEF-08, DEF-09, DEF-10, DEF-11, DEF-12, DEF-13, DEF-14, DEF-15, DEF-16
**Success Criteria** (what must be TRUE):
  1. On a brownfield project, `/define` produces `docs/codebase-assessment.md` before any gate approval is recorded
  2. On a greenfield project, `/define` skips Gate 0 and proceeds directly to Gate WB offer or Gate 1 interview
  3. Gate WB produces `docs/working-backwards.md` when approved; records `[-] Skipped` or `[ ] Pending` in `progress.txt` otherwise
  4. Gate 1 produces `prd.md` and records approval in `progress.txt` with date and artifact path; partial approval triggers in-session revision without restarting
  5. Revision mode reads existing `prd.md`, interviews on what changed, and surfaces a list of affected downstream artifacts for user decision without auto-resetting them
**Plans:** 4 plans

Plans:
- [x] 02-01-PLAN.md — Gate 0 + Gate WB reference files and shared references
- [x] 02-02-PLAN.md — Gate 1 reference file and adapted PRD template
- [x] 02-03-PLAN.md — SKILL.md flow controller
- [x] 02-04-PLAN.md — Documentation (detail doc + catalog entry)
**UI hint**: no

### Phase 3: /design (Gate 2)
**Goal**: Users can produce a complete architecture and design document from an approved PRD, with in-session revision before gate approval
**Depends on**: Phase 2
**Requirements**: DES-01, DES-02, DES-03, DES-04, DES-05, DES-06, DES-07, DES-08
**Success Criteria** (what must be TRUE):
  1. `/design` declines to run and reports the missing prerequisite when Gate 1 is not approved in `progress.txt`
  2. `/design` produces `docs/ARCHITECTURE_AND_DESIGN.md` with all required sections and a `docs/reviews/gate-2-review.md` checklist
  3. Gate 2 approval is recorded in `progress.txt` with date and artifact path only after the user explicitly approves; in-session revision is supported before approval
  4. Refresh mode consolidates accumulated architectural deviations from feature plans into an updated design document
**Plans:** 3 plans

Plans:
- [x] 03-01-PLAN.md — Reference files and architecture template (gate-2-design, refresh-mode, progress-format, review-checklist-template, architecture-template)
- [x] 03-02-PLAN.md — SKILL.md flow controller
- [x] 03-03-PLAN.md — Documentation (detail doc + catalog entry)

### Phase 4: /milestone (Gate 3)
**Goal**: Users can define milestones one at a time, with Gate 3 staying open until all milestones are defined, and revision mode preserving completed features
**Depends on**: Phase 3
**Requirements**: MIL-01, MIL-02, MIL-03, MIL-04, MIL-05, MIL-06, MIL-07, MIL-08, MIL-09, MIL-10, MIL-11, MIL-12, MIL-13
**Success Criteria** (what must be TRUE):
  1. `/milestone` declines to run and reports the missing prerequisite when Gate 2 is not approved in `progress.txt`
  2. Each invocation produces `milestones/<NN>-<name>/README.md`, `milestone-status.txt`, and a gate-3 review checklist with auto-incremented sequence number
  3. Gate 3 status in `progress.txt` is `[~] In progress` after milestone creation and transitions only when the user explicitly signals milestone planning is complete
  4. Revision mode surfaces all in-progress and complete features before any reset; only resets features the user identifies as affected; preserves completed features' status
**Plans:** 3 plans

Plans:
- [x] 04-01-PLAN.md — Reference files and milestone README template (gate-3-milestone, revision-mode, progress-format, review-checklist-template, milestone-readme-template)
- [x] 04-02-PLAN.md — SKILL.md flow controller
- [x] 04-03-PLAN.md — Documentation (detail doc + catalog entry)

### Phase 5: /plan (Gate 4)
**Goal**: Users can produce per-feature implementation plans with sub-feature sizing validation, and gate approval updates milestone-status.txt
**Depends on**: Phase 4
**Requirements**: PLAN-01, PLAN-02, PLAN-03, PLAN-04, PLAN-05, PLAN-06, PLAN-07, PLAN-08, PLAN-09
**Success Criteria** (what must be TRUE):
  1. `/plan` validates the target feature exists in the milestone README and is in pending or needs-replanning status before proceeding
  2. `/plan` produces `milestones/<NN>-<name>/plans/<feature>.md` with all required sections including an empty Architectural Deviations section and a test command
  3. Sub-features that exceed the ~120k-token sizing guideline are flagged with a proposed split before the plan is presented for review
  4. Gate 4 approval updates the feature entry in `milestone-status.txt` from `[ ]` to `[~] planned, awaiting build`; the plan file path is also recorded
**Plans:** 1/3 plans executed

Plans:
- [x] 05-01-PLAN.md — Reference files and feature plan template (gate-4-plan, revision-mode, review-checklist-template, progress-format, feature-plan-template)
- [ ] 05-02-PLAN.md — SKILL.md flow controller
- [x] 05-03-PLAN.md — Documentation (detail doc + catalog entry)

### Phase 6: /build
**Goal**: Users can implement features sub-feature by sub-feature, with each sub-feature leaving the codebase committable and state files updated incrementally
**Depends on**: Phase 5
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-05, BUILD-06, BUILD-07, BUILD-08, BUILD-09
**Success Criteria** (what must be TRUE):
  1. `/build` declines to begin implementation when no Gate 4-approved plan exists for the target feature
  2. `/build` refreshes `docs/codebase-assessment.md` at the start of each new feature before writing any code
  3. Each completed sub-feature is marked `[x]` in the feature plan and leaves the codebase in a committable state; architectural deviations are recorded in the plan when they occur
  4. Feature completion requires test command exit code 0; failure is a hard stop; `milestone-status.txt` is written before `progress.txt` rollup on completion
**Plans:** 3 plans

Plans:
- [x] 06-01-PLAN.md — Reference files (build-execution, codebase-refresh, deviation-recording, progress-format)
- [x] 06-02-PLAN.md — SKILL.md flow controller
- [x] 06-03-PLAN.md — Documentation (detail doc + catalog entry)

### Phase 7: /spike + Docs
**Goal**: Users can run adversarial technical research that produces a structured spike artifact, and every skill in the suite has complete documentation
**Depends on**: Phase 1 (for progress.txt spike section format); Phases 2-6 for documentation accuracy
**Requirements**: SPIKE-01, SPIKE-02, SPIKE-03, SPIKE-04, SPIKE-05, SPIKE-06, DOCS-01, DOCS-02, DOCS-03
**Success Criteria** (what must be TRUE):
  1. `/spike` produces `docs/spikes/<topic>.md` with research findings and a distinct red-team assessment section; the two perspectives are never merged or suppressed
  2. Follow-up mode appends a new log entry to an existing spike artifact without overwriting original findings; spike is marked `[x]` resolved in `progress.txt` when user signals resolution
  3. Each of the seven skills has a detail doc at `docs/skills/<name>.md` and a row in `docs/SKILLS.md`
  4. Each skill directory contains a `SKILL.md` with `disable-model-invocation: true` in its frontmatter
**Plans:** 3/3 plans complete

Plans:
- [x] 07-01-PLAN.md — Reference files and spike template
- [x] 07-02-PLAN.md — SKILL.md flow controller
- [x] 07-03-PLAN.md — Documentation (detail doc + catalog entry)

### Phase 8: Fix Greenfield Routing
**Goal**: Close the greenfield routing ambiguity — second `/project` invocation on a greenfield project routes correctly and Gate WB offer fires
**Depends on**: Phase 1 (routing-logic.md, SKILL.md)
**Requirements**: PROJ-03, PROJ-06 (gap closure)
**Gap Closure**: Closes `GREENFIELD-ROUTING` integration gap and `GREENFIELD-E2E` flow gap from v1.0 audit
**Success Criteria** (what must be TRUE):
  1. `routing-logic.md` has an explicit row for Gate 0 `[-]` (greenfield skip) state that routes correctly to Gate WB or Gate 1
  2. Gate WB offer condition in SKILL.md Step 5 fires for both `Gate 0 = [x]` and `Gate 0 = [-]` (greenfield)
  3. Second `/project` invocation on a greenfield project produces correct routing output — no ambiguous fall-through to unmatched state
**Plans:** 0 plans

### Phase 9: Nyquist Compliance
**Goal**: Complete Wave 0 test strategy for all 7 phases — define automated test coverage and mark `nyquist_compliant: true`
**Depends on**: All phases 1–7
**Requirements**: (tech debt — all phases, no new requirements)
**Gap Closure**: Closes systematic Nyquist compliance gap from v1.0 audit (0/7 phases compliant)
**Success Criteria** (what must be TRUE):
  1. All 7 phase VALIDATION.md files have `wave_0_complete: true` and `nyquist_compliant: true`
  2. Each phase has a defined test strategy covering its core observable behaviors
  3. Wave 0 tests run and pass for all 7 phases
**Plans:** 0 plans

### Phase 10: Tech Debt Sweep
**Goal**: Fix 4 low-severity documentation and attribution issues identified in v1.0 audit
**Depends on**: Phases 1, 4, 7
**Requirements**: (tech debt — no requirement changes)
**Gap Closure**: Closes SKILLS.md copy commands inconsistency, STATE-04 attribution, 04-03-SUMMARY.md missing frontmatter, ROADMAP.md stale checkboxes
**Success Criteria** (what must be TRUE):
  1. ROADMAP.md phase checkboxes are accurate (phases 1–7 show `[x]`, phases 8–11 show `[ ]`)
  2. `docs/SKILLS.md` consuming instructions list `cp` commands consistently for all skills (not just milestone/plan/spike)
  3. `/project` SKILL.md STATE-04 attribution accurately reflects which skill writes both files
  4. `04-03-SUMMARY.md` has `requirements-completed` frontmatter matching MIL requirements covered
**Plans:** 0 plans

### Phase 11: Gate 3 Closure Pathway
**Goal**: Resolve the structural contradiction between PROJ-10 (read-only after bootstrap) and D-05 (offer to close Gate 3) — either implement closure or explicitly document the constraint
**Depends on**: Phase 1 (SKILL.md, PROJ-10), Phase 4 (Gate 3 behavior)
**Requirements**: MIL-09, PROJ-10 (gap closure)
**Gap Closure**: Closes `GATE3-CLOSURE` integration gap from v1.0 audit (Gate 3 displays `[~] In progress` permanently)
**Success Criteria** (what must be TRUE):
  1. Either: Gate 3 closure pathway is implemented in `/project` SKILL.md with PROJ-10 updated to allow this specific write; OR: D-05 design decision is explicitly updated to acknowledge the read-only constraint makes automated closure impractical
  2. Gate 3 status on a fully-completed project is accurate, or the permanent `[~] In progress` display is explicitly documented as a known design limitation
**Plans:** 0 plans

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. /project Router | 3/3 | Complete | 2026-04-02 |
| 2. /define (Gates 0/WB/1) | 4/4 | Complete | 2026-04-02 |
| 3. /design (Gate 2) | 3/3 | Complete | 2026-04-02 |
| 4. /milestone (Gate 3) | 3/3 | Complete | 2026-04-02 |
| 5. /plan (Gate 4) | 3/3 | Complete | 2026-04-03 |
| 6. /build | 3/3 | Complete | 2026-04-03 |
| 7. /spike + Docs | 3/3 | Complete | 2026-04-03 |
| 8. Fix Greenfield Routing | 0/0 | Not started | - |
| 9. Nyquist Compliance | 0/0 | Not started | - |
| 10. Tech Debt Sweep | 0/0 | Not started | - |
| 11. Gate 3 Closure Pathway | 0/0 | Not started | - |
