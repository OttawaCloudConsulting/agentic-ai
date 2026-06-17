---
name: over-engineering-review
description: >-
  On-demand active pass that runs the 3-clause discriminator over the current
  diff, a named file, or a plan/design doc and reports classified findings
  (safe-remove / needs-decision / keep / harmful-theater). Thin wrapper that
  composes /simplify and /code-review, adding only the requirement-ledger freeze
  and discriminator. Use when asked to "/over-engineering-review", "check for
  over-engineering", "run the discriminator", "gate this for YAGNI/KISS", or
  "is this over-engineered". Accepts optional target: diff (default) | <file
  path> | plan.
disable-model-invocation: false
---

# /over-engineering-review — On-Demand Discriminator Pass

Runs the 3-clause discriminator over a target artifact and reports findings
classified `safe-remove`, `needs-decision`, `keep`, or `harmful-theater`.
Composes `/simplify` and `/code-review` — does not reimplement them.

## Rules

- **Discriminator is the test; context tunes severity, not detection.** The
  discriminator fires context-free. Severity and stop/ask posture adjust to
  context; whether the flag fires does not.
- **Compose, don't reimplement.** Run `/simplify` and `/code-review` as
  sub-passes. Add only the requirement-ledger freeze and the discriminator.
- **Freeze the ledger before review.** Extract stated requirements, observed
  failures, and named safety properties from conversation context, PRD, and
  any referenced docs before evaluating any element. Post-hoc requirement
  invention does not enter the ledger.
- **Cost-gate the counterfactual.** A full counterfactual on a trivial or
  reversible target is itself axis-8 over-engineering. Escalate only for
  qualifying targets (see Step 5).
- **Findings are flags, never scores.** Emit classified findings with cited
  clause-absence. No numeric ratings.
- **Correctness/safety floor is clause 3 of the discriminator.** Floor items
  pass clause 3 — they are classified `keep`, not flagged.

## Step 1 — Resolve Target

Parse the argument after `/over-engineering-review`:

- **No argument / `diff`**: `git diff HEAD` — the current working-tree diff.
- **File path**: read the named file.
- **`plan`** or natural language referencing a plan/design: read the referenced
  plan or design doc from conversation context.

If the target is empty (no diff, no file, nothing in context), stop and ask
the user what to review.

## Step 2 — Freeze the Requirement Ledger

Before evaluating any element, extract and freeze the requirement ledger.

Sources (priority order):

1. Explicit user statements in this conversation
2. `prd.md` (if present in the project root)
3. `docs/ARCHITECTURE_AND_DESIGN.md` (if present)
4. Any design doc referenced in the target

Tag each requirement by provenance: `[user-stated]` or `[agent-inferred]`.

**Agent-inferred requirements that justify nothing are not added to the
ledger.** If an agent-inferred entry is the sole justification for an element,
that element is a flag candidate.

Emit the frozen ledger before proceeding:

```
REQUIREMENT LEDGER (frozen)
  [user-stated]    <requirement>
  [agent-inferred] <inferred property>  ← escalated if unjustified
```

## Step 3 — Run /simplify and /code-review

Invoke as sub-passes in sequence:

1. `/simplify` — simplification and redundancy findings
2. `/code-review` — correctness, bug, and reuse findings

Retain their outputs to feed Step 4's per-element discriminator pass.
Do not re-emit them verbatim in the final report.

## Step 4 — Run the Discriminator Per Element

For each element in the target artifact (including any surfaced by Step 3):

> Does it trace to **(1)** a stated requirement, **(2)** an observed failure,
> or **(3)** a correctness/security defect on a reachable path at a trust
> boundary? **If none → flag.**

Apply modifiers after the flag, not before:

- **Context tunes severity, not detection.** Blast radius × lifespan (plus
  explicit security/data-sensitivity signal) tune enforcement posture and
  severity label. They do not suppress a flag.
- **Reversibility licenses a seam, not a feature.** A one-way door (persisted
  data, published contract, wire format, public name) licenses a cheap reversal
  seam — never the speculative feature itself. Blast-radius-escape count:
  0 triggers → defer (YAGNI); 1 → seam only; 2+ → surface to user.
