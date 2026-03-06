# Implementation Plan: occ-skill-creator

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | `references/anthropic-best-practices.md` | Add table of contents (198 lines, violates own >100-line standard) | P1 |
| 2 | `references/refactor-protocol.md` | Add table of contents (337 lines, same violation) | P1 |
| 3 | `SKILL.md` | Update frontmatter description to include "when to invoke" scenario signals | P1 |
| 4 | `SKILL.md` | Elevate "Test scripts by running them" to a standalone warning before sub-bullets | P1 |
| 5 | `SKILL.md` | Add pointer in Step 3 "Write SKILL.md" to description field quality criteria | P1 |
| 6 | `SKILL.md` | Add decline path to Step 4 (one line) | P2 |
| 7 | `SKILL.md` | Expand Example section to show a complete SKILL.md body | P2 |
| 8 | `SKILL.md` | Condense Reference Organization Patterns 2 and 3 into a note under Pattern 1 | P2 |
| 9 | `SKILL.md` | Cut introductory marketing sentence (line 12) | P2 |
| 10 | `SKILL.md` | Add line count reminder in Step 3 "Write SKILL.md" | P2 |

---

## Detailed Changes

### references/anthropic-best-practices.md

#### Change 1 — Add table of contents [P1]

**Location**: Top of file, after line 6 (after the `---` separator), before line 9 (`## Naming Rules`)

**Current**: File opens directly with `## Naming Rules` after the intro block.

**Add** (insert between line 7 `---` and line 9 `## Naming Rules`):

```markdown
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

**Reason**: The file is 198 lines, exceeding the >100-line threshold that this skill's own standard (SKILL.md line 128) requires a table of contents for — a self-contradicting defect.

---

### references/refactor-protocol.md

#### Change 2 — Add table of contents [P1]

**Location**: Top of file, after line 5 (after the `---` separator), before line 7 (`## Stage Overview`)

**Current**: File opens directly with `## Stage Overview` after the intro block.

**Add** (insert between line 5 `---` and line 7 `## Stage Overview`):

```markdown
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

**Reason**: The file is 337 lines, far exceeding the >100-line threshold. Same self-contradiction as Change 1.

---

### SKILL.md

#### Change 3 — Update frontmatter description to include "when to invoke" signals [P1]

**Location**: Lines 3–5 (frontmatter `description` field)

**Current**:
```yaml
description: >-
  Guide for creating effective skills. Covers the full lifecycle: creation,
  structured review, and iteration. Invoke explicitly with /occ-skill-creator.
```

**Replace with**:
```yaml
description: >-
  Guide for creating effective skills. Use when building a new Claude skill,
  packaging a domain workflow as a reusable skill bundle, or formalizing a
  repeated procedure. Covers the full lifecycle: creation, structured review,
  and iteration. Invoke explicitly with /occ-skill-creator.
```

**Reason**: The current description tells users how to invoke the skill but not when. Users who have never seen this skill cannot self-identify when it is relevant. Adding scenario signals ("when building a new Claude skill", "packaging a domain workflow") addresses the PARTIAL FAIL on trigger quality.

---

#### Change 4 — Cut introductory marketing sentence [P2]

**Location**: Line 12

**Current**:
```markdown
Create skills -- modular packages that extend Claude with specialized knowledge, workflows, and tools. Skills transform Claude from a general-purpose agent into a domain specialist equipped with procedural knowledge no model fully possesses.
```

**Replace with**:
```markdown
Create skills -- modular packages that extend Claude with specialized knowledge, workflows, and tools.
```

**Reason**: The second sentence ("Skills transform Claude from a general-purpose agent...") is marketing prose with no instructional value. The first sentence is sufficient.

---

#### Change 5 — Condense Reference Organization Patterns 2 and 3 [P2]

**Location**: Lines 99–123 (Patterns 2 and 3, including their directory trees and prose)

**Current**:
```markdown
**Pattern 2: Domain-specific organization**

```text
skill-name/
├── SKILL.md (overview and navigation)
└── references/
    ├── finance.md
    ├── sales.md
    └── product.md
```

