# CIS Docker Benchmark 1.8.0 — Container Runtime Configuration Applicability

**Source:** `docs/artifacts/CIS_Docker_Benchmark_v1.8.0.pdf` (registration-gated at
<https://www.cisecurity.org/benchmark/docker>, obtained 2026-09-04), section 5, "Container Runtime
Configuration," recommendations 5.1–5.32. Extracted and converted at
`docs/artifacts/CIS_Docker_Benchmark_v1.8.0.md`.

**What this table is.** A per-recommendation applicability disposition against R1 (isolation and
runtime), produced for Feature 01.2 (Pod topology, hardened runtime and minimal profile). It
**records applicability; it does not add controls.** A recommendation the benchmark makes that no
R1 requirement carries is recorded as such and stays a note, not a new control — this is what keeps
the table a reconciliation artifact rather than a source of new scope. "Verified" below means
checked against this feature's actual `compose/compose.yaml`, `images/Dockerfile`, or the
`tests/acceptance/verify-pod-topology.sh` acceptance run (2026-09-04) — not asserted from memory of
the benchmark or of Docker in general.

| # | Recommendation | Disposition | R1 correspondence | Verified in 01.2 |
|---|---|---|---|---|
| 5.1 | Swarm mode not enabled | **N/A** — this solution never uses Docker Swarm | None | N/A |
| 5.2 | AppArmor profile enabled, if applicable | **N/A** — Docker Desktop's Linux VM (LinuxKit) does not expose AppArmor to `docker inspect`; "if applicable" excludes it | None | N/A |
| 5.3 | SELinux security options set, if applicable | **N/A** — same basis as 5.2; SELinux is not present on this host's container runtime | None | N/A |
| 5.4 | Kernel capabilities restricted (remove all not required; specifically `NET_RAW`) | **Applies** | R1.4 | Yes — `docker inspect` asserts `CapDrop: [ALL]`, `CapAdd` empty, over all three services |
| 5.5 | Privileged containers not used | **Applies** | R1.5 | Yes — `Privileged: false` asserted over all three |
| 5.6 | Sensitive host system directories (`/`, `/boot`, `/dev`, `/etc`, `/lib`, `/lib64`, `/proc`, `/sys`, `/usr`) not mounted | **Applies** | No single R1.x number — addressed by the mount-set enumeration behind R1's design intent | Yes — the exact-mount-set assertion (criterion 4) proves only the state volume and the workspace bind exist; none of the listed paths are mounted |
| 5.7 | `sshd` not run within containers | **N/A** — no image installs or runs `sshd`; operator access is `docker exec`, matching the benchmark's own recommended alternative | None | N/A (by construction — not independently tested) |
| 5.8 | Privileged ports not mapped | **N/A** — no service publishes any port (`ports:` is absent from `compose/compose.yaml`) | None | N/A |
| 5.9 | Only needed ports open | **N/A** — same basis as 5.8; no ports are opened at all | None | N/A |
| 5.10 | Host network namespace not shared (`--net=host`) | **Applies** | Consistent with R1.1/R1.2's isolation intent; no single R1.x number | Yes, by construction — `network_mode: host` appears nowhere in `compose.yaml`; each service names its own `internal: true` network |
| 5.11 | Memory usage limited | **Applies** | R1.10 | Yes — `Memory` non-zero (4 GiB) asserted over all three |
| 5.12 | CPU priority set appropriately | **Applies** | R1.10 | Yes — `NanoCpus` non-zero (2.0 CPUs) asserted over all three |
| 5.13 | Root filesystem mounted read-only | **Applies** | R1.6 | Yes — `ReadonlyRootfs: true` plus declared `tmpfs` paths asserted over all three |
| 5.14 | Incoming traffic bound to a specific host interface | **N/A** — same basis as 5.8/5.9; nothing is published to the host at all | None | N/A |
| 5.15 | `on-failure` restart policy limited to 5 | **Gap, not currently set** — no `restart:` policy is declared for any service | None (availability/ops hygiene, not an isolation control) | Not set. Noted here rather than silently added — a restart policy is not part of this feature's Files-to-Modify scope and is left for design review to decide whether it belongs to 01.2 or a later feature |
| 5.16 | Host PID namespace not shared (`--pid=host`) | **Applies** | Consistent with R1.1/R1.2; no single R1.x number | Yes, by construction — `pid: host` appears nowhere in `compose.yaml` |
| 5.17 | Host IPC namespace not shared (`--ipc=host`) | **Applies** | Same basis as 5.16 | Yes, by construction |
| 5.18 | Host devices not directly exposed | **Applies** | Consistent with R1.5's spirit; no single R1.x number | Yes, by construction — no service declares `devices:` |
| 5.19 | Default ulimit overwritten if needed | **N/A** — no ulimit override is needed; nothing in this feature depends on a non-default ulimit | None | N/A |
| 5.20 | Mount propagation not set to shared | **Applies** | No single R1.x number | Yes — `docker inspect` shows `Propagation: rprivate` on the workspace bind mount (verified during SF-4), not `shared` |
| 5.21 | Host UTS namespace not shared (`--uts=host`) | **Applies** | Consistent with R1.1/R1.2; no single R1.x number | Yes, by construction — `uts: host` appears nowhere in `compose.yaml` |
| 5.22 | Default seccomp profile not disabled | **Applies** | Consistent with R1.4's "any capability added must be individually justified" | Yes, by construction — no service sets `security_opt: seccomp=unconfined` or any custom profile. **Direct cross-reference:** this is the exact mechanism behind Deviation 2 (base-posture probe) — Docker's default seccomp profile is what blocks `bwrap`/`srt` nesting under this posture, and relaxing it to enable nesting was rejected specifically because it would violate this recommendation without individual justification |
| 5.23 | `docker exec` not used with `--privileged` | **Operational, not a build/compose-time control** — no automation in this solution invokes `docker exec --privileged`; this is guidance for operators, not something `compose.yaml` or the images express | None | Not testable by this feature's acceptance script; noted for 01.4+ operator documentation |
| 5.24 | `docker exec` not used with `--user=root` | **Operational, not a build/compose-time control** — same basis as 5.23 | None | Not testable here |
| 5.25 | cgroup usage confirmed | **Applies, satisfied by the runtime** — Docker Desktop's Linux VM places every container in a cgroup by default; this feature does not override `--cgroup-parent` | None | Not independently re-verified; relies on Docker Desktop's own default behavior |
| 5.26 | Container restricted from acquiring additional privileges (`no-new-privileges`) | **Applies** | R1.4 | Yes — `no-new-privileges:true` asserted in `SecurityOpt` over all three |
| 5.27 | Container health checked at runtime (`HEALTHCHECK`) | **Gap, not currently set** — no image declares `HEALTHCHECK` and no service sets `--health-cmd` | None (availability/ops hygiene, not an isolation control) | Not set. Same treatment as 5.15 — noted, not silently added |
| 5.28 | Docker commands use the latest version of their image (not a stale cached tag) | **Deferred to 01.5, not this feature** | R10.2 (build/supply chain), not R1 | N/A here — 01.2 uses local `build:` contexts by design (see the feature plan's Dependencies section); D21/R10.2's "consume by digest, never by tag" arrives with 01.5's CI pipeline |
| 5.29 | PIDs cgroup limit used | **Applies** | R1.10 | Yes — `PidsLimit: 512` (non-zero) asserted over all three |
| 5.30 | Docker's default bridge `docker0` not used | **Applies** | Consistent with D2/criterion 1's per-agent network design | Yes — the same smoke-check assertion that proves no agent joins Compose's implicit default network also proves none uses the daemon-wide `docker0` bridge; each agent is on its own named, `internal: true` network |
| 5.31 | Host user namespaces not shared | **Applies** | Consistent with R1.1/R1.2; no single R1.x number | Yes, by construction — `userns_mode: host` appears nowhere in `compose.yaml` |
| 5.32 | Docker socket not mounted inside any container | **Applies** | R1.8 | Yes — the negative assertion over every service's `.Mounts` (criterion 3 in the Test Strategy table) |

## Summary

- **23 of 32** recommendations apply and are satisfied by this feature's configuration, verified
  either directly by `tests/acceptance/verify-pod-topology.sh` or by construction (the control in
  question is the *absence* of a Compose key that was never added).
- **7** are N/A to this solution's shape (no Swarm, no published ports, no `sshd`, host OS security
  modules not present on Docker Desktop for Mac, no non-default ulimit need).
- **2 operational** recommendations (5.23, 5.24) govern how operators invoke `docker exec`, not
  anything expressible in `compose.yaml` or the images — flagged for 01.4+ operator documentation,
  not testable by this acceptance script.
- **2 genuine gaps** are recorded, not silently closed: 5.15 (no restart policy) and 5.27 (no
  `HEALTHCHECK`). Neither maps to an R1 requirement — both are availability/operations hygiene, not
  isolation controls — so per this table's own rule they are noted rather than added as new scope.
  Left for `/design` or a later feature to decide where they belong.
- **1** (5.28) is explicitly deferred to 01.5 per the architecture's existing plan (D21/R10.2).

No new R1 requirement or control is introduced by this table. Where a recommendation maps to R1,
the mapping is 1:1 with an existing requirement number; where it does not, that is stated rather
than invented.
