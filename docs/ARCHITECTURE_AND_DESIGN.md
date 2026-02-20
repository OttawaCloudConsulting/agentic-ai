# Architecture and Design: Kiro Powers & Steering Conversion

## Overview

This project adds a `kiro/` directory to the agentic-ai repo containing Kiro-native equivalents of the existing Claude Code content. The content is organized into two categories:

- **Powers** (7 total) — workflow-oriented bundles activated by keywords, each containing a POWER.md and task-specific steering files
- **Steering** (6 total) — always-on or auto-activated guidance files providing best practices and behavioral rules

The output is consumed by copying into target projects, identical to the existing Claude Code content model.

## Component Diagram

```
agentic-ai/
├── commands/          (Claude Code — existing, unchanged)
├── rules/             (Claude Code — existing, unchanged)
├── skills/            (Claude Code — existing, unchanged)
└── kiro/              (Kiro — new)
    ├── powers/
    │   ├── project-lifecycle/     ← start-feature, create-prd
    │   ├── terraform-workflow/    ← test-terraform, update-docs-terraform
    │   ├── cdk-workflow/          ← test-cdk, update-docs-cdk
    │   ├── compliance/            ← compliance-assess, compliance-auto-assess
    │   ├── documentation/         ← update-docs
    │   ├── investigation/         ← investigate
    │   └── terraform-testing/     ← terraform-testing skill
    ├── steering/
    │   ├── defensive-protocol.md
    │   ├── terraform-best-practices.md
    │   ├── cdk-best-practices.md
    │   ├── kubernetes-best-practices.md
    │   ├── crossplane-best-practices.md
    │   └── crossplane-v2-best-practices.md
    ├── docs/
    │   ├── POWERS.md
    │   └── STEERING.md
    └── README.md
```

## Content Flow

```
Source (Claude Code)              Conversion              Target (Kiro)
─────────────────                 ──────────              ─────────────
commands/*.md          ──→   Rewrite + group    ──→   powers/*/POWER.md + steering/*.md
rules/*.md             ──→   Add frontmatter    ──→   steering/*.md
skills/*/SKILL.md      ──→   Rewrite            ──→   powers/*/POWER.md + steering/*.md
```

### Consumer Installation Flow

```
agentic-ai/kiro/powers/<name>/   ──copy──→   <project>/.kiro/powers/<name>/
                                              (then install from local path in Kiro IDE)

agentic-ai/kiro/steering/*.md    ──copy──→   <project>/.kiro/steering/
```

## File Format Specifications

### POWER.md Format

```yaml
---
name: "power-identifier"
displayName: "Human-Readable Name"
description: "What this power provides"
keywords: ["primary1", "primary2", "primary3"]
---
```

Followed by markdown content with two sections:

1. **Onboarding** — runs once on first activation. Lists available workflows, explains prerequisites.
2. **Workflow References** — maps tasks to steering files. Example: "For Terraform validation, see `steering/terraform-validation.md`"

Secondary keywords appear naturally in the body text rather than in the frontmatter array.

### Steering File Format (standalone, in kiro/steering/)

```yaml
---
inclusion: always
---
```

or

```yaml
---
inclusion: auto
name: identifier
description: "When this guidance should activate"
---
```

Followed by markdown content. No blank lines before the opening `---`.

### Steering File Format (within a power, in powers/*/steering/)

Plain markdown. No frontmatter needed — these are loaded by the power's POWER.md when relevant workflows are triggered.

## Content Mapping Detail

### Powers

| # | Power | Source | Steering Files | Primary Keywords |
|---|-------|--------|---------------|-----------------|
| 1 | project-lifecycle | start-feature, create-prd | feature-start.md, prd-creation.md | feature, prd, requirements, spec, start |
| 2 | terraform-workflow | test-terraform, update-docs-terraform | terraform-validation.md, terraform-docs-update.md | terraform plan, terraform apply, tfvars, terraform test |
| 3 | cdk-workflow | test-cdk, update-docs-cdk | cdk-validation.md, cdk-docs-update.md | cdk deploy, cdk synth, cdk test |
| 4 | compliance | compliance-assess, compliance-auto-assess | interactive-assessment.md, automated-assessment.md | compliance, ITSG-33, CCCS, security controls |
| 5 | documentation | update-docs | docs-refresh.md | update docs, refresh readme, documentation |
| 6 | investigation | investigate | structured-debugging.md | debug, investigate, troubleshoot |
| 7 | terraform-testing | skills/terraform-testing | validation-pipeline.md | terraform validate, tflint, checkov, trivy |

### Steering

