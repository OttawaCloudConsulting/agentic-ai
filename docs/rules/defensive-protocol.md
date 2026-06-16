# Defensive Coding Protocol

> **RETIRED — Historical Reference Only.** This describes the v1 single-file protocol. The canonical source (`rules/defensive-protocol.md`) was deleted in commit `9e0a6e6`. Use the three v2 modules instead: `rules/defensive-protocol-v2-anti-slop.md`, `rules/defensive-protocol-v2-epistemology.md`, `rules/defensive-protocol-v2-session-management.md`.

**Source:** `rules/defensive-protocol.md` *(deleted — v1 retired)*
**Scope:** All project types — language-agnostic behavioral guidelines for agentic coding sessions
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

**Reality is the arbiter. When observations contradict your model, your model is wrong.** Stop, update your mental model, only then proceed.

## Overview

The Defensive Coding Protocol is a comprehensive epistemological framework for agentic coding. It minimizes false beliefs, catches errors early, and prevents compounding mistakes across long coding sessions. This is the original, full-featured defensive protocol — it covers prediction, failure handling, investigation, session management, and autonomy boundaries in a single file.

## Sections

### Prediction Protocol

Requires making reasoning visible before any action that could fail. Uses a structured template:

- **Before acting:** State the action (`DOING`), the expected outcome (`EXPECT`), the next step if correct (`IF MATCH`), and the response if wrong (`IF MISMATCH`).
- **After acting:** Record the actual result (`RESULT`), whether it matched (`MATCH`), and the conclusion (`THEREFORE`).

The purpose is to create an audit trail. Without explicit predictions, reasoning is invisible and errors compound undetected.

### Failure Response

A strict three-step protocol when anything fails:

1. **Stop** — no retry, no next tool call.
2. **Report** — exact error, theory of why it happened, proposed action, expected outcome.
3. **Wait** — get user confirmation before proceeding.

Uses a structured template: `FAILED`, `THEORY`, `PROPOSE`, then `Proceed?`. The key insight is that failure is signal and silent retry destroys that signal.

### Confusion Response

When surprised by an outcome:

1. **Stop** — do not push through.
2. **Identify** — determine what belief was falsified.
3. **Log** — record the assumption vs. observation in `agents/memory/corrections.md`.

The phrase "this should work" is a red flag indicating the agent's model is wrong, not reality.

### Evidence Standards

Distinguishes between beliefs (theories, unverified) and verified facts (tested, observed, with evidence). Requires stating exactly what was tested rather than generalizing. Affirms that "I don't know" is a valid and valuable output.

### Verification Cadence

Sets a batch size of 3 actions before requiring a checkpoint. A checkpoint requires observable verification: running a test, reading the output, recording what happened, and confirming against expectations. More than 5 actions without verification equals accumulated unjustified beliefs.

### Context Window Management

Addresses context degradation in long sessions where early reasoning scrolls out. Every approximately 10 actions, the agent should:

1. Review the original goal and constraints.
2. Verify current understanding matches intent.
3. Write current state to `agents/memory/checkpoint.md`.
4. If unclear, stop and ask the user.

Degradation signals include sloppy output, uncertain goals, repeated work, and fuzzy reasoning. The protocol instructs the agent to say "Losing the thread. Checkpointing." and write state to memory before continuing.

### Investigation Protocol

Structured approach to debugging unknowns:

1. Create `agents/investigations/[topic].md`.
2. Add a pointer to `agents/memory/checkpoint.md` under Active Investigations.
3. Separate FACTS (verified) from THEORIES (plausible).
4. Maintain 3+ competing hypotheses — never chase just one.
5. Record what was tested, why, what was found, and what it means.

When resolved, move the pointer to Completed Investigations with an outcome summary.

### Root Cause Analysis

Requires thinking at three levels:

- **Immediate cause:** what failed.
- **Systemic cause:** why failure was possible.
- **Root cause:** why the system was designed this way.

Fixing only the immediate cause produces a temporary fix.

### Chesterton's Fence

Before removing or changing anything, articulate why it exists. Challenges three common assumptions:

- "Looks unused" — prove it by tracing references and checking git history.
- "Seems redundant" — determine what problem it was solving.
- "Don't know why it's here" — find out before touching.

Missing context is more likely than pointless code.

### Error Handling

Warns against silent fallbacks such as `or {}` and `try/except: pass`, which convert hard failures into silent corruption. The principle: let it crash, because crashes are data.

### Abstraction Timing

Requires 3 real examples before abstracting. Second time writing similar code, write it again. Third time, consider abstracting. Concrete first, frameworks later.

### Autonomy Boundaries

Before significant decisions, evaluate via a structured checklist:

- Confident this is what user wants?
- If wrong, what is the blast radius?
- Easily undone?
- Would user want to know first?

Lists conditions that should trigger asking the user: ambiguous requirements, unexpected state with multiple explanations, irreversible actions, scope changes, tradeoffs between valid approaches, and situations where being wrong costs more than waiting.

### Contradiction Handling

When instructions conflict or evidence contradicts stated facts: never silently pick one, assume misunderstanding, or proceed without noting. Instead, explicitly surface the contradiction and ask the user which to follow.

### Pushing Back

Defines when and how to push back: when there is concrete evidence an approach will not work, when a request contradicts stated goals, or when downstream effects are visible that the user has not modeled. The method is to state the concern concretely, share information the user might lack, propose an alternative, and defer to the user's decision.

### Handoff Protocol

When stopping work, write to `agents/memory/handoff.md` covering:

1. State of work — done, in progress, untouched.
2. Blockers — why stopped, what is needed.
3. Open questions — unresolved ambiguities.
4. Recommendations — what next, why.
5. Files touched — created, modified, deleted.
6. Active investigations — pointers to any open investigation files.

### Second-Order Effects

Before changing anything, list what reads, writes, or depends on it. The assumption "nothing else uses this" is usually wrong and must be proven.

### Irreversible Actions

Extra caution required for database schemas, public APIs, data deletion, git history modifications, and architectural commitments. The protocol requires pausing and verifying with the user.

### Codebase Navigation

Defines an order of operations: CLAUDE.md first, README.md second, code only if needed. Documentation is O(1); random code is O(n).

### Stop/Undo/Revert Commands

When the user says stop, undo, or revert:

1. Do exactly what was asked.
2. Confirm completion.
3. Stop completely — no "just checking."
4. Wait for explicit instruction.

### Claude-Specific Guidance

Identifies the primary failure mode as optimizing for completion by batching many actions. Counters include: do less and verify more, report observations not assumptions, think first and present theories, understand fixes before applying them, checkpoint when deep in debugging, express uncertainty, and share information even when it means pushing back.

### Summary

The protocol's summary mantra: **When anything fails: STOP, THINK, REPORT, WAIT.** Slow is smooth. Smooth is fast.

## Related Rules

- `rules/defensive-protocol-v2-anti-slop.md` — Lightweight extraction of the core guardrails from this protocol. Adopt as the minimum viable safety net.
- `rules/defensive-protocol-v2-epistemology.md` — Focused extraction of the reasoning and investigation sections with a tiered prediction model.
- `rules/defensive-protocol-v2-session-management.md` — Focused extraction of checkpoints, context window management, handoffs, and irreversible action safeguards.
