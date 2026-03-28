# Architecture and Design: AWS Well-Architected Review Solution Kit

## Overview

A multi-construct Claude Code solution kit that performs an AWS Well-Architected Framework (WAF) review against a project's architecture documentation and Infrastructure as Code. The solution uses an orchestrator agent to drive a 5-phase workflow: cataloguing, architecture review, discovery (interactive interview + gap analysis), per-pillar WAF assessment, and finalization (README generation + cleanup). All phases produce markdown deliverable documents that serve as the interface between agents. Reviews code and documentation only — no live AWS account access.

The solution ships as a self-contained kit: 5 agent files, 2 skill bundles, and 1 MCP configuration file. Consumers copy these to three targets in their project (`.claude/agents/`, `.claude/skills/`, `.mcp.json`).

The solution requires two pre-requisite documents in the target project: `docs/TENANT_PROFILE.md` (describes the AWS tenant/governance environment) and `docs/ARCHITECTURE_AND_DESIGN.md` (describes the workload architecture). Pre-flight validation fails if either is missing.

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     war-orchestrator                            │
│  (drives phases, spawns sub-agents, manages gate, resume)       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: Governance + Cataloguing                              │
│  ┌──────────────────────┐                                       │
│  │ war-governance-      │  inline skill                         │
│  │ profiler (SKILL)     │  (reads TENANT_PROFILE.md)            │
│  └──────────┬───────────┘                                       │
│             ▼                                                   │
│  GOVERNANCE_PROFILE.md                                          │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │ war-cataloguer (docs)│  │ war-cataloguer (code)│  parallel   │
│  └──────────┬───────────┘  └──────────┬───────────┘             │
│             │                         │                         │
│             ▼                         ▼                         │
│  DOCUMENT_CATALOGUE.md      CODE_CATALOGUE.md                   │
│                                                                 │
│  Phase 2: Architecture Review                                   │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │ war-arch-reviewer    │  │ war-arch-reviewer    │  parallel   │
│  │ (doc-driven)         │  │ (code-driven)        │             │
│  └──────────┬───────────┘  └──────────┬───────────┘             │
│             │                         │                         │
│             ▼                         ▼                         │
│  DOC_ARCHITECTURE_REVIEW.md CODE_ARCHITECTURE_REVIEW.md         │
│                                                                 │
│  Phase 3: Discovery                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │ war-discovery-       │  │ war-discovery-       │             │
│  │ interview (SKILL)    │→ │ analyst (AGENT)      │  sequential │
│  └──────────┬───────────┘  └──────────┬───────────┘             │
│             │                         │                         │
│             ▼                         ▼                         │
│  DESIGN_REQUIREMENTS.md    DISCOVERY_ANALYSIS.md                │
│                                      │                          │
│                            ┌──────────▼──────────┐              │
│                            │   DECISION GATE     │              │
│                            │ (surfaced to user)  │              │
│                            └─────────┬───────────┘              │
│                                      │                          │
│  Phase 4: Pillar Reviews (if gate passes)                       │
│  ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐   │
│  │Oper.   ││Security││Reliab. ││Perf.   ││Cost    ││Sustain.│   │
│  │Excel.  ││        ││        ││Effic.  ││Optim.  ││        │   │
│  └───┬────┘└───┬────┘└───┬────┘└───┬────┘└───┬────┘└───┬────┘   │
│      ▼         ▼         ▼         ▼         ▼         ▼        │
│  PILLAR_*.md (6 documents, all parallel)                        │
│                                                                 │
│  Phase 5: Finalization                                          │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │ Generate README.md   │→ │ Delete PROGRESS.md   │  sequential │
│  │ (reading guide)      │  │ (cleanup)            │             │
│  └──────────────────────┘  └──────────────────────┘             │
└─────────────────────────────────────────────────────────────────┘

