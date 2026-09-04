# Feature Plan: Pod topology, hardened runtime and minimal profile

**Milestone:** 01 - Sandboxed Pod
**Feature:** 01.2: Pod topology, hardened runtime and minimal profile
**Status:** Planned
**Date:** 2026-09-04

## Summary

Builds the pod's structural half: the Compose topology (three `internal: true` per-agent networks
plus a Compose-managed `egress-net` no agent container is ever attached to, D2), the four
container images (a shared
hardened base plus one per agent), the hardened runtime posture every agent container carries
(`cap_drop: ALL`, `no-new-privileges`, read-only root filesystem with `tmpfs` scratch, non-root
user, explicit CPU/memory/PID ceilings — D15), and `profiles/default.yaml` as the minimal profile
contract with `docker compose` plus a profile-selected override as the only entry point (R12.9,
D10). It also clears two Gate 2 documentation open items dated to this milestone's start: the CIS
Docker Benchmark 1.8.0 Container Runtime applicability table against R1, and the `README.md` drift
correction.

This feature produces a pod that **starts, is hardened, and has no default route to the
internet** — the egress mediator is Feature 01.3. That is a deliberate ordering consequence, not an omission, and it
bounds what 01.2 can honestly verify (see Acceptance Criteria and Test Strategy).

## Acceptance Criteria

Restated from the milestone README with implementation detail added. The README is authoritative
where the two differ.

1. **Network topology (D2).** `compose/compose.yaml` declares `claude-net`, `codex-net` and
   `agy-net`, each `internal: true`, each carrying exactly one agent container. It declares
   `egress-net` as a Compose-managed bridge with `internal: false` (**not** Compose `external:
   true`), to which no agent container is attached. Verified by `docker inspect` asserting each
   agent container's network attachment set has cardinality one and names its own network — which
   also proves no agent picked up Compose's implicit default network.

   **What `internal: true` does and does not give.** It withholds the default route and blocks
   outbound WAN traffic. It does **not** remove Docker's embedded DNS resolver at `127.0.0.11`,
   which continues to answer for container names. Pod DNS authority is D3's, delivered by the
   mediator in 01.3. The smoke check therefore asserts the absence of a default route and the
   failure of outbound WAN reachability, not the absence of a resolver.

2. **Hardened runtime (R1.3, R1.4, R1.6, R1.10, D15).** Every agent container declares
   `cap_drop: ALL`, `security_opt: no-new-privileges:true`, `read_only: true` with enumerated
   `tmpfs` scratch paths, a non-root `user:`, and explicit `cpus`, `mem_limit` and `pids_limit`.
   Verified by asserting the corresponding fields on the running containers, not by reading the
   YAML.

3. **Prohibited grants absent (R1.5, R1.8).** No container declares `privileged`, `NET_ADMIN` or
   `NET_RAW`, and no container mounts the host Docker socket. Verified as a negative assertion over
   `docker inspect` output for every service, so a later service addition cannot silently
   reintroduce one.

4. **Minimal profile and entry point (R12.9, D10).** `profiles/default.yaml` exists and defines the
   profile contract consumed by 01.5's policy compiler. `compose/overrides/default.yaml` exists as
   its hand-authored Compose counterpart. The documented entry point is

   ```
   docker compose --env-file compose/pins.env \
     -f compose/compose.yaml -f compose/overrides/default.yaml up
   ```

   `--env-file` is required, not optional: Compose interpolates `${VAR}` only from the shell, from
   an auto-loaded `.env` in the project directory, or from an explicit `--env-file`. Without it the
   version `build.args` resolve empty and the build fails for a reason the operator cannot see. The
   explicit flag is preferred over renaming to `.env` because R12.9 asks that the operator see
   exactly what runs. This is still `docker compose`; no wrapper CLI is built. The default profile mounts the project directory and each agent's state volume, and
   nothing else — every optional mount in the PRD Configuration table is off. **"Nothing else" is
   asserted, not assumed:** the smoke check enumerates each container's full mount set from
   `docker inspect` and requires it to equal exactly the allowed set (project bind, that agent's
   state volume, the declared `tmpfs` paths). Compose validity is not evidence of this. Build
   cache, host git config, forwarded sockets and any other mount are asserted absent.

5. **Version pinning and auto-update disabled (R3.5, R10.3).** Each agent image installs its agent
   at the version recorded by 01.1 SF-2, delivered to the build as a `build.arg` interpolated from
   `compose/pins.env`. The smoke check asserts `pins.env` agrees with
   `docs/records/agent-verification.md`, so the machine-readable copy cannot drift from the record.
   Auto-update is disabled:
   `DISABLE_AUTOUPDATER=1` for Claude Code and the recorded per-agent equivalents for Codex and
   `agy`. No installation step uses `curl | bash` (R7.7).

