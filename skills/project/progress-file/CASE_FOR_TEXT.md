# The Case for Extended Plain Text

Extended plain text — using the checkbox/indented-notes format established in
`progress-template.txt` and extended with labelled sections for gates and milestones — meets
every requirement in REQUIREMENTS.md while avoiding the structural fragility, cognitive
overhead, and readability costs that YAML introduces. YAML's apparent advantages (machine
parsability, nested structure) are largely illusory in this context: the model reading this
file is not a YAML parser, and the structure that matters most is visual, not syntactic.

---

## Requirement-by-Requirement Analysis

### FR-1: Gate tracking

**Plain text:** Gate status maps directly to the checkbox notation already established:

```
GATES
  [ ] Gate 0: Alignment
  [x] Gate WB: Working Backwards      2025-11-14
  [x] Gate 1: Scope                   2025-11-17
  [x] Gate 2: Design                  2025-11-19
  [ ] Gate 3: Milestone 1
  [ ] Gate 4: Feature 1.1
```

Status and date live on one line. A human can scan the gate block in two seconds. A skill
author writes: "find the GATES section; for each gate line, read the checkbox and trailing
date." That is a straightforward natural language instruction.

**YAML:**

```yaml
gates:
  gate_0:
    status: skipped
  gate_wb:
    status: approved
    approved_date: "2025-11-14"
  gate_1:
    status: approved
    approved_date: "2025-11-17"
```

This is more verbose (three lines per gate vs. one), and the model's instruction becomes
"find the `gates` key, then the `gate_wb` key, then read `approved_date`" — three levels of
navigation where one sufficed. Per-milestone Gate 3 and per-feature Gate 4 compound the
nesting further, producing a structure that is harder to write, harder to read, and harder to
update by hand.

The counterargument is that YAML's explicit keys make machine parsing unambiguous. This is
true in principle. In practice, the "machine" is the model itself, and the model parses
natural text at least as reliably as it navigates deep YAML hierarchies — and is far less
likely to corrupt text structure when writing than to corrupt YAML indentation.

---

### FR-2: Milestone grouping

**Plain text:**

```
## Milestone 1: Core Auth [in-progress]
   Gate 3: [ ] pending
   milestones/01-core-auth/README.md

   [ ] Feature 1.1: Login flow
   [x] Feature 1.2: Token refresh
   [ ] Feature 1.3: Logout and session expiry

## Milestone 2: Admin Portal [pending]
   Gate 3: [ ] pending
   milestones/02-admin-portal/README.md

   [ ] Feature 2.1: User management
   [ ] Feature 2.2: Audit log
```

Milestones are visually separated by `##` headers. Status is a bracketed tag on the header
line. Features are ordered as they appear. Dependency sequence is encoded in visual order —
no additional `order` or `sequence` field needed (FR-4).

**YAML:**

```yaml
milestones:
  - id: M1
    name: Core Auth
    status: in-progress
    gate_3: pending
    readme: milestones/01-core-auth/README.md
    features:
      - id: F1.1
        ...
```

The nested list structure is semantically equivalent but visually noisier. A human scanning
for "what milestone am I in?" must read past `id`, `name`, `status`, `gate_3`, and `readme`
before reaching the features. The plain text version answers that question at the `##` line.

The counterargument: YAML's explicit `status:` key is unambiguous, whereas `[in-progress]`
in a header depends on consistent bracket placement. This is a real concern but an easily
mitigated one — the format spec defines milestone status as the bracketed tag immediately
following the name, which is a single pattern to match, not a navigational hierarchy.

---

### FR-3: Feature status tracking

**Plain text:**

```
[~] Feature 1.1: Login flow
    - OAuth2 code flow with PKCE implemented
    - Session cookie set with correct SameSite/Secure flags
    - Redirect URI validation enforced
    NOTES: Started 2025-11-20. Blocked on design decision for refresh token storage —
           see Design Decision #3 in docs/ARCHITECTURE_AND_DESIGN.md.
```

Status (`[~]`), title, deliverables (bulleted lines), and free-text notes are all present and
scannable. Adding a note is a single keystroke plus text — no concern about breaking
indentation-sensitive syntax.

**YAML:**

```yaml
- id: F1.1
  title: Login flow
  status: in-progress
  deliverables:
    - OAuth2 code flow with PKCE implemented
    - Session cookie set with correct SameSite/Secure flags
    - Redirect URI validation enforced
  notes: |
    Started 2025-11-20. Blocked on design decision for refresh token storage —
    see Design Decision #3 in docs/ARCHITECTURE_AND_DESIGN.md.
```

