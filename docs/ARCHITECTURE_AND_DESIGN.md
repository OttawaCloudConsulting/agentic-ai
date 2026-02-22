# Architecture and Design: Compliance Assessment Skill Suite — ITSG & NIST/FedRAMP

## Overview

Three parallel, structurally consistent Claude Code skills for jurisdiction-specific cloud compliance assessment:

- **itsg-assessment** — Canadian ITSG-33 / CCCS Medium Cloud Profile assessment (renamed from `compliance-assess`)
- **nist-fedramp-assessment** — USA NIST SP 800-53 Rev 5 / FedRAMP Moderate assessment (new)
- **nist-csf-assessment** — NIST Cybersecurity Framework 2.0 outcome-based assessment (new)

All three skills are drop-in prompt bundles (no runtime code). Consumers copy the skill directory into `.claude/skills/` of the target repository. All follow an identical 4-phase workflow. Each skill is self-contained with its own control reference tables, output templates, and official references.

## Component Diagram

```
agentic-ai/skills/
│
├── itsg-assessment/                  ← Feature 1 (rename + rebrand)
│   ├── SKILL.md                      ← Skill definition, workflow, rules
│   └── references/
│       ├── itsg33-controls.md        ← ITSG-33 / CCCS Medium control tables
│       ├── phase-templates.md        ← Output format templates (ITSG terminology)
│       └── official-references.md   ← Canadian GC official links
│
├── nist-fedramp-assessment/          ← Feature 2 (new)
│   ├── SKILL.md                      ← Skill definition, workflow, rules
│   └── references/
│       ├── nist-fedramp-controls.md  ← FedRAMP Moderate control tables (12 families)
│       ├── phase-templates.md        ← Output format templates (NIST/FedRAMP terminology)
│       └── official-references.md   ← NIST CSRC, FedRAMP.gov, AWS FedRAMP links
│
└── nist-csf-assessment/              ← Feature 3 (new)
    ├── SKILL.md                      ← Skill definition, self-updating Phase 0, CSF workflow
    └── references/
        ├── nist-csf-subcategories.md ← CSF 2.0 subcategories + 800-53 informative refs (self-updating)
        ├── phase-templates.md        ← Output format templates (CSF terminology)
        └── official-references.md   ← NIST CSRC CSF links

agentic-ai/docs/
└── SKILLS.md                         ← Updated catalog (Features 1, 2 & 3)
```

## Workflow (Both Skills — 4 Phases)

```
Phase 0: Framework Validation
    ↓  Fetch official source → compare vs embedded control tables → update if needed
Phase 1: Architecture Discovery
    ↓  Scan tech stack + codebase → user checkpoint
Phase 2: Control Mapping
    ↓  Map each control: status + inheritance + evidence → user checkpoint
Phase 3: Gap Analysis + Executive Summary
       Risk-rate gaps → remediation guidance → executive dashboard
```

Smart re-run gate sits before Phase 0: if previous outputs exist, offer incremental re-run vs. full re-run.

## File Organization

### Feature 1 — itsg-assessment

| File | Change |
|---|---|
| `skills/itsg-assessment/SKILL.md` | Renamed from `compliance-assess/SKILL.md`. Frontmatter `name` → `itsg-assessment`. Description updated to explicitly name ITSG-33, CCCS Medium, and Canadian jurisdiction. |
| `skills/itsg-assessment/references/itsg33-controls.md` | Renamed file. Internal references updated. |
| `skills/itsg-assessment/references/phase-templates.md` | Internal references updated. Canadian terminology preserved (Protected B, CCCS, GC Org-level). |
| `skills/itsg-assessment/references/official-references.md` | Internal references updated. |
| `docs/SKILLS.md` | Catalog entry updated: old name removed, new name + description added. |

### Feature 2 — nist-fedramp-assessment

