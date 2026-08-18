# Worked Example — Control Evidence Document

> **Illustrative only.** The system, file paths, artifact locations, evidence, and names below are fictional. The **control text in 2.1 and 2.2 is verbatim from ITSG-33 Annex 3A** and is reproduced here so the example shows correct sourcing — but a real assessment must still resolve it per the Phase 4 steps rather than copying this file. Read this to see the shape of a completed document, then fill `assets/control-evidence-template.md` from real evidence.

CP-9 is used here because it has four lettered parts, which shows how the `3.2.<letter>` blocks repeat and how a control ends up Partially Satisfied when one part fails. Note that parts A, B and C each carry an `[Assignment: ...]` — those brackets stay untouched in 2.1, and the selected values appear in 2.4.

---

**PROTECTED B**

# Security Control Evidence — CP-9: Information System Backup

## Document Control

| Field | Value |
|---|---|
| System / Project | GC Case Management System (GC-CMS) |
| Control ID | CP-9 |
| Control Family | CP — Contingency Planning |
| Security Profile | CCCS Medium Cloud (ITSG-33) |
| Overall Status | Partially Satisfied |
| Inheritance | AWS Shared |
| Classification | Protected B |
| Document Version | 1.0 |
| Assessment Date | 2026-03-06 |
| Assessor | J. Tremblay, Cloud Security Assessor |

## Revision History

| Version | Date | Author | Summary of Change |
|---|---|---|---|
| 1.0 | 2026-03-06 | J. Tremblay | Initial issue |

## Approvals

| Role | Name | Title | Date | Signature |
|---|---|---|---|---|
| Preparer | J. Tremblay | Cloud Security Assessor | 2026-03-06 | |
| Reviewer (Security) | M. Okafor | Departmental IT Security Officer | 2026-03-09 | |
| Approver | S. Lavoie | Director, Digital Services | | |

---

## 1. Purpose

This document provides evidence of the implementation of ITSG-33 control CP-9 (Information System Backup) for the GC Case Management System. It covers backup of user-level data, system-level data, and system documentation, and the protection of backup information at rest. It supports the CCCS Medium Cloud Profile assessment of GC-CMS as a Protected B system hosted in ca-central-1.

## 2. Control Definition

### 2.1 Definition

**Source:** https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33 | **Retrieved:** 2026-03-06 | **Catalogue:** ITSG-33 Annex 3A
**Retrieval method:** full-page retrieval | **Raw capture:** docs/compliance/.control-text/annex3a.raw.html

A. The organization conducts backups of user-level information contained in the information system [Assignment: organization-defined frequency consistent with recovery time and recovery point objectives].

B. The organization conducts backups of system-level information contained in the information system [Assignment: organization-defined frequency consistent with recovery time and recovery point objectives].

C. The organization conducts backups of information system documentation including security-related documentation [Assignment: organization-defined frequency consistent with recovery time and recovery point objectives].

D. The organization protects the confidentiality, integrity, and availability of backup information at storage locations. The organization determines retention periods for essential business information and archived backups.

### 2.2 Supplemental Guidance

**Source:** https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33 | **Retrieved:** 2026-03-06 | **Catalogue:** ITSG-33 Annex 3A

System-level information includes, for example, system-state information, operating system and application software, and licenses. User-level information includes any information other than system-level information. Mechanisms employed by organizations to protect the integrity of information system backups include, for example, digital signatures and cryptographic hashes. Protection of system backup information while in transit is beyond the scope of this control. Information system backups reflect the requirements in contingency plans as well as other organizational requirements for backing up information. Related controls: CP-2, CP-6, MP-4, MP-5, SC-13.

### 2.3 Tailoring and Implementation Notes

CP-9 is assessed as **AWS Shared**. AWS provides the durability, storage, and snapshot mechanisms (Amazon S3, Amazon RDS automated backups, AWS Backup) under the shared responsibility model; GC-CMS is responsible for enabling them, setting frequency and retention against its RPO, and enforcing encryption and access controls on the backup store.

Scope is the GC-CMS production account only. The sandbox and development accounts hold no Protected B data and are out of scope for CP-9; they are covered by the environment classification recorded in `phase1-discovery.md`.

