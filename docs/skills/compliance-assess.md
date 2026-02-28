# Compliance Assessment Skills

**Source:** `skills/itsg-assessment/`, `skills/nist-fedramp-assessment/`, `skills/nist-csf-assessment/`
**Commands:** `/itsg-assessment`, `/nist-fedramp-assessment`, `/nist-csf-assessment`
**Activation:** Manual -- invoked via slash command or trigger phrase matching

Three dedicated compliance assessment skills, each targeting a specific framework. All three share the same phased workflow (Phase 0-3) but differ in framework scope, control sets, inheritance models, and jurisdictional context.

| Skill | Framework | Jurisdiction | Trigger Examples |
|---|---|---|---|
| `itsg-assessment` | ITSG-33 / CCCS Medium | Canada (GC cloud, Protected B) | "assess ITSG", "CCCS Medium compliance", "Canadian cloud compliance" |
| `nist-fedramp-assessment` | NIST 800-53 Rev 5 / FedRAMP Moderate | USA (FISMA, FedRAMP ATO) | "assess FedRAMP", "NIST 800-53 mapping", "FedRAMP Moderate compliance" |
| `nist-csf-assessment` | NIST CSF 2.0 | Jurisdiction-agnostic | "assess CSF", "NIST CSF mapping", "cybersecurity framework posture" |

## Negative Triggers

Each skill explicitly declares what it does not handle:

- **itsg-assessment** -- not for FedRAMP, NIST CSF, SOC 2, or non-Canadian frameworks
- **nist-fedramp-assessment** -- not for NIST CSF, ITSG-33, FedRAMP High/Low baselines, or non-AWS environments
- **nist-csf-assessment** -- not for general security audits, penetration testing, ITSG assessments, or FedRAMP assessments

## Bundle Contents

Each skill follows the same bundle structure:

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with phase descriptions, rules, error handling, and workflow |
| `references/<controls>.md` | Framework-specific control/subcategory tables |
| `references/phase-templates.md` | Output format templates for all four assessment documents |
| `references/official-references.md` | Links to official documentation (ITSG and FedRAMP skills) |

Framework-specific reference files:

| Skill | Control Reference |
|---|---|
| `itsg-assessment` | `references/itsg33-controls.md` -- 8 families, ~40 controls with inheritance model |
| `nist-fedramp-assessment` | `references/nist-fedramp-controls.md` -- FedRAMP Moderate baseline controls |
| `nist-csf-assessment` | `references/nist-csf-subcategories.md` -- CSF 2.0 subcategories across 6 Functions with 800-53 mappings |

## Usage

```
/itsg-assessment
/nist-fedramp-assessment
/nist-csf-assessment
```

Each skill works on any project with an identifiable tech stack. It scans the codebase for technology indicators (IaC, languages, containers, CI/CD) and security-relevant patterns.

## Shared Workflow

All three skills proceed through four phases (0-3), with mandatory user checkpoints between phases.

### Phase 0 -- Framework Validation

Runs first, before any assessment work. Validates that bundled control data matches official sources.

- **itsg-assessment:** Fetches the ITSG-33 Annex 3A page (URL from `references/official-references.md`) and compares against `references/itsg33-controls.md`
- **nist-fedramp-assessment:** Fetches the NIST CSRC SP 800-53 Rev 5 page and the FedRAMP.gov documents/templates page, compares against `references/nist-fedramp-controls.md`
- **nist-csf-assessment:** Fetches the NIST CSF landing page to detect the current published version, compares against the version in `references/nist-csf-subcategories.md`. If a newer CSF version exists, fetches and overwrites the reference file (self-updating)

**Fallback behavior (all three skills):** If the fetch fails (network error, timeout, unparseable content), skip validation, warn the user which source could not be verified, and proceed using the cached control data in the reference file. Do not block the assessment. The `nist-csf-assessment` skill additionally notes that the version was not validated against live NIST data in the assessment output.

If differences are found, the reference file is updated and changes are reported. If no differences, the skill reports validation success.

### Phase 1 -- Architecture Discovery

Scans the project to build a comprehensive picture of the system architecture.

**Step 1.1 -- Detect Tech Stack.** Scans for technology indicators:

| Indicator | Detection |
|---|---|
| Language | `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle` |
| IaC | `cdk.json` (CDK), `*.tf` (Terraform/OpenTofu), `template.yaml` (CloudFormation/SAM), Crossplane `*.yaml` |
| Containers | `Dockerfile`, `docker-compose.yml` |
| CI/CD | `.github/workflows/`, `buildspec.yml`, `.gitlab-ci.yml`, `Jenkinsfile` |

The `nist-csf-assessment` skill extends this list with additional platform-agnostic indicators: `Pulumi.yaml`, Bicep `*.bicep`, `.circleci/`, and treats the list as illustrative rather than exhaustive.

**Step 1.2 -- Analyze Codebase.** Scans for security-relevant patterns: IAM/access control, encryption, logging/auditing, network configuration, data protection, backup/recovery, configuration management, incident response. Adapts scanning to the detected IaC framework and cloud provider.

