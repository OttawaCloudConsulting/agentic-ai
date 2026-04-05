# Phase 8: Fix Greenfield Routing - Research

**Researched:** 2026-04-03
**Domain:** Markdown documentation — routing-logic.md table + SKILL.md prose
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `[-]` (greenfield skip) is treated as fully equivalent to `[x]` (approved) for ALL routing decisions downstream — not just Gate WB and Gate 1 advancement. Gate 0 skipped = Gate 0 effectively approved.
- **D-02:** The Gate WB offer condition in `SKILL.md` Step 5 is updated from "If Gate 0 is approved" to "If Gate 0 is approved or skipped (greenfield)" — i.e., `[x]` or `[-]`. Same Yes/Skip/Defer prompt either way. No stronger nudge for greenfield — standard offer is sufficient.
- **D-03:** Fix via an equivalence note added to the `routing-logic.md` Notes section (at bottom of routing table), not via new rows or in-place row rewrites. Note states: "`[-]` (skipped) is treated as equivalent to `[x]` (approved) for all Gate 0 routing — greenfield skip counts as Gate 0 resolved." Keeps the table clean; existing rows implicitly cover both states.

### Claude's Discretion

- Exact wording of the equivalence note
- Whether to add `[-]` alongside `[x]` in any inline table row references for clarity (cosmetic)
- Exact prose update to SKILL.md Step 5 condition block

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROJ-03 | `/project` routes user to the correct next skill by outputting a plain-language instruction | routing-logic.md row evaluation must cover Gate 0 `[-]` state so second `/project` invocation routes correctly |
| PROJ-06 | `/project` offers Gate WB when no `working-backwards.md` exists and customer outcome is unclear; records `[ ] Pending` if deferred | Gate WB offer condition in SKILL.md Step 5 must fire for `[-]` as well as `[x]` |
</phase_requirements>

---

## Summary

Phase 8 is a surgical two-file documentation fix. The gap identified in the v1.0 audit (`GREENFIELD-ROUTING`, `GREENFIELD-E2E`) has two independent symptoms with independent fixes in two Markdown files.

**Symptom 1 — Routing table ambiguity:** `routing-logic.md` rows 15–17 assume Gate 0 is either `[ ]` (never started) or `[x]` (approved). Gate 0 `[-]` (greenfield skip) has no explicit coverage. A user who bootstraps a greenfield project and immediately invokes `/project` a second time reaches an unmatched routing state. The fix is a Notes-section equivalence note (D-03), not a new table row — existing `[x]` rows implicitly handle `[-]` once the equivalence is documented.

**Symptom 2 — Gate WB offer never fires for greenfield:** SKILL.md Step 5 says "If Gate 0 is approved" — matching `[x]` only. Since greenfield projects record `[-]`, the offer condition is never satisfied. The fix is a one-line prose update expanding the condition to include `[-]` as a trigger (D-02).

Both changes are additive/clarifying edits to existing structures. No structural rewrites, no new files, no dependency changes. The routing table rows stay unchanged; the equivalence note sits in the already-existing Notes section. SKILL.md Step 5's condition block gets a single expansion.

**Primary recommendation:** Execute as a single-wave plan with two tasks: (1) add equivalence note to `routing-logic.md`, (2) update Gate WB offer condition in `SKILL.md` Step 5. Each task is independently verifiable with `grep`.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Markdown (plain text) | — | Skill documentation format | Established project convention; all skill files are `.md` |

No library dependencies. This phase edits Markdown documentation files only.

### Alternatives Considered

None applicable — file format and location are locked by established project conventions.

---

## Architecture Patterns

### Established File Structures

```
skills/project/
├── SKILL.md                    # Main flow controller — Step 5 Gate WB condition lives here
├── DESIGN.md                   # Background context (DD-11, D-08, D-09) — NOT modified
└── references/
    └── routing-logic.md        # Routing decision table + Notes section — receives equivalence note
```

### Pattern 1: routing-logic.md Notes Section Pattern

