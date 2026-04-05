# Project Skill — Design Review Findings

> Consolidated findings from two independent reviews of DESIGN.md and OPEN_QUESTIONS.md.
> Each finding is categorized, prioritized, and tracked for resolution.
>
> Status: [ ] open  [x] resolved  [-] won't fix  [~] deferred

---

## High Priority — Inconsistencies and Gaps

### [x] F-1: Bootstrap gap — no `progress.txt` on first run

**Type:** GAP | **Source:** DD-3, DD-4, DD-5 | **Resolution:** DD-3 updated

`/project` creates the initial `progress.txt` on first run as a bootstrap exception. DD-3
clarified: "read-only" means no state modification during normal operation. First-run
initialization is the one exception. Progress.txt lifecycle updated accordingly.

---

### [x] F-2: Multi-gate `/define` vs single entry point — orchestration ambiguity

**Type:** AMBIGUITY | **Source:** DD-2, DD-3, DD-4 | **Resolution:** DD-2 and DD-4 updated

`/define` runs Gates 0, WB, and 1 as a single continuous session. The gates are internal
approval checkpoints — the user approves each gate before `/define` continues, but does not
leave the conversation. DD-2 updated with an explicit carve-out: `/define` is the exception
to per-phase context isolation because codebase assessment, Working Backwards, and PRD
creation are tightly coupled. All other phase boundaries maintain full context isolation.
DD-4 rationale updated to clarify the internal checkpoint model.

---

### [x] F-3: Architecture doc has no re-invocation mechanism for milestones 2+

**Type:** GAP | **Source:** DD-4, Gate 2, ARCHITECTURE_AND_DESIGN.md lifecycle | **Resolution:** Lifecycle and feature plan updated

Architecture doc is written once at Gate 2. It does not grow automatically. When implementation
forces an architectural deviation, the change and reasoning are captured in the feature plan's
new Architectural Deviations section. The architecture doc can be consolidated from these
records at any time by user initiative through `/project`. No automatic trigger needed — the
user decides when the doc is stale enough to refresh.

---

### [x] F-4: Feature plan references "pulled from PRD" — should be milestone README

**Type:** INCONSISTENCY | **Source:** Feature plan artifact detail, OQ-6 | **Resolution:** Feature plan updated

Changed "pulled from PRD" to "pulled from milestone README" in the feature plan artifact
spec. Consistent with OQ-6: acceptance criteria live in the milestone README, not the PRD.

---

### [x] F-5: DD-4 component table omits `docs/` path prefix systematically

**Type:** INCONSISTENCY | **Source:** DD-4 vs Artifact Inventory | **Resolution:** DD-4 updated

DD-4 component table now uses full paths with `docs/` prefix consistently. Also added a
naming conventions section and document tree to the Artifacts area, establishing the
canonical path structure in one place.

---

### [x] F-6: Downstream artifacts not invalidated when upstream gate re-opens

**Type:** GAP | **Source:** DD-6, DD-7 | **Resolution:** Accepted as documented limitation

No automatic staleness tracking or cascade reset. The user initiates architecture changes
and is responsible for deciding which downstream artifacts need re-review. Architectural
deviations captured in feature plans during `/build` provide visibility into what changed.
Adding cascade logic would introduce complexity for a rare, user-initiated scenario.

---

### [-] F-7: Missing/corrupted `progress.txt` — no orchestrator behavior defined

**Type:** FAILURE MODE | **Source:** DD-3, DD-5 | **Resolution:** Accepted risk, won't fix

Corruption is unlikely (git merge conflicts and manual edit errors are the realistic cases,
both user-visible). Missing file is handled by F-1 bootstrap. For any corruption, recovery
from the last git commit restores both `progress.txt` and the corresponding project state.
No validation logic needed.

---

### [x] F-8: Gate approved but artifact file missing — no validation

**Type:** FAILURE MODE | **Source:** DD-3, DD-7 | **Resolution:** DD-3 updated

`/project` validates artifact paths listed in `progress.txt` against files on disk. If a
gate is approved but its artifact is missing, `/project` warns the user but does not block.
The artifact path is already present in the progress.txt format — this makes it a validation
input, not just documentation.

---

### [x] F-9: PRD-level vision change — no backward route to Gate 1

**Type:** EDGE CASE | **Source:** DD-6, DD-7 | **Resolution:** DD-6 expanded

DD-6 now covers two levels of re-planning: milestone (existing) and PRD (new). For PRD
revision, `/project` routes to `/define` in revision mode — a focused interview on what
changed, not a fresh start. Downstream artifacts are not automatically reset, consistent
with F-6 resolution.

---

### [x] F-10: Codebase assessment refresh contradicts architecture doc

**Type:** FAILURE MODE | **Source:** OQ-5, DD-10, ARCHITECTURE_AND_DESIGN.md | **Resolution:** Covered by F-3 pattern

When `/build` refreshes the codebase assessment and discovers divergence from the approved
architecture (e.g., external contributions), the same deviation capture process applies:
`/build` records the conflict in the feature plan's Architectural Deviations section. The
user decides whether to proceed or pause to update the architecture doc. No additional
mechanism needed beyond what F-3 established.

