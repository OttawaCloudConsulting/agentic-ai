# Milestone 03: AWS Access

> **Authority.** [`REQUIREMENTS.md`](../../REQUIREMENTS.md) is the authoritative register (R1–R15,
> SC-1…SC-8, T1–T45). [`docs/ARCHITECTURE_AND_DESIGN.md`](../../docs/ARCHITECTURE_AND_DESIGN.md) is
> the ratified design (D1–D21). This document cites both by ID and restates neither. Where they
> disagree with anything here, they win.
>
> **Gate-1 label.** The architecture document was written against the two-milestone Gate 1 shape and
> places the AWS pack, Q1 and Q9 "inside M1". Gate 3 carved them out into this milestone — see
> [`prd.md` § Milestones](../../prd.md). D13 and D13a's "sits inside M1" notes read as this milestone.

## Goal

The operator can run a session that needs AWS. An agent inside the pod holds short-lived credentials
for **one** dedicated agent role and nothing else, and `aws sts get-caller-identity` from inside the
container returns that role rather than an operator role (SC-5). The entitlement scope is proven
empirically from inside the container, not read off a config file (R6.5.6).

The credential path is **Model B** (D13): the mediator performs the SSO login outside the agent
blast radius and hands each agent time-boxed STS credentials bound to its own workload identity; no
SSO token and no refresh token exist inside any agent container (R6.5.4).

**This milestone is hard-gated on Q9.** If a dedicated Identity Center principal cannot be created,
there is no compliant credential model — Model C is prohibited (R6.5.1) and Model A carries the same
dependency (R6.5.2). D13a records that as a gate on the pack, not a risk to manage during it. See
Dependencies and the Definition of Done for the fail-closed outcome.

## Features

### Feature 03.1: AWS estate provisioning, entitlement design and third-party record

The estate-side half, and the only feature whose long pole sits in someone else's organisation. It
assumes Q9 is already answered positively — that is a start-gate on the milestone, not an outcome of
this feature.

**Acceptance Criteria:**

- A **dedicated Identity Center principal and agent permission set** exist for agent use, assigned
  only to that principal (R6.3.2, R6.5.2). No operator permission set is reachable from it.
- The permission set is **read-only by default**; write or mutate permissions are granted per
  use-case profile, explicitly and narrowly, and each grant is recorded with what it permits
  (R6.3.3).
- **Session duration is bounded and short**, with expiry accepted as an operational cost rather than
  engineered around (R6.3.5). The bound is stated as a number, not as "short".
- A **data perimeter** denies the agent principal access to resources outside the organisation —
  SCPs or role policies conditioned on `aws:ResourceOrgID` / `aws:PrincipalOrgID` (R6.3.6). This is
  the control T13 rests on; see the Q1 dependency below.
- A **permission boundary** prevents the agent principal from creating or escalating to other
  principals (R6.3.7), and **destructive actions** — delete, terminate, policy modification — are
  denied even under a profile that grants write (R6.3.9).
- **CloudTrail attribution is designed and its granularity recorded** (R6.3.8). Under Model B the
  broker holds one principal, so per-agent session naming is not automatic: either the broker
  role-chains with `RoleSessionName` carrying the R8.8 workload identity from 01.3, or attribution
  is recorded as **per-broker granularity only**. Whichever holds is recorded as a finding, not
  assumed — see the Ordering tradeoff.
- **Q1 is answered and its consequence recorded**: which accounts and services the agent must reach,
  and therefore whether R6.4.3's bucket-specific FQDN allowlisting is practical. If Q1 returns a
  broad S3 surface, R6.4.3 is recorded as impractical and **T13 rests entirely on R6.3.6** — a
  SHOULD, enforced in an estate this project does not own. That dependency is stated, not hidden.
- **AWS is recorded under R14.1 before any agent traffic reaches it**: what it observes, its stated
  retention period, and its breach-notification path. R14.1 is a MUST and applies per third party;
  01.1 recorded Docker Sandboxes and the three model providers, 02.3 recorded HashiCorp, GitHub and
  the Kubernetes endpoints. **AWS is covered by none of them.**
- **CloudTrail read access is available to the operator** for the agent principal's events — T12's
  pass condition is "AccessDenied, recorded in CloudTrail", which cannot be verified without it.
