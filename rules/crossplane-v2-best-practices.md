# Crossplane v2 Best Practices

> Guidelines specific to Crossplane v2 features, breaking changes, and migration patterns. Covers namespaced resources, spec.crossplane fields, XRD scope, Configuration packages, and v1-to-v2 migration.

## Breaking Changes from v1

**Removed features requiring migration:**

- Native patch-and-transform composition — use Composition Functions instead
- `ControllerConfig` type — replaced by `DeploymentRuntimeConfig`
- External secret stores — removed entirely
- Composite resource connection details — recreate using functions that compose secrets
- Default registry for packages — must use fully qualified URLs (e.g., `xpkg.upbound.io/...`)

**Run migration before upgrading:**

```bash
# Convert v1 compositions to pipeline mode
crossplane beta convert pipeline-composition composition.yaml
```

---

## XRD Scope (Critical v2 Change)

**v2 defaults to `Namespaced` scope.** This is the most significant architectural change. XRs are now namespaced by default instead of cluster-scoped.

```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.example.org
spec:
  group: example.org
  names:
    kind: XDatabase
    plural: xdatabases
  scope: Namespaced  # v2 default — explicit for clarity
```

**Three scope options:**

| Scope | Behavior | Claims Support | Use Case |
| --- | --- | --- | --- |
| `Namespaced` | XR lives in a namespace, can only compose same-namespace resources | No | Default for v2, multi-tenant platforms |
| `Cluster` | Cluster-scoped, can compose across namespaces | No | Shared infrastructure, cross-namespace resources |
| `LegacyCluster` | v1 compatibility mode | Yes | Migration path, existing v1 XRDs |

**Claims are not supported in v2-style XRs.** If you need claims, use `scope: LegacyCluster` for backward compatibility.

**Namespaced XRs can only compose resources in the same namespace.** This enforces tenant isolation but requires rethinking multi-namespace architectures.

---

## spec.crossplane Structure

**v2 moves all Crossplane machinery under `spec.crossplane`.** This separates user-defined fields from Crossplane internals:

```yaml
apiVersion: example.org/v1alpha1
kind: XDatabase
metadata:
  name: my-database
  namespace: team-a
spec:
  # User-defined fields
  engine: postgresql
  storageGB: 100

  # Crossplane machinery — all under spec.crossplane
  crossplane:
    compositionRef:
      name: xdatabase-aws
    compositionRevisionRef:
      name: xdatabase-aws-abc123
    compositionRevisionSelector:
      matchLabels:
        channel: stable
    compositionUpdatePolicy: Automatic
```

**Key `spec.crossplane` fields:**

| Field | Purpose |
| --- | --- |
| `compositionRef.name` | Select a specific Composition by name |
| `compositionSelector.matchLabels` | Select Composition by labels |
| `compositionRevisionRef.name` | Pin to a specific Composition revision |
| `compositionRevisionSelector.matchLabels` | Select revision by labels (e.g., release channel) |
| `compositionUpdatePolicy` | `Automatic` (default) or `Manual` |

**Reserved fields in XRD schemas.** Crossplane doesn't allow these in your schema definition:

- Any field under `spec.crossplane`
- Any field under `status.crossplane`
- `status.conditions`

---

## Namespaced Managed Resources

**All managed resources are namespaced in v2.** This enables fine-grained RBAC at the namespace level:

```yaml
apiVersion: s3.aws.upbound.io/v1beta2
kind: Bucket
metadata:
  name: my-bucket
  namespace: team-a  # Required in v2
spec:
  forProvider:
    region: us-east-1
```

**Provider support varies.** AWS providers fully support namespaced MRs. Check provider documentation for other clouds.

**Cluster-scoped MRs are legacy.** They still work but are marked for future removal. Plan migration to namespaced MRs.

---

## XRD Versioning

**Follow Kubernetes API versioning conventions:**

- `v1alpha1` — Unstable, expect breaking changes
- `v1beta1` — Stable, breaking changes discouraged
- `v1` — Stable, no breaking changes

