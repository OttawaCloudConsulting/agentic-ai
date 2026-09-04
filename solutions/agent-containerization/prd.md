# PRD: Sandboxed Agent Containerization

> **This document is the front door, not the register.** [`REQUIREMENTS.md`](REQUIREMENTS.md)
> is the authoritative requirement register — 157 numbered requirements across R1–R15, with
> success criteria SC-1…SC-8 and acceptance tests T1–T20. This PRD cites those IDs by
> reference and never restates them. When the two disagree, `REQUIREMENTS.md` wins.
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

Research is complete; no architecture option has been ratified — that is Gate 2.
`docs/OPTIONS_ANALYSIS.md` recommends Option 2 (Compose pod with an egress mediator). Of its
four Open Decisions, three were settled at Gate 1 (TLS posture → R5.15, Antigravity route →
R14.3, host-credential mount → R4.17); Open Decision 3, the Docker Sandboxes provider
assessment, remains open and is now governed by R14.1.

### Settled at Gate 1

| Item | Decision |
|---|---|
| Deployment scope (Q2) | **One workstation.** Assumption A1 holds. R10 (supply chain) and R11.2 (portability) stay SHOULD rather than rising to MUST |
| Repository trust (Q3) | **Trusted-ish repositories only.** Assumption A3 holds. Option 2 remains viable; Option 3 is not forced |
| `STANDARDS_MAPPING.md` G1–G9 | **Merged into the register.** Sixteen requirements added: R4.16, R7.14–R7.17, R8.8, R9.7–R9.8, R12.7–R12.8, R13.1–R13.3, R14.1–R14.2, R15.2, plus R15.1 recorded as a Non-Goal |
| Authentication scope | **Both API-key and OAuth**, per agent, selected by `AUTH_MODE` (R4.12). See `docs/OPTIONS_ANALYSIS.md` § Authentication modes |

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
| AWS estate modifiable to add an agent permission set | Operator's organisation | Pending — assumption A5; if unavailable, R6.3 becomes unimplementable |
| Docker Sandboxes (`sbx`) provider terms for intercepted traffic | Docker | **Not established** — Open Decision 3; constrains Option 1 evaluation |
| Antigravity Terms of Service Section 6 boundary | Google | **Unresolved** — Google staff declined to clarify; Open Decision 2 |

## Milestones

Scoping intent settled at Gate 1. The detailed feature breakdown is produced by `/milestone`
after Gate 3 — this records the shape, not the plan.

**Two milestones.**

| # | Milestone | Outcome |
|---|---|---|
| M1 | Working sandbox | All three agents run authenticated inside the pod with state surviving restart (SC-4), behind a seeded egress policy, with the AWS CLI pack available |
| M2 | Hardening | Adversarial validation passes (SC-1, SC-2, SC-3), remaining tool packs compose without hand-editing policy (SC-6), audit and reproducibility land (SC-7, SC-8) |

Three consequences worth stating now, because they shape the M1 breakdown:

- **M1 is large.** Including the AWS pack pulls in all of R6, plus R8.8 (per-agent workload
  identity) and Model B brokering, which R8.8 gates. `/milestone` may need to subdivide it.
- **M1's output must not be used for real work until M2 completes.** R12.8 requires
  adversarial validation before real use, and that lands in M2. M1 produces a sandbox that
  works, not a sandbox that is proven.
- **Q1 and Q9 remain open and both sit inside M1.** Q1 (which AWS accounts and services)
  determines whether R6.4.3's bucket-level allowlisting is practical; Q9 (whether a dedicated
  Identity Center principal can be created) determines whether Model B has a principal to
  broker from.

**Discovery approach:** egress discovery uses Docker Sandboxes against a synthetic repository
with throwaway credentials only. The constraint is the mitigation — Open Decision 3 stays open
without blocking M1, and no real code or credential crosses the vendor path (R14.1).

## Configuration

Everything below is declared in a version-controlled **use-case profile** (R2.2, R7). Nothing
is passed ad hoc on the command line.

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `profile` | name | The use-case profile selecting tool packs, mounts and policy (R7) |
| `AUTH_MODE` | enum, per agent | `apikey` \| `oauth-interactive` \| `oauth-token` \| `oauth-mount` (R4.12). Defaults: Claude Code `oauth-interactive` (fallback `oauth-token`), Codex `oauth-interactive`, `agy` `apikey` |
| project mount | path | The working directory. The only host directory mounted by default (R2.1) |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| AWS CLI pack | bool | off | Adds the agent role's reach to the blast radius (R6.3, R7.11) |
| Terraform pack | bool | off | Adds Terraform state — plaintext secrets and a map of the estate |
| Kubernetes pack | bool | off | Adds `kubeconfig`, often broadly scoped in practice |
| Language runtimes pack | bool | off | Node, Python, Go toolchains |
| OS packages | list, pinned | empty | Declared per pack, version-pinned, from a declared repository. Installed at image build only (R7.18). The agent cannot install at runtime (R7.19) |
| Build cache mount | bool | **off** | Per-agent. A shared cache is a cross-agent write channel (R2.10) |
| Host git config mount | bool | **off** | `:ro`, with `credential.helper` stripped first (R2.9) |

All mounts beyond the project directory and the per-agent state volumes are disabled by
default and enabled explicitly per profile (R2.8). Forwarded sockets — including
`SSH_AUTH_SOCK` — are not among the available options.

## Outputs

All four are produced and exported by default. A profile may disable an *export*; it may not
disable the underlying *recording*, which R9.1 and R9.7 make mandatory (R9.9).

| Output | Type | Description |
|--------|------|-------------|
| Egress audit log | log | Every attempted destination, allowed and blocked, written outside the blast radius (SC-7, R9.1, R9.2). Destination-level, not content-level |
| Agent action log | log | Tool invocations, file modifications, privilege changes (R9.7). Correlatable with the egress log by session ID and timestamp (R9.8). Attribution to a specific agent depends on R8.8 |
| Resolved egress policy | artifact | The composed allowlist for a given profile — what SC-6 is measured against |
| Image digest + SBOM | artifact | Makes SC-8 checkable rather than asserted. R7.18/R7.19 pinning is what makes reproduction true |

## Risk Assessment

Security posture settled in Round 3. Rows marked **accepted** are deliberate decisions with
their consequence stated, not unresolved items.

| Risk | Mitigation |
|------|-----------|
| **Accepted** — `oauth-mount` from the operator's own provider account puts the whole account in the blast radius, with all-or-nothing revocation (R4.17) | R4.13/R4.14/R4.15 constrain the shape: read-only bootstrap, dedicated directory, copy to volume. Never a read-write mount. Alternative modes (`oauth-interactive`, `apikey`) remain available per agent |
| **Accepted** — no content-level DLP anywhere in the architecture (R5.15) | TLS is spliced, so the mediator sees destinations, not payloads. The mediator is positioned to add termination later without redesign (R15.2). R5.13 keeps Antigravity permanently exempt on ToS grounds |
| **Accepted** — long-lived refresh tokens persist on state volumes (R4.16) | Per-agent volumes (R4.3), secret handling (R4.7), revocation (R8.5), backup exclusion (R8.7). Review trigger: brokered agent credentials becoming available from any provider |
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
