---
name: skill-creator
description: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Claude's capabilities with specialized knowledge, workflows, or tool integrations.
---

# Skill Creator

Create skills — modular packages that extend Claude with specialized knowledge, workflows, and tools. Skills transform Claude from a general-purpose agent into a domain specialist equipped with procedural knowledge no model fully possesses.

## Core Principles

### Concise is Key

The context window is a public good. Claude is already very smart — only add context Claude doesn't already have. Challenge each line: "Does this justify its token cost?"

Prefer concise examples over verbose explanations.

### Degrees of Freedom

Match specificity to the task's fragility:

- **High freedom** (text instructions): Multiple valid approaches, context-dependent decisions
- **Medium freedom** (pseudocode/parameterized scripts): Preferred pattern exists, some variation acceptable
- **Low freedom** (specific scripts, few parameters): Fragile operations, consistency critical, exact sequence required

### Progressive Disclosure

Skills load in three tiers to manage context efficiently:

1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — loaded when skill triggers (<500 lines)
3. **Bundled resources** — loaded as needed by Claude

Keep SKILL.md under 500 lines. Split content into reference files when approaching this limit. Always reference split-out files from SKILL.md with clear guidance on when to read them.

## Skill Structure

```
skill-name/
├── SKILL.md              (required)
├── scripts/              (optional) Executable code for deterministic tasks
├── references/           (optional) Documentation loaded into context as needed
└── assets/               (optional) Files used in output (templates, images, fonts)
```

### SKILL.md

**Frontmatter** (YAML, required):

```yaml
---
name: skill-name
description: What the skill does and when to use it. Include trigger phrases.
---
```

- `name`: kebab-case, max 64 characters
- `description`: Primary triggering mechanism. Include both what the skill does AND specific scenarios/triggers. All "when to use" information goes here — the body only loads after triggering.

**Body** (Markdown): Instructions and guidance for using the skill and its resources.

### scripts/

Executable code (Python/Bash/etc.) for tasks that are repeatedly rewritten or need deterministic reliability. Scripts can be executed without loading into context.

### references/

Documentation loaded into context as needed. Keeps SKILL.md lean. Information should live in either SKILL.md or references, not both.

Best practice: if reference files are large (>10k words), include grep search patterns in SKILL.md.

### assets/

Files used in output, not loaded into context. Templates, images, icons, boilerplate code, fonts.

### What Not to Include

No auxiliary documentation (README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, etc.). The skill contains only what an AI agent needs to do the job.

## Reference Organization Patterns

**Pattern 1: High-level guide with references**

```markdown
## Advanced features
- **Form filling**: See references/forms.md for complete guide
- **API reference**: See references/api.md for all methods
```

Claude loads reference files only when needed.

**Pattern 2: Domain-specific organization**

```
skill-name/
├── SKILL.md (overview and navigation)
└── references/
    ├── finance.md
    ├── sales.md
    └── product.md
```

User asks about sales metrics → Claude only reads `sales.md`.

**Pattern 3: Variant-specific organization**

```
cloud-deploy/
├── SKILL.md (workflow + provider selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

User chooses AWS → Claude only reads `aws.md`.

Guidelines:

- Keep references one level deep from SKILL.md
- For files >100 lines, include a table of contents at the top

## Creating a Skill

### 1. Understand the Use Cases

Clarify concrete examples of how the skill will be used:

- What functionality should it support?
- What would a user say to trigger it?
- What are the common workflows?

Skip only when usage patterns are already clearly understood.

### 2. Plan Resources

For each use case, identify what reusable resources help:

- **Repeated code** → `scripts/` (e.g., `scripts/rotate_pdf.py`)
- **Repeated discovery** → `references/` (e.g., `references/schema.md`)
- **Repeated boilerplate** → `assets/` (e.g., `assets/hello-world/`)

### 3. Build the Skill

1. Create the skill directory structure
2. Implement scripts, references, and assets identified in step 2
3. Test scripts by running them
4. Write SKILL.md:
   - Frontmatter with clear `name` and `description`
   - Body with workflow guidance and references to bundled resources
   - Use imperative/infinitive form throughout
5. Delete any unused directories

Consult these guides for design patterns:

- **Multi-step processes**: See references/workflows.md
- **Output formats/quality standards**: See references/output-patterns.md

### 4. Iterate

Use the skill on real tasks, notice struggles, update SKILL.md and resources, repeat.
