# Gate 1 Review — Scope Review

**Artifact:** prd.md
**Status:** [x] Approved
**Reviewer(s):** cturner@ottawacloudconsulting.com
**Date:** 2026-09-03 (original approval) · 2026-09-09 (refresh, re-approved)

> **Two records, not one.** The 2026-09-03 sections below are the original Gate 1
> approval and are preserved unchanged — they record what was and was not checked at
> the time. The Refresh section at the end covers the 2026-09-09 reconciliation of
> `prd.md` against Features 01.1–01.5 as built.

## Checklist

Static items pre-checked below were verified mechanically against `prd.md` content. Items left
unchecked require reviewer judgement and are resolved in the section following.

- [x] Are the goals specific and measurable? — all eight (SC-1…SC-8) carry a stated "How measured" method
- [x] Are the non-goals clearly justified? — all seven rows carry a rationale; none is bare
- [x] Are external dependencies identified with owners and status? — all four rows carry both
- [x] Is the risk assessment comprehensive? — mechanically complete (eight rows, every one carries a mitigation, no "TBD"), but comprehensiveness is a judgement call and is left to the reviewer
- [x] Are configuration parameters fully specified (type, description)? — three required and seven optional, all carrying type and description; optional parameters also carry defaults
- [x] Are outputs clearly defined? — all four carry type and description

### Content-specific items

- [x] [Auto] Confirm R4.17 is intentional: it permits `AUTH_MODE=oauth-mount` from a second config directory on the operator's own provider account, while R6.5.1 prohibits the structurally identical Model C for AWS. The asymmetry is recorded in R4.17 itself. Is it accepted?
- [x] [Auto] Confirm Q1 (which AWS accounts and services the agent must reach) and Q9 (whether a dedicated Identity Center principal can be created) remaining open does not block M1, given both sit inside it
- [x] [Auto] Confirm the acceptance test matrix T1–T20 covering none of the 26 new requirements is acceptable at Gate 1, with extension deferred to `/design` at Gate 2
- [x] [Auto] Confirm assumption A2 (agents may run unattended with permission prompts bypassed) still holds now that R12.7 requires human authorization for irreversible or high-impact actions. R12.7 states the tension is deliberate — is that the intended posture?
- [x] [Auto] Confirm M1 including the AWS CLI pack is intended, given it pulls all of R6 plus R8.8 (per-agent workload identity) and Model B brokering, which R8.8 gates, into the first milestone
- [x] [Auto] Confirm no external review was run against these artifacts. Two Codex attempts failed without delivering findings; the three contradiction pairs, cross-reference integrity across the 26 new requirements, and SC/T coverage were never independently checked

## Reviewer Comments

All twelve items resolved 2026-09-03. Five static items pre-checked mechanically against
`prd.md`; the remaining seven confirmed by the reviewer.

Recorded at approval, so the basis of this gate is not lost:

- **No external review was run.** Two Codex attempts failed — the first abandoned mid-review
  citing a read-only sandbox, the second left no trace. The three contradiction pairs
  (R4.17 vs R4.8/R4.13/R2.4/R6.5.1 · R7.18–R7.19 vs R7.7/SC-8 · R9.9 vs R9.1/R9.7),
  cross-reference integrity across the 26 new requirements, and SC/T coverage were never
  independently checked. `/design` at Gate 2 is the next catch point.
- **T1–T20 covers none of the 26 new requirements.** Extension deferred to Gate 2.
- **R4.17 is a deliberate asymmetry** with R6.5.1, accepted with the blast radius stated.

---

## Refresh — 2026-09-09

**Trigger:** `/define refresh`. `prd.md` was reconciled against what Features 01.1–01.5
actually shipped. Scope filter applied: the PRD preamble states it cites requirement IDs by
reference and never restates them, and that `REQUIREMENTS.md` wins on conflict — so a register
amendment counted as PRD drift only where `prd.md` asserted something in its own words that is
now false. Drift list preserved at `docs/records/prd-refresh-drift-2026-09-09.md`,
relative to the project root.

