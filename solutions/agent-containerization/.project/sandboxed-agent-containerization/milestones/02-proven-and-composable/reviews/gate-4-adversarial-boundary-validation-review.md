# Gate 4 Review -- Feature Plan: Adversarial boundary validation

**Artifact:** .project/sandboxed-agent-containerization/milestones/02-proven-and-composable/plans/adversarial-boundary-validation.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-10

## Pre-checks (verified programmatically)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present (Summary through Architectural Deviations)
- [x] `milestone-status.txt` exists for milestone 02
- [x] Feature 02.2 exists in `milestone-status.txt`

## Checklist

- [x] Does the approach handle known edge cases?
- [x] Are the sub-features correctly scoped for single-session work?
- [x] Is the test command appropriate for this feature?
- [x] Are the files to create/modify correct?
- [x] Are interface contracts compatible with existing code?
- [x] [Auto] Confirm the crux: T1–T8 run from inside the **real agent container** per agent (via `start_agents`/`in_agent`, `verify-pack-composition.sh:811-824`), not from the `probe()` mediator-image path (`verify-egress-mediator.sh:88-91`) that the existing smoke checks use. This is why 02.2 is a distinct feature from 01.3
- [x] [Auto] Confirm a failed scenario is recorded as a **design finding** routed to `/milestone` revision mode, not patched inside 02.2 (Decision 9, Gate 3 reviewer comment)
- [x] [Auto] Confirm Decision 7: `provisional: true` → `false` (operator selected the flip). `compile-policy.sh:188-190` `has()` already treats `false` as present, so the flip touches only `lint-policy.sh:37-38` plus a `resolved/default.yaml` recompile; `compile-policy.sh` is unchanged. `allowlist.test.yaml` keeps its own marker, so the two test artifacts do not recompile
- [x] [Auto] Confirm Decision 4: A2A tested on the shipped topology (operator selected). Direct half = no-route (D2 `internal: true`); relay half = allowlist default-deny; split recorded. No new `test-boundary` denylist
- [x] [Auto] Confirm the CDN-rotation TTL/cache defeat: fixture serves `rotating.fixture.lab` at TTL 0–1s and the suite sleeps past it, because `proxy.conf.tmpl` sets no `positive_dns_ttl` (Squid 6h default cap applies) and would otherwise answer attempt 2 from cache. The deny line asserts `resolved_ip` = the denied `.21`. A cached allow despite the short TTL is a D5 freshness finding, not a test bug (Decision 5)
- [x] [Auto] Confirm ICMP expected result is **EPERM at `socket()`** (`CAP_NET_RAW` dropped, `ping_group_range` unset), recorded as the mechanism — not a bug to fix by adding `NET_RAW` (SF-2, Edge Cases)
- [x] [Auto] Verify file: the read-only fixture mount resolves under the compose **project dir** — `../tests/fixtures/ro-fixture:/fixture-ro:ro` in `test-boundary-ro.yaml`, matching `default.yaml:43`'s `../workspace` convention, layered only for the R11.4 phase; and it is **not** `../` (which would mount `mediator-ca.key` into every agent and trip `verify-pack-composition.sh` Phase G) (Decision 6, Interface Contract 4)
- [x] [Auto] Confirm R11.4 is the host-side claim: `/proc/self/mountinfo` shows `,ro,` (pattern at `verify-auth-state.sh:845-852`) **and** the host file is sha256-unchanged after a write attempt — stronger than T2's in-container write failure
- [x] [Auto] Check dependency: T16 (SF-6) and SF-4's `action_logged` read the 02.1 sink, which does not exist until 02.1 is `[x]` (currently 0/5). Both sequence after 02.1 completes; stated in Dependencies
- [x] [Auto] Confirm the T-matrix maps to `REQUIREMENTS.md:457-464`, never to the existing harness `pass` strings (where "T3" is a raw socket and "T7" is an SNI mismatch)
- [x] [Auto] Confirm the harness location deviation: `tests/acceptance/validate-boundary.sh` (not `scripts/` per arch file tree `:170`) is carried as an Architectural Deviation for the milestone consolidation pass (Decision 1)

## Reviewer Comments

- **Approved 2026-09-10 with both open decisions resolved to the recommended options.** Decision 7:
  flip `provisional` to `false` (auditable claim, one script changed) over removal. Decision 4:
  agent-to-agent tested on the shipped topology (direct no-route + allowlist-covered relay) over a
  new `test-boundary` denylist. The plan already documented both as the recommended path, so no
  plan edits followed approval.
- **Three contract defects were fixed pre-approval** (advisor review): the `ro-fixture` bind path
  (`./` → `../`, compose project-dir relative); the CDN-rotation TTL/cache defeat (short TTL +
  sleep, else the scenario measures cache freshness not control 2); and the `provisional` mechanism
  (`false` flip needs only `lint-policy.sh` + recompile, not the three-script removal).
