# Gate 3 Review -- Milestone Planning

**Artifact:** milestones/03-aws-access/README.md
**Status:** [x] Approved
**Reviewer(s):** Operator; adversarial review by Codex; design review by advisor
**Date:** 2026-09-04

## Pre-checks (verified programmatically)

- [x] `milestones/03-aws-access/README.md` exists
- [x] All required sections present: Goal, Features, Dependencies, Ordering, Sizing, Definition of Done
- [x] `milestones/03-aws-access/milestone-status.txt` exists
- [x] Feature count matches across README.md and milestone-status.txt (5 and 5), and feature names are identical
- [x] Every feature carries at least one acceptance criterion (5 Acceptance Criteria blocks for 5 features)

## Checklist

- [x] Does the milestone represent a coherent, deployable increment?
- [x] Are features correctly grouped? Any that belong in a different milestone?
- [x] Is the ordering correct given dependencies?
- [x] Are the acceptance criteria specific and testable?
- [x] Is the sizing realistic?
- [x] [Auto] **Confirm test and requirement ownership.** No AWS test appears in the approved
      Milestone 01 or 02 READMEs — verified by grep: T10, T11, T12, T13, T19 and T20 are unowned
      until now. This milestone owns all six (T11 resolving to a proposed amendment rather than a
      pass), plus R8.3 as the mediator's fifth role that 01.3 explicitly deferred here, R12.6's AWS
      half, T14-style composition for the AWS pack, a T26 extension for the two new credentials, and
      re-runs of T38, T3–T8 and T42 against AWS-loading profiles. Confirm nothing is orphaned and
      that the re-runs read as regression against a changed boundary, not as double ownership with
      Milestone 02.
- [x] [Auto] **Decision required — Q9 as a start-gate rather than a feature outcome.** The README
      makes "Q9 answered positively" a hard dependency: if a dedicated Identity Center principal
      cannot be created, the milestone does not start, the pack does not ship, and SC-5 is recorded
      as **permanently unmet** with D13a as the reason. The alternative shape — a first feature that
      "resolves Q9" and may fail — was rejected because a feature that can fail is not a feature.
      Confirm the fail-closed outcome, and specifically confirm that **Model A is not treated as a
      fallback**: R6.5.2 requires the same dedicated principal, so a negative Q9 removes it too.
      **Operator approved, 2026-09-04:** Q9 is a start-gate; a negative answer records SC-5 as
      permanently unmet rather than triggering a substitution.
- [x] [Auto] **Decision required — R8.3's mechanism is unavailable under D4, and 03.2 records that
      rather than working around it.** R8.3 (SHOULD) describes credentials injected into upstream
      requests at the enforcement point, citing `codex-responses-api-proxy`. That requires TLS
      termination; D4 forbids termination for all three agents, and AWS requests are SigV4-signed by
      the client regardless. Delivery is therefore `credential_process` or refreshed environment
      credentials, and the agent container **does** hold a credential — a short-lived one. Confirm
      that meeting R8.3's goal (no long-lived token in the container) while recording its mechanism
      as structurally unavailable is the right disposition, rather than reopening D4.
      **Operator approved, 2026-09-04:** D4 is not reopened; R8.3's goal is met and its mechanism is
      recorded as unavailable.
- [x] [Auto] **Decision required — where the SSO relationship lives under Model B.** 03.2 relocates
      the headless login, the refresh token and the token cache from the agent container to the
      mediator, which makes R6.2.3, R6.2.4 and R6.2.5 mediator-side requirements and moves `oidc.*`
      and `portal.sso.*` off every agent allowlist (R6.4.6). The consequence is a **new long-lived
      credential on the mediator**, enumerated under R8.4 and revocable under R8.5/R13.1. Confirm the
      relocation, and confirm the mediator — which already holds the CA private key and the DNS role
      — is the right place to concentrate it. **Operator approved, 2026-09-04.**
