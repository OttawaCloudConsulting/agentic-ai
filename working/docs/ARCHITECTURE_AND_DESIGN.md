# Architecture and Design: Portable Terraform Testing Script

## Overview

A single self-contained bash script (`test-terraform.sh`) that validates and optionally deploys Terraform configurations. The script is portable across any AWS-focused Terraform repository. It loads configuration from a shell-sourceable file, auto-detects AWS credentials, runs a fixed validation pipeline, and optionally executes plan/apply/destroy workflows.

## Component Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                     test-terraform.sh                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Config       │  │ Tool         │  │ AWS Credential   │   │
│  │ Loader       │  │ Detector     │  │ Detector         │   │
│  │              │  │              │  │                  │   │
│  │ .conf file   │  │ terraform    │  │ CLI profile      │   │
│  │ env vars     │  │ git-secrets  │  │ IAM role         │   │
│  │ CLI flags    │  │ tflint       │  │ env var keys     │   │
│  │              │  │ checkov      │  │ OIDC             │   │
│  │              │  │ trivy        │  │                  │   │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘   │
│         │                 │                    │             │
│         ▼                 ▼                    ▼             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Directory Pre-Validation                │   │
│  │   Verify all TF_TEST_DIRS exist and contain .tf      │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         │                                    │
│                         ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              VALIDATION PIPELINE                     │   │
│  │                                                      │   │
│  │  Step 1: git-secrets (optional tool)                 │   │
│  │  Step 2: terraform fmt -check                        │   │
│  │  Step 3: terraform init + validate (per dir)         │   │
│  │  Step 4: tflint (optional tool, non-blocking)        │   │
│  │  Step 5: security scan (checkov OR trivy)            │   │
│  │          → JUnit XML + SARIF to $TF_OUTPUT_DIR       │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         │                                    │
│                    (--no-plan stops here)                    │
│                         │                                    │
│                         ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              PLAN/DEPLOY PIPELINE                    │   │
│  │                                                      │   │
│  │  Step 6: terraform plan (TF_DEPLOY_DIRS only)        │   │
│  │          → .tfplan to $TF_OUTPUT_DIR                  │   │
│  │                                                      │   │
│  │  Step 7: terraform apply (--deploy/--deploy-destroy) │   │
│  │                                                      │   │
│  │  Step 8: terraform destroy (--deploy-destroy only)   │   │
│  │          → interactive pause (tty) or timed (no tty) │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              SUMMARY & EXIT                          │   │
│  │  N passed / N warnings / N failed                    │   │
│  │  Exit code reflects worst failure                    │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

## Execution Flow

1. Parse CLI flags
2. Source `.test-terraform.conf` if present in CWD
3. Apply precedence: config file < env vars < CLI flags
4. Resolve directory lists (`TF_TEST_DIRS`, `TF_DEPLOY_DIRS`); fall back to CWD if empty
5. Pre-validate all directories (exist + contain `.tf`)
6. Detect and report available tools; auto-install missing optional tools
7. Run validation pipeline (Steps 1-5) — fail-fast on blocking failures
8. If not `--no-plan`: check AWS credentials, run plan against `TF_DEPLOY_DIRS`
9. If `--deploy` or `--deploy-destroy`: run apply, optionally destroy
10. Print summary, exit with appropriate code

## Configuration Precedence

```
Priority (highest to lowest):
  1. CLI flags          --profile, --target, --scanner, --output-dir, --soft-fail
  2. Environment vars   AWS_PROFILE, TF_TEST_DIRS, TF_SCANNER, TF_OUTPUT_DIR, etc.
  3. Config file        .test-terraform.conf (shell-sourced, sets env vars)
  4. Defaults           CWD for dirs, checkov for scanner, ./test-results/ for output
```

Implementation: Source config file first (sets env vars), then env vars are already set, then CLI flag parsing overwrites specific variables.

## AWS Credential Detection Logic

```
detect_aws_credentials():
  if --profile flag set:
    export AWS_PROFILE=<flag value>
    log "Using AWS profile: $AWS_PROFILE"
    return OK

  if AWS_PROFILE env var set (from config or environment):
    log "Using AWS profile: $AWS_PROFILE"
    return OK

  if AWS_ACCESS_KEY_ID is set:
    log "Using AWS access key credentials"
    return OK

  if AWS_CONTAINER_CREDENTIALS_RELATIVE_URI is set:
    log "Using ECS task role credentials"
    return OK

  if AWS_WEB_IDENTITY_TOKEN_FILE is set:
    log "Using OIDC credentials"
    return OK

  if curl -s --max-time 1 http://169.254.169.254/latest/meta-data/ succeeds:
    log "Using EC2 instance role credentials"
    return OK

  log "ERROR: No AWS credentials detected"
  return FAIL
```

