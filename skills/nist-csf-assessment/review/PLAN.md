# Implementation Plan: nist-csf-assessment

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | SKILL.md | Move "Important Rules" section above "Output" | P1 |
| 2 | SKILL.md | Add negative trigger for standalone 800-53 assessments to frontmatter description | P1 |
| 3 | SKILL.md | Add `compatibility` frontmatter field for network access requirement | P1 |
| 4 | SKILL.md | Remove cloud service → subcategory examples from Important Rules (lines 28–29) | P2 |
| 5 | SKILL.md | Trim References section — remove two URLs already cited inline in Phase 0 | P2 |
| 6 | SKILL.md | Trim opening body paragraph to delta-only content | P2 |
| 7 | SKILL.md | Add minimal worked example | P3 |

---

## Detailed Changes

### SKILL.md

#### Change 1 — Reorder: move "Important Rules" above "Output" [P1]

**Location**: Lines 10–33 (sections "## Output" and "## Important Rules")
**Current order**:
```
## Output        (line 10)
## Important Rules  (line 23)
```
**Replace with order**:
```
## Critical Rules   (rename and move here — first section after intro paragraph)
## Output           (move below Critical Rules)
```
**Exact restructure**: After line 8 (the intro paragraph), insert the "Important Rules" section (renaming it `## Critical Rules` to signal precedence), then place the `## Output` section after it.

The resulting section order should be:
1. Intro paragraph (line 8, trimmed per Change 6)
2. `## Critical Rules` (moved up, content from lines 24–33)
3. `## Output` (moved down, content from lines 11–21)
4. `## Error Handling`
5. `## Smart Re-run`
6. Phases 0–3
7. `## References`

**Reason**: Critical invariants (evidence over assumption, no fabricated subcategories, version mandate) must be encountered before phase instructions; a model skimming to Phase 0 currently bypasses them.

---

#### Change 2 — Add 800-53 negative trigger to frontmatter description [P1]

**Location**: Line 3, `description` field
**Current** (end of description):
```
Do NOT use for general security audits, penetration testing, ITSG assessments, or FedRAMP assessments — use the dedicated skills for those frameworks.
```
**Replace with**:
```
Do NOT use for general security audits, penetration testing, ITSG assessments, FedRAMP assessments, or standalone NIST SP 800-53 control assessments — use the dedicated skills for those frameworks.
```
**Reason**: The skill's body references 800-53 extensively; without this exclusion, a co-deployed 800-53 skill would create an over-trigger conflict on queries like "help me with 800-53 controls."

---

#### Change 3 — Add `compatibility` frontmatter field [P1]

**Location**: After line 4 (`---` closing frontmatter) — add field inside the frontmatter block, after the `description` field and before the closing `---`
**Current frontmatter**:
```yaml
---
name: nist-csf-assessment
description: ...
---
```
**Replace with**:
```yaml
---
name: nist-csf-assessment
description: ...
compatibility: Requires live network access to nist.gov and csrc.nist.gov for Phase 0 version check. In air-gapped environments, Phase 0 will fall back to the bundled reference file version.
---
```
**Reason**: Phase 0 makes live web fetches; consumers in restricted or air-gapped environments need to know fallback behavior applies automatically.

---

#### Change 4 — Remove cloud service examples from Important Rules [P2]

**Location**: Lines 28–29 (inside "Important Rules" / future "Critical Rules" section)
**Current**:
```
- **Cloud service evidence mapping**: At the subcategory level, identify which cloud services contribute to achieving that outcome (e.g., GuardDuty/Defender for Cloud/Chronicle -> DE.AE-02, AWS Config/Azure Policy/GCP Asset Inventory -> ID.AM-05).
- **800-53 informative references**: Always include them in Phase 2 output — they connect CSF outcomes to control-catalogue assessments and increase utility for teams also running NIST/FedRAMP assessments.
```
**Replace with**:
```
- **Cloud service evidence mapping**: At the subcategory level, identify which cloud services contribute to achieving each outcome. See Phase 2 for examples.
- **800-53 informative references**: Always include them in Phase 2 output — they connect CSF outcomes to control-catalogue assessments and increase utility for teams also running NIST/FedRAMP assessments.
```
**Reason**: The specific cloud service → subcategory examples (GuardDuty/DE.AE-02, AWS Config/ID.AM-05) duplicate content already present in Phase 2 lines 110–113; the rules section should state the requirement, not repeat the domain examples.

---

#### Change 5 — Trim References section: remove two inline-duplicated URLs [P2]