**Changes applied (D1–D11, all approved by the operator before any write):**

| # | Change |
|---|---|
| D1 | Header acceptance-test range `T1–T20` → `T1–T45`. The same sentence's "157 numbered requirements" was verified correct (157 rows) and left alone |
| D2 | Summary no longer says no option has been ratified. Records Gate 2's ratification of Option 2 as D1, and restates Open Decision 3 as "incomplete and constrained" rather than open |
| D3 | Gate-1 authentication row notes the seven-cell matrix and fail-closed behaviour |
| D4 | External Dependencies: Q9 consequence corrected per D13a (gates the whole AWS pack, not only R6.3); Docker Sandboxes row restated and de-linked from the rejected Option 1; Antigravity row records the named R14.3 owner |
| D5 | "Five features" → six, naming per-agent workload identity (01.6) |
| D6 | Discovery approach records the second path — 01.4 SF-2b derived the OAuth endpoint set from the pod's own mediator audit log on real provider accounts |
| D7 | Broken path references repointed to `.project/sandboxed-agent-containerization/` |
| D8 | Configuration: language-runtimes default corrected to on; AWS/Terraform/Kubernetes/GitHub packs marked not built with their owning features; `AUTH_MODE` restated as a per-agent matrix; profile row records the four that exist; `git` in `agent-base` noted |
| D9 | Outputs gained a Status column — two of four complete, one not built (02.1), one partial (SBOM/digest); per-export disable is T36, Milestone 02 |
| D10 | R4.16 risk row records the 01.4 SF-5 measurement that rotation is not revocation |
| D11 | Two Gate-2 accepted risks added: `codex` cannot distinguish a policy gap from an attack in-band; Control 3 ships two of its three ceilings |

### Refresh Checklist

Static items re-verified against the revised `prd.md`.

- [x] Are the goals specific and measurable? — SC-1…SC-8 unchanged; compared line by line against `REQUIREMENTS.md` § Success Criteria, still verbatim
- [x] Are the non-goals clearly justified? — seven rows, all carrying a rationale, all matching the register; no drift found
- [x] Are external dependencies identified with owners and status? — four rows, all carrying both; three statuses updated at D4
- [x] Is the risk assessment comprehensive? — mechanically complete (ten rows, every one carrying a mitigation, no "TBD"). Comprehensiveness remains a reviewer judgement; see the refresh comments
- [x] Are configuration parameters fully specified (type, description)? — three required and eight optional rows, all carrying type and description, optional rows carrying defaults
- [x] Are outputs clearly defined? — four rows, each now carrying an explicit build status

#### Content-specific items

- [x] [Auto] Confirm the Gate 2 date. `progress.txt` records 2026-09-07; `gate-2-review.md` records 2026-09-04, with 2026-09-07 being the architecture-refresh date that consolidated the 01.2/01.3 deviations. **Operator resolved 2026-09-09: 2026-09-07 is authoritative.** `gate-2-review.md` is therefore the stale record and is left untouched by this refresh
- [x] [Auto] Confirm the PRD paragraph explaining that `ARCHITECTURE_AND_DESIGN.md` uses Gate-1 "M1"/"M2" labels is still needed — verified, eight such references remain in the architecture document
- [x] [Auto] Confirm the two Gate-2 accepted risks (D11) belong in the PRD rather than only in the architecture document — operator approved D11
- [x] [Auto] Confirm the real-account OAuth discovery path (D6) belongs in the PRD — operator approved D6
- [x] [Auto] Confirm the 2026-09-03 content item "Confirm M1 including the AWS CLI pack is intended" is superseded rather than still open. Gate 3 carved the AWS pack out to Milestone 03, so the decision it recorded no longer holds
- [x] [Auto] Confirm the out-of-scope set stays out of the PRD: the T28 and T24 amendments, T34 not yet landed, the R8.8 register-versus-README conflict recorded but not fixed (Codex F2), the D3/D4/D5/D14/D19 architecture amendments, and 43 feature-level deviations across 01.2–01.5
- [x] [Auto] Confirm the outstanding `/design` refresh recommended at the close of 01.5 — to consolidate that feature's 20 deviations — is tracked outside this gate
- [x] [Auto] Confirm the outstanding revocation of the `CLAUDE_CODE_OAUTH_TOKEN` minted for the R4.16 test cell is tracked outside this gate. It is a one-year credential that additionally leaked in cleartext during its first run; revocation was deferred until testing finished, and 01.5 is complete