User asks about sales metrics -- Claude only reads `sales.md`.

**Pattern 3: Variant-specific organization**

```text
cloud-deploy/
├── SKILL.md (workflow + provider selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

User chooses AWS -- Claude only reads `aws.md`.
```

**Replace with**:
```markdown
Split by domain (`finance.md`, `sales.md`) or variant (`aws.md`, `gcp.md`) when sub-topics are independent and a user request will only ever need one.
```

**Reason**: Patterns 2 and 3 illustrate the same principle as Pattern 1 with different split axes. The distinction is captured in one sentence. Saves approximately 20 lines.

---

#### Change 6 — Elevate script testing to a standalone warning in Step 3 [P1]

**Location**: Lines 150–159 (Step 3 "Build the Skill")

**Current**:
```markdown
### 3. Build the Skill

1. Create the skill directory structure
2. Implement scripts, references, and assets identified in step 2
3. Test scripts by running them
4. Write SKILL.md:
   - Frontmatter with clear `name` and `description` (include trigger phrases)
   - Body with workflow guidance and references to bundled resources
   - Use imperative/infinitive form throughout
5. Delete any unused directories
```

**Replace with**:
```markdown
### 3. Build the Skill

1. Create the skill directory structure
2. Implement scripts, references, and assets identified in step 2

> **Before writing SKILL.md:** Test every script by running it. Do not document broken scripts. A script that fails during testing must be fixed before proceeding.

3. Write SKILL.md:
   - Frontmatter with clear `name` and `description` — for description field quality criteria, see `references/anthropic-best-practices.md` Frontmatter Requirements and Trigger Quality Checklist sections
   - Body with workflow guidance and references to bundled resources
   - Use imperative/infinitive form throughout
   - Verify SKILL.md stays under 500 lines; move overflow to `references/`
4. Delete any unused directories
```

