# Benchmark: occ-skill-refactor

**Date:** 2026-03-06
**Skill path:** `skills/occ-skill-refactor/SKILL.md`
**Plugin used:** `skill-creator:skill-creator` (official Anthropic plugin, v205b6e0b3036)
**Method:** 3 test cases × 2 configurations (with_skill / without_skill baseline). Parallel subagent execution. Graded against 13 assertions.

---

## Test Cases

| ID | Name | Task |
|---|---|---|
| TC1 | standard-refactor | Run full refactor review on occ-skill-creator, stop at approval gate |
| TC2 | trigger-fix | Refactor occ-skill-refactor focusing on trigger description quality |
| TC3 | targeted-refactor | Full workflow: review → requirements → apply targeted changes → log decisions |

---

## Trigger Accuracy

`occ-skill-refactor` has `disable-model-invocation: true` set in frontmatter.

**Result:** Correctly suppresses auto-triggering on all queries. No false positives observed.

**Discoverability concern:** The current description reads: *"Reviews and refactors an existing skill against quality standards. Invoke explicitly with /occ-skill-refactor. Do NOT use to create a new skill from scratch."*

Both the with_skill output (TC2) and the baseline review independently identified the same issues:
- "Invoke explicitly with /occ-skill-refactor" is redundant given the frontmatter flag
- "Quality standards" is undefined (critique criteria + Anthropic best practices are not named)
- Multi-agent, approval-gated nature of the workflow is not surfaced in the description

---

## Output Quality — Assertion Results

### TC1: standard-refactor

| Assertion | with_skill | without_skill |
|---|---|---|
| Skill path validated before proceeding | PASS | PASS |
| critique/feedback.md written with structured format | PASS | FAIL |
| red-team/feedback.md written with structured format | PASS | FAIL |
| review-summary.md compiled from both agents | PASS | FAIL |
| Approval gate presented (proceed / keep as-is / defer) | PASS | FAIL |
| No unauthorized skill file modifications | PASS | PASS |
| **Pass rate** | **6/6 (100%)** | **2/6 (33%)** |

**Key difference:** with_skill produced 4 structured artifacts (critique/feedback.md, red-team/feedback.md, review-summary.md, plus implicit approval gate). Baseline produced a single high-quality review.md but none of the structured workflow artifacts. Content quality was comparable — both identified the same core issues.

**Baseline advantage:** Baseline caught 2 issues the with_skill output missed: (1) parallel workflows pattern not documented in occ-skill-creator's Workflow Patterns section; (2) no guidance on when NOT to create a skill (skills vs commands vs rules distinction).

---

### TC2: trigger-fix

| Assertion | with_skill | without_skill |
|---|---|---|
| Skill path validated | PASS | PASS |
| Trigger quality and disable-model-invocation addressed | PASS | PASS |
| Review summary written and path presented | PASS | FAIL |
| Approval gate presented before changes | PASS | FAIL |
| **Pass rate** | **4/4 (100%)** | **2/4 (50%)** |

**Key difference:** Both outputs correctly identified the trigger description weaknesses. with_skill additionally produced the structured artifacts and approval gate. The baseline's unique insight (the "Invoke explicitly" text being redundant given the frontmatter flag) was genuinely valuable.

---

### TC3: targeted-refactor (full workflow)

| Assertion | with_skill | without_skill |
|---|---|---|
| Requirements gathered (3 questions: categories, new reqs, depth) | PASS | FAIL |
| decisions.md with approval, changes, implementation notes | PASS | FAIL |
| Only approved/targeted changes applied | PASS | PASS |
| **Pass rate** | **3/3 (100%)** | **1/3 (33%)** |

**Key difference:** with_skill executed requirements gathering, logged all decisions (approval, selected changes, scope, tradeoffs, deferred items), and applied only targeted changes. Baseline went directly from review to applying changes — no requirements gathering, no decisions log, no scope enforcement.

**Refactored SKILL.md quality (with_skill):** Changed description to add natural trigger phrases + negative scope. Improved troubleshooting vague-requirements entry. Deferred 3 nice-to-have items explicitly.

---

## Aggregate Results

| Configuration | Assertions Passed | Total | Pass Rate |
|---|---|---|---|
| with_skill (occ-skill-refactor) | 13 | 13 | **100%** |
| without_skill (baseline) | 5 | 13 | **38%** |
| **Delta** | +8 | — | **+62pp** |

This is the largest skill-vs-baseline gap observed. The refactor workflow (parallel agents, temp artifacts, approval gate, decisions log) is entirely non-obvious and the baseline never produces it without the skill.

---

## Qualitative Findings

### What occ-skill-refactor uniquely contributes

1. **Parallel critique + red-team agents** — Two independent perspectives (internal quality vs Anthropic best practices) in separate feedback files. Baseline produces a single unified review.
2. **Structured temp/ artifacts** — critique/feedback.md, red-team/feedback.md, review-summary.md at predictable paths. Enables traceability and re-review.
3. **Approval gate** — Human-in-the-loop control before any skill file changes. Baseline makes no pause before applying changes.
4. **Requirements gathering (3 questions)** — Scopes the change before execution. Prevents over-refactoring and captures the user's intent explicitly.
5. **decisions.md** — Logs what was changed, preserved, tradeoffs, and deferred items. Provides an audit trail.

### Where baseline matches or exceeds

1. **Content quality of review** — Both configurations identify the same core issues. The skill's value is process correctness, not analytical depth.
2. **Unique issue detection** — Baseline caught issues the with_skill structured review missed (parallel workflows pattern, skills-vs-rules framing, redundancy of "Invoke explicitly" text).
3. **Speed** — Baseline produces its review faster (fewer structured artifacts to write).

### Calibration note

The baseline is analytically competent. The skill's 62pp advantage comes entirely from process structure (artifacts, approval gate, requirements, decisions log), not from superior review quality. Teams that need auditability, explicit approval workflows, and scoped changes should use this skill. Teams that want a quick informal review may not need it.

---

## Review Findings (from TC1 and TC2 — apply to the skill itself)

### occ-skill-refactor issues found

| Issue | Severity | Source |
|---|---|---|
| Description missing trigger conditions for explicit invocation | Should-fix | Both reviews |
| `disable-model-invocation: true` undocumented in skill body | Should-fix | Both reviews |
| Step 3 (compile) missing explicit reference link to refactor-protocol.md | Should-fix | with_skill review |
| `references/refactor-protocol.md` (337 lines) lacks table of contents | Nice-to-have | Both reviews |
| `references/anthropic-best-practices.md` (198 lines) lacks table of contents | Nice-to-have | Both reviews |
| Sub-agent invocation mechanism underspecified ("launch simultaneously" is low-freedom but unspecified) | Nice-to-have | with_skill review |
| Example shows workflow steps but not a concrete input/output pair | Nice-to-have | Both reviews |
| No `compatibility` field for parallel sub-agent requirement | Nice-to-have | with_skill review |
