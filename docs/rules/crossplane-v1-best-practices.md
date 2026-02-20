# Crossplane v1 Best Practices

**Source:** `rules/crossplane-v1-best-practices.md`
**Scope:** Crossplane v1 infrastructure projects — for v2, use `crossplane-v2-best-practices`
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

Generate correct, safe, and maintainable Crossplane v1 infrastructure code. Prevent composition errors, state corruption, API breakage, and resource leaks.

## Overview

This rule provides comprehensive guidelines for Crossplane v1 projects. It covers XR (Composite Resource) design, Composition architecture using Functions, managed resource configuration, provider setup, connection secrets, Claims, testing, RBAC, versioning, observability, and project structure. The guidelines target Crossplane v1 specifically — a companion rule covers v2 features and migration.

## Sections

### XR (Composite Resource) Design

Focuses on designing future-proof API schemas that minimize the need for versioning:

- **Design APIs to avoid versioning.** Kubernetes Deployment v1 has evolved for 7+ years without requiring v2. Invest upfront in future-proof schemas.
- **Understand versioning constraints.** Multiple CRD versions represent different views of identical underlying data. Due to round-tripping: you can rename and relocate fields, but you cannot remove required fields from old versions or introduce new mandatory fields absent in earlier versions.
- **Minimize required fields.** Any required field becomes permanent. Prefer optional fields with sensible defaults.
- **Avoid boolean fields.** Replace booleans with string enums. `fast: true` limits future expansion; `speed: Regular|Fast|SuperFast` enables growth without schema changes.
- **Default to arrays.** Design single-value fields as arrays from inception. Worst case: users specify one element.
- **Plan for variants.** Structure variant-specific settings separately with a toggle field to support new types without breaking existing configurations.
- **Seek external review.** Get peer feedback and customer input before finalizing schemas.

### Composition Architecture

Covers Composition Functions (Pipeline mode), which is the recommended approach over patch-and-transform:

- **Use Composition Functions (Pipeline mode).** Functions provide full programming language capabilities, better testability, and cleaner logic separation.
- **Understand the pipeline model.** Functions execute sequentially. Each function receives accumulated desired state from all previous functions and must pass it forward.
- **Copy all desired state forward.** This is the most common composition mistake. A function must copy all desired state from its `RunFunctionRequest` to its `RunFunctionResponse`. If a function omits a resource, Crossplane deletes it.
- **Limit dynamic resource requests.** Crossplane limits dynamic requests to 5 iterations to prevent infinite loops. Use bootstrap requirements in pipeline steps when possible.
- **Functions cannot modify XR metadata or spec.** Functions can only modify composed (child) resources.
- **Validate function inputs.** Crossplane does not validate function input automatically.

### Managed Resources

- **Set explicit deletion policies** on every managed resource: `Delete` (external resource deleted when MR deleted, the default), `Orphan` (external resource preserved), or `ObserveOnly` (Crossplane only observes).
- **Use `Orphan` for critical resources.** Production databases, storage buckets with data, and resources with external dependencies.
- **Understand the deletion lifecycle.** When a managed resource is deleted, the provider begins deleting the external resource. The MR remains with a finalizer until complete. Do not force-delete managed resources — this orphans external resources.
- **Use management policies for import scenarios.** `ObserveOnly` lets you import existing resources without Crossplane managing them.

### Provider Configuration

- **One ProviderConfig per account/credential set.** Separate ProviderConfigs for different AWS accounts, GCP projects, or credential scopes.
- **Reference ProviderConfig in managed resources.** Every managed resource should explicitly reference its ProviderConfig via `providerConfigRef`.
- **Store credentials in Kubernetes Secrets.** Never hardcode credentials in ProviderConfig. Use `secretRef` in a secure namespace.
- **Use IRSA/Workload Identity where possible.** Configure pod-based authentication instead of static credentials for AWS, GCP, and Azure.

### Connection Secrets

- **Publish connection details for consumer resources.** Databases, caches, and message queues should write connection details to Secrets using `writeConnectionSecretToRef`.
- **Use `publishConnectionDetailsTo` for XRs.** Composite resources aggregate connection details from composed resources.
- **Scope connection secrets to consumer namespaces.** Write secrets to the namespace where consuming applications run, not `crossplane-system`.

