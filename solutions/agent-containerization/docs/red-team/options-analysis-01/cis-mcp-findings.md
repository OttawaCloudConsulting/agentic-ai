# CIS MCP Companion Guide Assessment

## Agent Persona

I am the CIS Controls v8.1 Model Context Protocol (MCP) Companion Guide conformance reviewer. My role is to test `OPTIONS_ANALYSIS.md` against the Safeguard-by-Safeguard MCP guidance in the April 2026 Companion Guide and find where the artifact omits, contradicts, misapplies, or wrongly scopes a control the guide names.

My adversarial posture: I assume the artifact is incomplete and over-confident about MCP until proven otherwise. Specifically, I assume that naming MCP once in a threat model and never again is a scoping failure, not an economy of expression, and that a network-layer enforcement architecture has not been shown to cover a protocol whose dominant local transport never touches the network. I challenge every affirmative claim in the comparison table and the recommendation, because those are the sentences a reader acts on.

## Assessment Summary

Reference: CIS Controls v8.1 MCP Companion Guide v1.0 (April 2026)

Items examined: **185**

| Scope | Count |
|---|---|
| CIS Controls reviewed (Control 1–18, full text) | 18 |
| Safeguards in the guide (per Appendix C) | 153 |
| Safeguards carrying MCP-specific applicability text | 131 |
| Safeguards marked "No Additional MCP Guidance" (excluded from scoring) | 22 |
| Appendix A deployment-pattern sections (A.1–A.6) | 6 |
| Appendix B MCP CVEs mapped to Safeguards | 21 |
| Glossary terms defining MCP-specific attack classes | 9 |
| Artifact lines read | 236 (all) |

Items examined = 131 MCP-annotated Safeguards + 18 Control-level "MCP Applicability" sections + 6 Appendix A patterns + 21 Appendix B CVEs + 9 attack-class glossary entries.

Findings: **11 (Critical: 1, High: 4, Medium: 4, Low: 2)**

Baseline measurement: `grep -c -i "mcp" docs/OPTIONS_ANALYSIS.md` returns **1**. The single occurrence is line 32. Lines 33–236 (204 lines, including the entire option comparison and every cross-cutting concern) contain no occurrence of "MCP", "Model Context Protocol", "stdio", "JSON-RPC", "tool invocation", or "server registry".

### Safeguards the guide actually covers (reusable mapping)

Coverage below reflects what the guide's MCP Applicability column adds, so this table can be reused for future conformance passes.

| Control | MCP theme the guide adds | Safeguards with MCP guidance | Artifact coverage |
|---|---|---|---|
| 1 — Enterprise Asset Inventory | Server/gateway/client registry; capability baseline snapshot; capability-drift detection; `listChanged` as inventory signal | 1.1–1.5 (5/5) | None |
| 2 — Software Asset Inventory | Server + tool-wrapper allowlisting, version pinning, SBOM, integrity verification at intake and provisioning | 2.1–2.7 (7/7) | None |
| 3 — Data Protection | Tool I/O and resource payloads as classified data; token/cache disposal; two-tier logging; config-file protection | 3.1–3.8, 3.10–3.14 (13/14) | Partial (line 194, confidentiality only) |
| 4 — Secure Configuration | Versioned capability baselines; stdout/stderr discipline; env-var allowlist per server; trusted DNS; change control on capability changes | 4.1, 4.2, 4.4–4.6, 4.8, 4.9 (7/12) | Partial (DNS only, line 103) |
| 5 — Account Management | Identities that run servers; OAuth grant lifecycle; downstream tool service accounts; no cross-env credential reuse | 5.1, 5.3–5.6 (5/6) | None |
| 6 — Access Control | Per-tool RBAC; token audience binding; `resource` parameter; full tool transparency at consent; annotations untrusted; gateway kill switch | 6.1–6.3, 6.5–6.8 (7/8) | None |
| 7 — Vulnerability Management | SDK/spec upgrades as security events; MCP-specific scan checks; third-party server maintenance SLAs | 7.1, 7.2, 7.4–7.7 (6/7) | None |
| 8 — Audit Log Management | Tool invocation, capability negotiation, resource retrieval, session lifecycle, OAuth events; correlation IDs; redaction | 8.1–8.6, 8.8–8.12 (11/12) | Partial (network destinations only) |
| 9 — Email/Web Protections | Tool wrappers as browser clients; DNS filtering of tool egress; URL filtering; content screening pre-context | 9.1–9.4 (4/7) | Partial (DNS, lines 103/203) |
| 10 — Malware Defenses | Server artifacts scanned at intake; **sandbox/containerize stdio servers by default**; EDR rules for server process behaviour | 10.1, 10.2, 10.5 (3/7) | Partial (container boundary) |
| 11 — Data Recovery | Backup of capability manifests, registry snapshots, gateway policy; restore identity layer before tool servers | 11.1–11.5 (5/5) | None |
| 12 — Network Infrastructure | Default-deny tool egress; segment third-party from internal servers; bind local-only servers to `127.0.0.1`; dedicated admin workstations | 12.1–12.4, 12.8 (5/8) | Partial (egress only) |
| 13 — Network Monitoring | Capability drift and tool-sequence anomalies as IoCs; **traffic filtering between MCP segments**; JSON-RPC-aware application-layer filtering | 13.1–13.4, 13.6–13.8, 13.10, 13.11 (9/11) | Partial (destination log) |
| 14 — Awareness & Training | Rug pull, typosquatting, misleading tool descriptions, Elicitation phishing, OAuth consent hygiene | 14.1–14.9 (9/9) | Out of artifact scope |
| 15 — Service Provider Mgmt | Third-party servers as service providers; signed code; registry mirroring; kill-switch testing | 15.1–15.7 (7/7) | None |
| 16 — Application Security | Server-side parameter validation; capability declarations as API surface; content screening for indirect injection; threat-model re-trigger on capability change | 16.1–16.14 (14/14) | None |
| 17 — Incident Response | Containment levers (disable tool, block server, revoke token, **registry freeze**); MCP-specific IR roles | 17.1–17.5, 17.7–17.9 (8/9) | None |
| 18 — Penetration Testing | stdio process-boundary and filesystem-escape testing; tool name shadowing; capability drift deny-by-default | 18.1–18.5 (5/5) | None |

