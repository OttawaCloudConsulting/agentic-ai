# PRD: Over-Engineering Gate

## Summary

A gate that catches an AI coding agent over-engineering its **own deliverables** —
design and code it produces in response to a request — measured against KISS, DRY,
and YAGNI. Detection collapses to one **3-clause discriminator**: an element is
flagged unless it traces to a stated requirement, an observed failure, or a
correctness/security defect on a reachable path at a trust boundary. Shipped as
**three discrete, zero-dependency Claude Code artifacts**, each independently
adoptable.

## Goals

- Flag deliverable elements that trace to none of: (1) a stated requirement, (2) an
  observed failure, (3) a correctness/security defect on a reachable path at a trust
  boundary.
- Stay generic — not bound to any language, domain, or deliverable type.
- Never push the artifact into *under*-engineering: the correctness/safety baseline
  is a discriminator pass, not a flaggable addition.
- Ship as three discrete artifacts with no inter-dependency; any subset is a working
  gate at its tier.
- Not over-engineer the gate itself (axis 8 — the meta-failure mode).

## Non-Goals

| Item | Rationale |
|------|-----------|
| Deterministic/static detection of over-engineering | No reliable syntactic signal exists; detection needs an agent reasoning pass. Hooks can remind/trigger, not detect. |
| A shared library the three artifacts import | Zero-dependency discreteness is the brief; each carries its own copy of the discriminator (deliberate, named DRY trade-off). Centralize only if all three are adopted. |
| Scoring over-engineering numerically | A number invites gaming; the gate surfaces flags, not scores. |
| Auto-fixing flagged elements | The gate detects and reports; remediation is a separate, user-driven step. |
| Replacing `/simplify` or `/code-review` | The skill composes them (thin wrapper), it does not reimplement them. |
| Catching over-engineering of agent/AI architecture | Out of frame — this gate is about the *deliverable*, generic software/system over-engineering. |
| Audit trail / monitoring for the gate | Axis-5 ops theater at this scope; findings go to stdout / injected context. |

## Architecture

Three independent artifacts mapping to this repo's three extension surfaces. They
share a *concept* (the discriminator), not a *dependency*.

```
                  3-clause discriminator + modifiers
                  (one concept, embedded 3x — no shared import)
                            |
        +-------------------+-------------------+
        |                   |                   |
   Option 1            Option 2            Option 3
   Agent profile       dp2 Rule (+hook)    Skill / command
   agent-profiles/     rules/ + .claude/   skills/<name>/SKILL.md
                       settings.json hook
        |                   |                   |
   active detect,      always-loaded +     active on-demand
   diff-model,         pre-build reminder  detect, composes
   isolated context    (hook can't detect) /simplify + /code-review

   Adopt any subset. All three = defense in depth (3 tiers:
   cheap always-on reminder / on-demand detect / isolated diff-model detect).
```

## Features

### Feature 1: Architecture and Design Document

The implementation design reference (`docs/ARCHITECTURE_AND_DESIGN.md`), **derived
from** the authoritative parent issue doc (`agents/issues/34-over-engineering-gate.md`)
— the discriminator, modifiers, the 8-axis taxonomy, guardrails on the gate itself,
and the per-artifact design for the three deliverables.

**Acceptance Criteria:**

- Captures the 3-clause discriminator and its modifiers (context-tunes-severity,
  reversibility-licenses-a-seam, counterfactual-as-escalation-only, cause-agnostic).
- Records the design decisions needed to explain the three artifacts and the
  discriminator — **no fixed quota** — each with rationale, including why detection
  cannot be deterministic and why the three artifacts share a concept not a
  dependency.
- Names the parent issue doc as source of truth; this doc is derived, not
  authoritative over it.
- Documents the anti-over-engineering guardrails the gate applies to itself.

### Feature 2: Over-Engineering Reviewer Agent Profile

A read-only reviewer subagent (`agent-profiles/over-engineering-reviewer.md`) that
runs the discriminator over a diff/file/plan/design and returns severity-tagged
findings — no praise, no fixes. The diff-model option is the only mechanism that
breaks artifact-anchored bias.

**Acceptance Criteria:**

- Frontmatter (`name`, `description`, `tools: Read, Grep, Glob`, `model`) plus a
  system-prompt body embedding the discriminator **and its four modifiers** (context
  tunes severity; reversibility licenses a seam not a feature; counterfactual is
  escalation-only via cold-regen by a different model; cause-agnostic), the 8-axis
  reference, and an anti-bias directive (find unjustified complexity, do not confirm
  quality; default to flagging).
- Every finding cites absence of **all three** discriminator clauses — no stated
  requirement, no observed failure, no correctness/security defect on a reachable
  path at a trust boundary.
- Findings output format: `path:line  <severity>  <axis>: <unjustified element>. <simpler alternative>.`
- Settable to a model other than the author's, for diff-model bias-break.
- Lives under the new top-level `agent-profiles/` directory.

