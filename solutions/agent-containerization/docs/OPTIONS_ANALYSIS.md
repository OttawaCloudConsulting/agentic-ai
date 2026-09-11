# Options Analysis — Sandboxed Agent Containerization

Three architectural options for running Claude Code, OpenAI Codex, and Google Antigravity (`agy`) inside a sandboxed container with a minimal blast radius.

Supporting evidence, version numbers, exact paths and citations are in [`RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md). This document is the decision material.

**Research date:** 2026-09-02. **Revised 2026-09-03** after an adversarial review against four published standards — see [`red-team/options-analysis-01/`](red-team/options-analysis-01/CONSOLIDATED-REPORT.md) for the 28 findings and [`DISPOSITION.md`](red-team/options-analysis-01/DISPOSITION.md) for how each was handled. The recommendation is unchanged; several of the reasons given for it were wrong and have been rewritten, and the comparison table has been corrected on four axes where it overstated the design.

## Contents

- [Design Constraints](#design-constraints)
- [Option 1 — Managed microVM (`sbx`)](#option-1--managed-microvm-sbx)
- [Option 2 — Compose pod with egress mediator](#option-2--compose-pod-with-egress-mediator)
- [Option 3 — Per-agent microVM, host-enforced egress](#option-3--per-agent-microvm-host-enforced-egress)
- [Comparison](#comparison)
- [Controls No Option Provides](#controls-no-option-provides)
- [Cross-Cutting Concerns](#cross-cutting-concerns)
- [Security Warning — Antigravity Terms of Service](#security-warning--antigravity-terms-of-service)
- [Open Decisions](#open-decisions)
- [Recommendation](#recommendation)

## Design Constraints

### The three agents are not symmetric

| Agent | Container artifact | Notes | Integrity at build time |
|---|---|---|---|
| Claude Code | `npm i -g @anthropic-ai/claude-code` (Node) | Refuses to start as root with `--dangerously-skip-permissions`; container must run non-root | Pin the exact version and commit a lockfile; rely on its integrity hash. A bare `npm i -g` resolves to whatever is current that day |
| OpenAI Codex | Static musl binary (Rust) | Trivial to put in a distroless image | Fetch the released `codex-*-unknown-linux-musl.tar.gz` and verify its published checksum |
| Google Antigravity | `agy` Go binary | Headless mode is first-class; do **not** containerize the desktop GUI | **Do not use the install script.** Fetch the released binary and verify it by checksum, per `REQUIREMENTS.md` R7.7 |

All three sit on a digest-pinned base image. The first version of this table recorded acquisition as a packaging detail and named an install script without comment. That sits badly against R7.7 (contents "verified by checksum or signature", with `curl | bash` prohibited at runtime), R10.2 (versions and digests pinned) and R10.3 (auto-updaters disabled, "so a pinned build stays pinned") — the strongest enforcement boundary is worth nothing if the thing inside it was substituted before the boundary existed.

### stdio MCP servers execute inside the blast radius under all three options

Every enforcement point below is a network mediator. MCP has two common transports, and only one of them crosses a network at all: Streamable HTTP does, stdio does not. A stdio MCP server is a subprocess of the agent, running inside the sandbox, exchanging JSON-RPC over `stdin`/`stdout`. Its tool calls, tool results and capability negotiation are invisible to the `sbx` proxy, to the Option 2 mediator, and to host `pf`/`nftables` alike. Only the server's own subsequent outbound HTTP calls are visible, and those are indistinguishable from the agent's.

Containerizing the agents does satisfy the MCP guidance's strongest stdio recommendation — that stdio servers run inside a sandboxed execution boundary — so the *confinement* is right. The *visibility* is absent in all three options, and no option should be selected on the belief that its audit trail covers the MCP path. It does not.

### Threat model

The primary threat is not a malicious user — it is a **compromised agent**. Specifically, and stated in the order the harm actually occurs:

**The compromise.** Indirect prompt injection, from a repository, a web page, a dependency, or an MCP server. The MCP surface is wider than a hostile tool *result*: tool names, descriptions and parameter schemas are ingested during capability negotiation, before any tool is invoked, and the model chooses which tool to call based on them. That makes **tool poisoning** (malicious instructions in tool metadata), **tool-name shadowing**, and the **rug pull** (a server benign at approval time, malicious after) injection vectors that no filter on tool output would ever see.

**The harm.** Exfiltration of data, and lateral reach to systems and peers the agent should not touch.

**None of the three options below mitigates the compromise. All three bound the harm.** This is the single most important thing to understand about this document, and the first version of it did not say so. Nothing in any option inspects an input, separates privileged instructions from untrusted content, or validates a tool call before execution. The agent, once injected, still executes the injected instruction — it reads its credential volume, rewrites the project, and calls the tools it holds. What the architecture constrains is where the result can be sent and how far the agent can reach.

The primary threat this document designs against is therefore **exfiltration and lateral reach by an already-compromised agent**. That framing is defensible and matches what the options actually do.

Two consequences drive every option below:

1. The agent has legitimate outbound network access (it must reach its model API), so egress control must be selective, not binary. Note that this leaves the highest-bandwidth exfiltration channel — the model API itself — open by necessity in every option.
2. The agent runs arbitrary code by design, so any control the agent process can itself modify is not a control. **The enforcement point must sit outside the blast radius.** This is the axis on which the three options differ most, and the one this analysis weighs most heavily. It is not the only axis on which they differ, and it says nothing about controls none of them have — see [Controls No Option Provides](#controls-no-option-provides).

### Non-goal — ingress filtering

Input inspection, prompt-injection filtering, context-boundary enforcement and deterministic tool-call mediation are **out of scope for this iteration**, and their absence is a deliberate, recorded decision rather than an oversight.

The reason is that we consume three third-party agent products. Their input-handling pipelines are not ours to instrument, and building a guardrail layer that intercepts every action across three different agent harnesses is a substantially larger undertaking than the sandbox itself. The residual risk is that a successful injection is neither prevented nor detected at the point of injection; it is bounded afterwards, and visible only if it attempts a blocked destination.

Recorded as gap G9 in [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md). The relevant Safeguards are CIS AI/LLM §16.10 and §16.11, and CIS AI Agents §16.10, §9.3, §9.6 and §10.1. Where an option can host such a layer later, that is a point in its favour and is scored in the comparison.

### Assumption — unattended operation

Every option assumes the agent runs unattended with permission prompts bypassed. That is the reason the sandbox exists, and it is a deliberate deviation from published guidance: Five Eyes L723–724 names "network egress" explicitly as a class of action warranting a human approval checkpoint.

The compensating control is that egress is constrained by policy rather than by a prompt. The gap this leaves is that no option as specified can hold a connection and ask an operator about a novel destination — though one of them could be extended to, which the comparison now scores.

### Enforcement point per option

| Option | Where policy is enforced | Can a compromised agent modify it? |
|---|---|---|
| 1 | Vendor proxy + microVM, outside the guest | No |
| 2 | Separate container, separate network namespace | No — no route to it except as a proxy client |
| 3 | Host kernel / hypervisor, outside the guest kernel | No — survives a guest kernel escape |

For contrast, the vendor reference devcontainers enforce with `iptables` **inside** the agent's own container, requiring `NET_ADMIN` and `NET_RAW`. That is weaker than any of the three below, and is why none of the options simply adopt it as-is.

## Option 1 — Managed microVM (`sbx`)

Docker Sandboxes. Enforcement sits in the vendor's proxy and hypervisor, outside the guest.

### Shape

- Standalone Homebrew CLI. **Does not require Docker Desktop or Docker Engine.** v0.38–0.39 as of Aug 2026.
- On Apple silicon, launches Arm Linux (Ubuntu) microVMs via Apple's Virtualization framework. Requires macOS 14+.
- `sbx run claude`, `sbx run codex`, `sbx run gemini`, `sbx run shell`. Supported agents: Claude Code, Codex, Copilot, Cursor, Docker Agent, Droid, Gemini, Kiro, OpenCode, Shell.
- Only the project workspace is mounted into the sandbox.
- Docker-in-Docker works inside the microVM with no access to the host Docker daemon.

### Egress policy

```bash
sbx policy init balanced
sbx policy allow network "api.anthropic.com,*.npmjs.org,*.pypi.org"
sbx policy deny  network "169.254.169.254,10.0.0.0/8"
```

- Resources accept hostnames, wildcard subdomains (`*.example.com`), IP addresses, **CIDR ranges**, and optional port suffixes (`example.com:443`).
- **Deny rules always take precedence over allow rules.**
- Presets: `open` (allow all), `balanced` (default-deny plus a baseline allowlist of AI provider APIs, package managers, code hosts, registries), `locked-down` (nothing leaves, including model provider APIs).
- **Scope is global by default**; `--sandbox <name>` scopes a rule to one sandbox. Under the default, every agent receives the union of all three agents' allowlists — so the per-sandbox isolation this option offers is a filesystem and VM property, not an egress-policy one. Every rule must be `--sandbox` scoped for per-agent egress policy to exist at all.
- Only HTTP/HTTPS is fully intercepted through the proxy. Non-HTTP TCP (including SSH) can be permitted with a hostname rule.
- **UDP and ICMP are blocked at the network layer and cannot be unblocked by policy.** This closes the DNS-exfiltration hole by construction — no other option gets this for free.

### The vendor is a service provider on the traffic path

This option interposes a closed-source third party that terminates HTTP/HTTPS for all agent traffic. The first version of this document assessed that vendor on two dimensions — auditability and lock-in, and the Antigravity terms-of-service question — and never as a provider that will see prompts, source code, tool output and credential-bearing headers in the clear.

That is the wrong order of operations. Published guidance (CIS AI Agents §15.5, §15.1) asks for the assessment *before* integration: what the provider can observe, its runtime isolation between tenants, its retention period, its deletion guarantees, and its breach-notification path.

**That assessment has not been done, and the terms are not established.** Two consequences follow, and both are load-bearing:

- Docker Sandboxes should be treated as an unassessed processor of decrypted agent traffic until the retention and data-handling terms are read.
- The proving-ground run in the sequence below is therefore constrained: synthetic repository, throwaway credentials, no production code. It was originally written as "a representative repository", which would have routed real source and real credentials through an unassessed third-party MITM proxy as the very first step.

This is recorded as an open decision below and as gap G8 in [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md).

### Assessment

| Pros | Cons |
|---|---|
| Working sandbox in hours | **Antigravity is not a supported agent** — run `agy` under `sbx run shell` or a custom image |
| Vendor-maintained; org-level policy governance available | CLI is closed-source (the public repo is a release and issue tracker) |
| Hypervisor boundary, not just namespaces | Requires a Docker Hub account to authenticate |
| DNS/UDP exfiltration closed by construction | macOS and Windows only; Linux hosts listed as "what's next" |
| Native allow **and** deny lists with CIDR support | Docker's proxy terminates HTTP/HTTPS — see the Antigravity ToS warning below |

## Option 2 — Compose pod with egress mediator

Agent containers on an isolated network with no route out; a single sidecar is the only path to the internet.

### Shape

```text
[claude] ── claude-net ─┐   each internal: true — no default route, no DNS to internet
[codex]  ── codex-net  ─┼── [egress-mediator] ── external network ── internet
[agy]    ── agy-net    ─┘     multi-homed onto all three agent networks
                              iron-proxy (Go, Apache-2.0) or Squid CONNECT-allowlist
                              + authoritative DNS resolver for the pod
                              + per-agent client identity (mTLS)
```

**One network per agent, not one shared network.** This is a correction. The first version of this document placed all three agents on a single `agents-net` and claimed "Cross-agent isolation: Per container". That claim was false: `internal: true` removes the default route to the internet, but Docker bridge networks by default "allow unrestricted communication between containers on the same bridge" (Docker's own bridge-driver documentation). A compromised Claude Code container could reach the Codex and Antigravity containers directly on any port, and the mediator would never see it, because the traffic never left the segment.

The three agents do not hold symmetric privilege — the Antigravity container may hold only a `GEMINI_API_KEY` while the Claude container holds a one-year OAuth token — so a compromised low-value agent reaching a high-value peer is a real escalation path, not a theoretical one.

The remedy used here is verified against Docker's documentation: containers on separate bridge networks "cannot communicate with each other by name or IP address", and a container reaches multiple networks only by being explicitly attached to each. The mediator is attached to all three; the agents are attached to one each.

An alternative is a single network with inter-container connectivity disabled via the bridge driver's ICC option (`com.docker.network.bridge.enable_icc`, passed through `driver_opts`). The `driver_opts` mechanism is confirmed and the bridge driver does expose an inter-container-connectivity option, but the exact key name is **UNVERIFIED** here — confirm it against the Docker version in use before relying on it. Per-agent networks need no such confirmation, which is why they are the primary form.

- Agent containers: `cap_drop: ALL`, `security_opt: no-new-privileges`, read-only root filesystem with `tmpfs` for scratch, non-root user, project directories bind-mounted (`:ro` where the agent does not need to write).
- **Resource limits** (`deploy.resources`): CPU, memory and PID ceilings per agent. Not optional decoration — without them a prompt-injected agent stuck in a loop exhausts the host and burns the model subscription while generating only allowlisted traffic the design logs as normal. Option 3 gets these for free from its VM boundary; Option 2 must declare them.
- **Inbound listeners bind `127.0.0.1`.** Any MCP HTTP listener binds loopback only, with Origin validation enabled and SDK DNS-rebinding protection explicitly turned on — both the TypeScript and Python MCP SDKs ship with rebinding protection *off* by default (CVE-2025-66414, CVE-2025-66416).
- One container per agent, one state volume per agent. Claude Code cannot read Codex's `auth.json` — a filesystem property, and with per-agent networks it is now a network property too.
- **DNS is served by the mediator.** The agent networks have no route to port 53 on the internet, so DNS tunnelling is structurally impossible rather than merely filtered. This is the fix for the hole in both vendor reference firewalls.
- Each agent's own native controls are layered inside as defence in depth: `srt` for Claude Code, `features.network_proxy` for Codex, `agy --sandbox` for Antigravity. **All three are reachable by the agent process**, so by this document's own principle none is a control — they are worth enabling and worth nothing as a boundary. One of them has a property worth naming specifically: `srt` hard-denies writes to `.mcp.json`, `.claude/commands` and `.claude/agents` at the project root, which is a partial mitigation for the configuration-integrity problem below. It covers Claude Code only.

### Preconditions

Two of these must be true before Option 2 is built. They are not enhancements.

**Per-agent identity at the mediator.** Credential brokering without caller authentication is worse than no brokering at all. A mediator that injects an upstream credential because "a request arrived from the pod network" hands every agent every brokered credential — a compromised Claude Code container no longer needs to read Codex's `auth.json`, it just sends the request and the mediator attaches the OpenAI token for it. Because the mediator is also the policy decision point, the resulting audit records look legitimate. This is a textbook confused-deputy pattern.

Therefore: each agent container is issued a distinct client certificate or workload identity; the mediator requires mTLS; each brokered credential is bound to exactly one client identity and cross-binding is refused; the client identity is recorded on every audit line. **Until this exists, brokering is mutually exclusive with a shared agent network, and only one agent may be brokered per pod.** Recorded as gap G3 in [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md).

**Network isolation between agents**, per the topology above.

### Mediator hardening

The mediator holds the brokered credentials for all three agents, terminates TLS wherever interception is used, holds the CA private key, serves DNS for the pod, and writes the audit log. It is the single component whose compromise yields everything. The first version of this document specified hardening for the agent containers in precise detail and none at all for the mediator.

- `cap_drop: ALL`, `no-new-privileges`, read-only root filesystem, non-root user — the same baseline the agent containers get.
- Its secrets and CA private key are injected at runtime from a secret manager, not baked into the image and not stored on a volume an agent can reach.
- It exposes exactly one port to each agent network — the proxy listener — and nothing else. It does not expose a management or metrics port to the agent networks.
- **The audit log is written inside the mediator or shipped directly off-host. It is never written to a volume shared with an agent container.** Five Eyes L658 makes this a control in its own right: "Isolate agents into enclaves with no write access to logs." A log the agent can edit is not evidence.

### Egress policy

Three independent controls, in order:

1. **Allowlist** of domains (exact and wildcard) and CIDRs, evaluated at CONNECT/SNI.
2. **Post-resolution CIDR denylist** — even for an allowlisted domain, the connection is refused if the resolved IP falls in a blocked range. This catches CDN IP rotation and DNS rebinding, which an `ipset` snapshot built at container start cannot.
3. **Per-agent rate and concurrency limits.** The mediator already terminates and rewrites requests, so the hook point exists. Without it, nothing bounds a runaway loop against the model API — a cost-exhaustion failure that generates only allowlisted traffic and so is invisible to controls 1 and 2. Network controls cannot detect semantic cost.

Cloud metadata (`169.254.169.254`), loopback, and private ranges are blocked by default in `iron-proxy`.

Optional **credential brokering**, subject to the per-agent identity precondition above: long-lived tokens live in the mediator and are injected as upstream headers, so the agent container never holds *that* secret. `codex-responses-api-proxy` is a ready-made primitive for this on the OpenAI side — it forwards only `POST /v1/responses` and 403s everything else.

**Brokering covers the model-provider API only.** A proxy that 403s everything except `POST /v1/responses` brokers nothing for a GitHub, Jira, database or cloud MCP server; those credentials still live in the agent container. The pattern extends per-destination, but each extension is a design decision to be recorded, not an automatic property. Any unqualified claim that tokens "never enter the agent container" stops being true the moment an MCP server with a downstream integration is added.

**What the log actually contains.** Every attempted destination is logged. You see an outbound attempt to a non-allowlisted destination; you do **not** see what caused it. There is no session identifier, no agent identity, no tool call and no command in that record — package-manager fetches, model API calls and injected tool fetches all arrive as an undifferentiated CONNECT stream from one source IP. This is a destination log, not an agent action log, and closing that gap requires per-agent identity first (see [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md) G1 and G3).

### Assessment

| Pros | Cons |
|---|---|
| The only option where FQDN rules work correctly (L7 CONNECT/SNI inspection) | You own and maintain it. Days, not hours — and the identity work in Preconditions is part of that, not an extra |
| Allowlist + denylist + post-resolution CIDR deny | Splice-only gives domain granularity; URL-path rules require TLS MITM and CA distribution |
| Identical on macOS and Linux hosts | Codex defaults to **WebSocket** transport — the proxy must permit `Upgrade` on 443 or streaming silently degrades to HTTP/SSE |
| Destination-level audit trail, self-owned. Not an agent action log | More moving parts than a managed product |
| Credential brokering keeps the model-provider token out of the agent container, given per-agent identity | Requires care so that a misconfigured internal network does not silently become routable — and nothing in the sequence currently tests for it except the new validation step |
| **The only enforcement point that can be extended** — per-agent identity, an operator hold on a novel destination, rate limiting, an MCP gateway | **Worst recovery-to-known-good of the three.** Persistent named volumes, a hand-built mediator with hand-built state, and a self-owned log. Options 1 and 3 destroy and recreate a microVM trivially |

CA distribution if MITM is used: Claude Code reads `NODE_EXTRA_CA_CERTS`; Codex reads `CODEX_CA_CERTIFICATE` (and uses rustls **with native roots**, so the usual "Rust binary ignores the system trust store" pitfall does not apply); `agy` CA handling is unverified — and see the ToS warning before intercepting its traffic at all.

## Option 3 — Per-agent microVM, host-enforced egress

Enforcement moves outside the guest kernel entirely.

### Shape

- Apple `container` CLI on macOS 26 (each container gets its own lightweight VM via Virtualization.framework, and its own IP on a private subnet; container-to-container networking requires macOS 26). On Linux, the equivalents are Lima, Firecracker, or Kata Containers.
- Network policy lives in host `pf` or `nftables` on the vmnet bridge, plus a proxy VM.
- Each agent gets its own kernel. An attacker must escape both the guest kernel and the hypervisor.

### Assessment

| Pros | Cons |
|---|---|
| Strongest available boundary | Heaviest. Estimate 1–2 weeks. |
| Agents fully isolated from one another | Apple `container` has no Compose equivalent; tooling is immature |
| Policy is unreachable from the blast radius even after a guest kernel escape | All network policy is hand-built |
| Survives a container escape, which Options 1 and 2 partly do not | Overkill unless kernel escape is in the threat model |

Note: gVisor is not an option on a macOS host.

## Comparison

This table covers only the axes on which the three options actually differ. Controls that none of them provides are listed separately in the next section, so that a reader does not mistake an absent row for a satisfied requirement — which is how the first version of this table was misread.

| | 1 · `sbx` | 2 · Compose + mediator | 3 · Per-agent microVM |
|---|---|---|---|
| Enforcement location | Outside guest (vendor) | Separate container | Outside guest kernel (self-built) |
| Isolation primitive | microVM | Namespaces | microVM with own kernel |
| FQDN denylist | Yes | Yes | Yes (via proxy) |
| IP / CIDR denylist | Yes | Yes, plus post-resolution | Yes |
| DNS exfiltration closed | Yes, by construction | Yes, by routing | Yes |
| Covers all three agents | Partial — Antigravity via `shell` | Yes | Yes |
| Credential / filesystem isolation | Per sandbox | Per container and volume | Per VM |
| **Agent-to-agent network reachability** | Blocked between sandboxes | **Blocked only with per-agent networks** — unrestricted on a shared bridge | Blocked between VMs |
| Per-agent egress policy | **Only if every rule is `--sandbox` scoped**; global by default | Yes, per network | Yes |
| **Egress audit log** | Vendor-provided, destination-level | Destination-level, self-owned | Destination-level, self-owned |
| **Log reachable by the agent?** | Unverifiable — closed source | No, if written inside the mediator | No |
| **Enforcement-point extensibility** — per-agent identity, operator hold on a novel destination, rate limiting, MCP gateway | **No** — closed-source policy engine, network resources only | **Yes** — self-owned and extensible | No — `pf`/`nftables` is network-only |
| **Runtime MCP install blockable** | No — cannot distinguish `npm i lodash` from `npx evil-mcp-server` | Possible via a registry mirror or pull-through cache | No |
| **Resource containment** | VM ceiling by construction | Only if `deploy.resources` limits are declared | VM ceiling by construction |
| **Containment and recovery to known-good** | Trivial — destroy and recreate the microVM | **Hardest** — persistent volumes, hand-built mediator state, self-owned log | Trivial — destroy and recreate the VM |
| Host portability | macOS / Windows only | macOS and Linux | Platform-specific |
| Tooling vendor dependency | High | None | None |
| Effort | Hours | Days | 1–2 weeks |

The "Tooling vendor dependency" row was previously titled "Vendor dependency", which invited the reading that Options 2 and 3 have no vendor exposure. They depend entirely on three SaaS model providers whose behaviour is the substrate of the whole system. That dependency is identical across all three options and is treated under [Provider governance](#provider-governance).

## Controls No Option Provides

These are named rather than omitted, because a comparison table that silently drops an axis reads as though the axis is covered. On every control below, all three options score identically: absent. They are therefore not discriminators — but they are the difference between what this architecture does and what published guidance asks for, and each is a forfeited control rather than a solved problem.

| Control | Guidance | Why it is absent |
|---|---|---|
| Input inspection / prompt-injection filtering | CIS AI/LLM §16.10, §16.11; CIS AI Agents §9.3, §9.6, §10.1; Five Eyes L519–525 | Declared a non-goal above. We do not control three third-party agents' input pipelines |
| Deterministic mediation of agent *actions* — tool calls, not packets | CIS AI Agents §16.10 | No option intercepts a tool call. Writing to a bind mount, `git push` to an allowlisted host, or `terraform apply` is unmediated everywhere |
| stdio MCP tool-invocation visibility | CIS MCP §8.2, L616–617 | The transport never crosses a network. See Design Constraints |
| Agent action log — tool calls, file writes, privilege changes | CIS AI Agents §8.5, §8.8; Five Eyes L679–681 | All three options log destinations only. Requires per-agent identity first |
| Model-provider governance — version pinning, retention, training opt-out | CIS AI/LLM §4.1, §15.2 | Identical across options; see [Provider governance](#provider-governance) |
| Content-level DLP on the model API channel | CIS AI/LLM §3.13; Five Eyes L541 | Follows from the splice-only decision below. The channel carrying 100% of prompt and completion content is inspected for hostname and byte count only |
| Human approval checkpoint on a novel destination | Five Eyes L723–724 | Unattended operation is assumed. Option 2 is the only one that *could* host this later |

The honest summary: this architecture bounds what a compromised agent can reach and records where it tried to go. It does not detect the compromise, constrain what the agent does inside the boundary, or attribute an action to an agent.

## Cross-Cutting Concerns

These apply identically to all three options.

### Filesystem scoping (requirement 2)

- Bind-mount only the specific project directories. Nothing else exists in the container's view.
- Mount read-only (`:ro`) wherever the agent does not need write access. On macOS, Docker Desktop's VirtioFS enforces read-only correctly, though `chown` from inside a bind mount is a no-op on the host.
- Do not mount the host home directory, SSH keys, or cloud credential directories. Anthropic's documentation advises passing cloud credentials as environment variables rather than mounting `~/.aws`.
- Under Option 2, per-agent containers mean each agent sees only its own project mounts and its own state volume.

### Auth and state persistence (requirement 4)

| Agent | Mount target | Critical detail |
|---|---|---|
| Claude Code | One volume at `CLAUDE_CONFIG_DIR` (e.g. `/home/agent/.claude`) | Mounting `~/.claude` alone **does not keep you signed in** — `~/.claude.json` lives outside that directory. Setting `CLAUDE_CONFIG_DIR` to the volume path pulls it inside. |
| OpenAI Codex | Volume at `CODEX_HOME` (e.g. `/home/agent/.codex`) | Set `cli_auth_credentials_store = "file"`. The `keyring` mode hard-fails with no D-Bus. |
| Antigravity `agy` | Volume at `/home/agent/.gemini` | Expects a Secret Service keyring and D-Bus. The documented headless path is `"modelProvider": "gemini"` in settings **plus** `GEMINI_API_KEY` — the environment variable alone is a documented no-op. |

Headless login, per agent, is covered in [`RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md).

