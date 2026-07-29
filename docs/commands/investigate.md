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
| Investigation file | `agents/investigations/[slug]/[slug].md` | Structured document with facts, theories, tests performed, and resolution |
| Resolution report | Console (stdout) | Summary of root cause, fix applied, and prevention strategy |

## Workflow

### Step 1 — Define the investigation

Asks or infers three things:

- **What is the symptom?** — exact error message, unexpected behavior, or deployment failure
- **Where was it observed?** — which file, stack, service, or command
- **When did it start?** — after which change, deploy, or action

Creates a slug from the topic (e.g., `circular-dependency`, `aurora-connection-timeout`, `lambda-permission-error`).

### Step 2 — Create investigation file

Writes `agents/investigations/[slug]/[slug].md` with this structure:

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
6. **Codex review of the hypotheses** — once 3+ competing hypotheses are recorded and before running the tests, hands the investigation file (plus the implicated source files) to Codex for an independent read. Codex is asked for non-distinct hypotheses, hypotheses contradicted by the recorded Facts, missing hypotheses the evidence supports, and tests that cannot discriminate between theories. Valid findings are folded back into Facts/Theories before testing; rejected findings get a one-line reason. Skipped entirely when codex is unavailable.

### Step 4 — Resolve

When the root cause is found:

1. Fills in the Resolution section with root cause, fix applied, and prevention strategy.
2. **Codex review of the resolution** — hands the completed investigation file to Codex to verify the root cause is supported by the recorded Facts and Tests (not asserted), the fix addresses the root cause rather than the symptom, no competing hypothesis was left un-eliminated, and Prevention is concrete. Valid findings are addressed before closing; an unsupported root cause keeps the investigation `Active` and returns to Step 3. Skipped entirely when codex is unavailable.
3. Changes Status from `Active` to `Resolved`.
4. Reports to the user:

```
INVESTIGATION RESOLVED: [title]

Root cause: [one sentence]
Fix: [what was changed]
Prevention: [how to avoid in future]
Codex review: [X valid / Y rejected — or "skipped (codex unavailable)"]

Full investigation: agents/investigations/[slug]/[slug].md
```

If the investigation represents a permanent learning (likely to recur, non-obvious), suggests adding it to CLAUDE.md via the `/memory` command.

### Codex Review

Both review points share one mechanism, documented in the command under `## Codex Review`:

- **Availability guard** — `command -v codex`. If codex or `.claude/scripts/codex-review.sh` is missing, the review is skipped and the investigation continues; the skip is recorded in the file and the report. Review tooling is never a gate.
- **Invocation** — `bash .claude/scripts/codex-review.sh <investigation file> [source files...] -p "<review questions>"`. The hardened wrapper is used instead of a hand-rolled `codex exec` (closed stdin, timeout, `-s read-only` sandbox). Exit `0` = PASS, `1` = FAIL, `2` = review failed (treated as "no verdict", never as PASS).
- **Alternative** — the `codex:codex-rescue` agent when the `codex` plugin is installed.
- **Triage** — every finding is classified VALID (reproducible against the recorded Facts/Tests or the real source) or REJECTED (one-line reason). Codex output is never auto-applied to the investigation file.

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
