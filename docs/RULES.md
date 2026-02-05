# Rules Reference

Rules are always-on behavioral guidelines loaded automatically via `.claude/rules/`. They are not commands and cannot be invoked by the user. They provide persistent context that shapes how the agent writes code, handles failures, and makes decisions.

## Quick Reference

| Rule | File | Purpose |
|---|---|---|
| Defensive Protocol | `rules/defensive-protocol.md` | Defensive epistemology for agentic coding: failure handling, prediction protocols, evidence standards |
| CDK Best Practices | `rules/cdk-best-practices.md` | AWS CDK guidelines: construct design, security, testing, deployment safety, anti-patterns |
| Terraform Best Practices | `rules/terraform-best-practices.md` | Terraform guidelines: state management, module design, security, naming, deployment safety |

## How Rules Work

- Rules live in `rules/` at the repository root (drop-in source)
- Consumers copy them to `.claude/rules/` in their target project
- Claude Code loads all `.md` files in `.claude/rules/` automatically on every conversation
- Rules have no YAML frontmatter — they are pure content
- One concern per file

### Rules vs Skills

| | Rules | Skills |
|---|---|---|
| Location | `.claude/rules/` | `.claude/commands/` |
| Activation | Automatic (always loaded) | Manual (`/skill-name`) |
| Purpose | Behavioral guidelines | Action workflows |
| Frontmatter | None | Required (name, description) |
| User-facing | No | Yes |

---

## Rule Details

### Defensive Protocol

**File:** `rules/defensive-protocol.md`
**Scope:** All project types
**Core principle:** Reality is the arbiter. When observations contradict your model, your model is wrong.

This rule establishes epistemic discipline for agentic AI coding sessions. It prevents the primary failure mode of AI agents: compounding unverified assumptions across many actions.

#### Key Protocols

**Prediction Protocol** — Before any action that could fail, make reasoning visible with explicit `DOING / EXPECT / IF MATCH / IF MISMATCH` blocks. After the action, record `RESULT / MATCH / THEREFORE`. This creates an audit trail that catches errors before they compound.

**Failure Response** — When anything fails: STOP (no retry), REPORT (exact error + theory + proposed action), WAIT (get user confirmation). Silent retry destroys signal.

**Confusion Response** — When surprised by an outcome: stop, identify which belief was falsified, log the correction. "This should work" means the model is wrong, not reality.

**Evidence Standards** — Distinguish beliefs (unverified theories) from verified facts (tested, observed, have evidence). "I don't know" is a valid output.

**Verification Cadence** — Batch size of 3 actions, then checkpoint with observable verification. More than 5 actions without verification = accumulated unjustified beliefs.

**Context Window Management** — Every ~10 actions in long tasks, review the original goal, verify current understanding, and write state to memory. Detects context degradation before it causes errors.

#### Additional Concerns

| Concern | Guideline |
|---|---|
| Investigation | Maintain 3+ competing hypotheses. Separate FACTS from THEORIES. |
| Root Cause Analysis | Fix immediate cause, but also identify systemic and root causes. |
| Chesterton's Fence | Articulate why something exists before removing it. |
| Error Handling | Silent fallbacks convert hard failures into silent corruption. Let it crash. |
| Abstraction Timing | Need 3 real examples before abstracting. |
| Autonomy Boundaries | Evaluate confidence, blast radius, reversibility before acting without asking. |
| Contradiction Handling | Surface conflicts between instructions; don't silently pick one. |
| Pushing Back | Push back with evidence when a request contradicts stated goals. |
| Irreversible Actions | Extra caution for database schemas, public APIs, data deletion, git history. |
| Handoff | Write state (done, blockers, open questions, recommendations, files touched). |

---

### CDK Best Practices