Two host-specific notes for this machine:

- Claude Code stores credentials in the **macOS Keychain** here (no `~/.claude/.credentials.json` present). Those credentials are not portable into a Linux container. Either log in inside the container, or use `claude setup-token` to mint a one-year `CLAUDE_CODE_OAUTH_TOKEN`.
- The host `~/.codex` directory is 1.5 GB of session history. Mount a fresh volume, not the host directory.

**Treat every one of these volumes as a secret.** They hold long-lived refresh tokens. Anthropic states the point plainly for its own devcontainer: with `--dangerously-skip-permissions`, the container "does not prevent a malicious project from exfiltrating anything accessible inside the container, including the Claude Code credentials stored in `~/.claude`." That is the argument for credential brokering under Option 2.

#### These volumes are also long-term memory, not just credential stores

Confidentiality is one property; the volumes need three more decisions that the first version of this document did not make. The host `~/.codex` directory being 1.5 GB of session history is not only a reason to mount a fresh volume — it is a preview of what the fresh volume becomes. Session transcripts hold prompts, tool output and repository contents in plaintext, and they accumulate without bound.

- **At rest and in backup.** Confirm the volume path is FileVault-covered. Exclude these volumes from host backup (Time Machine, any cloud-sync folder) and from version control. A routine host backup otherwise captures every agent's refresh token.
- **Retention.** State a posture even if the answer is "unbounded, accepted". Claude Code's `cleanupPeriodDays` defaults to 30; Codex has `codex exec --ephemeral` for runs that should persist nothing.
- **Teardown.** State what destroying the sandbox does to them, and that the answer is not "nothing".