---

## Medium Priority — Gaps and Ambiguities

### [x] F-11: DD-6 partial re-plan resets all features — too blunt

**Type:** GAP | **Source:** DD-6 | **Resolution:** DD-6 tradeoff updated

`/milestone` in revision mode now identifies which features are affected by the scope change
and resets only those to `planned` status. Completed features that are unaffected retain their
status. The user confirms the reset list before it takes effect.

---

### [x] F-12: Review checklists not included in artifact specs

**Type:** INCONSISTENCY | **Source:** DD-13, all artifact details | **Resolution:** DD-13, DD-4, DD-7 updated

Checklists are now separate dedicated files with consistent structure, not appended to
artifacts. Each gate has a defined checklist path (e.g., `docs/reviews/gate-2-review.md`,
`milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md`). DD-4 Writes column updated
to include review files. DD-7 adds gate rule 6: checklist completeness is validated before
gate approval — all items must be `[x]` or `[-]` N/A with a reason.

---

### [x] F-13: `/build` completion tracking — sub-feature vs feature updates unclear

**Type:** AMBIGUITY | **Source:** DD-1, DD-4, progress.txt format | **Resolution:** DD-4 updated

`/build` updates the feature plan's sub-feature checklist as each sub-feature is completed.
Sub-features are not tracked in progress files — they live only in the feature plan. When all
sub-features are done and the test command passes, `/build` marks the feature `[x]` in the
`milestone-status.txt`. When the last feature in a milestone completes, `/build` also
updates the milestone summary in the project-level `progress.txt`. No human approval step
between sub-features — the gate approval happened at Gate 4 (the feature plan). Sub-feature
work is continuous within `/build`.

---

### [x] F-14: "State file" vs "progress.txt" — inconsistent terminology

**Type:** INCONSISTENCY | **Source:** Throughout DESIGN.md | **Resolution:** Standardized terminology

All standalone "state file" references replaced with `progress.txt`. DD-3 retains one
definitional usage that introduces the term and immediately equates it to `progress.txt`.

---

### [x] F-15: DD-8 gate review prompts narrower than DD-13 checklists

**Type:** INCONSISTENCY | **Source:** DD-8, DD-13 | **Resolution:** DD-8 prompts expanded

All six gate review prompts now cover the same scope as their DD-13 checklists. Prompts
remain conversational but reference all checklist areas (e.g., Gate 2 now mentions component
inventory, data flow, and security; Gate 3 now mentions acceptance criteria and sizing).

---

### [x] F-16: `/build` Reads column omits `codebase-assessment.md`

**Type:** INCONSISTENCY | **Source:** DD-4 | **Resolution:** DD-4 updated

`/build` Reads column now includes the codebase (which covers reading the existing assessment
before refreshing it). Also added `ARCHITECTURE_AND_DESIGN.md` as a Read (needed to recognize
architectural deviations) and feature plan as a Write (sub-feature checklist updates and
architectural deviation records).

---

### [x] F-17: `/design` Reads omits existing `ARCHITECTURE_AND_DESIGN.md`

**Type:** INCONSISTENCY | **Source:** DD-4 | **Resolution:** Superseded by F-3 resolution

`/design` runs once at Gate 2. It does not re-invoke for later milestones. Architectural
deviations are captured in feature plans during `/build`, not by re-running `/design`. The
Read omission is no longer relevant because the re-invocation scenario doesn't exist.

---

## Missing Workflows

### [x] F-18: Hotfix / emergency changes that bypass normal flow

**Type:** MISSING WORKFLOW | **Resolution:** Accepted limitation, covered by existing refresh

The pipeline tolerates out-of-band changes (hotfixes, external contributions, manual edits).
The codebase assessment refresh at the start of each `/build` feature now explicitly checks
git history (commits since last assessment) to catch what changed, who changed it, and which
areas were affected. No dedicated hotfix workflow needed — the user decides if any artifacts
need updating when the refresh surfaces the changes. DD-10 and codebase-assessment.md spec
updated to include git history as an explicit input and a "Recent Changes" section.

---

### [-] F-19: Feature abandonment — no distinct status

**Type:** MISSING WORKFLOW | **Source:** DD-1 | **Resolution:** Won't fix — use `skipped`

`skipped` covers both "never started" and "started but abandoned." The feature plan and git
history provide the real signal for what happened. No downstream behavior would differ between
`abandoned` and `skipped`, so a third terminal state adds complexity without value.

---

### [x] F-20: Spike / prototype work before committing to a milestone

**Type:** MISSING WORKFLOW | **Resolution:** DD-14 added — `/spike` skill with agent-based research

New `/spike` skill enables targeted technical research. A research sub-agent runs autonomously
using user-provided tooling (MCP servers, crawlers, local docs, cloned repos). A separate
red-team sub-agent validates findings in a single pass. Research agent maintains memory for
follow-up investigation. `/project` offers spike research at contextually appropriate stages;
the user decides if it's needed. Spike artifacts tracked in `progress.txt` and referenced by
downstream planning skills. DD-4, document tree, artifact inventory, and progress.txt format
all updated.