- **No long-lived IAM access key exists anywhere** in the image, environment, or any mounted volume
  (R6.2.2), and none is created as part of this provisioning.

### Feature 03.2: Credential broker — the mediator's fifth role

01.3 built four of the mediator's five roles and named this one as Milestone 03. It is the feature
D6 hard-gates: brokering without caller identity hands every agent every brokered credential.

**Acceptance Criteria:**

- **R8.8 is verified present and working before this feature starts.** 01.3 issues each agent a
  distinct mTLS workload identity and T34 confirms cross-binding is refused at the mediator. The
  broker binds every credential it mints to that identity (D6, R6.5.5).
- The broker mints credentials for **exactly one role** — the agent permission set from 03.1 — and
  **refuses any request naming another role** (R6.5.5), so the container cannot pivot by asking.
- **The binding is enforced at issuance and refresh, not at use, and the residual is recorded.** The
  mediator refuses to mint or refresh a credential for agent A when the request arrives under agent
  B's R8.8 identity. It cannot detect agent B *using* an already-issued STS credential belonging to
  agent A: under Model B the container signs SigV4 locally and D4 splices rather than terminates, so
  the mediator sees a destination and a byte count, never a credential. **Per-agent network isolation
  (D2) is what makes the theft path narrow, not the broker.** Recorded as a residual, alongside D4's
  existing no-content-DLP entry.
- **The broker's own upstream credential lives on the mediator and is enumerated.** Model B
  relocates the SSO relationship out of the agent blast radius and into the mediator: the mediator
  holds the dedicated principal's SSO token and refresh token, and the agents hold only STS
  credentials expiring in ≤1 hour. Consequences, each of which is an acceptance criterion in its own
  right:
  - **R6.2.3 and R6.2.4 relocate to the mediator.** The headless login (`--no-browser` or
    `--use-device-code`) is performed for the *mediator's* identity, with the verification URL and
    code completed in a browser on the host, and `sso_registration_scopes = sso:account:access` set
    so refresh tokens are issued. This is the AWS half of R12.6's onboarding documentation.
  - **R6.2.5's caches live on mediator storage**, never on a volume any agent container can reach.
    R6.2.5 as written scopes itself to Model A; under Model B its subject is the mediator.
  - **`oidc.<region>.amazonaws.com`, `portal.sso.<region>.amazonaws.com` and the Identity Center
    start URL host are the mediator's own egress**, not entries in any agent's allowlist (R6.4.4,
    R6.4.6). They are logged as mediator-originated traffic and are distinguishable from agent
    traffic in the audit sink.
  - **The mediator's SSO token is a new long-lived credential** and is enumerated under R8.4 with
    its blast radius stated — exactly the agent permission set, by construction, since the principal
    is entitled to nothing else. Its cache is excluded from version control and from any backup
    leaving the trust boundary (R8.7). It joins the T26 inventory and carries a documented, executed
    revocation procedure (see 03.5).
- **No SSO token, refresh token or token cache is present in any agent container** (R6.5.4). Verified
  by inspection from inside each container, which is also T19's Model B pass condition.
- **R8.3's goal is met and its stated mechanism is recorded as not applicable.** R8.3 describes
  credentials "injected into upstream requests" at the enforcement point, citing
  `codex-responses-api-proxy`. That pattern requires reading and rewriting the request, which
  requires TLS termination — **D4 forbids termination for all three agents**, and AWS requests are
  SigV4-signed by the client in any case. Delivery is therefore `credential_process` or refreshed
  environment credentials (R6.5.3), with signing inside the container. R8.3 is a SHOULD; the record
  states that the no-long-lived-token-in-container goal is met while the injection mechanism is
  structurally unavailable under D4.
- **The GitHub CLI token and the Kubernetes `kubeconfig` receive an explicit R8.3 disposition.**
  02.3 ships both secret-injected or volume-resident and states that upstream brokering "is the
  mediator's fifth role and sits in **Milestone 03**" — this feature is where that lands. For each of
  the two, either brokering is implemented on the same identity-bound path as AWS, or it is recorded
  as **not applicable with its reason** and the credential stays enumerated under R8.4 with its blast
  radius and its R7.12 independent revocation. The likely finding is that neither brokers cleanly
  under D4 for the same reason AWS does not — GitHub tokens ride in an `Authorization` header the
  mediator cannot see without terminating TLS, and `kubeconfig` carries client certificates or
  tokens presented in the TLS handshake itself. R8.3 is a SHOULD; leaving the disposition unstated
  is what this criterion prevents.
