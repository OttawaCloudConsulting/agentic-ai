# Project Rules — Terraform

## Development Process

This project follows a strict **Feature > Test > Complete > Next Feature** workflow.
All features are tracked in `progress.txt`. Read it before starting any work.

### Rules

1. **Read `progress.txt` before doing anything.** Identify the current in-progress `[~]` feature or the next pending `[ ]` feature. Do NOT work on anything else.

2. **One feature at a time.** Never start the next feature until the current one is marked `[x]`.

3. **Every feature must pass validation before it can be marked complete.**
   - Run `terraform fmt -check -recursive` — formatting must be consistent.
   - Run `terraform validate` — syntax and internal consistency must pass.
   - Run `tflint` — linting must pass (if installed).
   - The `terraform plan` output is the primary evidence that the feature works as intended. Review the plan diff before applying.
   - "Validate passes" is not sufficient on its own — the plan output must show the expected resources and changes.

4. **Prove the feature works.** Run `/test-terraform` to execute all validation gates (validation, plan & apply, commit). Do NOT mark a feature `[x]` until `/test-terraform` passes. The `/test-terraform` skill handles validation, deployment, documentation, changelog, and git commit.

5. **Start a feature with `/start-feature`.** It reads `progress.txt`, identifies the next feature, marks it `[~]`, reads `prd.md` for requirements, and reports what needs to be built. Add any decisions or issues to NOTES in progress.txt as you work.

6. **Do NOT refactor, improve, or work on anything outside the current feature.** If you notice something that needs attention later, add it to NOTES in progress.txt under the relevant feature.

## AWS Environment

- **AWS CLI profile:** `<PROFILE_NAME>`
- **All Terraform and AWS commands must use the configured profile** (via `AWS_PROFILE=<PROFILE_NAME>` or provider config)
- **Region:** defined in provider configuration (not via CLI flag)
- **Backend:** state backend configuration is project-specific — defined in `backend.tf`
- **Deploy target:** dev account only

## Tech Stack

- Terraform (HCL)
- CLI: terraform, tflint, tfsec/checkov (if installed)
- Validation: `terraform validate`, `terraform fmt -check`, `tflint`
- All architecture decisions are in `prd.md` — follow them exactly

## Validation Expectations

### What counts as validation

- `terraform fmt -check -recursive` must pass with zero formatting errors
- `terraform validate` must pass with zero errors
- `tflint` must pass with zero errors (if installed)
- `tfsec` or `checkov` must pass with zero critical findings (if installed)
- `terraform plan` must show the expected resource changes — review the diff

### Validation rules

1. **`terraform validate` must actually run.** Never skip validation or substitute it with `echo` or `exit 0`.

2. **`terraform fmt -check` is not optional.** All `.tf` files must be canonically formatted. Do not auto-fix during validation — report and stop.

3. **Plan output is the test result.** Review the plan diff to verify the feature creates, modifies, or destroys the expected resources. A plan that shows "no changes" when changes are expected is a failure.

4. **All variables must be strongly typed.** Every `variable` block must have an explicit `type` constraint. Use specific types (`string`, `number`, `bool`, `list(string)`, `map(string)`, `object({...})`) — never leave `type` unset. For structured inputs, use `object()` with named attributes rather than `map(any)`.

5. **Validate inputs with patterns.** Use `validation` blocks on variables wherever possible. Enforce format constraints (e.g., regex for naming conventions, CIDR ranges, ARN patterns, allowed value sets). A variable without validation is a variable that accepts garbage.

## Defensive Coding

Follow the defensive coding protocol when writing code, debugging, investigating issues, or performing multi-step tasks. The protocol is loaded automatically when relevant. Key principle: **when anything fails, STOP → THINK → REPORT → WAIT.**

### Terraform-Specific Rules

1. **Never run `terraform apply` without a prior `terraform plan`.** Always plan first, review output, then apply from the saved plan file.
2. **Never run `terraform destroy` unless explicitly instructed.** This is an irreversible action.
3. **State is sacred.** Never manually edit `.tfstate` files. Never commit state files to git. Ensure `.gitignore` excludes `*.tfstate`, `*.tfstate.backup`, `.terraform/`, and `*.tfplan`.
4. **Lock before apply.** If using remote state, ensure state locking is configured.
5. **Pin provider versions.** Use `required_providers` with version constraints. Never use `>=` without an upper bound.
6. **Pin module versions.** When sourcing modules from registries, pin to exact versions or narrow ranges.
7. **Strongly type all variables.** (See Validation rules #4 above.)
8. **Validate inputs with patterns.** (See Validation rules #5 above.)
9. **Use `terraform plan -out=tfplan`** to ensure the applied changes match what was reviewed.
10. **Treat plan output as the test result.** The plan diff is the primary evidence that the feature works as intended.

## Git Discipline

`git add .` is forbidden. Add files individually. Know what you're committing.

## Terminal Discipline

**RULE:** Pipe JSON output to `jq` to prevent terminal hangs.

```bash
command --output json | jq
```

**RULE:** Never set executable permissions on shell scripts.

`chmod +x script.sh` is a security violation.

Execute scripts explicitly via interpreter:
```bash
bash ./script.sh
sh ./script.sh
```

## Skills

Development workflow and session management are handled by skills in `.claude/commands/`.

### Development Workflow

| Skill | When to use |
|---|---|
| `/start-feature` | Begin the next feature (reads progress.txt + prd.md, marks `[~]`) |
| `/test-terraform` | Complete a feature (validation, plan & apply, docs, changelog, commit) |
| `/update-docs-terraform` | Refresh README, ARCHITECTURE after features accumulate |

### Session Lifecycle

| Skill | When to use |
|---|---|
| `/catchup` | Start of session — read project state from last handoff |
| `/handoff` | End of session — save state before `/clear` or closing terminal |
| `/investigate` | Debug unknowns — structured facts/theories/tests in `agents/investigations/` |

### Always Active

| Skill | Purpose |
|---|---|
| `defensive-protocol` | Loaded automatically when writing code, debugging, or investigating |

**Persistent learnings:** Use `/memory` to add permanent corrections to CLAUDE.md.

## Project Directories

- **`modules/`** — Reusable Terraform modules
- **`envs/<env>/`** — Environment-specific root configurations (e.g., `envs/dev/`, `envs/prod/`)
- **`docs/`** — Project documentation (ARCHITECTURE, FEATURE_*.md)
- **`agents/`** — Working memory for session state and investigations (not project docs)
  - `agents/memory/handoff.md` — last session's end state (written by `/handoff`, read by `/catchup`)
  - `agents/investigations/` — structured debugging files (created by `/investigate`)

## Process Constraints

- Reference the user naturally (no special terminology required)
- When confused: stop, think, present plan, get signoff
