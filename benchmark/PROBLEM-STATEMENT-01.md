# Problem Statement 01 — Benchmark Cannot Reliably Identify Winners or Failures

## Background

`scripts/run-benchmark.sh` was validated end-to-end on 2026-03-08 (see [`docs/benchmark-test-run-report.md`](../docs/benchmark-test-run-report.md)). The script infrastructure is correct — directory layout, log isolation, manifest, verdict keywords, and run history all behave as specified. However, the benchmark failed to produce the expected verdicts on all three content test cases (TC-2, TC-3, TC-4).

The failures are not script bugs. They reveal two measurement design problems that make the benchmark unable to distinguish between a good skill, a bad skill, and no skill at all.

---

## Problem 1 — The bad-skill fixture scores perfectly

### Observed behaviour

`benchmark/test-fixtures/bad-skill/SKILL.md` was designed to score 2–6/18 per test input by instructing Claude to violate every quality standard. In practice it scored 18/18 (54/54 total) across both runs where it was used — higher than `occ-skill-creator` (53/54).

| Run | bad-skill | Comparison |
|-----|-----------|-----------|
| TC-2 (vs baseline) | 54/54 | 51/54 baseline |
| TC-4 (vs occ-skill-creator) | 54/54 | 53/54 champion |

### Root cause

The model ignores bad system prompt instructions when they conflict with its knowledge of what a good output looks like. The fixture gives domain guidance ("create comprehensive skill files") which anchors the model toward structured output. Instructions that were intended to degrade quality — no examples, generic trigger phrases, 1000-line SKILL.md — are overridden by the model's baseline capability.

The fixture still contains frontmatter, sections, and references to SKILL.md. The model treats these structural cues as authoritative and disregards the degrading instructions.

### Impact

- `REJECT` verdicts cannot be tested — the benchmark has no way to produce a clearly failing challenger
- The bad-skill fixture is not a useful test asset in its current form
- Any comparison against `bad-skill` produces misleading results

---

## Problem 2 — Rubric saturation: good skill cannot beat baseline

### Observed behaviour

In TC-3 (baseline mode), `occ-skill-creator` scored identically to the unaided baseline: 53/54 vs 53/54. Delta = 0. Verdict: `NO VALUE`.

Both runs dropped 1 point on T3 (cloud-deploy) in the same dimension (Instruction quality) for the same reason: absence of a concrete narrative example. Every other dimension was tied across all inputs.

### Root cause

The test briefs (conventional commits, database migrations, cloud deployment) are well-understood domains within the model's comfortable baseline capability. The model produces near-perfect skill outputs without any guidance. The rubric rewards structural qualities (correct frontmatter, no forbidden files, lean SKILL.md) that the model satisfies by default.

All runs — baseline, occ-skill-creator, and bad-skill — converge to 51–54/54. There is a ~3-point ceiling effect that leaves no meaningful headroom for discrimination.

### Impact

- `PROMOTE` verdicts cannot be reliably produced — no skill can demonstrate measurable improvement over baseline on current inputs
- The benchmark cannot answer the question "is this skill worth using?"
- Prior benchmark results (including the initial 52 vs 53 run) may reflect noise rather than real differences

---

## Options

Four levers are available. They target different parts of the problem.

### Option A — Fix the bad-skill fixture

Rewrite `benchmark/test-fixtures/bad-skill/SKILL.md` to give instructions that directly violate specific rubric criteria at the structural level — not just verbosity instructions the model will ignore:

- Omit the `name` field from frontmatter (targets Frontmatter quality)
- Set `description` to a single generic word with no trigger phrases (targets Trigger specificity)
- Instruct: "Write the entire skill as a single prose paragraph with no sections, headers, or bullet points" (targets Instruction quality, Conciseness)
- Instruct: "Do not split content into references/ files" (targets Progressive disclosure)
- Instruct: "Create a README.md and a CHANGELOG.md alongside SKILL.md" (targets Structure compliance)

**Fixes:** Problem 1.
**Risk:** The model may still override structural instructions it "knows" are wrong. This is a fundamental limit of instruction-based fixture design.

### Option B — Harden the test briefs

Replace or augment T1/T2/T3 with briefs that require domain-specific conventions the model cannot produce without skill guidance. Two sub-approaches:

**B1 — Add specificity requirements:** Briefs that demand a particular naming convention, output format, or error handling pattern the baseline model wouldn't know. The skill-guided model would produce it correctly; the baseline would not.

**B2 — Use niche or unfamiliar domains:** Domains where the model has weaker priors — a custom internal toolchain, a niche compliance framework, a highly specific CI/CD workflow. The baseline model cannot fake quality for something it doesn't know.

**Fixes:** Problem 2.
**Trade-off:** Harder briefs reduce repeatability and make it harder to interpret what a correct output looks like. The briefs would need accompanying reference outputs or acceptance criteria.

### Option C — Add a style-adherence rubric dimension

Add a 7th dimension to the rubric: **Style adherence** — does the output follow the specific conventions defined in the skill that was loaded?

- For skill-guided runs: score whether the output matches the skill's conventions (frontmatter format, trigger phrase style, reference file usage, sentence style)
- For baseline runs: score 0 by definition — the baseline model has no conventions to follow

This directly measures the thing a skill is actually there to do. A well-designed skill should produce outputs that are stylistically consistent with itself. The baseline model cannot do this.

**Fixes:** Problem 2. Also partially fixes Problem 1 — a bad-skill fixture with incoherent conventions would score low on this dimension even if it scores well on structural dimensions.
**Trade-off:** The scoring agent needs to be told which skill was loaded and what its conventions are. Adds complexity to the Phase 3 scoring prompt.

### Option D — Multi-run averaging

Run each comparison N times (e.g. 3) and average the scores. A consistent 1-point gap across 3 runs is more meaningful than a single-run observation.

**Fixes:** Neither problem directly — does not address saturation.
**Value:** Increases confidence on borderline deltas (1–2 points). Reduces the chance of acting on a noise-driven outcome.
**Trade-off:** 3× API cost and run time. The PRD lists this as a planned future enhancement.

---

## Recommended approach

Address the problems in this order:

1. **Option C (rubric dimension)** — highest leverage. No script changes required. Directly discriminates skill-guided from baseline runs. Implement as a 7th dimension in `benchmark/rubric.md` and update the Phase 3 scoring prompt in `scripts/run-benchmark.sh`.

2. **Option A (fixture rewrite)** — rewrite `bad-skill/SKILL.md` using structural violations rather than verbosity instructions. Re-run TC-2 and TC-4 to confirm `REJECT` and `CHAMPION CONFIRMED` verdicts.

3. **Option B (brief hardening)** — if Options C and A are insufficient, harden T1 first (simplest brief, easiest to target). Document the expected output conventions alongside the new brief.

Option D is complementary and can be added at any point without affecting the above.

---

## Success criteria

| Criterion | Test |
|-----------|------|
| `REJECT` verdict is producible | Re-run TC-2 with revised bad-skill fixture; expect `REJECT` |
| `PROMOTE` verdict is producible | Re-run TC-3 with occ-skill-creator; expect `PROMOTE` |
| `CHAMPION CONFIRMED` verdict is producible | Re-run TC-4; expect `CHAMPION CONFIRMED` |
| A clearly bad skill scores materially lower than baseline | bad-skill fixture scores ≤ 30/54 |
| occ-skill-creator scores materially above baseline | occ-skill-creator scores ≥ baseline + 3 |
