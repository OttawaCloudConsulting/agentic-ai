# Feedback: create-prd

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/create-prd/

---

## Critique Review — Internal Quality Standards

### Findings

- **Conciseness — Step 3 architecture areas list (lines 73–82)**: The six architecture interview areas are listed inline in SKILL.md even though they are already covered in `references/interview-guide.md`. This is the most significant conciseness violation: two sources of truth for the same content, and token cost with no added value over "Read `references/interview-guide.md` for the full architecture interview."
- **Conciseness — Step 4 cross-reference checklist (lines 90–99)**: Three bullet sub-lists under one step. The structural consistency checks (lines 91–93) and content propagation list (lines 95–99) could be merged or shortened without losing meaning. Both lists name examples that are template-specific and may not apply to all projects — a single guiding sentence would preserve the intent more concisely.
- **Degrees of freedom — Step 4 content propagation examples (lines 96–98)**: Items like "logging, security hardening, conditional components" are illustrative examples embedded in a prescriptive checklist. These are fine as examples but their placement makes them feel like a fixed list rather than guidance. Minor mismatch: medium-freedom guidance encoded as low-freedom enumeration.
- **Progressive disclosure — Step 3 duplication**: Architecture interview areas appear both in SKILL.md body (lines 73–82) and in `interview-guide.md`. Violates the "information lives in either SKILL.md or references, not both" principle from the core constraints.
- **Structure**: Solid. Sequential steps, clear section order, Rules at top, Error Handling at bottom. No issues.
- **Forbidden files**: None present. Only `SKILL.md`, `references/interview-guide.md`, and three `assets/` files. Clean.
- **Resource appropriateness**: Correct. Assets hold output templates (not loaded into context). Reference holds the question bank (loaded on demand). No scripts directory — appropriate, no deterministic code logic needed. No misplaced content.

### What Works Well

- SKILL.md at 162 lines is well under the 500-line limit with meaningful headroom.
- Each step names the exact tool, exact file path, and a specific verification step — the model never has to guess what to do next.
- The Rules section (lines 15–23) is at the top and covers the most critical behavioral constraints. "Do not begin implementation" is explicit.
- Assets are correctly separated from references: templates are output artifacts, not guidance loaded into context.
- Quality bars are called out inline at the steps where they matter (lines 63–64, 84–85), not buried in a generic guidelines section.
- The progress.txt numbering scheme (lines 124–128) is prescriptively locked down where consistency is critical — correct degree of freedom for a fragile, exact-sequence operation.
- Error handling covers the four most likely failure modes with specific, actionable responses.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Trigger quality — missing negative triggers** (should-fix): The description covers what the skill does and several positive trigger scenarios. It does not include negative triggers. A user (or routing model) could reasonably invoke this skill for: updating an existing PRD, creating a standalone architecture document for an existing system, or writing a technical design doc for a change (not a new project). Benchmark trigger testing confirmed two false positives on exactly these cases (tests 11 and 14 in BENCHMARK.md: "Update the PRD to add a new feature" and "Write a technical design doc for a change to an existing system"). With `disable-model-invocation: true` the auto-trigger risk is zero, but the description serves as the user-visible help text for command selection — the ambiguity is a usability gap.
- **Trigger quality — no user-facing phrases** (nice-to-have): The description uses task-noun phrases ("planning a new feature," "writing requirements") but no first-person user phrases ("I want to plan a new project," "help me write requirements for"). These would strengthen recognition for users scanning command descriptions.
- **Instruction quality — asset template fallback absent** (nice-to-have): Steps 1, 3, and 6 each call `Read assets/<template>` without any documented fallback if the file is missing. A consuming project that installs only `SKILL.md` and `references/` but omits `assets/` would encounter silent failure. The error handling section covers four failure modes but not this one.
- **`disable-model-invocation: true` evaluation**: Appropriate. This is a multi-step interactive interview workflow requiring explicit invocation. Auto-triggering would be disruptive and the skill is designed around deliberate user initiation. Setting is correct.
- **Naming**: Folder `create-prd` is kebab-case, lowercase, no spaces or underscores. `name` field matches exactly. `SKILL.md` filename is correctly cased. No reserved prefixes used. Fully compliant.
- **Frontmatter**: Both required fields present. No XML angle brackets. Description is approximately 220 characters — well under the 1024-character limit. YAML delimiters correctly formed. `disable-model-invocation` is a recognized optional field. No issues.
- **Progressive disclosure**: Three-tier model correctly implemented. Frontmatter is ~100 words. Body is 162 lines. Reference and asset files are conditionally loaded with explicit "when to read" guidance at each step. One violation: Step 3 lists interview areas inline that duplicate `interview-guide.md` content (flagged above under Critique).
- **Instruction quality**: High. Tool names specified at every step (`AskUserQuestion`, `Write`, `Edit`, `Bash`). Verification steps explicit ("Read the file back and confirm..."). No guesswork required. Quality bars are quantified ("Target 10–20 Design Decisions"). Critical rules at top.
- **File structure**: No forbidden files. Directory layout is correct. References are one level deep.
- **Reference files**: `interview-guide.md` is 81 lines — no table of contents needed. Assets are below 150 lines each. No structural issues.

### What Works Well

- Naming is fully compliant across all checked criteria.
- Frontmatter is clean and minimal with no violations.
- `disable-model-invocation: true` is correctly applied for an interactive workflow.
- Instruction actionability is high — among the strongest aspects of this skill.
- Progressive disclosure is correctly implemented except for the Step 3 duplication.
- The three output artifacts (PRD, architecture doc, progress tracker) are clearly defined with verification steps and a concrete summary template.

---

## Compiled Findings

### Critical Issues

None. No issues that break functionality or cause upload failure.

### Improvements

1. **Add negative triggers to the description** (trigger quality, usability): The description should explicitly exclude: updating an existing PRD, standalone architecture review of an existing system, and implementation tasks. Suggested addition: "Do NOT use for updating an existing PRD, documenting changes to an existing system, or starting implementation." This directly addresses the two confirmed false-positive cases from benchmark testing.

2. **Remove Step 3 architecture interview areas from SKILL.md body** (progressive disclosure / conciseness): Lines 73–82 list the six architecture interview areas inline. These should be removed from SKILL.md and left exclusively in `references/interview-guide.md`. The current instruction "Read `references/interview-guide.md` for the architecture interview areas" is sufficient — the inline list adds no value and duplicates reference content. Eliminates the single violation of "information lives in either SKILL.md or references, not both."

### Minor Notes

1. **Add user-facing phrase examples to description**: Adding one or two first-person phrases ("I want to plan a new project," "help me write requirements") would make the description more recognizable to users scanning command lists.

2. **Document asset fallback in error handling**: Add a failure mode for missing `assets/` templates — either a fallback behavior (construct the document from scratch without a template) or an explicit error message instructing the user to check the skill installation.

3. **Tighten Step 4 cross-reference checklist**: The two sub-lists in Step 4 (structural consistency checks and content propagation items) could be condensed. The specific examples (logging, security hardening) are illustrative rather than prescriptive and could be framed as examples rather than list items.

---

## Prioritized Action Items

1. Add negative triggers to the frontmatter description to disambiguate from PRD-update and existing-system documentation use cases.
2. Remove the six architecture interview areas listed inline in Step 3 (lines 73–82) — keep the `Read references/interview-guide.md` instruction, delete the inline list.
3. Add a missing-assets failure mode to the Error Handling section with a documented fallback.
4. Add one or two first-person user-facing phrases to the description.
5. Tighten the Step 4 cross-reference sub-lists for conciseness.
