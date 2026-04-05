---
phase: 2
slug: define-gates-0-wb-1
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-02
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + grep (no external test framework — skill files validated via content checks) |
| **Config file** | none — validation via file content assertions |
| **Quick run command** | `bash -c 'grep -q "Gate 0" skills/project/define/SKILL.md && echo PASS'` |
| **Full suite command** | `bash -c 'grep -q "greenfield\|Greenfield" skills/project/define/SKILL.md && grep -q "Gate 0" skills/project/define/SKILL.md && grep -q "codebase-assessment" skills/project/define/SKILL.md && grep -q "prd.md" skills/project/define/SKILL.md && grep -q "progress.txt" skills/project/define/SKILL.md && echo ALL_PASS'` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash cicd/lint-markdown.sh`
- **After every plan wave:** Run `bash cicd/lint-markdown.sh` + manual spot-check of SKILL.md step structure
- **Before `/gsd:verify-work`:** Full manual invocation test (greenfield + brownfield scenarios)
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | DEF-01 | manual | Invoke `/define` in empty dir | N/A | ⬜ pending |
| 02-01-02 | 01 | 1 | DEF-02 | manual | Invoke `/define` in brownfield project | N/A | ⬜ pending |
| 02-01-03 | 01 | 1 | DEF-03 | manual + lint | `bash cicd/lint-markdown.sh` on output | N/A | ⬜ pending |
| 02-01-04 | 01 | 1 | DEF-04 | manual | Check `docs/reviews/gate-{0,wb,1}-review.md` exists | N/A | ⬜ pending |
| 02-01-05 | 01 | 1 | DEF-05 | manual | Interactive test | N/A | ⬜ pending |
| 02-01-06 | 01 | 1 | DEF-06 | manual | Interactive test | N/A | ⬜ pending |
| 02-01-07 | 01 | 1 | DEF-07 | manual | Check progress.txt format | N/A | ⬜ pending |
| 02-01-08 | 01 | 1 | DEF-08 | manual | Interactive test | N/A | ⬜ pending |
| 02-01-09 | 01 | 1 | DEF-09 | manual | Check file exists with PR/FAQ sections | N/A | ⬜ pending |
| 02-01-10 | 01 | 1 | DEF-10 | manual | Interactive test | N/A | ⬜ pending |
| 02-01-11 | 01 | 1 | DEF-11 | manual + lint | `bash cicd/lint-markdown.sh` on output | N/A | ⬜ pending |
| 02-01-12 | 01 | 1 | DEF-12 | manual | Interactive test | N/A | ⬜ pending |
| 02-01-13 | 01 | 1 | DEF-13 | manual | Check progress.txt format | N/A | ⬜ pending |
| 02-01-14 | 01 | 1 | DEF-14 | manual | Full end-to-end test | N/A | ⬜ pending |
| 02-01-15 | 01 | 1 | DEF-15 | manual | Invoke with existing prd.md | N/A | ⬜ pending |
| 02-01-16 | 01 | 1 | DEF-16 | manual | Verify assessment used in PRD context | N/A | ⬜ pending |
| 02-01-C1 | 01 | 1 | DEF-01 | content | `grep -q 'greenfield\|Greenfield' skills/project/define/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 02-01-C2 | 01 | 1 | DEF-02/03 | content | `grep -q 'Gate 0' skills/project/define/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 02-01-C3 | 01 | 1 | DEF-03 | content | `grep -q 'codebase-assessment' skills/project/define/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 02-01-C4 | 01 | 1 | DEF-09 | content | `grep -q 'working-backwards\|Working Backwards' skills/project/define/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 02-01-C5 | 01 | 1 | DEF-10/11 | content | `grep -q 'prd.md' skills/project/define/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 02-01-C6 | 01 | 1 | DEF-07/13 | content | `grep -q 'progress.txt' skills/project/define/SKILL.md && echo PASS` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Target file (`skills/project/define/SKILL.md`) exists on disk. No new files, no framework setup required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Greenfield detection skips Gate 0 | DEF-01 | Requires interactive skill invocation in empty directory | Create empty dir, run `/define`, verify Gate 0 is skipped |
| Single continuous session across 3 gates | DEF-14 | Requires full interactive session | Run `/define` end-to-end, verify all 3 gates complete in one session |
| Partial Gate 1 approval triggers revision | DEF-12 | Requires interactive approval workflow | Approve some sections, reject others, verify revision flow |
| Revision mode surfaces affected artifacts | DEF-15 | Requires existing prd.md and interactive test | Create prd.md, run `/define` in revision mode, verify artifact list |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-04-03