The YAML block literal (`|`) for multi-line notes is a syntax detail that most developers
don't have memorized. Getting it wrong (forgetting the `|`, mis-indenting) silently corrupts
the field or breaks the parser. The text version has no multi-line syntax — you just keep
writing.

---

### FR-4: Ordering

**Plain text wins cleanly.** Milestones appear in the order they're listed. Features appear
in the order they're listed within each milestone. Visual order *is* dependency order. There
is no need for `sequence: 3` or `order: 2` fields. The structure communicates through layout,
exactly as UR-1 requires.

**YAML** requires either trusting list order (fragile to reordering during merges) or adding
explicit `order` fields (redundant verbosity). Plain text has no such ambiguity: what you see
is the sequence.

---

### FR-5: Artifact cross-references

**Plain text:**

```
ARTIFACTS
  PRD:           prd.md
  Architecture:  docs/ARCHITECTURE_AND_DESIGN.md
  Assessment:    docs/codebase-assessment.md
  Working Back:  docs/working-backwards.md
```

And per-milestone:

```
## Milestone 1: Core Auth [in-progress]
   milestones/01-core-auth/README.md
```

And per-feature:

```
[~] Feature 1.1: Login flow
    Plan: milestones/01-core-auth/plans/login-flow.md
```

Cross-references are human-readable paths, visually co-located with the thing they describe.

**YAML** puts these in `artifacts:` blocks that look reasonable in isolation but become
repetitive boilerplate when repeated across every milestone and feature entry. The path values
are identical in both formats; the difference is surrounding syntax overhead.

---

### FR-6: Session resilience

Both formats satisfy this requirement equally — the file is self-contained in either case.
Plain text has a marginal advantage: because its structure is easier to read at a glance, a
model starting a new session can extract the complete project state faster and with fewer
navigational instructions. YAML requires the model to know the schema in order to interpret
values; text embeds the schema in labels.

---

### UR-1: Human-readable at a glance

Plain text is designed for this. The `##` section headers, checkbox prefix symbols (`[ ]`,
`[~]`, `[x]`, `[-]`), and left-aligned NOTES field produce a format where status is readable
before the eye has moved past the first column. A developer glancing at the file while on a
call can answer "what are we building next?" in three seconds.

YAML is readable, but it is read as data, not prose. The eye must skip `status:`, `id:`,
`enabled:` keys to find values. That's fine for configuration files; it's friction for a
status board.

---

### UR-2: Human-editable with any text editor

Marking a feature complete in plain text: change `[ ]` to `[x]`. Two characters, any editor,
zero risk.

Marking a feature complete in YAML: find the `status:` key under the correct feature (which
requires navigating past `id`, `name`, `deliverables`, other fields), change the value,
ensure the indentation is still valid. The edit is not hard, but it's not trivial under
pressure, in a terminal editor, on a colleague's machine, without syntax highlighting.

Adding notes in YAML introduces the block-literal syntax question. Adding notes in text means
typing after `NOTES:`.

---

### UR-3: Diff-friendly

**Plain text diffs are surgical.** Marking a feature complete changes one character on one
line. Adding a note appends one line. Adding a feature appends four lines (status line,
two deliverables, NOTES line). These diffs are easy to review and easy to understand.

**YAML diffs depend on the writer.** If a skill re-serializes the entire YAML document on
every write (a common behavior), every invocation produces a noisy diff — key ordering may
change, blank lines may shift, comments may be stripped. Even with disciplined line-targeted
writes, any change that touches indentation cascades visually through the diff.

---

### UR-4: Low cognitive overhead for skill authors

This is YAML's strongest claimed advantage and where the counterargument deserves the most
honest treatment.

The argument for YAML: `status: approved` is unambiguous. A skill instruction can say "set
`gate_1.status` to `approved`" and there is only one place that key lives.

The counterargument: skill instructions in this pipeline are natural language prompts given
to an LLM, not Python code calling `yaml.load()`. The model does not run a YAML parser.
When a skill instruction says "find Gate 1 in the GATES section and mark it approved with
today's date," the model locates it by pattern matching against the file content — exactly
what it does for YAML keys. The difference is that text patterns (`Gate 1: [ ]`) are
*self-describing* to any reader of the file, while YAML keys (`gate_1.status`) require
knowing the schema.

The concrete risk for YAML is write corruption. When the model writes back to a YAML file, it
must preserve indentation precisely. A two-space indentation error causes a parse failure.
A forgotten colon causes a parse failure. Plain text is tolerant: extra whitespace, a missing
blank line, a slightly misaligned NOTES block — none of these break the format (UR-5 is
satisfied automatically).

