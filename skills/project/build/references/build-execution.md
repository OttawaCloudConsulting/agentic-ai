# Build Execution Specification

The complete sub-feature build loop. An executor reading only this file can run
the full flow from prerequisite validation through feature completion. References
`references/progress-format.md` for state file formats and
`references/deviation-recording.md` for architectural deviation handling.

## Prerequisite Validation (BUILD-01)

Read `milestone-status.txt` for the active milestone. Scan the `## Features`
section for any feature at `[~] planned, awaiting build` status (set by `/plan`
at Gate 4 approval). This status indicates a Gate 4-approved plan exists and the
feature is ready for implementation.

**If no features are at `[~] planned, awaiting build` status:**

> "No Gate 4-approved plans found. Run /plan to create a feature plan first."

Stop. Do not proceed.

**If multiple features are at `[~]` status:** Select the first one in file order
(features are ordered by dependency in milestone-status.txt). The user can
override by specifying a feature name.

Extract the `Plan:` path from the selected feature entry (e.g.,
`milestones/01-core-auth/plans/session-management.md`). This path is required --
if the plan file does not exist on disk, report the error and stop.

## Codebase Assessment Refresh (BUILD-02, D-05, D-06, D-07)

**Before reading the feature plan**, refresh the codebase assessment. This
ensures implementation decisions are grounded in current codebase state.

Read `references/codebase-refresh.md` and follow the complete refresh flow. The
refresh produces a standalone commit before any implementation begins.

After the refresh commit (or skip if assessment is current), proceed to Feature
Plan Loading.

## Feature Plan Loading (D-01)

Read the feature plan from the path extracted during Prerequisite Validation.
Parse the `## Sub-Features` section. The checklist format is:

```markdown
## Sub-Features

- [ ] **SF-1: Name** -- Description and scope
- [ ] **SF-2: Name** -- Description and scope
- [x] **SF-3: Name** -- Description and scope
```

Find the first unchecked `[ ]` sub-feature. This is the auto-resume mechanism
(D-01) -- if a previous session completed some sub-features, they are already
marked `[x]` and will be skipped.

**If all sub-features are `[x]`:** Skip directly to Feature Completion. This
happens when a previous session completed all sub-features but was interrupted
before running the test command.

## Sub-Feature Execution Loop (BUILD-03, BUILD-04, D-01, D-03, D-04)

For each unchecked `[ ]` sub-feature, in order:

### 1. Read Sub-Feature Description

Read the sub-feature's description from the plan. Also read:
- The feature's **Approach** section for implementation strategy
- The feature's **Interface Contracts** section for signatures and data shapes
- The feature's **Files to Create/Modify** section for target file paths
- `docs/ARCHITECTURE_AND_DESIGN.md` for architectural constraints

### 2. Implement the Sub-Feature

Write the actual code for this sub-feature in the user's codebase. This is real
implementation -- create files, modify existing code, add imports, write
functions, configure infrastructure.

**During implementation, watch for deviations (D-11, D-13):** If the
implementation contradicts what the feature plan or architecture doc specifies,
follow the deviation recording spec in `references/deviation-recording.md`.

### 3. Commit the Sub-Feature (D-03)

Each completed sub-feature gets its own commit. Use the message format:

```
feat(<feature-slug>): SF-N <sub-feature-name>
```

Where `<feature-slug>` is derived from the feature plan filename (e.g.,
`session-management` from `session-management.md`).

Example:
```
feat(session-management): SF-2 implement data access layer
```

### 4. Mark Sub-Feature Complete (BUILD-04)

Update the feature plan using the Edit tool. Change the sub-feature's marker
from `[ ]` to `[x]`:

Before: `- [ ] **SF-2: Implement data access layer** -- CRUD operations`
After:  `- [x] **SF-2: Implement data access layer** -- CRUD operations`

### 5. Update milestone-status.txt (BUILD-08)

Increment the `Sub-features:` count for this feature in `milestone-status.txt`:

Before: `Sub-features: 1/4 complete`
After:  `Sub-features: 2/4 complete`

### 6. Checklist Recap (D-04)

Display the full Sub-Features checklist with current marks and announce the next
sub-feature:

```
SUB-FEATURE COMPLETE: SF-2: Implement data access layer

## Sub-Features
- [x] **SF-1: Create database schema**
- [x] **SF-2: Implement data access layer**
- [ ] **SF-3: Add API endpoints**
- [ ] **SF-4: Integration tests**

NEXT: SF-3: Add API endpoints
```

### 7. Continue

Return to step 1 with the next unchecked `[ ]` sub-feature. If no unchecked
sub-features remain, proceed to Feature Completion.

## Feature Completion (BUILD-05, BUILD-08, BUILD-09, D-08, D-09)

All sub-features are `[x]`. Run the feature's test command to gate completion.

### Run Test Command (BUILD-05, D-08)

