# PRD: Compliance Assessment Skill Suite — ITSG & NIST/FedRAMP

## Summary

Two discrete skill updates to the compliance-assess skill suite. Feature 1 renames and rebrands the existing `compliance-assess` skill as a clearly Canadian/ITSG-specific tool. Feature 2 creates a parallel new skill (`nist-fedramp-assessment`) targeting USA-based NIST SP 800-53 Rev 5 and FedRAMP Moderate for AWS cloud workloads.

## Goals

- Make the Canadian compliance skill clearly identifiable as ITSG-specific with no ambiguity about jurisdiction
- Provide a USA-focused compliance assessment skill mirroring the ITSG workflow, scoped to FedRAMP Moderate
- Maintain structural consistency between the two skills so teams working across jurisdictions have a familiar experience
- Keep both skills drop-in compatible with `.claude/skills/` conventions

## Non-Goals

- No changes to the compliance assessment workflow logic — only naming, branding, and content updates for Feature 1
- Not targeting DoD IL2/IL4 or FedRAMP High
- Not building a tool or automation — both skills are Claude Code prompt-driven workflows
- Not modifying skills other than compliance-assess and the new nist-fedramp-assessment

## Features

### Feature 1: Rename compliance-assess → itsg-assessment

Rename the existing skill, update all internal references, strengthen Canadian-specific context, and update the docs catalog.

**Scope:**

- Rename skill directory: `skills/compliance-assess/` → `skills/itsg-assessment/`
- Update SKILL.md frontmatter: `name`, `description`
- Update all internal references throughout SKILL.md and all files in `references/`
- Strengthen Canadian-specific framing: GC data residency (ca-central-1), Protected B classification, CCCS guidance language
- Update `docs/SKILLS.md` catalog entry

**Acceptance Criteria:**

- `skills/compliance-assess/` directory no longer exists
- `skills/itsg-assessment/` directory exists with all original files
- SKILL.md `name` field is `itsg-assessment`
- SKILL.md `description` field explicitly names ITSG-33, CCCS Medium, and Canadian context
- No remaining references to `compliance-assess` anywhere in the skill bundle
- Canadian-specific context is explicit in at least: skill description, important rules section, and phase templates
- `docs/SKILLS.md` reflects the renamed skill with updated description

### Feature 2: Create nist-fedramp-assessment Skill

Create a new skill mirroring the itsg-assessment structure, adapted for FedRAMP Moderate control mapping on AWS.

**Scope:**

- New skill directory: `skills/nist-fedramp-assessment/`
- `SKILL.md` — skill definition with 4-phase workflow (Phase 0 + Phases 1–3), adapted for NIST/FedRAMP
- `references/nist-fedramp-controls.md` — FedRAMP Moderate control families and control table
- `references/phase-templates.md` — output templates adapted for NIST/FedRAMP context (different file naming)
- `references/official-references.md` — NIST CSRC, FedRAMP.gov, and AWS FedRAMP Moderate links

**Phase Structure (mirroring itsg-assessment):**

- Phase 0: Framework Validation — fetch NIST CSRC and FedRAMP.gov to verify embedded control tables
- Phase 1: Architecture Discovery — same tech stack detection as itsg-assessment
- Phase 2: Control Mapping — map to FedRAMP Moderate baseline with dual inheritance model
- Phase 3: Gap Analysis + Executive Summary

**Output Files (different naming from itsg-assessment):**

| File | Purpose |
|---|---|
| `docs/compliance/phase1-discovery.md` | Architecture discovery (same as ITSG) |
| `docs/compliance/phase2-nist-mapping.md` | FedRAMP Moderate control mapping |
| `docs/compliance/phase3-gap-analysis.md` | Gap analysis (same as ITSG) |
| `docs/compliance/assessment-summary.md` | Executive summary (same as ITSG) |

**Inheritance Model:**

- Both FedRAMP Moderate Customer Responsibility Matrix (CRM) AND generic NIST 800-53 shared responsibility
- Categories: AWS FedRAMP Inherited / AWS FedRAMP Shared / Customer Implemented / Organization-Level

**Acceptance Criteria:**

