# Feature Plan: Tool pack set, use-case profiles and MCP inventory

**Milestone:** 02 - Proven and Composable
**Feature:** 02.3: Tool pack set, use-case profiles and MCP inventory
**Status:** Planned
**Date:** 2026-09-10

## Summary

01.5 built the composition mechanism and exercised it with one pack that declares no runtime
egress, no environment and no credential — so SC-6 has never been measured against a pack that
changes the boundary. This feature ships the remaining non-AWS R7.10 packs — **Terraform**,
**Kubernetes** (`kubectl`, `helm`) and **GitHub CLI** — with real runtime egress and real
credentials. It gives packs the two landing points D10's 01.5 amendment refused: a non-secret
**environment** baked into the per-profile image, and a **credential** delivered as a
profile-scoped Compose `file:` secret. It adds one named **use-case profile** per pack, and it
records T14 against Terraform, the clean case. It builds the **MCP inventory** R7.14 requires: a
profile-level declaration carrying the full R7.3 field set, baked into the image and enforced by a
start-time gate that refuses an uninventoried server and reports a changed one as drift (T29–T32).
Every third party the packs put on the agent traffic path gets an R14.1 record before any traffic
reaches it (T42 re-inspected). `validate-boundary.sh` then re-runs against every shipped profile.
Several findings are **recorded rather than closed**: T32's register text cannot be satisfied under
D14, a public-FQDN-only Kubernetes reach, and the github.com code-fetch residual.

## Acceptance Criteria

Refined from the milestone README with the facts the codebase scan established:

1. **Three packs ship** — `packs/terraform/`, `packs/kubernetes/`, `packs/github-cli/`. Each
   declares every R7.3 field: pinned packages with SHA-256, runtime egress FQDNs and CIDRs, mounts
   and their mode, environment variables, credentials, write-access need, and an R7.11 blast-radius
   statement. A field that does not apply is an explicit empty list, never omitted. AWS CLI is
   Milestone 03.
2. **Packs gain `env` and `credentials` landing points, and `mounts` stays refused.** The compiler
   stops refusing `env` and `credentials` at exit 3. It validates them against Interface Contract 1,
   and each lands at a named place:
   - `env` is baked into the per-profile image and exported by the entrypoint.
   - `credentials` become Compose `file:` secrets, sourced per profile.

   No shipped pack needs a host mount, so the `mounts` refusal stays. Its stale message ("land at
   01.5 SF-5") is corrected to say that a pack mount is a design change reviewed against R2.8's
   enumeration. An unknown top-level manifest key is refused, so a pack cannot carry `cap_add`,
   `privileged` or `devices` silently (R7.8).
3. **R14.1 before traffic, mechanically.** A pack whose `egress.runtime` is non-empty must name, in
   `third_parties`, the `third-party-assessments.md` record for each party it reaches.
   `lint-policy.sh` refuses the pack if that record anchor does not resolve. Records exist for
   **HashiCorp** (`registry.terraform.io`, `releases.hashicorp.com`) and **GitHub**
   (`api.github.com`, `github.com`). The **Kubernetes** position is recorded:
   - The shipped pack reaches nothing at runtime.
   - Each per-cluster egress pack carries its own record for the cluster's hosting party before it
     can be loaded.

   **T42 is re-inspected and extended** to every party, and the inspection is recorded.
4. **T14 recorded acceptance, on Terraform** (reassigned from 01.5 per `gate-3-review.md`).
   `terraform` and `default` are compiled with `COMPILED_AT` fixed. Per agent, the entries gained
   equal exactly `packs/terraform/pack.yaml`'s `egress.runtime` entries and nothing else. Removing
   the pack from a probe copy of `terraform` and recompiling gives an artifact byte-identical to
   `default` apart from `compiled_from`, so no residue remains (R7.5). The GitHub overlap case is
   recorded under the same rule (Decision 4).
5. **Credential delivery is stated, and scoped to one profile** (R8.2, MUST).
   - The GitHub token and the `kubeconfig` are secret-injected: operator-staged files under
     `compose/generated/credentials/<profile>/<pack>/`, mounted `:ro` at `/run/secrets/pack-*`.
   - Under a profile that does not load the pack, no such secret and no `GH_TOKEN`/`KUBECONFIG` is
     present in any agent container. This is **verified from inside each container**, not read off
     the Compose file.
   - Each credential is enumerated under R8.4 in `docs/records/credential-inventory.md`, with its
     blast radius, its independent revocation path (R7.12) and its rotation. Rotation is a file swap
     plus `--force-recreate` with **no rebuild** (R8.5), which feeds 02.5's timing.
   - **R8.3 is not met and the record says why:** upstream brokering is Milestone 03.
6. **Named use-case profiles** `terraform`, `kubernetes` and `github` exist, each the `default`
   profile plus one pack. Each has a committed resolved artifact and a hand-authored
   `compose/overrides/<profile>.yaml`. **SC-6 is measured live:** `AGENT_PROFILE=<p> docker compose
   … up --build --force-recreate` loads each profile in turn and then returns to `default`. The
   mediator's live policy reports the pack set each time, the pack's binaries appear and disappear,
   and no policy file is edited by hand.
7. **R7.8 holds across every profile.** The rendered `docker compose config` agent services —
   including the hardening fields
   `cap_drop`, `cap_add`, `security_opt`, `read_only`, `user`, `privileged`, `devices`,
   `network_mode`, `pid`, `ipc` and the limits — are identical per agent to `default` for every
   shipped profile, apart from `secrets` and the `PROFILE` build argument. Every agent-side difference between a profile and `default` is one of that
   profile's declared pack secrets.
8. **The MCP inventory is built and enforced** (R7.14, D18). Every profile carries an `mcp:` block
   that inventories servers, plugins and skills per agent. Each server entry records the full R7.3
   field set, its version and checksum, a risk tier (read-only / write / irreversible), a transport
   with its enforcement point, and a capability baseline (Interface Contract 5). **No shipped profile
   inventories a server**; T29–T31 are exercised with fixture entries (Decision 9). The compiler
   refuses an incomplete entry, and it composes an HTTP server's declared egress into the listed
   agents' allowlists (D18: "declare their own egress").
9. **T29.** A start-time gate in the agent entrypoint checks the image-baked inventory against
   every enumerated capability-declaration file for the agent. An uninventoried server, plugin or
   skill **refuses the start at exit 3**, naming the file and entry. An inventoried server whose
   canonical config entry no longer matches its baseline refuses as **drift** and prints both
   hashes. Neither is ever silently accepted.
10. **T30.** Every inventoried server records its transport and names its enforcement point, and a
    stdio server states `none` (R7.15, D18). The compiler enforces the pairing: an `http`/`sse`
    server must name `mediator` and declare the FQDN it reaches, and a `stdio` server must name
    `none`.
11. **T31, re-verified against every committed profile.** No npm, yarn, PyPI or Go proxy entry
    appears in any resolved artifact, and `npx` is absent from every image. The HashiCorp entries
    are assessed and recorded against T31's scope. **Recorded residual:** `github.com` lets an
    agent fetch arbitrary source and run it with `node`. That was already true for `codex` under
    every profile, from the 01.1 base. The `github` profile extends it to `claude` and `agy`, and it
    is not "arbitrary `npx <server>`".
12. **T32.** Each agent's capability-declaration files are enumerated in
    `docs/records/mcp-inventory.md` (R7.17), and a write to each is attempted from inside that
    agent. **The write is not blocked for any agent, Claude Code included.** `srt` is not installed,
    and D14 as amended disables every native sandbox. The test therefore **records the gap for all
    three rather than passing**, and it asserts the compensating control: the next start is refused
    by the T29 gate. A **proposed T32 amendment** is recorded for an authority that may edit
    `REQUIREMENTS.md`, because the clause "Blocked for Claude Code via `srt`" has no satisfiable form
    today.
13. **`validate-boundary.sh` re-runs against every shipped profile** (`default`, `terraform`,
    `kubernetes`, `github`), and the results are recorded. Each re-run adds per-profile rows: the
    credential reachability of criterion 5, a pack-declared destination allowed and attributable, a
    pack-adjacent undeclared destination denied, and the agent's secret set equal to the set derived
    from the manifests.
14. **Constraints recorded, not closed.**
    - Kubernetes reach is **public-FQDN cluster endpoints only**. `allow_cidrs` is refused at the
      mediator render, and RFC1918 is denied post-resolution. So kind, Docker Desktop, private and
      IP-endpoint clusters are unreachable.
    - A pack credential reaches all three agents, under the same rule that gives all three a pack's
      egress.
    - `docker compose up --build` does not run the compose check host-side (Decision 3).

## Approach

### The starting position

The codebase scan established these facts; the design follows from them.

- **The R7.6 gate treats every runtime egress entry as an installation channel.** At
  `compile-policy.sh:661-664`, any `egress.runtime` count above zero with `runtime_install: false`
  exits 3.
  - Terraform and GitHub CLI must therefore set `runtime_install: true` with a reason. For both it
    is literally true: `terraform init` downloads provider executables, and `github.com` serves
    source.
  - A per-cluster Kubernetes pack must do the same. It has no package registry, but a cluster API
    can serve arbitrary bytes, and the conservative reading of the gate is kept rather than relaxed.
  - The refusal's wording ("egress to a package registry", "`npx`") conflates the two cases. It is
    corrected in SF-1.
- **A pack's egress applies to every agent** (`compile-policy.sh:856-862`). Entries are
  de-duplicated per agent on `fqdn|port|upgrade` (`:947`), and an `upgrade` mismatch against the
  base is refused (`:955-970`).
  - `codex`'s base already carries `github.com` and `api.github.com` with `upgrade: false`
    (`allowlist.base.yaml:80-87`). The GitHub CLI pack must declare `upgrade: false`, or it collides.
  - Loading it changes nothing for `codex` on those two hosts.
- **The mediator refuses `allow_cidrs`** (`images/mediator/entrypoint.sh:384-386`), and the base
  denylist denies RFC1918 after resolution (`denylist.base.yaml:22-26`). No pack in this feature
  declares a CIDR.
- **A new profile needs a committed resolved artifact, or the mediator will not start**
  (`images/mediator/entrypoint.sh:175`). `compile-policy-build.sh` refreshes artifacts but never
  creates one (`:30-33`). Test-base variants cannot be committed, because `CARRY_PROFILES` is a code
  constant (`images/mediator/compile-stage.sh:42-44`).
- **Archive installs are name-allowlisted.** Only `node` and `go` are accepted
  (`images/pack-plan.sh:252-255`, `images/pack-install.sh:77-81,88-113`). That allowlist is a
  deliberate trust choice: a third-party manifest never picks its own install destination.
  - `agent-base` carries no `unzip` and is digest-pinned from GHCR.
  - `pack-install.sh` installs apt items *before* archives (`:64-67`), so a pinned `unzip` apt item
    in the Terraform pack lands first. `agent-base` needs no republish.
- **Every pack's packages go into all three agent images** (`images/Dockerfile:231,258,294` all
  build `FROM agent-packs`). Per-agent selection is not supported.
