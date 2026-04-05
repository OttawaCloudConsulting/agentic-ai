# Project Research Summary

**Project:** `/project` Skill Suite — Gate-Based AI-Assisted Development Pipeline
**Domain:** Claude Code skills (Markdown prompt files with YAML frontmatter)
**Researched:** 2026-04-02
**Confidence:** HIGH

## Executive Summary

This project builds seven Claude Code skills (`/project`, `/define`, `/design`, `/milestone`, `/plan`, `/build`, `/spike`) implementing a gate-based AI-assisted development pipeline. The pipeline solves a single core problem: context rot — the degradation of AI output quality when a long-running development workflow accumulates too much conversational history. The architecture's answer is strict context isolation: each phase skill runs in a fresh conversation, reconstructing context exclusively from files on disk. Skills are not compiled code; they are Markdown prompt files with YAML frontmatter, and files on disk are the only communication channel between them.

The recommended approach is to build `skills/` directories (Option B: one subdirectory per skill) following the `create-prd` reference pattern, with `SKILL.md` as the entry point, `assets/` for templates, and `references/` for overflow content exceeding the 500-line body limit. All seven skills must carry `disable-model-invocation: true` and implement plain-text state file schemas that were already researched and decided — the schemas are not open questions. The design is fully specified in `skills/project/DESIGN.md` (DD-1 through DD-14), which is the authoritative source; all feature IDs, artifact paths, and state file formats are derived from it directly.

The single highest risk is state file correctness: `progress.txt` and per-milestone `milestone-status.txt` are the backbone the entire pipeline runs on. Write errors, partial writes, or cross-skill writes to state files the skill doesn't own corrupt the pipeline in ways that are hard to diagnose. The second risk is gate UX: implicit approval (inferring approval from silence or continuation) collapses gate integrity and is the natural failure mode for AI agents optimizing for completion. Both risks have clear mitigations documented in PITFALLS.md and must be reflected in every skill's SKILL.md body.

---

## Key Findings

### Stack (from STACK.md)

There is no compiled stack. The "technology" is a set of file conventions. All constraints are hard requirements, not style guidelines.

**Core conventions:**
- **Skill directory structure** (`skills/<name>/SKILL.md` + `assets/` + `references/`): established pattern from `create-prd`; every new skill must follow it exactly
- **SKILL.md frontmatter** (`name`, `description`, `disable-model-invocation: true`): mandatory; auto-invocation would corrupt stateful pipeline
- **500-line SKILL.md body limit**: hard limit; overflow goes to `references/` with explicit read instructions in SKILL.md
- **Plain-text state files** (`.txt`, not YAML): already decided and rationale documented; ~53% more token-efficient than YAML equivalent; human-editable; tolerates minor formatting errors
- **Checkbox notation** (`[ ]` / `[~]` / `[x]` / `[-]`): established in `create-prd`; must be preserved verbatim
- **Artifact naming convention** (lowercase kebab-case, `.md` for docs, `.txt` for state, UPPERCASE reserved for project-wide reference docs): all paths resolved in DESIGN.md DD-14

**Documentation requirement (non-negotiable):** Each skill needs `docs/skills/<name>.md` (detail doc) and a row in `docs/SKILLS.md`. This is a repo-level requirement enforced by `memory/feedback_docs_required.md`.

**`create-prd` carry-forward patterns for `/define`:** prerequisites check, interrupted session recovery (resume from last approved gate), one-round-at-a-time interviews, show-work-after-each-step, template-first writing (read asset template before writing artifact), cross-reference enforcement. These are not optional refinements — they are the baseline UX contract.

### Features (from FEATURES.md)

75 discrete features across 7 skills, fully specified. Feature IDs follow `<SKILL>-<NN>` pattern. All features are derived from `skills/project/DESIGN.md` (HIGH confidence — primary source).

