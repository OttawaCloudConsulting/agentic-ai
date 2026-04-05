---
phase: 7
slug: spike-docs
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-03
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification (markdown skill files — no compiled code) |
| **Config file** | none |
| **Quick run command** | `grep -l "disable-model-invocation: true" skills/project/*/SKILL.md skills/project/SKILL.md` |
| **Full suite command** | `bash -c 'echo "=== SKILL.md frontmatter ===" && grep -l "disable-model-invocation: true" skills/project/*/SKILL.md skills/project/SKILL.md && echo "=== Detail docs ===" && ls docs/skills/{project,define,design,milestone,plan,build,spike}.md && echo "=== SKILLS.md rows ===" && grep -c "^|" docs/SKILLS.md && echo "=== Spike files ===" && test -f skills/project/spike/references/research-agent.md && echo "research-agent.md exists" && test -f skills/project/spike/references/spike-format.md && echo "spike-format.md exists" && echo "=== All checks passed ==="'` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (verify frontmatter flag)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | SPIKE-03 | file-check | `test -f skills/project/spike/references/research-agent.md` | ✅ | ⬜ pending |
| 07-01-02 | 01 | 1 | SPIKE-03 | file-check | `test -f skills/project/spike/references/spike-format.md` | ✅ | ⬜ pending |
| 07-01-03 | 01 | 1 | SPIKE-04,06 | grep | `grep -q "## Spikes" skills/project/spike/references/progress-format.md` | ✅ | ⬜ pending |
| 07-02-01 | 02 | 1 | SPIKE-01,02 | grep | `grep -q "disable-model-invocation: true" skills/project/spike/SKILL.md` | ✅ | ⬜ pending |
| 07-02-02 | 02 | 1 | SPIKE-05 | grep | `grep -q "follow-up" skills/project/spike/SKILL.md` | ✅ | ⬜ pending |
| 07-03-01 | 03 | 2 | DOCS-01 | file-check | `test -f docs/skills/spike.md` | ✅ | ⬜ pending |
| 07-03-02 | 03 | 2 | DOCS-02 | grep | `grep -q "spike" docs/SKILLS.md` | ✅ | ⬜ pending |
| 07-03-03 | 03 | 2 | DOCS-03 | grep | `grep -c "disable-model-invocation: true" skills/project/*/SKILL.md skills/project/SKILL.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `skills/project/spike/` directory structure created
- [x] No framework install needed — markdown-only skill files

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Research + red-team sequential flow | SPIKE-01, SPIKE-02 | Agent orchestration behavior | Run `/spike` on a test topic, verify research completes before red-team |
| Follow-up appends without overwriting | SPIKE-05 | Requires existing spike artifact | Run `/spike` follow-up on existing spike, verify original findings preserved |
| Red-team section distinct from findings | SPIKE-01 SC1 | Content quality check | Read produced spike artifact, verify two separate sections |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 2s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-04-03
