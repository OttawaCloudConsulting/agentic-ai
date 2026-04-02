# The Case for YAML as the Progress File Format

YAML is the correct format for the progress file because it provides explicit, machine-readable structure that maps directly to the data model the requirements define, while remaining fully readable and editable by humans in any text editor. The plain text template solves a presentation problem but leaves the structural problem entirely to convention — a bet that breaks the moment a human edits casually or a skill author misreads indentation. YAML solves both problems simultaneously.

---

## Requirement-by-Requirement Analysis

### FR-1: Gate tracking

The requirements specify six distinct gates, each with a status value drawn from a controlled vocabulary and an optional date field. Plain text has no way to enforce this — it relies on the reader and writer agreeing on the format of a prose line. Consider what gate tracking looks like in each format:

**Plain text (implied, no standard exists in the template):**
```
Gate 0: approved 2026-01-15
Gate WB: skipped
Gate 1: approved 2026-01-20
Gate 2: pending
```

This is readable, but there is no schema. A skill author writing instructions for `/milestone` must describe in prose what the line looks like, how to find it, and how to update it in place. The model must locate a specific line by pattern match and overwrite it — a brittle operation.

**YAML:**
```yaml
gates:
  gate_0:   { status: approved, date: 2026-01-15 }
  gate_wb:  { status: skipped }
  gate_1:   { status: approved, date: 2026-01-20 }
  gate_2:   { status: pending }
  gate_3:   {}  # per-milestone, see milestones below
  gate_4:   {}  # per-feature, see features below
```

Each gate is a named key. Status and date are named sub-fields. A skill instruction can say "set `gates.gate_2.status` to `approved` and `gates.gate_2.date` to today" — unambiguous, location-independent, and correct regardless of what else changed nearby. FR-1 is fully and cleanly met.

---

### FR-2: Milestone grouping

The requirements define milestones as first-class objects with an identifier, name, status, and an ordered list of features. The plain text template does offer milestone grouping via `## Phase N: [Name]` headers — this works as visual separation. But status lives nowhere. There is no place in the plain text template to record that Milestone 1 is `approved` while Milestone 2 is `pending`. A reader can infer it from gate state and feature status, but that inference requires reading the entire file and reasoning about it.

YAML makes milestone status explicit:

```yaml
milestones:
  - id: M1
    name: Core API
    status: in-progress
    gate_3: { status: approved, date: 2026-02-01 }
    features: [...]
  - id: M2
    name: Dashboard
    status: pending
    gate_3: { status: pending }
    features: [...]
```

The `status` field is a direct answer to "what is the state of this milestone?" — no inference required. FR-2 is fully met.

---

### FR-3: Feature status tracking

Each feature needs status (from a five-value controlled vocabulary), 2–4 deliverable bullets, and a free-text notes field. The plain text template handles this with checkbox notation and indented bullets, which is readable. But status is encoded in the checkbox character (`[ ]`, `[~]`, `[x]`, `[-]`), which means changing a feature's status requires modifying a specific character inside a compound expression — error-prone for both humans and models.

YAML separates status from display:

```yaml
- id: F1.1
  title: Authentication endpoint
  status: complete
  gate_4: { status: approved, date: 2026-02-05 }
  deliverables:
    - JWT token issuance on POST /auth/login
    - Token validation middleware applied to all protected routes
    - Refresh token rotation with 7-day expiry
  notes: |
    Started 2026-02-03. Code complete 2026-02-07: 4 files changed,
    18 tests added, all pass. Completed 2026-02-08.
```

Status is a named field with a clear value. Notes is a multi-line string block — YAML's `|` literal block scalar preserves newlines cleanly and allows arbitrary prose without any escaping. FR-3 is fully met.

---

### FR-4: Ordering

This is where YAML's sequence type earns its place. A YAML list (`- item`) is ordered by definition. The order of milestones in the `milestones` list is the canonical order. The order of features within each milestone's `features` list is the canonical order. No numbering convention, no header hierarchy, no implied ordering from file position — the structure itself encodes the order.

Plain text encodes order through file position and numbering conventions like `Feature 2.1`, `Feature 2.2`. This works until a human inserts a feature out of order, uses a different numbering style, or omits the prefix. The convention is not enforced. YAML's list structure is inherently ordered and does not rely on convention. FR-4 is fully met.

---

### FR-5: Artifact cross-references

The requirements list six artifact paths that the progress file must reference. In plain text, these would appear as comment lines or a header block — readable, but structurally invisible. A skill looking for the PRD path must scan the file for a line that looks like a path, which is fragile if the path format changes or a comment precedes it.

