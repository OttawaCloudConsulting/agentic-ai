# Requirements: Project Skill Suite

**Defined:** 2026-04-02
**Core Value:** Every phase transition requires explicit human approval, preventing AI drift from user intent.

---

## v1 Requirements

### Router (`/project`)

- [x] **PROJ-01**: `/project` bootstraps `progress.txt` with gate entries and no milestones on first run (only state write it ever performs)
- [x] **PROJ-02**: `/project` reads `progress.txt` and `milestones/*/milestone-status.txt` and reports current project state — which gates are approved, which milestone is active, next recommended action
- [x] **PROJ-03**: `/project` routes user to the correct next skill by outputting a plain-language instruction (it does not auto-dispatch; the user starts a new conversation)
- [x] **PROJ-04**: `/project` validates that artifact file paths listed alongside approved gates exist on disk; warns (does not block) when missing
- [x] **PROJ-05**: `/project` validates consistency between milestone summary status in `progress.txt` and each `milestone-status.txt`; warns on divergence
- [x] **PROJ-06**: `/project` offers Gate WB when no `working-backwards.md` exists and customer outcome is unclear; records `[ ] Pending` in `progress.txt` if user defers the decision
- [x] **PROJ-07**: `/project` detects Gate WB `Pending` state on invocation and re-prompts user for a decision before reporting any further status
- [x] **PROJ-08**: `/project` routes to `/define` in revision mode when user signals project-level goals have changed
- [x] **PROJ-09**: `/project` routes to `/milestone` in revision mode when user initiates milestone re-planning
- [x] **PROJ-10**: `/project` remains strictly read-only after bootstrap — never modifies state files in normal operation

### Define (`/define`)

- [ ] **DEF-01**: `/define` detects greenfield projects (empty dir or boilerplate-only) and skips Gate 0, proceeding directly to Gate WB offer or Gate 1
- [ ] **DEF-02**: `/define` scans the codebase at Gate 0: file structure, naming patterns, dependency graph, git history, architectural conventions
- [ ] **DEF-03**: `/define` produces `docs/codebase-assessment.md` at Gate 0 with sections: Project Overview, File Organization, Detected Patterns, Dependency Graph, Assumptions, Patterns to Deviate From, Open Questions, Recent Changes
- [ ] **DEF-04**: `/define` produces a gate review checklist file at each gate (Gate 0: `docs/reviews/gate-0-review.md`, Gate WB: `docs/reviews/gate-wb-review.md`, Gate 1: `docs/reviews/gate-1-review.md`)
- [ ] **DEF-05**: `/define` presents Gate 0 findings to user and supports in-session correction before approval
- [ ] **DEF-06**: `/define` validates all review checklist items are resolved (`[x]` or `[-]` N/A with reason) before recording gate approval in `progress.txt`
- [ ] **DEF-07**: `/define` records Gate 0 approval in `progress.txt`: `[x] Gate 0: Codebase Alignment  Approved: <date>  docs/codebase-assessment.md`
- [ ] **DEF-08**: `/define` offers Gate WB after Gate 0; records `[x]` (approved), `[-] Skipped`, or `[ ] Pending — offered, awaiting decision` in `progress.txt`
- [ ] **DEF-09**: `/define` at Gate WB produces `docs/working-backwards.md` with: Press Release (customer, problem, solution, experience, quote, CTA), External FAQ, Internal FAQ
- [x] **DEF-10**: `/define` conducts a PRD interview at Gate 1, using approved PR/FAQ as primary input when Gate WB was used
- [x] **DEF-11**: `/define` produces `prd.md` at Gate 1 with sections: Summary, Goals, Non-Goals, External Dependencies, Milestones (initially empty), Configuration, Outputs, Risk Assessment, Future Enhancements
- [x] **DEF-12**: `/define` supports partial Gate 1 approval — user can approve parts and request revision of others; skill revises in-session (no restart)
- [x] **DEF-13**: `/define` records Gate 1 approval in `progress.txt`: `[x] Gate 1: Scope Review  Approved: <date>  prd.md`
- [ ] **DEF-14**: `/define` runs Gates 0, WB, and 1 as a single continuous session — user does not leave the conversation between gates
- [x] **DEF-15**: `/define` in revision mode reads existing `prd.md` and runs a focused interview on what changed; does not automatically reset downstream artifacts; surfaces affected artifact list for user decision
- [x] **DEF-16**: `/define` re-reads `docs/codebase-assessment.md` from disk at Gate 1 rather than relying on in-session memory (context rot mitigation)

