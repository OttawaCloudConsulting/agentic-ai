# Compliance Assess

**Source:** `skills/compliance-assess/`
**Command:** `/compliance-assess`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "assess compliance", "run security control mapping", "check ITSG-33 controls", "evaluate CCCS Medium posture", "compliance audit")

## Description

Maps a project's architecture and codebase to Canadian ITSG-33 security controls under the CCCS Medium Cloud Profile. Produces a multi-phase compliance assessment including architecture discovery, control mapping with AWS shared responsibility inheritance, risk-rated gap analysis, and an executive summary with remediation guidance. All output is written to `docs/compliance/`.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with phase descriptions, rules, and workflow |
| `references/itsg33-controls.md` | Complete ITSG-33 control family tables (8 families, ~40 controls) with descriptions, applicability notes, and the control inheritance model |
| `references/phase-templates.md` | Output format templates for all four assessment documents |
| `references/official-references.md` | Links to official Canadian Government, NIST, and AWS compliance documentation |

## Usage

```
/compliance-assess
```

The skill works on any project with an identifiable tech stack. It scans the codebase for technology indicators (IaC, languages, containers, CI/CD) and security-relevant patterns.

## Workflow

The assessment proceeds through four phases (0-3), with mandatory user checkpoints between phases.

### Phase 0 — Framework Validation

Runs first, before any assessment work. Validates that the bundled control data matches official sources.

1. Fetch the ITSG-33 Annex 3A page to verify control families and IDs
2. Compare against the control tables in `references/itsg33-controls.md`
3. If differences found: update the reference file and report changes
4. If no differences: report "Phase 0 complete -- all controls match official sources"

### Phase 1 — Architecture Discovery

Scans the project to build a comprehensive picture of the system architecture.

**Step 1.1 -- Detect Tech Stack.** Scans for technology indicators:

| Indicator | Detection |
|---|---|
| Language | `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle` |
| IaC | `cdk.json` (CDK), `*.tf` (Terraform/OpenTofu), `template.yaml` (CloudFormation/SAM), Crossplane `*.yaml` |
| Containers | `Dockerfile`, `docker-compose.yml` |
| CI/CD | `.github/workflows/`, `buildspec.yml`, `.gitlab-ci.yml`, `Jenkinsfile` |

**Step 1.2 -- Analyze Codebase.** Scans for security-relevant patterns: IAM/access control, encryption, logging/auditing, network configuration, data protection, backup/recovery, configuration management, incident response. Adapts scanning to the detected IaC framework.