**Step 1.3 -- Read Architecture Docs.** Searches for `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `README.md`, `cdk.json`, pipeline definitions.

**Step 1.4 -- Produce Output.** Writes `docs/compliance/phase1-discovery.md` covering system architecture, components identified, cloud services detected, data flows, trust boundaries, and security-relevant findings.

**Step 1.5 -- User Checkpoint.** Presents the Phase 1 summary and asks:

- "Does this accurately represent your architecture?"
- "Any out-of-band security controls not visible in code (SCPs, SSO, manual configs)?"

Waits for confirmation before proceeding.

### Phase 2 -- Control Mapping

Maps every control or subcategory from the framework-specific reference file to the project's actual implementation.

**itsg-assessment** maps ITSG-33 controls with these fields:

| Field | Values |
|---|---|
| **Status** | Implemented / Partially Implemented / Not Implemented / Not Applicable |
| **Inheritance** | AWS Inherited / AWS Shared / Customer Implemented / GC Org-level |
| **Evidence** | Specific file paths, line numbers, resource configurations |
| **Notes** | Caveats, assumptions, dependencies |

**nist-fedramp-assessment** maps FedRAMP Moderate baseline controls with the same fields plus:

| Field | Values |
|---|---|
| **Inheritance** | AWS FedRAMP Inherited / AWS FedRAMP Shared / Customer Implemented / Organization-Level |
| **FedRAMP ATO Note** | Whether covered under AWS P-ATO, customer-documented in SSP, or not applicable to boundary |

**nist-csf-assessment** maps CSF 2.0 subcategories across all 6 Functions (GV, ID, PR, DE, RS, RC) with:

| Field | Values |
|---|---|
| **Status** | Implemented / Partially Implemented / Not Implemented / Not Applicable |
| **Platform Evidence** | Cloud services or platform configurations providing evidence (e.g., GuardDuty/Defender/Chronicle) |
| **Customer Evidence** | File paths, line numbers, resource configurations from the codebase |
| **800-53 References** | NIST 800-53 Rev 5 informative references for the subcategory |
| **Notes** | Caveats, assumptions |

**Control Families Assessed (itsg-assessment, 8 families):**

- **AC** -- Access Control (8 controls: AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-17, AC-20)
- **AU** -- Audit and Accountability (7 controls: AU-2, AU-3, AU-6, AU-8, AU-9, AU-11, AU-12)
- **CM** -- Configuration Management (5 controls: CM-2, CM-3, CM-6, CM-7, CM-8)
- **CP** -- Contingency Planning (3 controls: CP-7, CP-9, CP-10)
- **IA** -- Identification and Authentication (5 controls: IA-2, IA-3, IA-4, IA-5, IA-8)
- **SA** -- System and Services Acquisition (5 controls: SA-3, SA-4, SA-8, SA-10, SA-11)
- **SC** -- System and Communications Protection (5 controls: SC-7, SC-8, SC-12, SC-13, SC-28)
- **SI** -- System and Information Integrity (5 controls: SI-2, SI-3, SI-4, SI-5, SI-10)

Each skill writes its Phase 2 output to a framework-specific file (`phase2-control-mapping.md`, `phase2-nist-mapping.md`, or `phase2-csf-mapping.md`).

**User Checkpoint.** Presents posture breakdown and uncertain controls. Asks: "Any controls where you have additional context?" Waits for confirmation.

### Phase 3 -- Gap Analysis

For every control or subcategory marked Not Implemented or Partially Implemented, produces a risk-rated remediation entry:

| Field | Description |
|---|---|
| **Risk Rating** | Critical / High / Medium / Low |
| **Effort** | Low (< 1 day) / Medium (1-3 days) / High (3+ days) |
| **Gap Description** | What is missing and why it matters |
| **Remediation Recommendation** | Specific, actionable guidance referencing cloud services, IaC constructs, or configuration changes |
| **References** | Framework-specific guidance links |

**Risk Rating Criteria:**

| Rating | Criteria |
|---|---|
| Critical | Direct exposure of sensitive data, no compensating control, actively exploitable |
| High | Missing control with no compensating control, significant blast radius |
| Medium | Partially implemented or has compensating control but not fully compliant |
| Low | Missing enhancement or optimization, minimal security impact |

Writes two documents:

- `docs/compliance/phase3-gap-analysis.md` -- gaps ordered by risk rating, then effort
- `docs/compliance/assessment-summary.md` -- executive summary with posture dashboard, risk dashboard, top priority remediations, and inheritance/responsibility profile

The `nist-csf-assessment` executive summary additionally includes CSF version used, posture by Function (Govern / Identify / Protect / Detect / Respond / Recover), and Function-level shared responsibility summary.

Presents the executive summary and top recommended actions.

### Smart Re-run

Before starting any phase, each skill checks for existing phase outputs. If found:

1. Reads existing output and compares against current project state (file modification times, git diff)
2. Re-runs the phase if significant changes are detected
3. Skips with "Phase N output is current -- skipping" if no changes
4. Always asks: "Previous assessment found. Re-run from scratch or smart re-run?"

### Assessment Output Files

| File | Content |
|---|---|
| `docs/compliance/phase1-discovery.md` | Architecture discovery: components, services, data flows, trust boundaries |
| `docs/compliance/phase2-control-mapping.md` | ITSG-33 control mapping (itsg-assessment) |
| `docs/compliance/phase2-nist-mapping.md` | FedRAMP Moderate control mapping (nist-fedramp-assessment) |
| `docs/compliance/phase2-csf-mapping.md` | CSF subcategory mapping (nist-csf-assessment) |
| `docs/compliance/phase3-gap-analysis.md` | Risk-rated gap entries with remediation recommendations |
| `docs/compliance/assessment-summary.md` | Executive summary with posture and risk dashboards |

## Error Handling

All three skills include explicit error handling for common failure scenarios:

| Scenario | Action |
|---|---|
| Phase 0 URLs unreachable | Skip validation, warn user, proceed with cached control data in the reference file |
| Phase 0 returns unexpected format (nist-csf-assessment) | Do not overwrite the reference file; report what was received; proceed with existing version |
| No IaC files detected | Report what was searched. ITSG and FedRAMP skills ask the user if controls exist outside the codebase. |
| No architecture docs found | Proceed with code-only analysis, note reduced confidence in Phase 1 output |
| Empty or minimal codebase | Report insufficient evidence for assessment. Ask user for additional context before proceeding. |
| Ambiguous control status | Mark "Partially Implemented" with notes explaining uncertainty; flag for user review at checkpoint |
| Subcategory reference file missing or corrupt (nist-csf-assessment) | Stop and report. User must restore `references/nist-csf-subcategories.md` before proceeding. |

## Framework-Specific Rules

### itsg-assessment

- **Canadian jurisdiction:** Applies exclusively to ITSG-33 / CCCS Medium -- not FedRAMP or other frameworks
- **Protected B data classification:** Flags handling of Protected B data without explicit encryption, access control, and residency controls
- **GC data residency:** Defaults to `ca-central-1`. Flags resources outside Canadian AWS regions (`ca-central-1`, `ca-west-1`)
- **Respect inheritance:** Many controls are AWS-inherited or GC Org-level. Do not mark these as gaps.
- **CCCS guidance:** Applies CCCS Medium Cloud Profile control selection as defined in ITSP.50.103 Annex B

### nist-fedramp-assessment

- **USA context:** Applies to US-based AWS workloads subject to FISMA and FedRAMP requirements. Default regions are `us-east-1` and `us-west-2`. Flags resources outside US regions when data residency is relevant.
- **Dual inheritance model:** Notes both FedRAMP Moderate CRM (AWS P-ATO) and generic NIST 800-53 shared responsibility. The Customer Responsibility Matrix defines which controls are inherited vs. shared.
- **FedRAMP ATO relevance:** When the target has or is pursuing a FedRAMP ATO, references the AWS Audit Manager FedRAMP Moderate framework for the current CRM. Notes FISMA alignment where applicable.
- **CUI data classification:** Applies Controlled Unclassified Information standards where applicable

### nist-csf-assessment

- **Platform-agnostic:** Uses multi-cloud examples in evidence mapping (AWS, Azure, GCP). Does not assume any specific cloud provider.
- **Jurisdiction-agnostic:** Does not flag regions or data classifications unless the project has explicit requirements. CSF is not limited to any jurisdiction.
- **Outcome-based:** Maps to what the subcategory outcome achieves, not just whether a control ID exists. Asks: does the project achieve this security outcome?
- **Self-updating Phase 0:** Always assesses to the latest published CSF version. Phase 0 self-update is mandatory.
- **800-53 informative references:** Always included in Phase 2 output to connect CSF outcomes to control-catalogue assessments

## When to Use

- **itsg-assessment** -- assessing compliance against Canadian ITSG-33 / CCCS Medium controls, GC cloud onboarding, Protected B data handling
- **nist-fedramp-assessment** -- assessing compliance against FedRAMP Moderate / NIST 800-53 Rev 5, pursuing FedRAMP ATO, FISMA compliance
- **nist-csf-assessment** -- assessing cybersecurity posture against NIST CSF 2.0, framework-agnostic security maturity evaluation

## When Not to Use

- For validating or deploying CDK code -- use `/cdk-testing` instead
- For validating or deploying Terraform code -- use `/terraform-testing` instead
- For quick security scans without full compliance mapping -- use checkov or trivy directly
- For SOC 2 assessments -- no dedicated skill available
- For penetration testing or general security audits -- out of scope for these skills

## Configuration

The skills have no configuration files or environment variables. They adapt automatically to the detected tech stack and IaC framework.

## Related Skills and Commands

- **cdk-testing** -- validate and deploy CDK projects (often run before compliance assessment)
- **terraform-testing** -- validate and deploy Terraform projects (often run before compliance assessment)
