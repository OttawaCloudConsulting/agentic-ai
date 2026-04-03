# Phase 8: Fix Greenfield Routing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-04-03
**Phase:** 08-greenfield-routing
**Mode:** discuss
**Areas discussed:** [-] state equivalence, Gate WB offer condition, routing-logic.md structure

## Gray Areas Presented

### [-] state equivalence
| Question | Options Offered |
|----------|----------------|
| Should `[-]` be treated as fully equivalent to `[x]` for all routing or only specific steps? | Fully equivalent (Recommended) / Step-specific handling |

### Gate WB offer condition
| Question | Options Offered |
|----------|----------------|
| How should greenfield be handled in the Gate WB offer condition? | Same offer, updated condition (Recommended) / Stronger nudge for greenfield / Separate routing row for greenfield WB |

### routing-logic.md structure
| Question | Options Offered |
|----------|----------------|
| How to represent the fix in routing-logic.md? | Equivalence note at top of table (Recommended) / Explicit new row for Gate 0 [-] / Expand existing row descriptions |

## Decisions Made

### [-] State Equivalence
- **User selected:** Fully equivalent to [x] (Recommended)
- **Decision:** `[-]` is treated as equivalent to `[x]` for all Gate 0 routing downstream

### Gate WB Offer Condition
- **User selected:** Same offer, updated condition (Recommended)
- **Decision:** Update SKILL.md Step 5 condition to include `[-]` alongside `[x]`; same Yes/Skip/Defer prompt

### routing-logic.md Structure
- **User selected:** Equivalence note at top of table (Recommended)
- **Decision:** Add a note to the Notes section in routing-logic.md stating `[-]` = `[x]` for routing; no new rows

## Corrections Made

No corrections — all recommended defaults accepted.

## Deferred Ideas

None — discussion stayed within phase scope.
