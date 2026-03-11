---
name: rule-creator
description: Generate new rules — always-on behavioral guidelines for Claude Code. Use when asked to create a rule, write best practices, add a new rule file, or generate coding guidelines. Walks through an interactive interview to produce a rule file and its documentation. Do NOT use for auditing, reviewing, or listing existing rules.
disable-model-invocation: true
license: MIT
---

# Rule Creator

Generate rules — always-on behavioral guidelines that shape how Claude writes code, handles failures, and makes decisions. Rules are pure markdown, have no frontmatter, and are loaded automatically when placed in `.claude/rules/`.

## Rule Constraints

- **No YAML frontmatter** — rules are pure content
- **One concern per file** — single topic focus
- **Terse style** — imperative sentences, minimal prose, say it once
- **Opinionated defaults** — works as-is, consumers adapt to their project
- **No filler** — every line intentional

## Workflow

### Step 1 — Gather Requirements

Use AskUserQuestion to determine the rule's domain and shape. Ask in a single round:

1. **Topic**: "What technology or practice should this rule cover?" (e.g., Go best practices, API design, Git workflow, observability)
2. **Rule type**: Infrastructure best practices (like CDK/Terraform/K8s rules) or behavioral/process guidelines (like defensive protocol rules)?
3. **Audience**: Who consumes this rule? (e.g., all projects, specific tech stack, specific team)
4. **Key concerns**: "What are the 3-5 most important things this rule must address?" (e.g., security, naming, testing, deployment safety)

If the user has already provided clear answers to any of these in their initial request, skip those questions.

### Step 2 — Research

If the rule covers a technology:

1. Read existing rules in `rules/` that overlap with the topic to avoid duplication
2. If the user has a codebase with examples, use Grep to search for configuration files, naming patterns, and recurring idioms (e.g., `grep -r "error handling" rules/`). Look for: repeated boilerplate, inconsistent conventions, inline TODOs about best practices, and error-handling patterns
3. Identify the boundary — what does this rule cover that existing rules do not?

### Step 3 — Draft Sections

Based on the rule type, plan sections using the section-type guidance in `references/rule-format.md`.

Present the planned section outline to the user via AskUserQuestion: "Here's the planned structure. Add, remove, or reorder sections?"

### Step 4 — Generate Rule

Write the rule file to `rules/<rule-name>.md`.

Follow `references/rule-format.md` exactly.

### Step 5 — Generate Documentation

Write documentation to `docs/rules/<rule-name>.md`.

Follow `references/doc-format.md` exactly.

### Step 6 — Update Catalog

If `docs/RULES.md` exists, update it:

1. Add a row to the Quick Reference table
2. Add a `cp` line to the Consuming Rules code block
3. Add to the Choosing Rules table if the rule fits a project type

If `docs/RULES.md` does not exist or has an unexpected structure, skip this step and note it in the summary (Step 8).

### Step 7 — Lint

Run `bash scripts/lint-markdown.sh` on all created/modified files. Fix any issues.

### Step 8 — Present Summary

Report:

- Files created
- Rule name and purpose
- Section count
- How to consume: `cp rules/<name>.md <target-repo>/.claude/rules/`

## Example

**User says:** "Create a rule for Go best practices focused on error handling and naming."

- **Trigger**: "Create a rule for Go best practices focused on error handling and naming."
- **Key decisions**: Topic and concerns already provided — skip those Step 1 questions. No existing Go rules found — boundary clear. Infrastructure-type rule selected.
- **Output**: `rules/go-best-practices.md`, `docs/rules/go-best-practices.md`, catalog updated.

## Error Handling

| Failure | Recovery |
|---|---|
| Lint fails on generated rule | Read the lint output. Fix the reported lines. Re-run lint until clean. |
| `docs/RULES.md` missing or unrecognized structure | Skip Step 6. Note in summary that catalog was not updated. |
| Reference files (`references/rule-format.md`, `references/doc-format.md`) not found | Stop and report. These files are required — the skill cannot produce correct output without them. |
| User requirements are ambiguous after Step 1 | Ask a follow-up AskUserQuestion to clarify before proceeding to Step 2. Do not guess. |
| Existing rule already covers the topic | Report the overlap to the user. Ask whether to extend the existing rule or create a new one with a narrower scope. |

## References

- **Rule file format patterns**: See `references/rule-format.md` for structural templates extracted from existing rules
- **Documentation format patterns**: See `references/doc-format.md` for the docs/rules/ documentation structure
