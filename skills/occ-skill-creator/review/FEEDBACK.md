# Feedback: occ-skill-creator

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol (self-review)
**Reviewed path**: skills/occ-skill-creator/

---

## Critique Review — Internal Quality Standards

### Findings

- **[Line 12] Introductory paragraph is borderline justifiable.** "Skills transform Claude from a general-purpose agent into a domain specialist equipped with procedural knowledge no model fully possesses" is marketing prose, not instruction. It adds no actionable guidance and can be cut entirely.

- **[Lines 20-34] "Core Principles" section names match "Concise is Key", "Degrees of Freedom", "Progressive Disclosure" — but these headers exist primarily to mirror the evaluation rubric, not to serve the person creating a skill.** The content under each is correct, but the framing is inward-looking. A creator needs to know *how to apply* these principles, not that they exist. The Degrees of Freedom table (lines 32-34) is actionable and should stay; the prose framing around it could be trimmed.

- **[Lines 86-128] Reference Organization Patterns section has redundancy.** Patterns 1, 2, and 3 each illustrate the same underlying concept — "split content into reference files by concern." Pattern 1 is sufficient. Patterns 2 and 3 add specificity (domain, variant) but could be collapsed into a single paragraph with examples rather than three fully elaborated headings and directory trees.

- **[Lines 160-165] Step 3 instruction #4 (Write SKILL.md) lists five sub-bullets without examples.** This is the most fragile part of skill creation — writing good frontmatter — yet the guidance is abstract. The description field quality is critical to triggering and is treated in one line ("include trigger phrases"). Compare to how `references/anthropic-best-practices.md` elaborates the description field with red flags, checklists, and character limits. The SKILL.md body under-serves this step.

- **[Lines 167-171] Refactor review step (Step 4) defers everything to references/refactor-protocol.md.** This is correct progressive disclosure. No issue here.

- **[Lines 177-215] Workflow Patterns section is well-matched to task fragility.** Sequential and conditional workflow examples use pseudocode/markdown — appropriate medium freedom. Good.

- **[Lines 207-214] Troubleshooting table is lean and actionable.** Each row has a concrete response. No issues.

- **[Lines 216-241] Example section is thin.** The PDF rotator example shows structure and frontmatter, but the body description ("Body covers: reading the input PDF...") is a summary of a body rather than the body itself. A reader cannot tell from this what good body content looks like. This is the place where showing beats telling.

- **Benchmarking gap (not documented anywhere in SKILL.md or references/).** The task prompt notes the skill claims to support benchmarking. There is no mention of benchmarking in SKILL.md, output-patterns.md, or any other reference file. If this capability is claimed, the workflow is undocumented. Either document it or remove the claim.

- **[Line 163] "references/output-patterns.md" is listed as a consultation target** for "Output formats or quality standards" but `output-patterns.md` contains only two patterns (Template Pattern, Examples Pattern) that cover generic output quality — not skill-specific output guidance. The guidance in that file is generic enough that Claude would already apply it without a reference. Marginal token cost justification.

- **Degrees of freedom mismatch — Step 3 Build the Skill (lines 153-165)** treats the creation of scripts, references, and SKILL.md as medium-freedom guidance (prose instructions). But script testing and SKILL.md frontmatter are low-freedom operations (specific sequence, specific field requirements). The critical constraint that scripts must be tested before writing SKILL.md (line 156 "Test scripts by running them") is buried as a sub-bullet — it should be a standalone warning.

### What Works Well

- Progressive disclosure is correctly implemented: frontmatter is short and accurate, SKILL.md body is 241 lines (well under 500), and references are conditional with explicit "when to read" pointers.
- The three reference files (anthropic-best-practices.md, refactor-protocol.md, output-patterns.md) are appropriately split out and referenced from SKILL.md with clear guidance on when to read each.
- Troubleshooting table is terse and actionable — exactly the right format for failure modes.
- The `disable-model-invocation: true` flag is correctly set for an interactive skill that should only be invoked explicitly.
- No forbidden files present. Directory structure is clean.
- Degrees of Freedom section correctly uses a table — right level of specificity for a concept that needs precise calibration.
- Step ordering (Understand → Plan → Build → Review → Iterate) is logical and mirrors real skill development cycles.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Naming conventions — PASS with one note.** Folder name `occ-skill-creator` is kebab-case, matches `name` field. `SKILL.md` is correctly cased. No forbidden prefixes (`claude`, `anthropic`) present. `occ-` prefix is acceptable. Note: the `name` field value `occ-skill-creator` is valid but the `occ-` prefix is organization-specific — acceptable for internal use, but limits portability if distributed.

