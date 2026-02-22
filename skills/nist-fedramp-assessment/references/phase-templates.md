# Phase Output Templates

Output templates for each phase of the NIST SP 800-53 / FedRAMP Moderate compliance assessment. All output goes to `docs/compliance/`.

## Phase 1 — Architecture Discovery

**File:** `docs/compliance/phase1-discovery.md`

```markdown
# Phase 1: Architecture Discovery

**Project:** [repo name]
**Assessed:** YYYY-MM-DD
**Tech Stack:** [detected technologies]

## System Architecture

[Narrative description of the system derived from code and docs analysis]

### Components Identified

| Component | Type | Files | Security Relevance |
|---|---|---|---|
| [e.g., API Service] | ECS Service | lib/api/*.ts | Access Control, Audit |
| [e.g., CI/CD Pipeline] | CDK Pipeline | lib/pipeline/*.ts | Change Management, Access Control |

### AWS Services Detected

| Service | Usage | Configuration Source |
|---|---|---|
| [e.g., CloudTrail] | Audit logging | configs/*.yaml |

### Data Flows

[Describe how data moves through the system — API calls, data storage, pipeline stages, CUI data flows]

### Trust Boundaries

[Identify trust boundary crossings — cross-account, cross-network, external integrations, authorization boundary]

### Security-Relevant Findings

[List specific security configurations found in code: encryption settings, IAM policies, logging configs, FedRAMP Moderate relevant patterns]
```

## Phase 2 — Control Mapping

**File:** `docs/compliance/phase2-nist-mapping.md`

```markdown
# Phase 2: NIST SP 800-53 / FedRAMP Moderate Control Mapping

**Project:** [repo name]
**Assessed:** YYYY-MM-DD
**Profile:** FedRAMP Moderate Baseline
**Control Families:** AC, AU, CA, CM, CP, IA, IR, PL, RA, SA, SC, SI

## Posture Summary

| Status | Count | Percentage |
|---|---|---|
| Implemented | X | X% |
| Partially Implemented | X | X% |
| Not Implemented | X | X% |
| Not Applicable | X | X% |

## Inheritance Summary

| Category | Count |
|---|---|
| AWS FedRAMP Inherited | X |
| AWS FedRAMP Shared | X |
| Customer Implemented | X |
| Organization-Level | X |

## Control Family: AC — Access Control

### AC-2: Account Management

- **Status:** [Implemented / Partially Implemented / Not Implemented / Not Applicable]
- **Inheritance:** [AWS FedRAMP Inherited / AWS FedRAMP Shared / Customer Implemented / Organization-Level]
- **Evidence:**
  - [file:line — description of what it implements]
  - [Architecture pattern or configuration reference]
- **Notes:** [Caveats, assumptions, or dependencies]
- **FedRAMP ATO Note:** [Covered under AWS P-ATO / Customer-documented in SSP / Not applicable to authorization boundary]

[Repeat for each control in each family]
```

## Phase 3 — Gap Analysis

**File:** `docs/compliance/phase3-gap-analysis.md`

```markdown
# Phase 3: Gap Analysis — FedRAMP Moderate

**Project:** [repo name]
**Assessed:** YYYY-MM-DD

## Risk Summary

| Risk Rating | Count |
|---|---|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |

## Remediation Priority

[Ordered list of gaps by risk rating (Critical first), then by effort (Low effort first within same risk)]

### [Control ID]: [Control Name]

**Status:** Not Implemented / Partially Implemented
**Risk Rating:** Critical / High / Medium / Low
**Effort:** Low (< 1 day) / Medium (1-3 days) / High (3+ days)

**Gap Description:**
[What is missing and why it matters for FedRAMP Moderate compliance]

**Remediation Recommendation:**
[Specific, actionable guidance — reference AWS services, CDK constructs, or configuration changes]

**References:**
- [FedRAMP Moderate guidance link or NIST 800-53 control description]
- [AWS Well-Architected or Security Reference Architecture]
```

### Risk Rating Criteria

| Rating | Criteria |
|---|---|
| **Critical** | Direct exposure of CUI data, no compensating control, actively exploitable |
| **High** | Missing control with no compensating control, significant blast radius |
| **Medium** | Partially implemented or has compensating control but not fully compliant |
| **Low** | Missing enhancement or optimization, minimal security impact |

## Executive Summary

**File:** `docs/compliance/assessment-summary.md`

```markdown
# NIST SP 800-53 / FedRAMP Moderate Compliance Assessment Summary

**Project:** [repo name]
**Date:** YYYY-MM-DD
**Framework:** NIST SP 800-53 Rev 5 / FedRAMP Moderate
**Scope:** FedRAMP Moderate Baseline (12 core technical families)

## Compliance Posture

| Metric | Value |
|---|---|
| Total Controls Assessed | X |
| Implemented | X (X%) |
| Partially Implemented | X (X%) |
| Not Implemented | X (X%) |
| Not Applicable | X (X%) |

## Risk Dashboard

| Risk Rating | Gaps |
|---|---|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |

## Top Priority Remediations

[Top 5 gaps ordered by risk, with one-line summary and effort indicator]

## Inheritance Profile

| Category | Controls |
|---|---|
| AWS FedRAMP Inherited | X |
| AWS FedRAMP Shared (configured) | X |
| Customer Implemented | X |
| Organization-Level | X |

## Assessment Artifacts

| Document | Path |
|---|---|
| Architecture Discovery | docs/compliance/phase1-discovery.md |
| Control Mapping | docs/compliance/phase2-nist-mapping.md |
| Gap Analysis | docs/compliance/phase3-gap-analysis.md |
```
