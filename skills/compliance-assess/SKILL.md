---
name: compliance-assess
description: Map project architecture to ITSG-33 / CCCS Medium Cloud Profile security controls. Produces a phased compliance assessment with control inheritance and risk-rated gap analysis. Use when asked to assess compliance, run a security control mapping, check ITSG-33 controls, evaluate CCCS Medium posture, or perform a compliance audit.
---

# ITSG-33 / CCCS Medium Compliance Assessment

Map a project's architecture and codebase to Canadian ITSG-33 security controls (CCCS Medium Cloud Profile). Produces a phased assessment with AWS shared responsibility inheritance, gap analysis, and risk-rated remediation guidance.

## Output

All output goes to `docs/compliance/`. Create the directory if it doesn't exist.

| File | Purpose |
|---|---|
| `phase1-discovery.md` | Architecture discovery results |
| `phase2-control-mapping.md` | ITSG-33 control mapping with inheritance |
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

1. Fetch the ITSG-33 Annex 3A page to verify control families and IDs
2. Compare against the control tables in references/itsg33-controls.md
3. If differences found: update references/itsg33-controls.md and report changes
4. If no differences: report "Phase 0 complete — all controls match official sources"

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

Read the control families from references/itsg33-controls.md. For every control, determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **Inheritance**: AWS Inherited / AWS Shared / Customer Implemented / GC Org-level
3. **Evidence**: Specific file paths, line numbers, resource configurations
4. **Notes**: Caveats, assumptions, dependencies

Write `docs/compliance/phase2-control-mapping.md` using the template in references/phase-templates.md.

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
- **Respect inheritance**: Many controls are AWS-inherited or org-level. Don't mark these as gaps.
- **Canadian context**: Data residency defaults to ca-central-1. Flag resources outside Canadian regions.
- **No fabricated controls**: Only map controls from ITSG-33. Verify against official sources when uncertain.
- **Phase checkpoints are mandatory**: Always pause between phases for user input.
- **Smart re-run is default**: If previous outputs exist, offer smart re-run first.

## References

- Control family tables: references/itsg33-controls.md
- Output format templates: references/phase-templates.md
- Official documentation links: references/official-references.md
