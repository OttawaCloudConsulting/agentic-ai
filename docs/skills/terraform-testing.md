# Terraform Testing

**Source:** `skills/terraform-testing/`
**Command:** `/terraform-testing`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "test terraform", "validate my terraform", "run terraform checks", "deploy terraform to dev")

## Description

Portable Terraform validation and deployment pipeline. Runs a gated sequence of secret scanning, HCL formatting, initialization, validation, provider-aware linting, security scanning (checkov or trivy), planning, and optionally apply/destroy — all through a single configurable shell script. Supports multiple execution modes from validation-only to full ephemeral deploy-destroy cycles.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with pipeline overview, configuration reference, and invocation examples |
| `scripts/test-terraform.sh` | Shell script implementing the full 9-step validation and deployment pipeline |
| `references/commit-workflow.md` | Step-by-step commit procedure executed after all gates pass (Gate 3) |

## Usage

```
/terraform-testing
```

The skill expects to be run from the root of a Terraform project containing `.tf` files.

### Script Invocations

```bash
# Validate + plan (default mode)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh

# Validate only — no plan, no deploy
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --no-plan

# Validate a specific directory
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --target modules/vpc

# Validate + plan + apply (resources left deployed)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --deploy

# Validate + plan + apply + destroy (ephemeral test)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --deploy-destroy

# Use a specific AWS profile
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --deploy --profile dev-account

# Treat security findings as warnings (don't fail)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --soft-fail

# Use trivy instead of checkov for security scanning
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --scanner trivy

# Custom output directory for reports and plan files
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --output-dir ./reports
```

## Workflow

The skill executes three sequential gates. Each gate must pass before the next begins.

### Gates 1 and 2 — Validation, Plan, and Deploy

Runs `test-terraform.sh`, which executes these steps in order:

| Step | Tool | Critical | Purpose |
|---|---|---|---|
| 0 | Tool detection | Yes | Auto-detect OS, find or install required tools |
| 1 | git-secrets | Yes | Scan for hardcoded secrets |
| 2 | terraform fmt | Yes | Check HCL formatting |
| 3 | terraform init | Yes | Initialize providers (with `-backend=false` for validation) |
| 4 | terraform validate | Yes | Syntax and consistency check |
| 5 | tflint | Yes | Provider-aware linting (with optional `.tflint.hcl` config) |
| 6 | checkov/trivy | No | Security scanning (warnings by default, configurable) |
| 7 | terraform plan | Yes | Generate deployment plan (skipped with `--no-plan`) |
| 8 | terraform apply | Yes | Deploy resources (only with `--deploy` or `--deploy-destroy`) |
| 9 | terraform destroy | Yes | Teardown resources (only with `--deploy-destroy`) |

The script auto-detects OS (macOS, Debian, RHEL) and attempts to install missing tools automatically. Terraform is required; all other tools are optional and skipped if unavailable.

**Directory handling:** The script validates all configured directories before running any pipeline steps. It supports multiple validate directories and separate deploy-eligible directories, configured via `.test-terraform.conf` or CLI flags.

**AWS credential detection:** Before plan/deploy steps, the script checks for credentials via AWS_PROFILE, access keys, ECS task role, OIDC, or EC2 instance metadata. Fails with actionable guidance if no credentials are found.

**Security scan output:** Produces both JUnit XML and SARIF reports in the output directory for each scanned directory.

**Deploy-destroy mode:** After apply, pauses for user confirmation (interactive TTY) or waits `TF_DESTROY_TIMEOUT` seconds (non-interactive/CI) before destroying resources.

**Pass criteria:** All critical steps pass (exit code 0).
**On failure:** Stop immediately. Report which step failed with actionable fix guidance.

### Gate 3 — Commit Workflow

Executes only after all validation and deployment gates pass. Follows the procedure in `references/commit-workflow.md`:

1. Read `progress.txt` to identify the current in-progress feature (marked `[~]`)
2. Update `progress.txt` — change `[~]` to `[x]`, add completion date
3. Update `CHANGELOG.md` — add entry for the completed feature
4. Create feature documentation at `docs/FEATURE_X.Y.md` with sections adapted to the feature type (summary, files changed, configuration, validation/plan summary, decisions, verification)
5. Stage files individually (never `git add .` or `git add -A`)
6. Commit locally with format `feat: X.Y — [Brief description]` — never push

### Output Format

```text
GATE 1 & 2 — Validation, Plan & Apply: PASS
  - git-secrets: passed
  - terraform fmt: passed
  - terraform init: passed
  - terraform validate: passed
  - tflint: passed (or skipped)
  - checkov: completed with warnings (or passed)
  Plan: 3 to add, 0 to change, 0 to destroy
  Apply: completed successfully

GATE 3 — Commit: PASS (committed as feat: X.Y — ...)

All gates passed. Feature X.Y is complete.
```

## When to Use

- After completing a feature in a Terraform project
- When you need to validate Terraform code before deployment
- When you want a single command to run the full validate-plan-deploy-commit cycle
- For ephemeral infrastructure testing with `--deploy-destroy`
- When a feature is marked `[~]` in `progress.txt` and ready for completion

## When Not to Use

- For CDK projects — use `/cdk-testing` instead
- For compliance assessments — use `/compliance-assess` instead
- When you only need to run `terraform plan` or `terraform apply` directly
- When the project does not use Terraform or OpenTofu

## Configuration

### CLI Flags

| Flag | Purpose |
|---|---|
| `--target <path>` | Validate a specific directory (overrides config) |
| `--no-plan` | Stop after validation steps |
| `--deploy` | Validate + plan + apply |
| `--deploy-destroy` | Validate + plan + apply + destroy |
| `--profile <name>` | AWS CLI profile |
| `--soft-fail` | Security scan findings as warnings |
| `--scanner <name>` | `checkov` (default) or `trivy` |
| `--output-dir <path>` | Directory for reports and plan files |

Flags `--no-plan`, `--deploy`, and `--deploy-destroy` are mutually exclusive.

### Configuration File

Place `.test-terraform.conf` in the project root to set defaults. This is a shell-sourced file.

| Variable | Purpose | Default |
|---|---|---|
| `TF_TEST_DIRS` | Space-separated directories to validate | `.` (current directory) |
| `TF_DEPLOY_DIRS` | Space-separated directories eligible for plan/apply | (none) |
| `AWS_PROFILE` | AWS CLI profile name | (none) |
| `TFLINT_CONFIG` | Path to `.tflint.hcl` | Auto-detect in project root |
| `TF_SCANNER` | `checkov` or `trivy` | `checkov` |
| `TF_OUTPUT_DIR` | Output directory for reports | `./test-results/` |
| `TF_DESTROY_TIMEOUT` | Seconds before auto-destroy in CI (non-TTY) | `60` |

**Precedence:** CLI flags > environment variables > config file > defaults.

### Suppressing Security Findings

- **Checkov:** Add `# checkov:skip=CKV_AWS_XX:Reason` inline comment
- **Trivy:** Use a `.trivyignore` file or `# trivy:ignore:AVD-AWS-XXXX` inline comment

Document suppression decisions in feature documentation or commit messages.

## Related Skills and Commands

- **cdk-testing** — equivalent pipeline for AWS CDK TypeScript projects
- **compliance-assess** — ITSG-33 compliance assessment (can follow after deployment)