- **Compose overrides are hand-authored** (`profiles/default.yaml:6-7`; `scripts/build.sh:123-133`,
  which has no profile-to-override mapping). Secrets use the short syntax, landing at
  `/run/secrets/<name>` (`compose.yaml:89-144`). The entrypoint already splices a secret file into
  an environment variable at start (`images/entrypoint.sh:99-139`, 01.6 Deviation 10), which is the
  precedent for `GH_TOKEN`.
- **Nothing in the repo knows about MCP.** There is no `mcp`, `skills` or `plugins` key anywhere,
  and every agent's home skeleton is empty of servers. `node` is in `agent-base` (`FROM
  node:22-slim`, `Dockerfile:78`), so all three images have a JSON parser. `jq` is `agy`-only
  (`:322`), and no image carries `yq`.
- **The records disagree on where capability declarations live:**
  - `claude`: `.claude.json` under `CLAUDE_CONFIG_DIR` (`Dockerfile:241`) or under `$HOME`
    (`bootstrap-auth.sh:191`).
  - `agy`: `~/.gemini/settings.json` or `~/.gemini/antigravity-cli/settings.json`.
  - `codex`: `config.toml` is rewritten on every start (`entrypoint.sh:40-64`).

  These are measured before the gate is designed (SF-6).
- **`srt` is not installed**, and D14 as amended disables every native sandbox
  (`agent-verification.md:207-240`). T32's "Blocked for Claude Code via `srt`" cannot pass.
- **02.1 and 02.2 change the same files first.**
  - 02.1: `compile-policy.sh` (`exports`), all three resolved artifacts,
    `images/mediator/entrypoint.sh`, `build.sh`, and possibly a `--profile-file` flag.
  - 02.2: `allowlist.test.yaml`, possibly `provisional`, and `validate-boundary.sh`.

  This plan's contracts are written against the post-02.1/02.2 shape.

### Decision 1 — env and credentials get landing points; mounts stay refused

D10's 01.5 amendment refused all three rather than drop them silently, and it named no landing
point for `env` or `credentials`. 02.3 has a concrete need for both:

- **`env`** — Terraform's `CHECKPOINT_DISABLE=1`. Without it every `terraform` invocation attempts
  `checkpoint-api.hashicorp.com`. That attempt is denied, so it is not a leak, but it puts a
  **blocked attempt on the audit trail on every run**, and a blocked attempt is the detection signal
  (R9.1). Noise there degrades SC-7's value. The same R5.11 posture applies to `gh`'s update
  notifier.
- **`credentials`** — the GitHub token and the `kubeconfig`.

Each lands where the concern belongs:

- **`env` is non-secret and per-profile, so it goes in the image.** `pack-plan.sh` writes
  `pack-env.txt`, `pack-install.sh` installs it read-only as `/opt/agent-pack/env`, and the
  entrypoint exports it before the agent starts. Because it rides the per-profile image (D10), R7.5
  holds by construction: remove the pack, rebuild, and the variable is gone.
- **`credentials` are secret, so never in the image (R8.1). They become Compose `file:` secrets.**
  `pack-plan.sh` writes `pack-credentials.txt` (secret name, delivery form), installed as
  `/opt/agent-pack/credentials`. The entrypoint reads each `/run/secrets/pack-<pack>-<cred>` and
  either exports its content (`delivery.env`, e.g. `GH_TOKEN`) or exports its path
  (`delivery.path_env`, e.g. `KUBECONFIG`). A missing secret file already fails closed, because
  Compose refuses `up` on an absent `file:` source. The entrypoint also asserts presence.
- **`mounts` stays refused.** No shipped pack needs a host mount: Terraform, `kubectl`, `helm` and
  `gh` keep their state and caches under `/home/agent` on the state volume. Building a mount landing
  point with no consumer fails the over-engineering discriminator, and R2.8 permits only enumerated
  mounts in any case. The refusal message is corrected.

**Credential sources are scoped per profile on disk:**
`${PACK_CREDENTIALS_DIR:-../compose/generated/credentials}/<profile>/<pack>/<cred>`. A second
profile that loads the same pack takes its own credential file, which meets R8.2's "single
use-case profile" in its strict reading and keeps each credential independently revocable (R7.12).
`PACK_CREDENTIALS_DIR` lets the harness point at scratch fixtures without touching the operator's
real files. Two consequences are recorded:

- **R2.4/R2.8 tension.** A Compose `file:` secret is a bind mount (D22). The precedent is 01.6's
  identity secrets. The `kubeconfig` must be a **dedicated, scoped file**, never `~/.kube/config`,
  and the GitHub token a dedicated fine-grained PAT, never `~/.config/gh`. R2.8's enumeration does
  not list pack credentials, and the record names that as a register tension.
- **All three agents receive the credential**, under the same rule that gives all three a pack's
  egress (`compile-policy.sh:856-862`). That is one token in three containers, stated as blast
  radius. Per-agent credential scoping has no stated requirement behind it and is **flagged, not
  built**.

### Decision 2 — one hand-authored override per profile, verified by a host-side check

Credentials need per-profile Compose `secrets:` declarations, and a Compose fragment cannot read
the profile (`build-cache.yaml:18-21`). Each new profile gets a hand-authored
`compose/overrides/<profile>.yaml` in `default.yaml`'s shape, carrying:

- the workspace mount;
- the limits copied from the profile (as today);
- the pack secrets.

A new `scripts/check-profile-compose.sh --profile <p>` renders `docker compose config` for that
profile and asserts two things:

- **(a)** each agent's secret set, minus the `default` baseline, equals exactly the set derived from
  the selected packs' `credentials`, in both directions. A missing secret fails; an extra one is
  residue and fails (R7.5).
- **(b)** every other part of each rendered agent service equals `default`'s. The only permitted
  differences are `secrets` and the `PROFILE` build argument, and for the mediator only
  `MEDIATOR_PROFILE`. This covers the R7.8 hardening fields and also catches a drifted workspace
  mount or limit in a hand-authored override. Outside `default`, no per-profile mount-set equality
  check exists anywhere else.

The rejected alternative is a compiler-generated secrets fragment. It keeps R7.5 by construction but
needs a third `-f` file on the entry point, which R12.9's single "profile-selected override" argues
against. The mediator's compile stage cannot see `compose/` either way, so the check is host-side in
both designs. Presented as a tradeoff callout.

### Decision 3 — the compose check runs in the Test Command and in `build.sh`, and its gap is stated

`check-profile-compose.sh` runs in two places:

- `verify-tool-packs.sh`, for every committed profile;
- `build.sh --profile <p>`, before building.

`docker compose up --build`, the R12.9 entry point, does not run it and cannot without a wrapper,
which R12.9 bars. The residual is stated in the README and the record. The mitigation is that a
drifted override also fails `validate-boundary.sh`'s per-profile secret-set row.

### Decision 4 — T14 is "gained equals declared minus base", recorded on Terraform

T14's pass text is "egress policy gains and loses exactly that pack's entries". De-duplication
against the base (`:947`) means a pack entry the base already carries adds nothing, so the rule is
stated precisely:

> For each agent `a`: `entries(profile+P)[a] − entries(profile)[a] == P.runtime − base[a]`, and the
> reverse difference is empty. Removing `P` returns an artifact byte-identical to the baseline
> (`del(.compiled_from)`), which is the no-residue check.

Terraform is the clean case the README names. No base agent carries a HashiCorp host, so
`P.runtime − base[a] = P.runtime` for all three agents. T14's recorded acceptance is this run. The
GitHub CLI pack is recorded under the same rule as the overlap case:

- `codex` gains nothing.
- `claude` and `agy` gain both hosts.

### Decision 5 — Terraform, not OpenTofu, and the provider-download widening is declared

The README names HashiCorp's endpoints for R14.1, so the pack ships **Terraform**, as a
checksummed `linux_arm64` zip from `releases.hashicorp.com`, with a pinned `unzip` apt item.
OpenTofu is not shipped. It would be a second pack with its own R14.1 party (`registry.opentofu.org`
and GitHub releases), and no requirement names it. Terraform is licensed under **BSL 1.1**, which
permits this one-workstation internal use (Q2). The license is named because the choice is the
operator's. **Assumption, for Revise.**

Runtime egress is `registry.terraform.io` and `releases.hashicorp.com`. `runtime_install: true`,
with the reason that `terraform init` downloads provider executables. The blast radius records:

- runtime provider download is a supply-chain widening;
- the registry's GET paths are a low-bandwidth exfil channel;
- providers hosted outside `releases.hashicorp.com` (third-party providers on GitHub) will fail,
  which is intended.

The stronger alternative is provider pre-baking via a `filesystem_mirror`. It is **recorded, not
taken**: it empties Terraform's runtime egress and would repeat language-runtimes' inability to
satisfy T14.

### Decision 6 — Kubernetes: binaries in the pack, reach in a per-cluster egress-only pack

The cluster API endpoint belongs to the operator and cannot be declared statically. The split:

- **`packs/kubernetes/`** carries `kubectl` (bare binary, SHA-256 from `dl.k8s.io`) and `helm`
  (tarball from `get.helm.sh`). It has `egress.runtime: []`, `runtime_install: false`, and one
  credential, `kubeconfig` (`delivery.path_env: KUBECONFIG`). Its build-time sources are not on the
  agent traffic path, so it names no `third_parties`.
- **A cluster is reached by loading a separate egress-only pack**, `packs/k8s-cluster-<name>/`. It
  has empty `packages`, `egress.runtime` naming the API server FQDN and any Helm repositories,
  `runtime_install: true` with a reason, and a `third_parties` record for the hosting party. This
  needs **no schema change**, because lint already accepts empty package lists. It keeps cluster
  reach reviewable as its own pack under R5.14.
- **The shipped `kubernetes` profile loads no cluster pack.** `kubectl` reaches nothing until the
  operator adds one. The harness exercises the mechanism with a temporary probe cluster pack, on
  `verify-pack-composition.sh`'s `sf7-probe` idiom; no fixture pack is committed.
- **Constraint recorded:** public-FQDN endpoints only (criterion 14). The `kubeconfig` must hold one
  context with token or client-certificate auth. An `exec` or `auth-provider` plugin would run a
  binary the image does not carry. **Assumption, for Revise:** no specific operator cluster is
  targeted in 02.3.

### Decision 7 — GitHub CLI: `gh` API operations with `GH_TOKEN`; git-over-HTTPS wiring not built

`gh` ships as the checksummed `linux_arm64` tarball from GitHub releases. The bookworm snapshot's
`gh` availability is not assumed, and a second apt repository would widen `package_repository`.

- **Runtime egress:** `api.github.com` and `github.com`, both `upgrade: false`, to match `codex`'s
  base. Further hosts (`uploads.github.com`, `objects.githubusercontent.com`) are added **only on an
  observed failure** of an operation the use case needs (R5.8, minimal).
- **Credential:** `github-token`, a dedicated fine-grained PAT scoped to named repositories, with
  `delivery.env: GH_TOKEN`.
- **Env:** the update notifier off, plus any telemetry switch the pinned `gh` version exposes,
  **measured at build** (R5.11).
- **Not built:** wiring `git push` over HTTPS through the token (a `credential.helper` via
  `GIT_CONFIG_*`). No stated requirement names it, and it interacts with R2.9's helper stripping.
  **Flagged for Revise.**

### Decision 8 — the MCP inventory lives in the profile, is baked into the image, and is enforced at start

R7.14 says "inventoried in the use-case profile", so the inventory is a profile `mcp:` block
(Interface Contract 5).

**The compiler validates the block.** It checks the R7.3 field set, the transport and
enforcement-point pairing (T30), the risk tier, a pinned version and checksum, and that a registry
is declared whenever `servers` is non-empty (R7.16). It composes an `http`/`sse` server's
`egress.allow_fqdns` into that server's listed agents, under the same collision rule as packs.

**`pack-plan.sh` renders the block** per agent to `/opt/agent-pack/mcp-inventory.json`. The file
sits on the read-only root filesystem and is image code, so the agent cannot alter it.

**The gate is `images/mcp-gate.js`,** run by `images/entrypoint.sh` after the home seed and the
R4.5 `config.toml` merge and before the agent command. `node` is present in all three images.

- It enumerates the agent's capability-declaration files and plugin and skill directories. The set
  is measured in SF-6.
- It canonicalises each server entry: sorted-key JSON, with `codex`'s TOML table extracted.
- It exits 3 on an uninventoried entry, and on drift, where the canonical entry's hash does not
  equal `capability_baseline.config_sha256`.
- For a `stdio` server with a pinned artifact, it also hashes the artifact on disk.

**Why start-time and not write-time.** Nothing outside the blast radius sees a config write, and
the native sandbox that could have blocked one is disabled (D14). A start-time gate in image code
blocks the thing R7.17 names: **persistence** across the session boundary. An agent can edit its
config mid-session, but every `docker compose run` or restart meets the gate.

**Recorded limitation.** The capability baseline hashes the *declared config entry* and the pinned
artifact. It does not hash the server's live `tools/list`, because that would mean executing the
server. A same-version server that changes its advertised tools is not detected. Version pinning
plus the artifact hash bound this.

**Host-side audit: flagged, not built.** A throwaway-container audit of a state volume would add
detection without a start. No stated requirement names it.

### Decision 9 — no real MCP server ships; fixtures exercise T29–T31

No requirement names a server to ship, so every shipped profile carries a complete, empty
inventory: `servers: []`, `plugins: []`, `skills: []`, `registry: none`. The empty lists are the
explicit "none". T29–T31 are exercised by the harness through a **test inventory mounted over
`/opt/agent-pack/mcp-inventory.json`** via `compose/overrides/test-mcp.yaml`. That follows 02.1's
`test-exports.yaml` precedent and needs no per-profile rebuild. The test inventory holds:

- a `stdio` fixture entry pointing at a committed fixture script;
- an `http` fixture entry pointing at `mcp.fixture.lab`, a fixture host.

**The mounted inventory is never compiled**, so its `egress` reaches no resolved artifact. The
fixture host therefore goes into `policy/allowlist.test.yaml` for all three agents, as a plain
test-base entry. 02.2 already edits that file. `test-fixtures` and `test-selfcheck` are recompiled
on the host in the same commit, and `tests/fixtures/authoritative-dns/` gains the record. T29–T31
run under the existing `test-egress.yaml` fixture topology with `test-mcp.yaml` layered on top. The
compiler's HTTP-egress composition is exercised separately, at compile level, with a probe profile
carrying the fixture `mcp:` block (SF-6 Phase A).

**The enforcement-point claim is asserted from both ends** (R7.15):

- An inventoried `http` server reaches `mcp.fixture.lab` with an **allow** verdict line attributed
  to the agent.
- An **uninventoried** HTTP server is refused twice. The gate refuses it at start. If its host is
  contacted anyway (for example, from a shell in a started container), the mediator refuses it with
  a **deny** line under `control=allowlist`.

Shipping a real server would add a registry, a build-time installer and a third party, none of
which traces to a requirement. Presented as a tradeoff callout.

### Decision 10 — the `validate-boundary.sh` re-run uses scratch test-base variants

Test-base variants of the new profiles cannot be committed (`CARRY_PROFILES`), and the shipped
artifacts point at real upstreams. The re-run therefore reuses **02.1 Decision 7's mechanism**:

1. Compile each shipped profile against `allowlist.test.yaml` and `denylist.test.yaml`, with
   `startup_check.allowed` repointed at a test-base host.
2. Write the result to `.build-scratch/`.
3. Mount it over the mediator's policy path.

Step 1 needs a profile edit outside `profiles/`, so it **depends on 02.1 SF-1's `--profile-file`
finding**. If 02.1 did not add the flag, SF-8 adds it as the recorded compiler interface change
02.1 named.

Each profile's expected agent secret set is **derived from the manifests** (Interface Contract 7),
not hardcoded. This avoids writing a fifth copy of the D22 mount predicate. The credential source
path `compose/generated/credentials/...` is checked against the harnesses' containment patterns
(`*/mediator*`, `*.key`) so that a name like `*.key` is never chosen. D22's consolidation is
**touched, not taken**.

## Sub-Features

- [x] **SF-1: Pack manifest schema — `env`, `credentials`, `third_parties`, unknown-key refusal.**
  - `compile-policy.sh`:
    - lift the exit-3 refusal of `env` and `credentials`, and validate both against Interface
      Contract 1: name regex, reserved names, literal values, delivery form, the two required
      prose fields;
    - correct the `mounts` refusal message and the R7.6 message wording;
    - refuse unknown top-level manifest keys at exit 2.
  - `lint-policy.sh`: the same shape checks, plus the `third_parties` anchor check (criterion 3).
  - `packs/language-runtimes/pack.yaml`: gains `third_parties: []`.
  - `packs/README.md`: rewrite the landing-point table.
  - Recompile every resolved artifact in the same commit; only the pack sha changes.
  - New harness `tests/acceptance/verify-tool-packs.sh`, Phase A: positive and negative probes on
    the `sf7-probe` idiom.
  - Composite green.
- [x] **SF-2: Delivery — pack env and credential plan, entrypoint export, compose check.**
  - `pack-plan.sh` emits `pack-env.txt` and `pack-credentials.txt`.
  - `pack-install.sh` installs them under `/opt/agent-pack/`.
  - `images/entrypoint.sh` exports the env, and maps each credential (`env` or `path_env`), failing
    at exit 3 if a declared secret file is absent.
  - Create `scripts/check-profile-compose.sh` (Decision 2) and call it from `build.sh`.
  - Add `compose/generated/credentials/` to `.gitignore`.
  - Harness Phase B: a probe pack with one `env` and one credential against a scratch
    `PACK_CREDENTIALS_DIR`, asserting the variable, the secret and its absence under `default`.
  - Composite green.
- [x] **SF-3: Terraform pack, `terraform` profile, T14 and SC-6.**
  - Create `packs/terraform/pack.yaml`: zip plus pinned `unzip`, `CHECKPOINT_DISABLE=1`,
    `third_parties: [HashiCorp]`.
  - Add a `terraform` archive rule to `pack-plan.sh` and `pack-install.sh`.
  - Add the HashiCorp R14.1 record.
  - Create `profiles/terraform.yaml` and `compose/overrides/terraform.yaml`.
  - Bootstrap `policy/resolved/terraform.yaml` with `compile-policy.sh --out`, then refresh through
    `compile-policy-build.sh`.
  - Harness Phase C: **T14 recorded acceptance** (Decision 4).
  - Harness Phase D: the **SC-6 live switch** `default → terraform → default`, plus `terraform
    version` present and then absent.
  - Composite green.
- [x] **SF-4: GitHub CLI pack, `github` profile, token delivery and R8.2 inspection.**
  - Create `packs/github-cli/pack.yaml` and add a `gh` archive rule.
  - Add the GitHub R14.1 record.
  - Create `profiles/github.yaml` and `compose/overrides/github.yaml`, bootstrap the artifact.
  - Add a credential-inventory row for the token, and correct the stale S1 row (01.6 built the
    mTLS key).
  - Harness Phase E:
    - the overlap case under Decision 4's rule;
    - `GH_TOKEN` present in every agent under `github` and absent under `default` and `terraform`,
      inspected from inside each container;
    - `gh --version`.
  - Record the `github.com` code-fetch widening (criterion 11).
  - **R8.6:** extend 02.1 Decision 8's export-channel redaction pattern set to GitHub token formats
    (`ghp_`, `github_pat_`, `gho_`). Assert it against a synthetic transcript line carrying the
    dummy token, so no live session is spent. Record in `credential-inventory.md` that `printenv` in
    a `github` session puts `GH_TOKEN` into the faithful sink.
  - Composite green.
- [x] **SF-5: Kubernetes pack, `kubernetes` profile, `kubeconfig` delivery, cluster-pack mechanism.**
  - Create `packs/kubernetes/pack.yaml` and add `kubectl` and `helm` archive rules.
  - Create `profiles/kubernetes.yaml` and `compose/overrides/kubernetes.yaml`, bootstrap the
    artifact.
  - Add a credential-inventory row for the `kubeconfig`.
  - Add the Kubernetes posture to `third-party-assessments.md` (Decision 6).
  - Harness Phase F:
    - `KUBECONFIG` resolves to the `:ro` secret path under `kubernetes` only;
    - `kubectl version --client` and `helm version` pass;
    - a temporary probe cluster pack adds exactly its FQDN (Decision 4's rule) and is refused
      without a resolvable `third_parties` anchor.
  - Record the public-FQDN constraint.
  - **R8.6:** extend the redaction pattern set to `kubeconfig` material (`client-key-data`,
    `client-certificate-data`, `token:`, PEM blocks). Assert it with a synthetic transcript line, and
    record it.
  - Harness Phase G: the R7.8 hardening comparison across all four profiles.
  - Composite green.
- [ ] **SF-6: MCP measurement, inventory schema and compile-time enforcement (T30, T31).**
  - **Measure first**, following 02.1 SF-1's pattern. For each agent, record the
    capability-declaration files and plugin and skill directories: path, write model (rewritten by
    the agent, by our entrypoint, or append-only), format, and how an entry is keyed. Resolve the
    `claude` `.claude.json` and `agy` `settings.json` path disagreements by observation, and record
    them in `docs/records/mcp-inventory.md`.
  - **Inspect the operator's current seed volumes read-only**, with operator consent, for entries
    the gate would refuse. The volumes have run live sessions since 01.4, `claude`'s login was
    observed contacting `mcp-proxy.anthropic.com`, and any project `.mcp.json` counts. The operator
    resolves each entry (inventory it or remove it) before SF-7's gate lands.
  - Add the `mcp:` schema to all shipped profiles (empty, explicit).
  - Compiler: validation, the T30 pairing, and HTTP-server egress composition.
  - `pack-plan.sh`: render the per-agent inventory JSON.
  - Recompile every artifact in the same commit.
  - New harness `tests/acceptance/verify-mcp-inventory.sh`, Phase A: schema negatives and T30.
  - Phase B: **T31** across every committed artifact and every built image, with the HashiCorp and
    GitHub assessment recorded.
  - Composite green.
- [ ] **SF-7: MCP start-time gate (T29) and capability-declaration integrity (T32).**
  - Create `images/mcp-gate.js` and call it from `images/entrypoint.sh`.
  - Create `compose/overrides/test-mcp.yaml`, the test inventory, and the fixture `stdio` script.
  - Harness Phase C, **T29**:
    - add an uninventoried server to each agent's config: refused, exit 3, message names file and
      entry;
    - change an inventoried fixture entry's args: drift, exit 3, both hashes;
    - a plugin and skill directory case per agent that has one;
    - codex's per-start `config.toml` rewrite does not produce false drift.
  - Harness Phase D, **T32**: write each enumerated file from inside each agent. The write succeeds,
    and the gap is recorded per agent. The next start is refused.
  - Record the proposed T32 amendment.
  - Composite green.
- [ ] **SF-8: `validate-boundary.sh` re-run against every profile, records and close-out.**
  - Add `BOUNDARY_PROFILES` to `validate-boundary.sh`, with per-profile scratch variants (Decision
    10, including `--profile-file` if 02.1 did not add it) and the per-profile rows (criterion 13).
  - Run the matrix for `default`, `terraform`, `kubernetes` and `github`, and record it in
    `docs/records/boundary-validation.md`.
  - Re-inspect **T42** across all parties and record the result.
  - README: the profile set, a switching recipe, credential staging and revocation, the MCP
    inventory and gate, and the `up --build` compose-check residual.
  - Finalize `docs/records/mcp-inventory.md`.
  - Composite green, with the full `BOUNDARY_PROFILES` set.

**Sizing.** No sub-feature is flagged `[OVERSIZED]`.

- **SF-1 and SF-2** carry the schema and delivery change: a compiler edit, two build-script edits,
  an entrypoint edit and a new check. They are split along the compile / deliver seam, because each
  alone is a full `/build` session with probes.
- **SF-3–SF-5** are one pack each. SF-3 is the heaviest of the three because it carries T14 and the
  live SC-6 switch.
- **SF-6 and SF-7** are the MCP half, split measure-and-schema / gate-and-tests. SF-7 depends on
  SF-6's measurement.
- **SF-8** is harness-and-records.

**Named fallback, as the milestone README requires:** if the MCP half runs long, SF-6 and SF-7 move
to their own milestone via `/milestone` revision mode. Deferring them silently inside 02.3 is not
the fallback. **Named split if SF-2 runs long:** SF-2a (env: plan, install and export) and SF-2b
(credentials plus the compose check).

## Interface Contracts

### 1. Pack manifest additions (schema stays `1`; new keys are additive, and unknown keys are refused)

```yaml
env:                                   # non-secret; baked into the per-profile image
  - name: CHECKPOINT_DISABLE           # ^[A-Z_][A-Z0-9_]*$
    value: "1"                         # literal string scalar; never a secret
    reason: "R5.11 -- suppresses a denied telemetry attempt on every run"