### Design (`/design`)

- [ ] **DES-01**: `/design` validates Gate 1 is approved in `progress.txt` before proceeding; reports missing prerequisite and declines if not met
- [ ] **DES-02**: `/design` reads `prd.md` and `docs/codebase-assessment.md` (if exists) as primary inputs
- [ ] **DES-03**: `/design` produces `docs/ARCHITECTURE_AND_DESIGN.md` with sections: Design Decisions (numbered table with decision/rationale/tradeoff/alternatives), Component Inventory, Data Flow, File Organization, Deployment & Operations, Security Considerations
- [ ] **DES-04**: `/design` produces `docs/reviews/gate-2-review.md` checklist
- [ ] **DES-05**: `/design` presents architecture for review focused on feasibility, tech fit, and completeness; highlights key tradeoffs explicitly
- [ ] **DES-06**: `/design` supports in-session revision before approval
- [ ] **DES-07**: `/design` records Gate 2 approval in `progress.txt`: `[x] Gate 2: Design Review  Approved: <date>  docs/ARCHITECTURE_AND_DESIGN.md`
- [ ] **DES-08**: `/design` in refresh mode consolidates accumulated architectural deviations from feature plans into an updated `docs/ARCHITECTURE_AND_DESIGN.md`

### Milestone (`/milestone`)

- [ ] **MIL-01**: `/milestone` validates Gate 2 is approved in `progress.txt` before proceeding
- [ ] **MIL-02**: `/milestone` reads `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `progress.txt` as primary inputs; reads spike artifacts when referenced
- [ ] **MIL-03**: `/milestone` auto-increments milestone sequence number from existing `milestones/` directories (`01`, `02`, …)
- [ ] **MIL-04**: `/milestone` produces `milestones/<NN>-<name>/README.md` with sections: Goal, Features (numbered with acceptance criteria), Dependencies, Ordering, Sizing, Configuration, Definition of Done
- [ ] **MIL-05**: `/milestone` produces `milestones/<NN>-<name>/milestone-status.txt` with feature entries at `[ ]` pending status
- [ ] **MIL-06**: `/milestone` produces `milestones/<NN>-<name>/reviews/gate-3-review.md` checklist
- [ ] **MIL-07**: `/milestone` adds milestone summary line to `progress.txt`: `[ ] Milestone <NN>: <Name>  milestones/<NN>-<name>/  0/<N> features complete`
- [ ] **MIL-08**: `/milestone` presents milestone breakdown for review focused on feature grouping coherence, ordering, sizing realism, acceptance criteria specificity
- [ ] **MIL-09**: `/milestone` records Gate 3 approval as `[~] In progress` in `progress.txt` — Gate 3 stays open until user signals all milestones are defined
- [ ] **MIL-10**: `/milestone` in revision mode loads existing milestone artifacts and offers to revise rather than overwrite
- [ ] **MIL-11**: `/milestone` in revision mode identifies affected features, presents the list for user confirmation before resetting those features to pending in `milestone-status.txt`
- [ ] **MIL-12**: `/milestone` in revision mode preserves completed features' status — only resets features explicitly identified as affected
- [ ] **MIL-13**: `/milestone` in revision mode updates the milestone summary line in `progress.txt` and the milestone's 1-2 sentence summary in `prd.md`

### Plan (`/plan`)

- [ ] **PLAN-01**: `/plan` reads milestone `README.md`, `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `progress.txt`, `milestone-status.txt` as primary inputs
- [ ] **PLAN-02**: `/plan` validates the target feature exists in the milestone README and is in pending or needs-replanning status
- [ ] **PLAN-03**: `/plan` produces `milestones/<NN>-<name>/plans/<feature>.md` with sections: Summary, Acceptance Criteria, Approach, Sub-Features (checklist), Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Files to Create/Modify, Dependencies, Architectural Deviations (empty)
- [ ] **PLAN-04**: `/plan` sizes sub-features to fit within a single `/build` session (~120k tokens on 200k-token model); flags oversized sub-features and proposes splits
- [ ] **PLAN-05**: `/plan` produces `milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md` checklist
- [ ] **PLAN-06**: `/plan` updates `milestone-status.txt` with the plan file path on plan creation
- [ ] **PLAN-07**: `/plan` presents plan for review focused on implementation correctness, edge case coverage, sub-feature sizing, test command appropriateness
- [ ] **PLAN-08**: `/plan` supports in-session revision before approval
- [ ] **PLAN-09**: `/plan` records Gate 4 approval by updating the feature entry in `milestone-status.txt` from `[ ]` to `[~] planned, awaiting build`