6. **Non-interactive invocation (R3.1, R3.2, R3.3, R3.4, R3.6).** Each image's entry point invokes
   its agent non-interactively — Claude Code, `codex exec`, `agy`. The Antigravity desktop GUI is
   not containerized. The `agy` invocation is wrapped so automation gates on the JSON `status`
   field and never on the exit code.
   **Scope limit:** with no mediator present, "runnable non-interactively" is verified in 01.2
   only in its offline form — the agent binary starts as the non-root user on a read-only root
   filesystem and reports its pinned version. A non-interactive run that reaches a model provider
   is not verifiable until 01.3 (route) and 01.4 (authentication) land, and is claimed by neither
   this feature's tests nor its checklist.

7. **Native agent sandboxes (R3.7, R3.8, D14).** The nesting viability of each agent's native
   sandbox inside the hardened container is **verified and recorded** before it is enabled. Where an
   inner sandbox cannot nest without weakening the outer container, R3.8 applies and it is disabled
   with the finding recorded. Codex's bubblewrap nesting is disabled from the outset on the existing
   R3.8 finding. See Edge Cases for the Claude Code case, which is an open design question this
   feature is the first to hit. The smoke check asserts the *record* exists and carries a verdict
   for all three agents; that each container's runtime configuration matches its recorded verdict
   is checked at review, not by the script.

8. **Smoke checks.** T1 (host filesystem containment — attempts to read paths outside declared
   mounts all fail) and T2 (read-only enforcement — a write to a `:ro` mount fails) pass.
   **T2 needs a `:ro` mount and the default profile has none** — it mounts the project `rw`,
   because that is what the profile is for. The test therefore supplies its own dedicated
   read-only fixture mount via a test-only override rather than changing the default profile's
   mode. The fixture exists to make T2 executable; it is not part of the shipped profile. These are
   prerequisite checks here; 02.2 owns them as recorded adversarial acceptance, and this feature
   does not claim adversarial validation.

9. **CIS Docker Benchmark 1.8.0 applicability table.** The benchmark's Container Runtime section
   is extracted into a per-recommendation table mapping each recommendation to an applicability
   disposition (applies / N/A with reason) and to the R1 requirement it corresponds to. **The table
   records applicability; it does not add controls.** A recommendation the benchmark makes that no
   R1 requirement carries is recorded as such and does not become a new control — this is what
   keeps the table a reconciliation artifact rather than a source of scope.

   **The benchmark is a hard prerequisite of SF-5, not a conditional.** It is not held locally —
   `references/README.md:167` carries only a URL, and the download is registration-gated. It is
   obtained before SF-5 begins and the table is written against the actual document; no
   recommendation number is asserted from memory. Because SF-5 is independent of SF-1 to SF-4, this
   prerequisite does not gate the pod build.

10. **`README.md` drift corrected.** The "Out of Scope for This Directory" section at
    `README.md:47-53` no longer lists artifacts that now exist, and the status line at `README.md:5`
    reflects the ratified Gate 2 state. See Edge Cases for the precision point on the architecture
    document's actual path.

## Approach

**Ordering.** The four sub-features run in order. SF-1 declares the topology and hardening in
Compose; SF-2 builds the hardened base image and the home-seeding mechanism; SF-3 layers the three
pinned agents onto it and settles each one's native-sandbox disposition; SF-4 adds the profile
contract, the override, the entry point and the smoke checks that exercise SF-1 to SF-3 together;
SF-5 is documentation and depends on none of them.

**Topology.** Networks are declared in `compose/compose.yaml` rather than an override, because the
isolation property is D2's ratified invariant and must not be profile-selectable. Each agent
service names exactly one network. `egress-net` is declared here but carries no service until
01.3 attaches the mediator to it; a Compose network with no attached service is valid and inert,
which is what makes the 01.2/01.3 seam clean.

**Naming precision.** `egress-net` is a **Compose-managed bridge network declared with
`internal: false`**. It is deliberately *not* Compose's `external: true`, which denotes a network
created outside the project and expected to pre-exist — that would make `docker compose up` fail
on a clean machine. The architecture document's phrase "the external network" (D2) means "the
network with a route out", not Compose's `external:` key. Read it that way everywhere in this
plan.

