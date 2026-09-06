# Gate 4 Review -- Feature Plan: Pack composition, policy compiler and build pipeline

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/pack-composition-policy-compiler-and-build-pipeline.md
**Status:** [x] Approved
**Reviewer(s):** OCC (operator)
**Date:** 2026-09-04

## Checklist

- [x] Does the approach handle known edge cases? -- 20 edge cases recorded. Ten arrived from the
      Codex adversarial pass and three more from reconciling those fixes against each other: the
      `--write`/build-stage output parity problem (17), the project-mount gate's inability to run in
      a build stage (18), and the 01.3 Interface Contract 5 contradiction (20). Each names its
      mitigation or records the residual explicitly. Two are deliberately named and not solved, with
      the choice left to `/build`: 17's parity resolution, and 13's UNVERIFIED SBOM attestation on
      local Compose builds.
- [x] Are the sub-features correctly scoped for single-session work? -- Seven, dependency-ordered,
      SF-1 through SF-7 strict except SF-6, which depends only on SF-5. None carries `[OVERSIZED]`.
      SF-4 carries a stated split condition (context work versus compile stage and drift check).
      SF-5 was the closest call and was trimmed during review when the R7.19 over-correction was
      removed. The milestone README's own split point -- "01.5 splits cleanly at compiler versus CI
      pipeline" -- is the SF-1..5,7 / SF-6 boundary and is preserved.
