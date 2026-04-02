# Codebase Structure

## Directory Layout

```
agentic-ai/
├── skills/                    # Skill bundles (multi-file, slash-invocable)
│   ├── cdk-testing/           # AWS CDK testing skill
│   ├── create-prd/            # PRD creation skill (predecessor to /project /define)
│   ├── itsg-assessment/       # ITSG-33 security assessment skill
│   ├── nist-csf-assessment/   # NIST CSF assessment skill
│   ├── nist-fedramp-assessment/ # NIST FedRAMP assessment skill
│   ├── occ-skill-creator/     # Skill authoring and review meta-skill
│   ├── occ-skill-refactor/    # Skill refactoring meta-skill
│   ├── project/               # /project orchestrated workflow (in design)
│   │   ├── DESIGN.md          # Design document (authoritative)
│   │   ├── design-decisions/  # OPEN_QUESTIONS.md, REVIEW_FINDINGS.md
│   │   └── progress-file/     # Format decision artifacts
│   ├── rule-creator/          # Claude Code rule authoring skill
│   └── terraform-testing/     # Terraform testing skill
│
├── commands/                  # Single-file slash commands
│   ├── catchup.md
│   ├── compliance-auto-assess.md
│   ├── dream.md
│   ├── handoff.md
│   ├── investigate.md
│   ├── start-feature.md
│   ├── start-feature-auto.md
│   ├── update-docs.md
│   ├── update-docs-cdk.md
│   └── update-docs-terraform.md
│
├── agents/                    # Standalone agent definitions
│   └── terraform-engineer.md
│
├── docs/                      # Catalog documentation
│   ├── SKILLS.md              # Skill catalog (index)
│   ├── COMMANDS.md            # Command catalog (index)
│   ├── RULES.md               # Rules catalog
│   ├── SCRIPTS.md             # Scripts catalog
│   ├── SOLUTIONS.md           # Solution kits catalog
│   ├── ARCHITECTURE_AND_DESIGN.md  # Repo-level architecture
│   ├── commands/              # Per-command detail docs
│   ├── skills/                # Per-skill detail docs
│   ├── rules/                 # Per-rule detail docs
│   ├── scripts/               # Per-script detail docs
│   └── solutions/             # Per-solution detail docs
│
├── cicd/                      # CI/CD scripts
│   └── lint-markdown.sh       # Markdown linting (3-tier: ignore/fix/error)
│
├── agentic-engineering/       # Reference materials (PDF, MD, SVG)
│
├── .claude/                   # Claude Code configuration (active/installed)
│   ├── agents/                # GSD agent definitions (18 agents)
│   ├── commands/              # Active commands (dream.md, start-feature.md)
│   ├── get-shit-done/         # GSD workflow engine
│   ├── hooks/                 # Claude Code hooks (5 hooks)
│   ├── rules/                 # Always-on behavioral rules
│   ├── settings.json          # Claude Code settings
│   └── settings.local.json    # Local overrides
│
├── .gemini/                   # Gemini CLI mirror of .claude/
│   └── (mirrors .claude/ structure)
│
├── .planning/                 # GSD planning workspace (gitignored)
│   └── codebase/              # Codebase map documents
│
├── CLAUDE.md                  # Project-level Claude instructions
├── .markdownlint.jsonc        # Markdown lint rules (error enforcement)
├── .markdownlint-fix.markdownlint.jsonc  # Markdown auto-fix rules
└── .gitignore
```

## Skill Bundle Structure

Every skill follows this internal layout:

```
skills/<skill-name>/
├── SKILL.md          # Required — frontmatter + workflow instructions
├── scripts/          # Optional — shell scripts (executed with explicit interpreter)
├── references/       # Optional — supporting reference docs loaded as needed
├── assets/           # Optional — templates, boilerplate
└── review/           # Optional — BENCHMARK.md, FEEDBACK.md, PLAN.md
```

## Naming Conventions

| Artifact | Convention | Example |
|---|---|---|
| Skill directories | `kebab-case` | `skills/create-prd/` |
| Command files | `kebab-case.md` | `commands/start-feature.md` |
| Agent files | `kebab-case.md` | `.claude/agents/gsd-executor.md` |
| Skill main file | `SKILL.md` (uppercase) | `skills/cdk-testing/SKILL.md` |
| Catalog docs | `UPPERCASE.md` | `docs/SKILLS.md` |
| Detail docs | match skill name | `docs/skills/create-prd.md` |
| Script files | `kebab-case.sh` | `cicd/lint-markdown.sh` |

## Key Locations

| What | Where |
|---|---|
| Add a new skill | `skills/<name>/SKILL.md` + `docs/skills/<name>.md` + entry in `docs/SKILLS.md` |
| Add a new command | `commands/<name>.md` + `docs/commands/<name>.md` + entry in `docs/COMMANDS.md` |
| Add a new agent | `agents/<name>.md` + `.claude/agents/<name>.md` + `.gemini/agents/<name>.md` |
| Add a new rule | `.claude/rules/<name>.md` + entry in `docs/RULES.md` |
| GSD workflow engine | `.claude/get-shit-done/` |
| GSD agent definitions | `.claude/agents/gsd-*.md` |

## .claude / .gemini Sync Pattern

`.gemini/` mirrors `.claude/` for multi-AI-runtime support. Both directories maintain the same agent definitions, hooks, and settings. Manual sync required — no automated sync exists yet.
