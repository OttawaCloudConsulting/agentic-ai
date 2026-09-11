# Gate 4 Review -- Feature Plan: Egress mediator (re-plan)

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/egress-mediator.md
**Status:** [x] Approved
**Reviewer(s):** OCC (operator)
**Date:** 2026-09-05

Supersedes the 2026-09-04 Gate 4 approval of this feature. That approval was invalidated by the
2026-09-04 `/milestone` revision, which split per-agent workload identity out to Feature 01.6 after
01.1 SF-2 found that two of three agents cannot present a client certificate to a TLS proxy listener
(`docs/records/r8-8-identity-mechanism-gap-escalation.md`). Items carried forward from the prior
checklist are marked **[carried]** with their status re-verified against the revised plan.

## Checklist

- [x] Does the approach handle known edge cases? -- 18 edge cases recorded. Two are new at this
      re-plan: `codex`'s plaintext proxy hop (what is exposed, to whom, what is genuinely lost) and
      the sharpened control-plane-in-project-mount case. One flipped from open risk to closed record:
      `agy` honouring `HTTPS_PROXY` is now a positive 01.1 SF-2 result, not a go/no-go. Each names its
      mitigation or records the residual explicitly.
- [x] Are the sub-features correctly scoped for single-session work? -- Eight, dependency-ordered,
      acyclic (SF-1 -> SF-2/SF-3 -> SF-4 -> SF-5 -> SF-6 -> SF-7 -> SF-8; confirmed by the Codex
      pass). Composition changed even though the count did not: the old SF-6 (workload identity) left
      with 01.6, the trust anchors it contained became a dedicated SF-3 on the operator's decision at
      this re-plan, and old SF-7a/SF-7b became SF-7/SF-8. No sub-feature carries `[OVERSIZED]`.
      SF-4 grew twice during review and was re-judged rather than left as first sized -- kept whole
      with its split condition stated (image vs. compose seam).
- [x] Is the test command appropriate for this feature? -- `bash tests/acceptance/verify-egress-mediator.sh`.
      Seven phases (A-G) covering T3-T8, T17, T28 plus the listener-set, per-agent proxy-hop
      transport, forwarding, control-plane-mount and sink-reachability assertions. **T34 removed** --
      it is 01.6's and is unexecutable here, since no client certificate exists to cross-present.
      Follows the repository convention: `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644,
      invoked as `bash`.
- [x] Are the files to create/modify correct? -- 17 create, 10 modify. Two rows corrected against
      disk at this re-plan: `.gitignore` is now **Modify**, not Create (01.2 landed one; the prior
      checklist recorded "verified on disk" for the opposite, which was true then and is not now),
      and `compose/overrides/default.yaml` carries the project-mount repoint. `workspace/.gitkeep`
      added so Docker does not auto-create the bind source root-owned against `user: "1000:1000"`.
- [x] Are interface contracts compatible with existing code? -- Six contracts. Contract 2 is the
      contract that changed most: the proxy URL scheme is now **per agent**, not uniform. Contract 3
      is retitled from "Workload identity" to "Proxy-hop trust anchors" and states the 01.3/01.6
      boundary row by row. Contract 5 extends 01.2's Compose seam; contract 1 fixes the schema 01.5's
      compiler must continue to emit.

### Codex adversarial review pass (2026-09-05)

- [x] [Auto] **Codex F4 -- the control plane is inside a read-write project mount today, not
      hypothetically.** `compose/overrides/default.yaml` binds `../:/workspace:rw` -- the solution
      tree -- into all three agents. **Verified on disk.** 01.3 is the feature that puts `policy/`,
      `mediator/config/` and `mediator/identity/` into that tree, so the default profile would ship
      the misconfiguration and the plan's own Phase A assertion would fail on the default profile
      rather than catch a mistake. SF-4 repoints the mount to a git-ignored `workspace/`. **Fixed in
      the plan.** The strongest finding of the pass.
- [x] [Auto] **Codex F5 -- the `agy` auto-updater host was a MUST falling into the crack between
      features.** `policy/allowlist.base.yaml` seeds
      `antigravity-cli-auto-updater-974169037036.us-central1.run.app`; R10.3 is a MUST that
      auto-updaters are disabled; `docs/records/agent-verification.md` states verbatim that this is
      "a residual, not-fully-closed R10.3 item **for 01.3 to account for in the allowlist**".
      **Verified on disk.** The pre-revision plan did not carry it at all. New criterion 12: SF-2
      excludes the host and records why, SF-8 Phase C proves `agy` still runs with it denied, and the
      recorded fallback if `agy` hard-fails is to allow with an explicit R10.3 residual. **Fixed in
      the plan.**
- [x] [Auto] **Codex F6 -- Feature 01.4's approved plan is stale against this feature's revised
      Interface Contract 2.** It still expects `CODEX_CA_CERTIFICATE` on `codex`, a per-agent mTLS
      client key at `/run/secrets` "that 01.3 issues", and cites `01.3 SF-7a`. **Verified on disk**
      (lines 148, 416, 429, 205). **Operator decision: re-plan 01.4 in revision mode before it is
      built.** 01.4 is `[~] planned, awaiting build`, so nothing has been built against the stale
      text. **Verified as decided and scheduled, not as executed** -- the re-plan is a separate
      `/plan-feature` invocation.
- [x] [Auto] **Codex F3 -- R5.1's third term.** R5.1 is a MUST covering IP addresses, CIDR ranges
      **and** FQDNs; the resolved-policy schema carried only `deny_cidrs` and `deny_fqdns`. Closed by
      stating that a single address is a `/32`//`128` entry, having the compiler normalise a bare
      address rather than reject it, and asserting in Phase C that a `/32` deny refuses its exact
      address and not its neighbour -- the test that distinguishes a real single-address deny from a
      mis-sized mask. **Fixed in the plan.**
- [x] [Auto] **Codex F8 -- listener certificate SANs.** Interface Contract 2 sets the proxy URL to
      `https://<mediator addr>:3128`, an IP literal, so each listener certificate needs an
      `iPAddress` SAN for that network's static mediator address; a `dNSName` SAN or a CN alone fails
      modern TLS stacks. The failure mode that matters is not the broken handshake but the tempting
      repair -- disabling verification at the agent, silently giving up the server authentication the
      TLS hop exists for. **Phase B now runs every TLS assertion with verification enabled and no
      bypass flag.** **Fixed in the plan.**