**What:** The `routing-logic.md` file uses a `## Routing Table` Markdown table followed by a `Notes:` prose block. Supplementary clarifications that apply across multiple rows live in the Notes block, not in the table itself.

**When to use:** When a clarification applies to the table as a whole or to an interpretation of existing rows rather than introducing a new routing state.

**Current Notes block (lines 29–36 of routing-logic.md):**
```markdown
Notes:

- The "Alternatives" column implements D-04 -- only actions valid for the current state appear. ...
- "Bootstrap" is an internal action performed by `/project` itself -- it does not route to another skill.
- "Offer Gate WB" is also handled internally by `/project` via `AskUserQuestion`.
- When open spikes exist, `/spike` is added to the alternatives list ...
- The "customer outcome unclear" condition for Gate WB offer is evaluated by Claude ...
```

The new equivalence note slots into this list as another bullet. No structural change needed.

**Target addition (append to Notes list):**
```markdown
- `[-]` (skipped) is treated as equivalent to `[x]` (approved) for all Gate 0 routing.
  Greenfield projects skip Gate 0 (codebase alignment is not applicable), but the skip
  counts as Gate 0 resolved for all downstream routing purposes.
```

### Pattern 2: SKILL.md Step 5 Inline Condition Pattern

**What:** SKILL.md Step 5 uses bold inline conditions in the form `**If [condition], ... -- offer Gate WB ...**`.

**Current text (lines 129–131 of SKILL.md):**
```markdown
**Gate WB offer (DD-11, D-08):** If Gate 0 is approved, no `docs/working-backwards.md`
exists, Gate WB has not been offered yet, and the customer outcome is unclear -- offer
Gate WB using `AskUserQuestion` with options:
```

**Target text (D-02, following CONTEXT.md specifics):**
```markdown
**Gate WB offer (DD-11, D-08):** If Gate 0 is approved (`[x]`) or skipped (`[-]` greenfield),
no `docs/working-backwards.md` exists, Gate WB has not been offered yet, and the customer
outcome is unclear -- offer Gate WB using `AskUserQuestion` with options:
```

### Anti-Patterns to Avoid

- **Adding a new routing table row for `[-]`:** D-03 explicitly rejects this approach. The equivalence note is the prescribed mechanism. Adding a row would duplicate and potentially desync with `[x]` rows.
- **Editing the routing table rows in-place:** Adding `[-]` inline to existing rows (e.g., changing "Gate 0 approved" to "Gate 0 approved or skipped" in the table cell) is cosmetic-only discretion, subordinate to the Notes note being added first.
- **Touching any file other than `routing-logic.md` and `SKILL.md`:** CONTEXT.md confirms the change is self-contained. No other skills reference Gate 0 `[-]` state explicitly.
- **Modifying `routing-logic.md` Gate WB Offer Logic section:** The table at lines 74–80 already correctly handles `[-]` for the Gate WB _state_ (post-offer). The gap is only in the _offer trigger_ condition in SKILL.md Step 5 and the routing table's _implicit_ coverage of `[-]`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Expressing `[-]` equivalence | Complex conditional routing with multiple `[-]` rows | Single Notes-section equivalence note | D-03 decision; keeps table clean and single-source-of-truth for the equivalence |
| Verifying changes | Manual file inspection | `grep` content assertions | Same pattern used across all prior phases; fast and scriptable |

---

## Common Pitfalls

### Pitfall 1: Incomplete Gate WB Offer Condition Update

**What goes wrong:** Only the SKILL.md condition is updated but the routing-logic.md section "Gate WB Offer Logic" table (lines 74–80) is left as-is, leaving a documentation inconsistency between SKILL.md and routing-logic.md.

**Why it happens:** The Gate WB Offer Logic table in routing-logic.md already handles the post-offer `[-]` state correctly (rows for `[x]` approved and `[-]` skipped). The offer-trigger condition is solely in SKILL.md Step 5. Conflating "when to offer" with "what to do after offering" leads to unnecessary edits in routing-logic.md.

