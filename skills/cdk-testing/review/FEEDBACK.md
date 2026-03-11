# Feedback: cdk-testing

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/cdk-testing/

---

## Critique Review — Internal Quality Standards

### Findings

- **Redundant production safety warning (line 70-72 vs line 18):** Gate 2 contains a `WARNING` block restating that `--require-approval never` is dev/sandbox only. Critical Rules (line 18) already states this explicitly. One of these should be removed or replaced with a cross-reference. Currently the same rule is stated twice in different tones — this is minor bloat that also risks inconsistency if one is updated and the other is not.

- **Prerequisites section is underspecified (lines 22-27):** The section says "Feature code and tests are complete" and "You know which feature you are completing" — both are obvious preconditions a developer would know. These lines add no information Claude doesn't already have. The more valuable prerequisite (that the project has a `cdk.json` and `package.json`) is mentioned only in the frontmatter description, not in the body. Consider replacing the trivial bullets with a concrete project structure check.

- **Degrees of freedom are well-matched:** Low-freedom operations (validation pipeline, deploy command) are locked to scripts and exact CLI invocations. The commit workflow is correctly offloaded to `references/commit-workflow.md` and loaded conditionally. High-freedom decisions (which files to stage, feature naming) are left to the consumer. No mismatches found.

- **Progressive disclosure is correctly implemented:** Frontmatter triggers (~100 words), SKILL.md body contains workflow at 113 lines (well under 500-line limit), and detailed commit steps live in `references/commit-workflow.md` with explicit conditional load guidance at lines 33 and 81.

- **No forbidden files present:** The `review/` directory contains `BENCHMARK.md` — this is not a forbidden file type, but it is worth noting that `review/` is non-standard for a skill bundle. It is not an AI-executable resource, and would be irrelevant noise when the skill is dropped into a consumer project. Consider whether `review/` content belongs in this repo's `docs/` or `temp/` directories rather than inside the skill bundle itself.

- **`commit-workflow.md` has no table of contents (68 lines):** Under the 100-line threshold where a TOC is required, so this is not a violation. Worth noting if the file grows.

### What Works Well

- SKILL.md is lean (113 lines) with no bloat — well under the 500-line limit.
- Critical Rules section is at the top of the body before any workflow content — highest-risk rules are not buried.
- Gate structure (1 → 2 → 3) with explicit pass criteria and stop conditions at each gate is a clean, low-ambiguity workflow.
- The pipeline table (lines 52-60) is an efficient encoding of 6 steps — a well-used table.
- The example section (lines 86-103) shows a complete trigger → full output trace, which is the correct pattern.
- `scripts/cdk-validation.sh` correctly encapsulates the deterministic pipeline logic — Claude is not asked to reimplement this logic, only to run the script.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Naming (no issues):** Folder name `cdk-testing` is kebab-case, lowercase, no spaces or underscores. `name` field matches folder name exactly. `SKILL.md` is correctly cased. No forbidden prefixes (`claude`, `anthropic`) used.

- **Frontmatter completeness (no critical issues):** Both required fields are present and valid. `compatibility` field is populated. No XML angle brackets. YAML delimiters are correct. Description is well under 1024 characters (estimated ~360 characters).

- **Missing negative trigger for staging/production deployments:** The description excludes Python CDK, CDK synth-only, and non-CDK TypeScript testing — all correct. However, it does not explicitly state "Do NOT use for staging or production deployments." The skill's Critical Rules (line 18) and the Gate 2 WARNING (line 70) both reinforce dev-only use, but a user who asks "deploy CDK to staging" could still trigger the skill. Adding this as a negative trigger in the description would close the boundary definitively at the triggering layer.

- **Trigger quality is strong overall:** Description contains specific user-facing phrases ("test cdk", "validate my cdk", "run cdk checks", "deploy cdk to dev", "/test-cdk"), a functional summary, relevant file type context (`cdk.json`, `package.json`), and three precise negative triggers. Under-trigger and over-trigger risks are both low.