#### Configuration integrity — the volumes hold capability declarations

These same volumes are where each agent records **which MCP servers it loads**. `~/.claude.json` — which the `CLAUDE_CONFIG_DIR` setting deliberately pulls *inside* the persistent volume — holds personal MCP servers and per-project trust. MCP config also lives under `~/.gemini`.

They are writable by design, because requirement 4 demands that auth survive a restart. So a compromised agent can write a new MCP server declaration into its own config volume, and it persists across restarts precisely because persistence is the volume's purpose. That is attacker persistence inside a sandbox whose governing principle is that "any control the agent process can itself modify is not a control" — and MCP server configuration is exactly such a control.

The same class of defect has been CVE'd twice against repository-carried config (CVE-2025-66580; CVE-2025-64109, RCE via a malicious `.cursor/mcp.json` in a repo), which matters here because project directories are bind-mounted writable by default.

Partial mitigation, Claude Code only: `srt` hard-denies writes to `.mcp.json`, `.claude/commands` and `.claude/agents` at the project root. Options 1 and 3 have no equivalent, and no equivalent exists for Codex or `agy`. Record which paths inside each state volume are capability declarations, and treat changes to them as configuration changes requiring review.

### Authentication modes (requirement 4)

Requirement 4 is mechanism-agnostic. R4.9 asks only that every agent have *some* fully headless path — "paste-back code, device code, or a pre-minted token" — and does not prefer API keys to OAuth. The first version of this document nevertheless arrived at a different mechanism per agent by expedience rather than by decision, and gave the operator no way to choose.

