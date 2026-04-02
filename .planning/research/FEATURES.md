# Feature Landscape

**Domain:** Claude Code skills — gate-based AI-assisted development pipeline
**Source:** `skills/project/DESIGN.md` (fully specified design)
**Researched:** 2026-04-02
**Confidence:** HIGH — derived directly from authoritative design document

---

## Complete Feature Inventory by Skill

Feature IDs follow the pattern `<SKILL>-<NN>` where SKILL is a short prefix for each component.

---

### `/project` — Router / Orchestrator (PROJ)

| ID | Feature | Source |
|----|---------|--------|
| PROJ-01 | Bootstrap: detect absence of `progress.txt` and create it with gate entries and no milestones on first run | DD-3 |
| PROJ-02 | Read `progress.txt` and report current project state (which gates are approved, which milestone is active, next recommended action) | DD-3 |
| PROJ-03 | Route user to the correct phase skill based on state (tell user what to run next) | DD-2, DD-4 |
| PROJ-04 | Artifact validation: verify that artifact file paths listed alongside approved gates actually exist on disk; warn (do not block) when missing | DD-3 |
| PROJ-05 | Consistency validation: compare milestone summary status in `progress.txt` against each `milestone-status.txt`; warn on divergence | DD-3, DD-5 |
| PROJ-06 | Offer Gate WB when no `working-backwards.md` exists and customer outcome is unclear; record `[ ] Pending — offered, awaiting decision` in `progress.txt` if user defers decision | DD-11 |
| PROJ-07 | Detect Gate WB `Pending` state on invocation and re-prompt user for decision before reporting further status | DD-11 |
| PROJ-08 | Offer spike research at contextually appropriate stages (post-Gate 2, during milestone planning, during build); user accepts or declines | DD-14 |
| PROJ-09 | Route to `/define` in revision mode when user signals project-level goals have changed | DD-6 |
| PROJ-10 | Route to `/milestone` in revision mode when user initiates milestone re-planning | DD-6 |
| PROJ-11 | Remain strictly read-only after bootstrap (never modify state files except the one-time bootstrap write) | DD-3 |

**Edge cases:**
- PROJ-EC-01: `progress.txt` exists but is empty or malformed — warn user, offer to re-bootstrap
- PROJ-EC-02: `milestone-status.txt` file missing for a milestone listed in `progress.txt` — warn user, suggest recovery steps (recreate from README + git)
- PROJ-EC-03: Gate WB is in `Pending` state from a previous session — re-prompt before doing anything else
- PROJ-EC-04: All gates approved and all milestones complete — report project complete, no further routing needed
- PROJ-EC-05: Artifact path listed in `progress.txt` points to a file that was deleted — warn user but do not block; user decides whether to restore or proceed

---

### `/define` — Gates 0, WB, 1 (DEF)

`/define` runs as a single continuous session. Gates 0, WB, and 1 are internal approval checkpoints — the user approves each before `/define` proceeds to the next, but does not leave the conversation.

