# agentic-ai

A library of drop-in agentic AI configurations for Claude Code and Kiro: commands, skills, rules, and scripts. No runtime code. Copy content into other repositories where it is consumed.

## What's Here

### Skills

Multi-file bundles — a `SKILL.md` plus supporting scripts and references. Copy the whole directory to `.claude/skills/<name>/` in your project and invoke with `/<skill-name>`.

Covers: CDK testing, Terraform testing, compliance assessments (ITSG-33, NIST FedRAMP, NIST CSF), PRD creation, skill authoring, and rule creation.

→ [docs/SKILLS.md](docs/SKILLS.md)

### Commands

Single-file markdown workflows. Copy to `.claude/commands/` and invoke with `/<command-name>`.

Covers: session catchup/handoff, feature start, investigation, documentation refresh, and compliance auto-assessment.

→ [docs/COMMANDS.md](docs/COMMANDS.md)

### Rules

Always-on behavioral guidelines loaded automatically from `.claude/rules/`. Not invoked — they shape the model's reasoning on every turn.

Covers: defensive protocol (anti-slop, epistemology, session management), CDK, Terraform, Crossplane v1/v2, and Kubernetes best practices.

→ [docs/RULES.md](docs/RULES.md)

### Scripts

Shell script bundles copied to `scripts/` and run directly from the terminal. Not Claude Code content.

Covers: skill benchmarking (score a skill against a baseline or previous version, produce a promotion verdict).

→ [docs/SCRIPTS.md](docs/SCRIPTS.md)

## Kiro

Parallel equivalents for Kiro: powers (keyword-activated workflow bundles) and steering (always-on guidance). See `kiro/README.md`.
