# test-terraform.sh

## Overview

A single, self-contained bash script that validates and optionally deploys Terraform configurations. Designed to be portable across any AWS-focused Terraform repository -- no hardcoded paths, no project-specific assumptions, no external dependencies beyond standard tooling.

The script runs a fixed validation pipeline (secrets scanning, formatting, init/validate, linting, security scanning) and optionally executes plan/apply/destroy workflows. It auto-detects the operating system and attempts to install missing tools. Configuration is layered: config file, environment variables, and CLI flags, with CLI flags taking highest precedence.

AWS-only. Terraform-only. Single file.

## Usage

Run from the **project root directory** (the directory containing your Terraform files or subdirectories).

```bash
bash test-terraform.sh [OPTIONS]
```

### Execution Modes

| Command | What it does |
|---|---|
| `bash test-terraform.sh` | Validate all directories + plan against deploy-eligible dirs |
| `bash test-terraform.sh --no-plan` | Validate only -- no plan, no deploy |
| `bash test-terraform.sh --deploy` | Validate + plan + apply (resources left deployed) |
| `bash test-terraform.sh --deploy-destroy` | Validate + plan + apply + pause + destroy |

### CLI Flags

| Flag | Description |
|---|---|
| `--target <path>` | Scope validation to a single directory (relative to project root) |
| `--no-plan` | Stop after validation steps |
| `--deploy` | Validate + plan + apply |
| `--deploy-destroy` | Validate + plan + apply + pause + destroy |
| `--profile <name>` | Use a specific AWS CLI profile |
| `--soft-fail` | Security scan findings are warnings, not failures |
| `--scanner <name>` | Security scanner: `checkov` (default) or `trivy` |
| `--output-dir <path>` | Directory for reports and plan files (default: `./test-results/`) |
| `--help` | Show usage |

Mutually exclusive: `--no-plan`, `--deploy`, and `--deploy-destroy` cannot be combined.

### Configuration File

Place a `.test-terraform.conf` file in the project root. It is shell-sourced -- use standard `KEY=value` format.

```bash
# Directories to validate (space-separated, relative to project root)
TF_TEST_DIRS="modules/core modules/vpc tests/default"

# Directories eligible for plan/apply (subset of TF_TEST_DIRS)
TF_DEPLOY_DIRS="tests/default"

# AWS CLI profile
AWS_PROFILE="my-profile"

# tflint config path (default: auto-detect .tflint.hcl in project root)
TFLINT_CONFIG=".tflint.hcl"

# Security scanner: checkov (default) or trivy
TF_SCANNER="checkov"

# Output directory for reports (default: ./test-results/)
TF_OUTPUT_DIR="./test-results"

# Seconds to wait before auto-destroy when no TTY (default: 60)
TF_DESTROY_TIMEOUT=60
```

### Configuration Precedence

```
CLI flags  >  environment variables  >  config file  >  defaults
```

When no config file exists and no `--target` is given, the current working directory is used as the single validation directory.

### Examples

```bash
# Simple repo, no config file -- validates CWD
bash test-terraform.sh --no-plan

# Validate a specific module
bash test-terraform.sh --target modules/vpc --no-plan

# Full pipeline with a named AWS profile
bash test-terraform.sh --deploy --profile dev-account

# Deploy, verify, then tear down -- security findings as warnings
bash test-terraform.sh --deploy-destroy --soft-fail

# Use trivy instead of checkov, custom output directory
bash test-terraform.sh --scanner trivy --output-dir ./reports
```

### Pipeline Steps

The script executes these steps in order. Steps 1-5 always run. Steps 6-8 are conditional.

| Step | Tool | Blocking | Description |
|---|---|---|---|
| 0 | -- | Fatal | Tool detection and auto-install |
| 1 | git-secrets | Fail-fast | Scan repo for hardcoded secrets |
| 2 | terraform fmt | Fail-fast | Check HCL formatting |
| 3 | terraform init + validate | Fail-fast | Init and validate each directory |
| 4 | tflint | Warnings only | Provider-aware linting |
| 5 | checkov / trivy | Fail-fast (or warnings with `--soft-fail`) | Security scanning |
| -- | -- | -- | AWS credential check (before plan/deploy only) |
| 6 | terraform plan | Fail-fast | Plan against deploy-eligible dirs |
| 7 | terraform apply | Fail-fast | Apply using saved plan file |
| 8 | terraform destroy | Fail-fast | Destroy after pause (`--deploy-destroy` only) |

### AWS Authentication

AWS credentials are checked before plan/deploy steps only. Validation steps never require credentials.

Detection order:

1. `--profile` flag or `AWS_PROFILE` env var / config value
2. `AWS_ACCESS_KEY_ID` env var (injected secrets)
3. `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` (ECS task role)
4. `AWS_WEB_IDENTITY_TOKEN_FILE` (OIDC)
5. EC2 instance metadata endpoint

### Output

Reports and plan files are written to the output directory (default: `./test-results/`).

| File | Source |
|---|---|
| `<dirname>-security.xml` | Security scan results (JUnit XML) |
| `<dirname>-security.sarif` | Security scan results (SARIF) |
| `<dirname>.tfplan` | Terraform plan output (cleaned up after apply) |

For nested directory paths, slashes are replaced with dashes (e.g., `modules/vpc` becomes `modules-vpc`).

### Destroy Behavior

With `--deploy-destroy`, after apply completes the script pauses before destroying:

