# Gate 3 Review -- Milestone Planning

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/README.md
**Status:** [x] Approved
**Reviewer(s):** Operator
**Date:** 2026-09-04

> **Fresh review after a scope revision (2026-09-04).** The prior Gate 3 review (approved
> 2026-09-04) is superseded: one of its `[Auto]` items — "per-agent **mTLS** workload identity
> (R8.8) sits in 01.3" — rested on an assumption 01.1 SF-2 subsequently falsified. Feature 01.3 is
> reset to `[ ]` pending and split; Feature 01.6 is new. Features 01.1 and 01.2 are complete and
> unaffected; 01.4 and 01.5 keep their Gate 4 plans.

## What changed in this revision

- **Trigger.** `/build` pre-flight for 01.3 found that 01.1 SF-2's recorded results contradict the
  milestone's identity criterion: `codex` rejects an `https://`-scheme proxy URL at parse time (it
  cannot reach a TLS listener at all) and `agy` reaches the handshake with no client certificate to
  present. Only `claude` can do mTLS. See
  `docs/records/r8-8-identity-mechanism-gap-escalation.md`.
- **Decision 1 — mechanism.** R8.8's own text requires "a distinct workload identity with a defined
  lifecycle, used for authentication to the enforcement point and recorded in the audit log" — it
  does not name mTLS. mTLS is D6's mechanism, and D6's precondition binds **credential brokering**,
  which is Milestone 03. Identity is therefore delivered in the strongest form each client supports,
  verified per agent.
- **Decision 2 — R8.8 is met, with the strength difference recorded.** Network-derived identity
  counts as authentication for R8.8: an agent cannot present itself on another agent's network at
  all, so the identity is unforgeable by the threat R8.8 names. It is weaker than a cryptographic
  binding because it is a property of the deployment shape and would break silently if two agents
  ever shared a network — so every audit line records which form produced the attribution, and the
  harness asserts network disjointness.
- **Decision 3 — Milestone 03 inherits the restriction.** Brokering is enabled only for
  cryptographically bound identities, which on today's evidence may mean `claude` alone.
- **Decision 4 — 01.3 is split.** 01.3 keeps L7 policy evaluation, DNS authority, the audit writer
  and the per-agent listener surface. New **Feature 01.6: Per-agent workload identity** takes client
  authentication, issuance, lifecycle, T34 and the M03 gate. The milestone goes to six features, one
  over DD-1's ceiling — recorded as a deliberate deviation in Sizing.
- **Sections revised.** Feature 01.3 (identity criteria removed, listener-surface criterion added,
  intro rescoped to three roles); **Feature 01.6 added**; Dependencies; Ordering (01.6's placement
  and why it is numbered rather than inserted); Sizing (DD-1 deviation); Configuration (two rows);
  Definition of Done (R8.8 item added, 5/5 → 6/6).
- **Sections preserved.** Goal, Features 01.1/01.2/01.4/01.5.

## Pre-checks (verified programmatically)

- [x] `milestones/01-sandboxed-pod/README.md` exists
- [x] All required sections present: Goal, Features, Dependencies, Ordering, Sizing, Configuration,
      Definition of Done
- [x] `milestones/01-sandboxed-pod/milestone-status.txt` exists
- [x] Feature count matches across README.md and milestone-status.txt (6 and 6), feature names identical
- [x] Every feature carries at least one acceptance criterion (6 Acceptance Criteria blocks for 6 features)
- [x] `milestone-status.txt` header count agrees with its feature markers (6 features, 2 complete)
- [x] `progress.txt` milestone summary agrees with `milestone-status.txt` (2/6 features complete)
- [x] Feature 01.3 is reset to `[ ]` with `Plan: (not yet planned)`; the prior plan file remains on
      disk at `plans/egress-mediator.md` for `/plan-feature` re-plan mode
- [x] Feature 01.6 is present at `[ ]` with `Plan: (not yet planned)`

## Checklist

- [x] Does the milestone represent a coherent, deployable increment? — unchanged by the revision. The
      split moves work between features inside the milestone; the milestone still delivers a pod that
      runs three authenticated agents behind a default-deny mediator.
- [x] Are features correctly grouped? Any that belong in a different milestone? — 01.6 is the one
      grouping change. It stays in Milestone 01 rather than moving to 03: R8.8 is a MUST, and
      deferring it to a milestone gated on Q9 would put a MUST behind an unanswered external question.
- [x] Is the ordering correct given dependencies? — 01.3 → 01.4 unchanged and reinforced. 01.6 is
      ordered after 01.3 and is free relative to 01.4/01.5, because 01.3 leaves per-agent policy
      selection working on network-derived identity. Numbering records insertion order; the Ordering
      section records execution order.