credentials:                           # secret; never in an image layer (R8.1)
  - name: github-token                 # ^[a-z0-9-]+$ -> Compose secret pack-<pack>-<name>
    delivery: {env: GH_TOKEN}          # exactly one of {env: VAR} | {path_env: VAR}
    description: "Fine-grained PAT scoped to named repositories"
    blast_radius: "..."                # R8.4
    revocation: "..."                  # R7.12 -- independent of every other credential
third_parties:                         # required non-empty iff egress.runtime is non-empty
  - {party: GitHub, record: "docs/records/third-party-assessments.md#r141-github"}
mounts: []                             # still refused when non-empty (Decision 1)
```

- **Reserved `env` and `delivery` names are refused.** These are variables the pod contract
  already sets:
  - `PATH`, `HOME`, `USER`, `SHELL`, `LD_*`;
  - `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` in either case;
  - `AUTH_MODE`, `AGENT_NAME`;
  - `*_API_KEY`, `CLAUDE_*`, `CODEX_*`, `GEMINI_*`;
  - `NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`;
  - `GIT_CONFIG_*`.

  Letting a pack override one would silently change the proxy, auth or identity behaviour.
- **Duplicates are refused.** A variable declared by two selected packs, or a credential name
  duplicated within a pack, exits 3, naming both sources. This is the same philosophy as the
  `upgrade` collision.

### 2. Plan files and in-image paths

| Plan file (`pack-plan` stage) | Line format | Installed as |
|---|---|---|
| `pack-env.txt` | `NAME<TAB>value` | `/opt/agent-pack/env` (0444, root) |
| `pack-credentials.txt` | `pack-<pack>-<cred><TAB>env\|path_env<TAB>VAR` | `/opt/agent-pack/credentials` (0444, root) |
| `mcp-inventory.<agent>.json` | Interface Contract 5, per agent | `/opt/agent-pack/mcp-inventory.json` (0444, root; each agent stage copies its own) |

The entrypoint exports the env before the credential map, so a credential mapping always wins. That
cannot collide, because Contract 1 refuses duplicates.

### 3. Credential source and Compose shape (per profile override)

```yaml
secrets:
  pack-github-cli-github-token:
    file: ${PACK_CREDENTIALS_DIR:-../compose/generated/credentials}/github/github-cli/github-token
