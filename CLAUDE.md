# Project Rules — agentic-ai

## What This Is

A library of drop-in Claude Code configurations: prompts, commands, and project rules. No runtime code. Content is copied into other repositories where it is consumed.

## Structure

```
agentic-ai/
├── CLAUDE.md                          ← this file (rules for working in this repo)
├── prompts/
│   ├── common/                        ← generic commands usable across any project type
│   │   └── commands/
│   └── <project-type>/                ← self-contained kit per project type
│       ├── CLAUDE.md                  ← project rules template
│       ├── commands/                  ← project-specific commands
│       └── CLAUDE_CODE_USER_GUIDE.md  ← optional developer guide
├── rules/                             ← always-on behavioral guidelines (not commands)
├── guides/                            ← developer-facing how-to docs (future)
├── notes/                             ← internal learnings and patterns (future)
└── .claude/                           ← local settings for this repo only (not drop-in content)
```

### Kit Model

Each `prompts/<project-type>/` is a **kit** — a self-contained set of files to copy into a target project. A kit may reference generic commands from `prompts/common/` that the consumer also needs to copy.

**To consume a kit:** copy `prompts/<project-type>/` contents into the target repo root, then copy any referenced generic commands from `prompts/common/commands/` into `.claude/commands/`. Copy any desired rules from `rules/` into `.claude/rules/`.

### Content Types

| Path | Contains | Drop-in target |
|---|---|---|
| `prompts/common/commands/*.md` | Generic skills (catchup, handoff, investigate, etc.) | `.claude/commands/` |
| `prompts/<type>/CLAUDE.md` | Project rules template | repo root |
| `prompts/<type>/commands/*.md` | Project-specific skills | `.claude/commands/` |
| `prompts/<type>/CLAUDE_CODE_USER_GUIDE.md` | Developer workflow guide | repo root or `docs/` |
| `rules/*.md` | Always-on behavioral guidelines (defensive protocol, etc.) | `.claude/rules/` |

## Rules

1. **Content project.** All files are markdown. Quality = clarity + correctness.
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

### Rules

- Pure content, no YAML frontmatter
- Behavioral guidelines, not action-oriented workflows
- Always-on context — loaded automatically, never invoked by the user
- One concern per file

### Project Type Kits

- Must contain a `CLAUDE.md` at minimum
- Define tech stack, workflow, and skill references
- List which generic commands from `prompts/common/` the kit depends on

## Workflow

The user describes what they need. Claude generates the content. The user reviews.

## Git

- Work on `dev`, merge to `main` when stable
- `git add .` forbidden — add files individually
