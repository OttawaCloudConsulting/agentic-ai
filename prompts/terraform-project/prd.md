# PRD — Terraform Project Kit

## Purpose

Create a drop-in Claude Code kit for Terraform projects, following the same structure and philosophy as the existing `cdk-project` kit. The kit provides project rules, developer workflow guide, and Terraform-specific commands that enforce the **Feature > Test > Complete > Next Feature** workflow.

## Background

The `cdk-project` kit uses CDK (TypeScript), Jest assertions, and `cdk deploy` as its validation and deployment pipeline. Terraform projects use HCL, have limited unit testing capabilities compared to CDK, and rely on `terraform validate`, `terraform plan`, and `terraform apply` for verification. This kit adapts the proven CDK workflow to Terraform's toolchain.

## Decisions

| # | Question | Decision |
|---|----------|----------|
| 1 | AWS profile name | Use `<PROFILE_NAME>` placeholder. Consumers replace it. |
| 2 | Terraform version constraint | None prescribed. Consumer defines their own. |
| 3 | Documentation commands | Update `update-docs.md` now with a Terraform variant. No deferred content. |
| 4 | Directory convention | Prescriptive based on best practices. Consumer customization is out of scope. |

## Deliverables

### 1. `prompts/terraform-project/CLAUDE.md` — Project Rules Template

Based on `prompts/cdk-project/CLAUDE.md`. Consumers copy this to their repo root.

**Sections to include:**

| Section | CDK Equivalent | Terraform Adaptation |
|---------|---------------|---------------------|
| Development Process | Same | Same workflow, same rules. Reference `/test-terraform` instead of `/test-cdk` |
| AWS Environment | Same | `<PROFILE_NAME>` placeholder. Add `backend` config notes |
| Tech Stack | CDK v2, TypeScript, Jest | Terraform (HCL), terraform CLI, tflint, terraform validate |
| Test Expectations | Jest assertions, Template.fromStack | `terraform validate`, `terraform fmt -check`, `tflint` |
| Defensive Coding | Same | Same — reference defensive-protocol. Add Terraform-specific rules |
| Git Discipline | Same | Same — no `git add .` |
| Terminal Discipline | Same | Same — pipe JSON to jq, no chmod +x |
| Skills | test-cdk, start-feature, etc. | test-terraform replaces test-cdk. update-docs-terraform replaces update-docs. All other skills reused as-is |
| Project Directories | lib/, test/, lambda/, docs/, agents/ | modules/, envs/, docs/, agents/ |
| Process Constraints | Same | Same |

**Key differences from CDK CLAUDE.md:**

- **Tech Stack:** Terraform (HCL) with terraform CLI. No Node.js dependency.
- **Test Expectations:** Terraform validation strategy:
  1. `terraform fmt -check -recursive` — formatting consistency
  2. `terraform validate` — syntax and internal consistency
  3. `tflint` — linting for provider-specific best practices (if installed)
  4. Security scanning via `tfsec` or `checkov` (if installed)
  - The `terraform plan` output serves as the primary verification that infrastructure changes are correct. Treat plan output as the test result.
- **Deployment gate:** `terraform plan` (review) then `terraform apply` instead of `cdk deploy`.
- **State management:** Terraform state must be configured (local or remote backend). The kit does not prescribe backend choice — that is a consumer decision documented in their `prd.md`.
- **Directory structure** (prescribed):
  - `modules/` — reusable Terraform modules (equivalent of CDK constructs in `lib/`)
  - `envs/<env>/` — environment-specific root configurations (e.g., `envs/dev/`, `envs/prod/`)
  - `docs/` — project documentation
  - `agents/` — Claude Code working memory (handoffs, investigations)

### 2. `prompts/terraform-project/CLAUDE_CODE_USER_GUIDE.md` — Developer Workflow Guide

Based on `prompts/cdk-project/CLAUDE_CODE_USER_GUIDE.md`. Consumers copy this to their repo root or `docs/`.