- **The broker adds no port to any agent network.** 01.3 established that the mediator exposes
  exactly one port per agent network — the proxy listener — with no management or metrics port. The
  `credential_process` path reaches the broker through that existing listener. A second port is a
  design change requiring review, not an implementation convenience.
- Broker secrets are injected at runtime from a secret manager, never baked into an image layer and
  never on an agent-reachable volume (R8.1) — the same posture 01.3 applied to the CA private key.
- Every mint, refusal and refresh is written to the audit sink with the requesting agent's R8.8
  identity, correlatable with the egress log by session identifier and timestamp (R9.1, R9.8).

### Feature 03.3: AWS CLI tool pack, synthetic config and scoped egress

The pack itself, composed through the 01.5 policy compiler and the 02.3 profile mechanism. This is
where SC-6 is exercised for the pack with the largest blast-radius contribution in the set.

**Acceptance Criteria:**

- **AWS CLI v2 ships as a tool pack**, not baked into the base image, version-pinned and verified by
  checksum at build time (R6.1.1, R6.1.2). The pack is optional and its egress entries are absent
  when it is not loaded (R6.1.3) — **T14-style composition**, verified by loading and unloading it:
  the resolved egress policy gains and loses exactly the pack's entries with no residue (R7.5).
- The pack declares the full R7.3 field set — pinned packages with checksums, egress FQDNs and
  CIDRs, mounts and modes, environment variables, credentials, write-access need — and states its
  **blast-radius contribution as R6.3** (R7.11), the largest of any pack in the set.
- **The AWS config presented to the container is synthetic and version-controlled**, containing only
  the agent's single `[profile]`. The operator's `~/.aws/config` is never its source and is never
  mounted (R6.2.6); the operator's `~/.aws` directory is never mounted into any agent container
  (R6.3.1). Under Model B there is no `[sso-session]` block in the container's config, because the
  container performs no SSO login — R6.2.6's literal text names both blocks, which is Model-A-shaped
  wording recorded alongside R6.2.5 and R6.3.2, not a gap.
- The synthetic config is **mounted read-only**, with any writable cache on a separate volume, so the
  agent cannot add profiles for other accounts or roles (R6.2.7). **Exactly one AWS profile** is
  available inside the container (R6.3.4).
- **Path-style S3 addressing is defeated by the allowlist shape, not by the config file.**
  `s3.addressing_style = virtual` is set in the synthetic config so well-behaved clients use
  virtual-hosted addressing — but the agent owns its own command line (`--endpoint-url`, a copied
  config on tmpfs), and R6.3.2a is the standing reminder that a config file is not a privilege
  boundary. **The control is that the resolved policy contains no bare regional S3 endpoint
  (`s3.<region>.amazonaws.com`) and no `*.s3.<region>.amazonaws.com` wildcard**, so a path-style
  request has no allowlisted host to reach. Asserted against the resolved policy, the same way the
  `*.amazonaws.com` prohibition is.
- **Egress entries are scoped to the required region and services** determined by Q1 (R6.4.1).
  **`*.amazonaws.com` is prohibited** and its absence is verified against the resolved policy, not
  only against the pack manifest (R6.4.2).
- **`sts.<region>.amazonaws.com` remains in the agent allowlist.** R6.4.6 removes `oidc.*` and
  `portal.sso.*` under Model B; it does not remove STS, which T10's `aws sts get-caller-identity`
  requires from inside the container. The resolved policy is checked for exactly this shape:
  STS present, SSO auth endpoints absent.
- **S3 is allowlisted by bucket-specific FQDN** where Q1's answer makes it practical (R6.4.3); where
  it does not, the resolved policy records the wider entry, names what it re-opens, and the
  compensating reliance on R6.3.6 is stated in the profile.
- The AWS CLI is **routed through the enforcement point like every other client**, honouring
  `HTTP_PROXY` / `HTTPS_PROXY` (R6.4.5). `AWS_CA_BUNDLE` is not used, because D4 splices rather than
  terminates and no mediator CA is presented to any agent.
