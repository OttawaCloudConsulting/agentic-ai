# Claude Code User Guide — Terraform

Guide for developers using Claude Code with this project. Covers setup, development workflow, available skills, session lifecycle, and what to expect.

## Setup

Copy files from the `agentic-ai` repo into your Terraform project repo.

### 1. Project rules

Copy to your repo root:

| Source (agentic-ai) | Destination (your repo) |
|---|---|
| `prompts/terraform-project/CLAUDE.md` | `CLAUDE.md` |
| `prompts/terraform-project/CLAUDE_CODE_USER_GUIDE.md` | `CLAUDE_CODE_USER_GUIDE.md` or `docs/` |

### 2. Commands

Copy to `.claude/commands/` in your repo. Create the directory if it doesn't exist.

**Terraform-specific commands:**

| Source (agentic-ai) | Destination (your repo) |
|---|---|
| `commands/test-terraform.md` | `.claude/commands/test-terraform.md` |
| `commands/update-docs-terraform.md` | `.claude/commands/update-docs-terraform.md` |

**Shared commands (required):**

| Source (agentic-ai) | Destination (your repo) |
|---|---|
| `commands/start-feature.md` | `.claude/commands/start-feature.md` |
| `commands/catchup.md` | `.claude/commands/catchup.md` |
| `commands/handoff.md` | `.claude/commands/handoff.md` |
| `commands/investigate.md` | `.claude/commands/investigate.md` |
| `commands/defensive-protocol.md` | `.claude/commands/defensive-protocol.md` |

### 3. Configure

After copying, edit `CLAUDE.md` in your repo:

- Replace all instances of `<PROFILE_NAME>` with your AWS CLI profile name
- Update the **Project Directories** section if your directory structure differs from the prescribed layout

### 4. Verify

Your repo should have this structure:

```text
your-terraform-repo/
├── CLAUDE.md                          ← project rules (edited with your profile)
├── .claude/
│   └── commands/
│       ├── test-terraform.md
│       ├── update-docs-terraform.md
│       ├── start-feature.md
│       ├── catchup.md
│       ├── handoff.md
│       ├── investigate.md
│       └── defensive-protocol.md
├── modules/                           ← reusable Terraform modules
├── envs/
│   └── dev/                           ← environment-specific root config
├── docs/                              ← project documentation
└── agents/                            ← Claude Code working memory
    ├── memory/
    └── investigations/
```

## Prerequisites