External:
┌──────────────────────────┐  ┌──────────────────────┐
│ aws-documentation-mcp    │  │ iac-mcp-server       │  via .mcp.json
│ (WAF guidance, no auth)  │  │ (template validation)│  (project-scoped)
└──────────────────────────┘  └──────────────────────┘
┌──────────────────────────┐
│ aws-pricing-mcp          │  inline in war-pillar-reviewer.md
│ (optional, AWS creds)    │  (cost pillar only)
└──────────────────────────┘
```

## Data Flow

1. **Orchestrator** runs pre-flight check: validates `docs/TENANT_PROFILE.md` and `docs/ARCHITECTURE_AND_DESIGN.md` exist (hard gate), checks uvx, MCP servers, output directory, existing deliverables.
2. **Orchestrator** invokes `war-governance-profiler` skill inline. The skill reads `docs/TENANT_PROFILE.md`, uses `AskUserQuestion` to resolve gaps, writes `GOVERNANCE_PROFILE.md`. Orchestrator then spawns 2 `war-cataloguer` agents in parallel with context: "catalogue documentation" / "catalogue code". Each agent reads the project, writes a catalogue file.
3. **Orchestrator** spawns 2 `war-architecture-reviewer` agents in parallel, passing file paths to catalogues, `GOVERNANCE_PROFILE.md`, plus brief summaries. Each reviewer reads the catalogue, governance profile, and source files, writes an architecture review.
4. **Orchestrator** invokes `war-discovery-interview` skill inline. The skill interviews the user via `AskUserQuestion`, writes `DESIGN_REQUIREMENTS.md`.
5. **Orchestrator** spawns `war-discovery-analyst` agent, passing paths to all 6 prior deliverables (1 governance profile, 2 catalogues, 2 architecture reviews, 1 requirements doc). Analyst reads them, writes `DISCOVERY_ANALYSIS.md` with gaps and proceed/stop recommendation.
6. **Orchestrator** reads the analyst output. If "stop": presents gaps to user, halts. If "proceed": presents summary, asks user confirmation.
7. **Orchestrator** spawns 6 `war-pillar-reviewer` agents in parallel (one per WAF pillar), passing pillar name, file paths (including `GOVERNANCE_PROFILE.md`), and brief context. Each writes `PILLAR_<name>.md`. Pillar reviewers classify findings as "workload gap" vs "inherited from governance."
8. **Orchestrator** updates `PROGRESS.md` after each phase. Supports resume from checkpoint.
9. **Orchestrator** generates `README.md` with process overview, recommended reading order, relative links to all deliverables, and a finding summary table extracted from pillar reviews.
10. **Orchestrator** verifies all 14 deliverables exist, then deletes `PROGRESS.md`. If any deliverable is missing, keeps `PROGRESS.md` and warns the user.

## Component Inventory

| # | Component | Type | Purpose |
|---|-----------|------|---------|
| 1 | `war-orchestrator.md` | Agent | Drives 4-phase workflow, spawns sub-agents, manages gate and resume |
| 2 | `war-cataloguer.md` | Agent | Reads project files, produces catalogue (parameterized: docs or code) |
| 3 | `war-architecture-reviewer.md` | Agent | Produces WAF-structured review from a catalogue (parameterized: doc-driven or code-driven) |
| 4 | `war-discovery-analyst.md` | Agent | Gap analysis across all deliverables, proceed/stop recommendation |
| 5 | `war-pillar-reviewer.md` | Agent | Reviews one WAF pillar (invoked 6x with pillar name as parameter) |
| 6 | `war-discovery-interview/SKILL.md` | Skill | Interactive user interview via `AskUserQuestion`, produces requirements doc |
| 7 | `war-governance-profiler/SKILL.md` | Skill | Reads tenant profile, produces governance baseline, resolves gaps via `AskUserQuestion` |
| 8 | `mcp.json` | Config | Project-scoped MCP server definitions (documentation + IaC servers) |
| 9 | `README.md` | Documentation | Install guide, prerequisites, MCP permissions, verification, usage |

## Agent Specifications

### war-orchestrator.md

```yaml
name: war-orchestrator
description: "Drives a full AWS Well-Architected Framework review across a project's documentation and code."
tools: Agent, Read, Write, Bash, Glob, Grep, AskUserQuestion
model: sonnet
maxTurns: 50
permissionMode: default
```

No MCP servers. Delegates all MCP-dependent work to sub-agents. High maxTurns to accommodate the multi-phase workflow with parallel agent spawning and gate logic.

### war-cataloguer.md

```yaml
name: war-cataloguer
description: "Catalogues project documentation or code files with structured summaries."
tools: Read, Glob, Grep, Write
model: sonnet
maxTurns: 20
permissionMode: default
```

No MCP servers. Read-heavy agent — scans the project tree, reads files, writes one catalogue document. Parameterized via orchestrator prompt: "catalogue documentation files" or "catalogue IaC and code files".

### war-architecture-reviewer.md

```yaml
name: war-architecture-reviewer
description: "Produces a Well-Architected Framework review from a project catalogue."
tools: Read, Glob, Grep, Write
model: sonnet
maxTurns: 25
permissionMode: default
mcpServers:
  - awslabs-aws-documentation
