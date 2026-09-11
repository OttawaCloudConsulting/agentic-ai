# Gate 4 Review -- Feature Plan: Per-agent workload identity

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/per-agent-workload-identity.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-09

## Checklist

- [x] Does the approach handle known edge cases? -- Nine, each traced to a measured fact rather than
      to a category. The load-bearing ones: the inner and self-check listeners must not inherit
      `clientca=` (edge case 1 -- the symptom is stage-2 self-check failure at every start, not an
      identity error); a cert-less refusal produces **no audit line at all** because
      required-at-handshake kills the connection before Squid has a request to log (edge case 2,
      measured at 01.3 SF-1), with `$AUDIT_DIR/squid-cache.log` named as the surface that is
      populated; and a 14th logformat field **appended** rather than inserted is silently discarded
      into `audit-writer.sh:62`'s trailing `extra` var without tripping the short-line guard, which
      tests an empty `$server` (edge case 4).
- [x] Are the sub-features correctly scoped for single-session work? -- Four. SF-1 is
      discovery-shaped (record only, no product code) and gated on real agent runs plus three API
      keys. SF-2 is the largest and is named as such; its split condition is stated and is clean --
      SF-2a leaves every harness green with nothing enforced, SF-2b is the single enforcement flip.
      SF-3 is small in either branch. SF-4 is test code, one register amendment and two records.
- [x] Is the test command appropriate for this feature? -- **01.5's composite, unchanged**, plus
      `lint-policy.sh`. Every harness the feature touches is in it, including
      `verify-pack-composition.sh`, which drives the mediator image build whose drift check the
      profile-schema change can break. `verify-auth-state.sh` is **deliberately excluded** and the
      reason is recorded in the plan: its header warns at `:15` that "PHASE D COSTS THE OPERATOR
      THEIR HOST CODEX LOGIN". A command run unattended at feature close must not burn a credential.
      It is run once by the operator at the end of SF-2 instead, recorded as an obligation rather
      than dropped.
- [x] Are the files to create/modify correct? -- Verified path by path and line by line against disk
      on 2026-09-09 by a scoped codebase scan. Four corrections were applied before approval: four
      profiles declare a `listeners:` block, not two (`default:132`, `test-fixtures:59`,
      `test-selfcheck:65`, `oauth-mount:124`); `mediator/config/errors/ERR_MEDIATOR_IDENTITY` was
      missing and is required by IC6's 403-with-body path; `verify-pack-composition.sh` joins the
      regression list because `compile-policy.sh` is a build stage of the mediator image
      (`Dockerfile:99,231`) and `compile-policy-build.sh` refuses an unreviewed resolved artifact
      (R5.14); and a proposed `lint-policy.sh` check that `identity` equals the agent key was
      **removed as a tautology** -- `compile-policy.sh:826` synthesizes the value from the agent key,
      so the check would test the compiler's own echo.
- [x] Are interface contracts compatible with existing code? -- Five contracts, each extending a
      shipped surface rather than replacing it. IC1 preserves `issue-identity.sh`'s four modes
      verbatim and adds a fifth. IC2 adds one key at the profile-side `has()` loop
      (`compile-policy.sh:810-812`), not the resolved-artifact field loop at `:256`, and carries it
      in the per-agent `listener:` map at `:827`. IC3 leaves the JSON schema shape untouched and
      extends one key's enumeration. IC4 is the `REQUIREMENTS.md` amendment text, drafted in the
      same block shape as the 2026-09-06 T28 and 2026-09-07 T24 amendments. IC5 changes only the
      rows of 01.3's Interface Contract 2 that this feature touches.
- [x] [Auto] Verify the `identity_source` propagation mechanism actually reaches the verdict line --
      **This was a real defect in the first draft and it is the reason this row exists.** The initial
      plan annotated `idsrc` on the front layer via `annotate_transaction`, gated on the `user_cert`
      ACL. That never reaches the verdict line: the front-to-inner hop is `cache_peer 127.0.0.1
      parent <inner>` (`entrypoint.sh:359`), a new client connection and a new master transaction,
      which is precisely why `agent` and `layer` are already re-derived per layer from `myportname`
      (`entrypoint.sh:570-585`, whose comment names "the inner line carrying the real verdict").
      Header propagation was considered and **rejected** -- the agent can set the header itself, so
      the inner layer would trust an unverifiable claim, and the `request_header_add` versus
      `request_header_access` ordering is unverified on Squid 6.13. The mechanism taken is
      topological and was confirmed on disk: the inner listener binds `127.0.0.1` only
      (`entrypoint.sh:352`) and `cache_peer_access <agent>peer allow p_<agent>_frontreal`
      (`:366-367`) admits only that agent's own front, so reaching `claude`'s inner port requires
      having passed required-mode `clientca=`. Per-listener derivation is sound, with `idsrc` and
      `clientca=` rendered from the same `client_auth` field in the same pass.
