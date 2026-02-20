---
name: "terraform-workflow"
displayName: "Terraform Workflow"
description: "Terraform validation, deployment, and documentation refresh workflows"
keywords: ["terraform plan", "terraform apply", "tfvars", "terraform test"]
---

# Terraform Workflow Power

Provides end-to-end workflows for Terraform projects covering validation, deployment, and documentation maintenance. Activate this power when working on HCL configurations that need to be validated, deployed to an environment, or when tf documentation has drifted from the current codebase state.

## Available Workflows

### Validate and Deploy

Run sequential validation gates (format, lint, security scan, plan) and optionally deploy to a target environment. Handles the full lifecycle from code validation through apply, followed by progress tracking and commit.

See `steering/terraform-validation.md` for the complete workflow.

### Documentation Update

Refresh README.md and docs/ARCHITECTURE.md to match the current state of Terraform modules, variables, and environment layout. Use after completing features, before creating a PR, or when documentation feels stale.

See `steering/terraform-docs-update.md` for the complete workflow.

## Onboarding

When first activated, verify:

1. The workspace contains `.tf` files
2. A test script exists at `tests/test-terraform.sh` or `scripts/test-terraform.sh`
3. Check for `progress.txt` and `CHANGELOG.md` for tracking workflows
