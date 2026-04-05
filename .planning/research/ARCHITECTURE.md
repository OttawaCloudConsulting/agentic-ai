# Architecture Patterns

**Domain:** Claude Code skills — gate-based AI-assisted development pipeline
**Project:** `/project` skill suite (7 components)
**Researched:** 2026-04-02
**Sources:** `skills/project/DESIGN.md` (primary), `skills/project/progress-file/` (format analysis), `skills/create-prd/SKILL.md` (reference skill)

---

## Skill Invocation and Routing Architecture

### How Claude Code Skills Are Invoked

Claude Code skills are Markdown files stored under `skills/<skill-name>/SKILL.md` (in this
repo). They are not auto-triggered. A user must invoke a skill explicitly by name (e.g.,
`/project`, `/define`, `/build`). The skill file's YAML front-matter declares its name,
description, and constraints:

```yaml
---
name: create-prd
description: Create a PRD ... Use when starting a new project ...
disable-model-invocation: true
---
```

The `disable-model-invocation: true` flag prevents Claude from auto-selecting the skill
based on conversation context. Every skill in the project suite should carry this flag.

When a skill is invoked:
1. Claude reads the SKILL.md file in full
2. The skill runs in the current conversation's context window
3. It reads whatever files are referenced (no automatic file ingestion — the skill
   instructions tell Claude what to read)

### How `/project` Routes

`/project` is a **stateless, read-only router**. It does not advance the pipeline. It reads
the current state from `progress.txt` and tells the user which skill to invoke next.

Routing logic (simplified):

```
On invocation:
  1. Check if progress.txt exists
     - No  → bootstrap (write initial progress.txt with gate entries, no milestones)
     - Yes → read it
  2. Validate artifact paths for approved gates exist on disk
     - Missing artifacts → warn user, do not block
  3. Validate consistency between progress.txt milestone summaries and each
     milestones/<NN>-<name>/milestone-status.txt
     - Divergence → warn user, do not block
  4. Report current state and direct user to next skill:
     - Gates 0/WB/1 incomplete → invoke /define
     - Gate 2 incomplete       → invoke /design
     - Gate 3 incomplete       → invoke /milestone
     - Gate 4 incomplete       → invoke /plan (for specific feature)
     - Gate 4 approved         → invoke /build (for specific feature)
     - Re-planning needed      → invoke /milestone or /define (revision mode)
     - Technical uncertainty   → offer /spike
```

The routing message to the user names the exact slash command to run. The user types it in
a new conversation (new context window). `/project` never calls other skills as sub-agents
— routing is an instruction to the human, not an automated dispatch.

### Context Isolation Mechanism

The design calls for "clean context window per skill" (DESIGN.md DD-2). In Claude Code, this
is achieved by the **user starting a fresh conversation** after `/project` tells them what to
invoke next. There is no `/clear`-within-conversation mechanism used here — each phase skill
is meant to run in a genuinely new conversation, not a cleared one.

The rationale is token budget. A `/define` session involves extensive back-and-forth
interviews. Carrying that token weight into `/design` or `/milestone` would degrade output
quality as the context fills.

**Exception:** `/define` runs Gates 0, WB, and 1 as a single continuous session. These three
internal checkpoints are tightly coupled — the codebase understanding feeds directly into
Working Backwards, which feeds directly into the PRD interview. Splitting them would force
re-ingestion of context just established.

**File artifacts as context transfer:** Each phase skill reads specific files at start-up to
reconstruct the context it needs. This is cheaper than carrying the full conversation history.
A milestone-scoped PRD keeps re-ingestion cost manageable — the PRD stays small by design.

---

## Component Map

| Component | Gate(s) | Context Scope | Entry Point |
|-----------|---------|---------------|-------------|
| `/project` | — (router) | Always new conversation | User invokes to check status |
| `/define` | 0, WB, 1 | Single continuous session | User invokes after `/project` directs |
| `/design` | 2 | New conversation per invocation | User invokes after `/project` directs |
| `/milestone` | 3 | New conversation per invocation | User invokes per milestone |
| `/plan` | 4 | New conversation per invocation | User invokes per feature |
| `/spike` | — (research) | New conversation per invocation | User invokes on demand |
| `/build` | — (impl) | New conversation per sub-feature | User invokes per sub-feature |

