---
name: itsg-assessment
description: Map project architecture to ITSG-33 / CCCS Medium Cloud Profile security controls for Canadian GC cloud workloads handling Protected B data. Produces a phased compliance assessment with AWS control inheritance and risk-rated gap analysis. Use when asked to assess ITSG, run a CCCS Medium compliance check, evaluate Canadian cloud compliance, map ITSG-33 controls, perform a GC cloud security assessment, check Protected B data handling requirements, write a control evidence document, or produce SA&A evidence for a specific control such as AC-2. Do NOT use for FedRAMP, NIST CSF, SOC 2, PBMM standalone reviews, TBS cloud profile assessments, or other non-ITSG-33 compliance frameworks.
compatibility: "AWS workloads in Canadian regions (ca-central-1, ca-west-1). Requires network access for Phase 0 control validation and Phase 4 control text retrieval. Phase 4 runs scripts/extract-control.py (python3, standard library only)."
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
- **No fabricated control text**: Official control definitions and supplemental guidance are transcribed only from a retained raw capture or the cache in `docs/compliance/.control-text/`. Search-engine snippets are not a source. If nothing is retrievable, emit a `[VERIFY-SOURCE]` marker and report it. Never write control wording from memory.
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
| `controls/<CONTROL-ID>.md` | Per-control SA&A evidence document (Phase 4, opt-in) |

Before writing any phase output, read `references/phase-templates.md` for the required format.

## Example

User: "Run an ITSG-33 compliance assessment on this CDK project."

1. Phase 0 — Validate controls against official ITSG-33 sources
2. Phase 1 — Scan `cdk.json`, `lib/`, pipeline definitions; identify AWS services, data residency, trust boundaries; write `docs/compliance/phase1-discovery.md`; checkpoint with user
3. Phase 2 — Map each control from `references/itsg33-controls.md` against discovered architecture; classify inheritance; write `docs/compliance/phase2-control-mapping.md`; checkpoint with user
4. Phase 3 — Produce risk-rated gap entries for unimplemented controls; write `docs/compliance/phase3-gap-analysis.md` and `docs/compliance/assessment-summary.md`
5. Phase 4 — Offer per-control evidence documents; if accepted, write `docs/compliance/controls/<CONTROL-ID>.md` for each in-scope control

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

## Phase 4 — Control Evidence Documents

Opt-in. Offer this phase after presenting the Phase 3 summary; never run it automatically. It produces the per-control artifact a GC assessor requests during SA&A — one formal document per control, carrying the official control wording, tailoring decisions, selected parameter values, and a per-requirement evidence response.

### Entry Points

- **After Phase 3** — offer it, report how many controls are in scope, and let the user narrow the list before generating.
- **Standalone** — a request naming specific controls ("write the evidence document for AC-2") enters here directly. Read `docs/compliance/phase2-control-mapping.md` if it exists; if it does not, run a targeted single-control discovery rather than a full Phase 1. Evidence documents are commonly rewritten one at a time when assessor comments come back.

### Scope

Every control in `phase2-control-mapping.md` not marked **Not Applicable**. Report the count and the list before generating anything.

### Control Text Resolution

Sections 2.1 and 2.2 require the official control wording. Resolve it in this order:

1. **Cache** — `docs/compliance/.control-text/<FAMILY>.md`. A cache entry is valid only if its raw capture (`annex3a.raw.html`) is present alongside it. An entry without raw backing is not trusted; fall through to step 2.
2. **Retrieve and extract** — run the extractor, which retains the raw capture and writes a cache entry carrying source, retrieval date, retrieval method, and part count:

   ```
   python3 scripts/extract-control.py --url <Annex 3A URL from references/official-references.md> \
       --control <CONTROL-ID> --out-dir docs/compliance/.control-text
   ```

3. **Fallback** — NIST SP 800-53 **Rev 4**, which is the revision Annex 3A follows. Full-page retrieval only. Keep the template's note stating the text is the NIST parallel rather than verbatim ITSG-33.
4. **Neither available** — write `[VERIFY-SOURCE: not retrieved — paste official wording from <URL>]` into 2.1 and 2.2. Never generate control text.

