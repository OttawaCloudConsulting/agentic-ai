# CDK Best Practices

**Source:** `rules/cdk-best-practices.md`
**Scope:** AWS CDK infrastructure projects (TypeScript, Python, Java, C#, Go)
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

Generate correct, safe, and maintainable AWS CDK infrastructure code. Prevent common mistakes that cause data loss, security holes, and deployment failures.

## Overview

This rule provides comprehensive guidelines for AWS CDK projects. It covers construct design, stack architecture, resource identity safety, configuration patterns, security, testing, deployment, and project hygiene. The guidelines are opinionated and designed to prevent the most common and dangerous CDK mistakes.

## Sections

### Construct Design

Establishes a hierarchy of construct preferences:

- **Prefer L2 constructs** over L1 (Cfn*) constructs. L1 constructs lack safe defaults and require manual security configuration. L2 constructs provide built-in best practices, grant methods, and helper functions.
- **Use L1 escape hatches, not raw L1 constructs.** When L2 does not expose a property: access `construct.node.defaultChild` to reach the underlying L1, use `addPropertyOverride()` for unexposed properties, and only create standalone L1 constructs as a last resort.
- **L3 constructs: use carefully.** Create L3 constructs only when composing multiple AWS resources into a reusable unit. If not interacting with AWS resources directly, use a plain helper class instead of extending `Construct`. Extend `Construct` directly rather than specific L2 constructs unless overriding their defaults.
- **Self-contained constructs.** Bundle infrastructure and runtime code (Lambda handlers, Docker assets) in the same construct. Co-locate and co-version them.

### Stack Architecture

- **Model with constructs, deploy with stacks.** Constructs define logical units; stacks define deployment boundaries. Never use a Stack where a Construct is appropriate.
- **Separate stateful from stateless resources.** Databases, S3 buckets, and VPCs go in dedicated stacks with termination protection. Stateless compute goes in separate stacks that can be freely destroyed and recreated.
- **Do not nest stateful resources in constructs that might be renamed or moved.** Renaming a parent construct changes logical IDs of all children, replacing stateful resources and destroying data.
- **Avoid monolithic stacks.** Large stacks slow synthesis, create deployment bottlenecks, and increase blast radius. Split by domain: networking, data, compute, monitoring.
- **Manage cross-stack references explicitly.** Pass construct references through props interfaces. Avoid `Fn.importValue` when stacks are in the same app — direct references are type-safe and enforce dependency ordering.

### Resource Identity (Critical)

The most dangerous section — covers how logical IDs work and how accidental changes destroy stateful resources.

- **Never change the logical ID of stateful resources.** Logical IDs derive from the construct ID and its position in the construct tree. Changing either causes CloudFormation to replace the resource — deleting databases, buckets, and all their data.
- Actions that silently change logical IDs: renaming construct IDs, moving constructs to different parents, reordering constructs within a scope, wrapping constructs in new parent constructs.
- **Write unit tests that assert logical IDs of stateful resources remain stable.** This is the safety net against accidental refactoring damage.
- **Use CDK Refactor for restructuring.** When resources must be renamed or moved between stacks, use CDK Refactor to safely reorganize without replacement.

### Configuration

- **Configure with properties, not environment variables.** Environment variable lookups inside constructs create machine-dependent, untestable behavior.
- **Limit env var lookups to the top-level app.** Pass resolved values down through props.
- **Do not use CloudFormation Parameters, Conditions, or `Fn::If`.** Make decisions at synthesis time in the programming language.
- **Commit `cdk.context.json` to version control.** Context providers cache non-deterministic lookups. Without the cache, deployments become non-deterministic.
- **Never modify AWS resources during synthesis.** Synthesis must be side-effect-free. Use Custom Resources for runtime changes.

### Naming

- **Use generated names, not physical names.** Hardcoded `bucketName`, `tableName`, `functionName` prevent deploying the same stack twice, multi-environment deployments, and resource replacement when immutable properties change.
- Pass generated names to consumers via environment variables, SSM Parameter Store, or construct references.
- **Exception:** Resources requiring stable names for external integration may use physical names with documentation of why.

### Security

- **Use grant methods for IAM.** `bucket.grantRead(lambda)` creates least-privilege policies automatically. Never write raw IAM policy documents when a grant method exists.
- **Let CDK manage roles.** Auto-created roles are scoped minimally. Predefined shared roles tend toward over-permissioning.
- **Enforce guardrails at multiple layers:** SCPs and permission boundaries, cdk-nag (static analysis with AWS Solutions and NIST 800-53 rule packs), Aspects (cross-cutting validation), and CloudFormation Guard (template-level validation in CI/CD).
- **Wrapper constructs are not compliance.** Developers can bypass `MyCompanyBucket` with L1 or third-party constructs. Always enforce with guardrails.
- **Enable encryption** on S3, RDS, DynamoDB, EBS, SNS, SQS — by default. Use KMS for customer-managed keys when required.
- **Never hardcode secrets.** Use Secrets Manager or SSM SecureString. Reference by name or ARN, never by value.

### Removal Policies and Retention

- **Set explicit removal policies** on every stateful resource. CDK defaults to `RETAIN`, which silently accumulates orphaned resources and costs.
- Three options: `RETAIN` for production databases, `SNAPSHOT` for resources supporting snapshots, `DESTROY` for dev/test environments.
- **Set log retention.** CDK defaults to `NEVER EXPIRE` for CloudWatch Logs. Set `logRetention` on Lambda functions.
- **Use Aspects to validate removal and retention policies across stacks.**

### Testing

Required test types:

- **Assertion tests:** `Template.fromStack(stack)` with `hasResourceProperties()`, `resourceCountIs()`, `hasOutput()`.
- **Logical ID stability tests:** Assert stateful resource logical IDs do not change across refactors.
- **Fine-grained assertions:** Verify IAM policies, security group rules, encryption settings.
- **Snapshot tests:** Catch unintended template drift (use as regression net, not primary validation).

Additional guidelines: avoid network lookups during synthesis (tests must run without AWS credentials), and `Template.fromStack()` alone proves nothing — always follow with specific assertions.

### Deployment

- **Always run `cdk diff` before deploy.** Review planned changes to catch unintended resource replacements.
- **Use CDK Pipelines for CI/CD.** Manual `cdk deploy` from developer machines creates inconsistency.
- **Model all environments in code.** Separate stack instances for dev, staging, and prod with environment-specific configuration.
- **Explicitly specify `env` on stacks.** Leaving `env` undefined creates environment-agnostic stacks that may deploy to unintended accounts or regions.

### Monitoring and Observability

- **Measure everything** using L2 convenience methods (`table.metricUserErrors()`, `fn.metricErrors()`).
- **Include monitoring in constructs.** Alarms and dashboards are infrastructure — define them alongside the resources they monitor.
- **Create business-level metrics** in addition to technical metrics for deployment decisions like rollbacks.

### Project Hygiene

- **One app per repository.** Multiple apps increase blast radius.
- **Keep CDK CLI current.** Pin to `2.x` range, not a specific version.
- **Avoid circular dependencies between stacks.** If Stack A exports to Stack B and vice versa, neither can be updated independently.
- **Clean up orphaned resources.** Audit regularly for resources from failed deployments or `RETAIN` policies.

## Bad Practices

| Practice | Why It's Dangerous |
|---|---|
| `git add .` with CDK projects | Commits `cdk.out/`, secrets, and generated files |
| Hardcoded resource names | Prevents multi-deploy, blocks replacement |
| `new CfnBucket()` when `new s3.Bucket()` exists | Loses safe defaults, grants, encryption |
| `process.env.*` inside constructs | Machine-dependent, breaks tests, non-deterministic |
| Renaming/moving constructs without checking IDs | Silently destroys stateful resources |
| `iam.PolicyStatement({ actions: ['*'], resources: ['*'] })` | Violates least privilege, security risk |
| Skipping `cdk diff` | Deploys blind, misses resource replacements |
| One massive stack for everything | Slow deploys, huge blast radius, coupled resources |
| Sharing mutable state between stacks via SSM at synth time | Non-deterministic, order-dependent failures |
| Ignoring cdk-nag warnings | Shipping known security and compliance violations |
| `RemovalPolicy.DESTROY` on production databases | One bad deploy deletes all data |
| Manual `cdk deploy` to production | No audit trail, no approval, no rollback strategy |
| Modifying AWS resources during synthesis | Side effects during synth are invisible and unrollable |
| Using CloudFormation `Parameters` for config | Defeats type safety and testability of CDK |
| Not pinning construct library versions | Surprise breaking changes in CI/CD |

## Related Rules

- `rules/terraform-best-practices.md` — Alternative IaC tool guidelines. Useful when evaluating CDK vs. Terraform approaches.
- `rules/kubernetes-best-practices.md` — Often used alongside CDK for EKS-based deployments.
