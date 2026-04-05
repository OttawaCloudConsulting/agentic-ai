# Phase 3: /design (Gate 2) - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Produces `docs/ARCHITECTURE_AND_DESIGN.md` from an approved PRD and codebase assessment, with in-session revision before gate approval. Supports refresh mode to consolidate accumulated architectural deviations from feature plans. This phase delivers one complete, invokable skill at `skills/project/design/SKILL.md`.

</domain>

<decisions>
## Implementation Decisions

### SKILL.md decomposition
- **D-01:** Reference file pattern — SKILL.md as flow controller (~150 lines) loading external reference files. Consistent with Phase 2's `/define` approach.
- **D-02:** Directory structure: `skills/project/design/` with `references/` (gate-2-design.md, refresh-mode.md, progress-format.md, review-checklist-template.md) and `assets/` (architecture-template.md).
- **D-03:** Own copy of `progress-format.md` — no cross-directory reads between skills (carries forward Phase 2 D-04).

### Architecture template
- **D-04:** `architecture-template.md` matches DESIGN.md exactly — 6 sections: Design Decisions (numbered table with decision/rationale/tradeoff/alternatives columns), Component Inventory, Data Flow, File Organization, Deployment & Operations, Security Considerations.

### Architecture generation method
- **D-05:** Agent-based deep codebase scan — spawn a sub-agent that reads 15-30 files through an architecture lens (component boundaries, data flow patterns, interface contracts, tech choices). Synthesize agent findings + PRD into the architecture doc.
- **D-06:** Always spawn the architecture agent, even on greenfield projects where `docs/codebase-assessment.md` doesn't exist. Scan whatever exists (boilerplate, configs, dependencies) to inform architecture decisions.
- **D-07:** Primary inputs always read: `prd.md`, `docs/codebase-assessment.md` (if exists), `progress.txt` (for gate validation).

### Design review UX
- **D-08:** Section-by-section partial approval — same pattern as Gate 1 PRD. Present full doc, then multiSelect checklist of 6 sections. User checks approved sections; unchecked get focused revision with "What should change?" prompt.
- **D-09:** Tradeoff callouts — after presenting the full doc, call out 2-4 design decisions with the most significant tradeoffs before the approval checklist. Draws attention without forcing a separate review round.
- **D-10:** Produce-then-review pattern — Claude produces full artifact, presents it, offers Approve/Revise. Revision happens in-session without restart (carries forward Phase 2 D-06).
- **D-11:** Review checklists auto-generated, all items must be `[x]` or `[-]` (N/A with reason) before gate approval is recorded (carries forward Phase 2 D-07).

### Refresh mode
- **D-12:** Per-deviation review — scan all `milestones/*/plans/*.md` for Architectural Deviations sections. Present each deviation with its original design decision and reason for change. User confirms which deviations to consolidate via multiSelect.
- **D-13:** After consolidation, present updated `ARCHITECTURE_AND_DESIGN.md` for approval using the same section-by-section review flow.
- **D-14:** When zero deviations found, report "No architectural deviations found. Architecture doc is current." and exit cleanly. No revision offer.

### Claude's Discretion
- Architecture agent prompt and file selection heuristics (architecture-focused, not convention-focused like Gate 0)
- Exact phrasing of gate approval prompts and tradeoff callouts
- How to handle edge cases in greenfield agent scanning (minimal files available)
- Progress.txt write format and recording details
- Review checklist item generation from architecture doc contents
- How to detect which design decisions are "key tradeoffs" worth calling out

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design decisions
- `skills/project/DESIGN.md` — All 13 design decisions (DD-1 through DD-13); authoritative source for gate behavior, state formats, artifact paths
- `skills/project/DESIGN.md` §DD-2 — Context isolation between phases; `/design` runs in its own session
- `skills/project/DESIGN.md` §DD-7 — Gate review behaviors and rules (checklist completeness required before approval)
- `skills/project/DESIGN.md` §DD-8 — Gate reviews adapt to phase context (Gate 2: feasibility, tech fit, completeness)
- `skills/project/DESIGN.md` §DD-13 — Gate 2 review checklist items

### Architecture document specification
- `skills/project/DESIGN.md` §`docs/ARCHITECTURE_AND_DESIGN.md (Gate 2)` — Required sections, lifecycle, refresh behavior

### Requirements
- `.planning/REQUIREMENTS.md` §Design — DES-01 through DES-08

### Predecessor skill patterns
- `skills/project/define/SKILL.md` — Flow controller pattern (reads references at appropriate steps)
- `skills/project/define/references/` — Reference file organization pattern
- `skills/project/define/assets/prd-template.md` — Template asset pattern to follow for architecture-template.md

### State file formats
- `skills/project/references/progress-format.md` — Progress.txt format spec (to be copied into design/references/)

### Codebase conventions
- `.planning/codebase/CONVENTIONS.md` — SKILL.md frontmatter, naming patterns, documentation requirements
- `.planning/codebase/STRUCTURE.md` — Directory layout, skill bundle structure, key locations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/project/define/SKILL.md` — Flow controller pattern (~200 lines) loading gate references; direct structural model for `/design`'s SKILL.md
- `skills/project/define/references/gate-1-prd.md` — Gate spec reference pattern with interview/generation/review flow
- `skills/project/define/assets/prd-template.md` — Template asset pattern for output document structure
- `skills/project/define/references/review-checklist-template.md` — Reusable review checklist template pattern
- `skills/project/references/progress-format.md` — Progress.txt format to copy into design/references/

### Established Patterns
- SKILL.md uses numbered steps with clear action verbs
- `AskUserQuestion` for interactive prompts (2-4 options, max 12-char headers)
- `disable-model-invocation: true` mandatory in frontmatter
- Reference loading: SKILL.md reads external spec files at the step that needs them (not all upfront)
- Produce-then-review: generate artifact → present → Approve/Revise loop
- Section-by-section partial approval via multiSelect checklist
- Sub-agent for codebase scanning (Gate 0 precedent)

### Integration Points
- `progress.txt` at project root — `/design` reads for Gate 1 validation, writes Gate 2 approval
- `prd.md` at project root — primary input (produced by `/define` Gate 1)
- `docs/codebase-assessment.md` — secondary input (produced by `/define` Gate 0, may not exist for greenfield)
- `docs/ARCHITECTURE_AND_DESIGN.md` — primary output, consumed by `/milestone` and `/plan`
- `docs/reviews/gate-2-review.md` — review checklist output
- `milestones/*/plans/*.md` — read in refresh mode for Architectural Deviations sections

</code_context>

<specifics>
## Specific Ideas

- Directory structure mirrors /define: `skills/project/design/` with self-contained `references/` and `assets/`
- Architecture agent focuses on architecture-relevant patterns (component boundaries, data flow, interfaces) — distinct from Gate 0's convention-focused scan
- Tradeoff callouts are a brief highlight before the approval checklist, not a separate review round
- Refresh mode scans feature plans for deviations and presents them per-deviation, not as a batch

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-design-gate-2*
*Context gathered: 2026-04-02*
