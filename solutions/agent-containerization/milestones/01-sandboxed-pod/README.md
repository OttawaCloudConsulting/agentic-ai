# Milestone 01: Sandboxed Pod

> **Authority.** [`REQUIREMENTS.md`](../../REQUIREMENTS.md) is the authoritative register (R1–R15,
> SC-1…SC-8, T1–T45). [`docs/ARCHITECTURE_AND_DESIGN.md`](../../docs/ARCHITECTURE_AND_DESIGN.md) is
> the ratified design (D1–D21). This document cites both by ID and restates neither. Where they
> disagree with anything here, they win.
>
> **Gate-1 label.** The architecture document was written against the two-milestone Gate 1 shape and
> says "sits inside M1" in several places. Gate 3 split Gate-1 M1 into Milestones 01 and 03 — see
> [`prd.md` § Milestones](../../prd.md).

## Goal

The operator can run Claude Code, OpenAI Codex and Google Antigravity inside the pod, each
authenticated and each retaining its session state across a restart, with the egress mediator as
the only route to the internet under a seeded default-deny policy.

**This milestone produces a sandbox that works, not a sandbox that is proven.** R12.8 requires
adversarial validation before real use and that lands in Milestone 02. Until then this environment
runs synthetic repositories and throwaway credentials only.

## Features

### Feature 01.1: Pre-build verification, provider governance and egress discovery

Runs **before** any build work in 01.2–01.5. Produces records and policy artifacts, not code, and
resolves the UNVERIFIED items the architecture names as build blockers.

**Acceptance Criteria:**

- An R14.1 record exists for **every** third party on the agent traffic path before any traffic
  reaches it — Docker Sandboxes (what its proxy observes, stated retention for intercepted traffic,
  deletion and breach-notification terms) and each of the three model providers. Where an assessment
  cannot be completed, the resulting constraint on use is recorded rather than left implicit.
- Each model provider additionally records its version-pinning capability or its absence, the
  history-retention and training-opt-out setting actually in use, and the data classification
  permitted to leave (R14.2).
- Antigravity ToS monitoring (R14.3) has a **named owner** recorded. The Gate 2 open-items table
  currently reads "Unassigned — needs a named person".
- `agy` verification against the pinned version, completed before 01.2 begins:
  (a) whether `agy` honours `HTTPS_PROXY`; (b) whether the `GEMINI_API_KEY` route works, given that
  the official install page documents it and a June 2026 maintainer statement contradicts it;
  (c) its CA-trust mechanism. A negative on (a) leaves `agy` with no route on an `internal: true`
  network — that is a design change under D1, not a build task, and stops 01.2 for that agent. The
  acceptance criterion is that each result is **recorded**, not that each passes; a negative routes
  to `/milestone` revision mode for a rescope, not to a failed feature.
- Each agent's HTTP client is verified to be capable of **presenting a client certificate to a TLS
  proxy listener at all**, before 01.3 builds on the assumption. `HTTPS_PROXY` conveys a URL, not a
  certificate, and HTTP clients of this kind commonly authenticate to a proxy with
  `Proxy-Authorization` rather than TLS client identity — whether any of the three agents can present
  a client certificate to the listener is precisely what this establishes, and it is unverified
  today. If none of the three can, R8.8's mechanism changes shape and
  01.3's largest sub-feature becomes a redesign — cheap to establish here, expensive to discover
  there.
- The default MCP transport is recorded per agent and per configured server — UNVERIFIED for all
  three today, and the input R7.15 needs.
- A discovery run under Docker Sandboxes `locked-down` mode (never `balanced`), one agent at a time,
  against a **synthetic repository with throwaway credentials only** (D17, R12.4, R14.1).
- `policy/allowlist.base.yaml` and `policy/denylist.base.yaml` are committed. The allowlist is
  seeded from the capture and cross-validated against a second source — agent verbose logging or
  `tcpdump` on the mediator during a shadow run — and is marked **provisional** until both sources
  agree (R5.8, D17). No vendor reference allowlist is copied verbatim.
- The denylist covers link-local `169.254.0.0/16` including `169.254.169.254`, loopback and RFC1918
  (R5.6).

### Feature 01.2: Pod topology, hardened runtime and minimal profile

**Acceptance Criteria:**

