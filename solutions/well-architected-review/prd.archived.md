# PRD: AWS Well-Architected Review Solution Kit

## Summary

A multi-construct Claude Code solution kit that performs an AWS Well-Architected Framework review against a project's architecture documentation and Infrastructure as Code. Reviews code and documentation only (pre-deployment) — no live AWS account access required. Produces a complete set of review deliverables: catalogues, architecture reviews, gap analysis, and per-pillar WAF assessments.

## Goals

- Deliver a structured, evidence-based AWS Well-Architected Review from code and documentation alone
- Automate a multi-phase review workflow that would otherwise require a human AWS Solutions Architect
- Produce auditable deliverable documents at each phase, enabling resume and debug
- Require zero AWS credentials for the minimum viable review (optional pricing enrichment only)
- Ship as a self-contained solution kit that consumers install by copying files to three targets

## Non-Goals

| Item | Rationale |
|------|-----------|
| Live AWS infrastructure analysis | Out of scope — this is a pre-deployment design review, not a runtime audit |
| Remediation or code changes | The WAR produces findings and recommendations; it does not modify the target project |
| Terraform IaC validation via MCP | `awslabs-iac-mcp-server` targets CloudFormation/CDK only. Terraform files are catalogued and reviewed as code, but MCP-based template validation is not available for Terraform. Terraform users should additionally integrate HashiCorp's official MCP server |
| Custom pillar definitions | Reviews the 6 standard AWS WAF pillars only |
| Multi-account or organization-level review | Scoped to a single project repository |

## Architecture

```
User invokes war-orchestrator
        │
        ├──► Pre-Flight: Validate prerequisites
        │       ├── Check: docs/TENANT_PROFILE.md exists (hard gate)
        │       ├── Check: docs/ARCHITECTURE_AND_DESIGN.md exists (hard gate)
        │       ├── Check: uvx, .mcp.json, output directory
        │       └── Warn: existing deliverables, optional MCP servers
        │
        ├──► Phase 1: Governance + Cataloguing (parallel)
        │       ├── war-governance-profiler (skill) ──► GOVERNANCE_PROFILE.md
        │       ├── war-cataloguer (docs)  ──► DOCUMENT_CATALOGUE.md
        │       └── war-cataloguer (code)  ──► CODE_CATALOGUE.md
        │
        ├──► Phase 2: Architecture Review (parallel)
        │       ├── war-architecture-reviewer (docs) ──► DOCUMENT_ARCHITECTURE_REVIEW.md
        │       └── war-architecture-reviewer (code) ──► CODE_ARCHITECTURE_REVIEW.md
        │
        ├──► Phase 3: Discovery
        │       ├── war-discovery-interview (skill, interactive) ──► DESIGN_REQUIREMENTS.md
        │       └── war-discovery-analyst (agent) ──► DISCOVERY_ANALYSIS.md
        │       │
        │       └──► DECISION GATE: proceed or stop (always surfaced to user)
        │
        ├──► Phase 4: Pillar Reviews (parallel, 6x)
        │       └── war-pillar-reviewer (per pillar) ──► PILLAR_*.md
        │
        └──► Phase 5: Finalization
                ├── Generate README.md (reading guide with relative links)
                └── Delete PROGRESS.md (workflow tracker no longer needed)
```

## Pre-Requisite Documents

The WAR requires two documents to exist in the target project's `docs/` directory before the review can begin. These are developer-authored documents that provide essential context no agent can derive from code alone.

### `docs/TENANT_PROFILE.md`

Describes the AWS tenant environment the workload deploys into. This is a project-level document, not WAR-specific — it may be referenced by other tools and processes beyond the Well-Architected Review.

**Expected content:**

- **Governance framework:** AWS Control Tower, Landing Zone Accelerator, or custom landing zone
- **Inheritable controls:** SCPs, guardrails, Config rules, Security Hub standards active at the org/OU level
- **Centralized services:** CloudTrail, Config, GuardDuty, Security Hub, centralized logging account, network firewall
- **Account structure:** Organization topology, OU placement, account vending process
- **Network boundaries:** Transit Gateway, VPC patterns, DNS resolution, egress controls
- **Compliance baselines:** Inherited compliance frameworks (e.g., CCCS Medium controls satisfied at the org level)
- **Shared resources:** Shared VPCs, central certificate authorities, shared KMS keys, IAM Identity Center

