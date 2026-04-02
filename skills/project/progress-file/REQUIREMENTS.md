# Progress File — Requirements Definition

> Defines the requirements for the project state/progress file used by the `/project` skill
> pipeline. This file must be designed before choosing a format (OQ-1 in OPEN_QUESTIONS.md).

## Purpose

The progress file is the single source of truth for project state across the `/project` skill
pipeline. It answers two questions:

1. **Where are we?** — which gates have been passed, which milestone is active, which feature
   is next
2. **What happened?** — when gates were approved, when features started and finished, what
   notes were recorded along the way

## Actors

| Actor | Reads | Writes | Context |
|---|---|---|---|
| `/project` (orchestrator) | Yes | No | Determines what phase the user is in; suggests next action |
| `/milestone` | Yes | Yes | Creates milestone and feature entries; records gate approvals |
| `/build` | Yes | Yes | Updates feature status (in-progress, complete); adds notes |
| Human (developer) | Yes | Yes | Checks status at a glance; manually corrects state; skips or resets steps |
| Human (team reviewer) | Yes | No | Reviews project status during standups, planning, or handoffs |

## Functional Requirements

### FR-1: Gate tracking

The file must track which gates have been passed and when.

- Gate 0 (Alignment) — status and approval date; or "skipped" for greenfield
- Gate WB (Working Backwards) — status and approval date; or "skipped" if declined
- Gate 1 (Scope) — status and approval date
- Gate 2 (Design) — status and approval date
- Gate 3 (Milestone) — status and approval date, per milestone
- Gate 4 (Plan) — status and approval date, per feature

### FR-2: Milestone grouping

Features must be grouped by milestone. Each milestone has:

- An identifier and name
- A status (pending, planning, approved, in-progress, complete)
- An ordered list of features belonging to it

### FR-3: Feature status tracking

Each feature must track:

- Status: pending, planned, in-progress, complete, skipped
- Key deliverables (2–4 bullets from acceptance criteria)
- Free-text notes field for dates, observations, cross-references

### FR-4: Ordering

Milestones and features within milestones must have a defined order that reflects dependency
sequencing. The file's structure must make this order visually obvious without requiring
parsing logic.

### FR-5: Artifact cross-references

The file must reference related artifacts so a reader can navigate to detail:

- PRD: `prd.md`
- Architecture: `docs/ARCHITECTURE_AND_DESIGN.md`
- Codebase assessment: `docs/codebase-assessment.md`
- Working backwards: `docs/working-backwards.md`
- Milestone definition: `milestones/<NN>-<name>/README.md`
- Feature plan: `milestones/<NN>-<name>/plans/<feature>.md`

### FR-6: Session resilience

The file must be fully self-contained. A new session (after `clear`, after days/weeks, on a
different machine) must be able to reconstruct the complete project state by reading only this
file. No dependency on conversation history.

## Usability Requirements

### UR-1: Human-readable at a glance

A developer opening the file must be able to determine project status within 5 seconds. This
means:

- Current phase/gate is visually obvious
- Active milestone is visually obvious
- Feature statuses use a scannable notation (e.g., checkboxes, status markers)
- No parsing required — the structure communicates through layout, not syntax

### UR-2: Human-editable with any text editor

A developer must be able to:

- Mark a feature as complete, skipped, or reset to pending
- Add notes to a feature
- Manually adjust gate status (e.g., re-open a gate for re-planning)
- Do all of the above without specialized tooling, YAML knowledge, or risk of breaking the
  file's structure

### UR-3: Diff-friendly

Changes to the file should produce clean, meaningful diffs in git. This means:

- Status changes should affect a single line (not rewrite a block)
- Adding a milestone or feature should be an append, not a restructure
- Notes should be inline or immediately adjacent to their feature

### UR-4: Low cognitive overhead for skill authors

The skill instructions that read and write this file must be simple. Complex parsing rules
(e.g., "find the YAML key nested three levels deep") increase the chance of model error.
Simpler formats produce more reliable skill behavior.

### UR-5: Tolerant of minor formatting errors

If a human hand-edits the file and introduces minor inconsistencies (extra whitespace, slightly
wrong indentation), the skills reading the file should still function. The format should not be
brittle to whitespace or alignment.

## Non-Functional Requirements

### NFR-1: Backward compatibility with progress.txt patterns

The file should feel familiar to users of the existing `create-prd` pipeline. The checkbox
notation (`[ ]`, `[~]`, `[x]`, `[-]`) is established and should be preserved where applicable.

### NFR-2: Token efficiency

The file will be read into the context window by every skill on every invocation. It should be
as concise as possible while meeting all functional requirements. Verbose formats waste context
budget.

### NFR-3: Single file

The state must live in one file, not split across multiple files. Multiple state files create
synchronization problems and increase the chance of inconsistency. Artifact details live in
their own files — the progress file tracks status and cross-references, not content.

## Constraints

- Must be a plain text file (not binary, not database)
- Must be version-controllable in git
- Must not require any runtime, library, or parser beyond what the model can do natively
- Must support both greenfield projects (no Gate 0, possibly no Gate WB) and brownfield
  projects (all gates active)
- Must support single-milestone projects (simple) and multi-milestone projects (phased)

## Evaluation Criteria

When comparing format options, evaluate against:

1. **Readability** — can a human scan it in 5 seconds? (UR-1)
2. **Editability** — can a human safely hand-edit it? (UR-2, UR-5)
3. **Parsability** — can the model reliably read and update it? (UR-4)
4. **Expressiveness** — can it represent all required state? (FR-1 through FR-6)
5. **Conciseness** — how many tokens does a typical project consume? (NFR-2)
6. **Familiarity** — does it build on existing conventions? (NFR-1)
