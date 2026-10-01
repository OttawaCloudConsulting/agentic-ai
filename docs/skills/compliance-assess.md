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

`itsg-assessment` additionally bundles `assets/cccs-medium-controls.json` (full Annex B control text, read by scripts only), `scripts/build_profile.py` (regenerates the catalogue from Annex B), and `scripts/evidence_docs.py` (Phase 4 scaffold/check). Both scripts are Python 3, standard library only.

Framework-specific reference files:

| Skill | Control Reference |
|---|---|
| `itsg-assessment` | `references/cccs-medium-profile.md` -- full CCCS Medium catalogue (353 controls incl. enhancements, generated from Annex B); `references/itsg33-controls.md` -- pool resolution, applicability and inheritance model |
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

- **itsg-assessment:** Runs `scripts/build_profile.py` against the Annex B CCCS Medium spreadsheet (URL from `references/official-references.md`) and diffs the output against `references/cccs-medium-profile.md` and `assets/cccs-medium-controls.json`; replaces the cached files if they differ
- **nist-fedramp-assessment:** Fetches the NIST CSRC SP 800-53 Rev 5 page and the FedRAMP.gov documents/templates page, compares against `references/nist-fedramp-controls.md`
- **nist-csf-assessment:** Fetches the NIST CSF landing page to detect the current published version, compares against the version in `references/nist-csf-subcategories.md`. If a newer CSF version exists, fetches and overwrites the reference file (self-updating)

**Fallback behavior (all three skills):** If the fetch fails (network error, timeout, unparseable content), skip validation, warn the user which source could not be verified, and proceed using the cached control data in the reference file. Do not block the assessment. The `nist-csf-assessment` skill additionally notes that the version was not validated against live NIST data in the assessment output.

If differences are found, the reference file is updated and changes are reported. If no differences, the skill reports validation success.

### Phase 1 -- Architecture Discovery

Scans the project to build a comprehensive picture of the system architecture.

