# Gate 4 Review -- Feature Plan: Agent authentication and state persistence

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/agent-authentication-and-state-persistence.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-07

> **Regenerated 2026-09-07 after a re-plan.** The prior checklist (approved 2026-09-04) was written
> against a plan that consumed per-agent client certificates from 01.3 and set
> `CODEX_CA_CERTIFICATE` on `codex`. Neither exists: client certificates left 01.3 for Feature 01.6
> at the milestone revision, and `codex` has no TLS hop to anchor. A checklist cannot verify a plan
> it was not written against, so it is replaced rather than amended.

## Checklist

- [x] Does the approach handle known edge cases? -- Unchanged by the re-plan: 16 edge cases, two of
      them recorded as structurally impossible rather than mitigated. The revision touched no edge
      case, because none of them turned on the identity material that changed.
- [x] Are the sub-features correctly scoped for single-session work? -- Unchanged: five,
      dependency-ordered SF-1 -> SF-5, with SF-2's split condition stated. The revision removed work
      (no client-certificate consumption) and added none.
- [x] Is the test command appropriate for this feature? -- **Resolved 2026-09-07: composite.** The
      command is now `verify-auth-state.sh && verify-pod-topology.sh && verify-egress-mediator.sh`.
      Operator decision: the obligation to keep the two existing harnesses passing belongs in the
      test command, not in sub-feature prose, because the test command is what actually runs at
      feature close. `verify-pod-topology.sh` is load-bearing here specifically because SF-1 and
      SF-4 amend its mount-set equality assertion; `verify-egress-mediator.sh` because SF-2 changes
      the compiled policy the mediator enforces.
- [x] Are the files to create/modify correct? -- Verified against disk on 2026-09-07: every file
      listed as Modify now exists (`compose/compose.yaml`, `profiles/default.yaml`,
      `policy/allowlist.base.yaml`, `.gitignore`, `tests/acceptance/verify-pod-topology.sh`). The
      repository-state note was corrected from "greenfield" to reflect this.
- [x] Are interface contracts compatible with existing code? -- This is what the re-plan fixed.
      Contract 6 now matches the running pod per agent: proxy scheme, CA-trust variable, and the
      absence of any client certificate. Cross-checked against `compose/compose.yaml` and the
      assertions in `tests/acceptance/verify-pod-topology.sh`. Contract 6 also now states the
      policy-currency consequence of 01.3: SF-2's allowlist edit is inert until
      `compile-policy.sh --write` regenerates `policy/resolved/default.yaml` and the mediator image
      is rebuilt, because the mediator reads the policy from its image layer and stage 1 validates
      schema, not currency.
- [x] [Auto] Confirm interface: Contract 6's per-agent table matches what 01.3 ships -- verified
      against `compose/compose.yaml` (seven secrets, CA mounted into `claude` and `agy` only) and
      against 01.3's harness, which asserts `codex` carries none of `NODE_EXTRA_CA_CERTS`,
      `SSL_CERT_FILE` or `CODEX_CA_CERTIFICATE`.
- [x] [Auto] Confirm the credential inventory records the empty path rather than dropping it --
      Contract 7's secret-mounted row now reads "empty at this milestone", naming 01.6 as the
      feature that fills it. An absence stated is auditable; a removed row is not.
- [x] [Auto] Check dependency: provider accounts -- **Resolved 2026-09-07.** Three of the seven
      cells are covered by API keys that already exist in `references/.env_keys`. For the four OAuth
      cells the operator elected to use **real accounts rather than throwaway ones**, accepting that
      a live Anthropic and ChatGPT credential is inside the sandbox whose boundary this feature
      tests. The reviewer raised the alternative (throwaway accounts, so that a defect found by T24
      is a defect with nothing at stake) and the operator decided otherwise; recorded as a decision,
      not an oversight. Two mitigations are now written into SF-5 as close obligations: revoke the
      one-year `claude setup-token` credential at feature close, and forbid the harness from
      printing credential values.

      Two consequential findings from verifying this rather than accepting the plan's framing:
      (a) SF-5 read "Runs against throwaway credentials only", which now contradicts the decision --
      corrected in place; (b) T24's original "no interactive terminal" criterion is **already
      amended** at the 2026-09-04 gate to "no browser inside the container", so interactive
      paste-back OAuth is the sanctioned mechanism and is not a blocker.
- [x] [Auto] Confirm the OAuth endpoint allowlist addition is still 01.4's to own -- **Resolved
      2026-09-07: stays 01.4's.** 01.4 is the consumer and therefore the feature that knows which
      endpoints are required; 01.5's compiler validates whatever the base file contains rather than
      authoring it. Moving it to 01.5 would have created an ordering dependency that does not exist
      today. The currency consequence is already stated in this plan's Contract 6 and stands as a
      build obligation: the allowlist edit is inert until the policy is recompiled **and** the
      mediator image rebuilt, so SF-2's flow must run both between observing the endpoints and
      re-testing them.
- [x] [Auto] Verify the audit-log cross-validation is expressible -- 01.3 SF-7's line is one JSON
      object per line; a refused endpoint appears as `verdict=deny`, `control=allowlist`,
      `reason=host_not_allowlisted` with `dest_host` and `agent`. SF-2 can select on fields rather
      than grepping text, and the plan now says so.

## Reviewer Comments

**Closed 2026-09-07.** All three open items resolved by operator decision; see each item above.
Everything else was checked against the tree as it stands on 2026-09-07.

**One defect found while closing, in an item this checklist had already ticked.** The
`[x] Are interface contracts compatible with existing code?` item was marked verified, but the plan
body still instructed operators to run `bash scripts/compile-policy.sh --write` (line 461) -- a flag
the shipped CLI does not have, and one that Contract 6 of Feature 01.5 explicitly names as the
*rejected* proposal. The re-plan corrected the contract sections of both plans and did not sweep
their bodies. Corrected in both plans on 2026-09-07. Recorded here rather than silently fixed,
because the lesson is about the tick, not the flag: a contract-compatibility item verified against
the contract section alone is not verified.

**Host precondition verified rather than assumed.** `~/.codex/auth.json` is present, `0600` and
file-backed (no `cli_auth_credentials_store` in `~/.codex/config.toml`; this install defaults to
file), so SF-4 has its credential source. Inspecting it surfaced a test-validity defect now written
into SF-4: the file carries `OPENAI_API_KEY` **and** `tokens`, so mounting it unmodified would let
the `oauth-mount` cell authenticate off the API key and pass while the OAuth path is broken. The
staged directory must strip the API key, and SF-5 must assert its absence.
