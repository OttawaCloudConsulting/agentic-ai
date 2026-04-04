---
phase: 8
slug: greenfield-routing
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-03
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + grep (no external test framework — skill files validated via content checks) |
| **Config file** | none — validation via file content assertions |
| **Quick run command** | `bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && echo PASS'` |
| **Full suite command** | `bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && grep -q "skipped.*greenfield\|greenfield.*skipped\|\[-\].*greenfield" skills/project/SKILL.md && echo ALL_PASS'` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && echo PASS'`
- **After every plan wave:** Run full suite command above
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 8-01-01 | 01 | 1 | PROJ-03 | content | `grep -q 'equivalent to' skills/project/references/routing-logic.md && echo PASS` | ✅ | ⬜ pending |
| 8-01-02 | 01 | 1 | PROJ-03 | content | `grep -q 'Gate 0 routing\|Gate 0 resolved' skills/project/references/routing-logic.md && echo PASS` | ✅ | ⬜ pending |
| 8-02-01 | 02 | 1 | PROJ-06 | content | `grep -q '\[-\]' skills/project/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 8-02-02 | 02 | 1 | PROJ-06 | content | `grep -q 'greenfield' skills/project/SKILL.md && echo PASS` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Both target files (`routing-logic.md` and `SKILL.md`) exist on disk. No new files, no framework setup required.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
