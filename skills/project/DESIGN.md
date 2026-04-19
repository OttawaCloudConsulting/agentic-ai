# Project Skill — Design Decisions

> Working document capturing design decisions for the `/project` orchestrated workflow.
> This document records the rationale behind each decision so future sessions can understand
> not just *what* was decided, but *why*.

## Problem Statement

The current pipeline (`create-prd` → `start-feature`) has gaps:

1. **No planning phase** — jumps from high-level PRD to implementation context with no place for
   feature-level design decisions (API shape, error handling, state management)
2. **Loosely coupled skills** — share state through file conventions but have no formal
   orchestration; the user must remember the sequence
3. **Monolithic PRD** — specifies all features up front, leading to drift, context bloat, and
   stale requirements by the time later features are built
4. **Context rot** — a single long session spanning define → plan → build degrades output quality
   as token usage grows
5. **No codebase alignment** — when working in existing codebases, the model silently adopts
   patterns (good or bad) without validating assumptions with the user

## Design Decisions

### DD-1: Three-level work hierarchy — Milestone > Feature > Sub-Feature

**Decision:** All work is decomposed into three levels:

| Level | Definition | Completion criteria | Sizing constraint |
|---|---|---|---|
| **Milestone** | A deployable increment of user-visible value. A grouping of features that, when complete, delivers something a user or stakeholder can see, touch, or use. | All features complete, integrated, documentation current | 2–5 features per milestone |
| **Feature** | A testable, reviewable unit of delivery. Maps to a single pull request. | Tests pass (including CI/CD if used), documentation created or updated, PR opened (suggested, not required) | Spans multiple sub-features; produces a coherent, reviewable change |
| **Sub-Feature (Task)** | The smallest unit of implementation work. A committable change completable within a single `/build` session. | Code committed, sub-feature checklist item checked off | Must fit within 60% of a 200k-token context window (~120k tokens). Larger models provide additional buffer but do not change the sizing target. |

**Milestone guidance:** A milestone should map to a customer-visible outcome. If Working
Backwards (DD-11) was used, each milestone should correspond to a bullet in the press release
or an answer in the FAQ. "Users can register and log in" is a good milestone. "Refactor
database layer" is not — reframe as the user-visible outcome the refactor enables.

**Feature guidance:** A feature is the PR boundary. Each feature produces one pull request
(suggested, not required to proceed to next features). Features always require:
1. A test command that validates the feature (pass/fail)
2. Documentation — new docs or updates to existing docs

**Sub-Feature guidance:** Sub-features are tracked as a checklist within the feature plan —
they do not need their own artifact files. Each sub-feature must leave the codebase in a
committable state. A sub-feature that requires the next sub-feature to avoid a broken build
is too small and should be merged with its dependent.

**Rationale:** Three levels provide enough granularity to steer work at the right altitude.
Milestones steer strategy (what delivers value). Features steer delivery (what's testable
and reviewable). Sub-features steer implementation (what fits in a context window). Each level
has concrete completion criteria that prevent ambiguity about "done."

**Tradeoff:** Loses the comprehensive upfront spec. Stakeholders who need a full project view
must assemble it from milestone artifacts. This is acceptable because the primary user is a
developer or small team iterating with an AI assistant, not a PMO tracking a waterfall plan.

---

### DD-2: State-driven orchestrator with phase-isolated skills

**Decision:** One orchestrator skill (`/project`) reads project state from a file and routes to
the appropriate phase skill. Each phase skill runs in its own conversation with a clean context
window.

**Exception — `/define` session scope:** `/define` runs Gates 0, WB, and 1 as a single
continuous session. These gates are internal approval checkpoints — the user approves each gate
before `/define` continues, but does not leave the conversation. Codebase assessment, Working
Backwards, and PRD creation are tightly coupled: the codebase understanding feeds directly into
the Working Backwards narrative, which feeds directly into the PRD interview. Splitting them
would force re-ingestion of context that was just established, with no quality benefit.

All other phase boundaries (between `/define` and `/design`, `/design` and `/milestone`, etc.)
maintain full context isolation with a clean context window per skill.

**Rationale:** Context isolation is critical. The define phase involves extensive back-and-forth
interviews that burn tokens. If planning and building happen in the same conversation, output
quality degrades. File artifacts act as a context-transfer mechanism — they carry decisions
forward without carrying the token weight of how those decisions were reached.

**Tradeoff:** Each phase must re-ingest file artifacts, spending tokens on re-reading. This is
cheaper than context rot. A milestone-scoped PRD (DD-1) keeps the re-ingestion cost manageable.

---

### DD-3: Orchestrator is stateless and read-only

**Decision:** `/project` reads `progress.txt` (the project state file) and tells the user what
phase they're in and what to run next. It does not modify state during normal operation.

Project state is split across two levels:

- **Project-level `progress.txt`** (project root) — gate approvals, milestone summary lines
  (one line per milestone with rolled-up status), and spike entries. Small and stable regardless
  of project scale.
- **Milestone-level `milestone-status.txt`** (`milestones/<NN>-<name>/milestone-status.txt`) —
  feature entries with plan paths, sub-feature checklists, and notes. Only read by skills
  working on that specific milestone.

**Bootstrap exception:** On first run, if the project-level `progress.txt` does not exist,
`/project` creates it with gate entries and no milestones. Milestone-level `milestone-status.txt`
files are created by `/milestone` when milestones are defined. This bootstrap is the only case where
`/project` writes to disk. After bootstrap, `/project` is strictly read-only.

**Gate 3 closure exception:** When all milestones are `[x]` complete and Gate 3 remains
`[~] In progress`, `/project` offers closure via `AskUserQuestion`. This is the only
post-bootstrap write `/project` performs.

**Artifact validation:** When reading `progress.txt`, `/project` checks that artifact paths
listed alongside approved gates exist on disk. If a gate is marked approved but its artifact
file is missing, `/project` warns the user but does not block — the user decides whether to
restore the file or proceed.

**Consistency validation:** `/project` validates that each milestone's summary status in the
project-level file is consistent with the milestone-level `milestone-status.txt`. If they diverge,
`/project` warns the user.

**Rationale:** Supports `clear` commands, session gaps (days/weeks), machine switches, and team
handoffs. Every invocation reconstructs the picture from files on disk. No conversation memory,
no session continuity assumptions.

