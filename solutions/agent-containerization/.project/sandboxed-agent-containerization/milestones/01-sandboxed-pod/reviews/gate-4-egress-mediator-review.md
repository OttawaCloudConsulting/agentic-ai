# Gate 4 Review -- Feature Plan: Egress mediator

**Artifact:** .project/sandboxed-agent-containerization/milestones/01-sandboxed-pod/plans/egress-mediator.md
**Status:** [x] Approved
**Reviewer(s):** OCC (operator)
**Date:** 2026-09-04

## Checklist

- [x] Does the approach handle known edge cases? -- 16 edge cases recorded, including four raised by
      the Codex review pass: the unlogged raw-socket attempt (R9.1 residual), the DNS covert channel
      over allowlisted names, the control plane inside the read-write project mount, and Encrypted
      ClientHello defeating the SNI-equality check. Each names its mitigation or records the residual
      explicitly rather than leaving it implied.
- [x] Are the sub-features correctly scoped for single-session work? -- Eight, dependency-ordered.
      SF-7 was flagged `[OVERSIZED]` at plan time and split into SF-7a (product code) and SF-7b (test
      code) on the operator's decision. No sub-feature carries the flag in the approved list. SF-5 is
      the closest remaining call and is kept whole with its split condition stated.
- [x] Is the test command appropriate for this feature? -- `bash tests/acceptance/verify-egress-mediator.sh`.
      Seven phases (A-G) covering T3-T8, T17, T28, T34 plus the listener-set, forwarding,
      control-plane-mount and sink-reachability assertions. Follows the repository convention:
      `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644, invoked as `bash`.
- [x] Are the files to create/modify correct? -- 15 create, 8 modify. Paths follow the ratified file
      tree in `docs/ARCHITECTURE_AND_DESIGN.md`. `.gitignore` is correctly listed as Create: the
      solution directory has none today (verified on disk).
- [x] Are interface contracts compatible with existing code? -- Six contracts. Contract 5 extends
      01.2's Compose seam rather than replacing it; contract 1 fixes the schema 01.5's compiler must
      continue to emit; contract 2 is what 01.4's OAuth flows land on. No in-repo container, proxy,
      resolver or CA prior art exists to conflict with -- the component is greenfield.

- [x] [Auto] Interpretation, criterion 1: the mediator exposes **two** listeners per agent network
      (proxy + resolver), not the one the milestone README and the architecture's Mediator hardening
      section state. Implemented as the README's own parenthetical -- no management and no metrics
      port -- with the permitted set asserted by enumeration. **Approved at whole-plan review.** The
      cost is stated in the plan: a resolver is a second protocol parser reachable from inside the
      blast radius, accepted because D3/R5.4 make owning DNS mandatory and the alternative is a live
      exfiltration channel.
- [x] [Auto] Interpretation, criterion 5: T28's pass criterion cannot hold as written alongside
      R8.8's mTLS mechanism -- client certificates require a TLS proxy hop the agent must trust.
      **Operator decision at this gate: amend T28 in `REQUIREMENTS.md`** to the property it protects
      (no mediator CA in any *destination* chain; mediator holds no plaintext; Antigravity never
      intercepted), with the single proxy-hop anchor recorded as an explicit exception. R8.8 is
      unchanged. Confirmed independently by the Codex review, which reached the same conflict.
- [x] [Auto] The T28 register amendment has a recorded owner and landing point: `/build` makes it
      during SF-6, the plan lists `REQUIREMENTS.md` in Files to Create/Modify, and its Documentation
      section names the same reading for `docs/ARCHITECTURE_AND_DESIGN.md`. **Verified as decided and
      scheduled, not as executed** -- an interpretation landing in only one of the two documents
      would be drift by construction, which is why both are named.
- [x] [Auto] Feature 01.1's approved plan states "nothing in the register asks for
      FQDN-level deny", which is false against R5.1 (MUST: deny specific IP addresses, CIDR ranges
      **and FQDNs**). 01.3 carries the fix by adding `deny_fqdns` to the schema, the mediator and
      `policy/denylist.base.yaml`. **Operator decision: re-plan 01.1 in revision mode once this gate
      closes** so the approved contract on disk stops contradicting a MUST. **Verified as decided and
      scheduled, not as executed** -- the re-plan is a separate `/plan-feature` invocation and is not
      a property of this plan. 01.3's own fix needs nothing further.
- [x] [Auto] Residual against R9.1, criterion 7: an agent that unsets its proxy variables and opens a
      raw socket fails with `ENETUNREACH` in its own namespace, so no audit line is written for an
      attempt R9.1 calls "the detection signal for a compromised agent". Recorded as a residual with
      the reason the obvious fix is rejected -- routing non-CONNECT traffic to the mediator so it can
      REJECT-and-log would make the enforcement point a router, contradicting criterion 3. Partial
      compensation is the DNS audit trail; 02.2 measures the blind spot.
- [x] [Auto] Residual against D5's rationale, control 3: under D4's splice the mediator counts
      connections and bytes, never requests, so a runaway loop reusing one connection is not bounded
      by request count. Ceilings shipped are `max_concurrent`, `connections_per_minute` and
      `bytes_per_second`. Request-level limiting would require terminating TLS, which R5.15 forbids
      and R5.13 permanently bars for `agy`. Recorded as a residual, not presented as satisfying D5.
- [x] [Auto] Verify sub-feature SF-1 gates the rest: six properties (P1-P6) are verified against the
      selected proxy and **the exact version recorded**, before SF-2 to SF-7b build on them. SF-3
      pins to that version. Squid's named directives are marked hypotheses to test, not asserted
      capabilities. A failure on P1, P2 or P6 changes what SF-5 and SF-6 build.
- [x] [Auto] Confirm cross-feature dependency: SF-3 amends `tests/acceptance/verify-pod-topology.sh`.
      01.2's mount-set **equality** assertion fails the moment a client-certificate secret is mounted
      under `/run/secrets`, so extending the allowed set is explicit work in this plan rather than a
      break discovered during the build.
- [-] [Auto] Validate the `limits` values against measured traffic -- **N/A at this gate.** The plan
      states they are proposals, not measurements; no traffic has been observed to derive them from.
      01.1 SF-3's discovery capture is the first data that could, and the values are confirmed or
      adjusted at build time under DD-12 without gate re-approval.
- [-] [Auto] Confirm the `agy` listener, network and allowlist entries -- **N/A until 01.1 SF-2
      reports.** If `agy` does not honour `HTTPS_PROXY` it has no route on an `internal: true`
      network, which the milestone README calls a design change under D1 that stops the build for
      that agent. This plan would then ship two agent networks and two listeners, and the third is a
      `/milestone` revision. Recorded as a dependency, not a plan defect.

## Reviewer Comments

Approved at whole-plan review on 2026-09-04 after a Codex adversarial review pass. Codex returned ten
findings; seven produced plan changes (unlogged raw-socket attempts, the DNS covert channel and
missing DNS audit, the control plane inside the read-write project mount, Encrypted ClientHello, the
never-exercised startup reachability check, T8's two untested tamper surfaces, and the unpinned proxy
version). Three restated interpretations already flagged in the plan, which is confirmation the
conflicts are real rather than evidence of new defects.

Two items are resolved as **decided and scheduled rather than executed**: the `REQUIREMENTS.md` T28
amendment lands in `/build` during SF-6, and the 01.1 re-plan is a separate `/plan-feature`
invocation. What this gate verified for both is that the decision is recorded, the owner named and
the landing point listed in the plan -- not that the edit exists on disk. Neither is a gap in this
plan; both are work this gate authorised and placed elsewhere.

Two items are `[-]`: the `limits` values (proposals, adjustable at build time under DD-12 without
gate re-approval) and the `agy` listener and allowlist entries (blocked on 01.1 SF-2's `HTTPS_PROXY`
result, a `/milestone` matter if negative). All remaining items are `[x]`.
