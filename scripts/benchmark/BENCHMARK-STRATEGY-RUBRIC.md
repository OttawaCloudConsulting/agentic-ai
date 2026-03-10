# Benchmarking Strategy: Rubric Guidance

This document defines how the scoring rubric works, when and how to adapt it, and what changes are safe versus breaking. It is the reference for teams that want to customise the benchmark for their specific skill domain.

---

## What the Rubric Does

The rubric is the scoring contract between the benchmark and the evaluation agent. It defines 7 dimensions, each scored 0–3 per test input, for a maximum of 63 points across 3 inputs (7 × 3 × 3).

The rubric file (`benchmark/rubric.md`) serves two purposes:

1. **Scoring criteria** — tells the evaluation agent what to look for and how to assign scores
2. **Output template** — defines the `scores.md` file structure that `run-variance.sh` parses for statistics

Any change to the rubric affects both purposes. Scoring changes affect verdict quality. Structural changes affect parsing.

---

## The Seven Dimensions

| Dimension | What it measures | Why it exists |
|-----------|-----------------|---------------|
| Frontmatter quality | `name`, `description`, trigger phrases present and well-formed | Ensures basic SKILL.md structure is correct |
| Trigger specificity | Phrases specific, multi-phrase, low false-positive risk, <1024 chars | Prevents overly broad or narrow triggers |
| Instruction quality | Steps + error handling + at least one example | Ensures the skill is actionable, not just descriptive |
| Progressive disclosure | SKILL.md lean (<500 lines), references loaded on demand | Prevents token waste from monolithic skills |
| Structure compliance | No forbidden auxiliary files (README, CHANGELOG, etc.) | Enforces clean skill bundles |
| Conciseness | No filler — every line justified | Prevents padding that inflates apparent quality |
| Style adherence | Output follows conventions of the loaded skill | Creates systematic separation between skill-guided and baseline runs |

**Style adherence is architecturally special.** It always scores 0 for baseline runs (no skill was loaded, so there are no conventions to follow). This creates a floor that no baseline run can exceed, which is what makes the benchmark discriminate reliably. Do not remove this dimension.

---

## When to Customise the Rubric

**Customise when:**
- Your skills follow domain-specific conventions the generic rubric doesn't capture (e.g. required frontmatter fields beyond `name`/`description`, mandatory output formats)
- A dimension is consistently inapplicable to your skill type (e.g. your skills are intentionally monolithic — progressive disclosure is irrelevant)
- You want higher resolution in an area that matters to your domain (e.g. split Instruction quality into two dimensions)

**Do not customise when:**
- You want higher scores — adjusting criteria to favour your existing skills invalidates the benchmark
- You haven't run at least three baseline comparisons with the default rubric — you need a baseline before you know what to change
- You're reacting to a single surprising verdict — investigate the run first

---

## Safe Changes

These changes alter scoring criteria without breaking the parsing pipeline:

**Revise criterion text.** The 0/1/2/3 descriptions for any dimension can be rewritten. The scoring agent reads them verbatim. Tighter criteria produce lower scores; looser criteria produce higher scores. Recalibrate your promotion threshold after revising.

**Raise or lower the bar within a dimension.** Move what currently scores 3 to score 2, or what scores 1 to score 0. This shifts the score distribution without changing the rubric structure.

**Add a note or example to a dimension row.** The scoring agent reads the full rubric and uses all context. Adding a domain-specific example to a criterion row improves scoring consistency.

---

## Structural Changes (Require Coordination)

These changes alter the number of dimensions or the `scores.md` template and require updates in multiple places.

### Adding a dimension

1. Add a row to the rubric table in `benchmark/rubric.md`
2. Add the dimension name to the Output Format template in `benchmark/rubric.md`
3. Update the maximum score references throughout:
   - Phase 4 decision prompt in `run-benchmark.sh`: update all `/63` references to the new max
   - Score matrix in Phase 4 prompt: add the new dimension row
   - `DIMS` array in `run-variance.sh`: add the dimension name in order
   - `N_DIMS` variable in `run-variance.sh`: increment by 1
4. Update threshold documentation: `BENCHMARK.md`, `BENCHMARK-STRATEGY-LIFECYCLE.md`

**Order matters.** `run-variance.sh` parses dimension scores positionally — the 7th score line in `scores.md` is assumed to be the 7th entry in `DIMS`. If the rubric order and the `DIMS` array order diverge, per-dimension statistics will be attributed to the wrong dimension.

### Removing a dimension

Follow the same steps as adding, in reverse. Removing style adherence is strongly discouraged — see above.

### Renaming a dimension

Rename in the rubric table and in the `DIMS` array in `run-variance.sh`. Run history rows and existing `scores.md` files will reflect the old name. This is cosmetic — it does not affect scoring or parsing of new runs.

---

## Calibrating Thresholds After Rubric Changes

After any structural change, the point scale changes. Previously established thresholds (e.g. "delta ≥ 5 means PROMOTE") no longer apply directly.

**Recalibration process:**

1. Run three baseline comparisons with your best-performing skill using the updated rubric
2. Record the deltas
3. Set the promotion threshold at approximately 60–70% of the mean delta from those runs
4. Update the `--threshold` flag default in your team's run commands

Example: if three runs produce deltas of +8, +7, +9 with an 8-dimension rubric (max 72), a threshold of 5 is conservative; 6–7 is calibrated.

---

## Domain-Specific Rubric Adaptation

The default rubric is calibrated for general-purpose Claude Code skills. For specialist domains, consider these adaptations:

**Structured output skills** (skills that produce JSON, YAML, or other machine-readable formats):
- Add a dimension: Output schema compliance — does the output match the expected schema?
- Tighten Instruction quality: require the skill to specify the exact output format, not just steps

**Interactive / multi-turn skills** (skills that ask the user questions):
- Conciseness criteria become less relevant — interaction overhead is expected
- Add a dimension: Question quality — are clarifying questions necessary and well-targeted?

**Domain-expert skills** (skills in specialised domains like legal, medical, financial):
- Add a dimension: Domain accuracy — does the output reflect correct domain knowledge?
- Note: the benchmark evaluates skill structure, not factual correctness. A domain accuracy dimension requires the scoring agent to have domain knowledge. Verify this holds for your chosen model.

**Refactoring / revision skills** (skills that improve existing content rather than create from scratch):
- Progressive disclosure and Style adherence are the most discriminating dimensions for this type
- Instruction quality criteria should require the skill to specify what constitutes a valid improvement

---

## Rubric Versioning

When you modify the rubric, runs before and after the change are not directly comparable. Scores from a 7-dimension rubric (max 63) cannot be compared to scores from an 8-dimension rubric (max 72).

**Recommended practice:**
- Record the rubric change in `docs/benchmark-run-history.md` as a header note (e.g. "Rubric updated YYYY-MM-DD: added X dimension, max score now 72")
- Do not compare deltas across rubric versions
- Re-run at least one baseline comparison after any structural change to establish a new reference point
