# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A library of drop-in agentic AI configurations for Claude Code and Kiro: commands, skills, rules, project kits, and powers. No runtime code. Content is copied into other repositories where it is consumed.

## Structure

```
agentic-ai/
├── CLAUDE.md                          ← this file (rules for working in this repo)
├── commands/                          ← drop-in command source files (generic + project-specific)
├── skills/                            ← portable skill bundles (SKILL.md + scripts/)
│   └── <skill-name>/
│       ├── SKILL.md                   ← skill definition with frontmatter
│       └── scripts/                   ← supporting shell scripts
├── rules/                             ← always-on behavioral guidelines (not commands)
├── prompts/                           ← self-contained project kits
│   └── <project-type>/
│       ├── CLAUDE.md                  ← project rules template
│       ├── commands/                  ← project-specific commands (if any)
│       └── CLAUDE_CODE_USER_GUIDE.md  ← optional developer guide
├── kiro/                              ← Kiro-native equivalents (powers + steering)
│   ├── powers/                        ← keyword-activated workflow bundles
│   │   └── <power-name>/
│   │       ├── POWER.md               ← power definition with frontmatter
│   │       └── steering/              ← task-specific steering files
│   ├── steering/                      ← always-on/auto-activated guidance
│   └── docs/                          ← Kiro reference docs (POWERS.md, STEERING.md)
├── agentic-engineering/               ← strategic workflow reference (diagram + docs)
├── mcp/                               ← MCP server project (has own README + architecture)
├── docs/                              ← reference documentation for this repo
│   ├── SKILLS.md                      ← skill catalog and usage guide
│   ├── RULES.md                       ← rules catalog and usage guide
│   └── ARCHITECTURE_AND_DESIGN.md     ← Kiro conversion architecture
├── working/                           ← scratch space for active development
├── tests/                             ← test fixtures
└── .claude/                           ← local settings for this repo only
```

## Content Model

### Claude Code Content

| Path | Contains | Drop-in target |
|---|---|---|
| `commands/*.md` | Standalone commands (catchup, handoff, investigate, etc.) | `.claude/commands/` |
| `skills/<name>/` | Skill bundles (SKILL.md + scripts) | `.claude/skills/<name>/` |
| `rules/*.md` | Always-on behavioral guidelines | `.claude/rules/` |
| `prompts/<type>/CLAUDE.md` | Project rules template | repo root |
| `prompts/<type>/CLAUDE_CODE_USER_GUIDE.md` | Developer workflow guide | repo root or `docs/` |

### Kiro Content

| Path | Contains | Drop-in target |
|---|---|---|
| `kiro/powers/<name>/` | Keyword-activated workflow bundles | `.kiro/powers/<name>/` |
| `kiro/steering/*.md` | Always-on/auto-activated guidance | `.kiro/steering/` |

### Relationship

Claude Code and Kiro content are parallel — same concepts, different formats. Commands/skills become Kiro powers (grouped by concern). Rules become Kiro steering files (with YAML frontmatter for inclusion mode). See `docs/ARCHITECTURE_AND_DESIGN.md` for the full mapping.

### Commands vs Skills

**Commands** (`commands/*.md`) are standalone markdown files. Copy directly to `.claude/commands/`.

**Skills** (`skills/<name>/`) are bundles that include a `SKILL.md` (with YAML frontmatter: `name`, `description`) plus supporting scripts or assets. The SKILL.md content goes into `.claude/commands/` and scripts are copied alongside.

### Kit Model

Each `prompts/<project-type>/` is a **kit** — a self-contained set of files to copy into a target project. A kit may reference commands from `commands/` that the consumer also needs to copy.

**To consume a kit:** copy `prompts/<project-type>/` contents into the target repo root, then copy any referenced commands from `commands/` into `.claude/commands/`. Copy any desired rules from `rules/` into `.claude/rules/`.

## Rules

1. **Content project.** All files are markdown (plus shell scripts in skills). Quality = clarity + correctness.
2. **One skill per file.** Self-contained. Can reference other skills by name, must not inline them.
3. **No filler.** Every line intentional. No boilerplate, no placeholder sections.
4. **Opinionated defaults.** Content works as-is but consumers are expected to adapt to their project.
5. **Terse style.** Imperative sentences. Minimal prose. Say it once.
6. **Preserve paths.** Do not reorganize or rename without explicit instruction.

## Content Guidelines

### Commands

- Clear purpose at the top
- Step-by-step instructions
- Define what the skill reads and what it produces
- Specify failure behavior

### Skills

- `SKILL.md` requires YAML frontmatter (`name`, `description`)
- `description` should include trigger phrases for model invocation
- Scripts in `scripts/` — portable, auto-detect OS, install missing tools
- Document configuration options (env vars, config files, CLI flags)

### Rules

- Pure content, no YAML frontmatter
- Behavioral guidelines, not action-oriented workflows
- Always-on context — loaded automatically, never invoked by the user
- One concern per file

### Kiro Powers

- `POWER.md` requires YAML frontmatter (`name`, `displayName`, `description`, `keywords`)
- Primary keywords in frontmatter, secondary keywords in body text
- Steering files within powers: plain markdown, no frontmatter
- Describe workflows as guidance, not imperative tool calls

### Kiro Steering

- Requires YAML frontmatter with `inclusion` mode (`always` or `auto`)
- `auto` mode needs `name` and `description` fields
- Tool-agnostic language (no Claude Code-specific references)

### Project Type Kits

- Must contain a `CLAUDE.md` at minimum
- Define tech stack, workflow, and skill references
- List which commands from `commands/` the kit depends on

## Workflow

The user describes what they need. Claude generates the content. The user reviews.

## Git

- Work on `dev`, merge to `main` when stable
- `git add .` forbidden — add files individually
