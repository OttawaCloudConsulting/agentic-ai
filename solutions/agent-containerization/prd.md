# PRD: Sandboxed Agent Containerization

> **This document is the front door, not the register.** [`REQUIREMENTS.md`](REQUIREMENTS.md)
> is the authoritative requirement register — 157 numbered requirements across R1–R15, with
> success criteria SC-1…SC-8 and acceptance tests T1–T45 (T21–T45 appended at Gate 2). This
> PRD cites those IDs by reference and never restates them. When the two disagree,
> `REQUIREMENTS.md` wins.
>
> Supporting analysis lives in [`docs/OPTIONS_ANALYSIS.md`](docs/OPTIONS_ANALYSIS.md),
> [`docs/RESEARCH_FINDINGS.md`](docs/RESEARCH_FINDINGS.md),
> [`docs/STANDARDS_MAPPING.md`](docs/STANDARDS_MAPPING.md), and the red-team pass in
> [`docs/red-team/options-analysis-01/`](docs/red-team/options-analysis-01/).

## Summary

Provide a reusable, sandboxed container environment in which Claude Code, OpenAI Codex and
Google Antigravity can run — including with permission prompts bypassed — such that a
compromised or prompt-injected agent cannot reach data, systems or networks outside an
explicitly declared boundary.

The environment must be adaptable per use case through composable tool packs (AWS CLI,
Terraform, Kubernetes, language runtimes) without widening the security boundary implicitly.

Research is complete. **Gate 2 ratified Option 2** — the Compose pod with an egress mediator
recommended by `docs/OPTIONS_ANALYSIS.md` — as decision **D1**, one of 22 decisions (D1–D21, plus
D13a) recorded in the architecture document at
[`.project/sandboxed-agent-containerization/docs/`](.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md).

Of the options analysis's four Open Decisions, three were settled at Gate 1 (TLS posture → R5.15,
Antigravity route → R14.3, host-credential mount → R4.17). Open Decision 3, the Docker Sandboxes
provider assessment, is **incomplete and constrained** rather than closed (01.1 SF-1): Docker's
documentation neither confirms nor denies that the `sbx` proxy decrypts traffic, and publishes no
retention, deletion or breach-notification terms. It is governed by R14.1.

### Settled at Gate 1

| Item | Decision |
|---|---|
| Deployment scope (Q2) | **One workstation.** Assumption A1 holds. R10 (supply chain) and R11.2 (portability) stay SHOULD rather than rising to MUST |
| Repository trust (Q3) | **Trusted-ish repositories only.** Assumption A3 holds. Option 2 remains viable; Option 3 is not forced |
| `STANDARDS_MAPPING.md` G1–G9 | **Merged into the register.** Sixteen requirements added: R4.16, R7.14–R7.17, R8.8, R9.7–R9.8, R12.7–R12.8, R13.1–R13.3, R14.1–R14.2, R15.2, plus R15.1 recorded as a Non-Goal |
| Authentication scope | **Both API-key and OAuth**, per agent, selected by `AUTH_MODE` (R4.12). As built this is a seven-cell matrix rather than a two-way choice: three agent/mode combinations are unsupported and fail closed, as does an unset `AUTH_MODE`. See `docs/OPTIONS_ANALYSIS.md` § Authentication modes and the Configuration section below |

## Goals

Promoted verbatim from `REQUIREMENTS.md` § Success Criteria. These are outcomes, not
implementation choices, and each carries a stated measurement.

| ID | Goal | How measured |
|---|---|---|
| SC-1 | A fully compromised agent cannot read any host file outside the declared mounts | Red-team: attempt host filesystem traversal from inside the container |
| SC-2 | A fully compromised agent cannot reach any network destination outside the declared egress policy — including via DNS | Red-team: attempt exfiltration over HTTP, HTTPS, raw TCP, DNS and ICMP to a controlled collector |
| SC-3 | A fully compromised agent cannot modify the egress policy, the mount set, or the enforcement point | Red-team: attempt policy tampering from inside the container |
| SC-4 | All three agents run non-interactively, authenticated, with state surviving container restart | Restart the container; confirm each agent is still signed in and retains session history |
| SC-5 | AWS access is present, SSO-authenticated, and least-privilege | `aws sts get-caller-identity` returns the dedicated agent role, not an operator role |
| SC-6 | A use case can add or remove tooling without hand-editing the security policy | Switch use-case profile; confirm egress policy recomposes automatically |
| SC-7 | Every destination an agent attempted — allowed or blocked — is recorded | Inspect the audit log after a session; confirm blocked attempts appear |
| SC-8 | The environment rebuilds reproducibly from version control with no manual steps | Clean-machine rebuild produces a functionally identical environment |

