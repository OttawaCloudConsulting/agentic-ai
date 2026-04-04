---
phase: 9
slug: nyquist-compliance
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-03
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash grep (content assertions) |
| **Config file** | none — no test framework needed |
| **Quick run command** | `grep -rq 'nyquist_compliant: true' .planning/phases/` |
| **Full suite command** | `bash scripts/lint-markdown.sh -r .planning/phases/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Verify the updated VALIDATION.md has `nyquist_compliant: true`
- **After every plan wave:** Run full suite grep across all 7 phases
- **Before `/gsd:verify-work`:** All 7 phases must have both flags set to `true`
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 9-01-01 | 01 | 1 | tech-debt | content | `grep -q 'wave_0_complete: true' .planning/phases/01-project-router/01-VALIDATION.md && echo PASS` | ✅ | ✅ green |
| 9-01-02 | 01 | 1 | tech-debt | content | `grep -q 'wave_0_complete: true' .planning/phases/02-define-gates-0-wb-1/02-VALIDATION.md && echo PASS` | ✅ | ✅ green |
| 9-01-03 | 01 | 1 | tech-debt | content | `grep -q 'wave_0_complete: true' .planning/phases/03-design-gate-2/03-VALIDATION.md && echo PASS` | ✅ | ✅ green |
| 9-01-04 | 01 | 1 | tech-debt | content | `grep -q 'wave_0_complete: true' .planning/phases/04-milestone-gate-3/04-VALIDATION.md && echo PASS` | ✅ | ✅ green |
| 9-01-05 | 01 | 1 | tech-debt | content | `grep -q 'wave_0_complete: true' .planning/phases/05-plan-gate-4/05-VALIDATION.md && echo PASS` | ✅ | ✅ green |
| 9-01-06 | 01 | 1 | tech-debt | content | `grep -q 'wave_0_complete: true' .planning/phases/06-build/06-VALIDATION.md && echo PASS` | ✅ | ✅ green |
| 9-01-07 | 01 | 1 | tech-debt | content | `grep -q 'wave_0_complete: true' .planning/phases/07-spike-docs/07-VALIDATION.md && echo PASS` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework needed — all checks are bash grep assertions against VALIDATION.md files.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Grep commands actually pass (exit 0) | tech-debt | Requires shell execution | Run each bash command in VALIDATION.md; verify exit code 0 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-04-03