**Hardening.** Read-only root filesystem is the constraint that shapes the image layout: every path
the agent writes must be either `tmpfs` (ephemeral) or on the per-agent state volume (persistent).
The decision that resolves this is to **mount each agent's state volume at the agent user's home
directory** rather than at a subdirectory of it. Agents in this set write directly into `$HOME`
(`~/.claude.json` is documented behaviour), so a volume mounted deeper leaves `$HOME` read-only and
the agent fails at startup. Mounting at `$HOME` makes `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and
`~/.gemini` all resolve onto the volume, which is exactly what R4.3-R4.6 and D7 require. 01.2 owns
this mount and environment wiring; 01.4 owns the authentication semantics that sit on top of it.
The contract is stated below so 01.4 does not re-decide it.

**Home seeding, because a named volume masks the image.** Docker copies an image's content at a
mount path into a named volume **only when that volume is empty**. On every later run the volume
wins, so any home file the image ships is visible on first run and silently shadowed afterwards —
a rebuilt image with a corrected default config would appear to take effect and would not. That
breaks SC-8's "identical rebuild" for anything under `$HOME`. The image therefore ships **no
files under `/home/agent`**. It ships a skeleton at the immutable path `/opt/agent-home-skel`,
and the entrypoint seeds missing paths from the skeleton into the volume on every start,
idempotently — creating what is absent and never overwriting agent-owned state. This is the
mechanism that keeps a state volume upgradable across an image rebuild rather than requiring the
operator to destroy it.

**Images and the build context.** A shared `images/agent-base/Dockerfile` establishes the
non-root user, the home skeleton and the writable-path layout; three thin per-agent Dockerfiles
layer the pinned agent onto it. **All four services use a single build context, `./images`**, with
`dockerfile:` selecting the per-agent file. One context means one `images/.dockerignore` governs
every build — `.dockerignore` is resolved relative to the build context and not to the Compose
file, so a solution-root ignore file would not apply to a context under `images/`.

**Version pins reach the build as build args, not as a document.** A Dockerfile cannot read
`docs/records/agent-verification.md`, and that record is outside the build context by design. SF-2
therefore derives a machine-readable `compose/pins.env` from the 01.1 record — one
`<AGENT>_VERSION` per agent plus its install source — and Compose interpolates those into
`build.args`. The markdown record stays the human authority; `pins.env` is its checked derivative,
and the test asserts the two agree so they cannot drift. A pin absent from `pins.env` fails the
build; nothing defaults to `latest`.

Builds are local `build:` contexts in this feature. D21/R10.2's "consume by digest, never
by tag" is delivered by 01.5's CI pipeline; until then local builds are the only option, and this
is a known temporary state rather than a deviation from R10.2.

**Native sandbox posture.** Rather than enabling the three native sandboxes on D14's default
assumption, SF-2 probes the base posture (can bubblewrap mount a fresh `/proc` under `cap_drop:
ALL` and `no-new-privileges` at all?) and SF-3 records the per-agent verdict against it. Each
sandbox is enabled only if it nests without requiring a capability R1.4 forbids. The result is
recorded per agent whether it passes or fails.
This mirrors 01.1's treatment of the `agy` `HTTPS_PROXY` question: the acceptance criterion is that
the result is recorded, not that it passes.

**Verification style.** Assertions run against `docker inspect` on running containers rather than
against the Compose YAML, because the YAML is the input to the property and not the property
itself. An override file, a Compose version difference or a default could each produce a running
container that does not match its declaration.

## Sub-Features

- [ ] **SF-1: Compose topology and hardened service declarations** — `compose/compose.yaml` with the
  three `internal: true` per-agent networks, `egress-net` as a Compose-managed bridge
  (`internal: false`, not Compose `external:`), the three agent services carrying the full D15
  hardening set, the three named state volumes, the project bind mount, and the shared `./images`
  build context with per-service `dockerfile:` and `build.args`. Every service names its network
  explicitly so none joins Compose's implicit default. Depends on nothing inside this feature;
  depends on 01.1 SF-2 only for the pins it interpolates.

- [ ] **SF-2: Hardened base image and the home-skeleton mechanism** — `images/agent-base/Dockerfile`
  and `images/agent-base/entrypoint.sh`, plus `images/.dockerignore` and `compose/pins.env` derived
  from the 01.1 record. Establishes the non-root `agent` user, the read-only-rootfs writable-path
  layout, the `/opt/agent-home-skel` skeleton and the idempotent seeding entrypoint. **Carries the
  base-posture nesting probe:** whether bubblewrap can mount a fresh `/proc` under `cap_drop: ALL`
  plus `no-new-privileges` is a property of this posture, not of any one agent, and it is the
  cheapest early signal on the D14 question (`RESEARCH_FINDINGS.md:76`). The result is recorded
  whether it passes or fails. Depends on SF-1 only for the build-context shape.

- [ ] **SF-3: Per-agent images, pins and native-sandbox disposition** — `images/claude/`,
  `images/codex/`, `images/agy/` plus `images/agy/agy-run.sh`. Thin layers on SF-2's base: pinned
  agent installation via `ARG` with no `curl | bash`, auto-update disabled, the non-interactive
  entry points, and the `agy` JSON `status` gating wrapper. **Records the per-agent native-sandbox
  verdict** (R3.7/R3.8/D14) against SF-2's base-posture result and configures each agent to follow
  its own verdict — `srt` for Claude Code, `features.network_proxy` for Codex, `--sandbox` for
  `agy`, each enabled only if it nests without a capability R1.4 forbids. Codex's bubblewrap
  nesting is disabled from the outset on the existing R3.8 finding. Depends on SF-2.

- [ ] **SF-4: Minimal profile contract, entry point and smoke checks** — `profiles/default.yaml`
  (the schema 01.5's compiler consumes), `compose/overrides/default.yaml` as its hand-authored
  Compose counterpart, `compose/overrides/test-readonly.yaml` supplying T2's read-only fixture
  mount, the documented `docker compose` invocation, and
  `tests/acceptance/verify-pod-topology.sh` implementing the topology, hardening, prohibited-grant,
  mount-enumeration, route, pin-agreement, record-presence and offline-version assertions plus the
  volume-upgrade check, T1 and T2. Depends on SF-1, SF-2 and SF-3.

- [ ] **SF-5: CIS applicability table and README drift correction** —
  `docs/cis-docker-runtime-applicability.md` mapping the benchmark's Container Runtime
  recommendations to R1 with an applicability disposition each, plus the `README.md` corrections at
  `:5` and `:47-53`, the documented entry point, the no-egress prerequisite, and the **not for real
  work** notice R12.8 requires until Milestone 02 completes. Documentation only; independent of
  SF-1 to SF-4. **Blocked until the CIS Docker Benchmark 1.8.0 is obtained** — see criterion 9.

Sizing note: five sub-features, each a single reviewable unit judged against DD-1's ~120k-token
session guideline. The base image and the three agent images were split at Gate 4 (SF-2 / SF-3) on
the operator's decision: the base carries the writable-path layout, the seeding mechanism and the
posture probe, and the per-agent layer carries the pins and the sandbox dispositions that read the
probe's result. DD-1's 2-5 ceiling governs features per milestone, not sub-features per feature, so
five is a judgement about session size here rather than a limit. None is flagged `[OVERSIZED]`.

## Interface Contracts

### 1. Version pin record — consumed from 01.1 SF-2

01.1 records, per agent, in `docs/records/agent-verification.md`: `agent`, `version`,
`image digest or install source`, `date pinned`. That file is a human record outside the build
context; a Dockerfile cannot read it. SF-2 therefore derives `compose/pins.env` from it:

```
CLAUDE_VERSION=<version>
CLAUDE_SOURCE=<install source or digest>
CODEX_VERSION=<version>
CODEX_SOURCE=<install source or digest>
AGY_VERSION=<version>
AGY_SOURCE=<install source or digest>
```

Compose interpolates these into each service's `build.args` **when the file is passed as
`--env-file compose/pins.env`** — see criterion 4 for the full invocation. The Dockerfiles take
them as `ARG` and fail the build if one is empty. Nothing defaults to `latest`. The record remains authoritative
and `pins.env` is its checked derivative — the smoke check asserts the two agree, so a hand-edit
to either is caught rather than silently shipped.

### 2. Container filesystem layout — produced by 01.2, consumed by 01.4

Per agent container:

| Path | Kind | Mode | Purpose |
|---|---|---|---|
| `/` | image layer | read-only | R1.6 |
| `/opt/agent-home-skel` | image layer | read-only | Home skeleton. The image ships home defaults **here**, never under `/home/agent` |
| `/home/agent` | named volume (`<agent>-state`) | read-write | Agent home. Carries all persistent agent state. Seeded from the skeleton at start |
| `/tmp` | `tmpfs` | read-write, `noexec`, `nosuid` | Scratch |
| `/run` | `tmpfs` | read-write, `noexec`, `nosuid` | Runtime files |
| `/home/agent/.cache` | on the state volume | read-write | npm/XDG cache. On the volume rather than `tmpfs` so a rebuild does not re-download |
| `/workspace` | bind mount | per profile | The project directory (R2.1) |

This mount set is exhaustive. The smoke check asserts each container's mounts equal exactly this
set for its agent, with nothing added.

**Seeding contract.** `images/agent-base/entrypoint.sh` runs before the agent and, for each path
in `/opt/agent-home-skel`, creates it under `/home/agent` **only if absent**. It never overwrites
an existing file, so agent-owned state and credentials written by 01.4 survive every restart and
every image rebuild, while a newly added default appears on the next start. The entrypoint is the
only component permitted to write to `/home/agent` outside the agent process itself.

Environment, set in 01.2 and relied on by 01.4:

| Variable | Value | Requirement |
|---|---|---|
| `HOME` | `/home/agent` | — |
| `CLAUDE_CONFIG_DIR` | `/home/agent/.claude` | R4.4 |
| `CODEX_HOME` | `/home/agent/.codex` | R4.5 |
| `GEMINI_*` home | `/home/agent/.gemini` | R4.6 |
| `DISABLE_AUTOUPDATER` | `1` (Claude Code) | R3.5, R10.3 |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | Prevents startup telemetry blocking on a pod with no default route |

The user is `agent`, uid/gid 1000. Paths that receive write grants are pre-created in the image,
because on Linux write grants apply only to paths that already exist.

### 3. Profile schema — produced by 01.2, consumed by 01.5

`profiles/default.yaml` establishes the shape the policy compiler reads. The default profile
populates only what the minimal contract requires; the remaining keys are declared with empty or
`false` values so the schema is complete rather than grown ad hoc later.

```yaml
name: default
packs: []                      # 01.5 composes egress from these. Empty at this profile
auth_mode:                     # R4.12 defaults, consumed by 01.4
  claude: oauth-interactive
  codex: oauth-interactive
  agy: apikey