**Must-have (table stakes):**
- State file read/write correctness — every skill depends on this; errors corrupt the pipeline
- Gate approval recording with timestamp and artifact path — source of truth for session resumption
- Checklist completeness validation before approval — prevents premature gate advancement
- Artifact path validation on read — prevents silent failure when artifacts are missing
- Graceful session resumption — each skill reads state fresh with no assumption of prior context
- In-session revision loops — every gate supports reject-and-revise without leaving the conversation

**Key differentiators (what makes this more than a PRD tool):**
- Three-level hierarchy with explicit sub-feature sizing constraints (60% of 200k context = ~120k tokens per sub-feature) — prevents context rot at the build phase
- Gate WB (Working Backwards) — optional but high-value; forces customer-outcome clarity before requirements are written
- Codebase assessment refresh at each feature build start — catches out-of-band changes that would invalidate plans
- Spike research with adversarial red-team validation pass — prevents confirmation bias in exploratory research
- Two-tier state files (project-level `progress.txt` + per-milestone `milestone-status.txt`) — keeps project state small regardless of project scale
- Architectural deviation tracking in feature plans — creates audit trail for architecture refresh decisions

**Explicit anti-features (out of scope):**
- Code review / PR review — external tooling handles this
- Automatic cascade resets on PRD revision — too destructive; user decides what downstream artifacts are affected
- Skills calling each other as sub-agents — defeats context isolation
- Multi-user coordination / locking — handled by git and business process

**Gate artifact inventory (complete):**

| Gate | Skill | Primary Artifact |
|------|-------|-----------------|
| 0 — Codebase Alignment | `/define` | `docs/codebase-assessment.md` |
| WB — Working Backwards (optional) | `/define` | `docs/working-backwards.md` |
| 1 — Scope | `/define` | `prd.md` |
| 2 — Design | `/design` | `docs/ARCHITECTURE_AND_DESIGN.md` |
| 3 — Milestone (per milestone) | `/milestone` | `milestones/<NN>-<name>/README.md` |
| 4 — Plan (per feature) | `/plan` | `milestones/<NN>-<name>/plans/<feature>.md` |
| — Spike | `/spike` | `docs/spikes/<topic>.md` |
| — Build | `/build` | Codebase + state file updates |

### Architecture (from ARCHITECTURE.md)

The pipeline is a **file-mediated, human-routed, context-isolated skill chain**. Skills do not call each other. `/project` is a stateless read-only router that tells the human which skill to invoke next. The human opens a fresh conversation and runs that skill. This is not a limitation — it is the mechanism that provides context isolation.

**Major components and responsibilities:**

1. **`/project`** — Read `progress.txt`, validate artifact paths and milestone state consistency, report status, direct user to next skill. Bootstrap `progress.txt` on first run (one-time write only; strictly read-only thereafter).
2. **`/define`** — Single continuous session spanning Gates 0, WB, and 1. Produces codebase assessment (brownfield), optional Working Backwards doc, and PRD. The three gates are internal checkpoints, not separate conversations.
3. **`/design`** — New conversation per invocation. Produces `docs/ARCHITECTURE_AND_DESIGN.md`. Gate 2 approval required before milestone planning begins.
4. **`/milestone`** — New conversation per milestone. Produces milestone README, `milestone-status.txt`, and gate-3 review. Gate 3 stays `[~] In progress` until all milestones are defined.
5. **`/plan`** — New conversation per feature. Produces feature plan with sub-feature checklist, acceptance criteria, test command, and architectural deviation section. Updates `milestone-status.txt` with plan path.
6. **`/build`** — New conversation per sub-feature group. Implements features, ticks sub-feature checkboxes, refreshes codebase assessment, records architectural deviations, runs test command.
7. **`/spike`** — On-demand research. Spawns research sub-agent and red-team sub-agent. Produces structured spike artifact. Non-blocking to pipeline.

**Key patterns:**
- Files are the API — no in-memory handoffs, no conversation continuations across skills
- `/project` is the only writer of the initial `progress.txt`; all other writes are by the owning phase skill
- `milestone-status.txt` is written first in any dual-file update; `progress.txt` rollup is derived and recoverable
- Gate WB must reach `[x]` or `[-]` before Gate 1 begins — `[ ] Pending` is a blocking state