```

Uses `aws-documentation-mcp-server` for authoritative WAF pillar guidance. Reads catalogue + source files, writes one architecture review. Parameterized: "doc-driven review" or "code-driven review".

### war-discovery-analyst.md

```yaml
name: war-discovery-analyst
description: "Performs gap analysis across WAR deliverables and recommends proceed or stop."
tools: Read, Grep, Write
model: sonnet
maxTurns: 15
permissionMode: default
```

No MCP servers. Reads all 6 prior deliverables (1 governance profile, 2 catalogues, 2 architecture reviews, 1 requirements doc), produces gap analysis with structured output: gaps list, severity, recommendation. Lower maxTurns — focused analytical task.

### war-pillar-reviewer.md

```yaml
name: war-pillar-reviewer
description: "Reviews one AWS Well-Architected Framework pillar against project documentation and code."
tools: Read, Glob, Grep, Write, Bash
model: sonnet
maxTurns: 25
permissionMode: default
mcpServers:
  - awslabs-aws-documentation
  - awslabs-iac
```

Uses `aws-documentation-mcp-server` for pillar-specific guidance and `iac-mcp-server` for template validation. Cost pillar additionally has optional inline `aws-pricing-mcp-server` definition:

```yaml
# Inline MCP server (optional, requires AWS credentials)
mcpServers:
  - awslabs-aws-documentation
  - awslabs-iac
  - awslabs-aws-pricing:
      type: stdio
      command: uvx
      args: ["awslabs.aws-pricing-mcp-server"]
```

Invoked 6 times with pillar name as parameter. Hardcoded pillar list in orchestrator:

1. Operational Excellence
2. Security
3. Reliability
4. Performance Efficiency
5. Cost Optimization
6. Sustainability

### war-governance-profiler (Skill)

```yaml
name: war-governance-profiler
description: "Reads tenant profile and produces a WAR-specific governance baseline with inherited controls mapped to WAF pillars."
disable-model-invocation: true
```

Must be a skill (not agent) because it requires `AskUserQuestion` to resolve gaps in the tenant profile. Reads `docs/TENANT_PROFILE.md`, maps tenant-level controls (SCPs, guardrails, centralized services, compliance baselines) to the 6 WAF pillars, and writes `GOVERNANCE_PROFILE.md`. For each pillar, identifies which controls are inherited (satisfied at org/account level) vs which remain the workload's responsibility. No MCP servers required.

### war-discovery-interview (Skill)

```yaml
name: war-discovery-interview
description: "Interactive interview to gather solution requirements for AWS Well-Architected Review."
disable-model-invocation: true
```

Must be a skill (not agent) because sub-agents cannot use `AskUserQuestion` interactively. The orchestrator invokes this skill inline in the main conversation context.

## MCP Server Architecture

### Distribution

| Server | Distribution | Scope | Auth |
|--------|-------------|-------|------|
| `awslabs-aws-documentation-mcp-server` | `.mcp.json` (project) | Session-wide, all agents | None |
| `awslabs-iac-mcp-server` | `.mcp.json` (project) | Session-wide, used by architecture reviewer + pillar reviewers | None |
| `awslabs-aws-pricing-mcp-server` | Inline in `war-pillar-reviewer.md` | Agent-scoped, cost pillar only | AWS creds + `pricing:*` |

### Per-Agent MCP Access

| Agent | aws-documentation | iac-server | aws-pricing |
|-------|:-:|:-:|:-:|
| war-orchestrator | — | — | — |
| war-cataloguer | — | — | — |
| war-architecture-reviewer | via .mcp.json | — | — |
| war-discovery-analyst | — | — | — |
| war-pillar-reviewer (Security) | via .mcp.json | via .mcp.json | — |
| war-pillar-reviewer (Cost) | via .mcp.json | via .mcp.json | inline (optional) |
| war-pillar-reviewer (Others) | via .mcp.json | — | — |
| war-governance-profiler (skill) | — | — | — |
| war-discovery-interview (skill) | — | — | — |

### MCP Permissions (for README)

| Server | What It Accesses | What It Cannot Access |
|--------|-----------------|----------------------|
| `aws-documentation` | Public AWS documentation via API | No AWS account data, no credentials used |
| `iac-server` | Local CloudFormation/CDK templates in the project directory | No remote resources, no AWS API calls |
| `aws-pricing` | AWS Pricing API (public pricing data) | Requires AWS credentials but only calls `pricing:*` (free, read-only) |

## Deliverable Document Specifications

### Governance Profile (GOVERNANCE_PROFILE.md)

Maps tenant-level controls to WAF pillars. Produced by the governance profiler skill from `docs/TENANT_PROFILE.md`.

```markdown
# Governance Profile