**How to avoid:** The Gate WB Offer Logic table in `routing-logic.md` describes what happens AFTER the offer has been made or skipped (states `[x]`, `[-]`, `[ ] Pending`). It does NOT need modification. Only the SKILL.md Step 5 prose changes.

**Warning signs:** If you find yourself editing the Gate WB Offer Logic table in routing-logic.md, stop — that table is not broken.

### Pitfall 2: Ambiguous Wording in Equivalence Note

**What goes wrong:** Note wording is vague (e.g., "greenfield is like approved") and a future reader is uncertain whether `[-]` triggers Gate WB offer or is treated as Gate WB already skipped.

**Why it happens:** `[-]` appears in two different contexts: Gate 0 status and Gate WB status. The equivalence applies to Gate 0 `[-]` only.

**How to avoid:** The note must specify "Gate 0 routing" explicitly. CONTEXT.md's specifics section provides the canonical phrasing: "Greenfield projects skip Gate 0 (codebase alignment is not applicable), but the skip counts as Gate 0 resolved for all downstream routing purposes."

### Pitfall 3: Skipping the Discretion Decision on Inline Table Cosmetics

**What goes wrong:** The planner leaves open whether to add `[-]` alongside `[x]` in the routing table rows themselves (e.g., "Gate 0 approved `[x]` or skipped `[-]`"), causing ambiguity during implementation.

**Why it happens:** CONTEXT.md marks this as Claude's discretion without a prescriptive answer.

**How to avoid:** Decide in the plan whether inline table cosmetic edits are in scope. Recommendation: keep the routing table rows as-is (no inline additions) — the Notes note is the single source of truth for the equivalence. Cosmetic additions risk table misalignment and add no logical value.

---

## Code Examples

### routing-logic.md — Current Notes Block (lines 29–36)

```markdown
Notes:

- The "Alternatives" column implements D-04 -- only actions valid for the current state appear. Do not show `/plan` if no milestone exists. Do not show `/build` if no planned features exist.
- "Bootstrap" is an internal action performed by `/project` itself -- it does not route to another skill.
- "Offer Gate WB" is also handled internally by `/project` via `AskUserQuestion`.
- When open spikes exist, `/spike` is added to the alternatives list for any state where it is contextually relevant (post-Gate 1 states).
- The "customer outcome unclear" condition for Gate WB offer is evaluated by Claude based on available project context -- if the project's purpose and target customer are well-defined from existing artifacts, Gate WB may not be offered.
```

### routing-logic.md — After Fix (new bullet appended)

```markdown
Notes:

- The "Alternatives" column implements D-04 -- only actions valid for the current state appear. Do not show `/plan` if no milestone exists. Do not show `/build` if no planned features exist.
- "Bootstrap" is an internal action performed by `/project` itself -- it does not route to another skill.
- "Offer Gate WB" is also handled internally by `/project` via `AskUserQuestion`.
- When open spikes exist, `/spike` is added to the alternatives list for any state where it is contextually relevant (post-Gate 1 states).
- The "customer outcome unclear" condition for Gate WB offer is evaluated by Claude based on available project context -- if the project's purpose and target customer are well-defined from existing artifacts, Gate WB may not be offered.
- `[-]` (skipped) is treated as equivalent to `[x]` (approved) for all Gate 0 routing. Greenfield projects skip Gate 0 (codebase alignment is not applicable), but the skip counts as Gate 0 resolved for all downstream routing purposes.
```

### SKILL.md Step 5 — Current Gate WB Offer Condition (lines 129–131)

```markdown
**Gate WB offer (DD-11, D-08):** If Gate 0 is approved, no `docs/working-backwards.md`
exists, Gate WB has not been offered yet, and the customer outcome is unclear -- offer
Gate WB using `AskUserQuestion` with options:
```

### SKILL.md Step 5 — After Fix

