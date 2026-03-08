# MVP: Benchmark Measurement Reliability

**Status:** Draft — for review before implementation
**Supersedes:** `benchmark/PROBLEM-STATEMENT-01.md` (background and root cause analysis)

---

## Problem Summary

`scripts/run-benchmark.sh` infrastructure is correct. The benchmark cannot reliably identify winners or failures because of two measurement design problems:

1. **The bad-skill fixture scores 54/54** — the model ignores bad system-prompt instructions and applies its own quality knowledge regardless.
2. **Rubric saturation** — all runs (baseline, good skill, bad skill) converge to 51–54/54. The benchmark cannot distinguish a good skill from no skill.

---

## Design Principle

The benchmark is a **general-purpose tool**. It works for any skill of any type. No specific skill name appears in the rubric, scoring prompts, or fixture logic. The loaded skill's content is injected dynamically at runtime.

---

## MVP Scope

Three required changes, one conditional:

| Option | Required? | Fixes |
|--------|-----------|-------|
| D — Configurable model selection | Yes | Makes saturation diagnosable; may resolve it without rubric changes |
| C — Style adherence rubric dimension | Yes | Problem 2 (saturation) |
| A — Revised bad-skill fixture | Yes | Problem 1 (fixture scores perfectly) |
| B — Brief hardening | Conditional | Apply only if C+D together do not resolve TC-3 |

---

## Option D — Configurable Model Selection

### What it solves

`run-benchmark.sh` hardcodes `--model sonnet` for all three phases. Model choice directly affects saturation: Sonnet is capable enough at skill creation that skill-guided and baseline runs converge at the top of the rubric. A less capable model (Haiku) needs more guidance — a well-designed skill has more impact, widening the delta.

Making model selection explicit also makes results interpretable. A score out of 63 means something different when produced by Haiku vs Sonnet vs Opus.

### Two distinct model roles

| Phase | Current | Role |
|-------|---------|------|
| Phase 2 — Creation | `sonnet` | Should match the model real users run day-to-day. Haiku widens the skill-vs-baseline gap. |
| Phase 3 — Scoring | `sonnet` | Opus would be a more discerning evaluator; Sonnet is consistent with the creation model. |
| Phase 4 — Decision | `sonnet` | Reasoning task; Sonnet is sufficient. |

### New flags

```
--creation-model <model>   Model for Phase 2 skill creation (default: sonnet)
--scoring-model <model>    Model for Phase 3 scoring and Phase 4 decision (default: sonnet)
```

Both default to `sonnet` — no behavioural change for existing invocations.

### Manifest changes

Add two new fields to `manifest.md`:

```
| Creation model | sonnet |
| Scoring model  | sonnet |
```

### Diagnostic value

Testing with `--creation-model haiku` tells us whether saturation is a model problem or a rubric/brief problem:

- If skill-guided Haiku significantly outscores baseline Haiku → model choice was the issue; rubric is adequate
- If Haiku also saturates → rubric and/or briefs need hardening regardless of model

### Script changes (`scripts/run-benchmark.sh`)

- Add `--creation-model` and `--scoring-model` to arg parsing (with `sonnet` defaults)
- Replace hardcoded `--model sonnet` in all `claude -p` calls: Phases 2 uses `$CREATION_MODEL`; Phases 3 and 4 use `$SCORING_MODEL`
- Add both fields to the manifest write block

---

## Option C — Style Adherence Rubric Dimension

### What it solves

Problem 2 (saturation). A baseline run scores 0 on this dimension by definition — no skill was loaded, so there are no conventions to follow. A skill-guided run is scored on how consistently the output follows the conventions of whatever skill was loaded. This creates a systematic gap between skill-guided and baseline runs that the six existing structural dimensions cannot produce, regardless of which skill is being tested.

### Rubric changes (`benchmark/rubric.md`)

**1. Add 7th dimension to the scoring table:**

| Dimension | 0 | 1 | 2 | 3 |
|-----------|---|---|---|---|
| **Style adherence** | No skill was loaded (baseline run), OR skill loaded but output ignores all its conventions | Output follows some conventions from the loaded skill (e.g. has frontmatter but structure diverges) | Output follows most conventions — correct frontmatter format, appropriate section structure, similar prose style | Output is fully consistent with the loaded skill — frontmatter matches exactly, trigger phrase style matches, structure and prose style match throughout |

**2. Update header:**
`**Max score per run: 18**` → `**Max score per run: 21**`

