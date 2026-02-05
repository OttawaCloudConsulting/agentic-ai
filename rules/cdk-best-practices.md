# CDK Best Practices

> Guidelines for generating correct, safe, and maintainable AWS CDK infrastructure code. Prevents common mistakes that cause data loss, security holes, and deployment failures.

## Construct Design

**Prefer L2 constructs.** L1 (Cfn*) constructs lack safe defaults and require manual security configuration. Use L2 constructs for built-in best practices, grant methods, and helper functions.

**Use L1 escape hatches, not raw L1 constructs.** When L2 doesn't expose a property:

1. Access `construct.node.defaultChild` to reach the underlying L1 construct
2. Use `addPropertyOverride()` for properties not publicly exposed
3. Only create standalone L1 constructs as a last resort

**L3 constructs: use carefully.** Create L3 constructs only when composing multiple AWS resources into a reusable unit. If not interacting with AWS resources directly, use a plain helper class instead of extending `Construct`. When creating L3 constructs, extend `Construct` directly — extend specific L2 constructs only when overriding their defaults.

**Self-contained constructs.** Bundle infrastructure and runtime code (Lambda handlers, Docker assets) in the same construct. Co-locate and co-version them.

---

## Stack Architecture

**Model with constructs, deploy with stacks.** Constructs define logical units. Stacks define deployment boundaries. Never use a Stack where a Construct is appropriate.

**Separate stateful from stateless resources.** Put databases, S3 buckets, and VPCs in dedicated stacks with termination protection enabled. Stateless compute (Lambda, ECS tasks) goes in separate stacks that can be freely destroyed and recreated.

**Don't nest stateful resources in constructs that might be renamed or moved.** Renaming a parent construct changes the logical IDs of all children, replacing stateful resources and destroying data.

**Avoid monolithic stacks.** Large stacks slow synthesis, create deployment bottlenecks, and increase blast radius. Split by domain: networking, data, compute, monitoring.

**Manage cross-stack references explicitly.** Pass construct references through props interfaces. Avoid `Fn.importValue` when stacks are in the same app — direct references are type-safe and enforce dependency ordering.

---

## Resource Identity (Critical)

**Never change the logical ID of stateful resources.** Logical IDs derive from the construct ID and its position in the construct tree. Changing either causes CloudFormation to replace the resource — deleting databases, buckets, and all their data.

Actions that silently change logical IDs:

- Renaming construct IDs
- Moving constructs to different parents
- Reordering constructs within a scope
- Wrapping constructs in new parent constructs

**Write unit tests that assert logical IDs of stateful resources remain stable.** This is your safety net against accidental refactoring damage.

**Use CDK Refactor for restructuring.** When you must rename or move resources between stacks, use the CDK Refactor feature to safely reorganize without replacement.

---

## Configuration

**Configure with properties, not environment variables.** Constructs and stacks accept props objects. Environment variable lookups inside constructs are an anti-pattern — they create machine-dependent, untestable behavior.

**Limit env var lookups to the top-level app.** Pass resolved values down through props.

**Don't use CloudFormation Parameters, Conditions, or `Fn::If`.** Make decisions at synthesis time in your programming language. CloudFormation expressions are limited and defeat the purpose of CDK.

**Commit `cdk.context.json` to version control.** Context providers cache non-deterministic lookups (AZs, AMIs, VPC info). Without the cache, deployments become non-deterministic and may break when AWS-side values change.

**Never modify AWS resources during synthesis.** Synthesis must be side-effect-free. Use Custom Resources for runtime changes.

---

## Naming

**Use generated names, not physical names.** Hardcoded `bucketName`, `tableName`, `functionName` etc. prevent:

- Deploying the same stack twice in one account
- Multi-environment deployments (dev/staging/prod)
- Resource replacement when immutable properties change

Pass generated names to consumers via environment variables, SSM Parameter Store, or construct references.

**Exception:** Resources that must have stable names for external integration (e.g., API domain names, shared resource names) may use physical names with clear documentation of why.

---

## Security

**Use grant methods for IAM.** `bucket.grantRead(lambda)` creates least-privilege policies automatically. Never write raw IAM policy documents when a grant method exists.

