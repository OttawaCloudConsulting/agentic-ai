# CIS Controls v8.1 AI and LLM Companion Guide Assessment

## Agent Persona

I am the CIS Controls v8.1 AI and LLM Companion Guide conformance reviewer. My role is to test `docs/OPTIONS_ANALYSIS.md` against the Safeguard-by-Safeguard guidance in `references/CIS_Controls_v8.1_AI_and_LLM_Companion_Guide_April_2026.md`, with particular attention to controls the guide places **upstream of the network layer**: context boundary enforcement, prompt and guardrail change control, output validation, inference-time monitoring, provider governance, and containment.

My adversarial posture: I assume the artifact is incomplete and over-confident until proven otherwise. Specifically, I assume that an architecture document which names indirect prompt injection as its primary threat and then reasons exclusively about network egress has mistaken a control on the *consequence* for a control on the *threat*, and I set out to prove that from both documents.

## Assessment Summary

Reference: CIS Controls v8.1 AI and LLM Companion Guide v1.0 (April 2026)

Items examined: **153 CIS Safeguards** as interpreted by the guide (19 of which the guide marks "No Additional AI LLM Guidance", leaving 134 with AI-specific text). Of these I assessed **47 Safeguards as in scope** for a model-consuming, non-training, endpoint-hosted + SaaS-API agent sandbox, and tested each against the artifact. Artifact read in full (236 lines). Reference read in full (7,639 lines, sequentially, Controls 1–18 plus Scope, Methodology, Glossary and Appendix A).

Findings: **11** (Critical: 1, High: 4, Medium: 5, Low: 1)

### Scoping decision — training/fine-tuning controls excluded

This project consumes third-party hosted models (Anthropic, OpenAI, Google) and does not train, fine-tune, or self-host weights. The following guide content is therefore **out of scope and is not reported as a gap**: training/fine-tuning dataset governance (Control 3 AI applicability, lines 1587–1596), data poisoning of training corpora (§6.8, lines 2963–2977), model checkpoint/registry backup (§11.1–11.5, lines 4353–4372), model-weight support lifecycle (§2.2, lines 1382–1396), GPU/CUDA vulnerability management (§7.3–7.5), model extraction defence (§13.3, §12.8 — we are the API consumer, not the model provider), and multimodal injection (§4.8 non-text clause, §15.5, §18.2 — the three agents are text/code only). RAG and vector-store Safeguards are excluded on the same basis; the guide itself scopes RAG in only "at the point where they intersect with the model's context window" (lines 558–566), and no RAG corpus exists here.

What survives that filter is exactly the material the artifact under-serves: Controls 3, 4, 5, 8, 9, 12, 13, 15, 16, 17, 18 as they apply to **inference, tool invocation, context boundaries, provider governance, and retirement**.

### In-scope Safeguards and artifact coverage

