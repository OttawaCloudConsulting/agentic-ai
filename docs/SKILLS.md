# Skills Reference

Skills are portable bundles that provide structured workflows with supporting assets (scripts, references, templates). Each skill is a directory containing a `SKILL.md` definition plus supporting files. They are invoked with `/<skill-name>` in the Claude Code CLI.

For single-file commands (no supporting assets), see [COMMANDS.md](COMMANDS.md).

## Quick Reference

| Skill | Command | Purpose | Details |
|---|---|---|---|
| CDK Testing | `/cdk-testing` | Validate, scan, build, test, and deploy CDK code | [View](skills/cdk-testing.md) |
| Terraform Testing | `/terraform-testing` | Validate, scan, plan, and deploy Terraform code | [View](skills/terraform-testing.md) |
| ITSG Assessment | `/itsg-assessment` | ITSG-33 / CCCS Medium compliance assessment for Canadian GC cloud workloads handling Protected B data, with user checkpoints | [View](skills/itsg-assessment.md) |
| NIST FedRAMP Assessment | `/nist-fedramp-assessment` | NIST SP 800-53 Rev 5 / FedRAMP Moderate compliance assessment for US cloud workloads with dual inheritance model and FedRAMP ATO readiness | [View](skills/nist-fedramp-assessment.md) |
| NIST CSF Assessment | `/nist-csf-assessment` | NIST CSF 2.0 outcome-based assessment across all 6 Functions with platform-agnostic evidence mapping, 800-53 informative references, and self-updating Phase 0 that always validates against the latest published CSF version | [View](skills/nist-csf-assessment.md) |
| Create PRD | `/create-prd` | Guided interview to produce a PRD, architecture document, and progress file for a new project | [View](skills/create-prd.md) |
| Define | `/define` | Single-session codebase assessment, optional Working Backwards, and PRD creation (Gates 0/WB/1) | [View](skills/define.md) |
| Design | `/design` | Architecture and design specification from approved PRD, with refresh mode for deviation consolidation (Gate 2) | [View](skills/design.md) |
| Milestone | `/milestone` | Per-milestone feature breakdown with acceptance criteria and revision support (Gate 3) | [View](skills/milestone.md) |
| OCC Skill Creator | `/occ-skill-creator` | Guide for creating new skills that extend Claude's capabilities | [View](skills/occ-skill-creator.md) |
| OCC Skill Refactor | `/occ-skill-refactor` | Reviews and refactors an existing skill against quality standards and best practices | [View](skills/occ-skill-refactor.md) |
| Project | `/project` | Project orchestrator -- bootstraps state, reports status, routes to next skill | [View](skills/project.md) |
| Rule Creator | `/rule-creator` | Interactive rule generation with documentation and catalog updates | [View](skills/rule-creator.md) |

## How Skills Work

- Skills live in `skills/<name>/` at the repository root (drop-in source)
- Consumers copy the entire directory to `.claude/skills/<name>/` in their target project
- Each skill directory contains:
  - `SKILL.md` — the skill definition with YAML frontmatter (`name`, `description`)
  - `scripts/` — executable shell scripts (optional)
  - `references/` — supporting documentation loaded on-demand (optional)
- The `description` field in frontmatter includes trigger phrases so the model knows when to invoke the skill
- Skills are invoked manually via `/<skill-name>` or automatically when the model matches trigger phrases
- Set `disable-model-invocation: true` in frontmatter to prevent auto-triggering (use for interactive or destructive skills)

### Skill Bundle Structure

```
skills/<name>/
├── SKILL.md                  ← skill definition (YAML frontmatter required)
├── scripts/                  ← executable scripts (portable, auto-detect OS)
│   └── *.sh
└── references/               ← supporting docs (loaded by SKILL.md as needed)
    └── *.md
```

### Frontmatter

```yaml
---
name: skill-name                    # Required. The /command name.
description: What the skill does    # Required. Include trigger phrases.
disable-model-invocation: true      # Optional. Prevents auto-triggering.
compatibility: node>=18, npm, git   # Optional. Documents runtime requirements.
license: Apache-2.0                 # Optional. License identifier.
---
```

## Consuming Skills

Copy the entire skill directory from `skills/` into `.claude/skills/` in the target repository:

```bash
# Copy a skill bundle
cp -r skills/cdk-testing/       <target-repo>/.claude/skills/cdk-testing/
cp -r skills/terraform-testing/  <target-repo>/.claude/skills/terraform-testing/
cp -r skills/itsg-assessment/           <target-repo>/.claude/skills/itsg-assessment/
cp -r skills/nist-fedramp-assessment/   <target-repo>/.claude/skills/nist-fedramp-assessment/
cp -r skills/nist-csf-assessment/       <target-repo>/.claude/skills/nist-csf-assessment/
cp -r skills/create-prd/                <target-repo>/.claude/skills/create-prd/
cp -r skills/project/milestone/          <target-repo>/.claude/skills/project/milestone/
cp -r skills/occ-skill-creator/         <target-repo>/.claude/skills/occ-skill-creator/
cp -r skills/occ-skill-refactor/        <target-repo>/.claude/skills/occ-skill-refactor/
cp -r skills/project/                   <target-repo>/.claude/skills/project/
cp -r skills/rule-creator/              <target-repo>/.claude/skills/rule-creator/
```

Skills take effect immediately on the next Claude Code conversation in that repository.
