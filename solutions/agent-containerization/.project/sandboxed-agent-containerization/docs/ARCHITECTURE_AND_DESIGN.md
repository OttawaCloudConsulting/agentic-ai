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
credential brokering is built — brokers upstream credentials to the agents whose identity is
cryptographic.

**Per-agent workload identity is built as of Feature 01.6, in three forms rather than one.**
`claude` presents a client certificate on a required-mode `clientca=` listener (*cryptographic*).
`codex` and `agy` present a per-agent proxy credential, which each client constructs from proxy-URL
userinfo preemptively (*credential*). All three additionally sit alone on their own `internal: true`
segment, so network membership is a third, structural form. The audit line names which one applied,
and the Milestone 03 brokering gate is the cryptographic form alone (D6).

The enforcement point sits outside every agent's blast radius (R1.2). No agent container holds
`NET_ADMIN`, and no agent firewalls itself (R1.5): a control the agent can reach is not a control.

**What this architecture does and does not do.** It bounds what a compromised agent can reach and
records where it tried to go. It does not detect the compromise or constrain what the agent does
inside the boundary. It now *does* attribute an egress attempt to a specific agent — that clause
was carried verbatim from the options analysis until 01.6 built the identity it waited on — but the
attribution is per *connection*, not per *action*: no control in this architecture sees a tool call
(D20, and Controls This Architecture Does Not Provide).

## Design Decisions

