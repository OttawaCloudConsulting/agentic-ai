---
phase: 5
slug: plan-gate-4
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual validation (Markdown skill — no automated test framework) |
| **Config file** | none |
| **Quick run command** | `bash cicd/lint-markdown.sh` |
| **Full suite command** | `bash cicd/lint-markdown.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash cicd/lint-markdown.sh`
- **After every plan wave:** Run `bash cicd/lint-markdown.sh` + manual review of SKILL.md structure
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | PLAN-01 | manual-only | Manual: invoke /plan, verify it reads all 5 inputs | N/A | ⬜ pending |
| 05-01-02 | 01 | 1 | PLAN-02 | manual-only | Manual: invoke /plan with invalid feature name | N/A | ⬜ pending |
| 05-01-03 | 01 | 1 | PLAN-03 | manual-only | Manual: review generated plan against template | N/A | ⬜ pending |
| 05-01-04 | 01 | 1 | PLAN-04 | manual-only | Manual: create feature with large scope, verify split proposal | N/A | ⬜ pending |
| 05-01-05 | 01 | 1 | PLAN-05 | manual-only | Manual: verify gate-4-review.md created | N/A | ⬜ pending |
| 05-01-06 | 01 | 1 | PLAN-06 | manual-only | Manual: verify Plan: field updated after plan creation | N/A | ⬜ pending |
| 05-01-07 | 01 | 1 | PLAN-07 | manual-only | Manual: verify tradeoff callouts and review prompts | N/A | ⬜ pending |
| 05-01-08 | 01 | 1 | PLAN-08 | manual-only | Manual: request revision, verify targeted edit | N/A | ⬜ pending |
| 05-01-09 | 01 | 1 | PLAN-09 | manual-only | Manual: approve plan, verify milestone-status.txt marker change | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No framework install needed — this is a Markdown-based skill (prompt engineering).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Reads correct input files | PLAN-01 | Markdown skill — no application code to unit-test | Invoke /plan, verify it reads milestone README, prd.md, ARCHITECTURE_AND_DESIGN.md, progress.txt, milestone-status.txt |
| Validates feature exists and is pending | PLAN-02 | Requires Claude Code session | Invoke /plan with invalid feature name, verify error message |
| Plan file has all required sections | PLAN-03 | Output is generated markdown | Review generated plan against DESIGN.md template spec |
| Oversized sub-features flagged | PLAN-04 | Requires judgment-based sizing | Create feature with large scope, verify split proposal shown |
| Review checklist produced | PLAN-05 | File creation verification | Verify gate-4-<feature>-review.md created with correct items |
| milestone-status.txt updated with plan path | PLAN-06 | State file write verification | Verify Plan: field updated in milestone-status.txt after plan creation |
| Plan presented with correct review focus | PLAN-07 | UX verification | Verify tradeoff callouts and approve/revise prompt shown |
| In-session revision works | PLAN-08 | Interactive flow verification | Request revision, verify targeted edit without restart |
| Gate 4 approval updates status to [~] | PLAN-09 | State file write verification | Approve plan, verify milestone-status.txt feature entry changes from [ ] to [~] |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
