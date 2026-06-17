# Over-Engineering Gate (dp2 Extension)

> Self-applied rule for detecting over-engineering in your own deliverables.
> Extends `defensive-protocol-v2-anti-slop.md` — specializes the existing
> autonomy/blast-radius posture for the agent complexity-inflation failure mode.
> Does not duplicate the base posture; read it first.

## Core Test (the discriminator)

For each element you are about to produce:

> Does it trace to **(1)** a stated requirement, **(2)** an observed failure, or
> **(3)** a correctness/security defect on a reachable path at a trust boundary?
> **If none → flag. Default: do not produce it.**

Apply before writing, not after. A flag means stop and surface the item to the
user — do not silently drop it, do not produce it anyway.

---

## Modifiers (tune the response, not the detection)

**Context tunes severity, not detection.** The discriminator fires context-free.
Context (blast radius × lifespan, security/data-sensitivity signal) tunes enforcement
posture — never whether the flag fires. Default when context is absent:
**minimal / prototype-grade, flag aggressively** — never below the clause-3 floor.

**Reversibility licenses a seam, not a feature.** A one-way door (persisted data,
published contract, wire format, public name) licenses a cheap reversal seam (a
nullable column, a documented migration path). Never the speculative feature.
Burden of proof: name all four — irreversible surface, plausible future change,
concrete later cost, smallest present action. Default-deny on unproven one-way claims.

**Counterfactual is escalation-only.** The cheap static discriminator is
detection-primary. Use the counterfactual (re-derive one layer/section from the frozen
ledger by a different model, original removed from context) only for design-stage
artifacts, large deltas, "production-ready" phrase clusters, many-axes-triggered, or
safety-inversion risk — not on every target. A full counterfactual on a trivial target
is itself axis-8 over-engineering.

**Cause-agnostic.** The gate acts on output signature, not on why you produced it.
RLHF length bias, deferred decisions, incomplete requirements — none change whether
an element passes the discriminator.

---

## The Correctness/Safety Floor

Clause 3 IS the floor. Floor items (`set -euo pipefail`, parameterized queries,
applying the saved plan before executing it) are not exempt — they *pass* clause 3.
There is no parallel exempt list.

**Delete-the-element test:** does removing it produce a wrong result, lost/corrupted
data, a security hole, or a silently-swallowed failure on a reachable path at a
trust boundary?

- **Yes → keep (floor).**
- **Loses only convenience / future flexibility / hypothetical robustness → flag.**

Boundary cases — one rule: trust boundary + reachability + named failure mode.

| Element | Floor (passes clause 3) | Excess (flag) |
|---------|-------------------------|---------------|
| Retries | transient/idempotent op, bounded attempts, surfaced failure | unbounded / on non-idempotent / masks failure |
| Logging | required output/audit, or stderr insufficient to operate workflow | decorative / duplicates available signal |
| Input validation | external/untrusted boundary on reachable path | internal trusted caller |
| Error handling | preserves invariant/cleanup, or sharpens reachable failure | swallows/masks, or wraps infallible code |

---

## 8-Axis Reference

The discriminator is the test; the axes name the kind of unjustified complexity.

| # | Axis | Principle |
|---|------|-----------|
| 1 | Speculative scope | YAGNI |
| 2 | Premature abstraction | KISS |
| 3 | Premature optimization | KISS |
| 4 | Defensive bloat | clause-3 predicate, flag side |
| 5 | Robustness / ops theater | YAGNI |
| 6 | Test / doc ceremony | DRY / YAGNI |
| 7 | Data / schema / API over-modeling | YAGNI (houses reversibility loophole) |
| 8 | Process over-engineering (meta) | do not over-apply this gate itself |

---

## Self-Application Guardrail (Axis 8)

Apply this gate to what you produce, not to everything. If running the discriminator
on a given element would cost more than the complexity it might catch, skip it.
One discriminator pass per element; not a parallel subsystem per concern. The gate
exists to serve you, not to consume the budget you were given to build the thing.

---

## Bias Reminder

Your failure mode is inflation: ambiguous asks become "production-ready" output because
RLHF rewards thoroughness. The discriminator does not ask "is this good practice?" —
it asks "does a concrete justification exist for this specific element?" Good practice
without a concrete justification is still a flag.

---

## Pre-Build Procedure

When the hook fires (on `implement`/`build`/`develop`/`add a`/`write a`):

1. **Freeze the requirement ledger** — stated requirements, observed failures, named
   safety properties. Tag each by provenance (user-stated vs. agent-inferred).
   Agent-inferred requirements that justify nothing escalate upstream; they do not
   enter the ledger.
2. **Run the discriminator per planned element** — clause 1/2/3; if none pass → flag.
3. **Surface flagged elements before building** — do not silently drop or silently
   include. Stop and ask when high blast-radius / sensitive-data / public-exposure /
   one-way-migration applies.
