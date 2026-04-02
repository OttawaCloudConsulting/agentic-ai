# Codebase Conventions

## Authoring Language

All content is Markdown. No application code (Python, TypeScript, etc.) exists in this repo — the "code" is prompt engineering, workflow instructions, and shell scripts.

## Skill File Conventions (SKILL.md)

### Frontmatter

```yaml
---
name: skill-name              # kebab-case, max 64 chars
description: >                # Trigger phrases embedded here for auto-detection
  Describes what the skill does and when to use it.
disable-model-invocation: true  # Always set — skills are slash-invoked only
---
```

- `disable-model-invocation: true` is mandatory — prevents auto-triggering
- Description includes natural-language trigger phrases ("Use when...", "Phrases like...")
- `compatibility` and `license` fields optional

### Workflow Structure

Skills use numbered steps with clear action verbs:

```markdown
## Step 1: Name

Action description.

## Step 2: Name
```

- Steps are sequential by default
- Each step shows work to user after completion
- `AskUserQuestion` used for interactive prompts (2-4 options, ≤12-char headers)
- Never dump all questions at once — one round at a time

### Tool Usage

- `Read` — read files and templates
- `Write` — create new files
- `Edit` — modify existing files
- `Bash` — read-only shell operations (ls, grep, git log)
- `AskUserQuestion` — interactive user prompts
- `Agent` — spawn sub-agents for parallel/isolated work
- Scripts always invoked with explicit interpreter: `bash scripts/foo.sh` (never `./scripts/foo.sh`)
- **Never** set executable bit on scripts (`chmod +x` prohibited)

## Command File Conventions

Single `.md` file with YAML frontmatter. Simpler than skills — no multi-file bundle.

```yaml
---
name: command-name
description: What it does and when to use it.
---
```

## Agent File Conventions

```yaml
---
name: agent-name
description: "What this agent does..."
tools: Read, Write, Edit, Bash, Grep, Glob
model: sonnet
maxTurns: 50
---
```

- Agents write output directly to files — they do not return content to orchestrator
- Orchestrator receives only confirmation + line counts
- Agent-to-agent communication via files only (never direct messaging)

## Markdown Style

| Rule | Behaviour |
|---|---|
| Line length (MD013) | Disabled — tables, URLs, descriptions exceed 80 chars naturally |
| Duplicate headings (MD024) | Disabled — repeated section names under different parents are intentional |
| Emphasis as heading (MD036) | Disabled — bold used as inline labels |
| Fenced code language (MD040) | Disabled — plain-text output and pseudocode blocks are common |
| Table column style (MD060) | Disabled — compact pipe syntax is repo standard |

Markdown linting via `bash cicd/lint-markdown.sh` (3-tier: ignore → auto-fix → error).

## Naming Conventions

| Thing | Pattern | Example |
|---|---|---|
| Directories | `kebab-case` | `skills/create-prd/` |
| Skill files | `SKILL.md` (uppercase) | `SKILL.md` |
| Catalog docs | `UPPERCASE.md` | `docs/SKILLS.md` |
| Detail docs | match directory name | `docs/skills/create-prd.md` |
| Scripts | `kebab-case.sh` | `cicd/lint-markdown.sh` |
| Agents | `kebab-case.md` | `gsd-executor.md` |
| GSD agents | `gsd-<role>.md` | `gsd-codebase-mapper.md` |

## Documentation Requirements

Every new component requires:
1. The component itself (`skills/<name>/SKILL.md` or `commands/<name>.md`)
2. A detail doc (`docs/skills/<name>.md` or `docs/commands/<name>.md`)
3. An entry in the relevant catalog (`docs/SKILLS.md` or `docs/COMMANDS.md`)

## Git Conventions

Commits follow conventional commit format observed in history:
- `feat:` — new skill, command, or significant capability
- `fix:` — bug fix in skill behaviour
- `docs:` — documentation updates
- PR titles kept under 70 characters
