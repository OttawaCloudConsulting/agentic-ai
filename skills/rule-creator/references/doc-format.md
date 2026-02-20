# Documentation Format for Rules

Template for generating documentation in `docs/rules/`. Each rule in `rules/` has a corresponding doc in `docs/rules/` that summarizes the rule for human consumption.

## Structure

```markdown
# <Rule Title>

**Source:** `rules/<filename>.md`
**Scope:** <What projects/technologies this applies to>
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

<One-sentence bold thesis from the rule, or a summary of its purpose.>

## Overview

<1-3 sentence paragraph explaining what the rule covers, its scope, and why it exists. This is a summary, not a copy of the rule.>

## Sections

### <Section Name>

<Summarize the section in 2-5 bullet points or a short paragraph. Do not duplicate the full content — summarize the key guidelines and rationale.>

### <Section Name>

<Continue for each H2 section in the source rule.>

## Bad Practices

| Practice | Why It's Dangerous |
|---|---|
| <Copy the bad practices table from the rule verbatim> |

## Related Rules

- `rules/<related-rule>.md` — <One-sentence explanation of the relationship.>
```

## Key Differences from Rule Files

| Aspect | Rule (`rules/`) | Doc (`docs/rules/`) |
|---|---|---|
| Style | Imperative, terse | Descriptive, summarized |
| Code examples | Included inline | Omitted or minimal |
| Bad Practices table | Full table | Copied verbatim |
| Audience | AI agent (always loaded) | Human reader (reference) |
| Purpose | Shape behavior | Explain behavior |

## Guidelines

- **Summarize, don't duplicate.** The doc explains what the rule does. Readers who want the full content read the rule file itself.
- **Preserve section names.** Use the same H2/H3 names as the source rule so readers can cross-reference.
- **Bad Practices table is verbatim.** This is the one section copied exactly — it serves as a quick-reference checklist for humans.
- **Related Rules section is required.** List rules that overlap, complement, or depend on this one. Every rule relates to at least the defensive protocol family.
- **No code examples in docs.** Docs summarize; rules demonstrate. Exception: if a code pattern is central to understanding (e.g., a structured template), include it.

## Metadata Header

The three metadata lines are always present:

```markdown
**Source:** `rules/<filename>.md`
**Scope:** <scope description>
**Activation:** Automatic — loaded when placed in `.claude/rules/`
```

- **Source**: Always references the rule file path relative to repo root
- **Scope**: Describes what projects benefit (e.g., "All project types", "AWS CDK projects", "Kubernetes workloads")
- **Activation**: Always the same line — rules are always automatic

## Section Summary Style

For infrastructure rules, summarize each section as bullet points with bold lead:

```markdown
### Security

- **Use grant methods for IAM.** Creates least-privilege policies automatically.
- **Let CDK manage roles.** Auto-created roles are scoped minimally.
- **Never hardcode secrets.** Use Secrets Manager or SSM SecureString.
```

For behavioral rules, summarize each section as a short paragraph:

```markdown
### Failure Response

A strict three-step protocol when anything fails: stop (no retry), report (exact error with theory and proposal), wait (get user confirmation). Uses a structured template format. The core insight: failure is signal, and silent retry destroys signal.
```