**State file ownership table (who writes what):**

| Field | Owned by |
|-------|---------|
| Initial `progress.txt` gate entries | `/project` |
| Gate 0/WB/1 approvals in `progress.txt` | `/define` |
| Gate 2 approval | `/design` |
| Gate 3 per-milestone lines | `/milestone` |
| Gate 4 per-feature lines | `/plan` |
| Milestone summary rollup in `progress.txt` | `/milestone` (creation), `/build` (completion) |
| `milestone-status.txt` (initial) | `/milestone` |
| `milestone-status.txt` (plan path, sub-feature ticks) | `/plan`, `/build` |
| Spike entries | `/spike` |

### Critical Pitfalls (from PITFALLS.md)

1. **Implicit gate approval** — Models optimize for completion and will naturally advance after presenting an artifact. Every gate must end with an explicit binary question ("Approve Gate N to proceed?") and wait. "Looks good for section 2, fix section 3" is not approval. Only record approval after the user approves the artifact in its current state.

2. **Two-tier state divergence** — `progress.txt` and `milestone-status.txt` can diverge when a `/build` session crashes between the two writes. Write `milestone-status.txt` first (source of truth); treat `progress.txt` rollup as derived and recoverable. `/project` validates consistency on every read and emits a specific warning block when divergence is detected — never auto-corrects silently.

3. **Context rot in `/define`** — `/define` is the most context-intensive skill (Gates 0 + WB + 1 in one session). A large codebase scan at Gate 0 can consume enough context that PRD quality degrades by Gate 1. Mitigation: write `docs/codebase-assessment.md` immediately after Gate 0 approval; re-read from file at Gate 1 start rather than relying on in-session memory.

4. **Gate WB pending state stalling the pipeline** — If the session ends before the user resolves the Gate WB offer, `[ ] Pending` persists. On next invocation of `/project` or `/define`, resolving the pending state must be the first action before any other status reporting. Never let the pipeline proceed past a pending Gate WB.

5. **Re-planning invalidating in-progress work without explicit decision** — When milestone re-planning begins while a feature is `[~] in progress`, `/milestone` must surface all in-progress and complete features explicitly before any status reset. The user decides for each; the skill cannot autonomously decide to discard in-progress code.

---

## Implications for Roadmap

All researchers agreed on implementation order: gate order (0/WB/1 → 2 → 3 → 4 → build), with `/project` built first as the foundation the others depend on.

### Phase 1: `/project` Router and State Bootstrap

**Rationale:** Every other skill reads `progress.txt` and expects `/project`'s bootstrap to have run. `/project` is also the simplest skill (read-only after bootstrap), making it the correct starting point to establish state file schemas and validation patterns that all other skills will follow. Building it first forces the full state file contract to be resolved before any phase skill is written.

**Delivers:** Working router skill with bootstrap, state validation, artifact path checking, milestone consistency checking, Gate WB pending detection, and re-planning routing. The `progress.txt` template in `assets/` and the state file schema in `references/`.

**Features addressed:** PROJ-01 through PROJ-11, all PROJ edge cases

**Pitfalls this phase must handle:** State file format correctness, two-tier consistency validation logic (even though `/build` is the source of divergence, `/project` must detect it)

**Research flag:** Standard patterns — no additional research needed. Schema is fully specified.

### Phase 2: `/define` — Gates 0, WB, 1

**Rationale:** Gate 1 (PRD) is the prerequisite for all downstream skills. `/define` is forked from `create-prd` with well-documented carry-forward patterns. It is the most complex single skill (three gates, one session, interview-heavy) and should be built second while the design is fresh.

**Delivers:** Codebase assessment (brownfield), optional Working Backwards doc, PRD. All Gate 0/WB/1 review checklists. Updated `progress.txt` with gate approvals. Greenfield/brownfield detection logic. Revision mode for PRD re-planning.

