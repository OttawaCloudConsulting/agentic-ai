---
name: create-prd
description: Create a PRD, architecture document, and progress file for a new project through guided interview. Use when starting a new project or blueprint from scratch.
---

# /create-prd — Guided Project Requirements and Design

Create a complete project foundation through a structured interview process. Produces three artifacts:
- `prd.md` — Product Requirements Document
- `docs/ARCHITECTURE_AND_DESIGN.md` — Architecture and design specification
- `progress.txt` — Discrete feature steps and phases

## Prerequisites

Before starting, confirm:
- The working directory is the project root (or the subdirectory where the project will live)
- No existing `prd.md` — if one exists, confirm with the user before overwriting

## Execution Steps

### Step 1 — Seed the PRD

Use `AskUserQuestion` to gather the initial project concept:

**Questions to ask (adapt to context):**
- What are you building? (1-2 sentence description)
- What AWS services are involved? (or what technology stack?)
- What is the primary goal / problem being solved?
- Is this a reusable module, a standalone deployment, or something else?

Write an initial `prd.md` with the information gathered:

```markdown
# PRD: [Project Title]

## Summary
[1-3 sentences from user's description]

## Goals
- [Extracted from user's answers]

## Architecture
[Placeholder — will be expanded in subsequent steps]

## Non-Goals
[Placeholder — will be defined through interview]

## Features
[Placeholder — will be defined through interview]
```

Report what was written and move to Step 2.

### Step 2 — PRD Deep Dive Interview

Conduct an iterative interview using `AskUserQuestion` to fill out the PRD comprehensively. Cover the following areas across multiple rounds of questions. Do NOT ask all questions at once — group them into logical rounds of 2-4 questions each.

**Round structure (adapt based on project type):**

**Round 1 — Scope and Boundaries:**
- What is explicitly out of scope? (non-goals)
- Are there constraints on regions, accounts, or environments?
- Are there compliance or security requirements?
- What existing infrastructure does this integrate with?

**Round 2 — Components and Architecture:**
- What are the major components / AWS resources?
- How do they connect? (data flow, request flow)
- Are there multi-region requirements?
- Are there conditional or optional components?

**Round 3 — Inputs and Outputs:**
- What does the consumer configure? (input variables)
- What needs to be exposed after deployment? (outputs)
- Are there required vs. optional inputs?
- What validation rules should inputs have?

**Round 4 — Security:**
- What is the encryption strategy (at rest, in transit)?
- What access control model applies?
- Are there edge protection requirements (WAF, Shield)?
- What security headers or policies are needed?

**Round 5 — Operational Concerns:**
- Is logging needed? (access logs, audit trails)
- What monitoring / alerting is expected?
- What is the deployment workflow? (single apply, multi-phase, etc.)
- Are there cost considerations or constraints?

After each round, update `prd.md` with the new information. Show the user what was added and confirm before proceeding to the next round.

Continue rounds until the user indicates the PRD is comprehensive enough, or all areas above have been covered.

**Important:** The PRD should reach a quality level comparable to the existing project PRDs — specific acceptance criteria per feature, clear input/output tables, explicit architecture decisions.

### Step 3 — Architecture and Design Document

Using the completed PRD as the foundation, conduct a focused interview using `AskUserQuestion` to create `docs/ARCHITECTURE_AND_DESIGN.md`.

**Interview areas (adapt to project type):**