**Tradeoff:** The orchestrator is the only entry point — users cannot invoke phase skills
directly. Skipping is supported *within* the orchestration (e.g., skip Working Backwards),
not by bypassing the orchestrator itself. This ensures gate integrity is always maintained.

---

### DD-4: One skill per gate, plus a router

**Decision:** Seven components — one router, one skill per gate, plus `/spike` and `/build`:

| Component | Gate | Role | Reads | Writes |
|---|---|---|---|---|
| `/project` | — | Router — reads state, reports status, directs to next phase | progress.txt, milestones/\*/milestone-status.txt (validation) | nothing |
| `/define` | 0, WB, 1 | Codebase assessment, optional Working Backwards, PRD creation | codebase, progress.txt | docs/codebase-assessment.md, docs/working-backwards.md, prd.md, docs/reviews/gate-{0,wb,1}-review.md, progress.txt |
| `/design` | 2 | Architecture and design specification | prd.md, docs/codebase-assessment.md, progress.txt | docs/ARCHITECTURE_AND_DESIGN.md, docs/reviews/gate-2-review.md, progress.txt |
| `/milestone` | 3 | Milestone breakdown — grouping, ordering, sizing | prd.md, docs/ARCHITECTURE_AND_DESIGN.md, progress.txt, docs/spikes/\*.md (if referenced) | milestones/\<NN\>-\<name\>/README.md, milestones/\<NN\>-\<name\>/milestone-status.txt, milestones/\<NN\>-\<name\>/reviews/gate-3-review.md, progress.txt, prd.md (milestone summary sync on re-plan) |
| `/plan-feature` | 4 | Per-feature implementation plan (one feature per invocation) | milestone README, prd.md, docs/ARCHITECTURE_AND_DESIGN.md, progress.txt, milestones/\<NN\>-\<name\>/milestone-status.txt, docs/spikes/\*.md (if referenced) | milestones/\<NN\>-\<name\>/plans/\<feature\>.md, milestones/\<NN\>-\<name\>/reviews/gate-4-\<feature\>-review.md, milestones/\<NN\>-\<name\>/milestone-status.txt |
| `/spike` | — | Agent-based technical research with red-team validation | user-defined question, available tooling (MCP, crawlers, local docs, repos), progress.txt | docs/spikes/\<topic\>.md, progress.txt |
| `/build` | — | Implementation, deviation tracking, sub-feature completion | feature plan, codebase, docs/codebase-assessment.md, progress.txt, milestones/\<NN\>-\<name\>/milestone-status.txt, docs/ARCHITECTURE_AND_DESIGN.md | docs/codebase-assessment.md (refresh), feature plan (sub-feature checklist, architectural deviations), milestones/\<NN\>-\<name\>/milestone-status.txt, progress.txt (milestone summary on completion) |

**Rationale:** Each gate is a meaningful phase boundary where the user reviews and approves
before proceeding (DD-7). One skill per gate gives each phase a clean context window,
eliminates context rot across phases, and maps directly to the gate structure. The `/define`
skill owns Gates 0, WB, and 1 as a single continuous session (see DD-2 exception) — these
gates are internal approval checkpoints within `/define`, not separate orchestrator-routed
invocations. The user approves each gate before `/define` proceeds to the next, but remains
in the same conversation throughout.

**Relationship to `create-prd`:** The `/define` skill is forked from the existing `create-prd`
skill (in `skills/create-prd/`) and refined for the milestone-based pipeline. `create-prd`
remains untouched as a standalone skill for users who want a traditional monolithic PRD without
the full orchestrated workflow.

**Tradeoff:** Six skills plus a router is more components to maintain than the original
proposal of two. Mitigation: each skill has a narrow, well-defined contract (read specific
inputs, produce specific outputs, update progress files). The narrow scope makes each skill
simpler to write and test individually.

---

### DD-5: File artifacts are the API between phases

**Decision:** Phase skills communicate exclusively through files on disk. No shared conversation
state, no in-memory hand-offs.

**Rationale:** Files survive `clear`, session gaps, machine switches, and team handoffs. They're
version-controllable, diff-able, and reviewable. The two-tier progress files are the source of
truth: the project-level `progress.txt` for gates, milestone summaries, and spikes; the
milestone-level `milestone-status.txt` for feature details. Every skill reads the project-level file
fresh on entry, and reads the milestone-level file only when working on that milestone.

**Tradeoff:** Two-tier progress files introduce a consistency concern — the milestone summary
in the project file must match the milestone's `milestone-status.txt`. Mitigation: `/project`
validates consistency on read and warns on divergence. Both files are version-controlled so
recovery is possible via git.

---

### DD-6: Re-planning at milestone and PRD level

**Decision:** Re-planning operates at two levels:

- **Milestone re-planning:** When requirements change or implementation reveals a flaw within
  a milestone, the user initiates re-planning through `/project`, which routes to `/milestone`
  for the affected milestone. The skill detects existing artifacts and offers to revise rather
  than overwrite. When the milestone's scope changes, `/milestone` also updates the
  corresponding 1-2 sentence summary line in `prd.md` to keep the PRD consistent.

- **PRD revision:** When project-level goals change (customer direction shifted, product vision
  revised), the user tells `/project` the goals have changed. `/project` routes to `/define`
  in revision mode — `/define` reads the existing PRD and runs a focused interview on what
  changed rather than starting from scratch. Downstream artifacts (architecture, milestones,
  feature plans) are not automatically reset — the user decides which downstream artifacts
  need re-review. No automatic cascade reset is enforced.

**Rationale:** Milestone re-planning replaces the original proposal's "follow-up `create-plan`"
with a natural re-entry point. PRD revision extends the same pattern one level up — the user
can re-plan *within* the project (milestone) or re-plan *the project itself* (PRD). Both paths
go through `/project` as the single entry point.

**Tradeoff:** Re-planning a milestone may invalidate some of its features. `/milestone` in
revision mode identifies which features are affected by the scope change and resets only those
to `planned` status in `milestone-status.txt`. Completed features that are
unaffected retain their status. The user confirms the reset list before it takes effect.
`/milestone` also updates the milestone summary line in the project-level `progress.txt` to
reflect the new feature count and status. PRD revision may affect downstream artifacts more
broadly, but cascade resets are not enforced — the user is responsible for deciding what
needs re-review (no automatic cascade).

---

### DD-7: Human-In-The-Loop at every phase gate

**Decision:** The pipeline has six explicit gates (0, WB, 1, 2, 3, 4) — Gate WB is optional.
No phase transition happens without human review and explicit approval.

