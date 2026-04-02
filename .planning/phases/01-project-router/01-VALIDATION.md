---
phase: 1
slug: project-router
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual invocation + markdown linting |
| **Config file** | `.markdownlint.jsonc` (existing) |
| **Quick run command** | `bash cicd/lint-markdown.sh` |
| **Full suite command** | `bash cicd/lint-markdown.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash cicd/lint-markdown.sh`
- **After every plan wave:** Manual invocation of `/project` against test scenarios
- **Before `/gsd:verify-work`:** All 5 success criteria verified by manual invocation
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | PROJ-01 | manual | Invoke `/project` in empty dir, inspect output | N/A | ⬜ pending |
| 01-01-02 | 01 | 1 | PROJ-02 | manual | Invoke `/project` with populated progress.txt | N/A | ⬜ pending |
| 01-01-03 | 01 | 1 | PROJ-03 | manual | Invoke `/project` at various pipeline stages | N/A | ⬜ pending |
| 01-01-04 | 01 | 1 | PROJ-04 | manual | Delete a gate artifact, invoke `/project` | N/A | ⬜ pending |
| 01-01-05 | 01 | 1 | PROJ-05 | manual | Edit milestone-status.txt to diverge, invoke | N/A | ⬜ pending |
| 01-01-06 | 01 | 1 | PROJ-06 | manual | Invoke `/project` with no working-backwards.md | N/A | ⬜ pending |
| 01-01-07 | 01 | 1 | PROJ-07/D-09 | manual | Set Gate WB to Pending, invoke `/project` | N/A | ⬜ pending |
| 01-01-08 | 01 | 1 | PROJ-08 | manual | Say "goals changed" during /project session | N/A | ⬜ pending |
| 01-01-09 | 01 | 1 | PROJ-09 | manual | Say "re-plan" during /project session | N/A | ⬜ pending |
| 01-01-10 | 01 | 1 | PROJ-10 | manual | Inspect file writes during /project invocation | N/A | ⬜ pending |
| 01-01-11 | 01 | 1 | STATE-01 | manual | Inspect bootstrapped progress.txt | N/A | ⬜ pending |
| 01-01-12 | 01 | 1 | STATE-02 | manual | Inspect existing milestone-status.txt parsing | N/A | ⬜ pending |
| 01-01-13 | 01 | 1 | STATE-03 | manual | Verify SKILL.md reads files at start | N/A | ⬜ pending |
| 01-01-14 | 01 | 1 | STATE-04 | manual | Verify SKILL.md/references document the contract | N/A | ⬜ pending |
| 01-ALL | ALL | ALL | ALL | unit | `bash cicd/lint-markdown.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No automated test framework is possible for prompt-based skills — validation is manual invocation against scenarios. Markdown linting (`bash cicd/lint-markdown.sh`) exists and covers syntactic correctness of all new `.md` files.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bootstrap creates valid progress.txt | PROJ-01 | Prompt-based skill — no programmatic test | Invoke `/project` in empty dir, verify progress.txt matches DD-3 format |
| Status report accuracy | PROJ-02 | Requires Claude Code runtime | Invoke `/project` with populated state, verify structured summary output |
| Routing correctness | PROJ-03 | Context-dependent Claude behavior | Invoke at various pipeline stages, verify recommended action |
| Artifact path warnings | PROJ-04 | Requires missing file scenario | Delete gate artifact, invoke, verify inline warning appears |
| Consistency divergence blocking | PROJ-05 | Requires divergent state files | Edit milestone-status.txt, invoke, verify blocking behavior |
| Gate WB offer | PROJ-06 | Context-dependent | Invoke without working-backwards.md, verify explain-and-ask offer |
| Gate WB Pending gentle reminder | PROJ-07/D-09 | Context-dependent | Set Pending state, invoke, verify reminder + full status (not hard-block) |
| Re-planning keyword detection | PROJ-08/09 | NLP-dependent | Use intent phrases, verify correct routing |
| Read-only after bootstrap | PROJ-10 | Requires file system monitoring | Invoke on existing project, verify no writes |
| State file format compliance | STATE-01/02 | Format inspection | Verify checkbox notation in bootstrapped files |
| Fresh state reads | STATE-03 | Architecture pattern | Review SKILL.md for file reads at step 1 |
| Write ordering documented | STATE-04 | Documentation check | Verify references document milestone-before-progress ordering |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
