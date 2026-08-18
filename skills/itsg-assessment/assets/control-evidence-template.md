<!-- Classification marking. Required on the first and last page of a Protected B document. Change the marking if the system carries a different classification; delete only if the system is Unclassified. -->

**PROTECTED B**

# Security Control Evidence — [CONTROL-ID]: [Control Title]

## Document Control

| Field | Value |
|---|---|
| System / Project | [System name as it appears in the SA&A package] |
| Control ID | [e.g. AC-2] |
| Control Family | [e.g. AC — Access Control] |
| Security Profile | CCCS Medium Cloud (ITSG-33) |
| Overall Status | [Satisfied / Partially Satisfied / Not Satisfied] |
| Inheritance | [AWS Inherited / AWS Shared / Customer Implemented / GC Org-level] |
| Classification | Protected B |
| Document Version | [e.g. 1.0] |
| Assessment Date | [YYYY-MM-DD] |
| Assessor | [Name, role] |

<!-- Overall Status omits Not Applicable because Phase 4 scope excludes controls mapped Not Applicable in Phase 2. If this document was requested standalone for such a control, use Not Applicable and give the reason in 2.3. -->

## Revision History

| Version | Date | Author | Summary of Change |
|---|---|---|---|
| [1.0] | [YYYY-MM-DD] | [Name] | [Initial issue] |

## Approvals

<!-- Signature column stays blank in the generated document — it is signed after review. -->

| Role | Name | Title | Date | Signature |
|---|---|---|---|---|
| Preparer | [Name] | [Title] | [YYYY-MM-DD] | |
| Reviewer (Security) | [Name] | [Title] | [YYYY-MM-DD] | |
| Approver | [Name] | [Title] | [YYYY-MM-DD] | |

---

## 1. Purpose

<!-- Two to four sentences. State which control this document provides evidence for, which system it covers, and what an assessor should conclude from it. Do not restate the control here — that is section 2. -->

[Purpose statement]

## 2. Control Definition

### 2.1 Definition

<!--
Official ITSG-33 control wording, transcribed verbatim. NEVER write this from memory.
Source it from docs/compliance/.control-text/<FAMILY>.md or a retained raw capture; if nothing
is retrievable, leave the [VERIFY-SOURCE] marker in place and flag it to the user.

Parts: one per top-level list item of the catalogue's Control block, lettered A., B., C. in
document order. This IS the official lettering (Annex 3A styles the list upper-alpha), so do
not add any note calling it assessor-added. Tag-stripping extractors and copy-paste drop those
CSS-generated markers and make a control look like unlettered prose -- it is not.
Nested sub-items stay inside their parent part here and in its 3.2 block.
Many controls have a single part; then only A. appears below.
Keep the [Assignment: ...] and [Selection: ...] brackets exactly as written -- they are official
text, not placeholders to fill. Chosen values go in 2.4, never substituted into 2.1.
-->

**Source:** [URL] | **Retrieved:** [YYYY-MM-DD] | **Catalogue:** [ITSG-33 Annex 3A / NIST SP 800-53 Rev 4 parallel — see note below]
**Retrieval method:** [full-page retrieval / local raw capture] | **Raw capture:** [path under docs/compliance/.control-text/]

<!-- If the text came from the NIST 800-53 Rev 4 parallel rather than Annex 3A, keep the following line. Otherwise delete it. -->
> **Note:** This wording is the NIST SP 800-53 Rev 4 parallel control, not verbatim ITSG-33 Annex 3A text. Confirm against Annex 3A before submission.

A. [Verbatim text of part A]

B. [Verbatim text of part B]

<!-- Repeat one lettered line per top-level part of the control. Delete B if the control has only one part. -->

### 2.2 Supplemental Guidance

<!-- Official supplemental guidance, transcribed verbatim. Same sourcing rule as 2.1. -->

**Source:** [URL] | **Retrieved:** [YYYY-MM-DD] | **Catalogue:** [ITSG-33 Annex 3A / NIST SP 800-53 Rev 4 parallel]

[Verbatim supplemental guidance text]

### 2.3 Tailoring and Implementation Notes

<!-- How this control was interpreted and scoped for THIS system. Cover: scope boundary (what the control does and does not apply to here), any CCCS Medium tailoring applied, inheritance rationale (what AWS provides versus what the project configures), and any compensating controls relied upon. This is the section an assessor reads to understand the reasoning, so state the reasoning, not the outcome. -->

