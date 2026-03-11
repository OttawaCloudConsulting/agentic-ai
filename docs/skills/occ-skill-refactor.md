# OCC Skill Refactor

**Source:** `skills/occ-skill-refactor/`
**Command:** `/occ-skill-refactor`
**Activation:** Manual only — must be invoked explicitly via `/occ-skill-refactor` (auto-triggering disabled)

## Description

Standalone refactor review for existing skills. Runs critique and red-team agents in parallel, compiles a review summary, and gates all changes behind explicit user approval. Use when asked to review, audit, improve, or refactor a skill. Do NOT use to create a new skill from scratch — use occ-skill-creator for that.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with workflow, input requirements, constraints, and reference guidance |
| `references/refactor-protocol.md` | Full protocol for the Refactor Review stage — critique and red-team agent templates, review structure, approval gates, decision logging, and sub-agent prompts |
| `references/anthropic-best-practices.md` | Anthropic official skill best practices used by the red-team agent — naming rules, frontmatter requirements, trigger quality checklist, progressive disclosure, and severity classification |

## Usage

```
/occ-skill-refactor
```

Invoke when you want to review and improve an existing skill. Accepts either a project-bound path (`.claude/skills/<skill-name>/`) or a template path (`skills/<skill-name>/`, or any other project-relative path). If no path is provided, you will be asked which skill to refactor. The skill guides the review process from initial location through parallel critique and red-team evaluation, user approval, requirements gathering, and final refactor application.

## Workflow

### 1. Locate Skill

Resolve the skill path. Read all files in the directory. If `SKILL.md` is missing, stop and report an error.

### 2. Launch Parallel Sub-agents

Launch both simultaneously:

- **Critique agent** — evaluates against internal quality standards (conciseness, degrees of freedom, progressive disclosure, structure, forbidden files). Read `references/refactor-protocol.md` for the prompt template.
- **Red-team agent** — evaluates against `references/anthropic-best-practices.md` (naming, frontmatter, trigger quality, instruction quality, error handling, file conventions). Read `references/refactor-protocol.md` for the prompt template.

Write outputs to:

- `temp/<skill-name>/critique/feedback.md`
- `temp/<skill-name>/red-team/feedback.md`

### 3. Compile Review Summary

Merge both feedback files into `temp/<skill-name>/refactor/review-summary.md`. Present the path to the user and ask them to review it before proceeding.

### 4. Approval Gate

Ask the user directly with these options: proceed with refactor, keep as-is, defer. If declined or deferred, log to `decisions.md` and stop.

### 5. Requirements Gathering

Ask the user up to 3 questions: which change categories to apply, any new requirements, refactor depth (targeted vs full rewrite). Log all answers to `temp/<skill-name>/refactor/decisions.md`.

### 6. Refactor Agent

Apply approved changes in-place to the skill files. Preserve sections not flagged for change in targeted refactors. Log implementation notes to `decisions.md`. Read `references/refactor-protocol.md` for the prompt template.

## Error Handling

- **Path does not exist**: Stop and report. Ask the user to provide a valid skill path.
- **SKILL.md missing**: Stop and report. The directory is not a valid skill.
- **Malformed frontmatter in target skill**: Flag as a critical finding in the critique feedback. Do not skip the review.
- **Conflicting recommendations between critique and red-team agents**: Include both perspectives in the review summary. Let the user decide during the approval gate.
- **Temp directory write failure**: Stop and report the error. Do not proceed without written artifacts.

## Example

```text
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

## When to Use

- When reviewing an existing skill for quality and improvement opportunities
- When auditing a skill against best practices before deployment
- When a skill has known issues that need fixing
- When refactoring a skill based on real-world usage feedback
- When you want structured critique from both design and best-practice perspectives

## When Not to Use

- When creating a new skill from scratch — use occ-skill-creator for that
- When you just want to run an existing skill without reviewing it
- When the task is a simple one-off improvement without formal review

## Related Skills and Commands

- **occ-skill-creator** — for creating new skills from scratch and guiding the initial design process