The default location is `docs/TENANT_PROFILE.md`. A project's `CLAUDE.md` may override this path.

### `docs/ARCHITECTURE_AND_DESIGN.md`

Describes the workload's architecture, design decisions, component inventory, and deployment model. This document provides the architectural context that cataloguers and reviewers need to understand intent, not just implementation.

The default location is `docs/ARCHITECTURE_AND_DESIGN.md`. A project's `CLAUDE.md` may override this path.

## Features

### Feature 1: Solution Kit Structure and Distribution

The solution ships as a `solutions/well-architected-review/` directory containing agents, a skill, MCP configuration, and installation documentation.

**Acceptance Criteria:**

- Directory contains `README.md`, `mcp.json`, `agents/` (5 `.md` files), `skills/` (2 skill bundles: `war-governance-profiler/`, `war-discovery-interview/`)
- `mcp.json` contains definitions for 2 required MCP servers (documentation, IaC) with no authentication
- README documents prerequisites, install steps (copy to 3 targets), MCP server table, verification steps, and usage
- Install experience is 3 copy commands (agents, skill, MCP config) plus prerequisite check (`uvx`)

### Feature 2: Document Cataloguer Agent

Agent that reads a project's documentation files and produces a structured catalogue.

**Acceptance Criteria:**

- Reads architecture docs, design docs, README files, and other markdown
- Produces `DOCUMENT_CATALOGUE.md` with file path as sub-header, 1-2 paragraph summary per file
- Runs in isolation with `Read`, `Glob`, `Grep`, `Write` tools
- No MCP servers required

### Feature 3: Code Cataloguer Agent

Same agent as Feature 2, parameterized for code instead of documentation.

**Acceptance Criteria:**

- Reads IaC files (Terraform, CDK, CloudFormation), Lambda/scripts, and miscellaneous code
- Produces `CODE_CATALOGUE.md` with file path as sub-header, 1-2 paragraph summary per file
- Runs in isolation with `Read`, `Glob`, `Grep`, `Write` tools
- No MCP servers required
- Single agent file (`war-cataloguer.md`) handles both doc and code cataloguing via parameter

### Feature 4: Architecture Reviewer Agent

Agent that takes a catalogue as input and produces a WAF-structured architecture review.

**Acceptance Criteria:**

- Reads one catalogue document (doc or code) and the source files it references
- Produces a review structured by the 6 WAF pillars plus continuous improvement and framework review
- Uses `aws-documentation-mcp-server` for authoritative WAF pillar guidance
- Single agent file (`war-architecture-reviewer.md`) handles both doc-driven and code-driven reviews via parameter
- Produces `DOCUMENT_ARCHITECTURE_REVIEW.md` or `CODE_ARCHITECTURE_REVIEW.md`

### Feature 5: Discovery Interview Skill

Interactive skill that interviews the user about solution requirements and design intent.

**Acceptance Criteria:**

- Uses `AskUserQuestion` to conduct a structured interview (not open-ended)
- Covers: business objectives, workload characteristics, compliance requirements, performance requirements, security assessment, cost analysis
- References existing documentation catalogue and architecture reviews to avoid redundant questions
- Produces `DESIGN_REQUIREMENTS.md`
- Implemented as a skill (not agent) because sub-agents cannot interact with the user mid-execution

### Feature 6: Discovery Analyst Agent

Agent that performs gap analysis across all prior deliverables and makes the proceed/stop recommendation.

**Acceptance Criteria:**

- Reads all 6 prior deliverables (1 governance profile, 2 catalogues, 2 architecture reviews, 1 requirements doc)
- Identifies gaps and discrepancies between documentation, code, and stated requirements
- Produces structured output: gaps list, severity (major/minor/none), recommendation (proceed/stop)
- Produces `DISCOVERY_ANALYSIS.md`
- No MCP servers required

### Feature 7: Decision Gate in Orchestrator

