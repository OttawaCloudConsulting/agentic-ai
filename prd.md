# PRD: Command-to-Skill Conversions

## Summary

Convert three single-file commands into full skill bundles (SKILL.md + scripts + references) in the `skills/` directory. This reduces context window bloat, separates reference data from workflow instructions, and aligns with the skill-creator pattern established in this repo.

## Goals

- Move large or artifact-bearing commands out of `commands/` into `skills/` as proper skill bundles
- Separate reference data (control tables, output templates) from procedural workflow instructions
- Eliminate duplication between `commands/test-terraform.md` and `skills/terraform-testing/`
- Bundle shell scripts with their skills rather than referencing external paths

## Non-Goals

- Converting small, self-contained commands (catchup, handoff, investigate, start-feature, update-docs-*) — these stay as commands
- Updating docs/SKILLS.md, docs/RULES.md, or CLAUDE.md — separate effort
- Modifying the compliance-auto-assess dispatcher — it stays as a command
- Modifying the Kiro equivalents in `kiro/`

## Features

### Feature 1: Convert compliance-assess to skill

Convert `commands/compliance-assess.md` (488 lines) into `skills/compliance-assess/`.

**Current state:** Single 488-line command file with inline ITSG-33 control tables (73 lines), phase output templates (~80 lines), and official reference links — all mixed in with the workflow instructions.

**Target structure:**
```
skills/compliance-assess/
├── SKILL.md                          (~150 lines: workflow, phases, rules)
└── references/
    ├── itsg33-controls.md            (8 control family tables from Phase 2)
    ├── phase-templates.md            (output format templates for phases 1-3)
    └── official-references.md        (CCCS/ITSG-33/NIST/AWS links)
```

**Acceptance criteria:**
- SKILL.md body under 200 lines
- All 43 controls preserved exactly in references/itsg33-controls.md
- Phase output templates extracted to references/phase-templates.md
- Official reference URLs extracted to references/official-references.md
- SKILL.md references each file with clear guidance on when to read it
- Frontmatter description includes trigger phrases for compliance assessment
- Delete `commands/compliance-assess.md` after conversion
- The compliance-auto-assess dispatcher (stays as command) must be updated to reference the new skill location if needed

### Feature 2: Merge test-terraform command into terraform-testing skill

Merge `commands/test-terraform.md` (171 lines) into the existing `skills/terraform-testing/` skill.

**Current state:** Two sources of truth — `commands/test-terraform.md` has Gate 3 commit workflow and output format that `skills/terraform-testing/SKILL.md` lacks. The skill has script documentation and configuration the command lacks. They overlap on pipeline steps and failure handling.

**Target structure:**
```
skills/terraform-testing/
├── SKILL.md                          (merged: workflow + script docs + commit workflow)
├── scripts/
│   └── test-terraform.sh             (existing, unchanged)
└── references/
    └── commit-workflow.md            (Gate 3 commit + feature doc + staging rules)
```

**Acceptance criteria:**
- Single SKILL.md combining the best of both sources
- Gate 3 commit workflow moved to references/commit-workflow.md (referenced from SKILL.md)
- Pipeline steps, configuration, failure handling — no information lost
- Delete `commands/test-terraform.md` after merge
- SKILL.md body under 200 lines (commit workflow in references)

### Feature 3: Create cdk-testing skill

Create `skills/cdk-testing/` from `commands/test-cdk.md` (159 lines), modeled on `skills/terraform-testing/`.

**Current state:** Single command file that references `scripts/cdk-validation.sh` by external path. Reference script exists at `working/cdk-validation.sh`.

**Target structure:**
```
skills/cdk-testing/
├── SKILL.md                          (workflow + script docs)
├── scripts/
│   └── cdk-validation.sh            (new, based on working/cdk-validation.sh)
└── references/
    └── commit-workflow.md            (Gate 3 commit + feature doc + staging rules)
```

**Acceptance criteria:**
- SKILL.md modeled on terraform-testing SKILL.md pattern
- `scripts/cdk-validation.sh` created based on `working/cdk-validation.sh` reference, adapted to be portable (OS detection, missing tool installation)
- Gate 3 commit workflow in references/commit-workflow.md (duplicated from Feature 2, adapted for CDK paths)
- Frontmatter description includes trigger phrases for CDK testing
- Delete `commands/test-cdk.md` after conversion
- SKILL.md body under 200 lines

## Architecture

### Conversion Pattern

Each conversion follows the same pattern:

1. Extract reference data (tables, templates, links) into `references/*.md`
2. Write a lean SKILL.md (~150-200 lines) with workflow instructions
3. Bundle any scripts in `scripts/`
4. Add YAML frontmatter with descriptive trigger phrases
5. Delete the original `commands/*.md` file

### Skill Anatomy (from skill-creator)

```
skill-name/
├── SKILL.md              (required: frontmatter + workflow)
├── scripts/              (optional: executable code)
└── references/           (optional: loaded into context as needed)
```

### Dependencies

- Feature 1 (compliance-assess) is independent
- Feature 2 (terraform-testing merge) is independent
- Feature 3 (cdk-testing) is independent but should be done after Feature 2 to use it as a pattern reference
