---
name: compliance-assess
description: Map project architecture to ITSG-33 / CCCS Medium Cloud Profile security controls. Produces a phased compliance assessment with control inheritance and risk-rated gap analysis.
---

# /compliance-assess — ITSG-33 / CCCS Medium Compliance Assessment

Map a project's architecture and codebase to Canadian ITSG-33 security controls (CCCS Medium Cloud Profile). Produces a phased assessment with AWS shared responsibility inheritance, gap analysis, and risk-rated remediation guidance.

## Output Location

All output goes to `docs/compliance/`. Create the directory if it doesn't exist.

| File | Purpose |
|---|---|
| `docs/compliance/phase1-discovery.md` | Architecture discovery results |
| `docs/compliance/phase2-control-mapping.md` | ITSG-33 control mapping with inheritance |
| `docs/compliance/phase3-gap-analysis.md` | Gap analysis with risk-rated remediation |
| `docs/compliance/assessment-summary.md` | Executive summary with posture dashboard |

## Smart Re-run

Before starting any phase, check if previous phase outputs exist in `docs/compliance/`. If they do:

1. Read the existing phase output
2. Compare the project's current state (file modification times, git diff since last assessment) against what was analyzed
3. If significant changes are detected, re-run that phase
4. If no changes, report "Phase N output is current — skipping" and proceed to next phase
5. Always ask the user: "Previous assessment found. Re-run from scratch or smart re-run (only changed phases)?"

---

## Phase 0 — Framework Validation (Self-Correcting)

**This phase runs FIRST, before any assessment work.** It validates that the control data embedded in this skill file matches the current official sources. If differences are found, update this skill file before proceeding.

### Step 0.1 — Fetch ITSG-33 Control Catalogue

Fetch the ITSG-33 Annex 3A page to verify the control families and IDs:

1. Fetch `https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33`
2. Compare the control IDs and names listed in the **Phase 2 control family tables** of this file against the official catalogue

**What to check:**
- Every control ID in this file exists in ITSG-33 Annex 3A
- Control names match (e.g., AC-2 is "Account Management", not something else)
- No fabricated control IDs

### Step 0.2 — Self-Mutate If Needed

If **any** differences are found in Step 0.1:

1. **Read this skill file** using the Read tool (path: the `.claude/commands/compliance-assess.md` file in the project root)
2. **Apply corrections** using the Edit tool:
   - Update the control family tables in Phase 2 (control IDs, names)
3. **Report changes** to the user in a summary table:

```
Framework Validation Results:
| Item | Status | Change |
|---|---|---|
| AC-7 description | OK / UPDATED | was "...", now "..." |
| ... | ... | ... |
```

If **no differences** are found:

- Report: "Phase 0 complete — all controls match official sources. No skill file updates needed."

### Step 0.3 — Proceed

After validation (and any self-mutations), proceed to Smart Re-run check, then Phase 1.

---

## Phase 1 — Architecture Discovery

### Step 1.1 — Detect Tech Stack

Scan the project root for technology indicators:

