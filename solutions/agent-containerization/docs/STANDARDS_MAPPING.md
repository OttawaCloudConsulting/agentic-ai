# Standards and Guidance Mapping

Which published security standards apply to sandboxed agentic AI, what each one actually says, and how it maps onto [`../REQUIREMENTS.md`](../REQUIREMENTS.md).

**Date:** 2026-09-02. All URLs link-checked on that date.
**Revised 2026-09-03** following the red-team run in [`red-team/options-analysis-01/`](red-team/options-analysis-01/CONSOLIDATED-REPORT.md). Three changes of substance: the CIS inventory was stale (three companion guides, not two); the Safeguard mappings are now extracted from the primary PDFs; and **five of the six Five Eyes quotations previously recorded here did not survive verification against the primary text** — see [Key positions](#key-positions).

## Contents

- [Summary](#summary)
- [CIS — what exists and what does not](#cis--what-exists-and-what-does-not)
- [Five Eyes joint guidance on agentic AI](#five-eyes-joint-guidance-on-agentic-ai)
- [Mapping to our requirements](#mapping-to-our-requirements)
- [Gaps](#gaps)
- [Frameworks not evaluated](#frameworks-not-evaluated)
- [Retrieval checklist](#retrieval-checklist)
- [Sources](#sources)

## Summary

| Question | Answer |
|---|---|
| Does CIS publish an agentic AI **Benchmark**? | **No.** The Benchmarks catalogue contains no AI, LLM, agentic, or MCP entry |
| Does CIS publish agentic AI **guidance**? | **Yes** — three CIS Controls v8.1 Companion Guides (AI Agents, AI and LLM, Model Context Protocol). The first two are dated 2026-04-20; the MCP guide's cover states only "April 2026" |
| Are those guides prescriptive config baselines? | **No.** They are Safeguard mappings — "apply Control X through an AI-aware lens" — not lintable configuration lines |
| Which CIS Benchmarks apply to this project? | Docker (1.8.0) and Kubernetes (2.0.1), for the container substrate rather than the agent layer |
| Most actionable published guidance for this project? | The Five Eyes **Careful Adoption of Agentic AI Services** (2026-05-01) — not a CIS product |

The practical consequence: CIS gives us a governance vocabulary and a container hardening baseline, but nothing that tells us how to configure an agent sandbox. The Five Eyes guidance is where the architectural direction comes from.

It corroborates one decision strongly — the enforcement-point-outside-the-blast-radius principle — and it is not a general endorsement of the design. Read as a review lens against `OPTIONS_ANALYSIS.md`, the same document produced 16 findings, one of them Critical. The three CIS guides produced a further 34. Treat these standards as a source of requirements not yet met, not as confirmation of requirements already met.

## CIS — what exists and what does not

### No agentic AI Benchmark

Verified against the live CIS Benchmarks catalogue on 2026-09-02: there is no AI, LLM, agentic AI, or MCP benchmark. If you are looking for a CIS-style prescriptive baseline for an agent sandbox, it does not exist and must be authored locally.

### Container Benchmarks that do apply

These cover the substrate beneath the agent, not the agent itself. Both are directly relevant to the enforcement architectures in [`OPTIONS_ANALYSIS.md`](OPTIONS_ANALYSIS.md).

| Benchmark | Version | Relevance |
|---|---|---|
| CIS Docker Benchmark | 1.8.0 | Host configuration, daemon configuration, image and build files, container runtime, security operations. Maps onto R1 (isolation and runtime) and R10 (build and supply chain) |
| CIS Kubernetes Benchmark | 2.0.1 | Only relevant if the sandbox is ever hosted on Kubernetes. Variants exist for EKS, AKS, GKE Autopilot and OpenShift |

The Docker Benchmark's container runtime section is the closest published thing to a checklist for R1.3–R1.8 (non-root, dropped capabilities, no privileged mode, read-only root filesystem, no host Docker socket). Its recommendations should be reconciled against R1 once an option is selected.

### CIS Controls v8.1 Companion Guides

| Guide | Published | Scope |
|---|---|---|
| AI Agents Companion Guide | 2026-04-20 | Applies CIS Controls v8.1 to the agent layer — planning, reasoning, tool invocation, multi-step workflows. Stated to span identity, endpoint execution environments, knowledge stores, integration pipelines, and operational monitoring |
| AI and LLM Companion Guide | 2026-04-20 | Text-centric generative AI across the lifecycle — training, deployment, inference, monitoring, retirement. Addresses prompt injection and retrieval poisoning; emphasises prompt and guardrail change management, context boundary enforcement, model and dataset provenance, and containment of unexpected behaviour |
| **Model Context Protocol (MCP) Companion Guide** | 2026-04-20 | The MCP layer specifically — server and tool inventory, capability negotiation, transport security (stdio vs. Streamable HTTP), tool poisoning and rug-pull attack classes, OAuth token scoping, gateway-mediated deployment patterns. Carries an appendix of 21 MCP-specific CVEs |

**Status: extracted 2026-09-03.** All three guides were read in full and mapped Safeguard by Safeguard during the red-team run. The per-guide Safeguard tables live in the findings files rather than being duplicated here:

| Guide | Safeguards examined | Extracted mapping |
|---|---|---|
| AI Agents | 130 of 153 carry agent-specific text (23 marked "No Additional AI Agent Guidance") | [`cis-ai-agents-findings.md`](red-team/options-analysis-01/cis-ai-agents-findings.md) |
| AI and LLM | 134 carry AI-specific text; 47 in scope for a model-consuming, non-training deployment | [`cis-ai-llm-findings.md`](red-team/options-analysis-01/cis-ai-llm-findings.md) |
| MCP | 131 of 153 carry MCP-annotated text | [`cis-mcp-findings.md`](red-team/options-analysis-01/cis-mcp-findings.md) |

The guides are Safeguard mappings, not lintable baselines, so "compliance coverage" remains the wrong frame. What the extraction produced is a list of named controls the current design does not have — see [Gaps](#gaps).

## Five Eyes joint guidance on agentic AI

**Careful Adoption of Agentic AI Services**, published 2026-05-01. Authoring agencies: CISA, NSA, ASD's ACSC (Australia), CCCS (Canada), NCSC-NZ, and NCSC-UK. The first coordinated multinational security guidance addressing agentic AI specifically.

### Five risk categories

1. Privilege escalation
2. Design and configuration flaws
3. Behavioural misalignment
4. Structural cascading failures
5. Accountability opacity

### Correction — the previously recorded quotations were not from the primary text

The earlier revision of this document carried six block quotations attributed to the Five Eyes guidance, taken from CSA secondary analysis because the primary PDF returns 403 to automated retrieval. A local copy is now available at [`../references/careful_adoption_of_agentic_ai_services.md`](../references/careful_adoption_of_agentic_ai_services.md), and on 2026-09-03 those six were checked against it.

**Five of the six do not appear in the primary document.** The phrases `sandbox isolation`, `workload identity`, `reasoning traces` and `causal chain` return zero occurrences; `blast radius` and `supply chain risk` occur but not in the quoted wording. Only the identity quotation is genuine. The primary document is written as short "Recommended best practices" bullets, not the flowing prose the paraphrases implied.

This is recorded rather than quietly deleted because the substance mostly survives while the authority does not: CSA's characterisations are reasonable readings, but they were being cited here as the guidance's own words, and one of them — "sandbox isolation … should be treated as a required architectural control, not an optional hardening measure" — is a materially stronger claim than anything the primary text states.

### Key positions

All quotations below are verbatim from the local primary copy, with line numbers.

On isolation (L652–658). The guidance treats isolation as a recommendation for reducing cascading failure, not as a mandatory architectural control:

> "Deployment should consider integration requirements of AI agents and apply isolation where possible. This can reduce cascading issues should the agent behave unexpectedly or maliciously."

> "Implement isolation and segmentation to limit blast radius of agent failure scenarios" · "Separate high-risk agents into distinct domains" · "Isolate agents into enclaves with no write access to logs"

On identity (L457–458) — the one quotation that survived verification unchanged:

> "developers should construct each agent as a distinct principal, a cryptographically anchored identity with its own unique keys or certificates"

And the practices that follow it (L462–468):

> "Authenticate all inter-agent and agent-to-service API calls using mutual transport layer security to ensure non-repudiation" · "Maintain a trusted registry and bind identities to authorised roles" · "Deny access for any agent or cryptographic key that is not present in the trusted registry"

On credentials (L904–906):

> "Limit entitlements to the exact resources, operations and timeframes needed" · "Replace static, long-lived secrets with ephemeral credentials that expire when the job is complete"

On resilience and blast radius (L539–543). Note this is about containment and rollback, not the comparison to human accounts the earlier paraphrase asserted:

> "Embed agentic AI systems with fail-safe defaults and containment mechanisms that limit the blast radius of unexpected behaviours" · "Implement data loss prevention controls specifically tuned to AI agent behaviours" · "Implement versioning and rollback mechanisms to safely revert a system to known-good agent behaviours when unpredictability is observed"

On third-party components (L561–573). The primary text says nothing about MCP servers specifically — that specificity came from CSA:

> "Verify all external third-party components originate from trusted sources and are up to date before inclusion in agentic AI systems" · "Maintain a trusted registry of third-party components" · "Restrict tool use to an approved allow list of tools and versions that are regularly verified as secure" · "Establish trigger-action protocols that automatically restrict agent permissions when unexpected behaviour emerges"

On monitoring and logging (L676–688):

> "Monitor all agent operations, including internal processes, not just the inputs and outputs" · "Monitor agent outputs and behaviour for indicators of bias, emerging data drift and other anomalous patterns, including user prompts, tool calls, memory interactions, internal reasoning, decisions made and actions taken" · "Log agent tool usage and ensure results are captured in system logs in a human-readable format" (L570–571) · "Use multiple independent monitoring systems that cross-validate agent reports and system logs"

On human oversight (L723–724):

> "Insert human-in-the-loop review or approval checkpoints for actions where the cost of error is high, such as system resets, network egress or deletion of critical records"

On the overall posture (L839–840):

> "prioritising resilience, reversibility and risk containment over efficiency gains"

## Mapping to our requirements

Where published guidance corroborates decisions already recorded.

| Guidance position | Source | Our requirement |
|---|---|---|
| Sandbox isolation is a required architectural control | Five Eyes | R1.1, R1.2 |
| Enforcement must survive agent compromise | Five Eyes (blast radius) | R1.2, R1.5 |
| Each agent a distinct principal, scoped to specific resources | Five Eyes | R1.7, R6.3.2, R6.3.4 |
| Short-lived credentials, not static API keys | Five Eyes | R6.2.2, **R6.5 Model B** |
| Runtime access policy enforcement | Five Eyes | R5, R6.5.5 |
| Supply chain review covering MCP servers and plugins | Five Eyes | R7.13 (note only — see G4) |
| Container runtime hardening: non-root, dropped capabilities, no privileged mode, read-only root filesystem | CIS Docker Benchmark 1.8.0 | R1.3, R1.4, R1.5, R1.6, R1.8 |
| Image and build-file hygiene, pinned provenance | CIS Docker Benchmark 1.8.0 | R10.2, R10.4, R10.7 |
| Context boundary enforcement, containment of unexpected behaviour | CIS AI/LLM Companion Guide §16.10, §16.11 | R2, R5 — **not currently met by any option**, see G9 |
| Dataset provenance | CIS AI/LLM Companion Guide | Not applicable — we consume hosted models, we do not train |
| **Model version pinning, history retention and training opt-out** | CIS AI/LLM Companion Guide §4.1, §15.2 | **Applicable and unmet.** Previously recorded here as "not applicable"; that was wrong. §4.1 requires pinning for consumed model artifacts, warning that implicit upgrades "break existing guardrails". See G8 |
| Deterministic policy layer intercepting every agent action before execution | CIS AI Agents §16.10 | No requirement — see G9 |
| Record all tool calls with timestamps, identity, parameters and outcomes | CIS AI Agents §8.5, §8.8 | G1 |
| Provision unique agent identities; revoke on retirement | CIS AI Agents §6.1, §6.2 | G3 |
| Traffic filtering between agent runtimes to prevent lateral movement | CIS AI Agents §13.4, §12.5 | R1.7 — **overstated in `OPTIONS_ANALYSIS.md` before 2026-09-03**, now corrected |
| Runtime controls to pause, isolate or disable a misbehaving agent; kill switch | CIS AI Agents §13.7, CIS AI/LLM §17.9 | G6 |
| MCP server and tool inventory, version pinning, integrity verification | CIS MCP §1.1, §2.5 | G4 |
| Install only from approved registries; block direct-URL and community-registry installs | CIS MCP §2.5, §15 | G4 — the runtime channel, not just the inventory |
| Protect capability and configuration declarations from modification | CIS MCP §3.11, §4.6 | G4 — config integrity half |
| Third-party service provider assessment before integration | CIS AI Agents §15.5, §15.1 | G8 |
| Adversarial testing of sandbox and injection surfaces | CIS AI Agents §18.2, §18.5, CIS AI/LLM §18.2 | G7 |

The strongest corroboration is for R6.5 Model B (brokered short-lived credentials, no SSO token in the container). The Five Eyes position on static credentials (L904–906) points at the same conclusion reached independently from the AWS token-scope analysis.

One caution on that corroboration. Brokering satisfies "replace static, long-lived secrets" only if the broker knows *which* agent is calling. The Five Eyes identity section (L457–468) requires mTLS and a trusted registry precisely because a broker without caller authentication is a confused deputy. The red-team run found the `OPTIONS_ANALYSIS.md` brokering design had no caller identity, which would have made credential isolation worse than the per-volume separation it replaced. R6.5 Model B is corroborated; a naive implementation of it is not.

## Gaps

Places where published guidance asks for something `REQUIREMENTS.md` does not yet cover. Each carries a proposed requirement, not yet merged.

G1–G5 predate the 2026-09-03 red-team run and are sharpened below with what the primary texts actually say. G6–G9 are new, and come from the three CIS guides whose Safeguards were not extracted when this document was first written.

Numbering checked 2026-09-03: `REQUIREMENTS.md` defines R1–R12, so the R13, R14 and R15 blocks proposed by G6, G8 and G9 are free and do not collide with an existing requirement. G7's proposed R12.8 extends the existing R12.

### G1 — Agent action logging

R9 covers network egress only. Five Eyes L679–681 wants monitoring that includes "user prompts, tool calls, memory interactions, internal reasoning, decisions made and actions taken"; CIS AI Agents §8.5 wants "all tool calls, capturing timestamps, identity used, parameters passed, and outcomes"; CIS MCP §8.2 adds MCP initialization, capability negotiation and tool invocation. None of this is network traffic.

**Sharpened 2026-09-03.** This gap was contradicted by the very document it applies to: `OPTIONS_ANALYSIS.md` claimed a "Full, self-owned" audit trail and used it as one of four reasons to select Option 2, while this document recorded the same coverage as missing. The claim has been corrected to "destination-level"; the gap stands, and note that it cannot be closed before G3 — a log with no agent identity cannot attribute an action to an agent.

> **Proposed R9.7 (MUST):** Agent tool invocations, file modifications and privilege changes are recorded outside the agent's blast radius, in a form sufficient to reconstruct the sequence of actions taken during a session.
>
> **Proposed R9.8 (SHOULD):** Agent session transcripts are retained and correlatable with the egress log by session identifier and timestamp.

### G2 — Human authorization for high-impact actions

Assumption A2 explicitly presumes unattended operation with permission prompts bypassed — that is the reason the sandbox exists. The guidance recommends human authorization gates for high-impact actions. This is a genuine tension, not an oversight, and should be a recorded decision rather than an unexamined default.

> **Proposed R12.7 (SHOULD):** Actions classified as irreversible or high-impact require human authorization even in otherwise unattended operation. The classification is declared per use-case profile. Where a profile waives this, the waiver is explicit and recorded.

### G3 — Per-agent workload identity

We isolate per container and per volume, but no agent carries a distinct cryptographic identity with a defined lifecycle. Currently agents are distinguished by which credentials they hold, not by who they are.

**Sharpened 2026-09-03 — this is now a precondition, not an improvement.** The red-team run established that credential brokering without caller identity at the mediator hands every agent on the shared network every brokered credential, which is strictly worse than the per-volume separation it replaces. Five Eyes L462–463 requires mTLS for agent-to-service calls and L466 requires denying any identity absent from a trusted registry. CIS AI Agents §6.1 requires "persistent, unique identities for agents, using ephemeral credentials where possible". G3 must be satisfied before R6.5 Model B brokering is enabled, not after.

> **Proposed R8.8 (SHOULD):** Each agent instance is issued a distinct workload identity with a defined lifecycle, used for authentication to the enforcement point and recorded in the audit log, so actions are attributable to an agent rather than only to a container.

### G4 — MCP and plugin supply-chain inventory

R7.13 carries a prose note that MCP servers are subject to the same egress policy, but there is no requirement to inventory or review them. An MCP server is third-party executable code with network access running inside the sandbox.

> **Proposed R7.14 (MUST):** MCP servers, agent plugins and skills loaded into the sandbox are inventoried in the use-case profile, pinned to a version, and reviewed on the same basis as any other tool pack under R7.3.

**Sharpened 2026-09-03.** The dedicated MCP guide turns this from one proposed requirement into four distinct problems, only the first of which R7.14 addresses:

1. **Inventory** — as proposed. CIS MCP §1.1 adds that the inventory must record risk tier and a capability baseline snapshot, and "must detect capability drift, not just new hosts."
2. **Transport visibility.** CIS MCP L616–617 and Appendix A.1: a stdio MCP server is a subprocess of the agent, inside the sandbox, communicating over `stdin`/`stdout`. Its tool calls reach no network enforcement point under any of the three options. An inventory requirement has no enforcement point to live at unless one is built.
3. **The install channel.** CIS MCP §2.5 requires installing "only from enterprise approved registries", blocking direct URL and local source installs. A wholesale `*.npmjs.org` egress entry permits `npx <any-server>`, so the egress allowlist actively undermines the inventory.
4. **Configuration integrity.** CIS MCP §3.11 and §4.6 require protecting capability declarations from modification. Those declarations live on the agent-writable state volumes R4 mandates, so a compromised agent can add a server that survives restart.


### G5 — Long-lived refresh tokens in state volumes

R4 requires that agent authentication survive container restart, which in practice means persisting long-lived OAuth refresh tokens on a volume. The guidance prefers short-lived credentials over persistent secrets. R4.7 already treats these volumes as secret material, but the trade-off is not written down as a decision.

> **Proposed R4.12 (MUST):** The persistence of long-lived agent refresh tokens is recorded as an accepted risk, with its compensating controls named (R4.3 per-agent volumes, R4.7 secret handling, R8.5 revocation, R8.7 backup exclusion) and a stated review trigger should brokered agent credentials become available.

Note that G5 applies to the model-provider credentials only. The AWS path already resolves this correctly under R6.5 Model B.

### G6 — Containment and response

Every requirement is preventive or detective. Nothing describes what happens after a detection. The guidance treats rapid disablement as a named control, not as an operational afterthought.

CIS AI Agents §13.7: "Use runtime controls to pause, isolate, or disable agents exhibiting harmful behavior. Revoke credentials, restrict network access, and stop tool invocation pathways." CIS AI/LLM §17.9 requires "kill switches or rapid-disable mechanisms". CIS MCP §6.7 wants "a rapid kill switch to disable high-risk tools or servers during investigation" and Control 17 adds "a registry freeze as an explicit containment lever". Five Eyes L542–543 requires "versioning and rollback mechanisms to safely revert a system to known-good agent behaviours".

> **Proposed R13.1 (MUST):** For each credential type the design persists, a revocation procedure is documented and tested, with a stated maximum time from detection to revocation.
>
> **Proposed R13.2 (MUST):** A single agent can be isolated, and a single MCP server or tool disabled, without stopping the other agents.
>
> **Proposed R13.3 (SHOULD):** A documented path returns a contaminated environment to a known-good state, naming what happens to the persistent state volumes.

### G7 — Adversarial validation

`REQUIREMENTS.md` carries an acceptance test matrix (T1–T20, SC-1 to SC-3), but no requirement obliges the build sequence to run it before the sandbox is used, and the tests are coverage-oriented rather than adversarial. The red-team run found the deployment sequence in `OPTIONS_ANALYSIS.md` went capture → policy → build → defer, with no step that attempts to defeat the boundary.

CIS AI Agents §18.2: "Attempt code injection, environment breakout, and malicious script execution." CIS AI/LLM §18.4: penetration tests "should confirm that… injection attacks… generate appropriate telemetry and that incident response teams can act quickly." Five Eyes L529–530 and L739–740 require sandbox testing before production and regular assessment of an agent's ability to bypass safeguards.

> **Proposed R12.8 (MUST):** Before the sandbox is used for real work, the enforcement boundary is tested adversarially against at least: DNS exfiltration, network-isolation routability, post-resolution CIDR deny under CDN rotation, policy modification from inside a container, agent-to-agent reachability, and a repository seeded with injected instructions. Each test records whether the attempt was blocked, whether it appeared in the log, and whether it was attributable.

### G8 — Third-party and model-provider governance

Two distinct provider relationships are ungoverned. The tooling vendor (Docker Sandboxes) terminates TLS for all agent traffic under Option 1 and was assessed only for lock-in and portability. The three model providers are the substrate of the entire system and were treated only as network destinations to allowlist.

CIS AI Agents §15.5 requires security assessment "before integrating third-party services", specifically validating "the provider's runtime isolation capabilities". CIS AI/LLM §15.2 requires a "conservative default" posture — "disabling history retention, opting out of model training, pinning specific model versions" — and §4.1 warns that without version pinning, implicit upgrades "break existing guardrails". §15.6 requires monitoring providers for changes in "security posture, terms of service, or data handling practices".

> **Proposed R14.1 (MUST):** Before any third party is placed on the agent traffic path, record what it can observe, its stated retention period for that data, and its breach-notification path. Where the assessment cannot be completed, the resulting constraint on use is recorded.
>
> **Proposed R14.2 (SHOULD):** For each model provider, record the model version pinning capability (or its absence), the history-retention and training-opt-out setting in use, and the data classification permitted to leave.

### G9 — Application-layer controls between input and action

The largest gap the extraction produced, and the one that motivates the others. The design has no control that acts on hostile input, and none that mediates an agent *action* as opposed to a network packet. The sandbox bounds the consequence of a compromise and does nothing about the compromise itself.

CIS AI/LLM §16.10 requires "strict architectural separation between privileged system instructions and untrusted inputs or retrieved data" and that "the system must default to a 'deny' state". §16.11 requires "vetted, code-based safety frameworks… rather than relying solely on system prompts". CIS AI Agents §16.10 requires "a deterministic policy enforcement layer, or guardrail middleware, to intercept every agent action before execution", validating tool calls against static policy and blocking high-risk requests "regardless of the agent's intent", with circuit breakers that fail closed.

This is a genuine tension rather than an oversight, and it should be recorded as a decision. We consume three third-party agent products; their input-handling pipelines are not ours to instrument, and building a deterministic guardrail layer in front of three different agent harnesses is a substantially larger undertaking than the sandbox itself.

> **Proposed R15.1 — merge as a Non-Goal, not a requirement.** `REQUIREMENTS.md` already carries a Non-Goals section (it is where "exfiltration through allowlisted destinations is structurally impossible to prevent" lives), and that is the right shape for this: no component inspects or constrains agent inputs, and the architecture bounds the consequences of a successful injection rather than preventing one. A MUST that records an absence belongs with the other recorded absences.
>
> **Proposed R15.2 (SHOULD):** Where an enforcement point capable of mediating tool calls is available, prefer the option that can host one later over one that cannot. This one is a genuine requirement and survives as an R.

## Frameworks not evaluated

Listed so their absence is a recorded decision rather than an assumed gap. None has been reviewed for this project.

- OWASP Top 10 for LLM Applications, and the OWASP Agentic Security Initiative
- NIST AI Risk Management Framework and its Generative AI Profile
- MITRE ATLAS
- Cloud Security Alliance AI Controls Matrix
- ISO/IEC 42001

If a compliance obligation attaches to any of these, evaluate before the design document is finalised.

## Retrieval checklist

| Artifact | Status | Extract |
|---|---|---|
| CIS Controls v8.1 **AI Agents** Companion Guide | **Done 2026-09-03** | 130 in-scope Safeguards mapped — [`cis-ai-agents-findings.md`](red-team/options-analysis-01/cis-ai-agents-findings.md) |
| CIS Controls v8.1 **AI and LLM** Companion Guide | **Done 2026-09-03** | 47 in-scope Safeguards mapped — [`cis-ai-llm-findings.md`](red-team/options-analysis-01/cis-ai-llm-findings.md) |
| CIS Controls v8.1 **MCP** Companion Guide | **Done 2026-09-03** | 131 MCP-annotated Safeguards, 6 deployment patterns, 21 CVEs — [`cis-mcp-findings.md`](red-team/options-analysis-01/cis-mcp-findings.md) |
| Five Eyes **Careful Adoption of Agentic AI Services** | **Done 2026-09-03** | Local copy at [`../references/careful_adoption_of_agentic_ai_services.md`](../references/careful_adoption_of_agentic_ai_services.md). 173 items examined. Quotations re-verified — five of six failed, see [Correction](#correction--the-previously-recorded-quotations-were-not-from-the-primary-text) |
| CIS **Docker** Benchmark 1.8.0 | **Outstanding** | The Container Runtime section in full. Produce a per-recommendation applicability table against R1, marking each applicable / not applicable / compensating control. This is now the only unextracted artifact bearing on the current design |
| CIS **Kubernetes** Benchmark 2.0.1 | Out of scope | Only if a Kubernetes-hosted variant is pursued |

The G1–G9 proposed requirements should be merged into `REQUIREMENTS.md` rather than left as proposals here. That merge has not been done.

## Sources

| URL | Notes |
|---|---|
| <https://www.cisecurity.org/cis-benchmarks> | Benchmarks catalogue — confirms no AI/LLM/agentic entry |
| <https://www.cisecurity.org/benchmark/docker> | Docker Benchmark 1.8.0 |
| <https://www.cisecurity.org/benchmark/kubernetes> | Kubernetes Benchmark 2.0.1 and platform variants |
| <https://www.cisecurity.org/controls/v8-1> | CIS Controls v8.1, the framework both companion guides extend |
| <https://www.cisecurity.org/insights/white-papers/controls-v8-1-ai-agents-companion-guide> | AI Agents Companion Guide landing page |
| <https://www.cisecurity.org/insights/white-papers/controls-v8-1-ai-llm-companion-guide> | AI and LLM Companion Guide landing page |
| <https://learn.cisecurity.org/controls-v8-1-mcp-companion-guide> | **MCP Companion Guide download.** Verified 200 on 2026-09-03. The matching `cisecurity.org/insights/white-papers/…` landing page was not found — both inferred forms (`…-mcp-companion-guide` and `…-model-context-protocol-mcp-companion-guide`) return 404, so unlike the other two guides no landing page is recorded here |
| <https://learn.cisecurity.org/controls-v8-1-ai-agent-companion-guide> | AI Agents guide download |
| <https://learn.cisecurity.org/controls-v8-1-ai-llm-companion-guide> | AI and LLM guide download |
| <https://learn.cisecurity.org/benchmarks> | Benchmark downloads |
| <https://www.cisa.gov/resources-tools/resources/careful-adoption-agentic-ai-services> | Five Eyes guidance, resource page |
| <https://www.cisa.gov/news-events/news/cisa-us-and-international-partners-release-guide-secure-adoption-agentic-ai> | Release announcement, full authoring agency list |
| <https://media.defense.gov/2026/Apr/30/2003922823/-1/-1/0/CAREFUL%20ADOPTION%20OF%20AGENTIC%20AI%20SERVICES_FINAL.PDF> | Primary PDF — **bot-blocked**, returns 403 to automated requests |
| <https://labs.cloudsecurityalliance.org/research/csa-research-note-cisa-agentic-ai-adoption-guide-20260513-cs/> | CSA analysis. **Was** the source of the quoted control positions in this document; five of its six characterisations do not appear in the primary text and have been replaced. Useful as commentary, not as a quotation source |

The guidance is also published by ASD's ACSC on `cyber.gov.au`. That domain was unreachable at check time (HTTP/2 transport failure across the whole host), so no deep link is recorded here.