- **The AWS credential is scoped to the single use-case profile that needs it** (R8.2, MUST). Under a
  profile that does not load the AWS pack, no AWS credential and no broker path are reachable from
  any agent container — verified by inspection from inside, not by declaration.
- The pack requires no capability, privilege or host access beyond the base container (R7.8).

### Feature 03.4: SC-5 empirical validation — identity, entitlement scope and least privilege

The measurement SC-5 names, run from inside the container. R6.5.6 makes the empirical form
mandatory: entitlement scope is verified by observation, never inferred from config file contents.

**Acceptance Criteria:**

- **T10 — AWS identity:** `aws sts get-caller-identity` from inside each agent container returns the
  dedicated agent role, not an operator role. This is SC-5's stated measurement.
- **T19 — token entitlement scope, Model B form:** `aws sso list-accounts` from inside the container
  **fails, because no SSO token exists there**. The register states this as Model B's pass condition.
  R6.3.2a is the reason the test exists at all: possession of an Identity Center access token
  permits `sso list-accounts` and `sso get-role-credentials` for everything the underlying identity
  is entitled to, and consults no config file — so absence of the token, not trimming of the config,
  is the boundary being verified.
- **T20 — role pivot:** an attempt to obtain credentials for a role other than the agent role is
  refused by the broker (R6.5.5). Tested from inside the container against the broker, and separately
  by presenting agent A's identity for a credential bound to agent B.
- **T12 — least privilege:** a denied AWS action returns `AccessDenied` and the event is **located in
  CloudTrail**, at the attribution granularity 03.1 recorded.
- **T13 — cross-account write:** `PutObject` to an out-of-organisation bucket is denied by the data
  perimeter or by the egress policy. **Which of the two denied it is recorded**, because they are not
  equivalent: the egress policy is inside this project's control and the data perimeter (R6.3.6) is a
  SHOULD in the operator's estate. If only the perimeter denied it, that is recorded as the single
  point of failure it is.
- **T11 is structurally unreachable under Model B and is recorded as a proposed register amendment.**
  T11 requires `aws sso login --no-browser` to complete inside the container with the token cached on
  a persistent volume. Under Model B the container performs no SSO login (R6.5.4), the auth endpoints
  are not in its allowlist (R6.4.6), and caching a token there is precisely what the model exists to
  prevent. The proposed amendment **relocates T11's subject to the mediator** — the headless login and
  refresh-token issuance verified in 03.2. `/milestone` has no authority to edit `REQUIREMENTS.md`, so
  this is recorded for the operator, in the same posture Milestone 02 took with R13.2/T40.
- **R6.3.2 is satisfied in substance and its wording noted.** R6.3.2 says the agent "authenticates as
  a dedicated permission set"; under Model B the agent authenticates to the mediator with its mTLS
  identity and never authenticates to AWS at all. The dedicated permission set is what its
  credentials resolve to. Recorded as a wording observation against the register, not as a gap.
- **SC-5 is demonstrated against the measurement `prd.md` § Goals states**, and the result is recorded
  per agent, not once for the pod.

### Feature 03.5: Boundary re-validation, revocation and AWS go-live

The AWS pack adds both egress entries and credential material to a boundary that Milestone 02
validated without them. This feature re-establishes that the boundary still holds, then lifts the
last R12.8 notice.

**Acceptance Criteria:**

- **`validate-boundary.sh` re-runs against every AWS-loading profile** and all six R12.8 scenarios
  execute, each recording whether the attempt was blocked, logged and attributable — **T38**. This
  is the reason `prd.md` places a re-run in this milestone rather than treating 02.2 as final.
- **T3–T8 re-run against the AWS profile.** The exfiltration, CDN-rotation, metadata-endpoint and
  policy-tampering results from 02.2 were obtained against a policy without AWS entries; the AWS pack
  adds allowlisted destinations that a compromised agent can attempt to reach with valid credentials.
- **T42 is extended to AWS** and the R14.1 record from 03.1 is confirmed present **before** the first
  agent request reaches an AWS endpoint. R14.1 is a MUST and is stated as a precondition on traffic,
  not a deliverable to be completed alongside it.