**Reason**: Addresses two issues at once. (a) Script testing is a low-freedom constraint (exact sequence, must happen before SKILL.md) buried as a peer bullet to high-freedom items — elevating it to a blockquote warning makes it unambiguous. (b) Adds the description field quality pointer (see FEEDBACK.md improvement #2) and the 500-line check reinforcement (see FEEDBACK.md improvement note on line 65) at the point of action.

---

#### Change 7 — Add decline path to Step 4 [P2]

**Location**: Lines 167–171 (Step 4 "Refactor Review")

**Current**:
```markdown
### 4. Refactor Review

Run a structured review before finalizing. See `references/refactor-protocol.md` for the full protocol including sub-agent prompt templates, output formats, and approval gates.

In short: launch parallel critique and red-team agents, compile feedback, get user approval, then apply approved changes.
```

**Replace with**:
```markdown
### 4. Refactor Review

Run a structured review before finalizing. See `references/refactor-protocol.md` for the full protocol including sub-agent prompt templates, output formats, and approval gates.

In short: launch parallel critique and red-team agents, compile feedback, get user approval, then apply approved changes. If the user declines, log the decision in `decisions.md` and proceed to Step 5 without changes.
```

**Reason**: The happy path (approve → apply) is documented but the decline path is only in refactor-protocol.md. Adding one sentence to the summary removes a gap in the SKILL.md step description without requiring readers to consult the reference for this case.

---

#### Change 8 — Expand Example section to show a complete SKILL.md body [P2]

**Location**: Lines 216–241 (Example section)

**Current**:
```markdown
## Example

User says: "Create a skill for rotating PDF pages."

Result:

```text
pdf-rotator/
├── SKILL.md
└── scripts/
    └── rotate.py
```

Frontmatter:

```yaml
---
name: pdf-rotator
description: >-
  Rotate pages in PDF files. Use when users say "rotate PDF", "turn PDF pages",
  "fix PDF orientation", or need to change page rotation in a PDF document.
---
```

Body covers: reading the input PDF, selecting pages, calling `scripts/rotate.py`, verifying output. Scripts handle the deterministic rotation logic. No references needed for a focused, single-purpose skill.
```

**Replace with**:
```markdown
## Example

User says: "Create a skill for rotating PDF pages."

Result:

```text
pdf-rotator/
├── SKILL.md
└── scripts/
    └── rotate.py
```

**SKILL.md** (complete):

```markdown
---
name: pdf-rotator
description: >-
  Rotate pages in PDF files. Use when users say "rotate PDF", "turn PDF pages",
  "fix PDF orientation", or need to change page rotation in a PDF document.
---

# PDF Rotator

Rotate one or more pages in a PDF file.

## Critical Constraints

- Input file must be a valid PDF. Encrypted PDFs are not supported.
- Rotation values must be multiples of 90 (0, 90, 180, 270).

## Usage

1. Confirm the input file path and target pages with the user.
2. Confirm the rotation angle (90, 180, or 270 degrees).
3. Run: `python scripts/rotate.py --input <file> --pages <range> --degrees <angle>`
4. Verify output by opening the result file.

## Troubleshooting

| Problem | Response |
|---|---|
| Script errors "not a valid PDF" | Confirm file is not encrypted or corrupted. |
| Wrong pages rotated | Re-confirm page range with user (1-indexed). |
```
```

**Reason**: The current example shows only frontmatter and a one-line body summary. A reader cannot calibrate what good body content looks like from a summary. The complete example above is short, realistic, and demonstrates: Critical Constraints section, numbered workflow steps, script invocation pattern, and Troubleshooting table — all elements the skill instructs creators to include.

---

## Implementation Order

1. **Change 1** (ToC in anthropic-best-practices.md) — fix the self-contradiction first; it is the highest-severity finding and unblocks all downstream validation.
2. **Change 2** (ToC in refactor-protocol.md) — same class of defect, fix in the same pass.
3. **Change 3** (frontmatter description) — high-visibility change; the description is the first thing any user reads. Fixing "when to invoke" improves discoverability immediately.
4. **Change 6** (script testing warning + description pointer + 500-line check in Step 3) — combines three related Step 3 improvements into one edit; do together to avoid multiple passes over the same section.
5. **Change 7** (decline path in Step 4) — one-line addition; quick and low-risk.
6. **Change 4** (cut marketing sentence) — straightforward deletion; apply before the example rework to reduce noise.
7. **Change 5** (condense Patterns 2 and 3) — restructures the Reference Organization section; verify line count after.
8. **Change 8** (expand Example) — most content-intensive change; do last so the earlier edits have stabilized the line count budget.
9. **Check total line count** — verify SKILL.md stays under 500 lines after all changes. Changes 4, 5 reduce count; Change 8 increases it. Net should be neutral or slightly shorter.

---

## Verification

After applying changes:

- [ ] `references/anthropic-best-practices.md` has a table of contents immediately after the opening `---` separator.
- [ ] `references/refactor-protocol.md` has a table of contents immediately after the opening `---` separator.
- [ ] ToC entries match actual heading text in each file exactly (case-sensitive).
- [ ] `SKILL.md` frontmatter description contains at least one "when to use" scenario phrase (not just "invoke with /occ-skill-creator").
- [ ] Line 12 marketing sentence is removed; introductory line is a single sentence.
- [ ] Step 3 contains a blockquote warning before the "Write SKILL.md" sub-step, not a peer bullet.
- [ ] Step 3 "Write SKILL.md" bullet references `references/anthropic-best-practices.md` Frontmatter Requirements section explicitly.
- [ ] Step 3 "Write SKILL.md" bullet includes a 500-line check instruction.
- [ ] Step 4 summary sentence includes the decline path ("If the user declines...").
- [ ] Reference Organization Patterns section contains only one named pattern; domain/variant split axes are described in prose, not separate headings with directory trees.
- [ ] Example section shows a complete SKILL.md body (not a summary).
- [ ] `SKILL.md` total line count is under 500.
- [ ] Run `bash scripts/lint-markdown.sh skills/occ-skill-creator/SKILL.md` — no errors.
- [ ] Run `bash scripts/lint-markdown.sh skills/occ-skill-creator/references/anthropic-best-practices.md` — no errors.
- [ ] Run `bash scripts/lint-markdown.sh skills/occ-skill-creator/references/refactor-protocol.md` — no errors.
