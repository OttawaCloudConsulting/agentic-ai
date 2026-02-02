---
name: catchup
description: Read project state from agents/memory/handoff.md and progress.txt to orient at the start of a session. Only invoke when the user explicitly asks to catch up, pick up, or check session state. Never invoke proactively.
---

# /catchup — Resume From Last Session

Read persistent project state and report what's in progress, what's blocked, and what to do next.

## Execution Steps

### Step 1 — Read session state

Read these files in order:

1. **`agents/memory/handoff.md`** — last session's end state
2. **`progress.txt`** — authoritative feature status
3. **`git status`** — current working tree
4. **`git log --oneline -5`** — recent commits

### Step 2 — Check for active investigations

Check if any files exist in `agents/investigations/`. If so, read them and note which are active vs resolved.

### Step 3 — Report

Present a summary:

```
SESSION CATCHUP

Last handoff: [date from handoff.md, or "No previous handoff found"]

CURRENT FEATURE:
  Feature X.Y — [Title]
  Status: [from progress.txt]
  [Summary of what's done and what remains, from handoff.md]

BLOCKERS: [from handoff.md, or "None"]

UNCOMMITTED CHANGES: [from git status]

RECENT COMMITS:
  [last 3-5 commits from git log]

ACTIVE INVESTIGATIONS: [list or "None"]

NEXT STEPS:
  1. [from handoff.md Next Steps]
  2. [...]

Ready to continue.
```

### Step 4 — Reconcile conflicts

If `progress.txt` and `handoff.md` disagree (e.g., handoff says Feature 12.3 is in progress but progress.txt shows it as `[x]`), trust `progress.txt` as the source of truth and note the discrepancy.

If `handoff.md` doesn't exist or says "No previous session state recorded," fall back to `progress.txt` only and report available state.

## Important Rules

- **progress.txt is authoritative** for feature status — handoff.md provides context, not status
- **Don't start working** — this skill only reports state. Wait for user direction.
- **Flag staleness** — if handoff.md date is more than 7 days old, note it may be outdated
- **Read investigations only if referenced** — don't read all files in agents/investigations/ unless handoff.md points to them
