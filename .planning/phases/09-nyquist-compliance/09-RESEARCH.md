# Phase 9: Nyquist Compliance - Research

**Researched:** 2026-04-03
**Domain:** Validation strategy upgrades — grep/content bash checks for markdown-only skills
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Upgrade phases 1–5 VALIDATION.md files to include grep/content bash checks in addition to (not replacing) the existing manual-only table rows. Pattern follows phases 6 and 8: `grep -q 'key-term' skills/project/<skill>/SKILL.md && echo PASS` style commands.
- **D-02:** Phases 6–7 already have content checks — review and verify they still pass; no redesign unless they're broken.
- **D-03:** Fix `bash cicd/lint-markdown.sh` → `bash scripts/lint-markdown.sh` in all 7 phase VALIDATION.md files. This correction is required for Wave 0 lint commands to actually run.
- **D-04:** gsd-nyquist-auditor executes the bash commands for each phase and confirms exit code 0 before marking that phase `wave_0_complete: true` and `nyquist_compliant: true`. A phase is not marked compliant based on declaration alone.
- **D-05:** Update Validation Sign-Off checklist in each VALIDATION.md: check all boxes (including `nyquist_compliant: true`) and set **Approval:** to the completion date.

### Claude's Discretion

- Specific grep patterns used per phase (based on actual file content)
- Whether to add a new "Automated Checks" table section or annotate existing Per-Task Verification Map rows
- Exact wording of any updated Wave 0 Requirements prose

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 9 is a documentation-only tech debt phase. No code is written. The deliverable is 7 updated VALIDATION.md files — one per phase (phases 1–7) — where each file gains verified bash grep commands, a corrected lint script path, and frontmatter flags set to `true`.

The core work pattern is: read a SKILL.md or reference file, identify 2–4 key terms that prove the requirement's content is present, write `grep -q 'term' path && echo PASS`, execute the command to verify exit 0, then update the VALIDATION.md. Phases 1–5 currently have no automated checks — only a manual-only table. Phases 6–7 already have content checks, but several of those checks reference wrong file names (spike-research.md vs research-agent.md) and wrong grep terms (gate-4 vs Gate 4) that cause failures. All 7 phases also have the wrong lint script path (`cicd/` is the actual location; CONTEXT.md D-03 says to change to `scripts/` — but `scripts/lint-markdown.sh` does not exist; the file is at `cicd/lint-markdown.sh`). This is a critical discrepancy that must be resolved before planning.

**Primary recommendation:** Fix the lint path discrepancy (cicd/ is correct; scripts/ is a fiction), upgrade phases 1–5 with verified grep checks, and fix the broken checks in phases 6–7.

---

## Critical Finding: Lint Script Path Discrepancy

**CONTEXT.md D-03 states:** Fix `bash cicd/lint-markdown.sh` → `bash scripts/lint-markdown.sh` in all 7 phase VALIDATION.md files.

**Reality (verified):**
- `cicd/lint-markdown.sh` — EXISTS at this path (confirmed)
- `scripts/lint-markdown.sh` — DOES NOT EXIST (`scripts/` directory contains only `benchmark/`)
- The script's own usage comment says `bash scripts/lint-markdown.sh` (the script was written with an incorrect self-referential comment)

**Implication:** D-03 is based on a misread — the script's internal usage comment says `scripts/`, but the file lives at `cicd/`. Changing the VALIDATION.md files from `bash cicd/lint-markdown.sh` to `bash scripts/lint-markdown.sh` would BREAK the lint check (command would fail with "file not found").

**Recommended resolution for planner:** The correct path is `bash cicd/lint-markdown.sh`. The planner should note this discrepancy and either: (a) keep `cicd/lint-markdown.sh` as-is (the working path), or (b) ask the user to clarify whether a `scripts/` symlink or rename is intended before implementing D-03. Do not blindly apply D-03 as written — it will produce broken commands.

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | system | Execute content checks | Already used in phases 6, 7, 8; no external dependencies |
| grep | system | Assert content presence in files | Fast, zero-dependency, exit-code-based pass/fail |
| test -f | system | Assert file existence | Used in phases 7 and 8; consistent with established pattern |
| markdownlint-cli2 | 0.21.0 (via npx) | Markdown linting | Invoked by `cicd/lint-markdown.sh`; already installed |

### No New Dependencies

This phase installs nothing. All tools are available on the system. Verified:

```
markdownlint-cli2 v0.21.0 (markdownlint v0.40.0) — confirmed working
cicd/lint-markdown.sh — confirmed exists, runs in ~5 seconds
```

