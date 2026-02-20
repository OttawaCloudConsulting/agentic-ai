# Agentic AI Engineering — Strategic Workflow

## Overview

This document describes a strategic software engineering workflow that is driven by agentic AI throughout every phase — from initial ideation through to production deployment. Rather than treating AI as a point tool, this workflow embeds multiple AI agents and platforms into a continuous, iterative pipeline where each stage produces structured deliverables, undergoes review, and feeds forward into the next.

Three AI platforms form the backbone of the process: **Claude Co-Work / Claude Code** for ideation, requirements, architecture, and development; **Notebook LM** for transforming technical artifacts into consumable documentation and multimedia; and **GitHub CoPilot** for automated code review at the pull-request stage.

Every stage includes a **Rework & Refine** feedback loop, ensuring that no output is considered final until it has been reviewed and approved.

---

## Phase 1 — Ideation

### Trigger

The workflow begins with an **IDEA** — a concept, problem statement, or feature request that someone wants to explore.

### Process

The idea is brought into **Claude Co-Work**, where a conversational, collaborative session shapes the raw concept into structured thinking. The outputs at this stage are **Markdown files** covering:

- **MVP** definition — the minimum viable scope
- **Concepts** — core principles, user stories, and hypotheses
- **Additional artifacts** as needed (competitive landscape, constraints, assumptions)

### Notebook LM Integration

The Markdown files are then fed into **Notebook LM**, which ingests the raw content and generates a suite of consumable documents:

- **Report** — a written summary of the idea and its rationale
- **Slide Deck** — a visual presentation for stakeholders
- **Audio Blog** — a narrated overview for asynchronous consumption
- **Data Table** — structured data extracted from the ideation content

This step ensures that the idea is not locked in a single format; it becomes accessible to different audiences (executives, developers, product managers) in the medium they prefer.

### Decision Gate

A **Decision** checkpoint follows. Stakeholders review the Notebook LM deliverables and decide whether to proceed. If the idea is not ready, the workflow loops back to **Rework & Refine** — returning to Claude Co-Work to iterate on the Markdown files before regenerating the documentation suite.

If approved, the workflow advances to requirements.

---

## Phase 2 — Requirements

### Process

**Claude Code** takes over to produce a formal **Product Requirements Document (PRD)**. This is a structured, detailed specification that translates the approved idea into actionable requirements — covering scope, user stories, acceptance criteria, non-functional requirements, and dependencies.

Claude Code is well-suited here because it can reason over the upstream Markdown artifacts, ask clarifying questions, and produce a technically rigorous document that will guide architecture and development.

### Review Gate

The PRD is submitted for **Review**. If it does not meet expectations, the workflow loops back to **Rework & Refine**, cycling through Claude Code until the requirements are solid. This loop can also feed all the way back to the ideation phase if the review reveals fundamental gaps in the original concept.

---

## Phase 3 — Architecture and Design

### Process

Once the PRD is approved, Claude Code (or the reviewer working with Claude Code) produces an **Architecture and Design markdown document**. This document covers:

- System architecture (components, services, data flows)
- Technology choices and trade-offs
- API contracts and interface definitions
- Data models and storage design
- Security considerations and compliance mapping

### Notebook LM Integration

The Architecture and Design document is fed into **Notebook LM** a second time, generating another round of deliverables:

- **Report** — a written architecture summary
- **Slide Deck** — diagrams and architecture visuals for review meetings
- **Audio Blog** — a narrated walkthrough of the design decisions
- **Data Table** — structured data (component inventory, dependency matrix, etc.)

This second Notebook LM pass ensures the architecture is documented in multiple formats before any code is written — critical for audit trails, onboarding, and stakeholder alignment.

### Review Gate

The architecture deliverables go through **Review**. Two feedback loops are available:

1. **Rework & Refine** the architecture document itself if the design needs adjustment
2. **Rework & Refine** back to earlier phases if the review surfaces issues with the requirements or the original idea

Only once the architecture is approved does the workflow move into development.

---

## Phase 4 — Development

### Process

**Claude Code** now drives the core engineering work. This phase is heavily automated and covers three parallel tracks:

1. **Feature Design: progress.txt** — Claude Code maintains a running progress file that tracks what is being built, what is complete, and what remains. This provides transparency and a lightweight project management artifact.