- [x] [Auto] **Codex F7 -- stale terminology.** The resolved-policy schema commented `identity:` as
      "certificate subject CN"; renamed to listener policy key, with a note that 01.6 binds a
      certificate subject to the same value. **Fixed in the plan.**
- [x] [Auto] **Codex F1 -- raw-socket egress attempts are invisible to R9.1. Downgraded from
      blocking to a recorded residual; the operator ratified the downgrade at this gate.** This is
      the same residual the 2026-09-04 gate reviewed and approved, raised by the same Codex reviewer
      then. Codex's added T16 citation does not hold here: the plan and the milestone README both
      assign T16 to 02.2, and this feature produces T16's input rather than claiming it. The obvious
      fix -- routing non-CONNECT traffic to the mediator so it can REJECT-and-log -- makes the
      enforcement point a router and contradicts criterion 3's `ip_forward=0` assertion. Partial
      compensation is the DNS audit trail; 02.2 measures the blind spot. **No plan change.**
- [x] [Auto] **Codex F2 -- R8.8/T34 are delegated to a feature that is not yet planned, and
      `REQUIREMENTS.md` R8.8 does not accept network-derived identity. Downgraded from blocking;
      the operator ratified the downgrade at this gate.** The delegation is a milestone-level
      decision `/milestone` took on 2026-09-04 and the milestone README ratifies; 01.3 structurally
      cannot close R8.8 and never claims it. Codex is nonetheless right that the register and the
      README disagree -- R8.8 requires a *distinct issued workload identity* and the README accepts
      "otherwise network-derived", which is topology, not a credential. **The plan's Dependencies
      section now names that drift explicitly and assigns it to 01.6**, which must either close R8.8
      with a real credential per agent or amend it in the register the way this feature amends T28.
      The milestone Definition of Done already blocks on 01.6 landing. **Recorded, not fixed here.**
