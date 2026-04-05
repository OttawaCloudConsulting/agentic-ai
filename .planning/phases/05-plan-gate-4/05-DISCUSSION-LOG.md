# Phase 5: /plan (Gate 4) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 05-plan-gate-4
**Areas discussed:** Feature targeting, Sub-feature sizing, Plan content scope, Review & approval

---

## Feature targeting

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-select next | Read milestone-status.txt, find first pending feature. User can override. | ✓ |
| Always explicit | User must specify feature name every time | |
| Menu selection | Present list of plannable features via AskUserQuestion | |

**User's choice:** Auto-select next (Recommended)
**Notes:** Consistent with /milestone D-09 auto-select pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect active milestone | Read progress.txt for first [ ] or [~] milestone. User can override. | ✓ |
| Always require argument | User must pass milestone number/name | |
| Menu if ambiguous | Auto-detect if one active, menu if multiple | |

**User's choice:** Auto-detect active (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Report and exit | Clean exit when no plannable features remain | ✓ |
| Offer re-plan | Present already-planned features for optional revision | |

**User's choice:** Report and exit (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, auto-detect | If plan file exists, enter re-plan mode. Consistent with /milestone D-10. | ✓ |
| Yes, explicit flag | Require --replan flag | |
| No re-plan in v1 | Defer re-planning support | |

**User's choice:** Yes, auto-detect (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Diff-focused revision | Read existing plan, ask what changed, revise affected sections | ✓ |
| Full regeneration | Discard and regenerate from scratch | |
| Side-by-side | Generate new alongside existing, present diff | |

**User's choice:** Diff-focused revision (Recommended)

---

## Sub-feature sizing

| Option | Description | Selected |
|--------|-------------|----------|
| Heuristic estimate | Claude estimates complexity based on files, logic scope, integration surface | ✓ |
| Line-count proxy | Flag anything over ~500 new lines | |
| Trust with warning | General warning at end, no per-item flagging | |

**User's choice:** Heuristic estimate (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Propose split inline | Flag oversized, propose 2-3 smaller items, present revised plan | ✓ |
| Flag only | Mark with warning, leave splitting to user | |
| Block until split | Refuse to present plan until all pass sizing | |

**User's choice:** Propose split inline (Recommended)

---

## Plan content scope

| Option | Description | Selected |
|--------|-------------|----------|
| Claude proposes, user confirms | Generate test command, present during review. Per DD-12. | ✓ |
| Always ask user | Explicitly ask user for test command | |
| Claude decides | Auto-generate as discretion, user can change during review | |

**User's choice:** Claude proposes, user confirms (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Signatures + shapes | Function signatures, data shapes, event formats | ✓ |
| Full API spec | Complete OpenAPI-style specs, full type definitions | |
| Descriptive only | Prose descriptions of interfaces | |

**User's choice:** Signatures + shapes (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, targeted scan | Sub-agent reads files relevant to the feature | ✓ |
| Direct reading only | Claude reads milestone README, PRD, architecture doc directly | |
| Optional per feature | Offer scan as option, skip for simple features | |

**User's choice:** Yes, targeted scan (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| User-referenced only | Read spike docs only when user explicitly references them | ✓ |
| Auto-detect from PRD | Scan PRD for spike references, auto-read | |

**User's choice:** User-referenced only (Recommended)

---

## Review & approval

| Option | Description | Selected |
|--------|-------------|----------|
| Whole-plan approve/revise | Present full plan, Approve / Revise. Simpler for single-feature scope. | ✓ |
| Section-by-section | multiSelect checklist of plan sections | |
| Key sections only | Highlight 2-3 key sections for focused review | |

**User's choice:** Whole-plan approve/revise (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, 1-2 callouts | Highlight most significant approach/sizing decisions before approval | ✓ |
| No callouts | Go straight to approve/revise | |
| Yes, full callouts | 2-4 callouts like /design | |

**User's choice:** Yes, 1-2 callouts (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Offer next | After approval, offer to plan next unplanned feature | ✓ |
| Exit after one | One feature per invocation | |
| Auto-continue | Automatically start next feature without asking | |

**User's choice:** Offer next (Recommended)

---

## Claude's Discretion

- Plan generation approach and section ordering
- Sub-agent prompt and file selection heuristics
- Sub-feature granularity within sizing guidelines
- Edge case identification depth
- Documentation section content
- Exact phrasing of approval prompts and tradeoff callouts
- Review checklist item generation
- Progress.txt interaction details

## Deferred Ideas

None — discussion stayed within phase scope
