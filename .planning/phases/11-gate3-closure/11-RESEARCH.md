# Phase 11: Gate 3 Closure Pathway — Research

**Researched:** 2026-04-03
**Domain:** Claude Code skill authoring — `/project` SKILL.md routing and state file writes
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Implement Gate 3 closure — add logic to `/project` Step 5 (Route) to detect when closure is appropriate and write `[x]` to Gate 3 in `progress.txt`. Do NOT take the documentation-only path.
- **D-02:** Narrow PROJ-10 (not remove it): the read-only rule gains one named exception: Gate 3 closure. REQUIREMENTS.md, DESIGN.md DD-3, and SKILL.md Rules section must all reflect the same narrowed rule.
- **D-03:** `/project` offers Gate 3 closure when: all milestones in `progress.txt` are `[x]` complete AND Gate 3 is still `[~] In progress`. Both conditions must be true simultaneously.
- **D-04:** Gate 3 closure is offered via `AskUserQuestion` (not automatic). Options: "Close Gate 3" / "Leave open". User must confirm before the write happens.
- **D-05:** The closure prompt is part of Step 5 routing — it fires as a special case in the routing table evaluation, before outputting the normal RECOMMENDED/Also available block.
- **D-06:** Add a new row to `references/routing-logic.md` routing table: State = "All milestones `[x]`, Gate 3 still `[~] In progress`" → Offer Gate 3 closure via `AskUserQuestion`. This row is inserted immediately before the existing "All milestones complete → Project complete" row.
- **D-07:** After Gate 3 is written `[x]`, routing falls through to the "All milestones complete" row and shows "Project complete" as the recommendation.
- **D-08:** Update DD-3 in `DESIGN.md` to add Gate 3 closure as a second named exception alongside bootstrap. Exact language: "**Gate 3 closure exception:** When all milestones are `[x]` complete and Gate 3 remains `[~] In progress`, `/project` offers closure via `AskUserQuestion`. This is the only post-bootstrap write `/project` performs."
- **D-09:** Update REQUIREMENTS.md PROJ-10 to reflect the narrowed rule: add parenthetical "(Bootstrap and Gate 3 closure are the two exceptions)".

### Claude's Discretion

- Exact wording of the AskUserQuestion prompt for Gate 3 closure offer
- Whether to show a 1-line explanation of what Gate 3 closure means before the prompt
- Whether to re-display the full status report after writing `[x]` or just confirm inline

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIL-09 | `/milestone` records Gate 3 approval as `[~] In progress` in `progress.txt` — Gate 3 stays open until user signals all milestones are defined | This requirement is already satisfied; Phase 11 adds the closure pathway so the `[~]` eventually becomes `[x]` via `/project` not `/milestone` |
| PROJ-10 (gap closure) | `/project` remains strictly read-only after bootstrap — never modifies state files in normal operation | The fix narrows the rule with a second named exception (Gate 3 closure); the `progress.txt` write pattern already exists at bootstrap and is directly reusable |

</phase_requirements>

---

## Summary

Phase 11 is a targeted gap closure: Gate 3 currently displays `[~] In progress` permanently even on fully-completed projects because the closure pathway was never implemented. The structural cause is a conflict between PROJ-10 (read-only after bootstrap) and the design intent (D-05) that `/project` should offer closure when all milestones are done.

The user has chosen the implementation path over the documentation-only path. The work is narrowly scoped: add one conditional branch to Step 5 of `/project` SKILL.md, one row to the routing table in `routing-logic.md`, one exception paragraph to DD-3 in `DESIGN.md`, and one parenthetical to the PROJ-10 row in `REQUIREMENTS.md`. No other skills are touched.

The implementation follows an exact existing pattern in the same file: the Gate WB offer (`AskUserQuestion` with confirm/skip, fires as a conditional branch before normal recommendation output). The progress.txt write follows the bootstrap write pattern (single targeted update). Both patterns are already present in the codebase.