- [x] Are the acceptance criteria specific and testable? — the identity criteria are outcome-recorded
      rather than outcome-assumed (the 01.1 disposition), and T34's two forms are each stated with
      the assertion that proves them.
- [x] Is the sizing realistic? — resolved by the split. Six features, one over DD-1's ceiling,
      recorded as a deviation in Sizing rather than absorbed silently.
- [x] [Auto] Validate the central trade: R8.8 with a per-agent mechanism. **Operator decision: R8.8
      is met, with the strength difference recorded per audit line.** The topology authenticates for
      the threat R8.8 names; what it does not survive is a change in deployment shape, which is why
      network disjointness is asserted by the harness rather than assumed.
- [x] [Auto] Confirm the Milestone 03 gate is inherited, not merely stated. **Operator decision:
      accept the restriction.** M03 is defined against whatever identity evidence exists then; if
      `codex`/`agy` still cannot bind cryptographically they are not brokered to and M03's scope
      narrows accordingly.
- [x] [Auto] Confirm the `codex` plaintext proxy hop is acceptable. Verified: `REQUIREMENTS.md`
      contains no requirement reading on agent→mediator proxy-hop confidentiality (R5.12 is a SHOULD
      governing CA distribution "where TLS interception is used"). Destination TLS is spliced, not
      terminated (D4, R5.15), so no new party observes hostname or payload; the hop runs on a
      two-member `internal: true` network. Search-based finding — absence of a matching requirement,
      not proof one cannot exist.
- [x] [Auto] Confirm sizing after the revision. **Operator decision: split 01.3.** See Sizing for the
      DD-1 deviation and its rationale.
- [x] [Auto] Confirm the register interpretations are routed, not absorbed. T34's method amendment
      and 01.3's existing T28 amendment are both recorded as `REQUIREMENTS.md` changes owned by
      `/plan-feature` at Gate 4. `/milestone` has no authority to edit the register (the prior
      review's stated posture, carried forward). **Open until `/plan-feature` lands them** — this
      item confirms the routing exists, not that the register is amended.
- [x] [Auto] Confirm 01.4 and 01.5 are genuinely unaffected. Verified: 01.4's Interface Contract 6
      names the proxy variables and states "01.4 consumes all of it unchanged" — no `https://` value
      is hardcoded, so a per-agent scheme is an edit inside 01.3's contract. One ripple, content not
      scope: 01.4's Contract 7 inventories the client **key** as an R8.4 credential, and for an agent
      with no certificate that entry becomes a proxy credential or nothing. 01.5 has no identity
      surface and is untouched.

## Reviewer Comments

- **DD-1 ceiling exceeded by one, deliberately.** Six features against a 2–5 ceiling. The ceiling
  governs review load; the alternative was a single feature already at eight sub-features before the
  revision added a verification step and a non-uniform listener surface. Recorded in Sizing rather
  than waived silently.
- **01.6 is numbered, not inserted.** Renumbering old 01.4/01.5 would have rewritten two Gate
  4-approved plans that reference their own numbers throughout. The number records insertion order;
  the Ordering section is authoritative for execution order. A reader who assumes numeric order is
  execution order will be wrong about this one milestone, which is the cost of the choice.
- **This revision exists because a Gate 4 plan was built on an assumption its own dependency had
  already falsified.** 01.1 SF-2's client-certificate result predates 01.3's plan; the plan's
  Interface Contract 2 assumed a uniform `https://` proxy hop anyway, and the contradiction surfaced
  at `/build` pre-flight rather than at Gate 4. Worth carrying into the next Gate 4 review as a check:
  does this plan's interface contract agree with the recorded results of the features it depends on?
- **What is still unverified.** Whether `codex` or `agy` accepts a proxy credential is unknown and is
  01.6's first criterion. If neither does, both carry network-derived identity and Milestone 03
  brokers to `claude` alone — a possibility this review accepts in advance rather than treating as a
  later surprise.

  **Answered, 2026-09-09 (01.6 SF-1, recorded at milestone close).** POSITIVE for **both**. Each
  constructs `Proxy-Authorization: Basic` from proxy-URL userinfo, preemptively — `codex` on the
  plain transport, `agy` on TLS and on plain — so neither needed a credential knob it does not have.
  Both now carry a per-agent proxy credential verified against the mediator's htpasswd, and their
  verdict lines read `identity_source: listener+proxy_auth`. The possibility this review accepted in
  advance did not materialise, but **the Milestone 03 restriction it anticipated stands anyway, for
  a different reason**: the brokering gate is the *cryptographic* form alone (D6), and the credential
  form is excluded because `codex`'s credential crosses its plain-HTTP hop in the clear. So
  Milestone 03 does broker to `claude` alone — not because the other two are unidentified, but
  because a credential an attacker can read off the wire is not a key. See
  `docs/records/workload-identity.md`.