The orchestrator surfaces the discovery analyst's recommendation to the user before proceeding to pillar reviews.

**Acceptance Criteria:**

- If analyst recommends "stop": present gap summary, halt workflow, require developers to remediate
- If analyst recommends "proceed": present summary, ask user confirmation before Phase 4
- User always sees the gate — no silent pass-through
- Gate decision and rationale recorded in `PROGRESS.md`

### Feature 8: Pillar Reviewer Agent

Agent that reviews one specific WAF pillar against all prior deliverables and source code/docs.

**Acceptance Criteria:**

- Single agent file (`war-pillar-reviewer.md`) invoked 6 times with pillar name as parameter
- Pillars: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization, Sustainability
- References `GOVERNANCE_PROFILE.md` to classify findings as "workload gap" (must be addressed) vs "inherited from governance" (satisfied at org/account level)
- Findings inherited from governance are documented as strengths, not gaps — with a note that the control is tenant-provided
- Uses `aws-documentation-mcp-server` for pillar-specific WAF guidance
- Security pillar additionally uses `iac-mcp-server` for template validation
- Cost pillar optionally uses `aws-pricing-mcp-server` (inline, requires AWS credentials)
- Produces `PILLAR_<name>.md` per pillar
- All pillar documents follow a standardized template: Overview, Findings (with H/M/L risk rating), Evidence, Recommendations, Summary Risk Rating
- Each finding includes a risk rating of High, Medium, or Low
- References MCP tools for authoritative content rather than carrying static checklists

### Feature 9: Governance Profiler Skill

Interactive skill that reads `docs/TENANT_PROFILE.md` and produces a WAR-specific governance baseline.

**Acceptance Criteria:**

- Reads `docs/TENANT_PROFILE.md` and extracts inherited controls, compliance baselines, and centralized services
- Produces `GOVERNANCE_PROFILE.md` in `docs/well-architected-review/` mapping tenant-level controls to WAF pillars
- For each WAF pillar, identifies which controls are inherited (satisfied at the org/account level) vs which remain the workload's responsibility
- Uses `AskUserQuestion` to resolve ambiguities or gaps in the tenant profile (e.g., "Your tenant profile mentions Control Tower but doesn't specify which guardrails are enabled — are you using the mandatory or strongly recommended set?")
- Updates `GOVERNANCE_PROFILE.md` with answers from gap resolution
- Implemented as a skill (not agent) because it requires `AskUserQuestion`
- Runs in Phase 1 (parallel with cataloguers) — governance context is available before architecture reviews

### Feature 10: Pre-Flight Check

The orchestrator validates prerequisites before starting the workflow.

**Acceptance Criteria:**

- **Hard gates (fail with guidance):**
  - `docs/TENANT_PROFILE.md` must exist — fail with description of expected content and a template outline
  - `docs/ARCHITECTURE_AND_DESIGN.md` must exist — fail with description of expected content
- **Soft checks:**
  - `uvx` is available on PATH
  - `.mcp.json` exists in the project root (or MCP servers are accessible)
  - `docs/well-architected-review/` is writable (creates if missing)
- Reports missing prerequisites with remediation steps
- Warns (does not block) if optional `aws-pricing-mcp-server` is unavailable
- If prior deliverables exist in `docs/well-architected-review/`, warns user they will be overwritten and asks confirmation

### Feature 11: Orchestrator Agent

Master agent that drives the full multi-phase workflow, spawns sub-agents, and manages sequencing.

**Acceptance Criteria:**

- Runs pre-flight check (Feature 10) before any phase
- Phase 1: spawns 2 cataloguer agents in parallel (doc + code), then runs governance profiler skill inline (blocking — requires `AskUserQuestion`). Cataloguers execute in background while skill runs. Waits for all three to complete.
- Phase 2: spawns 2 architecture reviewers in parallel (doc + code), waits for completion — reviewers reference `GOVERNANCE_PROFILE.md`
- Phase 3: invokes discovery interview skill, then spawns discovery analyst agent
- Evaluates decision gate (Feature 7)
- Phase 4: spawns 6 pillar reviewers in parallel, waits for completion
- Phase 5: generates `README.md` reading guide (Feature 14), then deletes `PROGRESS.md` (Feature 15)
- Passes context to sub-agents via file paths (for full content) plus a brief summary in the spawn prompt
- Maintains `PROGRESS.md` updated after each phase (deleted in Phase 5 upon successful completion)
- Supports resume from checkpoint: reads `PROGRESS.md` and skips completed phases if deliverables exist
- No MCP servers required (delegates to sub-agents)

