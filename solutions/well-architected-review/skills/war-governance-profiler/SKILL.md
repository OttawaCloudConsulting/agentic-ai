---
name: war-governance-profiler
description: "Reads docs/TENANT_PROFILE.md and produces a WAR-specific governance baseline. Maps tenant-level controls (SCPs, guardrails, centralized services, compliance baselines) to the 6 AWS WAF pillars. Identifies inherited controls vs workload responsibilities. Uses AskUserQuestion to resolve gaps."
disable-model-invocation: true
---

# Governance Profiler — AWS Well-Architected Review

Read the target project's `docs/TENANT_PROFILE.md` and produce `GOVERNANCE_PROFILE.md` — a WAR-specific governance baseline that maps tenant-level controls to the 6 AWS Well-Architected Framework pillars. Downstream pillar reviewers use this profile to classify findings as "workload gap" vs "inherited from governance."

## Rules

- **Tenant profile is the source of truth.** Extract what is stated. Do not infer controls that are not documented.
- **Every control maps to at least one pillar.** If a control spans multiple pillars, list it under each.
- **Inherited means the workload does not need to implement it.** The org/account/OU already provides the control.
- **Workload-responsible means the workload must implement it.** The tenant does not provide it.
- **Ask, do not guess.** When the tenant profile is ambiguous or silent on a topic, use `AskUserQuestion` to resolve it. Batch related questions into a single round.
- **Cap gap resolution at 3 rounds.** If ambiguities remain after 3 rounds of questions, record them as unresolved items.
- **Write once at the end.** Accumulate the full profile, then write the output document.

## Pillars

Map controls to these 6 pillars (standard AWS WAF):

1. **Operational Excellence** — monitoring, logging, incident management, change management, runbooks
2. **Security** — IAM, encryption, network controls, detective controls, incident response, compliance
3. **Reliability** — fault tolerance, disaster recovery, backup, capacity planning, health checks
4. **Performance Efficiency** — compute selection, scaling, caching, network optimization
5. **Cost Optimization** — cost tracking, budgets, right-sizing, reserved capacity, waste elimination
6. **Sustainability** — resource efficiency, managed services, data lifecycle, geographic selection

## Step 1 — Read Tenant Profile

Read `docs/TENANT_PROFILE.md` from the target project. If the file does not exist, report the error and stop — this is a hard prerequisite.

Extract the following categories of information:

- **Governance framework:** Control Tower, Landing Zone Accelerator, custom landing zone, or none
- **Inheritable controls:** SCPs, guardrails, AWS Config rules, Security Hub standards at org/OU level
- **Centralized services:** CloudTrail, Config, GuardDuty, Security Hub, centralized logging, network firewall
- **Account structure:** Organization topology, OU placement, account vending
- **Network boundaries:** Transit Gateway, VPC patterns, DNS, egress controls
- **Compliance baselines:** Inherited compliance frameworks (e.g., CCCS Medium, SOC 2 org-level controls)
- **Shared resources:** Shared VPCs, central CAs, shared KMS keys, IAM Identity Center

For each item found, note the source (which section of the tenant profile) and confidence level (explicit statement vs reasonable inference).

## Step 2 — Map Controls to Pillars

For each extracted control, determine:

1. **Which pillar(s) it maps to** — a control like "org-wide CloudTrail" maps to both Operational Excellence (logging) and Security (audit trail)
2. **Whether it is inherited** — the tenant/org provides it and the workload benefits automatically
3. **What the workload still needs to do** — even inherited controls may have workload-level responsibilities (e.g., org CloudTrail exists but the workload must still configure application-level logging)

Build the control-to-pillar mapping as a table per pillar.

## Step 3 — Identify Gaps and Ambiguities

Review the mapping for:

- **Pillars with no inherited controls** — the workload is fully responsible. This is not necessarily a gap, but note it.
- **Ambiguous statements** — "we use Security Hub" without specifying which standards are enabled
- **Missing categories** — tenant profile does not mention network boundaries, compliance baselines, etc.
- **Contradictions** — e.g., "no centralized logging" but "CloudTrail is org-wide"

Collect these into a question set for gap resolution.

## Step 4 — Gap Resolution via AskUserQuestion

If gaps or ambiguities exist, use `AskUserQuestion` to resolve them. Structure questions clearly:

- State what the tenant profile says (or does not say)
- Ask the specific question
- Offer options where applicable (e.g., "Are you using the mandatory guardrails only, or also the strongly recommended set?")

Batch related questions into a single `AskUserQuestion` call. Maximum 3 rounds of questions. After each round, update the mapping with new information.

If no gaps exist (tenant profile is comprehensive and unambiguous), skip this step.

## Step 5 — Compile Workload Responsibilities

For each pillar, list the controls the workload must implement — everything NOT inherited from the tenant. Organize by pillar.

This section is the primary input for pillar reviewers: it tells them what to look for in the workload's code and documentation.

## Step 6 — Write GOVERNANCE_PROFILE.md

Write the output to the directory path provided by the orchestrator (default: `docs/well-architected-review/`). Ensure the directory exists before writing (create if needed).

Use this template:

```markdown
# Governance Profile

## Tenant Environment

[Summary paragraph: governance framework in use, account structure, OU placement. 3-5 sentences drawn from the tenant profile.]

## Inherited Controls by Pillar

### Operational Excellence

| Control | Source | Inherited? | Notes |
|---------|--------|:----------:|-------|
| [Control name] | [Where in tenant profile / what provides it] | Yes/Partial | [Workload-level caveats if any] |

### Security

| Control | Source | Inherited? | Notes |
|---------|--------|:----------:|-------|
| [Control name] | [Source] | Yes/Partial | [Notes] |

### Reliability

| Control | Source | Inherited? | Notes |
|---------|--------|:----------:|-------|
| [Control name] | [Source] | Yes/Partial | [Notes] |

### Performance Efficiency

| Control | Source | Inherited? | Notes |
|---------|--------|:----------:|-------|
| [Control name] | [Source] | Yes/Partial | [Notes] |

### Cost Optimization

| Control | Source | Inherited? | Notes |
|---------|--------|:----------:|-------|
| [Control name] | [Source] | Yes/Partial | [Notes] |

### Sustainability

| Control | Source | Inherited? | Notes |
|---------|--------|:----------:|-------|
| [Control name] | [Source] | Yes/Partial | [Notes] |

## Workload Responsibilities

### Operational Excellence

- [Responsibility 1: what the workload must implement and why it is not inherited]
- [Responsibility 2]

### Security

- [Responsibility 1]

### Reliability

- [Responsibility 1]

### Performance Efficiency

- [Responsibility 1]

### Cost Optimization

- [Responsibility 1]

### Sustainability

- [Responsibility 1]

## Unresolved Items

- [Question or ambiguity that could not be resolved from the tenant profile or user interview]
- [If none: "No unresolved items."]
```

After writing, confirm to the user that `GOVERNANCE_PROFILE.md` has been written and report:

- Number of inherited controls identified (total across all pillars)
- Number of workload responsibilities identified
- Number of unresolved items (if any)
