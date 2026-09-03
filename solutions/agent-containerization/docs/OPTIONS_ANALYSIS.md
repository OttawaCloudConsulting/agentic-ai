# Options Analysis — Sandboxed Agent Containerization

Three architectural options for running Claude Code, OpenAI Codex, and Google Antigravity (`agy`) inside a sandboxed container with a minimal blast radius.

Supporting evidence, version numbers, exact paths and citations are in [`RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md). This document is the decision material.

**Research date:** 2026-09-02.

## Contents

- [Design Constraints](#design-constraints)
- [Option 1 — Managed microVM (`sbx`)](#option-1--managed-microvm-sbx)
- [Option 2 — Compose pod with egress mediator](#option-2--compose-pod-with-egress-mediator)
- [Option 3 — Per-agent microVM, host-enforced egress](#option-3--per-agent-microvm-host-enforced-egress)
- [Comparison](#comparison)
- [Cross-Cutting Concerns](#cross-cutting-concerns)
- [Security Warning — Antigravity Terms of Service](#security-warning--antigravity-terms-of-service)
- [Recommendation](#recommendation)

## Design Constraints

### The three agents are not symmetric

| Agent | Container artifact | Notes |
|---|---|---|
| Claude Code | `npm i -g @anthropic-ai/claude-code` (Node) | Refuses to start as root with `--dangerously-skip-permissions`; container must run non-root |
| OpenAI Codex | Static musl binary (Rust) | Trivial to put in a distroless image |
| Google Antigravity | `agy` Go binary via install script | Headless mode is first-class; do **not** containerize the desktop GUI |

### Threat model

The primary threat is not a malicious user — it is a **compromised agent**: indirect prompt injection from a repository, a web page, an MCP server response, or a dependency, causing the agent to exfiltrate data or reach systems it should not.

That threat model has two consequences that drive every option below:

1. The agent has legitimate outbound network access (it must reach its model API), so egress control must be selective, not binary.
2. The agent runs arbitrary code by design, so any control the agent process can itself modify is not a control. **The enforcement point must sit outside the blast radius.** This is the single axis on which the three options differ.

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
- Scope is global by default; `--sandbox <name>` scopes a rule to one sandbox.
- Only HTTP/HTTPS is fully intercepted through the proxy. Non-HTTP TCP (including SSH) can be permitted with a hostname rule.
- **UDP and ICMP are blocked at the network layer and cannot be unblocked by policy.** This closes the DNS-exfiltration hole by construction — no other option gets this for free.

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
[claude] ─┐
[codex]  ─┼── agents-net  (internal: true — no default route, no DNS to internet)
[agy]    ─┘        │
                   └── [egress-mediator] ── external network ── internet
                         iron-proxy (Go, Apache-2.0) or Squid CONNECT-allowlist
                         + authoritative DNS resolver for the pod
```

- Agent containers: `network: internal`, `cap_drop: ALL`, `security_opt: no-new-privileges`, read-only root filesystem with `tmpfs` for scratch, non-root user, project directories bind-mounted (`:ro` where the agent does not need to write).
- One container per agent, one state volume per agent. Claude Code cannot read Codex's `auth.json`.
- **DNS is served by the mediator.** The agent network has no route to port 53 on the internet, so DNS tunnelling is structurally impossible rather than merely filtered. This is the fix for the hole in both vendor reference firewalls.
- Each agent's own native controls are layered inside as defence in depth: `srt` for Claude Code, `features.network_proxy` for Codex, `agy --sandbox` for Antigravity.

### Egress policy

Two independent controls, in order:

1. **Allowlist** of domains (exact and wildcard) and CIDRs, evaluated at CONNECT/SNI.
2. **Post-resolution CIDR denylist** — even for an allowlisted domain, the connection is refused if the resolved IP falls in a blocked range. This catches CDN IP rotation and DNS rebinding, which an `ipset` snapshot built at container start cannot.

Cloud metadata (`169.254.169.254`), loopback, and private ranges are blocked by default in `iron-proxy`.

Optional **credential brokering**: long-lived tokens live in the mediator and are injected as upstream headers, so the agent container never holds a secret. `codex-responses-api-proxy` is a ready-made primitive for this on the OpenAI side — it forwards only `POST /v1/responses` and 403s everything else.

Every attempted destination is logged. You see the injection attempt, not just the block.

### Assessment

| Pros | Cons |
|---|---|
| The only option where FQDN rules work correctly (L7 CONNECT/SNI inspection) | You own and maintain it. Days, not hours. |
| Allowlist + denylist + post-resolution CIDR deny | Splice-only gives domain granularity; URL-path rules require TLS MITM and CA distribution |
| Identical on macOS and Linux hosts | Codex defaults to **WebSocket** transport — the proxy must permit `Upgrade` on 443 or streaming silently degrades to HTTP/SSE |
| Full audit trail of attempted destinations | More moving parts than a managed product |
| Credential brokering keeps tokens out of the agent container | Requires care so that a misconfigured `internal: true` does not silently become routable |

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

| | 1 · `sbx` | 2 · Compose + mediator | 3 · Per-agent microVM |
|---|---|---|---|
| Enforcement location | Outside guest (vendor) | Separate container | Outside guest kernel (self-built) |
| Isolation primitive | microVM | Namespaces | microVM with own kernel |
| FQDN denylist | Yes | Yes | Yes (via proxy) |
| IP / CIDR denylist | Yes | Yes, plus post-resolution | Yes |
| DNS exfiltration closed | Yes, by construction | Yes, by routing | Yes |
| Covers all three agents | Partial — Antigravity via `shell` | Yes | Yes |
| Cross-agent isolation | Per sandbox | Per container | Per VM |
| Audit log | Vendor-provided | Full, self-owned | Full, self-owned |
| Host portability | macOS / Windows only | macOS and Linux | Platform-specific |
| Vendor dependency | High | None | None |
| Effort | Hours | Days | 1–2 weeks |

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

### Egress policy (requirement 5)

Default-deny allowlist is the primary control; the denylist is a second, independent control layered on top. Deny takes precedence over allow in every option.

Minimum allowlists per agent are tabulated in [`RESEARCH_FINDINGS.md`](RESEARCH_FINDINGS.md). Two traps worth repeating here:

- **Do not copy the vendor reference allowlists.** Anthropic's is stale: it permits retired telemetry hosts (`sentry.io`, `statsig.com`) while omitting `claude.ai` and `platform.claude.com`, which OAuth sign-in and token refresh require.
- **DNS must be owned.** Both vendor firewalls permit UDP/53 to any destination.

## Security Warning — Antigravity Terms of Service

Google's Antigravity Additional Terms, Section 6, prohibits "using third party software, tools, or services to access the Service," giving the example of using a third-party client with Antigravity OAuth. Google has suspended paid accounts — including AI Ultra subscribers — without warning for using third-party tools and proxies against Antigravity OAuth.

Running the official `agy` binary inside a container is not what triggered those suspensions, and nothing in the terms prohibits containers or headless use as such. However, a **TLS-intercepting (MITM) proxy placed in front of Antigravity OAuth traffic is arguably within the scope of that clause.**

Concrete guidance:

- For the Antigravity container, use SNI/CONNECT **splice** — inspect the destination, never decrypt. Do not MITM it.
- Alternatively, sidestep the question: `GEMINI_API_KEY` or Vertex AI ADC routes to the public Gemini API on your own billing, outside the Antigravity OAuth relationship entirely.
- Avoid all third-party OAuth wrapper and proxy tooling for Antigravity. That is the one pattern with a documented history of account suspension.

This guidance is an interpretation of the published terms, not an official Google position. Google staff declined to clarify the boundary when asked on the developer forum.

## Recommendation

**Build Option 2. Validate the policy with Option 1 first.**

Option 1 produces a working sandbox within hours and independently validates the allow/deny list against real agent traffic. Its microVM boundary is genuinely stronger than plain Docker, and its inability to unblock UDP/ICMP closes the DNS hole without any work. It is excellent as a proving ground and a fallback.

It cannot be the durable answer, though: Antigravity is not a supported agent, the CLI is closed-source, it is macOS/Windows-only, and it creates a vendor dependency inside what is meant to be a reusable, portable artifact.

Option 2 meets all five requirements without a vendor dependency, is the only option where FQDN rules are evaluated correctly at Layer 7, is the only one that yields an audit trail of what a compromised agent attempted, and is the only one that can broker credentials so tokens never enter the agent container.

Option 3 is warranted only if container escape is inside the threat model. Revisit if the agents will handle untrusted third-party repositories or if the sandbox becomes multi-tenant.

### Suggested sequence

1. Stand up Option 1 and run the three agents against a representative repository. Capture the real set of destinations each agent contacts.
2. Turn that capture into the allowlist, and add the denylist overlay (metadata endpoint, RFC1918, link-local, any known-bad indicators).
3. Build Option 2 with that policy. Keep each agent's native sandbox enabled inside as defence in depth.
4. Re-evaluate Option 3 only if the threat model changes.