services:
  claude: {secrets: [pack-github-cli-github-token]}
  codex:  {secrets: [pack-github-cli-github-token]}
  agy:    {secrets: [pack-github-cli-github-token]}
```

The target is `/run/secrets/pack-github-cli-github-token`, with the short syntax, as today. The
operator stages the file, mode 0600, before `up`. Rotation is a file swap plus `--force-recreate`,
with no rebuild.

### 4. `scripts/check-profile-compose.sh`

```
bash scripts/check-profile-compose.sh --profile NAME [--credentials-dir DIR]
```

- Exit codes: 0 ok, 1 usage, 2 an unrenderable profile or override, 3 a secret-set mismatch
  (missing or residue), 4 any other service difference from `default` (Decision 2 (b)), naming the
  path.
- Renders with `--env-file compose/pins.env -f compose/compose.yaml -f
  compose/overrides/<p>.yaml`, and uses `--credentials-dir` for dummy secret sources so rendering
  needs no real credentials.
- Called by `verify-tool-packs.sh` (every committed profile) and by `build.sh`.

### 5. Profile `mcp:` block (every profile, including tests; empty is explicit)

```yaml
mcp:
  registry: none            # or {type: npm-tarball|oci|..., url, pinned: <snapshot/digest>} -- required iff servers non-empty (R7.16)
  servers:
    - name: fixture-http
      agents: [claude, codex, agy]
      version: "1.0.0"
      artifact: "n/a: remote server, nothing installed"   # or {path: /opt/mcp/<name>/..., sha256: <64hex>}
      transport: http        # stdio | http | sse
      enforcement_point: mediator   # stdio -> must be "none"; http/sse -> must be "mediator"
      egress: {allow_fqdns: [{fqdn: mcp.fixture.lab, port: 443}], allow_cidrs: []}
      mounts: []
      env: []
      credentials: []
      needs_write_access: false
      risk_tier: read-only   # read-only | write | irreversible
      capability_baseline:
        config_sha256: <64hex> # sha256 of the canonical agent-native entry (Decision 8)
        tools: [search, fetch] # recorded for review; NOT machine-checked (recorded limitation)
  plugins: []                # [{name, agents, version, sha256, risk_tier}]
  skills: []                 # same shape as plugins