Part C is interpreted to cover the system documentation held in the GC-CMS repository, including the security artifacts under `docs/compliance/`. Because that documentation lives in the version-control system rather than in the AWS boundary, it is assessed against the repository's own backup posture rather than against AWS Backup.

Backup frequency (daily) and retention (35 days) are inherited from the departmental contingency planning standard and are consistent with the 24-hour RPO recorded in the GC-CMS contingency plan.

### 2.4 Recommended Values

| Parameter | Assignment Source | Recommended Value | Implemented Value | Evidence Ref |
|---|---|---|---|---|
| Part A — [Assignment: organization-defined frequency consistent with recovery time and recovery point objectives] (user-level information) | Departmental contingency standard, against a 24-hour RPO | At least daily | Daily, 05:00 UTC | CP-9-A-01 |
| Part B — [Assignment: organization-defined frequency consistent with recovery time and recovery point objectives] (system-level information) | Departmental contingency standard, against a 24-hour RPO | At least daily | Daily, 05:00 UTC | CP-9-B-01 |
| Part C — [Assignment: organization-defined frequency consistent with recovery time and recovery point objectives] (system documentation) | Departmental contingency standard | At least weekly | Not set — no documentation backup exists | None — see section 4 |
| Part D — retention period for essential business information and archived backups | CCCS Medium profile | Minimum 30 days | 35 days | CP-9-A-01 |

---

## 3. Evidential Response

### 3.1 Description

GC-CMS meets three of the four CP-9 requirements. Backups of user-level and system-level information are defined in infrastructure-as-code and applied by an AWS Backup plan covering the production RDS instance and the case-document S3 bucket, running daily with 35-day retention — satisfying parts A and B and meeting the 24-hour RPO. Backup data is encrypted with a customer-managed KMS key whose key policy restricts decrypt to the backup and recovery roles, and the vault carries a resource policy denying deletion outside the break-glass role, satisfying part D for confidentiality and integrity.

Part C is **not satisfied**. System documentation, including the security artifacts under `docs/compliance/`, exists only in the GitHub repository. No independent backup of that repository is taken, and no departmental record copy is maintained. Loss of the repository would take the security documentation with it. This is recorded as a gap in section 4 rather than argued as satisfied by version control, because version history is not a backup of the hosting service.

**Verdict Summary**

| Part | Requirement (short) | Assessment |
|---|---|---|
| A | Back up user-level information | Satisfied |
| B | Back up system-level information | Satisfied |
| C | Back up system documentation | Not Satisfied |
| D | Protect backup information at storage locations; determine retention periods | Satisfied |

### 3.2 Artifacts

#### 3.2.A — Conducts backups of user-level information

**Implementation:** Case records are held in the `gc-cms-production` RDS PostgreSQL instance and case attachments in the `gc-cms-documents` S3 bucket. Both are selected into the `gc-cms-daily` AWS Backup plan, which runs daily at 05:00 UTC with 35-day retention.

**Assessment:** Satisfied

**Rationale:** The backup plan, its schedule, its retention, and the resource selections are all defined in CDK and applied by the production pipeline, so the configuration is verifiable in code rather than asserted. The console export confirms the plan is active and that the most recent job completed.

| Artifact ID | Type | Location / Reference | Date | Description |
|---|---|---|---|---|
| CP-9-A-01 | IaC | lib/backup/backup-stack.ts:34-71 | 2026-03-06 | `BackupPlan` with daily 05:00 UTC rule and 35-day `deleteAfter` |
| CP-9-A-02 | IaC | lib/backup/backup-stack.ts:73-88 | 2026-03-06 | `BackupSelection` covering the RDS instance and documents bucket |
| CP-9-A-03 | Screenshot | evidence/cp-9/aws-backup-jobs-2026-03-05.png | 2026-03-05 | AWS Backup jobs list showing completed daily job |

#### 3.2.B — Conducts backups of system-level information

**Implementation:** System state is reconstituted from infrastructure-as-code rather than from image backups. The CDK application is the authoritative definition of all system-level configuration, and the RDS automated backup captures database engine configuration and parameter group state alongside the data.

