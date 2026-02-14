---
name: terraform-testing
description: Run Terraform validation, security scanning, planning, and deployment testing. Use when the user asks to test Terraform code, validate Terraform configurations, run Terraform checks, or deploy Terraform to a dev environment. Triggers on requests like "test terraform", "validate my terraform", "run terraform checks", "deploy terraform to dev", or "/test-terraform".
---

# Terraform Testing

Portable Terraform validation and deployment pipeline. Runs git-secrets, fmt, init, validate, tflint, security scanning (checkov/trivy), plan, and optionally apply/destroy via a single shell script.

## Workflow

1. Run the test script (`scripts/test-terraform.sh`)
2. Review output — all critical steps must pass
3. If deploy mode: review plan output before apply proceeds
4. On success: update progress tracking and commit

## Running the Script

The script lives at `scripts/test-terraform.sh` relative to this skill directory. Copy or reference it from the target project.

### Common Invocations

```bash
# Validate only (no plan, no deploy)
bash scripts/test-terraform.sh --no-plan

# Validate + plan (default)
bash scripts/test-terraform.sh

# Validate specific directory
bash scripts/test-terraform.sh --target modules/vpc

# Validate + plan + apply
bash scripts/test-terraform.sh --deploy

# Validate + plan + apply + destroy (ephemeral test)
bash scripts/test-terraform.sh --deploy-destroy

# Use specific AWS profile
bash scripts/test-terraform.sh --deploy --profile dev-account

# Security findings as warnings (don't fail)
bash scripts/test-terraform.sh --soft-fail

# Use trivy instead of checkov
bash scripts/test-terraform.sh --scanner trivy
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
- **Security scan findings:** Reported as warnings by default. Use `--soft-fail` to prevent blocking.
- **Suppressing false positives:**
  - Checkov: `# checkov:skip=CKV_AWS_XX:Reason` inline comment
  - Trivy: `.trivyignore` file or `# trivy:ignore:AVD-AWS-XXXX` inline comment

## Post-Test Commit Workflow

After all gates pass, complete these steps:

1. Update `progress.txt` — change feature from `[~]` to `[x]`, add completion date
2. Update `CHANGELOG.md` — add entry: `## [Feature X.Y] — YYYY-MM-DD`
3. Create `docs/FEATURE_X.Y.md` if it doesn't exist
4. Stage files individually (never `git add .`)
5. Commit: `feat: X.Y — [Brief description]`
6. Do NOT push

## Output Format

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
```
