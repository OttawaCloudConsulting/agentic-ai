# Benchmark: occ-skill-creator

**Date:** 2026-03-06
**Skill path:** `skills/occ-skill-creator/SKILL.md`
**Plugin used:** `skill-creator:skill-creator` (official Anthropic plugin, v205b6e0b3036)
**Method:** 3 test cases × 2 configurations (with_skill / without_skill baseline). Parallel subagent execution. Graded against 14 assertions.

---

## Test Cases

| ID | Name | Task |
|---|---|---|
| TC1 | git-commits | Create a skill for conventional git commit messages |
| TC2 | weekly-report | Build a skill for weekly standup reports from git history |
| TC3 | dev-onboarding | Create a skill for new developer onboarding checklists |

---

## Trigger Accuracy

`occ-skill-creator` has `disable-model-invocation: true` set in frontmatter.

**Result:** Correctly suppresses auto-triggering on all queries. No false positives observed. The skill requires explicit invocation (`/occ-skill-creator`).

**Note:** Standard description trigger optimization (run_loop.py) is not applicable to `disable-model-invocation` skills. The description's primary role is discoverability in skill catalogs, not auto-trigger accuracy.

**Discoverability concern:** The current description reads: *"Guide for creating effective skills. Covers the full lifecycle: creation, structured review, and iteration. Invoke explicitly with /occ-skill-creator."*

This contains no natural trigger phrases users would say (e.g., "create a skill", "build a skill for") and no negative scope boundary. Both the with_skill output and baseline review independently flagged this gap.

---

## Output Quality — Assertion Results

### TC1: git-commits

| Assertion | with_skill | without_skill |
|---|---|---|
| Valid YAML frontmatter (kebab-case name, description) | PASS | PASS |
| Description explains WHAT + WHEN with trigger phrases | PASS | PASS |
| Description under 1024 chars | PASS | PASS |
| SKILL.md under 500 lines | PASS | PASS |
| Workflow completeness / resource planning applied | PASS | FAIL |
| No forbidden files | PASS | PASS |
| **Pass rate** | **6/6 (100%)** | **5/6 (83%)** |

**Key difference:** with_skill added an explicit degrees-of-freedom table distinguishing low-freedom git commands from high-freedom message judgment, plus a Rules section with safety guardrails. Baseline produced a valid skill but without this structural framing.

**Baseline advantage:** Baseline covered breaking change (`!`) syntax and included concrete examples for all 8 types — two things the with_skill output omitted.

---

### TC2: weekly-report

| Assertion | with_skill | without_skill |
|---|---|---|
| Valid YAML frontmatter | PASS | PASS |
| Considers scripts vs inline (resource planning) | PASS | FAIL |
| Workflow completeness | PASS | FAIL |
| Degrees-of-freedom explicitly applied | PASS | FAIL |
| **Pass rate** | **4/4 (100%)** | **1/4 (25%)** |

**Key difference:** with_skill created a bundled `scripts/generate_report.sh` with `--since`, `--branch`, `--path`, `--author` flags and cross-platform date handling. Baseline inlined 4 git command variants directly in SKILL.md with no script, no degrees-of-freedom labeling. The resource planning step is the most discriminating occ-skill-creator contribution.

**Baseline advantage:** Baseline's inline git commands used `|` delimiter to avoid spaces-in-commit-messages issue, and included a prescriptive output template with header metadata (period, branch, directory, generated date).

---

### TC3: dev-onboarding

| Assertion | with_skill | without_skill |
|---|---|---|
| Valid YAML frontmatter | PASS | PASS |
| Description includes specific trigger phrases | PASS | PASS |
| Output format defined | PASS | PASS |
| Workflow completeness + refactor guidance | PASS | FAIL |
| **Pass rate** | **4/4 (100%)** | **3/4 (75%)** |

**Key difference:** with_skill created a `references/checklist-template.md` (progressive disclosure), labeled degrees of freedom per extraction step (High/Medium/Low), and scanned 6 file/directory sources. Baseline inlined the template in SKILL.md and only reads CLAUDE.md and README.md.

---

## Aggregate Results

| Configuration | Assertions Passed | Total | Pass Rate |
|---|---|---|---|
| with_skill (occ-skill-creator) | 14 | 14 | **100%** |
| without_skill (baseline) | 9 | 14 | **64%** |
| **Delta** | +5 | — | **+36pp** |

**Token overhead:** with_skill uses ~13% more tokens (mean 12,004 vs 10,661 per run).
**Time overhead:** with_skill is ~33% slower (mean 41,550ms vs 31,277ms per run).

---

## Qualitative Findings

### What occ-skill-creator uniquely contributes

1. **Degrees-of-freedom framework** — Applied consistently across all 3 test cases. Baseline never produces this without the skill.
2. **Resource planning step** — Decision to create `scripts/` vs inline is guided. TC2 is the clearest example: skill creates a portable shell script; baseline inlines commands.
3. **Progressive disclosure** — `references/` directory used for templates (TC3) and flagged for large content. Baseline inlines everything.
4. **Safety rules section** — TC1 with_skill includes explicit prohibitions on `git add`, `--amend`, `--no-verify` without user request. Baseline omits these.

### Where baseline matches or exceeds

1. **Breaking change syntax** (TC1) — baseline covered `!` suffix and `BREAKING CHANGE:` footer; skill-guided output missed this.
2. **Delimiter handling** (TC2) — baseline used `|` to avoid spaces in commit messages.
3. **Prescriptive templates** (TC2) — baseline's output template includes more header metadata.

### Calibration note

The baseline is a strong performer. Basic Claude reasoning produces structurally valid SKILL.md files with proper frontmatter and good descriptions without the skill. The skill's incremental value is most visible in test cases with non-obvious structural decisions (TC2: script creation, TC3: references directory). For simple single-file skills (TC1), the gap narrows to ~17pp.

---

## Open Issues Identified (apply to the skill itself)

| Issue | Severity | Source |
|---|---|---|
| Description missing trigger phrases + negative scope | Should-fix | Both reviews |
| `output-patterns.md` reference pointer lacks explicit "when to read" text | Should-fix | Both reviews |
| No error guidance for vague/exploratory user requests | Should-fix | Baseline review |
| `references/anthropic-best-practices.md` (198 lines) lacks table of contents | Nice-to-have | Both reviews |
| No `compatibility` field | Nice-to-have | Both reviews |
| Parallel workflows pattern not documented in Workflow Patterns section | Nice-to-have | Baseline review |
| No framing on when a skill is right vs a command or rule | Nice-to-have | Baseline review |
