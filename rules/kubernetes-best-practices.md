# Kubernetes Best Practices

> Guidelines for generating correct, safe, and production-ready Kubernetes manifests. Prevents security vulnerabilities, resource exhaustion, availability failures, and operational incidents.

## Resource Management

**Set resource requests and limits on every container.** Without them, one application can destabilize the entire cluster:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    # CPU limits are often counterproductive - see below
```

**Be cautious with CPU limits.** Unlike memory (which triggers OOMKill), CPU limits throttle processes. This causes latency spikes in multi-threaded applications. Consider omitting CPU limits and relying on requests for scheduling:

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    memory: "1Gi"
    # No CPU limit - avoids artificial throttling
```

**Use LimitRange for namespace defaults.** Enforce resource constraints even when developers forget:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
    - default:
        memory: "512Mi"
      defaultRequest:
        memory: "256Mi"
        cpu: "100m"
      type: Container
```

**Use ResourceQuota to cap namespace consumption.** Prevent runaway resource usage:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.memory: "40Gi"
    pods: "50"
    persistentvolumeclaims: "10"
```

**Understand QoS classes.** Kubernetes assigns pods to Guaranteed, Burstable, or BestEffort based on resource specs. Under pressure, BestEffort pods are evicted first. Critical workloads should be Guaranteed (requests == limits).

---

## Health Probes

**Configure readiness probes for traffic routing.** Kubernetes only sends traffic to pods passing readiness checks:

```yaml
readinessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
```

**Configure liveness probes for stuck process detection.** Liveness failures trigger pod restart:

```yaml
livenessProbe:
  httpGet:
    path: /livez
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
  failureThreshold: 3
```

**Use startup probes for slow-starting applications.** Prevents liveness probe from killing pods during initialization:

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
  # Allows up to 5 minutes for startup (30 * 10s)
```

**Keep probes independent of external dependencies.** A probe that checks database connectivity causes cascading failures when the database is slow. Check only the application's own health.

**Set different thresholds for readiness vs liveness.** Readiness should be sensitive (detect issues quickly). Liveness should be conservative (avoid unnecessary restarts).

---

## Pod Disruption Budgets

**Create PDBs for all production workloads.** Without PDBs, cluster operations (upgrades, scaling) can take down all replicas simultaneously:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2  # Or use maxUnavailable: 1
  selector:
    matchLabels:
      app: my-app
```

**Use `minAvailable` or `maxUnavailable`, not both.** Choose based on your scaling pattern:

- `minAvailable: 2` — Always keep at least 2 pods running
- `maxUnavailable: 1` — Never evict more than 1 pod at a time

**Don't set PDB too restrictively.** `minAvailable` equal to replica count blocks all voluntary disruptions, including upgrades.

---

## Security

### Pod Security

**Run containers as non-root.** Prevents privilege escalation attacks:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
```

**Use read-only root filesystem.** Prevents tampering:

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

**Drop all capabilities, add only what's needed:**

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE  # Only if binding to ports < 1024
```

**Disable privilege escalation:**

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

**Never use privileged containers** unless accessing hardware (GPUs). Even then, prefer device plugins.

**Complete secure pod template:**

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

### RBAC

**Follow least privilege.** Start with empty permissions, add only what's needed:

```yaml
# Good: Specific permissions
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]

# Bad: Wildcard permissions
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
```

**Use Role/RoleBinding for namespace-scoped access.** Reserve ClusterRole/ClusterRoleBinding for cluster-wide resources.

**Never grant these high-risk permissions to users:**

- `secrets` with `list` or `watch` — reveals all secret contents
- `pods/exec` — allows command execution in any pod
- `nodes/proxy` — bypasses audit logging, allows kubelet API access
- `escalate`, `bind`, `impersonate` verbs — privilege escalation vectors
- Wildcard (`*`) on any field

**Disable service account token auto-mounting:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false  # Also set at pod level
```

**Audit RBAC regularly.** Review permissions quarterly, especially after team changes.

### Network Policies

**Start with default deny.** Block all traffic, then allow explicitly:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}  # Applies to all pods in namespace
  policyTypes:
    - Ingress
    - Egress
```

**Allow only required traffic:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-traffic
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - protocol: TCP
          port: 5432
    - to:  # Allow DNS
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

**Don't forget DNS egress.** Pods need to reach kube-dns for name resolution.

**Test in staging first.** Default deny policies can break applications with undocumented dependencies.