Skill authors writing instructions for text can say: "in the feature block starting with
`[ ] Feature 1.1`, change `[ ]` to `[x]`." That instruction is unambiguous, minimal, and
produces a diff of exactly one character. The equivalent YAML instruction requires navigating
a three-level hierarchy, and the write operation must reconstruct valid YAML syntax.

---

### UR-5: Tolerant of minor formatting errors

Plain text wins by design. The format has no required indentation depth, no special
characters with parser-significant meaning (YAML has eight: `:`, `-`, `#`, `{`, `}`, `[`,
`]`, `|`), and no structural rules that whitespace can violate. A human who adds an extra
blank line, indents inconsistently, or uses a tab instead of spaces produces a file that is
still fully readable.

YAML fails this requirement under realistic editing conditions. Indentation is
structure-defining. Misaligned keys silently change the parsed hierarchy. A `:` in a string
value requires quoting. These are not theoretical concerns — they are the reason "YAML
errors" are a recurring category in every software team that uses YAML-heavy tooling.

---

### NFR-1: Backward compatibility with progress.txt patterns

Plain text is the existing convention. The checkbox notation (`[ ]`, `[~]`, `[x]`, `[-]`),
the NOTES field, the section headers — these come directly from `progress-template.txt`.
Adopting extended plain text is an evolution; adopting YAML is a replacement.

A team using the existing `create-prd` pipeline can migrate to the new format by reading one
section header explanation. There is nothing new to learn about the checkbox convention.

---

### NFR-2: Token efficiency

Consider a concrete comparison for a single feature entry:

**Plain text (6 lines, ~70 tokens):**
```
[~] Feature 1.1: Login flow
    - OAuth2 code flow with PKCE implemented
    - Session cookie set with correct SameSite/Secure flags
    - Redirect URI validation enforced
    NOTES: Started 2025-11-20.
           Plan: milestones/01-core-auth/plans/login-flow.md
```

**YAML (11 lines, ~110 tokens):**
```yaml
- id: F1.1
  title: Login flow
  status: in-progress
  deliverables:
    - OAuth2 code flow with PKCE implemented
    - Session cookie set with correct SameSite/Secure flags
    - Redirect URI validation enforced
  notes: "Started 2025-11-20."
  plan: milestones/01-core-auth/plans/login-flow.md
  gate_4: pending
```

The YAML version is ~57% more verbose for the same information. The progress file is read on
every skill invocation. For a project with 10 features across two milestones, that difference
compounds to 400–500 tokens per invocation — not negligible in a skill pipeline where context
budget is finite.

---

### NFR-3: Single file

Both formats satisfy this requirement equally.

---

## Concrete Example: Two Milestones, Five Features

What follows is a complete example of the extended plain text format for a project with
two milestones, three features in milestone 1, and two features in milestone 2, with all
gates tracked.

```
# Progress: Payments Platform
# PRD: prd.md
# Architecture: docs/ARCHITECTURE_AND_DESIGN.md
# Status: [ ] pending  [~] in-progress  [x] complete  [-] skipped

ARTIFACTS
  PRD:           prd.md
  Architecture:  docs/ARCHITECTURE_AND_DESIGN.md
  Assessment:    docs/codebase-assessment.md
  Working Back:  docs/working-backwards.md

GATES
  [-] Gate 0: Alignment                 (skipped — greenfield)
  [x] Gate WB: Working Backwards        2025-11-14
  [x] Gate 1: Scope                     2025-11-17
  [x] Gate 2: Design                    2025-11-19
  [~] Gate 3: Milestone 1 — approved    2025-11-20
  [ ] Gate 3: Milestone 2 — pending
  [x] Gate 4: Feature 1.1               2025-11-21
  [~] Gate 4: Feature 1.2               2025-11-23
  [ ] Gate 4: Feature 1.3
  [ ] Gate 4: Feature 2.1
  [ ] Gate 4: Feature 2.2

────────────────────────────────────────────────

## Milestone 1: Core Auth [in-progress]
   milestones/01-core-auth/README.md

[x] Feature 1.1: OAuth2 login flow
    - Authorization code flow with PKCE implemented
    - Session cookie set with SameSite=Strict; Secure
    - Redirect URI allowlist enforced
    NOTES: Started 2025-11-21. CODE COMPLETE: auth/oauth.py, auth/session.py; 18 tests
           pass; lint clean. Completed 2025-11-22.
           Plan: milestones/01-core-auth/plans/oauth-login.md

[~] Feature 1.2: Token refresh
    - Refresh token rotation implemented
    - Revocation endpoint functional
    Plan: milestones/01-core-auth/plans/token-refresh.md
    NOTES: Started 2025-11-23. Blocked on key rotation strategy —
           see Design Decision #4 in docs/ARCHITECTURE_AND_DESIGN.md.

[ ] Feature 1.3: Logout and session expiry
    - All sessions for user invalidated on explicit logout
    - Idle expiry at 30 min enforced server-side
    Plan: milestones/01-core-auth/plans/logout.md
    NOTES:

────────────────────────────────────────────────

## Milestone 2: Admin Portal [pending]
   milestones/02-admin-portal/README.md

[ ] Feature 2.1: User management UI
    - List, search, and deactivate users
    - Role assignment from admin interface
    Plan: milestones/02-admin-portal/plans/user-mgmt.md
    NOTES:

[ ] Feature 2.2: Audit log viewer
    - Last 90 days of events queryable by actor, resource, action
    - CSV export functional
    Plan: milestones/02-admin-portal/plans/audit-log.md
    NOTES:
```