YAML gives each artifact a named key:

```yaml
artifacts:
  prd: prd.md
  architecture: docs/ARCHITECTURE_AND_DESIGN.md
  codebase_assessment: docs/codebase-assessment.md
  working_backwards: docs/working-backwards.md
```

Milestone-level and feature-level artifact references can be co-located with their objects:

```yaml
- id: M1
  name: Core API
  readme: milestones/01-core-api/README.md
  features:
    - id: F1.1
      plan: milestones/01-core-api/plans/authentication.md
```

A skill can retrieve `milestones[0].readme` without scanning. FR-5 is fully met.

---

### FR-6: Session resilience

Both formats can be self-contained. But YAML's named fields make the file more reliably interpretable across context gaps. When a new session reads the file, it does not need to understand a formatting convention — it reads keys and values. The schema is embedded in the structure. A session starting cold can answer "what is the current phase?" by reading `current_phase`, "what is the active milestone?" by reading `active_milestone`, and "what is next?" by reading the first feature with `status: pending` in the active milestone's feature list. No prose parsing, no convention recall. FR-6 is strongly met.

---

### UR-1: Human-readable at a glance

This is the strongest argument for plain text, and it deserves honest treatment. The existing `progress.txt` template with checkbox notation is genuinely fast to scan. `[x]`, `[~]`, `[ ]`, `[-]` are compact and visually distinct.

YAML does not match this out of the box — a naive YAML rendering is verbose. But YAML does not preclude compact notation. The two can coexist:

```yaml
features:
  - { id: F1.1, status: complete,     title: Authentication endpoint }
  - { id: F1.2, status: in-progress,  title: Authorization middleware }
  - { id: F1.3, status: pending,      title: Rate limiting }
```

This single-line flow style is as scannable as the checkbox format. The active milestone and current gate can be placed at the top of the file as a summary block, giving any reader the "where are we?" answer in under five seconds. UR-1 is met with intentional layout.

---

### UR-2: Human-editable with any text editor — and the counterargument

This is the strongest counterargument for YAML, and it is legitimate. Changing a feature status in plain text means replacing one character: `[ ]` becomes `[x]`. In YAML, it means changing `status: pending` to `status: complete` — still one field, but YAML is sensitive to indentation level. A developer who does not know YAML might accidentally change indentation, break a multi-line block scalar, or forget to quote a value containing a colon.

The honest answer is: YAML does impose a small learning overhead. However, the edit operations called out in UR-2 — changing a status, adding a note, re-opening a gate — are all simple scalar changes in YAML. They do not require understanding nested structures, block scalars, or anchors. The dangerous operations (rearranging list items, adding new milestones) are ones a developer would approach carefully in any format.

What YAML buys in exchange for this small overhead is that hand edits are validated by structure. If a developer inserts a note at the wrong indentation level in plain text, it silently becomes part of a different field's visual block, and neither the human nor the skill detects it. In YAML, the same mistake produces a parse error — visible, correctable, not silently wrong. This trade (explicit failure vs. silent corruption) is the right one for a state file.

---

### UR-3: Diff-friendly

YAML with one-field-per-line style produces clean, minimal diffs. A status change touches one line:

```diff
-  status: pending
+  status: complete
```

Adding a note appends to the `notes` block scalar without touching surrounding lines. Adding a new feature appends a new list item at the end of the milestone's feature list — a clean, readable insert. Plain text achieves similar diffs when edits are simple, but its lack of field boundaries means a note that wraps across lines or a status embedded in a checkbox can force a diff that touches multiple non-adjacent lines. UR-3 is met by YAML with careful formatting conventions.

---

### UR-4: Low cognitive overhead for skill authors

This is where YAML wins decisively. Consider the instruction a skill author must write for updating a gate status:

**Plain text instruction:** "Find the line starting with `Gate 1:` and replace the word `pending` with `approved`, then append the current date."

**YAML instruction:** "Set `gates.gate_1.status` to `approved` and `gates.gate_1.date` to today's date in YYYY-MM-DD format."

The plain text instruction requires the model to locate, pattern-match, and surgically edit a line — with no structural guidance about where that line is. The YAML instruction is a direct key-path assignment. The model does not need to know where in the file the key lives; YAML's structure provides the address. UR-4 is strongly met.

---

### UR-5: Tolerant of minor formatting errors — and the counterargument

