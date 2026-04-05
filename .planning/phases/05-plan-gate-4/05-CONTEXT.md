# Phase 5: /plan (Gate 4) - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Produces per-feature implementation plans with sub-feature breakdown, sizing validation, interface contracts, and test commands. One invocation plans one feature. Gate 4 approval updates `milestone-status.txt` from `[ ]` to `[~] planned, awaiting build`. Supports re-plan mode for already-planned features. Delivers one complete, invokable skill at `skills/project/plan/SKILL.md`.

</domain>

<decisions>
## Implementation Decisions

### Feature targeting
- **D-01:** Auto-select next unplanned feature — read `milestone-status.txt`, find first feature at `[ ]` pending or needs-replanning status. User can override with explicit feature name argument.
- **D-02:** Auto-detect active milestone — read `progress.txt` for the first milestone at `[ ]` or `[~]` status. User can override with explicit milestone name/number.
- **D-03:** When no plannable features remain, report and exit cleanly — "All features in milestone X are planned or complete. Run /project to check status."
- **D-04:** Auto-detect re-plan mode — if target feature already has a plan file, enter re-plan mode automatically (consistent with /milestone D-10).
- **D-05:** Re-plan uses diff-focused revision — read existing plan, ask "What changed?", revise only affected sections. Fresh review checklist after revision. Consistent with /define D-15 and /milestone D-12.

### Sub-feature sizing
- **D-06:** Heuristic estimation — Claude estimates sub-feature complexity based on files to touch, logic scope, and integration surface. No hard metric; it's a judgment call against the ~120k-token guideline (DD-1).
- **D-07:** Oversized sub-features get inline split proposals — flag the sub-feature, propose 2-3 smaller items, present revised plan. User approves or adjusts the split during review.

### Plan content scope
- **D-08:** Test command: Claude proposes based on feature scope and existing test patterns, user confirms during review. Per DD-12, user can adjust mid-build without gate re-approval.
- **D-09:** Interface contracts at signatures + shapes depth — function/method signatures, data shapes (types/schemas), event formats. Enough for /build to implement without guessing interfaces.
- **D-10:** Targeted codebase scan via sub-agent — spawn a sub-agent to read files relevant to the feature being planned. Informs approach, files to modify, and integration points. Consistent with /design D-05.
- **D-11:** Spike artifacts user-referenced only — /plan reads spike docs only when user explicitly references them. No auto-detection. Consistent with /milestone Phase 4 D-04.

### Review & approval UX
- **D-12:** Whole-plan approve/revise — present full plan, offer Approve / Revise. If Revise, ask what should change, fix, re-present. Simpler than section-by-section since plans are single-feature scope.
- **D-13:** 1-2 tradeoff callouts before approval prompt — highlight the most significant approach/sizing decisions. Lighter than /design (2-4 callouts) since plans are narrower in scope.
- **D-14:** After Gate 4 approval, offer to plan the next feature — "Feature X planned. Next unplanned feature: Y. Plan it now?" User can continue or exit. Streamlines multi-feature planning sessions.

### Claude's Discretion
- Plan generation approach and section ordering
- Sub-agent prompt and file selection heuristics for codebase scan
- Exact sub-feature granularity within sizing guidelines
- Edge case identification depth
- Documentation section content
- Exact phrasing of approval prompts and tradeoff callouts
- How to detect "key tradeoffs" worth calling out
- Review checklist item generation from plan contents
- Progress.txt interaction details (reads for validation, does not write — Gate 4 approval goes to milestone-status.txt only)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design decisions
- `skills/project/DESIGN.md` — All 13 design decisions (DD-1 through DD-13); authoritative source for gate behavior, state formats, artifact paths
- `skills/project/DESIGN.md` §DD-1 — Three-level hierarchy, sub-feature sizing (~120k tokens on 200k model), 2-5 features per milestone
- `skills/project/DESIGN.md` §DD-4 — Gate mapping; Gate 4 = per-feature implementation plan
- `skills/project/DESIGN.md` §DD-7 — HITL principle: every gate requires explicit human approval
- `skills/project/DESIGN.md` §DD-8 — Gate reviews adapt to phase context (Gate 4: approach correctness, sub-feature sizing, test command)
- `skills/project/DESIGN.md` §DD-12 — Test command planned in `/plan`, executed in `/build`; updatable mid-build
- `skills/project/DESIGN.md` §DD-13 — Gate 4 review checklist items
- `skills/project/DESIGN.md` §`milestones/<NN>-<name>/plans/<feature>.md (Gate 4)` — Feature plan required sections: Summary, Acceptance Criteria, Approach, Sub-Features, Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Files to Create/Modify, Dependencies, Architectural Deviations