**Search-engine snippets and answer-engine summaries are not acceptable sources for 2.1 or 2.2.** They return wording stripped of list structure, which produces text that looks correct while silently losing the official part boundaries. If a full-page retrieval is unavailable, go to step 3 or 4 — do not substitute a search result.

### Decomposing a Control into Parts

Annex 3A states each control as an ordered list styled `list-style-type: upper-alpha`, so a browser renders the parts as **A., B., C.** Those markers are generated by CSS, not present in the text, so tag-stripping extractors and copy-paste drop them and the control appears to be unlettered prose. It is not.

- **One part per top-level list item** of the control's Control block, lettered A, B, C in document order. This matches the official rendering — do **not** add a note claiming the lettering is assessor-added.
- **Nested sub-items** (Annex 3A styles them `lower-alpha`) stay inside their parent part in both 2.1 and its `3.2` block. Artifact IDs remain `<CONTROL-ID>-<PART>-<NN>`, and the 3.2 Rationale must address each sub-item. AC-2, AC-5, SA-4, SI-3 and SI-4 all have them.
- **Single-item controls** — many in-scope controls, including SC-28 — yield part A only.

The extractor in step 2 applies these rules directly; prefer its output over reading the parts off a rendered page.

### Control Enhancements

Evidence documents cover base controls only. Annex 3A lists control enhancements separately, and the CCCS Medium profile selects some of them. They are **out of scope** for Phase 4 — state this in the checkpoint so the limitation is declared rather than discovered by an assessor.

### Status Mapping

Phase 2 and the evidence document use different vocabularies. Treat them as equivalent:

| Phase 2 status | Evidence document Overall Status |
|---|---|
| Implemented | Satisfied |
| Partially Implemented | Partially Satisfied |
| Not Implemented | Not Satisfied |
| Not Applicable | Not Applicable (out of Phase 4 scope; only reachable via a standalone request) |

### Per Control

1. Resolve the control text as above.
2. Copy `assets/control-evidence-template.md`.
3. Fill it from the Phase 2 evidence for that control, plus targeted reads of the cited files. Decompose the control per the rules above — section 3.2 must have one block per part, in the same order and with the same letters.
4. Verify against `references/control-evidence-checklist.md`.
5. Write `docs/compliance/controls/<CONTROL-ID>.md`.

Read `references/control-evidence-example.md` before generating the first document in a session.

### User Checkpoint

Report the files generated, every `[VERIFY-SOURCE]` marker left unresolved with its control ID, any control whose per-part verdicts disagree with its Phase 2 status, and the fact that control enhancements are out of scope.

## Error Handling

| Situation | Action |
|---|---|
| No IaC files detected | Report what was searched, ask user if controls exist outside codebase |
| No architecture docs found | Proceed with code-only analysis, note reduced confidence in Phase 1 output |
| Empty or minimal project | Report insufficient evidence for assessment, ask user for additional context before proceeding |
| Phase 4 control text unavailable | Emit `[VERIFY-SOURCE]` in sections 2.1 and 2.2, continue the document, report the marker at the checkpoint |

## References

- Control family tables and inheritance model: `references/itsg33-controls.md` — read during Phase 2 to map each control
- Output format templates: `references/phase-templates.md` — read before writing any phase output
- Official documentation links: `references/official-references.md` — read during Phase 0 for validation URLs
- Evidence document template: `assets/control-evidence-template.md` — copy for each control during Phase 4
- Completed example: `references/control-evidence-example.md` — read before generating the first evidence document in a session
- Completeness gate: `references/control-evidence-checklist.md` — read before writing each evidence document
- Control text extractor: `scripts/extract-control.py` — run during Phase 4 step 2; invoke with `python3`, never `./`
- Cached official control wording: `docs/compliance/.control-text/<FAMILY>.md` plus its `annex3a.raw.html` raw capture — written by the extractor, read during Phase 4 control text resolution
