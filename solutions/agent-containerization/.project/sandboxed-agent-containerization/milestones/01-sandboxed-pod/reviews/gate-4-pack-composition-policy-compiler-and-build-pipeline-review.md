# Gate 4 Review -- Feature Plan: Pack composition, policy compiler and build pipeline

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/pack-composition-policy-compiler-and-build-pipeline.md
**Status:** [ ] Pending
**Reviewer(s):**
**Date:**

> **Regenerated 2026-09-07 after a re-plan.** The prior checklist was written against a plan that
> defined a compiler CLI incompatible with the one 01.3 shipped, and that scheduled a build-context
> change 01.3 has already made. Both are now corrected in the plan, so the checklist is replaced.

## Checklist

- [x] Does the approach handle known edge cases? -- Unchanged by the re-plan. The revision touched
      the inherited-validation section, two contracts and one sub-feature's scope; no edge case
      depended on them.
- [x] Are the sub-features correctly scoped for single-session work? -- Seven, unchanged in count.
      SF-4 got **smaller**: the build-context move and the solution-root `.dockerignore` are already
      on disk from 01.3 SF-4, leaving the compile stage, the allowlist extension, the drift check
      and the exit codes. Its split condition is restated for the new shape.
- [ ] Is the test command appropriate for this feature? -- `bash tests/acceptance/verify-pack-composition.sh`.
      **Needs the reviewer:** SF-4 now also requires re-running 01.3's harness, because it changes
      an image that harness drives end to end. Confirm whether that is part of this feature's test
      command or a build-time obligation.
- [x] Are the files to create/modify correct? -- Verified against disk on 2026-09-07.
      `scripts/compile-policy.sh`, `images/mediator/Dockerfile`, `.dockerignore` and
      `policy/resolved/` all exist and are extended rather than created. The agent images are one
      multi-stage `images/Dockerfile` (01.2 Deviation 1), not four, which the plan now reflects.
- [x] Are interface contracts compatible with existing code? -- This is what the re-plan fixed.
      Contract 6 extends the shipped CLI (`--profile`, `--out`, `--validate`, `--check`,
      `--allowlist`, `--denylist`) instead of replacing it with an incompatible signature.
- [x] [Auto] Confirm the compiler CLI in Contract 6 matches `scripts/compile-policy.sh` on disk --
      verified flag by flag on 2026-09-07.
- [x] [Auto] Verify the inherited-validation list matches what the compiler actually enforces --
      wildcard rejection, port-not-443 flag, `provisional:` propagation, hostname and agent-key
      shape checks, and the `connections_per_minute` refusal are all present in the shipped script,
      and the mediator re-enforces the shape checks at render time.
- [x] [Auto] Confirm the new special-use-TLD warning is owned here -- the Gate 2 refresh assigns it
      to this feature, since this is where the allowlist is validated. Recorded as a **warning**,
      not a refusal: an operator may run a local resolver that serves one.
- [ ] [Auto] Validate the exit-code change against existing callers -- **needs the reviewer.** The
      shipped script exits 1 for every failure; this feature introduces 2/3/4. 01.3's harness and
      the mediator's stage-1 check both test only for non-zero, so both survive, but the change is
      caller-visible and the plan requires it to be proven by re-running the harness rather than
      assumed.
- [ ] [Auto] Confirm the `.dockerignore` allowlist extension is safe -- **needs the reviewer.** The
      compile stage needs `profiles/`, `packs/` and the two base policy files in the mediator's
      build context. That file is deny-all plus an allowlist with trailing re-denies for
      `references/` and `mediator/identity/`; entries must go **above** that block, and its own
      comment says so. Getting this wrong sends the CA private key to the daemon.

## Reviewer Comments

Three items above need a decision that cannot be verified from the repository. Everything else was
checked against the tree as it stands on 2026-09-07.