Credential detection runs only before deploy steps. Validation steps do not require credentials.

## Security Scanner Integration

### checkov (default)

```bash
# JUnit XML output
checkov -d "$dir" --framework terraform --output junitxml > "$output_dir/${dirname}-security.xml"

# SARIF output
checkov -d "$dir" --framework terraform --output sarif > "$output_dir/${dirname}-security.sarif"
```

### trivy

```bash
# JUnit XML output
trivy fs "$dir" --scanners misconfig --severity HIGH,CRITICAL --format template \
  --template "@/path/to/junit.tpl" -o "$output_dir/${dirname}-security.xml"

# SARIF output
trivy fs "$dir" --scanners misconfig --severity HIGH,CRITICAL --format sarif \
  -o "$output_dir/${dirname}-security.sarif"
```

Native output flags used — no post-processing or format conversion.

## File Organization

The script is a single file. No library files. No sourced dependencies.

```
<any-terraform-repo>/
├── .test-terraform.conf    ← optional config (shell-sourceable)
├── .tflint.hcl             ← optional tflint config (auto-detected)
├── test-terraform.sh       ← the script (or in tests/)
├── test-results/            ← generated output directory
│   ├── <dir>-security.xml   ← JUnit XML security report
│   ├── <dir>-security.sarif ← SARIF security report
│   └── <dir>.tfplan         ← terraform plan output
├── modules/                 ← example structure (user-defined)
│   └── ...
└── tests/                   ← example structure (user-defined)
    └── ...
```

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | All steps passed |
| 1 | Secrets detected or general failure |
| 2 | Formatting issues found |
| 3 | Terraform init/validate failed |
| 4 | Deploy directory not found or invalid |
| 5 | Security scan findings (when not `--soft-fail`) |
| 6 | Plan failed |
| 7 | Apply or destroy failed |

## Design Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Single monolithic bash file | Easier to drop into any repo. No sourced dependencies to manage. Functions with section headers provide organization. |
| 2 | Terraform only, no OpenTofu | Reduces complexity. Single binary name to detect and invoke. |
| 3 | Shell-sourceable config file | No extra dependencies (jq, yq). Standard bash. Simple key=value format. |
| 4 | checkov as default scanner | Purpose-built for IaC: 1000+ Terraform-specific policies mapped to CIS/Well-Architected, graph-based cross-resource analysis, native JUnit/SARIF output without templates. Trivy is stronger for container/SBOM scanning and is faster (Go vs Python), but lacks checkov's Terraform policy depth and requires external Go templates for JUnit output. Trivy retained as toggle for teams standardized on it across their toolchain. |
| 5 | Native scanner output flags | Avoids post-processing complexity. Both checkov and trivy support JUnit and SARIF natively. |
| 6 | CWD fallback when no config | Makes the script useful out-of-the-box for simple single-module repos without requiring a config file. |
| 7 | Fail-fast for blocking steps | Matches original script behavior. Prevents wasted time validating downstream when upstream is broken. |
| 8 | Soft-fail for security scans | Dev environments often have legitimate security findings. Blocking deploys on advisory findings slows iteration. |
| 9 | Local backend state for deploy | Avoids remote state dependencies. Test deployments are ephemeral — local state is sufficient. |
| 10 | TTY detection for destroy pause | Interactive prompt for developers, timed auto-destroy for CI. Same script works in both contexts. |
| 11 | Pre-validate all directories | Fail upfront with complete list of problems rather than discovering issues mid-pipeline. |
| 12 | Credential detection before deploy only | Validation steps (fmt, init -backend=false, validate, lint) never need AWS credentials. Only check when actually deploying. |

## Tool Dependency Matrix

| Tool | Required | Auto-install | Blocking on failure |
|---|---|---|---|
| `terraform` | Yes | brew / apt / dnf | Fatal — script exits |
| `git-secrets` | No | brew / apt / dnf | Skip with warning |
| `tflint` | No | brew / apt / dnf | Findings are warnings |
| `checkov` | No (if trivy used) | pip | Skip with warning / soft-fail |
| `trivy` | No (if checkov used) | brew / apt / dnf | Skip with warning / soft-fail |

## Deployment Workflow

```
Validation only (default or --no-plan):
  fmt → init → validate → lint → security scan → [plan] → summary

Deploy (--deploy):
  fmt → init → validate → lint → security scan → plan → apply → summary

Deploy + Destroy (--deploy-destroy):
  fmt → init → validate → lint → security scan → plan → apply → pause → destroy → summary
```

## Out of Scope

- Multi-cloud providers (Azure, GCP)
- OpenTofu support
- Terragrunt wrapper support
- Remote state backend configuration
- Terratest / Go test framework integration
- Parallel directory validation
- Auto-discovery of directories
