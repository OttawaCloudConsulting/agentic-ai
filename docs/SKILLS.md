# Skills Reference

Skills are slash commands that provide structured workflows for common tasks. They are defined as markdown files in `.claude/commands/` and invoked with `/<skill-name>` in the Claude Code CLI.

## Quick Reference

| Skill | Command | Purpose |
|---|---|---|
| Create PRD | `/create-prd` | Guided interview to create PRD, architecture doc, and progress file |
| Start Feature | `/start-feature` | Begin the next feature from progress.txt |
| Test Terraform | `/test-terraform` | Validate, plan, apply, and commit a Terraform feature |
| Test CDK | `/test-cdk` | Validate, deploy, and commit a CDK feature |
| Compliance Assess | `/compliance-assess` | Interactive ITSG-33 compliance assessment with user checkpoints |
| Compliance Auto-Assess | `/compliance-auto-assess` | Automated ITSG-33 compliance assessment (runs as sub-agent) |
| Update Docs (Terraform) | `/update-docs-terraform` | Refresh README and architecture docs for Terraform projects |
| Update Docs | `/update-docs` | Refresh README, architecture, and testing docs |
| Investigate | `/investigate` | Structured debugging investigation |
| Catchup | `/catchup` | Read session state at start of a new session |
| Handoff | `/handoff` | Save session state before ending |

### Rules (Always-On)

Rules are behavioral guidelines loaded automatically via `.claude/rules/`. They are not commands and cannot be invoked.

| Rule | Purpose |
|---|---|
| Defensive Protocol | Defensive epistemology for agentic coding: failure handling, prediction protocols, evidence standards, autonomy boundaries. |

---

## Project Lifecycle

Skills follow a development lifecycle. Use them in this order for new projects:

```
/create-prd          Create project requirements, architecture, progress file
    |
/start-feature       Pick up the next feature from progress.txt
    |
  (implement)        Write the code
    |
/test-terraform      Validate, plan, apply, commit  (or /test-cdk for CDK projects)
    |
  (repeat)           /start-feature -> implement -> /test-*
    |
/update-docs-terraform   Refresh docs after features accumulate
```

### Session Management

```
/catchup             Start of session: read last handoff + progress.txt
  (work)
/handoff             End of session: save state before closing
```

---

## Skill Details

### `/create-prd`

Guided interview to set up a new project. Asks structured questions across multiple rounds, then produces:

- `prd.md` — Product requirements document
- `docs/ARCHITECTURE_AND_DESIGN.md` — Architecture and design decisions
- `progress.txt` — Feature tracking file

**Usage:**
```
/create-prd
```

### `/start-feature`

Reads `progress.txt` to find the next pending `[ ]` feature, marks it `[~]` (in-progress), reads `prd.md` for requirements, and reports what needs to be built.

**Usage:**
```
/start-feature
```

### `/test-terraform`

Runs all validation gates for a completed Terraform feature:

1. **Gate 1 — Validation:** `terraform fmt -check`, `terraform init`, `terraform validate`, `tflint`, `tfsec`/`checkov`
2. **Gate 2 — Plan & Apply:** `terraform plan -out=tfplan`, review diff, `terraform apply tfplan`
3. **Gate 3 — Commit:** Update progress.txt, CHANGELOG.md, create feature docs, git commit

Only invoke after finishing implementation. Does not mark a feature complete if any gate fails.

**Usage:**
```
/test-terraform
```

### `/test-cdk`

CDK equivalent of `/test-terraform`. Runs validation script, CDK deploy, and commit gates.

**Usage:**
```
/test-cdk
```

### `/compliance-assess`

Interactive ITSG-33 / CCCS Medium Cloud Profile compliance assessment. Runs in the main conversation with mandatory user checkpoints between phases:

- **Phase 0:** Framework validation (self-correcting control data)
- **Phase 1:** Architecture discovery → user checkpoint
- **Phase 2:** Control mapping (43 controls, 8 families) → user checkpoint
- **Phase 3:** Gap analysis with risk-rated remediation → final report

Produces output files in `docs/compliance/`:
- `phase1-discovery.md`
- `phase2-control-mapping.md`
- `phase3-gap-analysis.md`
- `assessment-summary.md`