- [x] [Auto] **Claude's own unverified claim, corrected before approval.** Criterion 12 originally
      asserted that a successful `agy` self-update "cannot persist" because the root filesystem is
      read-only. Checked: `agy` is installed to `/usr/local/bin/agy`, root-owned mode 0755 on the
      read-only layer, and the container runs as uid 1000 -- so the *pinned binary* cannot be
      overwritten. But `$HOME` is `/home/agent`, a writable state volume that survives restarts, and
      the install script takes `-d/--dir`, so a shadowing copy on `PATH` is not ruled out. The claim
      was narrowed to what is established and SF-8 now records the updater's actual target path.

### Carried forward from the 2026-09-04 checklist

- [x] [carried] **Interpretation, criterion 1:** the mediator exposes **two** listeners per agent
      network (proxy + resolver), not the one the milestone README and the architecture's Mediator
      hardening section state. Implemented as the README's own parenthetical -- no management and no
      metrics port -- with the permitted set asserted by enumeration. Unchanged by the re-plan.
      **Re-approved at whole-plan review.**
- [x] [carried] **Interpretation, criterion 5, re-derived:** T28's pass criterion cannot hold as
      written alongside a TLS proxy hop. **The cause changed and the conclusion did not.** In the
      prior plan the conflict was attributed to R8.8's mTLS mechanism; the 01.6 split removes client
      certificates from this feature but *not* the conflict, because `claude` and `agy` still reach an
      `https://` listener whose server certificate they must trust. Operator decision stands: amend
      T28 in `REQUIREMENTS.md` to the property it protects (no mediator CA in any *destination* chain;
      mediator holds no plaintext; Antigravity never intercepted), with the single proxy-hop anchor
      as an explicit exception. `codex` trusts no mediator CA at all.
- [x] [carried] **The T28 register amendment has a recorded owner and landing point -- re-homed.**
      It was scheduled to land in the old SF-6, which no longer exists. It now lands in **SF-3**, is
      listed in Files to Create/Modify, and its matching `docs/ARCHITECTURE_AND_DESIGN.md` entry is
      named in the Documentation section. **Verified as decided and scheduled, not as executed.**
      01.6 carries T34's separate amendment; that one is not this feature's.
- [x] [carried] **Feature 01.1's approved plan contradicts R5.1** ("nothing in the register asks for
      FQDN-level deny"). 01.3 carries the fix in schema, mediator and `policy/denylist.base.yaml`.
      **Still pending:** the denylist header on disk continues to assert the false statement, so the
      01.1 re-plan has not yet happened. **Operator decision stands: re-plan 01.1 in revision mode.**
      **Verified as decided and scheduled, not as executed.**
- [x] [carried] **Residual against R9.1, criterion 7** -- see Codex F1 above. Unchanged by the
      re-plan and re-affirmed at this gate.
- [x] [carried] **Residual against D5's rationale, control 3** -- under D4's splice the mediator
      counts connections and bytes, never requests, so a runaway loop reusing one connection is not
      bounded by request count. Unchanged by the re-plan. Recorded as a residual, not presented as
      satisfying D5.
- [x] [carried] **SF-1 gates the rest -- scope grew from six properties to eight.** P7 (heterogeneous
      listeners: two TLS and one plain-HTTP CONNECT in one instance, each selecting an independent
      per-agent policy) is the new tightest constraint and is the direct consequence of 01.1 SF-2.
      P8 (per-client policy selection from a proxy credential) is verified here for **01.6's**
      benefit, because this feature pins the implementation and 01.6 cannot re-open that choice. P1
      is restated as *capable*, not *enabled*. The exact proxy version is recorded and SF-4 pins to
      it.
- [x] [carried] **Cross-feature dependency: SF-4 amends `tests/acceptance/verify-pod-topology.sh`.**
      Reason updated -- 01.2's mount-set equality assertion (`{/home/agent, /workspace}`, verified at
      line 167 on disk) now breaks on the **CA secret** mounted into `claude` and `agy`, not on a
      client certificate. New asymmetry the amended check must tolerate: `codex` mounts no secret at
      all, so the three agents no longer share one expected mount set.
- [x] [carried, status changed] **Confirm the `agy` listener, network and allowlist entries.**
      **Was `[-]` N/A pending 01.1 SF-2; now `[x]` resolved positive.** `agy` honours `HTTPS_PROXY`
      for both `http://` and `https://` schemes and trusts a CA via `SSL_CERT_FILE`. All three agent
      networks, listeners and allowlists are in scope; no agent loses its route. `agy`'s TLS hop is
      kept deliberately rather than dropped to plain HTTP for consistency with `codex` -- recorded
      with its reason, as the escalation record asked.