| Indicator | Detection |
|---|---|
| **Language** | `package.json` (Node/TS), `requirements.txt`/`pyproject.toml` (Python), `go.mod` (Go), `Cargo.toml` (Rust), `pom.xml`/`build.gradle` (Java) |
| **IaC** | `cdk.json` (AWS CDK), `*.tf` (Terraform), `*.tf` with `required_providers` opentofu block (OpenTofu), `template.yaml`/`template.json` (CloudFormation/SAM), Crossplane `*.yaml` with `apiVersion: *.crossplane.io/*` or `apiVersion: *.upbound.io/*` (Crossplane/Upbound), `serverless.yml` (Serverless Framework) |
| **Containers** | `Dockerfile`, `docker-compose.yml`, `*.Containerfile` |
| **CI/CD** | `.github/workflows/`, `buildspec.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `pipeline` in CDK code |
| **Config** | `*.yaml`, `*.json`, `*.toml`, `*.env*` config files |

### Step 1.2 — Analyze Codebase

Scan the codebase for security-relevant patterns across all supported IaC tools:

**General security patterns (all IaC):**
- **IAM / Access Control**: IAM policies, roles, permissions, RBAC, auth middleware
- **Encryption**: KMS keys, TLS configs, encryption-at-rest settings, certificate management
- **Logging / Auditing**: CloudTrail, CloudWatch, access logs, audit trails, log groups
- **Network**: VPCs, security groups, NACLs, WAF, API Gateway, load balancers, DNS
- **Data Protection**: S3 bucket policies, RDS encryption, secrets management (Secrets Manager, SSM Parameter Store)
- **Backup / Recovery**: Backup plans, snapshots, replication, multi-AZ, DR configs
- **Configuration Management**: Config rules, drift detection, parameter stores
- **Incident Response**: SNS topics, alarms, Lambda triggers for security events

**IaC-specific detection:**

| IaC Tool | What to scan for |
|---|---|
| **AWS CDK** | L1/L2/L3 constructs, `Grant*` methods, `addToPolicy()`, CDK Aspects for compliance, CDK Nag rules, pipeline stages, cross-account trust |
| **Terraform / OpenTofu** | `aws_iam_policy`, `aws_security_group`, `aws_kms_key`, provider configs, backend state encryption, `tfsec`/`checkov` configs, module sources, state locking |
| **CloudFormation** | `AWS::IAM::*`, `AWS::KMS::*`, `AWS::EC2::SecurityGroup`, Conditions, cfn-guard/cfn-nag rules, nested stacks, stack policies |
| **Crossplane / Upbound** | `CompositeResourceDefinition`, `Composition`, `ProviderConfig`, `EnvironmentConfig`, managed resource specs, claim/composition security settings, IRSA/pod identity configs |

**Crossplane/Upbound-specific notes:**
- Check `ProviderConfig` for credential management (IRSA vs. static keys)
- Check `Composition` pipelines for resource configuration (encryption, networking, access)
- Check for `Usage` resources that enforce dependency ordering
- Check namespace isolation and RBAC on claims vs. composite resources
- Examine `DeploymentRuntimeConfig` for pod-level security context

**OpenTofu-specific notes:**
- Treat identically to Terraform for control mapping purposes
- Additionally check for state encryption configuration (OpenTofu native encryption vs. backend encryption)
- Check for `opentofu` block in provider requirements

### Step 1.3 — Read Architecture Docs

Search for and read architecture documentation:

- `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `ARCHITECTURE.md`, `README.md`
- Any `docs/*.md` files describing system design
- `cdk.json` context for environment and deployment configuration
- Pipeline definitions for deployment flow

### Step 1.4 — Produce Phase 1 Output

Write `docs/compliance/phase1-discovery.md`:

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

### Step 1.5 — User Checkpoint

Present the Phase 1 summary and ask:
- "Does this accurately represent your architecture?"
- "Are there components I missed?"
- "Any out-of-band security controls not visible in code (e.g., AWS Organizations SCPs, SSO, manual configs)?"

Wait for user confirmation before proceeding to Phase 2.

---

## Phase 2 — Control Mapping

### Source of Truth