---

## Architecture Patterns

### Target State Pattern (Gold Standard: Phase 8 VALIDATION.md)

The Phase 8 VALIDATION.md is the reference implementation. Key properties:

1. Each Per-Task Verification Map row has `content` in the Test Type column and a runnable bash command
2. File Exists column shows `✅` (not `❌ W0`) because files already exist on disk
3. Wave 0 Requirements section says "Existing infrastructure covers all phase requirements. Both target files exist on disk. No new files, no framework setup required."
4. Manual-Only Verifications section says "All phase behaviors have automated verification."
5. Frontmatter: `nyquist_compliant: true`, `wave_0_complete: true`
6. Sign-Off: all boxes checked, Approval set to date

### Grep Check Pattern

```bash
grep -q 'key-term' skills/project/<skill>/SKILL.md && echo PASS
```

- `-q` flag suppresses output; exit code 0 = term found, exit code 1 = not found
- `&& echo PASS` makes success visible in terminal output
- Single-term checks are preferred over regex (simpler, less fragile)
- For OR patterns: `grep -q 'term1\|term2' file && echo PASS`

### File Existence Check Pattern

```bash
test -f skills/project/<skill>/references/filename.md && echo PASS
```

### Composite Check Pattern (for quick/full suite commands)

```bash
bash -c 'grep -q "term1" file1 && grep -q "term2" file2 && echo ALL_PASS'
```

### Anti-Patterns to Avoid

- **Wrong grep term:** `gate-4` (hyphenated) fails; actual content uses `Gate 4` (space). Verify terms against actual file content before writing.
- **Wrong file path:** `spike-research.md` does not exist; actual file is `research-agent.md`. Always `ls` the directory before writing file-check commands.
- **Wrong lint path:** `scripts/lint-markdown.sh` does not exist; actual path is `cicd/lint-markdown.sh`.
- **Replacing manual rows:** D-01 says content checks are ADDITIVE — manual rows stay in the table.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Content verification | Custom test runner | grep + bash | Already established; zero overhead |
| Markdown linting | Custom linter | `cicd/lint-markdown.sh` | Already exists, works, uses markdownlint-cli2 |

---

## Per-Phase Gap Analysis

### Phase 1 (project-router) — Current State: Manual-only, wrong lint path

**Files to grep against:** `skills/project/SKILL.md`, `skills/project/references/routing-logic.md`

**Verified passing grep patterns:**

| Requirement | Pattern | File | Verifies |
|-------------|---------|------|---------|
| PROJ-01 (bootstrap) | `grep -q 'bootstrap\|Bootstrap'` | `skills/project/SKILL.md` | Bootstrap step present |
| PROJ-02/03 (routing) | `grep -q 'routing-logic'` | `skills/project/SKILL.md` | Routing table referenced |
| PROJ-10 (read-only) | `grep -q 'Read-only after bootstrap'` | `skills/project/SKILL.md` | Read-only rule present |
| PROJ-06 (Gate WB) | `grep -q 'working-backwards'` | `skills/project/SKILL.md` | WB offer present |
| PROJ-05 (consistency) | `grep -q 'consistency'` | `skills/project/SKILL.md` | Consistency check present |
| STATE-01/02 | `grep -q 'progress.txt'` | `skills/project/SKILL.md` | State file referenced |
| PROJ-03 (routing table) | `grep -q 'equivalent to'` | `skills/project/references/routing-logic.md` | Already used by Phase 8 |
| ALL (lint) | `bash cicd/lint-markdown.sh` | all .md files | Markdown syntax |

**Lint command fix required:** `cicd/lint-markdown.sh` → keep as `cicd/lint-markdown.sh` (already correct per D-03 note above)

### Phase 2 (define) — Current State: Manual-only, wrong lint path

**Files to grep against:** `skills/project/define/SKILL.md`

**Verified passing grep patterns:**

| Requirement | Pattern | File | Verifies |
|-------------|---------|------|---------|
| DEF-01 (greenfield) | `grep -q 'greenfield\|Greenfield'` | `skills/project/define/SKILL.md` | Greenfield skip present |
| DEF-02/03 (Gate 0) | `grep -q 'Gate 0'` | `skills/project/define/SKILL.md` | Gate 0 present |
| DEF-03 (codebase-assessment) | `grep -q 'codebase-assessment'` | `skills/project/define/SKILL.md` | Assessment doc referenced |
| DEF-09 (working backwards) | `grep -q 'working-backwards\|Working Backwards'` | `skills/project/define/SKILL.md` | WB document present |
| DEF-10/11 (Gate 1/PRD) | `grep -q 'prd.md'` | `skills/project/define/SKILL.md` | PRD artifact referenced |
| DEF-07/13 (progress) | `grep -q 'progress.txt'` | `skills/project/define/SKILL.md` | State file writes present |

