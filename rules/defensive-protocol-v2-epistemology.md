# Epistemology for Agentic Coding

> Reasoning framework for making good decisions under uncertainty. Covers how to predict outcomes, investigate unknowns, and avoid premature action.

## Prediction Protocol (Tiered)

Make your reasoning visible before acting. The level of detail scales with risk.

### Routine Actions

State your intent in one line before acting:

```
INTENT: Reading config to check whether feature X is enabled
```

```
INTENT: Adding import for the module we just installed
```

No further ceremony needed. Proceed and verify the result.

### High-Risk Actions

For actions that are destructive, irreversible, or ambiguous, make your full reasoning visible:

```
DOING: [action]
EXPECT: [specific predicted outcome]
IF MATCH: [next step]
IF MISMATCH: [stop and report to user]
```

After the action:

```
RESULT: [actual outcome]
MATCH: [yes/no]
THEREFORE: [conclusion or STOP]
```

**What qualifies as high-risk:**

- Deleting files, branches, or data
- Modifying database schemas or migration files
- Changing public APIs or shared interfaces
- Git history modifications (rebase, amend, force push)
- Actions affecting production or shared environments
- Any action where the user said "be careful" or "double check"
- Actions where you're uncertain about the outcome
- Overwriting files with uncommitted changes

When in doubt, use the full format. The cost of over-predicting is low; the cost of a silent wrong assumption is high.

---

## Investigation Protocol

When debugging unknowns:

1. Create a scratch investigation file to track findings
2. Separate **FACTS** (verified, observed) from **THEORIES** (plausible, untested)
3. Maintain **3+ competing hypotheses** — never chase just one
4. Record: what was tested, why, what was found, what it means

When resolved, summarize the outcome and which hypothesis was correct (or if the answer was none of them).

**Never commit to a theory without ruling out alternatives.** The first explanation that fits is often wrong.

---

## Root Cause Analysis

Symptoms surface. Causes live deeper.

- **Immediate cause:** what failed
- **Systemic cause:** why failure was possible
- **Root cause:** why the system was designed this way

Fix only the immediate cause = temporary fix. Identify and report the deeper causes even if fixing them is out of scope.

---

## Chesterton's Fence

Before removing or changing anything, articulate why it exists.

- "Looks unused" — Prove it. Trace references. Check git history.
- "Seems redundant" — What problem was it solving?
- "Don't know why it's here" — Find out before touching.

Missing context is more likely than pointless code.

---

## Abstraction Timing

Need 3 real examples before abstracting.

Second time writing similar code, write it again. Third time, *consider* abstracting.

Concrete first. Frameworks later.

---

## Codebase Navigation

Order of operations when entering unfamiliar code:

1. CLAUDE.md / project instructions
2. README.md
3. Code (only if needed)

Documentation is O(1). Random code is O(n).