---

## Complete Data Flow

### Normal Flow (Greenfield Project)

```
User runs /project
  └─► No progress.txt found
      └─► /project bootstraps progress.txt (gate entries, no milestones)
          └─► /project tells user: "invoke /define"

User runs /define (new conversation)
  Reads:  (empty codebase — Gate 0 skipped)
  ├─► Gate WB (optional): offers Working Backwards
  │     Writes: docs/working-backwards.md
  │             docs/reviews/gate-wb-review.md
  │             progress.txt (Gate WB status)
  ├─► Gate 1: PRD interview
  │     Writes: prd.md
  │             docs/reviews/gate-1-review.md
  │             progress.txt (Gate 1 approval + timestamp)
  └─► Session ends

User runs /project (new conversation)
  Reads:  progress.txt
  └─► Gates 0+WB+1 complete, Gate 2 pending
      └─► tells user: "invoke /design"

User runs /design (new conversation)
  Reads:  prd.md, progress.txt
  ├─► Architecture interview
  │     Writes: docs/ARCHITECTURE_AND_DESIGN.md
  │             docs/reviews/gate-2-review.md
  │             progress.txt (Gate 2 approval + timestamp)
  └─► Session ends

User runs /project (new conversation)
  Reads:  progress.txt
  └─► Gates 0–2 complete, Gate 3 pending
      └─► tells user: "invoke /milestone"

User runs /milestone (new conversation)
  Reads:  prd.md, docs/ARCHITECTURE_AND_DESIGN.md, progress.txt
  ├─► Milestone breakdown interview
  │     Writes: milestones/01-<name>/README.md
  │             milestones/01-<name>/milestone-status.txt  (features [ ] pending)
  │             milestones/01-<name>/reviews/gate-3-review.md
  │             progress.txt (Gate 3 approval, milestone summary lines)
  └─► Session ends  (repeat for each milestone)

User runs /project (new conversation)
  Reads:  progress.txt, milestones/*/milestone-status.txt (consistency check)
  └─► Gate 3 complete for Milestone 01, Gate 4 pending for Feature 01.1
      └─► tells user: "invoke /plan for Feature 01.1"

User runs /plan (new conversation)
  Reads:  milestones/01-<name>/README.md, prd.md,
          docs/ARCHITECTURE_AND_DESIGN.md, progress.txt,
          milestones/01-<name>/milestone-status.txt
  ├─► Feature plan interview
  │     Writes: milestones/01-<name>/plans/<feature>.md
  │             milestones/01-<name>/reviews/gate-4-<feature>-review.md
  │             milestones/01-<name>/milestone-status.txt (adds plan path)
  └─► Session ends  (repeat for each feature)

User runs /build (new conversation, per sub-feature)
  Reads:  milestones/01-<name>/plans/<feature>.md
          docs/codebase-assessment.md (refreshed at start)
          progress.txt
          milestones/01-<name>/milestone-status.txt
          docs/ARCHITECTURE_AND_DESIGN.md
  ├─► Implements sub-feature(s), runs test command
  │     Writes: [codebase files]
  │             docs/codebase-assessment.md  (refreshed)
  │             feature plan (sub-feature checklist ticks, deviation records)
  │             milestones/01-<name>/milestone-status.txt (feature status, notes)
  │             progress.txt (milestone summary rollup on feature completion)
  └─► Session ends
```

### Brownfield Project Variant (Existing Codebase)

Same flow, but `/define` fires Gate 0 before Gate WB/1:

