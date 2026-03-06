# Feedback: occ-skill-refactor

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/occ-skill-refactor/

---

## Critique Review — Internal Quality Standards

### Findings

- **Line 3 — Description missing trigger phrases**: The description reads "Invoke explicitly with /occ-skill-refactor" but does not include specific phrases a user would say. Since `disable-model-invocation: true` is set, this is low risk for over/under-triggering, but the description still serves as documentation and should describe the input shape more clearly.
- **Line 24 — Progressive disclosure works, but reference linking is indirect**: "See `references/refactor-protocol.md` for full sub-agent prompt templates, output formats, and AskUserQuestion schemas" is acceptable, but does not distinguish between the two reference files or state when each is needed. The anthropic-best-practices reference is only mentioned implicitly (as a resource the red-team agent reads), not called out as a file the orchestrator reads.
- **Line 34-35 — Degrees of freedom mismatch (sub-agent step descriptions)**: Steps 2 describe what each agent evaluates but defer all specifics to `refactor-protocol.md`. This is appropriate high-level orchestration. However, the phrase "Read `references/refactor-protocol.md` for the prompt template" appears three times (lines 24, 34-35, 56) — once in the intro and then repeated verbatim inside each step. The intro reference renders the per-step repetitions redundant.
- **Line 44 — Compile step path inconsistency**: The compile step writes to `temp/<skill-name>/refactor/review-summary.md`, but the Example block (line 74) shows the same path. However, `decisions.md` appears in the Constraints section (line 84) as a named file without a full path — this is consistent but worth noting that the path (`temp/<skill-name>/refactor/decisions.md`) is only discoverable by reading the protocol reference.
- **Dependency on sibling skill — structural concern**: Both `references/anthropic-best-practices.md` and `references/refactor-protocol.md` exist inside `skills/occ-skill-refactor/references/`. This means the skill is self-contained when deployed to `.claude/skills/occ-skill-refactor/`. This is correct behavior. The git status shows the old `skills/skill-refactor/references/` files are deleted; the new occ-* structure owns its own copies. No dependency problem.
- **Line 43-44 — Approval gate step buries a path**: The review summary path is only shown in the Example block (line 73). Step 3 says "Present the path to the user" but doesn't show the canonical path inline. A reader following Step 3 without the Example must consult the reference to know the path.
- **Line 52 — "up to 3 questions" is weak guidance**: This phrasing leaves open whether 1 or 3 questions should be asked. The refactor-protocol.md defines them precisely; SKILL.md should either list all three questions inline or say "ask the 3 questions defined in `references/refactor-protocol.md`" to remove ambiguity.
- **No "when to read" guidance per reference file**: SKILL.md references `references/refactor-protocol.md` but never calls out `references/anthropic-best-practices.md` directly. A consumer reading only SKILL.md would not know that file exists unless they read the protocol. The Anthropic best practices file should be surfaced with explicit when-to-read guidance.

### What Works Well

