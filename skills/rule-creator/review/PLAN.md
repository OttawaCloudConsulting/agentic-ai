# Implementation Plan: rule-creator

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | SKILL.md | Add negative trigger to frontmatter description | P1 |
| 2 | SKILL.md | Add `disable-model-invocation: true` to frontmatter | P1 |
| 3 | SKILL.md | Remove inlined format bullets from Step 4 (lines 70–75) | P1 |
| 4 | SKILL.md | Remove inlined format bullets from Step 5 (lines 83–88) | P1 |
| 5 | SKILL.md | Replace placeholder Grep command in Step 2 (line 36) | P2 |
| 6 | SKILL.md | Compress Example section (lines 117–124) | P2 |
| 7 | SKILL.md | Add `license: MIT` to frontmatter | P3 |
| 8 | SKILL.md | Move Step 3 section-type enumerations to reference pointer | P3 |

---

## Detailed Changes

### SKILL.md

#### Change 1 — Add negative trigger to description [P1]

**Location**: Line 3 / frontmatter `description` field

**Current**:
```
description: Generate new rules — always-on behavioral guidelines for Claude Code. Use when asked to create a rule, write best practices, add a new rule file, or generate coding guidelines. Walks through an interactive interview to produce a rule file and its documentation.
```

**Replace with**:
```
description: Generate new rules — always-on behavioral guidelines for Claude Code. Use when asked to create a rule, write best practices, add a new rule file, or generate coding guidelines. Walks through an interactive interview to produce a rule file and its documentation. Do NOT use for auditing, reviewing, or listing existing rules.
```

**Reason**: Prevents over-triggering on audit/review requests from broad phrases like "write best practices".

---

#### Change 2 — Add `disable-model-invocation: true` to frontmatter [P1]

**Location**: Lines 1–4 / frontmatter block

**Current**:
```
---
name: rule-creator
description: Generate new rules — ...
---
```

**Replace with**:
```
---
name: rule-creator
description: Generate new rules — ...
disable-model-invocation: true
---
```

**Reason**: The skill starts with an interactive interview (Step 1) and must not auto-trigger mid-session when a user discusses rule-writing in passing.

---

#### Change 3 — Remove inlined format spec from Step 4 [P1]

**Location**: Lines 70–75 / Step 4 — Generate Rule

**Current**:
```
Follow the format patterns in `references/rule-format.md` exactly:

- H1 title
- Blockquote one-line description
- H2 sections separated by `---`
- Code examples where they add clarity
- Bad Practices table for infrastructure rules
- Terse, imperative style throughout
```

**Replace with**:
```
Follow `references/rule-format.md` exactly.
```

**Reason**: These bullets duplicate content that lives in the reference file, violating single-source-of-truth and risking drift.

---

#### Change 4 — Remove inlined format spec from Step 5 [P1]

**Location**: Lines 83–88 / Step 5 — Generate Documentation

**Current**:
```
Follow the format patterns in `references/doc-format.md` exactly:

- Metadata header (Source, Scope, Activation)
- Core Principle
- Overview paragraph
- Sections (summarized, not duplicated from rule)
- Bad Practices table (copied from rule)
- Related Rules
```

**Replace with**:
```
Follow `references/doc-format.md` exactly.
```

**Reason**: Same as Change 3 — these bullets duplicate the reference file and will drift if the reference is updated.

---

#### Change 5 — Replace placeholder Grep command in Step 2 [P2]

**Location**: Line 36 / Step 2 — Research, bullet 2

**Current**:
```
2. If the user has a codebase with examples, use Grep to search for configuration files, naming patterns, and recurring idioms (e.g., `grep -r "pattern" src/`). Look for: repeated boilerplate, inconsistent conventions, inline TODOs about best practices, and error-handling patterns
```

**Replace with**:
```
2. If the user has a codebase with examples, use Grep to search for configuration files, naming patterns, and recurring idioms (e.g., `grep -r "error handling" rules/`). Look for: repeated boilerplate, inconsistent conventions, inline TODOs about best practices, and error-handling patterns
```

**Reason**: `grep -r "pattern" src/` is a non-actionable placeholder; a domain-relevant example is more instructive.

---

#### Change 6 — Compress Example section [P2]

**Location**: Lines 117–124 / Example section, numbered breakdown

