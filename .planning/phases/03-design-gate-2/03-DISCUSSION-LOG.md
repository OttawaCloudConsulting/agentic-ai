# Phase 3: /design (Gate 2) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 03-design-gate-2
**Areas discussed:** SKILL.md structure, Architecture generation, Design review UX, Refresh mode

---

## SKILL.md Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Reference files (Recommended) | Follow Phase 2 pattern: SKILL.md as flow controller + gate-2-design.md + refresh-mode.md. Consistent with /define, scales if complexity grows. | ✓ |
| Compact single-file | One SKILL.md (~300-400 lines) with everything inline. Simpler but breaks the pattern. | |
| Hybrid | SKILL.md handles main gate inline, only refresh mode extracted to reference file. | |

**User's choice:** Reference files
**Notes:** None — straightforward consistency choice.

### Template sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Match DESIGN.md exactly (Recommended) | Use the 6 sections as defined in DESIGN.md. Design Decisions as numbered table. | ✓ |
| You decide | Claude discretion to refine within the 6 categories. | |

**User's choice:** Match DESIGN.md exactly

---

## Architecture Generation

| Option | Description | Selected |
|--------|-------------|----------|
| PRD-driven with targeted reads (Recommended) | Read prd.md + codebase-assessment.md as primary inputs. Targeted file reads only. No sub-agent. | |
| Agent-based deep scan | Spawn sub-agent to read 15-30 files through architecture lens. More thorough. | ✓ |
| Hybrid — optional agent | Start PRD-driven, offer re-scan via agent if assessment seems stale. | |

**User's choice:** Agent-based deep scan

### Greenfield sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Skip agent, PRD-only (Recommended) | No codebase to scan — design doc purely PRD-driven. | |
| Always spawn agent | Even on greenfield, scan whatever exists. | ✓ |

**User's choice:** Always spawn agent
**Notes:** User wants thorough scanning regardless of project state.

---

## Design Review UX

| Option | Description | Selected |
|--------|-------------|----------|
| Section-by-section (Recommended) | MultiSelect checklist of 6 sections. Unchecked sections get focused revision. | ✓ |
| Whole-doc approve/revise | Present full doc, Approve/Revise. Simpler but less structured. | |
| Design decisions first | Two-pass: decisions table first, then remaining sections. | |

**User's choice:** Section-by-section

### Tradeoff sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Tradeoff callouts (Recommended) | Call out 2-4 key tradeoff decisions before approval checklist. | ✓ |
| Inline only | Tradeoffs in table column only, no special callout. | |
| You decide | Claude discretion. | |

**User's choice:** Tradeoff callouts

---

## Refresh Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Per-deviation review (Recommended) | Scan feature plans, present each deviation with context, multiSelect to consolidate. | ✓ |
| Batch update | Auto-fold all deviations, present updated doc for review. | |
| Diff-based review | Generate diff of current vs updated architecture doc. | |

**User's choice:** Per-deviation review

### Zero deviations sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Report and exit (Recommended) | Report no deviations found, exit cleanly. | ✓ |
| Offer revision anyway | Report no deviations but offer to revise anyway. | |

**User's choice:** Report and exit

---

## Claude's Discretion

- Architecture agent prompt and file selection heuristics
- Exact phrasing of gate approval prompts and tradeoff callouts
- Edge case handling for greenfield agent scanning
- Progress.txt write format and recording details
- Review checklist item generation
- Detection of "key tradeoffs" for callouts

## Deferred Ideas

None — discussion stayed within phase scope