mounts:
  project:
    path: <host path>
    mode: rw                   # :ro where the agent only reviews (R2.7). Default is rw;
                               # T2's read-only fixture comes from a test-only override,
                               # not from changing this
  build_cache: false           # R2.10, per-agent where enabled
  host_git_config: false       # R2.9, :ro with credential.helper stripped
limits:                        # R1.10, applied per agent container
  cpus: "2.0"
  memory: 4g
  pids: 512
exports:                       # R9.9 — export toggles only; recording is not disableable
  egress_audit_log: true
  agent_action_log: true
  resolved_policy: true
  image_digest_sbom: true
```

The `limits` values are proposals for confirmation at review, not derived from a measurement.

### 4. Compose seam — produced by 01.2, extended by 01.3

`compose/compose.yaml` after 01.2 declares four networks (`claude-net`, `codex-net`, `agy-net`,
`egress-net`), three agent services, three volumes, and a single `./images` build context shared
by all three services. 01.3 adds one `egress-mediator` service attached to all four networks and adds
`HTTPS_PROXY`/`HTTP_PROXY` plus the DNS setting to each agent service. 01.2 does not stub the
mediator and does not set proxy environment variables that point at nothing.

### 5. `agy` exit-status wrapper

`agy` soft-denies unapproved tools and still exits 0 (R3.6). SF-3 ships `images/agy/agy-run.sh`, which parses the
JSON output, reads the `status` field, and exits non-zero on a denial or failure status. Callers
gate on the wrapper's exit code; nothing in this solution gates on `agy`'s own.

## Edge Cases

1. **Claude Code's native sandbox may not nest — open design question.**
   `docs/RESEARCH_FINDINGS.md:76` records that inside an unprivileged container, bubblewrap cannot
   mount a fresh `/proc` (`bwrap: Can't mount proc on /newroot/proc`), and that the documented
   workaround `sandbox.enableWeakerNestedSandbox: true` is described by Anthropic as "considerably
   weakens security". Separately, `:83` records that `srt` on Linux **removes the network namespace
   entirely** and reaches proxies over bind-mounted Unix sockets via `socat` — which does not
   obviously compose with 01.3's design of reaching the mediator over `claude-net` via
   `HTTPS_PROXY`. R3.8 already names Codex's bubblewrap nesting as a disable-the-inner-sandbox case
   for exactly this reason; the same reasoning appears to apply to Claude Code, but D14 enables
   `srt` and the Gate 2 open-items table does not list this. **Handling:** SF-2 probes the base
   posture and SF-3 verifies and records
   the result per agent before enabling anything. If Claude Code's native sandbox cannot nest
   without a capability R1.4 forbids, R3.8 applies, the inner sandbox is disabled, and the finding
   is recorded under Architectural Deviations and routed to `/milestone` revision mode as a D14
   amendment — not resolved silently inside the build.