- [-] [carried] **Validate the `limits` values against measured traffic -- still N/A at this gate,
      for a weaker reason than before.** 01.1 SF-3's discovery capture now exists
      (`docs/records/egress-discovery.md`), so data that could inform these values is no longer
      absent. It was taken under `sbx`, where UDP and ICMP are invisible to the capture, so it bounds
      request volume loosely rather than settling the numbers. The values remain proposals, adjustable
      at build time under DD-12 without gate re-approval.

### New at this re-plan

- [x] [Auto] **The 01.3/01.6 boundary is stated in the artifact, not left to be inferred.** Interface
      Contract 3 lists it row by row with an owner column, criterion 6 states what 01.3 owns and what
      it does not, and SF-3's description cites the milestone README's own words ("the CA and listener
      certificates the TLS hops need") so the boundary is not re-litigated when 01.6 is planned.
- [x] [Auto] **`identity_source` emits exactly one value (`listener`) at this feature, and the field
      exists anyway.** Present so 01.6 extends its enumeration rather than the schema, and so a log
      written now does not need retroactive reinterpretation. 01.3 deliberately does **not**
      pre-declare 01.6's value names -- what 01.6 adds depends on a verification result that does not
      exist yet.
- [x] [Auto] **Milestone README internal drift, recorded rather than silently reconciled.** 01.6's
      feature text assigns the proxy-credential question to 01.6; the Configuration table says "if
      01.3's verification finds one". **Operator decision: split it** -- 01.3 SF-1 verifies the proxy
      side (P8), 01.6 verifies the agent side. The README itself is `/milestone`'s to correct, not
      this plan's; noted here so it is not lost.
- [x] [Auto] **Stale-state closures assigned to `/build`.** Three records outlive the state they
      describe and are listed in Files to Create/Modify:
      `docs/records/r8-8-identity-mechanism-gap-escalation.md` still reads
      `Status: Open -- blocks 01.3 build` (the revision it demanded has happened); 01.2's recorded
      Deviation 3 (`egress-net` not a live Docker resource) is closed when SF-4 attaches the mediator;
      and `profiles/default.yaml`'s comment that the override binds `..` becomes false with the mount
      repoint.

## Reviewer Comments

Approved at whole-plan review on 2026-09-05 after a Codex adversarial review pass, following the same
discipline as the 2026-09-04 gate. Codex returned eight findings: **six produced plan changes**, and
**two were downgraded from `blocking` with the operator ratifying each downgrade explicitly at this
gate** rather than the downgrade being recorded silently by Claude.

Three of Codex's findings were **verified against files on disk before being accepted** -- F4 (the
default override binds the solution tree read-write), F5 (the `agy` auto-updater host is allowlisted
against a MUST) and F6 (01.4's plan is stale against the revised Interface Contract 2). F5 is the
highest-value finding of the pass by the criterion the review was asked to prioritise: a requirement
that fell into the gap between features, explicitly handed to 01.3 by 01.1's verification record and
not carried by the pre-revision plan. F4 is the most consequential in practice, because the plan's own
Phase A assertion would have failed on the default profile rather than catching a misconfiguration.

One defect was found by Claude rather than by Codex, in Claude's own newly written text: criterion 12
asserted that an `agy` self-update could not persist, on the strength of the read-only root
filesystem, without checking where the updater writes. `$HOME` is a writable state volume. The claim
was narrowed to what the evidence supports and the open half was turned into an SF-8 assertion.

Three re-plan commitments are resolved as **decided and scheduled rather than executed**, each a
separate `/plan-feature` invocation: 01.1 (the `deny_fqdns` contradiction, carried from the prior
gate and still pending on disk), 01.4 (stale against Interface Contract 2), and the `REQUIREMENTS.md`
T28 amendment (re-homed from the retired SF-6 to SF-3, landing during `/build`). What this gate
verified for all three is that the decision is recorded, the owner named and the landing point
listed -- not that the edit exists on disk.

One item is `[-]`: the `limits` values, still proposals, now with capture data that informs but does
not settle them. All remaining items are `[x]`.