**Features addressed:** DEF-01 through DEF-21, all DEF edge cases

**Key implementation constraints:**
- Write `codebase-assessment.md` immediately after Gate 0 approval — do not hold findings in memory
- Gate WB offer logic: three states (approved, skipped, pending) with unambiguous `progress.txt` encoding
- One-round-at-a-time interview discipline throughout
- Confirm-before-overwrite on all artifacts
- Read-back-and-confirm after every state file write

**Pitfalls this phase must handle:** Context rot (large codebase at Gate 0), Gate WB pending resolution, partial approval vs. full approval, 500-line SKILL.md limit requiring aggressive `references/` use

**Research flag:** Needs careful attention to `create-prd` carry-forward patterns. No external research needed — patterns are fully documented in STACK.md.

### Phase 3: `/design` — Gate 2

**Rationale:** Depends on Gate 1 approval and `prd.md`. Simpler than `/define` (single gate, one artifact, no interview branching). Building it third establishes the pattern for gate-validated single-artifact skills that `/milestone` and `/plan` also follow.

**Delivers:** `docs/ARCHITECTURE_AND_DESIGN.md` with design decisions table, component inventory, data flow, file organization. Gate 2 review checklist. Architecture refresh mode for consolidating deviations.

**Features addressed:** DES-01 through DES-08, all DES edge cases

**Pitfalls this phase must handle:** Cross-reference enforcement (every component maps to a PRD feature), handling missing `prd.md` as a hard stop (not a graceful degradation)

**Research flag:** Standard patterns.

### Phase 4: `/milestone` — Gate 3

**Rationale:** Depends on Gate 2. More complex than `/design` because it handles revision mode with partial feature resets, multi-milestone coordination, and the Gate 3 `[~] In progress` state that stays open across multiple invocations.

**Delivers:** Per-milestone `README.md`, `milestone-status.txt`, gate-3 review. Milestone summary lines in `progress.txt`. Milestone revision logic (selective feature reset, completed-feature preservation). PRD milestone summary updates.

**Features addressed:** MIL-01 through MIL-16, all MIL edge cases

**Key implementation constraints:**
- Gate 3 status in `progress.txt` is `[~] In progress` until user signals milestone planning complete — not auto-closed
- Slug immutability: slugs are derived at creation time and do not change if the title is later revised
- Feature count warning when milestone exceeds 5 features (warn, do not block)

**Pitfalls this phase must handle:** Re-planning with in-progress features, scope creep during revision, plan path conflicts after re-naming

**Research flag:** Standard patterns.

### Phase 5: `/plan` — Gate 4

**Rationale:** Depends on Gate 3. One invocation per feature. Establishes the feature plan format that `/build` depends on. Sub-feature sizing (fitting within 120k tokens) is the critical constraint to enforce here.

**Delivers:** Per-feature plan (`plans/<feature>.md`) with sub-features, interface contracts, edge cases, test command, architectural deviation section. Gate 4 review checklist. `milestone-status.txt` update with plan path.

**Features addressed:** PLAN-01 through PLAN-10, all PLAN edge cases

**Key implementation constraints:**
- Sub-features must each leave the codebase in a committable state (no sub-feature that requires the next to avoid a broken build)
- Test command is required for completion — if missing, ask before proceeding
- Do not create orphan plan files for features not in the milestone README

**Research flag:** Standard patterns. Sub-feature sizing is the one area requiring judgment, but guidelines are documented (DD-1).

### Phase 6: `/build` — Implementation

**Rationale:** Depends on Gate 4 plan. Heaviest write activity: codebase, feature plan sub-feature ticks, architectural deviations, `milestone-status.txt`, and `progress.txt` rollup. Most vulnerable to context budget issues. Must be built after the full state contract is established by the preceding phases.

**Delivers:** Implemented sub-features. Refreshed `docs/codebase-assessment.md`. Sub-feature checklist ticks. Architectural deviation records. Milestone completion rollup in both state files.

