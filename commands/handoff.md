---
name: handoff
description: Write session state to agents/memory/handoff.md before ending a work session. Only invoke when the user explicitly says to hand off, wrap up, or end the session. Never invoke proactively.
disable-model-invocation: true
---

# /handoff — Write Session State

Capture the current session state to `agents/memory/handoff.md` so the next session can pick up where this one left off.

## When to Use

- Before running `/clear`
- Before closing the terminal
- At the end of a work session
- When context is getting high and you want to preserve state before it auto-compacts

## Execution Steps

### Step 1 — Gather current state

Read these files to understand where things stand:

1. **`progress.txt`** — current feature status
2. **`CHANGELOG.md`** — most recent entries (last 2-3 features)
3. **`git status`** — any uncommitted changes
4. **`git log --oneline -5`** — recent commits

### Step 2 — Write handoff

Write `agents/memory/handoff.md` with this structure:

```markdown
# Session Handoff

**Date:** YYYY-MM-DD
**Branch:** [current git branch]

## Current Feature
- **Feature:** X.Y — [Title]
- **Status:** [not started | in progress | gates pending | complete]
- **What's done:** [bullet list of completed work]
- **What remains:** [bullet list of remaining work]

## Blockers
[Any unresolved issues, or "None"]

## Uncommitted Changes
[List of modified files from git status, or "Working tree clean"]

## Recent Decisions
[Key decisions made during this session that affect future work]

## Open Questions
[Anything unresolved that needs user input]

## Active Investigations
[Pointers to any agents/investigations/*.md files, or "None"]

## Next Steps
[What to do when resuming — ordered list]
```

### Step 3 — Confirm

Report to the user:

```
SESSION STATE SAVED to agents/memory/handoff.md

Current feature: X.Y — [Title] ([status])
Uncommitted changes: [count or "none"]
Blockers: [count or "none"]
Next step: [first item from Next Steps]

Safe to /clear or close terminal.
```

## Important Rules

- **Always read before writing** — check current state, don't assume from conversation memory
- **Be specific** — "NLB construct is half-built" not "working on networking"
- **Include file paths** — reference exact files that were being edited
- **Capture decisions** — these are the most valuable thing to preserve across sessions
- **Overwrite the file** — each handoff replaces the previous one (it's current state, not a log)
