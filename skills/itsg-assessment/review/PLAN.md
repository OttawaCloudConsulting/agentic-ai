# Implementation Plan: itsg-assessment

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | SKILL.md | Add `compatibility` field to frontmatter | P1 |
| 2 | SKILL.md | Remove redundant "Canadian jurisdiction" rule (line 17) | P1 |
| 3 | SKILL.md | Remove Phase 0 fetch-fail row from Error Handling table (line 144) | P1 |
| 4 | SKILL.md | Remove "Ambiguous control status" row from Error Handling table (line 147) | P1 |
| 5 | SKILL.md | Define "significant changes" concretely in Smart Re-run step 2 (line 52) | P2 |
| 6 | SKILL.md | Trim Phase 1.1 tech stack table to IaC-specific rows only | P2 |
| 7 | SKILL.md | Remove "What to search for" column from Phase 1.2 table; keep category names and IaC note | P2 |
| 8 | SKILL.md | Move Output table (lines 34–44) before Example section (lines 25–33) | P3 |
| 9 | SKILL.md | Add PBMM/TBS to frontmatter negative triggers | P3 |

---

## Detailed Changes

### SKILL.md

#### Change 1 — Add `compatibility` field to frontmatter [P1]

**Location**: Line 4 (after `description`, before closing `---`)
**Current**:
```
description: Map project architecture to ITSG-33 ...
---
```
**Replace with**:
```
description: Map project architecture to ITSG-33 ...
compatibility: "AWS workloads in Canadian regions (ca-central-1, ca-west-1). Requires network access for Phase 0 control validation."
---
```
**Reason**: The skill has AWS-specific and network-access runtime dependencies that users in restricted environments need to know before triggering.

---

#### Change 2 — Remove redundant "Canadian jurisdiction" rule [P1]

**Location**: Line 17, inside `## Important Rules`
**Current**:
```
- **Canadian jurisdiction**: This skill applies exclusively to ITSG-33 / CCCS Medium — not NIST FedRAMP or other frameworks.
```
**Replace with**: *(delete this line entirely)*

**Reason**: This rule fires too late to prevent mis-triggering (body loads after trigger) and too early to add value during assessment execution; the frontmatter negative trigger already covers this.

---

#### Change 3 — Remove Phase 0 fetch-fail row from Error Handling table [P1]

**Location**: Line 144, `## Error Handling` table
**Current**:
```
| Phase 0 web fetch fails | Skip validation, use cached controls, report skip reason |
```
**Replace with**: *(delete this row)*

**Reason**: The fetch-fail fallback is already documented at the point of use in Phase 0 (line 65). Duplicating it in the error table adds maintenance burden without adding value.

---

#### Change 4 — Remove "Ambiguous control status" from Error Handling table [P1]

**Location**: Line 147, `## Error Handling` table
**Current**:
```
| Ambiguous control status | Mark "Partially Implemented" with notes explaining uncertainty, flag for user review at checkpoint |
```
**Replace with**: *(delete this row)*

**Reason**: This describes normal Phase 2 behavior already specified in the Phase 2 instructions — it is not an error condition and does not belong in the error table.

---

#### Change 5 — Define "significant changes" in Smart Re-run [P2]

**Location**: Line 52, `## Smart Re-run`, step 2
**Current**:
```
2. If significant changes detected, re-run that phase
```
**Replace with**:
```
2. If changes detected (any IaC file modified since the phase output was written, or any new AWS service added to the codebase), re-run that phase
```
**Reason**: "Significant changes" is undefined and leaves execution non-deterministic; a concrete heuristic removes ambiguity.

---

#### Change 6 — Trim Phase 1.1 tech stack table to IaC-specific rows [P2]