## Non-Goals

Promoted from `REQUIREMENTS.md` § Non-Goals. Listed so they are not silently assumed.

| Item | Rationale |
|------|-----------|
| Containerizing the Antigravity desktop GUI | Requires forfeiting the container sandbox; the `agy` CLI supersedes the need |
| Defending against a malicious operator | The threat model is a compromised agent, not an insider with host access |
| Defending against a compromised model provider | Outside the control of this environment |
| Preventing exfiltration through legitimately allowlisted destinations | Structurally impossible. An agent allowed to reach GitHub can push to GitHub. Mitigated by narrowing the allowlist and by audit, not eliminated |
| Multi-tenancy or hosting the sandbox as a shared service | Single-operator scope; revisit if this changes, since it raises the isolation requirement |
| Replacing code review of agent output | The sandbox bounds damage; it does not certify correctness |
| Ingress filtering — inspecting content entering the agent's context | Recorded as a Non-Goal in `docs/OPTIONS_ANALYSIS.md`. No option mitigates prompt injection itself; all three bound the harm. Tracked as `STANDARDS_MAPPING.md` G9 / R15.1 |

## External Dependencies

| Dependency | Owner | Status |
|------------|-------|--------|
| Model provider APIs reachable (Anthropic, OpenAI, Google) | Providers | Available — assumption A4; a fully air-gapped sandbox is not the goal |
| AWS estate modifiable to add an agent permission set | Operator's organisation | Pending — assumption A5 (Q9). **Gate 2 corrected the Gate 1 record (D13a):** a negative answer leaves no compliant AWS credential model at all — Model C is prohibited, Model B needs a principal to broker from, Model A needs a dedicated Identity Center user or group — and so gates the entire AWS CLI pack, not only R6.3 or Model B brokering |
| Docker Sandboxes (`sbx`) provider terms for intercepted traffic | Docker | **Incomplete, constrained** (01.1 SF-1) — Open Decision 3, governed by R14.1. Option 1 was rejected at Gate 2, so this no longer constrains an architecture choice; `sbx` is retained only as the egress-discovery seeding tool (D17) |
| Antigravity Terms of Service Section 6 boundary | Google | **Unresolved** — Google staff declined to clarify; Open Decision 2. The R14.3 interpretation owner is now named (Ottawa Cloud Consulting), closing the ownership gap; the interpretation itself remains explicitly unofficial |

## Milestones

Scoping intent settled at Gate 1. The milestone plan below was approved during **Gate 3 milestone
planning (2026-09-04)** after an adversarial review. `/milestone` produces the per-milestone
feature breakdown in
`.project/sandboxed-agent-containerization/milestones/<NN>-<name>/README.md` — this section
records the plan, not the breakdown.

**Three milestones.**

1. **Sandboxed pod** — `.project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/`.
   All three agents run authenticated inside the
   pod with state surviving restart (SC-4), behind a seeded default-deny egress policy, on a
   hardened runtime with the mediator as the only path out. The sandbox works; it is not yet
   proven, and R12.8 bars real work until Milestone 02. **Revised 2026-09-04:** R8.8's per-agent
   workload identity is delivered in the strongest form each agent's HTTP client actually supports
   (mTLS for Claude Code; a proxy credential or network-derived identity for Codex and Antigravity,
   whose clients cannot present a certificate), and D6's precondition is enforced by restricting
   Milestone 03's credential brokering to cryptographically bound identities only. That identity work
   is now its own feature (01.6), taking the milestone to **six features — one over DD-1's ceiling,
   recorded as a deliberate deviation** in the milestone README's Sizing section.
