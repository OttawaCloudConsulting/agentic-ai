# Gate 4 Review -- Feature Plan: Tool pack set, use-case profiles and MCP inventory

**Artifact:** .project/sandboxed-agent-containerization/milestones/02-proven-and-composable/plans/tool-pack-set-use-case-profiles-and-mcp-inventory.md
**Status:** [x] Approved
**Reviewer(s):** Operator (cturner)
**Date:** 2026-09-10

## Pre-checks (verified programmatically)

- [x] Plan file exists at the expected path
- [x] All 12 required sections present (Summary through Architectural Deviations)
- [x] `milestone-status.txt` exists for milestone 02
- [x] Feature 02.3 exists in `milestone-status.txt`

## Checklist

- [x] Does the approach handle known edge cases?
- [x] Are the sub-features correctly scoped for single-session work?
- [x] Is the test command appropriate for this feature?
- [x] Are the files to create/modify correct?
- [x] Are interface contracts compatible with existing code?
- [x] [Auto] Confirm Decision 4's T14 rule. Per agent, the entries gained must equal the pack's runtime entries minus base entries (`compile-policy.sh:947` de-duplicates on `fqdn|port|upgrade`), and unloading must give a byte-identical artifact. T14's recorded acceptance is on Terraform, the clean case: no base agent carries a HashiCorp host. GitHub CLI is recorded as the overlap case, because `codex`'s base already holds `github.com` and `api.github.com` (`allowlist.base.yaml:80-87`)
- [x] [Auto] Confirm that Terraform, GitHub CLI and every per-cluster pack set `runtime_install: true` with a reason. The R7.6 gate refuses **any** runtime egress without it (`compile-policy.sh:661-664`), and the plan keeps that conservative reading rather than relaxing it. The shipped `kubernetes` pack has zero runtime egress, so it sets `false`
- [x] [Auto] Confirm T32 records the gap for **all three** agents, Claude Code included. `srt` is not installed, and D14 as amended disables every native sandbox. The compensating control is the T29 start-time gate refusing the next start. A proposed T32 amendment is recorded, and `REQUIREMENTS.md` is not edited
- [x] [Auto] Confirm the dependency chain:
      - 02.1 `[x]` supplies the `exports` shape, the `test-exports.yaml` mount-over precedent and the `--profile-file` finding;
      - 02.2 `[x]` supplies `validate-boundary.sh`;
      - if `--profile-file` is absent after 02.1, SF-8 adds it as the compiler interface change 02.1 named (Decision 10)
- [x] [Auto] Confirm the MCP gate's **fatal-at-first-start** behaviour and its migration. SF-6 inspects the operator's seed volumes read-only, with consent, before SF-7 lands the gate. The gate does not grandfather any entry. This deliberately differs from the auth bootstrap's warn-don't-block posture (01.4 Deviation 2)
- [x] [Auto] Verify sub-feature sizing. SF-1 and SF-2, the schema and delivery change, are split along the compile/deliver seam, and SF-2 has a named split (2a env / 2b credentials). The MCP half, SF-6 and SF-7, carries the milestone README's named fallback: it moves to its own milestone via `/milestone` revision mode, never by silent deferral

## Reviewer Comments

- **Approved 2026-09-10. Both tradeoff callouts and all four assumptions were resolved to the plan's
  stated positions.**
  - Callout 1: one hand-authored override per profile, verified by `check-profile-compose.sh`, over
    a generated secrets fragment.
  - Callout 2: an empty, explicit MCP inventory, with T29–T31 exercised by fixtures, over shipping a
    real server.
  - Assumptions confirmed: Terraform and not OpenTofu (BSL 1.1 acceptable for one-workstation use);
    no specific operator cluster in 02.3; no git-over-HTTPS push wiring; pack-named profiles
    (`terraform`, `kubernetes`, `github`).

  No plan edits followed approval.
- **Two internal contradictions and several gaps were fixed before approval** (advisor review):
  - Composed MCP egress keeps its `mcp:<server>` source inside the compiler only and is not emitted,
    so the resolved schema is unchanged.
  - The bind-mounted test inventory is never compiled, so the fixture host `mcp.fixture.lab` moves
    into `allowlist.test.yaml`.
  - The per-profile `validate-boundary.sh` iteration now states its whole-pod cost (four agent
    rebuilds, `default` last).
  - 02.1's R8.6 redaction pattern set is extended to the two new credential formats.
  - A first-start migration edge case covers volumes and repositories that already carry MCP
    entries.
  - `check-profile-compose.sh` compares the full rendered service, not the hardening fields alone.
  - An explicit anchor convention is set for `third_parties` records.
- **Recorded for authorities outside `/plan-feature`**, and not applied:
  - T32 amendment ("Blocked for Claude Code via `srt`" has no satisfiable form under D14);
  - R2.8 enumeration of pack-credential secrets;
  - architecture edits: D10 amendment (1), the Tool packs component row, the file tree, and the
    R8.4 credential enumeration.
