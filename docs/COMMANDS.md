# Commands Reference

Commands are single-file markdown workflows invoked with `/<command-name>` in the Claude Code CLI. Each command is a standalone `.md` file with YAML frontmatter.

For multi-file skill bundles (with scripts and references), see [SKILLS.md](SKILLS.md).

## Quick Reference

| Command | Trigger | Purpose | Details |
|---|---|---|---|
| Create PRD | `/create-prd` | Guided interview to create PRD, architecture doc, and progress file | [View](commands/create-prd.md) |
| Start Feature | `/start-feature` | Begin the next feature from progress.txt — interactive, with human-in-the-loop review | [View](commands/start-feature.md) |
| Catchup | `/catchup` | Read project state at start of a new session | [View](commands/catchup.md) |
| Handoff | `/handoff` | Save session state before ending | [View](commands/handoff.md) |
| Investigate | `/investigate` | Structured debugging investigation | [View](commands/investigate.md) |
| Update Docs | `/update-docs` | Refresh README and architecture docs | [View](commands/update-docs.md) |
| Update Docs CDK | `/update-docs-cdk` | CDK-specific documentation refresh | [View](commands/update-docs-cdk.md) |
| Update Docs Terraform | `/update-docs-terraform` | Terraform-specific documentation refresh | [View](commands/update-docs-terraform.md) |
| Compliance Auto-Assess | `/compliance-auto-assess` | Automated ITSG-33 compliance assessment via sub-agent | [View](commands/compliance-auto-assess.md) |
| Dream | `/dream` | Reflective memory consolidation pass | [View](commands/dream.md) |

## How Commands Work

- Commands live in `commands/` at the repository root (drop-in source)
- Consumers copy them to `.claude/commands/` in their target project
- Claude Code registers each `.md` file in `.claude/commands/` as a slash command
- Commands have YAML frontmatter with `name` and `description` fields
- The `description` field includes trigger phrases so the model knows when to invoke the command
- Commands are invoked manually via `/<command-name>` or automatically when the model matches trigger phrases

### Frontmatter

```yaml
---
name: command-name                    # Required. The /command name.
description: What the command does    # Required. Include trigger phrases.
---
```

## Project Lifecycle

Commands follow a development lifecycle. Use them in this order for new projects:

```
/create-prd          Create project requirements, architecture, progress file
    │
/start-feature       Pick up the next feature — review plan, then implement on confirmation
/start-feature-auto  Pick up the next feature — write plan to NOTES, implement automatically
    │
  (implement)        Write the code
    │
/test-terraform      Validate, plan, apply, commit  (or /test-cdk for CDK projects)
    │
  (repeat)           /start-feature → implement → /test-*
    │
/update-docs         Refresh docs after features accumulate
```

### Session Management

```
/catchup             Start of session: read last handoff + progress.txt
  (work)
/handoff             End of session: save state before closing
/dream               Consolidate, merge, and prune memory files
```

### Debugging

```
/investigate         Create structured investigation for unknown issues
```

## Consuming Commands

Copy command files from `commands/` into `.claude/commands/` in the target repository:

```bash
# Copy individual commands
cp commands/create-prd.md              <target-repo>/.claude/commands/
cp commands/start-feature.md           <target-repo>/.claude/commands/
cp commands/catchup.md                 <target-repo>/.claude/commands/
cp commands/handoff.md                 <target-repo>/.claude/commands/
cp commands/investigate.md             <target-repo>/.claude/commands/
cp commands/update-docs.md             <target-repo>/.claude/commands/
cp commands/update-docs-cdk.md         <target-repo>/.claude/commands/
cp commands/update-docs-terraform.md   <target-repo>/.claude/commands/
cp commands/compliance-auto-assess.md  <target-repo>/.claude/commands/
cp commands/dream.md                   <target-repo>/.claude/commands/
```

Commands take effect immediately on the next Claude Code conversation in that repository.

### Choosing Commands

| Project Type | Recommended Commands |
|---|---|
| Any project | `create-prd`, `start-feature`, `start-feature-auto`, `catchup`, `handoff`, `investigate`, `update-docs`, `dream` |
| Terraform projects | Above + `update-docs-terraform` |
| CDK projects | Above + `update-docs-cdk` |
| Compliance-sensitive projects | Above + `compliance-auto-assess` |
