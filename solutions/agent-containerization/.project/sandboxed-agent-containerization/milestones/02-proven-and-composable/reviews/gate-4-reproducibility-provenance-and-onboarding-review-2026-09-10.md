# Gate 4 Review -- Feature Plan: Reproducibility, provenance and onboarding

**Artifact:** .project/sandboxed-agent-containerization/milestones/02-proven-and-composable/plans/reproducibility-provenance-and-onboarding.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-10

## Pre-checks (verified programmatically)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present (Summary through Architectural Deviations)
- [x] `milestone-status.txt` exists for milestone 02
- [x] Feature 02.4 exists in `milestone-status.txt`

## Checklist

- [x] Does the approach handle known edge cases?
- [x] Are the sub-features correctly scoped for single-session work?
- [x] Is the test command appropriate for this feature?
- [x] Are the files to create/modify correct?
- [x] Are interface contracts compatible with existing code?
- [x] [Auto] Confirm the T45 chain (Decision 2):
      - pinned index digest → provenance `runDetails.builder.id` → public runs API;
      - `head_branch == main`, and `head_sha` equals the provenance `vcs:revision`;
      - binding is by **run**, not by commit, so a fast-forwarded commit's branch-built digest still
        fails.

      Measured during planning: today's pin (run `34376295042`) reports `head_branch:
      feature/containerization`, so phase C is red until SF-4.
- [x] [Auto] Confirm SF-4 is operator-gated:
      - `/build` prepares the `feature/containerization` → `main` PR and never merges it;
      - the repin reaches `main` through a second PR rather than a direct commit to the unprotected
        `main`.
- [x] [Auto] Confirm `NODE_BASE_DIGEST`:
      - it is the **index** digest, with no ARG default;
      - it is consumed at `images/Dockerfile:40` and `:78`;
      - it is passed by the three agent services' `build.args` and by the workflow's pin-loading
        loop (`agent-sandbox-image.yml:145`);
      - it lands **before** the `main` publish, because pinning `:78` changes `agent-base`.
- [x] [Auto] Confirm T18's pass condition on the second physical Mac:
      - the `fingerprint-environment.sh` diff is clean with `commit` excluded, and the record lists
        both commits;
      - **and** the Test Command passes there;
      - the "Clean-environment procedure" runbook is written into `docs/records/reproducibility.md`
        before the run.
- [x] [Auto] Confirm Edge Case 16 for a public repository:
      - `GEMINI_API_KEY` is set with `read -rs` before recording;
      - the raw `script` transcript never leaves the second Mac, and only a cleaned log is
        committed;
      - teardown is mandatory — `down -v`, identity material deleted, the Claude and Codex sessions
        revoked at each provider, and Docker Desktop factory-reset.
- [x] [Auto] Confirm R10.4:
      - it is met as **declared + statically checked** (`images/build-allowlist.yaml`, kept out of
        `policy/`);
      - non-enforcement is recorded as a finding, with the proxy-builder option as its review
        trigger;
      - SF-1b and SF-1c (apt onto the snapshots) are kept, not cut.

## Reviewer Comments

- **Approved 2026-09-10.** Both tradeoff callouts were resolved to the plan's recommended positions:
  - Callout 1: D21 promotion by PR merge of `feature/containerization` into `main`, not a release
    tag on the branch.
  - Callout 2: R10.4 declared and statically checked, with non-enforcement recorded as a finding,
    not a proxy-enforced builder.
- **Assumptions confirmed:**
  1. T18 and T39 run on a **second physical Mac** (macOS 26, Apple silicon).
  2. The operator performs T39, following the README verbatim.
  3. The R12.3 reviewer role is the operator, reviewing via PR to `main`.
  4. SF-1b and SF-1c are kept.
- **Revised before approval, at the operator's request** (the question was "how do we perform the
  testing and validation on the second physical Mac?"):
  1. SF-5 gains a "Clean-environment procedure" runbook in `docs/records/reproducibility.md`,
     written before the run. It has five stages: reference, clean-state attestation, T39+T18,
     compare and record, teardown.
  2. T18 passes only if the fingerprint diff is clean **and** the Test Command passes on the second
     Mac.
  3. The fingerprint comparison excludes `commit`, and the record lists both commits.
  4. New Edge Case 16: session-log hygiene for a public repository, and mandatory credential
     teardown and provider-session revocation.
- **Measured during planning, not assumed:** the T45 mechanism was confirmed against today's pin.
  - Anonymous `imagetools inspect` shows `runDetails.builder.id` = run `34376295042`, an SPDX-2.3
    SBOM with 327 packages, and `node@22-slim` resolved to `sha256:83f487e0…`.
  - The public runs API reports `head_branch: feature/containerization`.
- **Recorded for authorities outside `/plan-feature`**, and not applied:
  - the D21 promotion-trigger amendment;
  - the GitHub CLI pack in the component inventory and file tree.

  Both target `docs/ARCHITECTURE_AND_DESIGN.md`.
