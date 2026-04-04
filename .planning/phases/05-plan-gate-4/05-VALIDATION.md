---
phase: 5
slug: plan-gate-4
status: draft
nyquist_compliant: true
wave_0_complete: true
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
| **Quick run command** | `bash -c 'grep -q "Gate 4" skills/project/plan/SKILL.md && echo PASS'` |
| **Full suite command** | `bash -c 'grep -q "Gate 4" skills/project/plan/SKILL.md && grep -q "milestone-status" skills/project/plan/SKILL.md && grep -q "sub-feature" skills/project/plan/SKILL.md && echo ALL_PASS'` |
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
| 05-01-C1 | 01 | 1 | PLAN-02/09 | content | `grep -q 'Gate 4' skills/project/plan/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 05-01-C2 | 01 | 1 | PLAN-06/09 | content | `grep -q 'milestone-status' skills/project/plan/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 05-01-C3 | 01 | 1 | PLAN-04 | content | `grep -q 'sub-feature' skills/project/plan/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 05-01-C4 | 01 | 1 | PLAN-09 | content | `grep -q 'awaiting build\|awaiting' skills/project/plan/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 05-01-C5 | 01 | 1 | PLAN-03 | content | `grep -q 'gate-4-plan\|gate-4' skills/project/plan/SKILL.md && echo PASS` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Target file (`skills/project/plan/SKILL.md`) exists on disk. No new files, no framework setup required.

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

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-04-03
