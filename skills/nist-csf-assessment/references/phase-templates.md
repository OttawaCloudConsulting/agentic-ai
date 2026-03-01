# Phase Output Templates

Output templates for each phase of the NIST CSF assessment. All output goes to `docs/compliance/`.

## Contents

- [Phase 1 — Architecture Discovery](#phase-1--architecture-discovery)
- [Phase 2 — CSF Subcategory Mapping](#phase-2--csf-subcategory-mapping)
- [Phase 3 — Gap Analysis](#phase-3--gap-analysis)
- [Risk Rating Criteria](#risk-rating-criteria)
- [Executive Summary](#executive-summary)

---

## Phase 1 — Architecture Discovery

**File:** `docs/compliance/phase1-discovery.md`

```markdown
# Phase 1: Architecture Discovery

**Project:** [repo name]
**Assessed:** YYYY-MM-DD
**CSF Version:** [from Phase 0, e.g., 2.0]
**Tech Stack:** [detected technologies]

## System Architecture

[Narrative description of the system derived from code and docs analysis]

### Components Identified

| Component | Type | Files | Security Relevance |
|---|---|---|---|
| [e.g., API Layer] | CDK Stack | lib/api/*.ts | Access Control, Data Security |
| [e.g., CI/CD Pipeline] | CDK Pipeline | lib/pipeline/*.ts | Platform Security, Governance |

### Cloud Services Detected

| Service | Usage | Configuration Source | CSF Functions |
|---|---|---|---|
| [e.g., CloudTrail / Azure Monitor / Cloud Audit Logs] | Audit logging | configs/*.yaml | DE (Detect), ID (Identify) |
| [e.g., GuardDuty / Defender for Cloud / Chronicle] | Threat detection | terraform/*.tf | DE (Detect) |

### Data Flows

[Describe how data moves through the system — deployments, API calls, pipeline stages]

### Trust Boundaries

[Identify trust boundary crossings — cross-account, cross-network, external integrations]

### Security-Relevant Findings

[List specific security configurations found in code: encryption settings, IAM policies, logging configs, monitoring setup, etc.]
```

## Phase 2 — CSF Subcategory Mapping

**File:** `docs/compliance/phase2-csf-mapping.md`

```markdown
# Phase 2: NIST CSF [version] Subcategory Mapping

**Project:** [repo name]
**Assessed:** YYYY-MM-DD
**CSF Version:** [e.g., 2.0]
**Functions Assessed:** GV, ID, PR, DE, RS, RC

## Posture Summary

| Function | Implemented | Partially Implemented | Not Implemented | Not Applicable |
|---|---|---|---|---|
| GV — Govern | X | X | X | X |
| ID — Identify | X | X | X | X |
| PR — Protect | X | X | X | X |
| DE — Detect | X | X | X | X |
| RS — Respond | X | X | X | X |
| RC — Recover | X | X | X | X |
| **Total** | **X** | **X** | **X** | **X** |

---

## GV — Govern

### GV.OC — Organizational Context

#### GV.OC-01

**Outcome:** The organizational mission is understood and informs cybersecurity risk management

- **Status:** [Implemented / Partially Implemented / Not Implemented / Not Applicable]
- **Platform Evidence:** [Cloud services contributing to this outcome, e.g., AWS Organizations / Azure Management Groups / GCP Resource Manager]
- **Customer Evidence:**
  - [file:line — description]
  - [configuration or documentation reference]
- **800-53 References:** PM-11, SA-2
- **Notes:** [Caveats, assumptions]

[Repeat for each subcategory in GV.OC, GV.RM, GV.RR, GV.PO, GV.OV, GV.SC]

---

## ID — Identify

### ID.AM — Asset Management

#### ID.AM-01

**Outcome:** Inventories of hardware managed by the organization are maintained

- **Status:** [Implemented / Partially Implemented / Not Implemented / Not Applicable]
- **Platform Evidence:** [e.g., AWS Config / Azure Resource Graph / GCP Asset Inventory — resource inventory and configuration history]
- **Customer Evidence:**
  - [file:line — description]
- **800-53 References:** CM-8, PM-5
- **Notes:** [Caveats, assumptions]

[Repeat for each subcategory in ID.AM, ID.RA, ID.IM]

---

## PR — Protect

### PR.AA — Identity Management, Authentication, and Access Control

#### PR.AA-01

**Outcome:** Identities and credentials for authorized users, services, and hardware are managed by the organization

- **Status:** [Implemented / Partially Implemented / Not Implemented / Not Applicable]
- **Platform Evidence:** [e.g., IAM Identity Center / Azure Entra ID / Google Cloud Identity — identity lifecycle management]
- **Customer Evidence:**
  - [file:line — description]
- **800-53 References:** AC-2, IA-2, IA-4, IA-5
- **Notes:** [Caveats, assumptions]

[Repeat for each subcategory in PR.AA, PR.AT, PR.DS, PR.PS, PR.IR]

---

## DE — Detect

### DE.CM — Continuous Monitoring

#### DE.CM-01

**Outcome:** Networks and network services are monitored to find potentially adverse events

- **Status:** [Implemented / Partially Implemented / Not Implemented / Not Applicable]
- **Platform Evidence:** [e.g., VPC Flow Logs / NSG Flow Logs / VPC Flow Logs, CloudWatch / Azure Monitor / Cloud Monitoring, Security Hub / Defender for Cloud / Security Command Center — network monitoring]
- **Customer Evidence:**
  - [file:line — description]
- **800-53 References:** AU-2, AU-12, CA-7, SI-4
- **Notes:** [Caveats, assumptions]

[Repeat for each subcategory in DE.CM, DE.AE]

---

## RS — Respond

### RS.MA — Incident Management

#### RS.MA-01

**Outcome:** The incident response plan is executed in coordination with relevant third parties once an incident is declared

- **Status:** [Implemented / Partially Implemented / Not Implemented / Not Applicable]
- **Platform Evidence:** [e.g., Systems Manager OpsCenter / Azure Sentinel / Chronicle SOAR — incident coordination]
- **Customer Evidence:**
  - [file:line — description]
- **800-53 References:** IR-4, IR-8
- **Notes:** [Caveats, assumptions]

[Repeat for each subcategory in RS.MA, RS.AN, RS.CO, RS.MI]

---

## RC — Recover

### RC.RP — Incident Recovery Plan Execution

#### RC.RP-01

**Outcome:** The recovery portion of the incident response plan is executed once initiated from the incident response process

- **Status:** [Implemented / Partially Implemented / Not Implemented / Not Applicable]
- **Platform Evidence:** [e.g., AWS Backup / Azure Backup / GCP Backup, CloudFormation / ARM Templates / Deployment Manager — infrastructure recovery]
- **Customer Evidence:**
  - [file:line — description]
- **800-53 References:** CP-10, IR-4
- **Notes:** [Caveats, assumptions]

[Repeat for each subcategory in RC.RP, RC.CO]
```

## Phase 3 — Gap Analysis

**File:** `docs/compliance/phase3-gap-analysis.md`

```markdown
# Phase 3: Gap Analysis — NIST CSF [version]

**Project:** [repo name]
**Assessed:** YYYY-MM-DD
**CSF Version:** [e.g., 2.0]

## Risk Summary

| Risk Rating | Count |
|---|---|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |

## Remediation Priority

[Ordered by risk rating (Critical first), then by effort (Low effort first within same risk)]

### [Subcategory ID]: [Subcategory short label]

**CSF Function:** [GV / ID / PR / DE / RS / RC]
**Status:** Not Implemented / Partially Implemented
**Risk Rating:** Critical / High / Medium / Low
**Effort:** Low (< 1 day) / Medium (1-3 days) / High (3+ days)

**Outcome:**
[The CSF subcategory outcome statement]

**Gap Description:**
[What is missing and why it matters for achieving this CSF outcome]

**Platform Remediation:**
[Specific cloud services or platform features that address this gap — adapt to the project's cloud provider]

**Remediation Recommendation:**
[Specific, actionable guidance — reference cloud services, IaC constructs, or configuration changes]

**800-53 References:**
[Informative references from the subcategory — useful if team is also pursuing a 800-53 / FedRAMP assessment]

**References:**
- [NIST CSF 2.0 subcategory link or NIST CSRC reference]
- [Cloud provider security service documentation]
```

### Risk Rating Criteria

| Rating | Criteria |
|---|---|
| **Critical** | Subcategory outcome entirely unaddressed, directly enables exploitation or data loss, no compensating control |
| **High** | Subcategory outcome not achieved, significant blast radius, no compensating control |
| **Medium** | Partially addressed or has compensating control but outcome not fully achieved |
| **Low** | Missing enhancement or optimization, minimal impact on security outcomes |

## Executive Summary

**File:** `docs/compliance/assessment-summary.md`

```markdown
# NIST CSF Assessment Summary

**Project:** [repo name]
**Date:** YYYY-MM-DD
**Framework:** NIST Cybersecurity Framework [version]
**Scope:** All 6 CSF Functions — GV, ID, PR, DE, RS, RC

## CSF Posture by Function

| Function | Implemented | Partially | Not Implemented | N/A | Posture |
|---|---|---|---|---|---|
| GV — Govern | X | X | X | X | [Strong / Moderate / Weak] |
| ID — Identify | X | X | X | X | [Strong / Moderate / Weak] |
| PR — Protect | X | X | X | X | [Strong / Moderate / Weak] |
| DE — Detect | X | X | X | X | [Strong / Moderate / Weak] |
| RS — Respond | X | X | X | X | [Strong / Moderate / Weak] |
| RC — Recover | X | X | X | X | [Strong / Moderate / Weak] |
| **Total** | **X** | **X** | **X** | **X** | |

## Risk Dashboard

| Risk Rating | Gaps |
|---|---|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |

## Function-Level Shared Responsibility Summary

| CSF Function | Platform Contribution | Customer Responsibility |
|---|---|---|
| GV — Govern | Low — governance is primarily customer | Policy, risk management, supply chain, oversight |
| ID — Identify | Medium — asset inventory via platform services; threat intel via security hub | Classification, risk assessment, improvement processes |
| PR — Protect | High — encryption, network controls, IAM via cloud services | Configuration, access management, awareness training |
| DE — Detect | High — audit logging, threat detection, flow logs, security dashboards | Alerting thresholds, SIEM integration, event analysis |
| RS — Respond | Low — response is primarily customer | IR plan, runbooks, communication, incident management |
| RC — Recover | Medium — backup/restore via platform services; IaC redeployment | RTO/RPO definition, DR testing, recovery communication |

## Top Priority Subcategory Gaps

[Top 5 gaps ordered by risk, with subcategory ID, one-line summary, and effort indicator]

1. [Subcategory ID] — [one-line description] — [Effort]
2. [Subcategory ID] — [one-line description] — [Effort]
3. [Subcategory ID] — [one-line description] — [Effort]
4. [Subcategory ID] — [one-line description] — [Effort]
5. [Subcategory ID] — [one-line description] — [Effort]

## Assessment Artifacts

| Document | Path |
|---|---|
| Architecture Discovery | docs/compliance/phase1-discovery.md |
| CSF Subcategory Mapping | docs/compliance/phase2-csf-mapping.md |
| Gap Analysis | docs/compliance/phase3-gap-analysis.md |
```