### Phase 3 (design) — Current State: Manual-only, wrong lint path

**Files to grep against:** `skills/project/design/SKILL.md`

**Verified passing grep patterns:**

| Requirement | Pattern | File | Verifies |
|-------------|---------|------|---------|
| DES-01 (Gate 1 prereq) | `grep -q 'Gate 1'` | `skills/project/design/SKILL.md` | Gate 1 check present |
| DES-03/07 (Gate 2) | `grep -q 'Gate 2'` | `skills/project/design/SKILL.md` | Gate 2 workflow present |
| DES-03 (arch doc) | `grep -q 'ARCHITECTURE_AND_DESIGN'` | `skills/project/design/SKILL.md` | Output artifact named |
| DES-08 (refresh mode) | `grep -q 'refresh\|Refresh'` | `skills/project/design/SKILL.md` | Refresh mode present |
| DES-08 (deviations) | `grep -q 'deviation'` | `skills/project/design/SKILL.md` | Deviation handling present |

### Phase 4 (milestone) — Current State: Manual-only, wrong lint path

**Files to grep against:** `skills/project/milestone/SKILL.md`

**Verified passing grep patterns:**

| Requirement | Pattern | File | Verifies |
|-------------|---------|------|---------|
| MIL-01 (Gate 2 prereq) | `grep -q 'Gate 2'` | `skills/project/milestone/SKILL.md` | Gate 2 check present |
| MIL-09 (Gate 3 stays open) | `grep -q 'Gate 3'` | `skills/project/milestone/SKILL.md` | Gate 3 handling present |
| MIL-05/08/11 (status file) | `grep -q 'milestone-status'` | `skills/project/milestone/SKILL.md` | Status file referenced |
| MIL-09 (in-progress) | `grep -q 'In progress'` | `skills/project/milestone/SKILL.md` | [~] In progress pattern present |
| MIL-10/11/12 (revision) | `grep -q 'revision\|Revision'` | `skills/project/milestone/SKILL.md` | Revision mode present |

### Phase 5 (plan) — Current State: Manual-only, wrong lint path

**Files to grep against:** `skills/project/plan/SKILL.md`

**Verified passing grep patterns:**

| Requirement | Pattern | File | Verifies |
|-------------|---------|------|---------|
| PLAN-02/09 (Gate 4) | `grep -q 'Gate 4'` | `skills/project/plan/SKILL.md` | Gate 4 workflow present |
| PLAN-06/09 (status file) | `grep -q 'milestone-status'` | `skills/project/plan/SKILL.md` | Status file write referenced |
| PLAN-04 (sub-features) | `grep -q 'sub-feature'` | `skills/project/plan/SKILL.md` | Sub-feature sizing present |
| PLAN-09 (approval marker) | `grep -q 'planned.*awaiting\|awaiting build'` | `skills/project/plan/SKILL.md` | Approval status marker present |
| PLAN-03 (gate reference) | `grep -q 'gate-4-plan\|gate-4'` | `skills/project/plan/SKILL.md` | Gate 4 spec referenced |

### Phase 6 (build) — Current State: Has checks, 2 checks fail

**Failing checks and corrections:**

| Current (failing) | Corrected | Why |
|-------------------|-----------|-----|
| `grep -q 'gate-4' skills/project/build/references/*.md` | `grep -q 'Gate 4' skills/project/build/references/*.md` | Files use "Gate 4" with space, not hyphen |
| `grep -q 'SKILL.md' skills/project/build/SKILL.md` | `grep -q 'disable-model-invocation' skills/project/build/SKILL.md` | "SKILL.md" doesn't appear as a string in the file; `disable-model-invocation` does |

**Verified passing checks (leave unchanged):**

All other Phase 6 checks currently pass:
- `grep -q 'codebase-assessment' skills/project/build/references/*.md` — PASS
- `grep -q 'sub-feature' skills/project/build/references/*.md` — PASS
- `grep -q 'gate.*4.*approved' skills/project/build/SKILL.md` — PASS (note: keep this pattern; `Gate.*4.*approved` also passes)
- `grep -q 'milestone-status' skills/project/build/SKILL.md` — PASS
- `grep -q 'deviation' skills/project/build/SKILL.md` — PASS
- `grep -q 'test.*exit.*0\|test.*command' skills/project/build/SKILL.md` — PASS
- `grep -q 'resume\|continuity' skills/project/build/SKILL.md` — PASS
- `grep -q 'build' docs/SKILLS.md` — PASS