- [x] [Auto] Confirm the two ordering constraints Decision 3 depends on are asserted, not assumed --
      Both are, and both are in the Test Strategy table. (1) The `user_cert CN` mismatch deny must be
      rendered ahead of the agent allow rules, because `cache_peer_access` is evaluated after
      `http_access`; without it a mismatched certificate is forwarded and the inner line reads
      `listener+mtls` on a connection the front should have refused. (2) The `idsrc` annotation
      attaches to the `p_<agent>_real` set, which filters the shadow listeners (`grep -v
      '^selfcheck'`, `entrypoint.sh:449`), with the `agent=selfcheck` tag's own `idsrc=listener`
      ordered after it -- `annotate_transaction key=value` replaces where `key+=value` appends, so
      last-wins is documented behaviour and not an assumption.
- [x] [Auto] Validate that criterion 3's assertion actually proves the attribution was earned -- The
      positive alone would not: under per-listener derivation the allow path *is* per-listener, so
      "claude reads `listener+mtls`" would also pass under a mechanism uncoupled from enforcement.
      The pair of negatives is what does the work and both are asserted: a cert-less connection
      produces **no audit line at all**, and a same-CA wrong-subject connection produces a front deny
      line carrying `identity_source=listener`, `control=identity`, `reason=subject_mismatch` and
      **no inner line**. Together they establish that `listener+mtls` on an inner line is unreachable
      without a verified, subject-matched certificate.
- [x] [Auto] Confirm the pack-composition and build-stage regression is scheduled, not discovered --
      Decision 8 item 5. `client_auth` is required-not-defaulted, so a key added to one profile fails
      every other profile's compile; the compiler is baked into the mediator image
      (`Dockerfile:99,231`); and `compile-policy-build.sh` exits non-zero on any drift against the
      committed `policy/resolved/` -- "the build refuses an artifact nobody reviewed (R5.14)". The
      compiler change, all four profiles and both regenerated artifacts land in one commit or the
      image does not build.
- [x] [Auto] Verify the T34 amendment text is drafted here rather than deferred to the build --
      Interface Contract 4 carries the full amendment block and the replacement matrix row, ready for
      SF-4 to apply. It follows the established shape: previous text, why it is unexecutable (only
      `claude` can present a client certificate at all, per 01.1 SF-2, so for two of three agents the
      method names an artifact that does not exist), the property it protects ("an identity bound to
      one agent cannot be used by another"), the method split by identity form, and what is
      explicitly unchanged (**R8.8 is unchanged and no agent is exempted**). This satisfies the
      milestone README's requirement that the amendment be carried to `REQUIREMENTS.md` rather than
      left as an interpretation living in a milestone README.
- [x] [Auto] Check the Milestone 03 brokering gate is recorded as an inherited input, not a footnote
      -- `docs/records/workload-identity.md` (created by SF-4) carries the per-agent identity form,
      the `identity_source` each produces and the resulting restriction. It is the record the
      milestone's Definition of Done names. Decision 4 sets the gate at `listener+mtls` alone, so on
      today's evidence Milestone 03 inherits `claude` only -- **including on a positive SF-1 result**,
      because a basic proxy credential is a bearer secret readable in the agent's own environment and
      plaintext on `codex-net`'s hop by construction.
## Reviewer Comments

Approved as written, with the corrections listed above applied before approval rather than deferred
to the build. Two tradeoff callouts were presented and both were accepted as planned:

1. **The Milestone 03 brokering gate stays `listener+mtls` even on a positive SF-1.** The alternative
   -- admitting `proxy_auth` to the gate so all three agents could be brokered to -- was rejected on
   D6's own reasoning: a credential the agent can read is a credential the agent can present.
2. **`client_auth` as profile schema is the widest blast radius in the feature** (compiler, linter,
   four profiles, both resolved artifacts, renderer, one commit). The alternative -- a per-agent
   capability list hardcoded in `entrypoint.sh` -- is far smaller but puts a policy decision where
   the compiler cannot validate it, the resolved policy does not show it and the linter cannot check
   it. SF-2's split condition exists partly to de-risk this.

The plan's own most important property is that it decides the R8.8 question in advance rather than
deferring it: a negative SF-1 for both agents is a **recorded outcome**, not an escalation, because
R8.8 closes cryptographically for `claude` and by register amendment plus recorded network-derived
form for the other two, with the residual carried per audit line rather than in a footnote.
