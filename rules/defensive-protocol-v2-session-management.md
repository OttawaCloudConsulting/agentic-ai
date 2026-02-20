# Session Management Protocol

> Maintains continuity and quality across long agentic coding sessions. Covers checkpoints, context window awareness, handoffs, and irreversible action safeguards.

## Checkpoint Mechanism

At each verification checkpoint, perform observable confirmation:

1. Run the relevant test or command
2. Read the actual output
3. Record what happened vs what was expected
4. If they don't match, stop and reassess before continuing

A checkpoint is not "I believe this works." A checkpoint is "I ran it, here's what happened."

---

## Context Window Management

Context degrades over long sessions. Early reasoning scrolls out and assumptions go stale.

**Every ~10 actions in long tasks, checkpoint your understanding:**

1. Review the original goal and constraints
2. Verify your current understanding still matches the user's intent
3. Write current state to a checkpoint file — goal, progress, blockers, decisions made, open questions
4. If unclear on anything, stop and ask the user

**Degradation signals — watch for these in your own output:**

- Sloppy or repetitive output
- Uncertain about the original goal
- Repeating work already done
- Fuzzy reasoning or hand-waving

When you notice degradation: say "Losing the thread. Checkpointing." Write state to a file, then reassess before continuing.

---

## Handoff Protocol

When stopping work (decision point, context limit, session end, or task complete), capture the following information in a handoff file so the next session can resume cleanly:

1. **State of work** — what's done, what's in progress, what's untouched
2. **Blockers** — why you stopped, what's needed to continue
3. **Open questions** — unresolved ambiguities or decisions deferred to the user
4. **Recommendations** — what to do next and why
5. **Files touched** — created, modified, or deleted during this session

Write this to whatever scratch or handoff location the project uses. The format matters less than capturing all five categories.

---

## Irreversible Actions

Extra caution required for actions that cannot be undone:

- Database schema changes or migrations
- Public API modifications
- Data deletion
- Git history modifications (rebase, amend, force push)
- Architectural commitments that constrain future options

For these: pause, state what you're about to do and why, and verify with the user before proceeding. The cost of a 30-second confirmation is negligible compared to the cost of an irreversible mistake.
