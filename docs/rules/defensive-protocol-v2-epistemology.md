# Epistemology for Agentic Coding

**Source:** `rules/defensive-protocol-v2-epistemology.md`
**Scope:** All project types — language-agnostic reasoning framework for agentic coding sessions
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

Make your reasoning visible before acting. The level of detail scales with risk.

## Overview

This rule provides a reasoning framework for making good decisions under uncertainty. It covers how to predict outcomes, investigate unknowns, and avoid premature action. This is one of three v2 modules extracted from the original Defensive Coding Protocol, focused specifically on epistemology — the "how to think" component.

## Sections

### Prediction Protocol (Tiered)

Introduces a two-tier system that scales ceremony with risk level.

**Routine Actions:** State intent in one line before acting. Examples: "INTENT: Reading config to check whether feature X is enabled" or "INTENT: Adding import for the module we just installed." No further ceremony needed — proceed and verify the result.

**High-Risk Actions:** For actions that are destructive, irreversible, or ambiguous, the full prediction template applies:

- **Before acting:** State the action (`DOING`), the expected outcome (`EXPECT`), the next step if correct (`IF MATCH`), and the response if wrong (`IF MISMATCH`).
- **After acting:** Record the actual result (`RESULT`), whether it matched (`MATCH`), and the conclusion (`THEREFORE`).

Actions that qualify as high-risk include:

- Deleting files, branches, or data.
- Modifying database schemas or migration files.
- Changing public APIs or shared interfaces.
- Git history modifications (rebase, amend, force push).
- Actions affecting production or shared environments.
- Any action where the user said "be careful" or "double check."
- Actions where the outcome is uncertain.
- Overwriting files with uncommitted changes.

When in doubt, use the full format. The cost of over-predicting is low; the cost of a silent wrong assumption is high.

### Investigation Protocol

Structured approach to debugging unknowns:

1. Create a scratch investigation file to track findings.
2. Separate FACTS (verified, observed) from THEORIES (plausible, untested).
3. Maintain 3+ competing hypotheses — never chase just one.
4. Record what was tested, why, what was found, and what it means.

When resolved, summarize the outcome and which hypothesis was correct (or if the answer was none of them). The key rule: never commit to a theory without ruling out alternatives. The first explanation that fits is often wrong.

### Root Cause Analysis

Requires thinking at three levels:

- **Immediate cause:** what failed.
- **Systemic cause:** why failure was possible.
- **Root cause:** why the system was designed this way.

Fixing only the immediate cause produces a temporary fix. The protocol instructs the agent to identify and report deeper causes even if fixing them is out of scope.

### Chesterton's Fence

Before removing or changing anything, articulate why it exists:

- "Looks unused" — prove it by tracing references and checking git history.
- "Seems redundant" — determine what problem it was solving.
- "Don't know why it's here" — find out before touching.

Missing context is more likely than pointless code.

### Abstraction Timing

Requires 3 real examples before abstracting. Second time writing similar code, write it again. Third time, consider abstracting. Concrete first, frameworks later.

### Codebase Navigation

Defines an order of operations when entering unfamiliar code:

1. CLAUDE.md / project instructions.
2. README.md.
3. Code (only if needed).

Documentation is O(1). Random code is O(n).

## Related Rules

- `rules/defensive-protocol-v2-anti-slop.md` — Companion v2 module providing the core guardrails (failure response, autonomy boundaries, pushing back).
- `rules/defensive-protocol-v2-session-management.md` — Companion v2 module covering checkpoints, context window management, and handoffs.
- `rules/defensive-protocol.md` — The original full-featured defensive protocol from which this module was extracted.