| Safeguard | Guide's AI-specific expectation (ref. lines) | Artifact coverage |
|---|---|---|
| 2.1 Software Inventory | Inventory model IDs, SDK versions, SBOM/MBOM (1373–1381) | Absent |
| 3.3 Data Access Control Lists | Retrieved/persistent context is a "trusted input"; filter and classify it (1812–1823) | Absent |
| 3.4 / 3.5 Retention & Disposal | Retention and secure disposal for interaction logs, cached outputs, transient artifacts (1824–1836) | Partial — L192 treats 1.5 GB of session history as a disk-size issue only |
| 3.11 Encrypt Data at Rest | Encrypt model-related data; OS-managed storage for API credentials/tokens (1865–1872) | Partial — L194 names volumes as secrets; no encryption stated |
| 3.12 Segment by Sensitivity | Isolate high-trust model components from untrusted external inputs (1942–1951) | Present — per-agent containers/volumes, L101–104 |
| 3.13 Deploy DLP | "DLP solutions … examining data being passed to and from LLMs of all types" (1952–1960) | Absent — see Finding 7 |
| 3.14 Log Sensitive Data Access | Monitor LLM logging for access to known sensitive data (1962–1963) | Absent |
| 4.1 Secure Configuration Process | Managed baselines; version control for system prompts and model parameters; **strict version pinning for model artifacts, avoiding "latest"** (2085–2101) | Absent for models — see Finding 5 |
| 4.4 Firewall on End-User Devices | Restrict outbound to authorized model APIs and repositories (2269–2276) | Present — Options 1/2/3 all |
| 4.5 Securely Manage Assets | "strict sandboxing and network isolation to endpoint-hosted models … centralized, scoped secret management for SaaS API credentials" (2277–2287) | Present — L101–104, L115 |
| 4.8 Disable Unnecessary Services | **"Disable all tools, plugins, and non-text modalities by default; enable only with explicit approval"** (2288–2299) | Absent — see Finding 6 |
| 4.9 Trusted DNS | Enterprise DNS, protected resolution paths, alert on suspicious AI domains (2301–2303) | Present (routing) / Absent (alerting) — L103 |
| 5.1 / 5.5 Account & Service Account Inventory | Inventory every API key, token and non-human identity for model access (2532–2540, 2642–2652) | Absent |
| 5.3 Disable Dormant Accounts | "Remove dormant, stale, or unused identities … API keys often remain active long after projects end" (2562–2567) | Absent — see Finding 8 |
| 6.1 / 6.2 Access Granting / Revoking | Documented grant and **immediate revocation** processes for AI platform access (2799–2808, 2829–2836) | Absent — see Finding 8 |
| 6.8 Role-Based Access Control | Distinct identities per lifecycle stage; least-privilege inference identity (2963–2977) | Partial — per-agent volumes only, L182 |
| 6.x Additional | "Base runtime authorization for tools … on identity policies, never model intent" (3038–3043) | Absent — see Finding 1 |
| 7.1 / 7.7 Vulnerability Mgmt | Prompt-injection weakness and jailbreak vectors treated as vulnerabilities requiring guardrail updates (3076–3080, 3123–3131) | Absent |
| 8.1 Audit Log Mgmt Process | Process for collecting and reviewing logs from LLMs, APIs (3415–3421) | Partial — L117, L163 |
| 8.2 Collect Audit Logs | Log inference traffic and lifecycle events with granular metadata (3436–3449) | Absent |
| 8.5 DNS Query Logs | DNS logs for AI-related domains; **alert on unknown AI endpoints** (3607–3609) | Partial — logging implied, alerting absent |
| 8.6 URL Request Logs | **"Log and attribute outbound HTTP/API requests initiated by models or agents, specifically distinguishing 'tool use' traffic"** + capture what URLs the LLM asked tools to fetch (3611–3621) | Absent — see Finding 2 |
| 8.7 Command-Line Logs | **"Capture execution logs from 'code interpreter' sandboxes … transient containers offload logs to central storage before termination"** (3623–3628) | Absent — see Finding 3 |
| 8.11 Audit Log Reviews | Review for adversarial interaction patterns and behavioural drift (3642–3656) | Absent |
| 8.12 Service Provider Logs | Integrate SaaS model API telemetry with network monitoring (3684–3691) | Absent |
| 9.2 DNS Filtering | Block unapproved AI services and domains used for tool poisoning (3816–3820) | Partial |
| 9.3 Network-Based URL Filters | "Enforce strict URL filtering on agent egress traffic … a compromised agent could be manipulated via prompt injection to exfiltrate data to arbitrary URLs" (3877–3894) | **Present — the artifact's core strength** |
| 9.4 Restrict Extensions/Plugins | Control add-ons that send data to external AI services (3896–3902) | Absent |
| 10.1 / 10.7 Malware Defenses | Content inspection of ingested material; scan for hidden text layers and prompts embedded in URLs before ingestion (4112–4118, 4260–4262) | Absent |
| 10.x Additional | "Tools that allow execution (e.g., 'code interpreters') must use hardened sandboxes with strict isolation and egress restrictions" (4272) | **Present — core of all three options** |
| 12.2 Secure Network Architecture | "restricting outbound connectivity is the primary defense against autonomous data exfiltration" (4600–4625) | **Present** |
| 12.3 Authenticated Gateways | Gateways/API proxies provide logging, identity enforcement, rate limiting (4666–4671) | Partial — no rate limiting, see Finding 11 |
| 12.4 Architecture Diagrams | Diagrams of LLM network architecture incl. flows to external APIs (4672–4677) | Present — L92–99 |
| 13.1 Centralize Security Event Alerting | Correlate SaaS model provider logs with internal identities (4912–4918) | Absent |
| 13.6 Network Traffic Flow Logs | Detect exfiltration attempts, volume spikes, unauthorized connections (5069–5075) | Partial — destination logging only |
| 13.10 Application Layer Filtering | Inspect and control the protocols used by LLM services (5098–5102) | Partial — CONNECT/SNI only, L110, L124 |
| 15.1 / 15.3 Provider Inventory & Classification | Catalogue and classify approved AI service providers (5632–5636) | Absent |
| 15.2 Provider Mgmt Policy | **"conservative default" posture: disabling history retention, opting out of model training, pinning specific model versions, and disabling risky capabilities (e.g., agents) until validated** (5654–5665) | Absent — see Finding 5 |
| 15.4 Contract Security Requirements | Data residency, retention limits, model version transparency (5769–5786) | Absent |
| 15.6 Monitor Providers | Monitor for changes in security posture, **terms of service**, or data handling (5799–5804) | Partial — L205–217 (ToS only, one vendor) |
| 15.7 Securely Decommission Providers | Remove data and **revoke access** on termination (5805–5810) | Absent — see Finding 8 |
| 16.10 Secure Design Principles | **Architectural separation of privileged instructions from untrusted input; system prompts as immutable code; authorization never from model judgment; default to "deny"** (6295–6304) | Absent — see Finding 1 |
| 16.11 Vetted Safety Modules | **Code-based safety frameworks rather than natural-language instructions as security controls** (6310–6316) | Absent — see Finding 1 |
| 16.12 Code-Level Security Checks | Validate model artifacts via signature/checksum before deployment (6322–6326) | Absent |
| 16.14 Threat Modeling | AI-specific threat modeling for unique attack vectors (6343–6347) | Partial — L30–37 is a threat statement, not a model |
| 16.x Additional | "Treat model output as untrusted input" (6397); "Guardrail logic must be version-controlled" (6442); "Fail-Early logic in LLM gateways … **Network controls cannot detect these semantic costs**" (6451–6455) | Absent — see Findings 1, 11 |
| 17.4 Incident Response Process | AI-specific IR procedures for unsafe behaviour, leakage, compromised tools (6660–6670) | Absent |
| 17.8 Post-Incident Reviews | Preserve prompts/policy versions, model versions and hashes, gateway logs, provider audit logs (6743–6751) | Partial — gateway logs only |
| 17.9 Incident Thresholds | **"kill switches or rapid-disable mechanisms for models, endpoints, or tool-enabled capabilities"** (6752–6770) | Absent — see Finding 4 |
| 18.2 External Penetration Tests | **"Test for AI-specific attack patterns such as prompt injection, jailbreaks…"** (6936–6945) | Absent — see Finding 9 |
| 18.4 Validate Security Measures | Confirm injection attacks generate appropriate telemetry and IR can act (7003–7010) | Absent — see Finding 9 |

