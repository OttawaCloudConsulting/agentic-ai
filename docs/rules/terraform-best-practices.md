# Terraform Best Practices

**Source:** `rules/terraform-best-practices.md`
**Scope:** Terraform/OpenTofu infrastructure projects across all cloud providers
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

Generate correct, safe, and maintainable Terraform infrastructure code. Prevent state corruption, security holes, drift, and deployment failures.

## Overview

This rule provides comprehensive guidelines for Terraform projects. It covers repository structure, module design, state management, security, variables, naming conventions, resource patterns, version management, testing, deployment safety, community modules, monitoring, and project hygiene. The guidelines apply across all cloud providers and are designed to prevent the most common and dangerous Terraform mistakes.

## Sections

### Repository Structure

Defines the standard file layout every root module and reusable module must use:

- `main.tf` — primary resource definitions and nested module calls.
- `variables.tf` — all input variable declarations with types and descriptions.
- `outputs.tf` — all output declarations referencing resource attributes.
- `locals.tf` — local values for computed or repeated expressions.
- `providers.tf` — provider configuration blocks (root modules only).
- `versions.tf` — `required_providers` block with version constraints.
- `data.tf` — data source lookups.
- `terraform.tfvars` — non-sensitive default variable values.
- `envs/` — environment-specific `.tfvars` files.
- `README.md` — module purpose and usage examples, generated with `terraform-docs`.

Resources stay in `main.tf` unless a resource group exceeds approximately 150 lines, in which case it splits into service-named files. Scripts go in `scripts/`, helpers in `helpers/`, static files in `files/`, and templates use `.tftpl` extension in `templates/`.

### Module Design

- **Do not wrap single resources.** If you struggle to name a module differently from its main resource type, the module is not creating a useful abstraction.
- **Encapsulate logical relationships.** Group related resources that together enable a capability.
- **Keep inheritance flat.** Avoid nesting modules more than one or two levels deep.
- **Export at least one output per resource.** Outputs let Terraform infer dependencies between modules.
- **Do not configure providers in modules.** Shared modules inherit providers from calling modules. Only declare `required_providers` in `versions.tf`.
- **Declare required providers** with version constraints using the pessimistic constraint operator (`~>`) for shared modules.

### State Management

- **Use remote state.** Local state files prevent collaboration, lack locking, and risk data loss. Recommends S3 + DynamoDB for AWS.
- **Enable state locking.** DynamoDB locking prevents concurrent writes that corrupt state.
- **Enable versioning on state buckets.** Preserves previous state snapshots for rollback and recovery.
- **Separate backends per environment.** Dev, staging, and production must have isolated state files.
- **Avoid shared workspaces for environment isolation.** Distinct backends provide stronger isolation than Terraform workspaces.
- **Never manually edit state files.** Use `terraform state mv`, `terraform state rm`, or `terraform import`.
- **Monitor state access.** Enable CloudTrail on state buckets and alert on direct state unlocks from developer workstations.

### Security

- **Use IAM roles, not access keys.** Never hardcode `access_key` and `secret_key` in provider blocks or `.tfvars` files.
- **Follow least privilege.** Start with an empty IAM policy, iteratively add required actions. Use IAM Access Analyzer.
- **Encrypt state at rest.** Enable SSE on state buckets — state files contain sensitive resource attributes in plaintext.
- **Never store secrets in Terraform code or state.** Use Secrets Manager or Vault. Mark sensitive outputs with `sensitive = true`.
- **Scan infrastructure code.** Embed Checkov, tfsec, and TFLint in CI/CD pipelines.
- **Enforce policy as code.** Use Sentinel, OPA, or CloudFormation Guard for organizational guardrails.
- **Use OIDC for CI/CD authentication.** Eliminates the need for stored access keys in CI/CD secrets.

### Variables and Configuration

- **All variables must have a defined type.** Untyped variables accept anything and defeat validation.
- **All variables and outputs must have descriptions.** Used for auto-generated documentation.
- **Provide defaults for environment-independent values.** Disk sizes, instance types, feature flags.
- **Omit defaults for environment-specific values.** Project IDs, VPC IDs, account numbers.
- **Do not over-parameterize.** Expose a variable only when there is a concrete use case. Use `locals` for repeated values that should not be configurable.
- **Use `locals` for computed values.** Do not repeat expressions.
- **Do not pass outputs through input variables.** This breaks the dependency graph.
- **Use `.tfvars` for variable values, not inline defaults.**

### Naming Conventions

- **Use `snake_case`** for all Terraform names (resources, variables, outputs, locals, modules).
- **Name resources by purpose, not type.** Use `main` or `this` for the sole resource of a type. Use descriptive names like `primary` and `read_replica` for multiples. Never repeat the resource type in the name.
- **Use singular nouns.**
- **Add units to numeric variables.** `ram_size_gb`, `disk_size_gib`, `timeout_seconds`. Use binary units for storage, decimal for other metrics.
- **Use positive names for booleans.** `enable_external_access`, not `disable_external_access`.

### Resource Patterns

