# Agent Profiles Reference

Agent profiles are system-prompt definitions for **read-only reviewer subagents** invoked via the Agent tool. Unlike skills and commands (which the user triggers with `/<name>`), a profile is loaded as a subagent's system prompt — the main agent dispatches it with a target, and it returns findings in an isolated context. Profiles live in `agent-profiles/` at the repository root.

The isolation is the point: a profile can run at a **different model** than the one that produced the artifact under review, which is the only mechanism that breaks artifact-anchored bias (an author model is anchored on its own output).

## Quick Reference

| Profile | File | Purpose | Details |
|---|---|---|---|
| Over-Engineering Reviewer | `agent-profiles/over-engineering-reviewer.md` | Runs the 3-clause discriminator over a diff/file/plan/design and emits severity-tagged over-engineering findings — no praise, no fixes; settable to a non-author model for diff-model bias-break | [View](agent-profiles/over-engineering-reviewer.md) |

## How Agent Profiles Work

- Profiles live in `agent-profiles/` at the repository root (drop-in source).
- Each profile is a single `.md` file with YAML frontmatter plus a system-prompt body.
- The main agent invokes a profile via the Agent tool, passing a target (diff, file, plan, or design doc).
- The subagent runs in an isolated context and returns findings only — it does not modify files.

### Frontmatter

```yaml
---
name: profile-name                  # Required. Identifier for the profile.
description: What the reviewer does  # Required. Include when-to-use guidance.
tools:                              # Read-only tool set.
  - Read
  - Grep
  - Glob
model: claude-sonnet-4-6            # Default model; override for diff-model bias-break.
---
```

### Profiles vs Rules vs Skills vs Commands

| | Agent Profiles | Rules | Skills | Commands |
|---|---|---|---|---|
| Location | `agent-profiles/` | `.claude/rules/` | `.claude/skills/<name>/` | `.claude/commands/` |
| Activation | Dispatched as a subagent | Automatic (always loaded) | Manual (`/skill-name`) | Manual (`/command-name`) |
| Context | Isolated subagent | Main agent | Main agent | Main agent |
| Writes files | No (read-only) | No | Yes | Yes |
| Frontmatter | Required | None | Required | Required |

## Consuming Agent Profiles

Copy a profile into the target repository's `agent-profiles/` directory:

```bash
cp agent-profiles/over-engineering-reviewer.md  <target-repo>/agent-profiles/
```

Set the profile's `model` field to a model other than the deliverable's author to enable the diff-model bias-break. The profile is zero-dependency — it embeds its own copy of the discriminator and carries no import of the other over-engineering-gate artifacts.

## See Also

- [`docs/rules/defensive-protocol-v2-over-engineering.md`](rules/defensive-protocol-v2-over-engineering.md) — the always-on reminder tier of the same gate.
- [`docs/skills/over-engineering-review.md`](skills/over-engineering-review.md) — the on-demand active-pass tier.
- [`docs/ARCHITECTURE_AND_DESIGN.md`](ARCHITECTURE_AND_DESIGN.md) — design spec for the discriminator and the three-artifact design.
