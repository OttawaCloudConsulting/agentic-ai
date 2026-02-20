# Skill Creator

**Source:** `skills/skill-creator/`
**Command:** `/skill-creator`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "create a new skill", "update an existing skill", "build a skill")

## Description

Guide for creating and updating skills — modular packages that extend Claude with specialized knowledge, workflows, and tools. This meta-skill encodes the design principles, structural conventions, and workflow patterns needed to produce high-quality skills. It transforms the process of skill creation from ad-hoc authoring into a structured methodology with clear quality gates.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with core principles, structural conventions, creation workflow, and resource organization patterns |
| `references/workflows.md` | Patterns for sequential and conditional workflows within skills |
| `references/output-patterns.md` | Patterns for template-based and example-based output quality in skills |
| `LICENSE.txt` | Apache License 2.0 |

## Usage

```
/skill-creator
```

Invoke when you want to create a new skill or improve an existing one. The skill guides the design process from use case analysis through implementation and iteration.

## Workflow

### 1. Understand the Use Cases

Clarify concrete examples of how the skill will be used:

- What functionality should it support?
- What would a user say to trigger it?
- What are the common workflows?

Skip only when usage patterns are already clearly understood.

### 2. Plan Resources

For each use case, identify what reusable resources help:

- **Repeated code** leads to `scripts/` (e.g., `scripts/rotate_pdf.py`)
- **Repeated discovery** leads to `references/` (e.g., `references/schema.md`)
- **Repeated boilerplate** leads to `assets/` (e.g., `assets/hello-world/`)

### 3. Build the Skill

1. Create the skill directory structure
2. Implement scripts, references, and assets identified in step 2
3. Test scripts by running them
4. Write SKILL.md:
   - Frontmatter with clear `name` and `description`
   - Body with workflow guidance and references to bundled resources
   - Use imperative/infinitive form throughout
5. Delete any unused directories

### 4. Iterate

Use the skill on real tasks, notice struggles, update SKILL.md and resources, repeat.

## Core Design Principles

### Concise is Key

The context window is a public good. Claude is already very smart — only add context Claude does not already have. Challenge each line: "Does this justify its token cost?" Prefer concise examples over verbose explanations.

### Degrees of Freedom

Match specificity to the task's fragility:

| Level | Format | When to Use |
|---|---|---|
| High freedom | Text instructions | Multiple valid approaches, context-dependent decisions |
| Medium freedom | Pseudocode / parameterized scripts | Preferred pattern exists, some variation acceptable |
| Low freedom | Specific scripts, few parameters | Fragile operations, consistency critical, exact sequence required |

### Progressive Disclosure

Skills load in three tiers to manage context efficiently:

1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — loaded when skill triggers (<500 lines)
3. **Bundled resources** — loaded as needed by Claude

Keep SKILL.md under 500 lines. Split content into reference files when approaching this limit. Always reference split-out files from SKILL.md with clear guidance on when to read them.

## Skill Structure Reference

```
skill-name/
├── SKILL.md              (required)
├── scripts/              (optional) Executable code for deterministic tasks
├── references/           (optional) Documentation loaded into context as needed
└── assets/               (optional) Files used in output (templates, images, fonts)
```

### SKILL.md Requirements

**Frontmatter (YAML, required):**

```yaml
---
name: skill-name
description: What the skill does and when to use it. Include trigger phrases.
---
```

- `name`: kebab-case, max 64 characters
- `description`: Primary triggering mechanism. Include both what the skill does AND specific scenarios/triggers. All "when to use" information goes here — the body only loads after triggering.

**Body (Markdown):** Instructions and guidance for using the skill and its resources.

### scripts/

Executable code (Python/Bash/etc.) for tasks that are repeatedly rewritten or need deterministic reliability. Scripts can be executed without loading into context.

### references/

Documentation loaded into context as needed. Keeps SKILL.md lean. Information should live in either SKILL.md or references, not both. Best practice: if reference files are large (>10k words), include grep search patterns in SKILL.md.

### assets/

Files used in output, not loaded into context. Templates, images, icons, boilerplate code, fonts.

### What Not to Include

No auxiliary documentation (README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, etc.). The skill contains only what an AI agent needs to do the job.

## Reference Organization Patterns

### Pattern 1: High-level Guide with References

```markdown
## Advanced features
- **Form filling**: See references/forms.md for complete guide
- **API reference**: See references/api.md for all methods
```

Claude loads reference files only when needed.

### Pattern 2: Domain-specific Organization

```
skill-name/
├── SKILL.md (overview and navigation)
└── references/
    ├── finance.md
    ├── sales.md
    └── product.md
```

User asks about sales metrics, so Claude only reads `sales.md`.

### Pattern 3: Variant-specific Organization

```
cloud-deploy/
├── SKILL.md (workflow + provider selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

User chooses AWS, so Claude only reads `aws.md`.

**Guidelines:**

- Keep references one level deep from SKILL.md
- For files >100 lines, include a table of contents at the top

## Output Quality Patterns

From `references/output-patterns.md`:

### Template Pattern

Provide templates for output format. Use strict templates for API responses and data formats. Use flexible templates when adaptation is useful. Include explicit markers like "ALWAYS use this exact template structure" for strict requirements.

### Examples Pattern

For skills where output quality depends on seeing examples, provide input/output pairs. Examples help Claude understand the desired style and level of detail more clearly than descriptions alone.

## Workflow Patterns

From `references/workflows.md`:

### Sequential Workflows

For complex tasks, break operations into clear, sequential steps. Provide an overview of the process towards the beginning of SKILL.md.

### Conditional Workflows

For tasks with branching logic, guide Claude through decision points with explicit "Creating new content?" vs "Editing existing content?" branches.

## When to Use

- When creating a new skill from scratch
- When refactoring or improving an existing skill
- When you need guidance on skill structure, naming, or organization
- When deciding how to split content between SKILL.md and reference files
- When designing progressive disclosure for a complex skill

## When Not to Use

- When you already have a well-defined skill and just need to run it
- When the task is better served by a simple command (no scripts, no references needed)
- When creating Kiro powers — use the Kiro-specific conventions in `kiro/docs/POWERS.md`

## Related Skills and Commands

- **cdk-testing** — example of a skill with scripts and a commit workflow reference
- **terraform-testing** — example of a skill with a configurable script and commit workflow reference
- **compliance-assess** — example of a skill with multiple reference files and phased workflow
