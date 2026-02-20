# Create PRD

**Source:** `commands/create-prd.md`
**Command:** `/create-prd`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "start a new project," "create a blueprint")

## Description

Creates a complete project foundation through a structured, multi-round interview process. Produces three artifacts: a Product Requirements Document, an Architecture and Design specification, and a progress tracking file. This is a planning-only command — it does not begin implementation.

## Usage

```
/create-prd
```

No arguments. The command conducts an interactive interview to gather all required information.

## Inputs

| Input | Source | Required |
|---|---|---|
| Project concept and requirements | User responses via `AskUserQuestion` | Yes |
| Scope and boundary decisions | User responses via `AskUserQuestion` | Yes |
| Architecture and security decisions | User responses via `AskUserQuestion` | Yes |
| Existing `prd.md` | File system (checked for overwrite confirmation) | No |
| Existing `docs/ARCHITECTURE_AND_DESIGN.md` | File system (checked for overwrite confirmation) | No |
| Existing `progress.txt` | File system (checked for overwrite confirmation) | No |

## Outputs

| Output | Location | Description |
|---|---|---|
| Product Requirements Document | `prd.md` | Complete PRD with summary, goals, non-goals, features with acceptance criteria, input/output tables, and architecture overview |
| Architecture and Design Document | `docs/ARCHITECTURE_AND_DESIGN.md` | Detailed architecture specification with component diagrams, data flow, resource inventory, security model, design decisions, and deployment workflow |
| Progress tracking file | `progress.txt` | All features from the PRD as trackable items with status markers and key deliverables |
| Final summary report | Console (stdout) | Artifact counts and pointer to `/start-feature` for beginning implementation |

## Workflow

### Step 1 — Seed the PRD

Uses `AskUserQuestion` to gather the initial project concept:

- What are you building? (1-2 sentence description)
- What AWS services or technology stack is involved?
- What is the primary goal or problem being solved?
- Is this a reusable module, standalone deployment, or something else?

Writes an initial `prd.md` with Summary, Goals, and placeholder sections for Architecture, Non-Goals, and Features.

### Step 2 — PRD Deep Dive Interview

Conducts an iterative interview across multiple rounds of 2-4 questions each. Never asks all questions at once. Covers five areas:

**Round 1 — Scope and Boundaries:** Non-goals, constraints (regions, accounts, environments), compliance/security requirements, existing infrastructure integration.

**Round 2 — Components and Architecture:** Major components/resources, how they connect (data flow, request flow), multi-region requirements, conditional/optional components.

**Round 3 — Inputs and Outputs:** Consumer-configurable inputs, post-deployment outputs, required vs. optional inputs, validation rules.

**Round 4 — Security:** Encryption strategy (at rest, in transit), access control model, edge protection (WAF, Shield), security headers/policies.

**Round 5 — Operational Concerns:** Logging (access logs, audit trails), monitoring/alerting, deployment workflow (single apply, multi-phase), cost considerations.

After each round, updates `prd.md` with new information, shows the user what was added, and confirms before proceeding. Continues until the user indicates completeness or all areas are covered.

### Step 3 — Architecture and Design Document

Using the completed PRD, conducts a focused interview to create `docs/ARCHITECTURE_AND_DESIGN.md`. Covers three areas:

**Architecture Decisions:** Presents key design decisions implied by the PRD for user confirmation. Captures what was decided, alternatives, and rationale. Numbers decisions sequentially for cross-referencing.

**Component Design:** For each major component, asks about implementation specifics not covered in the PRD — resource naming conventions, tagging strategy, dependency ordering.

**Security Review:** Presents relevant security best practices for the services involved. Categorizes each as Already Addressed, Added to Design, or Consumer Responsibility.

Writes the document with sections adapted to the project type: Overview, Component Diagram, Request/Data Flow, Resource Inventory, Region Strategy, Security Model, File Organization, Input Variables, Outputs, Design Decisions, Deployment Workflow, Out of Scope, and Dependency Graph. Omits irrelevant sections and adds needed ones not listed.

### Step 4 — Cross-Reference and Update PRD

Reviews the PRD against the architecture document:

1. Identifies new information from the architecture interview that should be reflected in the PRD.
2. Updates the PRD with new features discovered during architecture design, refined acceptance criteria, updated input/output tables, and the final component list.
3. Shows the user the changes and confirms correctness.

### Step 5 — Final PRD Review

Conducts a final review pass with the user:

- Presents a summary of the complete PRD (feature list, input/output counts, key decisions).
- Asks if anything is missing, incorrect, or needs adjustment.
- Asks if feature ordering makes sense (dependencies flow correctly).
- Asks if acceptance criteria are specific enough.

Applies any final changes to `prd.md`.

### Step 6 — Create progress.txt

Generates `progress.txt` from the finalized PRD. Every feature becomes a tracked item:

```
# Progress: [Project Title]
# Source: prd.md + ARCHITECTURE_AND_DESIGN.md
# Spec: ARCHITECTURE_AND_DESIGN.md is the authoritative design reference

## Features

[ ] Feature 1: [Title from PRD]
    [Key deliverables — 2-4 bullet points from acceptance criteria]
    NOTES:
```

Rules for progress.txt:

- Feature numbering matches the PRD.
- Sub-numbering (e.g., 2.1, 2.2) for phased features.
- All features start as `[ ]` (pending).
- Feature 1 is always the architecture/design document itself.
- Key deliverables extracted from PRD acceptance criteria.
- NOTES section left empty for population during development.
- Feature ordering respects dependencies (no feature depends on a later feature).

### Step 7 — Report

Presents a final summary:

```
PROJECT SETUP COMPLETE: [Project Title]

ARTIFACTS CREATED:
- prd.md — [N] features, [M] input variables, [K] outputs
- docs/ARCHITECTURE_AND_DESIGN.md — [N] design decisions, [M] resources
- progress.txt — [N] features tracked

FIRST FEATURE:
  Feature 1: [Title]
  [Brief description]

Run /start-feature to begin implementation.
```

## When to Use

- When starting a brand new project from scratch
- When creating a blueprint or design for a system before implementation begins
- When the user asks to plan a project, create requirements, or design an architecture

## When Not to Use

- If a `prd.md` already exists and the user wants to modify it rather than replace it
- If the user wants to skip planning and jump directly into implementation
- If the project is already in progress — use `/start-feature` or `/catchup` instead

## Related Commands and Skills

- `/start-feature` — The natural next step after `/create-prd`. Begins implementation of the first feature from the generated `progress.txt`.
- `/handoff` — Writes session state referencing the `progress.txt` created by this command.
- `/catchup` — Reads `progress.txt` and `handoff.md` to resume work on a project created by this command.
- `/update-docs` — Refreshes documentation after features have been implemented against the architecture created here.
