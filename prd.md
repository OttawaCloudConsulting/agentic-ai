# PRD: Kiro Powers & Steering Conversion

## Summary

Convert the existing Claude Code content library (10 commands, 6 rules, 1 skill) into AWS Kiro-compatible equivalents. Commands and skills are restructured into 7 Kiro **powers** (grouped by concern). Rules become 6 Kiro **steering** files with appropriate inclusion modes. All output lives under a new `kiro/` directory, maintaining the drop-in consumer model where content is copied into target projects. The catchup and handoff commands are excluded — they rely on Claude Code-specific session state patterns with no Kiro equivalent.

## Goals

- Produce Kiro-native versions of all commands, rules, and skills in a parallel `kiro/` directory
- Group related Claude Code commands into cohesive Kiro powers optimized for keyword activation
- Convert always-on rules into Kiro steering files with mixed inclusion modes (`always` for defensive-protocol, `auto` for tech-specific rules)
- Adapt content to Kiro-native patterns (Kiro specs instead of prd.md) rather than preserving Claude Code conventions
- Create reference documentation mirroring existing `docs/RULES.md` and `docs/SKILLS.md`
- Maintain the copy-based consumer model: users copy power directories and steering files into their project

## Non-Goals

- **Project kit conversion** — `prompts/terraform-project/` and `prompts/cdk-project/` are out of scope
- **MCP server bundling** — No `mcp.json` files; MCP configuration handled separately by consumers
- **Automated testing/validation** — No CI or validation tooling for the Kiro output
- **Publishing to registries** — No marketplace or power registry publishing; local/copy install only
- **Runtime code** — This remains a content-only library; no scripts or executables
- **Catchup/handoff commands** — These rely on Claude Code's `agents/memory/` file-based session state pattern with no Kiro equivalent

## Architecture

### Directory Structure

```
kiro/
├── README.md                              # Installation and usage guide
├── powers/
│   ├── project-lifecycle/                 # start-feature, create-prd
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── feature-start.md
│   │       └── prd-creation.md
│   ├── terraform-workflow/                # test-terraform, update-docs-terraform
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── terraform-validation.md
│   │       └── terraform-docs-update.md
│   ├── cdk-workflow/                      # test-cdk, update-docs-cdk
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── cdk-validation.md
│   │       └── cdk-docs-update.md
│   ├── compliance/                        # compliance-assess, compliance-auto-assess
│   │   ├── POWER.md
│   │   └── steering/
│   │       ├── interactive-assessment.md
│   │       └── automated-assessment.md
│   ├── documentation/                     # update-docs (generic)
│   │   ├── POWER.md
│   │   └── steering/
│   │       └── docs-refresh.md
│   ├── investigation/                     # investigate
│   │   ├── POWER.md
│   │   └── steering/
│   │       └── structured-debugging.md
│   └── terraform-testing/                 # terraform-testing skill
│       ├── POWER.md
│       └── steering/
│           └── validation-pipeline.md
├── steering/
│   ├── defensive-protocol.md              # inclusion: always
│   ├── terraform-best-practices.md        # inclusion: auto
│   ├── cdk-best-practices.md              # inclusion: auto
│   ├── kubernetes-best-practices.md       # inclusion: auto
│   ├── crossplane-best-practices.md       # inclusion: auto
│   └── crossplane-v2-best-practices.md    # inclusion: auto
└── docs/
    ├── POWERS.md                          # Powers reference guide
    └── STEERING.md                        # Steering reference guide
```

### Content Mapping

#### Powers (Commands/Skills → Powers)

| Power | Source Commands | Keywords (Primary) | Keywords (Secondary) |
|-------|---------------|--------------------|--------------------|
| project-lifecycle | start-feature, create-prd | feature, prd, requirements, spec | start, plan, next feature |
| terraform-workflow | test-terraform, update-docs-terraform | terraform plan, terraform apply, tfvars, terraform test | validate, deploy, hcl, tf |
| cdk-workflow | test-cdk, update-docs-cdk | cdk deploy, cdk synth, cdk test | aws cdk, construct, stack |
| compliance | compliance-assess, compliance-auto-assess | compliance, ITSG-33, CCCS, security controls | audit, assessment, GC cloud |
| documentation | update-docs | update docs, refresh readme, documentation | readme, architecture doc |
| investigation | investigate | debug, investigate, troubleshoot | root cause, error, failure |
| terraform-testing | skills/terraform-testing | terraform validate, tflint, checkov, trivy | security scan, lint, format |

