---
name: project
description: Project orchestrator for explicit use only. Bootstraps progress.txt, reports project state, validates existing Project artifacts, and recommends the next Project skill. Use only when the user explicitly invokes $project or asks to use this skill for project status/routing.
---

# Project Orchestrator

Use this skill only when explicitly invoked as `$project`. It bootstraps project
state on first run, reports status, validates artifacts, and recommends the next
Project skill. It preserves compatibility with existing Project artifacts from
the original Project suite.

## Core Rules

- Read `progress.txt` and all referenced milestone state fresh from disk every time.
- After bootstrap, do not modify files except for the explicit Gate WB state
  decisions and Gate 3 closure described in `references/routing-logic.md`.
- Route, do not dispatch. Tell the user which explicit skill to run next:
  `$project-define`, `$project-design`, `$project-milestone`,
  `$project-plan-feature`, `$project-build`, or `$project-spike`.
- Use concise chat questions for choices; use structured input tools when they
  are available, otherwise ask directly in chat.
- Preserve the on-disk formats in `references/progress-format.md`.
- When state diverges, treat `milestone-status.txt` as the source of truth and
  block routing until the user acknowledges the discrepancy.
- If `progress.txt` exists but is empty, incomplete, or malformed, report the
  issue and do not re-bootstrap or overwrite it.
- Read the referenced workflow files before executing their corresponding steps;
  they contain required edge-case handling and artifact formats.

## Workflow

1. If `progress.txt` is missing, read `references/progress-format.md`, determine
   greenfield vs. brownfield, ask or derive the project name, create the bootstrap
   template, read it back, verify it was created correctly, and report it.
   If `progress.txt` exists but is not parseable, stop and report the malformed
   state instead of attempting a second bootstrap.
2. Parse gates, milestones, spikes, and milestone status files from disk.
3. Read `references/routing-logic.md` and validate approved gate artifact paths
   plus milestone feature counts.
4. Read `references/status-report-format.md` and display the full status report.
5. Apply routing from `references/routing-logic.md`, including Gate WB and Gate 3
   closure offers when applicable.

## Reference Files

- `references/progress-format.md`: exact `progress.txt` and
  `milestone-status.txt` notation.
- `references/routing-logic.md`: validation, routing, Gate WB, and Gate 3 closure.
- `references/status-report-format.md`: user-facing status report shape.

## Errors

Report malformed state files instead of repairing them. Missing approved gate
artifacts are warnings only. Milestone count divergence blocks routing until the
user acknowledges which state is authoritative.