Scope now covers **both**: the container accepts an API-key configuration or an OAuth configuration for every agent that can take one. That is a container contract rather than a per-agent workaround — one `AUTH_MODE` variable per agent, defaulting to the safest mode that agent supports.

This expansion changes a requirement. R4.8 previously read as an unqualified MUST NOT on host credential stores entering the container; it is amended in [`REQUIREMENTS.md`](../REQUIREMENTS.md) to permit a bind-mount only under a recorded per-agent decision. Modes D and E below exist because that amendment was requested deliberately, not because the prohibition was wrong.

#### The axis that matters: who holds the refresh token, and who can write it back

Every option sorts on this one question, and the trade-offs fall out of it.

| # | Mode | Token minted | Token lives | Blast radius on container compromise | Revocable alone? |
|---|---|---|---|---|---|
| A | In-container interactive bootstrap | in container | volume | container | yes |
| B | Pre-minted token via environment | on host | env + process | container | yes |
| C | OAuth callback port-forward | in container | volume | container | yes |
| D-shared | Bind-mount the **live** host credential | on host | host file | **entire host account** | no — all-or-nothing |
| D-dedicated | Bind-mount a credential minted under a **separate provider account** | on host | host file | that account only | yes |
| E | Seed-copy at entrypoint, then detach | on host | volume | container | depends on source |
| F | Broker outside the container | outside | never in container | none | yes |