### Build (`/build`)

- [ ] **BUILD-01**: `/build` validates that a Gate 4-approved plan exists for the target feature before beginning implementation
- [ ] **BUILD-02**: `/build` refreshes `docs/codebase-assessment.md` at the start of each new feature: re-reads codebase, checks git history for commits since last assessment, updates Recent Changes section
- [ ] **BUILD-03**: `/build` implements sub-features from the feature plan checklist in order; each sub-feature leaves the codebase in a committable state
- [ ] **BUILD-04**: `/build` marks each completed sub-feature `[x]` in the feature plan checklist
- [ ] **BUILD-05**: `/build` runs the feature's test command on completion; only marks feature complete when test passes (exit code 0)
- [ ] **BUILD-06**: `/build` supports test command update mid-build — user provides corrected command; skill updates the feature plan (no gate re-approval needed)
- [ ] **BUILD-07**: `/build` records architectural deviations in the feature plan's Architectural Deviations section when approved design cannot be followed as planned
- [ ] **BUILD-08**: `/build` updates `milestone-status.txt` on sub-feature and feature completion; marks feature `[x]` complete when all sub-features pass
- [ ] **BUILD-09**: `/build` updates `progress.txt` milestone summary on feature completion (increment count); marks milestone `[x]` when last feature completes

### Spike (`/spike`)

- [ ] **SPIKE-01**: `/spike` accepts a user-defined research question and list of available tooling; spawns a research sub-agent to investigate
- [ ] **SPIKE-02**: `/spike` spawns a red-team sub-agent to validate research findings (factual errors, missing alternatives, flawed reasoning, unverified assumptions)
- [ ] **SPIKE-03**: `/spike` produces `docs/spikes/<topic>.md` with sections: Question, Available Tooling, Methodology, Findings, Red-Team Assessment, Recommendation, Status (open/resolved), Follow-Up Log
- [ ] **SPIKE-04**: `/spike` adds spike entry to `progress.txt` under `## Spikes` section
- [ ] **SPIKE-05**: `/spike` in follow-up mode appends a new entry to the Follow-Up Log of the existing spike artifact rather than overwriting
- [ ] **SPIKE-06**: `/spike` marks spike `[x]` resolved in `progress.txt` when user signals resolution

### State Files

- [x] **STATE-01**: `progress.txt` (project-level) uses plain-text checkbox notation; contains gate entries, milestone summary lines (one per milestone), and spikes section
- [x] **STATE-02**: `milestone-status.txt` (per-milestone) uses plain-text checkbox notation; contains one feature entry per milestone feature with plan path, sub-feature checklist, and notes
- [x] **STATE-03**: All skills read state files fresh on entry — no reliance on in-session memory for state
- [x] **STATE-04**: Skills write `milestone-status.txt` before `progress.txt` when both require updates (source-of-truth-first ordering for crash safety)

### Documentation

- [ ] **DOCS-01**: Each skill (`/project`, `/define`, `/design`, `/milestone`, `/plan`, `/build`, `/spike`) has a detail doc at `docs/skills/<name>.md`
- [ ] **DOCS-02**: `docs/SKILLS.md` catalog has a row for each new skill
- [ ] **DOCS-03**: Each skill directory (`skills/project/<name>/`) contains a `SKILL.md` entry point with `disable-model-invocation: true`

---

## v2 Requirements

### Enhancements