2. **`srt` starts successfully without its settings file.** `RESEARCH_FINDINGS.md:85` records that
   without a valid `~/.srt-settings.json` it starts anyway with network blocked and a small default
   write set — a clean start is not proof the settings loaded. If `srt` is enabled at all, it is
   invoked with an explicit `--settings` path so a load failure refuses to start.

3. **The pod has no default route in 01.2, and its DNS is Docker's, not the pod's.** Any image
   build step or entry point that assumes outbound access at container run time fails; all network
   access is confined to image build, and the test script must pass with no egress. Two precisions
   matter for what the tests may claim. First, `internal: true` withholds the default route and
   blocks WAN egress — it is not a proof that nothing on the host or in RFC1918 is reachable, and
   the plan does not claim one; full RFC1918, loopback and metadata denial is R5.6's, delivered by
   the mediator's denylist in 01.3. Second, Docker's embedded resolver at `127.0.0.11` is still
   present and still answers for container names; D3's pod DNS authority arrives with the mediator.
   The smoke check asserts no default route and no WAN reachability, and asserts nothing about the
   resolver.

4. **Read-only rootfs surfaces at first run, not at build.** An agent writing to a path that is
   neither `tmpfs` nor on the state volume fails only when the container runs. The smoke check runs
   each agent's version command as the non-root user with the read-only rootfs active, so the
   failure surfaces inside this feature rather than in 01.4.