[Tailoring and implementation notes]

### 2.4 Recommended Values

<!--
Assignment and selection parameters the control leaves to the organization
(e.g. "[Assignment: organization-defined time period]").
Record the value selected, where it came from, and what is actually configured.
List one row per parameter. If the control defines no parameters, replace the table with:
"This control defines no organization-assigned parameters."
-->

| Parameter | Assignment Source | Recommended Value | Implemented Value | Evidence Ref |
|---|---|---|---|---|
| [Parameter as worded in the control] | [CCCS Medium profile / GC policy / Departmental standard] | [Recommended value] | [Value actually configured] | [Artifact ID from 3.2, e.g. AC-2-A-01] |

---

## 3. Evidential Response

### 3.1 Description

<!-- Narrative rationale: why the evidence in 3.2 satisfies the control as defined in 2.1, read against the tailoring in 2.3. Argue the case; do not just list what exists. Where a part is not satisfied, say so plainly here rather than burying it in 3.2. -->

[Narrative and rationale]

**Verdict Summary**

<!-- One row per lettered part in 2.1. The Overall Status in Document Control must be consistent with this table: any part Not Satisfied makes the control at best Partially Satisfied. -->

| Part | Requirement (short) | Assessment |
|---|---|---|
| A | [Short restatement] | [Satisfied / Partially Satisfied / Not Satisfied / Not Applicable] |
| B | [Short restatement] | [Satisfied / Partially Satisfied / Not Satisfied / Not Applicable] |

<!-- One row per lettered part. Delete row B for a single-part control; add rows for C, D, ... as needed. -->

### 3.2 Artifacts

<!--
One block per lettered part in 2.1, in the same order and with the same letters.
Artifact IDs follow <CONTROL-ID>-<PART>-<NN>, e.g. AC-2-A-01. They are referenced from
2.4, from section 4, and by assessors in review comments, so they must be stable.
Every Location must resolve: a repo path with line range, a console screenshot committed
to the package, a document reference, or a URL. Never cite evidence that does not exist.
-->

#### 3.2.A — [Restated requirement of part A]

**Implementation:** [How the system meets this specific requirement]

**Assessment:** [Satisfied / Partially Satisfied / Not Satisfied / Not Applicable]

**Rationale:** [Why the artifacts below demonstrate the requirement is met, or what is missing if it is not]

| Artifact ID | Type | Location / Reference | Date | Description |
|---|---|---|---|---|
| [CONTROL-ID]-A-01 | [IaC / Config / Screenshot / Policy / Log / Document] | [e.g. lib/network/vpc.ts:42-58] | [YYYY-MM-DD] | [What this artifact shows] |

#### 3.2.B — [Restated requirement of part B]

**Implementation:** [How the system meets this specific requirement]

**Assessment:** [Satisfied / Partially Satisfied / Not Satisfied / Not Applicable]

**Rationale:** [Why the artifacts below demonstrate the requirement is met, or what is missing if it is not. Where the part has nested sub-items, address each one.]

| Artifact ID | Type | Location / Reference | Date | Description |
|---|---|---|---|---|
| [CONTROL-ID]-B-01 | [IaC / Config / Screenshot / Policy / Log / Document] | [Location] | [YYYY-MM-DD] | [What this artifact shows] |

<!-- Repeat a 3.2.<letter> block for every remaining lettered part in 2.1. -->

---

## 4. Residual Risk and Gaps

<!-- Required whenever Overall Status is anything other than Satisfied. If the control is fully Satisfied, replace the table with: "No residual risk identified. This control is fully satisfied." -->

| Part | Gap | Risk Rating | Compensating Control | Remediation Reference |
|---|---|---|---|---|
| [A] | [What is missing] | [Critical / High / Medium / Low] | [Compensating control, or "None"] | [Link to the entry in ../phase3-gap-analysis.md] |

<!-- Generated standalone, before any gap analysis exists? Use exactly: "none — generated standalone; gap analysis not yet produced" in Remediation Reference. -->

## 5. Traceability

| Reference | Path |
|---|---|
| Architecture Discovery | [../phase1-discovery.md] |
| Control Mapping | [../phase2-control-mapping.md] |
| Gap Analysis | [../phase3-gap-analysis.md] |
| Related Controls | [e.g. AC-3, AC-6 — controls whose evidence depends on or overlaps this one] |

---

**PROTECTED B**
