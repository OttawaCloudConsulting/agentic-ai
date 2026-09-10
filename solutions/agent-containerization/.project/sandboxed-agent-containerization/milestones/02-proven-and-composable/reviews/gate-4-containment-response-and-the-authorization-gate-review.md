# Gate 4 Review -- Feature Plan: Containment, response and the authorization gate

**Artifact:** .project/sandboxed-agent-containerization/milestones/02-proven-and-composable/plans/containment-response-and-the-authorization-gate.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-10

## Pre-checks (verified programmatically)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present (Summary through Architectural Deviations)
- [x] `milestone-status.txt` exists for milestone 02
- [x] Feature 02.5 exists in `milestone-status.txt`

## Checklist

- [x] Does the approach handle known edge cases?
- [x] Are the sub-features correctly scoped for single-session work?
- [x] Is the test command appropriate for this feature?
- [x] Are the files to create/modify correct?
- [x] Are interface contracts compatible with existing code?
- [x] [Auto] Confirm the T37 rule (Decision 1, Contract 2):
      - it enforces capability absence at compile time. A classified action enabled by a loaded pack
        or an inventoried MCP server exits 3 unless it is moved to a per-action `waive` with a
        reason;
      - the vocabulary is closed over every committed manifest, so an unknown action exits 2;
      - it edits 01.5's `authorization` field and 02.3's `github`/`kubernetes` profiles, and every
        resolved artifact is recompiled and passes `--check` in the same commit;
      - `codex`'s halt rests on credential absence, because its base allowlist carries `github.com`.
        No harness contacts a third-party host.
- [x] [Auto] Confirm the T26 measurement (Decision 2, Contract 6):
      - `t0` is the incident declaration and `t1` is a failed replay;
      - OAuth access tokens are replayed separately from refresh tokens;
      - "no rebuild" means every service's image ID is equal before and after;
      - the stated maxima are set before the drill;
      - drill credentials only, never working ones. No credential value enters the public record.
- [x] [Auto] Confirm T41 and R12.5 (Decision 5, Contract 5):
      - every volume in every shipped profile's `docker compose config` has a disposition row, and
        phase A fails otherwise;
      - `audit` and the action-audit volumes are preserved;
      - discarding is not revoking: T41 chains T26 for the contaminated agent;
      - `down -v` is never used during an incident, and the harness uses it only in its own trap.
- [x] [Auto] Confirm the T40 MCP half stays a proposal:
      - it is exercised against 02.3's `test-mcp.yaml`, and the R13.2/T40 amendment is recorded as
        text;
      - R13.2 stays formally unmet until the operator accepts it, and the milestone DoD gates the
        R12.8 notice on that acceptance.
- [x] [Auto] Confirm the leaked one-year `CLAUDE_CODE_OAUTH_TOKEN` is revoked **now**, outside
      02.5's build order (Edge Case 1). E4's drill mints and revokes a fresh drill token.
- [x] [Auto] Verify SF-2 fits a single `/build` session. It covers:
      - the compiler rule;
      - two manifests and two profiles;
      - probe fixtures;
      - harness phase F;
      - the recompile of every resolved artifact.

## Reviewer Comments

- **Approved 2026-09-10.** Both tradeoff callouts were resolved to the plan's recommended positions:
  - Callout 1: T37 is enforced by capability absence at compile time. The schema gains a per-action
    `waive` and a closed vocabulary. The alternatives were a mediator operator-hold and an
    in-container hook.
  - Callout 2: the T40 MCP-disable half is exercised against 02.3's test inventory and the R13.2/T40
    amendment is proposed as text, not built. R13.2 stays formally unmet until the operator accepts
    the amendment, which the milestone DoD gates on.
- **Review assumptions confirmed:**
  1. Stated maximum detection-to-revocation times: **30 minutes** for provider credentials (E1–E4,
     V1–V3) and pack credentials (P1–P2); **10 minutes** for pod-local identity material (S1–S3).
     These are set before the drills, and the drills must beat them.
  2. The event and incident definitions are as drafted in Interface Contract 7.
  3. The operator supplies the `waive` reasons for the `github` and `kubernetes` profiles at SF-2,
     including the PAT and RBAC scope that bounds each.
  4. The operator mints the drill credentials. Without a disposable cluster, P2 is recorded as a
     named gap.
  5. Ottawa Cloud Consulting owns the R14.3 review for all three provider routes, on a **monthly**
     cadence plus provider-announcement subscriptions.
- **Security action outside the build order:** the leaked one-year `CLAUDE_CODE_OAUTH_TOKEN`
  (`docs/records/prd-refresh-drift-2026-09-09.md:106-110`) is to be revoked now by the operator. It is
  recorded in `containment-drills.md` as a pre-drill revocation, with the date and without the value.
- **Found during planning, not assumed:**
  - R12.7 is shape-only (`compile-policy.sh:385-412`).
  - The credential inventory has no S2/S3 rows and no stated maxima.
  - The mediator policy is baked in at build and has no reload, so the architecture runbook's
    "denylist entry" is a rebuild.
  - `codex`'s base allowlist carries `github.com`.
  - The R14.3 owner covers the Antigravity route only.
  - Every harness cleans up with `down -v`, which would destroy the audit volume.
- **Recorded for authorities outside `/plan-feature`**, and not applied:
  - the architecture document's containment runbook table;
  - the R13.2/T40 amendment against `REQUIREMENTS.md`.
