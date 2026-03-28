# AWS Well-Architected Review Solution Kit

## Overview

A multi-construct Claude Code solution kit that performs an AWS Well-Architected Framework (WAF) review against a project's architecture documentation and Infrastructure as Code. An orchestrator agent drives a 4-phase workflow: cataloguing, architecture review, discovery (interactive interview + gap analysis), and per-pillar WAF assessment. All phases produce markdown deliverable documents. Reviews code and documentation only — no live AWS account access.

Ships as a self-contained kit: 5 agent files, 2 skill bundles, and 1 MCP configuration file. Install by copying to three targets in the consumer project.

## Architecture

```
war-orchestrator
├── Phase 1: Governance + Cataloguing
│   ├── war-governance-profiler (skill, inline)  → GOVERNANCE_PROFILE.md
│   ├── war-cataloguer (docs, parallel)          → DOCUMENT_CATALOGUE.md
│   └── war-cataloguer (code, parallel)          → CODE_CATALOGUE.md
│
├── Phase 2: Architecture Review (parallel)
│   ├── war-architecture-reviewer (doc-driven)   → DOCUMENT_ARCHITECTURE_REVIEW.md
│   └── war-architecture-reviewer (code-driven)  → CODE_ARCHITECTURE_REVIEW.md
│
├── Phase 3: Discovery (sequential)
│   ├── war-discovery-interview (skill, inline)  → DESIGN_REQUIREMENTS.md
│   ├── war-discovery-analyst (agent)            → DISCOVERY_ANALYSIS.md
│   └── DECISION GATE (surfaced to user)
│
└── Phase 4: Pillar Reviews (parallel, 6x)
    └── war-pillar-reviewer (per pillar)         → PILLAR_*.md
```

## Components

| # | Component | Type | Purpose |
|---|-----------|------|---------|
| 1 | `war-orchestrator.md` | Agent | Drives 4-phase workflow, spawns sub-agents, manages gate and resume |
| 2 | `war-cataloguer.md` | Agent | Reads project files, produces catalogue (parameterized: docs or code) |
| 3 | `war-architecture-reviewer.md` | Agent | Produces WAF-structured review from a catalogue (parameterized: doc-driven or code-driven) |
| 4 | `war-discovery-analyst.md` | Agent | Gap analysis across all deliverables, proceed/stop recommendation |
| 5 | `war-pillar-reviewer.md` | Agent | Reviews one WAF pillar (invoked 6x with pillar name as parameter) |
| 6 | `war-discovery-interview/` | Skill | Interactive user interview via `AskUserQuestion`, produces requirements doc |
| 7 | `war-governance-profiler/` | Skill | Reads tenant profile, produces governance baseline, resolves gaps via `AskUserQuestion` |
| 8 | `mcp.json` | Config | Project-scoped MCP server definitions (documentation + IaC servers) |

## Pre-Requisites

The target project must have two documents before the review can begin:

| Document | Purpose |
|----------|---------|
| `docs/TENANT_PROFILE.md` | Describes the AWS tenant/governance environment (Control Tower, SCPs, centralized services, compliance baselines) |
| `docs/ARCHITECTURE_AND_DESIGN.md` | Describes the workload architecture, design decisions, and deployment model |

Pre-flight validation fails with guidance if either is missing.

**Runtime requirements:** `uvx` (Python package runner) for MCP server launch. Install via `pip install uv`.

## MCP Servers

| Server | Distribution | Auth | Used By |
|--------|-------------|------|---------|
| `awslabs-aws-documentation-mcp-server` | `.mcp.json` | None | Architecture reviewer, pillar reviewers |
| `awslabs-iac-mcp-server` | `.mcp.json` | None | Pillar reviewer (Security) |
| `awslabs-aws-pricing-mcp-server` | Inline in agent | AWS creds (optional) | Pillar reviewer (Cost) |

The solution functions without any MCP servers (degraded quality). Functions fully with just `uvx` installed.

