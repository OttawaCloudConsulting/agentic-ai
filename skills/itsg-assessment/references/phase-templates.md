# Phase Output Templates

Output templates for each phase of the ITSG-33 compliance assessment. All output goes to `docs/compliance/`.

## Phase 1 — Architecture Discovery

**File:** `docs/compliance/phase1-discovery.md`

```markdown
# Phase 1: Architecture Discovery

**Project:** [system name]
**Assessed:** YYYY-MM-DD
**Scope:** [paths and docs assessed; how scope was determined]
**Tech Stack:** [detected technologies]

## System Architecture

[Narrative description of the system derived from code and docs analysis]

### Component Inventory

| Component | Class | Location | Language / Runtime | Deployed By | Source In Scope |
|---|---|---|---|---|---|
| [e.g., api-service] | Application | apps/api/ | Node.js 22 / Express | live/api/ (ECS) | Yes |
| [e.g., network] | Infrastructure | live/network/ | Terraform | Pipeline | Yes |
| [e.g., vendor-server] | Application | image registry.example/vendor:5.1 | Java | live/vendor/ (ECS) | No — config and docs only |

### Application Security Surfaces

One table per application component. Mark absent surfaces "None" — they drive Not Applicable decisions in Phase 2.

#### [Component]

| Surface | Finding | Evidence | Provenance |
|---|---|---|---|
| Entry points | [e.g., REST API on :8443, externally reachable via ALB] | src/server.ts:40 | code |
| Authentication | [e.g., OIDC via Cognito; no local passwords] | src/auth/oidc.ts:12 | code |
| Authorization | | | |
| Sessions | | | |
| Input handling | | | |
| Data | | | |
| Cryptography and secrets | | | |
| Outbound integrations | | | |
| Logging and audit | | | |
| Error handling | | | |
| Supply chain | | | |

### Doc / Code Discrepancies

[Components or behaviours described in docs but not found in code, or contradicted by code]

### AWS Services Detected

| Service | Usage | Configuration Source | Region |
|---|---|---|---|
| [e.g., Route53] | DNS hosting | configs/*.yaml | ca-central-1 |

### Data Residency

| Resource | Region | Protected B Eligible | Notes |
|---|---|---|---|
| [e.g., S3 bucket] | ca-central-1 | Yes | GC data residency requirement met |

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

**Project:** [system name]
**Assessed:** YYYY-MM-DD
**Control Pool:** [CCCS Medium Cloud Profile, N controls | supplied list: path, N controls]
**Jurisdiction:** Canadian GC — Protected B data classification
**Data Residency:** ca-central-1 (default); flag any resources outside Canadian AWS regions

## Applicability Summary

| Applicability | Count |
|---|---|
| Applicable | X |
| Organizational | X |
| Not Applicable | X |
| Outside CCCS Medium profile (supplied list only) | X |

## Posture Summary

Counts cover Applicable controls. A control assessed against several components takes its weakest component status.

| Status | Count | Percentage |
|---|---|---|
| Implemented | X | X% |
| Partially Implemented | X | X% |
| Not Implemented | X | X% |

## Inheritance Summary

| Category | Count |
|---|---|
| AWS Inherited | X |
| AWS Shared | X |
| Customer Implemented | X |
| GC Org-level | X |

## Controls Requiring System-Owner Input

Questionnaire responses ingested: [YYYY-MM-DD — X answered, X partial, X unanswered / not yet ingested]

| Control | Question | Response |
|---|---|---|
| AC-2 | [Specific record, policy or role the system owner must provide] | [answered / partial / unanswered — from `questionnaire.py ingest`] |

## Control Family: AC — Access Control

### AC-12: Session Termination

- **Applies to:** [component, component]
- **Inheritance:** [AWS Inherited / Shared / Customer / GC Org-level]

| Component | Status | Evidence | Provenance |
|---|---|---|---|
| [api-service] | [Implemented / Partially / Not Implemented] | [file:line — what it implements] | [code / config / documented / attested] |

- **Notes:** [Caveats, assumptions, or dependencies]
- **Pending system-owner input:** [Only when the control's Response is partial or unanswered: what is still awaited, and questionnaire/{Family}-questionnaire.md]

[Repeat for each Applicable control in each family]

### Not Applicable and Organizational — AC

| Control | Title | Decision | Reason |
|---|---|---|---|
| AC-18 | Wireless Access | Not Applicable | No component operates wireless networks |
| AC-1 | Access Control Policy and Procedures | Organizational | Policy obligation; not evidenced in code |

[Repeat per family]
```

## Phase 3 — Gap Analysis

**File:** `docs/compliance/phase3-gap-analysis.md`

```markdown
# Phase 3: Gap Analysis — ITSG-33 / CCCS Medium

**Project:** [repo name]
**Assessed:** YYYY-MM-DD

## Risk Summary

Counts exclude open items awaiting system-owner input.

| Risk Rating | Count |
|---|---|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |

## Open Items — Awaiting System-Owner Input

Controls whose remaining gap depends only on a partial or unanswered questionnaire response. Not risk-rated until the response arrives. A control that also has a gap shown by code or config stays in Remediation Priority, with the pending item named in its Gap Description.

| Control | Component | Current Status | Awaiting | Questionnaire |
|---|---|---|---|---|
| [ID] | [component] | [Partially Implemented / Not Implemented] | [record, policy or role still needed] | questionnaire/{Family}-questionnaire.md |

## Remediation Priority

[Ordered list of gaps by risk rating (Critical first), then by effort (Low effort first within same risk)]

### [Control ID]: [Control Name]

**Component:** [affected component(s)]
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
**Scope:** [components assessed]
**Control Pool:** [source, N controls]

## Compliance Posture

| Metric | Value |
|---|---|
| Controls in Pool | X |
| Applicable | X |
| Organizational | X |
| Implemented | X (X%) |
| Partially Implemented | X (X%) |
| Not Implemented | X (X%) |
| Not Applicable | X (X%) |
| Pending System-Owner Input | X (of X questionnaire entries; X answered, X partial) |

## Risk Dashboard

Gaps exclude open items awaiting system-owner input.

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
| System-Owner Questionnaires | docs/compliance/questionnaire/ |
```

