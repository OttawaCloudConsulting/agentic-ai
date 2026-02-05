# Rules Reference

Rules are always-on behavioral guidelines loaded automatically via `.claude/rules/`. They are not commands and cannot be invoked by the user. They provide persistent context that shapes how the agent writes code, handles failures, and makes decisions.

## Quick Reference

| Rule | File | Purpose |
|---|---|---|
| Defensive Protocol | `rules/defensive-protocol.md` | Defensive epistemology for agentic coding: failure handling, prediction protocols, evidence standards |
| CDK Best Practices | `rules/cdk-best-practices.md` | AWS CDK guidelines: construct design, security, testing, deployment safety, anti-patterns |
| Terraform Best Practices | `rules/terraform-best-practices.md` | Terraform guidelines: state management, module design, security, naming, deployment safety |
| Crossplane Best Practices | `rules/crossplane-best-practices.md` | Crossplane/Upbound guidelines: XR design, compositions, managed resources, provider config |
| Crossplane v2 Best Practices | `rules/crossplane-v2-best-practices.md` | Crossplane v2 specifics: namespaced XRs, spec.crossplane, Configuration packages, migration |
| Kubernetes Best Practices | `rules/kubernetes-best-practices.md` | Kubernetes guidelines: resource management, security, RBAC, networking, high availability |

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

### Crossplane Best Practices

**File:** `rules/crossplane-best-practices.md`
**Scope:** Crossplane and Upbound projects
**Core principle:** Prevent composition errors, state corruption, API breakage, and resource leaks through correct Crossplane patterns.

This rule provides comprehensive guidelines for generating Crossplane infrastructure code. It codifies Upbound documentation, Crossplane best practices, and community-learned anti-patterns into actionable rules for AI code generation.

#### Sections

**XR Design** — Design APIs to avoid versioning. Minimize required fields. Avoid boolean fields (use enums). Default to arrays. Plan for variants. Seek external review before finalizing schemas.

**Composition Architecture** — Use Composition Functions (Pipeline mode). Copy all desired state forward in functions. Limit dynamic resource requests. Functions cannot modify XR metadata/spec. Validate function inputs.

**Managed Resources** — Set explicit deletion policies (`Delete`, `Orphan`, `ObserveOnly`). Use `Orphan` for critical resources. Understand the deletion lifecycle. Use management policies for import scenarios.

**Provider Configuration** — One ProviderConfig per account/credential set. Reference ProviderConfig explicitly in managed resources. Store credentials in Kubernetes Secrets. Use IRSA/Workload Identity where possible.

**Connection Secrets** — Publish connection details for consumer resources. Use `publishConnectionDetailsTo` for XRs. Scope connection secrets to consumer namespaces.

**Claims and Namespacing** — Use Claims for self-service. Claims are namespaced, XRs are cluster-scoped. Name Claims descriptively.

**Testing** — Use `crossplane render` for local testing. Test with Development runtime. Write unit tests for composition functions. Validate rendered output. Test API evolution.

**RBAC and Permissions** — Grant RBAC for extra resource requests. Limit provider permissions to resources actually managed.

**Versioning and Upgrades** — Pin provider versions. Test upgrades in non-production. Monitor provider health.

#### Bad Practices Table

The rule includes a consolidated table of 14 anti-patterns with explanations. Key entries:

- Not copying desired state in functions (resources silently deleted)
- Boolean fields in XR schemas (limits future API evolution)
- Required fields without careful consideration (cannot be made optional later)
- Hardcoded credentials in ProviderConfig (security exposure)
- `deletionPolicy: Delete` on production databases (accidental deletion destroys data)
- Force-deleting managed resources (orphans external resources)
- Mixing PnT and Functions for same resources (unclear ownership)

#### Sources

This rule synthesizes guidance from:

