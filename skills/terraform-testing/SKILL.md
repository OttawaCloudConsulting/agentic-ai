---
name: terraform-testing
description: Run Terraform (and OpenTofu) validation, security scanning, planning, and deployment testing for .tf and .tfvars files. Use when the user asks to test Terraform or OpenTofu code, validate Terraform configurations, run Terraform checks, deploy Terraform to a dev environment, or test tofu configs. Triggers on requests like "test terraform", "validate my terraform", "run terraform checks", "deploy terraform to dev", "/test-terraform", "test opentofu", "validate my tofu", or "run tofu checks". Do NOT use for CloudFormation, Pulumi, CDK, or non-Terraform infrastructure code.
compatibility: "Requires Terraform CLI or OpenTofu (tofu) CLI. AWS credentials required for --deploy and --deploy-destroy modes. macOS, Debian, and RHEL supported."
---

# Terraform Testing

Portable Terraform validation and deployment pipeline. Runs git-secrets, fmt, init, validate, tflint, security scanning (checkov/trivy), plan, and optionally apply/destroy via a single shell script.

## Critical Rules

- **Sequential execution:** Never skip a step or run steps in parallel
- **Stop on failure:** If any critical step fails, stop immediately and report
- **No silent errors:** Always show the actual error output
- **Plan before apply:** Never run `terraform apply` without reviewing plan output first

## Prerequisites

- Terraform CLI (`terraform`) or OpenTofu CLI (`tofu`) installed and on `PATH`
- Git installed (required for git-secrets step)
- AWS credentials configured (required for `--deploy` and `--deploy-destroy` modes only)

## Workflow

1. Run the test script
2. Review output — all critical steps must pass
3. If deploy mode: review plan output before apply proceeds

## Running the Script

The script is bundled with this skill at `.claude/skills/terraform-testing/scripts/test-terraform.sh`.

If the script is not present at that path, the skill was likely installed without its `scripts/` directory. Re-install the skill bundle or verify the installation path matches your Claude Code skills directory.

### Common Invocations

```bash
# Validate only (no plan, no deploy)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --no-plan

# Validate + plan (default)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh

# Validate specific directory
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --target modules/vpc

# Validate + plan + apply
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --deploy

# Validate + plan + apply + destroy (ephemeral test)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --deploy-destroy

# Use specific AWS profile
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --deploy --profile dev-account

# Security findings as warnings (don't fail)
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --soft-fail

# Use trivy instead of checkov
bash .claude/skills/terraform-testing/scripts/test-terraform.sh --scanner trivy
```

### Configuration

Place `.test-terraform.conf` in the project root to set defaults:

| Variable | Purpose |
|---|---|
| `TF_TEST_DIRS` | Space-separated directories to validate |
| `TF_DEPLOY_DIRS` | Space-separated directories eligible for plan/apply |
| `AWS_PROFILE` | AWS CLI profile name |
| `TFLINT_CONFIG` | Path to `.tflint.hcl` |
| `TF_SCANNER` | `checkov` or `trivy` |
| `TF_OUTPUT_DIR` | Output directory for reports (default: `./test-results/`) |
| `TF_DESTROY_TIMEOUT` | Seconds before auto-destroy in CI (default: 60) |

Precedence: CLI flags > environment variables > config file > defaults.

## Pipeline Steps

| Step | Tool | Critical | Purpose |
|---|---|---|---|
| 1 | git-secrets | Yes | Scan for hardcoded secrets |
| 2 | terraform fmt | Yes | Check HCL formatting |
| 3 | terraform init | Yes | Initialize providers |
| 4 | terraform validate | Yes | Syntax and consistency |
| 5 | tflint | Yes | Provider-aware linting |
| 6 | checkov/trivy | No | Security scanning (warnings) |
| 7 | terraform plan | Yes | Generate deployment plan |
| 8 | terraform apply | Yes | Deploy (only with --deploy) |
| 9 | terraform destroy | Yes | Teardown (only with --deploy-destroy) |

The script auto-detects OS (macOS, Debian, RHEL) and installs missing tools automatically.

## Failure Handling

- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **`terraform init` connectivity failure:** If Step 3 fails with provider registry or download errors, the issue is network-level, not code-level. Check for corporate proxy requirements (`HTTPS_PROXY` env var), use a local provider mirror (`terraform init -plugin-dir`), or verify provider registry access. Re-run after resolving connectivity.
- **Security scan findings:** Reported as warnings by default. Use `--soft-fail` to prevent blocking.
- **Suppressing false positives:**
  - Checkov: `# checkov:skip=CKV_AWS_XX:Reason` inline comment
  - Trivy: `.trivyignore` file or `# trivy:ignore:AVD-AWS-XXXX` inline comment

Document suppression decisions in commit messages or project documentation.

## Output Format

The script prints a per-step pass/fail summary followed by a plan summary line (`N to add, N to change, N to destroy`) and, if deployed, an apply status line.

## Example

User says: "test my terraform"

```bash
bash .claude/skills/terraform-testing/scripts/test-terraform.sh
```

All steps pass. Output shows plan summary: `2 to add, 0 to change, 0 to destroy`. Report results to user.