- **PROJ-V2-01**: `/project` offers spike research at contextually appropriate stages (post-Gate 2, during milestone planning, during build)
- **DEF-V2-01**: `/define` research-before-questions mode: brief web search for best practices before asking follow-up questions
- **MIL-V2-01**: Cross-milestone dependency visualization — `/project` surfaces when a milestone depends on deliverables from a prior milestone
- **BUILD-V2-01**: Context budget check before each sub-feature — proactive warning before hitting context limits
- **ARCH-V2-01**: Shared `references/` subdirectory for long interview guides and gate checklists used across multiple skills (avoids 500-line SKILL.md limit)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Code review / PR review | External processes handle this; DD-9 |
| Automatic cascade reset on PRD revision | User decides which downstream artifacts need re-review; no automatic cascade; DD-6 |
| CI/CD integration | External to this pipeline |
| Test generation / test management | Skill invokes test commands; user writes and manages tests; DD-12 |
| Monolithic upfront spec | Replaced by milestone-scoped PRDs; DD-1 |
| OAuth / account management | Not applicable — Claude Code skills have no user accounts |
| Parallel skill invocation | Each skill runs in a single conversation; parallelism not supported in this model |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROJ-01 | Phase 1 | Complete |
| PROJ-02 | Phase 1 | Complete |
| PROJ-03 | Phase 1 | Complete |
| PROJ-04 | Phase 1 | Complete |
| PROJ-05 | Phase 1 | Complete |
| PROJ-06 | Phase 1 | Complete |
| PROJ-07 | Phase 1 | Complete |
| PROJ-08 | Phase 1 | Complete |
| PROJ-09 | Phase 1 | Complete |
| PROJ-10 | Phase 1 | Complete |
| STATE-01 | Phase 1 | Complete |
| STATE-02 | Phase 1 | Complete |
| STATE-03 | Phase 1 | Complete |
| STATE-04 | Phase 1 | Complete |
| DEF-01 | Phase 2 | Pending |
| DEF-02 | Phase 2 | Pending |
| DEF-03 | Phase 2 | Pending |
| DEF-04 | Phase 2 | Pending |
| DEF-05 | Phase 2 | Pending |
| DEF-06 | Phase 2 | Pending |
| DEF-07 | Phase 2 | Pending |
| DEF-08 | Phase 2 | Pending |
| DEF-09 | Phase 2 | Pending |
| DEF-10 | Phase 2 | Complete |
| DEF-11 | Phase 2 | Complete |
| DEF-12 | Phase 2 | Complete |
| DEF-13 | Phase 2 | Complete |
| DEF-14 | Phase 2 | Pending |
| DEF-15 | Phase 2 | Complete |
| DEF-16 | Phase 2 | Complete |
| DES-01 | Phase 3 | Pending |
| DES-02 | Phase 3 | Pending |
| DES-03 | Phase 3 | Pending |
| DES-04 | Phase 3 | Pending |
| DES-05 | Phase 3 | Pending |
| DES-06 | Phase 3 | Pending |
| DES-07 | Phase 3 | Pending |
| DES-08 | Phase 3 | Pending |
| MIL-01 | Phase 4 | Pending |
| MIL-02 | Phase 4 | Pending |
| MIL-03 | Phase 4 | Pending |
| MIL-04 | Phase 4 | Pending |
| MIL-05 | Phase 4 | Pending |
| MIL-06 | Phase 4 | Pending |
| MIL-07 | Phase 4 | Pending |
| MIL-08 | Phase 4 | Pending |
| MIL-09 | Phase 4 | Pending |
| MIL-10 | Phase 4 | Pending |
| MIL-11 | Phase 4 | Pending |
| MIL-12 | Phase 4 | Pending |
| MIL-13 | Phase 4 | Pending |
| PLAN-01 | Phase 5 | Pending |
| PLAN-02 | Phase 5 | Pending |
| PLAN-03 | Phase 5 | Pending |
| PLAN-04 | Phase 5 | Pending |
| PLAN-05 | Phase 5 | Pending |
| PLAN-06 | Phase 5 | Pending |
| PLAN-07 | Phase 5 | Pending |
| PLAN-08 | Phase 5 | Pending |
| PLAN-09 | Phase 5 | Pending |
| BUILD-01 | Phase 6 | Pending |
| BUILD-02 | Phase 6 | Pending |
| BUILD-03 | Phase 6 | Pending |
| BUILD-04 | Phase 6 | Pending |
| BUILD-05 | Phase 6 | Pending |
| BUILD-06 | Phase 6 | Pending |
| BUILD-07 | Phase 6 | Pending |
| BUILD-08 | Phase 6 | Pending |
| BUILD-09 | Phase 6 | Pending |
| SPIKE-01 | Phase 7 | Pending |
| SPIKE-02 | Phase 7 | Pending |
| SPIKE-03 | Phase 7 | Pending |
| SPIKE-04 | Phase 7 | Pending |
| SPIKE-05 | Phase 7 | Pending |
| SPIKE-06 | Phase 7 | Pending |
| DOCS-01 | Phase 7 | Pending |
| DOCS-02 | Phase 7 | Pending |
| DOCS-03 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 78 total
- Mapped to phases: 78
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-02*
*Last updated: 2026-04-02 after roadmap creation*