### Requirements
- `.planning/REQUIREMENTS.md` §Plan — PLAN-01 through PLAN-09

### Predecessor skill patterns
- `skills/project/milestone/SKILL.md` — Flow controller pattern (163 lines); most recent skill, closest structural model for `/plan`
- `skills/project/design/SKILL.md` — Sub-agent codebase scan pattern (D-05); model for targeted scan
- `skills/project/define/SKILL.md` — Diff-focused revision mode pattern (D-15); model for re-plan mode
- `skills/project/milestone/references/` — Reference file organization pattern (gate spec, progress-format, review-checklist-template, revision-mode)
- `skills/project/define/references/review-checklist-template.md` — Reusable review checklist template pattern

### State file formats
- `skills/project/references/progress-format.md` — Progress.txt format spec (to be copied into plan/references/)

### Codebase conventions
- `.planning/codebase/CONVENTIONS.md` — SKILL.md frontmatter, naming patterns, documentation requirements
- `.planning/codebase/STRUCTURE.md` — Directory layout, skill bundle structure, key locations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/project/milestone/SKILL.md` — Flow controller pattern (163 lines); auto-select next, revision mode auto-detect; closest structural model
- `skills/project/design/SKILL.md` — Sub-agent codebase scan spawn pattern (143 lines)
- `skills/project/define/references/review-checklist-template.md` — Reusable review checklist template
- `skills/project/references/progress-format.md` — Progress.txt format spec to copy into plan/references/
- `skills/project/milestone/references/revision-mode.md` — Revision mode reference pattern; model for re-plan mode reference

### Established Patterns
- SKILL.md uses numbered steps with clear action verbs (~150-200 lines)
- `AskUserQuestion` for interactive prompts (2-4 options, max 12-char headers)
- `disable-model-invocation: true` mandatory in frontmatter
- Reference loading: SKILL.md reads external spec files at the step that needs them (not all upfront)
- Produce-then-review: generate artifact, present, Approve/Revise loop
- Sub-agent for codebase scanning (Gate 0 and Gate 2 precedent)
- Own copy of shared references — no cross-directory reads between skills
- Auto-detect revision mode by checking if artifact already exists

### Integration Points
- `progress.txt` at project root — /plan reads for milestone validation (Gate 3 status)
- `milestones/<NN>-<name>/README.md` — primary input (feature list, acceptance criteria)
- `milestones/<NN>-<name>/milestone-status.txt` — read for feature status, write on plan creation and Gate 4 approval
- `prd.md` at project root — secondary input (project context)
- `docs/ARCHITECTURE_AND_DESIGN.md` — secondary input (architecture constraints)
- `docs/spikes/<topic>.md` — optional input (user-referenced only)
- `milestones/<NN>-<name>/plans/<feature>.md` — primary output (feature plan)
- `milestones/<NN>-<name>/reviews/gate-4-<feature>-review.md` — review checklist output

</code_context>

<specifics>
## Specific Ideas

- Directory structure mirrors /milestone: `skills/project/plan/` with `references/` and `assets/`
- After Gate 4 approval, offer to continue planning the next unplanned feature in the same session
- Re-plan mode auto-detected by existing plan file, uses diff-focused revision (ask what changed, revise affected sections)
- Whole-plan approve/revise is simpler than section-by-section — appropriate for single-feature scope
- Sub-agent scan is feature-targeted (not architecture-wide like /design) — focused on files the feature will touch

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-plan-gate-4*
*Context gathered: 2026-04-02*
