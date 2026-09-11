# Gate 4 Review -- Feature Plan: Audit completeness — agent action log, sink and exports

**Artifact:** .project/sandboxed-agent-containerization/milestones/02-proven-and-composable/plans/audit-completeness-agent-action-log-sink-and-exports.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-10

## Pre-checks (verified programmatically)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present (Summary through Architectural Deviations)
- [x] `milestone-status.txt` exists for milestone 02
- [x] Feature 02.1 exists in `milestone-status.txt`

## Checklist

- [x] Does the approach handle known edge cases?
- [x] Are the sub-features correctly scoped for single-session work?
- [x] Is the test command appropriate for this feature?
- [x] Are the files to create/modify correct?
- [x] Are interface contracts compatible with existing code?
- [x] [Auto] Verify sub-feature: "SF-2: Recorder and action sink" fits within a ~120k-token session. It is the largest SF: new image, new script, three services, three volumes, two harness amendments. SF-4's named split (4a/4b) is the fallback if SF-4 runs long
- [x] [Auto] Confirm Decision 1: narrowing `verify-pod-topology.sh:110-130` from "no named volume mounted by two services" to "no state volume mounted by two agent services; its only other mounter is its own recorder, ro, `network_mode: none`" is a harness amendment implementing the inventory row's "sidecar tail", not a design change to D7
- [x] [Auto] Confirm Decision 2: recorder-owned `<agent>-action-audit` volumes satisfy D12's operative clause ("never a volume an agent container can reach"), with the reading recorded rather than edited into the architecture document
- [x] [Auto] Confirm Decision 6: the stdout relays are the log exports; disabling `egress_audit_log` stops the two mediator relays, the supervisor treats a disabled relay as absent rather than dead, and the FIFO → volume recording path reads no toggle (D11)
- [x] [Auto] Check dependency: `scripts/compile-policy.sh` compiling a profile from outside `profiles/` (T36 scratch variants). Today `--profile` takes a name. SF-1 measures it; the fallback is a narrow `--profile-file` flag, not committed test profiles and not a T36 amendment
- [x] [Auto] Confirm edge case: the `agy` stdout-only branch (Decision 3), where real time cannot be met and a tee through `agy-run.sh` is itself a design choice, is surfaced to the operator at SF-1 close rather than decided inside the build
- [x] [Auto] Confirm interface: `export_config` is compatible with `verify-egress-mediator.sh` Phase G. Verified: Phase G's Contract-4 check is `select((.verdict != null) == (.event != null))`, and the event has `event` and no `verdict`, so it passes. The plan still asserts it in SF-4
- [x] [Auto] Verify file: resolved-artifact set. Verified: `policy/resolved/` holds `default`, `test-fixtures` and `test-selfcheck`, which is three, not four. The plan was corrected after approval (see Reviewer Comments)

## Reviewer Comments

- **Post-approval factual correction, 2026-09-10.** The plan as first presented said four committed
  resolved artifacts (including `oauth-mount`) would be recompiled. `policy/resolved/` holds
  three. `oauth-mount` is a one-shot bootstrap profile with no committed artifact, and the running
  pod loads `default`. The plan was corrected in four places (Decision 6, the Decision 9 table,
  SF-4, and the Files table), and an Edge Cases row was added: `oauth-mount`'s `exports` block is
  never read at runtime. The design is unchanged.