2. **Proven and composable** —
   `.project/sandboxed-agent-containerization/milestones/02-proven-and-composable/`.
   Adversarial validation passes
   (SC-1, SC-2, SC-3), the remaining tool packs compose without hand-editing policy (SC-6), and
   audit and reproducibility land (SC-7, SC-8). **Unlocks real work without AWS** — SC-5 is not in
   scope here, so a session that needs AWS still waits for Milestone 03.
3. **AWS access** — `.project/sandboxed-agent-containerization/milestones/03-aws-access/`.
   Brokered short-lived credentials (Model B) against a
   dedicated least-privilege role, with entitlement scope verified empirically from inside the
   container (SC-5). Gated on Q9; re-runs the adversarial matrix on completion, because the pack
   adds both egress entries and credential material to a boundary already validated without them.

**Mapping to the Gate 1 shape.** Gate 1 recorded two milestones: M1 "working sandbox" *including*
the AWS CLI pack, and M2 "hardening". Gate 3 split and resequenced them:

| Gate 1 | Gate 3 |
|---|---|
| M1 — working sandbox, AWS pack included | **Milestone 01** (pod, auth, egress) + **Milestone 03** (AWS) |
| M2 — hardening | **Milestone 02** |

Two departures from the Gate 1 sequencing, both deliberate. **The AWS pack is carved out** of the
first milestone, which is the scoping decision D13a explicitly deferred to Gate 3: a negative Q9
leaves no compliant AWS credential model, and carving the pack out means that gates one milestone
rather than the whole sandbox. **Hardening now precedes AWS**, because Q9 is an external dependency
on the operator's organisation with unknown lead time — a gated milestone in second position would
block the third — and because the AWS milestone depends on per-agent workload identity (R8.8, D6)
while the hardening milestone degrades gracefully without it (R9.8 records what happened, not who).

`.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md`
was written against the two-milestone shape and says "sits inside
M1" or "until M2 completes" in several places. Those are Gate-1 labels; read them through the table
above, not as references to the numbered milestones.

Three consequences worth stating now, because they shape the breakdown:

- **Milestone 01 is still the large one.** Six features covering the pod, the mediator, per-agent
  authentication, the composition mechanism and per-agent workload identity. R8.8 per-agent
  workload identity sits here rather
  than with the brokering it gates, for two reasons: R8.8 is a MUST, and deferring it to Milestone
  03 puts a MUST behind Q9, where a negative answer would orphan it permanently; and the component
  inventory already lists a client certificate as an interface on every agent container, so the
  service definitions and proxy configuration of three other features assume it. Deferring reopens
  them.
- **Neither Milestone 01's nor Milestone 02's output may be used for real work until Milestone 02
  completes.** R12.8 requires adversarial validation before real use and that lands in 02.
  Milestone 01 produces a sandbox that works, not a sandbox that is proven.
- **Q1 and Q9 remain open and now both sit inside Milestone 03.** Q1 (which AWS accounts and
  services) determines whether R6.4.3's bucket-level allowlisting is practical; Q9 (whether a
  dedicated Identity Center principal can be created) determines whether any compliant credential
  model exists at all (D13a). Both should be raised with the operator's organisation during
  Milestone 01, since the lead time is not ours to control.

**Discovery approach:** Feature 01.1's egress discovery used Docker Sandboxes against a synthetic
repository with throwaway credentials only. The constraint is the mitigation — Open Decision 3
stays open without blocking Milestone 01, and no real code or credential crossed the vendor path
(R14.1).

**This is no longer the only discovery path.** Feature 01.4 SF-2b derived the OAuth endpoint set
from the pod's own mediator audit log rather than from `sbx`, and the operator elected to run it
against real provider accounts rather than throwaway ones — accepting a live Anthropic and ChatGPT
credential inside the boundary that feature was testing. No vendor path is involved, so R14.1 is
unaffected; the credential exposure is recorded in that feature's Gate 4 review.

## Configuration