| ID | Feature | Source |
|----|---------|--------|
| DEF-01 | Greenfield detection: determine whether the project directory is empty or contains only boilerplate (README, .gitignore, package.json with no src/); skip Gate 0 if greenfield | DD-10 |
| DEF-02 | Gate 0 — codebase scan: scan file structure, key files, naming patterns, dependency graph, git history | DD-10 |
| DEF-03 | Gate 0 — produce `docs/codebase-assessment.md` with sections: Project Overview, File Organization, Detected Patterns, Dependency Graph, Assumptions to Carry Forward, Patterns to Deviate From (empty), Open Questions, Recent Changes | DD-10, Artifacts |
| DEF-04 | Gate 0 — produce `docs/reviews/gate-0-review.md` checklist with 4-item standard checklist | DD-13 |
| DEF-05 | Gate 0 — present findings to user: "Here's what I found — which patterns should I follow? Which should I deviate from?" | DD-8 |
| DEF-06 | Gate 0 — revision loop: incorporate user corrections into `docs/codebase-assessment.md` before approval | DD-7 |
| DEF-07 | Gate 0 — approval: validate all review checklist items resolved (`[x]` or `[-]` with reason); record `[x] Gate 0: Codebase Alignment  Approved: <date>  docs/codebase-assessment.md` in `progress.txt` | DD-7, DD-13 |
| DEF-08 | Gate 0 — record `[-] Gate WB: Working Backwards  Skipped` in `progress.txt` if user declines; record `[ ] Pending — offered, awaiting decision` if user defers | DD-11 |
| DEF-09 | Gate WB — offer Working Backwards: explain what it is and when it's useful; accept or skip based on user decision | DD-11 |
| DEF-10 | Gate WB — if activated: collaborate with user to produce `docs/working-backwards.md` with sections: Press Release (customer, problem, solution, experience, customer quote, CTA), External FAQ, Internal FAQ | DD-11, Artifacts |
| DEF-11 | Gate WB — produce `docs/reviews/gate-wb-review.md` checklist | DD-13 |
| DEF-12 | Gate WB — revision loop: refine PR/FAQ based on user feedback before approval | DD-7 |
| DEF-13 | Gate WB — approval: validate checklist; record `[x] Gate WB: Working Backwards  Approved: <date>  docs/working-backwards.md` in `progress.txt` | DD-7 |
| DEF-14 | Gate 1 — interview: conduct focused PRD interview; use approved PR/FAQ as primary input if Gate WB was used; otherwise start from user's idea | DD-8 |
| DEF-15 | Gate 1 — produce `prd.md` with sections: Summary, Goals, Non-Goals, External Dependencies, Milestones (1-2 sentence summaries, initially empty), Configuration, Outputs, Risk Assessment, Future Enhancements | Artifacts |
| DEF-16 | Gate 1 — produce `docs/reviews/gate-1-review.md` checklist | DD-13 |
| DEF-17 | Gate 1 — present PRD for review: focus on completeness and scope boundaries | DD-8 |
| DEF-18 | Gate 1 — revision loop: support partial approval ("features 1-3 OK, rethink 4"); revise in-session | DD-7 |
| DEF-19 | Gate 1 — approval: validate checklist; record `[x] Gate 1: Scope Review  Approved: <date>  prd.md` in `progress.txt` | DD-7 |
| DEF-20 | PRD revision mode: when invoked in revision mode, read existing `prd.md` and run focused interview on what changed rather than starting from scratch | DD-6 |
| DEF-21 | PRD revision mode: do NOT automatically reset downstream artifacts; present list of potentially affected downstream artifacts for user to decide | DD-6 |

**Edge cases:**
- DEF-EC-01: Codebase has inconsistent patterns (different authors, eras) — document inconsistency explicitly in assessment; ask user which pattern to carry forward
- DEF-EC-02: Gate 0 run on a very large codebase — produce a structured summary, not an exhaustive audit; focus on conventions and architecture, not every file
- DEF-EC-03: Session ends mid-Gate (e.g., after Gate 0 but before Gate WB decision) — on next invocation, `/project` detects incomplete state and routes back to `/define`; `/define` resumes from last approved gate
- DEF-EC-04: User invokes `/define` when Gate 1 is already approved — treat as revision mode; confirm before overwriting `prd.md`
- DEF-EC-05: Greenfield project where no git history exists — skip git history section of codebase assessment gracefully
- DEF-EC-06: `docs/working-backwards.md` already exists when Gate WB is offered — load existing content and ask whether to revise or use as-is

---

### `/design` — Gate 2 (DES)

| ID | Feature | Source |
|----|---------|--------|
| DES-01 | Read `prd.md` and `docs/codebase-assessment.md` (if exists) as primary inputs | DD-4 |
| DES-02 | Read `progress.txt` to validate Gate 1 is approved before proceeding | DD-7 |
| DES-03 | Produce `docs/ARCHITECTURE_AND_DESIGN.md` with sections: Design Decisions (numbered table with decision, rationale, tradeoff, alternatives), Component Inventory, Data Flow, File Organization, Deployment & Operations, Security Considerations | Artifacts |
| DES-04 | Produce `docs/reviews/gate-2-review.md` checklist | DD-13 |
| DES-05 | Present architecture for review: focus on feasibility, tech fit, completeness; highlight key tradeoffs explicitly | DD-8 |
| DES-06 | Revision loop: support in-session revision of architecture doc before approval | DD-7 |
| DES-07 | Approval: validate all checklist items resolved; record `[x] Gate 2: Design Review  Approved: <date>  docs/ARCHITECTURE_AND_DESIGN.md` in `progress.txt` | DD-7 |
| DES-08 | Architecture refresh mode: when user requests consolidation of accumulated architectural deviations, read all feature plans' Architectural Deviations sections and produce an updated `docs/ARCHITECTURE_AND_DESIGN.md` | Artifacts |

