# Benchmark Scoring Rubric

Used by the scoring agent to score each skill output. Score each dimension 0–3.

**Max score per input: 21**

## Dimensions

| Dimension | 0 | 1 | 2 | 3 |
|-----------|---|---|---|---|
| **Frontmatter quality** | Missing `name` or `description` | Incomplete triggers in description | Triggers present, could be more specific | Complete: `name`, `description` with specific trigger phrases |
| **Trigger specificity** | No triggers | Vague/generic phrases only | Specific but narrow coverage | Multi-phrase, covers edge cases, no false positives, <1024 chars |
| **Instruction quality** | No actionable steps | Steps present but no error handling | Steps + error handling | Steps + error handling + at least one concrete example |
| **Progressive disclosure** | SKILL.md >500 lines or no reference splits | Oversized, references missing | Appropriate size with some references | SKILL.md lean (<500 lines), references loaded on demand |
| **Structure compliance** | Forbidden files present (README, CHANGELOG, etc.) | Incorrect directory structure | Correct structure | Correct structure, no auxiliary docs, only what the agent needs |
| **Conciseness** | Heavy filler / boilerplate | Noticeable padding | Mostly lean | Every line justified — no wasted tokens |
| **Style adherence** | No skill loaded (baseline), OR skill loaded but output ignores all its conventions | Output follows some conventions from the loaded skill (e.g. has frontmatter but structure diverges) | Output follows most conventions — correct frontmatter format, appropriate section structure, similar prose style | Output fully consistent with loaded skill — frontmatter matches exactly, trigger phrase style matches, structure and prose style match throughout |

## Output Format

Each agent writes scores to `benchmark/runs/<run>/scores/<slot>/<input>/scores.md`:

```markdown
# Scores: <skill-id> / <input-id>

| Dimension              | Score (0-3) | Notes |
|------------------------|-------------|-------|
| Frontmatter quality    |             |       |
| Trigger specificity    |             |       |
| Instruction quality    |             |       |
| Progressive disclosure |             |       |
| Structure compliance   |             |       |
| Conciseness            |             |       |
| Style adherence        |             |       |
| **TOTAL**              | **/21**     |       |
```

## Agent Instructions

**Scope:** Score only files that are part of the skill bundle (SKILL.md, references/, scripts/). Ignore any other files present in the directory.

**Style adherence:** The scoring prompt will provide either the loaded skill's content (for skill-guided slots) or an explicit instruction to score 0 (for baseline slots). Apply accordingly — do not attempt to infer which skill was loaded from the output alone.

Score all 7 dimensions using this rubric. Scores are compiled into the results matrix in `docs/benchmark-run-history.md`.