```markdown
**Gate WB offer (DD-11, D-08):** If Gate 0 is approved (`[x]`) or skipped (`[-]` greenfield),
no `docs/working-backwards.md` exists, Gate WB has not been offered yet, and the customer
outcome is unclear -- offer Gate WB using `AskUserQuestion` with options:
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash + grep (no external test framework — skill files validated via content checks) |
| Config file | none — validation via file content assertions |
| Quick run command | `bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && echo PASS'` |
| Full suite command | `bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && grep -q "skipped.*greenfield\|greenfield.*skipped\|\[-\].*greenfield" skills/project/SKILL.md && echo ALL_PASS'` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROJ-03 | routing-logic.md Notes contains equivalence note for `[-]` | content | `grep -q 'equivalent to' skills/project/references/routing-logic.md && echo PASS` | routing-logic.md exists |
| PROJ-03 | Equivalence note mentions Gate 0 routing scope | content | `grep -q 'Gate 0 routing\|Gate 0 resolved' skills/project/references/routing-logic.md && echo PASS` | routing-logic.md exists |
| PROJ-06 | SKILL.md Step 5 Gate WB condition includes `[-]` | content | `grep -q '\[-\]' skills/project/SKILL.md && echo PASS` | SKILL.md exists |
| PROJ-06 | SKILL.md Step 5 condition references greenfield context | content | `grep -q 'greenfield' skills/project/SKILL.md && echo PASS` | SKILL.md exists |

### Sampling Rate

- **Per task commit:** `bash -c 'grep -q "equivalent to" skills/project/references/routing-logic.md && echo PASS'`
- **Per wave merge:** Full suite command above
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — both target files (`routing-logic.md` and `SKILL.md`) exist on disk. No new files, no framework setup required.

---

## State of the Art

| Old State | Fixed State | Context |
|-----------|-------------|---------|
| Gate 0 `[-]` has no explicit routing coverage | Equivalence note in routing-logic.md Notes covers `[-]` = `[x]` for all Gate 0 downstream routing | Gap identified in v1.0 audit (GREENFIELD-ROUTING) |
| Gate WB offer fires only for `[x]` Gate 0 | Gate WB offer fires for `[x]` or `[-]` Gate 0 | Same gap; SKILL.md Step 5 condition fix |
| Greenfield E2E flow PARTIAL | Greenfield E2E flow COMPLETE (second `/project` invocation routes correctly) | GREENFIELD-E2E flow gap from audit |

---

## Environment Availability

Step 2.6: SKIPPED — This phase is purely documentation edits to two Markdown files. No external tools, runtimes, services, or CLI utilities required beyond the text editor/Write tool.

---

## Open Questions

None. All decisions are locked (D-01, D-02, D-03). The CONTEXT.md specifics section provides the exact target wording for both changes. No ambiguity remains.

---

## Sources

### Primary (HIGH confidence)

- `skills/project/references/routing-logic.md` — Current routing table and Notes section; exact target for equivalence note
- `skills/project/SKILL.md` — Current Step 5 Gate WB offer condition text (lines 129–131); exact target for prose update
- `.planning/phases/08-greenfield-routing/08-CONTEXT.md` — Locked decisions (D-01, D-02, D-03) and canonical target wording
- `.planning/v1.0-MILESTONE-AUDIT.md` — GREENFIELD-ROUTING gap definition; GREENFIELD-E2E flow gap; confirms exactly what is broken and where
- `.planning/REQUIREMENTS.md` — PROJ-03 and PROJ-06 requirement text and traceability

### Secondary (MEDIUM confidence)

- `skills/project/DESIGN.md` DD-11 — Confirms Gate WB offer intent: "The trigger is strategic (unclear customer outcome), not structural (empty directory)"; confirms greenfield projects are a primary use case
- `.planning/phases/06-build/06-VALIDATION.md` — Reference for Nyquist validation pattern used across all prior phases

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no external dependencies; plain Markdown edits to existing files
- Architecture patterns: HIGH — current file structure and exact text verified by direct file reads
- Pitfalls: HIGH — identified from direct inspection of routing-logic.md and SKILL.md against audit findings
- Validation: HIGH — grep-based content assertions match prior phase validation patterns

**Research date:** 2026-04-03
**Valid until:** This research is stable indefinitely — references only internal project files with no external dependencies.