## Workflow

1. **Pre-flight** — validates prerequisites, checks tools, warns about existing deliverables
2. **Phase 1** — governance profiler runs inline (interactive), cataloguers run in parallel
3. **Phase 2** — two architecture reviewers run in parallel, reference governance profile
4. **Phase 3** — discovery interview (interactive), then analyst produces gap analysis
5. **Decision gate** — analyst recommendation surfaced to user; proceeds or halts
6. **Phase 4** — six pillar reviewers run in parallel, classify findings as workload gap vs inherited

Checkpoint resume: orchestrator reads `PROGRESS.md` and skips completed phases.

## Deliverables

All output writes to `docs/well-architected-review/` in the target project.

| Document | Phase | Description |
|----------|-------|-------------|
| `GOVERNANCE_PROFILE.md` | 1 | Tenant controls mapped to WAF pillars |
| `DOCUMENT_CATALOGUE.md` | 1 | Documentation file inventory with summaries |
| `CODE_CATALOGUE.md` | 1 | IaC/code file inventory with summaries |
| `DOCUMENT_ARCHITECTURE_REVIEW.md` | 2 | WAF review based on documentation |
| `CODE_ARCHITECTURE_REVIEW.md` | 2 | WAF review based on code |
| `DESIGN_REQUIREMENTS.md` | 3 | Solution requirements from user interview |
| `DISCOVERY_ANALYSIS.md` | 3 | Gap analysis with proceed/stop recommendation |
| `PILLAR_OPERATIONAL_EXCELLENCE.md` | 4 | Operational Excellence pillar review |
| `PILLAR_SECURITY.md` | 4 | Security pillar review |
| `PILLAR_RELIABILITY.md` | 4 | Reliability pillar review |
| `PILLAR_PERFORMANCE_EFFICIENCY.md` | 4 | Performance Efficiency pillar review |
| `PILLAR_COST_OPTIMIZATION.md` | 4 | Cost Optimization pillar review |
| `PILLAR_SUSTAINABILITY.md` | 4 | Sustainability pillar review |
| `PROGRESS.md` | All | Workflow progress tracker updated per phase |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Solution kit as new content category (`solutions/`) | Multi-construct solution doesn't fit single-type categories (commands, skills, rules) |
| Orchestrator + sub-agents | Multi-phase workflow with parallel execution, interactive interview, and decision gate exceeds single agent scope |
| Skills for interactive components | Sub-agents cannot use `AskUserQuestion`; interview and governance profiler must run inline |
| Parameterized agents | One cataloguer and one reviewer file, invoked with different parameters. Reduces file count from 9 to 5 |
| Documents as inter-agent interface | Markdown deliverables are debuggable, resumable, and auditable |
| Decision gate always surfaces to user | Analyst recommends but does not decide. Prevents false-proceed on severe gaps |
| Governance profile informs, does not suppress | Inherited controls documented as strengths, not omitted. Findings classified as workload gap vs inherited |
| Code/docs review only | Pre-deployment design review. No live AWS access, no broad credential requirements |

## Install

```bash
TARGET=/path/to/project

# Agents
cp solutions/well-architected-review/agents/*.md  $TARGET/.claude/agents/

# Skills
cp -r solutions/well-architected-review/skills/war-governance-profiler  $TARGET/.claude/skills/
cp -r solutions/well-architected-review/skills/war-discovery-interview  $TARGET/.claude/skills/

# MCP config (merge if .mcp.json already exists)
cp solutions/well-architected-review/mcp.json  $TARGET/.mcp.json
```

## Usage

```
@war-orchestrator
```

The orchestrator runs all 4 phases, manages sub-agents, and produces the full deliverable set. Supports checkpoint resume if interrupted.

## Related

- [Solution kit README](../../solutions/well-architected-review/README.md) — install guide, troubleshooting
- [Architecture and Design](../../solutions/well-architected-review/docs/ARCHITECTURE_AND_DESIGN.md) — full design reference