**File:** `rules/cdk-best-practices.md`
**Scope:** AWS CDK projects (TypeScript, Python, Java, C#, Go)
**Core principle:** Prevent data loss, security holes, and deployment failures through correct CDK patterns.

This rule provides comprehensive guidelines for generating AWS CDK infrastructure code. It codifies official AWS best practices, prescriptive guidance, and community-learned anti-patterns into actionable rules for AI code generation.

#### Sections

**Construct Design** — Prefer L2 constructs over L1. Use escape hatches (`node.defaultChild`, `addPropertyOverride`) instead of dropping to raw L1 constructs. Create L3 constructs only for multi-resource compositions. Bundle infrastructure and runtime code in the same construct.

**Stack Architecture** — Model with constructs, deploy with stacks. Separate stateful resources (databases, buckets) from stateless resources (Lambda, ECS) into different stacks. Enable termination protection on stateful stacks. Avoid monolithic stacks.

**Resource Identity** — Never change the logical ID of stateful resources. Renaming construct IDs, moving constructs to different parents, or wrapping them in new parents all silently change logical IDs, causing CloudFormation to replace (delete + recreate) the resource. Write unit tests asserting logical ID stability.

**Configuration** — Configure via props, not environment variables. Limit env var lookups to the top-level app. Avoid CloudFormation Parameters and Conditions. Commit `cdk.context.json` to version control. Never modify AWS resources during synthesis.

**Naming** — Use CDK-generated resource names by default. Hardcoded names prevent multi-environment deployment and block resource replacement.

**Security** — Use grant methods for IAM (`bucket.grantRead(lambda)`). Enforce compliance at multiple layers: SCPs, permission boundaries, cdk-nag, Aspects, CloudFormation Guard. Wrapper constructs are guidance, not enforcement. Enable encryption on all data stores. Never hardcode secrets.

**Removal Policies and Retention** — Set explicit removal policies on every stateful resource. Set log retention on Lambda functions and log groups to control costs. Use Aspects to validate policies across stacks.

**Testing** — Write assertion tests with `Template.fromStack()` plus `hasResourceProperties()`, `resourceCountIs()`, etc. Test logical ID stability. Avoid network lookups during synthesis. `Template.fromStack()` alone proves nothing.

**Deployment** — Always run `cdk diff` before deploy. Use CDK Pipelines for CI/CD. Model all environments in code. Explicitly specify `env` on stacks.

**Monitoring** — Use L2 metric convenience methods. Include alarms and dashboards in constructs alongside the resources they monitor. Create business-level metrics for automated rollback decisions.

**Project Hygiene** — One app per repository. Keep CDK CLI current. Avoid circular stack dependencies. Audit orphaned resources regularly.

#### Bad Practices Table

The rule includes a consolidated table of 15 anti-patterns with explanations of why each is dangerous. Key entries:

- Hardcoded resource names (prevents multi-deploy, blocks replacement)
- Using L1 when L2 exists (loses safe defaults, grants, encryption)
- `process.env` inside constructs (non-deterministic, breaks tests)
- Renaming/moving constructs without checking IDs (destroys stateful resources)
- Wildcard IAM policies (violates least privilege)
- Skipping `cdk diff` (deploys blind)
- `RemovalPolicy.DESTROY` on production databases (one bad deploy deletes all data)
- Manual `cdk deploy` to production (no audit trail or rollback)

#### Sources

This rule synthesizes guidance from:

- [AWS CDK Best Practices (official)](https://docs.aws.amazon.com/cdk/v2/guide/best-practices.html)
- [AWS CDK Security Best Practices](https://docs.aws.amazon.com/cdk/v2/guide/best-practices-security.html)
- [AWS Prescriptive Guidance — CDK TypeScript IaC](https://docs.aws.amazon.com/prescriptive-guidance/latest/best-practices-cdk-typescript-iac/introduction.html)
- [AWS Prescriptive Guidance — CDK Construct Layers](https://docs.aws.amazon.com/prescriptive-guidance/latest/aws-cdk-layers/best-practices.html)

---

### Terraform Best Practices

**File:** `rules/terraform-best-practices.md`
**Scope:** Terraform projects (HCL, any provider, primarily AWS)
**Core principle:** Prevent state corruption, security holes, drift, and deployment failures through correct Terraform patterns.

This rule provides comprehensive guidelines for generating Terraform infrastructure code. It codifies AWS Prescriptive Guidance, HashiCorp best practices, and community-learned anti-patterns into actionable rules for AI code generation.

#### Sections

**Repository Structure** — Standard file layout (`main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `providers.tf`, `versions.tf`). Keep resources in `main.tf`, split only when exceeding ~150 lines. Organize supporting files in `scripts/`, `helpers/`, `files/`, `templates/`.

**Module Design** — Don't wrap single resources. Encapsulate logical relationships. Keep inheritance flat (max 1-2 levels). Export at least one output per resource. Don't configure providers in modules — only declare `required_providers`.

**State Management** — Use remote state (S3 + DynamoDB). Enable state locking and versioning. Separate backends per environment. Never manually edit state files. Monitor state access via CloudTrail.

**Security** — Use IAM roles, not access keys. Follow least privilege. Encrypt state at rest. Never store secrets in code or state. Scan with Checkov/tfsec/TFLint. Enforce policy as code (Sentinel, OPA). Use OIDC for CI/CD authentication.

**Variables and Configuration** — All variables need types and descriptions. Provide defaults for environment-independent values, omit for environment-specific. Don't over-parameterize. Use locals for computed values. Don't pass outputs through input variables.

**Naming Conventions** — `snake_case` for everything. Name resources by purpose, not type. Singular nouns. Units on numeric variables. Positive names for booleans.

**Resource Patterns** — Attachment resources over embedded attributes. `default_tags` in the provider. Deliberate `lifecycle` blocks. Avoid provisioners when native resources exist.

**Version Management** — Pin providers with `~>`. Pin module versions explicitly. Pin Terraform CLI version. Upgrade in non-production first. Automate version checks in CI/CD.

**Testing and Validation** — `terraform fmt -check` on every commit. `terraform validate` after init. TFLint and security scans in CI/CD. Automated module tests. Always review plan before apply.

**Deployment Safety** — CI/CD pipelines for all deployments. Separate plan/apply permissions. Review destructive changes. Use `-target` sparingly. Protect critical resources with `prevent_destroy`. Implement drift detection.

**Community Modules** — Search before building. Customize via variables, don't fork. Audit dependencies. Use trusted sources. Pin commit hashes for Git-sourced modules.

**Monitoring and Drift** — Drift detection via scheduled plans. CloudTrail on state buckets. Alert on bypassed CI/CD. Track costs with tags.

**Project Hygiene** — `.gitignore` for Terraform artifacts. Pre-commit hooks. Auto-generate docs with `terraform-docs`. Follow registry naming. Limit blast radius with state boundaries.

#### Bad Practices Table

The rule includes a consolidated table of 17 anti-patterns with explanations. Key entries:

- Local state files for team projects (no locking, no backup, state loss)
- Hardcoded credentials in provider blocks (exposed in VCS)
- Secrets in `.tfvars` or HCL (plaintext in repos and state)
- Unpinned provider/module versions (non-deterministic builds)
- `terraform apply` without reviewing plan (blind deployment)
- Manual `terraform apply` to production (no audit trail)
- Single-resource wrapper modules (unnecessary abstraction)
- Manual state file edits (corruption, drift)
- Wildcard IAM policies (violates least privilege)
- `terraform destroy` without safeguards (deletes all infrastructure)

#### Sources

This rule synthesizes guidance from:

- [AWS Prescriptive Guidance — Terraform AWS Provider Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/introduction.html)
- [AWS Prescriptive Guidance — Code Structure and Organization](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html)
- [HashiCorp — Terraform Recommended Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)
- [10 Most Common Mistakes Using Terraform](https://blog.pipetail.io/posts/2020-10-29-most-common-mistakes-terraform/)
- [Terraform Anti-Patterns: Practices to Steer Clear Of](https://reaverops.medium.com/terraform-anti-patterns-practices-to-steer-clear-of-b7ce2784e85d)

---

## Consuming Rules

To use a rule in a target project, copy the file from `rules/` into `.claude/rules/` in the target repository:

```bash
cp rules/defensive-protocol.md       <target-repo>/.claude/rules/
cp rules/cdk-best-practices.md       <target-repo>/.claude/rules/
cp rules/terraform-best-practices.md  <target-repo>/.claude/rules/
```

Rules take effect immediately on the next Claude Code conversation in that repository.

### Choosing Rules

| Project Type | Recommended Rules |
|---|---|
| Any project | `defensive-protocol.md` |
| AWS CDK projects | `defensive-protocol.md` + `cdk-best-practices.md` |
| Terraform projects | `defensive-protocol.md` + `terraform-best-practices.md` |