#### Steering (Rules → Steering)

| Steering File | Source Rule | Inclusion Mode | Trigger |
|--------------|-----------|---------------|---------|
| defensive-protocol.md | rules/defensive-protocol.md | always | Every interaction |
| terraform-best-practices.md | rules/terraform-best-practices.md | auto | "Terraform HCL best practices for module design, state management, and deployment safety" |
| cdk-best-practices.md | rules/cdk-best-practices.md | auto | "AWS CDK best practices for construct design, security, and testing" |
| kubernetes-best-practices.md | rules/kubernetes-best-practices.md | auto | "Kubernetes resource management, security, and production readiness" |
| crossplane-best-practices.md | rules/crossplane-best-practices.md | auto | "Crossplane XR design, compositions, and provider configuration" |
| crossplane-v2-best-practices.md | rules/crossplane-v2-best-practices.md | auto | "Crossplane v2 breaking changes, namespaced resources, and migration patterns" |

### Content Adaptation Strategy

Claude Code commands contain explicit step-by-step instructions designed for Claude's tool-calling model. Kiro powers use a different paradigm:

1. **POWER.md** contains onboarding instructions (run once on activation) and references to steering files for specific workflows
2. **Steering files** within a power contain the actual workflow guidance, loaded contextually
3. **Keywords** in POWER.md frontmatter drive activation — tiered approach with narrow primary keywords and broader secondary keywords

**Key adaptations from Claude Code to Kiro:**

| Claude Code Concept | Kiro Equivalent |
|--------------------|----|
| `progress.txt` | Kiro task tracking / specs |
| `prd.md` | Kiro requirements spec |
| `/command-name` invocation | Keyword-triggered power activation |
| `CLAUDE.md` rules | `.kiro/steering/` files |
| `AskUserQuestion` tool calls | Kiro's interactive prompting |

Content in each steering file must be rewritten to use Kiro-native terminology and patterns rather than referencing Claude Code-specific concepts.

## Features

### Feature 1: Kiro Directory Scaffold

Create the `kiro/` directory structure with all subdirectories for powers, steering, and docs.

**Acceptance criteria:**
- All directories from the architecture section exist
- Empty placeholder files where needed
- `kiro/README.md` created with installation instructions and content overview

### Feature 2: Steering File Conversion — Defensive Protocol

Convert `rules/defensive-protocol.md` to `kiro/steering/defensive-protocol.md`.

**Acceptance criteria:**
- YAML frontmatter with `inclusion: always`
- Content adapted from Claude Code terminology to tool-agnostic language
- Remove references to Claude-specific behaviors (e.g., "Claude's failure mode: optimizing for completion")
- Preserve all substantive guidance (prediction protocol, failure response, verification cadence, etc.)
- File references updated to Kiro conventions where applicable

### Feature 3: Steering File Conversion — Tech-Specific Rules

Convert all 5 tech-specific rules to Kiro steering files with `inclusion: auto`.

**Acceptance criteria per file:**
- YAML frontmatter with `inclusion: auto`, `name`, and `description` fields
- `name` is lowercase-hyphenated identifier
- `description` is a concise sentence describing when the steering should activate
- Content preserved with minimal adaptation (these are largely tool-agnostic already)
- Files: terraform-best-practices, cdk-best-practices, kubernetes-best-practices, crossplane-best-practices, crossplane-v2-best-practices

### Feature 4: Power — project-lifecycle

Convert start-feature and create-prd commands into a single power.

**Acceptance criteria:**
- `POWER.md` frontmatter: name, displayName, description, keywords (tiered)
- Onboarding section that explains available workflows
- 2 steering files in `steering/` subdirectory, one per original command
- Each steering file adapted to Kiro patterns:
  - `feature-start.md` — begin next feature using Kiro specs/tasks instead of `progress.txt`
  - `prd-creation.md` — guided requirements creation adapted to Kiro's spec model