5. **The `README.md` drift is narrower than the milestone README states.** The milestone README
   says `prd.md`, `progress.txt` and `docs/ARCHITECTURE_AND_DESIGN.md` "all three now exist".
   `prd.md` and `progress.txt` do exist at the solution root. The architecture document exists at
   `.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md`, **not** at
   `docs/ARCHITECTURE_AND_DESIGN.md` where `README.md:52` and the architecture document's own file
   tree both place it. The correction states the actual path rather than asserting a file exists
   where it does not. The path discrepancy itself is recorded as a finding for `/project`, not
   fixed here.

6. **`README.md:53` becomes stale during this feature, not before it.** It lists "Dockerfiles,
   Compose files, firewall scripts, policy files, tool-pack manifests" as not produced. That is
   true today; 01.1 makes the policy-file half false and 01.2 makes the Dockerfile and Compose half
   false. SF-5 rewrites the section against the state at the end of 01.2, not against today's.

7. **A later service addition can silently drop hardening.** The prohibited-grant assertions
   enumerate services from `docker inspect` output rather than checking a fixed list of three, so a
   service added in 01.3 or later is covered by the same check.

8. **A populated state volume shadows a rebuilt image — the highest-value failure to design out.**
   Docker seeds a named volume from the image only when the volume is empty. On every subsequent
   run the volume wins. Without the `/opt/agent-home-skel` split, a corrected default shipped in a
   new image would be invisible on any workstation with an existing volume, the pod would appear
   correct, and SC-8's identical-rebuild claim would be false for everything under `$HOME`. The
   split plus idempotent seeding is what makes a state volume upgradable instead of disposable.
   The failure is silent by nature, so the smoke check covers it directly: run once, rebuild with a
   changed skeleton file, run again, assert the new file is present and that an agent-written file
   was not overwritten.

9. **`.dockerignore` is resolved against the build context, not the Compose file.** A
   `.dockerignore` at the solution root would not govern a context under `images/`. All three
   services therefore share the single context `./images` with one `images/.dockerignore`. Nothing
   the build must read may be excluded by it — which is the second reason version pins arrive as
   `build.args` rather than as a file the build is expected to open.

10. **Compose's implicit default network.** A service naming no network joins a project-default
    bridge with a route out. The cardinality-one network assertion in criterion 1 catches this,
    which is why it asserts an exact attachment set rather than merely that the intended network is
    present.

## Test Command

```
bash tests/acceptance/verify-pod-topology.sh
```

## Test Strategy

The script runs **two bring-ups** and must pass with no network access.

- **Phase A — default profile only.** `--env-file compose/pins.env` plus `compose.yaml` and
  `overrides/default.yaml`. Every assertion below runs here, including the mount-set equality check
  for criterion 4.
- **Phase B — T2 only.** The same invocation with `overrides/test-readonly.yaml` layered on, which
  adds the read-only fixture mount. Only T2 runs in this phase.