```

- `agents` must be a subset of the base allowlist's keys.
- A `stdio` server may still declare `egress`. Its own network traffic inherits the agent's proxy
  environment and crosses the mediator, attributed to the agent, even though its tool calls cross
  nothing.
- Composed MCP egress carries its origin as `mcp:<server>` **inside the compiler only**, on the same
  `fqdn|port|upgrade|source` accumulator packs use, so a collision can name both sides. The source
  is cut before emit (`compile-policy.sh:947`). The emitted `allow_fqdns` shape stays
  `{fqdn, port, upgrade}`, and the resolved schema the mediator validates at stage 1 is unchanged.

### 6. Gate: `images/mcp-gate.js`

```
node /usr/local/lib/mcp-gate.js --agent <agent> --inventory /opt/agent-pack/mcp-inventory.json
```

- Exit 0: every entry is inventoried and matches its baseline.
- Exit 3: an uninventoried entry or drift. Stderr carries one line per finding:

  ```
  mcp-gate: REFUSED uninventoried server '<name>' in <file> (R7.14, T29)
  mcp-gate: DRIFT '<name>' in <file>: baseline <hash> != live <hash> (R7.14, T29)
  ```

- Exit 2: an unreadable inventory, or a capability-declaration file that exists but does not
  parse. That fails closed.
- The enumerated file set is per agent, fixed by SF-6's measurement and recorded in
  `mcp-inventory.md`. It always includes `/workspace/.mcp.json` for `claude`.

### 7. `validate-boundary.sh` profile re-run

- `BOUNDARY_PROFILES="default terraform kubernetes github"` (default: `default`). One
  scratch-compiled test-base variant per profile, mounted over the mediator policy path.
- The expected agent secret set per profile is derived as the `default` baseline plus
  `pack-<pack>-<cred>` for every selected pack's `credentials`, computed from the manifests at run
  time.
- Record lines gain `"profile":"<name>"`. Otherwise this is 02.2's Interface Contract 1, unchanged.
- **Swapping only the mediator's policy is not enough; a profile iteration changes the whole pod.**
  For each profile the suite:
  1. sets `AGENT_PROFILE=<p>`;
  2. layers `-f compose/overrides/<p>.yaml`;
  3. stages dummy secrets under a scratch `PACK_CREDENTIALS_DIR`;
  4. **rebuilds the agent images**, because the run tag is always `:local` (`build.sh:102`; the
     scan, §12);
  5. mounts that profile's scratch test-base variant.

  That is four agent rebuilds per composite run, on top of SF-3's live switch. Pack layers cache,
  so a warm rerun costs one `agent-packs` layer per profile. `default` runs **last**, so the
  composite leaves `:local` at `default` for every harness that assumes it.

### 8. R14.1 record for a pack party (existing `third-party-assessments.md` shape)

`## R14.1 — <Party>`, followed by a Field/Value table:

- Party
- Role on the traffic path (named FQDNs, and the pack that places them)
- What it can observe
- Stated retention
- Deletion terms
- Breach-notification path
- Assessment status
- Resulting constraint on use
- Date
- Source

**Anchor convention.** Each pack-party section carries an explicit `<a id="r141-<party-slug>"></a>`
line directly under its heading. `third_parties[].record` references it as
`docs/records/third-party-assessments.md#r141-<party-slug>`, and `lint-policy.sh` resolves it by
matching `id="<slug>"`, not by guessing a renderer's heading slug. The harness's probe cluster pack
uses an existing anchor for its positive case and a bogus one for its negative.

## Edge Cases

| Case | Handling |
|---|---|
| The GitHub CLI pack's `upgrade` differs from `codex`'s base | Declared `upgrade: false` to match. Any mismatch is refused at exit 3 by the existing collision gate |
| Overlap: a pack entry the base already carries | De-duplicated. T14's rule is "declared minus base" (Decision 4). Recorded for `codex` with `github.com`/`api.github.com` |
| Cluster pack on a private, kind, Docker Desktop or IP-endpoint cluster | Unreachable: `allow_cidrs` is refused at the mediator render, RFC1918 is denied post-resolution. A recorded constraint, not a gap to close here |
| `kubeconfig` with an `exec`/`auth-provider` plugin, or several contexts | Documented as unsupported. Plugin binaries are absent, so it fails loudly. One scoped context is required, and the blast radius is stated per context |
| Credential file not staged | Compose refuses `up` (missing `file:` source). The entrypoint also exits 3 on an absent declared secret. Never a silent start without the credential |
| Operator stages `~/.kube/config` or `~/.config/gh` as the source | Documented as barred (R2.4). The staging path is a dedicated per-profile directory. Not mechanically blocked, because the source path is the operator's |
| Pack env collides with a pod-contract variable | Refused at compile (Contract 1 reserved names) |
| Terraform checkpoint call | `CHECKPOINT_DISABLE=1`, so no denied attempt pollutes the trail |
| Terraform provider hosted on GitHub | Fails at `init`: not allowlisted. Intended. Recorded in the blast radius |
| `gh` needs a host beyond `api.github.com`/`github.com` | Added only on an observed failure of a needed operation (R5.8), with an R14.1 check (same party) |
| `docker compose up --build` skips the compose check | Stated residual (Decision 3). `validate-boundary.sh`'s per-profile secret-set row is the backstop |
| `codex`'s entrypoint rewrites `config.toml` every start | The gate runs after the merge, and the baseline hashes only the `[mcp_servers.<name>]` table's canonical form. SF-7 asserts no false drift |
| Agent reformats its config without semantic change | The canonical sorted-key hash per entry, not a file hash. SF-6 measures whether any agent rewrites entries on its own |
| Agent adds an MCP server mid-session | Not blocked at write (T32 gap). Refused at the next start (T29 gate). The recorded limitation is that a running session may already have loaded it |
| First start after the gate lands, on a volume or repository with existing MCP entries | **Refused.** The gate does not grandfather. SF-6 inspects the operator's volumes first, and the README carries a migration note: inventory the entry, or remove it. This deliberately differs from the auth bootstrap's warn-don't-block start posture (01.4 Deviation 2). An unreviewed capability declaration is the R7.17 persistence path, and an absent credential is not |
| Same-version server changes its advertised tools | Not detected; recorded limitation (Decision 8). Bounded by the version pin and the artifact hash |
| New profile without a committed artifact | Bootstrapped with `compile-policy.sh --out policy/resolved/<p>.yaml`, then `compile-policy-build.sh`, in the same commit as the profile |
| A compiler change after 02.3 | The standing 01.6 rule: every artifact -- now six, the three existing plus `terraform`, `kubernetes` and `github` -- is recompiled on the host in the same commit |
| `--profile-file` absent after 02.1 | SF-8 adds it as the compiler interface change 02.1 named (Decision 10) |
| Credential source name matches a D22 containment pattern | Path chosen as `compose/generated/credentials/<p>/<pack>/<cred>` with no `.key`/`.pem` suffix, and asserted against the harness predicates in SF-8 |