## Phase 4 — Evidence Document

**File:** `docs/compliance/package/documents/{Family}/{Family}-{ControlId}[-{Enhancement}]-{Title_with_underscores}.md`, e.g. `AC/AC-2-1-Account_Management_Automated_System_Account_Management.md`

`scripts/evidence_docs.py scaffold` generates this structure; the model fills only the Evidential Response, References and Dictionary.

```markdown
# {Family}-{ControlId}-{Enhancement} - Title

Family: {Family}
Solution: {System name from Phase 1}
Date: {Date of last change, updated with each write/edit}
Status: {NOT-STARTED | DRAFT | APPROVED}

## Definition:

{Text and Bullet Points from Control, identical to source}

### Guidance

{Text and Bullet Points from Supplemental Guidance, identical to source}

## Evidential Response

### Description

{Narrative and rationale as to why the evidence below satisfies the above requirements}

### Artifacts

| Control Requirement | Response |
| --- | --- |
| **{Control Requirement Text}** | Evidential Proof, embedded image, code/content block, etc. |

### References

{URLS to external documentation and/or evidence}

## Dictionary of Definitions

{Section that provides explanation of Acronyms and Domain Specific terms for the reader/assessor}
```

### Artifacts Row Examples

| Control Requirement | Response |
| --- | --- |
| **(A) The information system automatically terminates a user session after a maximum of 24 hours of inactivity or upon request by the user.** | `code` — `apps/api/src/auth/session.ts:42` sets `absoluteTimeout: 8h`, `idleTimeout: 30m`; logout revokes the refresh token (`session.ts:88`). |
| **(B) The organization assigns account managers for information system accounts.** | Evidence: account manager assignments are held by the system owner, not in code. Request the current account-manager register from the GUARD system owner, or the Entra ID group ownership export (Entra admin centre > Groups > Owners). |
| **(A) The information system enforces approved authorizations for logical access.** | `config` — ALB listener rule requires Cognito authentication; excerpt: [`AC-3-alb-listener.json`](../../evidence/AC/AC-3-alb-listener.json) (`aws elbv2 describe-rules`, 2026-09-22, account 123456789012, ReadOnly). |

## System Owner Questionnaire

**Files:** `docs/compliance/questionnaire/{Family}-questionnaire.md` (one per family)

Generated by `scripts/questionnaire.py generate` after Phase 2 control mapping. Gathers organizational context, policies, and procedural evidence that cannot be derived from code or configuration alone.

```markdown
# ITSG-33 System Owner Questionnaire — {Family Full Title}

**Control Family:** {Family}
**Project:** {system name}
**Date:** {YYYY-MM-DD}

This questionnaire gathers organizational context, policies, and procedural evidence for the {Family Full Title} control family that cannot be derived from code or configuration alone.
Responses will complete the Phase 2 control mapping and inform the Phase 3 gap analysis.

Please provide specific, verifiable answers where possible.
Reference organizational policies, procedures, records, or responsible roles by name.
If evidence does not exist, state "Not implemented" rather than leaving blank.

---

## Background

{Introductory paragraph explaining what this family's questions establish and why organizational input is needed}

---

**Control ID:** {control-id}
**Description:** {control title from catalogue}
Question: {question from phase2-control-mapping.md}
**Response:**




---

**Control ID:** {control-id}
**Description:** {control title from catalogue}
Question: {question from phase2-control-mapping.md}
**Response:**




---

[Repeat for each control in this family]

---

## Submission

Return completed questionnaire to the assessment team.
Responses inform the Phase 2 control-mapping status and Phase 3 gap analysis.
```

**Directory structure after generation:**
```
docs/compliance/questionnaire/
├── AC-questionnaire.md
├── AU-questionnaire.md
├── CM-questionnaire.md
├── CP-questionnaire.md
├── IA-questionnaire.md
├── IR-questionnaire.md
└── ... (one file per family with controls requiring input)
```

### Questionnaire Generation Steps

`scripts/questionnaire.py generate` writes everything above except the Background paragraph: it reads the Control and Question columns of the "Controls Requiring System-Owner Input" table, looks up each title in `assets/cccs-medium-controls.json`, groups by family prefix, and writes one file per family. New files carry `<!-- PENDING -->` under Background; replace it with the family introductory paragraph below.

An existing file is never rewritten, so collected responses survive a re-run. New controls are appended before Submission; controls dropped from the mapping are reported and left in place. Don't hand-edit entries the script owns (Control ID, Description) or a system owner's response.

`scripts/questionnaire.py ingest` parses responses back. An entry is `answered` (non-empty response), `partial` (response contains a `<placeholder>` such as `<define procedure>`), or `unanswered` (empty). Bold and plain labels (`**Control ID:**` / `Control ID:`) both parse, since respondents often edit the formatting.

### Family Introductory Paragraph

Write one paragraph per family, replacing `<!-- PENDING -->`, from that family's own questions: the topics they cover, and what the responses confirm about organizational practice beyond what the code shows.

Example (AC): "The following questions establish account management procedures, session controls and access restrictions. Your responses confirm whether organizational policies and manual procedures exist to supplement the technical controls observed in code."
