---
name: project-build
description: Explicit Project build phase. Implements a planned feature sub-feature by sub-feature, records deviations, runs the feature test command, and updates milestone-status.txt then progress.txt. Use only when the user explicitly invokes $project-build.
---

# Project Build

Use this skill only when explicitly invoked as `$project-build`. It implements a
Gate 4-approved feature from its plan and updates state in source-of-truth-first
order.

## Core Rules

- Read `progress.txt`, the active `milestone-status.txt`, and the feature plan
  fresh from disk.
- Auto-resume from the first unchecked sub-feature.
- One commit per sub-feature is required. Each completed sub-feature must leave
  the codebase in a committable state and have its own commit before continuing.
- When both state files change, write `milestone-status.txt` first and
  `progress.txt` second.
- Run the feature's test command once when all sub-features are complete.
- Record architectural deviations when implementation contradicts the plan or
  architecture document.
- Ask concise chat questions for user choices; use structured input tools when
  available.
- Do not invoke the next skill automatically. Recommend the next explicit skill.
- Read the referenced workflow files before executing their corresponding steps;
  they contain required edge-case handling and artifact formats.

## Workflow

1. Detect the active milestone and target feature from `progress.txt` and
   `milestone-status.txt`.
2. If no feature is `[~] planned, awaiting build`, tell the user to run
   `$project-plan-feature`.
3. Read `references/codebase-refresh.md` and refresh the codebase assessment
   before reading the feature plan.
4. Read the feature plan, parse sub-features, and follow
   `references/build-execution.md` for the implementation loop.
5. When deviation handling is needed, read
   `references/deviation-recording.md`.
6. At feature completion, run the plan's test command, update
   `milestone-status.txt`, then update `progress.txt` feature counts and
   milestone status.

## Reference Files

- `references/build-execution.md`
- `references/codebase-refresh.md`
- `references/deviation-recording.md`
- `references/progress-format.md`

## Completion

Report updated artifacts, test result, sub-feature commits, recorded deviations,
and recommend `$project` for status or `$project-build` for the next planned
feature.