- [x] [Auto] **Decision required — CloudTrail attribution granularity (03.1).** One broker principal
      in front of three agents may record the broker rather than the agent in CloudTrail, against
      R6.3.8 (SHOULD). Three options are set out in Ordering: role-chain with `RoleSessionName`
      carrying the R8.8 identity (chosen, attempted first); three Identity Center principals (clean,
      but triples the Q9 ask that already gates the milestone); or accept per-broker granularity and
      record R6.3.8 as partially met. Confirm the choice and confirm that recording the outcome
      either way — rather than assuming role-chaining works — is acceptable. **Operator approved,
      2026-09-04:** attempt role-chaining, record the outcome as a finding either way.
- [x] [Auto] **Check dependency: 03.2 must precede 03.3.** The pack's egress shape is a consequence
      of the credential model — R6.4.6 removes the SSO auth endpoints from the agent allowlist
      *because* the broker performs the login, and `sts.<region>` stays because T10 needs it from
      inside the container. Confirm this ordering, and confirm the resolved-policy check in 03.3
      (STS present, SSO auth endpoints absent, no `*.amazonaws.com`) is the right shape to assert.
- [x] [Auto] **Check dependency: 03.2 does not start until T34 has passed.** D6 makes per-agent
      workload identity a hard precondition for brokering; R8.8 lands in 01.3. Confirm the gate is
      stated at the right strength — brokering without caller identity is worse than no brokering.