```
User runs /define (existing codebase detected)
  ├─► Gate 0: Codebase scan
  │     Writes: docs/codebase-assessment.md
  │             docs/reviews/gate-0-review.md
  │             progress.txt (Gate 0 approval)
  ├─► Gate WB (offered): Working Backwards
  │     ...same as greenfield...
  └─► Gate 1: PRD interview (codebase assessment feeds in)
        ...same as greenfield...
```

### Re-Planning Flows

**Milestone re-planning** (requirements change within a milestone):

```
User tells /project: "need to re-plan Milestone 02"
  └─► /project routes to /milestone (revision mode)

User runs /milestone (new conversation, revision mode)
  Reads:  existing milestones/02-<name>/README.md,
          milestones/02-<name>/milestone-status.txt,
          prd.md, progress.txt
  ├─► Offers to revise rather than overwrite
  ├─► Identifies affected features → resets only those to "planned" status
  ├─► User confirms reset list before it takes effect
  │     Writes: milestones/02-<name>/README.md (revised)
  │             milestones/02-<name>/milestone-status.txt (affected features reset)
  │             prd.md (milestone summary line updated)
  │             progress.txt (milestone summary rollup updated)
  └─► Session ends
```

**PRD revision** (project-level goals changed):

```
User tells /project: "goals have changed"
  └─► /project routes to /define (revision mode)

User runs /define (new conversation, revision mode)
  Reads:  prd.md, progress.txt
  ├─► Focused interview on what changed (not full restart)
  │     Writes: prd.md (revised)
  │             progress.txt (updated)
  └─► Downstream artifacts NOT automatically reset
      User decides which downstream artifacts need re-review
      (no automatic cascade)
```

---

## Progress File Schemas

### Project-Level `progress.txt` Schema

**Location:** `<project-root>/progress.txt`

**Format:** Extended plain text (chosen over YAML — see `skills/project/progress-file/`
for full analysis). Rationale: human-editable, LLM write-safe, token-efficient, tolerant of
minor formatting errors, backward-compatible with existing `create-prd` conventions.

**Status symbols:**
```
[ ]  pending (not started)
[~]  in progress
[x]  complete / approved
[-]  skipped / N/A
```

**Full schema:**

```
# Progress: <Project Name>
# Created: <ISO date>
# Status: [ ] pending  [~] in progress  [x] complete  [-] skipped

## Gates

[x] Gate 0: Codebase Alignment          Approved: <ISO date>  docs/codebase-assessment.md
[-] Gate WB: Working Backwards           Skipped
    # Alternate states:
    # [ ] Gate WB: Working Backwards     Pending — offered, awaiting decision
    # [x] Gate WB: Working Backwards     Approved: <ISO date>  docs/working-backwards.md
[x] Gate 1: Scope Review                Approved: <ISO date>  prd.md
[x] Gate 2: Design Review               Approved: <ISO date>  docs/ARCHITECTURE_AND_DESIGN.md
[~] Gate 3: Milestone Review             In progress
    # Per-milestone entries:
    [x] Gate 3: Milestone 01 — Core Auth  Approved: <ISO date>
    [ ] Gate 3: Milestone 02 — Dashboard  Pending
[~] Gate 4: Feature Plans
    # Per-feature entries:
    [x] Gate 4: Feature 01.1 — User Registration  Approved: <ISO date>
    [~] Gate 4: Feature 01.2 — Session Mgmt       In progress
    [ ] Gate 4: Feature 01.3 — Password Reset      Pending

## Milestones

[~] Milestone 01: Core Auth              milestones/01-core-auth/    2/3 features complete
[ ] Milestone 02: Dashboard              milestones/02-dashboard/    0/2 features complete

## Spikes

[x] Spike: WebSocket Auth Compatibility  docs/spikes/websocket-auth.md
    NOTES: Resolved <ISO date>. Confirmed middleware supports upgrade.
[ ] Spike: SQLite to Postgres Migration  docs/spikes/sqlite-postgres-migration.md
    NOTES: Started <ISO date>. Follow-up pending on connection pooling.
```

**Invariants:**
- The file is bootstrapped by `/project` on first run (gate entries, empty Milestones section,
  empty Spikes section)