**3. Add row to scores.md template:**
```
| Style adherence        |             |       |
```

**4. Fix stale output path** in the Output Format section:
`temp/benchmark/<run>/scores/` → `benchmark/runs/<run>/scores/`

**5. Generalise Agent Instructions.** The current section hardcodes a specific skill by name. Replace with:

```
**Scope:** Score only files that are part of the skill bundle (SKILL.md, references/, scripts/).
Ignore any other files present in the directory.

**Scoring agent** — evaluate each dimension objectively against its rubric criteria.
For the Style adherence dimension, use the loaded skill context provided in the scoring
prompt. If no skill context is provided, score Style adherence as 0.
```

### Script changes (`scripts/run-benchmark.sh`) — Phase 3

In the Phase 3 scoring loop, before each `claude -p` call, build a `style_context` block from the slot's loaded skill. The skill path is already available via `SKILL_MD_PATHS[$slot]` (empty string for baseline champion slot).

```bash
style_guide="${SKILL_MD_PATHS[$slot]}"
if [[ -n "$style_guide" && -f "$style_guide" ]]; then
  style_guide_content="$(cat "$style_guide")"
  style_context="## Style Adherence Context

The following skill was loaded as the system prompt during creation for this slot.
Score the Style adherence dimension based on how consistently the output follows
its conventions: frontmatter format and field names, trigger phrase style and
specificity, section structure, prose style (imperative vs explanatory), and
reference file usage patterns.

--- LOADED SKILL ---
$style_guide_content
--- END LOADED SKILL ---"
else
  style_context="## Style Adherence Context

No skill was loaded during creation (this is a baseline run).
Score the Style adherence dimension as 0."
fi
```

The scoring `claude -p` user prompt becomes:
```
Score the skill at: $SKILL_OUTPUT_DIR
Read SKILL.md and any reference files in that directory.
Apply the rubric below. Write your scores to: $SCORE_FILE

$style_context

$RUBRIC_CONTENT
```

The skill content is embedded directly — no `--add-dir` changes needed.

### Script changes — Phase 4 decision agent

Update all score max references from 54 to 63:

| Find | Replace |
|------|---------|
| `max 18 per file` | `max 21 per file` |
| `max 54 total` | `max 63 total` |
| `champion_total = sum ... (max 54)` | `(max 63)` |
| `challenger_total = sum ... (max 54)` | `(max 63)` |
| `**<champion_total>/54**` | `**<champion_total>/63**` |
| `**<challenger_total>/54**` | `**<challenger_total>/63**` |

Add Style adherence row to the score matrix template in the decision.md format block:
```
| Style adherence | | | | | | | | |
```

The default threshold of 3 requires no change — 3/63 (~4.8%) is proportionally similar to 3/54 (~5.6%).

### History file change (`docs/benchmark-run-history.md`)

Update header line:
```
Scores are out of 54
```
→
```
Scores are out of 63 (7 dimensions × 3 inputs × max 3pts, from 2026-03-08).
Prior runs used 6 dimensions (max 54) and are not directly comparable on the Style adherence dimension.
```

Historical rows remain unchanged.

---

## Option A — Revised bad-skill Fixture

### What it solves

Problem 1 (fixture scores 54/54). The current fixture has structural cues — frontmatter, section headers, references to SKILL.md — that anchor the model toward quality output regardless of the degrading instructions. The revision removes all structural scaffolding and replaces it with explicit anti-quality instructions targeting each rubric dimension individually.

### New content for `benchmark/test-fixtures/bad-skill/SKILL.md`

```markdown
---
description: skill
---

You are creating a skill file. Write the entire content of SKILL.md as a single
unbroken prose paragraph of at least 600 words. Do not use any markdown formatting:
no headers (##), no bullet points (-), no numbered lists, no code blocks, no bold,
no tables. One paragraph only.

Do not add a name field to the frontmatter. The description field above is sufficient.
Do not add trigger phrases or expand the description.

Do not create a references/ directory or any subdirectories. Put all content
directly in SKILL.md regardless of length.

Always create these additional files alongside SKILL.md:
- README.md (a full explanation of the skill for end users)
- CHANGELOG.md (a version history starting at v0.1.0)

Do not include step-by-step instructions, numbered steps, or error handling.
Describe the skill in general terms only.

Do not include any examples of what the skill produces or how it is invoked.

Repeat the main purpose of the skill at least three times throughout the paragraph.
```

### Dimension targeting