Coverage tally against the 47 in-scope Safeguards: **7 Present, 12 Partial, 28 Absent.** Every "Present" entry sits in Control 4, 9, 10, or 12 — the network and runtime-isolation band. Zero Safeguards from Control 16 (Application Software Security), Control 17 (Incident Response), or Control 18 (Penetration Testing) are covered.

## Findings

### Finding 1: The artifact's stated primary threat has no mitigating control in any of the three options

- **Severity:** Critical
- **Category:** Omission — context boundary enforcement (Control 16)
- **Observation:** The artifact declares indirect prompt injection the primary threat, then produces three options that differ only in where a network policy is enforced. The guide places the controls that actually address prompt injection at the application layer, above the network: §16.10 and §16.11. Neither appears in the artifact in any form. The strings `system prompt`, `context`, `guardrail`, and `output` occur **zero times** in all 236 lines.
- **Evidence:**
  - Artifact L32: *"The primary threat is not a malicious user — it is a **compromised agent**: indirect prompt injection from a repository, a web page, an MCP server response, or a dependency, causing the agent to exfiltrate data or reach systems it should not."*
  - Artifact L34–37 immediately reduces that threat to two network consequences: *"That threat model has two consequences that drive every option below: 1. The agent has legitimate outbound network access… 2. …The enforcement point must sit outside the blast radius."*
  - Reference §16.10 "Apply Secure Design Principles in Application Architectures", lines 6295–6304: *"Enforce strict architectural separation between privileged system instructions and untrusted inputs or retrieved data. Design applications to treat system prompts as immutable code, using strict template binding to ensure user inputs are sandboxed as passive data variables… When model behavior is ambiguous or violates policy, the system must default to a 'deny' state rather than attempt to autocorrect."*
  - Reference §16.11 "Leverage Vetted Modules or Services", lines 6310–6316: *"Implement vetted, code-based safety frameworks (e.g., NeMo Guardrails, Llama Guard) to enforce security policies, rather than relying solely on system prompts or natural language instructions as security controls. System prompts are easily bypassed via injection and lack deterministic enforcement."*
  - Reference Control 6 Additional, lines 3038–3043: *"Base runtime authorization for tools, data retrieval, and inference APIs on identity policies, never model intent. LLMs must never serve as the arbiter of permission."* The artifact's Option 2 explicitly relies on the agents' own in-container controls as its injection-adjacent layer (L104: *"Each agent's own native controls are layered inside as defence in depth: `srt` for Claude Code, `features.network_proxy` for Codex, `agy --sandbox`"*) — controls the artifact itself classifies at L37 as *"not a control"* because the agent process can reach them.
  - Reference Control 16 AI LLM Applicability, line 5907: *"application-layer logic becomes even more critical, acting as the 'policy spine' that constrains and interprets model behavior safely."* The artifact builds no policy spine.
- **Impact:** All three options are equally unprotected against the injection event itself. An agent under injection inside Option 2 still executes the injected instruction — it reads the credential volume, rewrites the project, calls the tools it holds. What the mediator constrains is only where the *result* can be sent, and the model provider API (`api.anthropic.com`, L65) is allowlisted by necessity (L36), which leaves the highest-bandwidth exfiltration channel open by design. The document is presented as *"the decision material"* (L5), but it gives a reader no basis whatsoever for choosing among options on the threat it declared primary. A reader who follows the recommendation will build Option 2 believing the primary threat is addressed.
- **Recommendation:** Add a Cross-Cutting Concern section covering the context boundary: (a) which agent inputs are untrusted-by-construction (repository contents, web fetches, MCP tool responses, dependency manifests) and what structurally separates them from instructions; (b) a statement of what is *not* mitigated, so the residual risk is explicit; (c) whether a deterministic policy layer sits between the agent and its tools, per §16.11. If the honest answer is "none of the three options mitigates injection; all three bound its consequences", say that in the threat model at L30–37 and restate the primary threat as *exfiltration and lateral reach by a compromised agent*. That is defensible; the current framing is not.

### Finding 2: Egress destination logging is presented as injection detection; the guide requires attribution the design cannot produce

