# Gate 4 Review -- Feature Plan: Agent authentication and state persistence

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/agent-authentication-and-state-persistence.md
**Status:** [x] Approved
**Reviewer(s):** OCC (operator)
**Date:** 2026-09-04

## Checklist

- [x] Does the approach handle known edge cases? -- 16 edge cases recorded, up from 12 after the
      Codex review pass. Two of them (1 and 2) are recorded as **structurally impossible** rather
      than mitigated, because the review showed the original runtime guards were defeatable by the
      agent controlling the guard's own condition. The remainder name a trigger and either a
      mitigation or an explicit residual -- R8.6 transcript capture, R8.3-until-Milestone-03
      environment visibility, the stale scrubbed artifact, and the unencrypted volume each record
      the residual rather than implying coverage.
- [x] Are the sub-features correctly scoped for single-session work? -- Five, dependency-ordered
      SF-1 -> SF-5. Sizing was the only attack category the Codex pass returned clean. SF-2 is the
      largest and is kept whole with its split condition stated (SF-2a dispatcher/precondition/
      `apikey`, SF-2b the OAuth branches plus the allowlist entries). The git-config scrub is folded
      into SF-1 rather than given its own sub-feature -- one host-side script and one assertion.
      None carries the `[OVERSIZED]` flag.