- `skills/nist-fedramp-assessment/` exists with all 4 files
- SKILL.md trigger phrases include: "assess NIST", "FedRAMP compliance", "NIST 800-53", "FedRAMP Moderate"
- Phase 0 references official sources: NIST CSRC SP 800-53 Rev 5 and FedRAMP.gov baseline
- Control reference file covers 12 core technical FedRAMP Moderate families: AC, AU, CM, CP, IA, SA, SC, SI (core 8) + RA (Risk Assessment), IR (Incident Response), PL (Planning), CA (Security Assessment)
- Output template uses NIST 800-53 status terminology ("Implemented", "Partially Implemented", "Not Implemented", "Not Applicable") with FedRAMP ATO notes where applicable
- Smart re-run logic identical to itsg-assessment: detect existing phase outputs, compare against project state, offer incremental re-run
- Dual inheritance model documented in control reference and SKILL.md (FedRAMP Moderate CRM + generic NIST 800-53 shared responsibility)
- USA context is explicit: US data residency considerations, FedRAMP ATO relevance, FISMA alignment
- `docs/SKILLS.md` catalog includes the new skill

### Feature 3: Create nist-csf-assessment Skill

Create a new skill for NIST Cybersecurity Framework (CSF) assessments, mirroring the structural pattern of itsg-assessment and nist-fedramp-assessment but adapted for CSF's outcome-based Functions/Categories/Subcategories model.

**Scope:**

- New skill directory: `skills/nist-csf-assessment/`
- `SKILL.md` — skill definition with 4-phase workflow, CSF 2.0 default, self-updating via Phase 0
- `references/nist-csf-subcategories.md` — CSF 2.0 subcategory tables with 800-53 informative references
- `references/phase-templates.md` — output templates adapted for CSF terminology
- `references/official-references.md` — NIST CSRC CSF links

**Version Strategy:**

- Default to CSF 2.0 (6 Functions: Govern, Identify, Protect, Detect, Respond, Recover)
- Phase 0 self-mutating: always fetch the latest CSF version from NIST CSRC on execution; if a newer version is available, update the embedded reference file and report the version change before proceeding
- Skill always assesses to the latest version available on the date executed

**Phase Structure (mirroring itsg-assessment):**

- Phase 0: Framework Validation — fetch NIST CSRC, detect latest CSF version, update embedded subcategory tables if needed
- Phase 1: Architecture Discovery — same tech stack detection as other skills
- Phase 2: Control Mapping — map to CSF subcategories (e.g., ID.AM-1, PR.AC-3) with 800-53 informative references and AWS evidence
- Phase 3: Gap Analysis + Executive Summary

**Output Files:**

| File | Purpose |
|---|---|
| `docs/compliance/phase1-discovery.md` | Architecture discovery (same pattern) |
| `docs/compliance/phase2-csf-mapping.md` | CSF subcategory mapping |
| `docs/compliance/phase3-gap-analysis.md` | Gap analysis |
| `docs/compliance/assessment-summary.md` | Executive summary |

**CSF-Specific Adaptations (no inheritance model):**

| Element | Approach |
|---|---|
| AWS evidence | Map AWS services to contributing subcategories (e.g., CloudTrail → DE.CM-3) |
| Shared responsibility | Function-level summary: which CSF Functions are largely platform-covered vs. customer responsibility |
| 800-53 cross-reference | Show 800-53 informative references alongside each subcategory in Phase 2 output |

**Acceptance Criteria:**

- `skills/nist-csf-assessment/` exists with all 4 files
- SKILL.md trigger phrases include: "assess CSF", "NIST CSF", "Cybersecurity Framework", "CSF 2.0"
- Phase 0 fetches NIST CSRC and self-updates embedded tables to latest CSF version
- Control reference file covers all 6 CSF 2.0 Functions and subcategory-level detail with 800-53 informative references
- Output template uses CSF terminology (Functions/Categories/Subcategories, not control families)
- AWS evidence mapping documented per subcategory; Function-level shared responsibility summary in output
- Smart re-run logic identical to other skills
- `docs/SKILLS.md` catalog includes the new skill

## Architecture

Three independent skills in `skills/`:

```
skills/
├── itsg-assessment/            ← renamed from compliance-assess
│   ├── SKILL.md
│   └── references/
│       ├── itsg33-controls.md
│       ├── phase-templates.md
│       └── official-references.md
├── nist-fedramp-assessment/    ← new
│   ├── SKILL.md
│   └── references/
│       ├── nist-fedramp-controls.md
│       ├── phase-templates.md
│       └── official-references.md
└── nist-csf-assessment/        ← new
    ├── SKILL.md
    └── references/
        ├── nist-csf-subcategories.md
        ├── phase-templates.md
        └── official-references.md
```

All three skills are structurally parallel. Consumers copy the relevant skill(s) into `.claude/skills/`.
