# Architecture and Design: Over-Engineering Gate

> Implementation design reference, **derived from** the authoritative parent issue
> doc `agents/issues/34-over-engineering-gate.md` (source of truth) and its
> deep-dive set `agents/issues/34-over-engineering/01..06`. PRD: `prd.md`.
> Where this doc and the parent issue doc disagree, the parent issue doc wins.

## Overview

The over-engineering gate catches an AI coding agent over-engineering its **own
deliverables** — the design and code it produces in response to a request — judged
against KISS, DRY, and YAGNI. The whole gate collapses to **one discriminator plus
modifiers**, not a set of separate detectors. It ships as **three discrete,
zero-dependency artifacts**, each a working gate at its own tier; any subset can be
adopted, in any order, with no reference to the others.

The root cause the gate exists to counter is inherent and un-removable: RLHF
thoroughness/length bias makes the agent inflate ambiguous asks into
"production-ready" output. Because the bias is in the producer, the correction must
be **external** to the producer — a separate pass that does not share the artifact's
authoring context. That is why the gate exists as tooling, not as a reminder the
author gives itself.

## The Discriminator (the spine)

For each element of a deliverable:

> Does it trace to **(1)** a stated requirement, **(2)** an observed failure, or
> **(3)** a correctness/security defect on a reachable path at a trust boundary?
> **If none → flag.**

Modifiers (tune the response, not the existence of the flag):

- **Context tunes severity, not detection.** The discriminator fires context-free.
  Context (blast radius × lifespan, plus an explicit security/data-sensitivity
  signal) tunes the cost threshold and the enforcement posture (advise vs. block),
  not whether the flag fires. Default when context is absent: **minimal /
  prototype-grade, flag aggressively** — but never below the clause-3 floor.
