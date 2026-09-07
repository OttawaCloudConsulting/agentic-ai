# Gate 4 Review -- Feature Plan: Agent authentication and state persistence

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/agent-authentication-and-state-persistence.md
**Status:** [ ] Pending
**Reviewer(s):**
**Date:**

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
- [ ] Is the test command appropriate for this feature? -- `bash tests/acceptance/verify-auth-state.sh`.
      **Needs the reviewer:** the command is unchanged, but two harnesses now exist that did not when
      it was written, and the plan requires both to keep passing. Confirm whether that belongs in
      this feature's test command or stays a build-time obligation.
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
- [ ] [Auto] Check dependency: throwaway provider accounts (Anthropic + OpenAI with both API key and
      OAuth login; Google API key only) -- **needs the reviewer.** The plan calls this the external
      dependency most likely to be underestimated: T24 iterates seven cells and cannot start without
      them.
- [ ] [Auto] Confirm the OAuth endpoint allowlist addition is still 01.4's to own -- **needs the
      reviewer.** SF-2 adds provider authentication endpoints to `policy/allowlist.base.yaml`,
      which is a scope addition relative to the milestone README. It was approved at the prior gate;
      it is re-listed because the file it edits is now populated and enforced rather than planned.
- [x] [Auto] Verify the audit-log cross-validation is expressible -- 01.3 SF-7's line is one JSON
      object per line; a refused endpoint appears as `verdict=deny`, `control=allowlist`,
      `reason=host_not_allowlisted` with `dest_host` and `agent`. SF-2 can select on fields rather
      than grepping text, and the plan now says so.

## Reviewer Comments

Three items above need a decision that cannot be verified from the repository. Everything else was
checked against the tree as it stands on 2026-09-07.
