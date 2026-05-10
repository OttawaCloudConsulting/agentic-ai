# Project Codex Skills

**Source:** `codex-skills/project/`
**Entry Skill:** `$project`
**Activation:** Manual only. The project suite is used only when the user explicitly invokes a project skill.
**Detailed Docs:** [docs/codex-skills/project.md](../codex-skills/project.md)

**Note:** This page is a Codex skill-suite summary, not a slash-command skill page. The commands below use `$project-*` invocation names and are documented separately from the legacy `/project` slash-command suite.

## Purpose

The Project Codex skills provide a gated project delivery workflow for Codex. The suite bootstraps project state, defines requirements, creates architecture, breaks work into milestones and feature plans, implements planned features, and captures technical spikes. State is tracked in plain-text project artifacts so Codex can resume work across sessions without relying on chat history.

## Skill Suite

| Skill | Purpose | Primary Outputs |
|---|---|---|
| `$project` | Bootstrap `progress.txt`, report status, validate state, and recommend the next skill | `progress.txt` on bootstrap; status report in chat |
| `$project-define` | Run Codebase Alignment, optional Working Backwards, and Scope Review | `.project/{slug}/docs/codebase-assessment.md`, `.project/{slug}/docs/working-backwards.md`, `prd.md`, review files |
| `$project-design` | Produce or refresh architecture and design documentation | `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`, Gate 2 review file |
| `$project-milestone` | Define or revise one milestone at a time | `.project/{slug}/milestones/<NN>-<name>/README.md`, `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt` |
| `$project-plan-feature` | Create or revise one feature implementation plan | `.project/{slug}/milestones/<NN>-<name>/plans/<feature>.md` |
| `$project-build` | Implement a planned feature sub-feature by sub-feature | Code changes, commits, updated status files, deviation notes when needed |
| `$project-spike` | Run adversarial technical research and track spike state | `.project/{slug}/docs/spikes/<topic>.md`, spike entries in `progress.txt` |

## When to Use

- Starting a new gated project with Codex
- Checking project status and deciding what to do next
- Creating a PRD, architecture document, milestones, and implementation plans in a controlled sequence
- Implementing approved feature plans while keeping progress files current
- Researching uncertain technical questions without mixing research and red-team review contexts

## Workflow Summary

1. Run `$project` first to create or read `progress.txt`.
2. Run `$project-define` to complete Gates 0, WB, and 1.
3. Run `$project-design` to complete Gate 2.
4. Run `$project-milestone` to define one milestone for Gate 3.
5. Run `$project-plan-feature` to approve a Gate 4 feature plan.
6. Run `$project-build` to implement the planned feature.
7. Use `$project-spike` whenever a technical uncertainty needs isolated research.
8. Return to `$project` for status, validation, routing, and Gate 3 closure.

## State Model

The suite uses `progress.txt` as the project-level state file and `.project/{slug}/milestones/*/milestone-status.txt` as per-milestone state. Both use four checkbox markers:

| Marker | Meaning |
|---|---|
| `[x]` | Complete |
| `[~]` | In progress |
| `[ ]` | Pending |
| `[-]` | Skipped or not applicable |

When both `milestone-status.txt` and `progress.txt` need updates, the milestone status file is written first. `$project` treats `milestone-status.txt` as the source of truth for feature completion and blocks routing when milestone counts diverge.

## Related Documentation

- [Project Codex Skills Detailed Guide](../codex-skills/project.md)
