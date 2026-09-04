# Gate 3 Review -- Milestone Planning

**Artifact:** milestones/02-proven-and-composable/README.md
**Status:** [x] Approved
**Reviewer(s):** Operator; adversarial review by Codex; design review by advisor
**Date:** 2026-09-04

## Pre-checks (verified programmatically)

- [x] `milestones/02-proven-and-composable/README.md` exists
- [x] All required sections present: Goal, Features, Dependencies, Ordering, Sizing, Definition of Done
- [x] `milestones/02-proven-and-composable/milestone-status.txt` exists
- [x] Feature count matches across README.md and milestone-status.txt (5 and 5), and feature names are identical
- [x] Every feature carries at least one acceptance criterion (5 Acceptance Criteria blocks for 5 features)

## Checklist

- [x] Does the milestone represent a coherent, deployable increment?
- [x] Are features correctly grouped? Any that belong in a different milestone?
- [x] Is the ordering correct given dependencies?
- [x] Are the acceptance criteria specific and testable?
- [x] Is the sizing realistic?
- [x] [Auto] **Confirm the provisional test ownership recorded by the Milestone 01 review.** That
      review assigned T1–T8 (adversarial acceptance), the T26 revocation half, T37, T40 and the
      R13.2/T40 amendment to Milestone 02, and flagged those assignments as provisional "until those
      milestones are defined by `/milestone`, at which point their gate-3 reviews confirm them". This
      milestone owns: T1–T8, T14, T16, T18, T26 (revocation half), T29–T32, T35, T36, T37, T38, T39,
      T40, T41, T44 and T45; and it **re-runs and extends T42** for the third parties 02.3 adds, which
      01.1 owns for the Docker Sandboxes and model-provider set. Confirm nothing is orphaned, and that
      the three split tests — T1–T8, T14 and T42 — read as prerequisite-then-acceptance rather than as
      double ownership.
- [x] [Auto] **Decision taken — D21 promotion trigger (02.4).** D21 as ratified moves the CI workflow
      to `main` "on project completion", branch-built images testing-only. Under that trigger Milestone
      02's Definition of Done would be met by an image D21 says not to use, and project completion now
      sits behind Milestone 03's external Q9. **Operator approved the amendment on 2026-09-04:** 02.4
      promotes the workflow to `main` (or a release ref) and Milestone 02 lifts the R12.8 notice for
      non-AWS profiles. Applying the amendment to `docs/ARCHITECTURE_AND_DESIGN.md` is a follow-up
      outside `/milestone`'s authority.
- [x] [Auto] **Check dependency: 02.1 must precede 02.2.** R12.8 requires each scenario to record
      blocked / logged / attributable. The agent action recorder, the audit sink and the R8.8
      correlation supply two of those three, so validating before instrumenting means re-running the
      adversarial suite. Confirm this ordering, and confirm that placing T16 in 02.2's run — rather
      than in 02.1, which builds what T16 inspects — is the right split.
- [x] [Auto] **Check ordering: packs after adversarial validation (02.2 before 02.3).** The cost is
      that 02.3 re-runs `validate-boundary.sh` against every profile it introduces, because each pack
      adds egress entries, a mount or a credential to a boundary validated without them. The
      alternative — packs first, validate once — is cheaper but puts the R12.8 gate behind the part of
      the milestone most likely to churn. Confirm the trade, and confirm the regression scope is
      "every shipped profile" rather than a hand-picked subset of tests.
- [x] [Auto] **Confirm sizing: 02.3 carries two bodies of work.** Three tool packs with credential
      handling (Terraform, Kubernetes, GitHub CLI) plus the MCP inventory and its four tests
      (T29–T32). R7.14 places MCP servers under the same review basis as any tool pack, which is why
      they are co-located, but a sixth feature would breach the DD-1 ceiling. Confirm the split seam
      at `/plan` time: pack set and profiles, then MCP inventory and drift detection.
- [x] [Auto] **Validate scope: credential-bearing packs without brokering.** GitHub CLI carries a
      token and Kubernetes carries a `kubeconfig`, but upstream credential brokering (R8.3, SHOULD) is
      the mediator's fifth role and sits in Milestone 03. 02.3 ships them secret-injected or
      volume-resident, enumerated under R8.4 with blast radius and independently revocable (R7.12).
      Confirm this is acceptable, or move the credential-bearing packs to Milestone 03.
- [x] [Auto] **Confirm the two recorded register amendments stay proposals.** R13.2/T40 (targeted MCP
      disable requires a rebuild; the MUST stays formally unmet until accepted) and D21 (promotion
      trigger). `/milestone` has no authority to edit `REQUIREMENTS.md` or the architecture document —
      the same posture Gate 2 took with T21–T45. Confirm both are recorded as proposals and put to the
      operator, not applied.
