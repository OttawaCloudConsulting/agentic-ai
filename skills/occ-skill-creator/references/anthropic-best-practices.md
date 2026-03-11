# Anthropic Skill Best Practices

Reference for red-teaming skills against official Anthropic standards. Use this during the refactor review stage to identify gaps and issues.

Source: The Complete Guide to Building Skills for Claude (Anthropic, 2026)

---

## Contents

- [Naming Rules](#naming-rules)
- [Frontmatter Requirements](#frontmatter-requirements)
- [Trigger Quality Checklist](#trigger-quality-checklist)
- [Progressive Disclosure](#progressive-disclosure)
- [Instruction Quality](#instruction-quality)
- [File Structure Conventions](#file-structure-conventions)
- [Common Failure Modes](#common-failure-modes)
- [Severity Classification for Gaps](#severity-classification-for-gaps)

---

## Naming Rules

| Rule | Requirement |
|---|---|
| Folder name | kebab-case, lowercase only, no spaces, no underscores |
| `name` field | Must match folder name |
| `SKILL.md` | Exact spelling, case-sensitive — no `skill.md`, `SKILL.MD` |
| No `README.md` | Not allowed inside skill folder |

Reserved prefixes — forbidden in skill names: `claude`, `anthropic`

---

## Frontmatter Requirements

Required fields:

```yaml
---
name: skill-name-in-kebab-case
description: What it does and when to use it.
---
```

Rules for each field:

**`name`**

- kebab-case only
- No spaces, no capitals, no underscores

**`description`** (the most critical field)

- Must include BOTH: what the skill does AND when to use it (trigger conditions)
- Under 1024 characters
- No XML angle brackets (`<` or `>`)
- Include specific phrases users would actually say
- Mention file types if the skill handles specific formats
- Include negative triggers for narrow skills ("Do NOT use for...")

Optional fields:

- `license`: MIT, Apache-2.0, etc. (for open-source)
- `compatibility`: Environment requirements, 1–500 characters
- `metadata`: Custom key-value pairs (author, version, mcp-server, etc.)
- `allowed-tools`: Restrict which tools the skill can use

---

## Trigger Quality Checklist

A skill description triggers Claude to load the skill. Evaluate:

- [ ] Does it include specific phrases users would say? (not just technical terms)
- [ ] Is it more specific than "helps with X"?
- [ ] Does it mention relevant file types (`.csv`, `.fig`, `.pdf`, etc.) if applicable?
- [ ] For narrow skills: does it include negative triggers to prevent false positives?
- [ ] Is it under 1024 characters?

**Red flags for under-triggering:**

- Description is too generic ("Helps with projects")
- No trigger phrases — only technical description
- Domain jargon users wouldn't say

**Red flags for over-triggering:**

- Description covers too broad a domain
- No negative triggers for skills with overlapping topics
- Trigger phrases match common general queries

---

## Progressive Disclosure

Three-tier loading system — the skill must implement this correctly:

| Tier | Location | When loaded | Size target |
|---|---|---|---|
| 1 — Metadata | YAML frontmatter | Always | ~100 words |
| 2 — Instructions | SKILL.md body | On trigger | <500 lines |
| 3 — Detail | `references/` files | As needed | Varies |

Failures to flag:

- SKILL.md body exceeds 500 lines — move content to `references/`
- Reference files mentioned but never linked from SKILL.md with clear "when to read" guidance
- All content inlined in SKILL.md instead of using progressive disclosure
- Reference files loaded unconditionally rather than conditionally

---

## Instruction Quality

Evaluate the SKILL.md body instructions against these criteria:

**Be specific and actionable**

- Bad: "Validate the data before proceeding."
- Good: "Run `python scripts/validate.py --input {filename}`. If validation fails, common issues include: missing required fields, invalid date formats."

**Include error handling**

- Common errors should be documented with cause and solution
- MCP connection failures if the skill uses MCP
- Script failures with recovery steps

**Reference bundled resources clearly**

- Each reference file should have explicit "when to read" guidance
- Don't say "see references/" — say "before writing queries, consult `references/api-patterns.md` for..."

**Examples**

- At least one concrete example showing trigger phrase → actions → result
- Examples should demonstrate the core use case, not edge cases

**Critical instructions at the top**

- Don't bury important rules in the middle or bottom of the document
- Use `## Important` or `## Critical` headers for must-follow instructions

---

## File Structure Conventions

```
skill-name/
├── SKILL.md          required
├── scripts/          optional — executable code for deterministic tasks
├── references/       optional — documentation loaded as needed
└── assets/           optional — templates, images, fonts used in output
```

**Forbidden files:**

- `README.md` (inside skill folder)
- `CHANGELOG.md`
- `INSTALLATION_GUIDE.md`
- Any file that's for human readers, not AI execution

**Reference file guidelines:**

- Keep references one level deep from SKILL.md (no nested `references/sub/`)
- For files >100 lines, include a table of contents at the top
- Information should live in either SKILL.md or references — not both

---

## Common Failure Modes

| Failure | Symptoms | Fix |
|---|---|---|
| Vague description | Skill never auto-triggers | Add specific trigger phrases, concrete examples |
| Missing triggers | Users must manually invoke | Include "Use when user says..." patterns |
| Instructions buried | Critical steps ignored | Move key rules to top, use `## Critical` headers |
| No error handling | Failures stop workflow | Add troubleshooting section with common errors |
| Over-verbose SKILL.md | Context bloat, degraded responses | Move details to `references/`, keep SKILL.md lean |
| Model "laziness" signals | Steps skipped, partial output | Add explicit "do not skip" notes; use deterministic scripts for critical checks |
| Duplicate content | Same info in SKILL.md and references | Choose one location; reference from the other |
| Vague resource references | Claude doesn't load the file | Say exactly when and why to load each reference |

---

## Severity Classification for Gaps

Use this when generating a gap report:

**Critical** — will break skill functionality or cause upload failure

- Wrong `SKILL.md` filename or case
- Invalid YAML frontmatter (missing delimiters, unclosed quotes)
- Name field with spaces or capitals
- Description contains XML angle brackets

**Should-fix** — degrades skill quality significantly

- Description missing trigger phrases (will under-trigger)
- Description too broad (will over-trigger)
- No error handling documented
- SKILL.md over 500 lines without references/
- Instructions not actionable

**Nice-to-have** — quality improvements

- No examples section
- Reference files lack table of contents (when >100 lines)
- Missing negative triggers on narrow skills
- No `compatibility` field when environment matters
