# Benchmark: rule-creator

**Date**: 2026-03-06
**Skill version**: unversioned
**Evaluator**: Claude (automated benchmark)

---

## Mode 1 — Static Quality Analysis

### Rubric A: Internal Quality Standards

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Conciseness | 4 | SKILL.md is 140 lines — well under the 500-line limit and lean throughout. The Example section (lines 115–124) earns its length by mapping each step to the concrete use case. The only mild redundancy is the rule constraints list (lines 12–16), which partially restates what is already implied by the rule type descriptions in Step 3. |
| Degrees of Freedom | 4 | Behavioral/process vs. infrastructure rule types are differentiated with appropriate guidance for each. Step 3 correctly leaves section ordering as a user decision. Step 2 gives Claude latitude to decide which existing rules are relevant. The one gap: Step 4's instruction "Follow the format patterns in `references/rule-format.md` exactly" is correctly low-freedom for a deterministic output, but Step 5's "exactly" reference to `references/doc-format.md` is similarly appropriate. |
| Progressive Disclosure | 5 | SKILL.md stays at 140 lines. Two reference files (`references/rule-format.md`, `references/doc-format.md`) are linked with explicit "when to read" guidance at Steps 3, 4, and 5, and in the References section. Content is not duplicated across SKILL.md and references. |
| Structure | 4 | Workflow is clearly numbered and sequential. The Example section follows immediately after the workflow, which is ideal placement. The Error Handling table covers the most important failure modes. The only structural note: the Rule Constraints section at the top is useful but slightly redundant with content implied by Step 3's section templates — a tighter integration would improve flow. |
| Resource Appropriateness | 5 | Two reference files cover format patterns for deterministic outputs — exactly the right use of references. No scripts directory exists (correct: no deterministic code tasks here). No assets directory (correct). The `review/` directory being created here is external to the skill bundle itself. |

**Rubric A Score**: 4.4 / 5.0

### Rubric B: Anthropic Best Practices

| Criterion | Score (1–5) | Evidence |
|---|---|---|
| Naming | 5 | Name is `rule-creator` — kebab-case, lowercase, no underscores, well under 64 characters. Does not use reserved prefixes. Folder name matches the `name` field exactly. |
| Frontmatter | 4 | Both required fields (`name`, `description`) are present. No XML angle brackets. Description is 229 characters — well under 1024. No optional fields (`license`, `compatibility`) are present; `license` would be appropriate given the repo context but is not required. |
| Trigger Quality | 4 | Description includes what the skill does ("Generate new rules — always-on behavioral guidelines") and specific trigger phrases ("create a rule, write best practices, add a new rule file, or generate coding guidelines"). The phrase "Walks through an interactive interview" is accurate and useful. Weakness: no negative triggers ("Do NOT use for creating skills or commands") — given the existence of skill-creator and command-creator skills in this repo, false-positive overlap is a real risk. |
| Instruction Quality | 5 | Every step is specific and actionable. Step 1 identifies which questions to skip when already answered. Step 2 provides a concrete grep pattern. Step 3 lists exact section names for each rule type. Steps 4–6 reference specific output paths. The Example section maps each step to a real scenario without being verbose. |
| Error Handling | 5 | The Error Handling table (lines 128–134) covers five distinct failure modes with specific recovery actions: lint failure, missing catalog, missing references, ambiguous requirements, and existing rule overlap. Each recovery action is concrete — no vague "handle gracefully" entries. |

**Rubric B Score**: 4.6 / 5.0

### Overall Quality Score: 4.5 / 5.0

### Key Findings

- The skill is well-scoped, lean, and follows progressive disclosure correctly — SKILL.md at 140 lines with two reference files linked at point of use.
- Error handling is a standout strength: five specific failure modes with concrete, non-vague recovery steps, including the important edge case of an existing rule overlap.
- The description lacks negative triggers to differentiate from skill-creator and command-creator workflows — a user asking to "add a new coding guideline file" could plausibly trigger either `rule-creator` or `skill-creator`, and the description does not guard against this.
- The Rule Constraints section (lines 10–16) is partially redundant with the section templates in Step 3 — those constraints are implied by the format guidance already. This is a minor conciseness issue, not a blocker.
- `disable-model-invocation: true` is absent, which is correct — this skill should auto-trigger. But its absence is worth noting since the interactive interview (Step 1 uses AskUserQuestion) means premature triggering on casual mentions of "rule" could be disruptive.

---

## Mode 2 — Trigger Accuracy Testing

The description field: *"Generate new rules — always-on behavioral guidelines for Claude Code. Use when asked to create a rule, write best practices, add a new rule file, or generate coding guidelines. Walks through an interactive interview to produce a rule file and its documentation."*

### Test Cases

