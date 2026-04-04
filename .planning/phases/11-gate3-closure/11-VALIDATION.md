---
phase: 11
slug: gate3-closure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — pure text/markdown edits |
| **Config file** | none |
| **Quick run command** | `grep -n "Gate 3" skills/project/SKILL.md` |
| **Full suite command** | `grep -rn "Gate 3\|PROJ-10\|DD-3\|gate3" skills/project/ .planning/REQUIREMENTS.md` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `grep -n "Gate 3" skills/project/SKILL.md`
- **After every plan wave:** Run `grep -rn "Gate 3\|PROJ-10\|DD-3\|gate3" skills/project/ .planning/REQUIREMENTS.md`
- **Before `/gsd:verify-work`:** Full suite must confirm all changes present
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | PROJ-10 | grep | `grep -n "Gate 3 closure" skills/project/SKILL.md` | ✅ | ⬜ pending |
| 11-01-02 | 01 | 1 | MIL-09 | grep | `grep -n "gate3\|Gate 3" skills/project/references/routing-logic.md` | ✅ | ⬜ pending |
| 11-01-03 | 01 | 1 | MIL-09 | grep | `grep -n "DD-3\|gate 3" skills/project/DESIGN.md` | ✅ | ⬜ pending |
| 11-01-04 | 01 | 1 | PROJ-10 | grep | `grep -n "PROJ-10" .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* (No test framework needed — all changes are text/markdown edits verified by grep.)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gate 3 closure offer appears during `/project` when all milestones complete | MIL-09 | Requires running the skill end-to-end | Run `/project` on a project where all milestones are checked complete, verify Gate 3 closure prompt appears |
| Post-closure `/project` invocation doesn't warn about sentinel artifact path | PROJ-10 | Requires running skill after closure | Run `/project` after closing Gate 3, verify no spurious artifact warning for `(closed by /project)` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
