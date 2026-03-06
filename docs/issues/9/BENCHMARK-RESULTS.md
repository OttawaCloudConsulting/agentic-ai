# Benchmark Results: occ-skill-creator and occ-skill-refactor

**Date:** 2026-03-06
**Issue:** [#9 — Execute Anthropic "skill-creator" to benchmark existing skills templates](https://github.com/OttawaCloudConsulting/agentic-ai/issues/9)
**Benchmarked by:** `skill-creator:skill-creator` plugin (official Anthropic, v205b6e0b3036)
**Method:** 3 test cases per skill × 2 configurations (with_skill / baseline). 27 total assertions.

---

## Summary Table

| Skill | with_skill | Baseline | Delta | Recommendation |
|---|---|---|---|---|
| occ-skill-creator | 14/14 (100%) | 9/14 (64%) | +36pp | **Keep — iterate on description** |
| occ-skill-refactor | 13/13 (100%) | 5/13 (38%) | +62pp | **Keep — iterate on description** |

Both skills pass all assertions under explicit invocation. The baseline gap is meaningful: 36–62pp depending on the skill. Both should be retained and improved rather than retired.

---

## Plugin Baseline

The official `skill-creator:skill-creator` plugin provides:

| Capability | Plugin | occ-skill-creator | occ-skill-refactor |
|---|---|---|---|
| Skill creation workflow | Full (5-stage with evals) | Simplified (5-stage, no evals) | Not in scope |
| Skill review/refactoring | Integrated (improvement loop) | Via refactor-protocol reference | Standalone workflow |
| Eval infrastructure (run_loop.py, aggregate) | Yes | No | No |
| Eval viewer (generate_review.py) | Yes | No | No |
| Description optimization (run_loop.py) | Yes | No | No |
| Blind A/B comparison | Yes | No | No |
| Packaging (.skill file) | Yes | No | No |
| Approval gate before changes | No | Via refactor-protocol | Yes (explicit) |
| Decisions log with traceability | No | Via refactor-protocol | Yes (decisions.md) |
| Degrees-of-freedom framework | No | Yes | Inherited |
| Auto-triggers | Yes | No (disable-model-invocation) | No (disable-model-invocation) |

---

## What the OCC Skills Add vs the Plugin

### occ-skill-creator

**Unique value:**
- Degrees-of-freedom framework (High/Medium/Low) — guides specificity level per task; plugin doesn't have this
- Progressive disclosure methodology with explicit "when to read" references
- Scripted resource planning (decides whether to create scripts/ vs inline)
- Anthropic best practices bundled as a reference file (anthropic-best-practices.md)

**Overlaps with plugin:**
- 5-stage creation workflow (understand → plan → build → review → iterate)
- Refactor review (offloaded to references/refactor-protocol.md)
- Same naming/structure conventions

**Gaps vs plugin:**
- No eval infrastructure — cannot measure skill quality objectively
- No description optimization — trigger description quality must be managed manually
- No packaging — cannot export .skill files

### occ-skill-refactor

**Unique value:**
- Standalone refactor review as a discrete skill (plugin bundles this in the create-improve loop)
- Explicit approval gate before any changes — human-in-the-loop control
- Two-agent review (critique + red-team) producing separate artifacts
- decisions.md audit trail with tradeoffs and deferred items
- Scoped requirements gathering (max 3 questions, logged)

**Overlaps with plugin:**
- Improvement loop concept (plugin does this iteratively with evals; OCC does it with approval gates)
- Review against Anthropic best practices

**Gaps vs plugin:**
- No eval measurement — reviews are qualitative only
- No before/after quantitative comparison
- No blind comparison

---

## Do They Complement or Duplicate the Plugin?

**Complementary, with overlap.**

The OCC skills occupy a different position than the plugin:

| Dimension | Plugin | OCC skills |
|---|---|---|
| **Orientation** | Quantitative (evals, benchmarks, scripts) | Qualitative (structured review, approval gates) |
| **Workflow model** | Iterate until evals pass | Review → approve → apply targeted change |
| **Human control** | Human reviews output after runs | Human approves before changes |
| **Invocation** | Auto-triggers | Explicit only |
| **Scope** | Full skill lifecycle in one skill | Split: creation (occ-skill-creator) + refactor (occ-skill-refactor) |

The key non-overlap: occ-skill-refactor's approval gate and decisions log exist for governance and auditability — neither is present in the plugin. Teams that need explicit human control before skill changes benefit from occ-skill-refactor even when the plugin is installed.

The key gap: neither OCC skill can measure quality objectively. Using the plugin's eval infrastructure (run_loop.py) to validate that occ-skill-creator produces better skills than baseline is the missing piece. This benchmark addressed this gap partially — the assertion-based approach gives a proxy metric, not a signal-to-noise ratio.

---

## Score Summary by Dimension

### occ-skill-creator

| Dimension | Score | Notes |
|---|---|---|
| Trigger accuracy | N/A (disabled) | disable-model-invocation: true, correct behavior |
| Frontmatter validity | 3/3 TCs | Both configurations produce valid frontmatter |
| Description quality | 3/3 TCs | Both produce descriptions with trigger phrases |
| Degrees-of-freedom applied | 3/3 TCs (with) / 0/3 (without) | Most discriminating dimension |
| Progressive disclosure | 2/3 TCs (with) / 0/3 (without) | TC1 didn't need references/; TCs 2-3 both used them |
| Resource planning (scripts/) | 1/3 TCs (with) / 0/3 (without) | TC2 is the clearest example |
| Workflow completeness | 3/3 TCs (with) / 2/3 (without) | Baseline omits refactor review guidance |

### occ-skill-refactor

| Dimension | Score | Notes |
|---|---|---|
| Trigger accuracy | N/A (disabled) | Correct behavior |
| Parallel agent execution | 3/3 TCs (with) / 0/3 (without) | Core workflow; baseline never does this |
| Structured artifacts (temp/) | 3/3 TCs (with) / 0/3 (without) | critique, red-team, summary files |
| Approval gate | 2/3 TCs confirmed (with) / 0/3 (without) | TC3 simulated approval; baseline skipped gate |
| Requirements gathering | 1/1 TCs tested (with) / 0/1 (without) | 3-question scope gathering |
| Decisions log | 1/1 TCs tested (with) / 0/1 (without) | Implementation notes + deferred items |
| Content quality of review | Comparable across both | Both find the same core issues |

---

## Recommendations

### For occ-skill-creator

**Keep. Iterate on description and two references.**

Priority changes:
1. (Should-fix) Rewrite description: remove "Invoke explicitly with /occ-skill-creator", add natural trigger phrases ("Use when creating a new skill, building a skill for X"), add negative scope ("Does not cover refactoring existing skills, Kiro powers, or rule creation").
2. (Should-fix) Add explicit "when to read" text to `output-patterns.md` reference pointer.
3. (Should-fix) Add a troubleshooting row for vague/exploratory requests with specific clarifying questions.
4. (Nice-to-have) Add table of contents to `references/anthropic-best-practices.md`.
5. (Nice-to-have) Add `compatibility: Claude Code (.claude/skills/)` to frontmatter.
6. (Nice-to-have) Document parallel workflows pattern in Workflow Patterns section.

**Do not retire.** The degrees-of-freedom framework and progressive disclosure methodology add genuine value. Baseline pass rate is 64% vs 100% — the skill earns its place.

### For occ-skill-refactor

**Keep. Iterate on description and reference pointers.**

Priority changes:
1. (Should-fix) Rewrite description: replace invocation instruction with trigger conditions ("Use after creating a skill and wanting a quality pass", "Use before publishing a skill to a shared library", "Use when a skill is producing inconsistent results").
2. (Should-fix) Document `disable-model-invocation: true` in skill body (one line in Constraints section).
3. (Should-fix) Add explicit reference link to refactor-protocol.md in step 3 (compile), consistent with steps 2 and 6.
4. (Nice-to-have) Add table of contents to `references/refactor-protocol.md` (337 lines) and `references/anthropic-best-practices.md` (198 lines).
5. (Nice-to-have) Strengthen example with concrete input/output (specific skill path → summary of expected artifacts).

**Do not retire.** The approval gate, decisions log, and structured artifacts are capabilities the plugin does not provide. Baseline pass rate is 38% vs 100% — the largest gap observed. The skill's process value is clear.

---

## Outstanding Gap

Neither OCC skill has been tested with the plugin's quantitative eval infrastructure (`run_loop.py`, `aggregate_benchmark.py`). The benchmarks above use assertion-based grading as a proxy. A follow-on iteration should:

1. Use `run_loop.py` to test description trigger accuracy for any future version where `disable-model-invocation` is reconsidered
2. Run the plugin's eval loop on the skills created by occ-skill-creator to measure output quality objectively
3. Track assertion pass rates across iterations to measure improvement from the recommended changes

---

## Approval Gate

> **Maintainer:** Review this document and the individual benchmark files before any changes are applied to the OCC skills.
>
> - `docs/issues/9/benchmark-occ-skill-creator.md` — detailed per-test results
> - `docs/issues/9/benchmark-occ-skill-refactor.md` — detailed per-test results
> - `temp/benchmark-workspace/` — raw outputs, grading.json files, benchmark.json files
>
> Options: **approve changes** / **keep as-is** / **request additional tests**
