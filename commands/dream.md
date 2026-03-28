---
name: dream
description: Perform a "dream" — a reflective memory consolidation pass. Reviews existing memory files, gathers recent signal from session transcripts, merges updates into topic files, and prunes the index. Only invoke when the user explicitly requests a dream / memory consolidation run; never call this command proactively.
---

# /dream — Memory Consolidation

You are performing a **dream** — a reflective pass over your memory files. The goal is to synthesize what you've learned recently into durable, well-organized memories so that future sessions can orient quickly.

This command works with the auto-memory system described in your system prompt. That section is the source of truth for memory types, file format, and what should or should not be saved. Refer to it throughout.

## Locate the memory directory

The memory directory path is provided in your system prompt's auto-memory section. It follows the pattern:

```
~/.claude/projects/<project-path-hash>/memory/
```

Read your system prompt to find the exact path. If you can't determine it, ask the user.

The **index file** is `MEMORY.md` inside the memory directory.

Session **transcripts** live under `~/.claude/projects/<project-path-hash>/` as JSONL files. These are large — grep narrowly, never read whole files.

---

## Phase 1 — Orient

Get the lay of the land before changing anything.

1. `ls` the memory directory to see what exists
2. Read `MEMORY.md` to understand the current index
3. Skim each existing topic file — understand what's already captured so you improve rather than duplicate
4. Note anything that looks stale, redundant, or contradictory

Report what you found before moving on. The user should understand the current state.

## Phase 2 — Gather recent signal

Look for new information worth persisting. Sources in priority order:

1. **Existing memories that drifted** — facts that contradict what you see in the codebase now. Run quick checks: do referenced files still exist? Are described patterns still accurate? Has the project structure changed?
2. **Transcript search** — if you suspect there's useful context from recent sessions (a decision, a correction, a preference the user expressed), grep the JSONL transcripts for narrow terms:

   ```
   grep -rn "<narrow term>" <transcripts-dir>/ --include="*.jsonl" | tail -50
   ```

3. **Git log** — check recent commits for context on what's changed since memories were last updated

Don't exhaustively read transcripts. Search only for things you already suspect matter based on what you saw in Phase 1.

## Phase 3 — Consolidate

For each thing worth remembering, write or update a memory file. Follow the format and type conventions from your system prompt's auto-memory section — it defines:

- The four memory types (user, feedback, project, reference) and when to use each
- The frontmatter format (name, description, type)
- What NOT to save (code patterns derivable from the repo, git history, debugging solutions, documented items, ephemeral task details)

Priorities:

- **Merge into existing files** rather than creating near-duplicates. If two files cover overlapping topics, combine them.
- **Convert relative dates** ("yesterday", "last week") to absolute dates so they stay interpretable.
- **Delete contradicted facts** — if today's investigation disproves an old memory, fix it at the source rather than adding a correction alongside it.
- **Remove stale memories** — if a memory references something that no longer exists or is no longer true, delete the file entirely.

## Phase 4 — Prune the index

Update `MEMORY.md` so it stays under **200 lines** and under **~25 KB**. It's an index, not a dump.

Each entry should be one line under ~150 characters:

```
- [Title](file.md) — one-line hook
```

Never write memory content directly into `MEMORY.md`.

Checklist:

- Remove pointers to memories that are stale, wrong, or superseded
- Shorten any entry over ~200 characters — move the detail into the topic file
- Add pointers to newly created or important memories
- Resolve contradictions — if two files disagree, fix the wrong one
- Verify every pointer — each linked file should actually exist

---

## Output

When finished, report a brief summary:

- **Added**: new memory files created
- **Updated**: existing files that were revised
- **Removed**: files or index entries that were pruned
- **No changes**: if memories are already clean, say so

Keep the summary concise — the user can read the diffs if they want details.