**Adaptations:**

- Prerequisites: Terraform CLI, AWS CLI profile configured, tflint (optional), tfsec/checkov (optional)
- Skills table: `/test-terraform` replaces `/test-cdk`. `/update-docs-terraform` replaces `/update-docs`. All other skills are identical.
- Development workflow steps:
  1. `/start-feature` — same as CDK (reads progress.txt, identifies next feature)
  2. Implement in HCL. Follow defensive protocol.
  3. `/test-terraform` — runs validation gates (fmt, validate, plan, apply, commit)
  4. Continue to next feature
  5. `/update-docs-terraform` — refresh documentation using Terraform data sources
- Session lifecycle: identical (`/catchup`, `/handoff`, `/investigate`)
- Project directories table: Terraform prescribed structure

### 3. `commands/test-terraform.md` — Terraform Validation and Commit Skill

Based on `commands/test-cdk.md`. This is the Terraform-specific replacement.

**Gate structure:**

| Gate | CDK Equivalent | Terraform Version |
|------|---------------|-------------------|
| Gate 1 — Validation | `bash scripts/cdk-validation.sh` (git-secrets, Prettier, ESLint, tsc, npm audit, Snyk) | `terraform fmt -check -recursive`, `terraform validate`, `tflint` (if installed), `tfsec`/`checkov` (if installed), `git-secrets` |
| Gate 2 — Plan & Apply | `npx cdk deploy --all --profile developer-account --require-approval never` | `terraform plan -out=tfplan` (review output), then `terraform apply tfplan` |
| Gate 3 — Commit | Same | Same (update progress.txt, CHANGELOG.md, create feature doc, stage individually, commit locally) |

**Gate 1 detail — Validation:**

Run each check sequentially. Stop on first failure.

1. **`git-secrets --scan`** — scan for hardcoded secrets
2. **`terraform fmt -check -recursive`** — verify formatting. Do NOT auto-fix; report and stop.
3. **`terraform init`** (if needed) — ensure providers are initialized
4. **`terraform validate`** — syntax and internal consistency check
5. **`tflint`** — provider-aware linting (skip if not installed, note in output)
6. **`tfsec`** or **`checkov`** — security scanning (skip if not installed, note in output)

**Gate 2 detail — Plan & Apply:**

1. Run `terraform plan -out=tfplan` with the configured AWS profile
2. Report the plan summary (resources to add/change/destroy)
3. Run `terraform apply tfplan`
4. On failure: STOP, report error, do not proceed

**Gate 3 detail — Commit:**

Same as CDK test-cdk.md Gate 3:
- Update progress.txt (`[~]` → `[x]`, completion date)
- Update CHANGELOG.md
- Create `docs/FEATURE_X.Y.md`
- Stage files individually (never `git add .`)
- Commit with `feat: X.Y — [Description]` + Co-Authored-By footer
- Do NOT push

**Output format:** Same gate-by-gate reporting as test-cdk.

### 4. `commands/update-docs-terraform.md` — Terraform Documentation Refresh Skill

Based on `commands/update-docs.md`. Replaces CDK-specific data sources with Terraform equivalents.

**Data source mapping:**

| CDK (`update-docs.md`) | Terraform (`update-docs-terraform.md`) |
|------------------------|---------------------------------------|
| `npm test --verbose` | `terraform validate` output |
| `lib/config.ts` | `variables.tf`, `locals.tf` |
| `cdk.json` | `terraform.tfvars`, `backend.tf` |
| test/ files | N/A (no assertion test files) |
| Stack architecture | Module structure (`modules/`) |

**Documents refreshed:**
- `README.md` — architecture overview, module table, project structure tree, configuration variables, deployment instructions
- `docs/ARCHITECTURE.md` — module design, environment layout, provider configuration, state management
- No `docs/TESTING.md` — validation is covered in ARCHITECTURE.md under a Validation section (no assertion test suite to document separately)