```
Codebase ──► [GATE 0: Alignment Review] ──► Validated Understanding
                                                    │
Idea ──────────────────────────────────────────────► │
                                                    ▼
                                      (optional) [GATE WB: Working Backwards] ──► PR/FAQ
                                                    │
                                             [GATE 1: Scope Review] ──► PRD
                                                    │
                                             [GATE 2: Design Review] ──► Architecture & Design
                                                    │
                                             [GATE 3: Milestone Review] ──► Milestone Breakdown
                                                    │
                                             [GATE 4: Plan Review] ──► Feature Implementation Plans
                                                    │
                                                    ▼
                                               Implementation
                                                    │
                                                    ▼
                                               (Code Review & PR — external, out of scope)
```

**Gate behaviors:**

| Gate | Input | Human reviews | Approve to proceed | Reject to |
|---|---|---|---|---|
| 0 — Alignment | Codebase scan results (skipped if greenfield — see DD-10) | Codebase assessment — detected patterns, conventions, architecture, assumptions | Gate WB (offered) or Gate 1 | Correct assumptions in-session |
| WB — Working Backwards (optional) | User's idea + validated understanding | Press release and FAQ — customer outcome, problem solved, experience, internal feasibility. Recorded as `[ ] Pending` when offered; must reach `[x]` or `[-]` before Gate 1 | Gate 1 | Revise PR/FAQ in-session, or skip (`[-]`) |
| 1 — Scope | Approved PR/FAQ (if used) + idea + interview answers | Draft PRD — goals, non-goals, milestone summaries, risk assessment | Gate 2 | Revise PRD in-session |
| 2 — Design | Approved PRD | Architecture doc — design decisions, component inventory, tech choices | Gate 3 | Revise design in-session |
| 3 — Milestone | Approved PRD + architecture | Milestone breakdown — grouping, ordering, sizing, dependencies | Gate 4 (per milestone) | Re-scope milestones in-session |
| 4 — Plan | Approved milestone + single feature | Per-feature implementation plan (one per invocation) — approach, interfaces, edge cases, test strategy | `/build` (for this feature) | Revise plan in-session |

**Gate rules:**

1. **Artifacts are drafts until approved.** The skill produces output, then pauses for review.
   It never auto-advances to the next phase.
2. **Rejection is revision, not restart.** When the user rejects at a gate, the skill revises
   the current artifact in the same session. It does not discard work and start over.
3. **Approval is recorded in `progress.txt`.** Each gate approval is timestamped so the
   orchestrator knows which phases are complete. This survives `clear` and session gaps.
4. **Partial approval is supported.** The user can approve parts of an artifact and request
   revision of others (e.g., "features 1–3 look good, rethink feature 4").
5. **No implicit approval.** Moving to the next phase requires an explicit "approved" or
   equivalent. The skill asks directly — it does not infer approval from silence or
   continuation.
6. **Checklist completeness required.** Before recording gate approval, the skill validates
   that all items in the gate's review checklist file are resolved — checked `[x]` or marked
   `[-]` N/A with a reason. Unresolved items block approval.

**Rationale:** The AI assistant is a collaborator, not an autonomous agent. Every phase transition
is a point where model assumptions can drift from user intent. The earlier drift is caught, the
cheaper it is to correct. Without explicit gates, the model optimizes for completion — producing
plausible-looking artifacts that may not reflect what the user actually wants.

This also means that between any two sessions, the user (or their team) can review artifacts
offline, bring feedback from stakeholders, or change direction — and the skill picks up from the
last approved gate.

**Tradeoff:** Slower throughput. A user who knows exactly what they want must still approve at
each gate. Mitigation: gates are lightweight — the skill presents a summary and asks for
approval, not a ceremony. A confident user can approve in one line.

---

### DD-8: Gate reviews adapt to phase context

**Decision:** Each gate review presents information appropriate to the decision being made.

- **Gate 0 (Alignment):** "Here's what I found in the codebase — detected patterns, conventions,
  architecture, and the assumptions I'll carry forward. Which patterns should I follow? Which
  should I change? What did I miss?" — focuses on correctness and completeness of the model's
  understanding
- **Gate WB (Working Backwards):** "Here's the press release and FAQ describing the finished
  product. Does this capture the right customer, problem, and outcome? Are the internal FAQ
  answers honest about feasibility and risks?" — focuses on customer value, clarity of vision,
  and internal honesty
- **Gate 1 (Scope):** "Here's what we're building and what we're not — goals, non-goals,
  milestone summaries, and risk assessment. Does this match your intent? Is anything missing
  or incorrectly excluded?" — focuses on completeness and boundaries
- **Gate 2 (Design):** "Here are the technical choices, tradeoffs, component inventory, data
  flow, and security considerations. Do these align with your constraints? Is anything
  missing?" — focuses on feasibility, completeness, and tech fit
- **Gate 3 (Milestone):** "Here's how the work is grouped and ordered — feature grouping,
  sequencing, acceptance criteria, and sizing. Does this sequencing make sense? Are the
  acceptance criteria specific and testable?" — focuses on delivery strategy and testability
- **Gate 4 (Plan):** "Here's how this specific feature will be implemented — approach, sub-feature
  breakdown, test command, files to create or modify, and interface contracts. Does this
  approach handle your edge cases? Are the sub-features scoped for single-session work?" —
  focuses on implementation correctness and feasibility

**Rationale:** A generic "does this look good?" at every gate trains the user to rubber-stamp.
Phase-specific review prompts direct attention to what matters at that stage and surface the
decisions that are most likely to cause problems if wrong.

---

### DD-9: Code review and PR review are out of scope

**Decision:** The pipeline ends at implementation. Code review, pull request review, and merge
decisions are handled by external processes (team review, CI/CD, GitHub PR workflows).

**Rationale:** Code review is an established practice with existing tooling. Duplicating it
inside the skill would add complexity without value. The skill's job is to ensure the *plan*
is right before code is written — reducing the volume of issues found in code review, not
replacing it.

---

### DD-10: Gate 0 — Codebase Alignment Review

**Decision:** When the skill runs in an existing codebase (not greenfield), Gate 0 fires before
any planning begins. The model scans the codebase, forms an understanding of existing patterns
and architecture, and presents that understanding for human validation.

**The codebase assessment covers:**

- **Detected patterns** — naming conventions, file organization, module structure, error handling
  style, test patterns
