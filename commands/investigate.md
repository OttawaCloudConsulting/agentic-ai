---
name: investigate
description: Create a structured investigation for debugging unknowns. Use when asked to investigate an issue, find a root cause, debug a failure, or when saying "investigate this" or "find root cause."
---

# /investigate — Structured Debugging Investigation

Create and maintain a structured investigation file when debugging an unknown issue. Separates facts from theories, tracks multiple hypotheses, and records findings.

## Execution Steps

### Step 1 — Define the investigation

Ask or infer:
- **What is the symptom?** (error message, unexpected behavior, deployment failure)
- **Where was it observed?** (which file, stack, service, command)
- **When did it start?** (after which change, deploy, or action)

Create a slug from the topic (e.g., `circular-dependency`, `aurora-connection-timeout`, `lambda-permission-error`).

### Step 2 — Create investigation file

Write `agents/investigations/[slug].md`:

```markdown
# Investigation: [Title]

**Created:** YYYY-MM-DD
**Status:** Active
**Symptom:** [What's going wrong — exact error message or behavior]

## Facts
[Verified observations only. Each must cite evidence.]

- FACT: [observation] — verified by [how you confirmed it]

## Theories
[Plausible explanations. Maintain 3+ competing hypotheses when possible.]

1. **[Theory name]:** [explanation]
   - Evidence for: [what supports this]
   - Evidence against: [what contradicts this]
   - Test: [how to confirm or rule out]

2. **[Theory name]:** [explanation]
   - Evidence for:
   - Evidence against:
   - Test:

3. **[Theory name]:** [explanation]
   - Evidence for:
   - Evidence against:
   - Test:

## Tests Performed
[What was tried and what was observed.]

| # | Action | Expected | Actual | Conclusion |
|---|--------|----------|--------|------------|
| 1 | [what you did] | [what you expected] | [what happened] | [what this means] |

## Resolution
[Empty until resolved]

- **Root cause:**
- **Fix applied:**
- **Prevention:** [how to avoid this in future]
```

### Step 3 — Investigate

Work through the theories systematically:

1. **Read the evidence** — examine error messages, logs, source code, CloudFormation templates
2. **Test one theory at a time** — don't shotgun multiple changes
3. **Record every test** in the Tests Performed table — even negative results are data
4. **Update Facts and Theories** as you learn — promote confirmed theories to facts, eliminate disproven ones
5. **Maintain 3+ hypotheses** — if you're down to one theory and it hasn't been confirmed, generate more

### Step 4 — Resolve

When the root cause is found:

1. Fill in the Resolution section
2. Change Status from `Active` to `Resolved`
3. Report to the user:

```
INVESTIGATION RESOLVED: [title]

Root cause: [one sentence]
Fix: [what was changed]
Prevention: [how to avoid in future]

Full investigation: agents/investigations/[slug].md
```

If the investigation is a **permanent learning** (likely to recur, non-obvious), suggest adding it to CLAUDE.md via the `/memory` command.

## During Long Investigations

- Update the investigation file as you go — don't accumulate findings only in conversation context
- If context is getting high, the investigation file preserves your work across `/compact` or `/clear`
- Reference the file path when reporting: "See agents/investigations/[slug].md for full details"

## Important Rules

- **Facts require evidence** — "I think" is a theory, not a fact
- **3+ hypotheses minimum** — single-theory investigations suffer from confirmation bias
- **Record negative results** — ruling something out is progress
- **Don't guess root causes** — if unsure, say so and propose the next test
- **One change at a time** — when testing theories, change one variable per test
- **Cite sources** — reference file paths, line numbers, error messages, command output
