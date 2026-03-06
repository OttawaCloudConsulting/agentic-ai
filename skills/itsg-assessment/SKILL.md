---
name: itsg-assessment
description: Map project architecture to ITSG-33 / CCCS Medium Cloud Profile security controls for Canadian GC cloud workloads handling Protected B data. Produces a phased compliance assessment with AWS control inheritance and risk-rated gap analysis. Use when asked to assess ITSG, run a CCCS Medium compliance check, evaluate Canadian cloud compliance, map ITSG-33 controls, perform a GC cloud security assessment, or check Protected B data handling requirements. Do NOT use for FedRAMP, NIST CSF, SOC 2, PBMM standalone reviews, TBS cloud profile assessments, or other non-ITSG-33 compliance frameworks.
compatibility: "AWS workloads in Canadian regions (ca-central-1, ca-west-1). Requires network access for Phase 0 control validation."
---

# ITSG-33 / CCCS Medium Compliance Assessment

Map a project's architecture and codebase to Canadian ITSG-33 security controls (CCCS Medium Cloud Profile). Produces a phased assessment with AWS shared responsibility inheritance, gap analysis, and risk-rated remediation guidance.

## Important Rules

These rules govern all phases. Read before starting any assessment work.

- **Evidence over assumption**: Every "Implemented" status must cite a file path or pattern. If no evidence, mark "Not Implemented" or ask.
- **Don't inflate compliance**: When uncertain, mark "Partially Implemented" with notes.
- **Respect inheritance**: Many controls are AWS-inherited or GC Org-level. Don't mark these as gaps.
- **Protected B data classification**: Flag any handling of Protected B data without explicit encryption, access control, and residency controls.
- **GC data residency**: Data residency defaults to ca-central-1. Flag resources deployed outside Canadian AWS regions (ca-central-1, ca-west-1).
- **CCCS guidance**: Apply CCCS Medium Cloud Profile control selection as defined in ITSP.50.103 Annex B. Follow CCCS guidance when interpreting control applicability.
- **No fabricated controls**: Only map controls from ITSG-33. Verify against official sources when uncertain.
- **Phase checkpoints are mandatory**: Always pause between phases for user input.
- **Smart re-run is default**: If previous outputs exist, offer smart re-run first.

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

## Smart Re-run

Before starting any phase, check if previous phase outputs exist. If they do:

1. Read the existing output and compare against current project state (file modification times, git diff)
2. If changes detected (any IaC file modified since the phase output was written, or any new AWS service added to the codebase), re-run that phase
3. If no changes, report "Phase N output is current — skipping"
4. Always ask: "Previous assessment found. Re-run from scratch or smart re-run?"

## Phase 0 — Framework Validation

Runs first, before any assessment work. Validates control data against official sources.

1. Look up the ITSG-33 Annex 3A URL in `references/official-references.md`, then fetch that page to verify control families and IDs
2. Compare against the control tables in `references/itsg33-controls.md`
3. If differences found: update `references/itsg33-controls.md` and report changes
4. If no differences: report "Phase 0 complete — all controls match official sources"

**If the fetch fails** (network error, page unavailable, timeout): skip validation, report "Phase 0 skipped — using cached controls from references/itsg33-controls.md", and proceed to Phase 1. Do not block the assessment.

## Phase 1 — Architecture Discovery

### 1.1 — Detect Tech Stack

Detect the IaC framework in use — this determines search terms in Phase 1.2:

| IaC Framework | Indicator |
|---|---|
| **CDK** | `cdk.json`, `lib/*.ts` or `lib/*.py` with CDK constructs |
| **Terraform / OpenTofu** | `*.tf` files |
| **CloudFormation / SAM** | `template.yaml` or `template.json` |
| **Crossplane** | `*.yaml` with `apiVersion: aws.upbound.io` or similar |

Also note language runtime and CI/CD platform for context, but do not let them drive control mapping.

### 1.2 — Analyze Codebase

Search for security-relevant patterns across these categories: IAM / Access Control, Encryption, Logging / Auditing, Network, Data Protection, Backup / Recovery.

Adapt search terms to the detected IaC framework (CDK constructs, Terraform resource types, or CloudFormation resource names).

If no IaC or security-relevant patterns are found, report what was searched and ask the user whether security controls exist outside the codebase.

### 1.3 — Read Architecture Docs

Search for `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `README.md`, `cdk.json`, pipeline definitions.

### 1.4 — Produce Output

Write `docs/compliance/phase1-discovery.md`. Before writing, read `references/phase-templates.md` for the Phase 1 template format.

### 1.5 — User Checkpoint

Present the Phase 1 summary and ask:

- "Does this accurately represent your architecture?"
- "Any out-of-band security controls not visible in code (SCPs, SSO, manual configs)?"

Wait for confirmation before Phase 2.

## Phase 2 — Control Mapping

Read the control families and inheritance model from `references/itsg33-controls.md`. For every control, determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **Inheritance**: Classify using the inheritance model in `references/itsg33-controls.md` (AWS Inherited / AWS Shared / Customer Implemented / GC Org-level)
3. **Evidence**: Specific file paths, line numbers, resource configurations
4. **Notes**: Caveats, assumptions, dependencies

Write `docs/compliance/phase2-control-mapping.md`. Before writing, read `references/phase-templates.md` for the Phase 2 template format.

### User Checkpoint

Present posture breakdown and uncertain controls. Ask: "Any controls where you have additional context?" Wait for confirmation before Phase 3.

## Phase 3 — Gap Analysis

For every control marked Not Implemented or Partially Implemented, produce a risk-rated remediation entry. Before writing, read `references/phase-templates.md` for the gap entry format and risk rating criteria.

Write:

- `docs/compliance/phase3-gap-analysis.md` — ordered by risk rating, then effort
- `docs/compliance/assessment-summary.md` — executive summary

Present the executive summary and top recommended actions.

## Error Handling

| Situation | Action |
|---|---|
| No IaC files detected | Report what was searched, ask user if controls exist outside codebase |
| No architecture docs found | Proceed with code-only analysis, note reduced confidence in Phase 1 output |
| Empty or minimal project | Report insufficient evidence for assessment, ask user for additional context before proceeding |

## References

- Control family tables and inheritance model: `references/itsg33-controls.md` — read during Phase 2 to map each control
- Output format templates: `references/phase-templates.md` — read before writing any phase output
- Official documentation links: `references/official-references.md` — read during Phase 0 for validation URLs
