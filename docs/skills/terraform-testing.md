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
| `scripts/test-terraform.sh` | Shell script implementing the full validation and deployment pipeline |

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

1. Run the test script
2. Review output — all critical steps must pass
3. If deploy mode: review plan output before apply proceeds

### Pipeline Steps

Runs `test-terraform.sh`, which executes these steps in order:

| Step | Tool | Critical | Purpose |
|---|---|---|---|
| 1 | git-secrets | Yes | Scan for hardcoded secrets |
| 2 | terraform fmt | Yes | Check HCL formatting |
| 3 | terraform init | Yes | Initialize providers |
| 4 | terraform validate | Yes | Syntax and consistency |
| 5 | tflint | Yes | Provider-aware linting |
| 6 | checkov/trivy | No | Security scanning (warnings) |
| 7 | terraform plan | Yes | Generate deployment plan |
| 8 | terraform apply | Yes | Deploy (only with `--deploy`) |
| 9 | terraform destroy | Yes | Teardown (only with `--deploy-destroy`) |

The script auto-detects OS (macOS, Debian, RHEL) and installs missing tools automatically. Terraform is required; all other tools are optional and skipped if unavailable.

**Directory handling:** The script validates all configured directories before running any pipeline steps. It supports multiple validate directories and separate deploy-eligible directories, configured via `.test-terraform.conf` or CLI flags.

**AWS credential detection:** Before plan/deploy steps, the script checks for credentials via AWS_PROFILE, access keys, ECS task role, OIDC, or EC2 instance metadata. Fails with actionable guidance if no credentials are found.

**Security scan output:** Produces both JUnit XML and SARIF reports in the output directory for each scanned directory.

**Deploy-destroy mode:** After apply, pauses for user confirmation (interactive TTY) or waits `TF_DESTROY_TIMEOUT` seconds (non-interactive/CI) before destroying resources.

**Pass criteria:** All critical steps pass (exit code 0).
**On failure:** Stop immediately. Report which step failed with actionable fix guidance.

### Output Format

```text
Terraform Testing: PASS
  - git-secrets: passed
  - terraform fmt: passed
  - terraform init: passed
  - terraform validate: passed
  - tflint: passed (or skipped)
  - checkov: completed with warnings (or passed)
  Plan: 3 to add, 0 to change, 0 to destroy
  Apply: completed successfully
```

## When to Use

- When you need to validate Terraform code before deployment
- When you want a single command to run the full validate-plan-deploy cycle
- For ephemeral infrastructure testing with `--deploy-destroy`

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
