# Implementation Plan: occ-skill-refactor

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | `SKILL.md` | Add `license: Apache-2.0` to frontmatter | P2 |
| 2 | `SKILL.md` | Expand description to mention input shape | P3 |
| 3 | `SKILL.md` | Remove redundant "Read `references/refactor-protocol.md`" repetitions from Steps 2 and 6 | P2 |
| 4 | `SKILL.md` | Surface `references/anthropic-best-practices.md` with explicit when-to-read guidance | P2 |
| 5 | `SKILL.md` | Replace "up to 3 questions" with specific question listing or direct section reference | P2 |
| 6 | `SKILL.md` | Inline the review-summary path in Step 3 | P3 |
| 7 | `references/refactor-protocol.md` | Add table of contents | P2 |
| 8 | `references/anthropic-best-practices.md` | Add table of contents | P2 |

---

## Detailed Changes

### SKILL.md

#### Change 1 — Add `license` field to frontmatter [P2]

**Location**: Line 1–5 (frontmatter block)

**Current**:
```
---
name: occ-skill-refactor
description: Reviews and refactors an existing skill against quality standards. Invoke explicitly with /occ-skill-refactor. Do NOT use to create a new skill from scratch.
disable-model-invocation: true
---
```

**Replace with**:
```
---
name: occ-skill-refactor
description: Reviews and refactors an existing skill against quality standards. Accepts a skill path (e.g. skills/<skill-name>/ or .claude/skills/<skill-name>/). Invoke explicitly with /occ-skill-refactor. Do NOT use to create a new skill from scratch.
disable-model-invocation: true
license: Apache-2.0
---
```

**Reason**: Matches `occ-skill-creator` frontmatter for consistency; description gains input-shape clarity at no triggering risk since `disable-model-invocation: true`.

---

#### Change 2 — Remove redundant protocol references from Steps 2 and 6, surface both reference files with when-to-read guidance [P2]

**Location**: Lines 24, 34–35, 56 (intro reference pointer and per-step repetitions)

**Current** (line 24):
```
See `references/refactor-protocol.md` for full sub-agent prompt templates, output formats, and AskUserQuestion schemas.
```

**Current** (lines 34–35, inside Step 2):
```
- **Critique agent** — evaluates against internal quality standards (conciseness, degrees of freedom, progressive disclosure, structure, forbidden files). Read `references/refactor-protocol.md` for the prompt template.
- **Red-team agent** — evaluates against `references/anthropic-best-practices.md` (naming, frontmatter, trigger quality, instruction quality, error handling, file conventions). Read `references/refactor-protocol.md` for the prompt template.
```

**Current** (line 56, inside Step 6):
```
Apply approved changes in-place to the skill files. Preserve sections not flagged for change in targeted refactors. Log implementation notes to `decisions.md`. Read `references/refactor-protocol.md` for the prompt template.
```

**Replace the intro block (line 24) with**:
```
Reference files used in this workflow:

- `references/refactor-protocol.md` — sub-agent prompt templates, output formats, temp directory structure, AskUserQuestion schemas, and decisions log template. Read before launching any sub-agent.
- `references/anthropic-best-practices.md` — Anthropic's official skill standards. The red-team agent reads this file directly to evaluate the target skill. Consult it to understand the evaluation criteria.
```

**Replace the Step 2 bullet lines (34–35) with**:
```
- **Critique agent** — evaluates against internal quality standards (conciseness, degrees of freedom, progressive disclosure, structure, forbidden files).
- **Red-team agent** — evaluates against Anthropic's official standards using `references/anthropic-best-practices.md` (naming, frontmatter, trigger quality, instruction quality, error handling, file conventions).
```

**Replace the Step 6 body (line 56) with**:
```
Apply approved changes in-place to the skill files. Preserve sections not flagged for change in targeted refactors. Log implementation notes to `decisions.md`.
```

**Reason**: The intro pointer is sufficient; per-step repetitions add noise. Surfacing `anthropic-best-practices.md` by name with when-to-read guidance makes it visible to readers who only read SKILL.md.

---

#### Change 3 — Clarify the requirements gathering step [P2]

**Location**: Line 52 (Step 5 body)

**Current**:
```
Ask the user up to 3 questions: which change categories to apply, any new requirements, refactor depth (targeted vs full rewrite). Log all answers to `temp/<skill-name>/refactor/decisions.md`.
```

**Replace with**:
```
Ask the user the 3 questions defined in `references/refactor-protocol.md` under "Requirements Gathering":
1. Which change categories to apply (multi-select: critical / should-fix / nice-to-have / specify below)
2. Any new requirements or direction changes
3. Refactor depth — targeted (fix selected issues only) vs full rewrite (only ask if scope is unclear)

Log all answers to `temp/<skill-name>/refactor/decisions.md`.
```

**Reason**: "Up to 3 questions" is ambiguous about whether fewer questions are acceptable; listing them removes guesswork while pointing to the protocol for the full schema.

---

#### Change 4 — Inline the review-summary path in Step 3 [P3]

**Location**: Line 44 (Step 3 body)

**Current**:
```
Merge both feedback files into `temp/<skill-name>/refactor/review-summary.md`. Present the path to the user and ask them to review it before proceeding.
```

