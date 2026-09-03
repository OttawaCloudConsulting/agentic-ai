# Standards and Guidance Mapping

Which published security standards apply to sandboxed agentic AI, what each one actually says, and how it maps onto [`../REQUIREMENTS.md`](../REQUIREMENTS.md).

**Date:** 2026-09-02. All URLs link-checked on that date.

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
| Does CIS publish agentic AI **guidance**? | **Yes** — two CIS Controls v8.1 Companion Guides, both dated 2026-04-20 |
| Are those guides prescriptive config baselines? | **No.** They are Safeguard mappings — "apply Control X through an AI-aware lens" — not lintable configuration lines |
| Which CIS Benchmarks apply to this project? | Docker (1.8.0) and Kubernetes (2.0.1), for the container substrate rather than the agent layer |
| Most actionable published guidance for this project? | The Five Eyes **Careful Adoption of Agentic AI Services** (2026-05-01) — not a CIS product |

The practical consequence: CIS gives us a governance vocabulary and a container hardening baseline, but nothing that tells us how to configure an agent sandbox. The Five Eyes guidance is where the architectural direction comes from, and it independently corroborates the design decisions already recorded in `REQUIREMENTS.md`.

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

**Status: control mappings not yet extracted.** The landing pages describe scope but do not expose which Safeguards are mapped or what each recommends. The specific Safeguard numbers and recommendations must be read from the source PDFs before this document can claim compliance coverage — see [Retrieval checklist](#retrieval-checklist). Everything stated above about these two guides comes from their public descriptions.

## Five Eyes joint guidance on agentic AI

**Careful Adoption of Agentic AI Services**, published 2026-05-01. Authoring agencies: CISA, NSA, ASD's ACSC (Australia), CCCS (Canada), NCSC-NZ, and NCSC-UK. The first coordinated multinational security guidance addressing agentic AI specifically.

### Five risk categories

1. Privilege escalation
2. Design and configuration flaws
3. Behavioural misalignment
4. Structural cascading failures
5. Accountability opacity

### Key positions

On isolation:

> "sandbox isolation for agent execution environments should be treated as a required architectural control, not an optional hardening measure"

On identity and credentials:

> "each agent should carry a verified, cryptographically secured identity — not a shared credential or a static API key but a workload identity with a defined lifecycle"

And on how that identity is provisioned:

> "each agent provisioned as a distinct principal carrying its own cryptographically anchored identity, scoped to specific resources, using short-lived credentials, and subject to runtime access policy enforcement"

On blast radius:

> "the potential blast radius of a privilege-compromised agent is substantially larger than that of a compromised human account, because agents may operate continuously, across multiple environments, and at machine speed"

On supply chain:

> "supply chain risk reviews should encompass all MCP servers, API plugins, and third-party model providers in the agent stack"

On logging:

> "capture internal reasoning traces, tool call sequences, privilege changes, and goal drift indicators"

Logs must let an analyst "reconstruct the causal chain of an agent's decisions." Human authorization controls are recommended for high-impact actions to limit irreversible consequences.

**Note on provenance.** The quotations above are as reported by secondary analysis of the guidance; the primary PDF on `media.defense.gov` returns 403 to automated requests. They should be re-verified against the primary document — see [Retrieval checklist](#retrieval-checklist).

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
| Context boundary enforcement, containment of unexpected behaviour | CIS AI/LLM Companion Guide | R2, R5 |
| Model and dataset provenance | CIS AI/LLM Companion Guide | Not applicable — we consume hosted models, we do not train |

The strongest corroboration is for R6.5 Model B (brokered short-lived credentials, no SSO token in the container). The Five Eyes position on static credentials and workload identity lifecycle points at the same conclusion reached independently from the AWS token-scope analysis.

## Gaps

Five places where published guidance asks for something `REQUIREMENTS.md` does not yet cover. Each carries a proposed requirement, not yet merged.

### G1 — Agent action logging

R9 covers network egress only. The guidance wants tool-call sequences, privilege changes and goal-drift indicators, sufficient to reconstruct the causal chain of an agent's decisions.

> **Proposed R9.7 (MUST):** Agent tool invocations, file modifications and privilege changes are recorded outside the agent's blast radius, in a form sufficient to reconstruct the sequence of actions taken during a session.
>
> **Proposed R9.8 (SHOULD):** Agent session transcripts are retained and correlatable with the egress log by session identifier and timestamp.

### G2 — Human authorization for high-impact actions

Assumption A2 explicitly presumes unattended operation with permission prompts bypassed — that is the reason the sandbox exists. The guidance recommends human authorization gates for high-impact actions. This is a genuine tension, not an oversight, and should be a recorded decision rather than an unexamined default.

> **Proposed R12.7 (SHOULD):** Actions classified as irreversible or high-impact require human authorization even in otherwise unattended operation. The classification is declared per use-case profile. Where a profile waives this, the waiver is explicit and recorded.

### G3 — Per-agent workload identity

We isolate per container and per volume, but no agent carries a distinct cryptographic identity with a defined lifecycle. Currently agents are distinguished by which credentials they hold, not by who they are.

> **Proposed R8.8 (SHOULD):** Each agent instance is issued a distinct workload identity with a defined lifecycle, used for authentication to the enforcement point and recorded in the audit log, so actions are attributable to an agent rather than only to a container.

### G4 — MCP and plugin supply-chain inventory

R7.13 carries a prose note that MCP servers are subject to the same egress policy, but there is no requirement to inventory or review them. An MCP server is third-party executable code with network access running inside the sandbox.

> **Proposed R7.14 (MUST):** MCP servers, agent plugins and skills loaded into the sandbox are inventoried in the use-case profile, pinned to a version, and reviewed on the same basis as any other tool pack under R7.3.

### G5 — Long-lived refresh tokens in state volumes

R4 requires that agent authentication survive container restart, which in practice means persisting long-lived OAuth refresh tokens on a volume. The guidance prefers short-lived credentials over persistent secrets. R4.7 already treats these volumes as secret material, but the trade-off is not written down as a decision.

> **Proposed R4.12 (MUST):** The persistence of long-lived agent refresh tokens is recorded as an accepted risk, with its compensating controls named (R4.3 per-agent volumes, R4.7 secret handling, R8.5 revocation, R8.7 backup exclusion) and a stated review trigger should brokered agent credentials become available.

Note that G5 applies to the model-provider credentials only. The AWS path already resolves this correctly under R6.5 Model B.

## Frameworks not evaluated

Listed so their absence is a recorded decision rather than an assumed gap. None has been reviewed for this project.

- OWASP Top 10 for LLM Applications, and the OWASP Agentic Security Initiative
- NIST AI Risk Management Framework and its Generative AI Profile
- MITRE ATLAS
- Cloud Security Alliance AI Controls Matrix
- ISO/IEC 42001

If a compliance obligation attaches to any of these, evaluate before the design document is finalised.

## Retrieval checklist

Artifacts whose contents are not yet extracted, and what to take from each. Until these are read, this document reflects public descriptions and secondary analysis only.

| Artifact | Extract |
|---|---|
| CIS Controls v8.1 **AI Agents** Companion Guide | The Safeguard-by-Safeguard mapping. Specifically what it says on agent identity, execution environment isolation, tool invocation control, and monitoring. Reconcile against R1, R7, R8, R9 |
| CIS Controls v8.1 **AI and LLM** Companion Guide | Its treatment of prompt injection, retrieval poisoning, context boundary enforcement, and containment. Reconcile against R2 and R5 |
| CIS **Docker** Benchmark 1.8.0 | The Container Runtime section in full. Produce a per-recommendation applicability table against R1, marking each applicable / not applicable / compensating control |
| CIS **Kubernetes** Benchmark 2.0.1 | Only if a Kubernetes-hosted variant is pursued. Otherwise mark out of scope |
| Five Eyes **Careful Adoption of Agentic AI Services** (primary PDF) | Re-verify the quotations in this document against the primary source, and extract the full mitigation list per risk category. The primary PDF returns 403 to automated retrieval |

Once extracted, the mapping and gap sections above should be revised against the primary text, and any resulting requirements merged into `REQUIREMENTS.md` rather than left as proposals here.

## Sources

| URL | Notes |
|---|---|
| <https://www.cisecurity.org/cis-benchmarks> | Benchmarks catalogue — confirms no AI/LLM/agentic entry |
| <https://www.cisecurity.org/benchmark/docker> | Docker Benchmark 1.8.0 |
| <https://www.cisecurity.org/benchmark/kubernetes> | Kubernetes Benchmark 2.0.1 and platform variants |
| <https://www.cisecurity.org/controls/v8-1> | CIS Controls v8.1, the framework both companion guides extend |
| <https://www.cisecurity.org/insights/white-papers/controls-v8-1-ai-agents-companion-guide> | AI Agents Companion Guide landing page |
| <https://www.cisecurity.org/insights/white-papers/controls-v8-1-ai-llm-companion-guide> | AI and LLM Companion Guide landing page |
| <https://learn.cisecurity.org/controls-v8-1-ai-agent-companion-guide> | AI Agents guide download |
| <https://learn.cisecurity.org/controls-v8-1-ai-llm-companion-guide> | AI and LLM guide download |
| <https://learn.cisecurity.org/benchmarks> | Benchmark downloads |
| <https://www.cisa.gov/resources-tools/resources/careful-adoption-agentic-ai-services> | Five Eyes guidance, resource page |
| <https://www.cisa.gov/news-events/news/cisa-us-and-international-partners-release-guide-secure-adoption-agentic-ai> | Release announcement, full authoring agency list |
| <https://media.defense.gov/2026/Apr/30/2003922823/-1/-1/0/CAREFUL%20ADOPTION%20OF%20AGENTIC%20AI%20SERVICES_FINAL.PDF> | Primary PDF — **bot-blocked**, returns 403 to automated requests |
| <https://labs.cloudsecurityalliance.org/research/csa-research-note-cisa-agentic-ai-adoption-guide-20260513-cs/> | CSA analysis — source of the quoted technical control positions |

The guidance is also published by ASD's ACSC on `cyber.gov.au`. That domain was unreachable at check time (HTTP/2 transport failure across the whole host), so no deep link is recorded here.
