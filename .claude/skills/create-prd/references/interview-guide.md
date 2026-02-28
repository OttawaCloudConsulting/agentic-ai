# Interview Guide

Reference for Step 2 (PRD Deep Dive) and Step 3 (Architecture and Design) interview rounds.
Group into rounds of 2–4 questions each. Do not ask all questions at once.
Adapt questions to the project type — not all rounds apply to every project.

## PRD Interview Rounds

### Round 1 — Scope and Boundaries

- What is explicitly out of scope? (non-goals)
- Are there constraints on environments, platforms, or deployment targets?
- Are there compliance or security requirements?
- What existing systems or services does this integrate with?

### Round 2 — Components and Architecture

- What are the major components or services?
- How do they connect? (data flow, request flow)
- Are there geographic distribution or redundancy requirements?
- Are there conditional or optional components?

### Round 3 — Inputs and Outputs

- What does the consumer or caller configure? (parameters, configuration, inputs)
- What needs to be exposed or returned after deployment? (outputs, endpoints, connection strings)
- Are there required vs. optional inputs?
- What validation rules should inputs have?

### Round 4 — Security

- What is the encryption strategy (at rest, in transit)?
- What access control model applies?
- Are there edge protection or traffic filtering requirements?
- What security headers or policies are needed?

### Round 5 — Operational Concerns

- Is logging needed? (access logs, audit trails)
- What monitoring / alerting is expected?
- What is the deployment workflow? (e.g., single step, multi-phase, manual approval gates, CI/CD pipeline)
- Are there cost considerations or constraints?

## Architecture Interview Areas

### Architecture Decisions

- Present key design decisions implied by the PRD and ask the user to confirm or override.
- For each decision, capture: what was decided, what alternatives exist, and why this choice was made.
- Number decisions sequentially (Decision #1, #2, ...) for cross-referencing.
- Target 10–20 decisions for a substantial architecture. Push beyond the obvious ones.

### Component Design

- For each major component in the PRD, ask about implementation specifics not covered in the PRD.
- Ask about naming conventions, versioning strategy, dependency ordering.

### File Organization

- What does the directory/file structure look like?
- Which files or modules own which responsibilities?
- Are there naming conventions for files?

### Deployment Workflow

- Is deployment a single step or multi-phase? (e.g., two-phase for ACM cert validation)
- Are there manual steps between automated stages?
- Is there a CI/CD pipeline? What does the stage flow look like?
- What are the prerequisites before a deploy can run?

### Risks and External Dependencies

- What are the biggest technical or delivery risks? How will they be mitigated?
- Is this work blocked on or coupled to anything outside the project?
  (external APIs, other teams, account-level prerequisites, DNS delegation, etc.)

### Security Review

- Present relevant security best practices for the technologies involved.
- Ask which best practices to incorporate into the design vs. leave as consumer responsibility.
- Categorize as: Already Addressed, Added to Design, Consumer Responsibility.