The split is necessary because the two checks are mutually exclusive by construction: criterion 4
requires each container's mount set to *equal exactly* the allowed set, and the T2 fixture is an
additional mount. Layering the override during phase A would fail mount equality; omitting it
entirely would leave T2 with no target.

Both phases use a test-scoped Compose project name (`-p`) and end in `down -v`, so the
volume-upgrade check, T1 and T2 never touch the operator's real state volumes.

**What is tested:**

| Check | Assertion | Criterion |
|---|---|---|
| Compose validity | `docker compose config` succeeds against base + default override | 4 |
| Network isolation | Each agent container attached to exactly one network; that network is `internal` | 1 |
| Egress network | No agent container attached to `egress-net`; `egress-net` is `internal: false` and Compose-managed | 1 |
| Default network | No agent container attached to Compose's implicit project-default network | 1 |
| No default route | `ip route` inside each agent container shows no default route; a WAN TCP connect fails | 1 |
| Capabilities | `CapDrop` contains `ALL`; `CapAdd` empty | 2 |
| Privilege escalation | `no-new-privileges` present in `SecurityOpt`; `Privileged` false | 2, 3 |
| Root filesystem | `ReadonlyRootfs` true; declared `tmpfs` paths present and writable | 2 |
| User | Effective uid is non-zero | 2 |
| Resource ceilings | `NanoCpus`, `Memory` and `PidsLimit` all non-zero | 2 |
| Docker socket | No mount whose source is the host Docker socket, over all services | 3 |
| Mount set | Each container's `.Mounts` equals exactly its allowed set; build cache, git config and sockets absent | 4 |
| Network capabilities | Neither `NET_ADMIN` nor `NET_RAW` granted, over all services | 3 |
| Agent starts | Each agent reports its version as the non-root user on a read-only rootfs | 6 |
| Version pin | Reported version equals the `pins.env` build arg | 5 |
| Pin agreement | `compose/pins.env` agrees with `docs/records/agent-verification.md` | 5 |
| Sandbox record | `docs/records/agent-verification.md` carries a nesting verdict for all three agents | 7 |
| Volume upgrade | After a rebuild with a changed skeleton file, the new file appears and an agent-written file is unchanged | 2 |
| T1 | Reads of paths outside declared mounts fail | 8 |
| T2 | Write to the read-only fixture mount supplied by `test-readonly.yaml` fails | 8 |

**What is not tested here:** anything requiring egress, DNS, authentication or a model provider.
T3-T8 belong to 01.3, T9 and the `AUTH_MODE` matrix to 01.4, and adversarial acceptance of T1 and
T2 to 02.2. The script asserts hardening is *declared and effective on the running container*; it
does not assert the boundary is *unbreakable*, which is R12.8's job in Milestone 02.

**Coverage expectation:** criteria 1-6 and 8 are each exercised by at least one assertion.
Criterion 7 is **partly** automated — the script asserts the nesting record exists and carries a
verdict per agent, but whether each container's configuration follows its verdict is a review
judgement, not a scriptable one. Criteria 9 and 10 are documentation and are verified by review
alone. Criterion 7's configuration half and criteria 9 and 10 are marked `[-]` against automated
coverage in the checklist with that reason, rather than being claimed as tested.

## Documentation

- `docs/cis-docker-runtime-applicability.md` — new (SF-5, acceptance criterion 9). Written against
  the obtained benchmark; no recommendation number asserted without the source document.
- `README.md` — corrections at `:5` and `:47-53` (SF-5, acceptance criterion 10).
- `docs/records/agent-verification.md` — appended, not created: the base-posture probe result from
  SF-2 and the per-agent native-sandbox verdicts from SF-3 join the verification records 01.1
  established there.
- `README.md` — the entry-point invocation and the prerequisite that the pod has no egress until
  01.3, added under the existing structure. Full first-run and troubleshooting documentation (R12.6)
  is not this feature's; it needs authentication, which is 01.4.
- The **not for real work** notice required by the milestone Definition of Done (R12.8) is added to
  `README.md` here, since 01.2 is the first feature to produce a runnable artifact.

## Files to Create/Modify

Paths are relative to `solutions/agent-containerization/`.