- `compose/compose.yaml` declares three `internal: true` networks — `claude-net`, `codex-net`,
  `agy-net` — carrying exactly one agent container each, plus an external network to which no agent
  container is ever attached (D2).
- Every agent container runs `cap_drop: ALL`, `no-new-privileges`, a read-only root filesystem with
  `tmpfs` scratch, a non-root user, and explicit CPU, memory and PID ceilings (R1.3, R1.4, R1.6,
  R1.10, D15). No container is granted `--privileged`, `NET_ADMIN` or `NET_RAW` (R1.5). The host
  Docker socket is never mounted (R1.8).
- `profiles/default.yaml` and the minimal profile contract exist, and `docker compose` with a
  profile-selected override is the only entry point — no wrapper CLI (R12.9, D10). The default
  profile mounts the project directory and each agent's state volume, and nothing else.
- Agent versions are pinned at build time and auto-update is disabled — `DISABLE_AUTOUPDATER=1` for
  Claude Code and the per-agent equivalents (R3.5, R10.3).
- Each agent runs non-interactively: Claude Code (R3.1), `codex exec` (R3.2), `agy` (R3.3). The
  Antigravity desktop GUI is not containerized (R3.4). Automation around `agy` gates on the JSON
  `status` field, never the exit code, because `agy` soft-denies unapproved tools and still exits 0
  (R3.6).
- Native agent sandboxes are enabled inside the container as defence in depth — `srt`,
  `features.network_proxy`, `--sandbox` (R3.7, D14) — and are not counted as a boundary. Codex's
  bubblewrap nesting stays disabled: it requires `SYS_ADMIN` plus `seccomp=unconfined`, violating
  R1.4 (R3.8).
- **Smoke checks:** T1 (host filesystem containment) and T2 (read-only enforcement) pass. These are
  prerequisite checks here; 02.2 owns them as recorded adversarial acceptance.
- The CIS Docker Benchmark 1.8.0 Container Runtime section is extracted into a per-recommendation
  applicability table against R1 (Gate 2 open item, unassigned until now).
- `README.md` drift is corrected: its "Out of Scope" section still lists `prd.md`, `progress.txt`
  and `docs/ARCHITECTURE_AND_DESIGN.md` as deliberately not produced, and all three now exist. The
  Gate 2 open-items table dates this "at M1 start".

### Feature 01.3: Egress mediator

The single enforcement point. Four of the mediator's five roles land here; the fifth — upstream
credential brokering — is Milestone 03.

**Acceptance Criteria:**

- One multi-homed mediator is the only path out, exposing **exactly one port to each agent
  network** — the proxy listener. No management port and no metrics port on any agent network
  (R1.2, § Mediator hardening).
- Three independent controls evaluate in order (D5): a default-deny allowlist matched per connection
  at CONNECT/SNI (R5.2, R5.5); a post-resolution CIDR denylist where deny wins (R5.3, R5.7); and
  per-agent rate and concurrency limits.
- The mediator serves DNS for the pod and no agent network has any route to port 53 on the internet
  (R5.4, D3).
- TLS is spliced and never terminated for all three agents: no mediator CA is presented to any
  agent, the mediator holds no plaintext, and Antigravity traffic is never intercepted (R5.15,
  R5.13, D4) — **T28**.
- `Upgrade` is permitted on TCP/443 so Codex's default WebSocket transport does not degrade silently
  (R5.9). Protocols other than TCP/443 and the resolver path are denied, including ICMP and
  arbitrary UDP (R5.10). Optional telemetry endpoints are excluded from the allowlist and disabled
  at the agent (R5.11).
- Each agent is issued a **distinct mTLS workload identity** with a defined lifecycle, used to
  authenticate to the mediator and recorded on every audit line; a credential bound to one identity
  is refused when presented by another (R8.8, D6) — **T34**.
- Every outbound attempt is logged with destination, verdict and timestamp — **blocked attempts
  included** — to a sink no agent container can reach or alter (R9.1, R9.2, D12). Denials are
  surfaced with a clear, actionable message naming the blocked destination, and rules REJECT rather
  than DROP where practical (R9.3, R9.4, R12.2).
- Startup self-checks a known-denied and a known-allowed destination, and a corrupt resolved policy
  aborts startup with a clear error (R9.5) — **T17**.