### 5. Shared Commands — No Changes

The following commands are reused as-is from `commands/`:

| Command | Why no change needed |
|---------|---------------------|
| `catchup.md` | Reads progress.txt + handoff.md — tool-agnostic |
| `handoff.md` | Saves session state — tool-agnostic |
| `investigate.md` | Structured debugging — tool-agnostic |
| `start-feature.md` | Reads progress.txt + prd.md — tool-agnostic |
| `defensive-protocol.md` | Epistemology protocol — tool-agnostic |

## Scope

### In scope

- `CLAUDE.md` project rules template for Terraform
- `CLAUDE_CODE_USER_GUIDE.md` developer workflow guide for Terraform
- `test-terraform.md` command (validation + deploy + commit)
- `update-docs-terraform.md` command (Terraform-aware documentation refresh)
- Prescribed directory convention (`modules/`, `envs/<env>/`, `docs/`, `agents/`)
- Documentation of which shared commands the kit depends on

### Out of scope

- Terraform Cloud / Terraform Enterprise integration
- Multi-environment (staging, prod) promotion workflows
- Remote state backend configuration (consumer decision)
- Specific provider configurations (AWS, GCP, Azure) — kit is provider-agnostic in structure, though examples use AWS
- Splitting `commands/` into `prompts/common/commands/` and `prompts/terraform-project/commands/` — tracked separately as a repo-wide structural task
- Terraform module registry publishing
- Consumer customization of directory convention

## Defensive Coding — Terraform Specifics

The defensive protocol applies as-is. Additional Terraform-specific defensive practices to encode in CLAUDE.md:

1. **Never run `terraform apply` without a prior `terraform plan`.** Always plan first, review output, then apply from the saved plan file.
2. **Never run `terraform destroy` unless explicitly instructed.** This is an irreversible action.
3. **State is sacred.** Never manually edit `.tfstate` files. Never commit state files to git. Ensure `.gitignore` excludes `*.tfstate`, `*.tfstate.backup`, `.terraform/`, and `*.tfplan`.
4. **Lock before apply.** If using remote state, ensure state locking is configured.
5. **Pin provider versions.** Use `required_providers` with version constraints. Never use `>=` without an upper bound.
6. **Pin module versions.** When sourcing modules from registries, pin to exact versions or narrow ranges.
7. **Strongly type all variables.** Every variable must have an explicit `type` constraint. Use specific types (`string`, `number`, `bool`, `list(string)`, `map(string)`, `object({...})`) — never leave `type` unset. For structured inputs, use `object()` with named attributes rather than `map(any)`.
8. **Validate inputs with patterns.** Use `validation` blocks on variables wherever possible. Enforce format constraints (e.g., regex for naming conventions, CIDR ranges, ARN patterns, allowed value sets). A variable without validation is a variable that accepts garbage.
9. **Use `terraform plan -out=tfplan`** to ensure the applied changes match what was reviewed.
10. **Treat plan output as the test result.** The plan diff is the primary evidence that the feature works as intended.

## File Manifest

Files to create:

```
prompts/terraform-project/
├── prd.md                            ← this file (already created)
├── CLAUDE.md                         ← project rules template
└── CLAUDE_CODE_USER_GUIDE.md         ← developer workflow guide

commands/
├── test-terraform.md                 ← Terraform validation + deploy + commit skill
└── update-docs-terraform.md          ← Terraform documentation refresh skill
```

## Implementation Order

| Phase | Deliverable | Depends on |
|-------|------------|------------|
| 1 | `prompts/terraform-project/CLAUDE.md` | This PRD (approved) |
| 2 | `commands/test-terraform.md` | Phase 1 (CLAUDE.md references this skill) |
| 3 | `commands/update-docs-terraform.md` | Phase 1 (CLAUDE.md references this skill) |
| 4 | `prompts/terraform-project/CLAUDE_CODE_USER_GUIDE.md` | Phases 1-3 (guide references all skills) |