- **Severity:** High
- **Category:** Misapplication — Control 8 (§8.6)
- **Observation:** The artifact claims its egress log reveals injection attempts. A destination log records that *something inside the container tried to reach a host*. It does not record which agent, which tool call, which session, or what the model was asked to fetch. The guide's §8.6 asks precisely for that attribution, and names it as the requirement for IR.
- **Evidence:**
  - Artifact L117: *"Every attempted destination is logged. **You see the injection attempt, not just the block.**"*
  - Artifact L126: *"Full audit trail of attempted destinations"* listed as an Option 2 pro.
  - Artifact L163 comparison row: `| Audit log | Vendor-provided | Full, self-owned | Full, self-owned |`
  - Reference §8.6 "Collect URL Request Audit Logs", lines 3611–3621: *"Log and attribute outbound HTTP/API requests initiated by models or agents, specifically distinguishing 'tool use' traffic from standard infrastructure updates… **Collecting the prompt response data from the LLM about what URLs or information from URLs the LLM is requesting tools to fetch completes the picture needed for IR** and other investigations of suspicious activity."*
  - The design forecloses the distinction §8.6 asks for: all traffic from a given agent container reaches the mediator as an undifferentiated CONNECT stream from one source IP. Package-manager fetches (`*.npmjs.org`, L65), model API calls, and injected tool fetches are indistinguishable at that layer.
- **Impact:** "Full" audit is asserted for Options 2 and 3 in the comparison table and repeated in the recommendation (L227: *"is the only one that yields an audit trail of what a compromised agent attempted"*). A reader selects Option 2 partly on that claim. In an actual incident the operator has a list of hostnames and no way to attribute any of them to a session, an agent, or a tool call — the reconstruction §8.6 exists to enable is not possible.
- **Recommendation:** Change L117 to state what the log actually shows ("you see an outbound attempt to a non-allowlisted destination; you do not see what caused it"). Retitle the L163 row from "Audit log" to "Egress audit log" and change the Option 2/3 cell from "Full, self-owned" to "Destination-level, self-owned". Add a distinct row for agent action logging with an honest value for all three options.

### Finding 3: No agent action, tool-call, or execution logging — and the comparison table asserts the opposite

- **Severity:** High
- **Category:** Omission — Control 8 (§8.7, §8.11)
- **Observation:** The guide requires execution logs from code-interpreter sandboxes, offloaded off the ephemeral container before it dies, and periodic review of those logs for adversarial patterns and behavioural drift. The artifact's containers are exactly the "transient containers" §8.7 names and it specifies no such capture. The strings `tool call`, `monitor`, `detect`, `alert`, and `drift` occur zero times in the artifact.
- **Evidence:**
  - Reference §8.7 "Collect Command-Line Audit Logs", lines 3623–3628: *"Capture execution logs from 'code interpreter' sandboxes and training environments, **ensuring transient containers offload logs to central storage before termination**. AI systems capable of generating and executing code (e.g., Python agents) act as remote shells; without logs, malicious code execution is untraceable."*
  - Reference §8.11 "Conduct Audit Log Reviews", lines 3642–3656: *"Review logs for adversarial interaction patterns, excessive errors, and unexpected behavioral drift."*
  - Artifact L235 explicitly designs for ephemerality without log offload: the suggested sequence builds and tears down environments with no persistence requirement for execution history. L172–177 (Filesystem scoping) and L179–194 (Auth and state) enumerate every volume the design mounts; **none is a log volume.**
  - Artifact L163 nonetheless claims `Full, self-owned` audit for Options 2 and 3.
  - Sibling coverage: `docs/STANDARDS_MAPPING.md` G1 already records this gap and proposes R9.7/R9.8. It is therefore not novel. What *is* novel is that the artifact affirmatively claims complete audit coverage while its own project documentation records the coverage as missing — the two documents contradict each other, and the artifact is the one being used as decision material.
- **Impact:** The artifact recommends Option 2 partly on audit grounds (L227). If the audit claim is understood as covering agent behaviour, the recommendation rests on a capability the design does not have and G1 says is not required yet. Post-incident, there is no record of what the agent did inside the container — only where it tried to connect.
- **Recommendation:** Either scope the audit claims to network egress explicitly everywhere they appear (L117, L126, L163, L227), or add agent action logging as a cross-cutting concern with a per-option assessment. Cross-reference G1 so the artifact and STANDARDS_MAPPING stop disagreeing.

### Finding 4: No containment, kill-switch, or revocation path — the guide's named response lever for AI systems

- **Severity:** High
- **Category:** Omission — Control 17 (§17.8, §17.9)
- **Observation:** The artifact is entirely about building the boundary and silent about what happens when the boundary reports a hit. The guide names containment as one of four AI-specific risk domains in its Executive Summary and gives it a dedicated Safeguard treatment. The strings `kill switch`, `revoke`, `revocation`, and `decommission` occur zero times.
- **Evidence:**
  - Reference Executive Summary, lines 504–507: *"It also highlights AI-specific risk domains that require explicit operational controls, including prompt and guardrail change control, context boundary enforcement, model and dataset provenance, and **the containment levers required to respond quickly when AI-driven workflows behave unexpectedly.**"*
  - Reference §17.9 "Establish and Maintain Security Incident Thresholds", lines 6752–6770: *"…tie those thresholds to rapid-disable mechanisms… isolated abnormal outputs, unexpected tool calls, or minor prompt-handling issues may be events, while sustained unsafe outputs, attempts to take unapproved actions through tools… should be treated as incidents. When those thresholds are met, enterprises need **kill switches or rapid-disable mechanisms for models, endpoints, or tool-enabled capabilities.**"*
  - Reference §17.8 preservation list, lines 6743–6751 — post-incident review must preserve: *"Prompts/policies versions · Model versions and hashes · RAG corpus snapshots · Vector database logs/snapshots · Gateway logs · Provider admin/audit logs."* Of the applicable four (prompts/policy versions, model versions and hashes, gateway logs, provider audit logs) the artifact preserves **one** — gateway logs.
  - Artifact L219–236: the Recommendation and Suggested sequence end at "build Option 2". There is no step covering detection thresholds, response, or teardown-under-compromise.
  - The artifact makes the omission materially worse at L191: *"use `claude setup-token` to mint a **one-year** `CLAUDE_CODE_OAUTH_TOKEN`"* — a one-year bearer token stored on a volume the artifact itself calls secret material (L194), with no stated revocation path.
