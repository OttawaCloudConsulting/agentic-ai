# Gate 2 Review — Design Review

**Artifact:** .project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md
**Status:** [x] Approved
**Reviewer(s):** cturner@ottawacloudconsulting.com
**Date:** 2026-09-04

## Checklist

Items marked below as pre-checked were verified mechanically against the artifact. Items
requiring reviewer judgement follow in the content-specific section.

- [x] Are the design decisions sound? Are tradeoffs acceptable? — mechanically complete (22 decisions, every row carrying rationale, tradeoff and alternatives; no row left "TBD"). Soundness is a judgement call and was confirmed by the reviewer at the Approve step
- [x] Is the component inventory complete? — 15 components, each with responsibility and interfaces. Completeness confirmed against the architecturally load-bearing requirements: enforcement point (R1.2), per-agent volumes (R4.3), policy compiler (SC-6), audit sink (R9.1/R9.2), action recorder (R9.7), broker (R6.5), build pipeline (SC-8)
- [x] Does the data flow match your understanding of the system? — six flows documented (allowed request, blocked attempt, DNS, audit write, profile→policy/image, auth bootstrap per mode). Confirmed by the reviewer at the Approve step
- [x] Are there security considerations missing? — threat model, trust boundary, authentication/access control, six accepted risks and six explicitly absent controls documented. The absent-controls table is stated so an absent control is not mistaken for a satisfied one

### Content-specific items

- [x] [Auto] Verify decision D1: Option 2 ratified, accepting the worst return-to-known-good of the three options in exchange for L7 FQDN correctness, extensibility and a self-owned audit trail — approved by the reviewer
- [x] [Auto] Verify decision D13a: a negative answer to Q9 leaves **no** compliant AWS credential model. Model C is prohibited (R6.5.1), Model B needs a principal to broker from, and Model A needs a dedicated Identity Center user or group (R6.5.2, MUST). M1 includes the AWS pack, so a negative Q9 forces an M1 rescope rather than a substitution. Correction to the Gate 1 record, which had Q9 gating Model B only
- [x] [Auto] Verify decision D20: R9.7 (MUST) is carried by shipping each agent's own session transcript off-container in real time. The agent authors its own transcript, so this delivers tamper-**evidence**, not tamper-**resistance**, and attribution still waits on R8.8. Recorded in the absent-controls table rather than hidden
- [x] [Auto] Verify decision D21: base image built by GitHub Actions and published to GitHub Packages, consumed by **digest, never by tag**. Builds run from the working branch during the project (testing only) and move to `main` on completion. Introduces this repository's first `.github/` workflow
- [x] [Auto] Verify decision D19 as amended: buildable artifacts live in `solutions/agent-containerization/` as copyable content; only the base image travels via the registry
- [x] [Auto] Confirm the splice-only posture (D4 / R5.15): no content-level DLP exists anywhere in the architecture, including on the channels carrying 100% of prompt and completion content. Accepted, with the mediator positioned to add termination later (R15.2) and Antigravity permanently barred (R5.13)
- [x] [Auto] Confirm the acceptance-test extension: T21–T45 appended to `REQUIREMENTS.md` § Acceptance Test Matrix at the reviewer's direction, covering all 30 requirements added at Gate 1 plus the CI-published image (T45). T1–T20 unmodified
- [x] [Auto] Confirm cross-reference integrity result: 78 cited R-IDs against 171 defined, zero genuine dangling references. R6.3 and R6.5 are section-level group references; R15.1 is deliberately recorded in Non-Goals
- [x] [Auto] Confirm the three suspected contradiction pairs are each self-reconciling in the register, and that each nevertheless forces a structural obligation now recorded as D8, D10 and D11
- [-] [Auto] Independent external review of the Gate 2 artifact — not run. N/A at this gate for the same reason recorded at Gate 1: two Codex attempts failed there and no external reviewer was available here either. The mechanical checks (ID resolution, section presence, table population, T1–T20 preservation) were run and are recorded above; the design judgement was not independently checked
- [-] [Auto] Verify `agy` honours `HTTPS_PROXY` — N/A at design time, cannot be resolved on paper. UNVERIFIED and recorded in Open Items as blocking D1 for one agent; scheduled for verification **before** the M1 build rather than during it
- [-] [Auto] Resolve Open Decision 3 (Docker Sandboxes retention and data-handling terms) — N/A at this gate. Governed by R14.1; the synthetic-repository and throwaway-credential constraint is the mitigation, and it blocks only a discovery run against a representative repository
- [-] [Auto] Assign an owner to the Antigravity ToS position — N/A at this gate, requires a named person rather than a design decision. Carried in Open Items as unassigned

## Reviewer Comments

Gate 2 approved 2026-09-04. The architecture ratifies Option 2 from `docs/OPTIONS_ANALYSIS.md`.

Recorded at approval, so the basis of this gate is not lost:

- **Gate 1's three deferred items are all resolved here.** Cross-reference integrity is clean; the
  three suspected contradiction pairs are not contradictions but each forces a structural
  obligation; the acceptance-test matrix has been extended and applied to the register.
- **Gate 1 undercounted the new requirements.** It recorded 26; the measured delta between
  `d303b55` and `442952c` is **30** newly defined requirements, none removed (126 rows to 156).
  All 30 are covered by T21–T44.
- **Q9 is a harder gate than Gate 1 recorded** — see D13a. It gates the entire AWS CLI pack, not
  only Model B brokering.
- **R9.7 had no component before this gate.** D20 names one and states its limitation plainly
  rather than implying an action log the architecture cannot produce.
- **No independent external review was run on this artifact**, matching the Gate 1 position. The
  mechanical checks were run; the design judgement was not independently checked.
- **Deferred to build, not resolved here:** Q1, Q9, Open Decision 3, the Antigravity ToS owner, and
  six items flagged UNVERIFIED — of which `agy`'s `HTTPS_PROXY` support is the one that can
  invalidate the design for a single agent on day one.