## Tenant Environment

[Summary: governance framework (Control Tower / LZA / custom), account structure, OU placement]

## Inherited Controls by Pillar

### Operational Excellence

| Control | Source | Inherited? | Notes |
|---------|--------|:----------:|-------|
| CloudTrail logging | LZA centralized logging | Yes | Org-trail, all regions |
| ... | ... | ... | ... |

### Security
[Same table format]

### Reliability
[Same table format]

### Performance Efficiency
[Same table format]

### Cost Optimization
[Same table format]

### Sustainability
[Same table format]

## Workload Responsibilities

[Controls NOT inherited — the workload must implement these. Grouped by pillar.]

## Unresolved Items

[Questions that could not be answered from TENANT_PROFILE.md or user interview]
```

### Catalogue Documents (DOCUMENT_CATALOGUE.md, CODE_CATALOGUE.md)

```markdown
# [Document|Code] Catalogue

## path/to/file.ext

[1-2 paragraph summary of file contents, purpose, and relevance to architecture]

## path/to/another-file.ext

[1-2 paragraph summary]
```

### Architecture Review Documents

WAF-structured review with sections per pillar plus continuous improvement and framework review. Narrative format with evidence citations referencing specific files and line ranges from the catalogue.

### Design Requirements Document (DESIGN_REQUIREMENTS.md)

Structured requirements captured from user interview. Sections: Business Objectives, Workload Characteristics, Compliance Requirements, Performance Requirements, Security Assessment, Cost Analysis.

### Discovery Analysis Document (DISCOVERY_ANALYSIS.md)

```markdown
# Discovery Analysis

## Gaps

| # | Gap | Source Documents | Severity |
|---|-----|-----------------|----------|
| 1 | [Description] | [Which docs conflict] | Major/Minor |

## Assessment

- **Overall severity:** Major | Minor | None
- **Recommendation:** Proceed | Stop

## Rationale

[Narrative explaining the recommendation]
```

### Pillar Review Documents (PILLAR_*.md)

Standardized template for all 6 pillars:

```markdown
# [Pillar Name] — Well-Architected Review

## Overview

[Pillar scope and what was reviewed]

## Findings

### Finding 1: [Title]

- **Risk:** High | Medium | Low
- **Evidence:** [File references, specific code/doc citations]
- **Description:** [What was found]
- **Recommendation:** [What should change]

### Finding 2: [Title]
...

## Summary

| Risk Level | Count |
|------------|-------|
| High | N |
| Medium | N |
| Low | N |

## Recommendations Priority

1. [Highest priority recommendation]
2. [Next priority]
...
```

### Progress Tracker (PROGRESS.md)

Transient workflow tracker. Deleted upon successful completion (Phase 5). Only retained if deliverables are missing.

```markdown
# WAR Progress

| Phase | Status | Started | Completed |
|-------|--------|---------|-----------|
| Pre-flight | [x] | timestamp | timestamp |
| Phase 1: Governance + Cataloguing | [x] | timestamp | timestamp |
| Phase 2: Architecture Review | [~] | timestamp | — |
| Phase 3: Discovery | [ ] | — | — |
| Phase 4: Pillar Reviews | [ ] | — | — |
| Phase 5: Finalization | [ ] | — | — |

## Gate Decision

- **Recommendation:** [pending|proceed|stop]
- **User decision:** [pending|approved|halted]
```

### Review README (README.md)

Generated in Phase 5 as the entry point for the completed review. Contains process overview, recommended reading order with relative links to all deliverables, and a finding summary table. Does not duplicate deliverable content.

## File Organization

### Solution Kit (source, in this repo)

```
solutions/well-architected-review/
├── README.md                              # Install guide, prerequisites, MCP permissions
├── mcp.json                               # Project-scoped MCP server definitions
├── prd.md                                 # This PRD
├── docs/
│   └── ARCHITECTURE_AND_DESIGN.md         # This architecture document
├── agents/
│   ├── war-orchestrator.md                # Orchestrator agent
│   ├── war-cataloguer.md                  # Cataloguer agent (parameterized)
│   ├── war-architecture-reviewer.md       # Architecture reviewer agent (parameterized)
│   ├── war-discovery-analyst.md           # Discovery analyst agent
│   └── war-pillar-reviewer.md             # Pillar reviewer agent (invoked 6x)
└── skills/
    ├── war-governance-profiler/
    │   └── SKILL.md                       # Governance profiler skill
    └── war-discovery-interview/
        └── SKILL.md                       # Interactive interview skill