**Assessment:** Satisfied

**Rationale:** Part B is met by a combination of the RDS automated backup and the IaC redeployment path documented in the contingency plan. Because every system-level component is declared in CDK and deployed from a pipeline, there is no mutable system state that would be lost and not recoverable. The recovery procedure has been exercised, and the test record is cited.

| Artifact ID | Type | Location / Reference | Date | Description |
|---|---|---|---|---|
| CP-9-B-01 | IaC | lib/database/rds-stack.ts:52-64 | 2026-03-06 | RDS `backupRetention` of 35 days with 05:00 UTC window |
| CP-9-B-02 | Document | docs/contingency/recovery-procedure.md | 2026-02-11 | IaC redeployment procedure for system-level reconstitution |
| CP-9-B-03 | Document | evidence/cp-9/dr-test-record-2026-02.md | 2026-02-14 | Recovery test record, restore completed within RTO |

#### 3.2.C — Conducts backups of information system documentation

**Implementation:** System and security documentation is maintained in the GC-CMS GitHub repository under `docs/`. No backup of the repository itself is taken, and no departmental record copy is held outside GitHub.

**Assessment:** Not Satisfied

**Rationale:** Version control preserves history within the hosting service but is not a backup of that service. Loss or prolonged unavailability of the GitHub organization would take the security documentation with it, and no compensating copy exists. The part C `[Assignment: ...frequency...]` has no value set, because no documentation backup runs at any frequency. No artifact can be cited demonstrating a backup of the documentation, so none is listed.

| Artifact ID | Type | Location / Reference | Date | Description |
|---|---|---|---|---|
| — | — | No artifact — requirement not met | — | See section 4 |

#### 3.2.D — Protects backup information at storage locations, and determines retention periods

**Implementation:** The `gc-cms-backup` vault encrypts all recovery points with the customer-managed KMS key `alias/gc-cms-backup`. The key policy grants `kms:Decrypt` only to the backup service role and the break-glass recovery role. A vault access policy denies `backup:DeleteRecoveryPoint` to every principal except the break-glass role. The vault is in ca-central-1; no copy action targets a region outside Canada.

**Assessment:** Satisfied

**Rationale:** Part D carries two requirements and both are met. Protection: confidentiality by customer-managed KMS encryption with a scoped key policy; integrity by the vault policy preventing deletion by day-to-day roles; availability by AWS-managed durability combined with the retention below. Retention determination: 35 days is set in the backup plan against the departmental standard's 30-day minimum, recorded in 2.4. Residency is confirmed by the absence of any cross-region copy rule.

| Artifact ID | Type | Location / Reference | Date | Description |
|---|---|---|---|---|
| CP-9-D-01 | IaC | lib/backup/backup-stack.ts:14-32 | 2026-03-06 | Backup vault with customer-managed KMS key, ca-central-1 |
| CP-9-D-02 | IaC | lib/backup/key-policy.ts:9-41 | 2026-03-06 | KMS key policy limiting decrypt to backup and break-glass roles |
| CP-9-D-03 | Config | evidence/cp-9/vault-access-policy.json | 2026-03-06 | Vault policy denying recovery point deletion outside break-glass |

---

## 4. Residual Risk and Gaps

| Part | Gap | Risk Rating | Compensating Control | Remediation Reference |
|---|---|---|---|---|
| C | System and security documentation is held only in GitHub; no independent backup or departmental record copy exists | Medium | Partial — Git history and distributed local clones reduce but do not remove the loss scenario | [CP-9 entry](../phase3-gap-analysis.md) |

## 5. Traceability

| Reference | Path |
|---|---|
| Architecture Discovery | [../phase1-discovery.md](../phase1-discovery.md) |
| Control Mapping | [../phase2-control-mapping.md](../phase2-control-mapping.md) |
| Gap Analysis | [../phase3-gap-analysis.md](../phase3-gap-analysis.md) |
| Related Controls | CP-10 (recovery and reconstitution, relies on these backups), SC-28 (protection at rest, shares the KMS key), CM-2 (baseline configuration held in the same repository as part C documentation) |

---

**PROTECTED B**
