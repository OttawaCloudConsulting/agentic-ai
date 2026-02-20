# Investigate

**Source:** `commands/investigate.md`
**Command:** `/investigate`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "investigate this," "find root cause," "debug this failure")

## Description

Creates and maintains a structured investigation file when debugging an unknown issue. Separates verified facts from unverified theories, tracks multiple competing hypotheses, records every test performed, and documents the resolution. Designed to survive context window limits — the investigation file persists across `/compact` or `/clear`.

## Usage

```
/investigate
/investigate [description of the issue]
```

Can be invoked with or without a description. If no description is provided, the command asks for the symptom, location, and timing of the issue.

## Inputs

| Input | Source | Required |
|---|---|---|
| Symptom description | User input (direct or via `AskUserQuestion`) | Yes |
| Location of the issue | User input (which file, stack, service, command) | Yes |
| Timing of the issue | User input (after which change, deploy, or action) | Recommended |
| Source code, logs, error messages | File system and command output | Yes (gathered during investigation) |

## Outputs

| Output | Location | Description |
|---|---|---|
| Investigation file | `agents/investigations/[slug].md` | Structured document with facts, theories, tests performed, and resolution |
| Resolution report | Console (stdout) | Summary of root cause, fix applied, and prevention strategy |

## Workflow

### Step 1 — Define the investigation

Asks or infers three things:

- **What is the symptom?** — exact error message, unexpected behavior, or deployment failure
- **Where was it observed?** — which file, stack, service, or command
- **When did it start?** — after which change, deploy, or action

Creates a slug from the topic (e.g., `circular-dependency`, `aurora-connection-timeout`, `lambda-permission-error`).

### Step 2 — Create investigation file

Writes `agents/investigations/[slug].md` with this structure:

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

Works through the theories systematically:

1. **Read the evidence** — examines error messages, logs, source code, CloudFormation templates, and any other relevant artifacts.
2. **Test one theory at a time** — does not shotgun multiple changes simultaneously.
3. **Record every test** in the Tests Performed table — even negative results are valuable data.
4. **Update Facts and Theories** as learning progresses — promotes confirmed theories to facts, eliminates disproven ones.
5. **Maintain 3+ hypotheses** — if down to one unconfirmed theory, generates more alternatives.

### Step 4 — Resolve

When the root cause is found:

1. Fills in the Resolution section with root cause, fix applied, and prevention strategy.
2. Changes Status from `Active` to `Resolved`.
3. Reports to the user:

```
INVESTIGATION RESOLVED: [title]

Root cause: [one sentence]
Fix: [what was changed]
Prevention: [how to avoid in future]

Full investigation: agents/investigations/[slug].md
```

If the investigation represents a permanent learning (likely to recur, non-obvious), suggests adding it to CLAUDE.md via the `/memory` command.

## When to Use

- When encountering an unexplained error or failure during development
- When asked to find the root cause of an issue
- When debugging a deployment failure or runtime error
- When an issue has multiple possible explanations and systematic elimination is needed

## When Not to Use

- For straightforward errors with obvious causes that do not need structured tracking
- For feature implementation work — use `/start-feature` instead
- For code review or documentation updates

## Related Commands and Skills

- `/catchup` — Reports active investigations found in `agents/investigations/` when resuming a session.
- `/handoff` — References active investigations in the Active Investigations section of the handoff document.
