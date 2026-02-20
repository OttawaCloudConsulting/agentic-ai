# Skills Reference

Skills are portable bundles that provide structured workflows with supporting assets (scripts, references, templates). Each skill is a directory containing a `SKILL.md` definition plus supporting files. They are invoked with `/<skill-name>` in the Claude Code CLI.

For single-file commands (no supporting assets), see [COMMANDS.md](COMMANDS.md).

## Quick Reference

| Skill | Command | Purpose | Details |
|---|---|---|---|
| CDK Testing | `/cdk-testing` | Validate, scan, build, test, and deploy CDK code | [View](skills/cdk-testing.md) |
| Terraform Testing | `/terraform-testing` | Validate, scan, plan, and deploy Terraform code | [View](skills/terraform-testing.md) |
| Compliance Assess | `/compliance-assess` | ITSG-33 / CCCS Medium compliance assessment with user checkpoints | [View](skills/compliance-assess.md) |
| Skill Creator | `/skill-creator` | Guide for creating new skills that extend Claude's capabilities | [View](skills/skill-creator.md) |

## How Skills Work

- Skills live in `skills/<name>/` at the repository root (drop-in source)
- Consumers copy the entire directory to `.claude/skills/<name>/` in their target project
- Each skill directory contains:
  - `SKILL.md` — the skill definition with YAML frontmatter (`name`, `description`)
  - `scripts/` — executable shell scripts (optional)
  - `references/` — supporting documentation loaded on-demand (optional)
- The `description` field in frontmatter includes trigger phrases so the model knows when to invoke the skill
- Skills are invoked manually via `/<skill-name>` or automatically when the model matches trigger phrases

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
---
```

## Consuming Skills

Copy the entire skill directory from `skills/` into `.claude/skills/` in the target repository:

```bash
# Copy a skill bundle
cp -r skills/cdk-testing/       <target-repo>/.claude/skills/cdk-testing/
cp -r skills/terraform-testing/  <target-repo>/.claude/skills/terraform-testing/
cp -r skills/compliance-assess/  <target-repo>/.claude/skills/compliance-assess/
cp -r skills/skill-creator/      <target-repo>/.claude/skills/skill-creator/
```

Skills take effect immediately on the next Claude Code conversation in that repository.