### Feature 12: MCP Server Integration

Progressive MCP server wiring across the solution.

**Acceptance Criteria:**

- `aws-documentation-mcp-server` available via `.mcp.json` (project-scoped, no auth)
- `iac-mcp-server` available via `.mcp.json` (project-scoped, no auth)
- `aws-pricing-mcp-server` defined inline in `war-pillar-reviewer.md` frontmatter (optional, AWS creds)
- Agents that don't need MCP servers don't have access to them
- Solution functions without any MCP servers (degraded quality); functions fully with just `uvx` installed

### Feature 13: Documentation

Complete documentation for the solution kit.

**Acceptance Criteria:**

- `solutions/well-architected-review/README.md`: install guide, prerequisites, MCP server table (with permissions/access scope per server), verification, usage, troubleshooting
- `docs/solutions/WELL_ARCHITECTED_REVIEW.md`: architecture doc with component diagram, phase workflow, agent responsibilities, MCP mapping, decision gate logic, deliverable specs
- `docs/SOLUTIONS.md`: catalog page listing available solution kits (follows pattern of `docs/SKILLS.md`)
- `CLAUDE.md` updated with `solutions/` in the structure diagram and content model table

### Feature 14: Review README Generation

The orchestrator generates a README.md that serves as an entry point and reading guide for the completed review deliverables.

**Acceptance Criteria:**

- Generated as the first step of Phase 5, after all pillar reviews complete
- Contains an overview of the Well-Architected Review process (what was reviewed, when, which pillars)
- Provides a recommended reading order with rationale (e.g., start with governance profile for context, then catalogues, then architecture reviews, then discovery, then pillar reviews)
- All deliverable files linked via relative paths (e.g., `[Governance Profile](GOVERNANCE_PROFILE.md)`)
- Brief 1-2 sentence description of each document's purpose alongside its link
- Does not duplicate deliverable content — serves as a map, not a summary
- Written to `docs/well-architected-review/README.md`

### Feature 15: Progress Tracker Cleanup

The orchestrator deletes `PROGRESS.md` after all phases complete successfully, since it is a workflow tracker with no value in the final deliverable set.

**Acceptance Criteria:**

- Runs as the final step of Phase 5, after README generation
- Deletes `docs/well-architected-review/PROGRESS.md`
- Only deletes if all prior phases completed successfully (all expected deliverables exist)
- Logs deletion in the orchestrator's final status message to the user
- If any deliverable is missing, keeps `PROGRESS.md` and warns the user which deliverables are absent

## Configuration

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| Target project path | Directory | The project repository to review (working directory when agents run) |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| AWS credentials | Environment | None | Only needed for `aws-pricing-mcp-server` (cost estimation enrichment) |
| `uvx` | Binary | Required | Python package runner needed to launch MCP servers (`pip install uv`) |

## Testing

### Test Repository

Phase 0 testing uses `temp/gcco-guard-public-website-infra`, a local clone of a real-world Terraform IaC repository that deploys a public website. This provides a meaningful target with actual infrastructure definitions, security configurations, and operational patterns — unlike the content-only agentic-ai repo used for early smoke tests.

