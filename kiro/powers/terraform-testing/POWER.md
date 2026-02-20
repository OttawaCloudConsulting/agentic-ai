---
name: "terraform-testing"
displayName: "Terraform Testing"
description: "Portable Terraform validation and deployment pipeline with automated tool installation"
keywords: ["terraform validate", "tflint", "checkov", "trivy"]
---

# Terraform Testing Power

Provides a portable Terraform validation and deployment pipeline that handles security scanning, linting, formatting, planning, and optionally applying/destroying infrastructure. The pipeline auto-detects the operating system and installs missing tools automatically.

Configuration is driven by `.test-terraform.conf` in the project root. The pipeline script can be invoked with various flags to control behavior (validate-only, deploy, deploy-and-destroy, scanner selection).

## Available Workflows

### Validation Pipeline

Run the full pipeline: git-secrets, fmt, init, validate, tflint, security scan (checkov or trivy), plan, and optionally apply/destroy. Includes post-test commit workflow for feature tracking.

See `steering/validation-pipeline.md` for the complete workflow.

## Onboarding

When first activated, verify:

1. The pipeline script exists at `scripts/test-terraform.sh` or `tests/test-terraform.sh`
2. Check for `.test-terraform.conf` in the project root for configuration
3. Verify `.tf` files exist in the configured test directories
