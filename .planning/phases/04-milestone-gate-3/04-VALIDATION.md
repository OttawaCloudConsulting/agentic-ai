---
phase: 4
slug: milestone-gate-3
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-02
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification (Markdown skill, no application code) |
| **Config file** | none |
| **Quick run command** | `bash -c 'grep -q "Gate 3" skills/project/milestone/SKILL.md && echo PASS'` |
| **Full suite command** | `bash -c 'grep -q "Gate 2" skills/project/milestone/SKILL.md && grep -q "Gate 3" skills/project/milestone/SKILL.md && grep -q "milestone-status" skills/project/milestone/SKILL.md && grep -q "In progress" skills/project/milestone/SKILL.md && grep -q "revision\|Revision" skills/project/milestone/SKILL.md && echo ALL_PASS'` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash cicd/lint-markdown.sh`
- **After every plan wave:** Run `bash cicd/lint-markdown.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | MIL-01 | manual-only | Invoke /milestone without Gate 2 approved | N/A | ⬜ pending |
| 04-01-02 | 01 | 1 | MIL-02 | manual-only | Invoke /milestone with all inputs present | N/A | ⬜ pending |
| 04-01-03 | 01 | 1 | MIL-03 | manual-only | Invoke /milestone with existing milestones/ dirs | N/A | ⬜ pending |
| 04-01-04 | 01 | 1 | MIL-04 | manual-only | Check README.md sections after invocation | N/A | ⬜ pending |
| 04-01-05 | 01 | 1 | MIL-05 | manual-only | Check milestone-status.txt after invocation | N/A | ⬜ pending |
| 04-01-06 | 01 | 1 | MIL-06 | manual-only | Check reviews/gate-3-review.md after invocation | N/A | ⬜ pending |
| 04-01-07 | 01 | 1 | MIL-07 | manual-only | Check progress.txt after invocation | N/A | ⬜ pending |
| 04-01-08 | 01 | 1 | MIL-08 | manual-only | Observe produce-then-review cycle | N/A | ⬜ pending |
| 04-01-09 | 01 | 1 | MIL-09 | manual-only | Check progress.txt Gate 3 line after invocation | N/A | ⬜ pending |
| 04-01-10 | 01 | 1 | MIL-10 | manual-only | Invoke /milestone on existing milestone | N/A | ⬜ pending |
| 04-01-11 | 01 | 1 | MIL-11 | manual-only | Invoke revision mode, observe multiSelect | N/A | ⬜ pending |
| 04-01-12 | 01 | 1 | MIL-12 | manual-only | Complete a feature, revise milestone, verify preserved | N/A | ⬜ pending |
| 04-01-13 | 01 | 1 | MIL-13 | manual-only | Check both files after revision | N/A | ⬜ pending |
| 04-01-C1 | 01 | 1 | MIL-01 | content | `grep -q 'Gate 2' skills/project/milestone/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 04-01-C2 | 01 | 1 | MIL-09 | content | `grep -q 'Gate 3' skills/project/milestone/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 04-01-C3 | 01 | 1 | MIL-05/08/11 | content | `grep -q 'milestone-status' skills/project/milestone/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 04-01-C4 | 01 | 1 | MIL-09 | content | `grep -q 'In progress' skills/project/milestone/SKILL.md && echo PASS` | ✅ | ⬜ pending |
| 04-01-C5 | 01 | 1 | MIL-10/11/12 | content | `grep -q 'revision\|Revision' skills/project/milestone/SKILL.md && echo PASS` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Target file (`skills/project/milestone/SKILL.md`) exists on disk. No new files, no framework setup required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gate 2 prerequisite check | MIL-01 | Markdown skill — no runtime to test programmatically | Invoke /milestone without Gate 2 approved in progress.txt |
| Read prd.md, architecture, progress | MIL-02 | Skill reads project files at runtime | Invoke with all inputs present, verify skill references them |
| Auto-increment sequence number | MIL-03 | Requires Claude session to test | Create milestones, verify NN auto-increments |
| Milestone README sections | MIL-04 | Output is Markdown document | Check README.md has Goal, Features, Dependencies, Ordering, Sizing, DoD |
| milestone-status.txt generation | MIL-05 | Output is status file | Check milestone-status.txt has pending features |
| gate-3-review.md checklist | MIL-06 | Output is review checklist | Check reviews/gate-3-review.md exists with checklist |
| progress.txt milestone summary | MIL-07 | State file update | Check progress.txt has milestone summary line |
| Produce-then-review cycle | MIL-08 | Interactive flow | Observe checkpoint presentation |
| Gate 3 stays in-progress | MIL-09 | State management | Check Gate 3 shows `[~] In progress` after invocation |
| Revision mode loads artifacts | MIL-10 | Interactive flow | Invoke /milestone on existing milestone |
| Revision mode feature checklist | MIL-11 | Interactive multiSelect | Observe multiSelect presentation |
| Preserves completed features | MIL-12 | State management | Complete a feature, revise, verify status preserved |
| Revision updates progress/prd | MIL-13 | State file updates | Check both files after revision mode |

**Justification:** This project's "code" is Markdown prompt engineering — there is no application runtime to test programmatically. Validation is done by invoking the skill in a Claude Code session and observing behavior.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-04-03