- [x] [Auto] **Confirm R14.1 coverage for the destinations 02.3 introduces.** R14.1 is a MUST that
      applies per third party, before traffic reaches it. 01.1 recorded Docker Sandboxes and the three
      model providers; 02.3 adds HashiCorp, GitHub and the Kubernetes endpoints. 02.3 re-runs and
      extends T42 to cover them. Confirm the scope is right and that no pack ships ahead of its record.
- [x] [Auto] **Confirm the R13.2 gate on lifting the R12.8 notice.** R13.2 is a MUST and targeted
      MCP-server disable currently requires a rebuild. The Definition of Done now requires the
      R13.2/T40 amendment to be **accepted**, or a live targeted-disable path to be built, before the
      notice lifts. Confirm that condition, or accept shipping with an outstanding MUST.
- [x] [Auto] **Validate scope: the goal claims real work *without AWS* only.** SC-5 is out of scope
      here and the AWS pack does not exist until Milestone 03. Confirm the Goal and Definition of Done
      do not overclaim — the Milestone 01 review closed an adversarial finding on exactly this
      overclaim.

## Reviewer Comments

- **`prd.md` gap carried forward from the Milestone 01 review — closed.** R7.10 lists a **GitHub CLI**
  tool pack that the `prd.md` § Configuration optional-pack table omitted. The row was added as part
  of this definition. The equivalent gap in `docs/ARCHITECTURE_AND_DESIGN.md` — the component
  inventory and file tree list the pack set without GitHub CLI — remains open and is recorded by 02.4
  as a proposed architecture amendment, since `/milestone` may not edit that document.
- **T14 is reassigned from 01.5 to 02.3, and Milestone 01 needs a one-line reconciliation.** The
  approved 01.5 acceptance criteria name T14, "exercised by loading and unloading the
  language-runtimes pack" — but that pack declares no runtime egress by design (R7.18), so the run
  cannot satisfy T14's pass condition, which is about egress entries gained and lost. 02.3 therefore
  owns T14's recorded acceptance and 01.5's run becomes a prerequisite exercise. **Milestone 01's
  01.5 criterion and its gate-3 coverage item should be reconciled to say so** — via `/milestone`
  revision mode, or at 01.5 build time. Recorded rather than papered over, the same posture taken on
  R13.2. **Operator decision, 2026-09-04: record now, correct Milestone 01 at 01.5 build time.**
  Milestone 01 is not reopened for it.
- **Adversarial review, and the findings closed before approval.** Reviewed by Codex against
  `REQUIREMENTS.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, `prd.md` and the approved Milestone 01
  artifacts. Two Critical and ten Major findings, all applied to the README before this review was
  presented: R13.2 MUST outstanding while the DoD lifted the real-work notice (DoD now gates on the
  amendment being accepted); R14.1/T42 not extended to the third parties 02.3 adds (new 02.3 criterion
  and DoD line); R8.2 credential scoping unproven (02.3); R8.5's "without rebuilding" limb untested
  (02.5); T14 double-owned between 01.5 and 02.3 (02.3 now owns recorded acceptance, 01.5 is the
  prerequisite exercise, mirroring T1–T8); D21 unratified in the design document (DoD now requires the
  amendment applied); the Ordering section's "degrades gracefully without R8.8" contradicting 02.1 and
  T38 (corrected — R8.8 lands in 01.3 and both depend on it); MCP inventory missing the R7.3 field set
  (02.3); R9.7's privilege-change limb uncovered by T35 (02.1); the Goal overclaiming SC-7 beyond
  destinations (narrowed); R11.1 unowned as a check (02.4's T18 host class); and 02.3's size (Sizing
  now names the revision-mode fallback rather than relying on `/plan` splitting).
- **Recorded blind spot, not a test failure.** 02.2 records that the stdio MCP injection vector is
  **not** exercised: a stdio server is a subprocess of the agent and its tool calls cross no
  enforcement point (D18). The architecture's bring-up sequence step 4 requires this to be recorded.
- **D20's limitation is stated, not closed.** 02.1 ships tamper-*evidence*, not tamper-*resistance* —
  the agent authors its own transcript and can write a false line before it ships. No milestone here
  closes that; the only source of an action log is the transcript the agent already writes.
- **02.2's failures are design findings, not bugs.** A failed adversarial test is a finding against
  Milestone 01's build or against the architecture, and routes to `/milestone` revision mode, not to
  a fix inside 02.2.