- [x] [Auto] **Validate scope: T13's denying control is recorded, not assumed.** A cross-account
      `PutObject` may be denied by the egress policy (inside this project's control) or by the data
      perimeter (R6.3.6, a SHOULD in the operator's estate). If Q1 returns a broad S3 surface,
      R6.4.3's bucket-FQDN allowlisting becomes impractical and T13 rests entirely on the perimeter.
      Confirm that recording which control denied it — and flagging a perimeter-only pass as a single
      point of failure — is the right treatment.
- [x] [Auto] **Confirm sizing: 03.2 is the largest build item and 03.1 the longest elapsed.** 03.2
      names its `/plan`-time split seam (minting and binding, then the upstream SSO relationship) and
      names revision mode as the fallback if it runs long. 03.1 is almost entirely someone else's
      work. Confirm both, and confirm that five features at the DD-1 ceiling is right for a milestone
      that cannot ship partially — SC-5 is one claim.
- [x] [Auto] **Confirm the two recorded amendments stay proposals.** T11 relocation (against
      `REQUIREMENTS.md` — Model B makes in-container SSO login structurally unreachable, so the test
      as written cannot pass) and the R6.3.8 attribution-granularity finding if role-chaining proves
      unreachable. `/milestone` may edit neither `REQUIREMENTS.md` nor the architecture document —
      the same posture Gate 2 took with T21–T45 and Milestone 02 took with R13.2/T40 and D21.
      Confirm both are recorded and put to the operator, not applied.
- [x] [Auto] **Confirm the R8.5 gate added after adversarial review.** An issued STS credential must
      be **actually revoked and timed**, not allowed to expire — R8.5 is a MUST and T26's pass
      condition is that revocation succeeds. 03.5 names the `aws:TokenIssueTime` deny-policy
      mechanism and the Definition of Done blocks lifting the R12.8 notice if no working procedure
      exists. Confirm that gate, or accept shipping AWS with an outstanding MUST. **Operator
      approved, 2026-09-04:** the gate holds — the notice does not lift with R8.5 outstanding.
- [x] [Auto] **Confirm 03.2 owns the R8.3 disposition Milestone 02 deferred here.** 02.3 ships the
      GitHub CLI token and the Kubernetes `kubeconfig` secret-injected or volume-resident and states
      that upstream brokering "sits in Milestone 03". 03.2 now requires each to be brokered or
      recorded N/A with reason. Confirm that this is the right home for it, and that a recorded N/A
      — the likely outcome under D4 — is an acceptable disposition for a SHOULD.
- [x] [Auto] **Validate scope: the broker binds at issuance, not at use.** The mediator refuses to
      mint or refresh for a mismatched R8.8 identity, but cannot detect agent B *using* agent A's
      already-issued STS credential — the container signs SigV4 locally and D4 splices rather than
      terminates. Per-agent network isolation (D2) is what narrows the theft path. Confirm the
      narrowed claim and the recorded residual.
- [x] [Auto] **Validate scope: the Goal claims SC-5 and nothing wider.** Milestone 02 lifted the R12.8
      notice for non-AWS profiles; this milestone lifts it for AWS-loading profiles only, after
      re-running T38 and T3–T8 against them. Confirm the Goal and Definition of Done do not
      overclaim — a Milestone 01 adversarial finding and a Milestone 02 review item both landed on
      exactly this.

## Reviewer Comments

- **AWS is a third party with no R14.1 record.** 01.1 recorded Docker Sandboxes and the three model
  providers; 02.3 recorded HashiCorp, GitHub and the Kubernetes endpoints. AWS is covered by none of
  them, and R14.1 is a MUST that applies **before** traffic reaches the third party. 03.1 records it
  and 03.5 confirms the record predates the first agent request via an extended T42.
- **T11 cannot pass as written, and this is a property of the chosen model rather than a defect.**
  R6.5.4 keeps the SSO token out of the container, R6.4.6 removes the auth endpoints from its
  allowlist, and T11 requires a login to complete inside it with the token cached on a volume. The
  proposed amendment relocates T11's subject to the mediator, where 03.2 verifies the same headless
  flow and refresh-token issuance. Recorded rather than papered over.
- **R6.3.2's wording is noted, not flagged as a gap.** It says the agent "authenticates as a
  dedicated permission set"; under Model B the agent authenticates only to the mediator, with its
  mTLS identity, and never to AWS. The dedicated permission set is what its credentials resolve to,
  which satisfies the requirement in substance.
- **Three register wordings are Model-A-shaped and are noted, not flagged as gaps.** R6.4.3 leans on
  `s3.addressing_style` as though the config file were the control — R6.3.2a says otherwise, and 03.3
  asserts the allowlist shape (no bare `s3.<region>` endpoint, no `*.s3.<region>` wildcard) as the
  actual enforcement. R6.2.6 names an `[sso-session]` block that a Model B container does not have.
  R6.3.2 says the agent "authenticates as a dedicated permission set", covered above.
- **R6.2.5 changes subject rather than lapsing.** Its own text scopes it to Model A; under Model B
  the caches it governs exist on the mediator, and 03.2 places them off every agent-reachable volume.
- **The one-port constraint from 01.3 is carried forward.** The mediator exposes exactly the proxy
  listener to each agent network, with no management or metrics port. `credential_process` reaches
  the broker through that listener; a second port would be a design change requiring review.
- **Adversarial review, and the findings closed before presentation.** Reviewed by Codex against
  `REQUIREMENTS.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `prd.md` and the approved Milestone 01 and 02
  artifacts. One Critical, two Major and one Minor, all applied to the README before this review was
  presented: **(Critical)** 03.5 treated in-flight STS expiry plus "no further mint" as revocation,
  which R8.5 (MUST) and T26 do not accept — 03.5 now requires an executed, timed active-session
  revocation and the Definition of Done blocks the R12.8 lift without one; **(Major)** the R8.3
  disposition for the GitHub CLI token and Kubernetes `kubeconfig`, which 02.3 explicitly deferred to
  Milestone 03, was unowned — now a 03.2 criterion; **(Major)** 03.2 claimed a credential could be
  refused when "presented by" another agent, which D4 makes impossible to observe — narrowed to
  issuance and refresh with the residual recorded; **(Minor)** R8.6's transcript credential-value
  check ran in 02.1 before AWS existed and was not re-run against the AWS command paths — now a 03.5
  criterion.
- **A 03.4 or 03.5 failure is a design finding, not a bug inside this milestone** — the posture
  Milestone 02 recorded for 02.2. A T13 failure is a finding against the estate design in 03.1; a
  T38 failure against an AWS-loading profile is a finding against the pack's egress scope in 03.3.
- **No `prd.md` gap surfaced during this definition.** The § Configuration optional-pack table already
  carries the AWS CLI pack row, the § Milestones section already records the three-milestone plan and
  the Gate 1 mapping, and `docs/ARCHITECTURE_AND_DESIGN.md` already lists the AWS credential broker in
  its component inventory and `aws-cli/pack.yaml` in its file tree. Nothing was added to either.
