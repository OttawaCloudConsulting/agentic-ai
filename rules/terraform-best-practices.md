# Terraform Best Practices

> Guidelines for generating correct, safe, and maintainable Terraform infrastructure code. Prevents state corruption, security holes, drift, and deployment failures.

## Repository Structure

**Follow the standard file layout.** Every root module and reusable module must use this structure:

- `main.tf` — primary resource definitions; nested module calls go here
- `variables.tf` — all input variable declarations with types and descriptions
- `outputs.tf` — all output declarations referencing resource attributes
- `locals.tf` — local values for computed or repeated expressions
- `providers.tf` — provider configuration blocks (root modules only)
- `versions.tf` — `required_providers` block with version constraints
- `data.tf` — data source lookups (keep near referencing resources unless numerous)
- `terraform.tfvars` — non-sensitive default variable values
- `envs/` — environment-specific `.tfvars` files (`envs/dev/terraform.tfvars`, etc.)
- `README.md` — module purpose, usage examples, generated with `terraform-docs`

**Keep resources in `main.tf`.** Only split into service-named files (e.g., `iam.tf`) when a resource group exceeds ~150 lines. Do not split by individual resource type.

**Organize supporting files.** Scripts called by Terraform go in `scripts/`. Helper scripts go in `helpers/`. Static files go in `files/`. Templates use `.tftpl` extension and go in `templates/`.

---

## Module Design

**Don't wrap single resources.** If you struggle to name a module differently from its main resource type, the module isn't creating a useful abstraction. Use the resource directly.

**Encapsulate logical relationships.** Group related resources that together enable a capability: networking foundations, data tiers, security controls, application stacks.

**Keep inheritance flat.** Avoid nesting modules more than one or two levels deep. Deeply nested structures complicate configuration and debugging. Modules should build on other modules, not tunnel through them.

**Export at least one output per resource.** Variables and outputs let Terraform infer dependencies between modules. Without outputs, consumers cannot properly order your module.

**Don't configure providers in modules.** Shared modules inherit providers from calling modules. Never place `provider` configuration blocks inside reusable modules — declare only `required_providers` in `versions.tf`.

**Declare required providers.** Every module must declare its provider requirements with version constraints:

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Use the pessimistic constraint operator (`~>`)** for shared modules. It allows patch/minor updates while preventing breaking major version changes.

---

## State Management

**Use remote state.** Local `terraform.tfstate` files prevent collaboration, lack locking, and risk data loss. Use S3 + DynamoDB for AWS deployments:

```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-states"
    key            = "myapp/production/tfstate"
    region         = "us-east-1"
    dynamodb_table = "TerraformStateLocking"
    encrypt        = true
  }
}
```

**Enable state locking.** DynamoDB locking prevents concurrent writes that corrupt state. Never skip this.

**Enable versioning on state buckets.** S3 versioning preserves previous state snapshots for rollback and recovery.

**Separate backends per environment.** Dev, staging, and production must have isolated state files. Shared state means accidents in dev can impact production.

**Avoid shared workspaces for environment isolation.** Distinct backends per environment provide stronger isolation than Terraform workspaces.

**Never manually edit state files.** Use `terraform state mv`, `terraform state rm`, or `terraform import` for state operations. Manual edits corrupt state and cause drift.

**Monitor state access.** Enable CloudTrail on state buckets. Alert on direct state unlocks from developer workstations — all changes should flow through CI/CD.

---

## Security

**Use IAM roles, not access keys.** IAM roles provide temporary credentials that auto-rotate. Never hardcode `access_key` and `secret_key` in provider blocks or `.tfvars` files.

**Follow least privilege.** Start with an empty IAM policy, iteratively add only required actions on specific resources. Use IAM Access Analyzer to find and remove unused permissions.

**Encrypt state at rest.** Enable S3 server-side encryption (SSE) on state buckets. State files contain sensitive resource attributes in plaintext.

**Never store secrets in Terraform code or state.** Use AWS Secrets Manager or HashiCorp Vault. Reference secrets by ARN or name, never by value. Mark sensitive outputs with `sensitive = true`.

