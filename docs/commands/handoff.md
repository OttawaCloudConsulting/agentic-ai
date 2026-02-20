# Handoff

**Source:** `commands/handoff.md`
**Command:** `/handoff`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "hand off," "wrap up," "end the session")

## Description

Captures the current session state to `agents/memory/handoff.md` so the next session can pick up where this one left off. Reads current project state from multiple sources, writes a structured handoff document, and confirms completion. Each invocation overwrites the previous handoff — it records current state, not a log.

## Usage

```
/handoff
```

No arguments. The command reads from fixed file paths and git state.

## Inputs

| Input | Source | Required |
|---|---|---|
| Feature status | `progress.txt` | Yes |
| Recent changelog entries | `CHANGELOG.md` (last 2-3 features) | Yes |
| Working tree state | `git status` output | Yes |
| Recent commit history | `git log --oneline -5` output | Yes |

## Outputs

| Output | Location | Description |
|---|---|---|
| Session handoff document | `agents/memory/handoff.md` | Structured state capture including current feature, blockers, uncommitted changes, recent decisions, open questions, active investigations, and next steps |
| Confirmation report | Console (stdout) | Brief summary confirming the handoff was saved |

## Workflow

### Step 1 — Gather current state

Reads these files to understand where things stand:

1. `progress.txt` — current feature status
2. `CHANGELOG.md` — most recent entries (last 2-3 features)
3. `git status` — any uncommitted changes
4. `git log --oneline -5` — recent commits

### Step 2 — Write handoff

Writes `agents/memory/handoff.md` with this structure:

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

Reports to the user:

```
SESSION STATE SAVED to agents/memory/handoff.md

Current feature: X.Y — [Title] ([status])
Uncommitted changes: [count or "none"]
Blockers: [count or "none"]
Next step: [first item from Next Steps]

Safe to /clear or close terminal.
```

## When to Use

- Before running `/clear` to preserve context
- Before closing the terminal at the end of a work session
- When context window is getting high and you want to preserve state before auto-compaction
- At the end of a work session to enable seamless pickup later

## When Not to Use

- Do not invoke proactively — only when the user explicitly asks to hand off, wrap up, or end the session
- Not needed mid-session if you have full context and plan to continue working
- If you need to read session state rather than write it, use `/catchup` instead

## Related Commands and Skills

- `/catchup` — Reads the `agents/memory/handoff.md` file written by this command. These two commands form a save/load pair.
- `/investigate` — Active investigations are referenced in the handoff document under the Active Investigations section.
- `/start-feature` — The handoff captures which feature is current, and `/start-feature` resumes or begins the next one.