**Edge cases:**
- DES-EC-01: `prd.md` is missing or incomplete when `/design` is invoked — report missing prerequisite; do not proceed
- DES-EC-02: Gate 1 not approved in `progress.txt` — warn user and decline to proceed without Gate 1 approval
- DES-EC-03: `docs/ARCHITECTURE_AND_DESIGN.md` already exists (re-planning scenario) — load existing content and treat as revision unless user specifies full restart
- DES-EC-04: No `docs/codebase-assessment.md` exists (greenfield) — proceed without it; note this in the design doc

---

### `/milestone` — Gate 3 (MIL)

`/milestone` is invoked once per milestone (each invocation defines or revises one milestone).

| ID | Feature | Source |
|----|---------|--------|
| MIL-01 | Read `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `progress.txt` as primary inputs | DD-4 |
| MIL-02 | Validate Gate 2 is approved in `progress.txt` before proceeding | DD-7 |
| MIL-03 | If spike artifacts are referenced by user, read relevant `docs/spikes/<topic>.md` files as additional input | DD-14 |
| MIL-04 | Determine next milestone sequence number from existing `milestones/` directories (auto-increment `<NN>`) | Artifacts |
| MIL-05 | Produce `milestones/<NN>-<name>/README.md` with sections: Goal, Features (numbered with acceptance criteria), Dependencies, Ordering (feature sequence with rationale), Sizing, Configuration, Definition of Done | Artifacts |
| MIL-06 | Produce `milestones/<NN>-<name>/milestone-status.txt` with feature entries at `[ ]` pending status, including plan path placeholders | Artifacts |
| MIL-07 | Produce `milestones/<NN>-<name>/reviews/gate-3-review.md` checklist | DD-13 |
| MIL-08 | Add milestone summary line to `progress.txt`: `[ ] Milestone <NN>: <Name>  milestones/<NN>-<name>/  0/<N> features complete` | DD-3 |
| MIL-09 | Present milestone breakdown for review: focus on grouping coherence, feature ordering, sizing realism, acceptance criteria specificity | DD-8 |
| MIL-10 | Revision loop: support in-session scope changes; track which features are added, removed, or reordered | DD-7 |
| MIL-11 | Approval: validate all checklist items resolved; record `[~] Gate 3: Milestone Review  In progress` in `progress.txt` (Gate 3 stays open until all milestones are defined) | DD-7 |
| MIL-12 | Revision mode: detect existing milestone artifacts on re-invocation; offer to revise rather than overwrite | DD-6 |
| MIL-13 | Revision mode: identify which features are affected by scope changes; present list to user for confirmation before resetting those features to `planned` status in `milestone-status.txt` | DD-6 |
| MIL-14 | Revision mode: update the milestone summary line in `progress.txt` to reflect new feature count and status | DD-6 |
| MIL-15 | Revision mode: update the milestone's corresponding 1-2 sentence summary line in `prd.md` when scope changes | DD-6 |
| MIL-16 | Preserve completed features' status during revision — only reset features explicitly identified as affected by the scope change | DD-6 |

**Edge cases:**
- MIL-EC-01: Gate 2 not approved — warn and decline to proceed
- MIL-EC-02: `milestones/` directory has no existing subdirectories — first milestone, sequence starts at `01`
- MIL-EC-03: Milestone name slug collides with an existing directory — append a distinguishing suffix or prompt user to rename
- MIL-EC-04: Re-planning of a milestone that has partially completed features — present completed features explicitly; confirm that user wants to reset only the identified affected features
- MIL-EC-05: `milestone-status.txt` is missing for an existing milestone — offer to recreate from README feature list before proceeding with new milestone definition
- MIL-EC-06: PRD milestone summaries section is out of sync with milestone directory contents — flag discrepancy; update PRD before approval
- MIL-EC-07: User defines all milestones in one session vs. across multiple sessions — behavior must be identical; Gate 3 status stays `[~] In progress` until user explicitly signals milestone planning is complete

---

### `/plan` — Gate 4 (PLAN)

`/plan` is invoked once per feature (one feature plan per invocation).

| ID | Feature | Source |
|----|---------|--------|
| PLAN-01 | Read milestone `README.md`, `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `progress.txt`, `milestone-status.txt` as primary inputs | DD-4 |
| PLAN-02 | Validate the target feature exists in the milestone README and is in `[ ]` pending or needs-replanning status in `milestone-status.txt` | DD-7 |
| PLAN-03 | If spike artifacts are referenced by user, read relevant `docs/spikes/<topic>.md` as additional input | DD-14 |
| PLAN-04 | Produce `milestones/<NN>-<name>/plans/<feature>.md` with sections: Summary, Acceptance Criteria (from milestone README, refined), Approach, Sub-Features (checklist), Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Files to Create/Modify, Dependencies, Architectural Deviations (empty initially) | Artifacts |
| PLAN-05 | Size sub-features: each sub-feature must fit within a single `/build` session (~120k tokens on 200k-token model); flag oversized sub-features | DD-1 |
| PLAN-06 | Produce `milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md` checklist | DD-13 |
| PLAN-07 | Update `milestone-status.txt`: add plan file path to the feature entry (`Plan: milestones/<NN>-<name>/plans/<feature>.md`) | DD-4 |
| PLAN-08 | Present plan for review: focus on implementation correctness, edge case coverage, sub-feature sizing, test command appropriateness | DD-8 |
| PLAN-09 | Revision loop: revise feature plan in-session before approval | DD-7 |
| PLAN-10 | Approval: validate all checklist items resolved; update feature entry in `milestone-status.txt` from `[ ]` to `[~] planned, awaiting build` | DD-7 |

