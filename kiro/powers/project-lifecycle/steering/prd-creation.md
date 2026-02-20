# Requirements Creation Workflow

Create a complete project foundation through a structured interview process.

## Outputs

- Requirements document (PRD) — features, acceptance criteria, constraints
- Architecture and design specification — component design, decisions, security model
- Feature tracking file — ordered list of discrete implementation steps

## Prerequisites

- Working directory is the project root
- No existing requirements document — confirm with user before overwriting

## Workflow

### Step 1 — Seed the Requirements

Gather the initial project concept through focused questions:

- What are you building? (1-2 sentence description)
- What technology stack or services are involved?
- What is the primary goal / problem being solved?
- Is this a reusable module, standalone deployment, or something else?

Write an initial requirements document with the gathered information.

### Step 2 — Deep Dive Interview

Conduct an iterative interview to fill out the requirements comprehensively. Cover these areas across multiple rounds of 2-4 questions each:

**Round 1 — Scope and Boundaries:**

- What is explicitly out of scope?
- Constraints on regions, accounts, environments?
- Compliance or security requirements?
- Integration with existing infrastructure?

**Round 2 — Components and Architecture:**

- Major components and services?
- How do they connect? (data flow, request flow)
- Multi-region requirements?
- Conditional or optional components?

**Round 3 — Inputs and Outputs:**

- What does the consumer configure?
- What needs to be exposed after deployment?
- Required vs. optional inputs?
- Validation rules?

**Round 4 — Security:**

- Encryption strategy (at rest, in transit)?
- Access control model?
- Edge protection requirements?
- Security headers or policies?

**Round 5 — Operational Concerns:**

- Logging needs?
- Monitoring and alerting?
- Deployment workflow?
- Cost considerations?

After each round, update the requirements document. Show what was added and confirm before proceeding.

### Step 3 — Architecture and Design Document

Using the completed requirements, conduct a focused interview to create the architecture specification:

- Present key design decisions and ask user to confirm or override
- For each major component, ask about implementation specifics
- Review relevant security best practices for the services involved
- Number decisions sequentially for cross-referencing

### Step 4 — Cross-Reference

Review requirements against architecture:

- Add features discovered during architecture design
- Refine acceptance criteria based on architecture decisions
- Update input/output definitions
- Show changes and confirm

### Step 5 — Final Review

Present a summary and ask:

- Is anything missing or incorrect?
- Does the feature ordering make sense?
- Are acceptance criteria specific enough?

### Step 6 — Create Feature Tracking

Generate a tracking file from the finalized requirements. Every feature becomes a tracked item with key deliverables extracted from acceptance criteria.

### Step 7 — Report

Present a final summary of all artifacts created.

## Rules

- One round of questions at a time — never dump all questions at once
- Show work after each step
- Confirm before overwriting existing documents
- Adapt to the project type — not all projects use the same technology
- Quality bar is high — documents must be detailed enough for another developer to implement without further clarification
- Cross-reference everything — requirements, architecture, and tracking must be internally consistent
- Do not begin implementation — this workflow produces planning documents only
