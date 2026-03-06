# Implementation Plan: create-prd

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | SKILL.md | Add negative triggers to frontmatter description | P1 |
| 2 | SKILL.md | Remove inline architecture interview areas from Step 3 (lines 73–79) | P1 |
| 3 | SKILL.md | Add missing-assets failure mode to Error Handling | P2 |
| 4 | SKILL.md | Add first-person user-facing phrases to frontmatter description | P2 |
| 5 | SKILL.md | Tighten Step 4 cross-reference sub-lists | P3 |

---

## Detailed Changes

### SKILL.md

#### Change 1 — Add negative triggers to frontmatter description [P1]

**Location**: Line 3 / `description` field in YAML frontmatter

**Current**:
```
description: Create a PRD, architecture document, and progress file for a new project through guided interview. Use when starting a new project, planning a new feature, writing requirements, scoping a project, or creating project documentation from scratch.
```

**Replace with**:
```
description: Create a PRD, architecture document, and progress file for a new project through guided interview. Use when starting a new project, planning a new feature, writing requirements, scoping a project, or creating project documentation from scratch. Phrases like "I want to plan a new project" or "help me write requirements for" are good triggers. Do NOT use for updating an existing PRD, documenting changes to an existing system, writing a technical design doc for an in-progress change, or starting implementation.
```

**Reason**: Two confirmed false positives from benchmark testing (PRD updates and existing-system design docs) are directly addressed by explicit exclusions; first-person phrases improve user recognition when scanning command lists.

---

#### Change 2 — Remove inline architecture interview areas from Step 3 [P1]

**Location**: Lines 71–79 / Step 3 body (the inline bullet list after "covering these areas from the interview guide:")

**Current**:
```
Use Bash (`mkdir -p docs`) to ensure `docs/` exists. Conduct a focused interview using
`AskUserQuestion` covering these areas from the interview guide:

- Architecture Decisions (always)
- Component Design (always)
- File Organization (always for multi-file projects; skip for single-file scripts)
- Deployment Workflow (include when deployment is non-trivial)
- Risks and External Dependencies (include when external coupling exists)
- Security Review (always)

Use the Write tool to create `docs/ARCHITECTURE_AND_DESIGN.md`.
```

**Replace with**:
```
Use Bash (`mkdir -p docs`) to ensure `docs/` exists. Conduct a focused interview using
`AskUserQuestion` covering all areas from the interview guide.

Use the Write tool to create `docs/ARCHITECTURE_AND_DESIGN.md`.
```

**Reason**: The six areas are already defined in `references/interview-guide.md` (referenced on line 67); duplicating them here violates the "information lives in either SKILL.md or references, not both" principle and creates two sources of truth.

---

#### Change 3 — Add missing-assets failure mode to Error Handling [P2]

**Location**: Lines 152–162 / `## Error Handling` section — append a new bullet after the last entry

**Current** (last entry in the section):
```
- **User wants to skip a round:** Allow it. Record the skipped round in prd.md as a comment so a
  future session can revisit it.
```

**Add after**:
```
- **Missing asset templates:** If any `assets/` file is absent (`prd-template.md`,
  `architecture-template.md`, `progress-template.txt`), do not silently fail. Notify the user
  which file is missing and construct the document from scratch using the section structure
  described in the relevant step. State that no template was used.
```

**Reason**: A consuming project that installs only `SKILL.md` and `references/` without `assets/` currently produces a silent failure; this makes the fallback behavior explicit and recoverable.

---

#### Change 4 — Add first-person user-facing phrases to frontmatter description [P2]

This change is folded into Change 1 above. The replacement text for Change 1 already includes the phrases "I want to plan a new project" and "help me write requirements for". No separate edit needed.

---

#### Change 5 — Tighten Step 4 cross-reference sub-lists [P3]

**Location**: Lines 89–99 / Step 4 body

**Current**:
```
Read `prd.md` and `docs/ARCHITECTURE_AND_DESIGN.md`. First verify structural consistency:

- Component names in the PRD Architecture section match the Component Inventory table
- Configuration parameter names are identical in both documents
- Feature titles referenced in the architecture doc match the PRD Features section

Then identify content to propagate back to the PRD:

- New features discovered during architecture design (logging, security hardening, conditional components)
- Refined acceptance criteria based on architecture decisions
- Updated configuration and output tables
```

**Replace with**:
```
Read `prd.md` and `docs/ARCHITECTURE_AND_DESIGN.md`. Verify structural consistency: component
names, configuration parameter names, and feature titles must match exactly across both documents.

Then propagate back to the PRD any new features discovered during architecture design, refined
acceptance criteria, and updated configuration or output tables.
```

**Reason**: Collapses two sub-lists into prose; the specific examples (logging, security hardening, conditional components) were illustrative rather than prescriptive and read as a fixed enumeration — guidance-level intent is preserved without encoding it as a checklist.

---

## Implementation Order

1. **Change 2 first** (remove Step 3 inline list) — standalone deletion with no dependencies; eliminates the duplicate-content violation before any new content is added.
2. **Change 1** (frontmatter description with negative triggers and user phrases) — self-contained frontmatter edit; no dependencies on other changes.
3. **Change 3** (add missing-assets error handling entry) — appends to Error Handling; no dependencies.
4. **Change 5** (tighten Step 4 sub-lists) — prose rewrite of an existing section; no dependencies.

Change 4 is already incorporated into Change 1 and requires no separate step.

---

## Verification

After applying changes:

- [ ] SKILL.md frontmatter `description` contains at least one explicit "Do NOT use for" exclusion covering PRD updates and existing-system documentation
- [ ] SKILL.md frontmatter `description` contains at least one first-person user phrase
- [ ] Lines formerly containing the six architecture interview areas (Architecture Decisions, Component Design, File Organization, Deployment Workflow, Risks and External Dependencies, Security Review) are gone from SKILL.md body
- [ ] Step 3 still retains the `Read references/interview-guide.md` instruction on the line before the removed list
- [ ] Error Handling section contains a bullet for missing asset templates with a documented fallback behavior
- [ ] Step 4 no longer contains two separate sub-lists; content is expressed as prose or a single condensed list
- [ ] SKILL.md remains under 500 lines
- [ ] No content was added to `references/interview-guide.md` — all changes are SKILL.md only
