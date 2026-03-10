# How Do You Know If Your AI Skill Is Actually Good?

*Building a head-to-head benchmark for Claude Code skills — and what we learned when our assumptions failed.*

---

We had a problem that sounds simple until you think about it: we'd written a skill for Claude Code, spent time refining it, and had no reliable way to know whether the refined version was actually better. We were making judgment calls based on vibes. That's fine for a prototype. It's not fine when you're trying to ship something repeatable.

So we built a benchmark.

This is the story of how that benchmark was designed, what broke along the way, and what we learned about the limits of automated quality measurement when large language models are both the subject *and* the scorer.

---

## The Problem With "I Think It's Better"

Claude Code skills are system prompts. They load automatically when the right trigger phrase appears, shaping how Claude responds to a specific category of request. A well-designed skill gets invoked reliably, provides clear step-by-step instructions, includes error handling, and produces outputs that follow consistent conventions. A poorly designed skill gets ignored, produces verbose noise, or confuses the model into doing something unexpected.

The challenge: all of that quality lives in the *output* — the thing Claude produces when the skill is active — not in the skill file itself. You can read a skill and form an opinion, but opinions are expensive, inconsistent across reviewers, and impossible to track over time.

What we wanted was a repeatable, automated signal: given skill A and skill B, which one produces measurably better output across a standardised set of tasks?

---

## The Architecture: Champion vs Challenger