| File | Action | Changes |
|------|--------|---------|
| `compose/compose.yaml` | Create | 3 `internal: true` networks + `egress-net` (`internal: false`, Compose-managed); 3 agent services with the full D15 hardening set; 3 named state volumes; project bind mount; shared `./images` build context with per-service `dockerfile:` and `build.args` |
| `compose/overrides/default.yaml` | Create | Hand-authored Compose counterpart of `profiles/default.yaml` — the R12.9 entry point |
| `compose/overrides/test-readonly.yaml` | Create | Test-only override adding T2's read-only fixture mount. Not a shipped profile |
| `compose/pins.env` | Create | Machine-readable derivative of the 01.1 pin record. Committed. Passed as `--env-file` and interpolated into `build.args` |
| `images/.dockerignore` | Create | Governs the single `./images` build context. Excludes nothing the build must read |
| `images/agent-base/Dockerfile` | Create | Non-root `agent` user (1000), `/home/agent` as an empty mount point, home defaults at `/opt/agent-home-skel`, pre-created writable paths, read-only-rootfs layout |
| `images/agent-base/entrypoint.sh` | Create | Idempotent seeding of `/opt/agent-home-skel` into the state volume; never overwrites existing files |
| `images/claude/Dockerfile` | Create | Pinned Claude Code, `DISABLE_AUTOUPDATER=1`, `CLAUDE_CONFIG_DIR`, native sandbox per the SF-3 verdict |
| `images/codex/Dockerfile` | Create | Pinned Codex CLI, auto-update off, `CODEX_HOME`, `features.network_proxy` on, bubblewrap nesting disabled (R3.8) |
| `images/agy/Dockerfile` | Create | Pinned `agy`, auto-update off, `~/.gemini` home, `--sandbox` per the SF-3 verdict, JSON `status` wrapper |
| `images/agy/agy-run.sh` | Create | Exit-status wrapper gating on the JSON `status` field (R3.6) |
| `profiles/default.yaml` | Create | The minimal profile contract; the schema 01.5's compiler consumes |
| `tests/acceptance/verify-pod-topology.sh` | Create | The Test Command. `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644, invoked as `bash` |
| `docs/cis-docker-runtime-applicability.md` | Create | Per-recommendation applicability table against R1. Records applicability only; adds no controls |
| `docs/records/agent-verification.md` | Modify | Append the base-posture probe result and the native-sandbox verdict per agent. Also the source `compose/pins.env` is derived from — see Interface Contract 1 |
| `README.md` | Modify | `:5` status line; `:47-53` Out of Scope section; entry point; no-egress prerequisite; not-for-real-work notice |

## Dependencies

**On Feature 01.1 — build cannot start until these records exist:**

- **01.1 SF-2 version pins** (`docs/records/agent-verification.md`): the three agent versions and
  install sources. SF-2 derives `compose/pins.env` from them; SF-3's Dockerfiles take them as
  `ARG`.
- **01.1 SF-2 `agy` `HTTPS_PROXY` result**: go/no-go for the `agy` container. A negative is a design
  change under D1 and may remove `agy` from this feature's scope entirely. The milestone README
  states it must be resolved before the pod is built, not during it.
- 01.1 SF-1 and SF-3 outputs are **not** consumed by 01.2. The allowlist and denylist are 01.3's
  input.

**On later features — deliberately absent here:**

- **No mediator.** 01.3 adds it. The pod has no default route and no WAN egress during 01.2,
  and no pod DNS authority — Docker's embedded resolver is what answers until D3 lands.
- **No CI-published base image.** D21/R10.2's consume-by-digest is 01.5. 01.2 uses local `build:`
  contexts, which is a known temporary state, not a deviation from R10.2.
- **No authentication.** 01.4 owns `AUTH_MODE` and credential bootstrap. 01.2 provides the volume
  and environment wiring they land on.
- **No policy compiler.** 01.5 consumes `profiles/default.yaml`; 01.2 defines its shape.

**External:**

- Docker Desktop on macOS 26, Apple silicon (R11.1, A1). Multi-arch base image selection follows
  from this.
- Upstream package sources reachable at image build time only.
- **CIS Docker Benchmark 1.8.0** — a hard prerequisite of SF-5. Not held locally: only a URL at
  `references/README.md:167`, registration-gated. Obtain it before SF-5 begins. SF-5 is independent
  of SF-1 to SF-4, so this blocks the applicability table and nothing else in the feature.

**Repository state:** greenfield. No tracked Dockerfile, Compose file or `.dockerignore` exists
anywhere in this repository, and there is no `.github/` directory. There is no in-repo container
prior art to inherit. Shell scripts follow `#!/usr/bin/env bash`, `set -euo pipefail`, mode 644,
invoked as `bash script.sh`.

## Architectural Deviations

(none)