Agents are tested individually against this repo before orchestration wiring (Phase 1).

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `docs/well-architected-review/GOVERNANCE_PROFILE.md` | Markdown | Tenant governance baseline mapped to WAF pillars |
| `docs/well-architected-review/DOCUMENT_CATALOGUE.md` | Markdown | Documentation file inventory with summaries |
| `docs/well-architected-review/CODE_CATALOGUE.md` | Markdown | IaC/code file inventory with summaries |
| `docs/well-architected-review/DOCUMENT_ARCHITECTURE_REVIEW.md` | Markdown | WAF review based on documentation |
| `docs/well-architected-review/CODE_ARCHITECTURE_REVIEW.md` | Markdown | WAF review based on code |
| `docs/well-architected-review/DESIGN_REQUIREMENTS.md` | Markdown | Solution requirements from user interview |
| `docs/well-architected-review/DISCOVERY_ANALYSIS.md` | Markdown | Gap analysis with proceed/stop recommendation |
| `docs/well-architected-review/PILLAR_OPERATIONAL_EXCELLENCE.md` | Markdown | Operational Excellence pillar review |
| `docs/well-architected-review/PILLAR_SECURITY.md` | Markdown | Security pillar review |
| `docs/well-architected-review/PILLAR_RELIABILITY.md` | Markdown | Reliability pillar review |
| `docs/well-architected-review/PILLAR_PERFORMANCE_EFFICIENCY.md` | Markdown | Performance Efficiency pillar review |
| `docs/well-architected-review/PILLAR_COST_OPTIMIZATION.md` | Markdown | Cost Optimization pillar review |
| `docs/well-architected-review/PILLAR_SUSTAINABILITY.md` | Markdown | Sustainability pillar review |
| `docs/well-architected-review/README.md` | Markdown | Reading guide with process overview and relative links to all deliverables |

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Orchestrator loses track of workflow state | Write `PROGRESS.md` updated after each phase; workflow is resumable from any phase |
| Sub-agent produces low-quality output | Phase 0 testing catches this before orchestration wiring |
| MCP server unavailable at runtime | Required servers need no auth and are low-risk; optional pricing server degrades gracefully |
| Pillar reviews are too shallow | Pillar reviewer prompt focuses on methodology depth, not broad topic checklists; MCP provides authoritative content |
| Gate decision is wrong (false proceed/stop) | Always surface decision to user — never auto-proceed past the gate |
| Discovery interview too long or too short | Skill uses a structured question set, not open-ended exploration |
| Consumer has no `uvx` installed | README documents prerequisite; solution functions (degraded) without MCP servers |

## External Dependencies

| Dependency | Owner | Status |
|------------|-------|--------|
| `awslabs-aws-documentation-mcp-server` | AWS Labs (github.com/awslabs/mcp) | Active, no auth |
| `awslabs-iac-mcp-server` | AWS Labs (github.com/awslabs/mcp) | Active, no auth |
| `awslabs-aws-pricing-mcp-server` | AWS Labs (github.com/awslabs/mcp) | Active, optional (AWS creds) |
| `uvx` (Python package runner) | Astral (uv project) | Stable, required for MCP server launch |
| Claude Code agent/skill runtime | Anthropic | Required — agents use frontmatter, sub-agent spawning, `AskUserQuestion` |

## Success Criteria

- A user with `uvx` installed can copy 3 sets of files, invoke the orchestrator, and receive a complete WAR with 14 deliverable documents (13 review artifacts plus a README reading guide; `PROGRESS.md` is deleted upon completion)
- The target project must have `docs/TENANT_PROFILE.md` and `docs/ARCHITECTURE_AND_DESIGN.md` — pre-flight fails with guidance if missing
- The minimum viable WAR requires zero AWS credentials
- Each sub-agent can be tested independently before orchestration (Phase 0 validates this)
- The decision gate halts the workflow when documentation/code gaps are severe enough to invalidate pillar reviews
- Pillar reviewers correctly distinguish workload gaps from tenant-inherited controls

## Future Enhancements

| Enhancement | Description |
|-------------|-------------|
| Terraform support | Add HashiCorp's official Terraform MCP server as an optional integration for Terraform-based projects |
| Install script | `bash install.sh /path/to/project` that copies agents, skill, MCP config, checks prerequisites, reports missing items |
| Summary report | Final agent that synthesizes all 6 pillar reviews into a single executive summary document |
| Live infrastructure mode | Optional second pass using `well-architected-security-mcp-server` and `cost-analysis-mcp-server` against deployed environments |
| Custom pillar weights | Allow users to prioritize certain pillars (e.g., security-heavy for regulated industries) |