The benchmark follows a sports-bracket logic. You define a **champion** (the current standard) and a **challenger** (the thing you're testing). Both are run through three test briefs — tasks designed to span simple, medium, and complex scenarios. The outputs are scored by a separate agent using a structured rubric. A decision agent reads all six score files, computes the delta, applies a minimum-threshold filter, and writes a verdict.

```
Phase 1: Setup
  → resolve skill paths, create run directory, write manifest

Phase 2: Creation (6× claude -p)
  → champion/{T1,T2,T3}/   ← skill output under champion prompt
  → challenger/{T1,T2,T3}/ ← skill output under challenger prompt

Phase 3: Scoring (6× claude -p)
  → scores/{champion,challenger}/{T1,T2,T3}/scores.md

Phase 4: Decision (1× claude -p)
  → decision.md  ←  primary output
```

The whole thing runs unattended from a single bash invocation. Every run lands in a timestamped directory. Nothing is overwritten. The history accumulates.

Three modes cover the practical workflows:

- **Baseline mode** — challenger vs no skill (pure natural language). Answers: *is this skill worth using at all?*
- **Git main mode** — challenger vs the same skill on the `main` branch. Answers: *did my edits make it better?*
- **Champion vs challenger** — two explicit skills head-to-head. Answers: *which of these two approaches wins?*

---

## The Rubric: Scoring Output Quality

We settled on six dimensions, each scored 0–3, applied to each of the three test inputs. Maximum score: 54 points.

| Dimension | What it measures |
|-----------|-----------------|
| Frontmatter quality | Is `name` set? Are trigger phrases specific and well-formed? |
| Trigger specificity | Multi-phrase, precise, low false-positive risk, under 1024 characters |
| Instruction quality | Clear steps, error handling, at least one concrete example |
| Progressive disclosure | SKILL.md under 500 lines; large content offloaded to `references/` |
| Structure compliance | No forbidden auxiliary files (README, CHANGELOG, examples/) |
| Conciseness | No filler, no boilerplate — every line justified |

The rubric is injected as a system prompt to the scoring agent. Scoring logs are isolated from skill output directories so the scorer doesn't accidentally penalise the artifact for benchmark files that were never part of the skill.

---

## First Validation: The Assumption That Failed

We built a test fixture — a deliberately bad skill — to validate the lower end of the rubric. The idea: load this anti-quality skill and confirm the benchmark produces a `REJECT` verdict (baseline outscores it). If the benchmark can detect obvious garbage, we can trust it to detect subtle differences.

The fixture was designed to hit every rubric dimension wrong:

- Generic one-word description
- Instructions to create README.md and CHANGELOG.md (forbidden files)
- "Use generic trigger phrases like 'help', 'create', 'make'"
- No error handling, no examples, no concision

We ran the benchmark. The bad skill scored **54/54**. Perfect.

The baseline scored 51/54. The verdict: `PROMOTE`. The bad skill "won."

This was not the result we expected. But it was the result we needed to understand.

---

## What the Model Override Revealed

The rubric evaluates *output quality*, not *instruction-following fidelity*. When the bad skill told the model to create README.md and CHANGELOG.md, the model simply didn't. When it told the model to use generic triggers, the model wrote specific ones. The model applied its own trained knowledge of what a good SKILL.md looks like and produced a well-formed output regardless of what the system prompt said.

This is, in a sense, reassuring about the model's robustness. But it breaks the fixture.

More importantly, it revealed something true about the benchmark: **a badly written skill cannot force bad output; it can only fail to provide useful guidance**. The model's baseline capability compensates for the absence of good direction. So the fixture's approach — giving wrong instructions — couldn't work. The model would just ignore the wrong instructions and do the right thing anyway.

We tried a more aggressive rewrite: 908 words of unstructured prose, no formatting, explicit instruction to produce everything wrong. Same result. The model overrides it.

We abandoned the bad-skill fixture.

---

## The Saturation Problem

The fixture failure pointed toward a deeper issue. When we ran our best skill — the one we'd invested real effort in — against the baseline, the result was:

```
baseline (no skill):  53/54
occ-skill-creator:    53/54
Verdict: NO VALUE
```

The benchmark couldn't tell them apart.

This was rubric saturation. The six structural dimensions (frontmatter, triggers, instructions, disclosure, compliance, conciseness) are all within the comfortable capability of a modern model without any guidance. Sonnet knows what a good SKILL.md looks like. Load a skill or don't — the outputs converge at the top of the rubric.

We needed a dimension that *only* matters when a skill is loaded.

---

## The Solution: Style Adherence

We added a seventh dimension: **Style adherence**.

The idea is simple. When a skill is loaded, the scoring agent is given the skill's content and asked: does the output follow the conventions this skill establishes? Not whether the output is generically good — whether it is *consistent with this specific skill's approach*.

For baseline runs, style adherence is 0 by definition. No skill was loaded. There are no conventions to follow. This creates a structural floor under the baseline and a ceiling above it that skill-guided runs can reach.

The maximum score increased from 54 to **63** (7 dimensions × 3 inputs × max 3 points).

---

## Validation: The Results That Held

With style adherence in place, we ran three baseline comparisons: our best skill vs no skill, using `haiku` as the creation model.

*(Why haiku? Haiku has weaker priors than Sonnet and benefits more from skill guidance — the gap is wider and more reliable. For champion-vs-challenger runs where both slots use the same model, this doesn't matter.)*

| Run | Baseline | Skill | Delta | Verdict |
|-----|----------|-------|-------|---------|
| v1 | 51/63 | 60/63 | +9 | PROMOTE |
| v2 | 51/63 | 58/63 | +7 | PROMOTE |
| v3 | 46/63 | 57/63 | +11 | PROMOTE |

Three runs. Three `PROMOTE` verdicts. Deltas of +7, +9, and +11 — all well above the threshold of 3. The benchmark can now reliably distinguish a well-designed skill from the unguided baseline.

For completeness, we also ran the champion-vs-challenger validation with our best skill against the revised bad skill:

```
occ-skill-creator:  58/63  (+6)
bad-skill:          52/63  (-6)
Verdict: CHAMPION CONFIRMED
```

The style adherence dimension drove the result: the champion scored 8/9 (conventions followed); the bad skill scored 0/9 (its "conventions" are anti-patterns, so not following them is correct — but the scorer appropriately penalises the absence of any consistent style).

---

## The Variance Tool in Action: A Second Skill

With `run-variance.sh` built, we validated it against a different skill: `occ-skill-refactor`. Where `occ-skill-creator` handles creating skills from scratch, `occ-skill-refactor` handles reviewing and improving existing ones — same domain, narrower scope.

We expected the deltas to be smaller. A creation skill touches every rubric dimension on every run: it establishes frontmatter, triggers, instructions, and style from zero. A refactor skill is invoked in a context where structure already exists; its guidance is more constrained and its stylistic footprint is lighter. Smaller delta was the predicted outcome.

The three-run variance result confirmed it:

| Run | Baseline | Skill | Delta | Verdict |
|-----|----------|-------|-------|---------|
| var1 | 45/63 | 55/63 | +10 | PROMOTE |
| var2 | 52/63 | 57/63 | +5 | PROMOTE |
| var3 | 50/63 | 52/63 | +2 | NO VALUE |

Mean delta: **+5.7**. Recommendation: **PROMOTE — majority 2/3 runs (moderate confidence)**.

Compare that to `occ-skill-creator`: deltas of +7, +9, +11, unanimous PROMOTE. The refactor skill is weaker on this rubric — not because it's badly written, but because its narrower mandate produces less stylistic differentiation from an unguided baseline.

This is exactly the scenario that makes multi-run variance necessary. If you ran only var3, you'd get delta +2 — NO VALUE — and conclude the skill adds nothing. The aggregate view shows that NO VALUE was noise: the skill leads in 2 of 3 runs with a mean delta well above threshold. Single-run benchmarking would have reached the wrong conclusion.

The per-dimension breakdown confirmed where the signal came from. Style adherence scored 5.0/9.0 mean for the refactor skill versus 0.0 for baseline — the same structural floor the dimension was designed to create. Every other dimension was effectively tied, which is consistent with what we'd expect for a specialist skill operating in a constrained domain.

---

## What We Learned About Automated Skill Evaluation

**1. Evaluate output, not instructions.**
The rubric was always evaluating output quality — but we didn't fully appreciate what that meant until the fixture failed. The model is the unit under test. The skill is the treatment condition. You can't force a bad treatment by writing a bad skill if the model can compensate.

**2. Discrimination requires dimensions the model can't fill on its own.**
The six structural dimensions are necessary but not sufficient. A capable model can satisfy them without help. Style adherence creates a dimension that requires knowing which skill was loaded — the baseline has no way to score above zero on it.

**3. Model capability matters — choose the creation model deliberately.**
Using Sonnet for both baseline and skill-guided creation produces near-identical outputs. Sonnet's priors are too strong; the skill provides marginal lift. Haiku's weaker priors make skill guidance visible. For baseline validation specifically, `--creation-model haiku` is the right choice.

**4. Single-run results are unreliable for small deltas.**
Model non-determinism introduces 1–2 point variance per run. A delta of 3–4 from a single run might flip on a second run. Deltas of 7+ are reliable. For anything in the 3–5 range, you need multiple runs and a consistent direction — not a single number. We built `scripts/benchmark/run-variance.sh` to automate this: it runs the benchmark N times, computes mean and stddev per dimension per slot, and reports a confidence-weighted recommendation (unanimous / majority / split).

**5. Some things can't be tested automatically.**
The "bad skill produces bad output" use case doesn't hold. The benchmark validates that a *good* skill produces better output than no skill — that's the meaningful question for promotion decisions. Testing the floor requires a different methodology (perhaps adversarial inputs, or human evaluation) that's out of scope for this tool.

---

## What the Tool Is Good For

The benchmark has three validated use cases:

**Promotion gating.** Before promoting a new skill for the first time, run it against baseline in haiku mode. Three `PROMOTE` verdicts with delta ≥5 is a reliable signal that the skill adds real value.

**Revision testing.** After editing an existing skill on a feature branch, run it against the `main` branch version. A `SWITCH RECOMMENDED` verdict with a comfortable delta means your changes are meaningful improvements.

**Head-to-head selection.** When you have two candidate implementations, a champion-vs-challenger run tells you which one produces better outputs across a standardised set of tasks.

---

## The Infrastructure

The benchmark is two bash scripts. No runtime dependencies beyond the `claude` CLI and standard Unix utilities.

**`scripts/benchmark/run-benchmark.sh`** — the core script. Takes two skills, runs them through the three briefs, scores them, and produces a `decision.md`. Every run is self-contained: its own timestamped directory, its own manifest, its own logs. Nothing overwrites anything. The score history accumulates in `docs/benchmark-run-history.md`.

```bash
--challenger <skill>          # required: skill under test
--champion <skill>            # explicit champion (omit for baseline mode)
--compare-main                # auto-extract champion from git main branch
--creation-model haiku        # recommended for baseline runs
--scoring-model sonnet        # default; use opus for higher-confidence scoring
--label my-skill-v2-baseline  # names the run directory
--threshold 3                 # minimum delta to act (default: 3/63)
```

**`scripts/benchmark/run-variance.sh`** — multi-run wrapper. Calls `run-benchmark.sh` N times and aggregates the results statistically. Produces a `variance-report.md` with mean/stddev per dimension per slot, verdict distribution, and a confidence-weighted recommendation. All flags pass through to the core script; add `--runs N` to set the count (default: 3, minimum: 2).

```bash
--runs 3                      # number of benchmark runs (default: 3)
# all run-benchmark.sh flags also accepted and forwarded
```

Running either script from inside Claude Code requires unsetting the nested session guard:

```bash
env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-benchmark.sh \
  --challenger my-skill \
  --label my-skill-baseline \
  --creation-model haiku

env -u CLAUDECODE BENCHMARK_SKIP_PERMISSIONS=1 bash scripts/benchmark/run-variance.sh \
  --challenger my-skill \
  --label my-skill-variance \
  --creation-model haiku \
  --runs 3
```

---

## What's Next

The benchmark is past MVP. The primary use cases work reliably and multi-run variance is automated. A couple of things remain on the backlog:

**Configurable test inputs.** The three fixed briefs (commit messages, database migrations, cloud deployment) are reasonable defaults. A `--inputs <dir>` flag would let you bring domain-specific briefs that expose weaknesses the generic ones miss.

**Score trend tracking.** The run history table accumulates runs but doesn't surface trends. A lightweight viz of score delta over successive skill iterations would make the improvement narrative visible.

---

The core insight of this project is straightforward: if you're making decisions about AI configurations — which skill to use, whether a revision is an improvement, whether a new skill is worth the overhead — you need a signal that's more reliable than your own judgment on a given day. A benchmark that runs unattended, scores consistently, and accumulates history is that signal.

It took us two validation sessions and a few failed assumptions to get there. The fixture that didn't work taught us more about the tool than the fixture that did.

---

*`scripts/benchmark/run-benchmark.sh` and `scripts/benchmark/run-variance.sh` are part of the [agentic-ai](https://github.com/OCC-github/agentic-ai) library of drop-in configurations for Claude Code.*
