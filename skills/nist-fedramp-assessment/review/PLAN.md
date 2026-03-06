# Implementation Plan: nist-fedramp-assessment

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | SKILL.md | Trim Critical Rules lines 28–30 — remove inline explanatory prose | P1 |
| 2 | SKILL.md | Move Smart Re-run section (lines 44–51) to after the Output table | P1 |
| 3 | SKILL.md | Replace Phase 2 field definitions (lines 103–110) with reference citation | P1 |
| 4 | SKILL.md | Add when-to-read anchor for references/official-references.md | P1 |
| 5 | SKILL.md | Resolve incomplete IaC detection guidance at line 82 | P2 |
| 6 | SKILL.md | Tighten "perform a NIST assessment" trigger phrase in frontmatter | P3 |
| 7 | SKILL.md | Add `compatibility` field to frontmatter | P3 |
| 8 | references/nist-fedramp-controls.md | Verify/add table of contents if >100 lines | P3 |
| 9 | references/phase-templates.md | Verify/add table of contents if >100 lines | P3 |

---

## Detailed Changes

### SKILL.md

#### Change 1 — Trim Critical Rules: remove inline explanatory prose [P1]

**Location**: Lines 28–30, Section "Critical Rules"

**Current**:
```
- **Dual inheritance model**: Note both FedRAMP Moderate CRM (AWS P-ATO) AND generic NIST 800-53 shared responsibility. AWS maintains a FedRAMP Moderate P-ATO; the Customer Responsibility Matrix (CRM) defines which controls are inherited vs. shared. For non-FedRAMP NIST assessments, apply generic shared responsibility.
- **USA context**: This skill applies to US-based AWS workloads subject to FISMA and FedRAMP requirements. Default AWS regions are us-east-1 and us-west-2. Flag resources deployed outside US regions when data residency is relevant. Apply CUI (Controlled Unclassified Information) data classification standards where applicable.
- **FedRAMP ATO relevance**: When the target has or is pursuing a FedRAMP ATO, reference the AWS Audit Manager FedRAMP Moderate framework for the current CRM. Note FISMA alignment where applicable.
```

**Replace with**:
```
- **Dual inheritance model**: Apply both FedRAMP Moderate CRM (AWS P-ATO) and generic NIST 800-53 shared responsibility. For non-FedRAMP NIST assessments, apply generic shared responsibility only.
- **USA context**: Applies to US-based AWS workloads. Flag resources deployed outside US regions when data residency is relevant.
- **FedRAMP ATO relevance**: When the target has or is pursuing a FedRAMP ATO, reference the AWS Audit Manager FedRAMP Moderate framework for the current CRM.
```

**Reason**: The inline explanations of CRM, CUI, and FISMA are domain background Claude already has; only the actionable rule needs to be present at this tier.

---

#### Change 2 — Move Smart Re-run section to after the Output table [P1]

**Location**: Lines 44–51 (current position: after Critical Rules, before Phase 0). Lines 10–21 (Output table, target insertion point).

**Current document order**:
```
## Output          ← lines 10–21
## Critical Rules  ← lines 23–32
## Error Handling  ← lines 34–42
## Smart Re-run    ← lines 44–51
## Phase 0         ← lines 53–63
```

**Replace with this order**:
```
## Output
## Smart Re-run    ← moved here (pre-flight, before Phase 0)
## Critical Rules
## Error Handling
## Phase 0
```

Move the entire Smart Re-run section block (lines 44–51) to immediately after the Output table (after line 21, before the Critical Rules heading). No content changes to the Smart Re-run text itself.

**Reason**: Smart Re-run is a pre-flight check before any phase runs. Placing it after the Output table and before Critical Rules restores linear workflow order and signals it as the first thing to do when the skill is invoked.

---

#### Change 3 — Replace Phase 2 field definitions with a reference citation [P1]

**Location**: Lines 103–110, Section "Phase 2 — Control Mapping"

**Current**:
```
Before starting this phase, read references/nist-fedramp-controls.md for the control families and IDs to map. For every control, determine:

1. **Status**: Implemented / Partially Implemented / Not Implemented / Not Applicable
2. **Inheritance**: AWS FedRAMP Inherited / AWS FedRAMP Shared / Customer Implemented / Organization-Level
3. **Evidence**: Specific file paths, line numbers, resource configurations
4. **Notes**: Caveats, assumptions, dependencies
5. **FedRAMP ATO Note**: Whether the control is covered under AWS P-ATO (FedRAMP Moderate), customer-documented in SSP, or not applicable to the authorization boundary
```

