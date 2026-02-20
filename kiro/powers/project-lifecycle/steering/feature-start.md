# Start Feature Workflow

Begin work on the next feature in the project roadmap.

## When to Use

When the user asks to start a new feature, begin the next feature, or resume work on an in-progress feature.

## Workflow

### 1. Identify the Feature

Read the project's feature tracking (Kiro specs, task list, or progress file) and identify:

- Any feature currently in progress — if found, resume that feature
- The next pending feature — if nothing is in progress

If all features are complete, report that and stop.

### 2. Read Requirements

Locate the requirements for the identified feature. Extract:

- What needs to be built
- Acceptance criteria
- Dependencies on other features

### 3. Mark as In Progress

Update the tracking to reflect the feature is now being worked on. Add the start date.

### 4. Report

Present a summary:

```
STARTING: Feature [number] — [Title]

REQUIREMENTS:
- [Key requirement 1]
- [Key requirement 2]

FILES LIKELY AFFECTED:
- [Based on requirements and existing codebase]

DEPENDENCIES:
- [Cross-feature dependencies]

Ready to begin implementation.
```

## Rules

- Never skip reading the feature tracking — it is the source of truth
- One feature at a time — do not start a new feature if another is in progress
- Follow the requirements exactly — architecture decisions are defined there, not improvised
