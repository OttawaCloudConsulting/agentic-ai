---
phase: 3
slug: design-gate-2
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual validation (Markdown skill files — no automated test framework) |
| **Config file** | None — skills are validated by invocation |
| **Quick run command** | `bash cicd/lint-markdown.sh` |
| **Full suite command** | `bash cicd/lint-markdown.sh` + manual skill invocation |
| **Estimated runtime** | ~5 seconds (lint only) |

---

## Sampling Rate

- **After every task commit:** Run `bash cicd/lint-markdown.sh`
- **After every plan wave:** Lint + manual review of file structure consistency
- **Before `/gsd:verify-work`:** Full lint + manual invocation of `/design` normal mode and refresh mode
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | DES-01 | manual | Invoke `/design` without Gate 1 approved | N/A | ⬜ pending |
| 03-01-02 | 01 | 1 | DES-02 | manual | Invoke `/design` with prd.md + codebase-assessment.md | N/A | ⬜ pending |
| 03-01-03 | 01 | 1 | DES-03 | manual | Check ARCHITECTURE_AND_DESIGN.md has 6 sections | N/A | ⬜ pending |
| 03-01-04 | 01 | 1 | DES-04 | manual | Check gate-2-review.md exists with checklist items | N/A | ⬜ pending |
| 03-01-05 | 01 | 1 | DES-05 | manual | Observe tradeoff callouts during invocation | N/A | ⬜ pending |
| 03-01-06 | 01 | 1 | DES-06 | manual | Select Revise during review | N/A | ⬜ pending |
| 03-01-07 | 01 | 1 | DES-07 | manual | Check progress.txt after approval | N/A | ⬜ pending |
| 03-01-08 | 01 | 1 | DES-08 | manual | Invoke `/design` refresh mode with deviation data | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. This is a Markdown-only skill — the lint script (`bash cicd/lint-markdown.sh`) is the only automated validation. Manual testing is the primary validation strategy for skill behavior.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gate 1 prerequisite check | DES-01 | Skill behavior requires running the skill | Invoke `/design` without Gate 1 approved in progress.txt; verify it declines |
| Architecture doc generation | DES-03 | Output is a generated markdown document | Invoke `/design` and verify all 6 sections present in output |
| Section-by-section review UX | DES-05, DES-06 | Interactive UX cannot be automated | Observe review flow, test revision by rejecting sections |
| Gate 2 approval recording | DES-07 | Requires full skill invocation | Approve at gate, verify progress.txt updated |
| Refresh mode deviation consolidation | DES-08 | Requires feature plans with deviations | Create test deviation data, invoke refresh mode |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
