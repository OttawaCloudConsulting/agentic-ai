# Rubric Guide

Complete reference for understanding and customising the benchmark scoring rubric. Read this when the default rubric doesn't fit your skill domain, or when you want to understand exactly how scoring works.

---

## How the Rubric Works

The rubric file (`benchmark/rubric.md`) serves two purposes simultaneously:

**Scoring criteria.** The evaluation agent reads the rubric verbatim and uses it to assign scores. Every word in the criterion descriptions affects what the agent rewards and penalises.

**Parsing contract.** `run-variance.sh` reads the `scores.md` files produced by the scoring agent and extracts dimension scores positionally — the Nth score line is assumed to correspond to the Nth dimension. The rubric defines what `scores.md` must look like for parsing to work correctly.

Any change to the rubric affects both purposes. Criterion text changes affect scoring quality. Structural changes (adding, removing, or reordering dimensions) break the parsing contract if not coordinated across all relevant files.

### Scoring structure

- 7 dimensions, each scored 0–3 per test input
- 3 test inputs per run (T1, T2, T3)
- Maximum score per input: 21 (7 × 3)
- Maximum total score per run: 63 (21 × 3)

### Style adherence is architecturally special

Style adherence always scores 0 for baseline runs. The scoring prompt instructs the agent to score 0 explicitly when no skill was loaded — there are no conventions to follow, so no conventions can be followed.

This is intentional. It creates a floor that no baseline run can exceed, which is what allows the benchmark to discriminate reliably between skill-guided and baseline performance. A skill that scores well on style adherence has demonstrated it produced output consistent with the conventions defined in the loaded skill. A baseline run cannot demonstrate this by definition.

Do not remove this dimension.

---

## The Seven Dimensions

