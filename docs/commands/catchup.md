# Catchup

**Source:** `commands/catchup.md`
**Command:** `/catchup`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "catch up," "pick up," "check session state")

## Description

Reads persistent project state from memory files and git history to orient at the start of a new session. Reports what is in progress, what is blocked, and what to do next. This is a read-only command — it never begins work, only reports state.

## Usage

```
/catchup
```

No arguments. The command reads from fixed file paths and git state.

## Inputs

| Input | Source | Required |
|---|---|---|
| Last session state | `agents/memory/handoff.md` | No (graceful fallback if missing) |
| Feature status | `progress.txt` | Yes |
| Working tree state | `git status` output | Yes |
| Recent commit history | `git log --oneline -5` output | Yes |
| Active investigations | `agents/investigations/*.md` | No (checked only if referenced) |

## Outputs

| Output | Location | Description |
|---|---|---|
| Session catchup report | Console (stdout) | Structured summary of project state, blockers, uncommitted changes, recent commits, and next steps |

No files are created or modified by this command.

## Workflow

### Step 1 — Read session state

Reads four sources in order:

1. `agents/memory/handoff.md` — the end-of-session state written by the last `/handoff` invocation
2. `progress.txt` — the authoritative source of truth for feature status
3. `git status` — current working tree (uncommitted changes, staged files)
4. `git log --oneline -5` — the five most recent commits

### Step 2 — Check for active investigations

Checks whether any files exist in `agents/investigations/`. If present, reads them and classifies each as active or resolved.

### Step 3 — Report

Presents a structured summary in the following format:

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

If `progress.txt` and `handoff.md` disagree on feature status (e.g., handoff says a feature is in progress but progress.txt shows it complete), the command trusts `progress.txt` as the source of truth and notes the discrepancy.

If `handoff.md` does not exist or contains no session state, the command falls back to `progress.txt` only and reports whatever state is available.

## When to Use

- At the beginning of a new work session to understand current project state
- After running `/clear` to restore context about what was in progress
- When returning to a project after time away
- When another developer (or Claude session) picks up work started by someone else

## When Not to Use

- Do not invoke proactively — only when the user explicitly asks to catch up or check state
- Not needed if you are continuing within the same session and have full context
- If you need to write session state rather than read it, use `/handoff` instead

## Related Commands and Skills

- `/handoff` — Writes the session state that `/catchup` reads. These two commands form a save/load pair.
- `/start-feature` — After catching up, the user typically invokes `/start-feature` to begin or resume work.
- `/investigate` — Active investigations referenced in the catchup report are created and maintained by `/investigate`.