**Step 1.3 -- Read Architecture Docs.** Searches for `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `README.md`, `cdk.json`, pipeline definitions.

**Step 1.4 -- Produce Output.** Writes `docs/compliance/phase1-discovery.md` covering system architecture, components identified, AWS services detected, data flows, trust boundaries, and security-relevant findings.

**Step 1.5 -- User Checkpoint.** Presents the Phase 1 summary and asks:

- "Does this accurately represent your architecture?"
- "Any out-of-band security controls not visible in code (SCPs, SSO, manual configs)?"

Waits for confirmation before proceeding.

### Phase 2 — Control Mapping

Maps every ITSG-33 control (from `references/itsg33-controls.md`) to the project's actual implementation. For each control determines:

| Field | Values |
|---|---|
| **Status** | Implemented / Partially Implemented / Not Implemented / Not Applicable |
| **Inheritance** | AWS Inherited / AWS Shared / Customer Implemented / GC Org-level |
| **Evidence** | Specific file paths, line numbers, resource configurations |
| **Notes** | Caveats, assumptions, dependencies |

Writes `docs/compliance/phase2-control-mapping.md` with posture summary, inheritance summary, and per-control entries organized by family.

**Control Families Assessed (8):**

- **AC** — Access Control (8 controls: AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-17, AC-20)
- **AU** — Audit and Accountability (7 controls: AU-2, AU-3, AU-6, AU-8, AU-9, AU-11, AU-12)
- **CM** — Configuration Management (5 controls: CM-2, CM-3, CM-6, CM-7, CM-8)
- **CP** — Contingency Planning (3 controls: CP-7, CP-9, CP-10)
- **IA** — Identification and Authentication (5 controls: IA-2, IA-3, IA-4, IA-5, IA-8)
- **SA** — System and Services Acquisition (5 controls: SA-3, SA-4, SA-8, SA-10, SA-11)
- **SC** — System and Communications Protection (5 controls: SC-7, SC-8, SC-12, SC-13, SC-28)
- **SI** — System and Information Integrity (5 controls: SI-2, SI-3, SI-4, SI-5, SI-10)

**User Checkpoint.** Presents posture breakdown and uncertain controls. Asks: "Any controls where you have additional context?" Waits for confirmation.

### Phase 3 — Gap Analysis

For every control marked Not Implemented or Partially Implemented, produces a risk-rated remediation entry:

| Field | Description |
|---|---|
| **Risk Rating** | Critical / High / Medium / Low |
| **Effort** | Low (< 1 day) / Medium (1-3 days) / High (3+ days) |
| **Gap Description** | What is missing and why it matters |
| **Remediation Recommendation** | Specific, actionable guidance referencing AWS services, IaC constructs, or configuration changes |
| **References** | CCCS guidance links, AWS Well-Architected references |

**Risk Rating Criteria:**

| Rating | Criteria |
|---|---|
| Critical | Direct exposure of Protected B data, no compensating control, actively exploitable |
| High | Missing control with no compensating control, significant blast radius |
| Medium | Partially implemented or has compensating control but not fully compliant |
| Low | Missing enhancement or optimization, minimal security impact |

Writes two documents:

- `docs/compliance/phase3-gap-analysis.md` — gaps ordered by risk rating, then effort
- `docs/compliance/assessment-summary.md` — executive summary with posture dashboard, risk dashboard, top priority remediations, and inheritance profile

Presents the executive summary and top recommended actions.

### Smart Re-run

Before starting any phase, the skill checks for existing phase outputs. If found:

1. Reads existing output and compares against current project state (file modification times, git diff)
2. Re-runs the phase if significant changes are detected
3. Skips with "Phase N output is current" if no changes
4. Always asks: "Previous assessment found. Re-run from scratch or smart re-run?"

### Assessment Output Files

| File | Content |
|---|---|
| `docs/compliance/phase1-discovery.md` | Architecture discovery: components, services, data flows, trust boundaries |
| `docs/compliance/phase2-control-mapping.md` | Full ITSG-33 control mapping with status, inheritance, and evidence |
| `docs/compliance/phase3-gap-analysis.md` | Risk-rated gap entries with remediation recommendations |
| `docs/compliance/assessment-summary.md` | Executive summary with posture and risk dashboards |

## When to Use

- When assessing a project's compliance posture against Canadian ITSG-33 / CCCS Medium controls
- Before a security audit or compliance review
- After significant architecture changes that affect security controls
- When onboarding a new project to GC cloud compliance requirements
- When you need evidence-based documentation of security control implementation

## When Not to Use

- For validating or deploying CDK code — use `/cdk-testing` instead
- For validating or deploying Terraform code — use `/terraform-testing` instead
- For non-Canadian compliance frameworks (SOC 2, FedRAMP, etc.) — this skill is ITSG-33 specific
- When you need a quick security scan without full compliance mapping — use checkov or trivy directly

## Configuration

The skill has no configuration file or environment variables. It adapts automatically to the detected tech stack and IaC framework.

**Canadian context default:** Data residency defaults to `ca-central-1`. Resources outside Canadian regions are flagged.

## Important Rules

- **Evidence over assumption:** Every "Implemented" status must cite a file path or pattern. If no evidence, mark "Not Implemented" or ask.
- **Don't inflate compliance:** When uncertain, mark "Partially Implemented" with notes.
- **Respect inheritance:** Many controls are AWS-inherited or org-level. Don't mark these as gaps.
- **No fabricated controls:** Only map controls from ITSG-33. Verify against official sources when uncertain.
- **Phase checkpoints are mandatory:** Always pause between phases for user input.
- **Smart re-run is default:** If previous outputs exist, offer smart re-run first.

## Related Skills and Commands

- **cdk-testing** — validate and deploy CDK projects (often run before compliance assessment)
- **terraform-testing** — validate and deploy Terraform projects (often run before compliance assessment)