This is the second legitimate counterargument. YAML is sensitive to indentation. Plain text forgives extra whitespace, blank lines, and irregular spacing. A developer who adds an extra space before a YAML list item can break the parse.

The mitigation is twofold. First, the skill instructions that read this file are AI models — they can tolerate and recover from minor YAML malformations that a strict parser would reject, because they read the file as text and interpret it structurally. Second, the operations developers actually perform on this file (changing a single value, adding a note line) are low-risk for indentation errors. The risky operations (adding a new nested object) are ones that even experienced developers would approach carefully.

The plain text format's tolerance is real, but it is also the reason silent corruption is possible. A misplaced note in plain text looks correct and reads as correct — it just attaches to the wrong context. YAML's intolerance of structural errors is a feature, not a bug.

---

### NFR-1: Backward compatibility with progress.txt patterns

The checkbox notation is not lost with YAML. YAML's status field can use the same values as the checkbox legend: `pending`, `in-progress`, `complete`, `skipped`. The visual legend from `progress.txt` can be reproduced at the top of the YAML file as a comment:

```yaml
# Status values: pending | in-progress | complete | skipped
```

More directly, the deliverables list within each feature can use checkbox-style markers in the content if desired, since YAML string values are arbitrary text. The meaningful conventions survive the format change. NFR-1 is substantially met.

---

### NFR-2: Token efficiency

YAML is more verbose than the plain text template for simple cases — key names add tokens. But YAML's named fields eliminate the need for skill instructions to carry their own in-context description of the file format. A plain text file requires the skill to include prose like "the file uses `[x]` for complete, `[~]` for in-progress, the NOTES: field follows the bullet list, phases are delimited by `## Phase N:` headers." This explanation occupies context on every invocation. A YAML file's schema is self-describing; the skill instruction can be shorter.

The net token cost is approximately neutral at small scale and favors YAML at larger scale, as the format documentation overhead disappears. NFR-2 is met.

---

### NFR-3: Single file

Not a format-specific requirement — both YAML and plain text are single files. Both are version-controllable in git. YAML meets NFR-3 trivially.

---

## Concrete Example: 2 Milestones, 5 Features, Gates Tracked

```yaml
# Project Progress — Payment Gateway Integration
# Status values: pending | in-progress | complete | skipped
# Last updated: 2026-03-31

project:
  title: Payment Gateway Integration
  active_milestone: M1
  current_gate: gate_4

artifacts:
  prd: prd.md
  architecture: docs/ARCHITECTURE_AND_DESIGN.md
  codebase_assessment: docs/codebase-assessment.md
  working_backwards: docs/working-backwards.md

gates:
  gate_0:  { status: approved,  date: 2026-01-10 }
  gate_wb: { status: skipped }
  gate_1:  { status: approved,  date: 2026-01-15 }
  gate_2:  { status: approved,  date: 2026-01-22 }

milestones:

  - id: M1
    name: Core Payment Processing
    status: in-progress
    readme: milestones/01-core-payment/README.md
    gate_3: { status: approved, date: 2026-02-01 }
    features:

      - id: F1.1
        title: Stripe API client setup
        status: complete
        gate_4: { status: approved, date: 2026-02-05 }
        plan: milestones/01-core-payment/plans/stripe-client.md
        deliverables:
          - Stripe SDK initialized with environment-scoped API keys
          - Client wrapper with retry logic and structured error types
          - Integration test against Stripe sandbox passes
        notes: |
          Started 2026-02-03. Code complete 2026-02-07: 3 files changed,
          12 tests added, all pass. Completed 2026-02-08.

      - id: F1.2
        title: Charge creation endpoint
        status: in-progress
        gate_4: { status: approved, date: 2026-02-10 }
        plan: milestones/01-core-payment/plans/charge-endpoint.md
        deliverables:
          - POST /payments/charge accepts amount, currency, payment method
          - Idempotency key enforced at database level
          - Webhook confirmation updates charge status asynchronously
        notes: |
          Started 2026-02-11. Idempotency key logic complete. Webhook
          handler in progress. See Design Decision #3 in ARCHITECTURE_AND_DESIGN.md.

      - id: F1.3
        title: Refund endpoint
        status: pending
        gate_4: { status: pending }
        plan: milestones/01-core-payment/plans/refund-endpoint.md
        deliverables:
          - POST /payments/refund accepts charge ID and optional partial amount
          - Refund propagated to Stripe and recorded locally
          - Audit log entry created for every refund
        notes: ""

  - id: M2
    name: Merchant Dashboard
    status: pending
    readme: milestones/02-dashboard/README.md
    gate_3: { status: pending }
    features:

      - id: F2.1
        title: Transaction history view
        status: pending
        gate_4: { status: pending }
        plan: milestones/02-dashboard/plans/transaction-history.md
        deliverables:
          - Paginated table of charges and refunds with date/status filters
          - CSV export for date range
          - Real-time status update via SSE without page refresh
        notes: ""

      - id: F2.2
        title: Dispute management UI
        status: pending
        gate_4: { status: pending }
        plan: milestones/02-dashboard/plans/dispute-ui.md
        deliverables:
          - List open disputes with days-remaining indicator
          - Evidence upload form linked to Stripe Disputes API
          - Email notification on dispute status change
        notes: ""
```