- **Reversibility licenses a seam, not a feature.** A one-way door (persisted data,
  published contract, wire format, public name) justifies a cheap *reversal seam*
  (a nullable column, a documented migration path) — never the speculative feature.
  Score by the blast-radius-escape test ("if I ship and reverse this later, who/what
  outside the current diff must change?"): **0 triggers → defer** (YAGNI applies);
  **1 trigger → build the seam, not the feature**; **2+ triggers → surface to the
  user.** Burden of proof: name all four — the irreversible surface, the plausible
  future change, the concrete later cost, the smallest present action — or YAGNI
  wins. The modifier never downgrades the discriminator; an unproven one-way claim
  is treated as two-way and deferred.
- **Counterfactual is escalation-only.** The cheap static discriminator is
  detection-primary; the counterfactual is the selective falsification test. Trigger
  it for design-stage artifacts, large deltas, "production-ready" phrase clusters,
  many-axes-triggered, or safety-inversion risk — not on every target. **Partial**
  counterfactual (re-derive one layer/section from the frozen ledger **by a
  different model**, original removed from context) is the default; a full rewrite
  is reserved for structural over-engineering (axis 2) where the shape is the excess.
  A full counterfactual on a trivial/reversible target is itself axis-8
  over-engineering.
- **Cause-agnostic.** The gate acts on the output signature (an element that fails
  the discriminator), not on why the agent produced it.

**Clause 3 IS the correctness/safety floor.** Floor items (`set -euo pipefail`,
parameterized queries, applying the saved plan) are **not exempt** — they *pass*
clause 3. There is no parallel "exempt list." The floor and Axis 4 (defensive
bloat) are one predicate, two verdicts: delete the element — does a plausible
in-scope input now produce a wrong result, lost/corrupted data, a security hole, or
a silently-swallowed failure on a reachable path at a trust boundary? Yes → floor
(keep). Loses only convenience / future flexibility / hypothetical robustness →
excess (flag).

**Boundary cases — one rule: trust boundary + reachability + named failure mode.**

| Element | Floor (passes clause 3) | Excess (flag) |
|---------|-------------------------|---------------|
| Retries | transient/idempotent op, bounded attempts, surfaced failure (named dependency) | unbounded / on non-idempotent / masks the failure |
| Logging | required output/audit, or stderr insufficient to operate the workflow | decorative / duplicates available signal |
| Input validation | external/untrusted boundary on a reachable path | internal trusted caller |
| Error handling | preserves an invariant/cleanup, or sharpens a reachable failure | swallows/masks, or wraps infallible code |

## The 8-Axis Taxonomy (reference)

The discriminator is the test; the axes are the vocabulary for *what kind* of
unjustified complexity was found.

| # | Axis | Principle |
|---|------|-----------|
| 1 | Speculative scope | YAGNI |
| 2 | Premature abstraction | KISS |
| 3 | Premature optimization | KISS |
| 4 | Defensive bloat | (clause-3 predicate, flag side) |
| 5 | Robustness / ops theater | YAGNI |
| 6 | Test / doc ceremony | DRY / YAGNI |
| 7 | Data / schema / API over-modeling | YAGNI (houses the reversibility loophole) |
| 8 | Process over-engineering (meta) | the agent over-applying its own machinery |

## Component Diagram

```
                 3-clause discriminator + 4 modifiers
                 ONE concept — embedded 3x, no shared import
                              |
        +---------------------+---------------------+
        |                     |                     |
   Feature 2             Feature 3             Feature 4
   Agent profile         dp2 Rule + hook       Skill / command
   agent-profiles/       rules/ + installer    skills/<name>/
   over-engineering-     defensive-protocol-   over-engineering-
   reviewer.md           v2-over-engineering   review/SKILL.md
        |                     |                     |
   active detect;        always-loaded rule    active on-demand
   isolated context;     + UserPromptSubmit     detect; composes
   diff-model bias-      hook reminder on       /simplify +
   break                 build intent           /code-review
        |                     |                     |
   ── tier 3 ──          ── tier 1 ──           ── tier 2 ──
   isolated/diff-        cheap always-on        on-demand
   model detection       reminder (can't        detection
   for high stakes       detect, only remind)
```

## Data Flow (the discriminator pass)

1. **Resolve target** — a diff, a file, a plan, or a design doc.
2. **Freeze the requirement ledger** — extract stated requirements, observed
   failures, and named safety properties (e.g. "human eyes on the plan before
   apply"), tagging each requirement's provenance (user-stated vs. agent-inferred).
   Freeze it before review so post-hoc requirement invention ("I needed it because I
   built it") and upstream gold-plating cannot contaminate the baseline. An
   agent-inferred requirement that justifies nothing escalates upstream, it does not
   enter the ledger.
3. **Run the discriminator per element** — check clause 1/2/3; if none pass → flag,
   tagged with an axis and a severity.
4. **Apply modifiers** (these govern the *response*, never whether the flag fires) —
   context tunes severity; reversibility routes a flag to defer / build-a-seam /
   surface per the blast-radius-escape count; qualifying targets escalate to the
   partial different-model counterfactual.
5. **Classify and emit** — each element is tagged `safe-remove` / `needs-decision` /
   `keep` / `harmful-theater`. Flagged items (`safe-remove`, `harmful-theater`) cite
   absence of all three clauses; `keep` cites the clause it passes (often clause 3,
   the floor); `needs-decision` is the contested middle, surfaced to the user, not
   auto-resolved.

## Component Inventory

| # | Component | Type / Technology | Purpose |
|---|-----------|-------------------|---------|
| 1 | `docs/ARCHITECTURE_AND_DESIGN.md` | Markdown | This design (Feature 1). |
| 2 | `agent-profiles/over-engineering-reviewer.md` | Markdown (agent profile) | Isolated/diff-model reviewer (Feature 2). |
| 3 | `rules/defensive-protocol-v2-over-engineering.md` | Markdown (dp2 rule) | Always-loaded self-applied rule (Feature 3). |
| 4 | `scripts/defensive-protocol/hooks/over-engineering-reminder.sh` | Bash (`UserPromptSubmit`) | Pre-build reminder injection (Feature 3). |
| 5 | `scripts/defensive-protocol/install.sh` (extended) | Bash + jq | Idempotent installer (Feature 3). |
| 6 | `skills/over-engineering-review/SKILL.md` | Markdown (skill) + `.claude/skills/` mirror | On-demand detection pass (Feature 4). |

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | The gate is **one discriminator + modifiers**, not separate detectors. | Emerged from 10 sub-agent reviews; separate machinery per axis would itself be over-engineering (axis 8). |
| 2 | The three artifacts share a **concept, not a dependency**; each embeds its own copy. | Zero-dependency discreteness is the brief. A shared library for a single adopter is premature abstraction (axis 2 / named DRY trade-off). |
| 3 | **No deterministic/static detection.** | No reliable syntactic signal for over-engineering exists; detection needs an agent reasoning pass. Hooks can remind/trigger, not detect. |
| 4 | The correctness/safety floor is **clause 3 of the discriminator**, not an exempt list. | An exempt list is a blind spot (floor items can themselves be over-applied). One predicate, two verdicts prevents building two gates. |
| 5 | **Minimal/prototype-grade default** when context is absent, flag aggressively. | The gate exists *because* the agent inflates ambiguous asks. Defaulting to maximal would encode the exact bias the gate catches. A flag is cheap; silent inflation is costly. |
| 6 | Context = **blast_radius × lifespan**, with security/data-sensitivity kept explicit. | Load-bearing pair carries most signal; security stays explicit so minimal-default never drops below the floor. `audience`/`change_frequency` are derived — dropped to cut capture cost. |
| 7 | Reversibility output is **"build a seam," never "build the feature."** | A one-way door reframed as permission-to-build is the loophole the bias weaponizes; axis 7 is its existence proof. The door licenses a reversal point only. |
| 8 | The counterfactual is **different-model, escalation-only.** | A different model breaks the artifact-anchored bias that same-model self-review cannot. Restricting to high-stakes targets stops the counterfactual itself becoming axis-8 bloat. |
| 9 | Inferred repo signals **tune severity + stop/ask posture, not flag existence.** | Keeps the discriminator context-free and falsifiable; a context-independent class of smells (rollback theater, swallowed errors, one-impl interfaces) fires regardless of context. |
| 10 | Feature 3 **extends the dp2 family**, reusing its rule format, installer, and CLAUDE.md sentinel block. | dp2 already carries the autonomy/blast-radius posture; this rule specializes it, not duplicates it (Chesterton on our own rules). |
| 11 | Feature 3 pairs the rule with a **`UserPromptSubmit` hook**. | The repo's own spike proved rule-text-alone is routed around by completion bias; the hook deterministically **injects a reminder** at the build-intent moment. Whether that reminder only advises or also blocks is enforcement mode — deferred (D1); the hook reminds, it does not detect or stop. |
| 12 | The skill (Feature 4) is a **thin wrapper** over `/simplify` + `/code-review`. | Reuses existing tooling (DRY); adds only the requirement-ledger freeze and the discriminator. Reimplementing them would be redundant. |
| 13 | Findings are **surfaced as flags, never scored numerically.** | A number invites gaming and false precision; the gate reports classified findings with cited clause-absence. |
| 14 | Installer is **fail-loud** (jq required, no silent fallback) and never sets the executable bit. | Matches dp2's tested-installer bar and the repo's anti-slop "let it crash"; `chmod +x` is hard-blocked repo policy. |
| 15 | Per-domain examples are **illustrative, review-owned, never canon.** | Maintain the *test*, not a curated list — a frozen checklist rots and re-imports the "to be safe" loophole. |

## Deferred Design Decisions

Intentionally unresolved; decide during implementation, not now.

| # | Decision | Status |
|---|----------|--------|
| D1 | **Feature 3 enforcement mode: advise-only vs. block.** A `UserPromptSubmit` hook injects context Claude reads on the *next* request (cannot pause); only `permissionDecision` ask/deny or `exit 2` on a `PreToolUse` action can stop execution. | **Deferred** (user, 2026-06-16). Lean advise-only unless implementation evidence warrants a block. |
| D2 | Whether to centralize the discriminator once all three artifacts are adopted. | Deferred — centralize only if all three artifacts are adopted AND the duplication is causing drift; until then, duplication keeps them discrete. |
| D3 | Exact context-sourcing precedence when explicit PRD/architecture text and inferred repo signals disagree. | Deferred — design says ask-user only when sources conflict AND the finding is high-cost. |

## Security Model

Right-sized to the actual surface (a tooling project: markdown + bash hooks + a jq
installer). Deliberately not expanded into theater — over-hardening here would
violate the gate's own ethos (axis 5).

### Execution surface

- The `UserPromptSubmit` hook is a bash script that **emits text only** (a reminder
  string); it does not read secrets, make network calls, or mutate state.
- **Untrusted prompt text is data, never code:** the prompt is read via `jq` from
  stdin and *matched*, never executed — all expansions quoted, no `eval` / `source`
  / command substitution on prompt content. (This is the real attack surface: a
  prompt is attacker-influencable input entering a shell.)
- Scripts are invoked via `bash script.sh`; the executable bit is never set
  (repo policy, hard-blocked).

### Installer surface

- The installer modifies `.claude/settings.json` (jq merge) and the CLAUDE.md
  Active-Rules block (sentinel-guarded append). Settings writes are
  **jq-to-temp-then-atomic-move**, validated before replacing the original, so a
  failed merge cannot corrupt `.claude/settings.json`. Both surfaces are
  **idempotent** and **fail-loud** — a missing jq or invalid JSON aborts rather than
  silently corrupting state.
- No network access, no credential handling, no data at rest.

### Audit and logging

- None required. The gate produces findings to stdout / injected context; it keeps
  no audit trail. Adding one would be axis-5 ops theater for this scope.

## File Organization

Pure layout (purpose lives in Component Inventory; relationships in Dependency
Graph — these are three lenses on the same six artifacts, not three copies):

```
project-root/
├── prd.md
├── progress.txt
├── docs/ARCHITECTURE_AND_DESIGN.md
├── agent-profiles/over-engineering-reviewer.md           # F2 (new top-level dir)
├── rules/defensive-protocol-v2-over-engineering.md       # F3 (rule source)
├── scripts/defensive-protocol/
│   ├── install.sh                                         # F3 (installer, extended)
│   └── hooks/over-engineering-reminder.sh                 # F3 (hook)
└── skills/over-engineering-review/SKILL.md                # F4 (+ .claude/skills/ mirror)
```

## Deployment Workflow

Per-artifact, independent (no shared deploy):

- **Feature 2 (agent profile):** drop the markdown file into `agent-profiles/`. No
  wiring. Invoked via the Agent tool.
- **Feature 3 (rule + hook):** `bash scripts/defensive-protocol/install.sh <target>`
  — copies the rule to `<target>/.claude/rules/`, the hook to
  `scripts/defensive-protocol/hooks/`, jq-merges the `UserPromptSubmit` entry into
  `.claude/settings.json`, and appends the sentinel-guarded rule to CLAUDE.md.
  Idempotent; restart Claude Code in the target to load.
- **Feature 4 (skill):** drop `SKILL.md` into `skills/over-engineering-review/`
  (+ `.claude/skills/` mirror). Invoked via `/over-engineering-review`.

## Dependency Graph

```
Feature 1 (this doc)
    └── source: agents/issues/34-over-engineering-gate.md (authoritative)

Feature 2  ──┐
Feature 3  ──┤── share the DISCRIMINATOR CONCEPT only (no build/runtime dependency)
Feature 4  ──┘

Feature 4 (skill)
    └── composes (runtime): /simplify, /code-review   # reuse, not a build dep
Feature 3 (installer)
    └── requires: jq, bash   # fail-loud if jq absent
```

## Out of Scope

| Item | Rationale |
|------|-----------|
| Deterministic/static over-engineering detection | No reliable syntactic signal; needs an agent pass (Decision #3). |
| A shared library imported by all three artifacts | Zero-dependency brief; premature for a single adopter (Decision #2). |
| Numeric over-engineering score | Invites gaming (Decision #13). |
| Auto-fixing flagged elements | Gate detects and reports; remediation is user-driven. |
| Reimplementing `/simplify` or `/code-review` | Feature 4 composes them (Decision #12). |
| Over-engineering of agent/AI architecture | Out of frame — the gate targets the *deliverable*, generic software over-engineering. |
| Audit trail / monitoring for the gate | Axis-5 ops theater at this scope (Security Model). |
