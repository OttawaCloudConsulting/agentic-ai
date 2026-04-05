# Phase 10: Tech Debt Sweep - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-04-03
**Phase:** 10-tech-debt-sweep
**Mode:** discuss
**Areas analyzed:** ROADMAP.md checkboxes, SKILLS.md cp consistency, STATE-04 attribution, 04-03 requirements frontmatter

## Gray Areas Identified

| Area | Determination | Reason |
|------|--------------|--------|
| ROADMAP.md checkboxes | Mechanical fix | 2 stale `[ ]` plan entries — single correct answer |
| SKILLS.md cp consistency | Discussed | 3 options: add missing, simplify, annotate |
| STATE-04 attribution | Mechanical fix | Remove `/plan` — it never writes both files |
| 04-03 requirements-completed | Discussed | Pattern match vs empty vs subset |

## Areas Discussed

### SKILLS.md cp Consistency

| Question | Options Presented | User Choice |
|----------|------------------|-------------|
| How to make cp commands consistent? | Add missing entries / Simplify to catch-all / Annotate | Add missing entries |

**Decision:** Add individual `cp -r` entries for `define/`, `design/`, `build/` — all 6 sub-skills have explicit entries for selective installs. Catch-all `skills/project/` remains.

### 04-03 requirements-completed

| Question | Options Presented | User Choice |
|----------|------------------|-------------|
| What should requirements-completed list? | All MIL-01–13 / Empty list / Subset | All MIL-01–13 |

**Decision:** Match pattern from 04-01 and 04-02 — all plan summaries in a phase claim the same requirements. Documentation is part of complete delivery.

## Mechanical Fixes (No Discussion)

- **ROADMAP.md:** `[ ] 01-03-PLAN.md` → `[x]`, `[ ] 05-02-PLAN.md` → `[x]`
- **STATE-04:** Remove `/plan` from attribution — "applies to `/build` and `/milestone`" only