### Phase 7 (spike-docs) — Current State: Has checks, 2 checks fail

**Failing checks and corrections:**

| Current (failing) | Corrected | Why |
|-------------------|-----------|-----|
| `test -f skills/project/spike/references/spike-research.md` | `test -f skills/project/spike/references/research-agent.md` | File was named `research-agent.md`, not `spike-research.md` |
| `test -f skills/project/spike/assets/spike-template.md` | `test -f skills/project/spike/references/spike-format.md` | No `assets/` directory exists; template is at `references/spike-format.md` |

**Verified passing checks (leave unchanged):**

- `grep -q "## Spikes" skills/project/spike/references/progress-format.md` — PASS
- `grep -q "disable-model-invocation: true" skills/project/spike/SKILL.md` — PASS
- `grep -q "follow-up" skills/project/spike/SKILL.md` — PASS
- `test -f docs/skills/spike.md` — PASS
- `grep -q "spike" docs/SKILLS.md` — PASS
- `grep -c "disable-model-invocation: true" skills/project/*/SKILL.md skills/project/SKILL.md` — PASS

---

## Common Pitfalls

### Pitfall 1: Wrong Grep Term Case/Format
**What goes wrong:** `grep -q 'gate-4'` returns exit 1 even though the content is present as `Gate 4`.
**Why it happens:** Grep is case-sensitive by default. The skill files use title case ("Gate 4") not kebab-case ("gate-4").
**How to avoid:** Always run the grep command against the actual file before writing it into VALIDATION.md.
**Warning signs:** A grep returns FAIL but you can see the content when reading the file.

### Pitfall 2: Wrong File Path Reference
**What goes wrong:** `test -f skills/project/spike/references/spike-research.md` fails because the file is actually `research-agent.md`.
**Why it happens:** The VALIDATION.md was written before implementation; the file name changed during implementation.
**How to avoid:** Run `ls` on the target directory before writing file-check commands.
**Warning signs:** `test -f` returns exit 1; `ls` shows a different filename.

### Pitfall 3: Lint Script Path (D-03 Discrepancy)
**What goes wrong:** Blindly applying D-03 changes `cicd/lint-markdown.sh` → `scripts/lint-markdown.sh`, which breaks the lint check because `scripts/lint-markdown.sh` does not exist.
**Why it happens:** The CONTEXT.md was written based on the script's internal usage comment (`scripts/`), not the actual file location (`cicd/`).
**How to avoid:** Verify the path before writing. Confirmed: `cicd/lint-markdown.sh` exists; `scripts/lint-markdown.sh` does not.
**Warning signs:** `bash scripts/lint-markdown.sh` returns "No such file or directory."

### Pitfall 4: Replacing Manual Rows Instead of Adding Content Checks
**What goes wrong:** Manual rows are removed from Per-Task Verification Map and replaced with content checks.
**Why it happens:** Misreading D-01 as "upgrade to" rather than "add to."
**How to avoid:** D-01 is explicit: content checks are additive. Keep all existing manual rows. Add a new "content" row for each requirement that can be content-checked.

### Pitfall 5: Marking Compliant Without Executing
**What goes wrong:** Setting `wave_0_complete: true` and `nyquist_compliant: true` without running the commands.
**Why it happens:** Shortcut — the checks "look right" without being run.
**How to avoid:** D-04 is absolute: execute every bash command, observe exit code 0, then mark compliant.

---

## Code Examples

### Working Phase 8 Pattern (copy this structure)

```bash
# Quick run command
bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && echo PASS'

# Full suite command
bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && grep -q "skipped.*greenfield\|greenfield.*skipped\|\[-\].*greenfield" skills/project/SKILL.md && echo ALL_PASS'
```

Per-Task Verification Map row format for content check:
```
| 01-01-01 | 01 | 1 | PROJ-01 | content | `grep -q 'bootstrap' skills/project/SKILL.md && echo PASS` | ✅ | ⬜ pending |
```

### Frontmatter Upgrade (before → after)

Before:
```yaml
nyquist_compliant: false
wave_0_complete: false
```

After:
```yaml
nyquist_compliant: true
wave_0_complete: true
```

### Sign-Off Block (after completion)