## Test Command

```
bash tests/acceptance/verify-pack-composition.sh && bash tests/acceptance/verify-pod-topology.sh && bash tests/acceptance/verify-egress-mediator.sh && bash tests/acceptance/verify-audit-completeness.sh && bash tests/acceptance/verify-tool-packs.sh && bash tests/acceptance/verify-mcp-inventory.sh && BOUNDARY_PROFILES="default terraform kubernetes github" bash tests/acceptance/validate-boundary.sh && bash scripts/lint-policy.sh
```

This is 02.2's composite, with the two new harnesses added and `validate-boundary.sh` widened to
every shipped profile. No phase spends model tokens or a login. Pack credentials in the harness are
dummy files under a scratch `PACK_CREDENTIALS_DIR`, and no call reaches GitHub or a cluster.
`verify-auth-state.sh` and 02.2's gated live phases stay out, on the same precedent. Per DD-12 the
operator may adjust this at build time without gate re-approval.

## Test Strategy

- **Schema:** negative probes for every new refusal. These cover: reserved env names; duplicate env
  across packs; both delivery forms at once; a missing `third_parties` with runtime egress; an
  unresolvable anchor; an unknown top-level key such as `cap_add`; a non-empty `mounts`. Each is
  asserted by exit code **and** message fragment, on `verify-pack-composition.sh`'s `expect` idiom.
- **T14:** a deterministic compile with `COMPILED_AT` fixed. It checks the set difference per agent
  under Decision 4's rule, and a byte-identical unload. This is recorded acceptance.
- **SC-6:** a live `up --build --force-recreate` switch across profiles. It reads the mediator's live
  `compiled_from.packs`, and pack binaries present and then absent. No file is edited between
  switches.
- **R8.2:** from inside each agent container under each profile, it checks the `/run/secrets`
  listing, `GH_TOKEN`/`KUBECONFIG` in the agent process environment, and that nothing resolves where
  the pack is not loaded.
- **R7.8 / R7.5:** `check-profile-compose.sh` on every committed profile, covering the secret-set
  delta and the hardening equality.
- **T29–T32:** real agent containers with the test inventory mounted. The gate's exit code and
  stderr lines are asserted literally. T32 asserts that the write **succeeds**, which is the
  recorded gap, and that the next start is refused.
- **T31:** every committed artifact and every built image are checked, plus the recorded
  HashiCorp/GitHub assessment.
- **Boundary:** the `validate-boundary.sh` matrix per profile, recorded.
- **Regression:** the full composite. All existing harnesses stay green under `default`, whose mount
  and secret set this feature does not change.

## Documentation

- `packs/README.md`:
  - the schema additions;
  - the landing-point table rewritten: `env` goes to the image, `credentials` to Compose secrets,
    and `mounts` stays refused, with the reason;
  - per-pack blast radius;
  - the cluster-pack how-to.
- `docs/records/third-party-assessments.md`: HashiCorp, GitHub, the Kubernetes posture, and the T42
  re-inspection result.
- `docs/records/credential-inventory.md`:
  - GitHub token and `kubeconfig` rows in Tables A and B;
  - the R8.3 "not yet brokered" statement;
  - a correction to the stale S1 row.