**Replace with**:
```
Before starting this phase, read references/nist-fedramp-controls.md for the control families and IDs to map. Read references/phase-templates.md "Phase 2" section for required field definitions (Status, Inheritance, Evidence, Notes, FedRAMP ATO Note) and output structure.
```

**Reason**: All five field definitions already appear verbatim in references/phase-templates.md (lines 80–86). This is direct duplication; the SKILL.md tier should cite, not repeat.

---

#### Change 4 — Add when-to-read anchor for references/official-references.md [P1]

**Location**: Line 63, end of Phase 0 section (after the Fallback paragraph). This is the natural placement since Phase 0 is where URLs are fetched and validated.

**Current** (end of Phase 0):
```
**Fallback:** If either URL is unreachable or returns unparseable content, skip validation for that source. Warn the user which source could not be verified and proceed using the cached control data in references/nist-fedramp-controls.md. Do not block the assessment.
```

**Replace with**:
```
**Fallback:** If either URL is unreachable or returns unparseable content, skip validation for that source. Warn the user which source could not be verified and proceed using the cached control data in references/nist-fedramp-controls.md. Do not block the assessment.

If official source URLs change or are uncertain, read references/official-references.md for current authoritative links before retrying.
```

**Reason**: Without a when-to-read anchor in the workflow body, the file is invisible to execution flow and will be ignored. Phase 0 is the correct trigger point since that is where URLs are used.

---

#### Change 5 — Resolve incomplete IaC detection guidance [P2]

**Location**: Line 82, Section "Phase 1.2 — Analyze Codebase"

**Current**:
```
For IaC-specific detection patterns (CDK, Terraform, CloudFormation, Crossplane), adapt scanning to the detected tech stack.
```

**Replace with**:
```
For IaC-specific detection patterns, read references/nist-fedramp-controls.md "IaC Detection Patterns" section if present, or apply these defaults: CDK — scan `lib/**/*.ts` for L2/L3 constructs; Terraform — scan `*.tf` for `resource` and `data` blocks; CloudFormation/SAM — scan `template.yaml` for `Properties`; Crossplane — scan `*.yaml` for `apiVersion: aws.crossplane.io`.
```

**Note on this change**: If references/nist-fedramp-controls.md does not contain an "IaC Detection Patterns" section, the inline defaults above are sufficient and the reference-link clause should be dropped. Verify the reference file content before applying.

**Reason**: "Adapt scanning to the detected tech stack" is not actionable. Either provide the patterns or remove the sentence; the feedback explicitly calls this out as vague.

---

#### Change 6 — Tighten over-broad trigger phrase in frontmatter [P3]

**Location**: Line 3, frontmatter `description` field

**Current**:
```
... perform a NIST assessment, ...
```

**Replace with**:
```
... perform a NIST 800-53 assessment, ...
```

**Reason**: "NIST assessment" alone can match NIST CSF, SP 800-171, or other NIST framework queries. Adding "800-53" tightens the trigger to the intended scope and reduces over-trigger risk.

---

#### Change 7 — Add `compatibility` field to frontmatter [P3]

**Location**: Lines 1–4, frontmatter block

**Current**:
```
---
name: nist-fedramp-assessment
description: Map AWS project architecture to NIST SP 800-53 Rev 5 / FedRAMP Moderate security controls. ...
---
```

**Replace with**:
```
---
name: nist-fedramp-assessment
compatibility: "AWS workloads; US regions (us-east-1, us-west-2); FedRAMP Moderate baseline"
description: Map AWS project architecture to NIST SP 800-53 Rev 5 / FedRAMP Moderate security controls. ...
---
```

**Reason**: The skill is AWS-specific and US-region scoped. Surfacing this at the metadata tier ensures the constraint is always in context, not buried in the Critical Rules body.

---

### references/nist-fedramp-controls.md

#### Change 8 — Add table of contents if file is >100 lines [P3]

**Location**: Top of file, after the `# FedRAMP Moderate Control Families` heading and before the first section heading.

