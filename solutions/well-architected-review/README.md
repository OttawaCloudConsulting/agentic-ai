# AWS Well-Architected Review — Solution Kit

A multi-agent Claude Code solution that performs an AWS Well-Architected Framework (WAF) review against a project's architecture documentation and Infrastructure as Code. Pre-deployment design review only — no live AWS account access required.

## Prerequisites

| Prerequisite | Required | How to Check |
|---|---|---|
| Claude Code CLI | Yes | `claude --version` |
| `uvx` (Python package runner) | Yes | `which uvx` — install via `pip install uv` |
| AWS credentials | No | Only needed for optional cost pricing enrichment |

The target project must contain two documents before the review can begin:

- **`docs/TENANT_PROFILE.md`** — describes the AWS tenant environment (governance framework, inherited controls, account structure, network boundaries, compliance baselines)
- **`docs/ARCHITECTURE_AND_DESIGN.md`** — describes the workload architecture, design decisions, component inventory, and deployment model

The orchestrator's pre-flight check validates both documents exist and provides guidance if missing.

## Install

Copy agents, skills, and MCP configuration into your target project:

```bash
# From the agentic-ai repo root (or adjust paths)
TARGET=/path/to/your/project

# 1. Copy agents
mkdir -p "$TARGET/.claude/agents"
cp solutions/well-architected-review/agents/*.md "$TARGET/.claude/agents/"

# 2. Copy skills
mkdir -p "$TARGET/.claude/skills"
cp -r solutions/well-architected-review/skills/war-governance-profiler "$TARGET/.claude/skills/"
cp -r solutions/well-architected-review/skills/war-discovery-interview "$TARGET/.claude/skills/"

# 3. Copy MCP config (merge manually if .mcp.json already exists)
cp solutions/well-architected-review/mcp.json "$TARGET/.mcp.json"
```

If the target project already has a `.mcp.json`, merge the two `mcpServers` entries (`awslabs-aws-documentation` and `awslabs-iac`) into the existing file rather than overwriting it.

## Verify Installation

```bash
cd /path/to/your/project

# Agents installed
ls .claude/agents/war-*.md
# Expected: war-orchestrator.md  war-cataloguer.md  war-architecture-reviewer.md
#           war-discovery-analyst.md  war-pillar-reviewer.md

# Skills installed
ls .claude/skills/war-governance-profiler/SKILL.md
ls .claude/skills/war-discovery-interview/SKILL.md

# MCP config
cat .mcp.json | grep awslabs

# uvx available
which uvx

# Pre-requisite documents
ls docs/TENANT_PROFILE.md docs/ARCHITECTURE_AND_DESIGN.md
```

## Usage

Start the review by invoking the orchestrator agent:

```
claude "Run the war-orchestrator agent against this project"
```

The orchestrator drives a 5-phase workflow:

1. **Governance + Cataloguing** — profiles tenant controls, catalogues documentation and code
2. **Architecture Review** — WAF-structured reviews of documentation and code
3. **Discovery** — interactive interview about requirements, then gap analysis with proceed/stop recommendation
4. **Pillar Reviews** — 6 parallel reviews (one per WAF pillar)
5. **Finalization** — generates a README reading guide with findings summary, then deletes the progress tracker

A decision gate between Phase 3 and Phase 4 always surfaces the analyst's recommendation to you. The workflow halts if gaps are severe.

All deliverables are written to `docs/well-architected-review/`. The orchestrator maintains `PROGRESS.md` and supports resume from checkpoint — if interrupted, re-invoke the orchestrator and it picks up where it left off.

### Deliverables

| Document | Phase | Description |
|---|---|---|
| `GOVERNANCE_PROFILE.md` | 1 | Tenant controls mapped to WAF pillars (inherited vs workload) |
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
| `README.md` | 5 | Reading guide with findings summary and relative links to all deliverables |

`PROGRESS.md` is maintained during the review as a workflow checkpoint (enabling resume if interrupted) and deleted upon successful completion.

## MCP Servers

Three MCP servers provide authoritative AWS content to review agents.