Read the `## Test Command` section from the feature plan. Execute the command
via the Bash tool with a reasonable timeout (default 120 seconds).

```bash
# Example
bash tests/test-session.sh
```

### Test Passes (exit code 0)

Proceed to state file updates.

**Update milestone-status.txt FIRST (STATE-04, BUILD-08):**

Change the feature marker from `[~]` to `[x]`. Set `Sub-features:` to `N/N
complete`. Add `Completed: <ISO date>` to the Notes line.

Before:
```
[~] Feature 01.2: Session Management
    Plan: milestones/01-core-auth/plans/session-management.md
    Sub-features: 3/4 complete
    Notes: Started 2026-04-03.
```

After:
```
[x] Feature 01.2: Session Management
    Plan: milestones/01-core-auth/plans/session-management.md
    Sub-features: 4/4 complete
    Notes: Started 2026-04-03. Completed 2026-04-04.
```

**Update progress.txt SECOND (BUILD-09):**

Increment the feature count in the milestone summary line:

Before: `[~] Milestone 01: Core Auth  milestones/01-core-auth/  2/3 features complete`
After:  `[~] Milestone 01: Core Auth  milestones/01-core-auth/  3/3 features complete`

**If this was the last feature** (completed count equals total count): also
change the milestone marker from `[~]` to `[x]` in `progress.txt`:

```
[x] Milestone 01: Core Auth  milestones/01-core-auth/  3/3 features complete
```

### Test Fails (non-zero exit code, D-09)

Hard stop. Display the failure report:

```
TEST FAILED: <feature plan path>

Command: <test command>
Exit code: <code>

Output:
<full test output>

DIAGNOSIS: <Claude's analysis of why the test failed>

Options:
- Fix       -- Fix the code to match test expectations
- Update    -- Provide a corrected test command
- Exit      -- Stop here; investigate manually
```

Use `AskUserQuestion` with these 3 options (max 12-character headers: Fix,
Update, Exit).

**Fix:** Claude diagnoses and fixes the code to make the test pass. Re-runs the
test command. If it passes, proceed with Feature Completion state updates. If it
fails again, show the failure output and re-offer the same 3 options.

**Update (BUILD-06, D-10):** The user provides a corrected test command. Claude
writes the new command to the feature plan's `## Test Command` section using the
Edit tool. Re-runs the updated command. If it passes, proceed. If it fails, show
the failure output and re-offer options.

**Exit:** Stop the session. Sub-features already marked `[x]` in the feature
plan are preserved. The user investigates manually. The next `/build` invocation
will skip to Feature Completion since all sub-features are already done.

## State File Update Details (STATE-04)

The write-ordering contract is critical for crash safety:

1. **Write `milestone-status.txt` FIRST** -- this is the source of truth for
   feature-level state
2. **Write `progress.txt` SECOND** -- this is the rolled-up milestone summary

If interrupted between writes, `milestone-status.txt` is already correct and
`/project` can detect the divergence on next read. See
`references/progress-format.md` for exact formats.

## Commit Message Format

Sub-feature commits follow this format:

```
feat(<feature-slug>): SF-N <sub-feature-name>
```

Where:
- `<feature-slug>` is kebab-case derived from the feature plan filename (e.g.,
  `session-management` from `session-management.md`)
- `N` is the sub-feature number
- `<sub-feature-name>` is a brief description

The codebase assessment refresh commit uses:
```
docs(assessment): refresh codebase assessment for <feature-name>
```

State file update commits on feature completion use:
```
chore(<feature-slug>): update state files for feature completion
```

## Session Continuity (D-02)

If the context window is filling up or the session needs to end:

1. **Mark all completed sub-features `[x]`** in the feature plan (should already
   be done incrementally)
2. **Commit** any uncommitted work
3. **Update `milestone-status.txt`** with current sub-feature count

The plan checklist IS the continuity mechanism. No separate resume file or state
tracking is needed. The next `/build` invocation:

1. Reads `milestone-status.txt` to find the feature in progress
2. Reads the feature plan
3. Finds the first `[ ]` sub-feature
4. Resumes from there

This auto-resume design (D-01) ensures that multi-session builds work
transparently. Each session picks up exactly where the last one left off.

## Anti-Patterns

- **Running tests per sub-feature** -- D-08 specifies tests at feature
  completion only. Sub-features are validated by committable state.
- **Auto-retrying failed tests** -- D-09 requires hard stop with diagnosis and
  user choice. No automatic retry loop.
- **Writing progress.txt before milestone-status.txt** -- violates STATE-04
  write-ordering contract.
- **Skipping codebase assessment refresh** -- D-06 requires refresh BEFORE
  reading the feature plan.
- **Omitting checklist recap** -- D-04 requires full checklist display after
  each sub-feature to keep the user oriented.
- **Auto-recording deviations without user confirmation** -- D-11 requires user
  confirms or dismisses each detected deviation.