### Claims and Namespacing

- **Use Claims for self-service.** Claims provide namespace-scoped, simplified interfaces to XRs.
- **Claims are namespaced, XRs are cluster-scoped.** This separation enables multi-tenancy.
- **Name Claims descriptively.** The Claim name becomes part of the XR and child resource names.

### Testing

- **Use `crossplane render` for local testing.** Preview composition output before deployment with `crossplane render xr.yaml composition.yaml functions.yaml`.
- **Test with the Development runtime.** Add the `crossplane.io/composition-functions-dev: "true"` annotation for detailed debugging.
- **Write unit tests for composition functions.** Mock `RunFunctionRequest` and verify `RunFunctionResponse`.
- **Validate rendered output** using `crossplane validate` to check against schemas.
- **Test API evolution.** Before releasing schema changes, verify existing resources can be read, updated, and round-tripped without data loss.

### RBAC and Permissions

- **Grant RBAC for extra resource requests.** Functions requesting non-provider, non-XR resources need explicit RBAC. Use aggregated ClusterRoles with the `rbac.crossplane.io/aggregate-to-crossplane: "true"` label.
- **Limit provider permissions.** Providers request broad permissions by default. Review and constrain to resources actually managed.

### Versioning and Upgrades

- **Pin provider versions** using specific versions in `Provider` manifests.
- **Test upgrades in non-production.** Provider upgrades can change resource behavior.
- **Monitor provider health.** Check provider pod status and `HEALTHY` condition on Function resources using `kubectl get providers` and `kubectl get functions`.

### Observability

- **Monitor composition reconciliation.** Watch `Synced` and `Ready` conditions on XRs and Claims using `kubectl get composite -o wide` and `kubectl get claim -o wide`.
- **Check managed resource status.** The `SYNCED` and `READY` columns show reconciliation status via `kubectl get managed`.
- **Review provider logs.** Provider pods log reconciliation errors.
- **Set up alerts for failed reconciliations.** Monitor for resources stuck in `Synced: False` or `Ready: False` states.

### Project Structure

Recommends organizing by capability, not resource type:

```
platform/
  apis/              — XRD definitions (database/, network/)
  compositions/      — Composition implementations (database/aws.yaml, database/gcp.yaml)
  functions/         — Custom composition functions with tests
  providers/         — Provider configurations (aws.yaml, gcp.yaml)
```

- **Separate XRDs from Compositions.** XRDs define the API contract; Compositions implement it. Different teams may own each.
- **Version control everything.** Compositions, XRDs, ProviderConfigs, and Functions should all be in Git with proper review processes.

## Bad Practices

| Practice | Why It's Dangerous |
|---|---|
| Not copying desired state in functions | Resources silently deleted, composition breaks |
| Boolean fields in XR schemas | Limits future API evolution |
| Required fields without careful consideration | Cannot be made optional later |
| Hardcoded credentials in ProviderConfig | Security exposure, rotation nightmare |
| `deletionPolicy: Delete` on production databases | Accidental deletion destroys data |
| Force-deleting managed resources | Orphans external resources, leaves cloud drift |
| Mixing PnT and Functions for same resources | Unclear ownership, debugging nightmare |
| Deeply nested XR hierarchies | Complexity explosion, hard to debug |
| Skipping `crossplane render` before deploy | Surprises in production |
| Unpinned provider versions | Non-deterministic behavior after upgrades |
| Functions without input validation | Silent failures, unexpected behavior |
| Publishing connection secrets to crossplane-system | Wrong namespace, access control issues |
| Dynamic requests without iteration limits | Infinite loops crash the function |
| Modifying XR metadata/spec in functions | Changes ignored silently |

## Related Rules

- `rules/crossplane-v2-best-practices.md` — Covers v2-specific features, breaking changes, and migration patterns from v1.
- `rules/kubernetes-best-practices.md` — Crossplane runs on Kubernetes; these guidelines apply to the cluster hosting Crossplane.
- `rules/terraform-best-practices.md` — Alternative IaC tool. Useful for comparison when evaluating Crossplane vs. Terraform.
