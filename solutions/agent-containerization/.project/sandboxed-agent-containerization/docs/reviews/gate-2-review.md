# Gate 2 Review — Design Review

**Artifact:** .project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md
**Status:** [x] Approved
**Reviewer(s):** cturner@ottawacloudconsulting.com
**Date:** 2026-09-04 (original approval) · 2026-09-09 (deviation-consolidation refresh)

> **Two records, not one.** Everything below the header down to the Refresh section is the
> original Gate 2 approval, preserved unchanged. The Refresh section records the 2026-09-09
> `/design` deviation-consolidation pass.
>
> **Date note.** `progress.txt` carried `Approved: 2026-09-07` against this file's 2026-09-04.
> The 09-07 date was the architecture refresh that consolidated the 01.2 and 01.3 deviations,
> not a re-approval. The operator ruled 09-07 authoritative on 2026-09-09; this file keeps
> 2026-09-04 as the date of the original approval, which is what it records.

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

---

## Refresh — 2026-09-09 (deviation consolidation)

**Trigger:** `/design refresh`, to consolidate accumulated architectural deviations and clear the
two Open Items that Feature 01.4's measurements resolved.

**Scan result.** 43 deviations across the five Milestone 01 feature plans — 01.1: 0, 01.2: 3,
01.3: 11, 01.4: 9, 01.5: 20. Each was checked against the architecture document itself rather
than against the plan's own status field, because the plans do not record consolidation; only
`milestone-status.txt` does, and it was not complete.

| Bucket | Count | Disposition |
|---|---|---|
| Already consolidated | 20 | 01.2 all three, 01.3 all eleven (both on 2026-09-07), 01.4-D1 (the file tree already carries a NOTE citing it), 01.5-D10/D11/D14/D15/D17. 01.4-D9 is closed by 01.5-D2 |
| Consolidated by this pass | 18 | 01.4-D2, D3, D4, D5 · 01.5-D1, D2, D3, D4, D5, D6, D7, D8, D9, D12, D13, D16, D19, D20 |
| Left in the feature plans | 4 | 01.4-D6, D7, D8 and 01.5-D18 — test-harness internals that touch none of the six architecture sections. Operator decision 2026-09-09 |

**Where the 18 landed.** D2 (agent-network `ip_range`), D8 (the seven-cell `AUTH_MODE` matrix and
the T24 amendment) and D10 (packs declare egress and OS packages only; `git` in `agent-base`;
base-image-forced pack versions) in Design Decisions. Networks, tool packs and the policy compiler
in Component Inventory. `compose/overrides/`, `profiles/`, `packs/` and `scripts/` in File
Organization. Entry point, build sequence, startup self-checks and reproducibility in Deployment &
Operations. Identity-as-built, the apt-closure residual and the adversarial-pass findings in
Security Considerations.

**Two Open Items cleared, both from Feature 01.4 measurements.**

- *Refresh-token rotation semantics* — resolved at 01.4 SF-3. Both providers roll the refresh
  token, cross-validated against mediator audit lines. `claude`'s `refreshTokenExpiresAt` is not
  extended by a refresh; `codex` triggers on the access token's own JWT `exp` and does not verify
  that JWT's signature locally.
- *Per-session refresh-token revocation* — resolved at 01.4 SF-5, **negatively**. A superseded
  refresh token replayed successfully against the same account, so rotation is not a revocation
  mechanism. Measured for **OpenAI**; **Anthropic was not replayed**. The asymmetry is carried
  verbatim into the document rather than generalised.

### Refresh Checklist

- [x] Every deviation scanned was classified, and its classification checked against the document rather than the plan
- [x] Decision count unchanged at 22 (D1–D21 plus D13a) — no decision row was added or removed
- [x] The document lints clean under the repository markdownlint configuration
- [x] The two cleared Open Items carry their measurement asymmetry rather than a bare "Resolved"
- [x] [Auto] Confirm the identity rewrite. The operator elected to describe network-derived identity for `codex` and `agy` as the built mechanism in Security Considerations. `REQUIREMENTS.md` R8.8 is unamended and a strict reading does not accept it. The rewrite records that disagreement — sourced to Codex finding F2 in the Feature 01.3 Gate 4 review, which recorded it as "recorded, not fixed here", and to `docs/records/r8-8-identity-mechanism-gap-escalation.md` — and assigns resolution to Feature 01.6 rather than settling it
- [x] [Auto] Confirm four consistency corrections made outside the deviation set, all of which contradicted already-consolidated material: the build sequence said native sandboxes are enabled (D14 was amended to disabled at the 01.2 build); it said "Run T1–T20" (the register runs to T45); step 0 said the Docker Sandboxes assessment was "Not done" (Open Items records it attempted and incomplete); and the packs tree had the AWS CLI and Kubernetes milestone assignments transposed
- [x] [Auto] Confirm the Observability correction. The section asserted "Four artifacts, produced by default, exported by default", which is not true today — the agent action log is Feature 02.1, the SBOM exists only for the CI-published base image, and the per-export disable is T36 in Milestone 02. It is not a deviation, but `prd.md` was corrected on the same point earlier the same day, so leaving it would have made the two documents disagree. **Operator decision 2026-09-09: fix it in this pass, out of deviation scope.** A per-artifact build-status table now follows the target-state sentence

### Refresh Comments

All refresh items resolved 2026-09-09. The architecture document was approved without revision.

Recorded at approval, so the basis of this refresh is not lost:

- **Two claims in the identity rewrite were authored before being sourced, and were corrected
  before approval.** The first draft asserted that network-derived identity is "what the egress
  audit log records today and it is sufficient for attribution", and that Milestone 03's brokering
  is restricted to cryptographically bound identities. The first is now sourced to D12's line
  format, which carries an `identity_source` field alongside `agent`; the second is attributed to
  `prd.md`, where the Gate 3 milestone revision records it — it is not a decision row. A probe
  count (53 probes, 0 failures) was likewise attributed to the adversarial pass as a whole and now
  sits with Deviation 8, which is what it verified.
- **The identity rewrite takes a position the register does not yet accept.** The operator elected
  to describe network-derived identity for `codex` and `agy` as the built mechanism. R8.8 remains
  unamended. The document records the disagreement and assigns resolution to Feature 01.6; it does
  not settle it, and nothing here should be read as an amendment to R8.8.
- **Four deviations were deliberately left in the feature plans** — 01.4-D6, D7, D8 and 01.5-D18.
  All four are test-harness internals touching none of the six architecture sections. 01.4-D8 is
  the one worth naming: a credential leaked in cleartext through the harness's *input* path
  because `references/.env_keys` was sourced rather than parsed. The harness now parses it. The
  consequence that outlives the harness — revoking the one-year `CLAUDE_CODE_OAUTH_TOKEN` — is
  recorded in the Open Items table and in the Gate 1 refresh record, and remains outstanding.
- **Decision count unchanged at 22.** Every consolidation amended an existing row or an existing
  section; no decision was added, renumbered or removed.