**Action**: Read the full file. If line count exceeds 100, insert a table of contents listing all control family sections (AC, AU, CA, CM, CP, IA, IR, PL, RA, SA, SC, SI) as anchor links immediately below the "Source of Truth" section.

**Example format**:
```markdown
## Contents

- [AC — Access Control](#ac--access-control)
- [AU — Audit and Accountability](#au--audit-and-accountability)
- [CA — Assessment, Authorization, and Monitoring](#ca--assessment-authorization-and-monitoring)
- [CM — Configuration Management](#cm--configuration-management)
- [CP — Contingency Planning](#cp--contingency-planning)
- [IA — Identification and Authentication](#ia--identification-and-authentication)
- [IR — Incident Response](#ir--incident-response)
- [PL — Planning](#pl--planning)
- [RA — Risk Assessment](#ra--risk-assessment)
- [SA — System and Services Acquisition](#sa--system-and-services-acquisition)
- [SC — System and Communications Protection](#sc--system-and-communications-protection)
- [SI — System and Information Integrity](#si--system-and-information-integrity)
```

**Reason**: Anthropic best practices require a table of contents for reference files exceeding 100 lines. Given the full FedRAMP Moderate control set, this file almost certainly exceeds 100 lines.

---

### references/phase-templates.md

#### Change 9 — Add table of contents if file is >100 lines [P3]

**Location**: Top of file, after the `# Phase Output Templates` heading.

**Action**: Read the full file. If line count exceeds 100, insert a table of contents listing all phase sections as anchor links immediately after the opening heading.

**Example format**:
```markdown
## Contents

- [Phase 1 — Architecture Discovery](#phase-1--architecture-discovery)
- [Phase 2 — Control Mapping](#phase-2--control-mapping)
- [Phase 3 — Gap Analysis](#phase-3--gap-analysis)
- [Risk Rating Criteria](#risk-rating-criteria)
- [Assessment Summary](#assessment-summary)
```

**Reason**: Same requirement as Change 8. Given templates for four output documents plus risk rating criteria, this file is likely >100 lines.

---

## Implementation Order

1. **Change 3** (Phase 2 field definitions) — must verify references/phase-templates.md contains the field definitions before removing from SKILL.md. Already confirmed (phase-templates.md lines 80–86 contain all five fields verbatim). Safe to proceed.
2. **Change 1** (Critical Rules trim) — independent, no file dependencies. High token-cost reduction.
3. **Change 2** (Smart Re-run relocation) — structural move within SKILL.md only. No content changes.
4. **Change 4** (official-references.md anchor) — adds one line to Phase 0. Independent.
5. **Change 5** (IaC detection guidance) — requires reading nist-fedramp-controls.md fully to check for existing IaC patterns section before applying the inline default fallback.
6. **Change 6** (trigger phrase tighten) — one-word change in frontmatter. Independent.
7. **Change 7** (compatibility field) — one-line frontmatter addition. Independent.
8. **Change 8** (nist-fedramp-controls.md TOC) — requires reading full file to confirm line count. Apply only if >100 lines.
9. **Change 9** (phase-templates.md TOC) — requires reading full file to confirm line count. Apply only if >100 lines.

---

## Verification

After applying changes:

- [ ] SKILL.md line count is still under 500 lines
- [ ] Smart Re-run section appears after the Output table and before Critical Rules
- [ ] Critical Rules lines 28–30 contain no inline explanatory prose — only actionable instructions
- [ ] Phase 2 section no longer enumerates the five field definitions inline; references phase-templates.md for them
- [ ] Phase 0 section ends with a when-to-read sentence for references/official-references.md
- [ ] Line 82 (IaC detection) is either replaced with concrete patterns or removed — no vague "adapt" language remains
- [ ] Frontmatter description reads "perform a NIST 800-53 assessment" (not "perform a NIST assessment")
- [ ] Frontmatter contains a `compatibility` field
- [ ] references/nist-fedramp-controls.md has a table of contents if its line count exceeds 100
- [ ] references/phase-templates.md has a table of contents if its line count exceeds 100
- [ ] All three reference files (nist-fedramp-controls.md, phase-templates.md, official-references.md) have at least one explicit when-to-read anchor in the SKILL.md body
