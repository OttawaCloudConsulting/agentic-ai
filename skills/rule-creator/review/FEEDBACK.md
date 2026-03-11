# Feedback: rule-creator

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/rule-creator/

---

## Critique Review — Internal Quality Standards

### Findings

- **Line 3 — Description missing negative triggers**: The description covers "create a rule, write best practices, add a new rule file, or generate coding guidelines" but does not exclude adjacent uses. A user asking to *audit existing rules* or *list current rules* could plausibly trigger this skill. No negative trigger is present.
- **Lines 43–58 — Degrees of freedom mismatch (low risk)**: The section type lists for "Infrastructure best practices" and "Behavioral/process rules" are prescriptive enumerations of section names. These are advisory, not fragile, so enumerating them verbosely adds token cost without narrowing the task meaningfully. A one-line summary with "see `references/rule-format.md`" would suffice since that reference already exists.
- **Lines 66–76 — Step 4 partially duplicates `references/rule-format.md`**: The format instructions ("H1 title, Blockquote one-line description, H2 sections separated by `---`, Code examples, Bad Practices table, Terse imperative style") repeat what the reference file is supposed to contain. This violates the "information lives in either SKILL.md or references — not both" constraint. These lines should be replaced with a pointer: "Write following `references/rule-format.md` exactly."
- **Lines 79–88 — Step 5 partially duplicates `references/doc-format.md`**: Same issue as Step 4. The bullet list of doc format requirements (Metadata header, Core Principle, Overview paragraph, etc.) belongs in `references/doc-format.md`, not inlined here.
- **Lines 113–124 — Example section is thorough but verbose**: The example restates the workflow steps verbatim with numbered sub-items. The numbered sub-items in the example mirror the workflow steps above almost exactly. This doubles the token cost for content already present. The example could be compressed to trigger + key decisions + output files only.
- **Line 36 — Grep command inline in prose**: `grep -r "pattern" src/` as an inline placeholder adds noise without value — it's not an actual command. Remove or replace with a meaningful example relevant to rule creation.
- **Line 102 — Lint step**: `bash scripts/lint-markdown.sh` on all created/modified files is correct and specific. No issue here.
- **Lines 128–134 — Error Handling table**: Well-structured with concrete recovery actions. The `references/rule-format.md` missing case correctly stops rather than silently continuing. No issues.
- **Progressive disclosure**: SKILL.md is 140 lines — well under the 500-line limit. The two reference files (`rule-format.md`, `doc-format.md`) are linked with clear "when to read" guidance (Steps 3, 4, 5). Tier structure is correct.
- **Forbidden files**: No README.md, CHANGELOG.md, LICENSE.txt, or INSTALLATION_GUIDE.md present. Clean.

### What Works Well