```markdown
## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-04-03
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | All content checks | ✓ | system | — |
| grep | All content checks | ✓ | system | — |
| markdownlint-cli2 | `cicd/lint-markdown.sh` | ✓ | 0.21.0 (via npx) | — |
| `cicd/lint-markdown.sh` | Lint check in all phases | ✓ | — | — |
| `scripts/lint-markdown.sh` | D-03 (as written) | ✗ | — | Use `cicd/lint-markdown.sh` |

**Missing dependencies with no fallback:** None that block execution.

**Missing dependencies with fallback:** `scripts/lint-markdown.sh` is missing — fallback is `cicd/lint-markdown.sh` (the working path).

---

## Validation Architecture

> nyquist_validation is `true` in config.json — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash + grep (no external test framework) |
| Config file | none |
| Quick run command | `bash cicd/lint-markdown.sh` (per phase) |
| Full suite command | per-phase content checks + lint |

### Phase Requirements → Test Map

This phase has no new requirements (tech debt only). The test strategy for Phase 9 itself is:

| ID | Behavior | Test Type | Automated Command | File Exists? |
|----|----------|-----------|-------------------|-------------|
| P9-01 | Phase 1 VALIDATION.md has wave_0_complete: true | content | `grep -q 'wave_0_complete: true' .planning/phases/01-project-router/01-VALIDATION.md && echo PASS` | ✅ |
| P9-02 | Phase 2 VALIDATION.md has nyquist_compliant: true | content | `grep -q 'nyquist_compliant: true' .planning/phases/02-define-gates-0-wb-1/02-VALIDATION.md && echo PASS` | ✅ |
| P9-03 | Phase 3 VALIDATION.md has wave_0_complete: true | content | `grep -q 'wave_0_complete: true' .planning/phases/03-design-gate-2/03-VALIDATION.md && echo PASS` | ✅ |
| P9-04 | Phase 4 VALIDATION.md has nyquist_compliant: true | content | `grep -q 'nyquist_compliant: true' .planning/phases/04-milestone-gate-3/04-VALIDATION.md && echo PASS` | ✅ |
| P9-05 | Phase 5 VALIDATION.md has wave_0_complete: true | content | `grep -q 'wave_0_complete: true' .planning/phases/05-plan-gate-4/05-VALIDATION.md && echo PASS` | ✅ |
| P9-06 | Phase 6 VALIDATION.md has nyquist_compliant: true | content | `grep -q 'nyquist_compliant: true' .planning/phases/06-build/06-VALIDATION.md && echo PASS` | ✅ |
| P9-07 | Phase 7 VALIDATION.md has wave_0_complete: true | content | `grep -q 'wave_0_complete: true' .planning/phases/07-spike-docs/07-VALIDATION.md && echo PASS` | ✅ |

### Sampling Rate

- **Per task commit:** Run the phase-specific content checks (quick run command for that phase)
- **Per wave merge:** All 7 phases' full content checks
- **Phase gate:** All 7 phases show PASS before `/gsd:verify-work`

### Wave 0 Gaps

None — all target files exist on disk. No new files are created in this phase. No framework install required.

---

## Open Questions

1. **Lint script path: D-03 says `scripts/` but actual file is at `cicd/`**
   - What we know: `cicd/lint-markdown.sh` exists and works; `scripts/lint-markdown.sh` does not exist
   - What's unclear: Does the user intend to rename/move the file, or was D-03 written in error?
   - Recommendation: The planner should treat `cicd/lint-markdown.sh` as the correct path and NOT apply D-03 as written. Flag this for user confirmation if planning automated. The safe default is to leave the working path alone.

---

## Sources

### Primary (HIGH confidence)

- Direct file inspection — all 7 VALIDATION.md files read and analyzed
- Direct bash execution — all grep patterns run against actual skill files, exit codes observed
- Phase 8 VALIDATION.md — gold standard pattern read and understood
- `cicd/lint-markdown.sh` — existence and functionality confirmed

### Secondary (MEDIUM confidence)

- CONTEXT.md — decisions and constraints from discuss phase (locked decisions)
- REQUIREMENTS.md — full requirement traceability confirmed

---

## Metadata

**Confidence breakdown:**
- What needs to change per phase: HIGH — directly read and verified against file content
- Grep patterns: HIGH — all patterns executed and confirmed passing
- Lint path discrepancy: HIGH — both paths directly checked (cicd/ exists, scripts/ does not)
- Phase 6/7 failure diagnosis: HIGH — failures reproduced, corrections confirmed

**Research date:** 2026-04-03
**Valid until:** Stable — skill files rarely change; valid as long as skill file content is unchanged