**Usage:**
```
/compliance-assess
/compliance-assess @path/to/project/
```

**When to use:** When you want to review and provide input between phases (e.g., adding context about org-level controls, correcting architecture assumptions).

### `/compliance-auto-assess`

Automated, non-interactive version of `/compliance-assess`. Dispatches the assessment as a **sub-agent** via the Task tool. Runs all phases (0 through 3) end-to-end without user checkpoints.

**Usage:**
```
/compliance-auto-assess
/compliance-auto-assess @path/to/project/
```

**When to use:** When you want the assessment to run autonomously without consuming main conversation context. Results are written to the same `docs/compliance/` output files.

**How it works:**

This skill uses a **dispatcher pattern** — the skill file (`.claude/commands/compliance-auto-assess.md`) is a short 44-line dispatcher that:

1. Resolves the target directory from command arguments
2. Reads the full assessment instructions from a separate file
3. Passes the instructions to a sub-agent via the Task tool
4. Returns the sub-agent's results (executive summary + output file paths)

The full assessment instructions live in a separate file:

```
.claude/
  compliance-auto-assess-instructions.md   <-- 470-line assessment instructions (not a skill)
  commands/
    compliance-auto-assess.md              <-- 44-line dispatcher (the skill)
```

The instructions file is intentionally placed in `.claude/` (not `.claude/commands/`) because any `.md` file in `commands/` gets registered as a skill. The instructions file is a payload for the sub-agent, not a user-invocable skill.

**Modifying the assessment:** To change control tables, output templates, or assessment rules, edit `.claude/compliance-auto-assess-instructions.md` — not the dispatcher skill.

### `/update-docs-terraform`

Refreshes `README.md` and `docs/ARCHITECTURE_AND_DESIGN.md` to match the current state of a Terraform codebase. Run after features accumulate and docs fall behind.

**Usage:**
```
/update-docs-terraform
```

### `/update-docs`

General-purpose documentation refresh for any project type. Updates README.md, docs/ARCHITECTURE.md, and docs/TESTING.md.

**Usage:**
```
/update-docs
```

### `/investigate`

Creates a structured investigation file in `agents/investigations/` for debugging unknown issues. Tracks:

- Known facts
- Theories and hypotheses
- Tests performed and results
- Resolution

**Usage:**
```
/investigate
/investigate <description of the issue>
```

### `/catchup`

Start-of-session skill. Reads `agents/memory/handoff.md` (written by `/handoff`) and `progress.txt` to orient on project state. Reports current feature status, blockers, and next steps.

**Usage:**
```
/catchup
```

### `/handoff`

End-of-session skill. Writes current state to `agents/memory/handoff.md` including:

- Current feature and its status
- Decisions made during the session
- Blockers or open questions
- Recommended next steps

Run this before `/clear` or closing the terminal.

**Usage:**
```
/handoff
```

---

## File Structure

```
.claude/
  commands/                                  Skills directory (all .md files here become skills)
    compliance-assess.md                     Interactive compliance assessment
    compliance-auto-assess.md                Automated compliance assessment (dispatcher)
    catchup.md                               Session start
    create-prd.md                            Project setup
    handoff.md                               Session end
    investigate.md                           Structured debugging
    start-feature.md                         Feature workflow
    test-cdk.md                              CDK validation + commit
    test-terraform.md                        Terraform validation + commit
    update-docs.md                           General doc refresh
    update-docs-cdk.md                       CDK doc refresh
    update-docs-terraform.md                 Terraform doc refresh
  rules/                                     Always-on behavioral guidelines
    defensive-protocol.md                    Defensive coding protocol
  compliance-auto-assess-instructions.md     Assessment payload for sub-agent (not a skill)
```

### Frontmatter Options

Skills support these frontmatter fields:

```yaml
---
name: skill-name                    # Required. The /command name.
description: What the skill does    # Required. Shown in /skills list.
disable-model-invocation: true      # Optional. Prevents the model from auto-invoking the skill.
---
```

**Note:** Rules (in `.claude/rules/`) do not use YAML frontmatter. They are pure content files.
