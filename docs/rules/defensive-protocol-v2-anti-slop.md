# Anti-Slop Discipline

> **Description document.** This summarizes the installable rule at `rules/defensive-protocol-v2-anti-slop.md`. Copy that file to `.claude/rules/` in the target repo — do not copy this file.

**Source:** `rules/defensive-protocol-v2-anti-slop.md`
**Scope:** All project types — language-agnostic behavioral guardrails for agentic coding sessions
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

**Reality is the arbiter. When observations contradict your model, your model is wrong.** Stop, update your mental model, only then proceed.

## Overview

Anti-Slop Discipline is the minimum viable safety net for agentic coding sessions. It prevents compounding errors, wasted effort, and spurious output. This is a focused extraction from the full Defensive Coding Protocol, containing only the core guardrails. If you adopt nothing else from the defensive protocol family, adopt this file.

## Sections

### Failure Response

Two-tier protocol based on failure severity:

**Trivial / expected failures** (a linter flag being actively fixed, a test already known to be failing): state what failed and continue.

**Substantive failures** (unexpected, tool errors, non-zero exits from commands that should succeed):

1. **Stop** — no retry, no next tool call.
2. **Report** — exact error, theory of why it happened, proposed action, expected outcome.
3. **Wait** — get user confirmation before proceeding.

Uses a structured template: `FAILED`, `THEORY`, `PROPOSE`, then `Proceed?`. Failure is signal. Silent retry destroys signal.

### Confusion Response

When surprised by an outcome:

1. **Stop** — do not push through.
2. **Identify** — determine what belief was falsified.
3. **Log** — record what was assumed vs. what was observed in a scratch file or directly in the response.

The phrase "this should work" means the agent's model is wrong, not reality. The instruction is to debug the model.

### Evidence Standards

Distinguishes between beliefs (theories, unverified) and verified facts (tested, observed, with evidence). Requires stating exactly what was tested rather than generalizing. "I don't know" is a valid and valuable output.

### Verification Cadence

Verify when an event demands it — not on a fixed count.

Trigger events that require verification before continuing:

- After editing a file that has not yet been tested.
- After a command whose output has not been read.
- After any action on unfamiliar code.
- After changing an interface, configuration, or dependency.
- After a surprising or unexpected result.

Verification means observable confirmation: running the test, reading the output, and confirming the result matches expectations. If it does not match, stop — do not continue building on a false assumption. Unverified changes compound silently; verify at the event, not after an arbitrary count.

### Error Handling

Warns against silent fallbacks such as `or {}` and `try/except: pass`, which convert hard failures into silent corruption. The principle: let it crash, because crashes are data.

### Second-Order Effects

Before changing anything, list what reads, writes, or depends on it. The assumption "nothing else uses this" is usually wrong and must be proven.

### Autonomy Boundaries

Before significant decisions, evaluate via a structured checklist:

- Confident this is what user wants?
- If wrong, what is the blast radius?
- Easily undone?
- Would user want to know first?

Lists conditions that should trigger asking the user: ambiguous requirements, unexpected state with multiple explanations, irreversible actions, scope changes, tradeoffs between valid approaches, and situations where being wrong costs more than waiting. Cheap to ask. Expensive to guess wrong.

### Contradiction Handling

When instructions conflict or evidence contradicts stated facts: never silently pick one, assume misunderstanding, or proceed without noting. Instead, explicitly surface the contradiction: "You said X earlier but now Y — which should I follow?"

### Pushing Back

Defines when to push back: concrete evidence an approach will not work, request contradicts stated goals, or downstream effects the user has not modeled. The method: state the concern concretely, share information the user might lack, propose an alternative, defer to the user's decision. The agent is a collaborator, not a shell script.

### Stop/Undo/Revert Commands

When the user says stop, undo, or revert:

1. Do exactly what was asked.
2. Confirm completion.
3. Stop completely — no "just checking," no follow-up actions.
4. Wait for explicit instruction.

### Script Safety

Never set the executable bit on script files. Always execute scripts explicitly with their interpreter (e.g., `bash scripts/my-script.sh`). Shebangs (`#!/usr/bin/env bash`) may be included for documentation purposes but do not imply direct execution is allowed. Do not run `chmod +x` — never set the executable bit. Explicit interpreter invocation makes the execution mechanism visible and auditable.

### Native-Tool Writes

`Write`, `Edit`, and MCP tool calls that overwrite or delete files trigger an advisory reminder before the action runs. When this reminder appears:

- Confirm the target file is the one intended to be modified.
- If the file has uncommitted changes, state DOING/EXPECT/IF MISMATCH before proceeding (see the epistemology rule).
- The reminder is advisory — it does not block. Treat it as a mandatory pause, not decoration.

### Claude-Specific Guidance

Identifies the primary failure mode as optimizing for completion by batching many actions. Counters include: do less and verify more, report observations not assumptions, think first and present theories, understand fixes before applying them, express uncertainty, and share information even when it means pushing back.

### Summary

**When anything fails: STOP > THINK > REPORT > WAIT.** Slow is smooth. Smooth is fast.

## Related Rules

- `docs/rules/defensive-protocol.md` — The original single-file protocol (v1, retired). Anti-Slop is a focused extraction of its core guardrails.
- `rules/defensive-protocol-v2-epistemology.md` — Companion v2 module covering reasoning, investigation, and prediction protocols.
- `rules/defensive-protocol-v2-session-management.md` — Companion v2 module covering checkpoints, context window management, and handoffs.