- **Frontmatter completeness — PASS.** Required fields `name` and `description` are present. Optional `license: Apache-2.0` is correctly set. No XML angle brackets in description. `disable-model-invocation: true` is present and appropriate.

- **Description length — PASS.** Description is approximately 160 characters, well under the 1024-character limit.

- **Trigger quality — PARTIAL FAIL.** The description reads: "Guide for creating effective skills. Covers the full lifecycle: creation, structured review, and iteration. Invoke explicitly with /occ-skill-creator." Since `disable-model-invocation: true` is set, auto-triggering is disabled by design — the skill must be invoked explicitly. This is correct. However, the description does not include specific phrases a user would say to know *when* to invoke it. "Invoke explicitly with /occ-skill-creator" tells the user *how*, not *when*. A user who has never seen this skill would not know to invoke it when starting to build a skill. The description should signal the scenario: "when building a new Claude skill", "when packaging a workflow as a reusable skill", etc.

- **Negative triggers — NOT APPLICABLE.** The skill is explicitly invoked only (`disable-model-invocation: true`), so negative triggers to prevent false auto-triggering are not needed. Correct omission.

- **Progressive disclosure — PASS.** Three-tier system is correctly implemented. Reference files are conditional. SKILL.md body is 241 lines.

- **Instruction actionability — PARTIAL FAIL.** Steps 1-3 are adequately actionable for medium-freedom guidance. Step 4 (Refactor Review) appropriately defers to refactor-protocol.md. However:
  - Step 3 sub-bullet "Write SKILL.md" (line 154-158) describes what to write but not how to write a good description field. The description field is the most failure-prone part of skill creation (as anthropic-best-practices.md documents extensively) and is handled in one phrase: "include trigger phrases."
  - There is no explicit instruction to check SKILL.md line count before finalizing (the 500-line limit is mentioned in Critical Constraints at the top, but not reinforced at the point of action in Step 3).

- **Error handling — PARTIAL PASS.** The Troubleshooting table covers 5 failure modes (vague requirements, broken scripts, SKILL.md too long, conflicting feedback, unclear reference pattern). Missing failure mode: what to do if the user declines the refactor review but the skill has critical issues. The protocol says "proceed to Step 5 (Iterate)" but SKILL.md step 4 only says "get user approval, then apply approved changes" — it doesn't document the decline path for the main workflow.

- **Reference file quality — PASS with note.** `references/anthropic-best-practices.md` is 198 lines — no table of contents required (threshold is >100 lines per the best practices document itself). However, the best practices reference *does* state: "For files >100 lines, include a table of contents at the top." This file is 198 lines and has no table of contents. This is a violation of the standard the skill itself documents.

- **`references/refactor-protocol.md` — PASS with note.** 337 lines, no table of contents. Same violation as above.

- **`references/output-patterns.md` — PASS.** 87 lines, under threshold.

- **Example quality — SHOULD-FIX.** The example (lines 216-241) shows the frontmatter and structure of a PDF rotator skill. It does not show a complete SKILL.md body. Per the best practices reference: "At least one concrete example showing trigger phrase → actions → result." The example shows structure but not a full execution trace. A user reading this skill for the first time cannot see what a good SKILL.md body looks like end-to-end.

- **Critical instructions placement — PASS.** "Critical Constraints" is the first section after the introduction, containing the 500-line limit and forbidden files rules. Correct placement.

- **No `compatibility` field — ACCEPTABLE.** The skill does not depend on specific environment tools or OS. Omission is justified.

### What Works Well

- `disable-model-invocation: true` is correctly applied — this skill requires user intent to invoke and should not auto-trigger on general conversation.
- The description is honest about what the skill does (full lifecycle: creation, review, iteration) and sets correct expectations.
- Forbidden files are absent. The skill practices what it preaches.
- Reference files are each focused on a single concern (best practices, refactor protocol, output patterns) — no scope overlap between them.
- The refactor-protocol.md reference is exceptionally well-structured: sub-agent prompts, output formats, approval gates, and decisions log template are all provided. This is the strongest part of the skill bundle.