Everything below is declared in a version-controlled **use-case profile** (R2.2, R7). Nothing
is passed ad hoc on the command line.

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `profile` | name | The use-case profile selecting tool packs, mounts and policy (R7). Four exist today: `default`, `oauth-mount` (added at 01.4 SF-4), and two test profiles. The use-case profile set proper arrives with the pack set at 02.3 |
| `AUTH_MODE` | enum, per agent | Four modes exist, but no agent supports all four. Claude Code: `apikey` \| `oauth-interactive` \| `oauth-token`. Codex: `apikey` \| `oauth-interactive` \| `oauth-mount`, where the interactive mode requires `--device-auth`. `agy`: `apikey` only, by decision D9. Unsupported combinations and an unset `AUTH_MODE` both fail closed (R4.12). Defaults: Claude Code `oauth-interactive` (fallback `oauth-token`), Codex `oauth-interactive`, `agy` `apikey` |
| project mount | path | The working directory. The only host directory mounted by default (R2.1) |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| AWS CLI pack | bool | off | **Not built — Feature 03.3.** Adds the agent role's reach to the blast radius (R6.3, R7.11) |
| Terraform pack | bool | off | **Not built — Feature 02.3.** Adds Terraform state — plaintext secrets and a map of the estate |
| Kubernetes pack | bool | off | **Not built — Feature 02.3.** Adds `kubeconfig`, often broadly scoped in practice |
| GitHub CLI pack | bool | off | **Not built — Feature 02.3.** Adds a GitHub token — repository read and write reach, and a legitimately allowlisted destination to push to (R7.10) |
| Language runtimes pack | bool | **on** | The only pack that exists today. Node, Python and Go toolchains, build-time only, declaring no runtime egress. Selected by both shipped profiles (`default`, `oauth-mount`) |
| OS packages | list, pinned | empty | Declared per pack, version-pinned, from a declared repository. Installed at image build only (R7.18). The agent cannot install at runtime (R7.19) |
| Build cache mount | bool | **off** | Per-agent. A shared cache is a cross-agent write channel (R2.10) |
| Host git config mount | bool | **off** | `:ro`, with `credential.helper` stripped first (R2.9) |

All mounts beyond the project directory and the per-agent state volumes are disabled by
default and enabled explicitly per profile (R2.8). Forwarded sockets — including
`SSH_AUTH_SOCK` — are not among the available options.

`git` is installed in the `agent-base` image rather than supplied by a pack (01.5 SF-1, closing an
01.4 deviation). The host git config mount was inert until it was.

## Outputs

**Target state:** all four are produced and exported by default. A profile may disable an
*export*; it may not disable the underlying *recording*, which R9.1 and R9.7 make mandatory
(R9.9). **As of Feature 01.5, two of the four are complete** — the Status column records where
each stands. The per-export disable mechanism is itself T36, in Milestone 02.

| Output | Type | Status | Description |
|--------|------|--------|-------------|
| Egress audit log | log | **Produced** (01.3) | Every attempted destination, allowed and blocked, written outside the blast radius (SC-7, R9.1, R9.2). Destination-level, not content-level. One JSON object per line on a volume mounted into the mediator alone. Residual: raw-socket egress attempts are invisible to it — recorded, not fixed |
| Agent action log | log | **Not built** — Feature 02.1 | Tool invocations, file modifications, privilege changes (R9.7). Correlatable with the egress log by session ID and timestamp (R9.8). Attribution to a specific agent depends on R8.8 |
| Resolved egress policy | artifact | **Produced** (01.5) | The composed allowlist for a given profile — what SC-6 is measured against. Four artifacts under `policy/resolved/`, emitted by a build stage behind a fail-on-drift gate |
| Image digest + SBOM | artifact | **Partial** | Makes SC-8 checkable rather than asserted. R7.18/R7.19 pinning is what makes reproduction true. Digest and SPDX SBOM exist for the CI-published base image only; local agent builds record an image ID and no SBOM, because the buildx docker driver rejects attestation. Provenance verification (T45) is Feature 02.4 |

## Risk Assessment

Security posture settled in Round 3. Rows marked **accepted** are deliberate decisions with
their consequence stated, not unresolved items.