- [x] Is the test command appropriate for this feature? -- `bash tests/acceptance/verify-auth-state.sh`.
      Five phases (A-E) covering T24 across all seven supported cells, T22, T25 in two stages, and
      T9 in both its restart and its image-rebuild form. Follows the repository convention:
      `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644, invoked as `bash`. Phases C and D are
      separated from A because each adds a mount and 01.2's mount-set **equality** assertion in
      phase A would fail with either layered.
- [x] Are the files to create/modify correct? -- 7 create, 12 modify, counted against the plan's
      table (6 create at approval; `compose/overrides/host-gitconfig.yaml` added by the
      post-approval clarification recorded below). Paths follow the ratified file
      tree except for `images/agent-base/bootstrap-auth.sh`, whose departure is recorded with its
      reason and its landing point (see the `[Auto]` item below). `scripts/scrub-gitconfig.sh` is
      **not** a departure after the Codex revision -- it runs host-side and belongs in `scripts/`
      exactly as the tree states. Every Modify target is created by an earlier feature in this
      milestone; none exists on disk yet, which is expected and stated in Dependencies.
- [x] Are interface contracts compatible with existing code? -- Seven contracts. Contracts 5 and 6
      are consumed unchanged from 01.2 and 01.3. Contracts 3 and 4 are **extensions**, each named as
      such after the Codex pass showed the Summary had claimed pure consumption while the body
      modified `compose.yaml`, `profiles/default.yaml` and `verify-pod-topology.sh`. No in-repo
      authentication, credential or entrypoint prior art exists to conflict with -- the solution
      tree is greenfield.

- [x] [Auto] Interpretation, criterion 4: **T24 as written cannot pass alongside R4.12.** T24's pass
      criterion is "no interactive terminal", but R4.9 defines the headless path by enumeration --
      "paste-back code, device code, or a pre-minted token" -- and two of those three require a
      terminal, while `oauth-interactive` is R4.12's default for both Claude Code and Codex.
      **Operator decision at this gate: an interactive terminal is permitted**, and T24 is amended
      in `REQUIREMENTS.md` to the property it protects -- no browser inside the container, and the
      default is the safest mode that agent supports. R4.9 and R4.12 are unchanged and no supported
      cell is removed. Same disposition Gate 4 applied to T28 in 01.3. **Verified as decided and
      scheduled, not as executed** -- the amendment lands in SF-2, and both `REQUIREMENTS.md` and
      `docs/ARCHITECTURE_AND_DESIGN.md` are listed in Files to Create/Modify, because a reading
      landing in one document and not the other is drift by construction.
- [x] [Auto] Two controls were moved from runtime guard to structural absence after the Codex pass,
      and both changes are load-bearing rather than cosmetic. **(a) R2.9/T22:** the earlier draft
      mounted the operator's gitconfig `:ro` and scrubbed to a copy, leaving the unfiltered helper
      pointer readable inside the container and failing T22, which inspects the mounted file. The
      scrub now runs host-side before `up` and the generated artifact is what is mounted, so R2.9's
      "removed **first**" holds literally. **(b) R4.15:** the earlier draft kept the credential
      source mounted under every `oauth-mount` start behind a copy-only-if-empty guard, which an
      agent defeats by deleting its own credential. The source is now mounted only by the one-shot
      bootstrap override, so steady state has no host mount and a deleted credential exits `3`
      naming the bootstrap command. Verified that the architecture's "steady state runs with no host
      mount" now holds as written rather than by convention.
- [x] [Auto] Confirm scope addition: **01.4 SF-2 owns adding the provider OAuth endpoints to
      `policy/allowlist.base.yaml`.** Neither 01.1's seed allowlist nor 01.3's resolved-policy
      example enumerates one, and 01.1's approved plan covers no OAuth behaviour at all -- so
      without an owner, SF-2's exit-`4` precondition would fail forever with nothing scheduled to
      close it. The derivation satisfies R5.8 and D17 rather than bypassing them: running the flow
      is the observation of the minimal destination set, and 01.3 SF-7a's mediator audit log is the
      independent second source. Entries are marked provisional on the same terms as the rest of the
      file. This is wider than the milestone README's wording for 01.4 and is called out in the plan
      rather than absorbed silently.
- [x] [Auto] Confirm the R4.5 interpretation: `cli_auth_credentials_store = "file"` is required
      **unconditionally**, not only under `oauth-mount`. The architecture's component table attaches
      it to `oauth-mount`; R4.5 does not, and the reason is mechanical -- the `keyring` store
      hard-fails with no D-Bus, and no container in this design has D-Bus under any mode. The
      register wins per the architecture's own authority note. Reached independently by the Codex
      review, which is confirmation rather than a second opinion.
- [x] [Auto] Verify the support matrix count and the `agy` disposition. **Seven** supported cells --
      claude x3, codex x3, agy x1 -- corrected from an arithmetic error of nine in the first draft,
      which also propagated into the external-dependency statement. `agy`'s `oauth-interactive` and
      `oauth-mount` cells are recorded as **"not offered by decision"**, distinct from "unsupported":
      D9 admits no Antigravity OAuth credential into any container, and R4.12 requires an API-key
      **or** an OAuth configuration per agent, not both. Google therefore needs a throwaway API key
      only -- the first draft's "OAuth logins on each provider" contradicted D9.
- [x] [Auto] Confirm R8.7 is claimed accurately, not aspirationally. The plan no longer states R8.7
      is met by documentation. The version-control half is enforced (`.gitignore` plus the absence of
      any export path this solution creates); the backup half is carried by a named host procedure
      (`tmutil addexclusion` against the Docker Desktop data path) with the **residual recorded** --
      Docker Desktop stores every named volume inside one VM disk image, so no per-volume exclusion
      exists to make, and an operator who skips the procedure has refresh tokens in a host backup
      that nothing here can detect.
- [x] [Auto] Confirm the credential inventory covers R8.4 and not only R4.16. Interface Contract 7
      spans three delivery paths -- environment-delivered keys and `CLAUDE_CODE_OAUTH_TOKEN`,
      volume-persisted refresh tokens, and the per-agent mTLS client key at `/run/secrets` that 01.3
      issues. R8.4 requires every credential the agent **can obtain** with its blast-radius
      contribution; R4.16's compensating-controls detail applies to the persisted rows only. The
      02.5 detection-to-revocation column is present and deliberately empty.
- [x] [Auto] Confirm the cross-feature contract amendments are explicit work, not incidental fixes.
      01.4 extends 01.2's Compose seam (Contract 4), 01.2's profile schema (Contract 3) and 01.2's
      mount-set equality assertion in `verify-pod-topology.sh`. 01.2's own Contract 4 names only 01.3
      as an extender, so 01.4 is the third and declares itself -- the same discipline 01.3 used when
      adding `/run/secrets`. Confirmed that **T21 is unaffected**: both optional mounts are absent
      from `profiles/default.yaml`, and T21 runs on the default profile.
- [x] [Auto] Verify the file-tree departure has a landing point. `bootstrap-auth.sh` ships at
      `images/agent-base/` rather than `scripts/` because 01.2's build context is `./images` and the
      copy-to-volume must run in-container. 01.2 set the precedent with `entrypoint.sh`. The
      correction to `docs/ARCHITECTURE_AND_DESIGN.md` lands in SF-2 and the document is listed in
      Files to Create/Modify. `Architectural Deviations` remains `(none)` per the Gate 4
      specification -- that section is `/build`'s to populate, not `/plan-feature`'s.
- [-] [Auto] Confirm `agy`'s single supported cell is viable -- **N/A until 01.1 SF-2 reports.** The
      `GEMINI_API_KEY` route is UNVERIFIED: the official install page documents it and a June 2026
      maintainer statement contradicts it. A negative leaves `agy` with no supported `AUTH_MODE` at
      all, which the milestone README dispositions as a `/milestone` rescope under D1 -- the same
      treatment it gives the `HTTPS_PROXY` result. Recorded as a dependency, not a plan defect.
- [-] [Auto] Validate the per-provider refresh-token rotation results -- **N/A at this gate.** No
      provider has been measured; SF-3 is the first work that could, and it is sequenced before SF-4
      precisely so `oauth-mount` is built against a measured answer rather than an assumption. The
      plan's acceptance criterion is that each result is **recorded**, not that each is favourable.

## Reviewer Comments

Approved at whole-plan review on 2026-09-04 after a Codex adversarial review pass. Codex returned
nine findings across eight attack categories; sizing was the only category it returned clean.

Six findings produced plan changes: the pre-mount git-config scrub (R2.9/T22), the bootstrap-only
credential mount (R4.15), the allowlist ownership contradiction, the overstated R8.7 claim, the
inventory's omission of environment-delivered and secret-mounted credentials (R8.4), and the
"consumes rather than extends" wording that three Modify entries contradicted. One finding was an
arithmetic error -- seven supported cells, not nine -- which had propagated into the external
credential dependency and, with it, an implied Antigravity OAuth login that D9 excludes. Two
findings restated conflicts the plan had already flagged, which is confirmation the conflicts are
real rather than evidence of new defects. Codex independently confirmed the R4.5 reading.

The two blocking design findings share a shape worth recording: in both cases the first draft relied
on a runtime guard whose condition the agent controls -- scrub-after-mount, and copy-only-if-empty.
Both are now structural. The material the guard was protecting is simply not present at the point
the agent could act on it. That is the same posture D1 takes toward agent self-firewalling: a
control the agent can reach is not a control.

One item is resolved as **decided and scheduled rather than executed**: the T24 amendment lands in
`/build` during SF-2, in both `REQUIREMENTS.md` and `docs/ARCHITECTURE_AND_DESIGN.md`. What this
gate verified is that the decision is recorded, the owner named and the landing point listed -- not
that the edit exists on disk. The operator's decision at this gate was explicit: an interactive
terminal is permitted, so T24 is amended to the property it protects and no supported cell is lost.

Two items are `[-]`: `agy`'s viability (blocked on 01.1 SF-2's `GEMINI_API_KEY` result, a
`/milestone` matter if negative) and the rotation results (unmeasurable before SF-3, which is why
SF-3 gates SF-4). All remaining items are `[x]`.

## Post-Approval Clarification (2026-09-04)

Recorded after approval, on the operator's decision, as a D-09 interface completion rather than a
change of scope or approach. No acceptance criterion, sub-feature, test or requirement mapping
changed, and Gate 4 is not reopened.

Moving the git-config scrub host-side during the Codex revision left the in-container side
underspecified in two ways `/build` would have had to guess at. Both are now stated:

1. **The mount had a source but no target.** `/run/oauth-src` was named; the git-config mount was
   not. It is now `/run/gitconfig`, under the `tmpfs` `/run` that 01.2 declares — the same shape
   01.3 used for `/run/secrets`, and the correct one for material that must not persist onto the
   state volume.
2. **`GIT_CONFIG_GLOBAL` was set unconditionally while the mount is optional.** Under
   `profiles/default.yaml` it would have pointed at an absent path, so every `git config --global`
   the agent ran would fail or land on `tmpfs` and vanish at restart. It is now set only by
   `compose/overrides/host-gitconfig.yaml`, the fragment that also supplies the mount, so the
   variable and its target appear and disappear together. `compose.yaml` and the base image set it
   nowhere.

The fragment is the seventh Create entry. Phase C gains one assertion — that `GIT_CONFIG_GLOBAL` is
**unset** without the fragment — so the default profile cannot carry a dangling pointer undetected.
`README.md` gains one line: while the mount is active the global config is `:ro` and a
`git config --global` write fails, which is correct under R2.3 and R2.9 but visible to the operator.