**Scan infrastructure code.** Embed static analyzers (Checkov, tfsec, TFLint) in CI/CD pipelines to catch misconfigurations before deployment. Shift security left.

**Enforce policy as code.** Use Sentinel, OPA, or CloudFormation Guard to enforce organizational guardrails: required tags, allowed instance types, encryption requirements, destruction prevention.

**Use OIDC for CI/CD authentication.** GitHub Actions, GitLab CI, and similar tools support OIDC federation with AWS — eliminating the need for stored access keys in CI/CD secrets.

---

## Variables and Configuration

**All variables must have a defined type.** Untyped variables accept anything and defeat validation.

**All variables and outputs must have descriptions.** One or two sentences explaining purpose. These are used for auto-generated documentation.

**Provide defaults for environment-independent values.** Disk sizes, instance types, and feature flags that don't change per environment should have sensible defaults.

**Omit defaults for environment-specific values.** Project IDs, VPC IDs, and account numbers must be explicitly provided by the caller.

**Don't over-parameterize.** Expose a variable only when there's a concrete use case for changing it. A variable with a remote chance of being needed adds complexity without value. Use `locals` for repeated values that shouldn't be configurable.

**Use `locals` for computed values.** Don't repeat expressions — assign them to locals. But don't expose locals as variables unless they genuinely vary per deployment.

**Don't pass outputs through input variables.** This breaks the dependency graph. Outputs must reference resource attributes directly so Terraform can infer implicit dependencies.

**Use `.tfvars` for variable values, not inline defaults.** Place common values in `terraform.tfvars` and environment-specific values in `envs/<env>/terraform.tfvars`.

---

## Naming Conventions

**Use `snake_case` for all Terraform names.** Resource names, variable names, output names, local names, module names. This matches Terraform style standards.

**Name resources by purpose, not type.** Use `main` or `this` for the sole resource of a type. Use descriptive names like `primary` and `read_replica` to distinguish multiples. Never repeat the resource type in the name.

```hcl
# Good
resource "aws_db_instance" "primary" { ... }
resource "aws_db_instance" "read_replica" { ... }

# Bad
resource "aws_db_instance" "aws_db_instance_primary" { ... }
```

**Use singular nouns.** `aws_security_group.web`, not `aws_security_group.webs`.

**Add units to numeric variables.** `ram_size_gb`, `disk_size_gib`, `timeout_seconds`. Use binary units (MiB, GiB) for storage, decimal (MB, GB) for other metrics.

**Use positive names for booleans.** `enable_external_access`, not `disable_external_access` or `no_external_access`.

---

## Resource Patterns

**Use attachment resources over embedded attributes.** Inline blocks (e.g., `ingress` in `aws_security_group`) create cause-and-effect issues. Prefer standalone attachment resources (e.g., `aws_security_group_rule`).

**Use `default_tags` in the provider.** Apply organization-standard tags to all resources automatically:

```hcl
provider "aws" {
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "terraform"
    }
  }
}
```

**Recommended tags:** `Name`, `Environment`, `Project`, `CostCenter`, `AppId`, `AppRole`, `ManagedBy`.

**Use `lifecycle` blocks deliberately.** `prevent_destroy` protects critical resources. `create_before_destroy` prevents downtime. `ignore_changes` suppresses expected external drift. Document why each lifecycle rule exists.

**Avoid `terraform_data` and provisioners when native resources exist.** Provisioners (`local-exec`, `remote-exec`) are a last resort. Check for native provider support first.

---

## Version Management

**Pin provider versions.** Unpinned versions create non-deterministic builds. Use the pessimistic constraint operator for flexibility with safety:

```hcl
aws = {
  source  = "hashicorp/aws"
  version = "~> 5.0"
}
```