- SKILL.md is well within the 500-line limit (140 lines).
- Reference files are linked with explicit, step-specific "when to read" guidance — not vague "see references/".
- Error handling table is complete: covers lint failures, missing catalog, missing references, ambiguous requirements, and overlap with existing rules.
- Step 1 skip logic ("If the user has already provided clear answers...") correctly reduces unnecessary questions.
- Step 6 catalog update has a graceful fallback for missing or unexpected structure.
- Workflow is sequential with clear named steps — easy to follow.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Naming conventions**: Folder is `rule-creator` (kebab-case, lowercase). `name` field is `rule-creator`. `SKILL.md` filename is correct. No reserved prefixes (`claude`, `anthropic`). All naming conventions pass.
- **Frontmatter — missing negative triggers (should-fix)**: The description does not include a negative trigger. The skill is narrow (only creates new rules), but the trigger phrases "write best practices" and "generate coding guidelines" could match requests to review, audit, or refactor existing rules. Add: "Do NOT use for auditing or reviewing existing rules."
- **Frontmatter — trigger phrases present (passes)**: The description includes "create a rule", "write best practices", "add a new rule file", "generate coding guidelines" — these are phrases users would actually say.
- **Frontmatter — description length**: Description is approximately 220 characters, well under the 1024-character limit.
- **Frontmatter — no XML angle brackets**: Confirmed absent.
- **Trigger quality — over-trigger risk (medium)**: "write best practices" is a broad phrase. A user asking to "write best practices for reviewing PRs" (not a new rule file) could trigger this skill. The negative trigger gap compounds this.
- **Trigger quality — under-trigger risk (low)**: The four trigger phrases cover the realistic invocation space well. Users asking to create a rule will use at least one of these phrases.
- **Progressive disclosure — correct tier structure**: Frontmatter ~100 words, body ~140 lines, reference files loaded conditionally. Passes.
- **Instruction quality — Steps 4 and 5 inline format specs that belong in references (should-fix)**: See Critique findings on lines 66–76 and 79–88. This reduces actionability slightly — the instruction says "follow exactly" but then also partially describes what's in the reference, creating potential for the inlined summary to drift from the actual reference content.
- **Instruction quality — Step 2 Grep command is a placeholder (nice-to-have)**: `grep -r "pattern" src/` is not actionable. A more realistic example (e.g., `grep -r "error handling" rules/`) would be more useful.
- **Error handling — complete and actionable (passes)**: All five failure modes have specific recovery instructions. The "stop and report" on missing reference files is appropriately strict.
- **Examples — present and illustrative (passes)**: The Go best practices example walks through all 8 steps with concrete decisions. It demonstrates skipping questions, checking for overlap, and running lint.
- **File conventions — no forbidden files (passes)**: Only SKILL.md and two reference files present.
- **`disable-model-invocation` field**: Not present. For a skill that should be explicitly invoked (interactive interview workflow), adding `disable-model-invocation: true` would prevent unwanted auto-triggering. The occ-skill-creator uses this for the same reason.
- **`license` field**: Not present. Optional, but the repo uses MIT/Apache-2.0 — consider adding for consistency.

### What Works Well

- Naming conventions are fully compliant.
- Description includes concrete trigger phrases users would actually say.
- Description is concise and within character limits.
- Progressive disclosure is implemented correctly.
- Error handling section covers all critical failure modes with specific recovery actions.
- The example section demonstrates the core use case end-to-end.

---

## Compiled Findings

### Critical Issues

None. The skill has no blockers that would prevent it from functioning or being published.

### Improvements

1. **Add negative trigger to description** (lines 1–4): Prevent over-triggering on audit/review requests. Add "Do NOT use for auditing or reviewing existing rules" to the description. This addresses the medium over-trigger risk from broad phrases like "write best practices."

2. **Remove inlined format specs from Steps 4 and 5** (lines 66–76, 79–88): The bullet lists describing rule and doc file formats duplicate content that belongs exclusively in `references/rule-format.md` and `references/doc-format.md`. Replace with single-line pointers to those files. Eliminates duplicate content and reduces SKILL.md by ~15 lines.

3. **Add `disable-model-invocation: true` to frontmatter**: This skill involves an interactive interview (Step 1) and should not auto-trigger mid-session. The occ-skill-creator uses this field for the same reason. Without it, the skill may be invoked unexpectedly when a user discusses rule-writing in passing.

4. **Compress the Example section** (lines 113–124): The step-by-step breakdown in the example mirrors the workflow above. Reduce to: trigger phrase, key decisions made (skipped questions, found no overlap), output files. Target ~5 lines instead of 12.

### Minor Notes

- Line 36: Replace `grep -r "pattern" src/` with a realistic example relevant to rule-searching (e.g., `grep -r "error handling" rules/`).
- Consider adding `license: MIT` to frontmatter for consistency with other skills in the repo.
- The section-type enumerations in Step 3 (lines 43–58) could be moved to `references/rule-format.md` as section planning guidance, keeping Step 3 to a 2-line pointer. Low priority given the skill is already concise.

---

## Prioritized Action Items

1. Add negative trigger to frontmatter description — addresses medium over-trigger risk with minimal effort.
2. Add `disable-model-invocation: true` to frontmatter — prevents unexpected auto-invocation of an interactive workflow.
3. Remove inlined format specs from Steps 4 and 5, replace with single-line references — eliminates duplicate content, enforces single-source-of-truth.
4. Compress Example section — reduces redundancy with the workflow above.
5. Replace placeholder Grep command on line 36 with a realistic example.
6. (Optional) Add `license: MIT` to frontmatter.
7. (Optional) Move Step 3 section-type enumerations to `references/rule-format.md`.