- **TTY detected** (local terminal): interactive prompt -- "Press Enter to destroy..."
- **No TTY** (CI/CD): timed wait using `TF_DESTROY_TIMEOUT` (default: 60 seconds), then auto-destroy

### Exit Codes

| Code | Meaning |
|---|---|
| 0 | All steps passed |
| 1 | Secrets detected or general failure |
| 2 | Formatting issues |
| 3 | terraform init or validate failed |
| 4 | No AWS credentials detected (deploy requested) |
| 5 | Security scan findings (without `--soft-fail`) |
| 6 | terraform plan failed |
| 7 | terraform apply or destroy failed |

## Development and Technical Reference

### Architecture

Single monolithic bash file (~940 lines). No sourced dependencies, no library files. Functions with section-header comments provide internal organization.

```
test-terraform.sh
  Defaults and constants
  Output helpers (print_step, print_success, print_warning, print_error, print_info)
  usage()
  Configuration loading (save_caller_env, restore_caller_env, load_config)
  Argument parsing (parse_args, apply_cli_overrides)
  Directory resolution (resolve_directories, validate_directories)
  OS detection (detect_os)
  Tool detection and auto-install (tool_available, attempt_install, detect_tools)
  AWS credential detection (detect_aws_credentials)
  main() -- orchestrates the full pipeline
```

### Shell Settings

The script runs with `set -euo pipefail`:

- **`-e`**: Exit on error. All conditional checks use `if/then` instead of `&&` short-circuit to remain compatible.
- **`-u`**: Treat unset variables as errors. Empty arrays use `${arr[@]+"${arr[@]}"}` expansion to avoid errors on older bash versions.
- **`-o pipefail`**: Pipe failures propagate.

### Configuration Precedence Implementation

The three-layer precedence (config < env < CLI) works as follows:

1. `save_caller_env()` snapshots the caller's environment variables before config sourcing
2. `source .test-terraform.conf` sets variables (potentially overwriting env vars)
3. `restore_caller_env()` restores the original env var values over config file values
4. `apply_cli_overrides()` overwrites with any CLI flag values

This ensures the correct precedence chain without complex merging logic.

### Tool Detection and Auto-Install

OS detection (`detect_os`) determines the install method:

| OS | Package managers |
|---|---|
| macOS | `brew` |
| Debian/Ubuntu | `apt-get` |
| RHEL/CentOS/Fedora | `dnf`, `yum` |

| Tool | Required | Install method | On failure |
|---|---|---|---|
| terraform | Yes | brew / apt / yum (HashiCorp repo) | Script exits |
| git-secrets | No | brew / apt / dnf | Skip with warning |
| tflint | No | brew / install script (Linux) | Skip with warning |
| checkov | No | pip3 / pip | Skip with warning |
| trivy | No | brew / apt (Aqua repo) / yum | Skip with warning |

Only the selected scanner (checkov or trivy) is checked -- never both.

### Directory Targeting

`terraform -chdir=<dir>` is used for all per-directory operations (init, validate, plan, apply, destroy). This avoids working directory side effects from `cd`.

For plan files, the output path is resolved to an absolute path before passing to `-out`, because `-chdir` changes terraform's working directory and relative paths would resolve against the target directory instead of the project root.

### Security Scanner Integration

**checkov** (default): Output is captured via stdout redirection. Runs twice per directory -- once for JUnit XML, once for SARIF.

```bash
checkov -d "$dir" --framework terraform --output junitxml > "report.xml"
checkov -d "$dir" --framework terraform --output sarif > "report.sarif"
```

**trivy**: Uses native `-o` flag for output. Also runs twice per directory.

```bash
trivy fs "$dir" --scanners misconfig --severity HIGH,CRITICAL --format template \
  --template "@contrib/junit.tpl" -o "report.xml"
trivy fs "$dir" --scanners misconfig --severity HIGH,CRITICAL --format sarif \
  -o "report.sarif"
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| Single bash file | Drop into any repo. No sourced dependencies to manage. |
| Terraform only (no OpenTofu) | Single binary, reduced complexity. |
| Shell-sourceable config | No extra tools (jq, yq). Standard `KEY=value`. |
| checkov as default scanner | 1000+ Terraform-specific policies, native JUnit/SARIF. |
| CWD fallback | Works out-of-the-box for simple single-module repos. |
| Fail-fast for blocking steps | No wasted time when upstream is broken. |
| Soft-fail for security scans | Dev environments often have legitimate findings. |
| Credential detection before deploy only | Validation steps never need AWS credentials. |
| Local backend state for deploy | Test deployments are ephemeral -- local state is sufficient. |
| TTY detection for destroy pause | Same script works for interactive and CI use. |

### Modifying the Script

**Adding a new pipeline step**: Add the step in the `main()` function between the existing steps. Use `print_step`, `print_success`, `print_warning`, and `print_error` for consistent output. Increment the appropriate counter via the helper functions.

**Adding a new tool**: Add a `HAS_<TOOL>` global, add detection/install logic in `attempt_install()` and `detect_tools()`, then gate the pipeline step on `$HAS_<TOOL>`.

**Adding a new CLI flag**: Add a `_CLI_<FLAG>` variable, handle it in `parse_args()`, apply it in `apply_cli_overrides()`. Add it to `usage()` and `print_config()`.

**Adding a new config variable**: Add it to `save_caller_env()`, `restore_caller_env()`, `load_config()` defaults, and `usage()`.