- **Instruction quality is high:** All commands are exact and runnable. Pass criteria for each gate specifies exit code 0. Stop conditions are explicit ("STOP. Report which check failed. Do not proceed to Gate 2"). The reference to `references/commit-workflow.md` is paired with a precise when-to-read condition (lines 33 and 81).

- **Error handling covers the main CDK deploy failure modes** (IAM permission, bootstrap, stack dependency, region mismatch) with recovery commands. One minor gap: git-secrets being absent is handled silently by the script (auto-skip), but SKILL.md does not acknowledge this behavior or tell the user what it means for coverage — a developer who relies on secrets scanning might not notice it was skipped if they don't read the script output carefully.

- **Reference file guidelines:** `references/commit-workflow.md` is one level deep (correct). No nested `references/sub/` structure. File is 68 lines — under the 100-line threshold for required table of contents.

- **No README.md, CHANGELOG.md, or other forbidden files inside the skill folder.** (The `review/` directory is non-standard but does not contain any of the forbidden file types.)

### What Works Well

- Trigger description is a model implementation: WHAT + WHEN + specific phrases + negative triggers, all within character limits.
- Instructions are specific and actionable throughout — no guesswork required to follow the workflow.
- Error handling section is thorough for the CDK deploy gate, which is the highest-risk step.
- Progressive disclosure is correctly implemented across all three tiers.
- `compatibility` field is populated with all environment requirements, including optional ones (git-secrets).

---

## Compiled Findings

### Critical Issues

None. The skill is structurally sound and contains no blockers.

### Improvements

1. **Add staging/production negative trigger to description:** The description does not explicitly say "Do NOT use for staging or production deployments." The skill enforces dev-only through Critical Rules and Gate 2 warnings, but a user asking to deploy to staging could still trigger the skill. A single phrase in the description would close this at the triggering layer: append "Do NOT use for staging or production deployments." to the existing negative triggers.

2. **Remove the Gate 2 WARNING block or collapse it to a cross-reference:** Lines 70-72 restate the production safety rule already expressed in Critical Rules (line 18). Having the same safety constraint in two places with different wording creates a maintenance risk and minor context bloat. Either: (a) remove the WARNING block and trust Critical Rules, or (b) replace it with a one-line cross-reference ("See Critical Rules above").

### Minor Notes

1. **Prerequisites section (lines 22-27) contains two trivial bullets:** "Feature code and tests are complete" and "You know which feature you are completing" are obvious and add no information. Replacing them with a concrete project structure check (e.g., confirm `cdk.json` and `package.json` exist at project root) would make the section more actionable.

2. **`review/` directory inside the skill bundle:** This is non-standard. `BENCHMARK.md` and `FEEDBACK.md` are not AI-executable resources and would be irrelevant noise when the skill is dropped into a consumer project. Consider moving review artifacts to `docs/` or `temp/` at the repo level.

3. **git-secrets auto-skip behavior is not surfaced in SKILL.md:** The script silently skips secrets scanning when git-secrets is not installed. SKILL.md (Failure Handling section) does not mention this case. A one-line note — "If git-secrets is not installed, secrets scanning is skipped; pipeline continues without it" — would set clear expectations.

---

## Prioritized Action Items

1. Add "Do NOT use for staging or production deployments." to the description's negative triggers — closes a triggering boundary gap that the body-level safety rules cannot enforce at trigger time.
2. Remove or collapse the Gate 2 WARNING block — eliminates duplicate safety language and the maintenance risk of two versions drifting apart.
3. Replace trivial Prerequisites bullets with a concrete project structure check — makes the section actionable rather than obvious.
4. Add a note in Failure Handling about git-secrets auto-skip behavior — prevents silent loss of secrets scanning coverage going unnoticed.
5. Move `review/` directory out of the skill bundle to `docs/` or `temp/` at the repo level — keeps the skill bundle clean for consumer drop-in use.
