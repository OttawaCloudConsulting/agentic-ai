# Phase 2: /define (Gates 0/WB/1) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-02
**Phase:** 02-define-gates-0-wb-1
**Areas discussed:** SKILL.md decomposition, Gate flow UX, Codebase assessment, PRD interview design

---

## SKILL.md Decomposition

### References organization

| Option | Description | Selected |
|--------|-------------|----------|
| Per-gate files | gate-0-codebase.md, gate-wb-working-backwards.md, gate-1-prd.md — each gate's spec is self-contained | ✓ |
| By concern | interview-guide.md, output-formats.md, review-checklists.md — organized by content type | |
| Hybrid | Per-gate for heavy specs, shared file for cross-cutting concerns | |

**User's choice:** Per-gate files
**Notes:** Matches the pattern of SKILL.md reading relevant reference at each gate start.

### Shared vs duplicated references

| Option | Description | Selected |
|--------|-------------|----------|
| Shared at suite level | skills/project/references/ holds shared specs, sub-skills read from shared location | |
| Copy per skill | Each skill gets its own copy of what it needs, no cross-directory reads | ✓ |
| You decide | Claude's discretion | |

**User's choice:** Copy per skill
**Notes:** Matches how /project already works — self-contained references/ per skill.

### Directory location

| Option | Description | Selected |
|--------|-------------|----------|
| skills/project/define/ | Nested under the project suite | ✓ |
| skills/define/ | Top-level alongside other skills | |
| You decide | Claude's discretion | |

**User's choice:** skills/project/define/

---

## Gate Flow UX

### Gate approval mechanics

| Option | Description | Selected |
|--------|-------------|----------|
| Produce-then-review | Each gate: produce artifact, present, ask Approve/Revise/Reject. Revision in-session. | ✓ |
| Incremental approval | Each section presented individually for approval | |
| Draft-then-walkthrough | Produce draft, walk through highlights, batch feedback, revise once | |

**User's choice:** Produce-then-review

### Review checklist approach

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-generate, user validates | Claude generates checklist from artifact, pre-checks verifiable items, user resolves rest | ✓ |
| Template-based | Fixed checklist template per gate, Claude fills what it can | |
| You decide | Claude's discretion | |

**User's choice:** Auto-generate, user validates

### Rejection handling

| Option | Description | Selected |
|--------|-------------|----------|
| Revise in-session | Rejection = revision request. Claude asks what's wrong, fixes, re-presents. No abort. | ✓ |
| Abort option | Offers Revise or Abort. Abort exits cleanly. | |
| You decide | Claude's discretion | |

**User's choice:** Revise in-session

### Partial approval (Gate 1)

| Option | Description | Selected |
|--------|-------------|----------|
| Section checklist | MultiSelect of PRD sections. Checked = approved, unchecked = needs revision. | ✓ |
| Free-text feedback | User describes changes in plain text, Claude identifies affected sections. | |
| You decide | Claude's discretion | |

**User's choice:** Section checklist

---

## Codebase Assessment

### Scan depth (Gate 0)

| Option | Description | Selected |
|--------|-------------|----------|
| Targeted scan | Read key files: manifests, top-level structure, 5-10 relevant source files | |
| Agent-based deep scan | Spawn sub-agent reading 20-40 files, return structured findings | ✓ |
| You decide | Claude's discretion based on project size | |

**User's choice:** Agent-based deep scan

### Greenfield detection

| Option | Description | Selected |
|--------|-------------|----------|
| Heuristic-based | Check for: no src/app/lib dirs, no manifests, <5 non-config files. All true = skip Gate 0. | ✓ |
| Ask the user | Always ask whether this is new or existing project | |
| You decide | Claude's discretion | |

**User's choice:** Heuristic-based

### Gate 1 re-read UX (DEF-16)

| Option | Description | Selected |
|--------|-------------|----------|
| Silent re-read | Re-read file, no user output, use internally for PRD interview | ✓ |
| Brief recap | Re-read and show 3-5 line summary to help user reconnect | |
| You decide | Claude's discretion | |

**User's choice:** Silent re-read

---

## PRD Interview Design

### Interview approach

| Option | Description | Selected |
|--------|-------------|----------|
| Fork and adapt | Copy create-prd's interview guide, add WB integration, remove architecture, add milestone scoping | ✓ |
| Start fresh | Design new interview flow from scratch | |
| You decide | Claude's discretion | |

**User's choice:** Fork and adapt

### Working Backwards integration at Gate 1

| Option | Description | Selected |
|--------|-------------|----------|
| WB as seed, shorter interview | Auto-populate PRD sections from WB doc, interview only gaps | |
| WB as context only | Read WB for context, full interview still runs | ✓ |
| You decide | Claude's discretion | |

**User's choice:** WB as context only
**Notes:** User chose full interview even when WB exists — WB informs but doesn't auto-populate.

### Revision mode

| Option | Description | Selected |
|--------|-------------|----------|
| Diff-focused interview | Read existing PRD, ask what changed, interview only affected sections, surface downstream artifacts | ✓ |
| Full re-interview | Re-run complete interview with existing PRD as starting point | |
| You decide | Claude's discretion | |

**User's choice:** Diff-focused interview

---

## Claude's Discretion

- Exact codebase scan agent prompt and file selection heuristics
- Assessment section ordering and formatting
- PRD interview pacing (questions per round)
- Exact phrasing of gate approval prompts
- Greenfield detection edge cases
- Progress.txt write format details

## Deferred Ideas

None — discussion stayed within phase scope