**Architecture Decisions:**
- Present key design decisions implied by the PRD and ask the user to confirm or override
- For each decision, capture: what was decided, what alternatives exist, and why this choice was made
- Number decisions sequentially (Decision #1, #2, ...) for cross-referencing

**Component Design:**
- For each major component in the PRD, ask about implementation specifics not covered in the PRD
- Ask about resource naming conventions, tagging strategy, dependency ordering

**Security Review:**
- Present relevant AWS security best practices for the services involved
- Ask which best practices to incorporate into the design vs. leave as consumer responsibility
- Categorize as: Already Addressed, Added to Design, Consumer Responsibility

Create `docs/ARCHITECTURE_AND_DESIGN.md` with sections appropriate to the project. Use the following structure as a template (adapt sections as needed):

```markdown
# Architecture and Design: [Project Title]

## Overview
[Expanded from PRD summary — includes all components and their relationships]

## Component Diagram
[Text-based architecture diagram showing components and connections]

## Request Flow / Data Flow
[Step-by-step description of how data moves through the system]

## Resource Inventory
[Table: #, Resource, Terraform Type / Service, Region, Purpose]

## Region Strategy
[If multi-region — which resources go where and why]

## Security Model
### Encryption
### Access Control
### Edge Protection (if applicable)

## File Organization
[Module / project directory structure]

## Input Variables
### Required
### Optional (grouped by concern)

## Outputs

## Design Decisions
[Numbered table: #, Decision, Rationale]

## Deployment Workflow
[How the infrastructure is deployed — single apply, multi-phase, etc.]

## Out of Scope
[Expanded from PRD non-goals with rationale]

## Dependency Graph
[Text-based graph showing resource dependencies and creation order]
```

**Not every section applies to every project.** Omit sections that are irrelevant. Add sections that are needed but not listed above.

### Step 4 — Cross-Reference and Update PRD

After the architecture document is complete, review the PRD against it:

1. **Read both documents** — identify any new information from the architecture interview that should be reflected in the PRD.
2. **Update the PRD** with:
   - New features discovered during architecture design (e.g., logging, security headers, conditional resources)
   - Refined acceptance criteria based on architecture decisions
   - Updated input/output tables if the architecture added or changed variables
   - Updated architecture section with the final component list
3. **Show the user the changes** and confirm they are correct.

### Step 5 — Final PRD Review

Conduct a final review pass with the user using `AskUserQuestion`:

- Present a summary of the complete PRD (feature list, input/output counts, key decisions)
- Ask if anything is missing, incorrect, or needs adjustment
- Ask if the feature ordering makes sense (dependencies flow correctly)
- Ask if the acceptance criteria are specific enough

Apply any final changes to `prd.md`.

### Step 6 — Create progress.txt

Generate `progress.txt` from the finalized PRD. Every feature in the PRD becomes a tracked item.

**Format:**

```
# Progress: [Project Title]
# Source: prd.md + ARCHITECTURE_AND_DESIGN.md
# Spec: ARCHITECTURE_AND_DESIGN.md is the authoritative design reference

## Features

[ ] Feature 1: [Title from PRD]
    [Key deliverables — 2-4 bullet points from acceptance criteria]
    NOTES:

[ ] Feature 2: [Title from PRD]
    [Key deliverables]
    NOTES:

[... all features ...]
```

**Rules for progress.txt:**
- Feature numbering matches the PRD (Feature 1, Feature 2, ...)
- If features have phases (e.g., 2.1, 2.2), use sub-numbering
- All features start as `[ ]` (pending)
- The first feature should always be the architecture/design document itself (Feature 1)
- Include key deliverables under each feature (extracted from PRD acceptance criteria)
- Leave NOTES section empty — it will be populated during development
- Feature ordering must respect dependencies (a feature should not depend on a later feature)

### Step 7 — Report

Present a final summary:

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

## Important Rules

- **One round of questions at a time.** Never dump all questions on the user at once. Group into focused rounds of 2-4 questions.
- **Show work after each step.** After updating a document, tell the user what was added or changed.
- **Confirm before overwriting.** If `prd.md`, `docs/ARCHITECTURE_AND_DESIGN.md`, or `progress.txt` already exist, ask before replacing.
- **Adapt to the project.** Not all projects are Terraform modules. Adjust terminology, sections, and question topics to match the technology and project type.
- **Quality bar is high.** The output documents should be detailed enough that another developer (or Claude session) can implement the project from them without further clarification.
- **Cross-reference everything.** The PRD, architecture doc, and progress file must be internally consistent. Feature numbers, variable names, and component names should match across all three documents.
- **Do not begin implementation.** This skill produces planning documents only. After completing, the user runs `/start-feature` to begin building.
- **Ensure `docs/` directory exists** before writing `ARCHITECTURE_AND_DESIGN.md`. Create it if needed.