- [Claude Code CLI](https://code.claude.com) installed
- AWS CLI profile `<PROFILE_NAME>` configured
- Terraform CLI installed
- tflint installed (optional — validation will skip if missing)
- tfsec or checkov installed (optional — security scanning will skip if missing)
- Familiarity with the project: read `README.md` for architecture, `prd.md` for requirements

## How Skills Work

Skills are custom commands defined in `.claude/commands/`. They extend Claude's capabilities with project-specific workflows. You invoke them by typing `/skill-name` in the Claude Code session, or by asking Claude to run them (e.g., "run the tests and commit").

Some skills are invoked automatically by Claude when relevant (like the defensive coding protocol during debugging). Others are manual-only — you must explicitly invoke them.

### Available Skills

| Skill | Trigger | Description |
| --- | --- | --- |
| `/start-feature` | You or Claude | Begin the next feature from the roadmap |
| `/test-terraform` | You or Claude | Run validation gates, plan & apply, and commit |
| `/update-docs-terraform` | You only | Refresh README, ARCHITECTURE docs |
| `/catchup` | You or Claude | Read project state at the start of a session |
| `/handoff` | You only | Save session state before ending |
| `/investigate` | You or Claude | Structured debugging for unknowns |
| `defensive-protocol` | Claude (automatic) | Loaded when writing code, debugging, or investigating |

## Development Workflow

The project follows a strict **Feature > Test > Complete > Next Feature** cycle. Every feature is tracked in `progress.txt`.

### 1. Start a feature

```text
/start-feature
```

Claude reads `progress.txt`, identifies the next pending feature, reads `prd.md` for requirements, marks the feature as in-progress (`[~]`), and reports what needs to be built. It does **not** start implementation — it waits for your direction.

**What you see:**

```text
STARTING: Feature 2.3 — S3 backend module

REQUIREMENTS:
- S3 bucket with versioning
- DynamoDB table for state locking
- KMS encryption key

FILES LIKELY AFFECTED:
- modules/backend/main.tf (new)
- modules/backend/variables.tf (new)
- modules/backend/outputs.tf (new)
- envs/dev/backend.tf (modified)

Ready to begin implementation.
```

At this point, direct Claude on what to build. It follows `prd.md` for architecture decisions.

### 2. Implement in HCL

Work with Claude to build the feature. Claude writes Terraform configuration following the defensive coding protocol. You can review, ask questions, request changes. All variables must be strongly typed with validation blocks where applicable.

During implementation, Claude follows the defensive coding protocol automatically. If something fails, it stops and reports rather than silently retrying.

### 3. Complete the feature

```text
/test-terraform
```

This runs three sequential gates. Each must pass before the next starts:

**Gate 1 — Validation**
Runs: git-secrets scan, `terraform fmt -check`, `terraform init`, `terraform validate`, tflint, tfsec/checkov.

**Gate 2 — Plan & Apply**
Runs `terraform plan -out=tfplan`, reports the plan summary, then runs `terraform apply tfplan`.

**Gate 3 — Commit**
Updates `progress.txt` (`[~]` → `[x]`), writes `CHANGELOG.md` entry, creates `docs/FEATURE_X.Y.md`, stages files individually, and commits locally.

**What you see:**

```text
GATE 1 — Validation: PASS
  - git-secrets: passed
  - terraform fmt: passed
  - terraform init: passed
  - terraform validate: passed
  - tflint: passed
  - tfsec: passed

GATE 2 — Plan & Apply: PASS
  Plan: 5 to add, 0 to change, 0 to destroy
  Apply: completed successfully

GATE 3 — Commit: PASS (committed as feat: 2.3 — S3 backend module)

All gates passed. Feature 2.3 is complete.
```

If any gate fails, Claude stops immediately and reports the error. Fix the issue and run `/test-terraform` again.

### 4. Continue to next feature

After a successful `/test-terraform`, run `/compact` to free context, then `/start-feature` for the next one.

```text
/compact
/start-feature
```

### 5. Refresh documentation (periodic)

After several features have been completed, documentation (README, ARCHITECTURE) may have stale tables and diagrams.

```text
/update-docs-terraform
```

Claude reads the codebase — `variables.tf`, `locals.tf`, `modules/`, `terraform.tfvars`, `backend.tf` — and updates README.md and docs/ARCHITECTURE.md. Run this before creating a pull request.

## Session Lifecycle

### Starting a session

If continuing from a previous session, run:

```text
/catchup
```

Claude reads `agents/memory/handoff.md` (written by the last `/handoff`) and `progress.txt`, then reports current state, blockers, uncommitted changes, and next steps.

If this is a fresh start or there's no handoff file, Claude falls back to `progress.txt` only.

**What you see:**

```text
SESSION CATCHUP

Last handoff: 2026-01-29

CURRENT FEATURE:
  Feature 2.3 — S3 backend module
  Status: in progress
  Done: S3 bucket and DynamoDB table created
  Remaining: KMS key, outputs, validation blocks

BLOCKERS: None

UNCOMMITTED CHANGES: Working tree clean

RECENT COMMITS:
  abc1234 feat: 2.2 — VPC module
  def5678 feat: 2.1 — Provider configuration

NEXT STEPS:
  1. Add KMS encryption key resource
  2. Add output values for bucket ARN and table name

Ready to continue.
```

### Ending a session

Before closing the terminal or running `/clear`, save state:

```text
/handoff
```

Claude reads `progress.txt`, `git status`, and recent commits, then writes a structured summary to `agents/memory/handoff.md`. The next session can pick up with `/catchup`.

**What you see:**

```text
SESSION STATE SAVED to agents/memory/handoff.md

Current feature: 2.3 — S3 backend module (in progress)
Uncommitted changes: none
Blockers: none
Next step: Add KMS encryption key resource

Safe to /clear or close terminal.
```

If you forget to run `/handoff`, no data is lost — `progress.txt` and git history still exist. The handoff file adds context (what was in progress, decisions made, blockers) that helps the next session start faster.

### Debugging issues

When you hit a problem you don't immediately understand:

```text
/investigate
```

Or say "investigate this" or "find the root cause" — Claude recognizes these triggers.

Claude creates a structured file at `agents/investigations/[slug].md` with:

- **Facts** — verified observations with evidence
- **Theories** — 3+ competing hypotheses
- **Tests Performed** — what was tried and what was observed
- **Resolution** — root cause, fix, and prevention

The investigation file persists across `/compact` and `/clear`, so long debugging sessions don't lose context.

## What to Expect from Claude

### Failure behavior

Claude follows a defensive coding protocol. When anything fails:

1. **Stops** — no silent retry
2. **Reports** — exact error, theory, proposed action
3. **Waits** — asks for confirmation before proceeding

You'll see structured output like:

```text
FAILED: terraform apply failed
THEORY: S3 bucket name already exists in another account
PROPOSE: Change bucket name prefix to include account ID
Proceed?
```

### What Claude won't do

- **Push to remote** — all commits are local only
- **Skip gates** — no feature is marked complete without validation + plan & apply + commit
- **Work outside the current feature** — if Claude notices something unrelated, it adds a note to `progress.txt` instead of fixing it
- **Use `git add .`** — files are staged individually
- **Set executable permissions** — scripts are run via `bash script.sh`
- **Run `terraform destroy`** — unless explicitly instructed
- **Apply without plan** — always plans first, reviews, then applies from saved plan file

## Project Directories

| Directory | Purpose | Managed by |
| --- | --- | --- |
| `modules/` | Reusable Terraform modules | Developer + Claude |
| `envs/<env>/` | Environment-specific root configurations | Developer + Claude |
| `docs/` | Project documentation (ARCHITECTURE, FEATURE_*.md) | `/test-terraform`, `/update-docs-terraform` |
| `agents/memory/` | Session state (handoff between sessions) | `/handoff`, `/catchup` |
| `agents/investigations/` | Structured debugging files | `/investigate` |
| `.claude/commands/` | Skill definitions | Project maintainer |

## Key Files

| File | Purpose | Who updates it |
| --- | --- | --- |
| `progress.txt` | Feature roadmap and status tracking | `/start-feature`, `/test-terraform` |
| `prd.md` | Product requirements (architecture decisions) | Project maintainer |
| `CHANGELOG.md` | Per-feature changelog | `/test-terraform` |
| `variables.tf` | Input variable definitions (types, defaults, validation) | Developer + Claude |
| `terraform.tfvars` | Environment-specific variable values | Developer |
| `backend.tf` | State backend configuration | Developer |
| `agents/memory/handoff.md` | Last session's end state | `/handoff` |

## Quick Reference

```text
# Start of session
/catchup

# Begin a feature
/start-feature

# ... implement with Claude ...

# Complete and commit
/test-terraform

# Free context and continue
/compact
/start-feature

# Refresh docs before a PR
/update-docs-terraform

# End of session
/handoff
```
