# Phase 1: /project Router - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Bootstraps `progress.txt` on first run, validates project state (artifact existence, milestone consistency), and routes user to the correct next skill on every subsequent invocation. `/project` is stateless and read-only after bootstrap (DD-3). This phase delivers one complete, invokable skill.

</domain>

<decisions>
## Implementation Decisions

### Status report format
- **D-01:** Structured summary with clean sections — gates as a checklist with dates, active milestone with per-feature status, one-line summaries for completed/upcoming milestones
- **D-02:** Show ALL spikes (both open and resolved) in a dedicated Spikes section

### Routing UX
- **D-03:** Prioritized menu — one recommended next action highlighted, with 2-3 context-sensitive valid alternatives listed below
- **D-04:** "Also available" options are context-sensitive — only show actions valid for the current project state (e.g., don't show `/plan` if no milestone exists)
- **D-05:** Detect re-planning intent from natural language keywords (e.g., "goals changed", "re-plan", "revise PRD") and route to the appropriate skill in revision mode

### Warning presentation
- **D-06:** Warnings appear inline, directly after the gate or milestone entry they affect (not collected in a separate section)
- **D-07:** Severity-based blocking — missing artifact warnings are informational only (don't block routing), but consistency divergence between `progress.txt` and `milestone-status.txt` blocks routing until the user acknowledges

### Gate WB offer/pending UX
- **D-08:** When no `working-backwards.md` exists and customer outcome is unclear, offer Gate WB with a brief explanation (2-3 sentences on Working Backwards value) plus three options: Yes, Skip, Defer
- **D-09:** When Gate WB is Pending on re-invocation, show a gentle reminder at the top of the report but still display the full status report. Do not hard-block — differs from strict PROJ-07 reading; the pending decision is highlighted but does not suppress status output

### Claude's Discretion
- Bootstrap `progress.txt` format and exact content (following the format defined in DESIGN.md)
- Exact phrasing of routing recommendations
- How to detect greenfield vs brownfield for Gate WB offer logic
- Internal implementation of state parsing

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design decisions
- `skills/project/DESIGN.md` — All 13 design decisions (DD-1 through DD-14); authoritative source for `/project` behavior, state file formats, gate structure, artifact paths
- `skills/project/DESIGN.md` §DD-3 — Stateless/read-only orchestrator contract
- `skills/project/DESIGN.md` §DD-7 — Gate review behaviors and rules
- `skills/project/DESIGN.md` §DD-11 — Gate WB optional stage, Pending state behavior

### State file formats
- `skills/project/progress-file/` — Progress file format analysis and decision artifacts (plain text chosen over YAML)

### Requirements
- `.planning/REQUIREMENTS.md` §Router — PROJ-01 through PROJ-10, STATE-01 through STATE-04

### Existing skill pattern
- `skills/create-prd/SKILL.md` — Reference SKILL.md structure (frontmatter, step format, tool usage) to follow for `/project`

### Codebase conventions
- `.planning/codebase/CONVENTIONS.md` — Skill file conventions, SKILL.md frontmatter, naming patterns, documentation requirements
- `.planning/codebase/STRUCTURE.md` — Directory layout, skill bundle structure, key locations for adding new components

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/create-prd/SKILL.md` — Reference pattern for SKILL.md structure (frontmatter with `disable-model-invocation: true`, numbered steps, AskUserQuestion usage)
- `skills/project/DESIGN.md` — Comprehensive design document with all behavior specifications
- `skills/project/progress-file/` — Format decision artifacts for `progress.txt`

### Established Patterns
- Skills are markdown-only prompt files — no compiled code in this repo
- `AskUserQuestion` used for interactive prompts (2-4 options, max 12-char headers)
- Scripts invoked with explicit interpreter (`bash scripts/foo.sh`, never `./`)
- Every new skill requires: SKILL.md + detail doc (`docs/skills/<name>.md`) + catalog entry (`docs/SKILLS.md`)
- `disable-model-invocation: true` mandatory in frontmatter

### Integration Points
- `progress.txt` at project root — created by `/project` on bootstrap, read by all downstream skills
- `milestones/*/milestone-status.txt` — read by `/project` for consistency validation
- `docs/SKILLS.md` — catalog entry needed for `/project`
- `docs/skills/project.md` — detail doc needed

</code_context>

<specifics>
## Specific Ideas

- Status report preview style matches the "Structured summary" mockup — gates as checklist with dates, active milestone expanded, others summarized
- Routing preview matches the "Prioritized menu" mockup — recommended action bold, alternatives as bullet list
- Warning style matches the "Inline" mockup — warning emoji + message directly under affected item
- Gate WB offer matches the "Explain and ask" mockup — brief value explanation + yes/skip/defer options

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-project-router*
*Context gathered: 2026-04-02*