## Findings

### Finding 1: No MCP transport model — the architecture is selected without establishing whether any option's enforcement point is on the MCP path

- **Severity:** Critical
- **Category:** Scoping failure / decision-invalidating omission
- **Observation:** The artifact names MCP as a primary injection vector, then evaluates three architectures whose enforcement points are all network-layer, without ever stating which MCP transport those agents use. For the dominant local transport (stdio), the enforcement point is not on the path at all. The recommendation therefore rests on an unstated and false premise.
- **Evidence:**

  Artifact line 32 (threat model): *"The primary threat is not a malicious user — it is a **compromised agent**: indirect prompt injection from a repository, a web page, an MCP server response, or a dependency..."*

  Artifact lines 34–37 declare the single decision axis: *"That threat model has two consequences that drive every option below... **The enforcement point must sit outside the blast radius.** This is the single axis on which the three options differ."*

  Every enforcement point named is a network mediator — line 42 "Vendor proxy + microVM", line 44 "Separate container, separate network namespace", line 45 "Host kernel / hypervisor".

  Guide line 488: *"Common transports include stdio for local integrations and Streamable HTTP for network deployments."*

  Guide lines 616–617: *"For stdio deployments, security rests on local process boundaries, operating system identities, and file system permissions. Treat local MCP servers as controlled software assets: run them under least-privilege accounts, restrict environment variable scope, control filesystem roots, and apply application allowlisting to approved server binaries."*

  Guide Appendix A.1, line 6791: *"The stdio server runs with the privileges of the host user. It inherits access to local files, environment variables, network resources, and any credentials available to that user. Without OS controls or sandboxing, it can reach any resource available to that user context."*

  Guide Appendix A.1: *"All components run on the same endpoint under the local user context, **with no network exposure between the host and MCP server**."*

  A stdio MCP server is a subprocess of the agent, inside the sandbox. Its JSON-RPC tool calls, tool results and capability negotiation traverse `stdin`/`stdout` and never reach the Option 2 mediator, the `sbx` proxy, or host `pf`/`nftables`. Only the server's own subsequent outbound HTTP calls are visible, and those are indistinguishable from the agent's own traffic.

  The artifact never states, for any of the three options, whether locally-spawned stdio MCP servers run inside or outside the enforcement boundary. The words "stdio", "transport", "JSON-RPC" and "tool invocation" do not appear in the file.
- **Impact:** The document's stated purpose is to select an architecture (line 5: *"This document is the decision material"*). It selects Option 2 partly because it *"is the only one that yields an audit trail of what a compromised agent attempted"* (line 227). For the MCP surface the threat model itself names, no option yields that audit trail, and the document does not tell the reader this. A reader implements Option 2, believes the MCP vector is mediated, and it is not. Every downstream design decision inherits the error.
- **Recommendation:** Add a transport row to the comparison table (lines 154–166) with three values per option: stdio MCP visible / Streamable HTTP MCP visible / MCP tool invocations logged. State explicitly in the Design Constraints section that stdio MCP servers execute inside the blast radius under all three options, and name the compensating control (guide Safeguard 10.5 Additional Considerations, line 4146: *"For high-risk environments, require stdio servers to run in a sandboxed or containerized execution boundary by default, with explicit exceptions required"* — which the container boundary satisfies for confinement but not for visibility).