---

## Application Lifecycle

### Graceful Shutdown

**Handle SIGTERM properly.** When Kubernetes terminates a pod:

1. Pod receives SIGTERM
2. `preStop` hook runs (if defined)
3. App has `terminationGracePeriodSeconds` to shut down
4. SIGKILL sent if still running

```yaml
spec:
  terminationGracePeriodSeconds: 30
  containers:
    - name: app
      lifecycle:
        preStop:
          exec:
            command: ["/bin/sh", "-c", "sleep 5"]  # Allow time for endpoint removal
```

**Drain connections before exit.** Your application should:

1. Stop accepting new connections
2. Complete in-flight requests
3. Close idle keepalive connections
4. Exit cleanly

**Forward SIGTERM to your process.** If using a shell entrypoint, use `exec`:

```dockerfile
ENTRYPOINT ["sh", "-c", "exec java -jar app.jar"]
```

### Configuration

**Use ConfigMaps for non-sensitive configuration:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
```

**Mount Secrets as files, not environment variables.** Environment variables are visible in `/proc` and process listings:

```yaml
# Good: Volume mount
volumes:
  - name: secrets
    secret:
      secretName: app-secrets
containers:
  - volumeMounts:
      - name: secrets
        mountPath: /etc/secrets
        readOnly: true

# Avoid: Environment variables
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: password
```

**Never store secrets in container images or ConfigMaps.**

---

## High Availability

**Run multiple replicas.** Single-pod deployments mean node failure = downtime:

```yaml
spec:
  replicas: 3
```

**Spread pods across nodes.** Use pod anti-affinity to prevent all replicas on one node:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: my-app
          topologyKey: kubernetes.io/hostname
```

**Spread across availability zones:**

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: my-app
```

**Don't store state in container filesystem.** Use external storage (databases, object storage) to enable horizontal scaling.

---

## Labels and Annotations

**Apply consistent labels.** Recommended label taxonomy:

```yaml
metadata:
  labels:
    # Technical
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: helm
    # Business
    team: platform
    cost-center: engineering
    # Security
    data-classification: internal
```

**Use annotations for non-identifying metadata:**

```yaml
metadata:
  annotations:
    description: "Production API server"
    oncall: "platform-team@example.com"
```

---

## Observability

**Log to stdout/stderr.** Follow twelve-factor app methodology. Let the platform handle log collection:

```yaml
# No sidecar needed - node-level collectors gather stdout
containers:
  - name: app
    # App logs to stdout, collected by fluentd/vector/etc on node
```

**Export metrics in Prometheus format.** Use `/metrics` endpoint:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

**Include request tracing.** Propagate trace context headers (W3C Trace Context, B3) for distributed tracing.

---

## Bad Practices — Never Do These

| Practice | Why It's Dangerous |
| --- | --- |
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

---

## Image Security

**Use specific image tags.** Never use `:latest` in production:

```yaml
# Good
image: myapp:v1.2.3
image: myapp@sha256:abc123...  # Even better: digest

# Bad
image: myapp:latest
image: myapp
```

**Pull from trusted registries only.** Configure admission control to allow only approved registries.

**Scan images for vulnerabilities.** Integrate Trivy, Grype, or similar into CI/CD.

**Use minimal base images.** `distroless`, `alpine`, or `scratch` reduce attack surface.

---

## Namespace Organization

**Use namespaces for isolation.** Separate environments, teams, or applications:

```
namespaces/
├── production/
├── staging/
├── team-a/
└── team-b/
```

**Apply LimitRange and ResourceQuota per namespace.** Prevent resource exhaustion and enforce defaults.

**Use NetworkPolicy per namespace.** Start with default deny, allow explicitly.

**Don't use the `default` namespace.** Create purpose-specific namespaces for all workloads.

---

## Cluster Hardening

**Run CIS Kubernetes Benchmark.** Use `kube-bench` to validate cluster security:

```bash
kube-bench run --targets=master,node
```

**Disable metadata API access from pods.** Prevents cloud credential leakage:

```yaml
# NetworkPolicy blocking metadata API
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-metadata
spec:
  podSelector: {}
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32  # AWS/GCP metadata
              - 100.100.100.200/32  # Azure metadata
```

**Use Pod Security Admission.** Enforce security standards at namespace level:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

**Prefer OIDC for user authentication.** ServiceAccount tokens are for applications; humans should use identity providers.
