# Phase 8: Fix Greenfield Routing - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the greenfield routing ambiguity in the `/project` skill. The second `/project` invocation on a greenfield project currently hits an unmatched state in the routing table (Gate 0 `[-]` has no explicit row), and the Gate WB offer condition in `SKILL.md` Step 5 never fires for `[-]` because it checks `[x]` only.

Two files require changes: `skills/project/references/routing-logic.md` and `skills/project/SKILL.md`.

</domain>

<decisions>
## Implementation Decisions

### [-] State Equivalence
- **D-01:** `[-]` (greenfield skip) is treated as fully equivalent to `[x]` (approved) for ALL routing decisions downstream — not just Gate WB and Gate 1 advancement. Gate 0 skipped = Gate 0 effectively approved.

### Gate WB Offer Condition
- **D-02:** The Gate WB offer condition in `SKILL.md` Step 5 is updated from "If Gate 0 is approved" to "If Gate 0 is approved or skipped (greenfield)" — i.e., `[x]` or `[-]`. Same Yes/Skip/Defer prompt either way. No stronger nudge for greenfield — standard offer is sufficient.

### routing-logic.md Table Structure
- **D-03:** Fix via an equivalence note added to the `routing-logic.md` Notes section (at bottom of routing table), not via new rows or in-place row rewrites. Note states: "`[-]` (skipped) is treated as equivalent to `[x]` (approved) for all Gate 0 routing — greenfield skip counts as Gate 0 resolved." Keeps the table clean; existing rows implicitly cover both states.

### Claude's Discretion
- Exact wording of the equivalence note
- Whether to add `[-]` alongside `[x]` in any inline table row references for clarity (cosmetic)
- Exact prose update to SKILL.md Step 5 condition block

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Routing specification
- `skills/project/references/routing-logic.md` — The routing decision table being fixed; Gate WB offer logic section defines the condition to update
- `skills/project/SKILL.md` — Step 5 (Route) contains the Gate WB offer condition that needs updating

### Gap closure source
- `.planning/v1.0-MILESTONE-AUDIT.md` — Defines `GREENFIELD-ROUTING` gap and `GREENFIELD-E2E` flow gap; specifies exactly what's broken and where

### Requirements
- `.planning/REQUIREMENTS.md` — PROJ-03 (correct routing), PROJ-06 (Gate WB offer fires)

### Design decisions
- `skills/project/DESIGN.md` — DD-11 (Gate WB optional), D-08 (Gate WB offer sequence), D-09 (Pending behavior)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `routing-logic.md` Notes section already exists (below the routing table) — the equivalence note slots in there naturally
- Gate WB offer condition is a single prose block in SKILL.md Step 5 — surgical one-line update

### Established Patterns
- routing-logic.md uses a Markdown table + Notes prose pattern; new content follows that pattern
- SKILL.md uses bold inline conditions (`**If Gate 0 is approved, ...**`) — update follows same style

### Integration Points
- Only two files change: `routing-logic.md` (note addition) and `SKILL.md` Step 5 (condition update)
- No other skills reference the Gate 0 `[-]` state explicitly — change is self-contained

</code_context>

<specifics>
## Specific Ideas

- The equivalence note should be precise: "`[-]` is treated as equivalent to `[x]` for all Gate 0 routing. Greenfield projects skip Gate 0 (codebase alignment is not applicable), but the skip counts as Gate 0 resolved for all downstream routing purposes."
- SKILL.md Step 5 condition: "If Gate 0 is approved (`[x]`) or skipped (`[-]` greenfield), no `docs/working-backwards.md` exists, Gate WB has not been offered yet, and the customer outcome is unclear — offer Gate WB..."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-greenfield-routing*
*Context gathered: 2026-04-03*