**Primary recommendation:** Copy the Gate WB offer pattern from SKILL.md Step 5 verbatim as the structural template for the Gate 3 closure offer. Replace condition, write target, and option labels only.

---

## Standard Stack

This phase involves no libraries or package dependencies. All changes are text edits to Markdown instruction files (`.md`). The "stack" is the existing pattern language of the skill suite.

### Core Pattern Assets

| Asset | File | Purpose | Source |
|-------|------|---------|--------|
| Gate WB offer pattern | `skills/project/SKILL.md` Step 5 (~line 128) | AskUserQuestion with Yes/Skip/Defer firing before normal routing output | Verified — read SKILL.md |
| Bootstrap write pattern | `skills/project/SKILL.md` Step 2 | Single targeted Write to `progress.txt` | Verified — read SKILL.md |
| Progress file Gate entry format | `skills/project/references/progress-format.md` lines 64–102 | Approved Gate line format with date and artifact path | Verified — read progress-format.md |
| Routing table top-to-bottom first-match semantics | `skills/project/references/routing-logic.md` | Row insertion position rules | Verified — read routing-logic.md |
| DD-3 Bootstrap exception paragraph | `skills/project/DESIGN.md` lines 100–103 | Bold-label paragraph format for named exceptions | Verified — read DESIGN.md |

### Installation

No packages to install. All changes are Markdown text edits.

---

## Architecture Patterns

### Files to Modify (4 files total)

```
skills/project/
├── SKILL.md                         -- Rules section + Step 5 closure branch
├── DESIGN.md                        -- DD-3: add Gate 3 closure exception paragraph
└── references/
    └── routing-logic.md             -- Routing table: add new row before "All milestones complete"

.planning/
└── REQUIREMENTS.md                  -- PROJ-10 row: add exception parenthetical
```

No new files are created. No other skills are modified.

### Pattern 1: Step 5 Conditional Branch (Gate 3 Closure Offer)

**What:** Before outputting the normal RECOMMENDED block, Step 5 evaluates an additional condition. If all milestones are `[x]` and Gate 3 is still `[~]`, it fires an `AskUserQuestion` before proceeding to the routing table output.

**When to use:** This is the exact same structure as the Gate WB offer already in Step 5. The existing Gate WB block (lines ~128–136 in SKILL.md) is the template.

**Existing Gate WB pattern to follow:**

```markdown
**Gate WB offer (DD-11, D-08):** If Gate 0 is approved (`[x]`) or skipped (`[-]` greenfield),
no `docs/working-backwards.md` exists, Gate WB has not been offered yet, and the customer
outcome is unclear -- offer Gate WB using `AskUserQuestion` with options:

- **Yes** -- proceed with Working Backwards exercise (routes to `/define`)
- **Skip** -- record Gate WB as skipped
- **Defer** -- record Gate WB as Pending for later decision

Include a 2-3 sentence explanation of the Working Backwards value proposition.
```