### Feature 3: defensive-protocol-v2-over-engineering Rule + Hook

A new rule in the dp2 family (`rules/defensive-protocol-v2-over-engineering.md`):
the discriminator + modifiers + guardrails as self-applied rule text, paired with a
`UserPromptSubmit` hook that injects a one-line reminder on build/implement intent.
Installed by an idempotent script matching the existing dp2 installer.

**Acceptance Criteria:**

- Rule extends the dp2 family (reuses format; specializes the existing
  autonomy/blast-radius posture — does not duplicate it).
- `UserPromptSubmit` hook fires on intent keywords (`implement`, `build`, `develop`,
  `add a`, `write a`) injecting: "before building: run the 3-clause discriminator;
  default minimal; justify every addition."
- Idempotent installer merges the hook into `.claude/settings.json` (jq, fail-loud)
  and extends the CLAUDE.md Active-Rules block via sentinel markers; re-running does
  not duplicate.
- `bats` test covers install idempotency (matches dp2's tested-installer bar).
- No `chmod +x`; scripts invoked via `bash`.

### Feature 4: over-engineering-review Skill / Command

An on-demand active pass (`skills/over-engineering-review/SKILL.md`,
`/over-engineering-review`) that runs the discriminator over the current diff / a
named file / a plan and reports classified findings. A thin wrapper that orchestrates
`/simplify` and `/code-review`, adding only the requirement-ledger verification and
the discriminator.

**Acceptance Criteria:**

- Steps: resolve target → freeze requirement ledger (stated requirements, observed
  failures, named safety properties, user-vs-agent provenance) → run discriminator
  per element → for qualifying targets (design-stage, large delta, "production-ready"
  clusters, many-axes, safety-inversion) escalate to a **partial** cold counterfactual
  (re-derive from the ledger **by a different model**; full rewrite only for
  structural/axis-2 cases) → emit findings classified safe-remove / needs-decision /
  keep / harmful-theater.
- Cost-gates the counterfactual (a full counterfactual on a trivial target is itself
  axis-8 over-engineering).
- Composes existing `/simplify` and `/code-review`; does not reimplement them.
- `SKILL.md` frontmatter (`name`, `description`) plus `.claude/skills/` mirror.

## Configuration

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| Reviewer `model` (Feature 2) | string | `sonnet` | Set to a non-author model for diff-model bias-break. |
| Hook intent keywords (Feature 3) | list | `implement, build, develop, add a, write a` | Prompts that trigger the pre-build reminder. |
| Skill target (Feature 4) | enum | current diff | `diff` \| named file \| plan/design doc. |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| Severity-tagged findings | text | `path:line  <severity>  <axis>: element. simpler alternative.` (Features 2, 4) |
| Pre-build reminder | injected context | One-line discriminator reminder on build intent (Feature 3). |
| Classified findings | text | safe-remove / needs-decision / keep / harmful-theater (Feature 4). |

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Gate over-engineers itself (axis 8) | Guardrails section; one discriminator + modifiers, not parallel subsystems; reviewers already caught this once (Point 5). |
| False positives flag the correctness/safety floor → under-engineering | Floor items PASS the discriminator (clause 3); not a separate exempt list. |
| Minimal-default under-builds a genuine production repo | Inferred repo signals (CI, deploy targets, file location, data sensitivity) tune **severity and the stop/ask posture — not flag existence**; the discriminator fires context-free and the default stays minimal unless a clause passes. Gate stops and asks on high blast-radius / sensitive-data / public-exposure / one-way-migration. |
| Hook can only remind, not detect | Documented; detection lives in the agent (F2) and skill (F4), not the hook. |
| Reversibility carve-out becomes a "everything is a one-way door" loophole | Door licenses a seam, not the feature; burden-of-proof names all four (surface, future change, later cost, smallest present action); default-deny on unproven one-way claims. |
| Three embedded copies of the discriminator drift | Named, deliberate DRY trade-off; centralize only when all three adopted. |

## Success Criteria

- On a known over-engineered fixture (the terraform plan>approve>apply illustration),
  the gate flags the unjustified additions and passes the correctness floor.
- On a minimal correct fixture, the gate produces zero false positives.
- Each artifact is adoptable standalone with no reference to the other two.
- Re-running the Feature 3 installer is idempotent.

## Future Enhancements

| Enhancement | Description |
|-------------|-------------|
| Centralize the discriminator | If all three artifacts are adopted, extract the shared discriminator to one source. |
| Wire the skill into review phases | Hook `/over-engineering-review` into `/plan-feature` and `/build` gates. |
| Per-domain illustrative examples | Non-authoritative, versioned, review-owned outputs of running the test in context — **barred from becoming checklist policy** (maintain the test, not a canon). |