---

### Finding 2: The egress allowlist doubles as an unrestricted MCP-server supply chain

- **Severity:** High
- **Category:** Misapplied control — network allowlist substituted for software allowlist
- **Observation:** Both the Option 1 policy example and the recommended bootstrap sequence permit package registries wholesale. A permitted package registry is the installation channel for arbitrary MCP servers. The artifact treats registry access purely as an egress convenience and never notes that it defeats MCP server allowlisting.
- **Evidence:**

  Artifact line 65: `sbx policy allow network "api.anthropic.com,*.npmjs.org,*.pypi.org"`

  Artifact line 71: *"Presets: `open` (allow all), `balanced` (default-deny plus a baseline allowlist of AI provider APIs, package managers, code hosts, **registries**)..."*

  Artifact lines 233–235 (Suggested sequence): *"Stand up Option 1 and run the three agents against a representative repository. Capture the real set of destinations each agent contacts. Turn that capture into the allowlist..."* — a capture-derived allowlist will contain npm and PyPI because the agents contact them.

  Guide Safeguard 2.5, lines 1387–1395: *"Enforce an allowlist for MCP servers and tool wrappers using versioned entries with integrity verification, deny-by-default per Control 1. **Install only from enterprise approved registries or vetted artifact repositories, block direct URL, personal registry, and local source installs in production, and verify signatures or hashes at intake and again at provisioning.** Allowlisting must cover both the server artifact and the approved capability set; capability expansions are blocked until reviewed and promoted."*

  Guide Control 10 applicability, line 3943: *"stdio servers run as local processes under the user context, which means that **a malicious package can execute with the same privileges as the host application** and access local files and environment variables."*

  Guide Safeguard 12 Additional Considerations, line 4618: *"Restrict registry access and artifact downloads (third-party servers) through controlled egress with allowlists and logging."*

  Guide Safeguard 15 Additional Considerations: *"implement artifact mirroring for all third-party MCP components... **Restrict production hosts from reaching external community registries directly** to prevent accidental execution of unverified or typosquatted servers."*

  The project already knows npm is the MCP install channel. `RESEARCH_FINDINGS.md` line 126 records: `| registry.npmjs.org | CLI install, plugin installs, `npx` MCP servers |`. That knowledge did not propagate into the artifact's egress reasoning.