**Pin module versions.** Always specify a version when sourcing modules from registries or VCS:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"
}
```

**Pin Terraform CLI version.** Use `required_version` in the `terraform` block and `tfenv` for local version management.

**Upgrade in non-production first.** Test provider and module upgrades in dev/test before promoting to production. Review changelogs for breaking changes.

**Add automated version checks in CI/CD.** Fail builds when provider versions are unpinned or undefined.

---

## Testing and Validation

**Run `terraform fmt -check` on every commit.** Enforce consistent formatting. Configure as a pre-commit hook.

**Run `terraform validate` after init.** Catches syntax errors and invalid configurations before plan.

**Run TFLint in CI/CD.** Checks for best practice violations, deprecated syntax, unused declarations, and AWS-specific errors beyond what `validate` catches.

**Run security scans (Checkov, tfsec) before apply.** Catch encryption gaps, overly permissive security groups, public S3 buckets, and other misconfigurations.

**Write automated tests for modules.** Use Terratest or the Terraform test framework to validate module behavior. Test that resources are created with expected properties.

**Always run `terraform plan` before apply.** Review the plan output. Never blindly apply. In CI/CD, save the plan (`-out=tfplan`) and apply the exact saved plan.

---

## Deployment Safety

**Use CI/CD pipelines for all deployments.** Manual `terraform apply` from developer machines creates inconsistency, lacks audit trails, and bypasses approval gates.

**Separate plan and apply permissions.** Plan requires read-only API access. Apply requires write access. Restrict who and what can trigger applies, especially in production.

**Review plan output for destructive changes.** Watch for `destroy` and `replace` actions on stateful resources. These indicate data loss risk.

**Use `-target` sparingly.** Targeted applies create partial state that can diverge from configuration. Use only for emergency fixes, then run a full plan/apply to reconcile.

**Never run `terraform destroy` without explicit confirmation.** Especially in production. Protect critical stacks with `lifecycle { prevent_destroy = true }`.

**Implement drift detection.** Compare Terraform state against actual infrastructure regularly. Surface unauthorized changes and either remediate or reconcile.

---

## Community Modules

**Search before building.** Check the Terraform Registry and GitHub for existing modules before writing from scratch. Favor verified, actively maintained modules with recent updates.

**Use variables to customize, don't fork.** Override module defaults through input variables. Fork only to contribute fixes upstream.

**Audit module dependencies.** Review required providers, nested modules, and external data sources before adopting a module. Map the full dependency tree.

**Use trusted sources.** Favor certified modules from verified publishers (AWS, HashiCorp partners). Review publisher history and usage reputation for others.

**Pin commit hashes for Git-sourced modules.** Registry modules use semantic versions, but Git-sourced modules should pin to a specific commit hash to prevent supply chain attacks:

```hcl
source = "github.com/org/module.git?ref=abc123def456"
```

---

## Bad Practices — Never Do These

| Practice | Why It's Dangerous |
| --- | --- |
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

---

## Monitoring and Drift

**Enable drift detection.** Use your IaC platform or scheduled `terraform plan` runs to detect infrastructure changes made outside Terraform.

**Monitor state bucket activity.** CloudTrail logging on S3 state buckets creates audit trails for all state operations.

**Alert on direct state changes.** State modifications that bypass CI/CD (manual unlocks, direct applies) indicate process violations or compromised credentials.

**Track resource costs with tags.** Use `CostCenter` and `Project` tags to enable cost attribution. Monitor for orphaned resources from failed deployments.

---

## Project Hygiene

**Use `.gitignore` for Terraform artifacts.** Exclude `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfplan`, and `crash.log`.

**Configure pre-commit hooks.** Run `terraform fmt`, `terraform validate`, TFLint, and Checkov before every commit. Use the `pre-commit` framework.

**Generate documentation automatically.** Use `terraform-docs` to keep README input/output tables current. Never manually maintain variable documentation.

**Follow registry naming for shareable modules.** Use the format `terraform-<PROVIDER>-<NAME>` (e.g., `terraform-aws-vpc`). Meet Terraform Registry requirements even if not publishing immediately.

**Clean up unused resources.** Terraform state can accumulate resources from failed applies, abandoned experiments, or `prevent_destroy` overrides. Audit regularly.

**Limit blast radius.** Structure state boundaries along service or organizational lines. Smaller state files mean faster plans, fewer resources at risk per apply, and simpler access controls.