| File | Purpose |
|---|---|
| `skills/nist-fedramp-assessment/SKILL.md` | Skill definition mirroring itsg-assessment. Workflow adapted for FedRAMP Moderate. Phase 0 targets NIST CSRC + FedRAMP.gov. |
| `skills/nist-fedramp-assessment/references/nist-fedramp-controls.md` | FedRAMP Moderate control tables for 12 core technical families. Dual inheritance model. |
| `skills/nist-fedramp-assessment/references/phase-templates.md` | Output templates with NIST/FedRAMP terminology. `phase2-nist-mapping.md` naming. |
| `skills/nist-fedramp-assessment/references/official-references.md` | NIST CSRC, FedRAMP.gov, AWS FedRAMP Moderate Audit Manager links. |

### Feature 3 — nist-csf-assessment

| File | Purpose |
|---|---|
| `skills/nist-csf-assessment/SKILL.md` | Skill definition. CSF 2.0 default. Self-updating Phase 0 fetches latest CSF version from NIST CSRC. Subcategory-level mapping workflow. |
| `skills/nist-csf-assessment/references/nist-csf-subcategories.md` | CSF 2.0 subcategory tables (all 6 Functions) with 800-53 informative references. **Self-updating** — overwritten by Phase 0 if a newer CSF version is detected. |
| `skills/nist-csf-assessment/references/phase-templates.md` | Output templates using CSF terminology (Functions/Categories/Subcategories). `phase2-csf-mapping.md` naming. Includes AWS evidence column and 800-53 reference column. |
| `skills/nist-csf-assessment/references/official-references.md` | NIST CSRC CSF page, NIST CSF 2.0 quick-start guides. |

## Control Family Scope

### itsg-assessment (unchanged from compliance-assess)

8 families: AC, AU, CM, CP, IA, SA, SC, SI

### nist-csf-assessment (new)

6 CSF 2.0 Functions → Categories → Subcategories (subcategory-level mapping):

| Function | Code | Subcategory Count (CSF 2.0) |
|---|---|---|
| Govern | GV | ~6 categories |
| Identify | ID | ~5 categories |
| Protect | PR | ~6 categories |
| Detect | DE | ~3 categories |
| Respond | RS | ~5 categories |
| Recover | RC | ~3 categories |

All subcategories include NIST 800-53 Rev 5 informative references (native to CSF 2.0).

> **Note:** Exact subcategory counts subject to Phase 0 self-update. The embedded reference file reflects the latest published CSF version on the date of assessment.

### nist-fedramp-assessment (new)

12 core technical families from FedRAMP Moderate baseline:

| Family | Code | Added vs. itsg-assessment |
|---|---|---|
| Access Control | AC | — (core 8) |
| Audit and Accountability | AU | — (core 8) |
| Configuration Management | CM | — (core 8) |
| Contingency Planning | CP | — (core 8) |
| Identification and Authentication | IA | — (core 8) |
| System and Services Acquisition | SA | — (core 8) |
| System and Communications Protection | SC | — (core 8) |
| System and Information Integrity | SI | — (core 8) |
| Risk Assessment | RA | Added |
| Incident Response | IR | Added |
| Planning | PL | Added |
| Security Assessment and Authorization | CA | Added |

## Inheritance Model

### itsg-assessment (unchanged)

| Category | Meaning |
|---|---|
| AWS Inherited | Fully AWS-managed |
| AWS Shared | AWS capability, customer must configure |
| Customer Implemented | Entirely customer responsibility |
| GC Org-level | Government of Canada organization-level |

### nist-fedramp-assessment (new — dual model)

| Category | Meaning |
|---|---|
| AWS FedRAMP Inherited | In AWS FedRAMP Moderate authorization package; no customer action needed |
| AWS FedRAMP Shared | AWS provides capability in authorization; customer must configure and document |
| Customer Implemented | Entirely customer responsibility |
| Organization-Level | Implemented at the agency/org level, not per-system |

FedRAMP note: AWS maintains a FedRAMP Moderate P-ATO. Customer Responsibility Matrix (CRM) defines which controls are inherited vs. shared. Reference the AWS Audit Manager FedRAMP Moderate framework for the current CRM.