**Edge cases:**
- PLAN-EC-01: Specified feature does not exist in milestone README — report error; do not create orphan plan
- PLAN-EC-02: Feature plan already exists for this feature (re-planning) — load existing plan, present diff of what changed in the milestone README since last plan, offer targeted revision
- PLAN-EC-03: Milestone README has no explicit feature ordering — infer ordering from dependencies section; ask user to confirm
- PLAN-EC-04: Test command requires external infrastructure not yet available (e.g., deployed service) — document in plan; note the dependency explicitly
- PLAN-EC-05: Sub-feature sizing pushes past the ~120k token target — split into smaller sub-features; present the proposed split to user for confirmation
- PLAN-EC-06: Feature has dependencies on another feature in the same milestone that is not yet planned — note the dependency in the plan; do not block but surface the ordering concern

---

### `/spike` — Spike Research (SPIKE)

| ID | Feature | Source |
|----|---------|--------|
| SPIKE-01 | Accept user-defined research question or hypothesis and list of available tooling (MCP servers, web crawlers, local docs, cloned repos) | DD-14 |
| SPIKE-02 | Read `progress.txt` to associate the spike with the current project | DD-14 |
| SPIKE-03 | Spawn research sub-agent with access to provided tooling; agent investigates the question and produces structured findings | DD-14 |
| SPIKE-04 | Research agent maintains investigation memory to enable targeted follow-up without re-doing prior work | DD-14 |
| SPIKE-05 | Spawn red-team sub-agent to perform a single validation pass on research findings: check for factual errors, missing alternatives, flawed reasoning, unverified assumptions, investigation gaps | DD-14 |
| SPIKE-06 | Produce `docs/spikes/<topic>.md` with sections: Question, Available Tooling, Methodology, Findings, Red-Team Assessment, Recommendation, Status (`open` or `resolved`), Follow-Up Log | Artifacts |
| SPIKE-07 | Add spike entry to `progress.txt` under `## Spikes` section: `[ ] Spike: <Topic>  docs/spikes/<topic>.md` with NOTES field | DD-14 |
| SPIKE-08 | Follow-up mode: on re-invocation for the same topic, append a new entry to the Follow-Up Log in the existing spike artifact rather than overwriting | DD-14 |
| SPIKE-09 | Status update: when user marks spike as resolved, update `progress.txt` spike entry from `[ ]` to `[x]` and record resolution note in NOTES field | DD-14 |