- `disable-model-invocation: true` is correctly set — this skill requires explicit invocation.
- SKILL.md is 85 lines, well under the 500-line limit. Progressive disclosure is respected.
- Error handling section (lines 60-64) is concrete and covers all major failure modes.
- The Example block (lines 67-78) is clean, correct, and shows the full workflow in one glance.
- Constraints section (lines 82-84) is terse and captures the critical rules.
- Input section correctly handles the two path variants and the "no path provided" case.
- References are owned by the skill directory — no cross-skill dependency at runtime.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Naming conventions — passes**: Folder is `occ-skill-refactor` (kebab-case), `name` field matches exactly, `SKILL.md` casing is correct. No reserved prefixes.
- **Frontmatter — `description` missing negative trigger specificity (nice-to-have)**: The description includes "Do NOT use to create a new skill from scratch" which is a correct negative trigger. However, it does not mention what to say to trigger it (since `disable-model-invocation: true`, auto-triggering is blocked — this is acceptable but the description could still be more useful as documentation).
- **Frontmatter — no `license` field**: occ-skill-creator has `license: Apache-2.0`. occ-skill-refactor does not. Should match for consistency if this is an open-source distribution.
- **Trigger quality — under-trigger risk is N/A**: `disable-model-invocation: true` prevents auto-triggering. The description is only used for documentation/discoverability. Risk is effectively zero for mis-triggering.
- **Progressive disclosure — correctly implemented**: Frontmatter ~30 words, SKILL.md body ~75 lines, two reference files for detail. Three-tier structure is sound.
- **Reference files — `anthropic-best-practices.md` not surfaced in SKILL.md body**: The skill mentions `references/refactor-protocol.md` four times but never mentions `references/anthropic-best-practices.md` by name in the body. Per best practices: "Each reference file should have explicit 'when to read' guidance." The best-practices file is effectively invisible to a reader of SKILL.md unless they open the protocol reference.
- **Instruction quality — sub-agent steps lack explicit output paths in the body**: Steps 2 and 6 say "Read `references/refactor-protocol.md` for the prompt template" without stating the output paths inline. The output paths are correct in the Example, but a reader following the numbered steps has to context-switch to a reference file to know where artifacts land.
- **Error handling — all five failure modes documented**: Path missing, SKILL.md missing, malformed frontmatter, conflicting agent feedback, temp write failure. All covered. This is thorough.
- **File conventions — no forbidden files found**: No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, LICENSE.txt in the skill directory.
- **Reference file structure — one level deep, no nested references/**: Correct.
- **`references/refactor-protocol.md` line count**: The file is 337 lines. Per best practices, files >100 lines should include a table of contents. Neither reference file has one.
- **`references/anthropic-best-practices.md` line count**: 198 lines — also exceeds 100-line threshold for recommended table of contents.
- **Example section — present and correct**: Lines 67-78 show the trigger phrase, all six workflow steps, and artifact locations. Covers the core use case.

### What Works Well

- `disable-model-invocation: true` is the right call for an interactive orchestration skill.
- Negative trigger ("Do NOT use to create a new skill from scratch") is present and unambiguous.
- Error handling is the strongest part of the skill — five cases, all specific.
- The description is under 1024 characters and contains no XML angle brackets.
- File structure is clean and conventions-compliant.
- Input validation (check directory exists, check SKILL.md present) is explicit before any sub-agent launch.

---

## Compiled Findings

### Critical Issues
(blockers — must fix before publishing)

- None. The skill is functional and conventions-compliant.

### Improvements
(meaningful improvements that raise quality)

1. **Surface `references/anthropic-best-practices.md` in SKILL.md body** — it exists in the directory but is never named in the skill body. Add explicit when-to-read guidance (e.g., "the red-team agent reads `references/anthropic-best-practices.md`; consult it to understand the evaluation criteria").
2. **Remove redundant "Read `references/refactor-protocol.md`" repetition** — appears at line 24 (intro), line 34, line 35, and line 56. One reference in the intro is sufficient; the per-step repetitions add noise without adding information.
3. **Add table of contents to both reference files** — `refactor-protocol.md` (337 lines) and `anthropic-best-practices.md` (198 lines) both exceed the 100-line threshold. A ToC at the top of each file enables faster targeted reads.
4. **Clarify the 3-question requirements gathering step** — "up to 3 questions" is ambiguous. Either list all three inline or point directly to the section in `references/refactor-protocol.md`.
5. **Add `license: Apache-2.0` to frontmatter** — matches occ-skill-creator's frontmatter; missing here.

### Minor Notes
(low-priority polish)

- Step 3 says "Present the path to the user" without stating the canonical path inline. The Example block covers this, but stating the path (`temp/<skill-name>/refactor/review-summary.md`) directly in Step 3 would remove the need to cross-reference.
- The description could be expanded slightly to describe the input shape ("accepts a skill path") for documentation clarity, since `disable-model-invocation: true` means it won't affect triggering behavior.

---

## Prioritized Action Items

1. **Surface `references/anthropic-best-practices.md` in SKILL.md body** — add when-to-read guidance; the file is invisible to SKILL.md readers today.
2. **Consolidate "Read `references/refactor-protocol.md`" references** — keep one clear pointer in the intro, remove the three per-step repetitions.
3. **Add ToC to `references/refactor-protocol.md`** (337 lines) — highest priority of the two reference files; it is the most frequently consulted.
4. **Add ToC to `references/anthropic-best-practices.md`** (198 lines).
5. **Clarify requirements gathering step** — specify all three questions or point to the exact section in the protocol reference.
6. **Add `license: Apache-2.0` to frontmatter** — consistency with occ-skill-creator.
7. **Inline the review-summary path in Step 3** — minor clarity improvement.
