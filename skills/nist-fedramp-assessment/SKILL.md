---
name: nist-fedramp-assessment
description: Map project architecture to NIST SP 800-53 Rev 5 / FedRAMP Moderate security controls. Produces a phased compliance assessment with AWS shared responsibility inheritance and risk-rated gap analysis. Use when asked to assess FedRAMP compliance, run a NIST 800-53 control mapping, check FedRAMP Moderate controls, evaluate FedRAMP posture, perform a NIST assessment, or assess for FedRAMP ATO readiness.
---

# NIST SP 800-53 / FedRAMP Moderate Compliance Assessment

Map a project's architecture and codebase to the FedRAMP Moderate baseline (NIST SP 800-53 Rev 5). Produces a phased assessment with AWS shared responsibility inheritance using the FedRAMP dual inheritance model, gap analysis, and risk-rated remediation guidance.

## Output

All output goes to `docs/compliance/`. Create the directory if it doesn't exist.

| File | Purpose |
|---|---|
| `phase1-discovery.md` | Architecture discovery results |
| `phase2-nist-mapping.md` | FedRAMP Moderate control mapping with inheritance |
| `phase3-gap-analysis.md` | Gap analysis with risk-rated remediation |
| `assessment-summary.md` | Executive summary with posture dashboard |

For output format templates, see references/phase-templates.md.

## Smart Re-run

Before starting any phase, check if previous phase outputs exist. If they do:

1. Read the existing output and compare against current project state (file modification times, git diff)
2. If significant changes detected, re-run that phase
3. If no changes, report "Phase N output is current — skipping"
4. Always ask: "Previous assessment found. Re-run from scratch or smart re-run?"

## Phase 0 — Framework Validation

Runs first, before any assessment work. Validates control data against official sources.

1. Fetch the NIST CSRC SP 800-53 Rev 5 page (`https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final`) to verify control families and IDs
2. Fetch the FedRAMP.gov documents and templates page (`https://www.fedramp.gov/documents-templates/`) to verify the FedRAMP Moderate baseline control selection
3. Compare both sources against the control tables in references/nist-fedramp-controls.md
4. If differences found: update references/nist-fedramp-controls.md and report changes
5. If no differences: report "Phase 0 complete — all controls match official sources"

## Phase 1 — Architecture Discovery

### 1.1 — Detect Tech Stack

Scan the project root for technology indicators:

| Indicator | Detection |
|---|---|
| **Language** | `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle` |
| **IaC** | `cdk.json` (CDK), `*.tf` (Terraform/OpenTofu), `template.yaml` (CloudFormation/SAM), Crossplane `*.yaml` |
| **Containers** | `Dockerfile`, `docker-compose.yml` |
| **CI/CD** | `.github/workflows/`, `buildspec.yml`, `.gitlab-ci.yml`, `Jenkinsfile` |

### 1.2 — Analyze Codebase

Scan for security-relevant patterns: IAM/access control, encryption, logging/auditing, network, data protection, backup/recovery, configuration management, incident response.

For IaC-specific detection patterns (CDK, Terraform, CloudFormation, Crossplane), adapt scanning to the detected tech stack.

### 1.3 — Read Architecture Docs

Search for `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `README.md`, `cdk.json`, pipeline definitions.

### 1.4 — Produce Output

Write `docs/compliance/phase1-discovery.md` using the template in references/phase-templates.md.

### 1.5 — User Checkpoint

Present the Phase 1 summary and ask:

- "Does this accurately represent your architecture?"
- "Any out-of-band security controls not visible in code (SCPs, SSO, manual configs)?"

Wait for confirmation before Phase 2.

## Phase 2 — Control Mapping

Read the control families from references/nist-fedramp-controls.md. For every control, determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **Inheritance**: AWS FedRAMP Inherited / AWS FedRAMP Shared / Customer Implemented / Organization-Level
3. **Evidence**: Specific file paths, line numbers, resource configurations
4. **Notes**: Caveats, assumptions, dependencies
5. **FedRAMP ATO Note**: Whether the control is covered under AWS P-ATO (FedRAMP Moderate), customer-documented in SSP, or not applicable to the authorization boundary

Write `docs/compliance/phase2-nist-mapping.md` using the template in references/phase-templates.md.

### User Checkpoint

Present posture breakdown and uncertain controls. Ask: "Any controls where you have additional context?" Wait for confirmation before Phase 3.

## Phase 3 — Gap Analysis

For every control marked Not Implemented or Partially Implemented, produce a risk-rated remediation entry. See references/phase-templates.md for the gap entry format and risk rating criteria.

Write:

- `docs/compliance/phase3-gap-analysis.md` — ordered by risk rating, then effort
- `docs/compliance/assessment-summary.md` — executive summary

Present the executive summary and top recommended actions.

## Important Rules

- **Evidence over assumption**: Every "Implemented" status must cite a file path or pattern. If no evidence, mark "Not Implemented" or ask.
- **Don't inflate compliance**: When uncertain, mark "Partially Implemented" with notes.
- **Dual inheritance model**: Note both FedRAMP Moderate CRM (AWS P-ATO) AND generic NIST 800-53 shared responsibility. AWS maintains a FedRAMP Moderate P-ATO; the Customer Responsibility Matrix (CRM) defines which controls are inherited vs. shared. For non-FedRAMP NIST assessments, apply generic shared responsibility.
- **USA context**: This skill applies to US-based workloads subject to FISMA and FedRAMP requirements. Default AWS regions are us-east-1 and us-west-2. Flag resources deployed outside US regions when data residency is relevant. Apply CUI (Controlled Unclassified Information) data classification standards where applicable.
- **FedRAMP ATO relevance**: When the target has or is pursuing a FedRAMP ATO, reference the AWS Audit Manager FedRAMP Moderate framework for the current CRM. Note FISMA alignment where applicable.
- **No fabricated controls**: Only map controls from the FedRAMP Moderate baseline in references/nist-fedramp-controls.md. Verify against official sources when uncertain.
- **Phase checkpoints are mandatory**: Always pause between phases for user input.
- **Smart re-run is default**: If previous outputs exist, offer smart re-run first.

## References

- Control family tables: references/nist-fedramp-controls.md
- Output format templates: references/phase-templates.md
- Official documentation links: references/official-references.md
