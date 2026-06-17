# Over-Engineering Gate (dp2 Extension)

> **Description document.** This summarizes the installable rule at `rules/defensive-protocol-v2-over-engineering.md`. Copy that file to `.claude/rules/` in the target repo — do not copy this file.

**Source:** `rules/defensive-protocol-v2-over-engineering.md`
**Scope:** All project types — language-agnostic guardrail against the agent over-engineering its own deliverables
**Activation:** Automatic — loaded when placed in `.claude/rules/`. Paired with a `UserPromptSubmit` hook that injects a one-line pre-build reminder on build/implement intent.

## Core Principle

**For each element you are about to produce, does it trace to (1) a stated requirement, (2) an observed failure, or (3) a correctness/security defect on a reachable path at a trust boundary? If none → flag.** Default: do not produce it.

## Overview

This rule specializes the Defensive Protocol v2 autonomy/blast-radius posture for one failure mode: the agent inflating its own output into "production-ready" complexity that no requirement asked for. It does not duplicate the base posture — read `defensive-protocol-v2-anti-slop.md` first. Detection collapses to a single 3-clause discriminator applied **before** writing, not after. A flag means stop and surface the element to the user — do not silently drop it, do not produce it anyway.

The rule is self-applied text. The companion `UserPromptSubmit` hook (`over-engineering-reminder.sh`) is the enforcement layer: it fires on intent keywords (`implement`, `build`, `develop`, `add a`, `write a`) and injects the discriminator reminder before the agent picks its first tool. The hook can only remind — detection lives in the agent reading this rule, in the reviewer agent profile, and in the `/over-engineering-review` skill.

## Sections

### Core Test (the discriminator)

The 3-clause discriminator is the whole detection mechanism. Applied per planned element, before writing. None of the three clauses pass → flag, default do-not-produce. The clauses are: traces to a stated requirement, traces to an observed failure, or fixes a correctness/security defect on a reachable path at a trust boundary.

### Modifiers (tune the response, not the detection)

Four modifiers govern enforcement posture after the flag fires — never whether it fires:

- **Context tunes severity, not detection.** The discriminator fires context-free. Blast radius × lifespan and security/data-sensitivity signal tune the stop/ask posture. Default when context is absent: minimal / prototype-grade, flag aggressively — never below the clause-3 floor.
- **Reversibility licenses a seam, not a feature.** A one-way door (persisted data, published contract, wire format, public name) licenses a cheap reversal seam, never a speculative feature. Burden of proof: name all four — irreversible surface, plausible future change, concrete later cost, smallest present action. Default-deny on unproven one-way claims.
- **Counterfactual is escalation-only.** The cheap static discriminator is detection-primary. The counterfactual (re-derive a layer from the frozen ledger by a different model, original removed from context) is reserved for design-stage artifacts, large deltas, "production-ready" phrase clusters, many-axes-triggered, or safety-inversion risk. A full counterfactual on a trivial target is itself axis-8 over-engineering.
- **Cause-agnostic.** The gate acts on output signature, not on why the element was produced. RLHF length bias, deferred decisions, incomplete requirements — none change whether an element passes.

### The Correctness/Safety Floor

Clause 3 **is** the floor — there is no parallel exempt list. Floor items (`set -euo pipefail`, parameterized queries, applying a saved plan before executing it) are not exempt; they *pass* clause 3. The **delete-the-element test**: removing it produces a wrong result, lost/corrupted data, a security hole, or a silently-swallowed failure on a reachable path at a trust boundary → keep (floor). Loses only convenience / future flexibility / hypothetical robustness → flag. Boundary cases resolve on one rule: trust boundary + reachability + named failure mode (retries, logging, input validation, error handling each get a floor-vs-excess row).

### 8-Axis Reference

The discriminator is the test; the axes name the *kind* of unjustified complexity: (1) speculative scope/YAGNI, (2) premature abstraction/KISS, (3) premature optimization/KISS, (4) defensive bloat, (5) robustness/ops theater, (6) test/doc ceremony, (7) data/schema/API over-modeling (houses the reversibility loophole), (8) process over-engineering — over-applying the gate itself.

### Self-Application Guardrail (Axis 8)

Apply the gate to what you produce, not to everything. If running the discriminator on an element would cost more than the complexity it might catch, skip it. One discriminator pass per element — not a parallel subsystem per concern. The gate serves the build, it does not consume the budget given to it.

### Bias Reminder

The failure mode is inflation: ambiguous asks become "production-ready" output because RLHF rewards thoroughness. The discriminator does not ask "is this good practice?" — it asks "does a concrete justification exist for this specific element?" Good practice without a concrete justification is still a flag.

### Pre-Build Procedure

When the hook fires: (1) freeze the requirement ledger — stated requirements, observed failures, named safety properties, each tagged user-stated vs. agent-inferred; agent-inferred requirements that justify nothing escalate upstream rather than entering the ledger. (2) Run the discriminator per planned element. (3) Surface flagged elements before building — do not silently drop or silently include; stop and ask when high blast-radius / sensitive-data / public-exposure / one-way-migration applies.

## Installation

The rule and its hook install together via the Defensive Protocol v2 installer:

```bash
bash scripts/defensive-protocol/install.sh <target-repo-path>
```

This copies the rule to `.claude/rules/`, copies `over-engineering-reminder.sh`, merges the `UserPromptSubmit` hook entry into `.claude/settings.json` (idempotent, keyed off a versioned marker), and appends an Active-Rules block to the target `CLAUDE.md`. See [SCRIPTS.md](../SCRIPTS.md#defensive-protocol-v2) and [scripts/defensive-protocol/README.md](../../scripts/defensive-protocol/README.md).

## Related Rules

- `rules/defensive-protocol-v2-anti-slop.md` — Base posture this rule extends. Read it first; the over-engineering gate specializes its autonomy/blast-radius model and does not duplicate it.
- `rules/defensive-protocol-v2-epistemology.md` — Companion v2 module; the requirement-ledger freeze parallels its investigation/prediction protocols.

## Related Artifacts

The discriminator ships as three discrete, zero-dependency artifacts that share a *concept*, not a dependency. This rule is the always-on reminder tier:

- **Agent profile** — [`docs/agent-profiles/over-engineering-reviewer.md`](../agent-profiles/over-engineering-reviewer.md): isolated diff-model detect.
- **Skill** — [`docs/skills/over-engineering-review.md`](../skills/over-engineering-review.md): on-demand active pass that composes `/simplify` and `/code-review`.
- **Design spec** — [`docs/ARCHITECTURE_AND_DESIGN.md`](../ARCHITECTURE_AND_DESIGN.md): the authoritative design reference for all three.
