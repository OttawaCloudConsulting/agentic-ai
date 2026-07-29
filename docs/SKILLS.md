# Skills Reference

Skills are portable bundles that provide structured workflows with supporting assets (scripts, references, templates). Each skill is a directory containing a `SKILL.md` definition plus supporting files. Most skills in this index are invoked with `/<skill-name>` in the Claude Code CLI. Codex-specific skill suites are listed separately in the same table and use their documented `$skill` explicit invocation names.

For single-file commands (no supporting assets), see [COMMANDS.md](COMMANDS.md).

## Quick Reference

| Skill | Command | Purpose | Details |
|---|---|---|---|
| CDK Testing | `/cdk-testing` | Validate, scan, build, test, and deploy CDK code | [View](skills/cdk-testing.md) |
| Terraform Testing | `/terraform-testing` | Validate, scan, plan, and deploy Terraform code | [View](skills/terraform-testing.md) |
| ITSG Assessment | `/itsg-assessment` | ITSG-33 / CCCS Medium compliance assessment for Canadian GC cloud workloads handling Protected B data, with user checkpoints | [View](skills/itsg-assessment.md) |
| NIST FedRAMP Assessment | `/nist-fedramp-assessment` | NIST SP 800-53 Rev 5 / FedRAMP Moderate compliance assessment for US cloud workloads with dual inheritance model and FedRAMP ATO readiness | [View](skills/nist-fedramp-assessment.md) |
| NIST CSF Assessment | `/nist-csf-assessment` | NIST CSF 2.0 outcome-based assessment across all 6 Functions with platform-agnostic evidence mapping, 800-53 informative references, and self-updating Phase 0 that always validates against the latest published CSF version | [View](skills/nist-csf-assessment.md) |
| Create PRD | `/create-prd` | Guided interview to produce a PRD, architecture document, and progress file for a new project | [View](skills/create-prd.md) |
| Define | `/define` | Single-session codebase assessment, optional Working Backwards, and PRD creation (Gates 0/WB/1) | [View](skills/define.md) |
| Design | `/design` | Architecture and design specification from approved PRD, with refresh mode for deviation consolidation (Gate 2) | [View](skills/design.md) |
| Milestone | `/milestone` | Per-milestone feature breakdown with acceptance criteria and revision support (Gate 3) | [View](skills/milestone.md) |
| Plan Feature | `/plan-feature` | Per-feature implementation plan with sub-feature sizing and test commands (Gate 4) | [View](skills/plan-feature.md) |
| Build | `/build` | Sub-feature implementation from Gate 4-approved plans with test gating and deviation tracking | [View](skills/build.md) |
| Spike | `/spike` | Adversarial technical research with red-team validation and follow-up support | [View](skills/spike.md) |
| Red-Team | `/red-team` | Adversarial review of any artifact — spawns parallel sub-agents with different adversarial lenses | [View](skills/red-team.md) |
| OCC Skill Creator | `/occ-skill-creator` | Guide for creating new skills that extend Claude's capabilities | [View](skills/occ-skill-creator.md) |
| OCC Skill Refactor | `/occ-skill-refactor` | Reviews and refactors an existing skill against quality standards and best practices | [View](skills/occ-skill-refactor.md) |
| Project Codex Skills | `$project` | Codex project suite -- bootstraps state, reports status, routes to the next explicit `$project-*` skill | [View](skills/project.md) |
| Rule Creator | `/rule-creator` | Interactive rule generation with documentation and catalog updates | [View](skills/rule-creator.md) |
| Over-Engineering Review | `/over-engineering-review` | On-demand 3-clause discriminator pass over a diff/file/plan; classifies findings safe-remove / needs-decision / keep / harmful-theater; composes `/simplify` and `/code-review` | [View](skills/over-engineering-review.md) |

## How Skills Work

- Skills live in `skills/<name>/` at the repository root (drop-in source)
- Consumers copy the entire directory to `.claude/skills/<name>/` in their target project
- Each skill directory contains:
  - `SKILL.md` — the skill definition with YAML frontmatter (`name`, `description`)
  - `scripts/` — executable shell scripts (optional)
  - `references/` — supporting documentation loaded on-demand (optional)