**Only one version can be `referenceable: true`.** This is the version Compositions reference:

```yaml
spec:
  versions:
    - name: v1alpha1
      served: true
      referenceable: false
      schema:
        openAPIV3Schema: { ... }
    - name: v1beta1
      served: true
      referenceable: true  # Compositions use this version
      schema:
        openAPIV3Schema: { ... }
```

**Composition `compositeTypeRef.apiVersion` is immutable.** You cannot change it after creation. To support a new XRD version:

1. Create a new Composition pointing to the new version
2. Migrate XRs to use the new Composition
3. Deprecate the old Composition

**Breaking changes require a new XRD.** Never add breaking changes as a new version on the same XRD — create a completely separate XRD resource.

---

## Composition Revisions

**Compositions auto-create revisions on each change.** Use revisions for safe rollouts:

```yaml
spec:
  crossplane:
    compositionRevisionSelector:
      matchLabels:
        channel: stable
    compositionUpdatePolicy: Automatic
```

**Release channel pattern for gradual rollouts:**

1. Label Composition revisions with channels (`stable`, `canary`, `experimental`)
2. XRs subscribe via `compositionRevisionSelector.matchLabels`
3. Promote revisions by updating labels
4. XRs automatically pick up new revisions with `compositionUpdatePolicy: Automatic`

```yaml
# Composition with channel label
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xdatabase-aws
  labels:
    channel: stable  # Promote by changing this label
```

**Pin revisions for stability.** Use `compositionRevisionRef.name` to prevent automatic updates in production:

```yaml
spec:
  crossplane:
    compositionRevisionRef:
      name: xdatabase-aws-abc123
    compositionUpdatePolicy: Manual
```

---

## EnvironmentConfigs (v2 Changes)

**Native EnvironmentConfig selection removed in v1.18+.** Use `function-environment-configs` instead:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
spec:
  mode: Pipeline
  pipeline:
    - step: environment
      functionRef:
        name: function-environment-configs
      input:
        apiVersion: environmentconfigs.fn.crossplane.io/v1beta1
        kind: Input
        spec:
          environmentConfigs:
            - type: Reference
              ref:
                name: my-env-config
```

**EnvironmentConfigs are selected in the function input, not `spec.crossplane`.**

---

## Configuration Packages

### Package Structure

```
my-configuration/
├── crossplane.yaml          # Package metadata (required)
├── apis/
│   └── definition.yaml      # XRDs
├── compositions/
│   └── aws.yaml             # Compositions
└── examples/                # Usage examples (optional but recommended)
    └── claim.yaml
```

### crossplane.yaml Format

```yaml
apiVersion: meta.pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: my-platform
  annotations:
    meta.crossplane.io/maintainer: Platform Team <platform@example.com>
    meta.crossplane.io/source: github.com/example/my-platform
    meta.crossplane.io/license: Apache-2.0
    meta.crossplane.io/description: Production database platform
spec:
  crossplane:
    version: ">=v2.0.0"
  dependsOn:
    - provider: xpkg.upbound.io/upbound/provider-aws-s3
      version: ">=v1.0.0"
    - provider: xpkg.upbound.io/upbound/provider-aws-rds
      version: ">=v1.0.0"
    - function: xpkg.upbound.io/crossplane-contrib/function-go-templating
      version: ">=v0.5.0"
```

### Building Packages

```bash
# Build package
crossplane xpkg build \
  --package-root=. \
  --examples-root=examples \
  --package-file=my-platform.xpkg

# Authenticate to registry
crossplane xpkg login -u <username> -p <token> xpkg.upbound.io

# Push package
crossplane xpkg push xpkg.upbound.io/my-org/my-platform:v1.0.0 \
  -f my-platform.xpkg
```

### v2 Package Requirements

**Fully qualified package URLs required.** No default registry:

```yaml
# v1 (worked with default registry)
package: crossplane-contrib/provider-aws