**Edge cases:**
- SPIKE-EC-01: User initiates a spike on a topic that already has a spike artifact — detect existing file and ask whether this is a follow-up or a new independent investigation
- SPIKE-EC-02: No tooling is available (no MCP, no web access) — warn user that research will be limited to training knowledge only; proceed if user confirms
- SPIKE-EC-03: Research agent produces findings that the red-team agent completely invalidates — present both in the artifact; include a recommendation that acknowledges the contradiction; do not suppress either perspective
- SPIKE-EC-04: Spike topic slug collides with an existing spike file — prompt user for a disambiguating name

---

### `/build` — Implementation (BUILD)

| ID | Feature | Source |
|----|---------|--------|
| BUILD-01 | Read feature plan (`milestones/<NN>-<name>/plans/<feature>.md`), `docs/codebase-assessment.md`, `progress.txt`, `milestone-status.txt`, `docs/ARCHITECTURE_AND_DESIGN.md` as primary inputs | DD-4 |
| BUILD-02 | Validate that a Gate 4-approved plan exists for the target feature before beginning implementation | DD-7 |
| BUILD-03 | Refresh `docs/codebase-assessment.md` at the start of each new feature: re-read codebase, check git history for commits since last assessment, update Recent Changes section to reflect out-of-band changes | DD-10 |
| BUILD-04 | Implement each sub-feature from the feature plan's sub-feature checklist, in order; each sub-feature must leave the codebase in a committable state | DD-1 |
| BUILD-05 | Update feature plan sub-feature checklist: mark each sub-feature `[x]` as completed | DD-4 |
| BUILD-06 | Run the feature's Test Command on feature completion; treat exit code 0 as pass; do not advance to complete status until test passes | DD-12 |
| BUILD-07 | Support test command update mid-build: user can provide corrected test command; update `Test Command:` field in feature plan (no gate re-approval needed) | DD-12 |
| BUILD-08 | Record architectural deviations: when the approved design cannot be followed as planned, add an entry to the feature plan's Architectural Deviations section (what changed, what was planned, why, impact on other components) | Artifacts |
| BUILD-09 | Update `milestone-status.txt` on sub-feature completion: update notes field with progress; mark feature `[x]` complete when all sub-features pass | DD-4 |
| BUILD-10 | Update `progress.txt` milestone summary on feature completion: increment feature count (e.g., `2/3 features complete`) and update milestone status checkbox | DD-3 |
| BUILD-11 | When the last feature in a milestone is completed, set milestone status to `[x]` in `progress.txt` | DD-3 |

**Edge cases:**
- BUILD-EC-01: Feature plan references files that don't exist yet — create them as part of the build; do not fail on missing targets
- BUILD-EC-02: Test command fails after implementation — do not mark feature complete; report failure with exact exit code and output; resume implementation to address the failure
- BUILD-EC-03: Test command is not set in the feature plan — warn user; cannot mark feature complete without a passing test command; ask user to provide one
- BUILD-EC-04: Codebase has changed significantly since the feature plan was created (large diff detected in git history refresh) — surface the changes to the user before beginning implementation; ask whether the plan needs revision
- BUILD-EC-05: Sub-feature mid-build leaves codebase in broken state when session ends — on next invocation, report which sub-feature was in progress; do not silently continue from a broken state
- BUILD-EC-06: Architectural deviation is significant enough to affect other planned features — flag it explicitly; recommend the user consider a `/design` architecture refresh before continuing to the next feature
- BUILD-EC-07: Feature plan sub-feature checklist is entirely empty — ask user whether to proceed without a sub-feature breakdown or to return to `/plan` first

---

## State File Schemas

### `progress.txt` — Project Level

Plain text with checkbox notation. Human-editable. Survives `clear`, session gaps, machine switches.

