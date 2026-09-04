# Gate 3 Review -- Milestone Planning

**Artifact:** milestones/01-sandboxed-pod/README.md
**Status:** [x] Approved
**Reviewer(s):** Operator; adversarial review by Codex (session 01a06c42-349d-7453-a4ae-32a419c3431a); design review by advisor
**Date:** 2026-09-04

## Pre-checks (verified programmatically)

- [x] `milestones/01-sandboxed-pod/README.md` exists
- [x] All required sections present: Goal, Features, Dependencies, Ordering, Sizing, Definition of Done
- [x] `milestones/01-sandboxed-pod/milestone-status.txt` exists
- [x] Feature count matches across README.md and milestone-status.txt (5 and 5), and feature names are identical
- [x] Every feature carries at least one acceptance criterion (5 Acceptance Criteria blocks for 5 features)

## Checklist

- [x] Does the milestone represent a coherent, deployable increment?
- [x] Are features correctly grouped? Any that belong in a different milestone?
- [x] Is the ordering correct given dependencies?
- [x] Are the acceptance criteria specific and testable?
- [x] Is the sizing realistic?
- [x] [Auto] Verify acceptance-test coverage: every test T1–T45 has exactly one owning feature across
      Milestones 01–03. T1–T8 are cited in 01.2/01.3 as smoke/prerequisite checks with 02.2 owning
      them as recorded adversarial acceptance; T26 is split (token inventory 01.4, tested revocation
      02.5). Confirm no test is orphaned and no duplicate ownership remains.
- [x] [Auto] Confirm 01.1's `agy` verification is a **go/no-go gate on 01.2–01.5**, not a task inside
      them. A negative `HTTPS_PROXY` result is a design change under D1 for one agent, not a build
      task (Gate 2 open item: "Verify against the pinned `agy` version before the M1 build, not
      during it").
- [x] [Auto] Check dependency: 01.3 (mediator) must precede 01.4 (authentication) — an agent on an
      `internal: true` network cannot complete an OAuth flow until the mediator resolves and permits
      the provider's auth endpoints.
- [x] [Auto] Validate scope: per-agent mTLS workload identity (R8.8) sits in 01.3 rather than
      deferring to Milestone 03's brokering. R8.8 is a MUST and deferring it puts a MUST behind Q9,
      where a negative answer orphans it permanently; and the component inventory already lists a
      client certificate as an interface on every agent container, so 01.2's service definitions,
      01.4's proxy configuration and 01.1's `agy` CA-trust check all assume it. Confirm this trade
      against 01.3's size.
- [x] [Auto] Confirm sizing: 01.3 maps 1:1 to the `egress-mediator` component and carries four of its
      five roles — expect one sub-feature per role at `/plan` time (policy engine, resolver, audit
      writer, mTLS identity).
- [x] [Auto] Confirm scope: 01.5 introduces the repository's **first** `.github/workflows/` at the
      repo root (D21), a cross-cutting change outside `solutions/agent-containerization/`, and makes
      CI a build-time dependency this repository did not previously have.

## Reviewer Comments

- **Coverage item, scope of the check.** Test ownership is verified for Milestone 01's own features.
  The Milestone 02 and 03 assignments recorded above are **provisional** until those milestones are
  defined by `/milestone`, at which point their gate-3 reviews confirm them.
- **Findings closed before approval.** The adversarial review found no Critical issues and six Major:
  provider governance scheduled after M1 traffic (moved into 01.1), "M02 unlocks real use"
  overclaiming against SC-5 (scoped to non-AWS), T11 dropped rather than replaced under Model B (03.2
  owns a replacement), R12.7/T37 unowned (profile field in 01.5, verification in 02.5), R13.2 versus
  the design's "partially unmet" admission, and R3.5/R3.6/R10.3 unowned (now explicit in 01.2).
- **R13.2 — operator decision.** Milestone 02 will record the rebuild-required limitation on targeted
  MCP-server disable as a **proposed amendment to R13.2/T40** for approval against
  `REQUIREMENTS.md`, rather than building a live targeted-disable path. The MUST stays formally unmet
  until that amendment is accepted. `/milestone` has no authority to edit the register.
- **Carried forward to Milestone 02 definition.** R7.10 lists a **GitHub CLI** tool pack that the
  `prd.md` Configuration table omits from its optional-pack rows. The pack is assigned to 02.3; the
  `prd.md` gap is unfixed and should be closed when Milestone 02 is defined.
- **Proposed register additions carried forward.** A Model-B replacement for T11 (03.2) and the
  R13.2/T40 amendment (02.5) are proposals recorded in milestone artifacts, not edits to
  `REQUIREMENTS.md` — the same posture Gate 2 took with T21–T45.