- Secrets and the CA private key are injected at runtime from a secret manager: never baked into an
  image layer, never on a volume any agent can reach (R8.1, § Mediator hardening).
- **Smoke checks:** T3–T8 pass. 02.2 owns them as recorded adversarial acceptance.

### Feature 01.4: Agent authentication and state persistence

**Acceptance Criteria:**

- `AUTH_MODE` is selectable per agent across `apikey`, `oauth-interactive`, `oauth-token` and
  `oauth-mount`, defaulting to the safest mode each agent supports rather than the most convenient
  (R4.12, D8) — **T24**, run headless for every supported mode.
- Each agent has its own state volume, never shared, with `CLAUDE_CONFIG_DIR`, `CODEX_HOME` plus
  `cli_auth_credentials_store = "file"`, and `~/.gemini` pointed at it (R4.3–R4.6, D7). Volumes are
  treated as secret material, excluded from backups that leave the trust boundary and from version
  control (R4.7, R8.7).
- Every agent has a fully headless authentication path requiring no browser inside the container
  (R4.9). The `oauth-interactive` callback forward is documented (Codex port 1455, fallback 1457,
  published as `127.0.0.1:1455:1455`).
- `oauth-mount` is constrained in shape, not only in policy: a dedicated **directory** is mounted
  and never the credential file itself, `:ro` for bootstrap only, copied into the state volume, so a
  forced OAuth refresh lands on the volume with the host file unchanged (R4.13–R4.15, R4.17) —
  **T25**.
- Where the host git configuration is mounted it is `:ro` with any `credential.helper` entry removed
  first (R2.9) — **T22**.
- Every persisted long-lived refresh token is inventoried with its compensating controls named and
  its review trigger recorded (R4.16) — the inventory half of **T26**; tested revocation with a
  stated maximum detection-to-revocation time belongs to 02.5.
- Refresh-token rotation semantics are verified per provider (Gate 2 open item — the failure most
  likely to make a host-credential mount unworkable in daily use regardless of security posture).
- Restart the pod and every agent is still authenticated with session state intact (R4.1, R4.2,
  SC-4) — **T9**.

### Feature 01.5: Pack composition, policy compiler and build pipeline

The mechanism SC-6 and SC-8 are measured against. Exercised here with the language-runtimes pack;
Terraform, Kubernetes and GitHub CLI arrive in 02.3, AWS CLI in 03.3.

**Acceptance Criteria:**

- A pack manifest schema declares, at minimum: packages with pinned versions and checksums, required
  egress FQDNs and CIDRs, required mounts and their modes, environment variables, credentials,
  whether the pack needs write access, and the pack's blast-radius contribution (R7.3, R7.11).
- The policy compiler composes the resolved egress policy from the profile plus its selected packs
  and emits it as a committed, reviewable artifact under `policy/resolved/`. It runs as a **build
  stage of the mediator image**, not as an operator step (R7.4, D10). Removing a pack removes its
  egress entries, mounts and credentials with no residue (R7.5) — **T14**, exercised by loading and
  unloading the language-runtimes pack.
- **The reference pack declares no runtime egress.** Its toolchains are build-time-only under R7.18,
  so it adds no package-registry entry to the resolved policy. A pack that granted runtime registry
  egress (`registry.npmjs.org`, PyPI, the Go proxy) would enable arbitrary `npx <server>` and break
  **T31** on every profile loading it, and R7.6 keeps runtime-install egress off by default and
  explicitly declared where used. Consequence to accept: T14 here exercises OS-package and mount
  composition, and the **egress** half of the composition delta is re-exercised in 02.3 by the first
  pack carrying unique entries — Terraform (`releases.hashicorp.com`, `registry.terraform.io`) is
  the clean case, since it needs no credential.
- OS packages are declared per pack, version-pinned, sourced from a repository declared in the
  profile, and installed **at image build only**. The agent process cannot invoke a package manager
  at runtime — no privilege and no write access to the paths it would modify (R7.18, R7.19, D10) —
  **T33** and **T15**.
- The profile schema carries R12.7's classification of irreversible or high-impact actions and the
  explicit recorded waiver where a profile waives it. Verification of the gate itself (**T37**)
  belongs to 02.5.
- A profile enabling `oauth-mount` without a recorded accepted-risk decision naming the file, mount
  mode, revocation path and blast radius refuses to build or start (R4.17) — **T27**.
