# Architecture and Design: Sandboxed Agent Containerization

> **Authority.** [`REQUIREMENTS.md`](../../../REQUIREMENTS.md) is the authoritative requirement
> register (157 requirements, R1–R15; success criteria SC-1…SC-8; acceptance tests T1–T20).
> This document ratifies an architecture against that register and cites requirement IDs by
> reference. Where the two disagree, `REQUIREMENTS.md` wins — except for the acceptance-test
> extension proposed in [Requirements Traceability](#requirements-traceability-and-test-extension),
> which is a proposal against the register, not a change to it.
>
> **Gate 2 scope.** Gate 1 approved `prd.md` and deferred three items here: extension of the
> acceptance-test matrix to the requirements added at Gate 1, verification of three suspected
> contradiction pairs, and cross-reference integrity. All three are resolved in this document —
> see [Gate 1 Deferred Items](#gate-1-deferred-items).
>
> **What this gate ratifies.** `docs/OPTIONS_ANALYSIS.md` recommended Option 2 (Compose pod with
> an egress mediator). Gate 2 adopts it. Supporting analysis:
> [`docs/OPTIONS_ANALYSIS.md`](OPTIONS_ANALYSIS.md), [`docs/RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md),
> [`docs/STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md), [`docs/red-team/options-analysis-01/`](red-team/options-analysis-01/).

## Overview

Three agent CLIs — Claude Code, OpenAI Codex, Google Antigravity (`agy`) — each run in their own
container, on their own internal Docker network with no route to the internet. A single
multi-homed `egress-mediator` is the only path out. It terminates per-agent mTLS, serves DNS for
the pod, evaluates a default-deny egress policy at Layer 7, writes the audit log, and — once
per-agent workload identity exists — brokers upstream credentials.

The enforcement point sits outside every agent's blast radius (R1.2). No agent container holds
`NET_ADMIN`, and no agent firewalls itself (R1.5): a control the agent can reach is not a control.

**What this architecture does and does not do.** It bounds what a compromised agent can reach and
records where it tried to go. It does not detect the compromise, constrain what the agent does
inside the boundary, or — until R8.8 lands — attribute an action to a specific agent. That
framing is carried verbatim from the options analysis and is the honest summary of the posture.

## Design Decisions

| # | Decision | Rationale | Tradeoff | Alternatives Considered |
|---|----------|-----------|----------|-------------------------|
| D1 | **Adopt Option 2** — Compose pod, agent containers on internal networks, single egress mediator | Only option evaluating FQDN rules correctly at L7 (R5.5); only enforcement point that can be *extended* to per-agent identity, operator hold, rate limiting and an MCP gateway (R15.2); yields a self-owned destination audit trail outside the agent's reach (R9.1) | Worst recovery-to-known-good of the three options: persistent volumes, hand-built mediator state and a self-owned log mean a contaminated environment is slower and less certain to rebuild than a destroyed microVM. Accepted, mitigated by D16 | **Option 1 (Docker Sandboxes `sbx`)** — hours not days, microVM boundary, UDP/ICMP blocked outright; rejected as durable answer: Antigravity unsupported, closed-source, macOS/Windows-only, vendor on the traffic path (R14.1 unmet), policy engine expresses network only and cannot be extended. Retained as the *discovery seeding* tool (D17). **Option 3 (per-agent microVM)** — strongest boundary; rejected as overkill: container escape is not in the threat model, 1–2 weeks, Apple `container` has no Compose equivalent. Revisit only if A3 (trusted-ish repos) or the multi-tenancy non-goal changes |
| D2 | **One internal network per agent** (`claude-net`, `codex-net`, `agy-net`, each `internal: true`), mediator multi-homed onto all three plus the external network | `internal: true` removes the default route but Docker bridge networks allow unrestricted container-to-container traffic on the same bridge. A shared `agents-net` gives *zero* cross-agent isolation while appearing to isolate. Containers on separate bridge networks cannot reach each other by name or IP | Three networks to declare and maintain instead of one; the mediator must be attached to each | **Single `agents-net`** — rejected, this was a red-team Critical finding against the pre-revision design. **Single network with ICC disabled** via `driver_opts` (`com.docker.network.bridge.enable_icc`) — the mechanism exists but the exact key name is **UNVERIFIED**; per-agent networks need no such confirmation, which is why they are the primary form |
| D3 | **The mediator owns DNS.** Agent networks have no route to port 53 on the internet | R5.4. Filtering UDP/53 by destination is insufficient — both vendor reference firewalls do exactly that and both are documented as exfiltration-capable over DNS. Owning the resolver makes DNS tunnelling structurally impossible rather than filtered | The mediator becomes a hard dependency for name resolution; its failure is a full outage rather than a degraded one | **Filter UDP/53 by destination** — rejected, this is the documented hole. **Allow a public resolver** — rejected, same hole |
| D4 | **TLS is spliced, never terminated**, for all three agents at first release. Destination validated at CONNECT via SNI; connection passed through undecrypted | R5.15. Required for Antigravity on ToS grounds (R5.13, D9); consistency avoids two trust models side by side; removes CA generation, distribution, rotation and per-agent trust-store config from a build that never scoped it | **No content-level DLP anywhere in the architecture.** The channels carrying 100% of prompt and completion content are inspected for hostname and byte count only. Remote MCP tool invocations to allowlisted hosts cannot be inspected or logged. Accepted; destination narrowing plus audit is the residual control | **TLS MITM for Claude Code and Codex, splice for `agy`** — rejected: runs two trust models, adds unscoped CA work, and buys URL-path granularity the requirements do not ask for. The mediator is positioned so termination can be added later without redesign (R15.2); R5.12 records the CA mechanisms (`NODE_EXTRA_CA_CERTS`, `CODEX_CA_CERTIFICATE`, `AWS_CA_BUNDLE`) against that later phase |
| D5 | **Egress policy is three independent controls in order**: (1) default-deny allowlist of domains and CIDRs evaluated at CONNECT/SNI; (2) post-resolution CIDR denylist; (3) per-agent rate and concurrency limits | R5.2/R5.3/R5.5/R5.7. An allowlist alone breaks on CDN IP rotation and DNS rebinding, which an `ipset` snapshot taken at container start cannot catch. Rate limiting is the only control that bounds a runaway loop against the model API — a cost-exhaustion failure that generates *only allowlisted traffic* and is therefore invisible to controls 1 and 2 | Three evaluation stages per connection; the rate limiter needs per-agent identity to be meaningful (D6) | **Allowlist only** — rejected, R5.7 requires the post-resolution check. **Denylist only** — rejected by R5.2: exfiltration succeeds to any host not on the list |
| D6 | **Per-agent workload identity (mTLS) at the mediator is a hard precondition for any credential brokering**, not a later enhancement | R8.8, promoted to MUST at Gate 1. A mediator that injects an upstream credential because "a request arrived from the pod network" hands *every* agent *every* brokered credential — a textbook confused deputy, and because the mediator is also the policy decision point the resulting audit lines look legitimate. Brokering without caller identity is worse than no brokering | Identity issuance, rotation and lifecycle are real work inside the M1 estimate, not adjacent to it. Until it exists, brokering is mutually exclusive with a shared agent network and only one agent may be brokered per pod | **Broker on network origin** — rejected, the confused-deputy pattern above (red-team Critical finding). **Defer brokering entirely** — viable but forfeits R6.5 Model B, which Gate 1 selected |
| D7 | **One state volume per agent; no shared volume, no shared build cache** | R4.3, R2.5, R2.10. Claude Code cannot read Codex's `auth.json` — a filesystem property, and with D2 a network property too. A cache shared across agents is a cross-agent write channel | Duplicated package/build caches cost disk and rebuild time | **Shared cache volume** — permitted by R2.10 only as a recorded accepted risk with blast radius stated. Not taken; the default is per-agent (`off` in the PRD configuration table) |
| D8 | **`AUTH_MODE` is per agent**, one of `apikey` \| `oauth-interactive` \| `oauth-token` \| `oauth-mount`, defaulting to the safest mode each agent supports | R4.12. The agents are not symmetric: Claude Code's credential is macOS-Keychain-resident and not portable to a Linux container; Codex's `auth.json` is plain JSON and mountable; `agy` has no working OAuth env-var path (upstream issue open) | Four code paths in the entrypoint instead of one | **API key everywhere** — rejected, Claude Code and Codex subscription auth is OAuth. **OAuth everywhere** — rejected, `agy` takes `apikey` by decision D9 |
| D9 | **Antigravity authenticates by `GEMINI_API_KEY` only.** No Antigravity OAuth credential enters any container. TLS interception of `agy` traffic is permanently barred | Open Decision 2, settled at Gate 1 (R14.3). Google's Additional Terms §6 prohibits "using third party software, tools, or services to access the Service"; Google has suspended paid accounts without warning over it, and staff declined to clarify the boundary. The API-key route leaves the OAuth relationship entirely rather than proxying it | Routes to the public Gemini API on the operator's own billing rather than the Antigravity account quota — the accepted cost. **The route itself is UNVERIFIED**: the official install page documents it, a June 2026 maintainer statement says Gemini API keys are not supported. Must be tested against the pinned `agy` version; fallback is Antigravity OAuth with splice-only and no proxy tooling, which leaves the ToS question open rather than sidestepped. Requires `"modelProvider": "gemini"` in settings **and** the env var — the variable alone is a documented no-op | **Antigravity OAuth + splice** — the fallback, not the default. **Antigravity OAuth + MITM** — permanently barred (R5.13): arguably within the clause actually enforced against |
| D10 | **The use-case profile drives the image build as well as the run.** OS packages are declared per pack, version-pinned, from a declared repository, installed at build time only. The agent process cannot invoke a package manager at runtime | R7.18/R7.19. This is what keeps R7.7 (checksum/signature verification, no `curl \| bash`), R7.16 and SC-8 (identical clean rebuild) satisfiable once packs may add OS packages | A profile change that touches packages is a rebuild, not a restart. Each profile pins to a distinct image digest, so "the image" is per-profile rather than universal | **Runtime `apt install` from a pack manifest** — rejected: defeats SC-8's reproducibility and R7.7's verification simultaneously, and hands a compromised agent a package manager |
| D11 | **Recording and export are separate concerns.** A profile may disable an *export*; it cannot disable the underlying *recording* | R9.9 against R9.1/R9.7. The recording path is wired to the mediator and the audit sink, not to the profile's export toggles, so there is no profile setting that can switch recording off. Any disabled export is explicit and recorded | An operator who disables an export still pays the cost of recording | **One toggle for both** — rejected: makes R9.1's mandatory blocked-attempt logging profile-defeatable, and the blocked attempt is the detection signal |
| D12 | **The audit log is written inside the mediator or shipped directly off-host — never to a volume an agent container can reach** | R9.1/R9.7 require recording outside the blast radius. Five Eyes L658: "Isolate agents into enclaves with no write access to logs." A log the agent can edit is not evidence | A mediator-local log shares the mediator's fate; off-host shipping adds a destination that must itself be allowlisted and governed | **Shared log volume mounted into each agent** — rejected outright, puts the evidence inside the blast radius |
| D13 | **AWS access uses Model B (brokered short-lived credentials), gated on D6.** Model C is prohibited | R6.5, R6.5.1. A container-resident SSO token entitled to the operator's permission sets gives a compromised agent organisation-wide access regardless of which config file is mounted. Model B is independently corroborated by the Five Eyes static-credential position — but only if the broker knows *which* agent is calling, which is D6 | Model B cannot be enabled until R8.8 is satisfied. Q1 (which accounts and services) and Q9 (whether a dedicated Identity Center principal can be created) are both open and both sit inside M1 | **Model A** (scoped SSO token for a *dedicated* Identity Center identity, R6.5.2) — the register rates it "acceptable, the simplest model that is actually bounded", but it is **not a fallback for a negative Q9**: R6.5.2 requires a dedicated Identity Center user or group just as Model B requires a principal to broker from. See the Q9 note below. **Model C** (operator's own identity, trimmed config) — prohibited by R6.5.1: "the appearance of scoping without the substance" |
| D13a | **A negative answer to Q9 leaves no compliant AWS credential model, and the AWS pack cannot ship.** This is recorded as a gate on the pack, not as a risk to be managed during it | Model C is prohibited outright (R6.5.1). Model B requires an Identity Center principal to broker from. Model A requires, under R6.5.2 (MUST), "a dedicated Identity Center user or group ... assigned **only** the agent permission set". All three paths therefore depend on the estate change assumption A5. If it does not hold, there is no remaining model that satisfies R6.5 | M1 includes the AWS CLI pack, so a negative Q9 forces an M1 rescope rather than a substitution. Surfacing it at Gate 2 is cheaper than discovering it mid-milestone | **Treat Model A as the fallback** — rejected on reading R6.5.2: it carries the same dependency. **Mount the operator's `~/.aws`** — prohibited by R6.3.1, which on this host would hand a compromised agent `OCC-Root-Admin` across the tenant. **Ship M1 without the AWS pack** — the actual fallback, and a scoping decision for Gate 3 |
| D14 | **Each agent's native sandbox is enabled inside the container as defence in depth, and is not counted as a boundary** | R3.7. `srt` for Claude Code, `features.network_proxy` for Codex, `--sandbox` for `agy`. All three are reachable and therefore modifiable by the agent process. One has a property worth naming: `srt` hard-denies writes to `.mcp.json`, `.claude/commands` and `.claude/agents` at the project root — a partial mitigation for R7.17 configuration integrity, covering Claude Code only | Enabling them costs configuration surface and can mask which layer actually blocked something during debugging | **Rely on native sandboxes** — rejected by R1.2: they sit inside the blast radius. **Disable them** — rejected: free defence in depth. Note R3.8: where an inner sandbox cannot nest without weakening the outer container it is disabled instead — Codex's bubblewrap nesting needs `SYS_ADMIN` plus `seccomp=unconfined`, which violates R1.4 |
| D15 | **Agent containers run hardened by default**: `cap_drop: ALL`, `no-new-privileges`, read-only root filesystem with `tmpfs` scratch, non-root user, and explicit CPU/memory/PID ceilings | R1.3, R1.4, R1.6, R1.10. Resource limits are not decoration: without them a prompt-injected agent stuck in a loop exhausts the host and burns the model subscription while generating only allowlisted traffic that the design logs as normal. Option 3 gets these free from its VM boundary; Option 2 must declare them | Read-only rootfs requires every writable path to be enumerated as a `tmpfs` or volume, which surfaces as build friction | **Default Docker posture** — rejected by R1.4. Any capability added must be individually justified here; none currently is |
| D16 | **Containment is designed in, not improvised.** A single agent can be stopped or detached without affecting the others; per-credential revocation procedures are documented and tested with a stated maximum detection-to-revocation time; the return-to-known-good path explicitly names what happens to each persistent state volume | R13.1, R13.2, R13.3 — the response side of D1's accepted weakness. Per-agent networks (D2) make single-agent isolation a native property rather than a special case | R13.3 is the hard one: a contaminated state volume currently cannot be distinguished from a clean one. The path therefore says *discard and re-bootstrap*, which costs a re-authentication per agent | **Rebuild everything on any incident** — safe but forfeits the state persistence SC-4 exists to provide. **Leave it to the incident** — rejected by R13.x and by red-team finding F7 |
| D17 | **The egress allowlist is seeded from a constrained Option 1 discovery run, then cross-validated — never adopted from the capture alone** | R5.8 requires an observed, minimal allowlist; vendor reference lists are stale (Anthropic's permits retired telemetry hosts and omits the OAuth endpoints). Option 1's `sbx` is the fastest observation point. R14.1 governs it: Docker Sandboxes' retention and data-handling terms for intercepted traffic are **not established** (Open Decision 3), so the run uses a **synthetic repository and throwaway credentials only** — the constraint is the mitigation | One closed-source observation point cannot establish completeness: `sbx` fully intercepts only HTTP/HTTPS and blocks UDP/ICMP entirely, so a legitimate UDP dependency is invisible in the capture and surfaces later as a novel failure. Cross-validation against agent verbose logging or `tcpdump` on the mediator during a shadow run is therefore mandatory, and the allowlist is provisional until both sources agree | **Copy the vendor reference allowlists** — rejected by R5.8. **Derive by hand from documentation** — rejected: the documentation is demonstrably stale and incomplete (the full Antigravity allowlist is not published by Google at all) |
| D18 | **MCP servers and tools are default-off, inventoried, version-pinned, and declare their own egress.** The stdio blind spot is recorded, not papered over | R7.14–R7.17. Default-deny was previously applied rigorously to the network and not at all to tools. Each server records a risk tier (read-only / write / irreversible) and a capability baseline, so capability *drift* is detectable rather than only new servers | **stdio MCP servers execute inside the blast radius and their traffic never crosses the enforcement point.** No control in this architecture sees a stdio tool invocation. The default transport per agent per server is itself UNVERIFIED. R7.17 is only partly mitigated, and only for Claude Code, by `srt` (D14) | **Inherit the agent's allowlist** — rejected: sizes every server's reach to the agent's. **Wholesale registry allowlisting** — rejected by R7.16: it undermines any inventory |
| D21 | **The base image is built by GitHub Actions and published to GitHub Packages (GHCR), consumed by digest.** Builds run from the working branch during the project and move to `main` on completion | Removes the last manual step between version control and a running environment, which is what SC-8 asks for and what a local `build.sh` could only approximate. A registry-published image has a stable digest to pin (R10.2), and CI is where SBOM emission and provenance attestation actually become practical (R10.7, currently MAY) | This repository has **no `.github/` directory today** — this introduces its first workflow, and CI becomes a build-time dependency the repo did not previously have. The published image is a supply-chain artifact: it must be consumed by digest rather than by a mutable tag, or the pinning R10.2 requires is defeated by the convenience of `:latest`. Branch-built images must not be consumed by anything but testing | **Local `build.sh` only** — the original draft; rejected by the operator: reproducibility stays operator-dependent and R10.7 attestation stays impractical. **Build from `main` immediately** — rejected for now: the project needs a testing path before `main` is meaningful. The promotion to `main` is the stated completion trigger |
| D20 | **R9.7's agent action log is carried by shipping each agent's own session transcript off-container in real time, and its limitation is stated rather than designed around** | R9.7 is a MUST and needs a named component. No option in the analysis intercepts a tool call, so no architecture here can *derive* an action log from observed behaviour — the only available source is the transcript each agent already writes. Shipping it in real time to an append-only sink puts the record outside the blast radius (R9.2) | **The agent authors its own transcript.** The record is complete-as-written, not tamper-proof at source: a compromised agent can write a false line before it ships. Real-time shipping buys tamper-*evidence*, not tamper-*resistance* — a retroactive edit on the volume does not propagate to the sink. **Attribution still waits on R8.8** (D6): until then the transcript says what happened, not which agent identity did it | **Derive the action log from egress** — impossible: destinations only, and stdio never crosses the enforcement point. **Wrap each agent to intercept tool calls** — this is R15.1's non-goal and a larger undertaking than the sandbox. **Record R9.7 as unmet** — rejected: an available source exists, and R9.7 is a MUST. The residual weakness is recorded in Controls This Architecture Does Not Provide rather than hidden |
| D19 | **This repository holds the sandbox as copyable content, not as a running deployment.** The compose files, Dockerfiles, profiles, pack manifests and policy sources are version-controlled here and copied into the consuming workstation or repository, matching the convention every other kit in `solutions/` follows | The repository README states its scope as "No runtime code. Copy content into other repositories where it is consumed." This solution would otherwise be the first deployable runtime system in the repo. Treating the artifacts as copyable content resolves the tension without weakening SC-8: R10.1 requires the environment be defined entirely in version-controlled files, and it is — here | The operator performs a copy step before first run, and a copied tree can drift from its source. R12.9 keeps this honest by making `docker compose` with a profile-selected override the entry point, with no wrapper CLI hiding the mechanics. **Amended at Gate 2:** the *base image* is not copied — it is built and published by CI and consumed by digest (D21), so only the declarative files travel | **Run the pod from this repository directly** — rejected: contradicts the repository's stated scope and makes the kit non-reusable across workstations. **Split into a separate repository** — viable, and the right move if the sandbox acquires its own release cadence; rejected now as premature for a one-workstation scope (Q2, assumption A1) |

## Component Inventory

| Component | Responsibility | Interfaces |
|-----------|---------------|------------|
| **`claude` container** | Runs Claude Code non-interactively (R3.1). Pinned version, auto-update disabled (`DISABLE_AUTOUPDATER=1`, R3.5). `srt` native sandbox on (R3.7, D14) | Attached to `claude-net` only. Proxy listener on the mediator; mediator-served DNS. Mounts: project dir, `claude-state` volume. Env: `AUTH_MODE`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`. Client cert for mTLS (D6) |
| **`codex` container** | Runs OpenAI Codex CLI non-interactively (`codex exec`, R3.2). Pinned, auto-update disabled. `features.network_proxy` on; bubblewrap nesting **disabled** — it needs `SYS_ADMIN` + `seccomp=unconfined`, violating R1.4 (R3.8) | Attached to `codex-net` only. Mounts: project dir, `codex-state` volume. Requires `cli_auth_credentials_store = "file"` under `oauth-mount`. **Egress needs `Upgrade` permitted on TCP/443** — Codex defaults to WebSocket transport and silently degrades otherwise (R5.9). Client cert for mTLS |
| **`agy` container** | Runs Google Antigravity via the `agy` CLI non-interactively (R3.3). GUI explicitly not containerized (R3.4). `--sandbox` on | Attached to `agy-net` only. Mounts: project dir, `agy-state` volume. Env: `GEMINI_API_KEY` **and** `"modelProvider": "gemini"` in settings (D9 — env var alone is a documented no-op). **Exit status is read from the JSON `status` field, not the exit code** — `agy` soft-denies unapproved tools and still exits 0 (R3.6). Client cert for mTLS |
| **`egress-mediator` container** | The single enforcement point and the only path to the internet (R1.2). Five roles in one process boundary: L7 CONNECT/SNI policy evaluation, authoritative DNS for the pod, audit writer, mTLS terminator for agent identity, and (gated on D6) upstream credential broker. Candidate implementations: **`iron-proxy`** (Go, Apache-2.0) or **Squid** in CONNECT-allowlist mode | Multi-homed onto `claude-net`, `codex-net`, `agy-net` and the external network. Exposes **exactly one port to each agent network** — the proxy listener — and no management or metrics port (see [Mediator hardening](#mediator-hardening) below). Reads the resolved egress policy; writes the audit stream to the sink. Broker secrets and the listener certificates injected at runtime through Compose `secrets:`, never baked into the image and never on an agent-reachable volume. **The CA private key is not injected at all — 01.3 SF-3 narrows issuance to an offline operator script and keeps the key on the operator host** |
| **`claude-net` / `codex-net` / `agy-net`** | Per-agent isolation segments, `internal: true` — no default route, no DNS path to the internet (D2, D3) | Each carries exactly one agent container plus the mediator |
| **External network** | The mediator's only route out | Mediator only. No agent container is ever attached |
| **Per-agent state volumes** (`claude-state`, `codex-state`, `agy-state`) | Persist agent authentication and session history across container restart and image rebuild (R4.1, SC-4). One per agent, never shared (R4.3, D7) | Mounted into exactly one agent container each. Excluded from backups (R8.7). Hold long-lived refresh tokens — the accepted risk of R4.16 |
| **Project mount** | The working directory — the only host directory mounted by default (R2.1). `:ro` where the agent only reviews (R2.7) | Bind mount, declared in the profile. Symlinks cannot escape the mount root (R2.6) |
| **Use-case profile** | Version-controlled declaration of tool packs, mounts, `AUTH_MODE` per agent, OS packages and export toggles (R2.2, R7). Nothing is passed ad hoc on the command line | Input to both the policy compiler and the image build (D10). The unit SC-6 is measured against |
| **Tool packs** (AWS CLI, Terraform, Kubernetes, language runtimes) | Composable capability units. Each declares its own egress entries, its OS packages (pinned, from a declared repository) and its mounts | Consumed by the policy compiler and the image build. Adding a pack must not require hand-editing the security policy (SC-6) |
| **Policy compiler** | Composes the resolved egress policy from the profile plus its enabled packs, and emits it as a reviewable artifact. This is the mechanism that makes SC-6 true rather than aspirational | Reads profile + pack manifests; writes the resolved egress policy artifact consumed by the mediator. Startup self-check aborts on a corrupt policy (T17) |
| **Image build pipeline** (GitHub Actions → GHCR) | Builds the **base image** in CI and publishes it to GitHub Packages, emitting digest and SBOM (D21). Per-profile images layer packs and pinned OS packages on that base at build time only (R7.18/R7.19, D10). Source branch is the working branch during the project, `main` after completion | Defined in `.github/workflows/`. Reads the profile and pack manifests. Publishes to GHCR; consumers pin by **digest, never by tag** (R10.2). The digest plus SBOM is the artifact that makes SC-8 checkable rather than asserted |
| **Agent action recorder** | Ships each agent's native session transcript off-container in real time to the audit sink, append-only: Claude Code JSONL session files, Codex session logs, `agy` JSON output. This is the component that carries R9.7; there is no interception of tool calls anywhere in the architecture (D20) | Reads the transcript path on each agent's state volume via the container logging driver or a sidecar tail. Writes to the audit sink only — never back to any agent-reachable path |
| **Audit sink** | Holds the egress log and the agent action log outside every agent's blast radius (D12). Correlatable by session ID and timestamp (R9.8) | Written by the mediator (egress) and by the agent-action recorder. Never a volume shared with an agent container |
| **AWS credential broker** (Model B, gated on D6) | Issues short-lived AWS credentials bound to one client identity; cross-binding refused (R6.5, D13) | A mediator role. Not enabled until R8.8 is satisfied. Blocked on Q1 and Q9 |

### Mediator hardening

The mediator holds brokered credentials for all three agents, the DNS authority for the pod, and
the audit log. **Narrowed by 01.3 SF-3 (2026-09-06): it does not hold the CA private key.** It is
the single component whose compromise yields most of the pod, and it therefore carries the same
baseline as the agent containers plus three additions:

- `cap_drop: ALL`, `no-new-privileges`, read-only root filesystem, non-root user (same as D15).
- Secrets injected at runtime — not in the image, not on a volume any agent can reach. On Docker
  Desktop the mechanism is Compose `secrets:` with a `file:` source, named plainly rather than as
  "a secret manager". **The CA private key is not among them (01.3 SF-3, criterion 9):** issuance
  is an offline operator script (`scripts/issue-identity.sh`) and the key never leaves the operator
  host. The mediator receives only the listener certificates it presents and the CA *certificate*
  that 01.6 will verify client certificates against, so a mediator compromise no longer yields the
  ability to mint agent identities. See `mediator/identity/README.md`.
- Exactly one port exposed to each agent network (the proxy listener). No management port, no
  metrics port, on any agent network.
- Cloud metadata (`169.254.169.254`), loopback and RFC1918 ranges denied by default (R5.6).

### Inbound listeners

Any MCP HTTP listener inside an agent container binds `127.0.0.1` only, with Origin validation
enabled and DNS-rebinding protection explicitly turned on — both the TypeScript and Python MCP
SDKs ship with rebinding protection **off** by default (CVE-2025-66414, CVE-2025-66416).

## Data Flow

### 1. Allowed outbound request

```text
agent process
  → HTTPS_PROXY / native proxy config
  → agent-net (internal: true — no other route exists)
  → mediator proxy listener
      ├─ mTLS handshake: client cert → agent identity            (R8.8, D6)
      ├─ DNS resolution by the mediator's own resolver           (R5.4, D3)
      ├─ control 1: allowlist match on CONNECT/SNI hostname      (R5.2, R5.5)
      ├─ control 2: resolved IP vs. CIDR denylist — deny wins    (R5.3, R5.7)
      ├─ control 3: per-agent rate / concurrency check           (D5)
      ├─ optional: inject brokered upstream credential           (D6, D13)
      └─ audit line: {session, agent identity, destination, verdict=allow, ts}
  → external network → destination
```

TLS is spliced at the CONNECT boundary: the mediator validates the destination and passes the
connection through undecrypted (R5.15, D4). It sees hostname and byte count, never payload.

### 2. Blocked outbound attempt

Identical up to the failing control. The connection is refused, the agent receives a surfaced
error (R9.3, R12.2), and the audit line is written with `verdict=deny`. **The blocked attempt is
the detection signal for a compromised agent** (R9.1) — which is why D11 makes the recording
non-disableable and D12 puts it out of the agent's reach. Detection is pull-based by decision;
push alerting stays MAY (R9.6).

### 3. DNS

There is no path from any agent network to port 53 on the internet. Every lookup terminates at
the mediator's resolver, which is also the component that evaluates the allowlist — so the name
that was resolved and the name that was authorised are the same name. DNS tunnelling is
structurally unavailable rather than filtered (R5.4, D3).

### 4. Audit write path

Egress lines are written by the mediator; agent-action lines (tool invocations, file
modifications, privilege changes — R9.7) are recorded by the action recorder. Both land in the
audit sink, correlatable by session ID and timestamp (R9.8). Neither path traverses a volume an
agent container can write (D12).

**Attribution is conditional.** Until R8.8 lands, the log records *what happened* but not *who
did it* — package-manager fetches, model API calls and injected tool fetches arrive as an
undifferentiated CONNECT stream. With per-agent mTLS (D6) the client identity is recorded on
every line and attribution becomes real. This is the single dependency that turns a destination
log into an agent log.

### 5. Profile → policy and image

```text
use-case profile ──┬─→ policy compiler ─→ resolved egress policy ─→ mediator
   (+ tool packs)  │        (SC-6: packs compose, policy is never hand-edited)
                   └─→ image build ─────→ per-profile image digest + SBOM
                            (pinned OS packages, build time only — R7.18/R7.19, D10; SC-8)
```

**The policy compiler runs as a build stage of the mediator image, not as an operator step.** `docker compose build` compiles the profile and its packs into the resolved policy and bakes it into the image, so the entry point stays `docker compose` with a profile override (R12.9) and there is no manual step between version control and a running environment (R10.1, SC-8). This is the same mechanism as D10: the profile drives the build.

A pack is added or removed by editing the profile. The policy recomposes and the image rebuilds;
neither step involves hand-editing the security policy. Startup aborts with a clear error if the
resolved policy fails its self-check (T17).

### 6. Authentication bootstrap, per `AUTH_MODE`

| Mode | Flow | Where the token ends up |
|---|---|---|
| `oauth-interactive` | Human runs login inside the container once and pastes the code back; or the OAuth callback is port-forwarded to a host browser (Codex documents port **1455**, fallback **1457**, redirect `http://localhost:1455/auth/callback`; publish as `-p 127.0.0.1:1455:1455`) | Minted in the container, written to that agent's state volume. Never existed on the host |
| `oauth-token` | Pre-minted token supplied by environment. Claude Code only — `claude setup-token` mints a **one-year** `CLAUDE_CODE_OAUTH_TOKEN`. Codex has no OAuth env-var equivalent; `agy` is explicitly unsupported | Env + process. Twelve-month replay window, accepted under R4.16 |
| `oauth-mount` | Host credential directory mounted **`:ro` for bootstrap only**; the entrypoint copies it into the agent's state volume; steady state runs with no host mount (R4.15) | The state volume. Refresh writes land on the volume, never on the host file |
| `apikey` | Key supplied by environment. The `agy` default (D9) | Env + process |

**`oauth-mount` is constrained in shape, not just in policy.** A dedicated directory is mounted,
never the credential file itself — CLIs write-temp-then-rename, and a single-file bind leaves the
container holding a stale inode indefinitely (R4.14). The mount is never read-write: OAuth
refresh rewrites the credential, so a writable mount lets a compromised container overwrite host
credential material (R4.13). File modes are not a control here — Docker Desktop's VirtioFS fakes
file ownership, so `0600` means nothing inside the container and `:ro` is the only real control.

## File Organization

Target tree. Everything below `compose/` and beyond is **not yet built** — this is the shape M1
creates, following the packaging convention set by `solutions/well-architected-review/` (D19).

```text
repository root/
└── .github/workflows/
    └── agent-sandbox-image.yml   # builds + publishes the base image to GHCR (D21)

solutions/agent-containerization/
├── README.md                      # install, prerequisites, first-run auth, troubleshooting (R12.6)
├── prd.md                         # Gate 1 artifact
├── REQUIREMENTS.md                # authoritative register — R1–R15, SC-1…SC-8, T1–T20
├── progress.txt                   # gate and milestone state
├── docs/
│   ├── ARCHITECTURE_AND_DESIGN.md # this document (Gate 2 artifact)
│   ├── OPTIONS_ANALYSIS.md        # option evaluation; Option 2 ratified here as D1
│   ├── RESEARCH_FINDINGS.md       # measured facts and UNVERIFIED register
│   ├── STANDARDS_MAPPING.md       # G1–G9 gaps → requirement IDs
│   ├── records/                   # R14.1/R14.2/R14.3 governance records; SF-2/SF-3 verification logs (01.1)
│   └── red-team/options-analysis-01/
├── references/                    # link-checked source index + local standards copies
│
├── compose/
│   ├── compose.yaml               # networks (3× internal + external), mediator, 3 agent services
│   └── overrides/<profile>.yaml   # profile-selected override — the R12.9 entry point
├── images/
│   ├── agent-base/Dockerfile      # non-root user, read-only-rootfs layout, tmpfs scratch paths
│   ├── claude/Dockerfile          # pinned Claude Code, DISABLE_AUTOUPDATER=1
│   ├── codex/Dockerfile           # pinned Codex CLI
│   ├── agy/Dockerfile             # pinned agy CLI
│   └── mediator/Dockerfile        # iron-proxy or Squid + resolver + audit writer
├── profiles/
│   ├── default.yaml               # project mount + state volumes only; every optional mount off
│   └── <use-case>.yaml            # packs, mounts, AUTH_MODE per agent, OS packages, export toggles
├── packs/
│   ├── aws-cli/pack.yaml          # egress entries, pinned OS packages, mounts
│   ├── terraform/pack.yaml
│   ├── kubernetes/pack.yaml
│   └── language-runtimes/pack.yaml
├── policy/
│   ├── allowlist.base.yaml        # seeded per D17, cross-validated, never vendor-copied (R5.8)
│   ├── denylist.base.yaml         # metadata endpoint, RFC1918, link-local, loopback (R5.6)
│   └── resolved/                  # policy-compiler output — the SC-6 artifact, committed
├── mediator/
│   ├── config/                    # proxy, resolver and rate-limit configuration
│   └── identity/                  # CA and per-agent cert issuance (R8.8). No private key committed
├── scripts/                       # bash, `set -euo pipefail`, invoked as `bash script.sh`
│   ├── compile-policy.sh          # profile + packs → policy/resolved/
│   ├── build.sh                   # per-profile image build; emits digest + SBOM (SC-8)
│   ├── bootstrap-auth.sh          # per-agent AUTH_MODE bootstrap, incl. :ro copy-to-volume (R4.15)
│   ├── validate-boundary.sh       # runs the adversarial matrix (R12.8) before real use
│   ├── lint-policy.sh             # feature test command (01.1); policy/*.yaml well-formedness only
│   └── install-deps.sh            # host dependency check/install (docker, openssl, curl, jq, yq, sbx); macOS + Linux (01.1)
└── tests/acceptance/              # T1–T20 plus the extension proposed below
```

**Convention notes, observed from this repository rather than assumed:** shell scripts use
`set -euo pipefail` and are invoked as `bash script.sh` (the executable bit is never set); MCP
configuration is JSON of the shape `{"mcpServers": {...}}`; the repository had no hosted CI before this
solution — `cicd/` contains manually-invoked bash only, and there is no `.github/` directory.
D21 introduces the first workflow, so SC-8's "no manual steps" is carried by the CI-published
base image and its pinned digest, with `build.sh` retained for local per-profile layering.

## Deployment & Operations

### Entry point

`docker compose` with a profile-selected override file (R12.9). No wrapper CLI is built — the
operator sees exactly what runs. Onboarding documentation covers the compose invocation directly
plus first-run authentication for all three agents and AWS SSO (R12.6).

### Build and bring-up sequence

This is the ratified sequence. Steps 0–2 are prerequisites to building the pod, not optional
preliminaries.

0. **Assess Docker Sandboxes as a service provider** (R14.1) — what its proxy observes, retention
   period for intercepted traffic, deletion and breach-notification terms. **Not done.** Until it
   is, step 1 runs constrained.
1. **Discovery run, not a production session.** Stand up Option 1 under its `locked-down` mode
   plus a minimal seed allowlist and widen only on observed failure. Not `balanced`, which starts
   at maximum permitted access and would run the agents at their widest policy against real code —
   the exact inverse of progressive deployment. **Synthetic repository and throwaway credentials
   only** (R12.4, R14.1). One agent at a time with `--sandbox` scoping, or the capture yields a
   union of all three allowlists rather than a per-agent policy.
2. **Seed — not validate — the allowlist** from that capture and add the denylist overlay.
   Cross-validate against a second source (agent verbose logging, or `tcpdump` on the mediator
   during a shadow run). Provisional until both agree (D17).
3. **Build Option 2** with that policy, satisfying both preconditions: per-agent workload identity
   (R8.8, D6) and per-agent network isolation (D2). Native agent sandboxes enabled inside as
   defence in depth (D14).
4. **Test the boundary adversarially before any real work** (R12.8, D16). Everything before this
   validates that the allowlist is *sufficient*; nothing yet validates that the boundary is
   *effective*. Run T1–T20 and at minimum the six R12.8 scenarios. Record which injection sources
   from the threat model are exercised and which are not — on the current design the stdio MCP
   vector is not, because it never crosses the enforcement point.
5. Re-evaluate Option 3 only if the threat model changes.

> **M1's output must not be used for real work until M2 completes.** R12.8 places adversarial
> validation in M2. M1 produces a sandbox that works, not a sandbox that is proven.

### Observability

Four artifacts, produced by default, exported by default (R9.9, D11): the egress audit log, the
agent action log, the resolved egress policy, and the image digest plus SBOM. Recording is
mandatory and not profile-disableable; only export is.

Denials are surfaced to the operator with a clear message naming the blocked destination (R9.3,
R12.2), so a legitimate policy gap is distinguishable from an attack. Detection is **pull-based
by decision** — push alerting on denial remains MAY (R9.6), with the review trigger being a
blocked attempt going unnoticed long enough to matter.

### Reproducibility

The base image is built and published to GitHub Packages by GitHub Actions and consumed by
**digest, never by tag** (D21, R10.2). During the project the workflow builds from the working
branch and those images are for testing only; on project completion the workflow moves to `main`,
which is the point at which a published digest becomes usable for real work. CI is also where the
SBOM is emitted and where provenance attestation becomes practical (R10.7).

The environment is defined entirely in version-controlled files with no manual setup steps
(R10.1). Base image, agent versions and pack contents are pinned to versions or digests (R10.2);
auto-updaters are disabled so a pinned build stays pinned (R10.3). The image builds without
network access outside the declared build allowlist (R10.4). A documented update path re-verifies
the policy after each agent version bump, because agent egress requirements change between
releases (R10.6).

Third-party agent Docker wrappers are deliberately not depended upon — the 2025 cohort is largely
abandoned; the build uses vendor primitives (R10.5).

### Containment and response runbook

| Need | Action |
|---|---|
| Cut egress immediately | Denylist entry at the mediator, or detach the agent's network |
| Isolate one agent, others keep running | Stop that container. Per-agent networks (D2) make this native, not a special case (R13.2) |
| Disable one MCP server or tool across all agents | Profile inventory change plus rebuild. **No live mechanism exists** — recorded, not solved (R13.2 partially unmet) |
| Rotate credentials | Per credential type, per the tested revocation procedure with its stated maximum detection-to-revocation time (R13.1, R8.5). The one-year `CLAUDE_CODE_OAUTH_TOKEN` is the longest-lived and the priority |
| Return to known-good | Rebuild containers from the pinned digest and **discard the state volumes**, re-bootstrapping authentication. A contaminated volume cannot currently be distinguished from a clean one, so the documented path does not attempt to (R13.3, D16) |

Define what constitutes an event versus an incident before go-live.

## Security Considerations

### Threat model

The adversary is a **compromised or prompt-injected agent** running with permission prompts
bypassed, inside the container, with the operator's delegated authority. Explicitly *not* in the
model: a malicious operator, a compromised model provider, or container escape (which is what
Option 3 would buy — see D1).

### Trust boundary

Inside the blast radius, and therefore not a control: everything in an agent container — the
agent process, its native sandbox, its state volume, its capability-declaration files, and every
stdio MCP server it spawns. Outside it: the mediator, the egress policy, the mount set, the audit
sink, and the CA private key. R1.2 is the line, and R1.5 is what stops the line being redrawn by
granting `NET_ADMIN` to a container so it can firewall itself.

### Authentication and access control

Per-agent `AUTH_MODE` (D8) with per-agent state volumes (D7). Mutual TLS gives each agent a
distinct workload identity at the mediator (D6) — the precondition for both credential brokering
and audit attribution. AWS uses brokered short-lived credentials (Model B, D13); Model C is
prohibited outright (R6.5.1).

Host credential stores are never mounted except under a recorded per-agent decision naming the
file, mount mode, revocation path and blast radius (R4.8) — and never read-write (R4.13), never a
single file (R4.14), always copied to the volume for steady state (R4.15).

The host home directory, SSH private keys, GPG keys, browser profiles, password-manager stores
and cloud credential directories are never mounted (R2.4). `SSH_AUTH_SOCK` and forwarded sockets
are not among the available options at all (R2.8). Where host git config is mounted it is `:ro`
with `credential.helper` stripped first — an unfiltered gitconfig is a pointer into host
credential storage and would defeat R4.8 (R2.9).

### Accepted risks

Each is a decision with its consequence stated, not an open item.

| Risk | Requirement | Compensating position |
|---|---|---|
| `oauth-mount` from a second config directory on the operator's **own** provider account puts the whole account in the blast radius, with all-or-nothing revocation | R4.17 | R4.13/R4.14/R4.15 constrain the shape. Alternative modes remain available per agent. **Deliberate asymmetry with R6.5.1**, which prohibits the structurally identical Model C for AWS — differs by decision, not oversight |
| No content-level DLP anywhere in the architecture | R5.15 | TLS is spliced, so the mediator sees destinations, not payloads. Positioned to add termination later without redesign (R15.2). R5.13 keeps Antigravity permanently exempt on ToS grounds |
| Long-lived refresh tokens persist on state volumes; a one-year Claude Code token is available | R4.16 | Per-agent volumes (R4.3), secret handling (R4.7), tested revocation (R8.5, R13.1), backup exclusion (R8.7). Review trigger: brokered agent credentials becoming available from any provider |
| Exfiltration through legitimately allowlisted destinations cannot be prevented | Non-Goal | Structural. An agent allowed to reach GitHub can push to GitHub. Narrowed allowlist plus audit bounds and detects it; nothing eliminates it |
| Prompt injection itself is not mitigated | Non-Goal (R15.1) | No component inspects agent input. The architecture bounds consequences rather than preventing the injection. R15.2 keeps the seam for a later tool-call mediation layer |
| Recovery to known-good is the weakest of the three options | D1, R13.3 | Accepted in exchange for L7 FQDN correctness, extensibility and a self-owned audit trail. Mitigated by the discard-and-rebootstrap path (D16) |

### Controls this architecture does not provide

Stated so an absent control is not mistaken for a satisfied one. On every row, all three evaluated
options score identically: **absent**.

| Control | Why absent |
|---|---|
| Input inspection / prompt-injection filtering | Non-goal — three third-party agents' input pipelines are not ours to instrument |
| Deterministic mediation of agent *actions* rather than packets | No option intercepts a tool call. Writing to a bind mount, `git push`, `terraform apply` are unmediated everywhere |
| stdio MCP tool-invocation visibility | The transport never crosses a network. R7.15 requires the inventory to *state* which enforcement point covers each server — or that none does |
| Agent action log that is tamper-resistant **at source**, or attributable to a specific agent | R9.7 is carried by shipping the agent's own transcript (D20), so an action log exists — but the agent authors it, and attribution requires per-agent identity (R8.8). Until both land, the record is complete-as-written and says what happened, not who did it |
| Content-level DLP on the model API channel | Follows from D4's splice-only decision |
| Human approval on a novel destination | Unattended operation is assumed (A2). Option 2 is the only evaluated option that *could* host this later |

**Honest summary:** this architecture bounds what a compromised agent can reach and records where
it tried to go. It does not detect the compromise, constrain what the agent does inside the
boundary, or attribute an action to an agent until R8.8 lands.

## Gate 1 Deferred Items

Gate 1 approved `prd.md` on 2026-09-03 and recorded three items as unresolved, naming `/design`
at Gate 2 as "the next catch point." All three are resolved here.

### 1. Cross-reference integrity — **clean**

Every requirement, success-criterion and test ID cited in `prd.md`, `docs/OPTIONS_ANALYSIS.md` and
`docs/STANDARDS_MAPPING.md` was checked mechanically against `REQUIREMENTS.md`: 78 distinct R-IDs
cited against 171 defined. Three citations resolved to something other than a table row and were
verified individually rather than reported as dangling:

- **R6.3** and **R6.5** are subsection headers (`### R6.3 — Least privilege and blast radius`,
  `### R6.5 — Credential delivery model`) with 10 and 6 child requirements respectively. Group
  references are valid.
- **R15.1** is deliberately absent from the R15 table and recorded in Non-Goals instead, with an
  explicit note in the register saying so. Intentional, and correctly cited everywhere.

**Result: zero genuine dangling references.** T1–T20 are all defined; all SC-1…SC-8 citations
resolve.

### 2. The three suspected contradiction pairs — **none is a contradiction**

Each pair is self-reconciling in the register text. Each nevertheless forces a structural
obligation, which is why each appears above as a design decision rather than merely a note.

| Pair | Finding | Obligation it forces |
|---|---|---|
| **R4.17** vs R4.8 / R4.13 / R2.4 / R6.5.1 | Not a contradiction. R4.8 already carries the clause "except under a recorded per-agent decision"; R4.17 *is* such a decision. R2.4 bars the host home directory and **cloud** credential directories — R4.17 mounts a dedicated provider-config directory, which R4.14 requires anyway. The asymmetry with R6.5.1 is named inside R4.17 itself and was accepted at Gate 1 | The `oauth-mount` path must be *structurally* incapable of violating R4.13 — read-only bootstrap, copy to volume, never read-write. See D8 and the auth bootstrap flow |
| **R7.18 / R7.19** vs R7.7 / SC-8 | Not a contradiction. R7.19's own text states it "is what keeps R7.7, R7.16 and SC-8 satisfiable once R7.18 exists." Pinned, build-time-only installation from a declared repository preserves both checksum verification and reproducible rebuild | **The profile drives the image build, not only the run.** Each profile therefore pins to a distinct image digest. This is D10, and it is the least obvious consequence in the whole register |
| **R9.9** vs R9.1 / R9.7 | Not a contradiction. R9.9 states the export/recording distinction explicitly and defers to R9.1 and R9.7 for the mandatory part | The recording path must be wired independently of the profile's export toggles, so no profile setting can switch recording off. This is D11 |

### 3. Acceptance-test coverage for requirements added at Gate 1 — **extension proposed below**

Gate 1 recorded "26 new requirements" with no test coverage. The measured delta between the
pre-Gate-1 register (commit `d303b55`) and the approved one (`442952c`) is **30 newly defined
requirements**, none removed — 126 rows to 156. The count of 26 was an undercount by four. The
matrix `T1–T20` was not extended in that commit and still covers none of them.

> **Scope note.** `/design` writes this document, its review checklist and `progress.txt`. It does
> not write `REQUIREMENTS.md`, which is the authoritative register. The extension below is
> therefore a **proposal recorded here**, not an edit to the register. Applying `T21`–`T44` to
> `REQUIREMENTS.md` § Acceptance Test Matrix is a follow-up action requiring approval.

## Requirements Traceability and Test Extension

Each of the 30 requirements added at Gate 1, the component that implements it, and the proposed
acceptance test. Numbering continues from the existing matrix.

| Proposed test | Method | Passes when | Covers | Component |
|---|---|---|---|---|
| **T21** Optional mounts default-off | Start the default profile; enumerate mounts inside each agent container | Only the project directory and that agent's state volume are present. No socket is forwarded | R2.8 | Profile, compose |
| **T22** Git config scrubbing | Enable the host gitconfig mount; inspect it inside the container | Mounted `:ro`; no `credential.helper` entry present | R2.9 | `bootstrap-auth.sh` |
| **T23** Per-agent build cache | Enable the build cache for two agents; write from one | Caches are distinct paths; neither agent can write the other's | R2.10 | Profile, volumes |
| **T24** `AUTH_MODE` matrix | For each agent, run each mode it supports, headless | Each authenticates with no interactive terminal, and the default is the safest mode that agent supports | R4.12 | Entrypoint |
| **T25** Credential mount shape | Under `oauth-mount`: inspect the mount, then force an OAuth refresh | Mount is `:ro`, is a directory not a file, and the refreshed credential lands on the state volume with the host file unchanged | R4.13, R4.14, R4.15 | `bootstrap-auth.sh` |
| **T26** Long-lived token inventory and revocation | Enumerate persisted refresh tokens; execute the documented revocation for each type and time it | Every persisted token is inventoried with its compensating controls named; revocation succeeds within the stated maximum time | R4.16, R13.1 | State volumes, runbook |
| **T27** `oauth-mount` risk recording | Enable `oauth-mount` in a profile that does not record the accepted-risk decision | The build or startup refuses until the decision is recorded with file, mount mode, revocation path and blast radius | R4.17 | Profile, policy compiler |
| **T28** TLS splice verification | Inspect the destination certificate chain from inside each agent container; attempt to read plaintext at the mediator; confirm no mediator CA appears in any destination chain | No mediator CA appears in any **destination** TLS chain; the mediator holds no plaintext; Antigravity traffic is never intercepted. **Recorded exception:** the single proxy-hop trust anchor -- `claude` and `agy` trust the mediator CA for the agent->mediator hop only (`NODE_EXTRA_CA_CERTS` / `SSL_CERT_FILE`); `codex` trusts no mediator CA at all | R5.15 (and R5.13) | Mediator |
| **T29** MCP inventory and drift | Add an uninventoried MCP server; then change an inventoried server's capabilities | The uninventoried server is refused; the capability change is reported as drift, not silently accepted | R7.14 | Profile |
| **T30** MCP transport declaration | Inspect the inventory for every configured server | Each records its transport and names the enforcement point covering it — or explicitly states that none does | R7.15 | Profile |
| **T31** MCP install channel | Attempt `npx <server>` for a server not in the pinned registry | Refused. No wholesale package-registry egress entry permits arbitrary server installation | R7.16 | Profile, policy |
| **T32** Capability-declaration integrity | From inside each agent, attempt to write that agent's MCP capability declaration file | Blocked for Claude Code via `srt`. For agents where it is not blocked, the test records the gap rather than passing | R7.17 | State volume, `srt` |
| **T33** Build-time-only packages | Inspect installed package versions; then attempt a package install as the agent user at runtime | Versions match the profile pins and the declared repository; the runtime install fails for want of both privilege and write access | R7.18, R7.19 | Image build |
| **T34** Per-agent workload identity | Present agent A's client certificate for a credential bound to agent B; inspect audit lines | Cross-binding is refused; every audit line carries the issuing agent's identity | R8.8 | Mediator identity |
| **T35** Agent action log | Perform a tool invocation and a file modification in a session; inspect the sink. Then edit the on-volume transcript retroactively and re-inspect | Both actions are recorded outside the agent's blast radius and correlate with the egress log by session ID and timestamp. The retroactive edit does **not** propagate to the sink — confirming tamper-evidence, which is the property D20 claims, rather than tamper-resistance, which it does not | R9.7, R9.8 | Agent action recorder, audit sink |
| **T36** Export toggle cannot disable recording | Disable each of the four exports in turn; inspect the sink | Recording continues in every case; each disabled export is explicitly recorded | R9.9 | Policy compiler, audit sink |
| **T37** Human authorization gate | Attempt an action the profile classifies as irreversible or high-impact, unattended | The action halts for authorization, or the profile carries an explicit recorded waiver | R12.7 | Profile |
| **T38** Adversarial validation gate | Run `validate-boundary.sh` before first real use | All six R12.8 scenarios execute, and each records whether the attempt was blocked, logged and attributable | R12.8 | `validate-boundary.sh` |
| **T39** Entry point | Bring the environment up as a fresh operator following the README | `docker compose` with a profile override is the only entry point; no wrapper CLI exists | R12.9 | Compose, README |
| **T40** Single-agent isolation | Stop one agent container; then disable one MCP server | The other two agents continue unaffected. The MCP disable path is exercised and its current rebuild requirement recorded | R13.2 | Compose, profile |
| **T41** Return to known-good | Execute the documented recovery path on a deliberately contaminated environment | The path completes and states explicitly what happened to each persistent state volume | R13.3 | Runbook |
| **T42** Third-party traffic-path governance | Inspect the record for every third party on the agent traffic path | Each records what it observes, its retention period and its breach-notification path — or records the constraint on use where the assessment could not be completed | R14.1 | Documentation |
| **T43** Provider governance record | Inspect the per-provider record | Each of the three records version-pinning capability, retention and training-opt-out settings in use, and the data classification permitted to leave | R14.2 | Documentation |
| **T44** ToS monitoring and mediation seam | Simulate a provider terms change; separately, inspect the mediator's extension points | The change triggers re-review of the affected access route; the mediator can host a tool-call mediation layer without redesign | R14.3, R15.2 | Process, mediator |

| **T45** Published base image provenance | Resolve the image the compose file consumes; compare against the GHCR-published digest and its SBOM | The image is pinned by digest and matches a CI-published build with an SBOM. No profile consumes a mutable tag, and no branch-built image is consumed outside testing | R10.2, R10.7 | GitHub Actions, GHCR |

**Coverage: 30 of 30 requirements added at Gate 1.** T45 is additional — it arises from D21 (the
Gate 2 decision to publish the base image via CI) and covers pinning and provenance for the
published artifact, which no existing test reached.

## Open Items Carried Into Build

These are open by decision or by dependency. None blocks Gate 2; each blocks something specific
downstream, named here so it is not discovered late.

| Item | Status | Blocks | Owner |
|---|---|---|---|
| **Q1** — which AWS accounts and services the agent must reach | Open | Whether R6.4.3 bucket-level allowlisting is practical. Sits inside M1 | Operator |
| **Q9** — whether a dedicated Identity Center principal can be created | Open | **The entire AWS CLI pack.** Model B needs a principal to broker from; Model A needs a dedicated Identity Center user or group (R6.5.2 MUST); Model C is prohibited (R6.5.1). A negative answer leaves no compliant model, and M1 includes the AWS pack — see D13a. Sits inside M1 | Operator's organisation |
| **Open Decision 3** — Docker Sandboxes retention and data-handling terms | **Incomplete, constrained (01.1 SF-1, 2026-09-04).** Docker's own docs neither confirm nor deny that the `sbx` proxy decrypts traffic, and publish no retention, deletion, or breach-notification terms. See `docs/records/third-party-assessments.md` | Only a discovery run against a *representative* repository. The synthetic-repo + throwaway-credential constraint is the mitigation (D17) — unconditional on whichever reading of "does it decrypt" is correct | Recorded, 01.1 SF-1 |
| **Antigravity ToS position** | **Resolved (01.1 SF-1, 2026-09-04) — owner named.** Interpretation itself remains explicitly unofficial; Google declined to clarify | Nothing today. Review trigger: Google clarifies, the terms change, or public-API billing becomes material (R14.3) | **Ottawa Cloud Consulting** |
| **`agy` + `GEMINI_API_KEY` route** | **Resolved (01.1 SF-2, 2026-09-04) — confirmed working** on `agy` 1.1.26 with `"modelProvider": "gemini"` set; the June 2026 maintainer statement is superseded. See `docs/records/agent-verification.md` | Was D9's default, gated on this — no longer gated | Recorded, 01.1 SF-2 |
| **Whether `agy` honours `HTTPS_PROXY`, and its CA-trust mechanism** | **Resolved (01.1 SF-2, 2026-09-04) — yes, both proxy schemes; CA-trust via `SSL_CERT_FILE`.** D1 is not blocked for `agy`. See `docs/records/agent-verification.md` | Was D1 itself for `agy` — no longer gated | Recorded, 01.1 SF-2 |
| **Whether any agent can present a client certificate to a TLS proxy listener** | **Resolved (01.1 SF-2, 2026-09-04) — not uniform.** `claude`: yes (`CLAUDE_CODE_CLIENT_CERT`/`_KEY`, confirmed). `codex`: no — structural; rejects an `https://`-scheme proxy URL at parse time, before any TLS attempt. `agy`: no — reaches the TLS `CertificateRequest` stage but has no cert to offer. See `docs/records/agent-verification.md` | **R8.8's mechanism is not uniformly redesigned**, but 01.3 needs either a non-TLS-clientcert path or an alternative identity mechanism for codex and agy specifically — codex cannot use an HTTPS-scheme mediator listener at all regardless of certificate support | 01.3 design decision |
| **T28 vs. a TLS proxy hop** | **Resolved by amendment (01.3 SF-3, 2026-09-06).** T28's original pass text ("no mediator CA is presented to any agent") and criterion 6's TLS proxy hops for `claude` and `agy` are mutually exclusive. `REQUIREMENTS.md` T28 now reads "no mediator CA in any **destination** TLS chain", with the single proxy-hop anchor as a recorded exception. R5.13 and R8.8 untouched | Was: SF-6/SF-8's T28 assertion had no satisfiable form. Now blocks nothing | Recorded, 01.3 SF-3 |
| **Where the CA private key lives** | **Narrowed (01.3 SF-3, 2026-09-06).** This document's "CA private key injected at runtime from a secret manager" is superseded: the key is created and used only on the operator host by `scripts/issue-identity.sh` and never enters the mediator. Moves in the safer direction — a mediator compromise yields no ability to mint agent identities. See `mediator/identity/README.md` | 01.6 inherits this lifecycle and this CA; it does not create a second one | Recorded, 01.3 SF-3 |
| **ICC driver_opts key name** | UNVERIFIED | Nothing — D2 uses per-agent networks precisely to avoid depending on it | — |
| **Default MCP transport per agent and per server** | **Resolved (01.1 SF-2, 2026-09-04) — no forced default; per-server, per config-entry key.** stdio egress has no application-layer enforcement point; covered only by 01.3's pod network-namespace-level enforcement. See `docs/records/agent-verification.md` | Was: determines whether any MCP traffic crosses the enforcement point at all — answered: HTTP/SSE MCP traffic follows the agent's own proxy behaviour above; stdio MCP traffic does not cross any app-layer point | Recorded, 01.1 SF-2 |
| **`agy` version-pinning capability** | **Resolved (01.1 SF-2, 2026-09-04) — none.** Installer always fetches the live manifest; no version/channel flag. Confirmed empirically (a build minutes apart from a host install pulled a newer version). See `docs/records/agent-verification.md` | 01.2's Dockerfile for `agy` cannot pin the way `codex`/`claude` can — must vendor a specific binary at build time or re-verify after every rebuild (R10.6) | 01.2 design decision |
| **D17 — egress allowlist seed and denylist** | **Recorded, provisional (01.1 SF-3, 2026-09-04).** `policy/allowlist.base.yaml` and `policy/denylist.base.yaml` committed; seeded from a real `sbx` discovery capture, cross-validated for `agy` fully and `codex`'s primary host, single-source for three secondary hosts and for `claude`'s only entry. See `docs/records/egress-discovery.md` | 01.2/01.3 consume these files. Not yet resolved: `claude`'s entry lacks a second source (see next row); UDP/ICMP blind spot applies to all three | Recorded, 01.1 SF-3 |
| **Whether `agy` can run under `sbx` at all** | **Resolved (01.1 SF-3, 2026-09-04) — yes.** No first-class `sbx` template exists for `agy` (only `gemini`, a different tool), but `agy` installs and executes successfully inside a generic `sbx` `shell` sandbox — not structurally barred, only lacking a template. See `docs/records/egress-discovery.md` | Was the plan's worst-case edge case (verbose-log-only fallback for `agy`); did not materialize — `agy`'s allowlist entries are fully cross-validated via a real `sbx` capture, same as `codex` | Recorded, 01.1 SF-3 |
| **`sbx` first-party kits can bypass the operator's own network policy** | **New finding (01.1 SF-3, 2026-09-04).** `sbx`'s `claude-code-docker` template bakes in a non-removable allow rule for 6 Anthropic-family hosts regardless of the global `deny-all` policy; the generic `shell` template does the same for `openrouter.ai` (a non-approved 4th provider). `codex-docker` carries no such rule. See `docs/records/egress-discovery.md` | Limits `sbx` as a *discovery* tool: it can confirm a host is used, but cannot prove a kit-covered host is unneeded, since it is never actually blocked-and-observed. Does not affect 01.3's own mediator (a separate, custom-built component) | 01.3 design awareness |
| **`sbx` first-party templates bundle their own agent version, independent of operator pins** | **New finding (01.1 SF-3, 2026-09-04).** `claude-code-docker` and `codex-docker` shipped `2.1.246`/`0.149.1` against SF-2's pins of `2.1.260`/`0.152.1`. No template flag selects a version; re-pinning in place worked (`claude install <version>`; `npm install -g @openai/codex@<version>`) but is a manual step per capture. See `docs/records/egress-discovery.md`, "Correction" | If `sbx` is ever considered as a *runtime* substrate (not just a discovery tool), R10.6's version-pin requirement needs an explicit re-pinning step per template refresh — the template will otherwise drift silently | 01.2/01.3 design awareness, if `sbx` is ever proposed as more than a discovery tool |
| **Per-session refresh-token revocation, per provider** | UNVERIFIED | Whether a second config directory on the same account is meaningfully separable. Until confirmed it is not — which is what makes R4.17 an accepted risk rather than a mitigation | Build |
| **Refresh-token rotation semantics, per provider** | UNVERIFIED | The failure most likely to make a host-credential mount unworkable in daily use regardless of security posture. Belongs in the test plan | Build |
| **CIS Docker Benchmark 1.8.0 Container Runtime section** | Not extracted | A per-recommendation applicability table against R1 | Documentation |
| **`README.md` drift** | Stale | Its "Out of Scope" section still lists `prd.md`, `progress.txt` and `docs/ARCHITECTURE_AND_DESIGN.md` as deliberately not produced. All three now exist. Correct at M1 start | Documentation |
