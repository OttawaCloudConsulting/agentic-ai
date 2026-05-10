---
name: build
description: >
  Sub-feature-by-sub-feature implementation from Gate 4-approved plans.
  Refreshes codebase assessment, implements code, tracks deviations, runs
  tests, and updates state files. Supports multi-session builds via
  auto-resume. Use when implementing a feature, building code, or
  continuing a build session.
disable-model-invocation: true
---

# /build -- Feature Implementation

Implements features sub-feature by sub-feature from Gate 4-approved plans.
Each sub-feature leaves the codebase in a committable state. Refreshes
codebase assessment before each new feature. Runs the feature's test command
on completion. Records architectural deviations when implementation diverges
from the plan. Updates both `milestone-status.txt` and `progress.txt`.

## Rules

1. **Read fresh every time.** Read `progress.txt` and `milestone-status.txt`
   from disk on every invocation -- never rely on conversation memory
   (STATE-03).
2. **One commit per sub-feature.** Each completed sub-feature gets its own
   commit (D-03). The codebase must be committable after every sub-feature.
3. **Checklist recap after each sub-feature.** Display the full Sub-Features
   checklist with current `[x]`/`[ ]` marks and announce the next sub-feature
   (D-04).
4. **Write-ordering contract.** When updating state files: write
   `milestone-status.txt` FIRST, then `progress.txt` (STATE-04). Never write
   progress.txt without having already written milestone-status.txt.
5. **Interactive prompts.** Use `AskUserQuestion` for all user-facing choices
   (2-4 options, max 12-character headers).
6. **No auto-dispatch.** Tell the user what to run next after completion.
   Never auto-invoke another skill.
7. **Test at feature completion only.** Run the test command once after all
   sub-features are done (D-08). Do NOT run tests per sub-feature.

## Prerequisites

- Working directory is the project root (where `progress.txt` lives).
- `progress.txt` must exist. If not, instruct user to run `/project` first.
- An active milestone must exist with at least one feature at
  `[~] planned, awaiting build` status in its `milestone-status.txt`.

## Step 1 -- Detect State and Target Feature

Read `progress.txt` from the project root. Find the line starting with
`# Project-ID:`, take the value after `:`, trim whitespace, and use it as `<slug>`.
Construct the artifact base path: `.project/<slug>/`. All artifact reads and writes
in this skill use this base path. If the header is missing, report the error and tell
the user to run `/project` to re-bootstrap.

Find the active milestone (first at `[ ]` or `[~]` status). Read that milestone's
`milestone-status.txt` at `.project/<slug>/milestones/<NN>-<name>/milestone-status.txt`.
Find the target feature:

- **Auto-detect:** First feature at `[~] planned, awaiting build` status
  (D-01 auto-resume).
- **User override:** User can specify an explicit feature name argument.
- **All sub-features done:** If the target feature has all sub-features
  `[x]` but is not yet marked complete, skip to Step 4 (Feature Completion).
- **No planned features:** If no features are at `[~] planned, awaiting
  build`, report: "No planned features ready for build. Run /plan-feature to plan a
  feature first." End session.

## Step 2 -- Refresh Codebase Assessment

Read `references/codebase-refresh.md` and follow the incremental refresh
specification (BUILD-02, D-05, D-06, D-07).

This refresh runs BEFORE reading the feature plan. It ensures implementation
decisions are grounded in current codebase state. The refresh produces a
standalone commit before any implementation begins.

## Step 3 -- Load Feature Plan and Begin Build

Read the feature plan from the path recorded in `milestone-status.txt`.
Parse the Sub-Features checklist. Find the first unchecked `[ ]` sub-feature
(D-01 auto-resume). If resuming a partially-completed build, report which
sub-features are already done.

Read `references/build-execution.md` and follow the Sub-Feature Execution
Loop section. For each sub-feature: implement, commit, mark `[x]` in the
plan, update `milestone-status.txt` sub-feature count, display checklist
recap.

For deviation handling during implementation, read
`references/deviation-recording.md` (BUILD-07, D-11, D-12, D-13). When the
implementation contradicts what the feature plan or architecture doc
specifies, follow the detection and confirmation flow in that reference.

## Step 4 -- Feature Completion

Read `references/build-execution.md` and follow the Feature Completion
section (BUILD-05, BUILD-08, BUILD-09, D-08, D-09, D-10).

1. Run the feature's test command from the plan's `## Test Command` section.
2. **Test passes:** Update `milestone-status.txt` FIRST -- mark feature
   `[x]` complete, set sub-features to N/N, add completion date. Then update
   `progress.txt` -- increment feature count on the milestone summary line.
   If this was the last feature, mark the milestone `[x]` in `progress.txt`.
3. **Test fails:** Hard stop with diagnosis and options (Fix, Update, Exit).
   Follow failure handling in `references/build-execution.md`.

## Step 5 -- Completion Report

Display summary:

```
FEATURE COMPLETE: [Feature NN.N: Name]

ARTIFACTS UPDATED:
- <feature plan path> (sub-features marked [x], deviations recorded)
- milestone-status.txt (feature: [x] complete)
- progress.txt (milestone: N/M features complete)

COMMITS: N sub-feature commits + 1 assessment refresh

NEXT: Build next feature, or run /project to check status.
```

If deviations were recorded, add:

```
DEVIATIONS: N recorded. Consider running /design refresh to consolidate.
```

## Error Handling

- **Missing progress.txt:** Do not proceed. Tell user to run `/project`
  first.
- **No active milestone:** Do not proceed. Tell user to run `/milestone`
  first.
- **No planned features:** Report available features and their statuses.
  Suggest running `/plan-feature`.
- **Missing feature plan file:** Report inconsistency --
  `milestone-status.txt` references a plan that doesn't exist on disk.
  Suggest running `/plan-feature` to re-plan the feature.
- **Missing codebase assessment:** Warn but continue -- `/build` can proceed
  without it (see `references/codebase-refresh.md` edge cases).
- **Test command fails:** Follow failure handling in
  `references/build-execution.md` (D-09). Hard stop with diagnosis and
  options.
- **Context window filling:** Follow session continuity in
  `references/build-execution.md` (D-02). Mark completed work, commit,
  report resume instructions.
- **Interrupted session:** User re-invokes `/build`. Skill re-reads state
  files, auto-resumes from first unchecked sub-feature (D-01).
