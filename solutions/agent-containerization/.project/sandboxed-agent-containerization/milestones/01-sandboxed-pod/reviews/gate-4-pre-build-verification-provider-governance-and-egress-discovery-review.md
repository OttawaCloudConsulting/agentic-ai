# Gate 4 Review -- Feature Plan: Pre-build verification, provider governance and egress discovery

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/pre-build-verification-provider-governance-and-egress-discovery.md
**Status:** [x] Approved
**Reviewer(s):** Operator; adversarial review by Codex
**Date:** 2026-09-04

## Pre-checks (verified programmatically)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present (Summary, Acceptance Criteria, Approach, Sub-Features,
      Interface Contracts, Edge Cases, Test Command, Test Strategy, Documentation, Files to
      Create/Modify, Dependencies, Architectural Deviations)
- [x] `milestone-status.txt` exists for Milestone 01
- [x] Feature 01.1 exists in `milestone-status.txt`

## Checklist

- [x] Does the approach handle known edge cases? Seven are enumerated, each with a disposition: `agy`
      unable to run under `sbx`; `agy` not honouring `HTTPS_PROXY` (go/no-go, routes to `/milestone`
      revision); no agent able to present a client certificate; Docker Sandboxes assessment
      incomplete; `sbx` blocking UDP/ICMP; capture yielding a union rather than per-agent policy;
      R14.3 owner unavailable.
- [x] Are the sub-features correctly scoped for single-session work? Three, none oversized. SF-3 was
      considered for a per-agent split and kept whole with the reason recorded.
- [x] Is the test command appropriate for this feature? `bash scripts/lint-policy.sh`, scoped to the
      two policy files. Record completeness is deliberately excluded — that is T42/T43 inspection.
- [x] Are the files to create/modify correct? Nine entries. Policy paths match the ratified file
      tree; `docs/records/` is new and is recorded as an explicit design update.
- [x] Are interface contracts compatible with existing code? No application code exists — the
      solution tree is confirmed greenfield (no `policy/`, `compose/`, `profiles/`, `packs/`,
      scripts or CI; repository root has no `.github/`). Compatibility is therefore forward-looking:
      the allowlist shape must compose with 01.5's policy compiler, which the revision addressed.
- [x] [Auto] **Verify test ownership against the register.** The first draft claimed 01.1 owns no
      T-tests. `REQUIREMENTS.md:461-462` defines T42 as inspecting the third-party record and T43 the
      per-provider record — both are SF-1 deliverables — and the Milestone 02 Gate 3 review records
      01.1 as owning T42 for the Docker Sandboxes and model-provider set, with 02.3 re-running and
      extending it. Both now assigned to 01.1. Corrected.
- [x] [Auto] **Confirm T44 is not double-owned.** `M02 README:237-239` places the simulated terms
      change and mediator seam inspection in 02.5, under the R14.3 owner named in 01.1. 01.1 supplies
      the owner as an input and does not own the test. Recorded as a **proposed Gate 3 register
      amendment** if the operator prefers an explicit split, in keeping with how T26 was recorded —
      not applied at Gate 4.
- [x] [Auto] **Check sequencing: SF-2 must precede SF-3.** SF-2 selects the agent version pins;
      R10.6 requires the egress policy to be re-verified after each agent bump because egress
      requirements change between releases. A capture taken against unpinned agents seeds an
      allowlist for versions the build will not run. Ordering corrected to strict SF-1 -> SF-2 -> SF-3
      and the capture is required to run at the SF-2 pins.
- [x] [Auto] **Validate the allowlist contract against the policy compiler.** R7.3 requires a pack
      manifest to declare egress FQDNs **and CIDRs**, and R7.4 composes the effective policy from
      base plus packs. The first draft's `{fqdn, port, source}` base could not compose with a
      CIDR-bearing pack. Revised to typed per-agent `allow_fqdns` and `allow_cidrs`, with R5.9
      `upgrade` metadata and a `pins:` reference.
- [x] [Auto] **Confirm the deliberate omissions from the policy files are recorded, not silent.**
      D5's per-agent rate and concurrency limits are mediator configuration and belong to 01.3, not
      the base policy. No `deny_fqdns` field: R5.3, R5.7 and D5 specify post-resolution **CIDR**
      deny only. Both stated in the Interface Contracts section.
- [x] [Auto] **Check dependency: the cross-validation source is available within 01.1.** The
      acceptance criterion offers agent verbose logging **or** `tcpdump` on the mediator during a
      shadow run. No mediator exists until 01.3, so the second source within this feature is agent
      verbose logging. Stated in the Approach section; the allowlist stays provisional regardless.
- [x] [Auto] **Confirm the operator-input dependency is not written as a task.** The R14.3 named
      owner cannot be produced by an implementation session. Recorded as a `/build` start
      precondition under Dependencies.
- [x] [Auto] **Validate scope: the throwaway TLS listener.** Challenged as possible
      over-engineering. It traces to a stated acceptance criterion — each agent's client must be
      verified capable of presenting a client certificate to a TLS proxy listener — and nothing in
      the environment asks for one today, so the check has no target without it. Scoped throwaway
      and explicitly not the 01.3 mediator. Kept.
- [x] [Auto] **Confirm `docs/records/` is not a silent deviation.** The ratified file tree does not
      carry that directory. Adding it is recorded as a design update in Files to Create/Modify;
      Architectural Deviations remains `(none)`, which is correct — that section is populated by
      `/build`.

## Reviewer Comments

Adversarial review by Codex against `REQUIREMENTS.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `prd.md`,
the approved Milestone 01 README and Gate 3 review, and the Milestone 02 artifacts. Three Major and
three Minor findings, all applied before approval:

- **(Major)** Test ownership — T42 and T43 belong to 01.1.
- **(Major)** Sequencing — SF-2's version pins are a prerequisite of SF-3's capture (R10.6).
- **(Major)** Interface contract — the base allowlist could not compose with CIDR-bearing packs
  (R7.3, R7.4).
- **(Minor)** `provisional` status cited R5.8; it derives from D17.
- **(Minor)** `docs/records/` sat outside the ratified file tree with no deviation recorded.
- **(Minor)** `lint-policy.sh` validated governance records, exceeding the ratified purpose of
  `scripts/`; records are inspection tests, not lint targets.

Two corrections to the review itself, verified against the register before applying: Codex cited
`REQUIREMENTS.md:303` for the sequencing finding, which is **R10.6**; and proposed splitting T44 with
**02.2**, where `M02 README:237-239` places it in **02.5**. The T44 split was not applied — see the
checklist item above.

**01.1 remains a go/no-go gate on 01.2-01.5.** A negative `agy` `HTTPS_PROXY` result is a design
change under D1 for one agent and routes to `/milestone` revision mode, not to a failed feature.
