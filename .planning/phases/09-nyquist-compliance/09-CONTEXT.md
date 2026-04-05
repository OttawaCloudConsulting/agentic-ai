# Phase 9: Nyquist Compliance - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Complete Wave 0 test strategy for all 7 phases (1–7). Each phase VALIDATION.md must be updated with:
- Runnable grep/content bash checks covering core observable behaviors (upgraded from manual-only for phases 1–5)
- Corrected lint script path (`scripts/lint-markdown.sh`, not `cicd/lint-markdown.sh`)
- `wave_0_complete: true` and `nyquist_compliant: true` in frontmatter

Agent actually executes the bash commands to confirm they pass before marking each phase compliant.

Phase 8 VALIDATION.md is out of scope (roadmap says "all 7 phases" = phases 1–7 only).

</domain>

<decisions>
## Implementation Decisions

### Test Approach
- **D-01:** Upgrade phases 1–5 VALIDATION.md files to include grep/content bash checks in addition to (not replacing) the existing manual-only table rows. Pattern follows phases 6 and 8: `grep -q 'key-term' skills/project/<skill>/SKILL.md && echo PASS` style commands.
- **D-02:** Phases 6–7 already have content checks — review and verify they still pass; no redesign unless they're broken.

### Lint Script Path
- **D-03:** Fix `bash cicd/lint-markdown.sh` → `bash scripts/lint-markdown.sh` in all 7 phase VALIDATION.md files. This correction is required for Wave 0 lint commands to actually run.

### Verification Standard
- **D-04:** gsd-nyquist-auditor executes the bash commands for each phase and confirms exit code 0 before marking that phase `wave_0_complete: true` and `nyquist_compliant: true`. A phase is not marked compliant based on declaration alone.

### Sign-Off Items
- **D-05:** Update Validation Sign-Off checklist in each VALIDATION.md: check all boxes (including `nyquist_compliant: true`) and set **Approval:** to the completion date.

### Claude's Discretion
- Specific grep patterns used per phase (based on actual file content)
- Whether to add a new "Automated Checks" table section or annotate existing Per-Task Verification Map rows
- Exact wording of any updated Wave 0 Requirements prose

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing VALIDATION.md files (all 7 to be updated)
- `.planning/phases/01-project-router/01-VALIDATION.md` — current manual-only strategy for phases 1
- `.planning/phases/02-define-gates-0-wb-1/02-VALIDATION.md` — current manual-only strategy for phase 2
- `.planning/phases/03-design-gate-2/03-VALIDATION.md` — current manual-only strategy for phase 3
- `.planning/phases/04-milestone-gate-3/04-VALIDATION.md` — current manual-only strategy for phase 4
- `.planning/phases/05-plan-gate-4/05-VALIDATION.md` — current manual-only strategy for phase 5
- `.planning/phases/06-build/06-VALIDATION.md` — existing content checks (verify still pass)
- `.planning/phases/07-spike-docs/07-VALIDATION.md` — check current state

### Reference pattern (best example of target state)
- `.planning/phases/08-greenfield-routing/08-VALIDATION.md` — gold standard: grep/content checks, working bash commands, all tasks show ✅ File Exists

### Skill files to grep against
- `skills/project/SKILL.md` — /project router
- `skills/project/define/SKILL.md` — /define skill
- `skills/project/design/SKILL.md` — /design skill
- `skills/project/milestone/SKILL.md` — /milestone skill
- `skills/project/plan/SKILL.md` — /plan skill
- `skills/project/build/SKILL.md` — /build skill
- `skills/project/spike/SKILL.md` — /spike skill
- `skills/project/references/routing-logic.md` — /project routing table
- `skills/project/references/` — shared reference files

### Lint script (corrected path)
- `scripts/lint-markdown.sh` — actual location (VALIDATION.md files incorrectly say `cicd/lint-markdown.sh`)

### Phase 9 roadmap goal
- `.planning/ROADMAP.md` §Phase 9 — success criteria define the compliance bar

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 8 VALIDATION.md pattern: minimal bash checks using `grep -q 'term' file && echo PASS` — copy this pattern for phases 1–5
- `scripts/lint-markdown.sh` exists, takes `-r` flag for recursive — usable as Wave 0 automated check across all phases

### Established Patterns
- Wave 0 checks are content assertions (grep), not behavioral tests (which require interactive Claude sessions)
- "File Exists" column in Per-Task Verification Map uses ✅ when file is on disk, ❌ W0 when it's a Wave 0 dependency
- Manual-only rows stay in the table — content checks are additive, not replacements

### Integration Points
- 7 VALIDATION.md files updated in place
- No new files created — only existing VALIDATION.md files modified
- `scripts/lint-markdown.sh` is the single shared test runner (already exists, no changes needed)

</code_context>

<specifics>
## Specific Ideas

- Phase 8 VALIDATION.md is the gold standard for target state — agents should match that pattern
- Content checks must be grep-based (no external test runner) — consistent with skills being markdown-only

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 09-nyquist-compliance*
*Context gathered: 2026-04-03*
