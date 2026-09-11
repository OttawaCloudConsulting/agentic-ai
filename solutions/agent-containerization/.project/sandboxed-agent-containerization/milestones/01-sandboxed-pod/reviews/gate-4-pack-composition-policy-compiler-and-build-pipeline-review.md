# Gate 4 Review -- Feature Plan: Pack composition, policy compiler and build pipeline

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/pack-composition-policy-compiler-and-build-pipeline.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-07

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
- [x] Is the test command appropriate for this feature? -- **Resolved 2026-09-07: composite.** Now
      `verify-pack-composition.sh && verify-pod-topology.sh && verify-egress-mediator.sh`. Same
      operator decision as 01.4: the obligation lives in the test command, which runs at feature
      close, rather than in sub-feature prose, which does not. SF-4 is what makes the third harness
      non-optional -- it rebuilds the mediator image `verify-egress-mediator.sh` drives end to end.
- [x] Are the files to create/modify correct? -- Verified path by path AND action by action against
      disk on 2026-09-07. Five rows were stale and are corrected: `.dockerignore` is Modify, not
      Create (01.3 SF-4 wrote it); the three per-agent Dockerfile rows and the `agent-base` row
      collapse to one `images/Dockerfile` row (01.2 Deviation 1); the keyring moves to
      `images/keyrings/`; `images/.dockerignore` keeps the agent context rather than being folded
      away; and the `compose/compose.yaml` row drops the context change, which is already made.
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
- [x] [Auto] Validate the exit-code change against existing callers -- **Resolved 2026-09-07 by
      reading every caller, which corrected the plan.** Three callers exist:
      `images/mediator/entrypoint.sh:180` (`if ! bash "$POLICY_VALIDATOR" --validate ...` -- tests
      non-zero, not a value); `tests/acceptance/verify-egress-mediator.sh`, which **does not invoke
      the compiler at all** and only reads `policy/resolved/default.yaml` at `:497`; and
      `README.md:132`, a documented human command. None inspects a specific exit value, so nothing
      breaks.

      **The plan's stated basis was wrong and is corrected.** It described 01.3's harness as an
      exit-code caller that "tests only for non-zero". It is not a caller. SF-4's obligation to
      re-run that harness stands, but as an end-to-end driver of the image this feature rebuilds --
      not as exit-code evidence. A verified caller table now sits in Contract 6 in place of the
      claim.

      **Gap closed at this gate:** `compile-policy.sh:36`'s `fail()` exits 1 for everything,
      including `unknown argument`, and the proposed 0/2/3/4 contract left CLI misuse unhomed.
      Operator decision: **retain 1 for usage errors**, narrowed to invocation errors only, so 2/3/4
      carry only meanings the compiler actually asserts and 1 keeps the shell-conventional meaning
      callers already assume.
- [x] [Auto] Confirm the `.dockerignore` allowlist extension is safe -- **Resolved 2026-09-07. Exact
      form ratified and pinned into SF-4** rather than left to the builder:

      ```
      !profiles
      !packs                        # inert until this feature creates the directory
      !policy/allowlist.base.yaml
      !policy/denylist.base.yaml
      ```

      Two properties were decided rather than assumed. **(a) The base policy files are named
      individually, not admitted as `!policy`** -- verified against disk, `policy/` also holds
      `allowlist.test.yaml` and `denylist.test.yaml`, 01.3's harness fixtures, which a blanket
      `!policy` would ship into the mediator image. **(b) All four sit above the trailing-deny
      block**, per that file's own comment; `packs/` does not exist yet and the entry is inert until
      this feature creates it, which is harmless.

      **Strengthened beyond the question asked.** SF-7 previously asserted only that the build
      context size was under a ceiling. A size ceiling cannot catch a 1.7 KB private key -- the
      exact failure the `.dockerignore`'s own comment warns about if a future `!` lands below the
      trailing-deny block. SF-7 now **positively asserts by name** that
      `mediator/identity/ca/mediator-ca.key` and `references/` are absent from the context.

## Reviewer Comments

**Closed 2026-09-07.** All three open items resolved; two of them changed the plan rather than
merely confirming it -- see the exit-code and `.dockerignore` items above.

**One defect found while closing, in an item this checklist had already ticked.** The
`[x] Are interface contracts compatible with existing code?` item was marked verified on the
strength of Contract 6, which correctly names `--write` as the **rejected** proposal and records
that the shipped CLI writes by default. But nine lines elsewhere in the same plan (`:444`, `:700`,
`:701`, `:704`, `:754`, `:768`, `:771`, `:789`, `:800`) still instructed operators to run `--write`,
and 01.4 carried the same instruction at its line 461. The re-plan fixed the contract sections of
both plans and did not sweep their bodies, so the documents contradicted their own contracts.
Corrected in both plans on 2026-09-07; the single surviving mention at `:563` is the intentional
reference to the rejected proposal. Recorded rather than silently fixed: the lesson is that a
contract-compatibility item verified against the contract section alone is not verified.