```
# Progress: <Project Name>
# Created: <ISO date YYYY-MM-DD>
# Status legend: [ ] pending  [~] in progress  [x] complete  [-] skipped/N/A

## Gates

[x] Gate 0: Codebase Alignment          Approved: 2026-03-15  docs/codebase-assessment.md
[ ] Gate WB: Working Backwards           Pending — offered, awaiting decision
[x] Gate 1: Scope Review                Approved: 2026-03-16  prd.md
[x] Gate 2: Design Review               Approved: 2026-03-17  docs/ARCHITECTURE_AND_DESIGN.md
[~] Gate 3: Milestone Review             In progress
[ ] Gate 4: Plan Review                  (per feature, tracked in milestone-status.txt)

## Milestones

[~] Milestone 01: Core Auth              milestones/01-core-auth/   2/3 features complete
[ ] Milestone 02: Dashboard              milestones/02-dashboard/   0/2 features complete

## Spikes

[x] Spike: WebSocket Auth Compatibility  docs/spikes/websocket-auth.md
    NOTES: Resolved 2026-03-17. Confirmed middleware supports upgrade.

[ ] Spike: SQLite to Postgres Migration  docs/spikes/sqlite-postgres-migration.md
    NOTES: Started 2026-03-20. Follow-up pending on connection pooling.
```

**Gate line format:**
```
[<status>] Gate <N>: <Name>  <optional: Approved: YYYY-MM-DD  <artifact-path>>
```
- `[ ]` = pending (not yet begun or offered but not yet decided for Gate WB)
- `[~]` = in progress
- `[x]` = approved with timestamp and artifact path
- `[-]` = skipped (Gate WB only)

**Gate WB variants:**
```
[ ] Gate WB: Working Backwards           Pending — offered, awaiting decision
[-] Gate WB: Working Backwards           Skipped
[x] Gate WB: Working Backwards           Approved: 2026-03-15  docs/working-backwards.md
```

**Milestone line format:**
```
[<status>] Milestone <NN>: <Name>  milestones/<NN>-<name>/  <M>/<N> features complete
```
- `[ ]` = not started (0/N complete)
- `[~]` = in progress (M of N complete, 0 < M < N)
- `[x]` = complete (M == N)

**Spike line format:**
```
[<status>] Spike: <Topic>  <artifact-path>
    NOTES: <free-form note, date-stamped>
```
- `[ ]` = open / in progress
- `[x]` = resolved

---

### `milestones/<NN>-<name>/milestone-status.txt` — Milestone Level

```
# Milestone <NN>: <Name>
# Status: [<status>] <label>
# Updated: <ISO date>

[x] Feature <NN>.<M>: <Feature Name>
    Plan: milestones/<NN>-<name>/plans/<feature-slug>.md
    - <sub-feature description 1>
    - <sub-feature description 2>
    NOTES: Started <date>. Completed <date>.

[~] Feature <NN>.<M+1>: <Feature Name>
    Plan: milestones/<NN>-<name>/plans/<feature-slug>.md
    - [x] <sub-feature description 1>
    - [ ] <sub-feature description 2>
    NOTES: Started <date>.

[ ] Feature <NN>.<M+2>: <Feature Name>
    Plan: (not yet planned)
    NOTES:
```

**Feature line states:**
- `[ ]` = not started (no plan yet, or plan exists but build not begun)
- `[~]` = in progress (build session active, sub-features partially complete)
- `[x]` = complete (all sub-features done, test command passed)

**Sub-feature checklist states (indented under feature):**
- `- [ ]` = pending
- `- [x]` = complete

**Plan path transitions:**
- On `/milestone` creation: `Plan: (not yet planned)`
- After `/plan` Gate 4 approval: `Plan: milestones/<NN>-<name>/plans/<feature-slug>.md`

---

## Gate Artifact Inventory

Complete mapping of what each gate produces, exact file paths, and state transitions.

