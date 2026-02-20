# Session Management Protocol

**Source:** `rules/defensive-protocol-v2-session-management.md`
**Scope:** All project types — session continuity and quality guidelines for long agentic coding sessions
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

Maintain continuity and quality across long coding sessions through structured checkpoints, context awareness, and clean handoffs.

## Overview

This rule maintains continuity and quality across long agentic coding sessions. It covers checkpoints, context window awareness, handoffs, and irreversible action safeguards. This is one of three v2 modules extracted from the original Defensive Coding Protocol, focused specifically on session lifecycle management.

## Sections

### Checkpoint Mechanism

At each verification checkpoint, perform observable confirmation:

1. Run the relevant test or command.
2. Read the actual output.
3. Record what happened vs. what was expected.
4. If they do not match, stop and reassess before continuing.

A checkpoint is not "I believe this works." A checkpoint is "I ran it, here's what happened." This distinction is critical — subjective confidence is not verification.

### Context Window Management

Addresses context degradation over long sessions where early reasoning scrolls out and assumptions go stale.

**Every approximately 10 actions in long tasks, checkpoint understanding:**

1. Review the original goal and constraints.
2. Verify current understanding still matches the user's intent.
3. Write current state to a checkpoint file — goal, progress, blockers, decisions made, open questions.
4. If unclear on anything, stop and ask the user.

**Degradation signals to watch for in own output:**

- Sloppy or repetitive output.
- Uncertainty about the original goal.
- Repeating work already done.
- Fuzzy reasoning or hand-waving.

When degradation is noticed, the protocol instructs: say "Losing the thread. Checkpointing." Write state to a file, then reassess before continuing.

### Handoff Protocol

When stopping work (at a decision point, context limit, session end, or task completion), capture the following in a handoff file so the next session can resume cleanly:

1. **State of work** — what is done, what is in progress, what is untouched.
2. **Blockers** — why you stopped, what is needed to continue.
3. **Open questions** — unresolved ambiguities or decisions deferred to the user.
4. **Recommendations** — what to do next and why.
5. **Files touched** — created, modified, or deleted during this session.

The format matters less than capturing all five categories. Write to whatever scratch or handoff location the project uses.

### Irreversible Actions

Extra caution required for actions that cannot be undone:

- Database schema changes or migrations.
- Public API modifications.
- Data deletion.
- Git history modifications (rebase, amend, force push).
- Architectural commitments that constrain future options.

For these: pause, state what you are about to do and why, and verify with the user before proceeding. The cost of a 30-second confirmation is negligible compared to the cost of an irreversible mistake.

## Related Rules

- `rules/defensive-protocol-v2-anti-slop.md` — Companion v2 module providing the core guardrails (failure response, autonomy boundaries, pushing back).
- `rules/defensive-protocol-v2-epistemology.md` — Companion v2 module covering reasoning, investigation, and prediction protocols.
- `rules/defensive-protocol.md` — The original full-featured defensive protocol from which this module was extracted.