**Gate 3 closure equivalent (new block, Claude's discretion for exact wording):**

```markdown
**Gate 3 closure offer (D-01 through D-05):** If all milestones in `progress.txt` are `[x]`
complete AND Gate 3 is still `[~] In progress` -- offer Gate 3 closure using `AskUserQuestion`:

- **Close Gate 3** -- write `[x] Gate 3: Milestone Review  Approved: <date>  (closed by /project)`
  to `progress.txt`, then continue to routing (shows "Project complete")
- **Leave open** -- skip the write, continue to normal routing ("Project complete" still shows)

[Optional 1-line explanation: "Gate 3 tracks milestone planning. Closing it marks the milestone
review phase officially complete."]
```

**Position:** This block is appended to Step 5 after re-planning intent detection and before (or as the first case of) normal routing output. The Gate WB offer and Gate 3 closure offer are both conditional branches in Step 5 that fire before the RECOMMENDED block when their conditions are met.

### Pattern 2: Progress.txt Gate Write

**What:** A targeted in-place update of the Gate 3 line in `progress.txt`. Changes `[~] Gate 3: Milestone Review  In progress` to the approved format.

**Approved Gate 3 line format** (from `progress-format.md`):

```
[x] Gate 3: Milestone Review  Approved: <YYYY-MM-DD>  (closed by /project)
```

The artifact path field for Gate 3 is `(closed by /project)` — there is no single artifact file (Gate 3 approval is distributed across multiple `gate-3-review.md` files per milestone). The CONTEXT.md specifies the exact format as: `[x] Gate 3: Milestone Review  Approved: <date>  (closed by /project)`.

**Write instruction for SKILL.md** (mirrors Step 2 bootstrap language):

```
Use the Write tool to update the Gate 3 line in `progress.txt`:
Replace: `[~] Gate 3: Milestone Review  In progress`
With:    `[x] Gate 3: Milestone Review  Approved: <YYYY-MM-DD>  (closed by /project)`
where <YYYY-MM-DD> is today's date.
Read the file back and confirm the update was applied correctly.
```

### Pattern 3: Routing Table Row Insertion

**What:** One new row inserted into the routing table in `routing-logic.md` immediately before the final "All milestones complete" row.

**Insertion point** (current last two rows):

```
| All features complete in active milestone, more milestones to define | Run `/milestone` for next milestone | `/design` (refresh) |
| All milestones complete | Project complete -- celebrate | `/design` (refresh) |  <-- insert before this
```

**New row:**

```
| All milestones `[x]` complete, Gate 3 still `[~] In progress` | Offer Gate 3 closure via `AskUserQuestion` (per D-01–D-05) | -- |
```

**Why before "All milestones complete":** The routing table uses top-to-bottom first-match. The new state (all milestones `[x]` + Gate 3 `[~]`) must be caught before the "All milestones complete" row — otherwise the terminal row matches first and Gate 3 is never offered. After the user confirms closure (or leaves open), routing falls through to "All milestones complete" for the final recommendation.

### Pattern 4: DD-3 Exception Paragraph

**What:** A second named exception paragraph appended to DD-3 in DESIGN.md, following the "Bootstrap exception" paragraph's bold-label format.

**Current DD-3 Bootstrap exception paragraph (lines 100–103):**

```markdown
**Bootstrap exception:** On first run, if the project-level `progress.txt` does not exist,
`/project` creates it with gate entries and no milestones. Milestone-level `milestone-status.txt`
files are created by `/milestone` when milestones are defined. This bootstrap is the only case where
`/project` writes to disk. After bootstrap, `/project` is strictly read-only.
```

**New Gate 3 closure exception paragraph (verbatim from D-08):**

```markdown
**Gate 3 closure exception:** When all milestones are `[x]` complete and Gate 3 remains
`[~] In progress`, `/project` offers closure via `AskUserQuestion`. This is the only
post-bootstrap write `/project` performs.
```

This paragraph is inserted immediately after the Bootstrap exception paragraph, before the "Artifact validation" paragraph.

### Pattern 5: REQUIREMENTS.md PROJ-10 Narrowing

**Current PROJ-10 text:**

```
- [x] **PROJ-10**: `/project` remains strictly read-only after bootstrap — never modifies state files in normal operation
```

**Updated PROJ-10 text (per D-09):**

```
- [x] **PROJ-10**: `/project` remains strictly read-only after bootstrap — never modifies state files in normal operation (Bootstrap and Gate 3 closure are the two exceptions)
```

### Pattern 6: SKILL.md Rules Section Update

The Rules section currently states:

```markdown
- **Read-only after bootstrap.** After the initial `progress.txt` creation, `/project`
  never modifies `progress.txt` or any other file (PROJ-10). Bootstrap (Step 2) is the
  sole exception.
```

This must be updated to name both exceptions:

```markdown
- **Read-only after bootstrap.** After the initial `progress.txt` creation, `/project`
  never modifies `progress.txt` or any other file (PROJ-10). Two exceptions exist:
  bootstrap (Step 2) and Gate 3 closure (Step 5, when all milestones are complete).
```

### Anti-Patterns to Avoid

- **Auto-closing Gate 3 without user confirmation.** D-04 is explicit: `AskUserQuestion` required. No silent writes.
- **Changing the routing table's "All milestones complete" row.** Do not modify the terminal row — only insert before it.
- **Writing a non-existent artifact path for Gate 3.** Gate 3 has no single artifact file. Use `(closed by /project)` as the artifact path field.
- **Modifying `/milestone` SKILL.md.** The CONTEXT.md canonical refs confirm: "No changes to `/milestone` or other skills."
- **Removing PROJ-10 instead of narrowing it.** D-02 is explicit: narrow, do not remove.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| AskUserQuestion prompt structure | Custom prompt format | Copy Gate WB offer structure from SKILL.md Step 5 verbatim |
| Progress.txt write mechanics | Custom write logic | Replicate Step 2 bootstrap Write tool instruction pattern |
| Exception documentation format | New documentation style | Bold-label paragraph format from DD-3 Bootstrap exception |

---

## Common Pitfalls

### Pitfall 1: Wrong Row Insertion Position

**What goes wrong:** The new routing table row is inserted after "All milestones complete" instead of before it. Routing hits the terminal row first (all milestones done = project complete), and the Gate 3 closure offer never fires.

**Why it happens:** The terminal row already matches the state "all milestones `[x]`" — it doesn't check Gate 3 status. The new row adds Gate 3 status as an additional discriminator that must be evaluated first.

**How to avoid:** New row goes immediately before the "All milestones complete" row. Verify by tracing: state = "all milestones `[x]`, Gate 3 `[~]`" — does it hit the new row before the terminal row? Yes if ordered correctly.

**Warning signs:** If "Project complete" appears without a Gate 3 closure offer ever firing on a fully-completed test project.

### Pitfall 2: Inconsistent Rule Updates Across Files

**What goes wrong:** PROJ-10 is updated in REQUIREMENTS.md but the SKILL.md Rules section still says "Bootstrap (Step 2) is the sole exception." Or DESIGN.md DD-3 is updated but SKILL.md Rules is not. The three files are out of sync, creating confusion for implementers and verifiers.

**Why it happens:** Four files need changes; it is easy to miss one.

**How to avoid:** D-02 explicitly requires all three documentation locations to be updated: REQUIREMENTS.md, DESIGN.md DD-3, and SKILL.md Rules section. The plan should treat these as a single atomic documentation task, not separate independent tasks.

**Warning signs:** Post-implementation grep for "sole exception" in SKILL.md — should not appear after the fix.

### Pitfall 3: Gate 3 Approved Line Missing Artifact Path

**What goes wrong:** The written Gate 3 line omits the artifact path field, producing `[x] Gate 3: Milestone Review  Approved: 2026-04-03` without the third field. `/project`'s own PROJ-04 artifact validation then fires a warning on the next invocation (because it parses the path from the line and finds nothing).

**Why it happens:** Gate 3 has no single artifact file, unlike Gates 0–2 which have clear artifact paths. The field cannot be left blank.

**How to avoid:** Use `(closed by /project)` as the artifact path (per CONTEXT.md D-05). This is a sentinel value that PROJ-04 can check for existence — it will not find a file at this path. Two options to handle this: (1) PROJ-04 skips the existence check for sentinel values starting with `(`; or (2) the planner accepts the warning as acceptable cosmetic noise and documents it. The simpler fix is option (1): add a guard in artifact validation to skip sentinel paths. This should be addressed in the plan.

**Warning signs:** After closure, re-invoking `/project` shows a "Artifact not found: (closed by /project)" warning inline with Gate 3.

### Pitfall 4: "Leave open" Option Still Shows Incorrect Routing

**What goes wrong:** User selects "Leave open" (D-04). The closure is skipped. But routing still needs to say "Project complete" — all milestones are done. The routing table's "All milestones complete" row must still fire after the user declines closure.

**Why it happens:** The closure offer interrupts normal routing. After the `AskUserQuestion` resolves (either option), routing must resume. D-07 specifies: "After Gate 3 is written `[x]`, routing falls through to 'All milestones complete' row." The same fall-through applies if the user says "Leave open."

**How to avoid:** The SKILL.md closure branch must explicitly state: after `AskUserQuestion` resolves (regardless of choice), continue to the normal routing table evaluation. The "All milestones complete" row will then match and show "Project complete."

---

## Code Examples

All examples are drawn from verified existing files in the codebase.

### Gate WB Offer (Template to Follow)

```markdown
<!-- Source: skills/project/SKILL.md Step 5 -- exact existing text -->
**Gate WB offer (DD-11, D-08):** If Gate 0 is approved (`[x]`) or skipped (`[-]` greenfield),
no `docs/working-backwards.md` exists, Gate WB has not been offered yet, and the customer
outcome is unclear -- offer Gate WB using `AskUserQuestion` with options:

- **Yes** -- proceed with Working Backwards exercise (routes to `/define`)
- **Skip** -- record Gate WB as skipped
- **Defer** -- record Gate WB as Pending for later decision

Include a 2-3 sentence explanation of the Working Backwards value proposition.
```

### Approved Gate Line Format

```
<!-- Source: skills/project/references/progress-format.md lines 64-70 -->
[x] Gate 0: Codebase Alignment  Approved: 2026-03-15  docs/codebase-assessment.md
```

Gate 3 approved with sentinel artifact path:

```
[x] Gate 3: Milestone Review  Approved: 2026-04-03  (closed by /project)
```

### Current Routing Table Tail (Insertion Point Reference)

```markdown
<!-- Source: skills/project/references/routing-logic.md lines 23-24 -->
| All features complete in active milestone, more milestones to define | Run `/milestone` for next milestone | `/design` (refresh) |
| All milestones complete | Project complete -- celebrate | `/design` (refresh) |
```

New row inserts between these two.

### DD-3 Bootstrap Exception (Style Template)

```markdown
<!-- Source: skills/project/DESIGN.md lines 100-103 -->
**Bootstrap exception:** On first run, if the project-level `progress.txt` does not exist,
`/project` creates it with gate entries and no milestones. Milestone-level `milestone-status.txt`
files are created by `/milestone` when milestones are defined. This bootstrap is the only case where
`/project` writes to disk. After bootstrap, `/project` is strictly read-only.
```

---

## Open Questions

1. **PROJ-04 artifact validation for sentinel path `(closed by /project)`**
   - What we know: PROJ-04 checks that artifact paths on `[x]` gate lines exist on disk. `(closed by /project)` is not a real file path.
   - What's unclear: Whether PROJ-04's artifact validation guard needs an explicit sentinel-skip clause, or whether the resulting warning is acceptable behavior.
   - Recommendation: The planner should decide: either add a guard in `routing-logic.md` Artifact Validation section to skip sentinel paths (paths starting with `(`), or document the warning as acceptable. Adding the guard is cleaner and prevents a confusing warning on every post-closure `/project` invocation. This is a small addition to the routing-logic.md Artifact Validation section.

2. **Status report display after Gate 3 closure write**
   - What we know: D-04 (Claude's Discretion) — whether to re-display the full status report after writing `[x]` or just confirm inline.
   - What's unclear: Which approach produces better UX.
   - Recommendation: Confirm inline with a one-line success message ("Gate 3 closed. Status updated."), then proceed to the "Project complete" routing recommendation. Re-displaying the full report adds token cost with minimal UX value — the user just saw the report in Step 4.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is purely Markdown text edits with no external dependencies, CLI tools, services, or runtimes required.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash + grep (same as all prior phases — no external test framework) |
| Config file | `.markdownlint.jsonc` (existing, project root) |
| Quick run command | `bash cicd/lint-markdown.sh` |
| Full suite command | `bash -c 'grep -q "Gate 3 closure" skills/project/SKILL.md && grep -q "two exceptions" skills/project/SKILL.md && grep -q "Gate 3 closure" skills/project/DESIGN.md && grep -q "Gate 3 closure" skills/project/references/routing-logic.md && grep -q "Gate 3 closure" .planning/REQUIREMENTS.md && echo ALL_PASS'` |
| Estimated runtime | ~2 seconds |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| MIL-09 | Gate 3 records `[~]` from `/milestone` (already satisfied — no behavior change) | content-check | `grep -q '\[~\] Gate 3' skills/milestone/references/gate-3-checklist.md \|\| grep -rq 'In progress' skills/milestone/SKILL.md` | Wave 0 — verify grep target |
| PROJ-10 (gap) | SKILL.md Rules names both bootstrap and Gate 3 closure as exceptions | content-check | `grep -q "two exceptions\|Gate 3 closure" skills/project/SKILL.md` | ❌ Wave 0 |
| PROJ-10 (gap) | REQUIREMENTS.md PROJ-10 row has exception parenthetical | content-check | `grep -q "Gate 3 closure are the two exceptions" .planning/REQUIREMENTS.md` | ❌ Wave 0 |
| PROJ-10 (gap) | DESIGN.md DD-3 has Gate 3 closure exception paragraph | content-check | `grep -q "Gate 3 closure exception" skills/project/DESIGN.md` | ❌ Wave 0 |
| PROJ-10 (gap) | routing-logic.md has new Gate 3 closure row | content-check | `grep -q "Gate 3 still" skills/project/references/routing-logic.md` | ❌ Wave 0 |
| PROJ-10 (gap) | Gate 3 closure offer uses AskUserQuestion (D-04) | content-check | `grep -q "AskUserQuestion" skills/project/SKILL.md \| grep -c Gate` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bash cicd/lint-markdown.sh`
- **Per wave merge:** Full suite command above
- **Phase gate:** Full suite green + manual invocation review before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] Content-check grep targets for MIL-09 need verification against actual `/milestone` skill file paths before writing VALIDATION.md
- [ ] Full suite command verified runnable: all 4 grep targets point to files that will exist post-implementation

---

## Sources

### Primary (HIGH confidence)

All findings are from direct file reads of the live codebase. No external sources required — this is an internal skill authoring task.

- `skills/project/SKILL.md` — Step 5 routing structure, Gate WB offer pattern, Rules section, read-only rule
- `skills/project/references/routing-logic.md` — routing table structure, insertion position, first-match semantics
- `skills/project/references/progress-format.md` — Gate entry approved line format
- `skills/project/DESIGN.md` (DD-3, lines 86–122) — Bootstrap exception paragraph format, read-only rationale
- `.planning/REQUIREMENTS.md` — PROJ-10 text, MIL-09 text, traceability table
- `.planning/phases/11-gate3-closure/11-CONTEXT.md` — all user decisions (D-01 through D-09)
- `.planning/v1.0-MILESTONE-AUDIT.md` — GATE3-CLOSURE gap definition and impact assessment

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` — project decision log confirming Phase 4 D-05: "Gate 3 stays `[~]` In progress — `/milestone` never writes `[x]` to Gate 3"

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no libraries; all patterns verified by reading live files
- Architecture: HIGH — exact insertion points, line numbers, and verbatim text verified from source files
- Pitfalls: HIGH — derived from direct reading of the files being modified (routing table semantics, artifact validation logic)

**Research date:** 2026-04-03
**Valid until:** Changes only if the skill files are modified by another phase before this one executes. Current branch state is the reference.