| Server | Required | Auth | What It Accesses |
|---|---|---|---|
| `awslabs-aws-documentation` | Yes | None | Public AWS documentation via API |
| `awslabs-iac` | Yes | None | Local CloudFormation/CDK templates in the project directory |
| `awslabs-aws-pricing` | No | AWS creds (`pricing:*`) | AWS Pricing API (public pricing data, read-only) |

### Per-Agent MCP Access

| Agent | aws-documentation | iac-server | aws-pricing |
|---|:-:|:-:|:-:|
| war-orchestrator | — | — | — |
| war-cataloguer | — | — | — |
| war-architecture-reviewer | Yes | — | — |
| war-discovery-analyst | — | — | — |
| war-pillar-reviewer | Yes | Security pillar | Cost pillar (optional) |
| war-governance-profiler (skill) | — | — | — |
| war-discovery-interview (skill) | — | — | — |

The two required servers are defined in `mcp.json` (project-scoped, no auth). The optional pricing server is defined inline in `war-pillar-reviewer.md` and only activates for the Cost Optimization pillar when AWS credentials are available.

### Enabling aws-pricing (Optional)

To enable cost pricing enrichment, edit `.claude/agents/war-pillar-reviewer.md` and uncomment the inline `awslabs-aws-pricing` MCP server definition in the frontmatter. Requires AWS credentials with `pricing:GetProducts` and `pricing:DescribeServices` permissions.

The solution functions fully without this server — the cost pillar review will still cover cost optimization practices, just without real-time pricing data.

## Components

| Component | Type | File |
|---|---|---|
| Orchestrator | Agent | `agents/war-orchestrator.md` |
| Cataloguer | Agent | `agents/war-cataloguer.md` (parameterized: docs or code) |
| Architecture Reviewer | Agent | `agents/war-architecture-reviewer.md` (parameterized: doc-driven or code-driven) |
| Discovery Analyst | Agent | `agents/war-discovery-analyst.md` |
| Pillar Reviewer | Agent | `agents/war-pillar-reviewer.md` (invoked 6x, one per pillar) |
| Governance Profiler | Skill | `skills/war-governance-profiler/SKILL.md` |
| Discovery Interview | Skill | `skills/war-discovery-interview/SKILL.md` |
| MCP Config | Config | `mcp.json` |

## Troubleshooting

### Pre-flight fails: missing TENANT_PROFILE.md

Create `docs/TENANT_PROFILE.md` describing your AWS tenant environment. Include: governance framework (Control Tower, LZA, custom), inherited controls (SCPs, guardrails, Config rules), centralized services (CloudTrail, GuardDuty, Security Hub), account structure, network boundaries, and compliance baselines.

### Pre-flight fails: missing ARCHITECTURE_AND_DESIGN.md

Create `docs/ARCHITECTURE_AND_DESIGN.md` describing your workload architecture, component inventory, design decisions, and deployment model.

### uvx not found

Install the `uv` package manager:

```bash
pip install uv
# or
brew install uv
```

Verify with `which uvx`.

### MCP servers fail to start

MCP servers are launched via `uvx` at runtime. Common issues:

- **`uvx` not on PATH** — ensure `uv` is installed and `uvx` is accessible
- **Network issues** — MCP servers are downloaded on first use; ensure internet access
- **Python version** — `uvx` requires Python 3.8+

### Orchestrator interrupted mid-review

Re-invoke the orchestrator. It reads `docs/well-architected-review/PROGRESS.md` and resumes from the last completed phase, skipping phases whose deliverables already exist.

### Decision gate recommends "stop"

The discovery analyst found significant gaps between documentation, code, and stated requirements. Review the gaps listed in `docs/well-architected-review/DISCOVERY_ANALYSIS.md`, address the issues, and re-run the orchestrator. The checkpoint resume will skip completed phases and re-run discovery.

### Terraform projects

The `iac-mcp-server` targets CloudFormation and CDK templates. For Terraform projects, IaC files are still catalogued and reviewed as code, but MCP-based template validation is not available. Consider additionally integrating HashiCorp's official Terraform MCP server.
