# Architecture and Design: [Project Title]

<!-- Omit sections that don't apply. Add sections the project needs that aren't listed here. -->

## Overview

[Narrative describing what the system does, the major components involved, and how they relate.
Expand from the PRD summary. This section should stand alone as a complete description.]

## Component Diagram

<!-- Use the format that best fits the project:
     - ASCII/Unicode boxes for infrastructure (CloudFront → S3, VPC topology)
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
     Use "Terraform Type" or "CDK Construct" instead of "Type" for IaC projects. -->

| # | Component | Type / Technology | Purpose |
|---|-----------|-------------------|---------|
| 1 | | | |

## Security Model

### Encryption

[At-rest and in-transit strategies.]

### Access Control

[IAM policies, bucket policies, role trust relationships, or equivalent.]

### Edge Protection

<!-- Include if applicable: WAF, Shield, CloudFront geo-restriction, security groups. -->

### Audit and Logging

<!-- Include if the project produces audit trails, access logs, or CloudTrail events. -->

### Response Headers

<!-- Include if the project configures HTTP security headers (HSTS, CSP, X-Frame-Options). -->

## File Organization

```
project-root/
├── file.tf          # What this file contains
├── other-file.tf    # What this file contains
└── subdir/
    └── nested.tf    # What this file contains
```

## Configuration

<!-- Include for projects that expose configurable inputs (Terraform modules, CDK constructs,
     CLI tools, libraries). Split Required and Optional. Group Optional by concern.
     Use "Variable" instead of "Parameter" in the column header for IaC projects if preferred. -->

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

     PHASED (for two-phase deploys, e.g. ACM cert validation before CloudFront association):
       Phase 1: [First apply — what gets created, what stays unconfigured]
       Phase 2: [Manual step] → [Second apply — what gets wired up]

     STEP-BY-STEP (for standard linear deploys):
       1. Prerequisites
       2. terraform init / cdk bootstrap
       3. Plan / synth
       4. Apply / deploy
       5. Smoke test

     PIPELINE (for CI/CD-managed deployments):
       Stage 1 → Stage 2 → Stage 3 (show artifact flow between stages) -->

## Dependency Graph

<!-- Include for infrastructure projects or when component initialization order matters.
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
