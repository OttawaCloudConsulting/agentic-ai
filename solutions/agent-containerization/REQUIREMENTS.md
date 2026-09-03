# Requirements — Sandboxed Agent Containerization

Requirements for a containerized, sandboxed environment running agentic coding agents with a minimal blast radius.

**Status:** Requirements draft. No architecture selected — see [`docs/OPTIONS_ANALYSIS.md`](docs/OPTIONS_ANALYSIS.md) for the three candidate designs and [`docs/RESEARCH_FINDINGS.md`](docs/RESEARCH_FINDINGS.md) for the evidence base.

**Date:** 2026-09-02.

## Contents

- [Purpose](#purpose)
- [Definitions](#definitions)
- [Success Criteria](#success-criteria)
- [Requirement Provenance](#requirement-provenance)
- [R1 — Isolation and Runtime](#r1--isolation-and-runtime)
- [R2 — Filesystem Scoping](#r2--filesystem-scoping)
- [R3 — Agent Toolchain](#r3--agent-toolchain)
- [R4 — State and Authentication Persistence](#r4--state-and-authentication-persistence)
- [R5 — Network Egress Policy](#r5--network-egress-policy)
- [R6 — AWS Access](#r6--aws-access)
- [R7 — Loadable Tool Packs](#r7--loadable-tool-packs)
- [R8 — Secrets and Credential Handling](#r8--secrets-and-credential-handling)
- [R9 — Observability and Audit](#r9--observability-and-audit)
- [R10 — Build, Supply Chain and Reproducibility](#r10--build-supply-chain-and-reproducibility)
- [R11 — Host Platform and Portability](#r11--host-platform-and-portability)
- [R12 — Operability](#r12--operability)
- [Non-Goals](#non-goals)
- [Assumptions](#assumptions)
- [Open Questions](#open-questions)
- [Acceptance Test Matrix](#acceptance-test-matrix)

## Purpose

Provide a reusable, sandboxed container environment in which Claude Code, OpenAI Codex and Google Antigravity can run — including with permission prompts bypassed — such that a compromised or prompt-injected agent cannot reach data, systems or networks outside an explicitly declared boundary.

The environment must be adaptable per use case through composable tool packs (AWS CLI, Terraform, Kubernetes, language runtimes) without widening the security boundary implicitly.

## Definitions

| Term | Meaning |
|---|---|
| **Agent** | Claude Code, OpenAI Codex CLI, or Antigravity CLI (`agy`) running inside the sandbox |
| **Blast radius** | The set of data, credentials, systems and networks reachable by a fully compromised agent process |
| **Enforcement point** | The component evaluating security policy. Must sit outside the blast radius. |
| **Tool pack** | A declarative, optional bundle of tooling (binaries, config, egress entries, mounts) selectable per use case |
| **Use-case profile** | A named, version-controlled selection of tool packs, mounts and policy for a class of work |
| **Egress policy** | The combined allowlist and denylist governing outbound network access |
| **Data perimeter** | AWS-side controls (SCPs, condition keys) restricting which accounts and resources a principal can reach |

## Success Criteria

The solution is successful when all of the following hold. These are outcomes, not implementation choices.

| ID | Criterion | How measured |
|---|---|---|
| SC-1 | A fully compromised agent cannot read any host file outside the declared mounts | Red-team: attempt host filesystem traversal from inside the container |
| SC-2 | A fully compromised agent cannot reach any network destination outside the declared egress policy — including via DNS | Red-team: attempt exfiltration over HTTP, HTTPS, raw TCP, DNS and ICMP to a controlled collector |
| SC-3 | A fully compromised agent cannot modify the egress policy, the mount set, or the enforcement point | Red-team: attempt policy tampering from inside the container |
| SC-4 | All three agents run non-interactively, authenticated, with state surviving container restart | Restart the container; confirm each agent is still signed in and retains session history |
| SC-5 | AWS access is present, SSO-authenticated, and least-privilege | `aws sts get-caller-identity` returns the dedicated agent role, not an operator role |
| SC-6 | A use case can add or remove tooling without hand-editing the security policy | Switch use-case profile; confirm egress policy recomposes automatically |
| SC-7 | Every destination an agent attempted — allowed or blocked — is recorded | Inspect the audit log after a session; confirm blocked attempts appear |
| SC-8 | The environment rebuilds reproducibly from version control with no manual steps | Clean-machine rebuild produces a functionally identical environment |

## Requirement Provenance

Every requirement below traces to one of three sources, shown in the `Src` column. Anything that traced to none was excluded rather than included "for completeness."

| Src | Meaning |
|---|---|
| **U** | User-stated requirement |
| **R** | Observed constraint from research — see [`docs/RESEARCH_FINDINGS.md`](docs/RESEARCH_FINDINGS.md) |
| **S** | Security floor — removing it produces a wrong result, data loss, or a reachable security hole |

Priority uses RFC 2119 keywords: **MUST**, **SHOULD**, **MAY**.

## R1 — Isolation and Runtime

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R1.1 | MUST | U | Each agent runs inside a container or VM boundary; no agent process runs directly on the host |
| R1.2 | MUST | S | The egress and mount policy enforcement point sits **outside** the agent's blast radius — a compromised agent cannot alter it |
| R1.3 | MUST | S | Agent containers run as a **non-root** user. Claude Code refuses to start with `--dangerously-skip-permissions` as root, and root plus a writable mount is an unnecessary escalation path |
| R1.4 | MUST | S | Containers run with `cap_drop: ALL` and `no-new-privileges`. Any capability added must be individually justified in the design document |
| R1.5 | MUST NOT | S | The container must not be granted `--privileged`, nor `NET_ADMIN`/`NET_RAW` for the purpose of self-enforcing its own firewall. In-container firewalling places the control inside the blast radius and violates R1.2 |
| R1.6 | SHOULD | R | The container root filesystem is read-only, with `tmpfs` for scratch paths |
| R1.7 | SHOULD | S | Each agent runs in its own container or VM, so a compromise of one cannot read another's credentials or state |
| R1.8 | SHOULD | R | The host Docker socket is never mounted. If an agent needs container builds, they occur inside the sandbox boundary with no path to the host daemon |
| R1.9 | MAY | R | A hypervisor boundary (microVM) is used in place of, or in addition to, namespace isolation where the threat model includes container escape |
| R1.10 | SHOULD | S | Resource limits (CPU, memory, PIDs, disk) are set, so a runaway or malicious agent cannot exhaust host resources |

**Note on R1.5.** Both Anthropic's and OpenAI's reference devcontainers do exactly what R1.5 forbids. They are useful reference designs for allowlist content, not for enforcement architecture.

## R2 — Filesystem Scoping

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R2.1 | MUST | U | Only explicitly nominated host directories are mounted into the container. Everything else is absent from the container's view |
| R2.2 | MUST | S | The mount set is declared in version-controlled configuration, not passed ad hoc on the command line |
| R2.3 | MUST | S | Directories the agent does not need to write are mounted read-only (`:ro`) |
| R2.4 | MUST NOT | S | The host home directory, SSH private keys, GPG keys, browser profiles, password-manager stores, and cloud credential directories are never mounted |
| R2.5 | MUST | S | Agent state volumes (R4) are separate from project mounts, so project write access does not imply credential write access |
| R2.6 | SHOULD | S | Symlinks in mounted project directories cannot escape the mount root |
| R2.7 | SHOULD | R | Where an agent only reviews code, the project mount is read-only and output is written to a separate writable path |

## R3 — Agent Toolchain

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R3.1 | MUST | U | Claude Code is present and runnable non-interactively |
| R3.2 | MUST | U | OpenAI Codex CLI is present and runnable non-interactively (`codex exec`) |
| R3.3 | MUST | U | Google Antigravity is present and runnable non-interactively via the **`agy` CLI** |
| R3.4 | MUST NOT | R | The Antigravity desktop GUI is not containerized. GUI-in-container requires `seccomp:unconfined`, which forfeits the sandbox to run an interface the agent cannot use |
| R3.5 | MUST | R | Agent versions are pinned at build time; auto-update is disabled (`DISABLE_AUTOUPDATER=1` for Claude Code, equivalent for others) |
| R3.6 | MUST | R | Non-interactive exit status is interpreted correctly per agent. `agy` soft-denies unapproved tools and still exits 0 — automation gates on the JSON `status` field, not the exit code |
| R3.7 | SHOULD | R | Each agent's own native sandbox is enabled inside the container as defence in depth: `sandbox.*` or `srt` for Claude Code, `features.network_proxy` for Codex, `--sandbox` for `agy` |
| R3.8 | SHOULD | R | Where an agent's inner sandbox cannot nest without weakening the outer container, the outer container is kept hardened and the inner sandbox is disabled. Codex's bubblewrap nesting requires `SYS_ADMIN` plus `seccomp=unconfined`, which violates R1.4 |
| R3.9 | MAY | U | Additional agents are addable through the same tool-pack mechanism as R7 |

## R4 — State and Authentication Persistence

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R4.1 | MUST | U | Agent authentication survives container restart and image rebuild without re-authenticating |
| R4.2 | MUST | U | Agent memory, session history and configuration survive container restart |
| R4.3 | MUST | S | Each agent's state lives on its own volume. No shared state volume across agents |
| R4.4 | MUST | R | Claude Code: `CLAUDE_CONFIG_DIR` is set to the mounted volume path. Mounting `~/.claude` alone is insufficient — `~/.claude.json` lives outside it and holds the OAuth account |
| R4.5 | MUST | R | Codex: `CODEX_HOME` is set to the mounted volume, and `cli_auth_credentials_store = "file"` is set explicitly. The `keyring` mode hard-fails with no D-Bus |
| R4.6 | MUST | R | Antigravity: `~/.gemini` is mounted. Keyring-dependent auth is avoided in favour of a documented headless path |
| R4.7 | MUST | S | All state volumes are treated as secret material. They hold long-lived refresh tokens |
| R4.8 | MUST NOT | R | Host credential stores are copied into the container. Claude Code credentials on this host live in the macOS Keychain and are not portable to a Linux container |
| R4.9 | MUST | R | Every agent supports a fully headless authentication path requiring no browser inside the container: paste-back code, device code, or a pre-minted token |
| R4.10 | SHOULD | S | Session transcripts, which contain full plaintext conversation history, are covered by a retention policy and are not committed to version control |
| R4.11 | SHOULD | R | Bulk host state is not bind-mounted. The operator's `~/.codex` on this host is 1.5 GB of session history; a fresh volume is used instead |

## R5 — Network Egress Policy

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R5.1 | MUST | U | The policy supports denying specific **IP addresses**, **CIDR ranges** and **FQDNs** |
| R5.2 | MUST | S | The policy is **default-deny with an allowlist** as its primary control. The denylist is a second, independent control layered on top. A denylist alone cannot bound the blast radius, because exfiltration succeeds to any host not on the list |
| R5.3 | MUST | S | Deny rules take precedence over allow rules |
| R5.4 | MUST | S | **DNS is owned by the enforcement point.** The agent has no route to port 53 on the internet. Filtering UDP/53 by destination is insufficient — both vendor reference firewalls do this and both are documented as exfiltration-capable over DNS |
| R5.5 | MUST | S | FQDN rules are evaluated per connection at Layer 7 (CONNECT or SNI), not by resolving names once into an IP set. IP-snapshot semantics break on CDN rotation, round-robin DNS and rebinding |
| R5.6 | MUST | S | Link-local (`169.254.0.0/16`, notably the cloud metadata endpoint `169.254.169.254`), loopback, and RFC1918 ranges are denied by default |
| R5.7 | MUST | S | Where a domain is allowlisted, the connection is still refused if the resolved address falls inside a denied CIDR |
| R5.8 | MUST | S | The allowlist is derived from the observed, minimal set of destinations each agent and tool pack requires. Vendor reference allowlists are not copied verbatim — Anthropic's is stale, permitting retired telemetry hosts while omitting the OAuth endpoints |
| R5.9 | MUST | R | Non-HTTP protocols are handled explicitly. Codex uses WebSockets by default and requires `Upgrade` on TCP/443; blocking it degrades streaming silently rather than failing loudly |
| R5.10 | SHOULD | S | Outbound protocols other than TCP/443 and the DNS path to the resolver are denied, including ICMP and arbitrary UDP |
| R5.11 | SHOULD | S | Optional telemetry endpoints are excluded from the allowlist by default and disabled at the agent (`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, Codex `ab.chatgpt.com`) |
| R5.12 | SHOULD | R | Where TLS interception is used, the CA is distributed through each agent's documented mechanism: `NODE_EXTRA_CA_CERTS` for Claude Code, `CODEX_CA_CERTIFICATE` for Codex, `AWS_CA_BUNDLE` for the AWS CLI |
| R5.13 | MUST NOT | S | Antigravity OAuth traffic is TLS-intercepted. See the Terms of Service warning in [`docs/OPTIONS_ANALYSIS.md`](docs/OPTIONS_ANALYSIS.md); use SNI/CONNECT splice for that agent, or authenticate by API key to avoid the OAuth relationship entirely |
| R5.14 | SHOULD | S | Policy changes are version-controlled and reviewed. An allowlist entry is a boundary change |

## R6 — AWS Access

Requirements for the AWS CLI and IAM Identity Center (SSO) authentication inside the sandbox.

### R6.1 — Tooling

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R6.1.1 | MUST | U | AWS CLI v2 is available, delivered as a tool pack under R7 rather than baked into the base image |
| R6.1.2 | MUST | R | The AWS CLI version is pinned and verified by checksum at build time |
| R6.1.3 | SHOULD | U | The AWS tool pack is optional — use cases with no AWS scope do not load it, and its egress entries are absent when it is not loaded |

### R6.2 — Authentication

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R6.2.1 | MUST | U | Authentication is via IAM Identity Center (SSO) |
| R6.2.2 | MUST NOT | S | Long-lived IAM access keys are present in the image, environment, or any mounted volume |
| R6.2.3 | MUST | R | Login works headlessly with no browser inside the container, using `aws sso login --no-browser` or `--use-device-code`. The verification URL and code are completed in a browser on the host |
| R6.2.4 | MUST | R | The `[sso-session]` block sets `sso_registration_scopes = sso:account:access`, so refresh tokens are issued and the agent does not require re-authentication on every token expiry |
| R6.2.5 | MUST | R | Where the container performs its own SSO login (R6.5 Model A), the SSO token cache (`~/.aws/sso/cache`) and CLI role cache (`~/.aws/cli/cache`) persist on a writable volume. These paths derive from `$HOME`; relocating them requires setting `HOME`, since `AWS_CONFIG_FILE` moves only the config file. Does not apply under Model B |
| R6.2.6 | MUST | U | The AWS config presented to the container is a **synthetic, version-controlled file** containing only the agent's `[sso-session]` and a single `[profile]`. The operator's `~/.aws/config` is never its source and is never mounted |
| R6.2.7 | MUST | S | The synthetic config is mounted read-only, with the token and role caches on a separate writable volume, so the agent cannot add profiles for other accounts or roles |

### R6.3 — Least privilege and blast radius

This subsection is the security core of R6. **AWS credentials inside the container extend the blast radius beyond the container and into the AWS estate.** The egress and mount controls in R1–R5 do not constrain what an agent can do once it holds a valid AWS session.

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R6.3.1 | MUST NOT | S | The operator's personal `~/.aws` directory is mounted into any agent container. On this host that directory grants `OCC-Root-Admin`, `OCC-Network-Admin`, `OCC-Automation-Admin` and `OCC-Development-Admin` across the `occ-aws-tenant` SSO session — mounting it hands a compromised agent organisation-wide administrative access |
| R6.3.2 | MUST | S | The agent authenticates as a **dedicated permission set** created for agent use, never an operator's permission set |
| R6.3.2a | MUST | S | **A trimmed config file is not a privilege boundary.** Possession of an IAM Identity Center access token permits `aws sso list-accounts` and `aws sso get-role-credentials` for every account and role the underlying identity is entitled to; neither command consults the config file. Verified against AWS CLI 2.33.24. The boundary is therefore the entitlements of the identity that minted the token, or the absence of a token in the container — see R6.5 |
| R6.3.3 | MUST | S | The default agent permission set is **read-only**. Write or mutate permissions are granted per use-case profile, explicitly and narrowly |
| R6.3.4 | MUST | S | Exactly one AWS profile is available inside the container — the one the current use-case profile declares. Other accounts and roles are not present in the container's config |
| R6.3.5 | MUST | S | The permission set's session duration is bounded and short. Expiry is an accepted operational cost, not a problem to engineer around |
| R6.3.6 | SHOULD | S | A data perimeter denies the agent principal access to resources outside the organisation — for example SCPs or role policies conditioned on `aws:ResourceOrgID` / `aws:PrincipalOrgID` — so an allowlisted AWS endpoint cannot be used to write into an attacker-controlled account |
| R6.3.7 | SHOULD | S | Permission boundaries prevent the agent principal from creating or escalating to other principals |
| R6.3.8 | SHOULD | S | Agent AWS activity is attributable in CloudTrail via a distinct role and session name |
| R6.3.9 | SHOULD | S | Destructive actions (delete, terminate, policy modification) are denied to the agent principal even when write access is granted |

### R6.4 — AWS egress

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R6.4.1 | MUST | S | The AWS tool pack declares its own egress entries, scoped to the required region and services — not a blanket `*.amazonaws.com` |
| R6.4.2 | MUST | S | Allowlisting `*.amazonaws.com` is prohibited. It re-opens general exfiltration: an agent can `PutObject` into an attacker-controlled S3 bucket, and the request is indistinguishable from legitimate traffic at the domain level |
| R6.4.3 | SHOULD | S | S3 access is allowlisted by **bucket-specific FQDN** (`<bucket>.s3.<region>.amazonaws.com`), which virtual-hosted-style addressing makes possible. Path-style addressing is disabled so it cannot be used to bypass the hostname rule |
| R6.4.4 | MUST | R | Where the container performs its own SSO login, these endpoints are allowlisted: `oidc.<region>.amazonaws.com`, `portal.sso.<region>.amazonaws.com`, the Identity Center start URL host, and `sts.<region>.amazonaws.com` |
| R6.4.6 | SHOULD | S | Under a brokered credential model (R6.5 Model B) the container performs no SSO login, so `oidc.*` and `portal.sso.*` are **removed** from the allowlist entirely. Fewer reachable auth endpoints is a smaller attack surface |
| R6.4.5 | SHOULD | R | The AWS CLI honours `HTTP_PROXY` / `HTTPS_PROXY` and `AWS_CA_BUNDLE`, and is routed through the enforcement point like every other client |

### R6.5 — Credential delivery model

Three ways to get AWS credentials into the container. One must be chosen explicitly and recorded in the design document. All three assume the synthetic config of R6.2.6; they differ in **what credential material the container holds** and therefore in what a compromised agent inherits.

| Model | Container holds | Agent's reachable AWS privilege | Verdict |
|---|---|---|---|
| **A — Scoped SSO identity** | SSO access token for a **dedicated agent identity** in Identity Center, entitled only to the agent permission set | Exactly the agent permission set | **Acceptable.** Simplest model that is actually bounded |
| **B — Brokered credentials** | Only short-lived STS credentials for one role. No SSO token, no refresh token | Exactly one role, expiring in ≤1 hour | **Preferred.** Smallest blast radius and the smallest egress allowlist |
| **C — Operator SSO identity with a trimmed config** | SSO access token for the **operator's** identity | Every account and role the operator is entitled to — the trimmed config does not restrict it | **Rejected.** Provides the appearance of scoping without the substance |

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R6.5.1 | MUST | S | Model C is prohibited. A container-resident SSO token entitled to the operator's permission sets gives a compromised agent organisation-wide access regardless of the mounted config |
| R6.5.2 | MUST | S | Under Model A, a dedicated Identity Center user or group exists for agent use, assigned **only** the agent permission set. The scoping is verified by running `aws sso list-accounts` from inside the container and confirming only the intended account is returned |
| R6.5.3 | SHOULD | S | Model B is preferred where operationally viable: the SSO login happens outside the blast radius, and only short-lived role credentials are delivered inward — via `credential_process` calling the enforcement point, or injected environment credentials refreshed on expiry |
| R6.5.4 | MUST | S | Under Model B the SSO token cache is **not** persisted into the container, and R6.2.5 does not apply. Credential expiry is handled by re-brokering, not by caching a longer-lived token inside the sandbox |
| R6.5.5 | SHOULD | S | Under Model B the broker mints credentials for exactly one role and refuses any request naming another, so the container cannot pivot by asking for a different role |
| R6.5.6 | MUST | S | Whichever model is chosen, the entitlement scope is verified empirically from inside the container, not assumed from the config file contents (test T19) |

## R7 — Loadable Tool Packs

The mechanism by which the environment adapts per use case without widening the boundary implicitly.

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R7.1 | MUST | U | The base image contains only the agents and a minimal runtime. All other tooling is delivered as optional, selectable tool packs |
| R7.2 | MUST | U | Tool packs are declared in version-controlled manifests, not installed ad hoc by the agent at runtime |
| R7.3 | MUST | S | A tool-pack manifest declares, at minimum: packages and pinned versions with checksums; required egress FQDNs and CIDRs; required mounts and their mode; required environment variables; required credentials; and whether the pack needs write access |
| R7.4 | MUST | S | The effective egress policy is **composed** from the base policy plus the packs the active use-case profile selects. A pack cannot widen policy at runtime |
| R7.5 | MUST | S | Removing a pack removes its egress entries, mounts and credentials. No policy residue |
| R7.6 | MUST | S | Packs are applied at build time into an immutable image wherever possible. Runtime installation requires package-registry egress, which widens the boundary, and is therefore off by default and explicitly declared when used |
| R7.7 | MUST | S | Pack contents are verified by checksum or signature. `curl \| bash` at runtime is prohibited |
| R7.8 | MUST | S | A pack cannot require capabilities, privileges or host access beyond what the base container has. A pack needing more is a design change requiring review, not a configuration change |
| R7.9 | MUST | U | A use-case profile is a named, version-controlled selection of packs, mounts, credentials and policy — reproducible and reviewable |
| R7.10 | SHOULD | U | Initial pack set covers: AWS CLI, Terraform/OpenTofu, Kubernetes (`kubectl`, `helm`), GitHub CLI, and language runtimes (Node, Python, Go) |
| R7.11 | SHOULD | S | Each pack states its blast-radius contribution — what a compromised agent gains when the pack is loaded. The AWS pack's entry is R6.3 |
| R7.12 | SHOULD | S | Packs granting credentials to external systems (AWS, Kubernetes, GitHub) are individually reviewable and independently revocable |
| R7.13 | MAY | U | Packs may carry agent configuration (skills, MCP servers, rules) alongside binaries, provided MCP servers are subject to the same egress policy |

**Note on MCP servers.** An MCP server is executable code with network access running inside the sandbox. It is covered by every requirement in this document that applies to the agent itself. Claude Code's built-in Bash sandbox does **not** constrain MCP servers — only `srt` or the container boundary does.

## R8 — Secrets and Credential Handling

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R8.1 | MUST | S | No secret is baked into a container image layer |
| R8.2 | MUST | S | Credentials are scoped to the single use-case profile that needs them |
| R8.3 | SHOULD | S | Credentials are brokered at the enforcement point — injected into upstream requests — so the agent container never holds a long-lived token. `codex-responses-api-proxy` is a working example of this pattern |
| R8.4 | MUST | S | Every credential the agent can obtain is enumerated in the design document, with its blast-radius contribution stated |
| R8.5 | MUST | S | Credential rotation and revocation are possible without rebuilding the environment |
| R8.6 | SHOULD | S | Agent session transcripts are checked to confirm they do not capture credential values from command output |
| R8.7 | MUST | S | State volumes holding refresh tokens are excluded from backups that leave the trust boundary, and from version control |

## R9 — Observability and Audit

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R9.1 | MUST | S | Every outbound connection attempt is logged with destination, verdict and timestamp — **blocked attempts included**. A blocked attempt is the detection signal for a compromised agent |
| R9.2 | MUST | S | Logs are written outside the agent's blast radius and cannot be altered by the agent |
| R9.3 | SHOULD | S | Policy denials are surfaced to the operator rather than failing silently, so a legitimate gap is distinguishable from an attack |
| R9.4 | SHOULD | S | Egress rules REJECT rather than DROP where practical, so misconfiguration fails fast and visibly instead of hanging |
| R9.5 | SHOULD | R | The environment self-verifies its policy at startup: a known-denied destination must fail and a known-allowed destination must succeed, or startup aborts. Both vendor reference firewalls do this and it is worth retaining |
| R9.6 | MAY | S | Egress logs are shipped to a SIEM or alerting pipeline |

## R10 — Build, Supply Chain and Reproducibility

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R10.1 | MUST | S | The environment is defined entirely in version-controlled files. No manual setup steps |
| R10.2 | MUST | S | Base image, agent versions and tool-pack contents are pinned to specific versions or digests |
| R10.3 | MUST | R | Agent auto-updaters are disabled, so a pinned build stays pinned |
| R10.4 | SHOULD | S | The image builds without network access to anything outside the declared build allowlist |
| R10.5 | SHOULD | R | Third-party agent wrappers are not depended upon. The 2025 cohort of agent Docker wrappers is largely abandoned; build on vendor primitives instead |
| R10.6 | SHOULD | R | A documented update path exists for agent versions, with the policy re-verified after each bump — agent egress requirements change between releases |
| R10.7 | MAY | S | Image provenance is attested (SBOM, signed images) |

## R11 — Host Platform and Portability

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R11.1 | MUST | R | Runs on macOS 26 on Apple silicon, the current development host |
| R11.2 | SHOULD | U | Runs on Linux hosts without architectural change, so the artifact is reusable on servers and CI |
| R11.3 | SHOULD | S | No dependency on a closed-source or account-gated component in the critical path, so the environment remains buildable and auditable |
| R11.4 | SHOULD | R | Read-only mounts are verified as enforced on the host's filesystem sharing layer. Docker Desktop on macOS uses VirtioFS, which fakes ownership but does enforce read-only |
| R11.5 | MAY | R | Multiple agents run concurrently on one host within the resource limits of R1.10 |

## R12 — Operability

| ID | Pri | Src | Requirement |
|---|---|---|---|
| R12.1 | MUST | S | Starting a sandboxed session for a given use-case profile is a single documented command |
| R12.2 | MUST | S | The failure mode when the policy blocks something legitimate is a clear, actionable message naming the blocked destination |
| R12.3 | SHOULD | S | A documented procedure exists for adding a destination to the allowlist, including who reviews it |
| R12.4 | SHOULD | S | A discovery mode exists to observe and record what a workload actually needs, for turning into a policy — run in a disposable environment, never against production credentials |
| R12.5 | SHOULD | S | Tearing down a session destroys ephemeral state but preserves the declared persistent volumes |
| R12.6 | SHOULD | S | Onboarding documentation covers first-run authentication for all three agents plus AWS SSO |

## Non-Goals

Explicitly out of scope. Listed so they are not silently assumed.

| Non-goal | Reason |
|---|---|
| Containerizing the Antigravity desktop GUI | Requires forfeiting the container sandbox; the `agy` CLI supersedes the need |
| Defending against a malicious operator | The threat model is a compromised agent, not an insider with host access |
| Defending against a compromised model provider | Outside the control of this environment |
| Preventing exfiltration through legitimately allowlisted destinations | Structurally impossible. An agent allowed to reach GitHub can push to GitHub. Mitigated by narrowing the allowlist and by audit, not eliminated |
| Multi-tenancy or hosting the sandbox as a shared service | Single-operator scope; revisit if this changes, since it raises the isolation requirement |
| Replacing code review of agent output | The sandbox bounds damage; it does not certify correctness |

## Assumptions

| # | Assumption | Impact if wrong |
|---|---|---|
| A1 | Single operator on a trusted host; the host itself is not part of the threat model | Multi-tenant use would force Option 3 in the options analysis |
| A2 | Agents may run unattended with permission prompts bypassed — this is the reason the sandbox exists | If always attended, requirements could relax substantially |
| A3 | Projects mounted are trusted-ish. Untrusted third-party repositories raise the bar materially | OpenAI explicitly limits its reference firewall to trusted repositories |
| A4 | Model provider APIs must be reachable; a fully air-gapped sandbox is not the goal | Would change R5 from selective to binary |
| A5 | The AWS estate is under the operator's organisation and can be modified to add an agent permission set | R6.3 becomes unimplementable; fall back to a read-only permission set with no data perimeter |

## Open Questions

Answers change the design; none blocks drafting requirements.

| # | Question | Why it matters |
|---|---|---|
| Q1 | Which AWS accounts and services must the agent actually reach? | Determines whether R6.4.3's bucket-level allowlisting is practical or whether the surface is too broad |
| Q2 | Is this for one workstation or a team/CI artifact? | Team use raises R10 and R11.2 from SHOULD to MUST |
| Q3 | Will agents operate on untrusted third-party repositories? | Invalidates A3, and pushes the recommendation toward the microVM option |
| Q4 | Which agent auth mode per agent — subscription OAuth or API key? | Changes the required allowlist and whether credential brokering (R8.3) is possible |
| Q5 | Is there an existing organisational egress proxy or data perimeter to integrate with? | May replace part of the enforcement point |
| Q6 | Acceptable session-duration and re-authentication frequency? | Trades operator friction against R6.3.5 |
| Q7 | Are Kubernetes or Terraform packs needed at first release, or later? | Terraform state and `kubeconfig` each add their own blast radius |
| Q8 | Which credential delivery model — A (dedicated agent SSO identity) or B (brokered short-lived credentials)? | Determines whether an SSO token exists in the container at all, and whether `oidc.*` / `portal.sso.*` appear in the allowlist |
| Q9 | Can a dedicated Identity Center user or group be created for agent use? | If not, Model A is unavailable and Model B becomes mandatory, since Model C is prohibited |

## Acceptance Test Matrix

Minimum verification set. Each test maps to a success criterion.

| Test | Method | Passes when | SC |
|---|---|---|---|
| T1 Host filesystem containment | Attempt to read paths outside declared mounts | All attempts fail | SC-1 |
| T2 Read-only enforcement | Attempt to write to a `:ro` mount | Write fails | SC-1 |
| T3 HTTP/HTTPS exfiltration | `curl` a non-allowlisted collector | Connection refused and logged | SC-2 |
| T4 DNS exfiltration | Encode data in a DNS query to a controlled authoritative server | No query arrives | SC-2 |
| T5 Raw TCP / non-HTTP egress | Open a socket to a non-allowlisted host and port | Connection refused | SC-2 |
| T6 CDN rotation | Allowlist a domain, then attempt a denied domain sharing its IP | Denied domain refused | SC-2 |
| T7 Metadata endpoint | Request `169.254.169.254` | Refused | SC-2 |
| T8 Policy tampering | Attempt to alter firewall, proxy config or mount set from inside | All attempts fail | SC-3 |
| T9 Restart persistence | Restart container; run each agent | All three still authenticated with state intact | SC-4 |
| T10 AWS identity | `aws sts get-caller-identity` | Returns the dedicated agent role, not an operator role | SC-5 |
| T11 AWS SSO headless login | `aws sso login --no-browser` with no browser in the container | Login completes; token cached on the persistent volume | SC-5 |
| T12 AWS least privilege | Attempt a denied AWS action | AccessDenied, recorded in CloudTrail | SC-5 |
| T13 Cross-account write | Attempt `PutObject` to an out-of-organisation bucket | Denied by data perimeter or egress policy | SC-5 |
| T19 Token entitlement scope | From inside the container, run `aws sso list-accounts` | Model A: only the intended account is returned. Model B: no SSO token exists, so the call fails | SC-5 |
| T20 Role pivot | Attempt to obtain credentials for a role other than the agent role | Refused by the broker (Model B) or absent from entitlements (Model A) | SC-5 |
| T14 Pack composition | Load and unload a tool pack | Egress policy gains and loses exactly that pack's entries | SC-6 |
| T15 Runtime install blocked | Agent attempts to install a package with no registry pack loaded | Blocked and logged | SC-6 |
| T16 Audit completeness | Review logs after T3–T7 | Every attempt is present with destination and verdict | SC-7 |
| T17 Startup self-check | Corrupt the policy, then start | Startup aborts with a clear error | SC-7 |
| T18 Clean rebuild | Rebuild from version control on a clean machine | Functionally identical environment, no manual steps | SC-8 |
