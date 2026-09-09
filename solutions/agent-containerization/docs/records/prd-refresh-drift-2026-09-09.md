# PRD drift list — reconcile prd.md to shipped reality (Features 01.1-01.5)
Date: 2026-09-09. Status: AWAITING OPERATOR APPROVAL. No writes made.

Filter applied: prd.md preamble says it cites requirement IDs by reference and never
restates them, and REQUIREMENTS.md wins on conflict. So a register amendment counts as
PRD drift ONLY where prd.md asserts something in its own words that is now false.

## IN SCOPE — prd.md says it, and it is now false

D1  Header: "acceptance tests T1-T20". Register now runs T1-T45 (T21-T45 appended at
    Gate 2). NOTE: the same sentence's "157 numbered requirements" is CORRECT (verified,
    157 rows) - do not touch it.

D2  Summary: "Research is complete; no architecture option has been ratified - that is
    Gate 2." Gate 2 ratified Option 2 as decision D1, with 22 decisions D1-D21 recorded.
    Same paragraph: Open Decision 3 status is now "Incomplete, constrained (01.1 SF-1)",
    not simply open.

D3  Settled at Gate 1 / Authentication scope row: "Both API-key and OAuth, per agent,
    selected by AUTH_MODE". As built: seven supported cells, three fail-closed cells,
    and unset AUTH_MODE is itself fail-closed. Understatement, not falsehood.

D4  External Dependencies, three rows:
    a) AWS estate / Q9 - "if unavailable, R6.3 becomes unimplementable". Gate 2 corrected
       this (D13a): a negative Q9 leaves NO compliant AWS credential model and gates the
       entire AWS CLI pack. prd.md's own Milestones section already states the stronger
       version, so the PRD contradicts itself.
    b) Docker Sandboxes - "Not established ... constrains Option 1 evaluation". Status is
       now "Incomplete, constrained"; Option 1 was REJECTED at Gate 2, so nothing is being
       constrained. sbx is retained only as the discovery-seeding tool (D17).
    c) Antigravity ToS - "Unresolved". Substance holds (Google still declined to clarify)
       but the R14.3 owner is now named: Ottawa Cloud Consulting.

D5  Milestones, third consequence bullet: "Milestone 01 is still the large one. Five
    features". True count is SIX - 01.6 Per-agent workload identity, split out of 01.3 on
    2026-09-04, not yet planned. The same section already says "six features" two
    paragraphs earlier.

D6  Milestones / Discovery approach: "egress discovery uses Docker Sandboxes against a
    synthetic repository with throwaway credentials only." True of 01.1. NOT true as a
    blanket claim: 01.4 SF-2b derived the OAuth endpoint set from the pod's own mediator
    audit log, on REAL accounts, by operator election.

D7  Broken path references: prd.md cites `docs/ARCHITECTURE_AND_DESIGN.md` and
    `milestones/<NN>-<name>/README.md`. Neither resolves. Real base is
    `.project/sandboxed-agent-containerization/`.

D8  Configuration / Optional table:
    a) "Language runtimes pack | bool | off" - it is ON by default in both shipped
       profiles (default.yaml, oauth-mount.yaml).
    b) AWS CLI, Terraform, Kubernetes, GitHub CLI packs are listed as available options.
       None exist. Terraform/K8s/GitHub arrive at 02.3, AWS CLI at 03.3.
    c) AUTH_MODE row lists a flat four-mode enum per agent. Real matrix: claude has no
       oauth-mount cell, codex has no oauth-token cell, agy is apikey only (D9).
    d) `profile` row implies a use-case profile set. Four profiles exist: default,
       oauth-mount (unplanned, added at 01.4 SF-4), and two test profiles.
    e) Not in the table but now real: git ships in the agent-base image (01.5 SF-1),
       which is what made the host-gitconfig mount non-inert.

D9  Outputs: "All four are produced and exported by default. A profile may disable an
    export". As built:
    - Egress audit log: PRODUCED. Residual: raw-socket egress attempts are invisible to it
      (Codex F1, downgraded from blocking to recorded residual).
    - Agent action log: NOT BUILT. Feature 02.1.
    - Resolved egress policy: PRODUCED. Four artifacts under policy/resolved/, behind a
      fail-on-drift build gate.
    - Image digest + SBOM: HALF. Digest + SPDX SBOM exist only for the CI-published base
      image; local agent builds record an image ID and no SBOM (buildx docker driver
      rejects attestation). Provenance verification T45 is 02.4.
    - The per-export disable mechanism itself is T36, Milestone 02.

D10 Risk Assessment, R4.16 refresh-token row: mitigation cites "revocation (R8.5)".
    Measured at 01.4 SF-5: rotation is NOT a revocation mechanism - a refresh token
    captured from a state volume stays valid after the legitimate client refreshes past
    it; only explicit provider revocation ends it. Measured for OpenAI; Anthropic not
    replayed. Separately, claude's refreshTokenExpiresAt is not extended by a refresh, so
    the family dies ~28 days after original login.

D11 Risk Assessment is incomplete against the ratified accepted-risk list. Two accepted
    risks exist in the architecture that prd.md does not carry:
    - codex cannot distinguish a policy gap from an attack in-band (its listener peeks, so
      every refusal arrives as a terminated connection with no body).
    - Control 3 ships two of its three ceilings; Squid 6.13 has no per-client
      connection-rate directive, so connection rate is not enforced.
    Additive, not a contradiction. Operator call whether these are PRD-level.

## OUT OF SCOPE — register or architecture, not prd.md text
- T28 amendment landed 2026-09-06; T24 amendment landed 2026-09-07.
- T34 NOT landed - still reads the unexecutable original; 01.6 unplanned.
- R8.8 unamended and knowingly in conflict with the milestone README on network-derived
  identity (Codex F2, recorded not fixed).
- D3, D4, D5, D14, D19 architecture amendments; CA key location narrowed.
- 43 feature-level deviations across 01.2 (3), 01.3 (11), 01.4 (9), 01.5 (20).
- 01.5 closes recommending a /design refresh to consolidate its 20 deviations. Outstanding.

## PROCESS / STATE inconsistencies (not prd.md body edits)
P1  Gate 2 date conflict: progress.txt says Approved 2026-09-07; gate-2-review.md says
    2026-09-04 and 09-07 is the architecture-refresh date. One of the two is wrong.
P2  gate-1-review.md is frozen at 2026-09-03 but prd.md has been edited twice since
    (ffa7adb, 9d2f1ce) with no date bump. Its content item "Confirm M1 including the AWS
    CLI pack is intended" was reversed at Gate 3 when AWS was carved out to Milestone 03.
P3  progress.txt Gate 1 line still reads Approved: 2026-09-03 - to be bumped on
    re-approval of this refresh.
P4  gate-3-review.md records a consistency check at "2/6 features complete"; now 5/6.

## OUTSTANDING SECURITY ACTION (not a PRD edit)
The CLAUDE_CODE_OAUTH_TOKEN minted for the R4.16 test cell is a one-year credential that
additionally leaked in cleartext during the first run. Revocation was deferred until
testing finished. Testing has finished (01.5 complete). This token should be revoked at
the provider.

## PROPOSED WRITE SET (skill /define Step 6 scope) — 3 files only
1. prd.md - edits D1..D11 as approved
2. .project/sandboxed-agent-containerization/docs/reviews/gate-1-review.md - regenerate
3. progress.txt - Gate 1 line, new Approved date
Downstream artifacts (ARCHITECTURE_AND_DESIGN.md, milestone plans, Gate 4 reviews) are
surfaced as impacts only. Per DD-6 they are NOT auto-reset.