Observations on this example:

- **Gate status is scannable in a single block.** A reviewer can see in three seconds that
  Gates 0–2 are done, Milestone 1 is in progress, and Milestone 2 hasn't started.
- **Active work is locatable immediately.** The `[~]` symbol draws the eye to Feature 1.2
  without scanning every line.
- **Cross-references are co-located.** The plan path lives with the feature it describes.
- **Free-text notes are unconstrained.** The Feature 1.1 note records start date, code
  complete evidence, and completion date exactly as the template specifies — no quoting, no
  escaping, no block literal syntax.
- **Adding Milestone 3 later is an append.** No restructuring, no reindexing.

---

## Addressing the Strongest Counterarguments

### "YAML enables reliable automated parsing (FR-1, FR-2)"

True in general. False for this specific context. The consumer of this file is an LLM-based
skill, not a Python script. The model does not call `yaml.safe_load()`. It reads the file
content as text and extracts information using pattern matching and comprehension — the same
cognitive operation it uses for plain text.

The question is not "which format is more machine-parsable in the abstract?" but "which
format does this specific model parse more reliably with simpler instructions?" The evidence
favors text: fewer navigation levels, self-describing labels, and no syntax that the model
must reconstruct exactly when writing back.

### "YAML's explicit keys eliminate ambiguity in milestone grouping (FR-2)"

The implicit claim is that `## Milestone 1: Core Auth [in-progress]` is ambiguous. It is not.
The `##` header marks a section boundary. The text before the bracket is the name. The
bracketed tag is the status. This three-part pattern is consistent, memorable, and easily
specified in a skill instruction. A skill that writes a new milestone header writes one line
following one pattern — no multi-field object to construct.

### "Plain text parsability is fragile if status tags vary (UR-4)"

This is the most legitimate concern. If status notation is inconsistent — `[in progress]` vs.
`[in-progress]` vs. `[~]` — the model may misread status. The mitigation is to define exactly
one canonical notation per status type in the format spec and include it in the file header
(`# Status: [ ] pending  [~] in-progress  [x] complete  [-] skipped`). The header is
present in every file, visible on load, and establishes the contract. YAML mitigates this
by constraining values to a defined enum — but that constraint lives in the skill instruction,
not the format. The same instruction-level constraint applies to plain text.

---

## Evaluation Summary

| Criterion | Plain Text | YAML | Notes |
|---|---|---|---|
| **Readability** (UR-1) | 5 | 3 | Checkbox prefix + section headers beat key-value scanning for status boards |
| **Editability** (UR-2, UR-5) | 5 | 2 | Text edits are two keystrokes; YAML edits risk indentation corruption |
| **Parsability** (UR-4) | 4 | 3 | LLM pattern-matches both; text is simpler to navigate and safer to write back |
| **Expressiveness** (FR-1 – FR-6) | 5 | 5 | Both represent all required state; text does it with fewer tokens |
| **Conciseness** (NFR-2) | 5 | 3 | ~57% more verbose per feature in YAML; compounds across all invocations |
| **Familiarity** (NFR-1) | 5 | 1 | Extends existing `progress-template.txt`; YAML is a full convention change |
| **Total** | **29/30** | **17/30** | |

YAML's parsability score (3) is not low because YAML is hard to parse in general — it is
lower because the consumer is a language model writing natural-language instructions, not a
typed runtime parser. In that context, simpler structural patterns produce fewer skill errors.

Plain text extended with labelled sections, checkbox notation, and co-located cross-references
satisfies every functional, usability, and non-functional requirement while costing fewer
tokens, requiring less syntax knowledge, and staying compatible with the established
convention. The format that communicates through layout will always win over the format that
requires schema navigation when the primary audience is human eyes and LLM pattern matching.