| # | Prompt | Expected | Predicted | Match | Reasoning |
|---|---|---|---|---|---|
| 1 | "Create a rule for how Claude should handle Git commits in this repo." | TRIGGER | TRIGGER | YES | "create a rule" is a direct trigger phrase from the description. |
| 2 | "Add a new rule file for Python error handling standards." | TRIGGER | TRIGGER | YES | "add a new rule file" is an exact trigger phrase in the description. |
| 3 | "Write best practices for our API design conventions." | TRIGGER | TRIGGER | YES | "write best practices" is listed explicitly as a trigger phrase. |
| 4 | "I need coding guidelines for how we handle database migrations." | TRIGGER | TRIGGER | YES | "generate coding guidelines" maps directly to this phrasing. |
| 5 | "Generate a behavioral rule for how Claude should respond when tests fail." | TRIGGER | TRIGGER | YES | "generate" + "rule" + "behavioral" aligns with the description's scope. |
| 6 | "Create an always-on guideline for defensive coding practices." | TRIGGER | TRIGGER | YES | "always-on behavioral guidelines" in the description covers this exactly. |
| 7 | "I want a rule that tells Claude to always use TypeScript strict mode." | TRIGGER | TRIGGER | YES | "create a rule" trigger phrase applies; the description explicitly covers coding standards. |
| 8 | "Can you make a Claude Code rule for our security review process?" | TRIGGER | TRIGGER | YES | "Claude Code" + "rule" + process aligns with the description's scope. |
| 9 | "Write a .claude/rules file covering our observability standards." | TRIGGER | TRIGGER | YES | The description's "add a new rule file" and "generate coding guidelines" cover this. |
| 10 | "We need a rule that enforces our naming conventions across all projects." | TRIGGER | TRIGGER | YES | Naming conventions are a coding guideline — covered by the description's trigger phrases. |
| 11 | "Create a new skill for rotating PDF pages." | SUPPRESS | SUPPRESS | YES | "create a skill" is distinct from "create a rule" — description does not list skill creation. |
| 12 | "I want to build a Claude command for running our test suite." | SUPPRESS | SUPPRESS | YES | "Claude command" is a different artifact type; description is specific to rules. |
| 13 | "Review my existing rules/ directory and tell me if anything is redundant." | SUPPRESS | SUPPRESS | YES | The description covers creation, not auditing; "produce a rule file" implies net-new output. |
| 14 | "Can you audit the defensive-protocol rule and suggest improvements?" | SUPPRESS | TRIGGER | NO | "suggest improvements" is adjacent to "write best practices" — the description may over-trigger here since it doesn't clarify it only creates new rules, not improves existing ones. |
| 15 | "How do I structure a Claude Code skill?" | SUPPRESS | SUPPRESS | YES | Question is about skills, not rules; no trigger phrase matches. |
| 16 | "Document our team's coding standards in a README." | SUPPRESS | SUPPRESS | YES | "README" is a different artifact; the description specifies ".claude/rules/" files. |
| 17 | "What are the best practices for Terraform module design?" | SUPPRESS | SUPPRESS | YES | This is a general knowledge question, not a creation request; no "create/add/generate" verb. |
| 18 | "Build a skill that knows about our infrastructure conventions." | SUPPRESS | SUPPRESS | YES | "skill" is the artifact type; description does not match skill creation. |
| 19 | "Create a command that runs lint on every PR." | SUPPRESS | SUPPRESS | YES | "command" is the artifact type; clearly distinct from rules in the description. |
| 20 | "Write a style guide for our Go codebase and save it as a markdown file." | SUPPRESS | TRIGGER | NO | "write" + "style guide" + "coding" loosely matches "write best practices" and "generate coding guidelines" — but the intended output is a markdown doc, not a `.claude/rules/` file. The description does not distinguish rule files from general documentation. |

### Accuracy Metrics

| Metric | Value |
|---|---|
| True Positive Rate | 10/10 (100%) |
| True Negative Rate | 8/10 (80%) |
| Overall Accuracy | 18/20 (90%) |

### Trigger Analysis

The description performs strongly on true positives — all ten trigger phrases map cleanly to the listed trigger conditions ("create a rule", "write best practices", "add a new rule file", "generate coding guidelines"). The two false negatives reveal the same underlying gap: the description does not clearly scope the output artifact as a `.claude/rules/` behavioral file, making it susceptible to triggering on requests to improve existing rules or create general documentation. Adding a negative trigger such as "Do NOT use for auditing existing rules, creating skills, commands, or general documentation files" would close both gaps and bring TNR to 100%.

---

## Summary

| Dimension | Score |
|---|---|
| Static Quality (Rubric A) | 4.4/5 |
| Static Quality (Rubric B) | 4.6/5 |
| Trigger Accuracy | 90% (18/20) |

**Benchmark verdict**: `rule-creator` is a high-quality, lean skill with excellent error handling and appropriate progressive disclosure. The primary gap is the absence of negative triggers in the description, which causes two false-positive trigger predictions in adjacent use cases (auditing existing rules, writing general documentation) — a targeted one-line addition to the description would resolve this.
