---
name: create-prd
description: Create a PRD, architecture document, and progress file for a new project through guided interview. Use when starting a new project, planning a new feature, writing requirements, scoping a project, or creating project documentation from scratch. Phrases like "I want to plan a new project" or "help me write requirements for" are good triggers. Do NOT use for updating an existing PRD, documenting changes to an existing system, writing a technical design doc for an in-progress change, or starting implementation.
disable-model-invocation: true
---

# /create-prd — Guided Project Requirements and Design

Create a complete project foundation through a structured interview process. Produces three artifacts:

- `prd.md` — Product Requirements Document
- `docs/ARCHITECTURE_AND_DESIGN.md` — Architecture and design specification
- `progress.txt` — Discrete feature steps and phases

## Rules

- **One round at a time.** Never dump all questions on the user at once.
- **Show work after each step.** Tell the user what was added or changed.
- **Confirm before overwriting.** Do not skip the overwrite check in Prerequisites.
- **Adapt to the project.** Adjust terminology, sections, and questions to match the technology.
- **Do not begin implementation.** This skill produces planning documents only.
- **Cross-reference everything.** Feature numbers, parameter names, and component names must match
  across all three documents.
- **Never write `spec.md`.** When one exists it is input only (see **Spec-seeded mode**).

## Spec-seeded mode

`/create-spec` produces a root-level `spec.md` that captures requirements, scope, and interface
contracts before this skill runs. When it exists, the interview becomes confirmation-only: present
what the spec already answers and ask only about gaps and contradictions.

| `spec.md` section | Seeds |
|-------------------|-------|
| Context, Requirements | `prd.md` Summary, Goals, Features |
| Out of scope | `prd.md` Non-Goals (same table shape) |
| Risks (`R<n>`) | `prd.md` Risk Assessment |
| External dependencies | `prd.md` External Dependencies |
| Approach decisions (`D<n>`) | Architecture Design Decisions |
| Interface contracts | Architecture Component Inventory and Configuration |
| Acceptance criteria | Feature acceptance criteria |
| Open assumptions | Resolved in Round 5, or carried into Risk Assessment |

**Identifiers.** `D<n>` and `R<n>` carry across verbatim and are never renumbered. Spec requirement
numbers are *traceability*, not feature numbers: Feature numbering is unchanged (Feature 1 is the
architecture document), and each PRD feature cites the requirement numbers it satisfies in a
`**Traces to:**` line. Every spec requirement must appear in at least one feature's `Traces to:`.

## Prerequisites

- Working directory is the project root (or subdirectory where the project will live)
- If `spec.md` exists in the working directory, read it in full and tell the user the run is
  spec-seeded. Otherwise the run is interview-seeded and the **Spec-seeded mode** sections below do
  not apply.
- Check whether any of the three output files exist (`prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`,
  `progress.txt`) — confirm with the user before overwriting any that are present
- **Coexistence with `/project` (schema guard).** `/create-prd` writes a *light* `progress.txt`
  (inline `[ ] Feature X.Y` lines) and routes to `/start-feature`. `/project` owns a *gated*
  `progress.txt` (`## Gates` / `## Milestones` sections, with milestones under `.project/<slug>/`).
  The two schemas are incompatible in one file. If the `progress.txt` in the working directory
  contains `## Gates` or `## Milestones`, this repo is under `/project` management — **stop** and
  tell the user: either continue with `/project`, or run `/create-prd` from a dedicated
  subdirectory (its own working dir = its own `progress.txt`, no collision). Never overwrite a
  gated `progress.txt` with the light schema.

## Step 1 — Seed the PRD

**Spec-seeded:** do not ask the questions below. Seed `prd.md` from `spec.md` per the mapping in
**Spec-seeded mode**, then ask one `AskUserQuestion` only for what the spec leaves unanswered
(typically technology stack or project type).

**Interview-seeded:** use `AskUserQuestion` to gather the initial project concept:

- What are you building? (1-2 sentence description)
- What is the technology stack? (languages, frameworks, services, platforms)
- What is the primary goal / problem being solved?
- Is this a reusable library, standalone application, service, or something else?

Read `assets/prd-template.md`. Use the Write tool to create `prd.md` populated with the
user's answers. Read the file back and confirm Summary, Goals, and Features sections are
populated. Tell the user what was written and move to Step 2.

## Step 2 — PRD Deep Dive Interview

Read `references/interview-guide.md` for the full question bank.

Conduct an iterative interview using `AskUserQuestion`. Work through the PRD interview rounds
(Round 1–5) in order, grouped into 2–4 questions per round. After each round, use the Edit tool
to update `prd.md` and show the user what was added before proceeding.

Each round maps to these PRD sections:

- Round 1 (Scope) → Goals, Non-Goals, External Dependencies
- Round 2 (Components) → Architecture section, Risk Assessment
- Round 3 (Inputs/Outputs) → Configuration, Outputs
- Round 4 (Security) → Risk Assessment (security entries); may surface new features
- Round 5 (Operational) → Risk Assessment (operational entries), Future Enhancements

**Spec-seeded:** run each round in confirmation-only mode. Show what `spec.md` already answers for
the round's sections, ask only about gaps and contradictions, and skip a round the spec fully
covers (say so). In Round 5, also raise every `Open assumptions` entry from the spec: resolve it
with the user, or record it in Risk Assessment with its stated default.

Continue until the user indicates the PRD is comprehensive, or all rounds are complete.

**Quality bar:** The PRD must have specific acceptance criteria per feature and clear
configuration and output tables. Design decisions belong in the architecture document (Step 3).

## Step 3 — Architecture and Design Document

Read `references/interview-guide.md` for the architecture interview areas.
Read `assets/architecture-template.md` for the document structure.

Use Bash (`mkdir -p docs`) to ensure `docs/` exists. Conduct a focused interview using
`AskUserQuestion` covering all areas from the interview guide.

**Spec-seeded:** pre-fill Design Decisions from the spec's `D<n>` entries, keeping their IDs and
rejected alternatives, and pre-fill Component Inventory and Configuration from its Interface
contracts. Ask only about areas the spec does not cover.

Use the Write tool to create `docs/ARCHITECTURE_AND_DESIGN.md`. Omit sections that are
irrelevant to the project; add sections needed but not in the template. Read the file back
and confirm Design Decisions and Component Inventory are populated. Tell the user what was written.

**Quality bar:** Target 10–20 Design Decisions for a substantial architecture. Every non-obvious
choice should be captured with rationale. Shallow decision tables are the most common quality gap.

## Step 4 — Cross-Reference and Update PRD

Read `prd.md` and `docs/ARCHITECTURE_AND_DESIGN.md`. Verify structural consistency: component
names, configuration parameter names, and feature titles must match exactly across both documents.

Then propagate back to the PRD any new features discovered during architecture design, refined
acceptance criteria, and updated configuration or output tables.

Use the Edit tool to apply changes to `prd.md`. Show the user what changed and confirm.

## Step 5 — Final PRD Review

Use `AskUserQuestion` for a final review pass:

- Present a summary of the complete PRD (feature list, input/output counts, key decisions)
- Ask if anything is missing, incorrect, or needs adjustment
- Ask if feature ordering makes sense (dependencies flow correctly)
- Ask if acceptance criteria are specific enough

Apply any final changes to `prd.md`. If new or changed features affect component design,
also update `docs/ARCHITECTURE_AND_DESIGN.md` to stay consistent.

## Step 6 — Create progress.txt

Read `assets/progress-template.txt` for the format.

Use the Write tool to create `progress.txt` from the finalized PRD. Every feature in the PRD
becomes a tracked item. Read the file back and confirm feature count matches the PRD.

Rules:

- Feature 1 is always the architecture/design document itself
- Single-phase projects: Feature 2, 3, ... for remaining features
- Multi-phase projects: use phase headers; features use sub-numbering by phase
  (Phase 1 = Feature 2.1, 2.2, ...; Phase 2 = Feature 3.1, 3.2, ...)
- All features start as `[ ]` (pending)
- Key deliverables extracted from PRD acceptance criteria (2–4 bullets per feature)
- NOTES section left empty
- Feature ordering respects dependencies

## Step 7 — Report

Present a final summary:

```
PROJECT SETUP COMPLETE: [Project Title]

SEEDED FROM: [spec.md | interview]

ARTIFACTS CREATED:
- prd.md — [N] features, [M] configuration parameters, [K] outputs
- docs/ARCHITECTURE_AND_DESIGN.md — [N] design decisions, [M] components
- progress.txt — [N] features tracked

FIRST FEATURE:
  Feature 1: [Title]
  [Brief description]

Run /start-feature to begin implementation.
```

## Error Handling

- **Interrupted interview:** If the user stops mid-interview, save progress to the artifacts
  created so far. On re-invocation, detect existing files and offer to resume from the last
  completed step rather than starting over.
- **Vague or contradictory answers:** Ask a clarifying follow-up. Do not guess intent or fill in
  placeholders. If the user cannot clarify, record the ambiguity in the PRD Risk Assessment table.
- **Project does not fit templates:** Omit irrelevant template sections. Add sections the project
  needs that are not in the template. State what was omitted and why.
- **User wants to skip a round:** Allow it. Record the skipped round in prd.md as a comment so a
  future session can revisit it.
- **Missing asset templates:** If any `assets/` file is absent (`prd-template.md`,
  `architecture-template.md`, `progress-template.txt`), do not silently fail. Notify the user
  which file is missing and construct the document from scratch using the section structure
  described in the relevant step. State that no template was used.