- `docs/records/mcp-inventory.md` (new):
  - the per-agent capability-declaration enumeration (R7.17), with measured paths and write models;
  - the inventory schema;
  - the gate and its limitations;
  - T29–T32 results, including the per-agent T32 gap and the proposed T32 amendment;
  - the T31 assessment and the `github.com` residual.
- `docs/records/boundary-validation.md`: the per-profile re-run matrix.
- `README.md`:
  - the profile set and the switching recipe;
  - credential staging, rotation and revocation per pack;
  - the MCP inventory, what a gate refusal looks like, and the **migration note** for existing
    volumes and repositories carrying MCP entries;
  - the `up --build` compose-check residual.
- **Not edited here:** `docs/ARCHITECTURE_AND_DESIGN.md` and `REQUIREMENTS.md`. Carried for the
  milestone consolidation pass or an authority that may apply them:
  - **Architecture:**
    - D10 amendment (1) — `env` and `credentials` now land;
    - the Tool packs component row;
    - the file tree — new packs, profiles, overrides, `mcp-gate.js`, `check-profile-compose.sh`;
    - the R8.4 credential enumeration.
  - **Register:** the T32 amendment, and the R2.8 enumeration of pack-credential secrets.

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `scripts/compile-policy.sh` | Modify | Validate `env`/`credentials`, keep the `mounts` refusal (corrected message), refuse unknown keys, reserved/duplicate env, R7.6 message wording, the `mcp:` block validation, T30 pairing, HTTP-server egress composition; `--profile-file` only if 02.1 did not add it |
| `scripts/lint-policy.sh` | Modify | Shape checks for the new keys, the `third_parties` anchor resolution |
| `scripts/check-profile-compose.sh` | Create | Interface Contract 4 |
| `scripts/build.sh` | Modify | Call `check-profile-compose.sh` before building a profile |
| `images/pack-plan.sh` | Modify | Emit `pack-env.txt`, `pack-credentials.txt`, per-agent MCP inventory JSON; archive name allowlist gains `terraform`, `kubectl`, `helm`, `gh` |
| `images/pack-install.sh` | Modify | Install rules for the four archives; install `/opt/agent-pack/*` |
| `images/Dockerfile` | Modify | Each agent stage copies its own `mcp-inventory.json` and `mcp-gate.js` (`agent-packs` stage and below only — never `agent-base`) |
| `images/entrypoint.sh` | Modify | Export pack env, map pack credentials, run the MCP gate after the home seed and `config.toml` merge |
| `images/mcp-gate.js` | Create | Interface Contract 6 |
| `packs/terraform/pack.yaml` | Create | Terraform zip, `unzip` apt pin, runtime egress, `CHECKPOINT_DISABLE`, `third_parties` |
| `packs/kubernetes/pack.yaml` | Create | `kubectl`, `helm`; no runtime egress; `kubeconfig` credential |
| `packs/github-cli/pack.yaml` | Create | `gh` tarball, runtime egress, `github-token` credential, env |
| `packs/language-runtimes/pack.yaml` | Modify | `third_parties: []` |
| `packs/README.md` | Modify | Schema, landing points, blast radius, cluster-pack how-to |
| `profiles/terraform.yaml`, `profiles/kubernetes.yaml`, `profiles/github.yaml` | Create | `default` plus one pack, `mcp:` block |
| `profiles/default.yaml`, `oauth-mount.yaml`, `test-fixtures.yaml`, `test-selfcheck.yaml` | Modify | Empty, explicit `mcp:` block |
| `compose/overrides/terraform.yaml`, `kubernetes.yaml`, `github.yaml` | Create | Workspace, limits, pack secrets (Contract 3) |
| `compose/overrides/test-mcp.yaml` | Create | Mounts the test inventory over `/opt/agent-pack/mcp-inventory.json` |
| `tests/fixtures/mcp/` | Create | The test inventory, the fixture stdio script |
| `policy/allowlist.test.yaml` | Modify | `mcp.fixture.lab` for all three agents (Decision 9) |
| `tests/fixtures/authoritative-dns/unbound.conf` | Modify | The `mcp.fixture.lab` record |
| `policy/resolved/terraform.yaml`, `kubernetes.yaml`, `github.yaml` | Create | Bootstrapped, then refreshed through the build |
| `policy/resolved/default.yaml`, `test-fixtures.yaml`, `test-selfcheck.yaml` | Regenerate | The pack sha and `mcp` changes, in the same commit as each compiler change |
| `tests/acceptance/verify-tool-packs.sh` | Create | Phases A–G (SF-1 to SF-5) |
| `tests/acceptance/verify-mcp-inventory.sh` | Create | Phases A–D (SF-6, SF-7) |
| `tests/acceptance/validate-boundary.sh` | Modify | `BOUNDARY_PROFILES`, scratch variants, per-profile rows |
| `.gitignore` | Modify | `compose/generated/credentials/` |
| 02.1's export-channel redaction pattern set (file fixed by the 02.1 build, per its Decision 8) | Modify | GitHub token and `kubeconfig` patterns (R8.6, SF-4/SF-5) |
| `docs/records/third-party-assessments.md` | Modify | HashiCorp, GitHub, Kubernetes posture, T42 re-inspection |
| `docs/records/credential-inventory.md` | Modify | Two credential rows, the R8.3 statement, the S1 correction |
| `docs/records/mcp-inventory.md` | Create | Enumeration, schema, gate, T29–T32 results, T31 assessment |
| `docs/records/boundary-validation.md` | Modify | The per-profile matrix |
| `README.md` | Modify | Profiles, credentials, MCP, residuals |

## Dependencies

- **Milestone 01, complete** — the compiler, pack pipeline, mediator, identity forms, and the
  harness idiom and helpers.
- **Feature 02.1, complete (`[x]`).**
  - The `exports` shape in every profile and artifact.
  - `compile-policy.sh`'s post-02.1 form.
  - The `test-exports.yaml` mount-over precedent that `test-mcp.yaml` and Decision 10 reuse.
  - The `--profile-file` finding.
- **Feature 02.2, complete (`[x]`).** `validate-boundary.sh`, which SF-8 extends, and the settled
  `provisional` state of `allowlist.base.yaml`. The milestone ordering is 02.2 before 02.3, per
  `gate-3-review.md`.
- **Upstream artifacts, pinned at build:** Terraform (`releases.hashicorp.com`), `kubectl`
  (`dl.k8s.io`), `helm` (`get.helm.sh`), `gh` (GitHub releases), all `linux_arm64` (D21's
  single-architecture constraint), plus a pinned `unzip` from the bookworm snapshot.
- **Public terms,** for the HashiCorp and GitHub R14.1 records: privacy statements, retention and
  breach notification. Read at build time; where a term cannot be established, the constraint on
  use is recorded (R14.1's own fallback).
- **Operator.** No credential or cluster is required for the Test Command. Real use of `github` and
  `kubernetes` needs:
  - a dedicated fine-grained PAT;
  - a dedicated scoped `kubeconfig`;
  - a cluster pack for a public-FQDN cluster.
- **Downstream:**
  - 02.4 rebuilds the final pack set (T18) and carries the GitHub CLI architecture-inventory edit.
  - 02.5 times revocation of the two pack credentials (T26), and exercises the MCP-disable path
    (T40) against this inventory.
  - Milestone 03 re-runs the matrix for the AWS pack under the same `BOUNDARY_PROFILES` mechanism.

## Architectural Deviations

(none)