**Features addressed:** BUILD-01 through BUILD-11, all BUILD edge cases

**Key implementation constraints:**
- Refresh `docs/codebase-assessment.md` at each new feature start (re-scan + git history diff)
- Write `milestone-status.txt` before `progress.txt` rollup — never the reverse
- Stop at sub-feature boundary when context budget is ~80%; write session summary; do not push through
- Test command must pass before feature is marked complete; failure is a hard stop, not a soft warning

**Research flag:** Context budget detection logic may need iteration. The 80% threshold and session-end handoff pattern are well-specified but the mechanics of detecting context consumption in a skill need validation during implementation.

### Phase 7: `/spike` — Research

**Rationale:** Non-blocking to the pipeline; can be built independently of phases 2-6. Placed last because it is the most architecturally distinct (spawns sub-agents) and is not on the critical path. Building it after the core pipeline is established means the `progress.txt` spike section format is already validated.

**Delivers:** Per-topic spike artifact with research findings, red-team assessment, and recommendation. Spike entry in `progress.txt`. Follow-up mode for existing spike topics.

**Features addressed:** SPIKE-01 through SPIKE-09, all SPIKE edge cases

**Key implementation constraints:**
- Red-team sub-agent is a fixed-cost single validation pass — not iterative
- When research and red-team findings directly contradict, present both in the artifact; do not suppress either perspective
- Follow-up mode appends to Follow-Up Log — never overwrites the original findings

**Research flag:** Sub-agent spawning patterns within a skill may need validation. This is the only skill in the suite that spawns sub-agents, and the token spend for the research agent is less predictable than other skills.

### Phase Ordering Rationale

- Gate order is the dependency order — each skill's prerequisite is the previous gate's approval
- `/project` first because it establishes the state file schema and contract that all phase skills implement
- `/define` second because `prd.md` is the root prerequisite for the entire downstream pipeline
- `/spike` last because it is non-blocking, architecturally distinct, and its `progress.txt` integration is only testable after the project-level state format is established
- Documentation (detail docs + SKILLS.md rows) must be written as each skill is completed, not deferred

### Research Flags

**Needs deeper attention during implementation:**
- **Phase 2 (`/define`):** 500-line SKILL.md limit will be tight given three gates plus interview logic plus revision mode. Plan for aggressive `references/` use from the start; do not defer the split.
- **Phase 6 (`/build`):** Context budget detection is specified but the implementation mechanics (how the skill tracks and surfaces approaching token limits) need validation. The 80% threshold may need adjustment based on real session behavior.
- **Phase 7 (`/spike`):** Sub-agent spawning within a skill is architecturally unique in this repo. Validate the sub-agent invocation pattern against the existing `occ-skill-creator` or GSD agents before writing.

**Standard patterns (no additional research needed):**
- **Phase 1 (`/project`):** Fully specified. Read-only router with well-documented validation logic.
- **Phase 3 (`/design`):** Single-gate, single-artifact skill following the established pattern.
- **Phase 4 (`/milestone`):** More complex but all edge cases are documented in DESIGN.md.
- **Phase 5 (`/plan`):** Feature plan format is fully specified in DESIGN.md artifacts section.

---

## Critical Constraints

These constraints must be reflected in every skill implementation without exception:

1. **`disable-model-invocation: true` on all skills.** No auto-triggering. The pipeline is stateful; auto-invocation would corrupt state by running a phase skill out of sequence.

2. **500-line SKILL.md body limit.** Content overflow goes to `references/` with explicit read instructions in SKILL.md body. `/define` will require the most aggressive `references/` use.

3. **Files are the only API.** No in-memory handoffs, conversation continuations, or cross-skill sub-agent calls. Each skill reads all context from disk at invocation.

4. **State file ownership is fixed.** Cross-skill writes to state files are a design defect. The ownership table (see Architecture section) is the law.

5. **Gate approval is explicit.** "Approve Gate N to proceed?" is the required question. Silence, continuation, or partial feedback on content is not approval.

