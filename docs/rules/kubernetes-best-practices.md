# Kubernetes Best Practices

**Source:** `rules/kubernetes-best-practices.md`
**Scope:** Kubernetes workload and cluster configuration — applies to any project deploying to Kubernetes
**Activation:** Automatic — loaded when placed in `.claude/rules/`

## Core Principle

Generate correct, safe, and production-ready Kubernetes manifests. Prevent security vulnerabilities, resource exhaustion, availability failures, and operational incidents.

## Overview

This rule provides comprehensive guidelines for Kubernetes manifest generation and cluster configuration. It covers resource management, health probes, pod disruption budgets, security (pod security, RBAC, network policies), application lifecycle, high availability, labels, observability, image security, namespace organization, and cluster hardening. The guidelines are designed to produce production-grade Kubernetes configurations.

## Sections

### Resource Management

- **Set resource requests and limits on every container.** Without them, one application can destabilize the entire cluster. Requests define scheduling guarantees; limits define hard caps.
- **Be cautious with CPU limits.** Unlike memory (which triggers OOMKill), CPU limits throttle processes, causing latency spikes in multi-threaded applications. Consider omitting CPU limits and relying on requests for scheduling.
- **Use LimitRange for namespace defaults.** Enforces resource constraints even when developers forget to set them.
- **Use ResourceQuota to cap namespace consumption.** Prevents runaway resource usage by setting hard limits on CPU, memory, pods, and PVCs.
- **Understand QoS classes.** Kubernetes assigns pods to Guaranteed (requests == limits), Burstable, or BestEffort based on resource specs. Under pressure, BestEffort pods are evicted first. Critical workloads should be Guaranteed.

### Health Probes

Three probe types with distinct purposes:

- **Readiness probes** control traffic routing. Kubernetes only sends traffic to pods passing readiness checks. Should be sensitive to detect issues quickly.
- **Liveness probes** detect stuck processes. Failures trigger pod restart. Should be conservative to avoid unnecessary restarts.
- **Startup probes** protect slow-starting applications. Prevents liveness probe from killing pods during initialization.

Key guidelines:

- **Keep probes independent of external dependencies.** A probe checking database connectivity causes cascading failures when the database is slow. Check only the application's own health.
- **Set different thresholds for readiness vs. liveness.** Readiness should be sensitive; liveness should be conservative.

### Pod Disruption Budgets

- **Create PDBs for all production workloads.** Without PDBs, cluster operations (upgrades, scaling) can take down all replicas simultaneously.
- **Use `minAvailable` or `maxUnavailable`, not both.** `minAvailable: 2` keeps at least 2 pods running; `maxUnavailable: 1` never evicts more than 1 at a time.
- **Do not set PDB too restrictively.** `minAvailable` equal to replica count blocks all voluntary disruptions, including upgrades.

### Security

#### Pod Security

- **Run containers as non-root** using `runAsNonRoot: true` with explicit `runAsUser` and `runAsGroup`.
- **Use read-only root filesystem** to prevent tampering.
- **Drop all capabilities, add only what is needed.** Start with `drop: ALL`, add specific capabilities like `NET_BIND_SERVICE` only if required.
- **Disable privilege escalation** with `allowPrivilegeEscalation: false`.
- **Never use privileged containers** unless accessing hardware. Even then, prefer device plugins.
- **Use seccomp profiles** (`RuntimeDefault` at minimum) for syscall filtering.

The source includes a complete secure pod template combining all these settings.

#### RBAC

- **Follow least privilege.** Start with empty permissions, add only what is needed.
- **Use Role/RoleBinding for namespace-scoped access.** Reserve ClusterRole/ClusterRoleBinding for cluster-wide resources.
- **Never grant high-risk permissions to users:** `secrets` with `list`/`watch` (reveals all secret contents), `pods/exec` (command execution in any pod), `nodes/proxy` (bypasses audit logging), `escalate`/`bind`/`impersonate` verbs (privilege escalation vectors), wildcards on any field.
- **Disable service account token auto-mounting** at both the ServiceAccount and Pod level.
- **Audit RBAC regularly.** Review permissions quarterly, especially after team changes.

#### Network Policies

- **Start with default deny.** Block all ingress and egress traffic, then allow explicitly.
- **Allow only required traffic** using pod selectors, namespace selectors, and port specifications.
- **Do not forget DNS egress.** Pods need to reach kube-dns for name resolution. Include an explicit egress rule for DNS (UDP port 53).
- **Test in staging first.** Default deny policies can break applications with undocumented dependencies.