- Gate entries record the artifact path when approved so `/project` can validate existence
- Gate WB must be `[x]` or `[-]` before Gate 1 can begin (cannot remain `[ ] Pending`)
- Milestone summary lines record stored rollup counts, not computed at read time
- `/project` is the only writer during bootstrap; all other writes are by phase skills
- After bootstrap, `/project` is strictly read-only

**Who writes what:**

| Field | Written by |
|-------|-----------|
| Initial gate entries | `/project` (bootstrap only) |
| Gate 0 approval line | `/define` |
| Gate WB status | `/define` |
| Gate 1 approval line | `/define` |
| Gate 2 approval line | `/design` |
| Gate 3 per-milestone lines | `/milestone` |
| Gate 4 per-feature lines | `/plan` |
| Milestone summary lines | `/milestone` (creation), `/build` (rollup on completion) |
| Spike entries | `/spike` |

---

### Milestone-Level `milestone-status.txt` Schema

**Location:** `milestones/<NN>-<name>/milestone-status.txt`

**Purpose:** Feature-level detail for one milestone. Keeps the project-level `progress.txt`
small and stable regardless of milestone complexity.

**Full schema:**

```
# Milestone <NN>: <Name>
# Status: [~] in progress

[x] Feature <NN>.<N>: <Feature Title>
    Plan: milestones/<NN>-<name>/plans/<feature-slug>.md
    - <Key deliverable from acceptance criteria>
    - <Key deliverable from acceptance criteria>
    - <Key deliverable from acceptance criteria>
    Sub-features:
      [x] <Sub-feature 1 description>
      [x] <Sub-feature 2 description>
      [ ] <Sub-feature 3 description>
    NOTES: <Free-form: start date, completion date, blockers, cross-refs>

[~] Feature <NN>.<N>: <Feature Title>
    Plan: milestones/<NN>-<name>/plans/<feature-slug>.md
    - <Key deliverable>
    - <Key deliverable>
    Sub-features:
      [x] <Sub-feature 1 description>
      [ ] <Sub-feature 2 description>
    NOTES: Started <ISO date>. <Any blocking context.>

[ ] Feature <NN>.<N>: <Feature Title>
    Plan:
    - <Key deliverable>
    - <Key deliverable>
    Sub-features:
    NOTES:
```

**Notes on sub-features:**
- Sub-features are added by `/plan` when the feature plan is created
- Each sub-feature must leave the codebase in a committable state
- A sub-feature that requires the next sub-feature to avoid a broken build is too small and
  should be merged with its dependent
- Sub-feature sizing target: completable within 60% of a 200k-token context window (~120k
  tokens) in a single `/build` session
- `/build` ticks sub-feature checkboxes as it completes each one

**Feature status values:**

| Symbol | Status | Set by |
|--------|--------|--------|
| `[ ]` | pending — plan not yet created | `/milestone` (creation) |
| `[ ]` | planned — Plan path populated | `/plan` (after plan approval) |
| `[~]` | in-progress — `/build` started | `/build` |
| `[x]` | complete — test command passed | `/build` |
| `[-]` | skipped | User (manual edit) or `/milestone` (re-planning) |

**Note:** Both "pending" and "planned" use `[ ]`. The distinction is whether the Plan field
has a path. The Plan line reads `Plan:` with no path until `/plan` fills it in.

**Who writes what:**

| Field | Written by |
|-------|-----------|
| Feature entries (initial, all `[ ]`) | `/milestone` |
| Plan path | `/plan` |
| Sub-feature checklist items | `/plan` |
| Feature status `[ ]` → `[~]` | `/build` |
| Sub-feature checkbox ticks | `/build` |
| Feature status `[~]` → `[x]` | `/build` |
| NOTES content | `/build` (progress notes), user (manual) |
| Milestone header status | `/milestone` (creation), `/build` (on completion) |

---

## Skill Directory Organization

### How Skills Are Organized in This Repo