| # | File | Source | Mode | Auto Description |
|---|------|--------|------|-----------------|
| 1 | defensive-protocol.md | rules/defensive-protocol.md | always | N/A |
| 2 | terraform-best-practices.md | rules/terraform-best-practices.md | auto | Terraform HCL best practices for module design, state management, and deployment safety |
| 3 | cdk-best-practices.md | rules/cdk-best-practices.md | auto | AWS CDK best practices for construct design, security, and testing |
| 4 | kubernetes-best-practices.md | rules/kubernetes-best-practices.md | auto | Kubernetes resource management, security, and production readiness |
| 5 | crossplane-best-practices.md | rules/crossplane-best-practices.md | auto | Crossplane XR design, compositions, and provider configuration |
| 6 | crossplane-v2-best-practices.md | rules/crossplane-v2-best-practices.md | auto | Crossplane v2 breaking changes, namespaced resources, and migration patterns |

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Parallel `kiro/` directory rather than alongside existing files | Clean separation. No risk of confusion between Claude Code and Kiro content. Each tool's content is self-contained. |
| 2 | Group related commands into powers by concern | Kiro's keyword activation model works best with cohesive power bundles. Granular powers (one per command) would cause excessive activation/deactivation churn. |
| 3 | Primary keywords in frontmatter, secondary in body text | Prevents false activations from broad terms while allowing contextual relevance from body content. Kiro indexes both but weights frontmatter keywords higher. |
| 4 | One steering file per original command within powers | Preserves modularity. Powers reference specific steering files by workflow, keeping each file focused and independently maintainable. |
| 5 | Full rewrite for power steering files, minimal changes for standalone steering | Power steering files need significant adaptation (Claude Code tool-calling → Kiro guidance patterns). Rules are already tool-agnostic guidance — only need frontmatter and minor terminology cleanup. |
| 6 | `inclusion: always` for defensive-protocol, `auto` for tech-specific | Defensive protocol applies universally. Tech-specific rules should only load when relevant to avoid context bloat. `auto` mode with descriptions lets Kiro decide contextually. |
| 7 | No MCP server bundling in powers | MCP configuration varies per consumer environment. Bundling would couple powers to specific server versions and configurations. |
| 8 | Copy-based consumer model (not GitHub URL install) | Matches existing Claude Code distribution model. Consumers select which powers/steering they need and copy them. Simpler than managing GitHub URL dependencies. |
| 9 | Removed catchup/handoff from project-lifecycle power | No Kiro-native equivalent for file-based session state persistence. These workflows are tightly coupled to Claude Code's `agents/memory/` pattern. |
| 10 | No `mcp.json` files in any power | Consistent with Decision #7. Powers are pure content — steering and documentation only. |

## Adaptation Patterns

### Pattern: Claude Code Command → Kiro Power Steering File

**Before (Claude Code command):**
```markdown
# /test-terraform — Validation and Deploy

## Steps
1. Run `terraform fmt -check`
2. Run `terraform validate`
3. Use Bash tool to execute `terraform plan`
...
```

**After (Kiro steering file):**
```markdown
# Terraform Validation Workflow

When validating Terraform code, follow this sequence:

## Validation Gates
1. Format check — `terraform fmt -check`
2. Configuration validation — `terraform validate`
3. Plan review — `terraform plan`
...
```

Key differences:
- Remove imperative "Run X" / "Use Y tool" instructions
- Describe workflows as guidance rather than step-by-step tool calls
- Remove Claude Code-specific tool references (Bash tool, AskUserQuestion, etc.)
- Use descriptive headings instead of command syntax headers

### Pattern: Claude Code Rule → Kiro Steering File

**Before (Claude Code rule):**
```markdown
# Defensive Coding Protocol
> Defensive epistemology for agentic coding...

## Claude-Specific Guidance
Your failure mode: optimizing for completion by batching many actions.
```

**After (Kiro steering file):**
```yaml
---
inclusion: always
---
# Defensive Coding Protocol
> Defensive epistemology for agentic coding...

## Agent-Specific Guidance
Common failure mode: optimizing for completion by batching many actions.
```

Key differences:
- Add YAML frontmatter with inclusion mode
- Replace "Claude" with "Agent" or tool-agnostic language
- Preserve all substantive content

## File Organization

```
kiro/
├── README.md
├── powers/
│   ├── project-lifecycle/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── feature-start.md
│   │       └── prd-creation.md
│   ├── terraform-workflow/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── terraform-validation.md
│   │       └── terraform-docs-update.md
│   ├── cdk-workflow/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── cdk-validation.md
│   │       └── cdk-docs-update.md
│   ├── compliance/
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── interactive-assessment.md
│   │       └── automated-assessment.md
│   ├── documentation/
│   │   ├── POWER.md
│   │   └── steering/
│   │       └── docs-refresh.md
│   ├── investigation/
│   │   ├── POWER.md
│   │   └── steering/
│   │       └── structured-debugging.md
│   └── terraform-testing/
│       ├── POWER.md
│       └── steering/
│           └── validation-pipeline.md
├── steering/
│   ├── defensive-protocol.md
│   ├── terraform-best-practices.md
│   ├── cdk-best-practices.md
│   ├── kubernetes-best-practices.md
│   ├── crossplane-best-practices.md
│   └── crossplane-v2-best-practices.md
└── docs/
    ├── POWERS.md
    └── STEERING.md
```

Total files: 7 POWER.md + 13 power steering + 6 standalone steering + 2 docs + 1 README = **29 files**

## Dependency Graph

```
Feature 1 (scaffold)
    ├──→ Feature 2 (defensive-protocol steering)
    ├──→ Feature 3 (tech-specific steering files)
    ├──→ Feature 4 (project-lifecycle power)
    ├──→ Feature 5 (terraform-workflow power)
    ├──→ Feature 6 (cdk-workflow power)
    ├──→ Feature 7 (compliance power)
    ├──→ Feature 8 (documentation power)
    ├──→ Feature 9 (investigation power)
    ├──→ Feature 10 (terraform-testing power)
    └──→ Feature 11 (reference docs) ──→ Feature 12 (README)
```

All features depend on Feature 1 (scaffold). Features 2-10 are independent of each other. Feature 11 depends on all content features (2-10) being complete. Feature 12 depends on Feature 11.

## Out of Scope

| Item | Rationale |
|------|-----------|
| Project kit conversion | Kits require deeper restructuring. Separate initiative. |
| MCP server bundling | Consumer-specific. Would couple powers to infrastructure. |
| Automated testing | No validation framework for Kiro content exists. Manual review only. |
| Publishing to registries | Copy model is sufficient. Registry publishing adds complexity without clear benefit. |
| Catchup/handoff commands | No Kiro-native equivalent for file-based session state persistence. |