- **Use attachment resources over embedded attributes.** Inline blocks create cause-and-effect issues. Prefer standalone attachment resources.
- **Use `default_tags` in the provider.** Apply organization-standard tags automatically. Recommended tags: `Name`, `Environment`, `Project`, `CostCenter`, `AppId`, `AppRole`, `ManagedBy`.
- **Use `lifecycle` blocks deliberately.** `prevent_destroy` protects critical resources, `create_before_destroy` prevents downtime, `ignore_changes` suppresses expected external drift. Document why each rule exists.
- **Avoid `terraform_data` and provisioners when native resources exist.** Provisioners are a last resort.

### Version Management

- **Pin provider versions** using the pessimistic constraint operator.
- **Pin module versions** when sourcing from registries or VCS.
- **Pin Terraform CLI version** using `required_version` and `tfenv` for local management.
- **Upgrade in non-production first.** Review changelogs for breaking changes.
- **Add automated version checks in CI/CD.** Fail builds when provider versions are unpinned or undefined.

### Testing and Validation

- **Run `terraform fmt -check` on every commit.** Configure as a pre-commit hook.
- **Run `terraform validate` after init.** Catches syntax errors and invalid configurations.
- **Run TFLint in CI/CD.** Checks for best practice violations and AWS-specific errors.
- **Run security scans (Checkov, tfsec) before apply.**
- **Write automated tests for modules.** Use Terratest or the Terraform test framework.
- **Always run `terraform plan` before apply.** Save the plan (`-out=tfplan`) and apply the exact saved plan in CI/CD.

### Deployment Safety

- **Use CI/CD pipelines for all deployments.** Manual `terraform apply` lacks audit trails and bypasses approval gates.
- **Separate plan and apply permissions.** Plan requires read-only; apply requires write access.
- **Review plan output for destructive changes.** Watch for `destroy` and `replace` actions on stateful resources.
- **Use `-target` sparingly.** Targeted applies create partial state. Use only for emergencies, then reconcile with a full plan/apply.
- **Never run `terraform destroy` without explicit confirmation.** Protect critical stacks with `lifecycle { prevent_destroy = true }`.
- **Implement drift detection.** Compare state against actual infrastructure regularly.

### Community Modules

- **Search before building.** Check the Terraform Registry and GitHub for existing modules.
- **Use variables to customize, do not fork.** Fork only to contribute fixes upstream.
- **Audit module dependencies.** Review required providers, nested modules, and external data sources.
- **Use trusted sources.** Favor certified modules from verified publishers.
- **Pin commit hashes for Git-sourced modules.** Prevents supply chain attacks.

### Monitoring and Drift

- **Enable drift detection** using scheduled `terraform plan` runs.
- **Monitor state bucket activity** with CloudTrail logging.
- **Alert on direct state changes** that bypass CI/CD.
- **Track resource costs with tags** for cost attribution and orphaned resource monitoring.

### Project Hygiene

- **Use `.gitignore`** for `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfplan`, and `crash.log`.
- **Configure pre-commit hooks** with `terraform fmt`, `terraform validate`, TFLint, and Checkov.
- **Generate documentation automatically** with `terraform-docs`.
- **Follow registry naming for shareable modules:** `terraform-<PROVIDER>-<NAME>`.
- **Clean up unused resources** from failed applies, abandoned experiments, or `prevent_destroy` overrides.
- **Limit blast radius** by structuring state boundaries along service or organizational lines.

## Bad Practices

| Practice | Why It's Dangerous |
|---|---|
| Local state files for team projects | No locking, no backup, no collaboration, state loss |
| Hardcoded `access_key`/`secret_key` in provider blocks | Credentials exposed in version control |
| Secrets in `.tfvars` or HCL files | Plaintext secrets in repos and state |
| Unpinned provider/module versions | Non-deterministic builds, surprise breaking changes |
| `terraform apply` without reviewing plan | Blind deployment, unintended resource destruction |
| Manual `terraform apply` to production | No audit trail, no approval gates, no rollback |
| Single resource wrapper modules | Unnecessary abstraction, added complexity for no value |
| Deeply nested module hierarchies (3+ levels) | Hard to debug, hard to reuse, hard to understand |
| Embedded attributes instead of attachment resources | Cause-and-effect ordering issues, hard to manage |
| `terraform destroy` on production without safeguards | Deletes all managed infrastructure |
| Manual state file edits | State corruption, drift, orphaned resources |
| `git add .` with Terraform projects | Commits `.terraform/`, state files, secrets, lock files |
| `actions: ["*"]` in IAM policies | Violates least privilege, excessive blast radius |
| Shared Terraform workspaces for environment isolation | Weak isolation, cross-environment blast radius |
| Using provisioners when native resources exist | Unmanaged state, unreliable execution, no rollback |
| Overcomplicating with `for_each`/`dynamic` in root modules | Sacrifices readability for minor boilerplate reduction |
| No `.gitignore` for Terraform artifacts | `.terraform/`, `*.tfstate`, `*.tfplan` leak into VCS |

## Related Rules

- `rules/cdk-best-practices.md` — Alternative IaC tool guidelines for AWS CDK projects.
- `rules/crossplane-v1-best-practices.md` — Kubernetes-native IaC alternative using Crossplane.
- `rules/crossplane-v2-best-practices.md` — Crossplane v2-specific features and migration patterns.
