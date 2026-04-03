---
phase: 6
slug: build
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + grep verification (no external test framework — skill files validated via structure/content checks) |
| **Config file** | none — validation via file content assertions |
| **Quick run command** | `bash -c 'test -f agents/skills/build/SKILL.md && echo PASS'` |
| **Full suite command** | `bash -c 'for f in agents/skills/build/SKILL.md agents/skills/build/references/*.md; do test -f "$f" && echo "PASS: $f" || echo "FAIL: $f"; done'` |
| **Estimated runtime** | ~1 second |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | BUILD-01 | content | `grep -q 'gate-4' agents/skills/build/references/*.md` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | BUILD-05 | content | `grep -q 'codebase-assessment' agents/skills/build/references/*.md` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | BUILD-06 | content | `grep -q 'sub-feature' agents/skills/build/references/*.md` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 2 | BUILD-02 | content | `grep -q 'SKILL.md' agents/skills/build/SKILL.md` | ❌ W0 | ⬜ pending |
| 06-02-02 | 02 | 2 | BUILD-03 | content | `grep -q 'gate.*4.*approved' agents/skills/build/SKILL.md` | ❌ W0 | ⬜ pending |
| 06-02-03 | 02 | 2 | BUILD-04 | content | `grep -q 'milestone-status' agents/skills/build/SKILL.md` | ❌ W0 | ⬜ pending |
| 06-02-04 | 02 | 2 | BUILD-07 | content | `grep -q 'deviation' agents/skills/build/SKILL.md` | ❌ W0 | ⬜ pending |
| 06-02-05 | 02 | 2 | BUILD-08 | content | `grep -q 'test.*exit.*0\|test.*command' agents/skills/build/SKILL.md` | ❌ W0 | ⬜ pending |
| 06-02-06 | 02 | 2 | BUILD-09 | content | `grep -q 'resume\|continuity' agents/skills/build/SKILL.md` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 2 | BUILD-01 | content | `grep -q 'build' docs/catalog.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `agents/skills/build/` — directory structure created
- [ ] Reference file stubs for gate-4-plan, feature-plan-template, progress-format

*Existing infrastructure (agents/skills/ pattern) covers directory conventions.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| /build declines without Gate 4 plan | BUILD-03 | Requires interactive Claude session | Invoke /build with no approved plan, verify refusal message |
| Sub-feature leaves committable state | BUILD-06 | Requires git state inspection during execution | Run /build, complete one sub-feature, verify `git status` is clean |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 1s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