NIST 800-53 note: For non-FedRAMP deployments, the generic shared responsibility model applies: platform-provided vs. customer-configured.

### nist-csf-assessment — No Inheritance Model (AWS Evidence + Shared Responsibility)

CSF is not a cloud-specific framework and has no inheritance concept. Instead:

**AWS Service Evidence Mapping:** At the subcategory level, identify which AWS services provide implementation evidence. Example: CloudTrail → DE.CM-3 (Monitored Computing Environment), GuardDuty → DE.AE-2 (Potentially Adverse Events Analyzed).

**Function-Level Shared Responsibility Summary:** In the executive summary, surface which CSF Functions are largely covered by AWS platform capabilities vs. customer responsibility:

| CSF Function | AWS Platform Contribution | Customer Responsibility |
|---|---|---|
| Govern (GV) | Low — governance is primarily customer | Policy, risk management, supply chain |
| Identify (ID) | Medium — asset inventory partially via Config/SSM | Classification, risk assessment |
| Protect (PR) | High — encryption, network, IAM via AWS services | Configuration, access management |
| Detect (DE) | High — CloudTrail, GuardDuty, Security Hub | Alerting thresholds, SIEM integration |
| Respond (RS) | Low — response is primarily customer | IR plan, runbooks, communication |
| Recover (RC) | Medium — backup/restore via AWS services | RTO/RPO definition, DR testing |

## Output File Naming

| Phase | itsg-assessment | nist-fedramp-assessment | nist-csf-assessment |
|---|---|---|---|
| Discovery | `phase1-discovery.md` | `phase1-discovery.md` | `phase1-discovery.md` |
| Control Mapping | `phase2-control-mapping.md` | `phase2-nist-mapping.md` | `phase2-csf-mapping.md` |
| Gap Analysis | `phase3-gap-analysis.md` | `phase3-gap-analysis.md` | `phase3-gap-analysis.md` |
| Summary | `assessment-summary.md` | `assessment-summary.md` | `assessment-summary.md` |

## Terminology Mapping

| Concept | itsg-assessment | nist-fedramp-assessment | nist-csf-assessment |
|---|---|---|---|
| Framework | ITSG-33 / CCCS Medium | NIST SP 800-53 Rev 5 / FedRAMP Moderate | NIST CSF 2.0 (self-updating) |
| Structure | Control families → Controls | Control families → Controls | Functions → Categories → Subcategories |
| Profile | CCCS Medium Cloud Profile | FedRAMP Moderate Baseline | All 6 CSF 2.0 Functions |
| Official source (Phase 0) | CCCS Annex 3A + ITSP.50.103 | NIST CSRC SP 800-53 Rev 5 + FedRAMP.gov | NIST CSRC CSF (latest version) |
| Jurisdiction flag | ca-central-1 / Canadian regions | us-east-1/us-west-2 / US regions | N/A (framework is jurisdiction-agnostic) |
| Data classification | Protected B | CUI / Controlled Unclassified Information | N/A (CSF is classification-agnostic) |
| Org-level category | GC Org-level | Organization-Level | N/A (no inheritance model) |
| Control status | Implemented / Partially / Not Implemented / N/A | Same + FedRAMP ATO notes | Implemented / Partially / Not Implemented / N/A |
| AWS handling | Inheritance model | Dual inheritance (FedRAMP CRM + 800-53) | AWS service evidence + Function-level summary |
| Cross-reference | None | None | NIST 800-53 informative references per subcategory |

## Phase 0 Validation Sources

### itsg-assessment

- ITSG-33 Annex 3A: `https://www.cyber.gc.ca/en/guidance/annex-3a-security-control-catalogue-itsg-33`
- ITSP.50.103 Annex B (CCCS Medium profile): `https://www.cyber.gc.ca/en/guidance/guidance-security-categorization-cloud-based-services-itsp50103`

### nist-fedramp-assessment

