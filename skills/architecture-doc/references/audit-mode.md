# Audit-mode rules

> Canonical specification of how the `architecture-doc` synthesis
> sub-agent behaves when invoked in **Audit mode** (PRD Feature 6 /
> progress.txt Feature 7). Read by the AUDIT block of
> `references/synthesis-agent-prompt.md` -- that prompt block is a thin
> caller; the substance of every Audit-mode rule lives here. Also read
> by `SKILL.md` Step 7 for orchestrator-side validation parity.
>
> Audit mode runs only when the user chose **Audit** at the existing-
> document detection prompt in SKILL.md Step 2. Create mode is
> orthogonal and is governed by the BEGIN CREATE block of the same
> prompt template, not by this file.

## Purpose

Audit mode updates an existing `docs/ARCHITECTURE_AND_DESIGN.md`
**in place** against the current state of the codebase, while
preserving everything the user has authored. The synthesis agent
**never** rewrites the doc wholesale; it appends, prepends, and
flags -- it does not replace. Anything in the existing doc that is
not directly contradicted by the new scan findings survives the
audit untouched.

The two failure modes Audit mode is designed to prevent:

1. **Silent overwrite** -- a user spent hours hand-tuning the
   Design Decisions table, runs `/architecture-doc`, and discovers
   the next morning that the agent quietly replaced their prose
   with a regenerated table. **This must never happen.**
2. **Silent stagnation** -- the doc has drifted from the code, the
   audit produces an unchanged file, and the user has no idea what
   the scan thought was wrong. The Audit Findings block solves this:
   every divergence the scan noticed is surfaced as a row the user
   sees the next time they open the doc.

## HARD RULES

These rules are non-negotiable. Violating any of them invalidates the
Audit-mode guarantee.

### HR-1: Read-only with inline return

The synthesis agent uses only `Read`, `Glob`, and `Grep` tools. It
MUST NOT use `Write`, `Edit`, `MultiEdit`, or `NotebookEdit` at all
during Audit mode. The agent reads the existing document, composes
the updated version in memory, and returns the complete updated
document inline using the `--- BEGIN DOCUMENT ---` / `--- END DOCUMENT ---`
markers. The orchestrator writes the document to disk.

**Why:** This pattern ensures the orchestrator controls all disk writes,
which aligns with the Claude Code harness expectations for sub-agents
and provides a single point of control for all file operations.

### HR-2: Design Decisions table is append-only

New Design Decision rows are appended to the **end** of the existing
table by inserting them after the last row and before any prose that
follows the table. Existing rows are **never** edited in place, not
even to fix a typo, not even to update a citation, not even to
re-number them.

If the table currently runs `1..N` and the audit identifies three
new decisions, the new rows become `N+1`, `N+2`, `N+3`. Existing
row numbers do not shift.

If a row in the existing table is contradicted by current findings,
the audit does **not** rewrite that row. Instead the contradiction
becomes a row in the Audit Findings block (see below) with `Type =
contradiction`, citing the existing decision number and the
contradicting evidence. The user resolves the row by hand.

**Why:** the Design Decisions table is the densest concentration of
user-authored interpretation in the doc. Tradeoffs and Alternatives
columns capture judgement calls a scan agent cannot reliably
re-derive. Append-only is the cheapest preservation guarantee that
still lets new findings surface.

### HR-3: Preserve user-authored prose and non-canonical sections

The canonical template defines six required sections (Design
Decisions, Component Inventory, Data Flow, File Organization,
Deployment & Operations, Security Considerations). A user-maintained
architecture doc routinely contains **additional** sections that are
not in the canonical six -- "Performance Notes", "Migration History",
"Open Questions", a top-of-doc summary paragraph, ADR-style decision
records, etc.

These sections, and all prose inside the canonical six that the
agent did not specifically come to add or contradict, MUST be left
exactly as written. The agent does not re-flow paragraphs, does not
"improve" wording, does not normalise formatting, does not
re-order anything. Untouched is the default state.

**Why:** the user is the authoritative voice of the document. The
audit's job is to catch drift, not to impose house style.

### HR-4: Never remove non-contradicted content

Existing rows, paragraphs, list items, and sections are **never
removed** by the audit unless their content is **directly
contradicted** by new findings AND the contradiction is so concrete
that removal is the only sensible repair (e.g. a Component Inventory
row that lists a component which no longer exists in the code at
all). Even in that case, the audit prefers to surface the
contradiction in the Audit Findings block and let the user remove
the row themselves.

When in doubt, **leave it alone and flag it.**

### HR-5: Audit Findings block is the only allowed prepend

The synthesis agent is allowed to prepend exactly **one** new
top-of-doc block: the Audit Findings block specified below. It MUST
NOT prepend anything else (no banners, no "last updated" notes, no
table-of-contents). It MUST NOT modify the document title (the first
H1 line) or any frontmatter that may precede it.