**Location**: Lines 73–79, `### 1.1 — Detect Tech Stack`
**Current**:
```
| Indicator | Detection |
|---|---|
| **Language** | `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle` |
| **IaC** | `cdk.json` (CDK), `*.tf` (Terraform/OpenTofu), `template.yaml` (CloudFormation/SAM), Crossplane `*.yaml` |
| **Containers** | `Dockerfile`, `docker-compose.yml` |
| **CI/CD** | `.github/workflows/`, `buildspec.yml`, `.gitlab-ci.yml`, `Jenkinsfile` |
```
**Replace with**:
```
Detect the IaC framework in use — this determines search terms in Phase 1.2:

| IaC Framework | Indicator |
|---|---|
| **CDK** | `cdk.json`, `lib/*.ts` or `lib/*.py` with CDK constructs |
| **Terraform / OpenTofu** | `*.tf` files |
| **CloudFormation / SAM** | `template.yaml` or `template.json` |
| **Crossplane** | `*.yaml` with `apiVersion: aws.upbound.io` or similar |

Also note language runtime and CI/CD platform for context, but do not let them drive control mapping.
```
**Reason**: Language and CI/CD rows list widely known indicators; only the IaC detection has non-obvious patterns (e.g., Crossplane YAML vs CloudFormation YAML) that affect control mapping behavior.

---

#### Change 7 — Trim Phase 1.2 search category table [P2]

**Location**: Lines 84–93, `### 1.2 — Analyze Codebase`
**Current**:
```
| Category | What to search for |
|---|---|
| **IAM / Access Control** | IAM policy documents, role definitions, `iam.Role`, `iam.Policy`, `aws_iam_*`, `Effect: Allow/Deny`, resource policies |
| **Encryption** | KMS key references, `encryption`, `kms`, `SSEAlgorithm`, TLS/HTTPS configuration, certificate resources |
| **Logging / Auditing** | CloudTrail, CloudWatch Logs, access logging, `log_group`, `Trail`, audit configuration |
| **Network** | VPC definitions, security groups, NACLs, subnet configurations, `cidr`, WAF rules, API Gateway |
| **Data Protection** | S3 bucket policies, `block_public_access`, versioning, DynamoDB encryption, RDS encryption settings |
| **Backup / Recovery** | Backup plans, snapshot policies, retention settings, cross-region replication |

Adapt search terms to the detected IaC framework (e.g., CDK constructs vs Terraform resource types vs CloudFormation resource names).
```
**Replace with**:
```
Search for security-relevant patterns across these categories: IAM / Access Control, Encryption, Logging / Auditing, Network, Data Protection, Backup / Recovery.

Adapt search terms to the detected IaC framework (CDK constructs, Terraform resource types, or CloudFormation resource names).
```
**Reason**: The per-category resource name examples (iam.Role, aws_iam_*, Effect: Allow/Deny, etc.) are common knowledge; listing them adds token cost without informing behavior. Category names alone are sufficient direction.

---

#### Change 8 — Move Output table before Example section [P3]

**Location**: Lines 25–44, sections `## Example` and `## Output`

The `## Example` section currently appears at lines 25–33 and `## Output` at lines 34–44. Swap their order so Output appears first.

**New section order**:
```markdown
## Output

All output goes to `docs/compliance/`. Create the directory if it doesn't exist.

| File | Purpose |
|---|---|
| `phase1-discovery.md` | Architecture discovery results |
| `phase2-control-mapping.md` | ITSG-33 control mapping with inheritance |
| `phase3-gap-analysis.md` | Gap analysis with risk-rated remediation |
| `assessment-summary.md` | Executive summary with posture dashboard |

Before writing any phase output, read `references/phase-templates.md` for the required format.

## Example

User: "Run an ITSG-33 compliance assessment on this CDK project."

1. Phase 0 — Validate controls against official ITSG-33 sources
2. Phase 1 — Scan `cdk.json`, `lib/`, pipeline definitions; identify AWS services, data residency, trust boundaries; write `docs/compliance/phase1-discovery.md`; checkpoint with user
3. Phase 2 — Map each control from `references/itsg33-controls.md` against discovered architecture; classify inheritance; write `docs/compliance/phase2-control-mapping.md`; checkpoint with user
4. Phase 3 — Produce risk-rated gap entries for unimplemented controls; write `docs/compliance/phase3-gap-analysis.md` and `docs/compliance/assessment-summary.md`
```
**Reason**: The Output table is a reference point readers need before the example makes full sense; presenting it first gives context for what the example's phase outputs produce.

---

#### Change 9 — Add PBMM/TBS to frontmatter negative triggers [P3]

**Location**: Line 3, `description` field in frontmatter — end of the negative trigger clause
**Current**:
```
Do NOT use for FedRAMP, NIST CSF, SOC 2, or non-Canadian compliance frameworks.
```
**Replace with**:
```
Do NOT use for FedRAMP, NIST CSF, SOC 2, PBMM standalone reviews, TBS cloud profile assessments, or other non-ITSG-33 compliance frameworks.
```
**Reason**: Adjacent Canadian frameworks (PBMM, TBS cloud) share vocabulary with ITSG-33 and create low-but-real over-trigger risk in multi-framework GC environments.

---

## Implementation Order

1. **Change 1** (frontmatter `compatibility`) — modifies frontmatter; do first so the file header is settled before body edits.
2. **Change 9** (frontmatter negative triggers) — also frontmatter; batch with Change 1 in the same edit.
3. **Change 8** (swap Output and Example sections) — structural reorder; do before body edits so subsequent line-number references are stable.
4. **Change 2** (remove Canadian jurisdiction rule) — straightforward line deletion in Important Rules.
5. **Change 5** (define "significant changes") — single line replacement in Smart Re-run.
6. **Change 6** (trim Phase 1.1 table) — replaces table block; independent of other body changes.
7. **Change 7** (trim Phase 1.2 table) — replaces table block; independent of other body changes.
8. **Change 3** (remove Phase 0 row from Error Handling) — row deletion; do after body changes so Error Handling table edits are batched.
9. **Change 4** (remove Ambiguous control status row) — row deletion; batch with Change 3 in the same Error Handling table edit.

---

## Verification

After applying all changes:

- [ ] Frontmatter contains `compatibility` field with AWS region and network access note
- [ ] Frontmatter `description` negative trigger list includes PBMM and TBS
- [ ] `## Output` section appears before `## Example` section in the file
- [ ] `## Important Rules` does not contain a "Canadian jurisdiction" bullet
- [ ] `## Smart Re-run` step 2 references IaC file modification and new AWS service as the concrete heuristic
- [ ] Phase 1.1 table contains only IaC framework rows (CDK, Terraform/OpenTofu, CloudFormation/SAM, Crossplane) — Language and CI/CD rows removed
- [ ] Phase 1.2 no longer contains a two-column table with resource name examples — replaced with prose category list
- [ ] Error Handling table has exactly three rows: No IaC files detected, No architecture docs found, Empty or minimal project
- [ ] Total line count remains under 500
- [ ] Run `bash scripts/lint-markdown.sh skills/itsg-assessment/SKILL.md` — no errors
