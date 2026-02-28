---
name: create-prd
description: Create a PRD, architecture document, and progress file for a new project through guided interview. Use when starting a new project or blueprint from scratch.
disable-model-invocation: true
---

# /create-prd — Guided Project Requirements and Design

Create a complete project foundation through a structured interview process. Produces three artifacts:

- `prd.md` — Product Requirements Document
- `docs/ARCHITECTURE_AND_DESIGN.md` — Architecture and design specification
- `progress.txt` — Discrete feature steps and phases

## Prerequisites

- Working directory is the project root (or subdirectory where the project will live)
- Check whether any of the three output files exist (`prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`,
  `progress.txt`) — confirm with the user before overwriting any that are present

## Step 1 — Seed the PRD

Use `AskUserQuestion` to gather the initial project concept:

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

Continue until the user indicates the PRD is comprehensive, or all rounds are complete.

**Quality bar:** The PRD must have specific acceptance criteria per feature and clear
configuration and output tables. Design decisions belong in the architecture document (Step 3).

## Step 3 — Architecture and Design Document

Read `references/interview-guide.md` for the architecture interview areas.
Read `assets/architecture-template.md` for the document structure.

Use Bash (`mkdir -p docs`) to ensure `docs/` exists. Conduct a focused interview using
`AskUserQuestion` covering Architecture Decisions, Component Design, and Security Review.

Use the Write tool to create `docs/ARCHITECTURE_AND_DESIGN.md`. Omit sections that are
irrelevant to the project; add sections needed but not in the template. Read the file back
and confirm Design Decisions and Component Inventory are populated. Tell the user what was written.

**Quality bar:** Target 10–20 Design Decisions for a substantial architecture. Every non-obvious
choice should be captured with rationale. Shallow decision tables are the most common quality gap.

## Step 4 — Cross-Reference and Update PRD

Read `prd.md` and `docs/ARCHITECTURE_AND_DESIGN.md`. First verify structural consistency:

- Component names in the PRD Architecture section match the Component Inventory table
- Configuration parameter names are identical in both documents
- Feature titles referenced in the architecture doc match the PRD Features section

Then identify content to propagate back to the PRD:

- New features discovered during architecture design (logging, security hardening, conditional components)
- Refined acceptance criteria based on architecture decisions
- Updated configuration and output tables

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

ARTIFACTS CREATED:
- prd.md — [N] features, [M] configuration parameters, [K] outputs
- docs/ARCHITECTURE_AND_DESIGN.md — [N] design decisions, [M] components
- progress.txt — [N] features tracked

FIRST FEATURE:
  Feature 1: [Title]
  [Brief description]

Run /start-feature to begin implementation.
```

## Rules

- **One round at a time.** Never dump all questions on the user at once.
- **Show work after each step.** Tell the user what was added or changed.
- **Confirm before overwriting.** Checked in Prerequisites — do not skip this for any of the three output files.
- **Adapt to the project.** Adjust terminology, sections, and questions to match the technology.
- **Do not begin implementation.** This skill produces planning documents only.
- **Cross-reference everything.** Feature numbers, parameter names, and component names must match across all three documents.