**Current**:
```
1. **Step 1** — Skip Topic (Go) and Key concerns (error handling, naming) since the user provided them. Ask Rule type and Audience only.
2. **Step 2** — Grep `rules/` for existing Go rules. Find none. Boundary is clear.
3. **Step 3** — Plan sections: Error Handling, Naming Conventions, Testing, Bad Practices. Present outline to user.
4. **Step 4** — Write `rules/go-best-practices.md` following infrastructure pattern from `references/rule-format.md`.
5. **Step 5** — Write `docs/rules/go-best-practices.md` following `references/doc-format.md`.
6. **Step 6** — Update `docs/RULES.md` catalog.
7. **Step 7** — Run `bash scripts/lint-markdown.sh rules/go-best-practices.md docs/rules/go-best-practices.md`. Fix issues.
8. **Step 8** — Report: 2 files created, 4 sections, consumption command.
```

**Replace with**:
```
- **Trigger**: "Create a rule for Go best practices focused on error handling and naming."
- **Key decisions**: Topic and concerns already provided — skip those Step 1 questions. No existing Go rules found — boundary clear. Infrastructure-type rule selected.
- **Output**: `rules/go-best-practices.md`, `docs/rules/go-best-practices.md`, catalog updated.
```

**Reason**: The numbered breakdown mirrors the workflow steps almost verbatim, doubling token cost for no added information.

---

#### Change 7 — Add `license: MIT` to frontmatter [P3]

**Location**: Lines 1–4 / frontmatter block (applied after Change 2)

**Current** (after Change 2):
```
---
name: rule-creator
description: ...
disable-model-invocation: true
---
```

**Replace with**:
```
---
name: rule-creator
description: ...
disable-model-invocation: true
license: MIT
---
```

**Reason**: Consistency with other skills in the repo that carry license metadata.

---

#### Change 8 — Compress Step 3 section-type enumerations [P3]

**Location**: Lines 43–61 / Step 3 — Draft Sections

**Current**:
```
Based on the rule type, plan sections. For structural patterns, read `references/rule-format.md`.

**Infrastructure best practices** typically include:

- Core design principles (construct/module/resource design)
- Architecture and organization
- Security
- Naming conventions
- Testing and validation
- Deployment safety
- Bad Practices table
- Monitoring/observability
- Project hygiene

**Behavioral/process rules** typically include:

- Core principle (one-sentence thesis)
- Concrete protocols with structured templates
- Boundary conditions (when to apply, when not to)
- Failure modes and countermeasures

Present the planned section outline to the user via AskUserQuestion: "Here's the planned structure. Add, remove, or reorder sections?"
```

**Replace with**:
```
Based on the rule type, plan sections using the section-type guidance in `references/rule-format.md`.

Present the planned section outline to the user via AskUserQuestion: "Here's the planned structure. Add, remove, or reorder sections?"
```

**Reason**: The enumerations are advisory and already duplicated in the reference file; a pointer keeps SKILL.md terse and `rule-format.md` as the single source.

---

## Implementation Order

1. **Changes 3 and 4 first** — remove inlined format specs from Steps 4 and 5. These are the highest-impact single-source-of-truth violations and shrink the file before other edits.
2. **Changes 1 and 2** — update frontmatter description and add `disable-model-invocation`. These are independent of body edits and set the correct invocation behavior.
3. **Change 5** — replace placeholder Grep command. Simple line edit with no dependencies.
4. **Change 6** — compress Example section. Depends on no other changes but reads more naturally after the workflow steps are already simplified.
5. **Change 8** — compress Step 3 enumerations. Low priority; do last among body edits since it requires verifying `references/rule-format.md` already contains equivalent section guidance.
6. **Change 7** — add `license: MIT` to frontmatter. Purely additive, no order dependency.

---

## Verification

After applying changes:

- [ ] Frontmatter contains `disable-model-invocation: true`
- [ ] Frontmatter description ends with a negative trigger sentence
- [ ] Step 4 body contains no bullet list — only a single-line pointer to `references/rule-format.md`
- [ ] Step 5 body contains no bullet list — only a single-line pointer to `references/doc-format.md`
- [ ] Line 36 Grep example uses a meaningful pattern (not `"pattern" src/`)
- [ ] Example section is 3–5 lines (trigger, decisions, outputs) with no numbered workflow recap
- [ ] `references/rule-format.md` contains section-type guidance before Change 8 is applied to Step 3
- [ ] Run `bash scripts/lint-markdown.sh skills/rule-creator/SKILL.md` — no errors
- [ ] Final SKILL.md line count is under 120 (down from 140 after removals)