- **Impact:** `npx <arbitrary-mcp-server>` succeeds inside every option's sandbox. The server is unreviewed, unpinned, unhashed, and inherits the agent's full container privileges — filesystem mounts, state volume, and the agent's own network allowlist. Typosquatting (guide glossary line ~810) is unmitigated. A network-destination allowlist and a software allowlist are different controls; the artifact's §Egress policy (requirement 5), lines 196–203, presents the former as if it bounded what code runs.
- **Recommendation:** State in §Egress policy that permitting a package registry is not a supply-chain control. Add the discriminating question to the comparison table: can this option block runtime installation of an unapproved MCP server? Name the compensating control per option (Option 2 can mirror registries at the mediator; Option 1's closed policy engine cannot distinguish `npm i lodash` from `npx evil-mcp-server`).

---

### Finding 3: MCP server configuration lives on writable persistent volumes; the artifact treats those volumes as a confidentiality problem only

- **Severity:** High
- **Category:** Omitted control — configuration integrity and attacker persistence
- **Observation:** The auth/state volumes the artifact mandates are exactly the files that declare which MCP servers the agent loads. The artifact's guidance about them is confidentiality-framed ("treat as a secret"). The guide's concern is integrity and change control, and the threat model is a compromised agent that can write to them.
- **Evidence:**

  Artifact lines 181–185 mandate writable volumes: `CLAUDE_CONFIG_DIR` (e.g. `/home/agent/.claude`), `CODEX_HOME` (e.g. `/home/agent/.codex`), and `/home/agent/.gemini`. Line 183 explicitly pulls `~/.claude.json` *inside* the persistent volume: *"Setting `CLAUDE_CONFIG_DIR` to the volume path pulls it inside."*

  Artifact line 194 is the only guidance given: *"**Treat every one of these volumes as a secret.** They hold long-lived refresh tokens."* The paragraph continues about exfiltration only.

  What those volumes actually contain, per the project's own research — `RESEARCH_FINDINGS.md` line 95: *"`~/.claude.json` is a separate file outside `~/.claude` — it holds app state, the OAuth account, **personal MCP servers**, and per-project trust."* And line 268: *"Settings at `~/.gemini/antigravity-cli/settings.json`. **MCP config**, saved conversations and workflows also live under `~/.gemini`. **`~/.gemini` is the high-value path to mount.**"*

  Guide Safeguard 3.11, line 1826: *"**Protect configuration files that may contain authorization metadata, OAuth client credentials, or capability declarations.** Store OAuth client secrets and API keys in a secrets manager, not in plaintext configuration files, and **restrict filesystem permissions on capability and configuration declarations**."*

  Guide Safeguard 4.6, line 2169: *"Apply change control to server deployments, including updates that affect capabilities, OAuth settings, or data source connections. **Treat changes to declared tools, resources, and prompts as configuration changes requiring review, approval, and re-validation before promotion to production.**"*

  Guide Safeguard 4.6 Additional Considerations, line 2377: *"Utilize the registry to maintain an 'allowlist' of authorized environment variables for each server. Prevent the injection of unauthorized credentials or configuration overrides during server startup that are not documented in the registry."*

  Guide Appendix B, line 7233: CVE-2025-66580, *"MCP server config injection — RCE via malicious server config on click"*. Line 7168: CVE-2025-64109, *"Cursor CLI — RCE via malicious `.cursor/mcp.json` in repo"* — and the artifact's threat model line 32 names *"indirect prompt injection from a repository"* while lines 174–175 bind-mount project directories writable by default (`:ro` only *"wherever the agent does not need write access"*).

  The artifact's hardening list at line 101 specifies *"read-only root filesystem with `tmpfs` for scratch"* — which does not cover these volumes. They are writable by design, because requirement 4 demands auth survive restart.
- **Impact:** A compromised agent writes a new MCP server declaration into its own config volume. It survives container restart, because persistence across restart is the volume's purpose. This is attacker persistence inside a sandbox whose entire premise (line 37) is that *"any control the agent process can itself modify is not a control."* MCP server configuration is precisely such a control, it is agent-writable, and the artifact does not notice. A repository-carried MCP config file is the same class of defect, already CVE'd twice.
- **Recommendation:** Add configuration integrity to §Auth and state persistence: which paths inside each state volume are capability declarations, and whether they are agent-writable. Note the one partial mitigation the project already found — `RESEARCH_FINDINGS.md` line 82 records that `srt` hard-denies `.mcp.json`, `.claude/commands` and `.claude/agents` at the project root — and note that it covers Claude Code only, that Options 1 and 3 have no equivalent, and that artifact line 104 currently cites `srt` as undifferentiated "defence in depth" without naming this property.

---

### Finding 4: The "full audit trail" claim covers network destinations only, and is used as a decision criterion

- **Severity:** High
- **Category:** Overstated claim / omitted control — tool-invocation logging
- **Observation:** The artifact's audit-trail claims escalate from an accurate narrow statement to an unqualified "Full" in the comparison table to a superlative in the recommendation. Nothing in any option logs an MCP tool invocation.
- **Evidence:**

  Artifact line 117 (accurate, narrow): *"Every attempted destination is logged. You see the injection attempt, not just the block."*

  Artifact line 126 (Option 2 pro): *"Full audit trail of attempted destinations"*.

  Artifact line 163 (comparison table, unqualified): `| Audit log | Vendor-provided | Full, self-owned | Full, self-owned |`

  Artifact line 227 (recommendation, superlative and load-bearing): Option 2 *"is the only one that yields an audit trail of what a compromised agent attempted"*.

  Guide Safeguard 8.2, line 3410: *"Collect audit logs for **MCP initialization, capability negotiation, tool invocation, resource retrieval, prompt expansion, OAuth token events, session life cycle, and JSON-RPC errors**. Include user identity where available and MCP client identity."* Line 3420: *"Log capability baselines (tools, resources, prompts) at initialization and any subsequent capability changes as high-signal audit events."*

  Guide Control 8 applicability: *"Define a minimum MCP audit schema so that investigations can correlate identity → server → tool/resource → action → outcome across components."*

  Guide Safeguard 3.14: *"Log tool and resource access with enough metadata for audit... Record tool or resource identifiers, identity, server, session, timestamp and request IDs."*

  A destination log records that `github.com` was contacted. It does not record which MCP tool was invoked, with what parameters, on whose behalf. For an MCP server that performs no network I/O — a filesystem server, a local git server (guide Appendix B lists three `mcp-server-git` CVEs at lines 7250–7256, covering arbitrary path init, symlink file write, and symlink file read) — it records nothing whatsoever.
- **Impact:** "Full" is false for the MCP surface, and line 227 uses that falsehood as one of four reasons to pick Option 2. Post-incident, an investigator cannot reconstruct what a compromised agent did through MCP. Guide Control 17 applicability: *"Missing or incomplete audit events tying identities and scopes to tool invocations, resource retrievals, capability changes, and session activity can limit responders' ability to reconstruct what actions occurred."*
- **Recommendation:** Change line 163 to "Network destinations only" for all three options and qualify line 227. This is adjacent to but distinct from `STANDARDS_MAPPING.md` gap G1 (proposed R9.7/R9.8, agent action logging): G1 identifies a missing *requirement*; this finding is that the artifact makes an affirmative *"Full"* claim that G1 shows to be false, inside the table the architecture decision is read from.

---

### Finding 5: No option is evaluated for MCP capability governance, and Option 1 structurally cannot provide it

- **Severity:** High
- **Category:** Scoping failure — missing discriminating criterion in the option comparison
- **Observation:** The comparison table has eleven rows and every one is about network reach, isolation primitive, portability or effort. None asks whether the option can enforce a policy about MCP servers or tools. The answer differs materially between the options, so this is a discriminating criterion that was omitted.
- **Evidence:**

  Artifact lines 154–166, all eleven rows: Enforcement location, Isolation primitive, FQDN denylist, IP/CIDR denylist, DNS exfiltration closed, Covers all three agents, Cross-agent isolation, Audit log, Host portability, Vendor dependency, Effort. No row concerns tool invocation, server allowlisting, capability baselines, or a kill switch.

  Guide Safeguard 1.1, line 980, requires the inventory to record *"risk tier (read-only vs. write vs. irreversible), containment lever owner (who can disable tools, server, gateway), and **capability baseline snapshot (hash or versioned export of tools, resources, prompts)**."*

  Guide Control 1 applicability, line 909: *"MCP servers can change declared capabilities over time (new tools, resources, prompts) without obvious infrastructure changes. **Inventory must detect capability drift, not just new hosts.**"* Line 1118: *"Treat `listChanged` notifications as inventory signals."*

  Guide Safeguard 6.7, line 2982: *"Gateways should support deny-by-default policy and **a rapid kill switch to disable high-risk tools or servers during investigation**."*

  Guide Methodology, line 581: *"**For high-impact workflows, gateway-mediated deployments are the recommended default** to centralize identity binding, policy enforcement, logging, and kill-switch controls."*

  Measured against that, the three options are not equivalent. Option 1's policy surface is network resources only (artifact lines 69–72: hostnames, wildcards, IPs, CIDRs, ports) and the CLI is closed-source (line 81: *"CLI is closed-source (the public repo is a release and issue tracker)"*), so it cannot be extended to express "this MCP server, this tool set." Option 2's mediator is a CONNECT/SNI proxy — network-only as designed, but self-owned and therefore extensible into an MCP gateway. Option 3's `pf`/`nftables` is network-only and not extensible.
- **Impact:** The chosen architecture has no enforcement point for MCP capability policy, and the document gives the reader no way to see that when comparing options. `STANDARDS_MAPPING.md` gap G4 proposes R7.14 (inventory and pin MCP servers) — but a requirement needs somewhere to be enforced, and the architecture selection made here does not create that place. Choosing Option 1, in particular, forecloses it: the option cannot be extended to enforce R7.14 even if R7.14 is merged.
- **Recommendation:** Add a comparison row — "MCP capability policy enforceable at this point: no / extensible / no" — and note in the recommendation that Option 2's self-owned mediator is the only one that can later grow into the gateway-mediated pattern the guide names as its recommended default for high-impact workflows. This is a further argument *for* the artifact's existing recommendation that the artifact does not make.

---

### Finding 6: The threat model mislocates the MCP injection surface

- **Severity:** Medium
- **Category:** Contradicts the guide's stated position
- **Observation:** The artifact scopes the MCP threat to "an MCP server response." The two MCP-specific attack classes the guide defines both operate on tool metadata at capability-negotiation time, before any tool is invoked and before any response exists.
- **Evidence:**

  Artifact line 32: *"...indirect prompt injection from a repository, a web page, **an MCP server response**, or a dependency..."*

  Guide glossary, line 857: *"**Tool Poisoning** — Embedding malicious instructions in tool names, descriptions, or parameter schemas to manipulate LLM behavior."*

  Guide glossary, line 785: *"**Rug Pull Attack** — Updating a previously benign MCP server to include malicious functionality after users have approved it."*

  Guide glossary, `Tool`: *"Tools are **model-controlled**, meaning the LLM selects which tools to invoke based on their descriptions."* The description is the attack surface, and it is ingested during the initialization handshake.

  Guide Safeguard 6.1, line 2803: *"**To counter tool poisoning, the consent process must include 'full tool transparency,'** displaying the complete, un-summarized tool manifest (including descriptions and parameters) to the user before a server is authorized."*

  Guide Safeguard 6.8 Additional Considerations, line 3031: *"**Do not rely on tool annotations** (e.g., `readOnlyHint/destructiveHint`) or model prompts to enforce access control; **treat annotations as untrusted metadata**."* Restated at line 3919 for Control 9.

  Guide Control 18 Additional Considerations: *"Test for **tool name shadowing** where attackers register tools with common names to masquerade as legitimate functionality."*
- **Impact:** A control set derived from "MCP server response" filters tool *outputs*. It does not address poisoned tool descriptions, shadowed tool names, or a rug pull — none of which appear in a response, and all of which influence which tool the model chooses to call in the first place. The threat model is the document's foundation (lines 34–37: *"That threat model has two consequences that drive every option below"*), so an error here propagates.
- **Recommendation:** Rewrite line 32 to name the MCP surface as it actually is: tool descriptions and parameter schemas ingested at capability negotiation, tool results, and capability changes after approval (`listChanged`). Name tool poisoning and rug pull as the attack classes.

---

### Finding 7: The credential-brokering claim is model-API-only; MCP server downstream credentials are unaddressed

- **Severity:** Medium
- **Category:** Overstated claim / omitted control — token scoping for MCP servers
- **Observation:** The artifact's credential broker forwards exactly one API path. Any MCP server that reaches a downstream system needs its own credential inside the container, contradicting the unqualified claim that Option 2 keeps tokens out of the agent container.
- **Evidence:**

  Artifact line 115: *"Optional **credential brokering**: long-lived tokens live in the mediator and are injected as upstream headers, so the agent container never holds a secret. `codex-responses-api-proxy` is a ready-made primitive for this on the OpenAI side — **it forwards only `POST /v1/responses` and 403s everything else**."*

  Artifact line 127: *"Credential brokering keeps tokens out of the agent container"*. Artifact line 227: Option 2 *"is the only one that can broker credentials so tokens never enter the agent container."*

  A proxy that 403s everything except `POST /v1/responses` brokers nothing for a GitHub, Jira, database or cloud MCP server. Those credentials must live in the container — so "never" at line 227 is false as soon as any MCP server with a downstream integration is added.

  Guide How to Use This Guide, lines 611–613: *"**Restrict token exposure to the minimum set of components required to enforce access**, and apply least privilege through scoped access and explicit approval of server capabilities. **Tokens should be scoped to specific servers and capabilities (audience-restricted), short-lived where feasible, and never logged in plaintext.**"*

  Guide glossary, line 846: *"**Token Passthrough** — Forwarding a token received from an MCP client to a downstream API. **MCP forbids token passthrough**; servers that call backend or downstream APIs should obtain separate tokens."*

  Guide Safeguard 5.5 requires a service-account inventory recording *"the tools and resources the account is authorized to access, and the approved secrets system or location used to store credentials. **Cross-environment credential reuse must be explicitly prohibited.**"*

  Guide Control 5 applicability: *"Tool integrations also introduce downstream credentials such as API keys and service tokens, and these must be stored in approved secrets systems and never embedded in code."*
- **Impact:** Line 227 is one of four stated reasons for the recommendation and is unqualified. A reader adds a GitHub MCP server and silently loses the property the recommendation was partly justified on. There is also no guidance on scoping: an MCP server's downstream token typically carries far broader rights than the tool needs, and the guide's audience-binding and least-scope requirements are not represented anywhere in the artifact.
- **Recommendation:** Qualify lines 115, 127 and 227 as covering the model provider API. Add a statement of what happens to MCP server credentials under each option, and whether the mediator's brokering pattern extends to them (it can, per-destination, but that is a design decision the artifact should record).

---

### Finding 8: The cross-agent isolation claim rests on filesystem evidence; the shared `agents-net` leaves agent containers mutually reachable

- **Severity:** Medium
- **Category:** Misapplied control — segmentation
- **Observation:** `internal: true` removes external routing. It does not isolate containers from each other. All three agent containers sit on one L2 segment, so an MCP server listening on a non-loopback address in one agent's container is reachable from another agent's container. The table states cross-agent isolation as an unqualified property.
- **Evidence:**

  Artifact line 94: `[claude] ─┐ [codex] ─┼── agents-net (internal: true — no default route, no DNS to internet)` — one shared network for all three agents.

  Artifact line 102, the only evidence offered: *"One container per agent, one state volume per agent. **Claude Code cannot read Codex's `auth.json`.**"* That is a filesystem statement.

  Artifact line 162, the claim: `| Cross-agent isolation | Per sandbox | Per container | Per VM |` — unqualified.

  Guide Safeguard 13.4, line 4830: *"**Enforce traffic filtering between MCP network segments**: clients to gateways, gateways to MCP servers, and MCP servers to backend systems accessed by tools. **Without filtering between these segments, a compromised MCP server has a network path to every backend system its tools connect to, defeating the containment purpose of the gateway architecture.** Filtering rules should permit only the specific flows required for each deployment pattern and deny all others by default."*

  Guide Safeguard 12.2, line 4449: *"Place servers and gateways in dedicated segments protected by firewall rules. **Isolate third-party servers from enterprise-developed servers.**"* Line 4456: *"**Restrict local-only servers to `127.0.0.1`.**"*

  Guide Appendix A.2, line ~6851: *"MCP servers intended for local access only must bind to `127.0.0.1` rather than 0.0.0.0."*
- **Impact:** The artifact's own attack scenario — one compromised agent — extends laterally over `agents-net` to any MCP HTTP listener in a sibling agent's container, with no policy in the way. The design's credential separation (line 102) is then bypassed at the network layer rather than the filesystem layer: reaching a sibling's MCP server means using that server's credentials without ever reading its `auth.json`.
- **Recommendation:** State the intra-`agents-net` policy explicitly. Either give each agent its own network with only the mediator in common, or require that any MCP HTTP listener bind `127.0.0.1`, and add the filtering requirement to line 101's hardening list. Qualify the line-162 table cell.

---

### Finding 9: The Antigravity splice mandate makes remote MCP traffic permanently uninspectable, and the artifact records the cost as an egress-precision issue

- **Severity:** Medium
- **Category:** Omitted second-order consequence
- **Observation:** The ToS analysis correctly concludes that Antigravity traffic must be spliced, not decrypted. Under splice, a Streamable HTTP MCP server on an allowlisted host is a black box. The artifact books the cost of splice as loss of URL-path granularity, not loss of MCP tool-invocation visibility.
- **Evidence:**

  Artifact line 213: *"For the Antigravity container, use SNI/CONNECT **splice** — inspect the destination, never decrypt. Do not MITM it."*

  Artifact line 124, where the cost is recorded: *"Splice-only gives domain granularity; URL-path rules require TLS MITM and CA distribution."*

  Guide Safeguard 13.10, lines 4930–4936: *"Deploy application-aware gateway controls or a Web Application Firewall (WAF) **capable of parsing JSON-RPC traffic to enforce protocol compliance, OAuth validation, and tool-invocation policies**. Define custom detections for injection attempts, unauthorized tool calls, confused-deputy patterns, and sampling abuse. **Network IDS cannot inspect encrypted MCP traffic; rely on gateway telemetry for application-layer security.**"*

  Guide Safeguard 13.3: *"Content-based detection of MCP protocol semantics requires application-layer inspection (see Safeguard 13.10)."*

  The artifact's line-214 alternative — *"`GEMINI_API_KEY` or Vertex AI ADC routes to the public Gemini API on your own billing, outside the Antigravity OAuth relationship entirely"* — resolves the ToS question for the model API only. It has no effect on MCP servers configured under `~/.gemini`, which the project's own research (`RESEARCH_FINDINGS.md` line 268) confirms exist there.
- **Impact:** For the one agent whose ToS forbids interception, the MCP surface is not merely unmediated (Finding 1) but unobservable in principle, and the artifact does not say so. The guide's answer — gateway telemetry rather than network inspection — requires an MCP gateway, which no option provides (Finding 5).
- **Recommendation:** Restate the cost of splice at line 124 and in §Security Warning to include MCP: under splice, remote MCP tool invocations to allowlisted hosts cannot be inspected or logged by any option, and the guide's compensating control (gateway telemetry, Safeguard 13.10) is not available in the current design.

---

### Finding 10: The container hardening list omits the local-listener and DNS-rebinding surface

- **Severity:** Low
- **Category:** Omitted control — transport hardening
- **Observation:** The Option 2 hardening enumeration covers capabilities, privileges, filesystem and user, but says nothing about inbound listeners or bind addresses. MCP SDKs ship without rebinding protection enabled by default, per two CVEs the guide lists.
- **Evidence:**

  Artifact line 101, the full hardening list: *"Agent containers: `network: internal`, `cap_drop: ALL`, `security_opt: no-new-privileges`, read-only root filesystem with `tmpfs` for scratch, non-root user, project directories bind-mounted (`:ro` where the agent does not need to write)."* No bind-address or inbound-listener policy.

  Guide Appendix B, line 7211: CVE-2025-66414, MCP TypeScript SDK, *"DNS rebinding risk (**protection not enabled by default**)"*. Line 7215: CVE-2025-66416, MCP Python SDK, same. Both map to Safeguards 4.1, 9.2, 12.2, 18.2 — the default posture of the two most common SDKs is vulnerable, so this is a shipped-default problem rather than a hypothetical.

  Guide Appendix A.2, line 6854: *"Enforce Origin validation using an explicit allowlist of expected Origins and reject missing, unexpected, or null Origin values... **do not rely on CORS configuration as a substitute for server-side Origin enforcement.** Origin validation reduces DNS rebinding and cross-origin request risks."*

  Guide Control 12 applicability: *"If endpoints run localhost HTTP helper services without DNS rebinding protections, Origin validation, and authentication, DNS rebinding risk increases... **Pure stdio transports are not affected, but any HTTP listener is.**"*
- **Impact:** Bounded, because `internal: true` blocks external reach, and this is partly the same exposure as Finding 8 approached from the SDK side rather than the network side. It becomes material as soon as any container gains a route out, or a browser-based MCP host is introduced.
- **Recommendation:** Add bind-address policy to line 101: MCP HTTP listeners bind `127.0.0.1`, Origin validation enabled, SDK rebinding protection explicitly turned on rather than left at its default.

---

### Finding 11: No option provides a containment lever below "stop the container"

- **Severity:** Low
- **Category:** Omitted control — incident response
- **Observation:** Every response mechanism in the artifact is network-layer. Nothing lets an operator disable one MCP server or one tool while the agent continues running, and the guide names that lever repeatedly.
- **Evidence:**

  The artifact's response mechanisms are: deny rules (line 66 `sbx policy deny network`, line 111 post-resolution CIDR denylist, line 198 *"the denylist is a second, independent control layered on top"*). All operate on destinations.

  Guide Safeguard 6.7, line 2982: *"Gateways should support deny-by-default policy and **a rapid kill switch to disable high-risk tools or servers during investigation**."*

  Guide Safeguard 1.1, line 980: the inventory must record *"**containment lever owner (who can disable tools, server, gateway)**"* — the guide assumes the lever exists and asks who owns it.

  Guide Control 17 Additional Considerations, line 6515: *"**Include a registry freeze as an explicit containment lever**: suspend all changes to the server registry and capability allowlists during active incidents to prevent capability expansion while an investigation is ongoing. Pre-define the authority and process for initiating and lifting a registry freeze to avoid delays during an incident."*

  Guide Safeguard 17.4: *"Define containment procedures for unauthorized invocations including token revocation, **tool disabling**, and human confirmation enforcement."*
- **Impact:** The coarsest-grained response is the only response: kill the container or blackhole a domain. There is no way to disable a single suspect MCP server across three agents, and no way to freeze capability expansion during an investigation.
- **Recommendation:** Note in the recommendation that MCP-level containment levers are not provided by any option and are follow-on work for the Option 2 mediator, which is the only enforcement point the project owns and can extend.

## Strengths

- **DNS is genuinely handled better than the guide's baseline.** Artifact line 103 (*"The agent network has no route to port 53 on the internet, so DNS tunnelling is structurally impossible rather than merely filtered"*) and line 74 (UDP/ICMP unblockable by policy under `sbx`) satisfy guide Safeguard 4.9 (*"Configure all assets running MCP hosts or clients to use enterprise-managed or trusted DNS resolvers. Untrusted DNS can redirect MCP clients to malicious servers or substitute illegitimate authorization server discovery endpoints, undermining the OAuth authorization chain before a connection is established"*) and Safeguard 9.2 (*"Ensure all DNS queries generated by MCP tools are routed through an approved DNS filtering service"*). The artifact reaches the guide's position by structural argument rather than by filtering, which is stronger than what the guide asks for.

- **The containerization posture satisfies the guide's strongest stdio recommendation.** Guide Safeguard 10.5 Additional Considerations, line 4140: *"Sandbox or constrain stdio servers and tool runtimes using containers, namespaces, or application sandboxes to limit filesystem, network, and subprocess access."* Line 4146: *"For high-risk environments, require stdio servers to run in a sandboxed or containerized execution boundary by default, with explicit exceptions required."* All three options do this by construction. The artifact gets the confinement right; it is the visibility and governance layers it omits.

- **Post-resolution CIDR denial is a control the guide does not name and should.** Artifact line 111: *"even for an allowlisted domain, the connection is refused if the resolved IP falls in a blocked range. This catches CDN IP rotation and DNS rebinding, which an `ipset` snapshot built at container start cannot."* This is a more robust rebinding mitigation than the guide's Origin-validation guidance (Appendix A.2, line 6854), and it applies to MCP servers that the guide's approach would miss.

- **The enforcement-point argument at line 37** (*"any control the agent process can itself modify is not a control"*) is the correct frame, and matches the guide's own deterministic-enforcement position at line 621 (*"a model or client request is not to be treated as an authorization decision. Authorization and policy enforcement must be implemented deterministically at the gateway and/or server layer, independent of model output"*). Finding 3 is a failure to apply the artifact's own principle to MCP configuration, not a disagreement with it.

- **Filesystem scoping and per-agent state separation** (lines 174–178) align with guide Safeguard 3.3 (*"For stdio, bind tool and resource access to the OS identity and restrict file roots and environment access by policy"*) and with the `Roots` primitive. The per-agent volume decision at line 102 is the right default.