- **Inferred architecture** — how components connect, data flow, dependency graph
- **Existing design decisions** — tech stack choices, framework usage, configuration approach
- **Assumptions the model will carry forward** — explicitly stated so the user can challenge them

**Why this gate exists:**

The model will detect patterns and treat them as intentional. But patterns in existing code may
be:

- Legacy decisions that should not be replicated
- Anti-patterns the team wants to move away from
- Inconsistent across the codebase (different authors, different eras)
- Technically functional but known to cause problems at scale

Without Gate 0, these patterns silently propagate into the PRD, design doc, and implementation
plans. The user discovers the drift only during code review — the most expensive place to catch
it.

**Gate 0 behavior:**

1. Skill scans codebase — file structure, key files, patterns, dependencies, git history
2. Produces a Codebase Assessment artifact listing findings and assumptions
3. Presents to user: "Here's what I found. Which patterns should I follow? Which should I
   deviate from?"
4. User corrects, confirms, or redirects
5. Approved understanding becomes an input to Gate 1 and Gate 2 (design). `/build` re-reads
   the codebase assessment when refreshing it at each feature start

**Greenfield detection:** If the project directory is empty or contains only boilerplate
(README, .gitignore, package.json with no src/), Gate 0 is skipped. The skill proceeds
directly to Gate 1.

**Tradeoff:** Adds an upfront step that may feel unnecessary for small projects or when the
user is deeply familiar with the codebase. Mitigation: the assessment is concise — a structured
summary, not an exhaustive audit. For small codebases, Gate 0 may take one exchange.

---

### DD-11: Optional Working Backwards stage

**Decision:** An optional "Working Backwards" gate (Gate WB) can be activated between Gate 0 and
Gate 1. When used, the skill collaborates with the user to produce a Press Release and FAQ
before any requirements are written.

**The PR/FAQ artifact contains:**

- **Press Release** — a future-dated, one-page announcement of the finished product written in
  plain language. Answers: who is the customer, what problem does this solve, what is the
  experience, and why does it matter.
- **External FAQ** — questions a customer would ask. Forces clarity on the user experience,
  limitations, and value proposition.
- **Internal FAQ** — questions a stakeholder or engineer would ask. Covers feasibility, cost,
  risks, dependencies, and timeline assumptions.

**When to use it:**

- Greenfield products where the customer outcome isn't yet clear
- Projects where multiple stakeholders need to align on vision before decomposition
- When the user explicitly requests it or the orchestrator offers it

**When to skip it:**

- Adding features to an existing product where the customer and outcome are already known
- Small, well-scoped work where a PRD interview is sufficient
- When the user declines the offer

**How it changes the flow:**

The approved PR/FAQ becomes a primary input to Gate 1 (Scope). Instead of the PRD interview
starting from a vague idea, it starts from an approved customer outcome. This produces a
tighter PRD with fewer rounds of revision — the "what" and "why" are already settled, so the
interview focuses on the "how much" (scope, acceptance criteria, boundaries).

**Activation:** The orchestrator (`/project`) or the `/define` skill offers Gate WB when
no PR/FAQ exists and the customer outcome is not yet clear. This is independent of Gate 0's
structural greenfield check — a project with substantial existing code can still benefit from
Working Backwards when it introduces a new product vertical, a major capability, or any
initiative where the "what does the customer get?" question hasn't been answered. The trigger
is strategic (unclear customer outcome), not structural (empty directory). The user can accept
or skip. If skipped, `progress.txt` records Gate WB as `[-] Skipped` so the offer is not
repeated.

**Pending state:** When Gate 0 completes and Gate WB is offered, `progress.txt` records Gate WB
as `[ ] Pending — offered, awaiting decision`. If the session ends before the user decides,
the pending state persists. On the next `/project` or `/define` invocation, the skill detects
the pending state and re-prompts the user for their decision before any further progress. Gate
WB must reach `[x]` or `[-]` before Gate 1 can begin.

**Rationale:** Working Backwards forces the hardest question first — "what does the customer
get?" — before the team falls in love with a technical approach. It's the highest-leverage
gate for preventing wasted effort, but it's also the most overhead for small projects. Making
it optional respects both use cases.

**Tradeoff:** Optional gates add branching logic to the orchestrator and skill. Mitigation: the
branch is binary (offered → accepted or skipped) with no further nesting. `progress.txt` tracks
the decision cleanly.

---

### DD-12: Feature testing — planned during `/plan-feature`, executed during `/build`

**Decision:** Every feature requires a test command that validates it (pass/fail). The skill's
role is strictly limited to invoking the test command and interpreting the exit code — it does
not generate, manage, or modify test content. Tests are:

1. **Defined during the `/plan-feature` phase** — the feature plan includes a `Test Command:` field
   specifying the single command to run for validation (e.g., `bash tests/test-auth.sh`,
   `pytest tests/test_auth.py`, `cdk deploy && bash tests/validate.sh`)
2. **Created and maintained by the user** — the user writes, generates, or manages test
   scripts and test content outside of the skill pipeline. The skill treats test artifacts
   as external inputs, not skill-managed artifacts
3. **Executed during `/build`** — the build skill runs the test command as part of feature
   completion. A feature is not complete until its test command passes (exit code 0)
4. **Updatable mid-build** — if the user needs to change the test command during `/build`
   (wrong path, different test runner, expanded scope), they tell `/build` and it updates
   the `Test Command:` field in the feature plan. No gate re-approval needed — the feature
   plan is already a `/build` write target

**Tests are not a separate phase or skill.** Test planning is part of `/plan-feature` (Gate 4). Test
execution is part of `/build`. No discrete testing gate or skill is needed.

**Rationale:** The skill is an orchestrator, not a test framework. It invokes a command and
checks pass/fail. Everything about test content — what to test, how to test, which framework
to use — is the user's responsibility. This keeps the skill decoupled from any specific
testing technology and avoids the skill generating tests that give false confidence.

**Tradeoff:** The skill cannot validate test quality or coverage — it only knows pass/fail.
Mitigation: the test command and strategy are visible in the feature plan (reviewed at Gate 4).
The user is responsible for ensuring the test command actually validates the feature.

---

### DD-13: Gate review checklists for offline reviewers

**Decision:** Each gate produces a structured review checklist alongside its artifact. The
checklist guides offline reviewers (team members, stakeholders) on what to evaluate, ensuring
consistent and complete feedback across sessions and reviewers.

**Checklist per gate:**