**Replace with**:
```
Merge both feedback files into `temp/<skill-name>/refactor/review-summary.md`. Present the path `temp/<skill-name>/refactor/review-summary.md` to the user and ask them to review it before proceeding.
```

**Reason**: The canonical path is visible inline; a reader following Step 3 no longer needs to consult the Example block or the protocol reference to know the output location.

---

### references/refactor-protocol.md

#### Change 5 — Add table of contents [P2]

**Location**: After line 5 (after the opening paragraph, before the first `---` separator at line 5)

**Current** (lines 1–6):
```
# Refactor Review Protocol

Full protocol for the Refactor Review stage. Claude follows this when executing the occ-skill-refactor workflow.

---
```

**Replace with**:
```
# Refactor Review Protocol

Full protocol for the Refactor Review stage. Claude follows this when executing the occ-skill-refactor workflow.

## Contents

- [Stage Overview](#stage-overview)
- [Temp Directory Structure](#temp-directory-structure)
- [Sub-agent 1: Critique Agent](#sub-agent-1-critique-agent)
- [Sub-agent 2: Red-team Agent](#sub-agent-2-red-team-agent)
- [Compile: Review Summary](#compile-review-summary)
- [Approval Gate](#approval-gate)
- [Requirements Gathering (Post-Approval)](#requirements-gathering-post-approval)
- [Sub-agent 3: Refactor Agent](#sub-agent-3-refactor-agent)
- [Decisions Log Template](#decisions-log-template)

---
```

**Reason**: File is 337 lines; ToC enables targeted reads without full scan. Required by best practices for files >100 lines.

---

### references/anthropic-best-practices.md

#### Change 6 — Add table of contents [P2]

**Location**: After line 5 (after the opening paragraph, before the first `---` separator)

**Current** (lines 1–7):
```
# Anthropic Skill Best Practices

Reference for red-teaming skills against official Anthropic standards. Use this during the refactor review stage to identify gaps and issues.

Source: The Complete Guide to Building Skills for Claude (Anthropic, 2026)

---
```

**Replace with**:
```
# Anthropic Skill Best Practices

Reference for red-teaming skills against official Anthropic standards. Use this during the refactor review stage to identify gaps and issues.

Source: The Complete Guide to Building Skills for Claude (Anthropic, 2026)

## Contents

- [Naming Rules](#naming-rules)
- [Frontmatter Requirements](#frontmatter-requirements)
- [Trigger Quality Checklist](#trigger-quality-checklist)
- [Progressive Disclosure](#progressive-disclosure)
- [Instruction Quality](#instruction-quality)
- [File Structure Conventions](#file-structure-conventions)
- [Common Failure Modes](#common-failure-modes)
- [Severity Classification for Gaps](#severity-classification-for-gaps)

---
```

**Reason**: File is 198 lines; ToC enables the red-team agent (and human readers) to navigate to the relevant section without reading the full file. Required by best practices for files >100 lines.

---

## Implementation Order

1. **`references/refactor-protocol.md` — ToC** (Change 5): No dependencies; standalone insert. Makes the most-consulted reference file navigable immediately.
2. **`references/anthropic-best-practices.md` — ToC** (Change 6): No dependencies; standalone insert.
3. **`SKILL.md` — Frontmatter** (Change 1): Isolated to lines 1–5; apply before touching the body to keep diffs clean.
4. **`SKILL.md` — Reference block + Step 2 + Step 6** (Changes 2 and 4 combined): These edits are adjacent and interdependent — removing per-step repetitions while adding the surfaced reference block should be done in one pass to avoid inconsistency.
5. **`SKILL.md` — Step 3 path inline** (Change 4): Single-line change; apply after the Step 2/6 edits to avoid re-reading the file twice.
6. **`SKILL.md` — Step 5 requirements gathering** (Change 3): Standalone body replacement; apply last since it has no dependencies on the other SKILL.md changes.

---

## Verification

After applying changes:

- [ ] `SKILL.md` frontmatter contains `license: Apache-2.0` and the updated description with input shape
- [ ] `SKILL.md` has exactly one pointer to `references/refactor-protocol.md` in the Workflow section intro (not inside Steps 2 or 6)
- [ ] `SKILL.md` names `references/anthropic-best-practices.md` explicitly with when-to-read guidance in the Workflow section intro
- [ ] `SKILL.md` Step 5 lists all three questions explicitly (or references the exact protocol section) — "up to 3 questions" phrasing is gone
- [ ] `SKILL.md` Step 3 includes the literal path `temp/<skill-name>/refactor/review-summary.md` inline
- [ ] `references/refactor-protocol.md` has a Contents section listing all 9 sections immediately after the opening paragraph
- [ ] `references/anthropic-best-practices.md` has a Contents section listing all 8 sections immediately after the source line
- [ ] No new files created; no existing sections deleted
- [ ] Run `bash scripts/lint-markdown.sh skills/occ-skill-refactor/SKILL.md skills/occ-skill-refactor/references/refactor-protocol.md skills/occ-skill-refactor/references/anthropic-best-practices.md` — no errors
