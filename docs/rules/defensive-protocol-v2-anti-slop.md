# Anti-Slop Discipline

**Source:** `rules/defensive-protocol-v2-anti-slop.md`
**Scope:** All project types — language-agnostic behavioral guardrails for agentic coding sessions
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

**Reality is the arbiter. When observations contradict your model, your model is wrong.** Stop, update your mental model, only then proceed.

## Overview

Anti-Slop Discipline is the minimum viable safety net for agentic coding sessions. It prevents compounding errors, wasted effort, and spurious output. This is a focused extraction from the full Defensive Coding Protocol, containing only the core guardrails. If you adopt nothing else from the defensive protocol family, adopt this file.

## Sections

### Failure Response

A strict three-step protocol when anything fails:

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

Uses a tiered approach:

- **Unfamiliar or risky work:** 3 actions, then verify.
- **Established patterns or routine work:** 5 actions, then verify.

Verification means observable confirmation: running the test, reading the output, and confirming the result matches expectations. If it does not match, stop — do not continue building on a false assumption. More than 5 actions without verification equals accumulated unjustified beliefs.

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

Never set the executable bit on script files. Always execute scripts explicitly with their interpreter (e.g., `bash scripts/my-script.sh`). Do not add shebangs — they imply direct execution. Do not run `chmod +x`. Explicit interpreter invocation makes the execution mechanism visible and auditable.

### Claude-Specific Guidance

Identifies the primary failure mode as optimizing for completion by batching many actions. Counters include: do less and verify more, report observations not assumptions, think first and present theories, understand fixes before applying them, express uncertainty, and share information even when it means pushing back.

### Summary

**When anything fails: STOP > THINK > REPORT > WAIT.** Slow is smooth. Smooth is fast.

## Related Rules

- `rules/defensive-protocol.md` — The original full-featured defensive protocol. Anti-Slop is a focused extraction of its core guardrails.
- `rules/defensive-protocol-v2-epistemology.md` — Companion v2 module covering reasoning, investigation, and prediction protocols.
- `rules/defensive-protocol-v2-session-management.md` — Companion v2 module covering checkpoints, context window management, and handoffs.