2. **Automated Development, Testing, and Documentation** — Claude Code handles:
   - **Develop** — writing the application code based on the PRD and architecture document
   - **Test** — generating and running unit tests, integration tests, and other validation
   - **Document** — producing inline documentation, API docs, and developer guides alongside the code

3. **Automated Final Documentation** — once development is functionally complete, Claude Code produces a comprehensive documentation package.

4. **Automated Security Review (ITSG/NIST)** — Claude Code performs an automated security assessment against recognized frameworks:
   - **ITSG** (Information Technology Security Guidance — Government of Canada)
   - **NIST** (National Institute of Standards and Technology — United States)

   This step ensures that security is not an afterthought but is baked into the development cycle with automated compliance checks.

### Notebook LM Integration

The security review and final documentation are fed into **Notebook LM** for a third time, producing the same document suite (Report, Slide Deck, Audio Blog, Data Table). A second **Notebook LM** instance also appears at this stage, suggesting that multiple Notebook LM runs may process different subsets of the development artifacts in parallel — for example, one handling the security report and another handling the feature documentation.

### Review Gate

All development outputs go through a final **Review** before proceeding to the pull request stage. As with every prior gate, a **Rework & Refine** loop is available to cycle back through development if issues are found.

---

## Phase 5 — Code Review and Deployment

### Pull Request

**Claude Code** creates a **Pull Request** containing all the developed code, tests, and documentation.

### Multi-Agent Review

The pull request is reviewed by multiple agents working in concert:

- **Multiple Sub-Agent Review** — several AI sub-agents examine the code from different angles (correctness, style, performance, security, test coverage). This is an agentic review layer where specialized agents each bring a focused lens to the code.
- **GitHub CoPilot PR Reviewer** — GitHub's own AI-powered reviewer provides an additional, independent assessment of the pull request.

This dual-layer review — internal sub-agents plus an external AI reviewer — creates a robust quality gate that catches issues a single reviewer might miss.

### Feedback Loop

The results of both reviews flow into a **Review and Respond to Feedback** step, where Claude Code addresses comments, fixes issues, and updates the pull request. This is an iterative loop — the PR may go through multiple rounds of review and revision.

### Approval and Merge

Once all reviewers are satisfied, the pull request reaches the **Approve** gate. Upon approval, the code is **Merged to Main**, which triggers deployment.

A final **Rework & Refine** loop exists even at this stage — if the approval review surfaces late-breaking concerns, the workflow can cycle back rather than forcing a premature merge.

---

## AI and Agent Integration Summary

| Agent / Platform | Role in Workflow | Phases Active |
|---|---|---|
| **Claude Co-Work** | Collaborative ideation and concept development | Phase 1 (Ideation) |
| **Claude Code** | Requirements authoring, architecture design, automated development, testing, documentation, security review, PR creation, and feedback response | Phases 2–5 |
| **Notebook LM** | Transforms technical Markdown into multi-format deliverables (Report, Slide Deck, Audio Blog, Data Table) | Phases 1, 3, 4 |
| **GitHub CoPilot PR Reviewer** | Independent AI-powered code review on pull requests | Phase 5 |
| **Multiple Sub-Agents** | Specialized review agents examining code from different quality dimensions | Phase 5 |

---

## Key Design Principles

### Iterative by Default

Every phase includes a Rework & Refine loop. Nothing is considered final on the first pass — the workflow assumes iteration and builds it into the structure rather than treating rework as a failure.

### Documentation as a First-Class Output

Notebook LM appears three times in the workflow, each time converting technical artifacts into four distinct formats. This means the project generates a rich documentation trail — reports, presentations, audio summaries, and structured data — at every major milestone, not just at the end.

### Security Built In, Not Bolted On

The automated ITSG/NIST security review happens during development, before the pull request is even created. Security findings feed back into the development loop, ensuring vulnerabilities are addressed before code reaches review.

### Multi-Agent Quality Assurance

The code review stage uses multiple independent AI reviewers rather than relying on a single agent. This diversity of perspective reduces the risk of blind spots and produces more thorough feedback.

### Human-in-the-Loop at Every Gate

Despite the heavy automation, every review gate is a point where human judgment can intervene — approving, rejecting, or redirecting the workflow. The AI agents accelerate the work, but humans retain control over the decisions.
