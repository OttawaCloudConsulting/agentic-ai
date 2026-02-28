# Rule Creator

**Source:** `skills/rule-creator/`
**Command:** `/rule-creator`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "create a rule", "write best practices", "add a new rule", "generate coding guidelines")

## Description

Interactive skill for generating new rules — always-on behavioral guidelines for Claude Code. Walks the user through a structured interview to determine the rule's domain, type, audience, and key concerns, then generates both the rule file and its companion documentation. Ensures all output follows the established format patterns used across the existing rule library.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with interactive workflow, rule constraints, and generation steps |
| `references/rule-format.md` | Structural templates for infrastructure and behavioral rules, extracted from existing rules |
| `references/doc-format.md` | Documentation template for `docs/rules/` companion files |

## Usage

```
/rule-creator
```

Invoke when you want to create a new rule file for the library. The skill handles the full lifecycle: requirements gathering, research, drafting, documentation, catalog updates, and linting.

## Workflow

### Step 1 — Gather Requirements

Uses AskUserQuestion to determine (in a single round):

- **Topic**: The technology or practice the rule covers (e.g., Go best practices, API design, Git workflow, observability)
- **Rule type**: Infrastructure best practices (like CDK/Terraform/K8s rules) or behavioral/process guidelines (like defensive protocol rules)?
- **Audience**: Who consumes the rule (e.g., all projects, specific tech stack, specific team)
- **Key concerns**: The 3-5 most important areas the rule must address (e.g., security, naming, testing, deployment safety)

Questions already answered in the user's initial request are skipped.

### Step 2 — Research

If the rule covers a technology:

1. Reads existing rules in `rules/` that overlap with the topic to avoid duplication
2. If the user has a codebase with examples, uses Grep to search for configuration files, naming patterns, and recurring idioms. Looks for: repeated boilerplate, inconsistent conventions, inline TODOs about best practices, and error-handling patterns
3. Identifies the boundary — what this rule covers that existing rules do not

### Step 3 — Draft Sections

Plans the section outline based on rule type. For structural patterns, reads `references/rule-format.md`.

**Infrastructure best practices** typically include: core design principles, architecture and organization, security, naming conventions, testing and validation, deployment safety, Bad Practices table, monitoring/observability, project hygiene.

**Behavioral/process rules** typically include: core principle (one-sentence thesis), concrete protocols with structured templates, boundary conditions (when to apply, when not to), failure modes and countermeasures.

Presents the planned outline to the user via AskUserQuestion for review before writing.

### Step 4 — Generate Rule

Writes the rule file to `rules/<rule-name>.md` following the structural patterns in `references/rule-format.md`:

- H1 title
- Blockquote one-line description
- H2 sections separated by `---`
- Code examples where they add clarity
- Bad Practices table for infrastructure rules
- Terse, imperative style throughout

### Step 5 — Generate Documentation

Writes companion documentation to `docs/rules/<rule-name>.md` following the patterns in `references/doc-format.md`:

- Metadata header (Source, Scope, Activation)
- Core Principle
- Overview paragraph
- Sections (summarized, not duplicated from rule)
- Bad Practices table (copied from rule)
- Related Rules

### Step 6 — Update Catalog

If `docs/RULES.md` exists, updates it:

- New row in the Quick Reference table
- New `cp` line in the Consuming Rules code block
- Entry in the Choosing Rules table if the rule fits a project type

If `docs/RULES.md` does not exist or has an unexpected structure, skips this step and notes it in the summary.

### Step 7 — Lint

Runs `bash scripts/lint-markdown.sh` on all created and modified files. Fixes any issues found.

### Step 8 — Present Summary

Reports files created, rule name and purpose, section count, and the consumption command.

## Rule Types

### Infrastructure Best Practices

For technology-specific coding guidelines (CDK, Terraform, Kubernetes, etc.). These rules typically include sections covering design principles, architecture, security, naming, testing, deployment, a Bad Practices table, monitoring, and project hygiene.

### Behavioral/Process Guidelines

For cross-cutting protocols that shape agent behavior (defensive coding, session management, etc.). These rules use structured templates in fenced code blocks and focus on a core principle, concrete protocols, boundary conditions, and failure modes.

## Output

| File | Location |
|---|---|
| Rule file | `rules/<rule-name>.md` |
| Rule documentation | `docs/rules/<rule-name>.md` |
| Updated catalog | `docs/RULES.md` |

## Rule Constraints

Rules generated by this skill follow these constraints:

- No YAML frontmatter — rules are pure content
- One concern per file
- Terse style — imperative sentences, minimal prose
- Opinionated defaults — works as-is, consumers adapt
- No filler — every line intentional

## Example

**User says:** "Create a rule for Go best practices focused on error handling and naming."

1. **Step 1** — Skip Topic (Go) and Key concerns (error handling, naming) since the user provided them. Ask Rule type and Audience only.
2. **Step 2** — Grep `rules/` for existing Go rules. Find none. Boundary is clear.
3. **Step 3** — Plan sections: Error Handling, Naming Conventions, Testing, Bad Practices. Present outline to user.
4. **Step 4** — Write `rules/go-best-practices.md` following infrastructure pattern from `references/rule-format.md`.
5. **Step 5** — Write `docs/rules/go-best-practices.md` following `references/doc-format.md`.
6. **Step 6** — Update `docs/RULES.md` catalog.
7. **Step 7** — Run `bash scripts/lint-markdown.sh` on created files. Fix issues.
8. **Step 8** — Report: 2 files created, 4 sections, consumption command.

## Error Handling

| Failure | Recovery |
|---|---|
| Lint fails on generated rule | Read the lint output. Fix the reported lines. Re-run lint until clean. |
| `docs/RULES.md` missing or unrecognized structure | Skip Step 6. Note in summary that catalog was not updated. |
| Reference files (`references/rule-format.md`, `references/doc-format.md`) not found | Stop and report. These files are required — the skill cannot produce correct output without them. |
| User requirements are ambiguous after Step 1 | Ask a follow-up question to clarify before proceeding to Step 2. Do not guess. |
| Existing rule already covers the topic | Report the overlap to the user. Ask whether to extend the existing rule or create a new one with a narrower scope. |

## When to Use

- Creating a new best-practices rule for a technology
- Creating a new behavioral or process guideline
- Adding domain-specific coding standards to the library

## When Not to Use

- Editing an existing rule — edit the file directly
- Creating skills or commands — use `/skill-creator`
- Creating Kiro steering files — different format conventions

## Related Skills

- **skill-creator** — for creating skills (action workflows with supporting assets), not rules (always-on guidelines)
- **compliance-assess** — example of a skill that consumes rules as behavioral context