- The `description` field in frontmatter includes trigger phrases so the model knows when to invoke the skill
- Skills are invoked manually via `/<skill-name>` or automatically when the model matches trigger phrases
- Set `disable-model-invocation: true` in frontmatter to prevent auto-triggering (use for interactive or destructive skills)

### Skill Bundle Structure

```
skills/<name>/
├── SKILL.md                  ← skill definition (YAML frontmatter required)
├── scripts/                  ← executable scripts (portable, auto-detect OS)
│   └── *.sh
└── references/               ← supporting docs (loaded by SKILL.md as needed)
    └── *.md
```

### Frontmatter

```yaml
---
name: skill-name                    # Required. The /command name.
description: What the skill does    # Required. Include trigger phrases.
disable-model-invocation: true      # Optional. Prevents auto-triggering.
compatibility: node>=18, npm, git   # Optional. Documents runtime requirements.
license: Apache-2.0                 # Optional. License identifier.
---
```

## Consuming Skills

Skills are copied, not installed — there is **no installer for skills**. (The only installers in this
repository are `scripts/agent-delegation/install.sh`, `scripts/defensive-protocol/install.sh`, and
`scripts/claude-toolkit/install.sh`; each installs its own rules/scripts/hooks and wires
`settings.json`. None of them copy skills.)

Copy the entire skill directory from `skills/` into `.claude/skills/` in the target repository:

```bash
# Standalone skills — one directory each
cp -r skills/architecture-doc/          <target-repo>/.claude/skills/architecture-doc/
cp -r skills/cdk-testing/               <target-repo>/.claude/skills/cdk-testing/
cp -r skills/terraform-testing/         <target-repo>/.claude/skills/terraform-testing/
cp -r skills/itsg-assessment/           <target-repo>/.claude/skills/itsg-assessment/
cp -r skills/nist-fedramp-assessment/   <target-repo>/.claude/skills/nist-fedramp-assessment/
cp -r skills/nist-csf-assessment/       <target-repo>/.claude/skills/nist-csf-assessment/
cp -r skills/create-prd/                <target-repo>/.claude/skills/create-prd/
cp -r skills/red-team/                  <target-repo>/.claude/skills/red-team/
cp -r skills/occ-skill-creator/         <target-repo>/.claude/skills/occ-skill-creator/
cp -r skills/occ-skill-refactor/        <target-repo>/.claude/skills/occ-skill-refactor/
cp -r skills/rule-creator/              <target-repo>/.claude/skills/rule-creator/
cp -r skills/over-engineering-review/   <target-repo>/.claude/skills/over-engineering-review/

# Gated project suite — the orchestrator plus its nested sub-skills.
# One copy takes the whole suite (build, define, design, milestone, plan-feature, spike):
cp -r skills/project/                   <target-repo>/.claude/skills/project/

# ...or cherry-pick sub-skills (skills/project/SKILL.md is required either way):
cp -r skills/project/build/             <target-repo>/.claude/skills/project/build/
cp -r skills/project/define/            <target-repo>/.claude/skills/project/define/
cp -r skills/project/design/            <target-repo>/.claude/skills/project/design/
cp -r skills/project/milestone/         <target-repo>/.claude/skills/project/milestone/
cp -r skills/project/plan-feature/      <target-repo>/.claude/skills/project/plan-feature/
cp -r skills/project/spike/             <target-repo>/.claude/skills/project/spike/
```

Skills take effect immediately on the next Claude Code conversation in that repository.

### Prerequisite: the Claude Toolkit scripts

`/build` and `/start-feature-auto` invoke helper scripts by path. Copying the skill alone leaves
those instructions pointing at files that do not exist:

| Consumer | Requires | Why |
|---|---|---|
| `skills/project/build/` (`/build`) | `.claude/scripts/gcommit` | Commit Command Protocol D-03 — every sub-feature and assessment-refresh commit is file-based |
| `commands/start-feature-auto.md` | `.claude/scripts/codex-review.sh` | Step 7 Codex review before the feature closes |

Install them first — this is the one install script involved in setting up the project suite, and it
installs **scripts and hooks only, never skills**:

```bash
bash scripts/claude-toolkit/install.sh <target-repo-path>
```

See [SCRIPTS.md](SCRIPTS.md#claude-toolkit) for what it writes to the target. Without it, `/build`
still runs but its commit step fails on a missing `gcommit`; `/start-feature-auto` records the review
as skipped rather than blocking.
