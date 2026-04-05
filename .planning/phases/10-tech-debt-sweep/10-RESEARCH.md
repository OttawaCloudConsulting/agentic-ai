# Phase 10: Tech Debt Sweep - Research

**Researched:** 2026-04-04
**Domain:** Documentation editing — 4 targeted text edits to existing files
**Confidence:** HIGH

## Summary

Phase 10 is a documentation-only sweep with zero behavioral or logic changes. All 4 fixes have a single correct answer defined by the decisions in CONTEXT.md. Every target file, target line number, and exact replacement value is already known — this phase requires no external library research, no ecosystem discovery, and no architectural decisions.

The work is: open 4 files, make 6 targeted edits (2 checkbox flips + 3 cp line insertions + 1 attribution fix + 1 frontmatter field addition), verify each edit against its success criterion.

No web searches, Context7 lookups, or package version checks are needed. All findings are drawn directly from the files on disk.

**Primary recommendation:** Plan this as a single wave with 4 tasks (one per fix), each with an explicit before/after verification step. No sequencing dependencies — all 4 edits are independent.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Flip `[ ] 01-03-PLAN.md` → `[x]` (ROADMAP.md line 44) — Phase 1 is complete, this plan entry is stale.
**D-02:** Flip `[ ] 05-02-PLAN.md` → `[x]` (ROADMAP.md line 110) — Phase 5 is complete, this plan entry is stale.
**D-03:** No other checkbox changes needed — phases 1–9 top-level entries already show `[x]`, phases 10–11 correctly show `[ ]`.
**D-04:** Add individual `cp -r` entries for `define/`, `design/`, and `build/` sub-skills to `docs/SKILLS.md` to match the existing entries for `milestone/`, `plan/`, and `spike/`.
**D-05:** The catch-all `cp -r skills/project/` line remains — it covers the full suite install path.
**D-06:** In `/project` SKILL.md line 27, remove `/plan` from the attribution list in the write-ordering note.
**D-07:** Corrected attribution text: "This rule applies to `/build` and `/milestone`, not to `/project` or `/plan`."
**D-08:** Add `requirements-completed: [MIL-01, MIL-02, MIL-03, MIL-04, MIL-05, MIL-06, MIL-07, MIL-08, MIL-09, MIL-10, MIL-11, MIL-12, MIL-13]` to the frontmatter of `04-03-SUMMARY.md`, after the `tags:` line.

### Claude's Discretion

- Exact placement of new `cp -r` lines in SKILLS.md (maintain alphabetical or natural order within the project sub-skills block)
- Whether to add a blank line separator between individual sub-skill entries and catch-all in SKILLS.md

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

## Standard Stack

Not applicable. This phase requires no libraries, packages, or tools beyond file editing.

**Installation:** None.

---

## Architecture Patterns

### The 4 Fixes in Detail

#### Fix 1 — ROADMAP.md Checkbox Stale Plan Entries

**File:** `.planning/ROADMAP.md`
**Lines:** 44 and 110
**Problem:** Two plan-level checkbox entries show `[ ]` even though their parent phases are marked `[x]` complete. Phase 1 (line 44: `01-03-PLAN.md`) and Phase 5 (line 110: `05-02-PLAN.md`) are both complete.
**Verified current state:** Line 44 shows `- [ ] 01-03-PLAN.md — Documentation (detail doc + catalog entry)`. Line 110 shows `- [ ] 05-02-PLAN.md — SKILL.md flow controller`.
**Correct state:** Both flip to `- [x]`.
**Why safe:** D-03 confirms no other checkboxes need changing. Phases 10–11 top-level entries correctly remain `[ ]`.

#### Fix 2 — docs/SKILLS.md cp Command Consistency

**File:** `docs/SKILLS.md`
**Lines:** 69–81 (the Consuming Skills bash block)
**Problem:** The install block has explicit `cp -r` lines for `milestone/`, `plan/`, and `spike/` sub-skills, but omits `define/`, `design/`, and `build/`. The sub-skill directories that exist on disk are: `build/`, `define/`, `design/`, `milestone/`, `plan/`, `spike/`.
**Verified current state (lines 75–80):**
```
cp -r skills/project/milestone/          <target-repo>/.claude/skills/project/milestone/
cp -r skills/project/plan/                <target-repo>/.claude/skills/project/plan/
cp -r skills/project/spike/               <target-repo>/.claude/skills/project/spike/
cp -r skills/occ-skill-creator/         ...
cp -r skills/occ-skill-refactor/        ...
cp -r skills/project/                   <target-repo>/.claude/skills/project/
```
**Correct state:** Add 3 lines for `build/`, `define/`, and `design/`. Placement: insert after existing project sub-skill entries and before the catch-all `cp -r skills/project/` line, in pipeline order (define → design → milestone → plan → build → spike) to match the natural invocation sequence.
**Claude's discretion:** pipeline order is preferred over strict alphabetical because the consuming instructions follow the same grouping used for the skill table above.

