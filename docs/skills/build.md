# /build

**Source:** `skills/project/build/`
**Command:** `/build`
**Activation:** Manual only (`disable-model-invocation: true`) -- invoked via slash command. Not auto-triggered by conversational phrases.

## Purpose

Sub-feature-by-sub-feature implementation skill that executes Gate 4-approved feature plans. Each invocation implements one feature (or continues a partially-completed build). Refreshes codebase assessment before each new feature. Each completed sub-feature gets its own commit. Runs the feature's test command on completion. Records architectural deviations when implementation diverges from the plan. Updates both `milestone-status.txt` and `progress.txt` on feature completion. Supports multi-session builds via auto-resume from the feature plan checklist.

## When to Use

- Implementing a feature after it has been planned (Gate 4 approved)
- Continuing a partially-completed feature build (auto-resumes)
- Building the next feature in a milestone

## When NOT to Use

- When you want to check project status or get routing (use `/project`)
- When you want to define project scope or create a PRD (use `/define`)
- When you want to design system architecture (use `/design`)
- When you want to define milestones and features (use `/milestone`)
- When you want to plan a feature (use `/plan-feature`)

## Behavior

### 1. State Detection

Reads `progress.txt` from the project root and finds the active milestone (first at `[ ]` or `[~]` status). Reads that milestone's `milestone-status.txt`. Auto-selects the first feature at `[~] planned, awaiting build` status. The user can override with an explicit feature name. If no features are at `[~] planned, awaiting build`, reports that no planned features are ready and suggests running `/plan-feature`. If all sub-features are already `[x]` but the feature is not yet marked complete, skips directly to Feature Completion.

### 2. Codebase Assessment Refresh

Before reading the feature plan, performs an incremental refresh of `.project/{slug}/docs/codebase-assessment.md`. Uses `git log` to find the last assessment update date, then identifies all files changed since then. If no files have changed, skips the refresh. Otherwise, spawns a sub-agent to read only the changed files and update the relevant assessment sections (Recent Changes, File Organization, Detected Patterns, Dependency Graph, Assumptions, Patterns to Deviate From). The refresh produces a standalone commit before any implementation begins.

### 3. Sub-Feature Execution

Loads the feature plan from the path recorded in `milestone-status.txt`. Parses the Sub-Features checklist and finds the first unchecked `[ ]` sub-feature (auto-resume mechanism for multi-session builds). For each sub-feature in order:

1. Reads the sub-feature description, Approach, Interface Contracts, Files to Create/Modify, and architecture doc
2. Implements the sub-feature -- writes actual code in the user's codebase
3. Commits the sub-feature with message format `feat(<feature-slug>): SF-N <name>`
4. Marks the sub-feature `[x]` in the feature plan
5. Updates `milestone-status.txt` sub-feature count
6. Displays the full Sub-Features checklist with current marks and announces the next sub-feature

### 4. Deviation Recording

During implementation, watches for contradictions between the code being written and what the feature plan or `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md` specifies. When a deviation is detected, pauses implementation and presents the deviation to the user with context on what was planned vs. what changed. The user confirms (Record) or dismisses the deviation. Confirmed deviations are written immediately to the feature plan's `## Architectural Deviations` section as a structured 4-field entry: What changed, Originally planned, Why necessary, Impact. After 3+ deviations, suggests running `/design` in refresh mode.

### 5. Feature Completion

After all sub-features are `[x]`, runs the feature's test command from the plan's `## Test Command` section. On success, updates state files in order: `milestone-status.txt` first (marks feature `[x]`, sets sub-features to N/N, adds completion date), then `progress.txt` (increments feature count on the milestone summary line; marks milestone `[x]` if this was the last feature). On test failure, performs a hard stop with diagnosis and presents three options: Fix (Claude repairs the code), Update (user provides corrected test command), or Exit (user investigates manually).

### 6. Multi-Session Support

The feature plan checklist is the continuity mechanism. Each completed sub-feature is marked `[x]` and committed incrementally. On the next `/build` invocation, the skill re-reads state files, finds the feature in progress, loads the plan, and resumes from the first unchecked `[ ]` sub-feature. No separate resume file or state tracking is needed. If the context window fills during a build, the skill commits any uncommitted work and updates `milestone-status.txt` with the current sub-feature count.

## Artifacts

| Artifact | Path | Created By |
|----------|------|------------|
| Updated feature plan | `.project/{slug}/milestones/<NN>-<name>/plans/<feature-slug>.md` | /build (marks sub-features, records deviations) |
| milestone-status.txt | `.project/{slug}/milestones/<NN>-<name>/milestone-status.txt` | /build (updates sub-feature counts, marks completion) |
| progress.txt | `progress.txt` | /build (increments feature counts, marks milestone completion) |
| Codebase assessment | `.project/{slug}/docs/codebase-assessment.md` | /build (incremental refresh via sub-agent) |
| Sub-feature commits | Git history | /build (one commit per sub-feature) |

## Skill Files

```
skills/project/build/
+-- SKILL.md                              # Flow controller (~144 lines)
+-- references/
    +-- build-execution.md                # Complete sub-feature build loop spec
    +-- codebase-refresh.md               # Incremental codebase assessment refresh spec
    +-- deviation-recording.md            # Architectural deviation detection and recording spec
    +-- progress-format.md                # State file format spec (own copy per D-04)
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `/project` | Reads `progress.txt` for milestone status; routes users to `/build` |
| `/plan-feature` | Produces Gate 4-approved feature plans that `/build` consumes |
| `/design` | Refresh mode consolidates deviations recorded by `/build` |