6. **Checklist completeness before approval.** All items must be `[x]` or `[-]` with reason before approval is recorded. In-session explicit approval lets the skill mark checklist items on the user's behalf — the checklist is a record, not an interactive form.

7. **Plain text for all state files.** YAML was evaluated and rejected. The decision is final. Checkbox notation (`[ ]` / `[~]` / `[x]` / `[-]`) is established and must be preserved exactly.

8. **Artifact paths are project-root-relative.** Never absolute. Slugs are derived at creation time and do not change if titles are later revised.

9. **Write `milestone-status.txt` before `progress.txt` rollup.** `milestone-status.txt` is the source of truth; `progress.txt` rollup is derived and recoverable.

10. **`create-prd` is untouched.** `/define` is a fork. No modifications to `skills/create-prd/`.

---

## Open Questions

These are unresolved questions that requirements and roadmap should acknowledge:

1. **Mid-session interruption handling for `/define`** — If the session ends after Gate 0 but before Gate WB is resolved (DEF-EC-03), `/project` is expected to detect incomplete state and route back to `/define`. How `/define` detects and resumes from the last approved gate needs to be specified precisely in the skill body. The `create-prd` interrupted-session-recovery pattern is the model, but the gate-state detection logic (read `progress.txt` → identify last approved gate → resume from next) needs explicit implementation guidance.

2. **Sub-feature token budget estimation** — PLAN-05 specifies that each sub-feature must fit within ~120k tokens in a single `/build` session. `/plan` must flag oversized sub-features. The heuristic for estimating token budget from a sub-feature description is not specified. A rough guideline (e.g., "a sub-feature that touches more than 5 files or requires more than 200 lines of new code is likely oversized") should be added to `/plan`'s references.

3. **Skill directory structure — Option A vs Option B** — ARCHITECTURE.md documents two structural options for the skill suite (flat vs. subdirectory per skill). Option B (subdirectory per skill, matching `create-prd`) is recommended, but whether shared `references/` live at the `skills/project/` level or are duplicated per skill needs a decision before writing begins. Given that all skills share the `progress.txt` format convention, a shared `references/progress-format.md` at `skills/project/` would reduce duplication.

4. **`/build` context budget detection mechanics** — How a skill detects that its context window is ~80% full is not specified. This may require a pragmatic approach (heuristic based on number of sub-features completed + approximate token cost per sub-feature) rather than a precise measurement. The skill should be explicit about this heuristic rather than leaving it implicit.

5. **Gate 3 closure signal** — MIL-EC-07 documents that Gate 3 stays `[~] In progress` until the user explicitly signals that milestone planning is complete. The exact signal (a phrase, a confirmation question, a command flag) is not specified and needs a UX decision before `/milestone` is written.

6. **Reconstruction of `progress.txt` from existing artifacts** — PITFALLS.md documents a recovery path where `/project` offers to reconstruct `progress.txt` from gate review files and milestone directories. The reconstruction logic (what it reads, what it infers, what it asks the user to confirm) needs to be specified explicitly in `/project`'s SKILL.md or a references file.

---

## Risks

1. **State file corruption is hard to detect without good tooling.** The pipeline depends on `progress.txt` and `milestone-status.txt` being correctly formatted and in sync. A partially written state file is a silent failure that only surfaces when the next skill reads it. Mitigation: read-back-and-confirm after every state file write; `/project` validates consistency on every invocation and emits explicit warnings; git is the primary recovery mechanism (all planning artifacts must be version-controlled).

2. **`/define` 500-line limit with three gates.** `/define` covers more workflow territory than any other skill in the suite (greenfield/brownfield detection, Gate 0 codebase scan, Gate WB interview, Gate 1 PRD interview, revision mode). Fitting all of this plus the required carry-forward patterns from `create-prd` into 500 lines without degrading the instructions requires aggressive use of `references/` from the start. If this constraint is not planned for upfront, the skill will need a major refactor after hitting the limit. Mitigation: design the `references/` structure before writing a single line of SKILL.md body.