- NIST SP 800-53 Rev 5: `https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final`
- FedRAMP Moderate baseline: `https://www.fedramp.gov/documents-templates/`
- AWS Audit Manager FedRAMP Moderate framework: `https://docs.aws.amazon.com/audit-manager/latest/userguide/fedramp-moderate.html`

### nist-csf-assessment (self-updating — always fetch latest)

- NIST CSF landing page (latest version): `https://www.nist.gov/cyberframework`
- NIST CSRC CSF 2.0 publication: `https://csrc.nist.gov/pubs/cswp/29/final`
- CSF 2.0 reference tool (subcategories + informative refs): `https://csrc.nist.gov/projects/cybersecurity-framework/filters`

Phase 0 fetches the NIST CSF landing page, detects the current version number, and compares against the version recorded in `nist-csf-subcategories.md`. If a newer version exists, it fetches the updated subcategory list and overwrites the reference file before proceeding.

## Design Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Rename skill dir from `compliance-assess` to `itsg-assessment` (not keep old name) | Eliminates ambiguity. Consumers browsing skills/ directory immediately know jurisdiction. |
| 2 | nist-fedramp-assessment mirrors itsg-assessment structure exactly | Consistent UX for teams working across jurisdictions. Lowers onboarding cost. |
| 3 | FedRAMP Moderate (not Full 800-53) as the primary control selection | FedRAMP Moderate is the most common US gov cloud compliance target. Scoping prevents overwhelming assessments. |
| 4 | 12 families for NIST skill (not 8, not all 17+) | Core 8 + RA/IR/PL/CA covers the technically relevant FedRAMP controls. Org-level families (PE, PS, AT, MP) are excluded as per-project assessment rarely applies. |
| 5 | NIST 800-53 status terms + FedRAMP ATO notes (not pure FedRAMP SSP vocabulary) | NIST terms are familiar to a wider audience. FedRAMP ATO notes layer in SSP-specific context without requiring FedRAMP SSP expertise. |
| 6 | Smart re-run identical in both skills | Consistent behavior reduces confusion. Teams running repeated assessments benefit equally. |
| 7 | Different Phase 2 output file name (`phase2-nist-mapping.md` vs `phase2-control-mapping.md`) | If both skills run against the same repo, outputs don't collide. Makes origin of each file obvious. |
| 8 | Dual inheritance model for NIST skill (FedRAMP CRM + generic 800-53) | Not all consumers use AWS GovCloud or have a FedRAMP ATO. Generic 800-53 model keeps the skill useful for non-FedRAMP NIST assessments. |
| 9 | CSF skill uses self-updating Phase 0 (overwrite reference file on version change) | CSF is actively maintained; CSF 2.0 released in 2024. Hardcoding a version would silently drift. Self-update ensures assessments always reflect the current published framework. |
| 10 | CSF skill has no inheritance model — uses AWS service evidence + Function-level summary | CSF is not a cloud-specific or control-catalogue framework. Inheritance doesn't map to its outcome-based structure. AWS evidence mapping is more aligned with CSF intent. |
| 11 | Include 800-53 informative references in CSF Phase 2 output | CSF 2.0 natively provides these cross-references. Surfacing them lets teams use CSF output to inform 800-53 / FedRAMP assessments, increasing the skill's utility. |
| 12 | CSF skill scoped to all 6 Functions (not a subset) | CSF is relatively concise at the Function level. All 6 Functions (including Govern, new in 2.0) are relevant to cloud workloads. No basis for excluding any. |

## Deployment / Drop-in Instructions

Both skills are consumed identically:

```
# Copy skill into target repo
cp -r skills/itsg-assessment/ /path/to/project/.claude/skills/
cp -r skills/nist-fedramp-assessment/ /path/to/project/.claude/skills/
```

No build step, no dependencies. Skills are loaded by Claude Code via the `.claude/skills/` convention.

## Out of Scope

- FedRAMP High or DoD IL2/IL4 — separate baselines; add as future skills if needed
- Changes to any other existing skills (terraform-testing, cdk-testing, skill-creator, rule-creator)
- Automated control validation tooling — skills are prompt-driven, not code