- [Upbound Documentation — Authoring Compositions](https://docs.upbound.io/build/control-plane-projects/authoring-compositions/)
- [Crossplane Documentation — Compositions](https://docs.crossplane.io/latest/composition/compositions/)
- [Mastering API Evolution: Best Practices for Crossplane XR Design](https://blog.upbound.io/crossplane-xr-best-practices)
- [Crossplane Testing: Rendering and Validating Compositions](https://blog.upbound.io/composition-testing-patterns-rendering)

---

### Crossplane v2 Best Practices

**File:** `rules/crossplane-v2-best-practices.md`
**Scope:** Crossplane v2+ projects
**Core principle:** Correctly handle v2 breaking changes, namespaced resources, spec.crossplane fields, and Configuration packages.

This rule covers Crossplane v2-specific features and migration patterns. Use alongside the general Crossplane Best Practices rule.

#### Breaking Changes from v1

- Native patch-and-transform composition removed — use Composition Functions
- `ControllerConfig` removed — use `DeploymentRuntimeConfig`
- External secret stores removed
- XR connection details removed — use functions to compose secrets
- Default registry removed — must use fully qualified package URLs

#### Key v2 Changes

**XRD Scope** — v2 defaults to `Namespaced` instead of cluster-scoped. Three options: `Namespaced` (default), `Cluster`, `LegacyCluster` (v1 compatibility with Claims support).

**spec.crossplane Structure** — All Crossplane machinery moved under `spec.crossplane`: `compositionRef`, `compositionSelector`, `compositionRevisionRef`, `compositionRevisionSelector`, `compositionUpdatePolicy`.

**Namespaced Managed Resources** — All MRs are namespaced in v2, enabling fine-grained RBAC. Cluster-scoped MRs are legacy.

**Claims Removed for v2-style XRs** — Claims only work with `scope: LegacyCluster`.

#### Configuration Packages

**crossplane.yaml format** — Metadata file with `meta.pkg.crossplane.io/v1` API, dependencies, and Crossplane version constraints.

**Fully qualified package URLs required** — No default registry in v2.

**Building and publishing** — Use `crossplane xpkg build`, `crossplane xpkg login`, and `crossplane xpkg push`.

**Dependencies** — Declare providers, functions, and other configurations with semantic version constraints.

#### XRD Versioning

- Only one version can be `referenceable: true`
- `compositeTypeRef.apiVersion` is immutable in Compositions
- Breaking changes require a new XRD, not a new version

#### Migration

1. Convert compositions: `crossplane beta convert pipeline-composition`
2. Update XRDs with appropriate `scope`
3. Update package references to fully qualified URLs
4. Test in non-production before upgrading

#### Bad Practices Table

The rule includes 11 anti-patterns specific to v2:

- Using `scope: Namespaced` expecting cross-namespace composition
- Adding breaking changes as new XRD version
- Omitting Crossplane version constraint in packages
- Using short package references without registry
- Relying on native EnvironmentConfig selection (removed)
- Expecting Claims with v2-style XRDs

#### Sources

- [Crossplane v2 What's New](https://docs.crossplane.io/latest/whats-new/)
- [Crossplane v2 XRD and Composition Version Management](https://tinfoilcipher.co.uk/2025/10/28/crossplane-v2-xrd-and-composition-version-management/)
- [Crossplane Configurations Documentation](https://docs.crossplane.io/latest/packages/configurations/)
- [Releasing Crossplane Extensions](https://docs.crossplane.io/latest/guides/extensions-release-process/)

---

### Kubernetes Best Practices

**File:** `rules/kubernetes-best-practices.md`
**Scope:** Kubernetes deployments (any distribution)
**Core principle:** Prevent security vulnerabilities, resource exhaustion, availability failures, and operational incidents through correct Kubernetes patterns.

This rule provides comprehensive guidelines for generating Kubernetes manifests. It codifies official Kubernetes documentation, CIS benchmarks, and production-learned anti-patterns into actionable rules for AI code generation.

#### Sections

**Resource Management** — Set resource requests and limits on every container. Be cautious with CPU limits (throttling). Use LimitRange for namespace defaults. Use ResourceQuota to cap namespace consumption. Understand QoS classes.

**Health Probes** — Configure readiness probes for traffic routing. Configure liveness probes for stuck process detection. Use startup probes for slow-starting applications. Keep probes independent of external dependencies.

**Pod Disruption Budgets** — Create PDBs for all production workloads. Use `minAvailable` or `maxUnavailable`. Don't set PDB too restrictively.

**Security — Pod Security** — Run containers as non-root. Use read-only root filesystem. Drop all capabilities, add only what's needed. Disable privilege escalation. Never use privileged containers.

**Security — RBAC** — Follow least privilege. Use Role/RoleBinding for namespace-scoped access. Never grant high-risk permissions (secrets list, pods/exec, nodes/proxy, escalate, bind, impersonate). Disable service account token auto-mounting. Audit RBAC regularly.

**Security — Network Policies** — Start with default deny. Allow only required traffic. Don't forget DNS egress. Test in staging first.

**Application Lifecycle** — Handle SIGTERM properly. Drain connections before exit. Use ConfigMaps for non-sensitive configuration. Mount Secrets as files, not environment variables.

**High Availability** — Run multiple replicas. Spread pods across nodes with anti-affinity. Spread across availability zones with topology constraints. Don't store state in container filesystem.

**Labels and Annotations** — Apply consistent labels (technical, business, security). Use annotations for non-identifying metadata.

**Observability** — Log to stdout/stderr. Export metrics in Prometheus format. Include request tracing.

**Image Security** — Use specific image tags. Pull from trusted registries only. Scan images for vulnerabilities. Use minimal base images.

**Namespace Organization** — Use namespaces for isolation. Apply LimitRange and ResourceQuota per namespace. Use NetworkPolicy per namespace. Don't use the `default` namespace.

**Cluster Hardening** — Run CIS Kubernetes Benchmark. Disable metadata API access from pods. Use Pod Security Admission. Prefer OIDC for user authentication.

#### Bad Practices Table

The rule includes a consolidated table of 18 anti-patterns with explanations. Key entries:

- No resource requests/limits (resource exhaustion, noisy neighbors)
- Single-replica deployments (node failure = downtime)
- Readiness probes checking external deps (cascading failures)
- Running as root (privilege escalation attacks)
- Secrets in environment variables (visible in `/proc`)
- Wildcard RBAC permissions (excessive access)
- No NetworkPolicy (unrestricted lateral movement)
- Auto-mounted service account tokens (unnecessary credential exposure)

#### Sources

This rule synthesizes guidance from:

- [Kubernetes RBAC Good Practices (official)](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
- [Kubernetes Network Policies (official)](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kubernetes Production Best Practices](https://learnkube.com/production-best-practices)
- [14 Kubernetes Best Practices You Must Know in 2025](https://komodor.com/learn/14-kubernetes-best-practices-you-must-know-in-2025/)
- [A Practical Guide to Kubernetes Security: Hardening Your Cluster in 2025](https://sealos.io/blog/a-practical-guide-to-kubernetes-security-hardening-your-cluster-in-2025)

---

## Consuming Rules

To use a rule in a target project, copy the file from `rules/` into `.claude/rules/` in the target repository:

```bash
cp rules/defensive-protocol.md             <target-repo>/.claude/rules/
cp rules/cdk-best-practices.md             <target-repo>/.claude/rules/
cp rules/terraform-best-practices.md       <target-repo>/.claude/rules/
cp rules/crossplane-best-practices.md      <target-repo>/.claude/rules/
cp rules/crossplane-v2-best-practices.md   <target-repo>/.claude/rules/
cp rules/kubernetes-best-practices.md      <target-repo>/.claude/rules/
```

Rules take effect immediately on the next Claude Code conversation in that repository.

### Choosing Rules

| Project Type | Recommended Rules |
|---|---|
| Any project | `defensive-protocol.md` |
| AWS CDK projects | `defensive-protocol.md` + `cdk-best-practices.md` |
| Terraform projects | `defensive-protocol.md` + `terraform-best-practices.md` |
| Crossplane v1 projects | `defensive-protocol.md` + `crossplane-best-practices.md` + `kubernetes-best-practices.md` |
| Crossplane v2 projects | `defensive-protocol.md` + `crossplane-best-practices.md` + `crossplane-v2-best-practices.md` + `kubernetes-best-practices.md` |
| Kubernetes projects | `defensive-protocol.md` + `kubernetes-best-practices.md` |
