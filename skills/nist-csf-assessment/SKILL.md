---
name: nist-csf-assessment
description: Map project architecture to NIST Cybersecurity Framework (CSF) 2.0 outcomes. Produces a phased assessment at the subcategory level with cloud service evidence mapping and NIST 800-53 informative references. Always uses the latest published CSF version. Use when asked to assess CSF compliance, run a NIST CSF mapping, check Cybersecurity Framework posture, evaluate CSF 2.0 controls, or perform a cybersecurity framework assessment. Do NOT use for general security audits, penetration testing, ITSG assessments, or FedRAMP assessments — use the dedicated skills for those frameworks.
---

# NIST Cybersecurity Framework (CSF) Assessment

Map a project's architecture and codebase to NIST CSF 2.0 subcategory outcomes. Produces a phased, outcome-based assessment with cloud service evidence mapping, NIST 800-53 informative references, and risk-rated gap analysis. Always assesses to the latest published CSF version — Phase 0 self-updates the reference file if a newer version is available.

## Output

All output goes to `docs/compliance/`. Create the directory if it doesn't exist.

| File | Purpose |
|---|---|
| `phase1-discovery.md` | Architecture discovery results |
| `phase2-csf-mapping.md` | CSF subcategory mapping with cloud service evidence and 800-53 references |
| `phase3-gap-analysis.md` | Gap analysis with risk-rated remediation |
| `assessment-summary.md` | Executive summary with posture by Function |

Before writing any phase output, read the corresponding template in `references/phase-templates.md`.

## Important Rules

- **Evidence over assumption**: Every "Implemented" status must cite cloud service evidence or a file path. If no evidence, mark "Not Implemented" or ask.
- **Always assess to latest CSF version**: Phase 0 self-update is mandatory — never skip it. The reference file version must match the live NIST published version before mapping begins.
- **CSF is outcome-based, not control-catalogue**: Map to what the subcategory outcome achieves, not just whether a control ID exists. Ask: does the project achieve this security outcome?
- **Cloud service evidence mapping**: At the subcategory level, identify which cloud services contribute to achieving that outcome (e.g., GuardDuty/Defender for Cloud/Chronicle -> DE.AE-02, AWS Config/Azure Policy/GCP Asset Inventory -> ID.AM-05).
- **800-53 informative references**: Always include them in Phase 2 output — they connect CSF outcomes to control-catalogue assessments and increase utility for teams also running NIST/FedRAMP assessments.
- **No fabricated subcategories**: Only map subcategories from the version-validated reference file. Never invent or paraphrase subcategory IDs.
- **Phase checkpoints are mandatory**: Always pause between phases for user input.
- **Smart re-run is default**: If previous outputs exist, offer smart re-run first.
- **Framework is jurisdiction-agnostic**: Do not flag regions or data classifications unless the project has explicit requirements. CSF is not limited to any jurisdiction or data classification.

## Error Handling

| Failure | Fallback |
|---|---|
| Phase 0 — cannot reach NIST website | Report the error. Use the version in `references/nist-csf-subcategories.md` as-is. Note the version was not validated against live NIST data in the assessment output. |
| Phase 0 — NIST page returns unexpected format | Do not overwrite the reference file. Report what was received. Proceed with the existing reference file version. |
| Phase 1 — no IaC or security patterns detected | Report that no IaC or security-relevant code was found. Ask the user for architecture context (diagrams, docs, verbal description). Proceed with whatever context is provided. |
| Phase 1 — no architecture docs found | Note the gap. Rely on codebase scanning and user-provided context. |
| Phase 2 — subcategory reference file missing or corrupt | Stop. Report the issue. The user must restore `references/nist-csf-subcategories.md` before assessment can proceed. |

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

If the fetch fails, see Error Handling above.

## Phase 1 — Architecture Discovery

### 1.1 — Detect Tech Stack

Scan the project root for technology indicators:

| Indicator | Detection |
|---|---|
| **Language** | `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle` |
| **IaC** | `cdk.json` (CDK), `*.tf` (Terraform/OpenTofu), `template.yaml` (CloudFormation/SAM), Crossplane `*.yaml`, `Pulumi.yaml`, Bicep `*.bicep` |
| **Containers** | `Dockerfile`, `docker-compose.yml` |
| **CI/CD** | `.github/workflows/`, `buildspec.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/` |

This list is illustrative — scan for any IaC or CI/CD patterns present in the project.

### 1.2 — Analyze Codebase

Scan for security-relevant patterns: IAM/access control, encryption, logging/auditing, network, data protection, backup/recovery, configuration management, incident response.

For IaC-specific detection patterns, adapt scanning to the detected tech stack and cloud provider.

### 1.3 — Read Architecture Docs

Search for `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `README.md`, `cdk.json`, pipeline definitions.

### 1.4 — Produce Output

Write `docs/compliance/phase1-discovery.md` using the Phase 1 template in `references/phase-templates.md`. Include the CSF version from Phase 0 in the header.

### 1.5 — User Checkpoint

Present the Phase 1 summary and ask:

- "Does this accurately represent your architecture?"
- "Any out-of-band security controls not visible in code (SCPs, SSO, manual configs)?"

Wait for confirmation before Phase 2.

## Phase 2 — CSF Subcategory Mapping

Read the subcategory tables from `references/nist-csf-subcategories.md`. For every subcategory across all 6 Functions (GV, ID, PR, DE, RS, RC), determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **Platform Evidence**: Which cloud services or platform configurations provide implementation evidence (e.g., CloudTrail/Azure Monitor/Cloud Audit Logs -> DE.CM-03, GuardDuty/Defender/Chronicle -> DE.AE-02)
3. **Customer Evidence**: Specific file paths, line numbers, resource configurations from the codebase
4. **800-53 References**: The NIST 800-53 Rev 5 informative references for this subcategory (from the reference file)
5. **Notes**: Caveats, assumptions

Write `docs/compliance/phase2-csf-mapping.md` using the Phase 2 template in `references/phase-templates.md`.

### User Checkpoint

Present a Function-level posture breakdown (GV / ID / PR / DE / RS / RC) with Implemented / Partially / Not Implemented counts per Function. Ask: "Any subcategories where you have additional context?" Wait for confirmation before Phase 3.

## Phase 3 — Gap Analysis

For every subcategory marked Not Implemented or Partially Implemented, produce a risk-rated remediation entry. Gaps ordered by risk rating, then effort. Read `references/phase-templates.md` for the gap entry format and risk rating criteria before writing output.

Write:

- `docs/compliance/phase3-gap-analysis.md` — ordered by risk rating, then effort
- `docs/compliance/assessment-summary.md` — executive summary

Executive summary includes:

- CSF version used for assessment
- Posture by Function (Govern / Identify / Protect / Detect / Respond / Recover)
- Function-level shared responsibility summary (which Functions are largely platform-covered vs. customer responsibility)
- Top priority subcategory gaps

Present the executive summary and top recommended actions.

## References

- Subcategory tables: `references/nist-csf-subcategories.md` — read during Phase 2 for the full subcategory list and 800-53 mappings
- Output format templates: `references/phase-templates.md` — read before writing any phase output
- [NIST Cybersecurity Framework (CSF) — Landing Page](https://www.nist.gov/cyberframework)
- [NIST CSF 2.0 Publication (CSWP 29)](https://csrc.nist.gov/pubs/cswp/29/final)
- [CSF 2.0 Reference Tool — Subcategories and Informative References](https://csrc.nist.gov/projects/cybersecurity-framework/filters)
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
