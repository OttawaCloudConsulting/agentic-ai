---
name: war-discovery-interview
description: "Interactive interview to gather solution requirements for AWS Well-Architected Review. Conducts a structured interview covering business objectives, workload characteristics, compliance, performance, security, and cost. Produces DESIGN_REQUIREMENTS.md."
disable-model-invocation: true
---

# Discovery Interview — AWS Well-Architected Review

Conduct a structured interview to capture solution requirements and design intent that cannot be derived from code or documentation alone. Produces `DESIGN_REQUIREMENTS.md` as input for the discovery analyst agent.

## Rules

- **Structured, not open-ended.** Each round has specific questions. Do not free-form explore.
- **One round at a time.** Present 2-4 questions per round via `AskUserQuestion`. Wait for answers before proceeding.
- **Reference existing deliverables.** Read prior phase outputs first. Never ask about something already documented.
- **Respect "not applicable."** If the user says a domain does not apply, record that and move on.
- **No recommendations.** Capture requirements, do not evaluate them. Analysis belongs to the discovery analyst.
- **Write once at the end.** Accumulate answers across all rounds, then write the output document.

## Prerequisites

The orchestrator provides the output directory path. Expect these deliverables to exist from prior phases:

- `DOCUMENT_CATALOGUE.md` — Phase 1 output
- `CODE_CATALOGUE.md` — Phase 1 output
- `DOCUMENT_ARCHITECTURE_REVIEW.md` — Phase 2 output
- `CODE_ARCHITECTURE_REVIEW.md` — Phase 2 output

If any deliverable is missing, note its absence but proceed with the interview. The discovery analyst will flag the gap.

## Step 1 — Read Prior Deliverables

Read all 4 deliverables from the output directory. Extract:

- What the system does (from catalogues)
- Architectural patterns and technology choices (from reviews)
- Known gaps and concerns already identified (from review gap sections)

Use this context to skip questions the deliverables already answer and to ask sharper follow-up questions where the deliverables are silent or ambiguous.

## Step 2 — Business Objectives (Round 1)

Use `AskUserQuestion` to gather:

- What is the primary business objective this workload serves?
- Who are the end users and what are their expectations (availability, latency, geographic distribution)?
- What are the consequences of this workload being unavailable for 1 hour? 1 day?
- Are there regulatory or contractual SLAs that apply?

## Step 3 — Workload Characteristics (Round 2)

Use `AskUserQuestion` to gather:

- What is the expected traffic pattern? (steady, spiky, seasonal, event-driven)
- What is the expected scale? (requests/sec, data volume, concurrent users)
- What are the data retention requirements?
- Is this workload stateless or stateful? Where does state live?

## Step 4 — Compliance and Governance (Round 3)

Use `AskUserQuestion` to gather:

- Which compliance frameworks apply? (SOC 2, HIPAA, PCI-DSS, FedRAMP, GDPR, none, other)
- Are there data residency requirements? (specific AWS regions or countries)
- What is the data classification? (public, internal, confidential, restricted)
- Are there audit logging or evidence retention requirements?

## Step 5 — Security Assessment (Round 4)

Use `AskUserQuestion` to gather:

- How do end users authenticate? (Cognito, SAML/SSO, API keys, IAM, other)
- How are secrets and credentials managed? (Secrets Manager, Parameter Store, vault, environment variables)
- Are there network isolation requirements? (VPC, private subnets, VPN, PrivateLink)
- What is the encryption posture? (at-rest, in-transit, KMS managed keys, default)

## Step 6 — Performance Requirements (Round 5)

Use `AskUserQuestion` to gather:

- What are the latency targets for critical operations? (p50, p99, or general expectations)
- Are there batch processing or async workloads? What are their SLAs?
- What caching strategy is in place or planned?
- Are there known performance bottlenecks or concerns?

## Step 7 — Cost Analysis (Round 6)

Use `AskUserQuestion` to gather:

- Is there a monthly or annual budget target for this workload?
- What cost optimization strategies are in place? (reserved instances, savings plans, spot, right-sizing)
- Are there cost allocation or chargeback requirements? (tags, accounts, cost centers)
- Which cost dimensions matter most? (compute, storage, data transfer, third-party services)

## Step 8 — Write DESIGN_REQUIREMENTS.md

Compile all answers into a structured document. Write to the output directory path provided by the orchestrator.

```markdown
# Design Requirements

## Business Objectives

[Compiled from Round 1 answers. Include business objective, end user expectations, downtime impact, SLAs.]

## Workload Characteristics

[Compiled from Round 2 answers. Include traffic pattern, scale, data retention, state management.]

## Compliance and Governance

[Compiled from Round 3 answers. Include frameworks, data residency, classification, audit requirements.]

## Security Assessment

[Compiled from Round 4 answers. Include authentication, secrets management, network isolation, encryption.]

## Performance Requirements

[Compiled from Round 5 answers. Include latency targets, async workloads, caching, known bottlenecks.]

## Cost Analysis

[Compiled from Round 6 answers. Include budget, optimization strategies, allocation, key cost dimensions.]

## Context from Prior Phases

[Brief summary of what the catalogues and architecture reviews already established. Note any areas where interview answers confirm, contradict, or extend the documented architecture.]
```

Write the file, then confirm to the user that `DESIGN_REQUIREMENTS.md` has been written and the interview is complete.
