# Gate 4 Review -- Feature Plan: Pod topology, hardened runtime and minimal profile

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/pod-topology-hardened-runtime-and-minimal-profile.md
**Status:** [x] Approved
**Reviewer(s):** Operator
**Date:** 2026-09-04

## Checklist

### Pre-checked by Claude (programmatic)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present in the plan
- [x] `milestone-status.txt` exists for milestone 01
- [x] Feature 01.2 exists in `milestone-status.txt`
- [x] Plan passes `markdownlint-cli2` against the repository root config (0 errors)

### Static items

- [x] Does the approach handle known edge cases? -- Ten edge cases, four of which were added from
      the independent Codex review: named-volume masking of a rebuilt image, `.dockerignore`
      build-context resolution, Compose's implicit default network, and the `internal: true`
      route/DNS precision.
- [x] Are the sub-features correctly scoped for single-session work? -- Five sub-features after the
      Gate 4 split of the base image (SF-2) from the three per-agent images (SF-3), each judged
      against DD-1's ~120k-token session guideline. DD-1's 2-5 ceiling governs features per
      milestone, not sub-features per feature. None flagged `[OVERSIZED]`.
- [x] Is the test command appropriate for this feature? -- `bash tests/acceptance/verify-pod-topology.sh`,
      a single script that must pass on a pod with no default route and no WAN egress. It runs two
      bring-ups: phase A under the default profile carries every assertion including mount-set
      equality, and phase B layers the read-only fixture override for T2 alone. The split is
      required because the mount-equality assertion and the T2 fixture mount are mutually exclusive
      by construction. Both phases use a test-scoped project name and `down -v`.
- [x] Are the files to create/modify correct? -- 16 rows. Every sub-feature output appears, and
      every row is owned by a sub-feature. `compose/pins.env` is committed and reaches the build via
      an explicit `--env-file` in the documented entry point -- Compose does not otherwise read it.
- [-] Are interface contracts compatible with existing code? -- **N/A: greenfield.** No tracked
      Dockerfile, Compose file or `.dockerignore` exists anywhere in this repository, and there is
      no `.github/` directory. The contracts that matter here are forward contracts to 01.4
      (filesystem layout and environment) and 01.5 (profile schema), reviewed under the auto items
      below rather than against existing code.

### Content-specific items

- [x] [Auto] Sub-feature sizing: **split at Gate 4 on the operator's decision.** SF-2 now carries
      the hardened base image, the `/opt/agent-home-skel` mechanism, the seeding entrypoint,
      `images/.dockerignore` and `compose/pins.env`. SF-3 carries the three per-agent images, the
      pins as `ARG`, the `agy` wrapper and the per-agent sandbox dispositions. The split point is
      the base/agents seam.
- [x] [Auto] D14 escalation disposition: **verify and record, do not pre-decide.**
      `docs/RESEARCH_FINDINGS.md:76` and `:83` indicate Claude Code's native sandbox may not nest
      inside an unprivileged hardened container, contradicting D14's enablement. SF-2 probes the
      base posture (can bubblewrap mount a fresh `/proc` under `cap_drop: ALL` plus
      `no-new-privileges`?) and SF-3 records the per-agent verdict, enabling each sandbox only if it
      nests without a capability R1.4 forbids. A negative routes to `/milestone` revision mode as a
      D14 amendment. This mirrors 01.1's treatment of the `agy` `HTTPS_PROXY` go/no-go.
      **Note:** 01.1 SF-2 does not cover this question, and the Gate 2 Open Items table does not
      list it. It was first identified during this Gate 4 review.
- [x] [Auto] Resource ceilings confirmed as proposed: `cpus: "2.0"`, `memory: 4g`, `pids: 512`
      (R1.10), declared in `profiles/default.yaml`. Adjustable per profile without gate
      re-approval.
- [x] [Auto] State-volume mount point confirmed: the volume mounts at `/home/agent` (the agent's
      `$HOME`), with image-provided home defaults at `/opt/agent-home-skel` and idempotent seeding
      by `entrypoint.sh` that never overwrites existing files. This resolves Docker's masking of
      image content by a populated named volume on every run after the first. 01.4 inherits the
      contract rather than re-deciding it.
- [x] [Auto] Test command coverage validated: criteria 1-6 and 8 are each exercised by at least one
      assertion. Criterion 7 is partly automated (record presence and per-agent verdict are
      asserted; configuration-follows-verdict is a review judgement). Criterion 9 is documentation,
      verified by review alone. Neither is claimed as tested.
- [x] [Auto] Scope boundary confirmed: the mediator (01.3), authentication (01.4), the policy
      compiler and the CI pipeline (01.5) are all excluded. `compose.yaml` declares `egress-net` but
      attaches no service to it until 01.3. Nothing belonging to those features was pulled forward.
- [x] [Auto] CIS Docker Benchmark 1.8.0 handling confirmed: the applicability table **stays in
      Feature 01.2** (criterion 9), carried by SF-5. The benchmark is treated as a **hard
      prerequisite of SF-5**, not as a conditional -- it is obtained before SF-5 begins and the
      table is written against the actual document, with no recommendation number asserted from
      memory. The earlier "record the constraint if unobtainable" hedge was removed at the
      operator's direction. Because SF-5 is independent of SF-1 to SF-4, the prerequisite blocks the
      table and nothing else in the feature.

## Reviewer Comments

**Independent review.** Seven findings from a Codex review were applied to the plan before this
checklist was finalised: version pins now reach the build as `build.args` from `compose/pins.env`
rather than as a markdown record a Dockerfile cannot read, with a single `./images` build context
and `images/.dockerignore` (one blocker); the `/opt/agent-home-skel` split resolves named-volume
masking of a rebuilt image (the highest-value fix -- the failure is silent by construction and would
have falsified SC-8 for everything under `$HOME`); `internal: true` claims were narrowed from "no
route and no DNS" to "no default route, no WAN egress" with Docker's embedded resolver acknowledged
and RFC1918/metadata denial left to R5.6 in 01.3; T2 gained a dedicated read-only fixture override,
since the default profile mounts the project `rw`; criterion 7's coverage claim was split into an
automated record check and a review judgement; the "nothing else mounted" invariant gained an
explicit `.Mounts` equality assertion; and the egress network was renamed `egress-net` and
disambiguated from Compose's `external:` key.

**CIS criterion: dropped and reinstated during this review.** The applicability table was briefly
removed from Feature 01.2 and then restored at the operator's direction: the intent was to remove
the "the benchmark may not be obtainable" conditional, not the deliverable. The plan now carries
criterion 9 in full and treats obtaining the benchmark as a hard prerequisite of SF-5. **No
`/milestone` revision is required on this account** -- the plan, the milestone README and the
architecture document's Open Items table all agree that the table belongs to Feature 01.2.

**Open design question raised, not resolved, by this plan.** The D14 native-sandbox nesting
contradiction (auto item 2 above) is recorded as a build-time verification with a defined escalation
path. If SF-2's base-posture probe or SF-3's per-agent verdicts come back negative for Claude Code,
that is a D14 amendment and belongs to `/milestone`, not to `/build`.
