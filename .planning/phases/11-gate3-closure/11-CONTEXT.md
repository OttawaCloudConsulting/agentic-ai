# Phase 11: Gate 3 Closure Pathway - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve the structural contradiction between PROJ-10 (read-only after bootstrap) and the Gate 3 closure design — by implementing Gate 3 closure in `/project` with a narrowly-scoped exception to the read-only rule. Gate 3 should show `[x]` on a fully-completed project.

This phase touches `/project` SKILL.md (Step 5 routing logic + Rules), `references/routing-logic.md` (new routing table row), `DESIGN.md` (DD-3 exception clause), and REQUIREMENTS.md (PROJ-10 narrowing). No changes to `/milestone` or other skills.

</domain>

<decisions>
## Implementation Decisions

### Resolution Approach
- **D-01:** Implement Gate 3 closure — add logic to `/project` Step 5 (Route) to detect when closure is appropriate and write `[x]` to Gate 3 in `progress.txt`. Do NOT take the documentation-only path.
- **D-02:** Narrow PROJ-10 (not remove it): the read-only rule gains one named exception: Gate 3 closure. REQUIREMENTS.md, DESIGN.md DD-3, and SKILL.md Rules section must all reflect the same narrowed rule.

### Closure Trigger Condition
- **D-03:** `/project` offers Gate 3 closure when: all milestones in `progress.txt` are `[x]` complete AND Gate 3 is still `[~] In progress`. Both conditions must be true simultaneously.
- **D-04:** Gate 3 closure is offered via `AskUserQuestion` (not automatic). Options: "Close Gate 3" / "Leave open". User must confirm before the write happens.
- **D-05:** The closure prompt is part of Step 5 routing — it fires as a special case in the routing table evaluation, before outputting the normal RECOMMENDED/Also available block.

### Routing Table Update
- **D-06:** Add a new row to `references/routing-logic.md` routing table: State = "All milestones `[x]`, Gate 3 still `[~] In progress`" → Offer Gate 3 closure via `AskUserQuestion`. This row is inserted immediately before the existing "All milestones complete → Project complete" row.
- **D-07:** After Gate 3 is written `[x]`, routing falls through to the "All milestones complete" row and shows "Project complete" as the recommendation.

### Documentation Updates
- **D-08:** Update DD-3 in `DESIGN.md` to add Gate 3 closure as a second named exception alongside bootstrap. Exact language: "**Gate 3 closure exception:** When all milestones are `[x]` complete and Gate 3 remains `[~] In progress`, `/project` offers closure via `AskUserQuestion`. This is the only post-bootstrap write `/project` performs."
- **D-09:** Update REQUIREMENTS.md PROJ-10 to reflect the narrowed rule: add parenthetical "(Bootstrap and Gate 3 closure are the two exceptions)".

### Claude's Discretion
- Exact wording of the AskUserQuestion prompt for Gate 3 closure offer
- Whether to show a 1-line explanation of what Gate 3 closure means before the prompt
- Whether to re-display the full status report after writing `[x]` or just confirm inline

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Files to modify
- `skills/project/SKILL.md` — Rules section (PROJ-10 line ~21) + Step 5 Route (new closure branch)
- `skills/project/references/routing-logic.md` — routing table, add new row before "All milestones complete"
- `skills/project/DESIGN.md` — DD-3 (lines 86–122), add Gate 3 closure exception paragraph
- `.planning/REQUIREMENTS.md` — PROJ-10 row, add exception parenthetical

### Audit source
- `.planning/v1.0-MILESTONE-AUDIT.md` — `GATE3-CLOSURE` integration gap definition (describes contradiction, impact, and both resolution paths)

### Existing patterns to follow
- `skills/project/SKILL.md` Step 5 Gate WB offer — uses identical AskUserQuestion pattern (2-option confirm/skip); follow this exact pattern for the closure offer

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Gate WB offer pattern** (`SKILL.md` Step 5, ~line 85): AskUserQuestion with Yes/Skip/Defer options, fires as a conditional branch in routing before normal recommendation output. Gate 3 closure follows this exact structure — detect condition, offer AskUserQuestion, write state, continue to normal routing.
- **Bootstrap write pattern** (`SKILL.md` Step 2): the only existing disk write in `/project`. The Gate 3 write is structurally identical — a single targeted update to `progress.txt`.

### Established Patterns
- **Routing table evaluation**: top-to-bottom, first-match. New row must be inserted at the correct position — after the milestone-in-flight rows but before the "All milestones complete" terminal row.
- **Progress.txt Gate 3 line format**: `[~] Gate 3: Milestone Review             In progress` → changes to `[x] Gate 3: Milestone Review  Approved: <date>  (closed by /project)` (see `references/progress-format.md` for exact format).
- **Rule/exception documentation style**: DD-3 already has a "Bootstrap exception" paragraph with bold label. Gate 3 closure exception follows the same bold-label paragraph format.

### Integration Points
- `/project` SKILL.md Step 5 — the closure offer fires here, after routing table evaluation determines "all milestones complete" state
- `progress.txt` Gate 3 line — the only file modified by the closure write
- `/milestone` SKILL.md Rule: "Gate 3 closure is /project's responsibility (D-05)" — this comment is already correct; no change needed in /milestone

</code_context>

<specifics>
## Specific Ideas

No specific requirements — the closure UX follows the existing Gate WB offer pattern exactly.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-gate3-closure*
*Context gathered: 2026-04-03*