- **Impact:** The design produces a detection signal (a blocked destination) with no defined response. Under §17.9 the operator needs to disable an agent, a tool pack, or a credential quickly; nothing in the artifact says how, and the one-year token at L191 is the slowest possible thing to revoke.
- **Recommendation:** Add a "Containment and response" cross-cutting concern: what constitutes an event vs. an incident for this sandbox (per §17.9's own examples — unexpected tool calls, repeated blocked destinations); how an agent is stopped and its credentials revoked without rebuilding the environment; which of the §17.8 artifacts are preserved and where. State the revocation path and expiry posture for the one-year `CLAUDE_CODE_OAUTH_TOKEN` at L191 or drop that recommendation.

### Finding 5: The model providers are never treated as service providers — no model version pinning, no provider configuration baseline

- **Severity:** High
- **Category:** Omission — Control 15 (§15.2, §15.4, §15.6), Control 4 (§4.1)
- **Observation:** The artifact treats Anthropic, OpenAI and Google exclusively as network destinations to be allowlisted and, in one case, as a legal risk. It never treats them as AI service providers under Control 15, and never applies the model-configuration baseline of §4.1. `model version` occurs zero times in the artifact.
- **Evidence:**
  - Reference §15.2 "Establish and Maintain a Service Provider Management Policy", lines 5654–5665: *"The service provider management policy must enforce a 'conservative default' posture by mandating a safe baseline: **disabling history retention, opting out of model training, pinning specific model versions, and disabling risky capabilities (e.g., agents) until validated.** Policies must also require evidence of tenant isolation, logging clarity, and AI-specific incident notification SLAs."*
  - Reference §4.1 "Establish and Maintain a Secure Configuration Process", lines 2085–2101: *"Establish managed configuration baselines for all AI components, enforcing version control for system prompts and model parameters, **strict version pinning for model artifacts**, and hardened defaults for inference environments… Without strict version pinning (avoiding 'latest' tags), enterprises risk implicit upgrades that introduce new vulnerabilities or **break existing guardrails.**"*
  - Reference §15.6 "Monitor Service Providers", lines 5799–5804: monitor for changes in *"security posture, terms of service, or data handling practices."*
  - Artifact L165 comparison row: `| Vendor dependency | High | None | None |` — "vendor" here means **Docker**, not the model providers. Options 2 and 3 are scored "None" for vendor dependency while depending entirely on three SaaS model providers whose behaviour is the substrate of the whole system. This is a scoping error in the decision table itself.
  - The artifact's only provider-governance content is L205–217 (Antigravity ToS), which is a legal-exposure analysis for one vendor, not a §15.2 configuration baseline for any of the three.
  - The guide's own shared-responsibility model for SaaS-hosted models (lines 786–798) assigns the enterprise: *"Data classification and deciding what data is allowed to be sent… Integration logic, guardrails, and application behavior built around the model… Contractual requirements for data retention, residency, and training reuse."* None appears in the artifact.
- **Impact:** A provider-side model change can silently alter agent behaviour inside a sandbox whose entire security argument is about *where the agent can connect*, not *how it behaves*. Under §4.1 that change can "break existing guardrails" — and since the artifact has no guardrails (Finding 1), the change is undetectable. The `Vendor dependency: None` row misleads the reader about Option 2's actual dependency surface.
- **Recommendation:** Add a Cross-Cutting Concern for provider governance covering, per agent: model version pinning or the absence of that capability; history retention and training opt-out settings; what data classification is permitted to leave; and the provider's incident-notification path. Rename the L165 comparison row to "Tooling vendor dependency" so it is not read as covering the model providers, and add a row for model provider governance where all three options score identically (which is itself the useful finding).

### Finding 6: MCP servers are named as an injection vector at L32 and then never constrained anywhere in the design

- **Severity:** High
- **Category:** Scoping error — Control 4 (§4.8), Control 2 (§2.1)
- **Observation:** The artifact's threat statement names *"an MCP server response"* as one of four injection sources. MCP then disappears from the document entirely — it appears exactly once, at L32. No option describes how MCP servers are inventoried, pinned, granted or denied network access, or defaulted off. The guide's position on tools and plugins is unambiguous default-deny.
- **Evidence:**
  - Artifact L32 (only occurrence of "MCP" in 236 lines): *"indirect prompt injection from a repository, a web page, **an MCP server response**, or a dependency"*.
  - Reference §4.8 "Uninstall or Disable Unnecessary Services", lines 2288–2299: *"**Disable all tools, plugins, and non-text modalities by default; enable only with explicit approval.** Tools and plugins empower models to execute real-world actions that can bypass standard application policies… Enabling these features without review opens the door to unauthorized command execution and unmonitored data processing. A default-deny posture ensures that these high-risk capabilities are only active when the specific security controls required to protect them are confirmed to be in place."*
  - Reference §2.1, lines 1373–1381, requires inventory of *"SDKs with versions, and runtimes"* — MCP servers are third-party executable code with network access running inside the sandbox and fall squarely inside this.
  - The artifact applies default-deny reasoning rigorously to the network (L71, L198: *"Default-deny allowlist is the primary control"*) and not at all to tools. The asymmetry is the finding.
  - Sibling coverage: `REQUIREMENTS.md` R7.13 carries a prose note, and `STANDARDS_MAPPING.md` G4 records the missing inventory requirement. The gap is documented. But the artifact is the document that *introduced MCP as a primary threat source*, and dropping it from every option and from the comparison table is an artifact-level failure, not a downstream one.
- **Impact:** An MCP server added to a use-case profile is a new injection source and a new network client inside the boundary. Under the artifact as written, Option 2's per-agent egress allowlist would have to be widened for it, and nothing in the decision material tells the reader that or forces a review. The threat named at L32 is unaddressed by the option the artifact recommends.
- **Recommendation:** Either remove MCP from L32 (if MCP is out of scope, say so in a non-goal) or add MCP/tool governance to Cross-Cutting Concerns: default-off, inventoried and version-pinned per profile, egress entries declared by the server not inherited, and reviewed on the same basis as any other tool pack. Add a comparison row for tool/MCP containment.

### Finding 7: The chosen design forecloses content inspection of the model-API channel and never states the consequence

- **Severity:** Medium
- **Category:** Omission — Control 3 (§3.13), Control 9 model-hosting considerations
- **Observation:** The guide requires DLP inspection of data flowing to and from LLMs. The artifact's recommended design deliberately cannot do this on the one channel that carries every prompt and completion, and presents the resulting audit posture as "full" without noting the blind spot. `DLP` occurs zero times.
- **Evidence:**
  - Reference §3.13 "Deploy a Data Loss Prevention Solution", lines 1952–1960: *"Ensure that DLP solutions are examining data being passed to and from LLMs of all types to ensure that data flow is following enterprise policies. **LLM interactions represent just as large a vector for data loss as any other application or network data flow and must be given as much attention as these to reduce risk.**"*
  - Reference Control 9, Endpoint-Hosted Models, lines 3964–3968: *"Workstations used for AI-assisted browsing must still respect corporate SWG and DLP policies. Local tools must not configure direct, unmanaged connections to external AI endpoints."*
  - Artifact L124 acknowledges the mechanism but not the consequence: *"Splice-only gives domain granularity; URL-path rules require TLS MITM and CA distribution"*.
  - Artifact L213 mandates splice for one agent on legal grounds: *"For the Antigravity container, use SNI/CONNECT **splice** — inspect the destination, never decrypt. Do not MITM it."*
  - Net effect: for `api.anthropic.com`, `chatgpt.com` and the Gemini endpoint — the destinations that carry 100% of prompt and completion content — the design sees hostname and byte count only.
  - Sibling coverage: `REQUIREMENTS.md` Non-Goals declares *"Preventing exfiltration through legitimately allowlisted destinations — Structurally impossible."* That answers a different question. §3.13 asks for **detection and policy inspection**, not prevention; the sibling's non-goal does not discharge it, and the artifact carries neither the non-goal nor the trade-off.
- **Impact:** The blind spot sits exactly where the guide says the data-loss vector is largest. The artifact's Option 2 pro column (L126, "Full audit trail of attempted destinations") reads as comprehensive coverage to a reader who has not traced which channel carries the data.
- **Recommendation:** Add an explicit statement in the Egress policy cross-cutting section (L196–203): the model provider channel is inspected at the destination level only; prompt and completion content is not inspected in any of the three options; a compromised agent can exfiltrate through the model API and this is accepted, not mitigated. Name it as a residual risk rather than leaving it implicit in the MITM discussion at L124/L213.

### Finding 8: No retirement path — credential revocation, token expiry, and session-transcript disposal are all absent

- **Severity:** Medium
- **Category:** Omission — Control 5 (§5.3), Control 6 (§6.2), Control 15 (§15.7), Control 3 (§3.4, §3.5)
- **Observation:** The guide covers the full lifecycle "including retirement" (line 503). The artifact covers provisioning and steady state. It correctly identifies that state volumes hold long-lived refresh tokens (L194) and then stops — no rotation, no revocation, no expiry, no disposal.
- **Evidence:**
  - Reference §5.3 "Disable Dormant Accounts", lines 2562–2567: *"Remove dormant, stale, or unused identities in AI development, training, and model-management environments. **Service accounts and API keys often remain active long after projects end.** Regular cleanup prevents exploitation of forgotten credentials."*
  - Reference §15.7 "Securely Decommission Service Providers", lines 5805–5810: *"Establish a process for securely removing data and revoking access when terminating AI service provider contracts."*
  - Reference §3.4/§3.5 AI applicability (lines 1824–1836): *"Establish and enforce documented retention policies for model interaction logs… Implement secure deletion processes for model interaction logs, embeddings, cached outputs, and transient artifacts to ensure sensitive or residual content is irreversibly removed when no longer required."*
  - Artifact L194: *"**Treat every one of these volumes as a secret.** They hold long-lived refresh tokens."* — correct diagnosis, no prescription.
  - Artifact L191: a **one-year** `CLAUDE_CODE_OAUTH_TOKEN` is offered as a solution with no expiry-management or revocation guidance.
  - Artifact L192: *"The host `~/.codex` directory is 1.5 GB of session history. Mount a fresh volume, not the host directory."* — session transcripts are treated as a disk-space problem. Under §3.4/§3.5 they are model interaction logs containing full plaintext conversation history and carry retention and secure-disposal obligations.
  - Sibling coverage: `REQUIREMENTS.md` R4.10 covers transcript retention and R8.5 covers rotation/revocation; `STANDARDS_MAPPING.md` G5 records the long-lived-token trade-off as unrecorded. The artifact carries none of it, and L191/L192 actively point the reader away from it.
- **Impact:** A one-year bearer token on an unencrypted volume, in an environment whose whole purpose is containing a compromise, with no stated revocation path, is the single longest-lived piece of credential material the design creates. The artifact recommends minting it without flagging that.
- **Recommendation:** Add lifecycle language to the "Auth and state persistence" section: rotation cadence and revocation path per agent; retention and disposal policy for session transcripts (naming them as model interaction logs, not history files); and an explicit note at L191 that a one-year token is a deliberate trade against §5.3 with revocation as the compensating control.

### Finding 9: The validation plan cannot falsify the design against its own stated primary threat

- **Severity:** Medium
- **Category:** Omission — Control 18 (§18.2, §18.4)
- **Observation:** The Suggested sequence is a four-step plan and every validation step in it is a traffic-capture step. The guide requires that AI systems be tested with adversarial input specifically, and that the test confirm the monitoring and response path fires.
- **Evidence:**
  - Reference §18.2 "Perform Periodic External Penetration Tests", lines 6936–6945: *"**Test for AI-specific attack patterns such as prompt injection, jailbreaks, model extraction, data leakage, and misuse of model capabilities.** Pen testers should actively attempt to break guardrails, generate unsafe output, trigger unapproved tools, or extract sensitive model or data elements."*
  - Reference §18.4 "Validate Security Measures", lines 7003–7010: *"Validate that monitoring, alerting, and incident response procedures correctly detect and respond to AI-specific attacks. Penetration tests should confirm that model extraction attempts, **injection attacks**, or poisoning behaviors generate appropriate telemetry and that incident response teams can act quickly."*
  - Reference Control 18, Endpoint-Hosted Models, lines 7028–7032: *"Browsing or code-execution tools enabled on endpoints should be validated for **sandbox bypass** or unsafe outbound traffic."*
  - Artifact L231–236, the complete validation plan: *"1. Stand up Option 1 and run the three agents against a representative repository. Capture the real set of destinations each agent contacts. 2. Turn that capture into the allowlist… 3. Build Option 2 with that policy… 4. Re-evaluate Option 3 only if the threat model changes."*
  - Step 1's stated purpose is discovering legitimate destinations, i.e. **reducing false positives**, not testing the boundary against an adversary. No step introduces a poisoned repository, an injected web page, or a hostile MCP response — the four sources L32 names.
- **Impact:** The plan validates that the allowlist does not break normal work. It never tests whether the boundary holds under the attack the document was written to defeat, and §18.4's requirement — that an injection attempt produce telemetry an operator can act on — is untested and, given Findings 2 and 3, would fail.
- **Recommendation:** Add a validation step between current steps 3 and 4: run each agent against a repository seeded with injected instructions targeting a non-allowlisted collector, confirm the attempt is blocked, confirm the attempt is visible in the log, and confirm the operator can attribute it. Note explicitly which of the four L32 injection sources are exercised and which are not.

### Finding 10: "The single axis on which the three options differ" is asserted without support and is the root cause of Findings 1–9

- **Severity:** Medium
- **Category:** Assertion without evidence / scoping error
- **Observation:** The artifact narrows the entire option space to one variable in a single sentence, with no argument for the exclusion of the others. The guide's model is explicitly layered, and the artifact's own comparison table contains eleven rows, at least six of which are axes on which the options differ.
- **Evidence:**
  - Artifact L37: *"the agent runs arbitrary code by design, so any control the agent process can itself modify is not a control. **The enforcement point must sit outside the blast radius. This is the single axis on which the three options differ.**"*
  - Artifact L154–166: the comparison table's own rows contradict this — `Isolation primitive`, `IP / CIDR denylist` (Option 2 alone has post-resolution deny), `Covers all three agents` (Option 1 is Partial), `Audit log`, `Host portability`, `Vendor dependency`, `Effort` are all axes of difference, and the Recommendation at L227 decides on four of them, not on enforcement-point location.
  - Reference Control 16 AI LLM Applicability, line 5907: *"LLM integration should never bypass traditional application security; instead, **application-layer logic becomes even more critical, acting as the 'policy spine'** that constrains and interprets model behavior safely."*
  - Reference Executive Summary, lines 504–507, names four AI-specific risk domains requiring explicit operational controls; **network egress is not among them.**
  - The claim also does real analytical damage: because L37 declares the axis settled, Sections "Option 1/2/3" (L49–150) and the comparison table (L152–166) never revisit whether an option differs on any AI-layer control — and consequently 28 of 47 in-scope Safeguards are absent from the artifact.
- **Impact:** The framing at L37 is what makes the rest of the document network-only. It converts a genuine and well-argued insight (enforcement must sit outside the blast radius) into a claim of exhaustiveness that the guide does not support and that the artifact's own table refutes.
- **Recommendation:** Change L37 to *"This is the axis on which the three options differ most, and the one this analysis weighs most heavily"* and add one sentence naming what the axis does **not** cover — the AI-layer controls of Controls 4, 8, 16 and 17, which are identical across all three options and are therefore treated as cross-cutting concerns rather than differentiators. That single change makes Findings 1, 3, 4, 5 and 6 into acknowledged scope rather than silent omissions.

### Finding 11: The mediator is an LLM gateway, and the guide names a control at that exact component which the design omits

- **Severity:** Low
- **Category:** Omission — Control 16 Additional, Control 12 (§12.3)
- **Observation:** Option 2's egress mediator is precisely the "LLM gateway / control layer proxying LLM interactions" the guide addresses, and the guide states outright that the network controls the artifact builds cannot detect the class of abuse it names there.
- **Evidence:**
  - Reference Control 16 Additional, lines 6451–6455: *"**Implement 'Fail-Early' logic in LLM gateways and other control layers proxying LLM interactions.** To prevent 'Denial of Wallet' attacks, which aim to exhaust token budgets, the application must validate token counts, enforce strict 'max_token' limits, and identify recursive loops before requests are forwarded to the model inference layer. **Network controls cannot detect these semantic costs.**"*
  - Reference §12.3 "Securely Manage Network Infrastructure", lines 4666–4671: *"Use authenticated gateways/API proxies (or mutual TLS) so that only authorized systems can reach model endpoints. Inference APIs should not be directly exposed to user networks; **gateways provide logging, identity enforcement, rate limiting, and consistent policy application.**"*
  - Artifact L106–118 enumerates the mediator's controls: allowlist at CONNECT/SNI, post-resolution CIDR denylist, credential brokering, destination logging. No rate limiting, no request-count bounding, no loop detection.
  - Artifact L115 shows the design already terminates and rewrites requests at the mediator (*"long-lived tokens live in the mediator and are injected as upstream headers"*), so the hook point for §12.3 rate limiting exists and is unused. `codex-responses-api-proxy` is cited at L115 as forwarding only `POST /v1/responses` — a request-shape control, not a rate control.
- **Impact:** A prompt-injected agent stuck in a loop burns the operator's model subscription and generates only allowlisted-destination traffic, which the design logs as normal. This is a cost and availability consequence rather than a data-loss one, which is why it is Low — but it is a control the guide places at the component the artifact is building, and the design already has the interception point needed to implement it.
- **Recommendation:** Add per-agent request-rate and concurrent-session limits to the Option 2 mediator description at L106–118, alongside the existing allowlist and denylist controls. One line in the "Two independent controls, in order" list.

## Strengths

- **Control 12 §12.2 is met better than most production designs.** The guide's statement at lines 4619–4625 — *"restricting outbound connectivity is the primary defense against autonomous data exfiltration; without strict egress filtering to approved domains, a compromised or hallucinating model could send proprietary outputs to external endpoints"* — is the exact argument the artifact builds three options around, and it builds them correctly.
- **Control 9 §9.3 is met, including the reasoning.** Reference lines 3877–3894 state the control's purpose as protecting against *"a compromised agent … manipulated via prompt injection to exfiltrate data to arbitrary URLs"*. The artifact reaches the same conclusion independently and goes further than the guide on mechanism: the post-resolution CIDR denylist (L111) defeats CDN rotation and DNS rebinding, which a naive allowlist does not.
- **The DNS-ownership analysis exceeds the guide.** §4.9 (lines 2301–2303) asks for trusted DNS servers; §8.5 (3607–3609) asks for DNS query logs. The artifact's insight at L103 — *"The agent network has no route to port 53 on the internet, so DNS tunnelling is structurally impossible rather than merely filtered"* — is a stronger control than either Safeguard requires, correctly identifies that both vendor reference firewalls fail here (L204), and is carried consistently across all three options in the comparison table (L160).
- **Control 4 §4.5 is met precisely.** Reference lines 2253–2260 call for *"strict sandboxing and network isolation to endpoint-hosted models while mandating centralized, scoped secret management for SaaS API credentials."* The artifact's L101 hardening set (`cap_drop: ALL`, `no-new-privileges`, read-only rootfs, non-root, per-agent state volumes) plus credential brokering at L115 is a direct implementation of both halves.
- **Control 10's code-interpreter clause is the artifact's whole premise.** Reference line 4272: *"Tools that allow execution (e.g., 'code interpreters') must use hardened sandboxes with strict isolation and egress restrictions."* All three options satisfy this; Option 3 exceeds it.
- **The enforcement-point-outside-the-blast-radius principle (L37, L39–45) is correct and is not stated anywhere in the CIS guide with equal clarity.** The rejection of the vendor reference devcontainers at L47 — in-container `iptables` requiring `NET_ADMIN`/`NET_RAW` — is a sound application of the principle and correctly identifies published reference designs as inadequate.
- **The Antigravity ToS analysis (L205–217) is honest about its own epistemic status.** *"This guidance is an interpretation of the published terms, not an official Google position. Google staff declined to clarify the boundary when asked."* This is the correct posture under §15.6 (monitoring providers for terms-of-service changes) and the artifact does not overstate it.
- **Delegation of evidence to `RESEARCH_FINDINGS.md` (L5) is a legitimate structure** and was respected in this review: no finding above is a missing citation. Every finding is a missing control, risk, or decision.
