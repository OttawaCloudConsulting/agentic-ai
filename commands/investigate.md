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

Write `agents/investigations/[slug]/[slug].md`:

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
6. **Codex review of the hypotheses** — once the Theories section holds 3+ competing hypotheses with
   evidence and tests, and *before* you spend cycles running those tests, get an independent read on the
   hypothesis set (see [Codex Review](#codex-review) below). Ask Codex for:
   - hypotheses that are not actually distinct (same cause, different wording)
   - hypotheses contradicted by the recorded Facts
   - a missing hypothesis the recorded evidence supports
   - tests that cannot discriminate between the listed theories

   Fold valid findings back into Facts/Theories before testing. Record rejected findings with a
   one-line reason. **Skip this substep entirely if codex is not available.**

### Step 4 — Resolve

When the root cause is found:

1. Fill in the Resolution section
2. **Codex review of the resolution** — before closing, hand the completed investigation file to Codex
   (see [Codex Review](#codex-review) below). Ask it to verify:
   - the root cause is supported by the recorded Facts and Tests Performed, not asserted
   - the fix addresses the root cause, not just the symptom
   - no competing hypothesis was left un-eliminated
   - Prevention is concrete and actionable, not a platitude

   Address valid findings before closing. A root cause Codex shows is unsupported means the
   investigation stays `Active` — go back to Step 3. **Skip this substep entirely if codex is not
   available.**
3. Change Status from `Active` to `Resolved`
4. Report to the user:

```
INVESTIGATION RESOLVED: [title]

Root cause: [one sentence]
Fix: [what was changed]
Prevention: [how to avoid in future]
Codex review: [X valid / Y rejected — or "skipped (codex unavailable)"]

Full investigation: agents/investigations/[slug]/[slug].md
```

If the investigation is a **permanent learning** (likely to recur, non-obvious), suggest adding it to CLAUDE.md via the `/memory` command.

## Codex Review

Both review points (Step 3 hypotheses, Step 4 resolution) use the same mechanism. Codex is an
independent engine — a second pass on reasoning the investigating context is blind to, which is
exactly the confirmation bias the 3+ hypothesis rule exists to counter.

**Availability guard — check first.** The review is optional tooling, not a gate:

```bash
command -v codex >/dev/null 2>&1
```

If codex is absent, or `.claude/scripts/codex-review.sh` is missing, **skip the review and
continue**. Record `CODEX REVIEW: skipped (codex unavailable)` in the investigation file and say so
in the report. Never block an investigation on review-tooling absence, and never infer a clean
review from one that did not run.

**Run it** with the hardened wrapper in file mode — do NOT hand-roll `codex exec` (an open stdin
hangs the process, and a review must never run in a writable sandbox):

```bash
bash .claude/scripts/codex-review.sh \
  agents/investigations/[slug]/[slug].md [implicated source files...] \
  -p "This is a debugging investigation, not a code diff. Review the <Theories|Resolution> section against the recorded Facts and Tests Performed and the real source. <the bullet questions from the step>"
```

Pass the implicated source files alongside the investigation file so Codex can check claims against
the code rather than trusting the write-up.

Exit codes: `0` = PASS, `1` = FAIL (findings reported), **`2` = review failed (timeout / codex
error) — treat as "no verdict", never infer PASS**. On exit 2, treat it as unavailable: record the
reason and continue.

Alternative: the `codex:codex-rescue` agent (harness-native, same engine) when the `codex` plugin is
installed.

**Triage every finding** — do not auto-apply Codex output into the investigation file:

- **VALID** — reproducible against the recorded Facts/Tests or the real source
- **REJECTED** — false positive, out of scope, or unsupported; record a one-line reason

Record the triage outcome in the investigation file under the section that was reviewed.

## During Long Investigations

- Update the investigation file as you go — don't accumulate findings only in conversation context
- If context is getting high, the investigation file preserves your work across `/compact` or `/clear`
- Reference the file path when reporting: "See agents/investigations/[slug]/[slug].md for full details"

## Important Rules

- **Facts require evidence** — "I think" is a theory, not a fact
- **3+ hypotheses minimum** — single-theory investigations suffer from confirmation bias
- **Record negative results** — ruling something out is progress
- **Don't guess root causes** — if unsure, say so and propose the next test
- **One change at a time** — when testing theories, change one variable per test
- **Cite sources** — reference file paths, line numbers, error messages, command output