For the full per-score criteria (0/1/2/3 descriptions for each dimension), see the Scoring section in [REFERENCE.md](REFERENCE.md#scoring) — that is the authoritative reference. The source rubric text is in `benchmark/rubric.md`.

| Dimension | What it measures | Why it exists |
|-----------|-----------------|---------------|
| Frontmatter quality | `name`, `description`, and trigger phrases present and well-formed | Ensures basic SKILL.md structure is correct |
| Trigger specificity | Phrases are specific, multi-phrase, have low false-positive risk, and are under 1024 chars | Prevents overly broad or overly narrow triggers |
| Instruction quality | Steps present, error handling covered, at least one concrete example | Ensures the skill is actionable, not merely descriptive |
| Progressive disclosure | SKILL.md stays under 500 lines; detail is offloaded to references loaded on demand | Prevents token waste from monolithic skills |
| Structure compliance | No forbidden auxiliary files (README, CHANGELOG, etc.); correct directory layout | Enforces clean skill bundles |
| Conciseness | No filler — every line is justified | Prevents padding that inflates apparent quality |
| Style adherence | Output follows the conventions of the loaded skill; always 0 for baseline | Creates the systematic separation between skill-guided and baseline runs |

---

## When to Customise vs When Not To

**Customise when:**

- Your skills follow domain-specific conventions the generic rubric doesn't capture (e.g. required frontmatter fields beyond `name`/`description`, mandatory output formats, required sections)
- A dimension is consistently inapplicable to your skill type (e.g. your skills are intentionally monolithic — progressive disclosure is irrelevant for your domain)
- You want higher scoring resolution in an area that matters to your domain (e.g. splitting Instruction quality into separate dimensions for steps and for examples)

**Do not customise when:**

- You want higher scores — adjusting criteria to favour your existing skills invalidates the benchmark
- You haven't run at least three baseline comparisons with the default rubric — you need a reference point before you know what to change
- You're reacting to a single surprising verdict — investigate the run first; single-run variance is expected

---

## Safe Changes

These changes alter scoring criteria without breaking the parsing pipeline. No file coordination required beyond `benchmark/rubric.md` itself.

**Revise criterion text.** The 0/1/2/3 descriptions for any dimension can be rewritten. The scoring agent reads them verbatim. Tighter criteria produce lower scores; looser criteria produce higher scores. After revising, recalibrate your promotion threshold (see Threshold Recalibration below).

**Raise or lower the bar within a dimension.** Move what currently scores 3 to score 2, or what scores 1 to score 0. This shifts the score distribution without changing the rubric structure or the parsing contract.

**Add a note or example to a dimension row.** The scoring agent reads the full rubric and uses all context. Adding a domain-specific example to a criterion row improves scoring consistency without affecting parsing.

---

## Structural Changes

Adding or removing a dimension changes the `scores.md` format and the scoring mathematics. These changes require coordination across multiple files.

### Adding a dimension

1. Add a row to the rubric table in `benchmark/rubric.md`.
2. Add the dimension name to the Output Format template in `benchmark/rubric.md` (the `scores.md` template block under "Output Format").
3. Update `scripts/benchmark/run-benchmark.sh` — Phase 4 decision prompt:
   - Change all `/63` references to the new maximum (`N_DIMS × 3 × 3`)
   - Add a row for the new dimension in the Score Matrix template (lines that list each dimension by name)
4. Update `scripts/benchmark/run-variance.sh`:
   - Add the dimension name to the `DIMS` array in `run-variance.sh` in the same position it appears in the rubric
   - Increment the `N_DIMS` variable in `run-variance.sh` by 1

> **Critical: dimension order is a parsing invariant.** `run-variance.sh` maps the Nth score line in `scores.md` to the Nth entry in the `DIMS` array — by position, not by name. If the rubric order and the `DIMS` array order diverge, per-dimension statistics are silently misattributed to the wrong dimensions with no error or warning. Always add new dimensions to both the rubric table and the `DIMS` array at the same index position.

### Removing a dimension

Follow the adding steps in reverse. Decrement `N_DIMS`. Remove the dimension from the `DIMS` array at the correct index. Remove its row from the rubric table, the Output Format template, and the Phase 4 Score Matrix in `run-benchmark.sh`.

Do not remove Style adherence. See above.

### Renaming a dimension

Rename in the rubric table, in the Output Format template in `benchmark/rubric.md`, in the Score Matrix rows in the Phase 4 prompt in `run-benchmark.sh`, and in the `DIMS` array in `run-variance.sh`. Existing `scores.md` files and run history rows will reflect the old name — this is cosmetic and does not affect scoring or parsing of new runs.

> **Critical:** The rubric table order and the `DIMS` array order must always match — `run-variance.sh` attributes per-dimension statistics by position, not by name. If you rename and the orders diverge, statistics will be silently misattributed.

---

## Threshold Recalibration

The `--threshold` flag sets the minimum score delta required for an actionable verdict (PROMOTE, REJECT, SWITCH RECOMMENDED, or CHAMPION CONFIRMED). After any structural change, the point scale changes and the previous threshold no longer applies directly.

**Recalibration process:**

1. Run three baseline comparisons with your best-performing skill using the updated rubric.
2. Record the deltas from those three runs.
3. Set the promotion threshold at approximately 60–70% of the mean delta from those runs.
4. Update the `--threshold` value in your team's standard run commands.

Example (hypothetical — not the default): with an 8-dimension rubric (max 72), if three calibration runs produce deltas of +8, +7, +9, the mean delta is 8. A threshold of 5 is conservative; 6 is calibrated.

The default threshold (3 points on a 63-point scale) was calibrated against the 7-dimension default rubric. Do not use it after structural changes without recalibrating.

---

## Domain-Specific Patterns

The default rubric is calibrated for general-purpose Claude Code skills. For specialist domains, consider these adaptations.

**Structured output skills** (skills that produce JSON, YAML, or other machine-readable formats):

- Add a dimension: Output schema compliance — does the output match the expected schema?
- Tighten Instruction quality: require the skill to specify the exact output format, not just steps

**Interactive / multi-turn skills** (skills that ask the user clarifying questions):

- Conciseness criteria become less relevant — interaction overhead is expected overhead
- Add a dimension: Question quality — are clarifying questions necessary and well-targeted?

**Domain-expert skills** (skills in specialised domains: legal, medical, financial, regulatory):

- Add a dimension: Domain accuracy — does the output reflect correct domain knowledge?
- Note: the benchmark evaluates skill structure, not factual correctness. A domain accuracy dimension requires the scoring agent to have domain knowledge. Verify this holds for your chosen scoring model before relying on results.

**Refactoring / revision skills** (skills that improve existing content rather than create from scratch):

- Progressive disclosure and Style adherence are the most discriminating dimensions for this skill type
- Instruction quality criteria should require the skill to specify what constitutes a valid improvement, not just that improvements should be made

---

## Rubric Versioning

When you modify the rubric, runs before and after the change are not directly comparable. A 7-dimension rubric (max 63) and an 8-dimension rubric (max 72) produce scores on different scales. Deltas cannot be compared across rubric versions.

**Recommended practice:**

- Record the rubric change in `docs/benchmark-run-history.md` as a header note, e.g.: `Rubric updated 2026-03-10: added Output schema compliance dimension, max score now 72`
- Do not compare deltas across rubric versions
- Re-run at least one baseline comparison after any structural change to establish a new reference point before acting on results

---

## See Also

- After modifying the rubric, run three baseline comparisons to recalibrate — see USER-GUIDE.md Workflow 1
- For the complete flag reference including `--threshold`, see REFERENCE.md
- For promotion decision thresholds after recalibration, see LIFECYCLE-GUIDE.md