The ITSG-33 controls are defined in [Annex 3A — Security Control Catalogue (ITSG-33)](https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33). The CCCS Medium Cloud Profile control selection is defined in Annex B of [ITSP.50.103 — Guidance on the Security Categorization of Cloud-based Services](https://www.cyber.gc.ca/en/guidance/guidance-security-categorization-cloud-based-services-itsp50103).

When in doubt about a control's description or applicability, fetch the official documentation page to verify before mapping.

### ITSG-33 Control Families (CCCS Medium)

Map these 8 control families (technical + operational + management controls applicable to cloud):

#### AC — Access Control
| Control | Description | Applicability |
|---|---|---|
| AC-2 | Account Management | How user/service accounts are created, managed, disabled |
| AC-3 | Access Enforcement | IAM policies, resource policies, least privilege |
| AC-4 | Information Flow Enforcement | Security groups, NACLs, VPC flow, WAF rules |
| AC-5 | Separation of Duties | Cross-account deployment, role separation |
| AC-6 | Least Privilege | IAM policy scoping, wildcard avoidance |
| AC-7 | Unsuccessful Login Attempts | Lockout policies, failed auth handling |
| AC-17 | Remote Access | VPN, bastion, Session Manager, API access |
| AC-20 | Use of External Information Systems | Third-party integrations, external dependencies |

#### AU — Audit and Accountability
| Control | Description | Applicability |
|---|---|---|
| AU-2 | Auditable Events | What events are logged (CloudTrail, CloudWatch, access logs) |
| AU-3 | Content of Audit Records | Log detail level, fields captured |
| AU-6 | Audit Review, Analysis, and Reporting | Log monitoring, alerting, dashboards |
| AU-8 | Time Stamps | NTP sync, UTC usage, timestamp consistency |
| AU-9 | Protection of Audit Information | Log integrity, immutability, access restrictions |
| AU-11 | Audit Record Retention | Log retention periods, archival |
| AU-12 | Audit Generation | Which components generate audit records |

#### CM — Configuration Management
| Control | Description | Applicability |
|---|---|---|
| CM-2 | Baseline Configuration | IaC templates, golden images, config-as-code |
| CM-3 | Configuration Change Control | PR reviews, pipeline gates, approval workflows |
| CM-6 | Configuration Settings | Hardened configs, CIS benchmarks, security defaults |
| CM-7 | Least Functionality | Disabled unnecessary services/ports, minimal runtimes |
| CM-8 | Information System Component Inventory | Asset tracking, resource tagging |

#### CP — Contingency Planning
| Control | Description | Applicability |
|---|---|---|
| CP-7 | Alternate Processing Site | Multi-AZ, cross-region, DR strategy |
| CP-9 | Information System Backup | Backup policies, snapshot schedules, retention |
| CP-10 | Information System Recovery and Reconstitution | Recovery procedures, RTO/RPO, IaC redeployment |

#### IA — Identification and Authentication
| Control | Description | Applicability |
|---|---|---|
| IA-2 | Identification and Authentication (Organizational Users) | SSO, MFA, IAM Identity Center |
| IA-3 | Device Identification and Authentication | Service-to-service auth, mTLS, API keys |
| IA-4 | Identifier Management | Naming conventions, unique IDs, lifecycle |
| IA-5 | Authenticator Management | Password policies, key rotation, secret management |
| IA-8 | Identification and Authentication (Non-Organizational Users) | External user auth, federation |

#### SA — System and Services Acquisition
| Control | Description | Applicability |
|---|---|---|
| SA-3 | System Development Life Cycle | SDLC process, pipeline stages, testing |
| SA-4 | Acquisition Process | Dependency management, supply chain (npm, pip) |
| SA-8 | Security Engineering Principles | Defense in depth, least privilege, fail-secure |
| SA-10 | Developer Configuration Management | Source control, branch protection, code review |
| SA-11 | Developer Security Testing | SAST, DAST, dependency scanning, unit tests |

#### SC — System and Communications Protection
| Control | Description | Applicability |
|---|---|---|
| SC-7 | Boundary Protection | VPC, subnets, security groups, WAF, API Gateway |
| SC-8 | Transmission Confidentiality and Integrity | TLS, HTTPS enforcement, certificate management |
| SC-12 | Cryptographic Key Establishment and Management | KMS, key policies, rotation |
| SC-13 | Cryptographic Protection | Encryption algorithms, at-rest encryption |
| SC-28 | Protection of Information at Rest | S3 encryption, RDS encryption, EBS encryption |

#### SI — System and Information Integrity
| Control | Description | Applicability |
|---|---|---|
| SI-2 | Flaw Remediation | Patching strategy, dependency updates, vulnerability management |
| SI-3 | Malicious Code Protection | GuardDuty, anti-malware, container scanning |
| SI-4 | Information System Monitoring | CloudWatch alarms, GuardDuty, Security Hub |
| SI-5 | Security Alerts, Advisories, and Directives | Notification mechanisms, response procedures |
| SI-10 | Information Input Validation | Input validation, parameterized queries, sanitization |

### Control Inheritance Model

For each control, classify the implementation responsibility:

| Category | Meaning | Example |
|---|---|---|
| **AWS Inherited** | Fully provided by AWS, no customer action needed | PE-* (Physical), data center security |
| **AWS Shared** | AWS provides the capability, customer must configure it | SC-28: AWS provides S3 encryption, customer must enable it |
| **Customer Implemented** | Entirely the customer's responsibility | AC-2: Account management within the application |
| **GC Org-level** | Implemented at the GC organization/department level, not per-project | AT-* (Security Training), PS-* (Personnel Security) |

### Step 2.1 — Map Each Control

For every control in the families above, determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **Inheritance**: AWS Inherited / AWS Shared / Customer Implemented / GC Org-level
3. **Evidence**: Specific file paths, line numbers, resource configurations, or architecture patterns that demonstrate implementation
4. **Notes**: Any caveats, assumptions, or dependencies

### Step 2.2 — Produce Phase 2 Output

Write `docs/compliance/phase2-control-mapping.md`:

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

### Step 2.3 — User Checkpoint

Present the Phase 2 summary:
- Control posture breakdown (Implemented / Partial / Not Implemented / N/A counts)
- Any controls where the assessment was uncertain
- Ask: "Any controls where you have additional context I should factor in?"

Wait for user confirmation before proceeding to Phase 3.

---

## Phase 3 — Gap Analysis

### Step 3.1 — Gap Analysis

For every control marked **Not Implemented** or **Partially Implemented**, produce a risk-rated remediation entry:

```markdown
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

#### Risk Rating Criteria

| Rating | Criteria |
|---|---|
| **Critical** | Direct exposure of Protected B data, no compensating control, actively exploitable |
| **High** | Missing control with no compensating control, significant blast radius |
| **Medium** | Partially implemented or has compensating control but not fully compliant |
| **Low** | Missing enhancement or optimization, minimal security impact |

### Step 3.2 — Produce Phase 3 Outputs

Write `docs/compliance/phase3-gap-analysis.md`:

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

[Gap entries as defined in Step 3.1]
```

### Step 3.3 — Executive Summary

Write `docs/compliance/assessment-summary.md`:

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

### Step 3.4 — Final Report

Present the executive summary to the user and note:
- Total compliance posture percentage
- Number and severity of gaps
- Top recommended actions

---

## Important Rules

- **Evidence over assumption**: Every "Implemented" status must cite a file path or architecture pattern. If you can't find evidence, mark it "Not Implemented" or ask.
- **Don't inflate compliance**: When uncertain, mark as "Partially Implemented" with notes, not "Implemented".
- **Respect inheritance**: Many controls are AWS-inherited or org-level. Don't mark these as gaps in the project.
- **Canadian context**: Data residency defaults to ca-central-1. Flag any resources outside Canadian regions.
- **Generic analysis**: This skill works on any project. Adapt the component detection and service mapping to whatever tech stack is found.
- **No fabricated controls**: Only map controls that exist in ITSG-33. Don't invent control IDs or descriptions.
- **Verify against official sources**: When uncertain about a control description, fetch the official documentation (see Source of Truth in Phase 2) to verify. Do not rely solely on the control tables in this skill file — they are summaries.
- **Phase checkpoints are mandatory**: Always pause between phases for user input. Never run all three phases without stopping.
- **Smart re-run is default**: If previous outputs exist, always offer smart re-run before starting from scratch.

## Official References

- [ITSG-33 Annex 3A — Security Control Catalogue](https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33)
- [ITSP.50.103 — Guidance on Security Categorization of Cloud-based Services (contains CCCS Medium profile in Annex B)](https://www.cyber.gc.ca/en/guidance/guidance-security-categorization-cloud-based-services-itsp50103)
- [GC Security Control Profile for Cloud-Based IT Services](https://www.canada.ca/en/government/system/digital-government/digital-government-innovations/cloud-services/government-canada-security-control-profile-cloud-based-it-services.html)
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final) — ITSG-33 Annex 3A adopts the same control IDs
- [AWS CCCS Medium Compliance](https://aws.amazon.com/compliance/cccs/)
- [AWS Audit Manager — CCCS Medium Framework](https://docs.aws.amazon.com/audit-manager/latest/userguide/cccs-medium.html)