#### Fix 3 — /project SKILL.md STATE-04 Attribution

**File:** `skills/project/SKILL.md`
**Line:** 27
**Problem:** The write-ordering rule note lists `/plan` as a skill subject to the STATE-04 ordering constraint. `/plan` only writes `milestone-status.txt`, never both files simultaneously, so the ordering constraint is not applicable to it.
**Verified current state (line 27):** `This rule applies to \`/build\`, \`/milestone\`, and \`/plan\`, not to \`/project\` itself.`
**Correct state (D-07):** `This rule applies to \`/build\` and \`/milestone\`, not to \`/project\` or \`/plan\`.`
**Why this matters:** The note is referenced by downstream skill authors. Incorrect attribution could cause future skills to implement unnecessary write-ordering in `/plan`.

#### Fix 4 — 04-03-SUMMARY.md Missing Frontmatter

**File:** `.planning/phases/04-milestone-gate-3/04-03-SUMMARY.md`
**Problem:** The frontmatter has `tags:` but no `requirements-completed:` field. The other two Phase 4 summaries (04-01, 04-02) both have this field. Phase audit tooling reads this field to track coverage.
**Verified current state:** Frontmatter ends at line 5 (`tags: [milestone, gate-3, documentation, catalog]`) with no `requirements-completed:` line.
**Reference pattern (from 04-01-SUMMARY.md line 43):** `requirements-completed: [MIL-01, MIL-02, ..., MIL-13]`
**Correct state (D-08):** Add `requirements-completed: [MIL-01, MIL-02, MIL-03, MIL-04, MIL-05, MIL-06, MIL-07, MIL-08, MIL-09, MIL-10, MIL-11, MIL-12, MIL-13]` after the `tags:` line (before the blank line that closes the frontmatter block). All plan summaries in a phase claim the same requirements list.

---

## Don't Hand-Roll

Not applicable. All changes are direct text edits using the Edit tool. No scripts, no automation.

---

## Common Pitfalls

### Pitfall 1: Partial ROADMAP.md Scan
**What goes wrong:** Scanning only for the two known stale lines, then missing that Phase 9 plan 4 (`09-04-PLAN.md`) might also need a check.
**Why it happens:** The implementer focuses on the two identified lines and skips a full review.
**How to avoid:** D-03 is authoritative — verify it by reading the Phase 9 plans block in ROADMAP.md before declaring done. Phase 9 has 4 plans; all 4 were marked complete in the phase execution. Current ROADMAP.md shows `4/4 plans complete` for Phase 9.
**Warning signs:** Phase 9 plan rows showing `[ ]` in the implementation's post-edit state.

### Pitfall 2: Wrong Frontmatter Placement in 04-03-SUMMARY.md
**What goes wrong:** Adding `requirements-completed:` after the closing `---` of the frontmatter block instead of inside it.
**Why it happens:** The frontmatter block ends at line 15 (the second `---`). Inserting after line 5 but before line 15 is correct; inserting after line 15 is wrong.
**How to avoid:** Read the full frontmatter block before editing. The `---` delimiters are at lines 1 and 15 (based on SUMMARY file structure). Insert after the `tags:` line (line 5), not after the closing `---`.

### Pitfall 3: Disrupting the SKILLS.md Bash Block Formatting
**What goes wrong:** New `cp -r` lines are inserted with inconsistent alignment, breaking the visual pattern.
**Why it happens:** Copy-paste from an existing line without matching padding.
**How to avoid:** Match the existing alignment pattern. The 3 new lines should follow the `skills/project/<name>/` + padding + `<target-repo>/.claude/skills/project/<name>/` format used by the existing `milestone/`, `plan/`, `spike/` entries.

### Pitfall 4: Altering 04-03-SUMMARY.md Body Content
**What goes wrong:** Editing the markdown body of the SUMMARY file in addition to the frontmatter.
**Why it happens:** The file is being opened for editing and the body content looks like it may benefit from updates.
**How to avoid:** Fix is frontmatter-only. The `## One-Liner`, `## Self-Check`, and remaining body content are correct as-is. Touch only the YAML frontmatter between the `---` delimiters.

---

## Code Examples

### Fix 1: ROADMAP.md Before/After (line 44)
```
Before: - [ ] 01-03-PLAN.md — Documentation (detail doc + catalog entry)
After:  - [x] 01-03-PLAN.md — Documentation (detail doc + catalog entry)
```