```

### Drop-in Targets (in consumer project)

```
target-project/
├── .mcp.json                              # From mcp.json
├── .claude/
│   ├── agents/
│   │   ├── war-orchestrator.md
│   │   ├── war-cataloguer.md
│   │   ├── war-architecture-reviewer.md
│   │   ├── war-discovery-analyst.md
│   │   └── war-pillar-reviewer.md
│   └── skills/
│       ├── war-governance-profiler/
│       │   └── SKILL.md
│       └── war-discovery-interview/
│           └── SKILL.md
└── docs/
    └── well-architected-review/           # Created by orchestrator at runtime
        ├── README.md                      # Reading guide (generated in Phase 5)
        ├── GOVERNANCE_PROFILE.md
        ├── DOCUMENT_CATALOGUE.md
        ├── CODE_CATALOGUE.md
        ├── DOCUMENT_ARCHITECTURE_REVIEW.md
        ├── CODE_ARCHITECTURE_REVIEW.md
        ├── DESIGN_REQUIREMENTS.md
        ├── DISCOVERY_ANALYSIS.md
        ├── PILLAR_OPERATIONAL_EXCELLENCE.md
        ├── PILLAR_SECURITY.md
        ├── PILLAR_RELIABILITY.md
        ├── PILLAR_PERFORMANCE_EFFICIENCY.md
        ├── PILLAR_COST_OPTIMIZATION.md
        └── PILLAR_SUSTAINABILITY.md
