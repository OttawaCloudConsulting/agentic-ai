---
name: occ-skill-creator
description: >-
  Guide for creating effective skills. Use when building a new Claude skill,
  packaging a domain workflow as a reusable skill bundle, or formalizing a
  repeated procedure. Covers the full lifecycle: creation, structured review,
  and iteration. Invoke explicitly with /occ-skill-creator.
disable-model-invocation: true
license: Apache-2.0
---

# Skill Creator

Create skills -- modular packages that extend Claude with specialized knowledge, workflows, and tools.

## Critical Constraints

- Keep SKILL.md under 500 lines. Move overflow to `references/`.
- No auxiliary files (README.md, CHANGELOG.md, LICENSE.txt, INSTALLATION_GUIDE.md). Only files an AI agent needs to do the job.
- Information lives in either SKILL.md or references -- not both.

## Core Principles

### Concise is Key

The context window is a public good. Claude is already very smart -- only add context Claude doesn't already have. Challenge each line: "Does this justify its token cost?"

Prefer concise examples over verbose explanations.

### Degrees of Freedom

Match specificity to the task's fragility:

- **High freedom** (text instructions): Multiple valid approaches, context-dependent decisions
- **Medium freedom** (pseudocode/parameterized scripts): Preferred pattern exists, some variation acceptable
- **Low freedom** (specific scripts, few parameters): Fragile operations, consistency critical, exact sequence required

### Progressive Disclosure

Skills load in three tiers to manage context efficiently:

1. **Metadata** (name + description) -- always in context (~100 words)
2. **SKILL.md body** -- loaded when skill triggers (<500 lines)
3. **Bundled resources** -- loaded as needed by Claude

Split content into reference files when approaching the 500-line limit. Always reference split-out files from SKILL.md with clear guidance on when to read them.

## Skill Structure

```text
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
- `description`: Primary triggering mechanism. Include both what the skill does AND specific scenarios/triggers. All "when to use" information goes here -- the body only loads after triggering.

**Body** (Markdown): Instructions and guidance for using the skill and its resources.

### scripts/

Executable code (Python/Bash/etc.) for tasks that are repeatedly rewritten or need deterministic reliability. Scripts can be executed without loading into context.

### references/

Documentation loaded into context as needed. Keeps SKILL.md lean.

Best practice: if reference files are large (>10k words), include grep search patterns in SKILL.md.

### assets/

Files used in output, not loaded into context. Templates, images, icons, boilerplate code, fonts.

## Reference Organization Patterns

**Pattern 1: High-level guide with references**

```markdown
## Advanced features

- **Form filling**: See references/forms.md for complete guide
- **API reference**: See references/api.md for all methods
```

Claude loads reference files only when needed.

Split by domain (`finance.md`, `sales.md`) or variant (`aws.md`, `gcp.md`) when sub-topics are independent and a user request will only ever need one.

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

- **Repeated code** -- `scripts/` (e.g., `scripts/rotate_pdf.py`)
- **Repeated discovery** -- `references/` (e.g., `references/schema.md`)
- **Repeated boilerplate** -- `assets/` (e.g., `assets/hello-world/`)

### 3. Build the Skill

1. Create the skill directory structure
2. Implement scripts, references, and assets identified in step 2

> **Before writing SKILL.md:** Test every script by running it. Do not document broken scripts. A script that fails during testing must be fixed before proceeding.

3. Write SKILL.md:
   - Frontmatter with clear `name` and `description` — for description field quality criteria, see `references/anthropic-best-practices.md` Frontmatter Requirements and Trigger Quality Checklist sections
   - Body with workflow guidance and references to bundled resources
   - Use imperative/infinitive form throughout
   - Verify SKILL.md stays under 500 lines; move overflow to `references/`
4. Delete any unused directories

Consult these guides based on the skill type:

- **Output formats or quality standards**: See references/output-patterns.md
- **Anthropic naming/structure conventions**: See references/anthropic-best-practices.md
- **Workflow patterns**: See "Workflow Patterns" section below

### 4. Refactor Review

Run a structured review before finalizing. See `references/refactor-protocol.md` for the full protocol including sub-agent prompt templates, output formats, and approval gates.

In short: launch parallel critique and red-team agents, compile feedback, get user approval, then apply approved changes. If the user declines, log the decision in `decisions.md` and proceed to Step 5 without changes.

### 5. Iterate

Use the skill on real tasks, notice struggles, update SKILL.md and resources, repeat.

## Workflow Patterns

### Sequential Workflows

For complex tasks, break operations into clear, sequential steps. Give Claude an overview early in SKILL.md:

```markdown
Filling a PDF form involves these steps:

1. Analyze the form (run analyze_form.py)
2. Create field mapping (edit fields.json)
3. Validate mapping (run validate_fields.py)
4. Fill the form (run fill_form.py)
5. Verify output (run verify_output.py)
```

### Conditional Workflows

For tasks with branching logic, guide Claude through decision points:

```markdown
1. Determine the modification type:
   **Creating new content?** -- Follow "Creation workflow" below
   **Editing existing content?** -- Follow "Editing workflow" below

2. Creation workflow: [steps]
3. Editing workflow: [steps]
```

## Troubleshooting

| Problem | Response |
|---|---|
| User gives vague requirements | Ask clarifying questions in step 1 before proceeding. Do not guess. |
| Script fails during testing | Fix the script before writing SKILL.md. Do not document broken scripts. |
| Generated SKILL.md exceeds 500 lines | Move detailed content to `references/`. Keep only workflow and navigation in SKILL.md. |
| Refactor agents produce conflicting feedback | Prioritize critical items from both. Present conflicts to user for resolution. |
| Unclear which reference pattern fits | Default to Pattern 1 (high-level guide with references). Split by domain or variant only when the skill has distinct, independent sub-topics. |

## Example

User says: "Create a skill for rotating PDF pages."

Result:

```text
pdf-rotator/
├── SKILL.md
└── scripts/
    └── rotate.py
```

**SKILL.md** (complete):

```markdown
---
name: pdf-rotator
description: >-
  Rotate pages in PDF files. Use when users say "rotate PDF", "turn PDF pages",
  "fix PDF orientation", or need to change page rotation in a PDF document.
---

# PDF Rotator

Rotate one or more pages in a PDF file.

## Critical Constraints

- Input file must be a valid PDF. Encrypted PDFs are not supported.
- Rotation values must be multiples of 90 (0, 90, 180, 270).

## Usage

1. Confirm the input file path and target pages with the user.
2. Confirm the rotation angle (90, 180, or 270 degrees).
3. Run: `python scripts/rotate.py --input <file> --pages <range> --degrees <angle>`
4. Verify output by opening the result file.

## Troubleshooting

| Problem | Response |
|---|---|
| Script errors "not a valid PDF" | Confirm file is not encrypted or corrupted. |
| Wrong pages rotated | Re-confirm page range with user (1-indexed). |
```