This file answers both progress-file questions immediately:

- **Where are we?** Active milestone is `M1`, current gate is `gate_4`. Scanning the M1 features: F1.1 complete, F1.2 in-progress, F1.3 pending. The work is on F1.2.
- **What happened?** F1.1's notes record start date, completion summary, and test count. F1.2's notes record start date and current state. Gate approvals carry dates.

A new session reading only this file can reconstruct the full project state without any prior conversation.

---

## Addressing the Strongest Counterarguments

**"Plain text is safer to hand-edit."**

The risk in hand-editing YAML is indentation. The risk in hand-editing plain text is silent misattribution. When a developer adds a note at the wrong indentation in YAML, they get a visible error. When they add a note at the wrong indentation in plain text, the file still looks correct — but the skill reads the note as belonging to a different feature. Explicit failure is preferable to silent corruption for a state file. The specific edits UR-2 names (changing status, adding notes, resetting gates) are all simple scalar field changes in YAML that require no structural knowledge.

**"YAML is fragile to whitespace errors" (UR-5).**

This is true of a strict YAML parser. The skills reading this file are language models, not parsers. A model can interpret `status:complete` (missing space) and `  status: complete` (extra indentation) correctly while still flagging the inconsistency. The real brittleness risk is in block scalar handling for the `notes` field — but that is also the most free-text, prose-heavy field, and models handle prose regardless of formatting. The structural fields (status, date, id) are single-line scalars where whitespace errors are visually obvious.

**"Users know checkboxes; they don't know YAML" (NFR-1).**

The checkbox convention (`[ ]`, `[x]`, `[~]`, `[-]`) is preserved in spirit through the status field. The visual legend at the top of the file documents the values. The specific character syntax changes (`status: complete` instead of `[x]`), but the conceptual model — each feature has a status that progresses through a known set of values — is identical. Users who find YAML unfamiliar will find that the only operations they need to perform are changing single words and appending to notes fields. Neither operation requires YAML knowledge.

---

## Summary Evaluation

| Criterion | Evaluation dimension | Plain text score | YAML score | Notes |
|---|---|:---:|:---:|---|
| **Readability** | Can a human scan it in 5 seconds? (UR-1) | 4 | 4 | YAML with flow-style summary block matches plain text readability; neither is native markdown |
| **Editability** | Can a human safely hand-edit it? (UR-2, UR-5) | 5 | 3 | Plain text genuinely easier for casual edits; YAML's indentation is a real obstacle for non-YAML users |
| **Parsability** | Can the model reliably read and update it? (UR-4) | 2 | 5 | YAML's named key paths eliminate ambiguity; plain text requires pattern-matching against prose conventions |
| **Expressiveness** | Can it represent all required state? (FR-1–FR-6) | 2 | 5 | Plain text has no place for milestone status, gate dates per feature, or structured artifact refs |
| **Conciseness** | Token efficiency on read? (NFR-2) | 4 | 3 | Plain text is terser per item, but YAML eliminates format-description overhead in skill instructions |
| **Familiarity** | Builds on existing conventions? (NFR-1) | 5 | 3 | Plain text is the existing format; YAML preserves concepts but changes syntax |
| **Total** | | **22/30** | **23/30** | |

The totals are close, but the distribution matters. Plain text's advantage is concentrated in editability and familiarity — important, but the scores reflect one-time learning costs. YAML's advantage is concentrated in parsability and expressiveness — requirements that fire on every skill invocation, every session, every developer who reads the file. The criteria where YAML wins are structural; the criteria where plain text wins are habitual. For a state file that exists to serve a machine-readable pipeline and a human reader equally, structural correctness outweighs familiarity.

The honest version: if this file were read only by humans, plain text would win. Because it is also read and written by skill agents on every invocation, YAML's named structure is the right foundation.