### Feature 5: Power — terraform-workflow

Convert test-terraform and update-docs-terraform into a single power.

**Acceptance criteria:**
- `POWER.md` with terraform-specific keywords
- `steering/terraform-validation.md` — validation and deployment workflow
- `steering/terraform-docs-update.md` — documentation refresh workflow
- Content adapted from Claude Code tool-calling patterns to Kiro steering guidance

### Feature 6: Power — cdk-workflow

Convert test-cdk and update-docs-cdk into a single power.

**Acceptance criteria:**
- `POWER.md` with CDK-specific keywords
- `steering/cdk-validation.md` — validation and deployment workflow
- `steering/cdk-docs-update.md` — documentation refresh workflow
- Content adapted to Kiro patterns

### Feature 7: Power — compliance

Convert compliance-assess and compliance-auto-assess into a single power.

**Acceptance criteria:**
- `POWER.md` with compliance/security keywords
- `steering/interactive-assessment.md` — interactive ITSG-33/CCCS assessment workflow
- `steering/automated-assessment.md` — automated dispatcher workflow
- Content adapted to Kiro patterns

### Feature 8: Power — documentation

Convert generic update-docs command into a power.

**Acceptance criteria:**
- `POWER.md` with documentation keywords
- `steering/docs-refresh.md` — generic documentation refresh workflow
- Content adapted to Kiro patterns

### Feature 9: Power — investigation

Convert investigate command into a power.

**Acceptance criteria:**
- `POWER.md` with debugging/investigation keywords
- `steering/structured-debugging.md` — structured debugging workflow with facts/theories separation
- Adapt `agents/investigations/` file convention to Kiro-native approach

### Feature 10: Power — terraform-testing

Convert terraform-testing skill into a power.

**Acceptance criteria:**
- `POWER.md` with terraform testing/validation keywords
- `steering/validation-pipeline.md` — portable validation pipeline (git-secrets, fmt, init, validate, tflint, security scanning, plan, apply)
- Reference script content from `skills/terraform-testing/scripts/` preserved in steering guidance

### Feature 11: Reference Documentation

Create `kiro/docs/POWERS.md` and `kiro/docs/STEERING.md`.

**Acceptance criteria:**
- `POWERS.md` lists all 7 powers with: name, description, keywords, included workflows, source commands
- `STEERING.md` lists all 6 steering files with: name, inclusion mode, trigger description, source rule
- Both documents explain the consumer installation model
- Cross-references between powers and steering where relevant (e.g., terraform-workflow power + terraform-best-practices steering)

### Feature 12: Consumer Installation Guide

Create `kiro/README.md` with comprehensive installation instructions.

**Acceptance criteria:**
- Explains what the kiro/ directory contains
- Step-by-step instructions for installing powers (copy to project, install from local path)
- Step-by-step instructions for installing steering files (copy to `.kiro/steering/`)
- Lists all available powers and steering files with brief descriptions
- Explains the relationship between powers (workflow tools) and steering (always-on guidance)
- Notes which powers and steering files are recommended for each project type (terraform, cdk, kubernetes, crossplane)

## Input Variables

N/A — this is a content project, not a software module.

## Outputs

| Output | Description |
|--------|-------------|
| `kiro/powers/` | 7 power directories, each with POWER.md and steering/ files |
| `kiro/steering/` | 6 steering files with YAML frontmatter |
| `kiro/docs/POWERS.md` | Powers reference guide |
| `kiro/docs/STEERING.md` | Steering reference guide |
| `kiro/README.md` | Consumer installation guide |

## Constraints

- All files are markdown — no runtime code
- Content must work with Kiro IDE and Kiro CLI
- Steering files must use valid YAML frontmatter as first content (no blank lines before `---`)
- Power POWER.md files must follow Kiro's expected format: YAML frontmatter with name/displayName/description/keywords, then onboarding + steering sections
- No MCP server configuration (`mcp.json`) in any power
- File and directory names use lowercase-hyphenated convention
