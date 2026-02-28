# Interactive Compliance Assessment Workflow

Map a project's architecture and codebase to Canadian ITSG-33 security controls (CCCS Medium Cloud Profile). Produces a phased assessment with AWS shared responsibility inheritance, gap analysis, and risk-rated remediation guidance.

## Output Location

All output goes to `docs/compliance/`. Create the directory if it does not exist.

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

## Phase 0 — Framework Validation

This phase runs first, before any assessment work. It validates that the control data used in the assessment matches the current official sources.

### Step 0.1 — Fetch ITSG-33 Control Catalogue

Fetch the ITSG-33 Annex 3A page to verify the control families and IDs:

1. Fetch `https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33`
2. Compare the control IDs and names listed in the Phase 2 control family tables against the official catalogue

What to check:

- Every control ID used in the assessment exists in ITSG-33 Annex 3A
- Control names match (e.g., AC-2 is "Account Management")
- No fabricated control IDs

### Step 0.2 — Report Validation Results

If any differences are found:

1. Report changes in a summary table
2. Use corrected control data for the rest of the assessment

If no differences are found:

- Report: "Phase 0 complete — all controls match official sources."

### Step 0.3 — Proceed

After validation, proceed to the smart re-run check, then Phase 1.

---

## Phase 1 — Architecture Discovery

### Step 1.1 — Detect Tech Stack

Scan the project root for technology indicators:

| Indicator | Detection |
|---|---|
| **Language** | `package.json` (Node/TS), `requirements.txt`/`pyproject.toml` (Python), `go.mod` (Go), `Cargo.toml` (Rust), `pom.xml`/`build.gradle` (Java) |
| **IaC** | `cdk.json` (AWS CDK), `*.tf` (Terraform), `template.yaml`/`template.json` (CloudFormation/SAM), Crossplane `*.yaml` with `apiVersion: *.crossplane.io/*` (Crossplane), `serverless.yml` (Serverless Framework) |
| **Containers** | `Dockerfile`, `docker-compose.yml`, `*.Containerfile` |
| **CI/CD** | `.github/workflows/`, `buildspec.yml`, `.gitlab-ci.yml`, `Jenkinsfile` |
| **Config** | `*.yaml`, `*.json`, `*.toml`, `*.env*` config files |

### Step 1.2 — Analyze Codebase

Scan for security-relevant patterns:

**General security patterns (all IaC):**

- IAM / Access Control: policies, roles, permissions, RBAC, auth middleware
- Encryption: KMS keys, TLS configs, encryption-at-rest settings, certificate management
- Logging / Auditing: CloudTrail, CloudWatch, access logs, audit trails
- Network: VPCs, security groups, NACLs, WAF, API Gateway, load balancers
- Data Protection: S3 bucket policies, RDS encryption, secrets management
- Backup / Recovery: backup plans, snapshots, replication, multi-AZ
- Configuration Management: config rules, drift detection, parameter stores
- Incident Response: SNS topics, alarms, Lambda triggers for security events

**IaC-specific detection:**

| IaC Tool | What to scan for |
|---|---|
| **AWS CDK** | L1/L2/L3 constructs, `Grant*` methods, CDK Aspects, CDK Nag rules, pipeline stages, cross-account trust |
| **Terraform** | `aws_iam_policy`, `aws_security_group`, `aws_kms_key`, provider configs, backend state encryption, checkov configs, module sources |
| **CloudFormation** | `AWS::IAM::*`, `AWS::KMS::*`, `AWS::EC2::SecurityGroup`, cfn-guard/cfn-nag rules, nested stacks |
| **Crossplane** | `CompositeResourceDefinition`, `Composition`, `ProviderConfig`, managed resource specs, IRSA configs |

### Step 1.3 — Read Architecture Docs

Search for and read architecture documentation:

- `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `ARCHITECTURE.md`, `README.md`
- Any `docs/*.md` files describing system design
- `cdk.json` context or provider configuration for deployment details
- Pipeline definitions for deployment flow

### Step 1.4 — Produce Phase 1 Output

Write `docs/compliance/phase1-discovery.md` with:

- Project name, assessment date, detected tech stack
- System architecture narrative derived from code and docs analysis
- Components identified (component, type, files, security relevance)
- AWS services detected (service, usage, configuration source)
- Data flows (how data moves through the system)
- Trust boundaries (cross-account, cross-network, external integrations)
- Security-relevant findings (specific configurations found in code)

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

When in doubt about a control's description or applicability, verify against the official documentation before mapping.

### ITSG-33 Control Families (CCCS Medium)

Map these 8 control families:

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
| **GC Org-level** | Implemented at the GC organization/department level, not per-project | AT-*(Security Training), PS-* (Personnel Security) |

### Step 2.1 — Map Each Control

For every control in the families above, determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **Inheritance**: AWS Inherited / AWS Shared / Customer Implemented / GC Org-level
3. **Evidence**: Specific file paths, line numbers, resource configurations, or architecture patterns that demonstrate implementation
4. **Notes**: Any caveats, assumptions, or dependencies

### Step 2.2 — Produce Phase 2 Output

Write `docs/compliance/phase2-control-mapping.md` with:

- Project name, assessment date, profile, control families
- Posture summary (status counts and percentages)
- Inheritance summary (category counts)
- Each control family with per-control status, inheritance, evidence, and notes

### Step 2.3 — User Checkpoint

Present the Phase 2 summary:

- Control posture breakdown (Implemented / Partial / Not Implemented / N/A counts)
- Any controls where the assessment was uncertain
- Ask: "Any controls where you have additional context I should factor in?"

Wait for user confirmation before proceeding to Phase 3.

---

## Phase 3 — Gap Analysis

### Step 3.1 — Gap Analysis

For every control marked Not Implemented or Partially Implemented, produce a risk-rated remediation entry:

- **Status**: Not Implemented / Partially Implemented
- **Risk Rating**: Critical / High / Medium / Low
- **Effort**: Low (< 1 day) / Medium (1-3 days) / High (3+ days)
- **Gap Description**: What is missing and why it matters
- **Remediation Recommendation**: Specific, actionable guidance
- **References**: CCCS guidance links, AWS documentation

#### Risk Rating Criteria

| Rating | Criteria |
|---|---|
| **Critical** | Direct exposure of Protected B data, no compensating control, actively exploitable |
| **High** | Missing control with no compensating control, significant blast radius |
| **Medium** | Partially implemented or has compensating control but not fully compliant |
| **Low** | Missing enhancement or optimization, minimal security impact |

### Step 3.2 — Produce Phase 3 Outputs

Write `docs/compliance/phase3-gap-analysis.md` with:

- Risk summary (counts by rating)
- Remediation priority (ordered by risk rating, then effort)
- Gap entries with full detail

### Step 3.3 — Executive Summary

Write `docs/compliance/assessment-summary.md` with:

- Compliance posture metrics
- Risk dashboard
- Top 5 priority remediations
- Inheritance profile
- Assessment artifact paths

### Step 3.4 — Final Report

Present the executive summary and note:

- Total compliance posture percentage
- Number and severity of gaps
- Top recommended actions

---

## Rules

- **Evidence over assumption**: Every "Implemented" status must cite a file path or architecture pattern. If evidence is not found, mark as "Not Implemented" or ask.
- **Do not inflate compliance**: When uncertain, mark as "Partially Implemented" with notes, not "Implemented".
- **Respect inheritance**: Many controls are AWS-inherited or org-level. Do not mark these as gaps in the project.
- **Canadian context**: Data residency defaults to ca-central-1. Flag any resources outside Canadian regions.
- **Generic analysis**: This workflow works on any project. Adapt detection and mapping to the tech stack found.
- **No fabricated controls**: Only map controls that exist in ITSG-33. Do not invent control IDs or descriptions.
- **Verify against official sources**: When uncertain about a control description, consult the official documentation (see Source of Truth in Phase 2). The control tables here are summaries.
- **Phase checkpoints are mandatory**: Always pause between phases for user input. Never run all three phases without stopping.
- **Smart re-run is default**: If previous outputs exist, always offer smart re-run before starting from scratch.

## Official References

- [ITSG-33 Annex 3A — Security Control Catalogue](https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33)
- [ITSP.50.103 — Guidance on Security Categorization of Cloud-based Services (CCCS Medium profile in Annex B)](https://www.cyber.gc.ca/en/guidance/guidance-security-categorization-cloud-based-services-itsp50103)
- [GC Security Control Profile for Cloud-Based IT Services](https://www.canada.ca/en/government/system/digital-government/digital-government-innovations/cloud-services/government-canada-security-control-profile-cloud-based-it-services.html)
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final) — ITSG-33 Annex 3A adopts the same control IDs
- [AWS CCCS Medium Compliance](https://aws.amazon.com/compliance/cccs/)
- [AWS Audit Manager — CCCS Medium Framework](https://docs.aws.amazon.com/audit-manager/latest/userguide/cccs-medium.html)