---

## Compiled Findings

### Critical Issues

1. **Missing table of contents in references/anthropic-best-practices.md (198 lines) and references/refactor-protocol.md (337 lines).** The skill's own internal standard (from SKILL.md line 128: "For files >100 lines, include a table of contents at the top") is violated by two of its own reference files. This is a self-contradicting defect.

2. **Benchmarking capability undocumented.** If the skill claims to support benchmarking, the workflow is missing entirely from SKILL.md and all reference files. Either document the workflow or remove the claim.

### Improvements

1. **Description field needs "when to invoke" context.** The current description tells users *how* to invoke (`/occ-skill-creator`) but not *when*. Add scenario signals: "Use when building a new Claude skill, packaging a domain workflow, or creating a reusable skill bundle." This helps users self-identify when the skill is relevant.

2. **Step 3 sub-step "Write SKILL.md" undersells description field quality.** The description field is the highest-failure-risk element of skill creation. The current instruction ("include trigger phrases") is insufficient. Add a pointer: "For description field quality criteria, see references/anthropic-best-practices.md — Frontmatter Requirements section."

3. **Example section should show a complete body, not just structure.** The PDF rotator example shows the frontmatter and a one-line summary of the body. It should show a short but complete SKILL.md body so users can calibrate what "good" looks like. This is the primary teaching moment in the skill.

4. **Decline path for refactor review not documented in Step 4.** Step 4 describes the happy path (approve → apply). The protocol for "user declines" exists in refactor-protocol.md but is not summarized in the SKILL.md step description. Add one line: "If the user declines, log the decision and proceed to Step 5 without changes."

5. **"Test scripts by running them" (line 156) is buried.** This is a low-freedom constraint (scripts must work before SKILL.md is written) but appears as a peer bullet to high-freedom items like "Create the skill directory structure." Elevate it with a warning note or place it before the other sub-bullets.

6. **Reference Organization Patterns section (lines 86-128) can be condensed.** Patterns 2 and 3 illustrate the same principle as Pattern 1 with different split axes. Collapse into Pattern 1 with a note: "Split by domain (finance.md, sales.md) or variant (aws.md, gcp.md) when sub-topics are independent." Save ~20 lines.

7. **Introductory paragraph (line 12) contains marketing prose.** Cut or trim "Skills transform Claude from a general-purpose agent into a domain specialist equipped with procedural knowledge no model fully possesses." It adds no instructional value.

### Minor Notes

- `references/output-patterns.md` is referenced for "Output formats or quality standards" but contains generic patterns Claude would apply without prompting. Consider whether this file earns its token cost or whether its content should be absorbed into SKILL.md directly (it's only 87 lines).
- The `occ-` prefix in the name field is correct for organizational use but worth noting in a comment if the skill is intended for external distribution.
- "Consult these guides based on the skill type" (line 161) uses a colon-then-list format that is slightly verbose. Could be: "For output format guidance see references/output-patterns.md; for naming/structure see references/anthropic-best-practices.md."

---

## Prioritized Action Items

1. Add table of contents to `references/anthropic-best-practices.md` (198 lines, violates own standard — critical self-contradiction).
2. Add table of contents to `references/refactor-protocol.md` (337 lines, same violation).
3. Update the frontmatter description to include "when to invoke" scenario signals (not just how to invoke).
4. Expand the example section to show a complete SKILL.md body, not just structure + one-line summary.
5. Add a pointer in Step 3 "Write SKILL.md" to the description field quality criteria in references/anthropic-best-practices.md.
6. Document the refactor decline path in Step 4 (one line).
7. Elevate "Test scripts by running them" in Step 3 to a standalone warning before the sub-bullets.
8. Condense Reference Organization Patterns (Patterns 2 and 3 → collapsed note under Pattern 1).
9. Cut introductory marketing sentence from line 12.
10. Evaluate whether `references/output-patterns.md` earns its place or should be absorbed inline (low priority, no correctness issue).