**D-dedicated means a separate provider account**, not a second session of the operator's own. The distinction is the whole value of the row. A second `codex login` under a different `CODEX_HOME` on the same ChatGPT account yields a second refresh token, but the blast radius stays the account and per-session revocation is **UNVERIFIED** — nothing establishes that any of the three providers can invalidate one refresh token without invalidating the account's others. Same-account separation therefore buys convenience, not containment, and should be treated as D-shared until the revocation question is answered. A genuinely separate account costs a second seat and buys real independence.

#### The modes

**A — In-container interactive bootstrap.** A human runs the login inside the container once and pastes the code back. The credential is minted in the blast radius but never existed on the host. Claude Code needs `claude.ai` and `platform.claude.com` allowlisted, neither of which Anthropic's own reference firewall permits. Codex uses `codex login --device-auth`. `agy` detects a remote session and prints a copy-paste URL and code. This is the cleanest option; its cost is one human interaction per container rebuild, mitigated by the state volume surviving rebuilds.

**B — Pre-minted token via environment variable.** Claude Code only: `claude setup-token` mints a one-year `CLAUDE_CODE_OAUTH_TOKEN`. Codex has no OAuth environment-variable equivalent. `agy` explicitly does not support one — issue #632 is open and container runs fail with `authentication required. Run 'agy' to log in, then retry`. The twelve-month replay window is recorded as an accepted risk under *Credential lifecycle* below.

**C — OAuth callback port-forward.** The browser runs on the host; the callback lands inside the container, so the token is minted in the container and never touches host storage. Codex documents port 1455 with 1457 as fallback and redirect `http://localhost:1455/auth/callback`; publish it as `-p 127.0.0.1:1455:1455`, or `ssh -L 1455:localhost:1455` for a remote host. Best ergonomics-to-risk ratio of the OAuth modes.

**D — Bind-mount the host credential.** Requested explicitly, and it has real advantages: no re-authentication at all, it works today for Codex, and it matches how a single-operator workstation is actually used — one identity, one login, everywhere.

| Agent | Host artifact (measured 2026-09-03) | Mountable? |
|---|---|---|
| OpenAI Codex | `~/.codex/auth.json` — 4.0 KB, `-rw-------` | **Yes.** Plain JSON, no OS binding. Requires `cli_auth_credentials_store = "file"`. Mount a dedicated directory, never the 1.5 GB `~/.codex` |
| Antigravity `agy` | `~/.gemini/oauth_creds.json` — 4.0 KB, `-rw-------` | **Unverified** — see below |
| Claude Code | macOS **Keychain**; no `~/.claude/.credentials.json` present | **No.** Not portable to a Linux container |

Claude Code cannot take mode D here without first degrading host posture, because the credential would have to be forced out of the Keychain into a file. Separately, `~/.claude.json` is 224 KB holding the OAuth account, every project's trust decision, and personal MCP servers — and setting `CLAUDE_CONFIG_DIR` deliberately pulls it *inside* the mounted directory. Mounting it surrenders the trust and MCP configuration, not merely a token. Use A or B for Claude Code.

