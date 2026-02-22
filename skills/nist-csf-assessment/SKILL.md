---
name: nist-csf-assessment
description: Map project architecture to NIST Cybersecurity Framework (CSF) 2.0 outcomes. Produces a phased assessment at the subcategory level with AWS service evidence mapping and NIST 800-53 informative references. Always uses the latest published CSF version. Use when asked to assess CSF compliance, run a NIST CSF mapping, check Cybersecurity Framework posture, evaluate CSF 2.0 controls, or perform a cybersecurity framework assessment.
---

# NIST Cybersecurity Framework (CSF) Assessment

Map a project's architecture and codebase to NIST CSF 2.0 subcategory outcomes. Produces a phased, outcome-based assessment with AWS service evidence mapping, NIST 800-53 informative references, and risk-rated gap analysis. Always assesses to the latest published CSF version — Phase 0 self-updates the reference file if a newer version is available.

## Output

All output goes to `docs/compliance/`. Create the directory if it doesn't exist.

| File | Purpose |
|---|---|
| `phase1-discovery.md` | Architecture discovery results |
| `phase2-csf-mapping.md` | CSF subcategory mapping with AWS evidence and 800-53 references |
| `phase3-gap-analysis.md` | Gap analysis with risk-rated remediation |
| `assessment-summary.md` | Executive summary with posture by Function |

For output format templates, see references/phase-templates.md.

## Smart Re-run

Before starting any phase, check if previous phase outputs exist. If they do:

1. Read the existing output and compare against current project state (file modification times, git diff)
2. If significant changes detected, re-run that phase
3. If no changes, report "Phase N output is current — skipping"
4. Always ask: "Previous assessment found. Re-run from scratch or smart re-run?"

## Phase 0 — Framework Version Check (SELF-UPDATING)

Runs first, before any assessment work. Validates and updates the CSF reference to the latest published version.

1. Fetch the NIST CSF landing page (`https://www.nist.gov/cyberframework`) to detect the current published version number
2. Read the version recorded in `references/nist-csf-subcategories.md` (look for the `<!-- version: X.X -->` comment at the top of the file)
3. Compare versions:
   - If versions match: report "Phase 0 complete — CSF X.X is current"
   - If NIST has a newer version: fetch the updated subcategory list from the NIST CSRC CSF reference tool (`https://csrc.nist.gov/projects/cybersecurity-framework/filters`), overwrite `references/nist-csf-subcategories.md` with the new content (preserving the `<!-- version: X.X -->` header and table format), report "Updated CSF reference from X.X to Y.Y"
4. Report which CSF version is being used for this assessment before proceeding

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

Write `docs/compliance/phase1-discovery.md` using the template in references/phase-templates.md. Include the CSF version from Phase 0 in the header.

### 1.5 — User Checkpoint

Present the Phase 1 summary and ask:

- "Does this accurately represent your architecture?"
- "Any out-of-band security controls not visible in code (SCPs, SSO, manual configs)?"

Wait for confirmation before Phase 2.

## Phase 2 — CSF Subcategory Mapping

Read the subcategory tables from `references/nist-csf-subcategories.md`. For every subcategory across all 6 Functions (GV, ID, PR, DE, RS, RC), determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **AWS Evidence**: Which AWS services or configurations provide implementation evidence (e.g., CloudTrail → DE.CM-03, GuardDuty → DE.AE-02)
3. **Customer Evidence**: Specific file paths, line numbers, resource configurations from the codebase
4. **800-53 References**: The NIST 800-53 Rev 5 informative references for this subcategory (from the reference file)
5. **Notes**: Caveats, assumptions

Write `docs/compliance/phase2-csf-mapping.md` using the template in references/phase-templates.md.

### User Checkpoint

Present a Function-level posture breakdown (GV / ID / PR / DE / RS / RC) with Implemented / Partially / Not Implemented counts per Function. Ask: "Any subcategories where you have additional context?" Wait for confirmation before Phase 3.

## Phase 3 — Gap Analysis

For every subcategory marked Not Implemented or Partially Implemented, produce a risk-rated remediation entry. Gaps ordered by risk rating, then effort. See references/phase-templates.md for the gap entry format and risk rating criteria.

Write:

- `docs/compliance/phase3-gap-analysis.md` — ordered by risk rating, then effort
- `docs/compliance/assessment-summary.md` — executive summary

Executive summary includes:

- CSF version used for assessment
- Posture by Function (Govern / Identify / Protect / Detect / Respond / Recover)
- Function-level AWS shared responsibility summary (which Functions are largely platform-covered vs. customer responsibility)
- Top priority subcategory gaps

Present the executive summary and top recommended actions.

## Important Rules

- **Evidence over assumption**: Every "Implemented" status must cite AWS service evidence or a file path. If no evidence, mark "Not Implemented" or ask.
- **Always assess to latest CSF version**: Phase 0 self-update is mandatory — never skip it. The reference file version must match the live NIST published version before mapping begins.
- **CSF is outcome-based, not control-catalogue**: Map to what the subcategory outcome achieves, not just whether a control ID exists. Ask: does the project achieve this security outcome?
- **AWS evidence mapping**: At the subcategory level, identify which AWS services contribute to achieving that outcome (e.g., GuardDuty → DE.AE-02, AWS Config → ID.AM-05).
- **800-53 informative references**: Always include them in Phase 2 output — they connect CSF outcomes to control-catalogue assessments and increase the skill's utility for teams also running NIST/FedRAMP assessments.
- **No fabricated subcategories**: Only map subcategories from the version-validated reference file. Never invent or paraphrase subcategory IDs.
- **Phase checkpoints are mandatory**: Always pause between phases for user input.
- **Smart re-run is default**: If previous outputs exist, offer smart re-run first.
- **Framework is jurisdiction-agnostic**: Do not flag regions or data classifications unless the project has explicit requirements. CSF is not limited to any jurisdiction or data classification.

## References

- Subcategory tables: references/nist-csf-subcategories.md
- Output format templates: references/phase-templates.md
- Official documentation links: references/official-references.md
