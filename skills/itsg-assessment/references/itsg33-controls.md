# ITSG-33 Control Families (CCCS Medium Profile)

8 control families — technical + operational + management controls applicable to cloud.

## Source of Truth

The ITSG-33 controls are defined in [Annex 3A — Security Control Catalogue (ITSG-33)](https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33). The CCCS Medium Cloud Profile control selection is defined in Annex B of [ITSP.50.103 — Guidance on the Security Categorization of Cloud-based Services](https://www.cyber.gc.ca/en/guidance/guidance-security-categorization-cloud-based-services-itsp50103).

When in doubt about a control's description or applicability, fetch the official documentation page to verify before mapping.

## AC — Access Control

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

## AU — Audit and Accountability

| Control | Description | Applicability |
|---|---|---|
| AU-2 | Auditable Events | What events are logged (CloudTrail, CloudWatch, access logs) |
| AU-3 | Content of Audit Records | Log detail level, fields captured |
| AU-6 | Audit Review, Analysis, and Reporting | Log monitoring, alerting, dashboards |
| AU-8 | Time Stamps | NTP sync, UTC usage, timestamp consistency |
| AU-9 | Protection of Audit Information | Log integrity, immutability, access restrictions |
| AU-11 | Audit Record Retention | Log retention periods, archival |
| AU-12 | Audit Generation | Which components generate audit records |

## CM — Configuration Management

| Control | Description | Applicability |
|---|---|---|
| CM-2 | Baseline Configuration | IaC templates, golden images, config-as-code |
| CM-3 | Configuration Change Control | PR reviews, pipeline gates, approval workflows |
| CM-6 | Configuration Settings | Hardened configs, CIS benchmarks, security defaults |
| CM-7 | Least Functionality | Disabled unnecessary services/ports, minimal runtimes |
| CM-8 | Information System Component Inventory | Asset tracking, resource tagging |

## CP — Contingency Planning

| Control | Description | Applicability |
|---|---|---|
| CP-7 | Alternate Processing Site | Multi-AZ, cross-region, DR strategy |
| CP-9 | Information System Backup | Backup policies, snapshot schedules, retention |
| CP-10 | Information System Recovery and Reconstitution | Recovery procedures, RTO/RPO, IaC redeployment |

## IA — Identification and Authentication

| Control | Description | Applicability |
|---|---|---|
| IA-2 | Identification and Authentication (Organizational Users) | SSO, MFA, IAM Identity Center |
| IA-3 | Device Identification and Authentication | Service-to-service auth, mTLS, API keys |
| IA-4 | Identifier Management | Naming conventions, unique IDs, lifecycle |
| IA-5 | Authenticator Management | Password policies, key rotation, secret management |
| IA-8 | Identification and Authentication (Non-Organizational Users) | External user auth, federation |

## SA — System and Services Acquisition

| Control | Description | Applicability |
|---|---|---|
| SA-3 | System Development Life Cycle | SDLC process, pipeline stages, testing |
| SA-4 | Acquisition Process | Dependency management, supply chain (npm, pip) |
| SA-8 | Security Engineering Principles | Defense in depth, least privilege, fail-secure |
| SA-10 | Developer Configuration Management | Source control, branch protection, code review |
| SA-11 | Developer Security Testing | SAST, DAST, dependency scanning, unit tests |

## SC — System and Communications Protection

| Control | Description | Applicability |
|---|---|---|
| SC-7 | Boundary Protection | VPC, subnets, security groups, WAF, API Gateway |
| SC-8 | Transmission Confidentiality and Integrity | TLS, HTTPS enforcement, certificate management |
| SC-12 | Cryptographic Key Establishment and Management | KMS, key policies, rotation |
| SC-13 | Cryptographic Protection | Encryption algorithms, at-rest encryption |
| SC-28 | Protection of Information at Rest | S3 encryption, RDS encryption, EBS encryption |

## SI — System and Information Integrity

| Control | Description | Applicability |
|---|---|---|
| SI-2 | Flaw Remediation | Patching strategy, dependency updates, vulnerability management |
| SI-3 | Malicious Code Protection | GuardDuty, anti-malware, container scanning |
| SI-4 | Information System Monitoring | CloudWatch alarms, GuardDuty, Security Hub |
| SI-5 | Security Alerts, Advisories, and Directives | Notification mechanisms, response procedures |
| SI-10 | Information Input Validation | Input validation, parameterized queries, sanitization |

## Control Inheritance Model

For each control, classify the implementation responsibility:

| Category | Meaning | Example |
|---|---|---|
| **AWS Inherited** | Fully provided by AWS, no customer action needed | PE-\* (Physical), data center security |
| **AWS Shared** | AWS provides the capability, customer must configure it | SC-28: AWS provides S3 encryption, customer must enable it |
| **Customer Implemented** | Entirely the customer's responsibility | AC-2: Account management within the application |
| **GC Org-level** | Implemented at the GC organization/department level, not per-project | AT-\* (Security Training), PS-\* (Personnel Security) |