| Instruction | Dimension | Expected score |
|-------------|-----------|----------------|
| No `name` field in frontmatter | Frontmatter quality | 0 |
| `description: skill` — one generic word, no trigger phrases | Trigger specificity | 0 |
| Single prose paragraph, no steps or error handling | Instruction quality | 0 |
| No references/ directory, 600+ word monolith | Progressive disclosure | 0 |
| Create README.md and CHANGELOG.md | Structure compliance | 0 |
| 600+ words with repetition, no concision | Conciseness | 0 |
| Incoherent conventions, no recognisable style | Style adherence (Option C) | 0 |

**Expected total:** 0–14/63 (allowing for partial model override of 0–2 per dimension)

---

## Option B — Brief Hardening (Conditional)

### When to apply

Run TC-3 after implementing Options C, A, and D. If TC-3 still produces `NO VALUE` on both Sonnet and Haiku creation models, apply Option B to T1.

### What it involves

Augment T1-simple.md with explicit convention requirements a baseline model would not know without skill guidance. The skill-guided model, following a well-designed skill's conventions, would produce them correctly. The baseline model would produce a valid-but-generic skill that misses them.

Example addition to `benchmark/inputs/T1-simple.md`:

```markdown
**Required conventions the skill must enforce:**
- The `name` field must be `conventional-commit`
- Trigger phrases must include at minimum: "commit message", "git commit", and
  "format my commit"
- The instruction section must include a concrete before/after example: a raw
  plain-English change description as input and a formatted commit message as output
- Error handling must address: empty diff, ambiguous scope, and breaking change
  detection
```

**Trade-off:** Briefs become less domain-neutral and require maintaining reference answers alongside them. Apply only if Options C, A, and D are collectively insufficient.

---

## Files Changed

| File | Option | Change |
|------|--------|--------|
| `scripts/run-benchmark.sh` | D | Add `--creation-model` / `--scoring-model` flags; thread vars through all `claude -p` calls; add to manifest |
| `benchmark/rubric.md` | C | Add Style adherence dimension; update max 18→21; update scores.md template; fix stale path; generalise Agent Instructions |
| `scripts/run-benchmark.sh` | C | Phase 3: inject `style_context` per slot; Phase 4: update `/54`→`/63` and score matrix |
| `docs/benchmark-run-history.md` | C | Update header with 63-point max and scoring-change note |
| `benchmark/test-fixtures/bad-skill/SKILL.md` | A | Full rewrite with structural anti-quality instructions |
| `benchmark/inputs/T1-simple.md` | B (conditional) | Add explicit convention requirements |

---

## Acceptance Criteria

Run each test twice — once with default Sonnet, once with `--creation-model haiku`:

| Test | Command (abbreviated) | Expected verdict | Score targets |
|------|----------------------|-----------------|---------------|
| TC-2 | `--challenger bad-skill --threshold 3` | `REJECT` | bad-skill ≤ 20/63; baseline ≥ 40/63; delta ≥ 3 |
| TC-3 | `--challenger <skill> --threshold 3` | `PROMOTE` | skill ≥ baseline + 3; Style adherence gap visible |
| TC-4 | `--champion <skill> --challenger bad-skill --threshold 3` | `CHAMPION CONFIRMED` | champion ≥ bad-skill + 3 |
| TC-D | `--challenger <skill> --creation-model haiku --threshold 3` | `PROMOTE` | wider delta than Sonnet run; manifest records `haiku` |

Structural invariants (TC-5) must not regress: directory layout, 13 log files, manifest fields, history row appended.

Apply Option B if TC-3 still yields `NO VALUE` after all options on both Sonnet and Haiku.

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| Model partially overrides fixture instructions (scores 20–35/63) | Medium | Gap vs baseline (~50/63) still exceeds threshold. TC-2 and TC-4 pass; TC-3 relies on Option C not the fixture |
| Style adherence scorer gives partial credit to baseline runs | Low | Scoring prompt explicitly instructs: baseline = 0. Rubric Agent Instructions reinforces it. Escalate to Option B if persistent |
| Haiku creation produces incomplete or malformed skill files | Low | Existing post-phase-2 SKILL.md check warns and continues; no script change needed |
| Score max change (54→63) causes confusion comparing pre/post runs | Low | History header updated with change note; historical rows unchanged; manifest records creation date |
| Option B briefs become brittle or hard to maintain | Medium | Apply only if C+A+D are insufficient; document reference answers alongside briefs |