- **Clause 3 IS the floor.** Delete-the-element test: does removing it produce
  a wrong result, lost/corrupted data, a security hole, or a
  silently-swallowed failure on a reachable path at a trust boundary?
  - Yes → `keep` (floor item)
  - Loses only convenience / future flexibility → flag

Boundary cases — one rule: trust boundary + reachability + named failure mode:

| Element | Floor (`keep`) | Excess (flag) |
|---------|----------------|---------------|
| Retries | transient/idempotent op, bounded, surfaced failure | unbounded / non-idempotent / masks failure |
| Logging | required output/audit; stderr insufficient to operate | decorative / duplicates available signal |
| Input validation | external/untrusted boundary, reachable path | internal trusted caller |
| Error handling | preserves invariant/cleanup; sharpens reachable failure | swallows/masks; wraps infallible code |

## Step 5 — Cost-Gate and Optionally Run Counterfactual

Escalate to a **partial** cold counterfactual (re-derive one layer/section
from the frozen ledger **by a different model**, original removed from context)
only when at least one qualifying condition is met:

- Target is design-stage, OR
- Diff is large (>200 lines), OR
- Target contains "production-ready" / "enterprise-grade" / similar phrase
  clusters, OR
- Multiple axes (≥3) are triggered, OR
- Safety-inversion risk is present

**And** cost is proportionate. A full counterfactual on a trivial or reversible
target is itself axis-8 over-engineering — do not run it.

Counterfactual scope: **partial** (one layer/section). Full rewrite is reserved
for axis-2 structural over-engineering where the shape is the excess.

Announce the decision either way:

```
COUNTERFACTUAL: escalating — <reason>. Re-deriving <layer/section> via
<different model> with original removed from context.
```

```
COUNTERFACTUAL: skipped — <reason> (trivial/reversible/small). Cost-gate.
```

## Step 6 — Classify and Emit Findings

Classify each finding:

| Tag | Meaning |
|-----|---------|
| `safe-remove` | Fails discriminator; no clause passes; removing it is unambiguously correct. |
| `needs-decision` | Fails discriminator; contested (reversibility, blast-radius, conflicting signal); surface to user. |
| `keep` | Passes clause 3 (floor item) or a stated requirement / observed failure. |
| `harmful-theater` | Fails discriminator AND its presence actively harms (swallows failures, false safety signal, masks real errors). Remove before proceeding. |

Emit format — one line per finding:

```
path:line  [tag]  axis-N: <unjustified element>. <simpler alternative or "remove".>
```

For `keep` items, cite the clause:

```
path:line  [keep]  clause-3/floor: <element>. Required: <named failure mode>.
```

End with a summary block:

```
OVER-ENGINEERING REVIEW SUMMARY
  harmful-theater : N  (remove before proceeding)
  safe-remove     : N
  needs-decision  : N  (surfaced below for user)
  keep            : N

NEEDS-DECISION ITEMS:
  [each item with context and recommendation]
```

## The 8-Axis Reference

| # | Axis | Principle |
|---|------|-----------|
| 1 | Speculative scope | YAGNI |
| 2 | Premature abstraction | KISS |
| 3 | Premature optimization | KISS |
| 4 | Defensive bloat | clause-3 predicate, flag side |
| 5 | Robustness / ops theater | YAGNI |
| 6 | Test / doc ceremony | DRY / YAGNI |
| 7 | Data / schema / API over-modeling | YAGNI |
| 8 | Process over-engineering (meta) | do not over-apply this gate itself |

## Anti-Bias Directive

Failure mode: confirming quality rather than finding unjustified complexity.

Counter it:

- Default posture: **flag aggressively**. Ask "does a concrete justification
  exist for this element?" — not "is this good practice?"
- Good practice without a concrete justification is still a flag.
- Do not emit `keep` findings for items not positively verified against the
  frozen ledger.
- Apply axis 8 to yourself: one discriminator pass per element; not a parallel
  subsystem per concern.
