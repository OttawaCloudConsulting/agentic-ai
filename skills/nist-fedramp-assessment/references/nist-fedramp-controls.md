# FedRAMP Moderate Control Families (NIST SP 800-53 Rev 5)

12 core technical families from the FedRAMP Moderate baseline.

## Source of Truth

The NIST SP 800-53 Rev 5 control catalogue is published at [NIST CSRC — SP 800-53 Rev 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final). The FedRAMP Moderate baseline control selection is published at [FedRAMP.gov — Documents and Templates](https://www.fedramp.gov/documents-templates/).

Phase 0 validates these tables against both official sources before any assessment begins. When in doubt about a control's description or applicability, fetch the official documentation to verify before mapping.

## AC — Access Control

| Control | Description | Applicability |
|---|---|---|
| AC-2 | Account Management | How user/service accounts are created, managed, disabled |
| AC-3 | Access Enforcement | IAM policies, resource policies, least privilege |
| AC-4 | Information Flow Enforcement | Security groups, NACLs, VPC flow, WAF rules |
| AC-5 | Separation of Duties | Cross-account deployment, role separation |
| AC-6 | Least Privilege | IAM policy scoping, wildcard avoidance |
| AC-7 | Unsuccessful Logon Attempts | Lockout policies, failed auth handling |
| AC-8 | System Use Notification | Login banners, acceptable use notices |
| AC-17 | Remote Access | VPN, bastion, Session Manager, API access |
| AC-20 | Use of External Systems | Third-party integrations, external dependencies |

## AU — Audit and Accountability

| Control | Description | Applicability |
|---|---|---|
| AU-2 | Event Logging | Which events are logged (CloudTrail, CloudWatch, access logs) |
| AU-3 | Content of Audit Records | Log detail level, fields captured |
| AU-6 | Audit Record Review, Analysis, and Reporting | Log monitoring, alerting, dashboards |
| AU-8 | Time Stamps | NTP sync, UTC usage, timestamp consistency |
| AU-9 | Protection of Audit Information | Log integrity, immutability, access restrictions |
| AU-11 | Audit Record Retention | Log retention periods, archival |
| AU-12 | Audit Record Generation | Which components generate audit records |

## CA — Security Assessment and Authorization

| Control | Description | Applicability |
|---|---|---|
| CA-2 | Control Assessments | Security testing, third-party assessments, 3PAO |
| CA-3 | Information Exchange | System interconnection agreements, data sharing |
| CA-7 | Continuous Monitoring | Automated monitoring, ConMon program, vulnerability scanning cadence |
| CA-9 | Internal System Connections | Internal service-to-service connections, lateral movement controls |

## CM — Configuration Management

| Control | Description | Applicability |
|---|---|---|
| CM-2 | Baseline Configuration | IaC templates, golden images, config-as-code |
| CM-3 | Configuration Change Control | PR reviews, pipeline gates, approval workflows |
| CM-6 | Configuration Settings | Hardened configs, CIS benchmarks, security defaults |
| CM-7 | Least Functionality | Disabled unnecessary services/ports, minimal runtimes |
| CM-8 | System Component Inventory | Asset tracking, resource tagging |
| CM-10 | Software Usage Restrictions | License management, approved software list |

## CP — Contingency Planning

| Control | Description | Applicability |
|---|---|---|
| CP-7 | Alternate Processing Site | Multi-AZ, cross-region, DR strategy |
| CP-9 | System Backup | Backup policies, snapshot schedules, retention |
| CP-10 | System Recovery and Reconstitution | Recovery procedures, RTO/RPO, IaC redeployment |

## IA — Identification and Authentication

| Control | Description | Applicability |
|---|---|---|
| IA-2 | Identification and Authentication (Organizational Users) | SSO, MFA, IAM Identity Center |
| IA-3 | Device Identification and Authentication | Service-to-service auth, mTLS, API keys |
| IA-4 | Identifier Management | Naming conventions, unique IDs, lifecycle |
| IA-5 | Authenticator Management | Password policies, key rotation, secret management |
| IA-8 | Identification and Authentication (Non-Organizational Users) | External user auth, federation |

## IR — Incident Response

| Control | Description | Applicability |
|---|---|---|
| IR-4 | Incident Handling | IR plan, containment procedures, escalation paths |
| IR-5 | Incident Monitoring | Tracking open incidents, metrics, trend analysis |
| IR-6 | Incident Reporting | Reporting to US-CERT/CISA, FedRAMP PMO notification |
| IR-8 | Incident Response Plan | Documented IR plan, roles, contact lists |

## PL — Planning

| Control | Description | Applicability |
|---|---|---|
| PL-2 | System Security Plan | SSP documentation, authorization boundary, system description |
| PL-4 | Rules of Behavior | Acceptable use policy, user acknowledgment |

## RA — Risk Assessment

| Control | Description | Applicability |
|---|---|---|
| RA-3 | Risk Assessment | Threat modeling, risk register, likelihood/impact analysis |
| RA-5 | Vulnerability Monitoring and Scanning | Vulnerability scanning cadence, tooling (Inspector, Security Hub) |

## SA — System and Services Acquisition

| Control | Description | Applicability |
|---|---|---|
| SA-3 | System Development Life Cycle | SDLC process, pipeline stages, testing |
| SA-4 | Acquisition Process | Dependency management, supply chain (npm, pip) |
| SA-8 | Security Engineering Principles | Defense in depth, least privilege, fail-secure |
| SA-9 | External System Services | Third-party service review, FedRAMP-authorized service providers |
| SA-10 | Developer Configuration Management | Source control, branch protection, code review |
| SA-11 | Developer Testing and Evaluation | SAST, DAST, dependency scanning, unit tests |

## SC — System and Communications Protection

| Control | Description | Applicability |
|---|---|---|
| SC-7 | Boundary Protection | VPC, subnets, security groups, WAF, API Gateway |
| SC-8 | Transmission Confidentiality and Integrity | TLS, HTTPS enforcement, certificate management |
| SC-12 | Cryptographic Key Establishment and Management | KMS, key policies, rotation |
| SC-13 | Cryptographic Protection | Encryption algorithms, FIPS 140-2/3 validated modules |
| SC-28 | Protection of Information at Rest | S3 encryption, RDS encryption, EBS encryption |

## SI — System and Information Integrity

| Control | Description | Applicability |
|---|---|---|
| SI-2 | Flaw Remediation | Patching strategy, dependency updates, vulnerability management |
| SI-3 | Malicious Code Protection | GuardDuty, anti-malware, container scanning |
| SI-4 | System Monitoring | CloudWatch alarms, GuardDuty, Security Hub |
| SI-5 | Security Alerts, Advisories, and Directives | Notification mechanisms, response procedures, US-CERT feeds |
| SI-10 | Information Input Validation | Input validation, parameterized queries, sanitization |

## Dual Inheritance Model

FedRAMP Moderate uses a dual inheritance model: the FedRAMP Moderate Customer Responsibility Matrix (CRM) based on AWS P-ATO, and the generic NIST 800-53 shared responsibility model for non-FedRAMP NIST assessments.

| Category | Meaning | Example |
|---|---|---|
| **AWS FedRAMP Inherited** | In AWS FedRAMP Moderate P-ATO authorization package; no customer action needed | PE-\* (Physical), data center controls |
| **AWS FedRAMP Shared** | AWS provides the capability in authorization package; customer must configure and document in SSP | SC-28: AWS provides S3 encryption capability, customer must enable and document |
| **Customer Implemented** | Entirely the customer's responsibility; no AWS inheritance | AC-2: Application-level account management |
| **Organization-Level** | Implemented at the agency/org level, not per-system | AT-\* (Security Training), PS-\* (Personnel Security) |

Reference the [AWS Audit Manager FedRAMP Moderate framework](https://docs.aws.amazon.com/audit-manager/latest/userguide/fedramp-moderate.html) for the current CRM detailing which controls are inherited vs. shared under the AWS P-ATO.
