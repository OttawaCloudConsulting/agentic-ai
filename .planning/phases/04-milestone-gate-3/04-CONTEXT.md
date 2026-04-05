# Phase 4: /milestone (Gate 3) - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Breaks an approved PRD and architecture doc into milestone-scoped feature breakdowns with acceptance criteria, ordering, and sizing. Supports revision mode for in-flight scope changes. Delivers one complete, invokable skill at `skills/project/milestone/SKILL.md`.

</domain>

<decisions>
## Implementation Decisions

### Milestone generation
- **D-01:** Analyze and propose — Claude reads PRD + architecture doc, proposes full milestone breakdown, user reviews/revises. Consistent with produce-then-review pattern from prior phases.
- **D-02:** Direct reading of inputs — no sub-agent needed. Inputs are focused docs (PRD, architecture), not a sprawling codebase.
- **D-03:** Tradeoff callouts before approval checklist — call out 2-3 key grouping/ordering decisions before the approval flow. Consistent with /design Phase 3 D-09.
- **D-04:** Spike artifacts user-referenced only — don't auto-detect spike docs from PRD. User cites relevant spikes explicitly.

### Gate 3 closure
- **D-05:** /project detects closure — /project offers to close Gate 3 when milestones exist with approved reviews. User explicitly confirms. Keeps /project as routing authority, maintains HITL principle.
- **D-06:** Closure checks — milestones exist AND each has a completed `gate-3-review.md`. Ensures every milestone was reviewed before gate closes.

### Scope discovery
- **D-07:** Propose all, define one — first invocation proposes milestone plan (count, summaries, order). User approves overall plan. Then Claude generates detailed README for milestone #1. Subsequent invocations auto-select the next undefined milestone.
- **D-08:** Milestone plan persisted in `prd.md` Milestones section — natural home alongside requirements.
- **D-09:** Auto-select next undefined milestone on subsequent invocations. User can override to target a specific milestone.

### Revision mode UX
- **D-10:** Auto-detect revision mode — if milestone directory already exists, enter revision mode automatically. No flag needed.
- **D-11:** Feature checklist with multiSelect for affected features — show all features with current status, user selects which are affected by scope change. Selected features reset to `[ ] pending`, completed features preserved.
- **D-12:** Load and revise existing README — read existing content, ask what changed, revise only affected sections. Consistent with /define revision mode Phase 2 D-15.
- **D-13:** Fresh `gate-3-review.md` after revision — prior review is no longer valid after milestone changes.

### Claude's Discretion
- Milestone grouping heuristics and ordering rationale
- Feature sizing estimation approach within DD-1 constraints
- Exact phrasing of approval prompts and tradeoff callouts
- How to handle edge cases when PRD has ambiguous feature boundaries
- Review checklist item generation from milestone contents
- Detection of "key tradeoffs" worth calling out in grouping/ordering
- README format and section structure for individual milestones

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design decisions
- `skills/project/DESIGN.md` — All 13 design decisions (DD-1 through DD-13); authoritative source for gate behavior, state formats, artifact paths
- `skills/project/DESIGN.md` §DD-1 — Three-level hierarchy: Milestone > Feature > Sub-Feature; 2-5 features per milestone; sub-features fit 60% context window
- `skills/project/DESIGN.md` §DD-4 — Gate mapping; Gate 3 = milestone planning
- `skills/project/DESIGN.md` §DD-6 — Re-planning: milestone re-planning via `/milestone` in revision mode
- `skills/project/DESIGN.md` §DD-7 — HITL principle: every gate requires explicit human approval
- `skills/project/DESIGN.md` §DD-8 — Gate reviews adapt to phase context (Gate 3: scope completeness, feature sizing, ordering rationale)
- `skills/project/DESIGN.md` §DD-13 — Gate 3 review checklist items

### Requirements
- `.planning/REQUIREMENTS.md` MIL-01 through MIL-13

### Predecessor skill patterns
- `skills/project/define/SKILL.md` — Flow controller pattern (reads references at appropriate steps)
- `skills/project/design/SKILL.md` — Flow controller pattern with agent-based scanning
- `skills/project/define/references/` — Reference file organization pattern
- `skills/project/define/references/review-checklist-template.md` — Reusable review checklist template pattern

### State file formats
- `skills/project/references/progress-format.md` — Progress.txt format spec (to be copied into milestone/references/)

### Codebase conventions
- `.planning/codebase/CONVENTIONS.md` — SKILL.md frontmatter, naming patterns, documentation requirements
- `.planning/codebase/STRUCTURE.md` — Directory layout, skill bundle structure, key locations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/project/define/SKILL.md` — Flow controller pattern (~200 lines) loading gate references; structural model for `/milestone`'s SKILL.md
- `skills/project/define/references/gate-1-prd.md` — Gate spec reference pattern with generation/review flow
- `skills/project/define/assets/prd-template.md` — Template asset pattern; `prd.md` Milestones section is where milestone plan persists
- `skills/project/define/references/review-checklist-template.md` — Reusable review checklist template pattern
- `skills/project/references/progress-format.md` — Progress.txt format to copy into milestone/references/

### Established Patterns
- SKILL.md uses numbered steps with clear action verbs
- `AskUserQuestion` for interactive prompts (2-4 options, max 12-char headers)
- `disable-model-invocation: true` mandatory in frontmatter
- Reference loading: SKILL.md reads external spec files at the step that needs them (not all upfront)
- Produce-then-review: generate artifact, present, Approve/Revise loop
- Section-by-section partial approval via multiSelect checklist
- Auto-generated review checklists with completeness validation

### Integration Points
- `progress.txt` at project root — `/milestone` reads for Gate 2 validation, writes Gate 3 approval per milestone
- `prd.md` at project root — primary input (produced by `/define`), also receives Milestones section
- `docs/ARCHITECTURE_AND_DESIGN.md` — secondary input (produced by `/design` Gate 2)
- `milestones/<name>/README.md` — primary output per milestone
- `docs/reviews/gate-3-review.md` (per milestone) — review checklist output
- `milestone-status.txt` (per milestone) — initialized on milestone definition

</code_context>

<specifics>
## Specific Ideas

- Directory structure mirrors /define and /design: `skills/project/milestone/` with `references/` and `assets/`
- Two-phase flow: first invocation proposes overall milestone plan, subsequent invocations define individual milestones
- Revision mode auto-detected by existing milestone directory, presents feature checklist for selective reset
- Gate 3 closure is detected by /project, not by /milestone itself

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-milestone-gate-3*
*Context gathered: 2026-04-02*