If a previous Audit Findings block already exists at the top of the
doc (left over from a prior unresolved audit), the new block
**replaces** that previous block. Stale audit findings from prior
runs are never accumulated.

## The Audit Findings block

The Audit Findings block is the surface where every divergence the
audit detected is reported back to the user. It is prepended to the
top of `docs/ARCHITECTURE_AND_DESIGN.md`, immediately after the
document title (the first H1 line) and any HTML comments that
follow it, and immediately before the first H2 section.

### Block format (literal)

```markdown
## Audit Findings

_Auto-generated by /architecture-doc audit on <ISO8601>. Resolve and delete this block when done._

| # | Type | Section | Finding | Evidence | Suggested Action |
|---|------|---------|---------|----------|------------------|
| 1 | <type> | <section> | <finding> | <evidence> | <action> |
| 2 | <type> | <section> | <finding> | <evidence> | <action> |
...
```

Field rules:

- `#` is a 1-indexed integer, contiguous, in the order findings were
  detected. Numbering does not need to mean anything beyond
  uniqueness for the user to reference in conversation.
- `Type` is exactly one of the three literal tokens defined in the
  Contradiction Taxonomy below: `missing`, `contradiction`, `stale`.
  Lowercase, no other tokens accepted.
- `Section` is the canonical-template section name the finding
  applies to (e.g. `Design Decisions`, `Component Inventory`,
  `Data Flow`, `File Organization`, `Deployment & Operations`,
  `Security Considerations`). For findings that target a specific
  numbered Design Decision row, append the row number with `#`:
  `Design Decisions #4`. For findings that apply to a non-canonical
  section the user added, use that section's literal heading text.
- `Finding` is one prose sentence in present tense describing what
  the audit observed. No more than ~25 words. Be concrete: name the
  thing, not the problem class.
- `Evidence` is one or more `(src: <path>)` citations identical in
  format to the Create-mode citation discipline. At least one
  citation is required for every row -- a finding the audit cannot
  cite is a finding the audit cannot make.
- `Suggested Action` is one prose sentence telling the user what to
  do about the finding (typically "Add row", "Update wording",
  "Refresh tree", "Confirm intent", "Remove if obsolete"). Imperative
  voice. The audit never claims to have done the action -- the user
  does the action.

### Empty case

If the audit detected zero divergences (the existing doc is fully
consistent with current findings, and there are no missing
canonical sections, and there are no new decisions to append), the
Audit Findings block is **still** prepended, with the table replaced
by the literal sentence:

```markdown
## Audit Findings

_Auto-generated by /architecture-doc audit on <ISO8601>. Resolve and delete this block when done._

No divergences were detected during this audit. The existing document is consistent with the current scan findings.
```

This guarantees the user always sees explicit confirmation that the
audit ran, even when nothing changed.

### Replacement of prior Audit Findings blocks

If the existing document already contains an `## Audit Findings`
H2 immediately after the title (left over from a prior audit the
user did not resolve), the agent MUST replace the entire prior
block -- from the `## Audit Findings` heading through the last
table row or empty-case sentence -- with the freshly generated
block. In the composed document, the prior block is removed and
the new block takes its place.

Detection of "the entire prior block" stops at the first
subsequent `## ` H2 heading or at end-of-file, whichever comes
first.

## Contradiction taxonomy

The `Type` column in the Audit Findings block uses exactly three
tokens. Each token has a precise meaning and a precise repair
suggestion.

### `missing`

**Meaning:** the audit observed something in the current code or
in newly harvested existing-doc files that the existing
architecture document does not mention at all.

**Examples:**

- A new component (module, service, package) appears in the
  scan-agent findings under Component Boundaries but is not in
  the existing Component Inventory.
- A new external integration appears in Interface Contracts but
  is not in the existing Data Flow.
- A canonical-template section (one of the six) is entirely
  absent from the existing document.

**Suggested Action pattern:** "Add <thing> to <section>." or
"Backfill the <section> section."

### `contradiction`

**Meaning:** the existing document and the current findings make
**directly opposing claims** about the same thing. Not "the doc
is silent on X" (that's `missing`); not "the doc is out of date
in a soft way" (that's `stale`). Strict opposition.

**Examples:**

- The existing Decision #4 says "scan heuristics are vendored",
  but the current code reads them in place from
  `skills/project/design/`.
- The existing Component Inventory lists `legacy-auth.ts` as the
  auth surface, but the scan finds `auth/middleware.ts` is the
  current implementation and `legacy-auth.ts` no longer exists.
- The existing Deployment & Operations section says CI runs on
  CircleCI, but the repo now contains `.github/workflows/`.

**Suggested Action pattern:** "Update <thing> to reflect <new
state> or confirm intent." Audit never auto-resolves a
contradiction; the user decides whether the doc was right and
the code drifted, or whether the code is right and the doc
needs updating.