| Gate | Skill | Artifact Files Produced | State Written to `progress.txt` |
|------|-------|------------------------|----------------------------------|
| 0 — Alignment | `/define` | `docs/codebase-assessment.md`, `docs/reviews/gate-0-review.md` | `[x] Gate 0: Codebase Alignment  Approved: <date>  docs/codebase-assessment.md` |
| WB — Working Backwards (optional) | `/define` | `docs/working-backwards.md`, `docs/reviews/gate-wb-review.md` | `[x] Gate WB: Working Backwards  Approved: <date>  docs/working-backwards.md` OR `[-] Gate WB: Working Backwards  Skipped` OR `[ ] Gate WB: Working Backwards  Pending — offered, awaiting decision` |
| 1 — Scope | `/define` | `prd.md`, `docs/reviews/gate-1-review.md` | `[x] Gate 1: Scope Review  Approved: <date>  prd.md` |
| 2 — Design | `/design` | `docs/ARCHITECTURE_AND_DESIGN.md`, `docs/reviews/gate-2-review.md` | `[x] Gate 2: Design Review  Approved: <date>  docs/ARCHITECTURE_AND_DESIGN.md` |
| 3 — Milestone | `/milestone` | `milestones/<NN>-<name>/README.md`, `milestones/<NN>-<name>/milestone-status.txt`, `milestones/<NN>-<name>/reviews/gate-3-review.md` | Milestone summary line added; `prd.md` updated with 1-2 sentence summary for the milestone |
| 4 — Plan | `/plan` | `milestones/<NN>-<name>/plans/<feature>.md`, `milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md` | `milestone-status.txt` feature entry updated with plan path |
| — Spike | `/spike` | `docs/spikes/<topic>.md` | Spike entry added/updated under `## Spikes` in `progress.txt` |
| — Build | `/build` | Updates `docs/codebase-assessment.md` (refresh), feature plan (sub-feature checklist, deviations), `milestones/<NN>-<name>/milestone-status.txt` | Milestone feature count updated; milestone status set to `[x]` on final feature completion |

### Review Checklist File Format (All Gates)

All review files follow this structure:

```markdown
# Gate <N> Review — <Gate Name>

**Artifact:** <path to artifact under review>
**Status:** [ ] Pending | [x] Complete
**Reviewer(s):** <name(s)>
**Date:** <date>

## Checklist

- [ ] <gate-specific item 1>
- [ ] <gate-specific item 2>

## Reviewer Comments

<free-form feedback>
```

All items must reach `[x]` (approved) or `[-]` (N/A with reason) before the gate can be recorded as approved in `progress.txt`.

---

## Re-Planning Flows

### Milestone Re-Planning (DD-6)

**Trigger:** User tells `/project` that requirements changed within a milestone.

**Flow:**
1. User invokes `/project`, states the milestone needs re-planning
2. `/project` routes to `/milestone` with the target milestone identifier (PROJ-10)
3. `/milestone` detects existing artifacts for the milestone (MIL-12)
4. `/milestone` reads current `milestone-status.txt` to identify completed vs. in-progress vs. unstarted features
5. `/milestone` presents the existing milestone scope and asks what changed
6. `/milestone` identifies which features are affected by the scope change
7. `/milestone` presents the affected feature list to user for confirmation before any reset (MIL-13)
8. User confirms (or adjusts) the list of features to reset
9. `/milestone` updates `milestone-status.txt`: affected features reset to `[ ]` pending; their plan paths cleared; completed unaffected features retain `[x]` status (MIL-16)
10. `/milestone` updates the milestone `README.md` with revised scope
11. `/milestone` updates the milestone summary line in `progress.txt` with new feature count and status (MIL-14)
12. `/milestone` updates the milestone's 1-2 sentence summary in `prd.md` (MIL-15)
13. Revised milestone goes through Gate 3 review and approval before any `/plan` or `/build` work resumes on affected features

**State transitions during milestone re-planning:**
```
progress.txt: [x] Milestone 01: Core Auth  →  [~] Milestone 01: Core Auth  1/4 features complete
                                                  (reset count reflects only unaffected completed features)
milestone-status.txt: affected features: [x] or [~]  →  [ ] (plan path cleared)
                      unaffected completed features: [x]  →  [x] (unchanged)
prd.md: milestone summary line updated to reflect new scope
```

### PRD Revision (DD-6)

**Trigger:** User tells `/project` that project-level goals have changed.

**Flow:**
1. User invokes `/project`, states goals have changed
2. `/project` routes to `/define` in revision mode (PROJ-09)
3. `/define` reads existing `prd.md`
4. `/define` runs focused interview: "What changed? What's the same?" (DEF-20)
5. `/define` revises `prd.md` in place (targeted edits, not full rewrite where possible)
6. Revised `prd.md` goes through Gate 1 review
7. `/define` presents list of potentially affected downstream artifacts (Gate 2 architecture doc, milestone READMEs, feature plans) and asks user which need re-review (DEF-21)
8. User decides which downstream artifacts to revisit — no automatic cascade reset
9. For each downstream artifact the user marks as needing re-review, the corresponding gate approval in `progress.txt` is cleared (reverted from `[x]` to `[ ]`)