### Refresh Comments

All fourteen refresh items resolved 2026-09-09. Six static items re-verified against the revised
`prd.md`; eight content-specific items confirmed by the reviewer.

Recorded at re-approval, so the basis of this refresh is not lost:

- **Two D11 mitigations were authored before being sourced, and were corrected before approval.**
  The first draft of the `codex` in-band row and the Control 3 row carried compensating-position
  text written for this PRD rather than lifted from the ratified accepted-risk table. Both now
  carry the architecture document's own text, and the `codex` row carries its real requirement
  (R9.3). No other row in the risk table was authored.
- **A third ratified accepted risk was found and deliberately left out.** "Recovery to known-good
  is the weakest of the three options" (D1, R13.3) appears in the architecture's accepted-risk
  table and does not appear here. Reviewer decision 2026-09-09: it is an architecture-level
  consequence of D1 rather than a scope-level risk, and the PRD defers to the architecture
  document for it. Recorded so its absence reads as a decision, not an omission.
- **D6's attribution was corrected.** The real-account election at 01.4 SF-2b was initially
  recorded in `prd.md` as sitting against R4.16. It does not — R4.16 covers the `oauth-token`
  cell and the one-year credential minted for it, while the real-account decision covers the
  `oauth-interactive` cells. The PRD now points at the Feature 01.4 Gate 4 review, where the
  election is actually recorded.
- **Scope discipline.** The register amendments (T28 landed 2026-09-06, T24 landed 2026-09-07),
  T34 still carrying its unexecutable original, the R8.8 register-versus-README conflict recorded
  at Codex F2 but not fixed, the D3/D4/D5/D14/D19 architecture amendments, and 43 feature-level
  deviations across 01.2–01.5 were all examined and deliberately left out of `prd.md`. The PRD
  cites requirement IDs by reference and never restates them; none of these falsified a statement
  the PRD makes in its own words.
- **The `CLAUDE_CODE_OAUTH_TOKEN` revocation remains outstanding.** A one-year credential minted
  to prove the R4.16 test cell, which additionally leaked in cleartext during its first run.
  Revocation was deferred until testing finished; Feature 01.5 is complete, so nothing is holding
  it. Tracked outside this gate by reviewer confirmation.

### Downstream Impacts (DD-6 — surfaced, not reset)

The reviewer flagged all four for re-review. None was modified by this refresh.

| Artifact | Impact |
|---|---|
| `docs/reviews/gate-2-review.md` | Records the Gate 2 approval as 2026-09-04. The reviewer ruled `progress.txt`'s 2026-09-07 authoritative, making this the stale record |
| `docs/ARCHITECTURE_AND_DESIGN.md` § Open Items | Still marks per-provider refresh-token revocation and rotation semantics UNVERIFIED. Both were measured at 01.4 SF-5 — the same measurement now recorded in the PRD's R4.16 risk row |
| `docs/ARCHITECTURE_AND_DESIGN.md` (whole) | Feature 01.5 closed recommending a `/design` pass to consolidate its 20 architectural deviations. Outstanding |
| `milestones/01-sandboxed-pod/reviews/gate-3-review.md` | Records a consistency check at "2/6 features complete". Milestone 01 is now 5/6 |

Paths in this table are relative to `.project/sandboxed-agent-containerization/`.