### Application Lifecycle

#### Graceful Shutdown

Covers the Kubernetes termination sequence: SIGTERM, preStop hook, `terminationGracePeriodSeconds`, then SIGKILL. Applications should:

1. Stop accepting new connections.
2. Complete in-flight requests.
3. Close idle keepalive connections.
4. Exit cleanly.

A `preStop` hook with a short sleep (e.g., 5 seconds) allows time for endpoint removal from Services. When using shell entrypoints, use `exec` to forward SIGTERM to the process.

#### Configuration

- **Use ConfigMaps for non-sensitive configuration.**
- **Mount Secrets as files, not environment variables.** Environment variables are visible in `/proc` and process listings. Volume mounts are more secure.
- **Never store secrets in container images or ConfigMaps.**

### High Availability

- **Run multiple replicas.** Single-pod deployments mean node failure equals downtime.
- **Spread pods across nodes** using pod anti-affinity with `preferredDuringSchedulingIgnoredDuringExecution`.
- **Spread across availability zones** using `topologySpreadConstraints` with `topology.kubernetes.io/zone`.
- **Do not store state in container filesystem.** Use external storage to enable horizontal scaling.

### Labels and Annotations

**Recommended label taxonomy:**

- Technical labels: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`.
- Business labels: `team`, `cost-center`.
- Security labels: `data-classification`.

**Use annotations for non-identifying metadata** such as descriptions and oncall contacts.

### Observability

- **Log to stdout/stderr.** Follow twelve-factor methodology. Let the platform handle log collection.
- **Export metrics in Prometheus format** via a `/metrics` endpoint with appropriate annotations.
- **Include request tracing.** Propagate trace context headers (W3C Trace Context, B3) for distributed tracing.

### Image Security

- **Use specific image tags.** Never use `:latest` in production. Image digests (`@sha256:...`) are even better.
- **Pull from trusted registries only.** Configure admission control to allow only approved registries.
- **Scan images for vulnerabilities** using Trivy, Grype, or similar tools in CI/CD.
- **Use minimal base images.** `distroless`, `alpine`, or `scratch` reduce attack surface.

### Namespace Organization

- **Use namespaces for isolation** — separate environments, teams, or applications.
- **Apply LimitRange and ResourceQuota per namespace.**
- **Use NetworkPolicy per namespace** starting with default deny.
- **Do not use the `default` namespace.** Create purpose-specific namespaces for all workloads.

### Cluster Hardening

- **Run CIS Kubernetes Benchmark** using `kube-bench` to validate cluster security.
- **Disable metadata API access from pods** using NetworkPolicy to block 169.254.169.254/32 (AWS/GCP) and 100.100.100.200/32 (Azure).
- **Use Pod Security Admission** to enforce security standards at namespace level with `restricted` profile labels.
- **Prefer OIDC for user authentication.** ServiceAccount tokens are for applications; humans should use identity providers.

## Bad Practices

| Practice | Why It's Dangerous |
|---|---|
| No resource requests/limits | Resource exhaustion, noisy neighbors, OOM kills |
| CPU limits without testing | Artificial throttling, latency spikes |
| Single-replica deployments | Node failure = downtime |
| All replicas on one node | No fault tolerance despite multiple replicas |
| Readiness probes checking external deps | Cascading failures across services |
| No PodDisruptionBudget | Cluster operations take down all pods |
| Running as root | Privilege escalation attacks |
| Privileged containers | Full node access if compromised |
| Secrets in environment variables | Visible in `/proc`, process listings |
| Secrets in ConfigMaps | Not encrypted, wrong abstraction |
| Wildcard RBAC permissions | Excessive access, privilege escalation |
| `cluster-admin` for regular users | Bypasses all security controls |
| No NetworkPolicy | Unrestricted lateral movement |
| Auto-mounted service account tokens | Unnecessary credential exposure |
| Storing state in container filesystem | Breaks scaling, data loss on restart |
| Ignoring SIGTERM | Dropped requests during shutdown |
| No labels/selectors | Unmanageable at scale |
| Hardcoded image tags (`:latest`) | Non-reproducible deployments |

## Related Rules

- `rules/crossplane-v1-best-practices.md` — Crossplane runs on Kubernetes and manages cloud resources from within the cluster.
- `rules/crossplane-v2-best-practices.md` — Crossplane v2 introduces namespaced managed resources that interact with Kubernetes namespace isolation.
- `rules/cdk-best-practices.md` — AWS CDK can deploy EKS clusters and Kubernetes resources.