- **Gate 0 (Alignment):**
  - [ ] Are the detected patterns accurate for the current codebase?
  - [ ] Are there patterns listed as "carry forward" that should be changed?
  - [ ] Are there existing patterns not detected that the model should follow?
  - [ ] Are the open questions answerable? Provide answers.

- **Gate WB (Working Backwards):**
  - [ ] Does the press release describe the right customer?
  - [ ] Is the problem statement accurate and compelling?
  - [ ] Does the described experience match what we intend to build?
  - [ ] Are the internal FAQ answers honest about feasibility and risks?

- **Gate 1 (Scope):**
  - [ ] Do the goals capture what success looks like?
  - [ ] Are the non-goals correct — nothing excluded that should be in scope?
  - [ ] Do the milestone summaries cover all intended work?
  - [ ] Is the risk assessment complete?

- **Gate 2 (Design):**
  - [ ] Are the design decisions sound? Are tradeoffs acceptable?
  - [ ] Is the component inventory complete?
  - [ ] Does the data flow match your understanding of the system?
  - [ ] Are there security considerations missing?

- **Gate 3 (Milestone):**
  - [ ] Does the milestone represent a coherent, deployable increment?
  - [ ] Are features correctly grouped? Any that belong in a different milestone?
  - [ ] Is the ordering correct given dependencies?
  - [ ] Are the acceptance criteria specific and testable?
  - [ ] Is the sizing realistic?

- **Gate 4 (Plan):**
  - [ ] Does the approach handle known edge cases?
  - [ ] Are the sub-features correctly scoped for single-session work?
  - [ ] Is the test command appropriate for this feature?
  - [ ] Are the files to create/modify correct?
  - [ ] Are interface contracts compatible with existing code?

**Delivery:** Each gate produces a dedicated review checklist file, separate from the artifact.
Files follow a consistent path convention:

| Gate | Checklist path |
|---|---|
| 0 (Alignment) | `docs/reviews/gate-0-review.md` |
| WB (Working Backwards) | `docs/reviews/gate-wb-review.md` |
| 1 (Scope) | `docs/reviews/gate-1-review.md` |
| 2 (Design) | `docs/reviews/gate-2-review.md` |
| 3 (Milestone) | `milestones/<NN>-<name>/reviews/gate-3-review.md` |
| 4 (Plan) | `milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md` |

Every checklist file uses a consistent structure:

```markdown
# Gate <N> Review — <Gate Name>

**Artifact:** <path to artifact under review>
**Status:** [ ] Pending | [x] Complete
**Reviewer(s):** <name(s)>
**Date:** <date>

## Checklist

- [ ] <gate-specific item 1>
- [ ] <gate-specific item 2>
...

## Reviewer Comments

<free-form feedback, inline references to checklist items>
```

**Completeness validation:** A gate cannot be approved until all checklist items are resolved —
each item must be checked `[x]` or marked `[-]` N/A with a reason. The skill validates
checklist completeness before recording gate approval in `progress.txt`. Feedback in reviewer
comments is addressed in the current session before approval.

**Rationale:** Without a checklist, offline reviewers default to "looks good" or provide
unstructured feedback that may miss critical areas. Separate files keep review artifacts
distinct from the work artifacts themselves — the artifact is the deliverable, the checklist
is the review record. The consistent structure makes it easy to scan review status across gates.

**Tradeoff:** Adds files to the project. Mitigation: the checklists are short (4–6 items)
and gate-specific. They're a guide, not a form — reviewers can add feedback beyond the
checklist items. The files also serve as an audit trail of what was reviewed and by whom.

---

### DD-14: Spike research with agent-based investigation

**Decision:** A `/spike` skill enables targeted technical research before committing to a plan.
`/project` offers spike research at contextually appropriate stages — primarily between Gate 2
(Design) and Gate 3 (Milestone), and during `/build` when unexpected technical questions arise.
The user decides whether a spike is needed; it is never automatic.

**How it works:**

