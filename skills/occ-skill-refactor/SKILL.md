---
name: occ-skill-refactor
description: Reviews and refactors an existing skill against quality standards. Accepts a skill path (e.g. skills/<skill-name>/ or .claude/skills/<skill-name>/). Invoke explicitly with /occ-skill-refactor. Do NOT use to create a new skill from scratch.
disable-model-invocation: true
license: Apache-2.0
---

# Skill Refactor

Standalone refactor review for existing skills. Runs critique and red-team agents in parallel, compiles a review summary, and gates all changes behind explicit user approval.

## Input

Accept one of:

- Project-bound path: `.claude/skills/<skill-name>/`
- Template path: `skills/<skill-name>/` (or any other project-relative path)

If the user does not provide a path, ask which skill to refactor before proceeding.

Confirm the directory exists and contains `SKILL.md` before launching sub-agents.

## Workflow

Reference files used in this workflow:

- `references/refactor-protocol.md` — sub-agent prompt templates, output formats, temp directory structure, AskUserQuestion schemas, and decisions log template. Read before launching any sub-agent.
- `references/anthropic-best-practices.md` — Anthropic's official skill standards. The red-team agent reads this file directly to evaluate the target skill. Consult it to understand the evaluation criteria.

### 1. Locate skill

Resolve the skill path. Read all files in the directory. If `SKILL.md` is missing, stop and report.

### 2. Launch parallel sub-agents

Launch both simultaneously:

- **Critique agent** — evaluates against internal quality standards (conciseness, degrees of freedom, progressive disclosure, structure, forbidden files).
- **Red-team agent** — evaluates against Anthropic's official standards using `references/anthropic-best-practices.md` (naming, frontmatter, trigger quality, instruction quality, error handling, file conventions).

Write outputs to:

- `temp/<skill-name>/critique/feedback.md`
- `temp/<skill-name>/red-team/feedback.md`

### 3. Compile review summary

Merge both feedback files into `temp/<skill-name>/refactor/review-summary.md`. Present the path `temp/<skill-name>/refactor/review-summary.md` to the user and ask them to review it before proceeding.

### 4. Approval gate

Ask the user directly with these options: proceed with refactor, keep as-is, defer. If declined or deferred, log to `decisions.md` and stop.

### 5. Requirements gathering

Ask the user the 3 questions defined in `references/refactor-protocol.md` under "Requirements Gathering":
1. Which change categories to apply (multi-select: critical / should-fix / nice-to-have / specify below)
2. Any new requirements or direction changes
3. Refactor depth — targeted (fix selected issues only) vs full rewrite (only ask if scope is unclear)

Log all answers to `temp/<skill-name>/refactor/decisions.md`.

### 6. Refactor agent

Apply approved changes in-place to the skill files. Preserve sections not flagged for change in targeted refactors. Log implementation notes to `decisions.md`.

## Error Handling

- **Path does not exist**: Stop and report. Ask the user to provide a valid skill path.
- **SKILL.md missing**: Stop and report. The directory is not a valid skill.
- **Malformed frontmatter in target skill**: Flag as a critical finding in the critique feedback. Do not skip the review.
- **Conflicting recommendations between critique and red-team agents**: Include both perspectives in the review summary. Let the user decide during the approval gate.
- **Temp directory write failure**: Stop and report the error. Do not proceed without written artifacts.

## Example

```
User: /occ-skill-refactor skills/occ-skill-creator/

1. Locate skill  -> reads skills/occ-skill-creator/SKILL.md + references/
2. Sub-agents     -> writes temp/occ-skill-creator/critique/feedback.md
                     writes temp/occ-skill-creator/red-team/feedback.md
3. Review summary -> writes temp/occ-skill-creator/refactor/review-summary.md
4. Approval gate  -> asks user: proceed / keep as-is / defer
5. Requirements   -> asks user: change scope, new requirements, depth
6. Refactor       -> applies approved changes in-place
```

## Constraints

- Never modify skill files without explicit user approval
- Write all intermediate artifacts to `temp/<skill-name>/` before any approval gate
- Log all user decisions and implementation choices to `decisions.md`
