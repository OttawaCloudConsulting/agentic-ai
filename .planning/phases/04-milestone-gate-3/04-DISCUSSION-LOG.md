# Phase 4: /milestone (Gate 3) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 04-milestone-gate-3
**Areas discussed:** Milestone generation, Gate 3 closure, Scope discovery, Revision mode UX

---

## Milestone Generation

| Option | Description | Selected |
|--------|-------------|----------|
| Analyze and propose (Recommended) | Claude reads PRD + architecture doc, proposes full milestone breakdown, user reviews/revises. Produce-then-review pattern. | |
| Interview-driven | Ask user about grouping preferences before generating. | |
| Template-based | Provide milestone template, user fills in. | |

**User's choice:** Analyze and propose

### Input method sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Direct reading (Recommended) | Read PRD + architecture doc directly. Inputs are small focused docs. | |
| Sub-agent scan | Spawn agent to analyze inputs. | |

**User's choice:** Direct reading

### Tradeoff visibility sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Tradeoff callouts (Recommended) | Call out 2-3 key grouping/ordering decisions before approval. Consistent with /design D-09. | |
| Inline only | Tradeoffs embedded in milestone descriptions only. | |

**User's choice:** Tradeoff callouts

### Spike artifact handling sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| User-referenced only (Recommended) | Don't auto-detect spikes from PRD. User cites relevant spikes. | |
| Auto-detect | Scan docs/spikes/ and surface relevant ones. | |

**User's choice:** User-referenced only

---

## Gate 3 Closure

| Option | Description | Selected |
|--------|-------------|----------|
| /project detects (Recommended) | /project offers Gate 3 closure when milestones exist with approved reviews. User confirms. | |
| /milestone signals | /milestone itself closes Gate 3 after last milestone. | |
| Manual only | User explicitly runs a closure command. | |

**User's choice:** /project detects
**Notes:** Keeps /project as routing authority, maintains HITL principle.

### Closure criteria sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Milestones + reviews (Recommended) | Milestones exist AND each has completed gate-3-review.md. | |
| Milestones only | Gate closes when all milestones defined, reviews optional. | |

**User's choice:** Milestones + reviews

---

## Scope Discovery

| Option | Description | Selected |
|--------|-------------|----------|
| Propose all, define one (Recommended) | First invocation proposes milestone plan (count, summaries, order). User approves. Then generates milestone #1 detail. Subsequent invocations auto-advance. | |
| Define all at once | Generate all milestones in one session. | |
| Fully incremental | Define one milestone at a time with no upfront plan. | |

**User's choice:** Propose all, define one
**Notes:** Balances planning visibility with per-milestone review quality.

### Persistence sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| prd.md Milestones section (Recommended) | Natural home alongside requirements. | |
| Separate milestones-plan.md | Standalone file for the plan. | |

**User's choice:** prd.md Milestones section

### Auto-advance sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-select next (Recommended) | On subsequent invocations, auto-select next undefined milestone. User can override. | |
| Always ask | User picks which milestone to define each time. | |

**User's choice:** Auto-select next

---

## Revision Mode UX

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-detect (Recommended) | If milestone directory exists, enter revision mode automatically. No flag needed. | |
| Explicit flag | User passes --revise flag. | |
| Always ask | Prompt user whether to create or revise. | |

**User's choice:** Auto-detect

### Affected features sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Feature checklist (Recommended) | Show all features with status, user multiSelects affected ones. Selected reset to pending, completed preserved. | |
| All-or-nothing | Revise entire milestone. | |
| Diff-based | Show what changed and auto-detect affected features. | |

**User's choice:** Feature checklist

### Revision approach sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Load and revise (Recommended) | Read existing README, ask what changed, revise affected sections. Consistent with /define revision mode D-15. | |
| Regenerate | Regenerate entire milestone from updated inputs. | |

**User's choice:** Load and revise

### Review after revision sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Fresh review (Recommended) | Generate fresh gate-3-review.md. Prior review no longer valid. | |
| Incremental review | Only review changed sections. | |

**User's choice:** Fresh review

---

## Claude's Discretion

- Milestone grouping heuristics and ordering rationale
- Feature sizing estimation approach within DD-1 constraints
- Exact phrasing of approval prompts and tradeoff callouts
- Edge case handling for ambiguous feature boundaries
- Review checklist item generation
- Detection of key tradeoffs for grouping/ordering callouts
- README format and section structure

## Deferred Ideas

None — discussion stayed within phase scope
