# PRD: Portable Terraform Testing Script

## Summary

A drop-in, AWS-focused Terraform validation and deployment script that works in any Terraform repository without hardcoded paths or project-specific assumptions. The script is executed from the project root directory. Directories to scan are defined via config file or CLI args — no magic auto-discovery. Falls back to CWD when no config or target is provided. Configurable via optional shell-sourceable config file, env vars, and CLI flags (config file < env vars < CLI flags precedence). Supports both local developer use and CI/CD pipelines.

## Goals

- **Portable:** Works in any Terraform repo with no hardcoded paths or project-specific names
- **Explicit inputs:** Directories to validate come from config file or CLI args, not auto-discovery
- **Configurable:** Optional config file for project defaults, env vars and CLI flags for overrides
- **CI/CD and local:** Structured exit codes and output for automation, helpful messages for developers
- **Tool-tolerant:** Attempts auto-install of missing tools, gracefully skips what it can't install
- **AWS-native auth:** Auto-detects credentials across local CLI, IAM roles, and OIDC/secrets environments

## Execution Model

The script is run from the **project root directory** (not from `tests/`). The project root is the CWD.

**Default behavior (no flags):** Runs all validation steps plus `terraform plan` against deploy-eligible directories.

**No-config fallback:** When no `.test-terraform.conf` exists and no `--target` is given, treats CWD as the single directory to validate.

### CLI Flags

| Flag | Description |
|---|---|
| `--target <path>` | Scope validation to a specific relative directory path |
| `--no-plan` | Stop after validation steps (fmt, init, validate, lint, security). No plan. |
| `--deploy` | Run plan + apply. Resources are left deployed. |
| `--deploy-destroy` | Run plan + apply, pause for verification, then destroy. |
| `--profile <name>` | Use a specific AWS CLI profile |
| `--soft-fail` | Security scan findings are warnings, not failures (for dev environments) |
| `--scanner <name>` | Security scanner to use: `checkov` (default) or `trivy`. Only one active at a time. |
| `--output-dir <path>` | Directory for reports and plan files (default: `./test-results/`) |
| `--help` | Show usage |

### Validation Pipeline (always runs)

1. **git-secrets** — scan for hardcoded secrets
2. **terraform fmt** — check HCL formatting
3. **terraform init + validate** — syntax and provider validation (per directory, `-backend=false`)
4. **tflint** — provider-aware linting
5. **Security scan** — checkov (default) or trivy. One scanner active. Findings output to JUnit XML and SARIF.

### Plan/Deploy Pipeline (conditional)

6. **terraform plan** — runs by default against deploy-eligible directories only. Skipped with `--no-plan`.
7. **terraform apply** — only with `--deploy` or `--deploy-destroy`. Uses local backend state.
8. **terraform destroy** — only with `--deploy-destroy`. Interactive pause (tty) or timed pause (no tty, configurable timeout).

## AWS Authentication

AWS-only. No multi-cloud support. The script auto-detects credentials from three environments:

1. **Local developer** — AWS CLI profile. Auto-detected from `~/.aws/credentials` or `AWS_PROFILE` env var. Overridden with `--profile <name>` flag or config file `AWS_PROFILE` setting.
2. **AWS runtime** (CodeBuild, EC2, ECS, Lambda) — IAM role via instance metadata / task role. Auto-detected when no profile is set and `AWS_CONTAINER_CREDENTIALS_*` or instance metadata is available.
3. **Third-party CI** (GitHub Actions, GitLab CI) — credentials via OIDC or injected secrets (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`). Auto-detected from env vars.

**Precedence:** `--profile` flag > config file `AWS_PROFILE` > `AWS_PROFILE` env var > ambient credentials (IAM role / injected secrets).

The script validates that *some* form of AWS credentials are available before running deploy steps. Validation-only steps (fmt, validate, lint) do not require AWS credentials.

## Configuration File

Optional shell-sourceable file: `.test-terraform.conf` in project root.

```bash
# Directories to validate (space-separated, relative to project root)
TF_TEST_DIRS="modules/core modules/default tests/default"

# Directories eligible for plan/apply (subset of TF_TEST_DIRS)
TF_DEPLOY_DIRS="tests/default"

# AWS CLI profile (overridden by --profile flag)
AWS_PROFILE="my-profile"

# tflint config path (default: auto-detect .tflint.hcl in project root)
TFLINT_CONFIG=".tflint.hcl"

# Security scanner: checkov (default) or trivy
TF_SCANNER="checkov"

# Output directory for reports (default: ./test-results/)
TF_OUTPUT_DIR="./test-results"

# Deploy-destroy timeout in seconds when no tty (default: 60)
TF_DESTROY_TIMEOUT=60
```

## Non-Goals

- **Multi-cloud support** — AWS only
- **Terragrunt support** — pure Terraform only
- **Remote state management** — validation uses `-backend=false`, deploy uses local state
- **Custom test frameworks** — no Terratest, kitchen-terraform, or Go/Ruby test integration
- **Auto-discovery** — directories must be explicitly configured

## Features

### Feature 1: Configuration and Directory Resolution

Load settings from config file, env vars, and CLI flags with proper precedence. Pre-validate all configured directories exist and contain `.tf` files before starting any work.

**Acceptance Criteria:**
- Shell-sourceable `.test-terraform.conf` loaded from CWD if present
- Env vars override config file values; CLI flags override both
- All dirs in `TF_TEST_DIRS` validated for existence and `.tf` content upfront
- Clear error listing all missing/invalid dirs if pre-validation fails
- No config + no `--target` = CWD used as single validation directory
- No hardcoded directory names, paths, or project-specific assumptions anywhere in script

### Feature 2: Tool Detection and Auto-Install

Detect required and optional tools. Attempt auto-install for missing tools. Gracefully skip optional tools that cannot be installed.

**Acceptance Criteria:**
- Required tool: `terraform` — fail if not available and cannot be installed
- Optional tools: `git-secrets`, `tflint`, `checkov`, `trivy` — warn and skip if unavailable
- Auto-install via brew (macOS), apt-get (Debian), dnf/yum (RHEL), pip (checkov)
- OS detection for install method selection
- Clear messages for each tool: installed, skipped, or failed

### Feature 3: AWS Credential Detection

Auto-detect AWS credentials across local CLI, IAM role, and third-party CI environments. Support explicit profile override.

**Acceptance Criteria:**
- `--profile` flag sets `AWS_PROFILE` env var for all subsequent commands
- Config file `AWS_PROFILE` used when no flag provided
- Detects ambient credentials: `AWS_ACCESS_KEY_ID`, `AWS_CONTAINER_CREDENTIALS_*`, instance metadata
- Credential check runs before deploy steps only (not validation)
- Credential source logged (profile, env vars, IAM role) for debugging
- Fails with clear message if deploy requested but no credentials detected

### Feature 4: Validation Pipeline — Secrets Scanning

Run `git-secrets` against the repository to detect hardcoded secrets.

**Acceptance Criteria:**
- Scans entire repo from project root
- Pass: no secrets found
- Fail: exits immediately (fail-fast)
- Skip with warning if `git-secrets` not available

### Feature 5: Validation Pipeline — Format Check

Run `terraform fmt -check` against all configured directories.

**Acceptance Criteria:**
- Recursive format check from project root
- Pass: all files formatted correctly
- Fail: exits immediately with message to run `terraform fmt -recursive`
- `terraform` is a required tool — fails if not available

### Feature 6: Validation Pipeline — Init and Validate

Run `terraform init -backend=false` and `terraform validate` against each configured directory.

**Acceptance Criteria:**
- Iterates over all directories in `TF_TEST_DIRS`
- `init` uses `-backend=false -input=false`
- `validate` runs only if `init` succeeds
- Per-directory pass/fail reporting
- Fail-fast: exits on first directory failure with full error output

### Feature 7: Validation Pipeline — Linting

Run `tflint` against configured directories.

**Acceptance Criteria:**
- Uses `TFLINT_CONFIG` path from config if set; auto-detects `.tflint.hcl` in project root otherwise
- Runs `tflint --init` before scanning
- Lints each directory in `TF_TEST_DIRS`
- Findings are **non-blocking warnings** (does not fail the pipeline)
- Skip with warning if `tflint` not available

### Feature 8: Validation Pipeline — Security Scanning

Run one security scanner (checkov or trivy) against configured directories. Output findings to JUnit XML and SARIF reports.

**Acceptance Criteria:**
- `--scanner` flag or `TF_SCANNER` config selects scanner: `checkov` (default) or `trivy`
- Only one scanner active per run — never both
- Findings written to `$TF_OUTPUT_DIR/<dirname>-security.xml` (JUnit) and `$TF_OUTPUT_DIR/<dirname>-security.sarif` (SARIF)
- Output directory created if it doesn't exist
- **Default:** findings cause failure (fail-fast)
- **`--soft-fail`:** findings are warnings, pipeline continues
- Skip with warning if selected scanner not available

### Feature 9: Plan Pipeline

Run `terraform plan` against deploy-eligible directories.

**Acceptance Criteria:**
- Runs by default against directories in `TF_DEPLOY_DIRS`
- Skipped entirely with `--no-plan`
- When `--target` is used, plans only the targeted directory (if it's in `TF_DEPLOY_DIRS`)
- Uses `terraform init` (without `-backend=false`) with local state for plan
- Plan output saved to `$TF_OUTPUT_DIR/<dirname>.tfplan`
- Fail-fast on plan failure

### Feature 10: Deploy Pipeline

Run `terraform apply` against deploy-eligible directories. Optionally destroy after verification pause.

**Acceptance Criteria:**
- **`--deploy`:** plan + apply. Resources left deployed. No destroy.
- **`--deploy-destroy`:** plan + apply + pause + destroy.
- Apply uses the saved plan file from Feature 9
- Pause behavior:
  - TTY detected: interactive prompt "Press Enter to destroy..."
  - No TTY: timed wait using `TF_DESTROY_TIMEOUT` (default: 60s), then auto-destroy
- Destroy runs `terraform destroy -auto-approve`
- Plan file cleaned up after apply
- Credential validation (Feature 3) must pass before deploy steps run

### Feature 11: Output and Reporting

Structured output for both human and CI/CD consumption.

**Acceptance Criteria:**
- Color output: green (pass), yellow (warn), red (fail) — same as current script
- Per-step counters: passed, warnings, failed
- Summary line at end: `Results: N passed, N warnings, N failed`
- Exit codes: 0 (success), 1 (secrets/general failure), 2 (fmt failure), 3 (validate failure), 4 (deploy dir not found), 5 (security scan failure), 6 (plan failure), 7 (apply/destroy failure)
- Security scan reports in JUnit XML and SARIF format in `$TF_OUTPUT_DIR`
- Plan files saved in `$TF_OUTPUT_DIR`

## Architecture

See `docs/ARCHITECTURE_AND_DESIGN.md` for component design, execution flow, and design decisions.