Skills live under `skills/<skill-name>/` with one SKILL.md per skill. The `create-prd` skill
is the reference pattern:

```
skills/create-prd/
├── SKILL.md          — The skill itself (front-matter + instructions)
├── assets/           — Template files the skill reads (prd-template.md, etc.)
├── references/       — Reference guides the skill reads (interview-guide.md, etc.)
└── review/           — Review or audit materials
```

### How the Project Skill Suite Is Organized

The project skill suite lives entirely under `skills/project/`:

```
skills/project/
├── DESIGN.md                 — Design decisions (this document's source)
├── progress-file/            — Research on progress.txt format (REQUIREMENTS, TEXT vs YAML, etc.)
└── design-decisions/         — Open questions and review findings
```

At time of research, the individual skill files (`SKILL.md` for `/project`, `/define`, etc.)
have not yet been written. Based on the `create-prd` reference pattern, each skill in the
suite should follow one of two structural options:

**Option A — Flat (one SKILL.md per skill, all in `skills/project/`):**
```
skills/project/
├── project.md        — /project router skill
├── define.md         — /define skill
├── design.md         — /design skill
├── milestone.md      — /milestone skill
├── plan.md           — /plan skill
├── spike.md          — /spike skill
├── build.md          — /build skill
├── assets/           — Shared templates
└── references/       — Shared reference guides
```

**Option B — Subdirectory per skill (mirrors create-prd pattern):**
```
skills/project/
├── project/          — /project router
│   └── SKILL.md
├── define/           — /define skill
│   ├── SKILL.md
│   ├── assets/
│   └── references/
├── design/
│   └── SKILL.md
...
```

**Recommendation based on codebase evidence:** The `create-prd` skill has its own assets and
references directories — each skill is self-contained. For skills that share reference material
(e.g., all skills read `progress.txt` format conventions), Option B with a shared `references/`
at the `skills/project/` level is the cleanest structure. Skills that need private assets get
their own `assets/` subdirectory.

### How Skills Are Installed/Accessed by End Users

Skills in `skills/` are **templates**, not runtime components. A user who wants to use a skill
must copy it into their project's `.claude/` directory or reference it through the repo's
`.claude/commands/` convention.

Looking at the existing command pattern in `.claude/commands/gsd/new-project.md`:

```yaml
---
name: gsd:new-project
description: Initialize a new project with deep context gathering and PROJECT.md
---
```

Commands use YAML front-matter with a `name:` field. When installed, they become invocable as
`/gsd:new-project`. The project skill suite would similarly need commands in `.claude/commands/`
that reference the skill files:

```
.claude/commands/
├── project.md   → wraps skills/project/project/SKILL.md (or inline)
├── define.md    → wraps skills/project/define/SKILL.md
├── design.md    → wraps skills/project/design/SKILL.md
...
```

**Key constraint from the `create-prd` reference:** The `occ-skill-creator` and
`occ-skill-refactor` skills (`skills/occ-skill-creator/`, `skills/occ-skill-refactor/`)
use the same `SKILL.md` + `references/` + `review/` pattern. This is the established repo
convention: each skill is a self-contained directory with SKILL.md as the entry point.

---

## Component Boundaries and Contracts

### Narrow Contracts

Each skill has an explicitly narrow contract: read specific inputs, produce specific outputs,
update specific state. This is the key architectural constraint from DESIGN.md DD-4.

