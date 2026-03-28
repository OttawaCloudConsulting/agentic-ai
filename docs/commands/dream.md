# Dream

**Source:** `commands/dream.md`
**Command:** `/dream`
**Activation:** Manual — invoked via slash command only

## Description

Performs a reflective memory consolidation pass over the project's auto-memory files. Reviews existing memories, gathers recent signal from session transcripts and git history, merges overlapping or duplicate entries, removes stale information, and prunes the index to stay within size limits.

## Usage

```
/dream
```

No arguments. The command locates the memory directory from the system prompt's auto-memory section.

## Inputs

| Input | Source | Required |
|---|---|---|
| Memory directory | `~/.claude/projects/<project-path>/memory/` | Yes |
| Memory index | `MEMORY.md` in memory directory | Yes |
| Topic memory files | `*.md` files in memory directory | Yes |
| Session transcripts | `~/.claude/projects/<project-path>/` JSONL files | No (searched narrowly if relevant) |
| Git history | `git log` output | No (checked for recent context) |

## Outputs

| Output | Location | Description |
|---|---|---|
| Updated memory files | Memory directory | Merged, corrected, or pruned topic files |
| Updated index | `MEMORY.md` | Cleaned index with valid pointers, under 200 lines |
| Consolidation summary | Console (stdout) | Brief report of what was added, updated, or removed |

## Workflow

### Phase 1 — Orient

Reads the memory directory and all existing topic files to understand current state. Reports findings before making changes.

### Phase 2 — Gather recent signal

Checks for new information worth persisting:

1. **Drifted memories** — facts that contradict current codebase state
2. **Transcript search** — narrow grep of JSONL transcripts for suspected important context
3. **Git log** — recent commits for context on what changed since last consolidation

### Phase 3 — Consolidate

Writes or updates memory files following the auto-memory system conventions:

- Merges overlapping files rather than creating duplicates
- Converts relative dates to absolute dates
- Deletes contradicted facts at the source
- Removes memories referencing things that no longer exist

### Phase 4 — Prune the index

Updates `MEMORY.md` to stay under 200 lines and ~25 KB:

- Removes pointers to stale or superseded memories
- Shortens entries over ~200 characters
- Adds pointers to newly created memories
- Verifies every pointer references an existing file

## When to Use

- At the end of a long session to consolidate what was learned
- Periodically to keep memory files organized and current
- When memory files have accumulated duplicates or stale entries
- After a project undergoes significant structural changes

## When Not to Use

- During active work where memory changes would conflict with in-progress tasks
- If the project has no memory files yet (nothing to consolidate)

## Related Commands and Skills

- `/catchup` — Reads project state at session start; `/dream` maintains the memory that `/catchup` benefits from
- `/handoff` — Saves session state; `/dream` consolidates accumulated session knowledge into durable memories