### Fix 1: ROADMAP.md Before/After (line 110)
```
Before: - [ ] 05-02-PLAN.md — SKILL.md flow controller
After:  - [x] 05-02-PLAN.md — SKILL.md flow controller
```

### Fix 2: SKILLS.md — 3 lines to insert after `spike/` entry (line 77), before `occ-skill-creator` entries
```bash
cp -r skills/project/define/              <target-repo>/.claude/skills/project/define/
cp -r skills/project/design/              <target-repo>/.claude/skills/project/design/
cp -r skills/project/build/               <target-repo>/.claude/skills/project/build/
```
These join the existing block:
```bash
cp -r skills/project/milestone/          <target-repo>/.claude/skills/project/milestone/
cp -r skills/project/plan/                <target-repo>/.claude/skills/project/plan/
cp -r skills/project/spike/               <target-repo>/.claude/skills/project/spike/
# ^ insert define/, design/, build/ here in pipeline order, before catch-all below
cp -r skills/project/                   <target-repo>/.claude/skills/project/
```

### Fix 3: SKILL.md Line 27 Before/After
```
Before: This rule applies to `/build`, `/milestone`, and `/plan`, not to
        `/project` itself.
After:  This rule applies to `/build` and `/milestone`, not to `/project` or `/plan`.
```

### Fix 4: 04-03-SUMMARY.md Frontmatter — Line to add after `tags:`
```yaml
requirements-completed: [MIL-01, MIL-02, MIL-03, MIL-04, MIL-05, MIL-06, MIL-07, MIL-08, MIL-09, MIL-10, MIL-11, MIL-12, MIL-13]
```
Pattern verified from `04-01-SUMMARY.md` line 43.

---

## Validation Architecture

nyquist_validation is enabled (config.json has `"nyquist_validation": true`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash grep (no test runner — doc-only phase) |
| Config file | none |
| Quick run command | `grep -c '\[x\]' .planning/ROADMAP.md` |
| Full suite command | see per-fix verification commands below |

### Phase Requirements to Test Map

This phase has no requirement IDs (tech debt — no requirement changes). Tests verify the 4 success criteria directly.

| Success Criterion | Behavior | Test Type | Automated Command | File Exists? |
|-------------------|----------|-----------|-------------------|-------------|
| SC-1 | ROADMAP.md plan checkboxes accurate | smoke | `grep -n "01-03-PLAN\|05-02-PLAN" .planning/ROADMAP.md` — both lines must show `[x]` | Already exists |
| SC-2 | SKILLS.md has cp lines for all 6 sub-skills | smoke | `grep "cp -r skills/project/define\|cp -r skills/project/design\|cp -r skills/project/build" docs/SKILLS.md` — must return 3 matches | Already exists |
| SC-3 | SKILL.md STATE-04 attribution correct | smoke | `grep "This rule applies" skills/project/SKILL.md` — must NOT contain `/plan` in the applies-to list | Already exists |
| SC-4 | 04-03-SUMMARY.md has requirements-completed | smoke | `grep "requirements-completed" .planning/phases/04-milestone-gate-3/04-03-SUMMARY.md` — must match MIL pattern | Already exists |

### Sampling Rate

- **Per task commit:** run the grep command for that task's success criterion
- **Per wave merge:** run all 4 grep commands
- **Phase gate:** all 4 grep commands green before `/gsd:verify-work`

### Wave 0 Gaps

None — all 4 verifications use grep against existing files with no test infrastructure required.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is purely file edits with no external tool dependencies. All files exist on disk and were verified by direct reads above.

---

## Open Questions

None. All 4 fixes have a single correct answer fully defined by the decisions in CONTEXT.md. File paths, line numbers, and exact replacement text are confirmed by direct inspection.

---

## Sources

### Primary (HIGH confidence)

- Direct file reads of all 4 target files — confirmed current state vs. required state for all changes
- `10-CONTEXT.md` — locked decisions D-01 through D-08 define every edit
- `04-01-SUMMARY.md` line 43 — frontmatter pattern reference for Fix 4
- `skills/project/SKILL.md` line 27 — confirmed current attribution text for Fix 3
- `docs/SKILLS.md` lines 75–80 — confirmed current cp block for Fix 2
- `ROADMAP.md` lines 44 and 110 — confirmed current checkbox state for Fix 1

### Secondary

None needed — all findings are from direct file inspection.

---

## Metadata

**Confidence breakdown:**

- Fix targets: HIGH — all 4 files read directly, line numbers verified
- Exact replacement text: HIGH — confirmed against CONTEXT.md decisions and reference files
- No regressions: HIGH — all changes are additive or in-place text substitutions with no behavioral surface

**Research date:** 2026-04-04
**Valid until:** Indefinite — static documentation phase with fully pre-specified edits
