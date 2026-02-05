# Crossplane Best Practices

> Guidelines for generating correct, safe, and maintainable Crossplane infrastructure code. Prevents composition errors, state corruption, API breakage, and resource leaks.

## XR (Composite Resource) Design

**Design APIs to avoid versioning.** Kubernetes Deployment v1 has evolved for 7+ years without requiring v2. Invest upfront in future-proof schemas rather than planning version bumps.

**Understand versioning constraints.** Multiple CRD versions represent different views of identical underlying data. Due to round-tripping requirements:

- **Can do:** Rename fields, relocate fields to different paths
- **Cannot do:** Remove required fields from old versions, introduce new mandatory fields absent in earlier versions

A new version is only useful for renaming or moving fields — it doesn't solve design problems.

**Minimize required fields.** Assume any required field becomes permanent. Prefer optional fields with sensible defaults. Adding optional fields is backward-compatible; making fields required is not.

**Avoid boolean fields.** Replace booleans with string enums. `fast: true` limits future expansion, while `speed: Regular|Fast|SuperFast` enables growth without schema changes.

**Default to arrays.** Design single-value fields as arrays from inception. Worst case: users specify one element. Best case: multi-value scenarios require no migration.

**Plan for variants.** Structure variant-specific settings separately (`spec.postgresql`, `spec.mysql`) with a toggle field. This permits supporting new types without breaking existing configurations.

**Seek external review.** Request peer feedback and customer input before finalizing schemas. Anticipate future evolution needs.

---

## Composition Architecture

**Use Composition Functions (Pipeline mode).** Functions provide full programming language capabilities, better testability, and cleaner logic separation than patch-and-transform.

**Understand the pipeline model.** Functions execute sequentially. Each function receives the accumulated desired state from all previous functions and must pass it forward.

**Copy all desired state forward.** A function must copy all desired state from its `RunFunctionRequest` to its `RunFunctionResponse`. If a function omits a resource, Crossplane deletes it. This is the most common composition mistake.

```yaml
# Each function builds on previous state
pipeline:
  - step: create-network
    functionRef:
      name: function-go-templating
  - step: create-database
    functionRef:
      name: function-go-templating
  # Second function MUST include network resources or they get deleted
```

**Limit dynamic resource requests.** Crossplane limits dynamic requests to 5 iterations to prevent infinite loops. Use bootstrap requirements in pipeline steps when possible — they're more performant than runtime requests.

**Functions cannot modify XR metadata or spec.** Functions can only modify composed (child) resources. Changes to the composite resource itself are ignored.

**Validate function inputs.** Crossplane doesn't validate function input automatically. Functions must validate their own configuration data.

---

## Managed Resources

**Set explicit deletion policies.** Every managed resource should have a deliberate `deletionPolicy`:

- `Delete` — External resource deleted when MR deleted (default for most providers)
- `Orphan` — External resource preserved when MR deleted
- `ObserveOnly` — Crossplane only observes, never modifies or deletes

```yaml
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  name: production-data
spec:
  deletionPolicy: Orphan  # Preserve bucket if Crossplane resource deleted
  forProvider:
    region: us-east-1
```

**Use `Orphan` for critical resources.** Production databases, storage buckets with data, and resources with external dependencies should use `Orphan` to prevent accidental deletion.

**Understand the deletion lifecycle.** When you delete a managed resource, the provider begins deleting the external resource. The MR remains with a finalizer until the external resource is fully deleted. Don't force-delete managed resources — this orphans external resources.

**Use management policies for import scenarios.** `ObserveOnly` lets you import existing resources without Crossplane managing them. Useful for gradual migration.

---

## Provider Configuration

**One ProviderConfig per account/credential set.** Create separate ProviderConfigs for different AWS accounts, GCP projects, or credential scopes:

```yaml
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: production-account
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-production-creds
      key: credentials
```

**Reference ProviderConfig in managed resources.** Every managed resource should explicitly reference its ProviderConfig:

```yaml
spec:
  providerConfigRef:
    name: production-account
```

**Store credentials in Kubernetes Secrets.** Never hardcode credentials in ProviderConfig. Use `secretRef` to reference Secrets in a secure namespace.

