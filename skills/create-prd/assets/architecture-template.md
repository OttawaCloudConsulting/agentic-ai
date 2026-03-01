# Architecture and Design: [Project Title]

<!-- Omit sections that don't apply. Add sections the project needs that aren't listed here. -->

## Overview

[Narrative describing what the system does, the major components involved, and how they relate.
Expand from the PRD summary. This section should stand alone as a complete description.]

## Component Diagram

<!-- Use the format that best fits the project:
     - ASCII/Unicode boxes for infrastructure or network topology
     - Mermaid flowchart for service interaction diagrams
     - Text tree for script/module structure -->

```
[Diagram here]
```

## Data Flow

<!-- Include when the system has a meaningful request or data path to describe.
     Omit for simple single-component projects. -->

[Step-by-step description of how data or requests move through the system.]

## Component Inventory

<!-- Column selection: always include #, Resource/Component, Type/Technology.
     Add Region if multi-region. Add Quantity if resources are created in multiples.
     Adapt column headers to the project (e.g., "Terraform Type" for IaC, "Service" for microservices). -->

| # | Component | Type / Technology | Purpose |
|---|-----------|-------------------|---------|
| 1 | | | |

## Security Model

### Encryption

[At-rest and in-transit strategies.]

### Access Control

[Authentication and authorization strategy. Role-based access, API keys, OAuth, or equivalent.]

### Edge Protection

<!-- Include if applicable: WAF, rate limiting, geo-restriction, firewall rules, security groups. -->

### Audit and Logging

<!-- Include if the project produces audit trails, access logs, or event records. -->

### Response Headers

<!-- Include if the project configures HTTP security headers (HSTS, CSP, X-Frame-Options). -->

## File Organization

```
project-root/
├── file.ext         # What this file contains
├── other-file.ext   # What this file contains
└── subdir/
    └── nested.ext   # What this file contains
```

## Configuration

<!-- Include for projects that expose configurable inputs (modules, libraries, CLI tools,
     services). Split Required and Optional. Group Optional by concern.
     Adapt column headers to the project (e.g., "Variable" for IaC, "Flag" for CLI tools). -->

### Required

| Parameter | Type | Validation | Description |
|-----------|------|------------|-------------|
| | | | |

### Optional — [Group Name]

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| | | | |

## Outputs

<!-- Include for projects that produce artifacts consumed by other systems or callers. -->

| Output | Type | Description |
|--------|------|-------------|
| | | |

## Design Decisions

<!-- Target: 10–20 decisions for a substantial architecture. Capture every non-obvious choice.
     Add "Alternatives Considered" column when the rejected alternatives matter to future readers. -->

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | | |
| 2 | | |

## Deployment Workflow

<!-- Use the pattern that matches the project's deployment model:

     PHASED (for multi-phase deploys with intermediate manual steps):
       Phase 1: [What gets created or configured]
       Phase 2: [Manual step] → [What gets wired up or finalized]

     STEP-BY-STEP (for standard linear deploys):
       1. Prerequisites
       2. Initialize / bootstrap
       3. Plan / preview
       4. Apply / deploy
       5. Smoke test

     PIPELINE (for CI/CD-managed deployments):
       Stage 1 → Stage 2 → Stage 3 (show artifact flow between stages) -->

## Dependency Graph

<!-- Include when component initialization or build order matters.
     Show both logical dependencies and initialization sequence. -->

```
[Component A]
    └── depends on [Component B]
        └── depends on [Component C]
```

## Out of Scope

<!-- Expand from PRD non-goals. Include rationale — this prevents scope-creep conversations. -->

| Item | Rationale |
|------|-----------|
| | |