1. **User defines the spike** — a question or hypothesis to investigate (e.g., "Can we use
   WebSockets with our existing auth middleware?" or "What's the migration path from SQLite to
   Postgres for our schema?"). The user also specifies available tooling for the research:
   - MCP servers (APIs, databases, external services)
   - Web crawlers / search
   - Local documentation
   - Local cloned repos (reference implementations, libraries)
   - Any other tools the user makes available

2. **Research agent** — a sub-agent runs autonomously using the provided tooling. It investigates
   the question and produces a structured findings document. The research agent maintains memory
   of its investigation so the user can task it with follow-up checks after reviewing initial
   findings (e.g., "also check how library X handles connection pooling").

3. **Red-team agent** — a separate sub-agent performs a single validation pass on the research
   findings, checking for:
   - Factual errors or unsupported claims
   - Missing alternatives not considered
   - Flawed reasoning or confirmation bias
   - Assumptions stated as facts
   - Gaps in the investigation

4. **Spike artifact** — `docs/spikes/<topic>.md` with consistent structure (see Artifact details).

**Pipeline integration:**

- `/project` offers spike research when presenting status at stages where technical uncertainty
  is common (post-Gate 2, during milestone planning, during build). The user accepts or declines.
- `/spike` writes spike entries to the project-level `progress.txt` under the `## Spikes`
  section (adds new entries, updates status on resolution).
- `/milestone` and `/plan-feature` read relevant spike artifacts as inputs when the user references them.
- Spikes don't block the pipeline — the user decides when a spike is resolved and whether findings
  change the plan.
- Follow-up research: after reviewing findings, the user can re-invoke `/spike` on the same
  topic. The research agent's memory preserves prior investigation context, enabling targeted
  follow-up without re-doing earlier work.

**Rationale:** Spikes are how teams answer "can we do this?" before committing resources. Without
a formal place in the pipeline, exploratory research either doesn't happen (leading to bad plans)
or happens informally with findings lost. Agent-based research with red-team validation produces
higher-quality findings than a single-pass investigation — the adversarial review catches the
confirmation bias that research agents are prone to. Making it opt-in (offered, not automatic)
avoids wasting tokens on questions the user can already answer.

**Tradeoff:** Adds a skill and artifact type. The research agent's autonomy means token spend is
less predictable than other skills. Mitigation: the user controls when spikes happen and what
tooling is available. The red-team pass adds token cost but catches errors that would be more
expensive to discover during implementation.

---

## Artifacts

### Naming conventions

**Milestone directories:** `milestones/<NN>-<name>/`
- `<NN>` — zero-padded two-digit sequence number enforcing execution order (e.g., `01`, `02`)
- `<name>` — kebab-case slug derived from the milestone title (e.g., `core-auth`, `dashboard`)
- Example: `milestones/01-core-auth/`

**Feature plan files:** `milestones/<NN>-<name>/plans/<feature>.md`
- `<feature>` — kebab-case slug derived from the feature name (e.g., `user-registration`, `data-export`)
- One file per feature, all plans for a milestone live in its `plans/` subdirectory

**General rules:**
- All names are lowercase kebab-case (words separated by hyphens, no spaces or underscores)
- Names are derived from titles at creation time and do not change if the title is later revised
- Project-level strategic artifacts live in the project root (`prd.md`, `progress.txt`)
- Milestone-level state lives alongside milestones (`milestones/<NN>-<name>/milestone-status.txt`)
- Supporting documents live in `docs/` (`codebase-assessment.md`, `working-backwards.md`, `ARCHITECTURE_AND_DESIGN.md`)
- Gate review checklists live in `docs/reviews/` (Gates 0, WB, 1, 2) and `milestones/<NN>-<name>/reviews/` (Gates 3, 4)
- `ARCHITECTURE_AND_DESIGN.md` uses uppercase to signal it is a project-wide reference document, distinct from the per-milestone artifacts

### Document tree

```
<project-root>/
├── progress.txt                              # Project state — gate approvals, milestone summaries, spikes
├── prd.md                                    # Product Requirements Document — goals, non-goals, milestone summaries
├── docs/
│   ├── codebase-assessment.md                # Gate 0 — detected patterns, conventions, assumptions
│   ├── working-backwards.md                  # Gate WB — optional press release & FAQ
│   ├── ARCHITECTURE_AND_DESIGN.md            # Gate 2 — system-level design decisions, components, data flow
│   ├── reviews/                              # Gate review checklists (Gates 0, WB, 1, 2)
│   │   ├── gate-0-review.md                  # Gate 0 — codebase alignment review checklist
│   │   ├── gate-wb-review.md                 # Gate WB — working backwards review checklist
│   │   ├── gate-1-review.md                  # Gate 1 — scope review checklist
│   │   └── gate-2-review.md                  # Gate 2 — design review checklist
│   └── spikes/                               # Spike research artifacts
│       └── <topic>.md                        # Per-spike findings, red-team assessment, recommendation
└── milestones/
    ├── 01-core-auth/
    │   ├── README.md                         # Gate 3 — milestone scope, features, acceptance criteria
    │   ├── milestone-status.txt              # Milestone state — feature entries, plans, sub-features, notes
    │   ├── reviews/                          # Gate review checklists (Gates 3, 4)
    │   │   ├── gate-3-review.md              # Gate 3 — milestone review checklist
    │   │   └── gate-4-user-registration-review.md  # Gate 4 — per-feature plan review checklist
    │   └── plans/
    │       ├── user-registration.md           # Gate 4 — feature implementation plan
    │       └── session-management.md          # Gate 4 — feature implementation plan
    └── 02-dashboard/
        ├── README.md                         # Gate 3 — milestone scope, features, acceptance criteria
        ├── milestone-status.txt              # Milestone state — feature entries, plans, sub-features, notes
        ├── reviews/                          # Gate review checklists (Gates 3, 4)
        │   └── gate-3-review.md              # Gate 3 — milestone review checklist
        └── plans/
            ├── data-visualization.md          # Gate 4 — feature implementation plan
            └── export.md                      # Gate 4 — feature implementation plan
```

### Artifact inventory

| Gate | Artifact | Path | Description |
|---|---|---|---|
| 0 — Alignment | Codebase Assessment | `docs/codebase-assessment.md` | Detected patterns, conventions, architecture, assumptions; annotated with user corrections |
| WB — Working Backwards (optional) | Press Release & FAQ | `docs/working-backwards.md` | Customer-facing press release, external FAQ, internal FAQ |
| 1 — Scope | Product Requirements Document | `prd.md` | Fixed-size strategic doc: goals, non-goals, milestone summaries, risk assessment |
| 2 — Design | Architecture & Design Document | `docs/ARCHITECTURE_AND_DESIGN.md` | System-level design decisions, component inventory, tech choices |
| 3 — Milestone | Milestone Breakdown | `milestones/<NN>-<name>/README.md` | Milestone scope, feature list, ordering, dependencies, sizing |
| 4 — Plan | Feature Implementation Plan | `milestones/<NN>-<name>/plans/<feature>.md` | Per-feature implementation plan — approach, interfaces, edge cases, test strategy |
| — Spike | Spike Research | `docs/spikes/<topic>.md` | Question, methodology, findings, red-team assessment, recommendation |
| All gates | Review Checklist | `docs/reviews/gate-{0,wb,1,2}-review.md`, `milestones/<NN>-<name>/reviews/gate-{3,4-<feature>}-review.md` | Per-gate structured checklist for offline review; completeness validated before gate approval |
| All | Project State | `progress.txt` | Gate approvals (with timestamps), milestone summary statuses, spike entries |
| All | Milestone State | `milestones/<NN>-<name>/milestone-status.txt` | Feature entries with plan paths, sub-feature checklists, notes |

### Artifact details

#### `docs/codebase-assessment.md` (Gate 0)

Produced by the `/define` skill when an existing codebase is detected. Records the model's
understanding of the codebase so it can be reviewed, corrected, and referenced by all downstream
phases.

**Sections:**

- **Project Overview** — language, framework, runtime, package manager
- **File Organization** — directory structure, naming conventions, module boundaries
- **Detected Patterns** — error handling, logging, testing, configuration, API style
- **Dependency Graph** — key internal and external dependencies, how components connect
- **Assumptions to Carry Forward** — explicit list of what the model will treat as intentional
- **Patterns to Deviate From** — populated by user during Gate 0 review; empty until then
- **Open Questions** — things the model couldn't determine from the code alone
- **Recent Changes** — summary of git history since last assessment (commits, authors, areas changed)

**Lifecycle:** Created at Gate 0 (project start). Refreshed automatically at the start of each
new feature — `/build` re-reads the codebase and checks git history (commits since the last
assessment) to identify what changed, who changed it, and which areas were affected. This
catches out-of-band changes such as hotfixes, external contributions, or manual edits made
outside the pipeline. Can also be refreshed on-demand at any time by user request. Not
refreshed between milestones unless a new feature triggers it (milestone boundaries do not
significantly change the codebase relative to feature boundaries).

#### `docs/working-backwards.md` (Gate WB — optional)

Press Release and FAQ. Forces clarity on the customer outcome before requirements are written.
Only produced when Gate WB is activated.

**Sections:**

- **Press Release** — future-dated announcement of the finished product. Written in plain
  language for a non-technical audience. Covers: customer, problem, solution, experience,
  quote from a hypothetical customer, call to action.
- **External FAQ** — questions a customer or end-user would ask. Covers: how it works, what
  it costs, limitations, getting started, compatibility.
- **Internal FAQ** — questions an engineer, stakeholder, or executive would ask. Covers:
  technical feasibility, estimated effort, risks, dependencies, alternatives considered,
  why now.

**Lifecycle:** Created at Gate WB if activated. Approved before Gate 1 begins. Referenced by
Gate 1 as primary input — the PRD interview draws goals, non-goals, and features from the
approved PR/FAQ. Not updated after approval unless the user explicitly revisits vision (rare).

#### `prd.md` (Gate 1)

Product Requirements Document. A fixed-size strategic document that defines *what* is being
built and *why*. Does not contain milestone-level detail — milestones own their own detail
in their README files.

**Sections:**

- **Summary** — 1–2 sentence project description
- **Goals** — what success looks like
- **Non-Goals** — explicit scope boundaries
- **External Dependencies** — services, APIs, platforms
- **Milestones** — 1–2 sentence summary per milestone with cross-reference to
  `milestones/<NN>-<name>/README.md`. Completed milestones marked `[COMPLETE]`.
- **Configuration** — project-wide parameters, environment variables, settings
- **Outputs** — what the system produces (APIs, files, events, UI)
- **Risk Assessment** — known risks with severity and mitigation
- **Future Enhancements** — out-of-scope ideas to revisit later

**Lifecycle:** Created at Gate 1. Remains approximately constant size throughout the project.
New milestones add a summary line, not a full section. Milestone detail (features, acceptance
criteria, ordering) lives in the milestone README. No archiving needed — the PRD never grows
beyond its initial scope.

#### `docs/ARCHITECTURE_AND_DESIGN.md` (Gate 2)

System-level architecture and design specification. Defines *how* the system is structured.

**Sections:**

- **Design Decisions** — numbered table: decision, rationale, tradeoff, alternatives considered
- **Component Inventory** — components, responsibilities, interfaces
- **Data Flow** — how data moves through the system
- **File Organization** — target directory structure and naming
- **Deployment & Operations** — how the system is deployed, monitored, operated
- **Security Considerations** — auth, access control, data handling

**Lifecycle:** Created at Gate 2. One document for the whole project — system-level decisions
are project-wide, not milestone-scoped. The architecture doc reflects the design as understood
at Gate 2. When implementation forces an architectural deviation (failed approach, new
constraint discovered, technology change), the deviation and its reasoning are captured in the
feature plan's Architectural Deviations section. The architecture doc can be updated at any
point by the user initiating a refresh through `/project`, using accumulated deviation records
as input. There is no automatic trigger — the user decides when consolidation is warranted.

#### `milestones/<NN>-<name>/README.md` (Gate 3)

Milestone definition. The authoritative source of detail for a milestone — features, acceptance
criteria, and scope live here, not in the PRD.

**Sections:**

- **Goal** — what this milestone delivers and why it's a coherent unit
- **Features** — numbered list with acceptance criteria per feature (the detail that would
  traditionally live in a PRD's feature section)
- **Dependencies** — what must be complete before this milestone starts (prior milestones,
  external dependencies)
- **Ordering** — sequence of features within the milestone, with rationale
- **Sizing** — relative complexity estimate per feature
- **Configuration** — milestone-specific parameters (if any beyond project-wide config)
- **Definition of Done** — what "milestone complete" means

**Lifecycle:** Created at Gate 3. One directory per milestone. The `<NN>` prefix enforces
ordering (e.g., `01-core-auth/`, `02-dashboard/`). Updated if re-planning occurs (DD-6).
Self-contained — a completed milestone's directory has everything needed to understand what
was built and why.

#### `milestones/<NN>-<name>/plans/<feature>.md` (Gate 4)

Per-feature implementation plan. The most granular planning artifact — what a developer (or
`/build`) needs to begin coding.

**Sections:**

- **Summary** — what this feature does, in one paragraph
- **Acceptance Criteria** — pulled from milestone README, refined with implementation detail
- **Approach** — how the feature will be implemented (algorithms, patterns, flow)
- **Sub-Features** — checklist of committable units of work, each completable within a single
  `/build` session (~120k tokens on a 200k model). Each item describes the change and its scope.
- **Interface Contracts** — API signatures, data shapes, event formats
- **Edge Cases** — known edge cases and how they're handled
- **Test Command** — the single command to run to validate this feature (e.g.,
  `pytest tests/test_auth.py`, `bash tests/smoke.sh`). Agent-generated, user-adjustable.
- **Test Strategy** — what to test, how to test, coverage expectations
- **Documentation** — what documentation to create or update for this feature
- **Files to Create/Modify** — specific file paths and what changes in each
- **Dependencies** — other features, libraries, services this feature needs
- **Architectural Deviations** — any changes to the project's architecture forced during
  implementation. Each entry records: what changed, what was originally planned, why the
  change was necessary, and impact on other components. Empty if the feature was built as
  designed. These records serve as input when the user consolidates updates into
  `docs/ARCHITECTURE_AND_DESIGN.md`.

**Lifecycle:** Created at Gate 4, one per feature. Referenced by `/build` during implementation.
Updated if re-planning occurs. `/build` adds architectural deviation entries during
implementation when the approved design cannot be followed as planned.

#### `docs/spikes/<topic>.md` (Spike research)

Produced by the `/spike` skill when the user initiates technical research. Captures the
investigation, adversarial validation, and recommendation in a single document.

**Sections:**

- **Question** — the specific technical question or hypothesis being investigated
- **Available Tooling** — what tools were provided for the research (MCP servers, crawlers,
  local docs, cloned repos, etc.)
- **Methodology** — what the research agent investigated and how (searches performed, docs
  read, code analyzed, APIs queried)
- **Findings** — what the research agent discovered, organized by sub-question or theme
- **Red-Team Assessment** — the validation agent's critique: errors found, alternatives missed,
  unsupported claims, gaps identified
- **Recommendation** — conclusion incorporating both findings and red-team feedback; actionable
  input for planning decisions
- **Status** — `open` (investigation ongoing or follow-up pending) or `resolved` (question
  answered, findings incorporated into planning)
- **Follow-Up Log** — chronological record of follow-up research rounds, each with its own
  findings and red-team assessment (empty if no follow-ups were needed)

**Lifecycle:** Created by `/spike` when the user initiates a research question. Updated when
the user requests follow-up investigation on the same topic. Referenced by `/milestone` and
`/plan-feature` when the user indicates spike findings should inform planning. Status set to `resolved`
by the user when the question is satisfactorily answered.

#### `progress.txt` — Project level (All gates)

Project-level source of truth. Contains gate approvals, milestone summaries (one line each),
and spike entries. Every skill reads this on entry. Deliberately kept small — feature-level
detail lives in milestone-level `milestone-status.txt` files.

**Format:** Plain text, extending the existing `progress.txt` conventions (checkbox notation,
comment headers, inline notes). Chosen over YAML for human editability, model write safety,
token efficiency, and format tolerance. See [progress-file/](progress-file/) for full analysis.

**Format (indicative):**

```
# Progress: <Project Name>
# Created: <ISO date>
# Status: [ ] pending  [~] in progress  [x] complete  [-] skipped

## Gates

[x] Gate 0: Codebase Alignment          Approved: 2026-03-15  docs/codebase-assessment.md
[-] Gate WB: Working Backwards           Skipped                                            # or: [ ] Pending — offered, awaiting decision
[x] Gate 1: Scope Review                Approved: 2026-03-16  prd.md
[x] Gate 2: Design Review               Approved: 2026-03-17  docs/ARCHITECTURE_AND_DESIGN.md
[~] Gate 3: Milestone Review             In progress

## Milestones

[~] Milestone 01: Core Auth              milestones/01-core-auth/   2/3 features complete
[ ] Milestone 02: Dashboard              milestones/02-dashboard/   0/2 features complete

## Spikes

[x] Spike: WebSocket Auth Compatibility    docs/spikes/websocket-auth.md
    NOTES: Resolved 2026-03-17. Confirmed middleware supports upgrade.

[ ] Spike: SQLite to Postgres Migration    docs/spikes/sqlite-postgres-migration.md
    NOTES: Started 2026-03-20. Follow-up pending on connection pooling.
```

**Milestone summary rollup:** The feature count (e.g., "2/3 features complete") and milestone
status checkbox are updated by `/build` each time a feature is completed — this is a stored
value, not computed at read time. `/milestone` sets the initial count when milestones are
defined. `/project` validates consistency against milestone-level files on each invocation.

**Lifecycle:** Created by `/project` on first run (bootstrap — gate entries, no milestones).
Milestone summary lines added by `/milestone` when milestones are defined. Updated by
`/define`, `/design`, `/milestone`, and `/spike` as gates are passed and spikes are tracked.
`/build` updates the milestone summary (status and feature count) after each feature
completion. Read-only by `/project` after initial creation.

#### `milestones/<NN>-<name>/milestone-status.txt` — Milestone level

Milestone-level source of truth for feature status. Contains feature entries with plan paths,
sub-feature checklists, and notes. Only read by skills working on this specific milestone
(`/plan-feature`, `/build`, `/milestone` in revision mode).

**Format (indicative):**

```
# Milestone 01: Core Auth
# Status: [~] in progress

[x] Feature 01.1: User Registration
    Plan: milestones/01-core-auth/plans/user-registration.md
    - Registration endpoint with email validation
    - Password hashing and storage
    NOTES: Started 2026-03-18. Completed 2026-03-19.

[~] Feature 01.2: Session Management
    Plan: milestones/01-core-auth/plans/session-management.md
    - JWT token issuance and refresh
    - Session expiry handling
    NOTES: Started 2026-03-20.

[ ] Feature 01.3: Password Reset
    Plan: milestones/01-core-auth/plans/password-reset.md
    - Reset email flow
    - Token expiry validation
    NOTES:
```

**Lifecycle:** Created by `/milestone` when the milestone is defined (feature entries with
`[ ]` pending status). Updated by `/plan-feature` (adds plan paths, sub-feature lists) and `/build`
(updates feature status, sub-feature checklists, notes as work progresses). When `/build`
completes the last feature, it also updates the milestone summary line in the project-level
`progress.txt`.

**Recovery:** If a `milestone-status.txt` file is missing but the milestone directory and
README exist, `/milestone` or `/plan-feature` can recreate it from the milestone README's feature
list. Feature plans on disk provide plan paths. Git history provides completion status. As
with project-level `progress.txt`, git recovery is the primary mechanism.

**Sync contract:** The milestone-level file is the source of truth for feature status. The
project-level file contains only the rolled-up milestone status. `/project` validates
consistency between `progress.txt` and each milestone's `milestone-status.txt` on each
invocation and warns if they diverge.

### Artifact dependencies

Each artifact informs the next in gate order: codebase assessment → (Working Backwards) →
PRD → architecture doc → milestone READMEs → feature plans. The project-level `progress.txt`
tracks gate and milestone status; `milestone-status.txt` files track feature status.
See the document tree above for the full directory structure.

---

## Open Questions

> Full details in [OPEN_QUESTIONS.md](design-decisions/OPEN_QUESTIONS.md).

- **~~OQ-1:~~** RESOLVED — Plain text format. See [progress-file/](progress-file/) for analysis.
- **~~OQ-2:~~** RESOLVED — `create-prd` stays untouched. `/define` is forked from it, scoped to pipeline.
- **~~OQ-3:~~** RESOLVED — Three-level hierarchy (DD-1). Sub-features fit in 120k tokens, features are PR-sized, milestones are value increments.
- **~~OQ-4:~~** RESOLVED — No direct invocation. `/project` is the only entry point. Skipping happens within orchestration (e.g., skip Gate WB), not by bypassing it.
- **~~OQ-5:~~** RESOLVED — Assess at project start, refresh at each new feature, on-demand refresh available.
- **~~OQ-6:~~** RESOLVED — PRD is fixed-size strategic doc. Milestone detail lives in milestone READMEs. No archiving needed.
- **~~OQ-7:~~** RESOLVED — Each gate produces a review checklist to guide offline reviewers (DD-13).
- **~~OQ-8:~~** RESOLVED — Out of scope. Multi-user coordination handled by business processes and git.
