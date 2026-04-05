# Phase 1: /project Router - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 01-project-router
**Areas discussed:** Status report format, Routing UX, Warning presentation, Gate WB offer/pending UX

---

## Status Report Format

| Option | Description | Selected |
|--------|-------------|----------|
| Structured summary | Gates as checklist, active milestone with feature progress, next action — clean sections, scannable | x |
| Compact dashboard | Dense, minimal — gates on one line, milestone as progress bar | |
| Narrative report | Prose-style status with context — reads like a briefing | |

**User's choice:** Structured summary
**Notes:** None

### Follow-up: Milestone scope in report

| Option | Description | Selected |
|--------|-------------|----------|
| Active + summary | Full detail for active milestone, one-line status for completed/upcoming | x |
| Active only | Only show current milestone | |
| All milestones | Show every milestone with feature status | |

**User's choice:** Active + summary
**Notes:** None

### Follow-up: Spike display

| Option | Description | Selected |
|--------|-------------|----------|
| Open spikes only | Show unresolved spikes only | |
| All spikes | Show both open and resolved spikes | x |
| Only if relevant | Show spikes only when referenced by active milestone | |

**User's choice:** All spikes
**Notes:** None

---

## Routing UX

| Option | Description | Selected |
|--------|-------------|----------|
| Single next action | One clear recommendation, opinionated | |
| Prioritized menu | Top recommendation highlighted, 2-3 valid alternatives below | x |
| Full menu | All valid actions listed equally | |

**User's choice:** Prioritized menu
**Notes:** None

### Follow-up: Context sensitivity

| Option | Description | Selected |
|--------|-------------|----------|
| Context-sensitive | Only show actions valid for current state | x |
| Fixed set | Always show same alternatives | |

**User's choice:** Context-sensitive
**Notes:** None

### Follow-up: Re-planning detection

| Option | Description | Selected |
|--------|-------------|----------|
| Detect intent from keywords | Recognize phrases like "goals changed", "re-plan" | x |
| Explicit flags only | User must use flags like --revise-prd | |
| You decide | Claude's discretion | |

**User's choice:** Detect intent from keywords
**Notes:** None

---

## Warning Presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Inline after gate/milestone | Warning appears right next to affected item | x |
| Separate warnings section | All warnings collected at top or bottom | |
| You decide | Claude's discretion | |

**User's choice:** Inline after gate/milestone
**Notes:** None

### Follow-up: Warning blocking behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Inform only | Show warning, still route to next action | |
| Block on divergence | Consistency warnings pause routing until acknowledged | |
| Severity-based | Missing artifacts = inform, consistency divergence = block | x |

**User's choice:** Severity-based
**Notes:** Missing artifact warnings are informational. Consistency divergence between progress.txt and milestone-status.txt blocks routing.

---

## Gate WB Offer/Pending UX

| Option | Description | Selected |
|--------|-------------|----------|
| Explain and ask | Brief explanation of WB value + yes/skip/defer options | x |
| Minimal prompt | One-line offer, no explanation | |
| You decide | Claude's discretion | |

**User's choice:** Explain and ask
**Notes:** None

### Follow-up: Pending re-prompt insistence

| Option | Description | Selected |
|--------|-------------|----------|
| Gentle reminder first | Show status report normally, highlight pending at top | x |
| Block immediately | Must resolve before any status shown (strict PROJ-07) | |
| You decide | Claude's discretion | |

**User's choice:** Gentle reminder first
**Notes:** Differs from strict PROJ-07 reading. User prefers seeing status alongside the pending reminder rather than being hard-blocked.

---

## Claude's Discretion

- Bootstrap progress.txt format and exact content
- Exact phrasing of routing recommendations
- Greenfield vs brownfield detection logic for Gate WB offer
- Internal implementation of state parsing

## Deferred Ideas

None — discussion stayed within phase scope
