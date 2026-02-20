# Kiro Steering Reference

Steering files provide persistent project guidance loaded automatically based on their inclusion mode. They are the Kiro equivalent of Claude Code rules.

## Installation

Copy desired steering files into your project's `.kiro/steering/` directory:

```bash
mkdir -p <your-project>/.kiro/steering
cp kiro/steering/<file>.md <your-project>/.kiro/steering/
```

## Inclusion Modes

| Mode | Behavior |
|------|----------|
| `always` | Loaded in every interaction |
| `auto` | Loaded when conversation context matches the file's `description` field |

## Steering Files

### defensive-protocol.md

| Field | Value |
|-------|-------|
| Source | `rules/defensive-protocol.md` |
| Inclusion | `always` |
| Related Powers | investigation |
| Note | **Also available as a power** at `powers/defensive-protocol/` — use the power if the standalone steering file does not import in your environment |

Defensive epistemology for agentic coding. Core behavioral guidelines: prediction protocol (DOING/EXPECT/RESULT), failure response (stop/report/wait), verification cadence, autonomy boundaries, investigation protocol, Chesterton's fence, and contradiction handling. Loaded in every interaction to enforce safe, observable development practices.

### terraform-best-practices.md

| Field | Value |
|-------|-------|
| Source | `rules/terraform-best-practices.md` |
| Inclusion | `auto` |
| Description | Terraform HCL best practices for module design, state management, and deployment safety |
| Related Powers | terraform-workflow, terraform-testing |

Comprehensive Terraform guidelines: repository structure, module design, state management, security, variables, naming, resource patterns, version management, testing, deployment safety, community modules, and anti-patterns.

### cdk-best-practices.md

| Field | Value |
|-------|-------|
| Source | `rules/cdk-best-practices.md` |
| Inclusion | `auto` |
| Description | AWS CDK best practices for construct design, security, and testing |
| Related Powers | cdk-workflow |

CDK guidelines: construct design (L1/L2/L3), stack architecture, resource identity (logical IDs), configuration, naming, security (grants, guardrails), removal policies, testing, deployment, and anti-patterns.

### kubernetes-best-practices.md

| Field | Value |
|-------|-------|
| Source | `rules/kubernetes-best-practices.md` |
| Inclusion | `auto` |
| Description | Kubernetes resource management, security, and production readiness |
| Related Powers | — |

Kubernetes guidelines: resource management (requests/limits/QoS), health probes, PDBs, security (pod security, RBAC, network policies), application lifecycle, high availability, labels, observability, image security, namespace organization, and cluster hardening.

### crossplane-v1-best-practices.md

| Field | Value |
|-------|-------|
| Source | `rules/crossplane-v1-best-practices.md` |
| Inclusion | `auto` |
| Description | Crossplane XR design, compositions, and provider configuration |
| Related Powers | — |

Crossplane guidelines: XR API design (versioning, field design), composition architecture (pipeline mode, functions), managed resources (deletion policies), provider configuration, connection secrets, claims, testing, RBAC, and anti-patterns.

### crossplane-v2-best-practices.md

| Field | Value |
|-------|-------|
| Source | `rules/crossplane-v2-best-practices.md` |
| Inclusion | `auto` |
| Description | Crossplane v2 breaking changes, namespaced resources, and migration patterns |
| Related Powers | — |

Crossplane v2-specific guidelines: breaking changes from v1, XRD scope (Namespaced/Cluster/LegacyCluster), spec.crossplane structure, namespaced managed resources, XRD versioning, composition revisions, EnvironmentConfigs, Configuration packages, and v1-to-v2 migration steps.