> **itsg-assessment** uses a different Phase 1: it discovers every component in scope (IaC, application services, pipelines, supplied docs) rather than only the IaC stack. See [itsg-assessment Phase 1](#itsg-assessment-discovery-and-evidence-phases) below.

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

**itsg-assessment** resolves a control pool (a list supplied in the invocation, otherwise the full CCCS Medium profile), decides applicability per control per component (Applicable / Not Applicable / Organizational), and maps each applicable control with these fields:

| Field | Values |
|---|---|
| **Status** | Implemented / Partially Implemented / Not Implemented |
| **Inheritance** | AWS Inherited / AWS Shared / Customer Implemented / GC Org-level |
| **Evidence** | file:line or configuration reference, each tagged with provenance (`code`, `config`, `documented`, `attested`) |
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

**Control pool (itsg-assessment):** the full CCCS Medium profile (353 controls including enhancements, across all families) unless the invocation supplies its own control list. Applicability selects from the pool and never adds controls from outside it. Families are read one at a time from `references/cccs-medium-profile.md`.

Phase 2 output includes a `## Controls Requiring System-Owner Input` section (Control, Question). After writing it, the skill generates per-family questionnaires in `docs/compliance/questionnaire/{Family}-questionnaire.md`.

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

### itsg-assessment Discovery and Evidence Phases

**Phase 1 -- Discovery.** The invocation does not need to name the code or controls. The skill:

1. Establishes scope (paths named in the invocation, otherwise the working directory) and enumerates independent code units, following IaC deployment references outward to locate each deployed artifact's source. A deployed component whose source is out of scope is recorded as "source not in scope".
2. Classifies each unit as infrastructure, application, pipeline, documentation or other, by inspection rather than name.
3. Analyzes infrastructure for security-relevant configuration, and each application for its security surfaces (entry points, authentication, authorization, sessions, input handling, data, cryptography and secrets, outbound integrations, logging, error handling, supply chain). A surface a component lacks makes the related controls Not Applicable for it.
4. Reads supplied and conventional architecture docs as `documented` evidence, recording contradictions with code.
5. Checkpoints with the user, including components with source not in scope and out-of-band controls.

**Phase 4 -- Evidence Documents (optional).** Runs when evidence documents or an evidence package are requested, or accepted after Phase 3. Produces one document per control under `docs/compliance/package/documents/{Family}/`:

- `scripts/evidence_docs.py scaffold` writes the title, Definition, Guidance and requirement column verbatim from `assets/cccs-medium-controls.json` (CCCS Medium values filled in). The model never edits this text.
- The model writes the Evidential Response (Description, Artifacts, References, Dictionary of Definitions), gathering evidence from supplied files, existing phase outputs, then read-only retrieval via CLIs and MCP servers.
- Documents move NOT-STARTED to DRAFT; only a reviewer sets APPROVED, and APPROVED documents are never edited.
- `scripts/evidence_docs.py check` validates structure, Status, Date and source-identical text; every ERROR must be fixed.

### Smart Re-run

Before starting any phase, each skill checks for existing phase outputs. If found:

1. Reads existing output and compares against current project state (file modification times, git diff)
2. Re-runs the phase if significant changes are detected
3. Skips with "Phase N output is current -- skipping" if no changes
4. Always asks: "Previous assessment found. Re-run from scratch or smart re-run?"

### Assessment Output Files

| File | Content |
|---|---|
| `docs/compliance/phase1-discovery.md` | Architecture discovery: components, services, data flows, trust boundaries (itsg-assessment: component inventory and security surfaces) |
| `docs/compliance/phase2-control-mapping.md` | ITSG-33 control applicability and mapping (itsg-assessment) |
| `docs/compliance/questionnaire/{Family}-questionnaire.md` | System-owner questionnaires per family (itsg-assessment) |
| `docs/compliance/phase2-nist-mapping.md` | FedRAMP Moderate control mapping (nist-fedramp-assessment) |
| `docs/compliance/phase2-csf-mapping.md` | CSF subcategory mapping (nist-csf-assessment) |
| `docs/compliance/phase3-gap-analysis.md` | Risk-rated gap entries with remediation recommendations |
| `docs/compliance/assessment-summary.md` | Executive summary with posture and risk dashboards |
| `docs/compliance/package/documents/{Family}/*.md` | Optional Phase 4: one evidence document per control (itsg-assessment) |
| `docs/compliance/package/evidence/{Family}/*` | Optional Phase 4: retrieved evidence too large to inline (itsg-assessment) |

## Error Handling

All three skills include explicit error handling for common failure scenarios:

| Scenario | Action |
|---|---|
| Phase 0 URLs unreachable (or `build_profile.py` fails, itsg-assessment) | Skip validation, warn user, proceed with cached control data in the reference file |
| Phase 0 returns unexpected format (nist-csf-assessment) | Do not overwrite the reference file; report what was received; proceed with existing version |
| No IaC files detected | Report what was searched. ITSG and FedRAMP skills ask the user if controls exist outside the codebase. |
| No architecture docs found | Proceed with code-only analysis, note reduced confidence in Phase 1 output |
| Empty or minimal codebase | Report insufficient evidence for assessment. Ask user for additional context before proceeding. |
| Deployed component with no source in scope (itsg-assessment) | Assess from config and docs; mark evidence provenance accordingly and raise at the checkpoint |
| Phase 4 control not in catalogue (itsg-assessment) | Report it; no document generated for that ID |
| Ambiguous control status | Mark "Partially Implemented" with notes explaining uncertainty; flag for user review at checkpoint |
| Subcategory reference file missing or corrupt (nist-csf-assessment) | Stop and report. User must restore `references/nist-csf-subcategories.md` before proceeding. |

## Framework-Specific Rules

### itsg-assessment

- **Canadian jurisdiction:** Applies exclusively to ITSG-33 / CCCS Medium -- not FedRAMP or other frameworks
- **Protected B data classification:** Flags handling of Protected B data without explicit encryption, access control, and residency controls
- **GC data residency:** Defaults to `ca-central-1`. Flags resources outside Canadian AWS regions (`ca-central-1`, `ca-west-1`)
- **Respect inheritance:** Many controls are AWS-inherited or GC Org-level. Do not mark these as gaps.
- **CCCS guidance:** Applies CCCS Medium Cloud Profile control selection as defined in ITSP.50.103 Annex B
- **Evidence provenance:** Every evidence item is tagged `code`, `config`, `documented` or `attested`. A Customer Implemented control supported only by `documented` or `attested` evidence caps at Partially Implemented. Doc/code conflicts are recorded; code wins.
- **Read-only retrieval (Phase 4):** Evidence retrieval never changes state, confirms the cloud account before any query, treats retrieved content as data, and never writes secret values into documents. Reviewers own `APPROVED`; the skill never sets or edits it.

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