**Let CDK manage roles.** Auto-created roles are scoped minimally. Predefined shared roles tend toward over-permissioning because they must cover all possible resource combinations and can't reference resources that don't exist yet.

**Enforce guardrails at multiple layers:**

1. **SCPs and permission boundaries** — organization-level controls CDK cannot bypass
2. **cdk-nag** — static analysis of constructs before deployment (AWS Solutions, NIST 800-53 rule packs)
3. **Aspects** — cross-cutting validation applied to all constructs in a stack
4. **CloudFormation Guard** — template-level validation in CI/CD pipeline

**Wrapper constructs are not compliance.** `MyCompanyBucket` with encryption defaults is useful guidance but developers can bypass it with L1 constructs or third-party constructs. Always enforce with guardrails above.

**Enable encryption.** S3 buckets, RDS instances, DynamoDB tables, EBS volumes, SNS topics, SQS queues — encrypt by default. Use `aws-cdk-lib/aws-kms` for customer-managed keys when required.

**Never hardcode secrets.** Use Secrets Manager or SSM SecureString. Reference by name or ARN, never by value.

---

## Removal Policies and Retention

**Set explicit removal policies.** CDK defaults to `RETAIN` for stateful resources (to prevent accidental data loss), which silently accumulates orphaned resources and costs.

For each stateful resource, explicitly choose:

- `RemovalPolicy.RETAIN` — production databases, critical storage
- `RemovalPolicy.SNAPSHOT` — resources that support snapshots (RDS)
- `RemovalPolicy.DESTROY` — dev/test environments, caches, replaceable data

**Set log retention.** CDK defaults to `NEVER EXPIRE` for CloudWatch Logs. Set `logRetention` on Lambda functions and explicit retention on log groups to control costs.

**Use Aspects to validate removal and retention policies across stacks.**

---

## Testing

**Unit test your infrastructure.** CDK code is code. Test it.

Required test types:

- **Assertion tests:** `Template.fromStack(stack)` with `hasResourceProperties()`, `resourceCountIs()`, `hasOutput()`
- **Logical ID stability tests:** Assert stateful resource logical IDs don't change across refactors
- **Fine-grained assertions:** Verify IAM policies, security group rules, encryption settings
- **Snapshot tests:** Catch unintended template drift (use as regression net, not primary validation)

**Avoid network lookups during synthesis.** Tests must run without AWS credentials. Mock or cache all external data.

**`Template.fromStack()` alone proves nothing.** Always follow with specific assertions about resources, properties, and counts.

---

## Deployment

**Always run `cdk diff` before deploy.** Review planned changes to catch unintended resource replacements, especially for stateful resources.

**Use CDK Pipelines for CI/CD.** Manual `cdk deploy` from developer machines creates inconsistency. Automate deployments through a pipeline with validation stages.

**Model all environments in code.** Create separate stack instances for dev, staging, and prod with environment-specific configuration baked in. Don't rely on runtime parameters.

**Explicitly specify `env` on stacks.** Leaving `env` undefined creates environment-agnostic stacks that may deploy to unintended accounts or regions.

---

## Bad Practices — Never Do These

| Practice | Why It's Dangerous |
| --- | --- |
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

---

## Monitoring and Observability

**Measure everything.** Use L2 convenience methods (`table.metricUserErrors()`, `fn.metricErrors()`) to create CloudWatch metrics, alarms, and dashboards.

**Include monitoring in your constructs.** Alarms and dashboards are infrastructure — define them alongside the resources they monitor, not as an afterthought.

**Create business-level metrics** in addition to technical metrics. Use them to automate deployment decisions like rollbacks.

---

## Project Hygiene

**One app per repository.** Multiple apps in one repo increase blast radius — changes to one app trigger deployment of all others.

**Keep CDK CLI current.** The CLI is backward-compatible with all construct library versions released before it. Pin to `2.x` range, not a specific version.

**Avoid circular dependencies between stacks.** If Stack A exports to Stack B and Stack B exports to Stack A, neither can be updated independently. Redesign the boundary.

**Clean up orphaned resources.** Stacks left behind from development, failed deployments, or `RETAIN` policies accumulate cost. Audit regularly.
