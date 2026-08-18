# Control Evidence Completeness Checklist

Read this before writing any `docs/compliance/controls/<CONTROL-ID>.md` file in Phase 4. Every item must pass, or the failure must be reported to the user at the Phase 4 checkpoint. A document that fails any item is not submission-ready.

## Template Hygiene

- No unfilled **template** placeholders remain — the `[Bracketed guidance]` fields that came from `assets/control-evidence-template.md`.
- **Exempt from that check, and required to stay exactly as written:** the official `[Assignment: ...]` and `[Selection: ...]` brackets inside the verbatim text in 2.1 and 2.2, and any `[VERIFY-SOURCE]` marker. These are catalogue text and status markers, not fields to fill. Chosen parameter values belong in 2.4 — never substituted into 2.1 or 2.2.
- All `<!-- ... -->` guidance comments from the template have been deleted.
- The classification marking appears at both the top and the bottom of the document.
- Document Control, Revision History, and Approvals tables are populated. Signature cells stay blank — they are signed after review.

## Control Text Integrity

- Sections 2.1 and 2.2 carry a provenance line with a real source URL, a retrieval date, the catalogue, the retrieval method, and the raw capture path.
- The raw capture named in the provenance line exists under `docs/compliance/.control-text/`.
- **Substring check:** each part's text in 2.1, and the guidance in 2.2, appears in the retained raw capture (ignoring whitespace and markup). Text that is not in the capture was not retrieved from it.
- **Part count check:** the number of lettered parts in 2.1 equals the number of top-level list items in the raw capture's Control block for this control.
- Control text was transcribed from a retained raw capture or the cache — never from a search-engine snippet, and never from memory.
- Where text came from the NIST SP 800-53 Rev 4 parallel rather than ITSG-33 Annex 3A, the note saying so is present in 2.1 and the catalogue field in 2.2 says the same.
- Any `[VERIFY-SOURCE]` marker still in the document is reported to the user by control ID and section. Never silently ship one.

## Structural Consistency

- Parts in 2.1 are lettered A, B, C in catalogue order, one per top-level list item of the Control block. No note claims the lettering is assessor-added — it is the official lettering.
- Nested sub-items sit inside their parent part in 2.1 and are addressed in that part's `3.2` Rationale. They do not become separate lettered parts.
- Every lettered part in 2.1 has a matching `3.2.<letter>` block, in the same order. Single-part controls have only `3.2.A`.
- No `3.2.<letter>` block exists for a letter that is not in 2.1.
- The Verdict Summary table in 3.1 has one row per lettered part.
- Overall Status is consistent with the per-part verdicts: any part Not Satisfied makes the control at best Partially Satisfied; all parts Satisfied is required for Satisfied.
- Overall Status is consistent with the control's Phase 2 status under the mapping in SKILL.md (Implemented = Satisfied, Partially Implemented = Partially Satisfied, Not Implemented = Not Satisfied), or the divergence is reported to the user.

## Evidence Quality

- Every artifact row has a Location that resolves — a repo path with a line range, a committed screenshot, a document reference, or a URL.
- Cited line ranges were opened and confirmed to contain what the Description claims.
- Artifact IDs follow `<CONTROL-ID>-<PART>-<NN>` and are unique within the document.
- No artifact is cited that does not exist. An absent artifact is a gap, recorded in section 4 — not an invented reference.
- Every parameter row in 2.4 with an Implemented Value points at an artifact ID that exists in 3.2.
- Every `[Assignment: ...]` and `[Selection: ...]` appearing in 2.1 has a corresponding row in 2.4, or 2.4 states the control defines no organization-assigned parameters.

## Gaps and Traceability

- Section 4 is populated whenever Overall Status is anything other than Satisfied, and each gap links to its entry in `phase3-gap-analysis.md`.
- **Standalone generation:** when the document was produced without a Phase 3 gap analysis, Remediation Reference reads exactly `none — generated standalone; gap analysis not yet produced`. A missing `phase3-gap-analysis.md` is not a checklist failure in that case.
- Where Overall Status is Satisfied, section 4 states that no residual risk was identified rather than being left empty.
- Section 5 paths resolve relative to `docs/compliance/controls/`.