| Risk | Mitigation |
|------|-----------|
| **Accepted** — `oauth-mount` from the operator's own provider account puts the whole account in the blast radius, with all-or-nothing revocation (R4.17) | R4.13/R4.14/R4.15 constrain the shape: read-only bootstrap, dedicated directory, copy to volume. Never a read-write mount. Alternative modes (`oauth-interactive`, `apikey`) remain available per agent |
| **Accepted** — no content-level DLP anywhere in the architecture (R5.15) | TLS is spliced, so the mediator sees destinations, not payloads. The mediator is positioned to add termination later without redesign (R15.2). R5.13 keeps Antigravity permanently exempt on ToS grounds |
| **Accepted** — long-lived refresh tokens persist on state volumes (R4.16) | Per-agent volumes (R4.3), secret handling (R4.7), tested revocation (R8.5, R13.1), backup exclusion (R8.7). **Measured at 01.4 SF-5: rotation is not a revocation mechanism.** A refresh token captured from a state volume stays valid after the legitimate client refreshes past it; only explicit provider revocation ends it. Measured for OpenAI; Anthropic was not replayed. Claude Code's `refreshTokenExpiresAt` is not extended by a refresh, so that token family expires roughly 28 days after the original login however often it refreshes. Review trigger: brokered agent credentials becoming available from any provider |
| **Accepted** — `codex` cannot distinguish a policy gap from an attack in-band (R9.3). Its listener peeks, so every refusal reaches it as a terminated connection with no body | The audit record — which Interface Contract 6 already makes the authoritative half — names the destination, the control and the reason. `claude` and `agy` still get the 403 body on pre-CONNECT verdicts. Closing it would mean giving `codex` a non-bumping front listener, which is the cascade its plaintext hop exists to avoid, and would still produce no body once the peek stage runs |
| **Accepted** — Control 3 ships two of its three ceilings (D5). Concurrency and byte rate are enforced; connection *rate* is not | Squid 6.13 has no per-client connection-rate directive at all. The alternatives were an external helper process inside the enforcement point, or a policy key that silently enforces nothing; the field was dropped and the compiler now refuses an artifact that declares it, so the gap is visible rather than assumed away |
| **Sequencing** — AWS Model B brokering without per-agent identity is *worse* than not brokering: every agent on the network receives every brokered credential | R8.8 promoted to MUST and made a hard precondition. Model B is not enabled until a distinct workload identity exists per agent |
| **Unresolved** — Antigravity ToS Section 6 boundary; Google has suspended paid accounts without warning, and staff declined to clarify the boundary | Open Decision 2. `agy` defaults to `AUTH_MODE=apikey`, sidestepping the OAuth relationship. R5.13 bars TLS interception of Antigravity traffic permanently |
| **Unresolved** — Docker Sandboxes' retention and data-handling terms for intercepted traffic are not established | Open Decision 3, and now R14.1. Option 1 evaluation is constrained to a synthetic repository and throwaway credentials until the assessment completes |
| **Structural** — exfiltration through legitimately allowlisted destinations cannot be prevented | Recorded as a Non-Goal. Narrowed allowlist plus audit (SC-7, R9.1) bound and detect it rather than eliminating it |
| **Structural** — no option mitigates prompt injection itself; all three bound the harm | Recorded as a Non-Goal (R15.1). R15.2 keeps the architectural option to add a tool-call mediation layer later |

## Future Enhancements

Known desirables, explicitly parked. Each names what would trigger revisiting it.

| Enhancement | Description |
|-------------|-------------|
| TLS termination and content-level DLP | R5.15 ships splice-only. The mediator is positioned so termination can be added without redesign (R15.2). Trigger: a requirement to see *what* leaves, not only *where* it goes. R5.13 bars this for Antigravity permanently |
| Push alerting on policy denial | R9.6 stays MAY by decision — blocks are logged and surfaced to the agent (R9.3, R12.2), detection is pull-based. Trigger: a blocked attempt going unnoticed long enough to matter |
| Tool-call mediation layer | R15.2 keeps the architectural option. Trigger: a deterministic guardrail available for all three agent harnesses, or a shift toward untrusted repositories |
| Model B without the R8.8 dependency | Brokered short-lived credentials direct from a provider. Trigger: any of the three providers shipping brokered agent credentials — also the stated review trigger for R4.16 |
| Option 3 — per-agent microVM | Re-evaluate only if the threat model changes: untrusted repositories (invalidating A3), or multi-tenancy (currently a Non-Goal) |
| Team or CI distribution | Q2 settled as one workstation. Trigger: a second operator. Raises R10 and R11.2 to MUST and makes R8.8 attribution load-bearing |