**Location**: Lines 143–146 (References section)
**Current**:
```markdown
- [NIST Cybersecurity Framework (CSF) — Landing Page](https://www.nist.gov/cyberframework)
- [NIST CSF 2.0 Publication (CSWP 29)](https://csrc.nist.gov/pubs/cswp/29/final)
- [CSF 2.0 Reference Tool — Subcategories and Informative References](https://csrc.nist.gov/projects/cybersecurity-framework/filters)
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
```
**Replace with**:
```markdown
- [NIST CSF 2.0 Publication (CSWP 29)](https://csrc.nist.gov/pubs/cswp/29/final)
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
```
**Reason**: The NIST CSF landing page (`nist.gov/cyberframework`) and CSRC reference tool (`csrc.nist.gov/projects/cybersecurity-framework/filters`) are already cited inline in Phase 0 lines 58 and 62. The CSWP 29 and SP 800-53 links are not cited inline and add standalone reference value.

---

#### Change 6 — Trim opening body paragraph to delta content only [P2]

**Location**: Line 8
**Current**:
```
Map a project's architecture and codebase to NIST CSF 2.0 subcategory outcomes. Produces a phased, outcome-based assessment with cloud service evidence mapping, NIST 800-53 informative references, and risk-rated gap analysis. Always assesses to the latest published CSF version — Phase 0 self-updates the reference file if a newer version is available.
```
**Replace with**:
```
Produces a risk-rated gap analysis across all CSF subcategories. Phase 0 self-updates the reference file to the latest published CSF version before assessment begins.
```
**Reason**: The removed content ("Map a project's architecture... cloud service evidence mapping... NIST 800-53 informative references") duplicates the frontmatter description almost verbatim. Only the two deltas — risk-rated gap analysis and Phase 0 self-update behavior — justify the body paragraph.

---

#### Change 7 — Add minimal worked example [P3]

**Location**: Add as a new `## Example` section immediately before `## Phase 0`, after the Smart Re-run section
**Current**: No example exists
**Add**:
```markdown
## Example

> User: "Run a CSF assessment on this repo."

1. Phase 0 — fetches `nist.gov/cyberframework`, confirms CSF 2.0 is current, reports version
2. Phase 1 — scans project for IaC, CI/CD, security patterns; writes `phase1-discovery.md`; pauses for user confirmation
3. Phase 2 — maps every subcategory across all 6 Functions; writes `phase2-csf-mapping.md`; presents Function-level posture breakdown; pauses for user confirmation
4. Phase 3 — produces risk-rated gap analysis and executive summary; writes `phase3-gap-analysis.md` and `assessment-summary.md`
```
**Reason**: The four-phase, multi-checkpoint workflow is complex; a brief example scopes user expectations before invocation and reduces mid-run confusion.

---

## Implementation Order

1. **Change 6 first** (trim body paragraph) — establishes the clean intro before the restructure
2. **Change 1** (reorder sections) — the primary structural change; do after trimming so the moved content is already clean
3. **Change 4** (remove cloud examples from rules) — apply within the moved section while it's being restructured
4. **Change 2** (frontmatter negative trigger) — isolated frontmatter edit, no dependencies
5. **Change 3** (frontmatter `compatibility` field) — isolated frontmatter edit, no dependencies
6. **Change 5** (trim References) — isolated tail-of-file edit, no dependencies
7. **Change 7** (add worked example) — add after structure is finalized

Changes 2, 3, 5, and 7 are independent of each other and of the restructure. Changes 1, 4, and 6 are interdependent and should be applied together as one edit pass.

---

## Verification

After applying changes:

- [ ] Section order in SKILL.md: Critical Rules appears before Output, which appears before Error Handling
- [ ] Frontmatter description ends with "...or standalone NIST SP 800-53 control assessments — use the dedicated skills for those frameworks."
- [ ] Frontmatter contains a `compatibility` field referencing nist.gov and csrc.nist.gov
- [ ] Critical Rules section does NOT contain specific subcategory IDs (DE.AE-02, ID.AM-05) — those remain only in Phase 2
- [ ] References section contains exactly 2 URLs (CSWP 29 and SP 800-53 Rev 5)
- [ ] Opening body paragraph is 2 sentences or fewer and does not repeat frontmatter description content
- [ ] Example section exists between Smart Re-run and Phase 0
- [ ] SKILL.md line count remains under 500
- [ ] `references/nist-csf-subcategories.md` has a table of contents — confirmed present (lines 12–19)
- [ ] `references/phase-templates.md` has a table of contents — confirmed present (lines 5–11)