| # | Decision | Rationale | Tradeoff | Alternatives Considered |
|---|----------|-----------|----------|-------------------------|
| D1 | **Adopt Option 2** — Compose pod, agent containers on internal networks, single egress mediator | Only option evaluating FQDN rules correctly at L7 (R5.5); only enforcement point that can be *extended* to per-agent identity, operator hold, rate limiting and an MCP gateway (R15.2); yields a self-owned destination audit trail outside the agent's reach (R9.1) | Worst recovery-to-known-good of the three options: persistent volumes, hand-built mediator state and a self-owned log mean a contaminated environment is slower and less certain to rebuild than a destroyed microVM. Accepted, mitigated by D16 | **Option 1 (Docker Sandboxes `sbx`)** — hours not days, microVM boundary, UDP/ICMP blocked outright; rejected as durable answer: Antigravity unsupported, closed-source, macOS/Windows-only, vendor on the traffic path (R14.1 unmet), policy engine expresses network only and cannot be extended. Retained as the *discovery seeding* tool (D17). **Option 3 (per-agent microVM)** — strongest boundary; rejected as overkill: container escape is not in the threat model, 1–2 weeks, Apple `container` has no Compose equivalent. Revisit only if A3 (trusted-ish repos) or the multi-tenancy non-goal changes |
| D2 | **One internal network per agent** (`claude-net`, `codex-net`, `agy-net`, each `internal: true`), mediator multi-homed onto all three plus the external network. **Amended at the 01.5 SF-7b build (2026-09-08): each agent network additionally declares an `ip_range` (`172.31.{10,20,30}.128/25`) inside its `/24`.** Without it Docker's dynamic allocation offers `.2` — the mediator's own static address — first, and because no `depends_on` orders the four services, `up --build` failed 3 of 3 with `failed to set up container networking: Address already in use`. Measured, then proved clean 3 of 3 (01.5 Deviation 19) | `internal: true` removes the default route but Docker bridge networks allow unrestricted container-to-container traffic on the same bridge. A shared `agents-net` gives *zero* cross-agent isolation while appearing to isolate. Containers on separate bridge networks cannot reach each other by name or IP | Three networks to declare and maintain instead of one; the mediator must be attached to each | **Single `agents-net`** — rejected, this was a red-team Critical finding against the pre-revision design. **Single network with ICC disabled** via `driver_opts` (`com.docker.network.bridge.enable_icc`) — the mechanism exists but the exact key name is **UNVERIFIED**; per-agent networks need no such confirmation, which is why they are the primary form |
| D3 | **The mediator owns DNS.** Agent networks have no route to port 53 on the internet | R5.4. Filtering UDP/53 by destination is insufficient — both vendor reference firewalls do exactly that and both are documented as exfiltration-capable over DNS. Owning the resolver makes DNS tunnelling structurally impossible rather than filtered | The mediator becomes a hard dependency for name resolution; its failure is a full outage rather than a degraded one. **Amended at the 01.3 SF-5 build (2026-09-05): the pod resolver is TWO daemons, not one.** `dnsdist` 1.9.16 holds all of the policy — per-agent exact-match allowlist selected by the arriving subnet, QTYPE restricted to A/AAAA, non-canonical QNAMEs refused, everything else REFUSED and forwarded nowhere, every decision audited — and `unbound` sits behind it on loopback as the re-originating stage, because dnsdist proxies the client's packet and criterion 4 requires a fresh query with the client's EDNS options dropped. Tested, not assumed: unbound alone fails three of the six properties (`local-zone` is subtree-scoped, so "this name and nothing below it" has no expression; it has no QTYPE policy; it forwards a mixed-case QNAME verbatim). See `docs/records/resolver-verification.md` | **Filter UDP/53 by destination** — rejected, this is the documented hole. **Allow a public resolver** — rejected, same hole |
| D4 | **TLS is spliced, never terminated**, for all three agents at first release. Destination validated at CONNECT via SNI; connection passed through undecrypted | R5.15. Required for Antigravity on ToS grounds (R5.13, D9); consistency avoids two trust models side by side; removes CA generation, distribution, rotation and per-agent trust-store config from a build that never scoped it | **No content-level DLP anywhere in the architecture.** The channels carrying 100% of prompt and completion content are inspected for hostname and byte count only. Remote MCP tool invocations to allowlisted hosts cannot be inspected or logged. Accepted; destination narrowing plus audit is the residual control. **Amended at the 01.3 build:** splice is intact — no destination TLS is terminated anywhere — but the AGENT-to-mediator hop is now TLS for `claude` and `agy` (criterion 6, SF-3), which is a second, unrelated TLS relationship and is why T28's pass text was amended to name the *destination* chain. `codex`'s hop stays plaintext because it rejects an `https://`-scheme proxy URL at parse time, and its single listener nevertheless carries a **bumping** certificate: Squid loads no signing context on a peeking port without `tls-cert=`, parses cleanly, and then declines to bump — the SNI control would enforce nothing. That certificate is never presented on an allowed path and `codex` never validates it (01.3 Deviation 5) | **TLS MITM for Claude Code and Codex, splice for `agy`** — rejected: runs two trust models, adds unscoped CA work, and buys URL-path granularity the requirements do not ask for. The mediator is positioned so termination can be added later without redesign (R15.2); R5.12 records the CA mechanisms (`NODE_EXTRA_CA_CERTS`, `CODEX_CA_CERTIFICATE`, `AWS_CA_BUNDLE`) against that later phase |
| D5 | **Egress policy is three independent controls in order**: (1) default-deny allowlist of domains and CIDRs evaluated at CONNECT/SNI; (2) post-resolution CIDR denylist; (3) per-agent rate and concurrency limits | R5.2/R5.3/R5.5/R5.7. An allowlist alone breaks on CDN IP rotation and DNS rebinding, which an `ipset` snapshot taken at container start cannot catch. Rate limiting is the only control that bounds a runaway loop against the model API — a cost-exhaustion failure that generates *only allowlisted traffic* and is therefore invisible to controls 1 and 2 | Three evaluation stages per connection; the rate limiter needs per-agent identity to be meaningful (D6). **Amended at the 01.3 build, three ways.** (1) Control 3 ships **two of its three ceilings**: Squid 6.13 has no per-client connection-rate directive at all, so `connections_per_minute` was dropped from the schema rather than left to enforce nothing — `max_concurrent` and `bytes_per_second` are enforced, and the compiler now refuses an artifact that declares the third (Deviation 4). (2) Control 1 gained an **FQDN deny** (`deny_fqdns`), closing an R5.1 MUST that 01.1's approved contract had explicitly denied the need for. (3) **The order within control 1 is itself a control:** the per-agent allowlist gate is evaluated before the post-resolution address deny, because a `dst` ACL forces the mediator to RESOLVE the CONNECT host — an attacker-chosen name would otherwise be resolved through the mediator's own upstream, on no audit line, before being refused | **Allowlist only** — rejected, R5.7 requires the post-resolution check. **Denylist only** — rejected by R5.2: exfiltration succeeds to any host not on the list |
| D6 | **Per-agent workload identity (mTLS) at the mediator is a hard precondition for any credential brokering**, not a later enhancement. **Built at the 01.6 build (2026-09-09), and in three forms rather than one.** *Cryptographic* — `claude` presents a client certificate to a required-mode `clientca=` front listener, issued by the offline CA 01.3 SF-3 narrowed. *Credential* — `codex` and `agy` present a per-agent proxy credential; SF-1 measured that both clients construct `Proxy-Authorization` from proxy-URL userinfo preemptively, which is the surface the plan had assumed did not exist for either. *Structural* — all three sit alone on their own `internal: true` segment, so network membership names the agent even where nothing is presented. **The precondition this row states is unchanged and now discriminates: the Milestone 03 brokering gate is `listener+mtls` alone, so `claude` only.** A proxy credential is a real identity — it is presented, verified and audited — but it is not a cryptographic one, and for `codex` the concrete reason is that its hop to the mediator is plaintext (D4), so the credential crosses the agent network in the clear | R8.8, promoted to MUST at Gate 1. A mediator that injects an upstream credential because "a request arrived from the pod network" hands *every* agent *every* brokered credential — a textbook confused deputy, and because the mediator is also the policy decision point the resulting audit lines look legitimate. Brokering without caller identity is worse than no brokering | Identity issuance, rotation and lifecycle are real work inside the M1 estimate, not adjacent to it. **Two costs surfaced at the 01.6 build and neither was anticipated.** (1) **The mediator cannot warm its own cascade for an authenticating agent** — the warm-up reaches its target through that agent's own front listener, which now demands a certificate the mediator does not hold or a credential it cannot construct (it holds the htpasswd, which is hashes). The gate is `client_auth == none`, so `claude` and `agy` are both excluded and each may have its first request after a mediator start answered 500 and retried; see Startup self-checks and Accepted risks (01.6 Deviations 1 and 9). (2) **Generated trust material legitimately mounted into an agent trips every harness's "is this mount control plane" predicate** — see D22 | **Broker on network origin** — rejected, the confused-deputy pattern above (red-team Critical finding). **Defer brokering entirely** — viable but forfeits R6.5 Model B, which Gate 1 selected. **Treat the credential form as sufficient for brokering** — rejected at 01.6: it is presentable identity, not bound key material, and `codex` presents it over a plaintext hop |
| D7 | **One state volume per agent; no shared volume, no shared build cache** | R4.3, R2.5, R2.10. Claude Code cannot read Codex's `auth.json` — a filesystem property, and with D2 a network property too. A cache shared across agents is a cross-agent write channel | Duplicated package/build caches cost disk and rebuild time | **Shared cache volume** — permitted by R2.10 only as a recorded accepted risk with blast radius stated. Not taken; the default is per-agent (`off` in the PRD configuration table) |
| D8 | **`AUTH_MODE` is per agent**, defaulting to the safest mode each agent supports. **Amended at the 01.4 build (2026-09-07): the four modes are not uniformly available — the matrix is seven supported cells, not twelve.** `claude`: `apikey` \| `oauth-interactive` \| `oauth-token`. `codex`: `apikey` \| `oauth-interactive` \| `oauth-mount`, where the interactive cell requires `--device-auth` because plain `codex login` strands on an in-container callback port the host browser cannot reach. `agy`: `apikey` only (D9). An unsupported agent/mode pair and an unset `AUTH_MODE` both fail closed at exit 2. T24's pass criterion was amended in the same build to "no browser inside the container", replacing "no interactive terminal" | R4.12. The agents are not symmetric: Claude Code's credential is macOS-Keychain-resident and not portable to a Linux container; Codex's `auth.json` is plain JSON and mountable; `agy` has no working OAuth env-var path (upstream issue open) | Four code paths in the entrypoint instead of one | **API key everywhere** — rejected, Claude Code and Codex subscription auth is OAuth. **OAuth everywhere** — rejected, `agy` takes `apikey` by decision D9 |
| D9 | **Antigravity authenticates by `GEMINI_API_KEY` only.** No Antigravity OAuth credential enters any container. TLS interception of `agy` traffic is permanently barred | Open Decision 2, settled at Gate 1 (R14.3). Google's Additional Terms §6 prohibits "using third party software, tools, or services to access the Service"; Google has suspended paid accounts without warning over it, and staff declined to clarify the boundary. The API-key route leaves the OAuth relationship entirely rather than proxying it | Routes to the public Gemini API on the operator's own billing rather than the Antigravity account quota — the accepted cost. **The route itself is UNVERIFIED**: the official install page documents it, a June 2026 maintainer statement says Gemini API keys are not supported. Must be tested against the pinned `agy` version; fallback is Antigravity OAuth with splice-only and no proxy tooling, which leaves the ToS question open rather than sidestepped. Requires `"modelProvider": "gemini"` in settings **and** the env var — the variable alone is a documented no-op | **Antigravity OAuth + splice** — the fallback, not the default. **Antigravity OAuth + MITM** — permanently barred (R5.13): arguably within the clause actually enforced against |
| D10 | **The use-case profile drives the image build as well as the run.** OS packages are declared per pack, version-pinned, from a declared repository, installed at build time only. The agent process cannot invoke a package manager at runtime. **Amended at the 01.5 build (2026-09-07/08), in three ways.** (1) A pack declares egress, OS packages and nothing else: `mounts`, `env` and `credentials` are validated and then **refused at exit 3**, naming a different landing point for each, because the resolved-policy schema has no field for them and a silently dropped declaration is indistinguishable from a correctly refused one (Deviation 5). (2) `git` is installed in the `agent-base` stage rather than supplied by a pack — a deliberate departure from the composition model this decision describes, because R2.9's host-gitconfig mount and its scrub script are *profile*-level features and are inert without a `git` binary, so a profile could enable them, pass every gate, and still mount a file nothing reads (Deviation 2). (3) A pack's declared version may be forced by the base image: `language-runtimes` declares node 22.23.2, the version `node:22-slim` ships, because installing the originally specified 20.18.1 alongside would leave two runtimes on `PATH` (Deviation 1) | R7.18/R7.19. This is what keeps R7.7 (checksum/signature verification, no `curl \| bash`), R7.16 and SC-8 (identical clean rebuild) satisfiable once packs may add OS packages | A profile change that touches packages is a rebuild, not a restart. Each profile pins to a distinct image digest, so "the image" is per-profile rather than universal | **Runtime `apt install` from a pack manifest** — rejected: defeats SC-8's reproducibility and R7.7's verification simultaneously, and hands a compromised agent a package manager |
| D11 | **Recording and export are separate concerns.** A profile may disable an *export*; it cannot disable the underlying *recording* | R9.9 against R9.1/R9.7. The recording path is wired to the mediator and the audit sink, not to the profile's export toggles, so there is no profile setting that can switch recording off. Any disabled export is explicit and recorded | An operator who disables an export still pays the cost of recording | **One toggle for both** — rejected: makes R9.1's mandatory blocked-attempt logging profile-defeatable, and the blocked attempt is the detection signal |
| D12 | **The audit log is written inside the mediator or shipped directly off-host — never to a volume an agent container can reach** | R9.1/R9.7 require recording outside the blast radius. Five Eyes L658: "Isolate agents into enclaves with no write access to logs." A log the agent can edit is not evidence | A mediator-local log shares the mediator's fate; off-host shipping adds a destination that must itself be allowlisted and governed. **Given a concrete form by 01.3 SF-7:** one JSON object per line, per connection attempt, allow and deny alike, carrying `agent`, `identity_source`, destination, resolved address, verdict, and — on a denial — the refusing control, a reason token and the policy path an operator edits. `identity_source` read `listener` on every line through 01.5 and said so, so a network-derived attribution could never later be read as a cryptographic one. **01.6 extended the enumeration to three values — `listener`, `listener+mtls`, `listener+proxy_auth` — and the enumeration is the point: the reader can tell which mechanism named a given entry, which is what makes D6's brokering gate expressible against the log.** Non-verdict lines carry an `event` key and no `verdict` key, which is what lets a consumer select on `verdict` and see only verdicts. Four consequences worth naming. A bumping listener logs the CONNECT acceptance separately from the outcome, so the acceptance is emitted as an event rather than as an allow. The mediator warms its own cascade at start (01.3 Deviation 10), which puts one such event per fronted agent on the trail under that agent's listener — **for the `client_auth: none` agents only since 01.6**. **The two refusal forms differ in kind and the harness asserts each literally** (01.6 Deviation 7): an `mtls` subject mismatch is `403` with `control=identity`, `reason=subject_mismatch` and a body; a `proxy_auth` miss is Squid's own `407 Proxy Authentication Required`, with `control` and `reason` both null and no body — a missed `proxy_auth` ACL halts ACL evaluation on its own line, so no rule that could name an error page is ever reached. Keeping them distinct is deliberate: 403 means "policy refused this destination", 407 means "this listener wants a credential". And **a cert-less refusal is not literally silent** (01.6 Deviation 2): it produces no *verdict* line, but one `{"event":"proxy_internal","detail":"error:transaction-end-before-headers"}` — no `agent`, no `dest_host`, no `identity_source`, because there were no request headers to derive any from. The property the design wanted (the trail says nothing that identifies the attempt) holds; the earlier wording "no audit line at all" was false against the pinned Squid | **Shared log volume mounted into each agent** — rejected outright, puts the evidence inside the blast radius |
| D13 | **AWS access uses Model B (brokered short-lived credentials), gated on D6.** Model C is prohibited | R6.5, R6.5.1. A container-resident SSO token entitled to the operator's permission sets gives a compromised agent organisation-wide access regardless of which config file is mounted. Model B is independently corroborated by the Five Eyes static-credential position — but only if the broker knows *which* agent is calling, which is D6 | Model B cannot be enabled until R8.8 is satisfied. Q1 (which accounts and services) and Q9 (whether a dedicated Identity Center principal can be created) are both open and both sit inside M1 | **Model A** (scoped SSO token for a *dedicated* Identity Center identity, R6.5.2) — the register rates it "acceptable, the simplest model that is actually bounded", but it is **not a fallback for a negative Q9**: R6.5.2 requires a dedicated Identity Center user or group just as Model B requires a principal to broker from. See the Q9 note below. **Model C** (operator's own identity, trimmed config) — prohibited by R6.5.1: "the appearance of scoping without the substance" |
| D13a | **A negative answer to Q9 leaves no compliant AWS credential model, and the AWS pack cannot ship.** This is recorded as a gate on the pack, not as a risk to be managed during it | Model C is prohibited outright (R6.5.1). Model B requires an Identity Center principal to broker from. Model A requires, under R6.5.2 (MUST), "a dedicated Identity Center user or group ... assigned **only** the agent permission set". All three paths therefore depend on the estate change assumption A5. If it does not hold, there is no remaining model that satisfies R6.5 | M1 includes the AWS CLI pack, so a negative Q9 forces an M1 rescope rather than a substitution. Surfacing it at Gate 2 is cheaper than discovering it mid-milestone | **Treat Model A as the fallback** — rejected on reading R6.5.2: it carries the same dependency. **Mount the operator's `~/.aws`** — prohibited by R6.3.1, which on this host would hand a compromised agent `OCC-Root-Admin` across the tenant. **Ship M1 without the AWS pack** — the actual fallback, and a scoping decision for Gate 3 |
| D14 | **Each agent's native sandbox is enabled inside the container as defence in depth, and is not counted as a boundary** | R3.7. `srt` for Claude Code, `features.network_proxy` for Codex, `--sandbox` for `agy`. All three are reachable and therefore modifiable by the agent process. One has a property worth naming: `srt` hard-denies writes to `.mcp.json`, `.claude/commands` and `.claude/agents` at the project root — a partial mitigation for R7.17 configuration integrity, covering Claude Code only | Enabling them costs configuration surface and can mask which layer actually blocked something during debugging. **Amended at the 01.2 build (2026-09-04): all three native sandboxes are DISABLED by default, not enabled.** Each was found to conflict with the outer container rather than nest inside it — Codex's bubblewrap needs `SYS_ADMIN` plus `seccomp=unconfined` (R3.8 already anticipated this), and the other two were disabled on the same reading of R3.8: where an inner sandbox cannot nest without weakening the outer container, it is disabled instead. The decision's *substance* is unchanged — a native sandbox was never counted as a boundary (R1.2) — but its default is now off, and this row previously read as though the defence in depth were free. Re-enabling any of them is a per-agent decision with the nesting cost stated | **Rely on native sandboxes** — rejected by R1.2: they sit inside the blast radius. **Disable them** — rejected: free defence in depth. Note R3.8: where an inner sandbox cannot nest without weakening the outer container it is disabled instead — Codex's bubblewrap nesting needs `SYS_ADMIN` plus `seccomp=unconfined`, which violates R1.4 |
| D15 | **Agent containers run hardened by default**: `cap_drop: ALL`, `no-new-privileges`, read-only root filesystem with `tmpfs` scratch, non-root user, and explicit CPU/memory/PID ceilings | R1.3, R1.4, R1.6, R1.10. Resource limits are not decoration: without them a prompt-injected agent stuck in a loop exhausts the host and burns the model subscription while generating only allowlisted traffic that the design logs as normal. Option 3 gets these free from its VM boundary; Option 2 must declare them | Read-only rootfs requires every writable path to be enumerated as a `tmpfs` or volume, which surfaces as build friction | **Default Docker posture** — rejected by R1.4. Any capability added must be individually justified here; none currently is |
| D16 | **Containment is designed in, not improvised.** A single agent can be stopped or detached without affecting the others; per-credential revocation procedures are documented and tested with a stated maximum detection-to-revocation time; the return-to-known-good path explicitly names what happens to each persistent state volume | R13.1, R13.2, R13.3 — the response side of D1's accepted weakness. Per-agent networks (D2) make single-agent isolation a native property rather than a special case | R13.3 is the hard one: a contaminated state volume currently cannot be distinguished from a clean one. The path therefore says *discard and re-bootstrap*, which costs a re-authentication per agent | **Rebuild everything on any incident** — safe but forfeits the state persistence SC-4 exists to provide. **Leave it to the incident** — rejected by R13.x and by red-team finding F7 |
| D17 | **The egress allowlist is seeded from a constrained Option 1 discovery run, then cross-validated — never adopted from the capture alone** | R5.8 requires an observed, minimal allowlist; vendor reference lists are stale (Anthropic's permits retired telemetry hosts and omits the OAuth endpoints). Option 1's `sbx` is the fastest observation point. R14.1 governs it: Docker Sandboxes' retention and data-handling terms for intercepted traffic are **not established** (Open Decision 3), so the run uses a **synthetic repository and throwaway credentials only** — the constraint is the mitigation | One closed-source observation point cannot establish completeness: `sbx` fully intercepts only HTTP/HTTPS and blocks UDP/ICMP entirely, so a legitimate UDP dependency is invisible in the capture and surfaces later as a novel failure. Cross-validation against agent verbose logging or `tcpdump` on the mediator during a shadow run is therefore mandatory, and the allowlist is provisional until both sources agree | **Copy the vendor reference allowlists** — rejected by R5.8. **Derive by hand from documentation** — rejected: the documentation is demonstrably stale and incomplete (the full Antigravity allowlist is not published by Google at all) |
| D18 | **MCP servers and tools are default-off, inventoried, version-pinned, and declare their own egress.** The stdio blind spot is recorded, not papered over | R7.14–R7.17. Default-deny was previously applied rigorously to the network and not at all to tools. Each server records a risk tier (read-only / write / irreversible) and a capability baseline, so capability *drift* is detectable rather than only new servers | **stdio MCP servers execute inside the blast radius and their traffic never crosses the enforcement point.** No control in this architecture sees a stdio tool invocation. The default transport per agent per server is itself UNVERIFIED. R7.17 is only partly mitigated, and only for Claude Code, by `srt` (D14) | **Inherit the agent's allowlist** — rejected: sizes every server's reach to the agent's. **Wholesale registry allowlisting** — rejected by R7.16: it undermines any inventory |
| D21 | **The base image is built by GitHub Actions and published to GitHub Packages (GHCR), consumed by digest.** Builds run from the working branch during the project and move to `main` on completion. **Single-architecture, `linux/arm64` only (01.5 Deviation 15)** — this row read as architecture-neutral when written, which it is not: `images/apt-pinned.sh` verifies `git` against the `.deb` `apt-get download` fetches for the container's own dpkg architecture, and `compose/pins.env` carries one `GIT_SHA256`, the arm64 one. An amd64 runner fails at that checksum comparison. Going multi-architecture is therefore a **second separately verified pin** in `pins.env` plus a `platforms:` line, in that order — not a runner-label change — and an operator on an x86 workstation cannot consume the published base at all, since the digest pin resolves to an index with no matching platform. Bounded by R11.1 / assumption A1 (Docker Desktop on Apple silicon) | Removes the last manual step between version control and a running environment, which is what SC-8 asks for and what a local `build.sh` could only approximate. A registry-published image has a stable digest to pin (R10.2), and CI is where SBOM emission and provenance attestation actually become practical (R10.7, currently MAY) | This repository has **no `.github/` directory today** — this introduces its first workflow, and CI becomes a build-time dependency the repo did not previously have. The published image is a supply-chain artifact: it must be consumed by digest rather than by a mutable tag, or the pinning R10.2 requires is defeated by the convenience of `:latest`. Branch-built images must not be consumed by anything but testing. **The boundary of what belongs in the published base moved twice, both times because a local edit reached nothing.** `SKEL_MARKER` moved out at 01.5 SF-6b and `images/entrypoint.sh` with its `ENTRYPOINT` moved out at 01.6 SF-3 (Deviation 10), both into `agent-packs`: BuildKit skips a stage nothing references, so once the agent stages consume the base by digest, an edit to a base-stage file is invisible to a local build. What D21 protects is intact — the base an operator runs is still the base CI built and attested — but the consequence is worth stating plainly: **the pod's start-up logic is now repository-versioned rather than digest-pinned**, which is the right ceremony for a 145-line shell script and the wrong one for a supply-chain base, and **the published base no longer carries an `ENTRYPOINT`, so `--target agent-base` now produces a rootfs rather than an independently runnable image.** CI was checked before the move rather than after: the workflow holds no `docker run`, no smoke step and no `--version` invocation against the built base, so removing the `ENTRYPOINT` cannot fail it. `images/bootstrap-auth.sh` was deliberately left in `agent-base` and carries the same latent property | **Local `build.sh` only** — the original draft; rejected by the operator: reproducibility stays operator-dependent and R10.7 attestation stays impractical. **Build from `main` immediately** — rejected for now: the project needs a testing path before `main` is meaningful. The promotion to `main` is the stated completion trigger |
| D20 | **R9.7's agent action log is carried by shipping each agent's own session transcript off-container in real time, and its limitation is stated rather than designed around** | R9.7 is a MUST and needs a named component. No option in the analysis intercepts a tool call, so no architecture here can *derive* an action log from observed behaviour — the only available source is the transcript each agent already writes. Shipping it in real time to an append-only sink puts the record outside the blast radius (R9.2) | **The agent authors its own transcript.** The record is complete-as-written, not tamper-proof at source: a compromised agent can write a false line before it ships. Real-time shipping buys tamper-*evidence*, not tamper-*resistance* — a retroactive edit on the volume does not propagate to the sink. **Attribution still waits on R8.8** (D6): until then the transcript says what happened, not which agent identity did it | **Derive the action log from egress** — impossible: destinations only, and stdio never crosses the enforcement point. **Wrap each agent to intercept tool calls** — this is R15.1's non-goal and a larger undertaking than the sandbox. **Record R9.7 as unmet** — rejected: an available source exists, and R9.7 is a MUST. The residual weakness is recorded in Controls This Architecture Does Not Provide rather than hidden |
| D19 | **This repository holds the sandbox as copyable content, not as a running deployment.** The compose files, Dockerfiles, profiles, pack manifests and policy sources are version-controlled here and copied into the consuming workstation or repository, matching the convention every other kit in `solutions/` follows | The repository README states its scope as "No runtime code. Copy content into other repositories where it is consumed." This solution would otherwise be the first deployable runtime system in the repo. Treating the artifacts as copyable content resolves the tension without weakening SC-8: R10.1 requires the environment be defined entirely in version-controlled files, and it is — here | The operator performs a copy step before first run, and a copied tree can drift from its source. R12.9 keeps this honest by making `docker compose` with a profile-selected override the entry point, with no wrapper CLI hiding the mechanics. **Amended at Gate 2:** the *base image* is not copied — it is built and published by CI and consumed by digest (D21), so only the declarative files travel | **Run the pod from this repository directly** — rejected: contradicts the repository's stated scope and makes the kit non-reusable across workstations. **Split into a separate repository** — viable, and the right move if the sandbox acquires its own release cadence; rejected now as premature for a one-workstation scope (Q2, assumption A1) |
| D22 | **"Which mounts may this agent hold?" is one question, and it is currently answered independently in all four acceptance harnesses, in two overlapping flavours.** *Containment* — "is this source control plane?" — is held by `verify-egress-mediator.sh` (01.6 Deviation 4), `verify-pack-composition.sh` Phase G SC-3 and `verify-pod-topology.sh`. *Mount-set equality* — "what should this agent mount, exactly?" — is held by `verify-pod-topology.sh`, `verify-pack-composition.sh` and `verify-auth-state.sh` (Deviation 6). No copy delegates to another. Recorded here as a decision because 01.6 Deviations 5 and 6 both assign the consolidation to `/design` rather than to a feature | Generated trust material that legitimately lives under `mediator/` and is legitimately mounted into one agent trips **every** copy: a Compose `file:` secret is a bind mount, so `claude-client.key` matches `verify-egress-mediator.sh`'s `*/agent-containerization/mediator*` **and** its `*.key`, and it breaks every mount-set equality assertion at the same time. An agent's own workload identity is not control plane — it is read-only, it is what the agent authenticates with, and holding it is the point (D6). Each copy therefore needed the same exception written separately, and each was deliberately **name-scoped to the agent's own pair** (`*/clients/<agent>-client.crt\|.key`) rather than widened to `*/clients/*`, so `claude` mounting `agy`'s key is still caught | Four files to keep in agreement, and the count is empirical rather than designed: Decision 8 of the 01.6 plan enumerated five shipped assertions that would break; **seven** did, the sixth and seventh found by running harnesses the plan had said to verify rather than assume. A fourth agent-mounted secret repeats the whole exercise. **One copy is worse placed than the others:** `verify-auth-state.sh` is excluded from the composite Test Command by design — its Phase D costs the operator a real credential refresh — so its two mount-set failures were found only by running it by hand, and the feature-completion gate would otherwise have closed green over them. An assertion outside the Test Command is an assertion the gate cannot protect, and being excluded for a good reason does not stop it rotting | **Leave the copies** — rejected: 01.6 demonstrated they drift apart under exactly the change they exist to catch. **Widen each exception to `*/clients/*`** — rejected: it would admit one agent mounting another's key, which is the property T34's structural form rests on. **Consolidate into one shared predicate** — the intended direction, deliberately unscoped here: this row records the obligation and its owner, not the refactor, which belongs to a feature. A cheap mount-set-only mode of `verify-auth-state.sh`, admissible to the composite because it spends nothing, is the candidate shape for the excluded copy |

## Component Inventory

| Component | Responsibility | Interfaces |
|-----------|---------------|------------|
| **`claude` container** | Runs Claude Code non-interactively (R3.1). Pinned version, auto-update disabled (`DISABLE_AUTOUPDATER=1`, R3.5). `srt` native sandbox **off by default** (R3.7, D14 as amended — it does not nest inside the container) | Attached to `claude-net` only. Proxy listener on the mediator; mediator-served DNS. Mounts: project dir, `claude-state` volume. Env: `AUTH_MODE`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`. **Carries a client certificate (`CLAUDE_CODE_CLIENT_CERT`/`_KEY`) mounted as a Compose `file:` secret — the pod's only *cryptographic* workload identity (D6, 01.6).** Its front listener runs `clientca=` in required mode, so a cert-less connection is refused at the handshake with no verdict line (D12). Consequence of that mode: the mediator cannot warm this agent's cascade peer, so the first request after a mediator start may be answered 500 and retried (01.6 Deviation 1) |
| **`codex` container** | Runs OpenAI Codex CLI non-interactively (`codex exec`, R3.2). Pinned, auto-update disabled. `features.network_proxy` **off by default** (D14 as amended); bubblewrap nesting **disabled** — it needs `SYS_ADMIN` + `seccomp=unconfined`, violating R1.4 (R3.8) | Attached to `codex-net` only. Mounts: project dir, `codex-state` volume. Requires `cli_auth_credentials_store = "file"` under `oauth-mount`. **Egress needs `Upgrade` permitted on TCP/443** — Codex defaults to WebSocket transport and silently degrades otherwise (R5.9). **Carries a per-agent proxy credential, not a client certificate (D6, 01.6)** — it rejects an `https://`-scheme proxy URL at parse time, so no TLS listener is reachable to present one on. SF-1 measured that it nevertheless constructs `Proxy-Authorization` from proxy-URL userinfo preemptively, which is the surface the identity rests on. **Its hop to the mediator is plaintext, so the credential crosses `codex-net` in the clear** — the concrete reason `codex` is outside the Milestone 03 brokering gate |
| **`agy` container** | Runs Google Antigravity via the `agy` CLI non-interactively (R3.3). GUI explicitly not containerized (R3.4). `--sandbox` **off by default** (D14 as amended) | Attached to `agy-net` only. Mounts: project dir, `agy-state` volume. Env: `GEMINI_API_KEY` **and** `"modelProvider": "gemini"` in settings (D9 — env var alone is a documented no-op). **Exit status is read from the JSON `status` field, not the exit code** — `agy` soft-denies unapproved tools and still exits 0 (R3.6). **Carries a per-agent proxy credential (D6, 01.6)** — it reaches the TLS `CertificateRequest` stage with nothing to offer, so the credential form is its only presentable identity; its hop to the mediator is TLS, unlike `codex`'s. Its front listener demanding a credential the mediator cannot construct (it holds only the htpasswd) means `agy` is excluded from the cascade warm-up alongside `claude`, with the same first-request-500 residual (01.6 Deviation 9) |
| **`egress-mediator` container** | The single enforcement point and the only path to the internet (R1.2). Five roles in one process boundary: L7 CONNECT/SNI policy evaluation, authoritative DNS for the pod, audit writer, **verifier of per-agent workload identity in both forms — mTLS terminator for `claude`, `proxy_auth` authenticator for `codex` and `agy` (D6, 01.6)** — and (gated on D6) upstream credential broker. **Implementation selected and pinned at 01.3 SF-1: Squid 6.13 (`squid-openssl`), with `dnsdist` 1.9.16 and `unbound` 1.22.0 as the two-daemon resolver (D3) and a small `bash` audit writer.** `iron-proxy` was not taken. Every property the design rests on was verified against exactly these builds, which is why the versions and the base-image digest are pinned together — see `docs/records/mediator-selection.md` | Multi-homed onto `claude-net`, `codex-net`, `agy-net` and the external network. Exposes **exactly two ports to each agent network** — the proxy listener (3128) and the resolver (53, UDP and TCP) — and no management or metrics port (see [Mediator hardening](#mediator-hardening) below). **The proxy is five listeners, not three (01.3 Deviation 1):** Squid cannot both terminate the agent-to-mediator TLS hop and peek at the client's ClientHello on one port, so each TLS-fronted agent gets a front listener on its own network plus a peeking inner listener on **loopback inside the container**, and `codex`'s single plaintext listener does both. The inner listeners are not reachable from any agent network, which is what keeps the cascade inside criterion 1's "exactly {proxy, resolver}" enumeration; the acceptance harness asserts it by port sweep from each agent network. Reads the resolved egress policy; writes the audit stream to the sink. Broker secrets and the listener certificates injected at runtime through Compose `secrets:`, never baked into the image and never on an agent-reachable volume. **The CA private key is not injected at all — 01.3 SF-3 narrows issuance to an offline operator script and keeps the key on the operator host**. **Since 01.6 it also verifies workload identity, in two mechanisms:** the CA *certificate* it already held now backs `clientca=` in required mode on `claude`'s front listener, and a **htpasswd** — hashes, never plaintext — backs `proxy_auth` on `codex`'s and `agy`'s. It holds no agent's private key and no agent's plaintext password, which is why it cannot answer its own listeners and cannot warm their peers (D6). One non-obvious dependency: **Squid does not forward `Proxy-Authorization` to a `cache_peer` parent**, so the inner listener cannot re-check the credential and annotates on the front's word. That is sound only because the front's bare enforcement deny refuses a credential-less request before any rule that can forward — remove it and the inner annotation becomes false (01.6 Deviation 8) |
| **`claude-net` / `codex-net` / `agy-net`** | Per-agent isolation segments, `internal: true` — no default route, no DNS path to the internet (D2, D3) | Each carries exactly one agent container plus the mediator. Each declares an `ip_range` inside its subnet so IPAM cannot allocate the mediator's static address to a starting agent (01.5 Deviation 19) |
| **External network** (`egress-net`) | The mediator's only route out | Mediator only. No agent container is ever attached. **Declared but not a live Docker resource until 01.3 SF-4 attached the mediator to it** (01.2 Deviation 3, now closed): 01.2 could declare the network but nothing joined it, so its properties were unasserted for one feature |
| **Per-agent state volumes** (`claude-state`, `codex-state`, `agy-state`) | Persist agent authentication and session history across container restart and image rebuild (R4.1, SC-4). One per agent, never shared (R4.3, D7) | Mounted into exactly one agent container each. Excluded from backups (R8.7). Hold long-lived refresh tokens — the accepted risk of R4.16 |
| **Project mount** | The working directory — the only host directory mounted by default (R2.1). `:ro` where the agent only reviews (R2.7) | Bind mount, declared in the profile. Symlinks cannot escape the mount root (R2.6) |
| **Use-case profile** | Version-controlled declaration of tool packs, mounts, `AUTH_MODE` per agent, OS packages and export toggles (R2.2, R7). Nothing is passed ad hoc on the command line | Input to both the policy compiler and the image build (D10). The unit SC-6 is measured against |
| **Tool packs** | Composable capability units. Each declares its own egress entries and its OS packages (pinned, from a declared repository). **A pack does not declare mounts, environment variables or credentials — all three are refused at exit 3 (01.5 Deviation 5).** Only `language-runtimes` is built (01.5 SF-1); Terraform, Kubernetes and GitHub CLI arrive at 02.3 and AWS CLI at 03.3 | Consumed by the policy compiler and the image build. Adding a pack must not require hand-editing the security policy (SC-6) |
| **Policy compiler** | Composes the resolved egress policy from the profile plus its enabled packs, and emits it as a reviewable artifact. This is the mechanism that makes SC-6 true rather than aspirational. Emits every list `LC_ALL=C` sorted and deduplicated, because the drift gate is a byte comparison and an emitter whose output depends on input order makes that check fire on identical policy (01.5 Deviation 7). Exit codes are contractual: 1 invocation error, 2 validation failure, 3 refusal, 4 drift (01.5 Deviation 4). It also carries the project-mount containment gate, compared lexically rather than through `realpath` so it behaves identically on the host and in the compile stage (01.5 Deviation 3, SC-3). **A collision between the base allowlist and a pack on the same `(agent, fqdn, port)` with different `upgrade` values is refused at exit 3, naming both sources** (01.5 Deviation 6); identical tuples dedup silently. Every alternative loses information — base-wins silently drops a pack's declared need, and pack-wins or OR lets third-party content overwrite the base record for a destination the base already governs (R5.14). The refusal's recorded reason is narrower than the one first drafted: an OR would produce a **contradictory policy record**, not a live enforcement widening, because `upgrade` is R5.9 metadata and the renderer reads only `fqdn` and `port`. **The gap this leaves is real rather than an oversight: the schema has no way to express a legitimately pack-specific `upgrade` on an identical host and port**, so a future pack needing `upgrade: true` where the base says `false` requires an edit to the base allowlist. That is the intended direction — the base is canonical for a destination it already governs — but it is a schema limitation, and closing it is a manifest/resolved-schema change | Reads profile + pack manifests; writes the resolved egress policy artifact consumed by the mediator. Startup self-check aborts on a corrupt policy (T17) — and it is **the same script** the mediator calls in `--validate` mode at start, so "valid" cannot mean two different things at the two ends. `--allowlist`/`--denylist` select alternate bases, which is how the acceptance harness compiles a test-scoped artifact without putting fixture hostnames into the discovery-derived allowlist (01.3 Deviation 11); every artifact records the bases it was built from. **A standing property, named at 01.6 because it first bit there (Deviation 3): a compiler or profile-schema change is gated by the build for `default` alone.** The two test-scoped artifacts are *carried through* the compile stage rather than recompiled by it — their declared bases sit deliberately outside the mediator's build context (01.5 Deviation 9) — and the drift gate then compares each copy against the file it was copied from, so their staleness is invisible to the build. They must be recompiled on the host **in the same commit** as any such change, or the harnesses run against a policy the mediator would refuse to load. 01.6's `client_auth` key invalidated all three artifacts, not the two the plan listed |
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
  host. The mediator receives only the listener certificates it presents and the CA *certificate*,
  which since 01.6 backs `clientca=` on `claude`'s front listener, so a mediator compromise no
  longer yields the ability to mint agent identities. See `mediator/identity/README.md`.
- **The identity material each side holds is deliberately asymmetric (01.6).** The mediator holds
  the CA certificate and a **htpasswd** — hashes — and therefore cannot construct any agent's
  credential, which is what makes the warm-up exclusion (D6) a mechanism rather than a choice. Each
  agent holds only its own material: `claude` its client certificate and key, `codex` and `agy`
  their own `mediator/identity/credentials/<agent>.cred`, all mounted `:ro` as Compose `file:`
  secrets. **A credential file carries `<username>:<password>` — the whole userinfo string, not the
  secret alone** (Deviation 11). The username the mediator matches is the *resolved policy's*
  `identity`, and the only token resembling it inside an agent container is the image-baked
  `AGENT_NAME`: equal in every shipped profile, kept equal by nothing. Deriving it in the container
  would put a silent wrong-username 407 one profile edit away, on a path whose failure mode is
  "this agent reaches nothing". Issuance writes the username and verifies it against the policy each
  time; delivery never guesses it, and `rebuild_htpasswd` reads it back from the file so the two
  halves of one credential cannot disagree after a profile edit. The proxy URLs in `compose.yaml`
  stay credential-free and so does `docker inspect` — the agent entrypoint splices the userinfo into
  `HTTPS_PROXY`/`HTTP_PROXY` at start (Deviation 10).
- Exactly **two** ports exposed to each agent network — the proxy listener and the resolver — and
  no management or metrics port on any agent network. **Amended from "exactly one" at the 01.3
  build:** D3 makes the mediator the pod's DNS authority, which is a listener the original text
  did not count. The peeking inner listeners of the proxy cascade bind loopback *inside* the
  container and are unreachable from any agent network; the acceptance harness asserts the
  reachable set from each network rather than reading it off the Compose file.
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
  → mediator FRONT listener on that agent's network            (3128; TLS for claude/agy, plain for codex)
      ├─ terminates the agent→mediator proxy hop (D4 amendment) — TLS-fronted listeners
      │   cannot also peek, so the front decides on the CONNECT authority alone
      ├─ identity (R8.8, D6 — built at 01.6): the arriving listener always names the
      │   agent (agent ↔ port ↔ network are 1:1), and the front then VERIFIES what
      │   the agent presents — clientca= for claude, proxy_auth for codex and agy.
      │   THE TWO ANNOTATION IDIOMS DIFFER, and the mtls one does not transpose:
      │     mtls      — annotate idsrc=listener+mtls on the MATCH, override to
      │                 =listener on the miss path, with rsn_subject ctl_identity
      │                 trailing the same deny (which is what makes an mtls refusal
      │                 log control=identity, reason=subject_mismatch)
      │     proxy_auth— annotate idsrc=listener UNCONDITIONALLY on the _real port
      │                 set, then override to =listener+proxy_auth on a separate
      │                 rule gated by the credential ACL; the enforcement deny is
      │                 BARE. A proxy_auth miss halts ACL evaluation on its own
      │                 line, so every term after it is unreachable — transposing
      │                 the mtls shape here logged idsrc=- (01.6 Dev 8, measured)
      ├─ control 1a: allowlist match on the CONNECT authority     (R5.2)
      └─ cache_peer → mediator INNER listener on loopback         (not reachable from any agent net)
  → inner listener (ssl-bump peek at step SslBump1, then splice)
      ├─ DNS resolution by the mediator's own resolver            (R5.4, D3)
      ├─ control 1b: allowlist match on the TLS SNI               (R5.5 — catches domain fronting)
      ├─ control 2: resolved IP vs. CIDR denylist — deny wins     (R5.3, R5.7)
      ├─ control 3: per-agent rate / concurrency check            (D5)
      ├─ optional: inject brokered upstream credential            (D6, D13 — not built)
      └─ raw audit line → FIFO → audit writer → JSON audit sink
  → egress-net → destination
```

`codex` has one plaintext listener that does both jobs, so its path has no cascade hop — which is
why a `codex` denial is refused *after* the CONNECT is accepted and carries no error body.

TLS is spliced at the CONNECT boundary: the mediator peeks at the ClientHello to read the SNI,
then passes the connection through undecrypted (R5.15, D4). It sees hostname and byte count, never
payload. The certificate the destination presents is the origin's own, not the mediator's.

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

The resolver is two daemons, not one (D3 as amended at 01.3):

```text
agent stub resolver → agent-net → mediator :53 (udp/tcp)
  → dnsdist 1.9.16 — policy: the arriving subnet names the agent, the per-agent allowlist
      decides, and every decision (name, QTYPE, agent, verdict) is written to the audit sink
      before anything is forwarded; a refusal is REFUSED, never NXDOMAIN
  → unbound 1.22.0 on loopback:5353 — re-origination only: recursion, cache, and the
      RFC 6761 special-use zones (test., invalid., localhost., example.) answered locally
      and never forwarded
  → egress-net → upstream
```

Splitting policy from re-origination is what lets the audit line be written by the component that
made the decision. Note the RFC 6761 consequence recorded at 01.3 SF-8: names under `test.` cannot
be used for fixtures, because unbound answers them locally — the acceptance harness uses `.lab`.

### 4. Audit write path

Egress lines are written by the mediator; agent-action lines (tool invocations, file
modifications, privilege changes — R9.7) are recorded by the action recorder. Both land in the
audit sink, correlatable by session ID and timestamp (R9.8). Neither path traverses a volume an
agent container can write (D12).

**Attribution was conditional through 01.5 and is no longer.** Until 01.6 built R8.8's mechanism,
the egress log recorded *what happened* but not *who did it* — package-manager fetches, model API
calls and injected tool fetches arrived as an undifferentiated CONNECT stream. Since 01.6 every verdict line
carries an `identity_source` of `listener`, `listener+mtls` or `listener+proxy_auth`, and the
enumeration is what stops a network-derived attribution being read later as a cryptographic one
(D12). That is the dependency that turned a destination log into an agent log.

**Two limits survive it, and neither is closed by identity.** The *egress* log now attributes a
connection to an agent; the *action* log still does not attribute an action, because no component
intercepts a tool call and the transcript is authored by the agent itself (D20). And attribution is
not uniform in strength: `codex` presents its credential over a plaintext hop, which is why D6's
brokering gate reads `listener+mtls` alone rather than "any verified identity".

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

The tree as it stands after Feature 01.6, which closes Milestone 01. Paths marked *(not yet built)* in the comments below
are still target state; everything else exists and is exercised by the acceptance harnesses. It
follows the packaging convention set by `solutions/well-architected-review/` (D19).

```text
repository root/
└── .github/workflows/
    └── agent-sandbox-image.yml   # builds + publishes the base image to GHCR (D21). TWO jobs:
                                  #   policy-drift (every push/PR, x86, --target drift) and
                                  #   publish-base (never on a PR, linux/arm64 ONLY -- pins.env
                                  #   carries one GIT_SHA256 and it is the arm64 .deb hash)

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
│   └── overrides/                 # profile-selected overrides — the R12.9 entry point
│       ├── <profile>.yaml
│       ├── oauth-mount.bootstrap.yaml # :ro credential mount + AUTH_MODE. Publishes NO port
│       ├── codex-callback.yaml    #   127.0.0.1:1455 forward, kept a SEPARATE fragment: a
│       │                          #   fragment layers whole or not at all, so publishing here
│       │                          #   would open a host port on the one invocation that is NOT
│       │                          #   an interactive login (01.4 Deviation 4, R2.8)
│       ├── build-cache.yaml       #   per-agent /build-cache, default off (R2.10)
│       └── host-gitconfig.yaml    #   :ro scrubbed gitconfig, default off (R2.9)
├── images/
│   ├── Dockerfile                 # ONE multi-stage build. agent-base is DEFINED here and built
│   │                              #   only by CI (--target agent-base); the agent stages consume
│   │                              #   it FROM ghcr.io/...@sha256:$AGENT_BASE_DIGEST, so a LOCAL
│   │                              #   build pulls the attested base rather than rebuilding it
│   │                              #   (01.5 SF-6b, D21, R10.2). BuildKit skips the unreferenced
│   │                              #   local stage. Stages: agent-base + claude + codex + agy,
│   │                              #   selected by `target:` (01.2 Deviation 1). Four files became
│   │                              #   one because the three agent stages share the base layer and
│   │                              #   Compose selects the stage per service
│   ├── keyrings/debian-archive.gpg # committed trust anchor for the pinned snapshot repo; its
│   │                              #   full fingerprint is asserted with gpgv at build (01.5 SF-5)
│   ├── pack-plan.sh               # resolves a profile's pack set to a flat install plan; runs in
│   │                              #   the `pack-plan` stage, the only place yq touches this build
│   ├── pack-install.sh            # consumes that plan: pinned apt items + checksummed archives
│   ├── apt-pinned.sh              # gpgv/fingerprint assertion, snapshot-only sources, verified
│   │                              #   .deb download; shared by agent-base (git) and agent-packs
│   ├── remove-package-managers.sh # R7.19 conditions 3-4, run LAST in every agent stage, and it
│   │                              #   ASSERTS its own end state rather than trusting the rm
│   ├── entrypoint.sh              # idempotent home seed from /opt/agent-home-skel, the R4.5
│   │                              #   config.toml merge, the proxy-credential splice into
│   │                              #   HTTPS_PROXY/HTTP_PROXY (01.6 Dev 10), then the start-time
│   │                              #   bootstrap-auth pass. COPY'd and ENTRYPOINT-set in the
│   │                              #   `agent-packs` stage, NOT `agent-base`: the base is consumed
│   │                              #   FROM ghcr by digest, so BuildKit skips it and an edit here
│   │                              #   would reach nothing. Same trap as SKEL_MARKER (01.5 SF-6b)
│   ├── bootstrap-auth.sh          # per-agent AUTH_MODE dispatcher (01.4 SF-2), incl. the :ro
│   │                              #   copy-to-volume (R4.15). HERE, not scripts/ -- see the note
│   │                              #   below the tree and Feature 01.4 Deviation 1
│   ├── agy/agy-run.sh             # agy's JSON status-field gating (R3.6)
│   └── mediator/
│       ├── Dockerfile             # Squid 6.13 + dnsdist + unbound + yq, all pinned; context is
│       │                          #   the SOLUTION ROOT (it carries policy/resolved/ and
│       │                          #   mediator/config/), guarded by a deny-all .dockerignore
│       ├── entrypoint.sh          # stage-1 policy validation, config render, cascade warm-up,
│       │                          #   stage-2 reachability check, then supervise the daemons
│       └── audit-writer.sh        # Squid's line -> Interface Contract 4's JSON (bash, not awk:
│                                  #   mawk emits nothing from a FIFO whose writer is still open)
├── profiles/
│   ├── default.yaml               # project mount + state volumes only; every optional mount off
│   ├── oauth-mount.yaml           # carries the accepted_risk record the bootstrap checks for
│   │                              #   (01.4 Deviation 5) — the profile does not exist inside the
│   │                              #   container, so the record travels with the material
│   ├── test-fixtures.yaml         # harness fixture profile (01.3/01.5)
│   ├── test-selfcheck.yaml        # startup self-check profile
│   └── <use-case>.yaml            # (not yet built — 02.3) packs, mounts, AUTH_MODE, OS packages
├── packs/
│   ├── README.md                  # manifest schema; the no-runtime-egress decision; the checksum
│   │                              #   residual (01.5 Deviation 13) and what the removals cost
│   ├── language-runtimes/pack.yaml # BUILT (01.5 SF-1). Node, Python, Go; build-time only
│   ├── terraform/pack.yaml        # (not yet built — 02.3)
│   ├── kubernetes/pack.yaml       # (not yet built — 02.3)
│   └── aws-cli/pack.yaml          # (not yet built — 03.3)
├── policy/
│   ├── allowlist.base.yaml        # seeded per D17, cross-validated, never vendor-copied (R5.8)
│   ├── denylist.base.yaml         # metadata endpoint, RFC1918, link-local, loopback (R5.6)
│   ├── allowlist.test.yaml        # TEST-SCOPED base: the harness's fixture hosts. Kept out of the
│   ├── denylist.test.yaml         #   discovery-derived base so its provenance stays intact; the
│   │                              #   test denylist omits 172.16.0.0/12 and says why (Docker's
│   │                              #   bridges are RFC1918 and the fixtures live inside it)
│   └── resolved/                  # policy-compiler output — the SC-6 artifact, committed
│                                  #   default.yaml + test-fixtures.yaml + test-selfcheck.yaml
├── mediator/
│   ├── config/                    # TEMPLATES, rendered at start from the resolved policy (SC-6):
│   │                              #   proxy.conf.tmpl, resolver-policy.conf.tmpl (dnsdist),
│   │                              #   resolver-reorigin.conf.tmpl (unbound), errors/ERR_MEDIATOR_*
│   │                              #   (the operator-facing denial pages, one per control).
│   │                              #   ERR_MEDIATOR_IDENTITY is the mtls subject-mismatch page and
│   │                              #   is claude's alone: a proxy_auth refusal is Squid's own 407
│   │                              #   challenge and takes NO deny_info route, so no page was
│   │                              #   added beside it (01.6 Dev 7, measured across 12 cells)
│   └── identity/                  # CA and per-agent workload identity (R8.8). No private key
│       │                          #   committed; the CA key never leaves the operator host
│       ├── clients/               # claude-client.{crt,key} -- the ONLY cryptographic identity.
│       │                          #   Mounted :ro into claude alone as a Compose file: secret,
│       │                          #   which is a bind mount and therefore trips three harnesses'
│       │                          #   control-plane predicates -- see D22 (01.6 Dev 4, 5, 6)
│       └── credentials/           # <agent>.cred for codex and agy: `<username>:<password>`,
│                                  #   the whole userinfo string (01.6 Dev 11). The mediator side
│                                  #   is a htpasswd -- hashes only, never these files
│
│   # NOTE (01.5 SF-5, Deviation 11): THE AGENT BUILD CONTEXT IS NOW THE SOLUTION ROOT, not
│   # ./images. The agent images resolve their own package set from profiles/ and packs/, which
│   # sit outside images/, and a build stage can only read its own context; a .dockerignore
│   # selects WITHIN a context and cannot admit a path outside one. Both builds therefore share
│   # one context and one guard -- the solution-root .dockerignore -- and `images/.dockerignore`
│   # was DELETED rather than left inert, because Docker resolves .dockerignore at the context
│   # root and a file under images/ now governs nothing. The note below is kept for its reasoning
│   # and its premise is superseded: bootstrap-auth.sh still ships at images/bootstrap-auth.sh,
│   # now for the copy-to-volume reason alone rather than for the context reason as well.
│   #
│   # AND THE CONSEQUENCE THAT FOLLOWS, because the obvious reading of the paragraph above is
│   # now false: there are no longer TWO build contexts, there is ONE, shared by the agent and
│   # mediator builds. That single context legitimately contains images/mediator/, mediator/
│   # config/, policy/ and scripts/compile-policy.sh alongside packs/ and profiles/ -- the
│   # mediator build needs them and none is a secret. So Interface Contract 5's rule ("the agent
│   # images copy packs/ and profiles/ and NEVER policy/, mediator/ or any identity path") is no
│   # longer separable at the context level and MUST be asserted against the BUILT IMAGE. The
│   # division of labour: the CONTEXT assertion (the CA private key and references/ are absent --
│   # both stay denied because !images sits above the trailing-deny block) is now ONE assertion
│   # covering both builds; the IMAGE assertion is what discriminates agent from mediator.
│   # "The context no longer contains control-plane paths, so the agent images cannot have them"
│   # was true before this deviation and is false after it.
│   #
│   # NOTE (01.4 SF-2): `bootstrap-auth.sh` was listed here in an earlier revision of this tree.
│   # It ships at `images/bootstrap-auth.sh` instead. The build context for the agent images was
│   # ./images, so a file under scripts/ could not be COPY'd into the image, and the copy-to-volume
│   # it performs must run inside the container where both the :ro source and the state volume
│   # are mounted. 01.2 set the same precedent with `images/entrypoint.sh`. See the Feature 01.4
│   # plan, Deviation 1 — which also records that the per-agent image directories this tree once
│   # implied (`images/agent-base/`, `images/codex/`) do not exist: 01.2 collapsed them into one
│   # multi-stage `images/Dockerfile` with `target:` selection.
├── scripts/                       # bash, `set -euo pipefail`, invoked as `bash script.sh`
│   ├── compile-policy.sh          # profile + packs → policy/resolved/
│   ├── compile-policy-build.sh    # host wrapper: regenerates the artifacts THROUGH the mediator
│   │                              #   build (01.5 SF-4), which is why the drift gate cannot live
│   │                              #   in the emitting stage — it would fail on the only occasion
│   │                              #   the wrapper is ever run (01.5 Deviation 10)
│   ├── build.sh                   # per-profile image build (01.5 SF-6, SC-8). Drives the SAME
│   │                              #   Compose files as the entry point, tags the agent images
│   │                              #   :<profile>, records image IDs to .build-scratch/build/.
│   │                              #   NO local SBOM: measured -- the `docker` driver cannot carry
│   │                              #   an attestation, so R10.7's SBOM half stays with CI
│   ├── scrub-gitconfig.sh         # HOST-side pre-mount git-config scrub (01.4 SF-1, R2.9/T22).
│   │                              #   Writes compose/generated/gitconfig.d/; the operator's own
│   │                              #   ~/.gitconfig is never mounted into any container
│   ├── stage-oauth-mount.sh       # HOST-side oauth-mount staging (01.4 Deviation 5): validates
│   │                              #   the five accepted_risk fields, refuses a rw source and a
│   │                              #   Keychain-backed host install, strips OPENAI_API_KEY as a
│   │                              #   test-validity control, writes compose/generated/oauth-src/
│   ├── validate-boundary.sh       # (not yet built — M2) runs the adversarial matrix (R12.8)
│   ├── lint-policy.sh             # feature test command (01.1); policy/*.yaml well-formedness only
│   ├── issue-identity.sh          # OFFLINE CA + listener certificates (01.3 SF-3). Runs on the
│   │                              #   operator host; the CA private key never enters the mediator
│   ├── verify-agent-clients.sh    # 01.1 SF-2's client-capability probe
│   └── install-deps.sh            # host dependency check/install (docker, openssl, curl, jq, yq, sbx); macOS + Linux (01.1)
├── tests/
│   ├── acceptance/                # T1–T45. verify-pod-topology.sh (01.2), verify-egress-
│   │                              #   mediator.sh (01.3), verify-auth-state.sh (01.4, 56
│   │                              #   assertions across phases A–E)
│   │   ├── verify-pod-topology.sh       # 01.2's test command
│   │   ├── verify-egress-mediator.sh    # 01.3's test command: phases A–G. Carries T34 in both
│   │   │                                #   the cryptographic and the credential form, and
│   │   │                                #   retry_cold_peer -- which retries a 500 at most twice
│   │   │                                #   and NOTHING else, because a 403 or 407 is a result
│   │   │                                #   and swallowing one makes the assertion a tautology
│   │   ├── verify-pack-composition.sh   # 01.5's test command: phases A–G
│   │   └── verify-auth-state.sh         # 01.4's, phases A–E. EXCLUDED from the composite Test
│   │                                    #   Command by design (Phase D spends a real credential
│   │                                    #   refresh; AUTH_SKIP_PHASE_D=1 stops before it), which
│   │                                    #   is why two of its mount-set failures at 01.6 were
│   │                                    #   found only by hand -- see D22
│   │   # ALL FOUR answer "which mounts may this agent hold?" independently, in two overlapping
│   │   # flavours -- containment ("is this source control plane?": egress-mediator, pack-
│   │   # composition Phase G, pod-topology) and mount-set equality ("what should this agent
│   │   # mount, exactly?": pod-topology, pack-composition, auth-state). Each carries its own
│   │   # name-scoped exception for the agent's own identity material. D22 records the
│   │   # consolidation obligation; a fourth agent-mounted secret repeats the whole exercise.
│   └── fixtures/                  # destinations the harness OWNS: a controlled authoritative DNS
│                                  #   server (T4 asserts an absence, which needs a log to read),
│                                  #   and TLS endpoints. No third-party host is contacted
└── workspace/                     # the default profile's project mount, git-ignored except .gitkeep
                                   #   (binding the solution tree would put the control plane inside
                                   #   the agents' writable mount)
```

**Convention notes, observed from this repository rather than assumed:** shell scripts use
`set -euo pipefail` and are invoked as `bash script.sh` (the executable bit is never set); MCP
configuration is JSON of the shape `{"mcpServers": {...}}`; the repository had no hosted CI before this
solution — `cicd/` contains manually-invoked bash only, and there was no `.github/` directory
until 01.5 SF-6 created one. D21's first workflow now exists, so SC-8's "no manual steps" is
carried by the CI-published base image and its pinned digest, with `build.sh` retained for local
per-profile layering.

**Two things about that workflow depart from what Gate 2 assumed, and both are mechanism rather
than preference.** The GHCR namespace is `ottawacloudconsulting/agentic-ai` — the git remote's
owner — and not the `OCC-github` the plan's Dependencies section named, which is only this
machine's local directory name. And the publish job builds **`linux/arm64` only**: the
`agent-base` stage installs `git` through `images/apt-pinned.sh`, which hashes the `.deb` that
`apt-get download` fetches for the container's own dpkg architecture, and `compose/pins.env`
carries a single `GIT_SHA256` — the arm64 one, matching R11.1/A1's Docker Desktop on Apple
silicon. An amd64 runner fails at that checksum comparison. Publishing a second architecture
therefore needs a second verified pin, not a runner change, and D21's "the base image" is
consequently single-architecture for as long as A1 holds.

**D21 is now load-bearing rather than aspirational, and one consequence was found by testing.**
Since 01.5 SF-6b the agent stages consume the published base by digest, so BuildKit no longer
builds `agent-base` locally at all. Anything driven by a build argument declared in that stage
became unreachable from a local build: `verify-pod-topology.sh`'s volume-upgrade check passes
`--build-arg SKEL_MARKER=...`, and it silently reached nothing until the hook was moved down into
`agent-packs`. The general rule the tree should hold to is that **a build argument only has effect
in a stage that is still built locally**, and the narrower one is that a test-only affordance has
no business in the CI-published supply-chain artifact in the first place. Verified after the move:
the built agent images' first 17 layers are byte-for-byte the published base's, with 7 layers
added on top (re-measured after the move -- the relocated `RUN` adds one).

A third consequence, found the same way and worth the same generalisation: since BuildKit parses
every stage's `FROM` before it prunes unreachable ones, and only *resolution* is
reachability-gated, `--target agent-base` also fails when `AGENT_BASE_DIGEST` is unset -- even
though that stage never reads it. The CI publish job therefore passes the digest to a build that
does not consume it. **Pruning happens after parsing**, so a defaultless ARG in any `FROM`
constrains every target in the file, not just the reachable ones.

## Deployment & Operations

### Entry point

`docker compose up --build --force-recreate` with a profile-selected override file (R12.9). No
wrapper CLI is built — the operator sees exactly what runs.

**Both flags are load-bearing, and `--force-recreate` was added unconditionally at the 01.5 SF-7b
build (Deviation 20).** SF-4 fixed the stale *image*; this fixes the stale *container*. Measured:
after editing `profiles/default.yaml` and refreshing the artifact, `up --build` exited 0 and the
mediator image ID changed, but Compose reported the container `Running` rather than recreated —
and the mediator went on serving `compiled_from.packs: 1` against a committed artifact of `0`.
SC-6, R12.1 and D10 are halves of one requirement, so the amendment is unconditional rather than
confined to the refresh procedure. The cost is stated in `README.md`: in-flight proxy and DNS
connections break, startup checks re-run, `/run` and `/tmp` are dropped and container IDs rotate;
named volumes and the audit volume are preserved — checked, not assumed. Onboarding documentation covers the compose invocation directly
plus first-run authentication for all three agents and AWS SSO (R12.6).

### Build and bring-up sequence

This is the ratified sequence. Steps 0–2 are prerequisites to building the pod, not optional
preliminaries.

0. **Assess Docker Sandboxes as a service provider** (R14.1) — what its proxy observes, retention
   period for intercepted traffic, deletion and breach-notification terms. **Attempted and
   incomplete (01.1 SF-1): Docker's own documentation neither confirms nor denies that the `sbx`
   proxy decrypts traffic, and publishes no retention, deletion or breach-notification terms.**
   Step 1 therefore runs constrained unconditionally, on whichever reading is correct.
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
   (R8.8, D6) and per-agent network isolation (D2). Native agent sandboxes **disabled by default**
   inside the container (D14 as amended at the 01.2 build: bubblewrap cannot create or use a
   nested namespace under D15's hardened posture, and any seccomp exception broad enough to
   permit nesting is itself an R1.4 violation).
4. **Test the boundary adversarially before any real work** (R12.8, D16). Everything before this
   validates that the allowlist is *sufficient*; nothing yet validates that the boundary is
   *effective*. Run T1–T45 and at minimum the six R12.8 scenarios. Record which injection sources
   from the threat model are exercised and which are not — on the current design the stdio MCP
   vector is not, because it never crosses the enforcement point.
5. Re-evaluate Option 3 only if the threat model changes.

> **M1's output must not be used for real work until M2 completes.** R12.8 places adversarial
> validation in M2. M1 produces a sandbox that works, not a sandbox that is proven.

### Observability

Four artifacts, produced by default, exported by default (R9.9, D11): the egress audit log, the
agent action log, the resolved egress policy, and the image digest plus SBOM. Recording is
mandatory and not profile-disableable; only export is.

**That is the target state. As of Feature 01.5 two of the four are complete** — stated here so an
absent artifact is not mistaken for a produced one.

| Artifact | Status as built |
|---|---|
| Egress audit log | **Produced** (01.3). One JSON object per line on a volume mounted into the mediator alone. Residual: raw-socket egress attempts are invisible to it — recorded, not fixed |
| Agent action log | **Not built.** Feature 02.1 |
| Resolved egress policy | **Produced** (01.5). Four artifacts under `policy/resolved/`, emitted by a build stage behind the fail-on-drift gate |
| Image digest + SBOM | **Partial.** Digest and SPDX SBOM exist for the CI-published base image only; a local agent build records an image ID and no SBOM, because the buildx `docker` driver rejects attestation. Provenance verification (T45) is Feature 02.4 |

The per-export disable mechanism D11 describes is itself unbuilt — it is T36, in Milestone 02.

Denials are surfaced to the operator with a clear message naming the blocked destination (R9.3,
R12.2), so a legitimate policy gap is distinguishable from an attack. Detection is **pull-based
by decision** — push alerting on denial remains MAY (R9.6), with the review trigger being a
blocked attempt going unnoticed long enough to matter.

**The denial surface has two halves, and only one of them is guaranteed** (amended at the 01.3
build, Deviations 2 and 8). The **authoritative** half is the structured audit record and the
operator-facing message rendered from it — it exists for every refusal, on every agent. The
**client-visible** half is best effort: a verdict reached *before* the CONNECT is accepted comes
back as an HTTP 403 whose body names the destination, the refusing control and the policy file to
edit, but a verdict reached *after* the ClientHello (an SNI that disagrees with the CONNECT host)
terminates the connection with no body, because writing one would mean minting a certificate for
the destination — the MITM capability D4 forbids. `codex` gets no body for **any** verdict: its
single listener peeks, and a peeking listener must accept the CONNECT before it can decide.
R9.3's "distinguishable in-band" therefore holds for `claude` and `agy` on pre-CONNECT verdicts
and **not** for `codex`, which is recorded as a residual rather than claimed.

**01.6 added a third refusal shape, and it is deliberately not folded into the other two.** An
identity refusal is not a policy refusal, and the trail must not let the two be confused:

| Refusal | Client sees | Audit line |
|---|---|---|
| Policy (pre-CONNECT) | 403 with a body naming destination, control and the policy file to edit | `verdict=deny`, the refusing control, a reason token |
| Identity — `mtls` subject mismatch | 403 with `ERR_MEDIATOR_IDENTITY` | `verdict=deny`, `control=identity`, `reason=subject_mismatch` |
| Identity — `proxy_auth` miss | **407 Proxy Authentication Required**, no body | `control` and `reason` both null |
| Identity — cert-less handshake | Connection refused at TLS, nothing in-band | **No verdict line.** One anonymous `{"event":"proxy_internal","detail":"error:transaction-end-before-headers"}` |

The 407 takes no `deny_info` route at all — measured across twelve cells at the 01.6 build
(`docs/records/mediator-selection.md` P9): a missed `proxy_auth` ACL makes Squid answer its own
challenge before any rule that could name an error page is reached, so a 403 route there would be
configuration that never executes. 403 means "policy refused this destination", 407 means "this
listener wants a credential", and an operator reading the trail needs to tell them apart. The
cert-less row is the one operator trap: **the agent gets nothing and the trail carries no denial**,
so the diagnosis is `$AUDIT_DIR/squid-cache.log`, not the audit sink. The earlier claim that a
cert-less refusal produces "no audit line at all" was false against the pinned Squid — the property
that holds is that the line it does produce identifies nothing (01.6 Deviation 2).

### Startup self-checks

The mediator refuses to serve on a policy it has not validated, and by default proves the
enforcement path before it reports itself up (R9.5, T17):

- **Stage 1 — unconditional and fatal.** The resolved policy is schema-validated before any
  listener binds, by the same script that compiled it. A corrupt policy aborts the start naming
  the file and the failing field. There is no skip.
- **Cascade warm-up, and the agents it can no longer cover.** Squid marks its `cache_peer` parents
  DEAD at start — on this topology the parents are its own loopback listeners — and revives them
  only when a request needs one, which costs that request a 500. The mediator therefore spends the
  sacrificial request itself at start (01.3 Deviation 10). **Since 01.6 it can only do so for an
  agent whose `client_auth` is `none` — which today is neither of the two fronted agents:
  `claude` is excluded as `mtls` (Deviation 1) and `agy` as `proxy_auth` (Deviation 9), so the
  warm-up now runs for no agent at all.**
  The mechanism is not a choice. `warm_cascade` reaches its target through that agent's own front
  (`cache_peer_access <agent>peer allow p_<agent>_frontreal` admits nothing else), and it connects
  from inside the mediator, which holds no client key and only the htpasswd's hashes — so under
  required-mode `clientca=` the handshake is refused, and against `proxy_auth` the mediator cannot
  construct a credential to answer its own 407. Left unfixed it would spend the full retry budget
  (20 × 3.5s) failing at every start. The gate is on the **field**, not the agent name, so any agent
  later flipped to an authenticating mode inherits the exclusion. `codex` is unaffected: a
  single-listener agent has no cascade to warm. Three alternatives were rejected on mechanism and
  the reasoning is recorded at the exclusion in the code — a loopback warm port admitted to the peer
  would put `idsrc=listener+mtls` or `listener+proxy_auth` on a line with nothing authenticated
  anywhere on the path, which is the false attribution the whole feature exists to prevent; mounting
  the agent's key or plaintext into the mediator would put one agent's identity in two containers;
  and warming through the inner listener directly does not revive a peer, which is the finding the
  warm-up was built on. The residual is stated in Accepted risks and in `README.md`'s R12.2 section.
- **Stage 2 — reachability, through the rendered proxy.** One allowed and one denied destination
  are driven through a loopback shadow listener that mirrors the checked agent's own topology, so
  a rendering bug in the proxy configuration fails the check rather than passing it. The probes
  carry their own identity (`agent: "selfcheck"`) and are never attributed to the agent whose
  policy they borrow. Skippable **only** through an explicit `startup_check.offline: true`, which
  is recorded on the audit trail at every start.

**Agent bootstrap is deliberately not fatal at start.** `bootstrap-auth.sh --at-start` warns on
stderr and exits 0 when a credential is absent, reserving exit 3 for explicit invocation; an unset
or unsupported `AUTH_MODE` still exits 2 in both passes, and `oauth-mount` on an emptied volume
still exits 3 in both. The flat reading would make `docker compose up` fail on a fresh volume
under the default profile — all three agents exit non-zero — taking the pre-existing 01.2 topology
harness down with it, and this feature's own composite test command requires that harness.
Operator decision at the 01.4 build (Deviation 2): warn, do not block.

### Reproducibility

The base image is built and published to GitHub Packages by GitHub Actions and consumed by
**digest, never by tag** (D21, R10.2). During the project the workflow builds from the working
branch and those images are for testing only; on project completion the workflow moves to `main`,
which is the point at which a published digest becomes usable for real work. CI is also where the
SBOM is emitted and where provenance attestation becomes practical (R10.7).

The environment is defined entirely in version-controlled files with no manual setup steps
(R10.1). Base image, agent versions and pack contents are pinned to versions or digests (R10.2);
auto-updaters are disabled so a pinned build stays pinned (R10.3).

Three mechanisms carry that pinning in practice, all settled at the 01.5 build. The pack set
invalidates the image cache by **content** — the `pack-plan` stage's `COPY packs/ profiles/` is
keyed on tree content — rather than through a `PACK_SET_HASH` build argument, which had no
producer: Compose interpolates build arguments only from the environment and `--env-file`, and a
hand-maintained hash that is never recomputed is exactly the stale-cache failure such an argument
exists to prevent (Deviation 12). `MEDIATOR_PROFILE` tracks `AGENT_PROFILE` in `compose.yaml`, so
one variable selects both the agents' pack set and the mediator's enforced policy; before that,
`AGENT_PROFILE=oauth-mount docker compose up --build` built agent images for one profile's pack
set while enforcing another's policy, with no surface reporting the mismatch (Deviation 16). And
**a build argument only has effect in a stage that is still built locally**: once the agent stages
consume the published base `FROM ghcr.io/...@sha256:<digest>`, BuildKit skips the unreferenced
local `agent-base` stage, so a `--build-arg` aimed at it reaches nothing (Deviation 17). **The rule
is broader than build arguments, and 01.6 SF-3 found the second half of it: a file edit in that
stage reaches nothing either.** Moving the proxy-credential splice into `images/entrypoint.sh`
changed a file the local build never rebuilt — all three agents rebuilt, and
`verify-pod-topology.sh` reported the splice had not happened, because the image still carried the
published copy. The fix was the precedent `SKEL_MARKER` had already set: move the `COPY` and the
`ENTRYPOINT` down into `agent-packs` (Deviation 10, D21). SF-3 was the **first** change to a
base-image file since the digest pin landed, so no precedent existed to follow until one was made. Stated as a rule for whatever edits that stage next: **anything in `agent-base` is
CI-built and digest-pinned, so a local edit to it is inert until CI republishes.** The image builds without
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

Per-agent `AUTH_MODE` (D8) with per-agent state volumes (D7). **Amended at the 01.3, 01.4 and 01.6
builds: identity is not uniform, because mutual TLS is not available to every agent — but as of
01.6 every agent presents something, which was not true through 01.5.** The three forms, and why
the split falls where it does:

| Agent | Form | Mechanism | Audit `identity_source` |
|---|---|---|---|
| `claude` | **Cryptographic** | Client certificate (`CLAUDE_CODE_CLIENT_CERT`/`_KEY`, confirmed 01.1 SF-2) on a required-mode `clientca=` front listener, issued by the offline CA of 01.3 SF-3 | `listener+mtls` |
| `codex` | **Credential** | Per-agent proxy credential. It rejects an `https://`-scheme proxy URL at parse time, so no TLS listener exists to present a certificate on — but it constructs `Proxy-Authorization` from proxy-URL userinfo preemptively | `listener+proxy_auth` |
| `agy` | **Credential** | Same, over a TLS hop. It reaches the TLS `CertificateRequest` stage with no certificate to offer | `listener+proxy_auth` |
| all three | **Structural** | Each sits alone on its own `internal: true` segment (D2), so the arriving network names the agent even where nothing is presented | `listener` |

**The credential form was built on a measurement that reversed a plan-time assumption.** Interface
Contract 4 had been drafted to say that for two of three agents "the method names an artifact that
does not exist", making their T34 case structural only. SF-1 measured otherwise for both, SF-3
built on it, and the harness has carried a credential-form T34 assertion since. Applying that
contract verbatim would have put a statement in the acceptance register that the shipped code, the
shipped harness and `docs/records/mediator-selection.md` P9 all contradict, so **T34 is amended in
a three-form shape rather than the two-form one drafted** (01.6 Deviation 12) — see the T34 row in
Requirements Traceability. The two clauses about what each client *cannot* do remain true and are
kept; they are why the certificate form is `claude`'s alone.

**A credential is a real identity and still not a sufficient one for brokering.** D6's precondition
is unchanged and now discriminates: the Milestone 03 gate is `listener+mtls` alone. The concrete
reason for `codex` is the plaintext hop recorded at SF-3 — its credential crosses `codex-net` in
the clear. `prd.md` records the same consequence at the Gate 3 milestone revision.

`REQUIREMENTS.md` **R8.8 is unamended** and still reads "each agent instance is issued a distinct
workload identity". The disagreement that Codex finding F2 raised at the Feature 01.3 Gate 4 review
— closed then as "recorded, not fixed here", written up in
`docs/records/r8-8-identity-mechanism-gap-escalation.md` — is **narrowed but not formally closed by
01.6**: each agent is now issued and presents a distinct identity, which the strict reading asks
for, and the residual is that two of the three are not cryptographically bound. The milestone's
Definition of Done wording ("which agents carry a cryptographic identity and which carry
network-derived identity") is a two-form phrasing of a three-form outcome; the record it names,
`docs/records/workload-identity.md`, is accurate, and restating the Definition of Done is the
milestone's to do. AWS uses brokered short-lived credentials (Model B, D13); Model C is
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
| Long-lived refresh tokens persist on state volumes; a one-year Claude Code token is available | R4.16 | Per-agent volumes (R4.3), secret handling (R4.7), tested revocation (R8.5, R13.1), backup exclusion (R8.7). **Measured at 01.4 SF-5: rotation is not a revocation mechanism** — a superseded refresh token replayed successfully against the same account, so only explicit provider revocation ends a captured one (OpenAI measured; Anthropic not replayed). Review trigger: brokered agent credentials becoming available from any provider |
| Exfiltration through legitimately allowlisted destinations cannot be prevented | Non-Goal | Structural. An agent allowed to reach GitHub can push to GitHub. Narrowed allowlist plus audit bounds and detects it; nothing eliminates it |
| Prompt injection itself is not mitigated | Non-Goal (R15.1) | No component inspects agent input. The architecture bounds consequences rather than preventing the injection. R15.2 keeps the seam for a later tool-call mediation layer |
| **`codex` cannot distinguish a policy gap from an attack in-band.** Its listener peeks, so every refusal reaches it as a terminated connection with no body | R9.3 | The audit record — which Interface Contract 6 already makes the authoritative half — names the destination, the control and the reason. `claude` and `agy` still get the 403 body on pre-CONNECT verdicts. Closing it would mean giving `codex` a non-bumping front listener, which is the cascade its plaintext hop exists to avoid, and would still produce no body once the peek stage runs |
| **Control 3 ships two of its three ceilings.** Concurrency and byte rate are enforced; connection *rate* is not | D5, R5.x | Squid 6.13 has no per-client connection-rate directive at all. The alternatives were an external helper process inside the enforcement point or a policy key that silently enforces nothing; the field was dropped and the compiler now refuses an artifact that declares it, so the gap is visible rather than assumed away |
| **The declared-checksum guarantee covers three packages, not the installed set.** `apt-get install --no-install-recommends python3 python3-venv git` resolves to **40** packages; the manifest declares 3 with `sha256` values | R7.3, D10 | The transitive closure installs under a pinned snapshot repository whose `InRelease` signature and full key fingerprint are asserted at build (`VALIDSIG B8B80B5B623EAB6AD8775C45B7C5D7D6350947F8`, the fingerprint `profiles/default.yaml` pins), so closure integrity rests on the signature rather than on per-package hashes. `jq` moved into this category at 01.5 SF-5. Recorded as a residual against R7.3 in `packs/README.md` (01.5 Deviation 13) |
| **An authenticating agent's first request after a mediator start may be answered 500.** Applies to `claude` (`mtls`) and `agy` (`proxy_auth`); `codex` has no cascade to warm | D6, R9.3 | Mechanism, not oversight: the warm-up must traverse that agent's own front listener, which now demands material the mediator does not hold — no client key, and only the htpasswd's hashes. Every alternative costs more than it buys, and two of them (a loopback warm port, or mounting the agent's key into the mediator) would defeat the feature they serve. Visible on the trail as a front line with `http_status: 500` and `verdict: allow` — **not** a policy refusal — and clients retry. `verify-egress-mediator.sh` carries `retry_cold_peer`, which retries a 500 at most twice and nothing else. Observed at the 01.6 build that all three peers revived about a second after start when `agy`'s warm-up ran, so the 500 did not materialise in that run: the residual is real but not certain, and is stated as "may". Documented in `README.md` R12.2; Milestone 02.2's adversarial acceptance inherits it |
| **`codex` presents its workload identity over a plaintext hop.** Its proxy credential crosses `codex-net` unencrypted | D4, D6, R8.8 | Structural in the client: `codex` rejects an `https://`-scheme proxy URL at parse time, so the TLS-fronted cascade the other two use is unavailable to it and no certificate can be presented either. `codex-net` is `internal: true` and carries exactly one agent plus the mediator, so the exposure is to a compromise of one of those two containers rather than to the pod at large. This is the concrete reason D6's Milestone 03 brokering gate is `listener+mtls` alone rather than "any verified identity" — the credential is a real identity that is deliberately not trusted to broker |
| Recovery to known-good is the weakest of the three options | D1, R13.3 | Accepted in exchange for L7 FQDN correctness, extensibility and a self-owned audit trail. Mitigated by the discard-and-rebootstrap path (D16) |

### What the 01.5 adversarial pass changed

The policy compiler was put through an external adversarial review (Codex, 2026-09-08). Seven
findings, all seven reproduced before being fixed. Two belong here because they change what the
compiler is trusted for.

- **A regression the feature itself introduced.** The accumulator encodes each entry as
  `fqdn|port|upgrade|source`. Base-supplied `port` and `upgrade` values were not shape-checked, so
  a base allowlist entry whose `port` was a block scalar emitted a second, well-formed, **allowed
  destination the base allowlist never contained** — and compile exited 0 with the artifact
  validating. Recorded as a rule: introducing an internal encoding retroactively makes every value
  that flows into it security-relevant. A second finding ran the same direction —
  `egress_exclusions` written as a map made every exclusion lapse, including R10.3's auto-updater
  exclusion. Verification for this deviation: 12 new probes on top of the original 41 — 53 in
  total, 0 failures — with emitter output byte-identical before and after.
- **Provenance could select its own code path.** The compile stage copies a committed artifact
  through unchanged when the bases it names are absent, which is how harness fixtures survive a
  `.dockerignore` that deliberately excludes them. In the first version the artifact's own
  `compiled_from` line chose that branch, so one spoofed provenance line sent the shipped profile
  down the copy path and the image enforced the tampered policy — reproduced end to end. The
  predicate is now a code constant. The residual is stated rather than closed: drift is trivially
  satisfied for a carried artifact, so `--check` must be run on both fixture artifacts explicitly
  (01.5 Deviations 8 and 9).

All three resolved artifacts remain `--check` current after the pass.

### Controls this architecture does not provide

Stated so an absent control is not mistaken for a satisfied one. On every row, all three evaluated
options score identically: **absent**.

| Control | Why absent |
|---|---|
| Input inspection / prompt-injection filtering | Non-goal — three third-party agents' input pipelines are not ours to instrument |
| Deterministic mediation of agent *actions* rather than packets | No option intercepts a tool call. Writing to a bind mount, `git push`, `terraform apply` are unmediated everywhere |
| stdio MCP tool-invocation visibility | The transport never crosses a network. R7.15 requires the inventory to *state* which enforcement point covers each server — or that none does |
| Agent action log that is tamper-resistant **at source** | R9.7 is carried by shipping the agent's own transcript (D20), and the agent authors it, so the record is complete-as-written rather than tamper-proof. Real-time shipping buys tamper-*evidence*, not tamper-*resistance*. Unchanged by 01.6 — identity binds a *connection* to an agent, not a *line of a transcript* to one |
| Attribution of an *action*, as distinct from a connection | **Narrowed at 01.6, not closed.** Every egress verdict line now names the agent and the mechanism that identified it (D6, D12), so the destination log is an agent log. No component sees a tool call, so the action side still rests on the agent's own transcript. Attribution is also uneven in strength: cryptographic for `claude`, credential for `codex` and `agy` |
| Content-level DLP on the model API channel | Follows from D4's splice-only decision |
| Human approval on a novel destination | Unattended operation is assumed (A2). Option 2 is the only evaluated option that *could* host this later |

**Honest summary:** this architecture bounds what a compromised agent can reach, records where it
tried to go, and — since 01.6 built R8.8's mechanism — names which agent tried and by which
identity form. It does not detect the compromise, constrain what the agent does inside the
boundary, or attribute an *action* rather than a connection. R8.8 itself remains unamended in the
register; see Authentication and access control for what that leaves open.

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
| **T24** `AUTH_MODE` matrix | For each agent, run each mode it supports, headless. Seven supported cells — see the Feature 01.4 plan, Interface Contract 1 | Each authenticates with **no browser inside the container** (an interactive terminal is permitted; amended 2026-09-07, Feature 01.4 SF-2 — see `REQUIREMENTS.md`), and the default is the safest mode that agent supports | R4.12 | Entrypoint |
| **T25** Credential mount shape | Under `oauth-mount`: inspect the mount, then force an OAuth refresh | Mount is `:ro`, is a directory not a file, and the refreshed credential lands on the state volume with the host file unchanged | R4.13, R4.14, R4.15 | `bootstrap-auth.sh` |
| **T26** Long-lived token inventory and revocation | Enumerate persisted refresh tokens; execute the documented revocation for each type and time it | Every persisted token is inventoried with its compensating controls named; revocation succeeds within the stated maximum time | R4.16, R13.1 | State volumes, runbook |
| **T27** `oauth-mount` risk recording | Enable `oauth-mount` in a profile that does not record the accepted-risk decision | The build or startup refuses until the decision is recorded with file, mount mode, revocation path and blast radius | R4.17 | Profile, policy compiler |
| **T28** TLS splice verification | Inspect the destination certificate chain from inside each agent container; attempt to read plaintext at the mediator; confirm no mediator CA appears in any destination chain | No mediator CA appears in any **destination** TLS chain; the mediator holds no plaintext; Antigravity traffic is never intercepted. **Recorded exception:** the single proxy-hop trust anchor -- `claude` and `agy` trust the mediator CA for the agent->mediator hop only (`NODE_EXTRA_CA_CERTS` / `SSL_CERT_FILE`); `codex` trusts no mediator CA at all | R5.15 (and R5.13) | Mediator |
| **T29** MCP inventory and drift | Add an uninventoried MCP server; then change an inventoried server's capabilities | The uninventoried server is refused; the capability change is reported as drift, not silently accepted | R7.14 | Profile |
| **T30** MCP transport declaration | Inspect the inventory for every configured server | Each records its transport and names the enforcement point covering it — or explicitly states that none does | R7.15 | Profile |
| **T31** MCP install channel | Attempt `npx <server>` for a server not in the pinned registry | Refused. No wholesale package-registry egress entry permits arbitrary server installation | R7.16 | Profile, policy |
| **T32** Capability-declaration integrity | From inside each agent, attempt to write that agent's MCP capability declaration file | Blocked for Claude Code via `srt`. For agents where it is not blocked, the test records the gap rather than passing | R7.17 | State volume, `srt` |
| **T33** Build-time-only packages | Inspect installed package versions; then attempt a package install as the agent user at runtime | Versions match the profile pins and the declared repository; the runtime install fails for want of both privilege and write access | R7.18, R7.19 | Image build |
| **T34** Per-agent workload identity | **Amended at the 01.6 build to a three-form method** (Deviation 12), because the two-form text drafted at plan time asserted that two agents could present nothing, which SF-1 measured false. *Cryptographic* (`claude`): present a same-CA certificate carrying another agent's subject on this agent's listener. *Credential* (`codex`, `agy`): present another agent's proxy credential on this agent's listener. *Structural* (all three): enumerate network membership and show no route exists over which either could be presented | Cross-binding is refused in every form and the refusal shapes are asserted literally, not interchangeably: the certificate form gives 403 with `control=identity`, `reason=subject_mismatch`; the credential form gives **407** with `control` and `reason` null (01.6 Deviation 7). Every verdict line carries `identity_source`, and its value distinguishes the form that identified the caller | R8.8 | Mediator identity |
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
| **Whether any agent can present a client certificate to a TLS proxy listener** | **Resolved (01.1 SF-2, 2026-09-04) — not uniform.** `claude`: yes (`CLAUDE_CODE_CLIENT_CERT`/`_KEY`, confirmed). `codex`: no — structural; rejects an `https://`-scheme proxy URL at parse time, before any TLS attempt. `agy`: no — reaches the TLS `CertificateRequest` stage but has no cert to offer. See `docs/records/agent-verification.md` | **Closed at 01.6 (2026-09-09).** The alternative mechanism this row asked for is the per-agent proxy credential: SF-1 measured that `codex` and `agy` both construct `Proxy-Authorization` from proxy-URL userinfo preemptively — a positive result for both, against a plan that had assumed neither. The certificate form stays `claude`'s alone for exactly the two structural reasons this row records. See D6 and `docs/records/workload-identity.md` | Recorded, 01.6 SF-1/SF-3 |
| **T28 vs. a TLS proxy hop** | **Resolved by amendment (01.3 SF-3, 2026-09-06).** T28's original pass text ("no mediator CA is presented to any agent") and criterion 6's TLS proxy hops for `claude` and `agy` are mutually exclusive. `REQUIREMENTS.md` T28 now reads "no mediator CA in any **destination** TLS chain", with the single proxy-hop anchor as a recorded exception. R5.13 and R8.8 untouched | Was: SF-6/SF-8's T28 assertion had no satisfiable form. Now blocks nothing | Recorded, 01.3 SF-3 |
| **Where the CA private key lives** | **Narrowed (01.3 SF-3, 2026-09-06).** This document's "CA private key injected at runtime from a secret manager" is superseded: the key is created and used only on the operator host by `scripts/issue-identity.sh` and never enters the mediator. Moves in the safer direction — a mediator compromise yields no ability to mint agent identities. See `mediator/identity/README.md` | **Discharged as written (01.6).** 01.6 inherited this lifecycle and this CA and created no second one: `scripts/issue-identity.sh` issues `claude`'s client pair and writes the `codex`/`agy` credential files, the mediator receives the CA *certificate* to verify against and the htpasswd's hashes, and the CA private key still never enters a container | Recorded, 01.3 SF-3; discharged 01.6 |
| **Binding port 53 without capabilities** | **Resolved (01.3 SF-4, 2026-09-05) — the namespaced sysctl works.** `net.ipv4.ip_unprivileged_port_start=0` lets the mediator bind :53 with `cap_drop: ALL` intact; `cap_add: NET_BIND_SERVICE` was the recorded fallback and was not needed. Verified on Docker Desktop, not assumed from documentation. See `docs/records/mediator-runtime-verification.md` | Was D3's mechanism on a hardened container. Blocks nothing | Recorded, 01.3 SF-4 |
| **Whether Compose `dns:` actually redirects Docker's embedded resolver on an `internal: true` bridge** | **Resolved (01.3 SF-4, 2026-09-05) — yes, confirmed by capture on the mediator**, not by reading Compose documentation. That redirect is the whole of D3's mechanism | Was D3 itself. Blocks nothing | Recorded, 01.3 SF-4 |
| **`unbound` answers RFC 6761 special-use TLDs itself** | **New finding (01.3 SF-8, 2026-09-07).** The re-originating stage carries built-in local zones for `test.`, `invalid.`, `localhost.` and `example.`: it answers such names locally and never forwards them, whatever `forward-zone` says. Measured against an isolated unbound — a `.lab` name resolved, a `.test` name was answered locally with no query leaving. See the addendum in `docs/records/resolver-verification.md` | **An allowlist entry under a special-use TLD will compile, will be audited as `allow`, and will still not resolve.** Every surface says "allowed"; the only signal is the absent answer. Worth a compile-time warning where the allowlist is validated | 01.5 (policy compiler) |
| **Squid marks its cascade peers DEAD at start** | **Resolved by design (01.3 SF-8, 2026-09-07).** The parents are the process's own loopback listeners, and the probe runs before they accept; Squid revives a dead parent only when a request needs one, and that request is answered 500. Unchanged by `dead_peer_timeout 1s`, `standby=1` or `connect-fail-limit=100`. The entrypoint now spends the sacrificial request at start | Was: an agent's first request after every pod start failed. Now costs one `connect_accepted` event per fronted agent on the audit trail, under that agent's listener | Recorded, 01.3 SF-8 |
| **ICC driver_opts key name** | UNVERIFIED | Nothing — D2 uses per-agent networks precisely to avoid depending on it | — |
| **Default MCP transport per agent and per server** | **Resolved (01.1 SF-2, 2026-09-04) — no forced default; per-server, per config-entry key.** stdio egress has no application-layer enforcement point; covered only by 01.3's pod network-namespace-level enforcement. See `docs/records/agent-verification.md` | Was: determines whether any MCP traffic crosses the enforcement point at all — answered: HTTP/SSE MCP traffic follows the agent's own proxy behaviour above; stdio MCP traffic does not cross any app-layer point | Recorded, 01.1 SF-2 |
| **`agy` version-pinning capability** | **Resolved (01.1 SF-2, 2026-09-04) — none.** Installer always fetches the live manifest; no version/channel flag. Confirmed empirically (a build minutes apart from a host install pulled a newer version). See `docs/records/agent-verification.md` | 01.2's Dockerfile for `agy` cannot pin the way `codex`/`claude` can — must vendor a specific binary at build time or re-verify after every rebuild (R10.6) | 01.2 design decision |
| **D17 — egress allowlist seed and denylist** | **Recorded, provisional (01.1 SF-3, 2026-09-04).** `policy/allowlist.base.yaml` and `policy/denylist.base.yaml` committed; seeded from a real `sbx` discovery capture, cross-validated for `agy` fully and `codex`'s primary host, single-source for three secondary hosts and for `claude`'s only entry. See `docs/records/egress-discovery.md` | 01.2/01.3 consume these files. Not yet resolved: `claude`'s entry lacks a second source (see next row); UDP/ICMP blind spot applies to all three | Recorded, 01.1 SF-3 |
| **Whether `agy` can run under `sbx` at all** | **Resolved (01.1 SF-3, 2026-09-04) — yes.** No first-class `sbx` template exists for `agy` (only `gemini`, a different tool), but `agy` installs and executes successfully inside a generic `sbx` `shell` sandbox — not structurally barred, only lacking a template. See `docs/records/egress-discovery.md` | Was the plan's worst-case edge case (verbose-log-only fallback for `agy`); did not materialize — `agy`'s allowlist entries are fully cross-validated via a real `sbx` capture, same as `codex` | Recorded, 01.1 SF-3 |
| **`sbx` first-party kits can bypass the operator's own network policy** | **New finding (01.1 SF-3, 2026-09-04).** `sbx`'s `claude-code-docker` template bakes in a non-removable allow rule for 6 Anthropic-family hosts regardless of the global `deny-all` policy; the generic `shell` template does the same for `openrouter.ai` (a non-approved 4th provider). `codex-docker` carries no such rule. See `docs/records/egress-discovery.md` | Limits `sbx` as a *discovery* tool: it can confirm a host is used, but cannot prove a kit-covered host is unneeded, since it is never actually blocked-and-observed. Does not affect 01.3's own mediator (a separate, custom-built component) | 01.3 design awareness |
| **`sbx` first-party templates bundle their own agent version, independent of operator pins** | **New finding (01.1 SF-3, 2026-09-04).** `claude-code-docker` and `codex-docker` shipped `2.1.246`/`0.149.1` against SF-2's pins of `2.1.260`/`0.152.1`. No template flag selects a version; re-pinning in place worked (`claude install <version>`; `npm install -g @openai/codex@<version>`) but is a manual step per capture. See `docs/records/egress-discovery.md`, "Correction" | If `sbx` is ever considered as a *runtime* substrate (not just a discovery tool), R10.6's version-pin requirement needs an explicit re-pinning step per template refresh — the template will otherwise drift silently | 01.2/01.3 design awareness, if `sbx` is ever proposed as more than a discovery tool |
| **Per-session refresh-token revocation, per provider** | **Resolved (01.4 SF-5, 2026-09-07) — negatively, which is the answer that matters.** A superseded refresh token was replayed against the same account minutes after the legitimate client had refreshed past it, and it **worked**: parent `51ffa144` refreshed to `f0952196` on one run and to `1ffe309a` on the next. A refresh in one client does **not** invalidate another client's copy. Measured for **OpenAI**; **Anthropic was not replayed**, by operator decision. Rotation is therefore not a revocation mechanism — a refresh token captured from a state volume stays valid until the provider is told to revoke it | A second config directory on the same account is **not** meaningfully separable, which is exactly what keeps R4.17 an accepted risk rather than a mitigation — this row anticipated it, and the measurement confirms it. Outstanding: the one-year `CLAUDE_CODE_OAUTH_TOKEN` minted for the R4.16 cell is still to be revoked | Recorded, 01.4 SF-5 |
| **Refresh-token rotation semantics, per provider** | **Resolved (01.4 SF-3, 2026-09-07) — measured, not assumed.** Both providers **roll** the refresh token on refresh: `claude`'s `refreshToken` and `codex`'s `tokens.refresh_token` both changed, each cross-validated against a mediator audit line for the refresh endpoint. Two asymmetries follow. `claude`'s `refreshTokenExpiresAt` is **not** extended by a refresh — the same absolute instant before and after — so the family expires roughly 28 days after the original login however often it refreshes. `codex`'s refresh trigger is the access token's own 10-day JWT `exp`, not the `last_refresh` field (backdating that, and the `id_token` exp, was inert), and `codex` does not verify that JWT's signature locally | Nothing further. `oauth-mount` is confirmed a one-shot bootstrap. Recorded in `docs/records/agent-verification.md` and `docs/records/credential-inventory.md` | Recorded, 01.4 SF-3 |
| **The duplicated mount-classification predicate across the acceptance harnesses** | **Open, owner assigned here (D22, 2026-09-10).** All four harnesses answer "which mounts may this agent hold?" independently, in two overlapping flavours; 01.6's agent-mounted trust material tripped every one of them and each needed the same name-scoped exception written separately. Both 01.6 Deviation 5 and Deviation 6 assign the consolidation to `/design` rather than to a feature | A fourth agent-mounted secret repeats the work and risks the copies drifting apart under exactly the change they exist to catch. One copy, `verify-auth-state.sh`, sits outside the composite Test Command by design, so its assertions rot where the completion gate cannot see them — a mount-set-only mode that spends nothing is the candidate fix for that half. Blocks nothing today, which is why it is recorded rather than scheduled | Milestone 02 feature, scope TBD |
| **No way to express a pack-specific `upgrade` on a host the base already governs** | **Open, recorded at 01.5 SF-3 (Deviation 6).** A collision on `(agent, fqdn, port)` with differing `upgrade` values is refused at exit 3 rather than merged, because every merge rule loses information (R5.14). The refusal is right; the schema gap behind it is real | A pack that legitimately needs `upgrade: true` where the base says `false` cannot ship without an edit to the base allowlist. Closing it is a resolved-schema change, so it lands with a manifest-schema feature rather than an install-step one | Unassigned — the deviation names no owner; scope TBD |
| **CIS Docker Benchmark 1.8.0 Container Runtime section** | Not extracted | A per-recommendation applicability table against R1 | Documentation |
| **`README.md` drift** | **Resolved (01.3, 2026-09-07).** The "Out of Scope" section was corrected as the features landed; the bring-up now carries all three listener certificates and the R12.2 denial-troubleshooting section | Nothing | Recorded, 01.3 |