### `stale`

**Meaning:** the existing document is technically not wrong but
is missing freshness. A list that has grown, a tree that has
acquired new top-level directories, a Tradeoff column that
referenced an alternative the codebase has since adopted.

`stale` is the softest of the three types. When in doubt
between `stale` and `contradiction`, prefer `stale`.

**Examples:**

- The File Organization section's tree omits two new top-level
  directories.
- A Component Inventory row's `Interfaces` column does not
  mention an interface the scan now sees.
- An Existing Documentation citation in the existing doc points
  at a doc file that has been moved or renamed.

**Suggested Action pattern:** "Refresh <thing>." or "Add
<missing detail> to <field>."

## New Design Decisions: append rules

Aside from the Audit Findings block, the only **substantive**
change the audit may make to the body of the document is appending
new rows to the Design Decisions table. These are decisions the
audit observed in the current code that the existing table does
not capture at all (i.e. they would be `missing`-type findings,
but for Design Decisions specifically the audit appends the new
row directly **and** records a `missing` finding referencing the
new row number, so the user has a single place to see what the
audit added).

Append procedure:

1. Read the existing document and locate the Design Decisions
   table. Determine the current highest row number `N`.
2. For each new decision the audit identified:
   - Compose a row in the same column format as the existing
     table: `# | Decision | Rationale | Tradeoff | Alternatives
     Considered`. Cite at least one source path in the Decision
     or Rationale cell using the `(src: <path>)` format.
   - If the audit could not infer a Tradeoff or an Alternative,
     append `(inferred)` to the Decision cell and supply the
     most plausible Tradeoff and Alternative -- the columns are
     never blank (this matches Create-mode citation rules in
     `synthesis-agent-prompt.md`).
3. In the composed document, insert the new rows immediately after
   the last existing row of the table, preserving the table's
   column alignment and trailing blank line. Row numbers continue
   from `N+1`.
4. Record one Audit Findings row per appended Design Decision row,
   with `Type = missing`, `Section = Design Decisions #<new row
   number>`, and `Suggested Action = "Review the appended
   decision and confirm wording."` so the user knows to look at
   what the audit added.

## Citation discipline

Citations in Audit mode are identical to Create mode (see the
BEGIN CREATE block of `synthesis-agent-prompt.md`):

- Inline parenthetical `(src: <path>)` markers, paths relative
  to `{{TARGET_PATH}}`.
- Multiple sources comma-separated inside one parenthetical.
- Existing-doc citations cite the doc's relative path with the
  same `(src: <doc path>)` format.
- New Design Decision rows that the audit could not verify
  directly are marked `(inferred)` and still need a citation
  pointing at the file or doc the audit inferred from.

The Audit Findings block's `Evidence` column uses the same
format and the same hard requirement: every row needs at least
one citation.

## Structural validation hand-off

After the orchestrator writes the document returned by the agent,
SKILL.md Step 7 runs a soft structural-validation pass. The
canonical six section headers are checked; any that are missing
are emitted as a `WARN` line in `run.log` and surfaced to the
Step 8 review loop. **Audit mode does NOT abort on missing
canonical sections** -- a user-maintained doc may legitimately
omit one of the six, and the user can choose whether to backfill
it from the Step 8 prompt.

User-added sections that are not in the canonical six are
**never** flagged. Audit mode is preservation-first; unknown
sections are features, not bugs.

## Return contract

When the synthesis agent finishes, it returns a message to the
orchestrator. The first line of the return text MUST be one of
the literal status tokens below:

- `STATUS: success new_decisions=<N_new> findings=<N_findings> contradictions=<N_contra>`
  -- the audit completed successfully. `<N_new>` is the number
  of new Design Decision rows appended; `<N_findings>` is the
  total number of rows in the Audit Findings block (including
  the `missing`-type rows for the appended decisions);
  `<N_contra>` is the subset of `<N_findings>` whose `Type` is
  `contradiction`. All three are decimal integers; in the
  empty case all three are `0`.
  
  **After the status line**, include the complete updated
  document, enclosed between literal fenced-block markers:
  
  ```
  --- BEGIN DOCUMENT ---
  <full updated architecture document content here>
  --- END DOCUMENT ---
  ```
  
  The orchestrator extracts the content between these markers
  and writes it to the output path. If the markers are missing
  or malformed, the orchestrator treats this as an error.

- `STATUS: error reason=<short description>`
  -- something went wrong; no document produced. The
  orchestrator surfaces the reason and stops the run. Do not
  include the document block.

After the document block (or after the status line for error
cases), the agent MAY include a brief human-readable summary
(under 200 words) of what the audit did: which sections were
touched, how many findings of each type, and any judgement
calls worth surfacing. The orchestrator includes this in the
session summary printed by Step 10.
