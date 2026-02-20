# Phase Output Templates

Output templates for each phase of the ITSG-33 compliance assessment. All output goes to `docs/compliance/`.

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
| [e.g., DNS Infrastructure] | CDK Stack | lib/application/*.ts | Network, Access Control |
| [e.g., CI/CD Pipeline] | CDK Pipeline | lib/pipeline/*.ts | Change Management, Access Control |

### AWS Services Detected

| Service | Usage | Configuration Source |
|---|---|---|
| [e.g., Route53] | DNS hosting | configs/*.yaml |

### Data Flows

[Describe how data moves through the system — deployments, DNS resolution, pipeline stages]

### Trust Boundaries

[Identify trust boundary crossings — cross-account, cross-network, external integrations]

### Security-Relevant Findings

[List specific security configurations found in code: encryption settings, IAM policies, logging configs, etc.]
```

## Phase 2 — Control Mapping

**File:** `docs/compliance/phase2-control-mapping.md`

```markdown
# Phase 2: ITSG-33 Control Mapping (CCCS Medium Profile)

**Project:** [repo name]
**Assessed:** YYYY-MM-DD
**Profile:** CCCS Medium Cloud — Technical Controls
**Control Families:** AC, AU, CM, CP, IA, SA, SC, SI

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
| AWS Inherited | X |
| AWS Shared | X |
| Customer Implemented | X |
| GC Org-level | X |

## Control Family: AC — Access Control

### AC-2: Account Management

- **Status:** [Implemented / Partially / Not Implemented / N/A]
- **Inheritance:** [AWS Inherited / Shared / Customer / GC Org-level]
- **Evidence:**
  - [file:line — description of what it implements]
  - [Architecture pattern or configuration reference]
- **Notes:** [Caveats, assumptions, or dependencies]

[Repeat for each control in each family]
```

## Phase 3 — Gap Analysis

**File:** `docs/compliance/phase3-gap-analysis.md`

```markdown
# Phase 3: Gap Analysis — ITSG-33 / CCCS Medium

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
[What is missing and why it matters for CCCS Medium compliance]

**Remediation Recommendation:**
[Specific, actionable guidance — reference AWS services, CDK constructs, or configuration changes]

**References:**
- [CCCS guidance link or ITSG-33 control description]
- [AWS Well-Architected or Security Reference Architecture]
```

### Risk Rating Criteria

| Rating | Criteria |
|---|---|
| **Critical** | Direct exposure of Protected B data, no compensating control, actively exploitable |
| **High** | Missing control with no compensating control, significant blast radius |
| **Medium** | Partially implemented or has compensating control but not fully compliant |
| **Low** | Missing enhancement or optimization, minimal security impact |

## Executive Summary

**File:** `docs/compliance/assessment-summary.md`

```markdown
# ITSG-33 Compliance Assessment Summary

**Project:** [repo name]
**Date:** YYYY-MM-DD
**Framework:** ITSG-33 / CCCS Medium Cloud Profile
**Scope:** Technical Controls (AC, AU, CM, CP, IA, SA, SC, SI)

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
| AWS Inherited | X |
| AWS Shared (configured) | X |
| Customer Implemented | X |
| GC Organization-Level | X |

## Assessment Artifacts

| Document | Path |
|---|---|
| Architecture Discovery | docs/compliance/phase1-discovery.md |
| Control Mapping | docs/compliance/phase2-control-mapping.md |
| Gap Analysis | docs/compliance/phase3-gap-analysis.md |
```