**Use IRSA/Workload Identity where possible.** For AWS (IRSA), GCP (Workload Identity), and Azure (Workload Identity), configure pod-based authentication instead of static credentials.

---

## Connection Secrets

**Publish connection details for consumer resources.** Databases, caches, and message queues should write connection details to Secrets:

```yaml
spec:
  writeConnectionSecretToRef:
    namespace: app-namespace
    name: database-connection
```

**Use `publishConnectionDetailsTo` for XRs.** Composite resources aggregate connection details from composed resources:

```yaml
spec:
  publishConnectionDetailsTo:
    name: my-composite-connection
    configRef:
      name: default
```

**Scope connection secrets to consumer namespaces.** Write secrets to the namespace where consuming applications run, not `crossplane-system`.

---

## Claims and Namespacing

**Use Claims for self-service.** Claims provide namespace-scoped, simplified interfaces to XRs. Platform teams define XRDs and Compositions; application teams create Claims.

**Claims are namespaced, XRs are cluster-scoped.** This separation enables multi-tenancy — each namespace can claim resources without seeing others' infrastructure.

**Name Claims descriptively.** The Claim name becomes part of the XR and child resource names. Use meaningful names that identify the workload.

---

## Testing

**Use `crossplane render` for local testing.** Preview composition output before deployment:

```bash
crossplane render xr.yaml composition.yaml functions.yaml
```

**Test with the Development runtime.** Add annotation for detailed debugging:

```yaml
metadata:
  annotations:
    crossplane.io/composition-functions-dev: "true"
```

**Write unit tests for composition functions.** Functions are code — test them like code. Mock the `RunFunctionRequest` and verify the `RunFunctionResponse`.

**Validate rendered output.** Use `crossplane validate` to check rendered resources against their schemas:

```bash
crossplane render xr.yaml composition.yaml functions.yaml | crossplane validate
```

**Test API evolution.** Before releasing schema changes, verify existing resources can be read, updated, and round-tripped without data loss.

---

## RBAC and Permissions

**Grant RBAC for extra resource requests.** Functions requesting non-provider, non-XR resources need explicit RBAC. Use aggregated ClusterRoles:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: crossplane-extra-resources
  labels:
    rbac.crossplane.io/aggregate-to-crossplane: "true"
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
```

**Limit provider permissions.** Providers request broad permissions by default. Review and constrain to resources actually managed.

---

## Versioning and Upgrades

**Pin provider versions.** Use specific versions in `Provider` manifests:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1.1.0
```

**Test upgrades in non-production.** Provider upgrades can change resource behavior. Test in dev/staging before production.

**Monitor provider health.** Check provider pod status and `HEALTHY` condition on Function resources:

```bash
kubectl get providers
kubectl get functions
```

---

## Bad Practices — Never Do These

| Practice | Why It's Dangerous |
| --- | --- |
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

---

## Observability

**Monitor composition reconciliation.** Watch for `Synced` and `Ready` conditions on XRs and Claims:

```bash
kubectl get composite -o wide
kubectl get claim -o wide
```

**Check managed resource status.** The `SYNCED` and `READY` columns show reconciliation status:

```bash
kubectl get managed
```

**Review provider logs.** Provider pods log reconciliation errors:

```bash
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws
```

**Set up alerts for failed reconciliations.** Monitor for resources stuck in `Synced: False` or `Ready: False` states.

---

## Project Structure

**Organize by capability, not resource type.** Group compositions by what they provide (database, network, observability), not by cloud resource type.

```
platform/
├── apis/                    # XRD definitions
│   ├── database/
│   │   └── definition.yaml
│   └── network/
│       └── definition.yaml
├── compositions/            # Composition implementations
│   ├── database/
│   │   ├── aws.yaml
│   │   └── gcp.yaml
│   └── network/
│       └── aws.yaml
├── functions/               # Custom composition functions
│   └── database-sizing/
│       ├── fn.go
│       └── fn_test.go
└── providers/               # Provider configurations
    ├── aws.yaml
    └── gcp.yaml
```

**Separate XRDs from Compositions.** XRDs define the API contract; Compositions implement it. Different teams may own each.

**Version control everything.** Compositions, XRDs, ProviderConfigs, and Functions should all be in Git with proper review processes.
