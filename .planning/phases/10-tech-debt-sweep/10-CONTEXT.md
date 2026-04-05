# Phase 10: Tech Debt Sweep - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix 4 low-severity documentation and attribution issues identified in the v1.0 audit:
1. ROADMAP.md phase checkboxes — 2 stale `[ ]` plan entries for completed phases
2. `docs/SKILLS.md` cp command inconsistency — individual sub-skill entries missing for define/design/build
3. `/project` SKILL.md STATE-04 attribution — `/plan` incorrectly listed as a skill subject to write-ordering
4. `04-03-SUMMARY.md` missing `requirements-completed` frontmatter

All changes are documentation edits. No behavior changes. No skill logic changes.

</domain>

<decisions>
## Implementation Decisions

### ROADMAP.md Checkbox Fix
- **D-01:** Flip `[ ] 01-03-PLAN.md` → `[x]` (line 44) — Phase 1 is complete, this plan entry is stale
- **D-02:** Flip `[ ] 05-02-PLAN.md` → `[x]` (line 110) — Phase 5 is complete, this plan entry is stale
- **D-03:** No other checkbox changes needed — phases 1–9 top-level entries already show `[x]`, phases 10–11 correctly show `[ ]`

### SKILLS.md cp Consistency
- **D-04:** Add individual `cp -r` entries for `define/`, `design/`, and `build/` sub-skills to match the existing entries for `milestone/`, `plan/`, and `spike/`. All 6 sub-skills should have explicit entries for selective installs.
- **D-05:** The catch-all `cp -r skills/project/` line remains — it covers the full suite install path.

### STATE-04 Attribution Fix
- **D-06:** In `/project` SKILL.md, update the STATE-04 attribution line (currently: "This rule applies to `/build`, `/milestone`, and `/plan`") to remove `/plan`. `/plan` only writes `milestone-status.txt`, never both files simultaneously, so write-ordering is not applicable.
- **D-07:** Corrected attribution: "This rule applies to `/build` and `/milestone`, not to `/project` or `/plan`."

### 04-03-SUMMARY.md Frontmatter
- **D-08:** Add `requirements-completed: [MIL-01, MIL-02, MIL-03, MIL-04, MIL-05, MIL-06, MIL-07, MIL-08, MIL-09, MIL-10, MIL-11, MIL-12, MIL-13]` to the frontmatter of `04-03-SUMMARY.md`, matching the pattern from 04-01 and 04-02. All plan summaries in a phase claim the same requirements — documentation is part of complete delivery.

### Claude's Discretion
- Exact placement of new `cp -r` lines in SKILLS.md (maintain alphabetical or natural order)
- Whether to add a blank line separator between individual sub-skill entries and catch-all in SKILLS.md

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Files to edit
- `.planning/ROADMAP.md` — 2 stale plan checkboxes to flip (lines 44 and 110)
- `docs/SKILLS.md` — consuming instructions section, add 3 missing cp commands (lines 69–81)
- `skills/project/SKILL.md` — STATE-04 attribution line (line 27)
- `.planning/phases/04-milestone-gate-3/04-03-SUMMARY.md` — add requirements-completed frontmatter field

### Audit source
- `.planning/v1.0-MILESTONE-AUDIT.md` — original source of all 4 tech debt items; `tech_debt` section lists exact descriptions

### Reference for requirements list
- `.planning/phases/04-milestone-gate-3/04-01-SUMMARY.md` — has `requirements-completed: [MIL-01..MIL-13]` (line 43) — pattern to match in 04-03

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — all changes are targeted text edits to existing files

### Established Patterns
- SUMMARY.md frontmatter pattern: `requirements-completed: [REQ-01, REQ-02, ...]` as seen in 04-01 and 04-02
- SKILLS.md consuming instructions pattern: `cp -r skills/<name>/  <target-repo>/.claude/skills/<name>/`

### Integration Points
- `docs/SKILLS.md` lines 69–81: the consuming instructions block where 3 new cp lines need to be inserted
- `skills/project/SKILL.md` line 27: the write-ordering note referencing `/build`, `/milestone`, and `/plan`
- `04-03-SUMMARY.md` frontmatter block: add field after existing `tags:` line

</code_context>

<specifics>
## Specific Ideas

No specific requirements — all 4 fixes have a single correct answer defined by the success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 10-tech-debt-sweep*
*Context gathered: 2026-04-03*