**State transitions during PRD revision:**
```
progress.txt: [x] Gate 1: Scope Review  Approved: <date>  prd.md
              →  (re-runs Gate 1 interview, new approval timestamp after revised PRD is approved)

User-directed downstream resets (no automatic cascade):
  If user marks Gate 2 for re-review: [x] Gate 2  →  [ ] Gate 2
  If user marks a milestone for re-review: [x] Milestone <NN>  →  [ ] Milestone <NN>
  Feature plans: user decides case-by-case
```

---

## Table Stakes vs. Differentiators

### Table Stakes (Must-Have for Any Functional Skill)

| Feature | Why Required |
|---------|-------------|
| State file read/write correctness | Every skill depends on `progress.txt` and `milestone-status.txt`; errors corrupt the pipeline |
| Gate approval recording | Timestamps and artifact paths must be accurate; source of truth for resumption |
| Checklist completeness validation before approval | Prevents premature gate advancement |
| Artifact path validation on read | Prevents silent failure when artifacts are missing |
| Graceful session resumption | Each skill must read state fresh; no assumption of previous session context |
| Revision loops in-session | Every gate supports reject-and-revise without leaving the conversation |

### Differentiators (Distinguish this Pipeline from Simple PRD Tools)

| Feature | Value |
|---------|-------|
| Three-level hierarchy with explicit sizing constraints | Prevents context rot by keeping sub-features scoped to single sessions |
| Gate WB (Working Backwards) | Forces customer-outcome clarity before any requirements are written |
| Codebase assessment refresh at each feature start | Catches out-of-band changes that would invalidate plans |
| Spike research with red-team validation | Adversarial review catches confirmation bias in exploratory research |
| Two-tier state files (project + milestone) | Keeps project-level state small and stable regardless of project scale |
| Offline reviewer checklists | Enables async team review without losing structure |
| Architectural deviation tracking in feature plans | Creates an audit trail for architecture refresh decisions |

### Anti-Features (Explicitly Out of Scope)

| Anti-Feature | Why Excluded |
|-------------|-------------|
| Code review / PR review | External tooling handles this better; pipeline ends at implementation (DD-9) |
| Test generation | Decoupled from testing frameworks; user owns test content (DD-12) |
| Automatic cascade resets on PRD revision | Too destructive; user must decide what downstream artifacts are affected (DD-6) |
| Direct skill invocation (bypassing `/project`) | Gate integrity must always go through the router (DD-3, DD-4) |
| Multi-user coordination / locking | Out of scope; handled by business processes and git (OQ-8) |
| Automatic architecture doc updates | User decides when to consolidate deviations; no automatic trigger |

---

## Feature Dependencies

```
PROJ-01 (bootstrap)
  ↓
DEF-01..DEF-07 (Gate 0)
  ↓
DEF-09..DEF-13 (Gate WB — optional, must resolve before Gate 1)
  ↓
DEF-14..DEF-19 (Gate 1)
  ↓
DES-01..DES-07 (Gate 2)
  ↓
MIL-01..MIL-11 (Gate 3 — one invocation per milestone)
  ↓
PLAN-01..PLAN-10 (Gate 4 — one invocation per feature)
  ↓
BUILD-01..BUILD-11 (Implementation — one invocation per feature)

Spikes:
SPIKE-01..SPIKE-09 — can occur between Gate 2 and Gate 3, or during build; non-blocking

Re-planning entry points:
PROJ-09 → DEF-20, DEF-21 (PRD revision)
PROJ-10 → MIL-12..MIL-16 (milestone revision)
DES-08 (architecture refresh, triggered by user via /project)
```

**Critical path:** Gate 0 → Gate WB (if activated, must resolve) → Gate 1 → Gate 2 → Gate 3 → Gate 4 → Build. Each gate's approval is a prerequisite for the next phase to begin.

---

## Sources

- `skills/project/DESIGN.md` — primary source; all design decisions (DD-1 through DD-14), artifact specifications, and file schemas are fully specified there
- Confidence: HIGH — derived directly from the authoritative design document; no external research required
