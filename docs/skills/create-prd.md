# Create PRD

**Source:** `skills/create-prd/`
**Command:** `/create-prd`
**Activation:** Manual only (`disable-model-invocation: true`) — invoked via slash command. Not auto-triggered by conversational phrases.

## Description

Guided skill for producing a complete project foundation through structured interview. Conducts five PRD interview rounds followed by an architecture design interview, then generates three artifacts: a Product Requirements Document, an Architecture and Design specification, and a progress tracking file. The interview is incremental — questions are grouped into rounds of 2--4, the user sees what was written after each round, and the documents are refined through a cross-reference and final review pass before the progress file is generated. Terminology and sections adapt to the project's technology stack.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with 7-step workflow, round-to-section mapping, and quality bars |
| `assets/prd-template.md` | PRD output scaffold — Summary, Goals, Non-Goals, Architecture, Features, Configuration, Outputs, Risk Assessment, External Dependencies, Success Criteria, Future Enhancements |
| `assets/architecture-template.md` | Architecture doc scaffold — Component Diagram, Data Flow, Component Inventory, Security Model, File Organization, Configuration, Outputs, Design Decisions, Deployment Workflow, Dependency Graph, Out of Scope |
| `assets/progress-template.txt` | Progress file scaffold with status legend, multi-phase variant, and NOTES field conventions |
| `references/interview-guide.md` | Question bank for PRD rounds (Round 1–5) and architecture interview areas |

## Usage

```
/create-prd
```

Invoke at the start of a new project. The skill checks for existing output files and confirms before overwriting any.

## Workflow

### Step 1 — Seed the PRD

Gathers the initial concept via `AskUserQuestion` (what you're building, tech stack, primary goal, project type), then writes an initial `prd.md` from the template.

### Step 2 — PRD Deep Dive Interview

Conducts five interview rounds in order, updating `prd.md` after each:

| Round | Topics | PRD Sections Updated |
|---|---|---|
| 1 — Scope | Non-goals, constraints, compliance, integrations | Goals, Non-Goals, External Dependencies |
| 2 — Components | Major components, data flow, distribution, conditional elements | Architecture, Risk Assessment |
| 3 — Inputs/Outputs | Configuration parameters, outputs, required vs. optional, validation | Configuration, Outputs |
| 4 — Security | Encryption, access control, edge protection, security headers | Risk Assessment (security) |
| 5 — Operational | Logging, monitoring, deployment workflow, cost constraints | Risk Assessment (operational), Future Enhancements |

**Quality bar:** The PRD must have specific acceptance criteria per feature and clear configuration and output tables. Design decisions belong in the architecture document (Step 3).

### Step 3 — Architecture and Design Document

Interviews on Architecture Decisions, Component Design, File Organization (skip for single-file scripts), Deployment Workflow (include when non-trivial), Security Review, and Risks/External Dependencies (include when external coupling exists). Writes `docs/ARCHITECTURE_AND_DESIGN.md`. Irrelevant template sections are omitted; sections the project needs that are not in the template are added.

**Quality bar:** Target 10–20 Design Decisions. Shallow decision tables are the most common quality gap.

### Step 4 — Cross-Reference and Update PRD

Verifies structural consistency (component names, parameter names, and feature titles match across both documents), then propagates new content discovered during architecture design back to `prd.md`.

### Step 5 — Final PRD Review

Presents a summary of the complete PRD and asks the user to confirm feature ordering, acceptance criteria specificity, and completeness. Updates both documents if changes are made.

### Step 6 — Create progress.txt

Generates `progress.txt` from the finalized PRD. Feature 1 is always the architecture document. Single-phase projects use sequential numbering (Feature 2, 3, ...); multi-phase projects use phase headers with sub-numbering (Phase 1 = Feature 2.1, 2.2, ...; Phase 2 = Feature 3.1, 3.2, ...).

### Step 7 — Report

Presents a summary: artifact names, feature count, configuration parameter count, output count, design decision count, and a pointer to Feature 1.

## Output

| Artifact | Location | Contents |
|---|---|---|
| Product Requirements Document | `prd.md` | Summary, Goals, Non-Goals, Architecture, Features with Acceptance Criteria, Configuration, Outputs, Risk Assessment, External Dependencies |
| Architecture and Design | `docs/ARCHITECTURE_AND_DESIGN.md` | Component Diagram, Component Inventory, Security Model, File Organization, Design Decisions, Deployment Workflow |
| Progress tracker | `progress.txt` | One tracked item per PRD feature, with 2–4 deliverable bullets each |

## Rules

- **One round at a time.** Questions are grouped; the user is never shown all questions at once.
- **Show work after each step.** The user sees what was added or changed before the next step begins.
- **Confirm before overwriting.** All three output files are checked in Prerequisites; the user confirms before any existing file is replaced.
- **Adapt to the project.** Terminology, sections, and questions adjust to match the technology stack.
- **Design decisions belong in the architecture doc.** The PRD does not have a Design Decisions section.
- **Cross-reference everything.** Feature numbers, parameter names, and component names must match across all three documents.
- **No implementation.** This skill produces planning documents only.

## Error Handling

- **Interrupted interview:** Saves progress to artifacts created so far. On re-invocation, detects existing files and offers to resume from the last completed step.
- **Vague or contradictory answers:** Asks a clarifying follow-up rather than guessing. Unresolved ambiguity is recorded in the PRD Risk Assessment table.
- **Project does not fit templates:** Irrelevant template sections are omitted; needed sections not in the template are added. States what was omitted and why.
- **User wants to skip a round:** Allowed. The skipped round is recorded in `prd.md` as a comment so a future session can revisit it.

## When to Use

- Starting a new project from scratch
- Building a blueprint for a feature or service with multiple components
- Any project where you want a structured PRD + architecture doc before writing code

## When Not to Use

- Updating an existing PRD — edit the file directly
- Projects so small they don't warrant a PRD (a single function, a one-off script)
- When the architecture is already fully defined and you only need a progress file

## Related Skills

- **skill-creator** — use to build new skill bundles like this one
- **start-feature** — invoke after `/create-prd` to begin implementing Feature 1