- **T26 is extended to the two new credentials** and both revocations are **executed and timed**
  against the stated maximum detection-to-revocation time (R13.1, R8.5): the mediator's SSO refresh
  token, and the STS credentials issued to agents.
- **An issued STS credential has a real revocation procedure, or R8.5 is recorded as unmet.** R8.5 is
  a MUST and T26's pass condition is that revocation *succeeds* within a stated maximum — waiting for
  expiry is not revocation, and stopping further mints at the broker does nothing to a credential
  already in an agent's hands. The procedure must **invalidate the active session**: the standard
  mechanism is a deny policy on the agent role conditioned on `aws:TokenIssueTime`, which cuts every
  session issued before a timestamp. It is executed against a live agent session and timed, and the
  agent's next AWS call is confirmed to fail. **If no such procedure can be made to work, R8.5 is
  recorded as a named gap and that gap blocks lifting the R12.8 notice** — the posture 02.5 took with
  R13.2, and the reason the Definition of Done gates on it rather than noting it.
- **Rotation and revocation complete without rebuilding the environment** (R8.5, MUST). Where one
  cannot, the rebuild requirement is recorded as a named gap against R8.5 rather than folded into the
  timing — the posture 02.5 took.
- **R8.6's transcript check is re-run against the AWS command paths.** 02.1 confirmed agent session
  transcripts capture no credential values from command output, but ran before any AWS credential
  existed. AWS CLI output and the `credential_process` path are checked for STS access keys, session
  tokens and any SSO material reaching a transcript, and any leak found is recorded with its
  mitigation (R8.6).
- **The containment runbook gains its AWS entries**: cut the broker (no further mints), revoke the
  mediator's SSO session, and what each means for a session in flight. This extends the four
  containment actions the 02.5 runbook shipped with.
- **R12.6's AWS half is documented**: first-run authentication for the mediator's SSO identity, the
  headless device-code flow completed on the host, and what an operator does when the mediator's
  refresh token expires. Milestone 02 documented the three agents; this completes R12.6.
- **The R12.8 "not for real work" notice is lifted for AWS-loading profiles**, once the above pass.
  Milestone 02 lifted it for non-AWS profiles only.
- **Two records are carried to the operator, not applied by `/milestone`**: the T11 relocation
  amendment against `REQUIREMENTS.md` (from 03.4), and — if 03.1 found per-agent CloudTrail session
  naming unreachable — the attribution-granularity finding against R6.3.8.

## Dependencies

- **Q9 answered positively.** This is a **start-gate, not a feature outcome**. If a dedicated Identity
  Center principal cannot be created, D13a records that no compliant credential model remains: Model C
  is prohibited (R6.5.1) and **Model A is not a fallback** — R6.5.2 requires the same dedicated
  principal. The milestone does not start. See the Definition of Done for the fail-closed outcome.
- **Q1 answered.** Feeds 03.1 (whether R6.4.3 is practical, and therefore how much weight T13 puts on
  R6.3.6) and 03.3 (the actual egress entries). A milestone started with Q1 open builds a pack whose
  scope is a guess.
- **Assumption A5 holds** — the AWS estate is under the operator's organisation and can be modified to
  add an agent permission set. A5 and Q9 are the same dependency seen from two sides.
- **All of Milestone 01, and specifically R8.8/T34 from 01.3.** D6 makes per-agent workload identity a
  hard precondition for brokering, and 03.2 does not start until T34 has passed.
- **All of Milestone 02.** 03.3 composes through the 01.5 policy compiler as extended by 02.3's
  profile mechanism; 03.5 re-runs the `validate-boundary.sh` suite 02.2 built and extends the 02.5
  runbook and the 02.1 audit sink. Starting before 02 completes means re-running the matrix twice.
- **CloudTrail read access** for the agent principal's events, without which T12 cannot be verified.
- **External:** the operator's organisation for Q1, Q9, the permission set, the data perimeter and the
  permission boundary. This is the milestone's long pole and none of it is under this project's
  control — which is why `prd.md` directs that Q1 and Q9 be raised during Milestone 01. If they were
  not, 03.1 absorbs the full lead time.

## Ordering

Third and last. Two reasons, both recorded at Gate 3 and both about dependency direction rather than
importance.

