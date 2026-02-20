# Crossplane v2 Best Practices

**Source:** `rules/crossplane-v2-best-practices.md`
**Scope:** Crossplane v2 infrastructure projects — covers v2-specific features, breaking changes, and v1-to-v2 migration
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

Understand and correctly apply Crossplane v2 breaking changes, new scoping model, and migration patterns. Prevent silent failures from v1 assumptions carried into v2.

## Overview

This rule covers features, breaking changes, and migration patterns specific to Crossplane v2. It addresses namespaced resources, the `spec.crossplane` field structure, XRD scope changes, Configuration packages, Composition revisions, EnvironmentConfig changes, and step-by-step v1-to-v2 migration. This is a companion to the v1 best practices rule — use both together for v2 projects.

## Sections

### Breaking Changes from v1

Lists features removed in v2 that require migration:

- **Native patch-and-transform composition** — must use Composition Functions instead.
- **`ControllerConfig` type** — replaced by `DeploymentRuntimeConfig`.
- **External secret stores** — removed entirely.
- **Composite resource connection details** — must recreate using functions that compose secrets.
- **Default registry for packages** — must use fully qualified URLs (e.g., `xpkg.upbound.io/...`).

Provides the migration command: `crossplane beta convert pipeline-composition composition.yaml` to convert v1 compositions to pipeline mode.

### XRD Scope (Critical v2 Change)

The most significant architectural change in v2. XRs are now namespaced by default instead of cluster-scoped.

Three scope options:

| Scope | Behavior | Claims Support | Use Case |
|---|---|---|---|
| `Namespaced` | XR lives in a namespace, can only compose same-namespace resources | No | Default for v2, multi-tenant platforms |
| `Cluster` | Cluster-scoped, can compose across namespaces | No | Shared infrastructure, cross-namespace resources |
| `LegacyCluster` | v1 compatibility mode | Yes | Migration path, existing v1 XRDs |

Key constraints:

- **Claims are not supported in v2-style XRs.** Use `scope: LegacyCluster` for backward compatibility if claims are needed.
- **Namespaced XRs can only compose resources in the same namespace.** This enforces tenant isolation but requires rethinking multi-namespace architectures.

### spec.crossplane Structure

v2 moves all Crossplane machinery under `spec.crossplane`, separating user-defined fields from Crossplane internals. User-defined fields go directly under `spec`; Crossplane fields go under `spec.crossplane`.

Key `spec.crossplane` fields:

| Field | Purpose |
|---|---|
| `compositionRef.name` | Select a specific Composition by name |
| `compositionSelector.matchLabels` | Select Composition by labels |
| `compositionRevisionRef.name` | Pin to a specific Composition revision |
| `compositionRevisionSelector.matchLabels` | Select revision by labels (e.g., release channel) |
| `compositionUpdatePolicy` | `Automatic` (default) or `Manual` |

Reserved fields that cannot be used in XRD schemas: anything under `spec.crossplane`, anything under `status.crossplane`, and `status.conditions`.

### Namespaced Managed Resources

All managed resources are namespaced in v2, enabling fine-grained RBAC at the namespace level. A `namespace` field is required on managed resources.

- **Provider support varies.** AWS providers fully support namespaced MRs. Check documentation for other clouds.
- **Cluster-scoped MRs are legacy.** They still work but are marked for future removal.

### XRD Versioning

Follows Kubernetes API versioning conventions: `v1alpha1` (unstable), `v1beta1` (stable, breaking changes discouraged), `v1` (stable, no breaking changes).

Key constraints:

- **Only one version can be `referenceable: true`.** This is the version Compositions reference.
- **`compositeTypeRef.apiVersion` in Compositions is immutable.** To support a new XRD version: create a new Composition, migrate XRs, deprecate the old Composition.
- **Breaking changes require a new XRD.** Never add breaking changes as a new version on the same XRD.

### Composition Revisions

Compositions auto-create revisions on each change. Revisions enable safe rollouts:

- **Release channel pattern:** Label revisions with channels (`stable`, `canary`, `experimental`). XRs subscribe via `compositionRevisionSelector.matchLabels`. Promote revisions by updating labels. XRs pick up new revisions with `compositionUpdatePolicy: Automatic`.
- **Pin revisions for stability:** Use `compositionRevisionRef.name` with `compositionUpdatePolicy: Manual` to prevent automatic updates in production.

### EnvironmentConfigs (v2 Changes)

Native EnvironmentConfig selection was removed in v1.18+. The replacement is `function-environment-configs`, which is configured in the Composition pipeline as a function step with its own input specification. EnvironmentConfigs are selected in the function input, not `spec.crossplane`.

### Configuration Packages

Covers the full lifecycle of Configuration packages in v2:

**Package structure:** `crossplane.yaml` (metadata, required), `apis/` (XRDs), `compositions/` (implementations), `examples/` (usage examples).

**crossplane.yaml format:** Includes metadata annotations for maintainer, source, license, and description. The `spec` section declares Crossplane version constraint and dependencies on providers, functions, and other configurations.

**v2-specific requirements:**

- Fully qualified package URLs required (no default registry).
- Must specify Crossplane version constraint (`spec.crossplane.version`).

**Dependency management:** Declare all dependencies explicitly with semantic version constraints. Supported formats: minimum version (`>=v1.0.0`), version range (`>=v1.0.0,<v2.0.0`), or exact version (`=v1.2.3`, avoid in production).

**Building and pushing:** Uses `crossplane xpkg build`, `crossplane xpkg login`, and `crossplane xpkg push`.

### Installing Configurations

Covers the Configuration install manifest including package pull policies (`IfNotPresent`, `Always`, `Never`), revision activation policies (`Automatic`, `Manual`), revision history limits, and package pull secrets.

### Migration from v1 to v2

Four-step migration process:

1. **Convert Compositions** using `crossplane beta convert pipeline-composition`.
2. **Update XRDs for v2** — change apiVersion to `apiextensions.crossplane.io/v2` and add `scope: LegacyCluster` for backward compatibility with Claims.
3. **Update package references** to fully qualified URLs.
4. **Test in non-production** — deploy v2 Crossplane to a test cluster, install converted Compositions and XRDs, create test XRs, verify behavior, and check provider logs for deprecation warnings.

### Observability

- **Check XR status for v2-specific fields:** `status.crossplane.compositionRef`, `status.crossplane.compositionRevisionRef`, `status.crossplane.conditions`.
- **Monitor Configuration package health** using `kubectl get configurations` and `kubectl get configurationrevisions`.
- **Watch for SYNCED vs READY desync.** After changing `referenceable` version, existing XRs may show READY but not SYNCED until migrated to new Compositions.

## Bad Practices

| Practice | Why It's Dangerous |
|---|---|
| Using `scope: Namespaced` and expecting cross-namespace composition | XRs can only compose same-namespace resources |
| Adding breaking changes as new XRD version | Breaks existing XRs, requires new XRD instead |
| Omitting `spec.crossplane` version constraint in packages | Package may install on incompatible Crossplane versions |
| Using short package references without registry | Fails in v2, no default registry |
| Relying on native EnvironmentConfig selection | Removed in v1.18+, use function-environment-configs |
| Expecting Claims with v2-style XRDs | Claims only work with `scope: LegacyCluster` |
| Modifying `compositeTypeRef.apiVersion` in Compositions | Field is immutable, create new Composition instead |
| Skipping `crossplane beta convert` before v2 upgrade | PnT compositions will not work in v2 |
| Using `scope: Cluster` when `Namespaced` suffices | Loses namespace isolation benefits |
| Unpinned function/provider versions in packages | Non-deterministic installs |
| Connection details in XR spec (v1 pattern) | Removed in v2, use functions to compose secrets |

## Related Rules

- `rules/crossplane-v1-best-practices.md` — Covers v1 fundamentals (XR design, Composition architecture, managed resources, testing). Use alongside this v2 rule.
- `rules/kubernetes-best-practices.md` — Crossplane runs on Kubernetes; these guidelines apply to the cluster hosting Crossplane.
- `rules/terraform-best-practices.md` — Alternative IaC tool for comparison when evaluating approaches.