---

### [-] F-21: Milestone insertion between existing numbered milestones

**Type:** EDGE CASE | **Source:** Artifact structure | **Resolution:** Accepted limitation

The naming convention specifies two-digit integers. Insertion between milestones can use
decimal numbering (e.g., `01.5`) without renaming existing directories, but deeply nested
insertion degrades readability. This is rare enough in practice to accept as-is.

---

### [-] F-22: Feature revert after completion

**Type:** MISSING WORKFLOW | **Resolution:** Covered by F-18 — codebase refresh catches reverts

A revert is a git operation. The codebase refresh at the next `/build` detects it via git
history. The user updates `progress.txt` (mark feature back to `planned` or `skipped`) and
decides impact on downstream features. No dedicated revert workflow needed.

---

## Scale Concerns

### [x] F-23: 10+ milestones makes `progress.txt` a token sink

**Type:** SCALE CONCERN | **Source:** NFR-2 | **Resolution:** Two-tier progress files

Project state split into project-level `progress.txt` (gates, milestone summaries, spikes —
~25 lines max at any scale) and milestone-level `milestone-status.txt` (feature detail — ~21 lines
per milestone). Skills read only the project-level file plus the specific milestone file when
needed. A 12-milestone project reads ~46 lines per skill invocation instead of ~280.
DD-3, DD-4, DD-5, document tree, artifact inventory, and artifact details all updated.

---

### [x] F-24: Gate 4 — batch vs per-feature invocation unclear

**Type:** AMBIGUITY | **Source:** DD-4, DD-7 | **Resolution:** DD-4 and DD-7 updated

`/plan` runs once per feature, not batch. `/project` routes to `/plan` for the next unplanned
feature in the current milestone. `milestone-status.txt` tracks which features have plans.
Consistent with context isolation philosophy — each feature plan is independent and doesn't
need other plans in context.

---

### [x] F-25: 6+ month projects — architecture doc staleness

**Type:** SCALE CONCERN | **Source:** ARCHITECTURE_AND_DESIGN.md lifecycle | **Resolution:** Superseded by F-3 resolution

Architectural deviations are captured in feature plans as they occur during `/build`. The
user can consolidate these into the architecture doc at any time. The accumulated deviation
records provide both the trigger ("enough deviations have piled up") and the input for the
update. No periodic automatic trigger needed.

---

## Lower Priority

### [x] F-26: Greenfield detection criteria differ between Gate 0 and Gate WB

**Type:** AMBIGUITY | **Source:** DD-10, DD-11 | **Resolution:** DD-11 Activation clarified

Gate 0 and Gate WB intentionally use different criteria because they serve different purposes.
Gate 0's check is structural (is there existing code to assess?). Gate WB's check is strategic
(is the customer outcome unclear?). A project with existing code can — and frequently will —
trigger both: Gate 0 assesses the codebase, Gate WB clarifies the vision for the new initiative.
DD-11 Activation paragraph updated to make this distinction explicit and remove the conflation
of "greenfield" with "major new initiative."

---

### [x] F-27: No `progress.txt` state for "Gate WB offered, awaiting decision"

**Type:** GAP | **Source:** DD-11, progress.txt format | **Resolution:** DD-11, gate table, progress.txt format updated

Added `[ ] Pending — offered, awaiting decision` state for Gate WB. When Gate 0 completes
and Gate WB is offered, the pending state is written to `progress.txt`. If the session ends
before the user decides, the next `/project` or `/define` invocation detects the pending
state and re-prompts. Gate WB must reach `[x]` or `[-]` before Gate 1 can begin.

---

### [x] F-28: PRD milestone summary drifts from milestone README

**Type:** FAILURE MODE | **Source:** OQ-6, DD-6 | **Resolution:** DD-6 and DD-4 updated

`/milestone` now updates the PRD's milestone summary line when re-planning changes a
milestone's scope. DD-6 milestone re-planning paragraph updated. `/milestone` component
table Writes column updated to include `prd.md` (milestone summary sync on re-plan).

---

### [x] F-29: Test command update mid-build

**Type:** MISSING WORKFLOW | **Source:** DD-12 | **Resolution:** DD-12 rewritten

DD-12 rewritten to clarify the skill's role: invoke the test command, check exit code,
nothing more. Test content is created and maintained by the user outside the skill pipeline.
The `Test Command:` field in the feature plan is updatable during `/build` without gate
re-approval — the user tells `/build` the new command and it updates the feature plan.

---

### [-] F-30: Parallel feature work across milestones

**Type:** EDGE CASE | **Source:** OQ-8 | **Resolution:** Accepted limitation

The orchestrator surfaces one "next" action per session. Users who want parallel work can
run separate Claude Code sessions on different features — the progress files and git handle
concurrency naturally. No parallel orchestration model needed. Multi-user coordination is
already out of scope (OQ-8).