| Skill | Reads | Writes | Must NOT |
|-------|-------|--------|----------|
| `/project` | progress.txt, milestone-status.txt (validation) | progress.txt (bootstrap only) | Advance state, invoke other skills |
| `/define` | codebase, progress.txt | codebase-assessment.md, working-backwards.md, prd.md, reviews, progress.txt | Skip gate review |
| `/design` | prd.md, codebase-assessment.md, progress.txt | ARCHITECTURE_AND_DESIGN.md, gate-2-review.md, progress.txt | Modify prd.md |
| `/milestone` | prd.md, ARCHITECTURE_AND_DESIGN.md, progress.txt, spikes | milestone README, milestone-status.txt, gate-3-review.md, progress.txt | Modify ARCHITECTURE_AND_DESIGN.md |
| `/plan` | milestone README, prd.md, ARCHITECTURE_AND_DESIGN.md, milestone-status.txt, spikes | feature plan, gate-4-review.md, milestone-status.txt | Modify milestone README |
| `/spike` | user question, available tooling, progress.txt | docs/spikes/<topic>.md, progress.txt | Block the pipeline |
| `/build` | feature plan, codebase, codebase-assessment.md, milestone-status.txt, ARCHITECTURE_AND_DESIGN.md | codebase, codebase-assessment.md, feature plan (sub-feature ticks, deviations), milestone-status.txt, progress.txt | Approve gates, modify plans beyond allowed fields |

### Gate Approval Contract

Gates are recorded in `progress.txt` with a timestamp and artifact path. Rules:

1. The skill presents output, then pauses — it never auto-advances
2. Rejection means revise in-session, not discard and restart
3. Approval requires explicit user confirmation ("approved" or equivalent)
4. Before recording approval, the skill validates the gate's review checklist is fully
   resolved (all items `[x]` or `[-]` with reason)
5. Gate WB must reach `[x]` or `[-]` before Gate 1 can begin
6. No implicit approval — silence or continuation is not approval

---

## Scalability Considerations

The two-tier state file design (project-level `progress.txt` + per-milestone
`milestone-status.txt`) is the key architectural decision enabling scale:

| Concern | How Addressed |
|---------|---------------|
| Context window budget | `progress.txt` stays small (milestone summaries only, not feature detail). Only the active milestone's `milestone-status.txt` is loaded per session. |
| Large project (many milestones) | Each milestone is isolated. `/project` reads only summary lines. Feature detail never enters project-level state. |
| Team handoffs | All state is file-based, version-controlled. No conversation memory dependencies. |
| Session gaps (days/weeks) | Any skill reconstructs complete context from files alone. |
| Re-planning | Milestone re-planning resets only affected features. PRD revision has no automatic cascade. |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Skills Calling Each Other as Sub-Agents

The design is explicit: `/project` tells the human what to run next. It does not dispatch
to `/define` as a sub-agent. Each skill runs in its own conversation started by the user.

**Why bad:** Sub-agent calls accumulate token context from the calling session, defeating the
purpose of context isolation.

**Instead:** `/project` outputs a plain instruction to the user ("invoke /define"). The user
opens a new conversation.

### Anti-Pattern 2: Sharing State Through Variables or Memory

No skill passes data to another skill through any mechanism other than files on disk.

**Why bad:** In-memory state, conversation continuations, and session variables do not
survive `clear`, session gaps, or machine switches.

**Instead:** Files on disk. Every skill re-reads from scratch.

### Anti-Pattern 3: Auto-Advancing Gates

No skill advances to the next gate automatically after producing an artifact.

**Why bad:** Removes the human review point. The AI optimizes for completion, not correctness.

**Instead:** The skill presents output, then explicitly asks for approval. It waits.

### Anti-Pattern 4: Monolithic Progress File

Keeping all feature detail (sub-feature checklists, notes, plan paths) in `progress.txt`.

**Why bad:** The file grows without bound. Every skill on every invocation reads the entire
file, burning context budget on irrelevant milestone detail.

**Instead:** `progress.txt` has milestone summary lines only (one line per milestone).
Feature detail lives in `milestone-status.txt`, read only by skills working on that milestone.

### Anti-Pattern 5: Cascade Resets on PRD Revision

Automatically resetting all downstream gates when the PRD is revised.

**Why bad:** Destroys valid work. A PRD change that affects feature scope in Milestone 02
does not necessarily invalidate the already-approved design in Milestone 01.

**Instead:** PRD revision routes to `/define` in revision mode. The user decides which
downstream artifacts need re-review. No automatic cascade.