`agy` mode D has two unresolved problems that compound. `RESEARCH_FINDINGS.md` previously recorded the token as landing at `~/.gemini/antigravity-cli/antigravity-oauth-token`; that file does not exist on this host and the claim is now corrected. The candidate artifact is `~/.gemini/oauth_creds.json`, whose mtime is five weeks older than `agy`'s own `settings.json` — consistent with macOS `agy` using the Keychain and this file being a `gemini-cli` remnant, though it postdates the 2026-06-18 `gemini-cli` shutdown and so is not clearly dead either. Whether Linux `agy` reads it with no Secret Service present is exactly what a test must establish. Until then, treat `agy` mode D as **UNVERIFIED**.

The second `agy` problem is not technical. Antigravity Additional Terms Section 6 prohibits "using third party software, tools, or services to access the Service", and Google has suspended paid subscribers without warning for it. Mounting an Antigravity OAuth credential into a container to be driven by a wrapper is the closest pattern in this list to the one actually enforced against, and the blast radius is the whole Google account rather than the container. See [Security Warning — Antigravity Terms of Service](#security-warning--antigravity-terms-of-service).

**E — Seed-copy at entrypoint, then detach.** Mount the host credential read-only for bootstrap only; the entrypoint copies it into the persistent volume; steady-state runs with no host mount at all. Refresh writes land on the volume. This reduces host exposure from continuous to a bootstrap window while keeping most of mode D's ergonomics, and it is the honest middle ground if mode D is what you want.

**F — Broker outside the container.** Codex ships a ready-made primitive: `codex-responses-api-proxy` forwards **only** `POST /v1/responses` to `api.openai.com`, injects `Authorization` from a key read on stdin, 403s everything else, and runs as a privileged user so the agent process never sees the key. Strongest available control, and it fits the Option 2 mediator directly. It is API-key-shaped, however — it does not carry an OAuth flow the CLI drives itself — so it does not generalise to the other two agents today.

#### Traps

These decide the choice more than the threat model does.

1. **OAuth refreshes, so `:ro` breaks.** The access token expires and the CLI writes a new one back. A read-only mount works until the first expiry and then fails, possibly mid-run and hours in. A read-write mount lets a compromised agent **overwrite** the host credential — corruption and operator lockout, a second-order effect that the threat model's exfiltration-and-lateral-reach framing does not name. Mode E resolves this: refresh lands on the volume, not the host.
2. **Never bind-mount a single credential file.** CLIs commonly write to a temporary file and rename. The container retains the old inode and silently keeps a stale credential indefinitely. Mount a dedicated directory.
3. **Refresh-token rotation race.** If a provider issues single-use refresh tokens, a host and a container sharing one file invalidate each other and log the operator out of both. **UNVERIFIED per provider**, and the failure most likely to make D-shared unworkable in daily use irrespective of security posture. It belongs in the test plan.
4. **`0600` means nothing inside the container.** Docker Desktop on macOS uses VirtioFS and fakes file ownership, so reads and writes succeed regardless of the container UID. Host file modes are not a control here; `:ro` is the only real one.
5. **Revocation granularity.** D-shared revokes as a single unit — suspecting the container forces re-authentication on every machine the operator owns. Only a **separate provider account** changes that. A second login under a different `CODEX_HOME` on the same account looks like separation and is not, because revocation granularity is a property of the provider, not of the file layout, and no provider here is known to revoke one refresh token in isolation.

#### The precedent already set in this repository

R6.5 answers the same question for AWS and rejects Model C — the operator's own identity with a trimmed configuration — in these words: "Provides the appearance of scoping without the substance." Mounting the operator's live OAuth credential is Model C applied to model providers. The asymmetry is worth stating plainly: R6.2.2 forbids long-lived IAM access keys for AWS, while this document recommends a one-year OAuth token for Claude Code. Both may be defensible, but they are opposite postures in one repository and the difference has not been argued anywhere. See [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md) G5.

#### What each agent can actually accept

| Mode | Claude Code | OpenAI Codex | Antigravity `agy` |
|---|---|---|---|
| API key | Yes — `ANTHROPIC_API_KEY` | Yes — `codex login --with-api-key`, reads stdin | Yes — `GEMINI_API_KEY` **and** `"modelProvider": "gemini"`; the variable alone is a documented no-op |
| A — in-container login | Yes — needs `claude.ai` + `platform.claude.com` | Yes — `--device-auth` | Yes — SSH paste-back |
| B — pre-minted OAuth env | Yes — one-year `CLAUDE_CODE_OAUTH_TOKEN` | No equivalent | No — issue #632 |
| C — callback port-forward | **Unverified** — whether the container login is a localhost callback or a browser paste-back code is an open item in [`RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md). If paste-back, there is no port to forward and C collapses into A | Yes — 1455 / 1457 | Unverified |
| D — mount host credential | No — Keychain-bound | Yes — `auth.json` | Unverified, and ToS-exposed |
| E — seed-copy | Nothing to copy | Yes | Same caveats as D |
| F — broker | No primitive | Yes — `codex-responses-api-proxy` | No |

#### Position

Implement the mode switch, since that is the actual scope change: `AUTH_MODE=apikey | oauth-interactive | oauth-token | oauth-mount` per agent, defaulting to the safest mode the agent supports rather than to whichever mode is most convenient.

The lettered modes above do not map one-to-one onto that enum, and the mapping needs stating or an implementer cannot select what this section recommends. **A and C are both `oauth-interactive`** — C is A with the OAuth callback port published (`-p 127.0.0.1:1455:1455`) so the browser can run on the host. **B is `oauth-token`. D and E are both `oauth-mount`**, and R4.15 makes E the required shape of it: read-only bootstrap mount, copied to the volume. **F is not an agent auth mode at all** — it is a mediator concern under Option 2, and it is listed here only because it is the strongest answer to the same problem.

- **Claude Code** — mode A, falling back to B where no human is available.
- **Codex** — A or C first. E where the host credential's ergonomics are wanted, and only from a separate provider account; a second config directory on the operator's own account is D-shared wearing a different name. Not D-shared.
- **Antigravity `agy`** — API key. Mode D is unverified *and* ToS-exposed, and the two problems compound rather than trading off.

**Overridden at Gate 1.** The Codex recommendation above was not adopted. R4.17 permits `oauth-mount` from a second config directory on the operator's own provider account — which this section defines as functionally D-shared — recorded as an accepted risk with the blast radius stated. The E shape (R4.15) still applies.

One rule holds across every mode: **no read-write bind-mount of a host credential.** A read-only bootstrap plus a copy to the volume delivers the same ergonomics without granting a compromised container write access to host credential material.

### Credential lifecycle (requirements 4 and 6)

The design persists long-lived refresh tokens and, for headless Claude Code, may mint a one-year `CLAUDE_CODE_OAUTH_TOKEN`. That token sits on a volume this document concedes a malicious project can read — a twelve-month replay window. The first version offered it as guidance with no invalidation path attached.

**Recorded as an accepted risk**, with these conditions:

- Prefer the shortest viable credential lifetime. Prefer in-container login over `setup-token` where a human is available to perform it. If the one-year token is chosen, state why in the use-case profile.
- Compensating controls are the per-agent volumes, secret handling, and backup exclusion above.
- A revocation path is documented and tested per credential type, with a stated maximum time from detection to revocation. Anthropic tokens revoke through the console; Codex through the OpenAI account; `agy` through the Google account or by rotating `GEMINI_API_KEY`.
- **Review trigger:** revisit when brokered short-lived agent credentials become available from any of the three providers.

Note what identity-free credentials cost beyond theft risk: because no agent carries an identity, nothing in the egress or host logs distinguishes "the operator did this" from "Claude Code did this on the operator's behalf". Non-repudiation is unsatisfiable by construction until per-agent identity exists. See [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md) G3 and G5.

### MCP and tool governance

MCP appeared once in the first version of this document, as a source of hostile input, and never as software that runs inside the sandbox holding the agent's full egress allowlist. Both are true, and the second is the one with design consequences.

- **Default off.** Tools, plugins and MCP servers are disabled unless explicitly approved. This document applies default-deny rigorously to the network and, until now, not at all to tools — an asymmetry with no justification.
- **Inventoried and version-pinned** per use-case profile, recording risk tier (read-only / write / irreversible) and a capability baseline, so that capability *drift* is detectable and not just new servers.
- **Egress declared by the server, not inherited from the agent.** An MCP server currently inherits an allowlist sized for the agent. It should declare the destinations it needs.
- **Installed from an approved source.** See the third trap below.
- Subject to every control that applies to the agent itself.

Recorded as gap G4 in [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md). Only Option 2 has an enforcement point that can grow into the gateway-mediated pattern the MCP guidance names as its recommended default for high-impact workflows; Option 1 forecloses it.

### Provider governance

Anthropic, OpenAI and Google are not merely destinations to allowlist — they are AI service providers, and this dependency is identical under all three options.

Per agent, record: the model version pinning capability or its absence; the history-retention and training-opt-out settings in use; the data classification permitted to leave the sandbox; and the provider's incident-notification path. A provider-side model change can silently alter agent behaviour, and published guidance warns that unpinned upgrades "break existing guardrails" — which is unfalsifiable here, since this architecture has no guardrails to break.

### TLS interception — splice, not MITM (proposed, needs owner)

The first version left this decision open for two of three agents while recommending "Build Option 2", which meant selecting an architecture with its principal content-inspection decision unmade.

**Proposed: SNI/CONNECT splice for all three agents. No TLS interception anywhere.** Rationale: it is required for Antigravity on terms-of-service grounds (below), consistency avoids running two trust models side by side, and it removes CA generation, distribution, rotation and per-agent trust-store configuration from the build — work that was never scoped in the "Days, not hours" estimate.

**State the cost plainly.** Splice was previously booked only as the loss of URL-path granularity. It is more than that:

- No content-level DLP on the model API channel — the destinations carrying 100% of prompt and completion content are inspected for hostname and byte count only. This is precisely where guidance says the data-loss vector is largest.
- Remote MCP tool invocations to allowlisted hosts cannot be inspected or logged.

Content-level DLP is therefore **out of scope**, and destination narrowing plus the audit log is the accepted residual control. If MITM is later adopted for Claude Code and Codex: Claude Code reads `NODE_EXTRA_CA_CERTS`; Codex reads `CODEX_CA_CERTIFICATE` and uses rustls with native roots.

### If an agent is compromised

The first version designed a detection surface and stopped at it. The one place it produces a signal was followed by nothing. A response path is needed before the sandbox is used, not after the first incident.

| Need | Action |
|---|---|
| Cut egress immediately | Option 1: `sbx policy deny network`. Option 2: denylist entry at the mediator, or detach the agent's network |
| Isolate one agent without stopping the others | Option 2: stop that container; per-agent networks mean the others are unaffected |
| Rotate credentials | Per credential type, per the revocation paths in Credential lifecycle above. The one-year `CLAUDE_CODE_OAUTH_TOKEN` is the longest-lived and the priority |
| Disable one MCP server or tool across all agents | **No mechanism exists today.** Requires the MCP governance layer above |
| Return to known-good | Options 1 and 3: destroy and recreate the microVM. Option 2: rebuild containers, and decide what happens to the persistent state volumes — a contaminated volume cannot currently be distinguished from a clean one |

Define what constitutes an event versus an incident before go-live. Recorded as gap G6 in [`STANDARDS_MAPPING.md`](STANDARDS_MAPPING.md).

### Egress policy (requirement 5)

Default-deny allowlist is the primary control; the denylist is a second, independent control layered on top. Deny takes precedence over allow in every option.

Minimum allowlists per agent are tabulated in [`RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md). Three traps worth repeating here:

- **Do not copy the vendor reference allowlists.** Anthropic's is stale: it permits retired telemetry hosts (`sentry.io`, `statsig.com`) while omitting `claude.ai` and `platform.claude.com`, which OAuth sign-in and token refresh require.
- **DNS must be owned.** Both vendor firewalls permit UDP/53 to any destination.
- **A registry allowlist is not a software allowlist.** This is the trap the first version missed, and it is the one that undermines everything above it. `*.npmjs.org` and `*.pypi.org` are not data destinations — they are arbitrary-code inbound channels, and the installation channel for arbitrary MCP servers. `npx <any-mcp-server>` succeeds inside every option's sandbox; the server is unreviewed, unpinned, unhashed, and inherits the agent's container privileges and its whole egress allowlist. Typosquatting is unmitigated. A wildcard registry entry is also an exfiltration destination — a publish to an attacker-controlled package name is indistinguishable from a fetch at the domain level.

  Prefer registry access absent at runtime, with packages installed at build time; or narrow it to specific package paths through a pull-through cache or mirror. Note that the `balanced` preset used for the discovery run permits package managers and registries wholesale, so this flaw propagates by construction into the durable policy unless it is corrected deliberately.

## Security Warning — Antigravity Terms of Service

Google's Antigravity Additional Terms, Section 6, prohibits "using third party software, tools, or services to access the Service," giving the example of using a third-party client with Antigravity OAuth. Google has suspended paid accounts — including AI Ultra subscribers — without warning for using third-party tools and proxies against Antigravity OAuth.

Running the official `agy` binary inside a container is not what triggered those suspensions, and nothing in the terms prohibits containers or headless use as such. However, a **TLS-intercepting (MITM) proxy placed in front of Antigravity OAuth traffic is arguably within the scope of that clause.**

Concrete guidance:

- For the Antigravity container, use SNI/CONNECT **splice** — inspect the destination, never decrypt. Do not MITM it.
- Alternatively, sidestep the question: `GEMINI_API_KEY` or Vertex AI ADC routes to the public Gemini API on your own billing, outside the Antigravity OAuth relationship entirely.
- Avoid all third-party OAuth wrapper and proxy tooling for Antigravity. That is the one pattern with a documented history of account suspension.

This guidance is an interpretation of the published terms, not an official Google position. Google staff declined to clarify the boundary when asked on the developer forum.

### Decision (proposed, needs owner)

Because the interpretation is explicitly unofficial and the vendor declined to clarify, this risk cannot be closed by further analysis. It needs an accepted position rather than more research.

**Proposed: take the `GEMINI_API_KEY` (or Vertex AI ADC) route**, which sidesteps the clause entirely by leaving the Antigravity OAuth relationship rather than proxying it. Set `"modelProvider": "gemini"` in settings **and** the environment variable — the variable alone is a documented no-op. This routes to the public Gemini API on your own billing rather than the Antigravity account quota, which is the accepted cost.

**The route itself is UNVERIFIED.** [`RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md) records a conflict: the current official install page documents this path, but a June 2026 maintainer statement says Gemini API keys are not supported. Test it against the pinned `agy` version before committing to it. If it does not work, the fallback is Antigravity OAuth with splice-only and no proxy tooling — which leaves the ToS question open rather than sidestepping it.

Splice-only for the Antigravity container remains the position if the OAuth route is used instead. Avoid all third-party OAuth wrapper and proxy tooling either way — that is the one pattern with a documented history of account suspension.

- **Owner:** unassigned — needs a named person.
- **Review trigger:** Google clarifies the boundary, the Additional Terms change, or the billing cost of the public-API route becomes material.

## Open Decisions

**Three of four were settled at Gate 1 (2026-09-03).** Their resolutions are recorded in [`prd.md`](../prd.md) and in the requirement register; this table is kept so the reasoning above stays traceable to an outcome. Open Decision 3 remains open and is now governed by R14.1.

| # | Decision | Proposed position | Blocking? |
|---|---|---|---|
| 1 | TLS interception posture | **Settled — splice now, termination possible later.** R5.15. No content-level DLP at first release; the mediator keeps the seam (R15.2) | Closed |
| 2 | Antigravity access route | **Settled — `GEMINI_API_KEY` only**, with a ToS-change review trigger (R14.3). No Antigravity account credential enters a container. R5.13 remains a permanent bar | Closed |
| 3 | Docker Sandboxes provider assessment | Not done. Step 1 is constrained to a synthetic repository and throwaway credentials until it is | No — the constraint *is* the mitigation. Would block only a run against a representative repository |
| 4 | Host-credential mount posture for Codex | **Settled against the proposed position.** R4.17 permits `oauth-mount` from a second config directory on the operator's *own* account, recorded as an accepted risk: blast radius is the whole account, revocation all-or-nothing. R4.13–R4.15 still bound the shape | Closed |

## Recommendation

**Build Option 2, subject to its Preconditions. Seed the policy with Option 1 first.**

The recommendation is unchanged from the first version of this document. Three of the four reasons originally given for it were wrong, and are restated here on ground that survives review.

Option 1 produces a working sandbox within hours and seeds the allow/deny list from real agent traffic. Its microVM boundary is genuinely stronger than plain Docker, and its inability to unblock UDP/ICMP closes the DNS hole without any work. It is a good proving ground and a good fallback.

It cannot be the durable answer: Antigravity is not a supported agent, the CLI is closed-source, it is macOS/Windows-only, it creates a vendor dependency inside what is meant to be a reusable portable artifact, and — the reason that matters most — its policy engine expresses network resources only and cannot be extended to enforce anything about identity, tools or MCP servers.

**Why Option 2:**

1. It is the only option where FQDN rules are evaluated correctly at Layer 7. Unchanged and still true.
2. **It is the only enforcement point that can be extended.** Per-agent identity, an operator hold on a novel destination, rate limiting, and an MCP gateway are all buildable at a self-owned mediator and at neither of the alternatives. Given how much of the gap list above is an application-layer problem, extensibility is the strongest argument for Option 2 — and the first version of this document never made it.
3. It yields a **destination-level** audit trail that is self-owned and outside the agent's reach. Note the correction: this is not an agent action log, and on action logging all three options score identically at zero.
4. It can broker the **model-provider** credential, given per-agent identity at the mediator. Without that identity the feature is worse than useless, which is why it is a precondition rather than a benefit.

**What Option 2 costs**, stated because the comparison now carries it: recovery to known-good is the worst of the three. Persistent volumes, hand-built mediator state and a self-owned log mean a contaminated environment is slower and less certain to rebuild than a destroyed microVM. That is a real trade against Options 1 and 3, accepted in exchange for reasons 2 and 3.

Option 3 is warranted only if container escape is inside the threat model. Revisit if the agents will handle untrusted third-party repositories or if the sandbox becomes multi-tenant.

### Suggested sequence

0. **Assess Docker Sandboxes as a service provider** — what its proxy observes, its retention period for intercepted traffic, its deletion and breach-notification terms. This has not been done. Until it is, step 1 runs constrained as written below.
1. **Discovery run, not a production session.** Stand up Option 1 under `locked-down` plus a minimal seed allowlist, and widen only on observed failures — not under `balanced`, which starts at maximum permitted access and would run the agents at their widest policy against real code, which is the exact inverse of progressive deployment. Use a **synthetic repository and throwaway credentials**, per step 0 and `REQUIREMENTS.md` R12.4. Run **one agent at a time with `--sandbox` scoping**, or the capture yields a union of all three allowlists rather than a per-agent policy.
2. **Seed** — not validate — the allowlist from that capture, and add the denylist overlay (metadata endpoint, RFC1918, link-local, known-bad indicators). One closed-source observation point cannot establish completeness: `sbx` fully intercepts only HTTP/HTTPS and blocks UDP/ICMP entirely, so a legitimate UDP dependency is invisible here and surfaces as a novel failure later. Cross-validate against a second source — the agents' own verbose logging, or `tcpdump` on the mediator during a shadow run — and treat the allowlist as provisional until both agree. Correct the package-registry entries per the third trap above rather than carrying them over.
3. **Build Option 2** with that policy, satisfying both Preconditions. Keep each agent's native sandbox enabled inside as defence in depth, remembering that none of them is a boundary.
4. **Test the boundary adversarially before using it for real work.** Everything above validates that the allowlist is *sufficient*; nothing yet validates that the boundary is *effective*. Run the acceptance matrix in `REQUIREMENTS.md` (T1–T20, SC-1 to SC-3), and at minimum exercise:
   - DNS exfiltration
   - whether the internal networks are genuinely non-routable — this document names a silently-routable network as a failure mode and it has no visible symptom
   - post-resolution CIDR deny against a rotating CDN
   - policy modification attempted from inside a container
   - reach from one agent container to the other two
   - a repository seeded with injected instructions targeting a non-allowlisted collector — confirming the attempt is blocked, appears in the log, and is attributable

   Record which of the injection sources named in the threat model are exercised and which are not. On current design, the MCP vector is not, because stdio never crosses the enforcement point.
5. Re-evaluate Option 3 only if the threat model changes.