# v2 (must be fully qualified)
package: xpkg.upbound.io/crossplane-contrib/provider-aws
```

**Specify Crossplane version constraint:**

```yaml
spec:
  crossplane:
    version: ">=v2.0.0"
```

### Dependency Management

**Declare all dependencies explicitly:**

```yaml
spec:
  dependsOn:
    # Providers
    - provider: xpkg.upbound.io/upbound/provider-aws-s3
      version: ">=v1.0.0"
    # Functions
    - function: xpkg.upbound.io/crossplane-contrib/function-go-templating
      version: ">=v0.5.0"
    # Other Configurations
    - configuration: xpkg.upbound.io/my-org/base-platform
      version: ">=v2.0.0"
```

**Use semantic version constraints:**

- `">=v1.0.0"` — minimum version
- `">=v1.0.0,<v2.0.0"` — version range
- `"=v1.2.3"` — exact version (avoid in production)

---

## Installing Configurations

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: my-platform
spec:
  package: xpkg.upbound.io/my-org/my-platform:v1.0.0
  packagePullPolicy: IfNotPresent
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 3
  packagePullSecrets:
    - name: registry-credentials
```

**Package pull policies:**

- `IfNotPresent` — Pull only if not cached (default)
- `Always` — Always pull latest
- `Never` — Use only cached images

**Revision activation policies:**

- `Automatic` — Activate new revisions immediately (default)
- `Manual` — Require explicit activation

---

## Migration from v1 to v2

### Step 1: Convert Compositions

```bash
crossplane beta convert pipeline-composition old-composition.yaml > new-composition.yaml
```

### Step 2: Update XRDs for v2

```yaml
# Before (v1)
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
spec:
  claimNames:  # Claims supported in v1
    kind: Database
    plural: databases

# After (v2 with backward compatibility)
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
spec:
  scope: LegacyCluster  # Maintains claim support
  claimNames:
    kind: Database
    plural: databases
```

### Step 3: Update Package References

```yaml
# Before
package: provider-aws

# After
package: xpkg.upbound.io/upbound/provider-aws-s3:v1.0.0
```

### Step 4: Test in Non-Production

1. Deploy v2 Crossplane to test cluster
2. Install converted Compositions and XRDs
3. Create test XRs and verify behavior
4. Check provider logs for deprecation warnings

---

## Bad Practices — Never Do These

| Practice | Why It's Dangerous |
| --- | --- |
| Using `scope: Namespaced` and expecting cross-namespace composition | XRs can only compose same-namespace resources |
| Adding breaking changes as new XRD version | Breaks existing XRs, requires new XRD instead |
| Omitting `spec.crossplane` version constraint in packages | Package may install on incompatible Crossplane versions |
| Using short package references without registry | Fails in v2, no default registry |
| Relying on native EnvironmentConfig selection | Removed in v1.18+, use function-environment-configs |
| Expecting Claims with v2-style XRDs | Claims only work with `scope: LegacyCluster` |
| Modifying `compositeTypeRef.apiVersion` in Compositions | Field is immutable, create new Composition instead |
| Skipping `crossplane beta convert` before v2 upgrade | PnT compositions won't work in v2 |
| Using `scope: Cluster` when `Namespaced` suffices | Loses namespace isolation benefits |
| Unpinned function/provider versions in packages | Non-deterministic installs |
| Connection details in XR spec (v1 pattern) | Removed in v2, use functions to compose secrets |

---

## Observability

**Check XR status for v2-specific fields:**

```bash
kubectl get xdatabase my-db -o yaml
```

Look for:
- `status.crossplane.compositionRef` — active Composition
- `status.crossplane.compositionRevisionRef` — active revision
- `status.crossplane.conditions` — reconciliation status

**Monitor Configuration package health:**

```bash
kubectl get configurations
kubectl get configurationrevisions
```

**Watch for SYNCED vs READY desync.** After changing `referenceable` version, existing XRs may show READY but not SYNCED until migrated to new Compositions.