**Q9 is an external dependency with unknown lead time.** A gated milestone in second position blocks
the third; in third position it blocks only itself, and Milestones 01 and 02 deliver a usable,
proven sandbox for every non-AWS session regardless of how Q9 resolves.

**Brokering is hard-gated on per-agent workload identity** (R8.8, D6, D13) in a way the hardening
milestone is not. R8.8 lands in 01.3 either way — `prd.md`'s "degrades gracefully" phrasing is the
argument for *this* ordering, not a claim that Milestone 02 forgoes attribution.

Internally the order is 03.1 → 03.2 → 03.3 → 03.4 → 03.5:

- **03.1 first, and started early.** It is the only feature whose completion this project cannot
  drive. Its outputs — the permission set, the entitlement design, Q1's answer — are inputs to
  everything after it.
- **03.2 before 03.3.** The pack's egress shape is a consequence of the credential model: R6.4.6
  removes the SSO auth endpoints from the agent allowlist *because* the broker performs the login.
  Building the pack first means building it against endpoints the model then removes.
- **03.4 after both.** SC-5's measurement is empirical and needs a running broker and a loaded pack.
- **03.5 last.** Re-validation must cover the final shape, and the R12.8 notice cannot lift before it.

**Tradeoff — attribution granularity (03.1).** Model B puts one broker principal in front of three
agents, so CloudTrail may record the broker rather than the agent. Three options: role-chain with
`RoleSessionName` carrying the R8.8 identity (preserves per-agent attribution, needs a role that
trusts the SSO principal); create three Identity Center principals (clean, but triples the Q9 ask
that is already the milestone's gate); or accept per-broker granularity and record R6.3.8 — a SHOULD
— as partially met. **Chosen: attempt role-chaining, record the outcome either way.** Reasonable
people disagree here, which is why 03.1 makes it a recorded finding rather than an assumption.

**Tradeoff — build against a throwaway account while Q9 pends.** The broker and pack could be built
against a personal or sandbox AWS account before Q9 resolves, converting external wait into parallel
work. Against it: the entitlement design *is* the security content of this milestone, and a broker
built against an unbounded throwaway account exercises the mechanism without exercising the boundary
— then needs re-validating anyway. **Chosen: do not start 03.2 before 03.1.** If schedule pressure
forces it, the throwaway account carries no real data and 03.4 and 03.5 re-run in full against the
real principal.

**Tradeoff — `credential_process` versus refreshed environment credentials.** `credential_process`
fetches on demand, so a credential exists in the process only while in use and expiry is handled
transparently; it runs an executable inside the agent container that must reach the broker through
the single proxy listener. Environment injection is simpler and needs no in-container helper, but
leaves credentials in the environment of every process for their full lifetime and needs a refresh
mechanism that notices expiry. **Chosen: `credential_process`**, with environment injection recorded
as the fallback if the one-port constraint cannot be met without a design change.

## Sizing

Five features, the DD-1 ceiling — the same shape as 01 and 02, and again because the milestone is
indivisible: SC-5 is one claim and the R12.8 notice for AWS profiles cannot lift on a partial one.

- **03.2 is the largest build item.** It is a new mediator role with its own credential lifecycle,
  identity binding, refusal semantics and audit surface, plus the relocated SSO login. The planned
  split at `/plan` time is along the seam between **minting and binding** (broker core, one role,
  cross-binding refusal) and **the upstream relationship** (mediator-side SSO login, refresh, cache
  location, revocation). **Named fallback if it runs long:** the upstream half moves to its own
  feature via `/milestone` revision mode. Deferring it silently inside 03.2 is not the fallback.
- **03.1 is small in build terms and long in elapsed time.** Almost none of it is this project's work
  to do; its risk is schedule, not complexity, and it is why the milestone sits third.
- **03.3 is a well-understood shape.** 02.3 shipped three packs through the same mechanism; this one
  differs by carrying a credential and by the config-file constraints of R6.2.6 / R6.2.7 / R6.3.4.
- **03.4 is testing-shaped**: six named tests, one of which (T11) resolves to a recorded amendment
  rather than a pass. Its risk is outcome, not size — a T13 failure is a finding against the estate
  design in 03.1, not a bug to fix inside 03.4.
- **03.5 is regression plus documentation.** Its long pole is the timed revocation drill, which is an
  executed procedure rather than code.

## Configuration

| Parameter | Value at this milestone |
|---|---|
| AWS CLI pack | Ships here. Optional, off by default; absent from the resolved policy when not loaded (R6.1.3) |
| Credential model | **Model B** — brokered short-lived STS, ≤1 hour, one role (D13, R6.5.3) |
| AWS profile in container | Exactly one, from the synthetic read-only config. No `[sso-session]` block (R6.2.6, R6.2.7, R6.3.4) |
| `s3.addressing_style` | `virtual` in the synthetic config. The control is the allowlist shape: no bare `s3.<region>` endpoint and no `*.s3.<region>` wildcard in the resolved policy |
| Agent allowlist additions | Region- and service-scoped per Q1, plus `sts.<region>.amazonaws.com`. `*.amazonaws.com` prohibited (R6.4.1, R6.4.2) |
| Agent allowlist exclusions | `oidc.*` and `portal.sso.*` — mediator-side only under Model B (R6.4.6) |
| Mediator-side egress | `oidc.<region>`, `portal.sso.<region>`, Identity Center start URL host (R6.4.4) |
| Agent permission set | Read-only default; write granted per profile, explicitly and narrowly (R6.3.3) |
| Session duration | Bounded and short, stated as a number in 03.1 (R6.3.5) |

## Definition of Done

- [ ] All features complete (`[x]` in `milestone-status.txt`)
- [ ] All acceptance criteria verified
- [ ] `gate-3-review.md` checklist fully resolved
- [ ] `milestone-status.txt` updated with final counts
- [ ] `progress.txt` milestone summary shows 5/5 features complete
- [ ] **SC-5 demonstrated per agent**: `aws sts get-caller-identity` returns the dedicated agent role
      (T10), entitlement scope verified empirically from inside the container (T19, R6.5.6), role
      pivot refused (T20), least privilege confirmed in CloudTrail (T12), cross-account write denied
      with the denying control named (T13)
- [ ] **No SSO token, refresh token or long-lived IAM key exists in any agent container** (R6.2.2,
      R6.5.4), verified by inspection rather than by declaration
- [ ] **The mediator's SSO credential is enumerated under R8.4** with its blast radius stated, and its
      revocation is executed and timed within the stated maximum (T26 extension, R13.1, R8.5)
- [ ] **An issued STS credential is actually revoked — not merely allowed to expire — and timed**
      (R8.5 MUST, T26). Stopping further mints at the broker does not revoke a credential already
      issued. **If no working procedure exists, R8.5 is recorded as a named gap and the R12.8 notice
      does not lift**
- [ ] **The GitHub CLI token and Kubernetes `kubeconfig` carry an explicit R8.3 disposition** —
      brokered on the identity-bound path, or recorded N/A with reason. 02.3 deferred both here
- [ ] **`*.amazonaws.com` is absent from the resolved policy**, not merely from the pack manifest
      (R6.4.2), and the resolved policy shows STS present with the SSO auth endpoints absent
- [ ] **The R14.1 record for AWS existed before the first agent request reached an AWS endpoint**, and
      T42 covers it (R14.1 is a MUST per third party)
- [ ] **T38 and T3–T8 re-run against every AWS-loading profile** and recorded — the boundary was
      validated in 02.2 without AWS entries or AWS credentials on it
- [ ] **Two records are put to the operator, not applied**: the **T11 relocation amendment** against
      `REQUIREMENTS.md` (Model B makes in-container SSO login structurally unreachable), and the
      **R6.3.8 attribution-granularity finding** if per-agent CloudTrail session naming proved
      unreachable. `/milestone` may edit neither document
- [ ] **The R12.8 notice is lifted for AWS-loading profiles.** Milestone 02 lifted it for non-AWS
      profiles; this completes it
- [ ] **Fail-closed outcome, if Q9 is answered negatively.** The milestone does not start. The AWS CLI
      pack does not ship, **SC-5 is recorded as permanently unmet** with D13a as the reason, and
      `prd.md` § Goals is annotated accordingly. **Model A is not a substitution** — R6.5.2 requires
      the same dedicated principal — and mounting the operator's `~/.aws` is prohibited outright
      (R6.3.1). This is a recorded project outcome, not a milestone to work around