- [x] Is the test command appropriate for this feature? -- `bash tests/acceptance/verify-pack-composition.sh`.
      Eight phases (A-H) covering T14, T15, T21, T23, T27, T31 and T33, plus the rebuild-on-documented-command
      phase (D) and the build-context content assertion (A). Follows the repository convention:
      `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644, invoked as `bash`, test-scoped Compose
      project name, `down -v` teardown, assertions against `docker inspect` on running containers.
- [x] Are the files to create/modify correct? -- 8 create, 17 modify. Paths follow the ratified file
      tree, with two departures recorded in the plan rather than left as drift: the build context
      moves to the solution root (Contract 5) and `scripts/build.sh` is claimed from the ratified
      tree where no sibling created it. `policy/resolved/default.yaml` is correctly Modify, not
      Create -- 01.3 creates it as the committed SC-6 artifact.
- [x] Are interface contracts compatible with existing code? -- Six contracts. Contract 3 emits
      01.3's fixed resolved-policy schema unchanged, populating only `compiled_from.packs`.
      Contract 2 extends 01.2's and 01.4's profile schemas additively. Contract 6 fixes the
      `compile-policy.sh` signature and exit codes 01.3 left unstated. **Contract 5 is not
      compatible with 01.3's Interface Contract 5 and says so** -- see the `[Auto]` item below. No
      in-repo prior art exists to conflict with; the component is greenfield.

- [x] [Auto] Interpretation, criterion 9: D21's "base image" is read as **singular**. CI publishes
      `images/agent-base` only; `images/{claude,codex,agy}` build locally `FROM ...@sha256:` and are
      where pack OS packages land (D10's per-profile digest); `images/mediator` retains a local
      `build:` because the compile stage makes it profile-dependent. Anchored on the architecture's
      Reproducibility section. **Approved at whole-plan review.**
- [x] [Auto] The 01.3 Interface Contract 5 contradiction has a recorded owner and landing point:
      **01.3 is re-planned in revision mode before 01.3 builds**, batched with the 01.1 re-plan its
      own gate already scheduled. The ordering is load-bearing -- 01.3 builds before 01.5, so
      leaving IC5 as written means `/build` implements the contract this plan contradicts.
      **Verified as decided and scheduled, not as executed** -- the re-plan is a separate
      `/plan-feature` invocation and is not a property of this plan.
- [x] [Auto] The entry-point amendment (`up` gains `--build`) has a recorded landing point:
      `README.md`, listed in Files to Create/Modify. 01.2's plan text carries the old form and is
      **superseded, not edited** -- this feature does not edit sibling plans. Without the amendment
      the compiler sits in a build stage that the documented command never runs, and SC-6 fails
      while appearing to pass. Test Phase D proves it.
- [x] [Auto] Residual against R7.19: its filesystem clause is **structurally unsatisfiable** for
      language-level installers while `/home/agent` is writable, and SC-4 requires it writable. The
      plan claims **T15** for `pip`/`npm`/`go` (carried by egress denial, which supplies the
      "logged" half) and claims **T33 for the OS package manager only**. Recorded as a residual
      rather than presented as satisfying R7.19. An earlier draft's `go` wrapper and
      installer-hostile environment variables were **removed during review** as ineffective: the
      real `go` binary must remain for `go build`, and the plan's own text conceded the agent can
      unset the variables.
- [x] [Auto] Interpretation of R7.3's "checksums": every package carries a SHA-256, `apt` items
      included, taken from the signed `Packages` index and re-verified at build; the repository is
      pinned to a `snapshot.debian.org` timestamp with the signing key's full fingerprint asserted.
      An earlier draft argued the signed `Release` made per-package hashes redundant -- **corrected
      during review**, since that argues `apt` is safe, not that the manifest is pinned, and a suite
      pin does not survive Debian archive rotation, which is what SC-8's later rebuild measures.
- [x] [Auto] Confirm the build-context allowlist is asserted as a **security boundary**: it must
      never re-include `mediator/identity/`, `compose/generated/` or `compose/pins.env`. A build
      context is the working tree, and 01.3 places the CA private key under `mediator/identity/`
      locally. Re-including `mediator/config/` rather than `mediator/` is correct but was correct by
      path choice; SF-7 Phase A now enumerates the context and fails if any of the three appears.
- [x] [Auto] Confirm the two-reader split for pack manifests: the mediator's build stage composes
      the resolved egress policy, and each agent image separately resolves its own package set from
      the same manifests. The compiler's output is baked into the mediator layer and is **not**
      reachable from another image's build, so the agent-side resolution cannot consume it. A
      Contract 1 schema change touches both readers; SF-1 owns the schema for both.
- [-] [Auto] Name the schema-validation tool -- **N/A, and deliberately so.** 01.3 SF-2 promises
      "the schema validator the mediator's stage-1 self-check calls" and names no tool. Selecting one
      here would pre-empt a decision that belongs to 01.3. The constraint recorded for `/build` is
      that it runs inside the mediator image at stage 1 and adds no language runtime the images do
      not already carry (Edge Case 15).
- [-] [Auto] Adopt BuildKit `additional_contexts:` instead of moving the build context -- **N/A,
      rejected.** `additional_contexts:` is a Compose key, while `scripts/build.sh` and the CI drift
      job invoke `docker build`/buildx directly; the equivalent there is hand-mirrored
      `--build-context` flags, which is a second implementation of the compiler's input surface, and
      Contract 4's drift check is only meaningful while there is one. It also grants whole-directory
      access per context, so it buys no finer isolation than `COPY`-only-what-you-need already gives.
- [-] [Auto] Verify T37, T45 and T18 -- **N/A at this gate, by milestone assignment.** T37 (human
      authorization gate) is 02.5; T45 (published base image provenance) and T18 (clean rebuild) are
      02.4. This feature produces the artifacts those tests will verify -- the R12.7 classification,
      the published digest and SBOM -- and validates their shape only.
- [-] [Auto] Verify the `snapshot.debian.org` timestamp, the archive URLs and the pinned package
      versions -- **N/A until `/build`.** These are concrete values no one has selected yet; the
      plan fixes the schema that must carry them and the verification the build must perform. Under
      DD-12 they are set at build time without gate re-approval.

## Reviewer Comments

Approved at whole-plan review on 2026-09-04 after a Codex adversarial review pass. Codex returned ten
findings and **all ten produced plan changes** -- a higher acceptance rate than 01.3's pass (seven of
ten), reflecting that this plan was the first to touch the build pipeline, where several siblings had
left contracts unstated rather than wrong.

The Critical finding was the one worth the pass: the plan's R7.19 controls addressed the OS package
manager only, while the reference pack ships Node, Python and Go and 01.2 makes `/home/agent`
writable. Two Major findings were internal inconsistencies in the plan's own contracts (undeclared
build-egress hosts and a keyring absent from the `.dockerignore` allowlist); five were contradictions
with authority the plan had missed, the sharpest being that 01.2's documented start command has no
`--build`, which would have left the compiler in a build stage the entry point never runs.

A self-review pass after applying the ten findings caught two defects introduced by the fixes
themselves: accepting the entry-point and fail-on-drift findings independently left Test Phase D
asserting "no second command was needed" under a rule that requires one, and the response to the
Critical finding had over-corrected into a `go` wrapper and five environment variables that changed
nothing an attacker could do. Both were corrected before approval, and the removal is recorded in the
plan rather than silently dropped.

Three items are resolved as **decided and scheduled rather than executed**: the 01.3 Interface
Contract 5 re-plan, the entry-point amendment landing in `README.md`, and the architecture-document
records for the build-context departure and the D21 reading. What this gate verified for all three is
that the decision is recorded, the landing point named and the file listed in the plan -- not that
the edit exists on disk.

Five items are `[-]`: the schema validator (01.3's to select), `additional_contexts` (rejected with
its reason), T37/T45/T18 (assigned to 02.4 and 02.5), and the concrete pin values (DD-12, set at
build time). All remaining items are `[x]`.