- Mounts beyond the project directory and per-agent state volumes are optional, disabled by default,
  and only those enumerated in R2 are available to enable — forwarded sockets including
  `SSH_AUTH_SOCK` are not among them (R2.8) — **T21**. A build cache, where enabled, is per-agent
  (R2.10) — **T23**.
- A GitHub Actions workflow at the repository root builds the base image and publishes it to GHCR
  with its digest and SBOM; compose consumes it **by digest, never by tag**, and branch-built images
  are consumed by testing only (D21, R10.2, R10.7). Provenance verification (**T45**) and the
  clean-rebuild proof (**T18**) belong to 02.4.

## Dependencies

- **01.1 gates 01.2–01.5.** The `agy` `HTTPS_PROXY` result is go/no-go: on an `internal: true`
  network a client that ignores proxy configuration has no route at all and simply fails. A negative
  is a design change under D1 affecting one agent, and must be resolved before the pod is built, not
  during it.
- **Repository-root `.github/workflows/`** (01.5) is a cross-cutting change outside
  `solutions/agent-containerization/`. This repository has no `.github/` directory today; D21
  introduces its first workflow, and CI becomes a build-time dependency the repo did not previously
  have.
- **External:** Docker Desktop on macOS 26, Apple silicon (R11.1, A1). Model provider APIs reachable
  (A4). Docker Sandboxes (`sbx`) available for the 01.1 discovery run, under the R14.1 constraint.
- **No dependency on Milestone 02 or 03.** Q1 and Q9 should be raised with the operator's
  organisation during this milestone because the lead time is not ours to control, but they block
  only Milestone 03 (D13a).

## Ordering

First milestone — nothing precedes it. Internally the order is fixed by the ratified bring-up
sequence: 01.1 covers its steps 0–2 (assess the provider, run discovery constrained, seed and
cross-validate the allowlist) and 01.2–01.5 cover step 3 (build Option 2 with that policy, meeting
both preconditions — per-agent workload identity and per-agent network isolation). Step 4,
adversarial validation, is Milestone 02 and is what makes the environment usable for real work.

01.3 must precede 01.4 in practice: an agent on an `internal: true` network cannot complete an
OAuth flow until the mediator resolves and permits the provider's auth endpoints.

## Sizing

Five features — the DD-1 ceiling, and a deliberate consequence of the pod being unusable until all
five land.

- **01.3 is the largest.** It maps 1:1 to the `egress-mediator` component and carries four of its
  five roles. Expect one sub-feature per role at `/plan` time: L7 policy engine, DNS resolver, audit
  writer, mTLS identity issuance. The fifth role, credential brokering, is Milestone 03.
- **01.5 splits cleanly** at compiler versus CI pipeline if it runs long.
- **01.1 is discovery-shaped.** Its output is records, verification results and two policy files —
  not code. It is sized by external dependencies (a vendor assessment, a named ToS owner) more than
  by build effort, and it is the feature most likely to return a result that changes the design.
- **01.2 and 01.4** are each a single reviewable unit.

## Configuration

| Parameter | Value at this milestone |
|---|---|
| `profile` | `default` only. Use-case profiles arrive with the pack set in 02.3 |
| `AUTH_MODE` | Per agent, per R4.12 defaults: Claude Code `oauth-interactive` (fallback `oauth-token`), Codex `oauth-interactive`, `agy` `apikey` |
| Tool packs | Language runtimes only, as the reference pack exercising the compiler |
| `policy/allowlist.base.yaml` | Marked **provisional** until the capture and its cross-validation source agree (D17) |

## Definition of Done

- [ ] All features complete (`[x]` in `milestone-status.txt`)
- [ ] All acceptance criteria verified
- [ ] `gate-3-review.md` checklist fully resolved
- [ ] `milestone-status.txt` updated with final counts
- [ ] `progress.txt` milestone summary shows 5/5 features complete
- [ ] SC-4 demonstrated end to end: restart the pod, all three agents still authenticated with state
      intact (T9)
- [ ] The provisional status of `policy/allowlist.base.yaml` is recorded in the file itself
- [ ] `README.md` drift corrected (Gate 2 open item, due at this milestone's start)
- [ ] The environment carries a stated **not for real work** notice until Milestone 02 completes
      (R12.8)
