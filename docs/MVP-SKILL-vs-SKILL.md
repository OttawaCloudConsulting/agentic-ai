# Skill Creator Benchmark Results

Competitive comparison of `occ-skill-creator` (A) vs `skill-creator` (B).

- **Inputs:** `benchmark/inputs/` — 3 test briefs (T1 simple, T2 medium, T3 complex)
- **Scoring:** `benchmark/rubric.md` — 6 dimensions, 0–3 each, max 18 per run
- **Runner:** `bash scripts/run-benchmark.sh [run-label]`

---

<!-- Runs are appended below. Most recent run first. -->

---

## Run: 20260307T002147Z

- **skill-A:** occ-skill-creator
- **skill-B:** skill-creator (Anthropic plugin)

### Results Matrix

| Dimension              | A/T1 | A/T2 | A/T3 | A total | B/T1 | B/T2 | B/T3 | B total |
|------------------------|------|------|------|---------|------|------|------|---------|
| Frontmatter quality    | 3    | 3    | 3    | 9       | 3    | 3    | 3    | 9       |
| Trigger specificity    | 3    | 3    | 3    | 9       | 3    | 3    | 3    | 9       |
| Instruction quality    | 2    | 3    | 3    | 8       | 3    | 3    | 3    | 9       |
| Progressive disclosure | 3    | 3    | 3    | 9       | 3    | 3    | 3    | 9       |
| Structure compliance   | 3    | 2    | 3    | 8       | 3    | 2    | 3    | 8       |
| Conciseness            | 3    | 3    | 3    | 9       | 3    | 3    | 3    | 9       |
| **TOTAL**              | **17** | **17** | **18** | **52/54** | **18** | **17** | **18** | **53/54** |

### Winner

**skill-B (skill-creator / Anthropic plugin)** — 53/54 vs 52/54. Margin: 1 point.

### Notable findings

- skill-A dropped 1 point on T1 (Instruction quality): no concrete example of a finished commit message in the simple case.
- Both skills dropped 1 point on T2 (Structure compliance): `creation.log` artifact left in the skill bundle — not needed by the agent and shouldn't be present.
- skill-B scored perfect (18/18) on T1 and T3; skill-A scored perfect only on T3.
- Both skills were otherwise equivalent — identical scores on 5 of 6 dimensions across all tasks.