3. **Implicit approval is the default AI behavior.** Every gate depends on the skill actively resisting the natural tendency to advance after presenting an artifact. This is not a one-time consideration — it must be enforced in the SKILL.md instructions for every gate in every skill. Any gate where the explicit approval question is missing or softened will collapse under normal use. Mitigation: gate approval question is a required element in the implementation checklist for each skill; peer review of skill drafts should check this specifically.

4. **Re-planning scenarios are complex and under-tested.** The re-planning flows (milestone re-planning with in-progress features, PRD revision with staleness surfacing) are fully specified but involve the most edge cases and state transitions. These are the scenarios most likely to produce bugs that only appear in real use. Mitigation: build re-planning into each skill's implementation scope from the start — not as a v2 concern — and include explicit edge case tests in the review artifacts.

5. **Documentation debt accumulates if deferred.** The repo requires a `docs/skills/<name>.md` detail doc and a `docs/SKILLS.md` row for each new skill. With seven skills being built in sequence, there is a temptation to defer documentation until all skills are done. If a skill's detail doc is missing at review time, the skill is incomplete per repo requirements. Mitigation: treat documentation as part of each skill's definition of done, not a post-completion task.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Derived entirely from direct codebase inspection; all conventions verified against `create-prd` and `skills/project/DESIGN.md` |
| Features | HIGH | All 75 features derived directly from the authoritative `DESIGN.md` design document (DD-1 through DD-14); no external research needed |
| Architecture | HIGH | Fully specified in `DESIGN.md`; context isolation mechanism confirmed by codebase inspection of existing skills and commands |
| Pitfalls | HIGH | Derived from `DESIGN.md` warnings, `create-prd` patterns, and direct source inspection; no speculative findings |

**Overall confidence:** HIGH

The research is unusually high confidence because this project's design is already fully specified in `skills/project/DESIGN.md`. There are no external APIs to research, no third-party libraries to evaluate, and no community consensus to weigh. All findings are derived from primary source documents in this repo.

### Gaps to Address

- **Sub-feature sizing heuristics:** The 120k-token target is specified; the heuristic for estimating whether a described sub-feature fits within that target is not. Address in `/plan`'s references before writing the skill.
- **`/define` references structure:** The 500-line limit requires pre-planning what goes in `references/`. Design the references structure before writing SKILL.md body.
- **Gate 3 closure signal:** The phrase or mechanism by which the user signals "milestone planning complete" needs a UX decision before `/milestone` is written.
- **Shared `references/` for `progress.txt` format:** Decide whether format documentation is shared at `skills/project/` level or duplicated per skill. Shared is cleaner but requires confirming how skill-level `references/` inheritance works in the repo.

---

## Sources

### Primary (HIGH confidence)

- `skills/project/DESIGN.md` — authoritative source for all design decisions (DD-1 through DD-14), artifact specifications, state file schemas, and feature inventory
- `skills/create-prd/SKILL.md` — reference skill for carry-forward patterns, gate UX, interview discipline, and error handling
- `skills/project/progress-file/` — format analysis research (REQUIREMENTS, TEXT vs YAML comparison); rationale for plain-text decision
- `skills/project/design-decisions/OPEN_QUESTIONS.md` — resolved open questions including OQ-2 (`/define` fork from `create-prd`)
- `docs/SKILLS.md` — catalog index; confirms documentation requirements and consuming instructions
- `docs/skills/create-prd.md` — detail doc pattern to replicate for each new skill
- `memory/feedback_docs_required.md` — confirms documentation is a repo-level requirement, not optional

### Secondary (MEDIUM confidence)

- `skills/occ-skill-creator/`, `skills/occ-skill-refactor/` — additional evidence for `SKILL.md` + `references/` + `review/` directory pattern
- `.claude/commands/gsd/new-project.md` — confirms command front-matter format and slash command naming convention

---

*Research completed: 2026-04-02*
*Ready for roadmap: yes*