```

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Solution Kit as new content category (`solutions/`) | Multi-construct solution doesn't fit existing single-type categories (commands, skills, rules). One instance justifies the category because the compliance suite is adjacent. |
| 2 | Orchestrator + sub-agents (not single agent) | Multi-phase workflow with parallel execution, sequential dependencies, interactive interview, and decision gate exceeds what a single system prompt can govern. |
| 3 | Discovery interview as skill, not agent | Sub-agents run in isolated context and cannot use `AskUserQuestion` interactively. The interview must run inline in the main conversation. |
| 4 | Parameterized agents (1 cataloguer, 1 reviewer) | One agent file invoked with different context is simpler than maintaining near-duplicate agent files. Reduces file count from 9 to 5. |
| 5 | Documents as inter-agent interface | Markdown deliverables serve as the contract between phases. Makes the workflow debuggable (read any intermediate doc), resumable (re-run from any phase), and auditable. |
| 6 | Decision gate always surfaces to user | The discovery analyst recommends but does not decide. Prevents false-proceed scenarios where the LLM underestimates gaps. |
| 7 | Code/docs review only — no live AWS access | Eliminates 7 MCP servers, removes credential requirements, and matches the actual use case (pre-deployment design review). |
| 8 | 2 required + 1 optional MCP servers (down from 10) | `aws-documentation` and `iac-server` cover all review needs without auth. `aws-pricing` is optional enrichment for cost pillar. |
| 9 | `.mcp.json` for required servers, inline for optional | Required servers used by multiple agents → project-scoped. Optional pricing server used by one agent → inline definition, scoped to that agent. |
| 10 | Hardcoded 6 AWS WAF pillars | This is an AWS WAF review, not a generic framework tool. Configurability adds complexity without matching the use case. |
| 11 | Sonnet model for all sub-agents | Sub-agents perform focused, well-scoped tasks. Sonnet provides sufficient capability at lower cost/latency. Orchestrator also uses sonnet — it delegates rather than reasons deeply. |
| 12 | Pre-flight check before workflow | Catches missing prerequisites (uvx, MCP, write permissions) before spawning agents. Warns about existing deliverables before overwriting. |
| 13 | Checkpoint resume via PROGRESS.md | Orchestrator reads PROGRESS.md and skips completed phases. Enables recovery from context window limits, errors, or deliberate pause. |
| 14 | H/M/L risk rating for pillar findings | Standard 3-tier scale. Simple, familiar, maps to AWS WAR conventions. Avoids over-classification. |
| 15 | Standardized pillar review template | All 6 pillar documents use identical sections (Overview, Findings, Evidence, Recommendations, Summary). Enables consistent quality and cross-pillar comparison. |
| 16 | Context passing: file paths + brief summary | Sub-agents get file paths for full content access plus a brief summary in the spawn prompt for immediate context. Balances completeness with prompt efficiency. |
| 17 | No static checklists in agent prompts | Concept checklists from MVP doc are human reference, not agent instructions. MCP servers provide authoritative, up-to-date content. Prevents prompt bloat. |
| 18 | Single deliverables directory, overwrite on re-run | `docs/well-architected-review/` is overwritten each run. Users preserve history via git commits. Avoids timestamped directory proliferation. |
| 19 | `TENANT_PROFILE.md` and `ARCHITECTURE_AND_DESIGN.md` as hard pre-requisites | Prevents false negatives from agents guessing at governance context or architecture intent. Pre-flight fails with guidance if missing. |
| 20 | `TENANT_PROFILE.md` as reusable project document, not WAR-specific | Tenant profile describes the AWS environment, not the review. Other tools and processes may reference it. Lives in `docs/`, not in WAR output directory. |
| 21 | Governance profiler as skill, not agent | Requires `AskUserQuestion` for gap resolution. Sub-agents cannot interact with users. Runs inline in orchestrator context. |
| 22 | Governance profile informs but does not suppress findings | Inherited controls are documented as strengths, not omitted. Pillar reviewers classify findings as "workload gap" vs "inherited from governance" so the review is complete and auditable. |
| 23 | README.md as reading guide, not executive summary | The README links to deliverables with a recommended reading order and brief descriptions. It does not summarize findings — each pillar document stands on its own. Prevents staleness if pillar docs are updated independently. |
| 24 | PROGRESS.md deleted on completion | PROGRESS.md is a workflow tracker, not a deliverable. Retaining it clutters the output directory and confuses readers about its purpose. Kept only if deliverables are missing, as a debugging aid. |

## Deployment Workflow

### Build Phases

**Phase 0: Foundation (build and test individually)**

Build each sub-agent as a standalone file. Test independently against a real repository before orchestration.

Build order (by dependency):

1. `war-cataloguer.md` — test produces clean catalogue documents
2. `war-architecture-reviewer.md` — feed it a catalogue, test the review output
3. `war-discovery-interview` skill — test the interview flow produces usable requirements
4. `war-discovery-analyst.md` — feed it the documents, test gap analysis
5. `war-pillar-reviewer.md` — feed it review context, test one pillar output
6. `war-governance-profiler` skill — test reads tenant profile, produces governance baseline

**Phase 1: Governance + Orchestration**

Build `war-governance-profiler` skill and `war-orchestrator.md`. The orchestrator wires all sub-agents and skills into the 4-phase workflow with parallel execution, gate logic, and checkpoint resume.

**Phase 2: MCP Integration**

Wire in MCP servers progressively:

1. `aws-documentation-mcp-server` → enables evidence-based architecture and pillar reviews
2. `iac-mcp-server` → enables security validation of CloudFormation/CDK templates
3. `aws-pricing-mcp-server` (optional) → enriches cost pillar with real pricing data

### Install (Consumer)

```bash
# 1. Copy agents
cp solutions/well-architected-review/agents/*.md  /path/to/project/.claude/agents/

# 2. Copy skills
cp -r solutions/well-architected-review/skills/war-governance-profiler \
      /path/to/project/.claude/skills/
cp -r solutions/well-architected-review/skills/war-discovery-interview \
      /path/to/project/.claude/skills/

# 3. Copy MCP config (merge if .mcp.json already exists)
cp solutions/well-architected-review/mcp.json  /path/to/project/.mcp.json

# 4. Verify prerequisites
which uvx  # must be available (pip install uv)
```

## Out of Scope

| Item | Rationale |
|------|-----------|
| Live AWS infrastructure analysis | Pre-deployment design review only. Live analysis requires different MCP servers and AWS credentials with broad permissions. |
| Automated remediation | WAR produces findings and recommendations. Applying fixes is a separate workflow. |
| Terraform IaC validation | `iac-mcp-server` targets CloudFormation/CDK. Terraform users should integrate HashiCorp's official MCP server. |
| Custom pillar definitions | 6 standard AWS WAF pillars are hardcoded. Custom frameworks would require a different tool. |
| Multi-repo or organization review | Scoped to a single project repository in the working directory. |
| Executive summary report | Future enhancement — synthesize 6 pillar reviews into one document. |
