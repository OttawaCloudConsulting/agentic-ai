# Sandboxed Agent Containerization

Research and design options for running agentic coding agents (Claude Code, OpenAI Codex, Google Antigravity) inside a fully sandboxed container with a minimal blast radius.

**Status:** Gate 3 (Milestone Review) in progress. Gates 1 (Scope) and 2 (Design) are ratified — see
[`prd.md`](prd.md) and [`.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md`](.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md).
Milestone 01 (Sandboxed Pod) is building; Feature 01.2 (pod topology, hardened runtime, minimal
profile) has produced a runnable pod. **This pod is not for real work yet** — it has no egress
(Feature 01.3), no authentication (Feature 01.4), and no adversarial acceptance testing (Milestone
02) until those land. See [`progress.txt`](progress.txt) for current gate/feature state.

**Entry point** (requires Docker Desktop; builds the pod cold on first run):

```
docker compose --env-file compose/pins.env \
  -f compose/compose.yaml -f compose/overrides/default.yaml up --build
```

This is the only entry point — no wrapper script. `--env-file` is required: Compose interpolates
version pins from it into the image builds, and without it the build fails.

**`--build` is required, not a convenience** (Feature 01.5 SF-4). The mediator's egress policy is
compiled by a *build stage*, so a run that reuses a cached image also reuses the policy that was
current when that image was built. Switching profiles changes only the Compose files, so without
`--build` a profile switch would appear to work while the pod kept enforcing the previous policy. The pod starts with no
default route and no route to the internet (Feature 01.3 adds the egress mediator).

**Date of research:** 2026-09-02. Agent tooling in this space moves fast; re-verify version-specific claims before building.

## Contents

| Document | Purpose |
|---|---|
| [`REQUIREMENTS.md`](REQUIREMENTS.md) | Numbered, prioritised requirements with provenance, success criteria, non-goals, open questions, and an acceptance test matrix |
| [`docs/OPTIONS_ANALYSIS.md`](docs/OPTIONS_ANALYSIS.md) | The three architectural options, comparison matrix, and recommendation |
| [`docs/RESEARCH_FINDINGS.md`](docs/RESEARCH_FINDINGS.md) | Verified per-agent reference: install shape, native sandbox, egress controls, auth/state paths, required domains, known gaps. Cited. |
| [`docs/STANDARDS_MAPPING.md`](docs/STANDARDS_MAPPING.md) | What CIS and the Five Eyes agentic AI guidance say, how it maps to our requirements, and five gaps it exposes |
| [`references/README.md`](references/README.md) | Directory of all 94 source URLs by topic, each link-checked, with a one-line note on what it covers |

## Requirements This Addresses

| # | Requirement | Requirement IDs | Design coverage |
|---|---|---|---|
| 1 | Containerize agentic AI development/coding agents | R1, R3 | All three options |
| 2 | Access limited to specific local directories, mounted | R2 | Options analysis — "Filesystem scoping" |
| 3 | Latest Claude Code, Google Antigravity, OpenAI Codex | R3 | Research findings — one section per agent |
| 4 | Persist memory and authentication state across restarts | R4 | Options analysis — "Auth and state persistence" |
| 5 | Blacklist of IP addresses, CIDR ranges, and FQDNs | R5 | Options analysis — "Egress policy"; see the caveat below |
| 6 | AWS CLI, authenticated via IAM Identity Center (SSO) | R6 | Requirements only — not yet reflected in the options analysis |
| 7 | Loadable tools that vary per use case | R7 | Requirements only — not yet reflected in the options analysis |

## Three Findings That Change the Brief

Read these before the options document — each one invalidates a common assumption.

1. **Antigravity ships a headless CLI.** Since Antigravity 2.0 (May 2026), Google ships `agy`, a single Go binary with a documented headless mode. Containerizing the desktop GUI is the wrong approach. Separately, `gemini-cli` was shut off on 2026-06-18 and returns HTTP 410 — `agy` is its replacement.

2. **All three agents now ship their own egress controls.** Claude Code has `sandbox.network.*` plus the `@anthropic-ai/sandbox-runtime` wrapper; Codex has a built-in policy proxy (`features.network_proxy`). The container's job is to be the boundary these controls cannot disable, not to reinvent them.

3. **Both vendor reference firewalls leak DNS.** Anthropic's and OpenAI's `init-firewall.sh` scripts permit UDP/53 to any destination. OpenAI documents the consequence directly: code in an untrusted repository can exfiltrate data over DNS. Any design chosen here must own DNS resolution.

## Caveat on Requirement 5

A denylist alone cannot deliver a minimal blast radius. An agent that is compromised or prompt-injected exfiltrates to any host that is *not* on the list, and the list can never be complete. Every serious implementation surveyed — Anthropic, OpenAI, Docker, iron-proxy, SlicerVM — is default-deny with an allowlist.

The recommendation is therefore: **default-deny allowlist as the primary control, with the denylist layered on top** as an independent second control for known-bad indicators, RFC1918 and link-local ranges, and the cloud metadata endpoint. All three options support both, with deny taking precedence over allow. Requirement 5 is met — it is just not the only control.

## Bring-Up

Two things must happen before `docker compose up`, and both are ordering, not preference.

**1. Issue the proxy-hop trust material.** The Compose `secrets:` have `file:` sources pointing
into `mediator/identity/`, which is generated and git-ignored — the project fails to start if the
certificates do not exist. The listener certificates carry an `iPAddress` SAN for the mediator's
static address on that agent's network, so the addresses below must match `compose/compose.yaml`'s
`ipam` blocks. See `mediator/identity/README.md` for the lifecycle, renewal and revocation paths.

```bash
bash scripts/issue-identity.sh ca
bash scripts/issue-identity.sh listener claude --ip 172.31.10.2
bash scripts/issue-identity.sh listener codex  --ip 172.31.20.2
bash scripts/issue-identity.sh listener agy    --ip 172.31.30.2
bash scripts/issue-identity.sh status
```

**`codex` needs a certificate too, and it is not a proxy hop.** Its hop *is* plain HTTP CONNECT —
it rejects an `https://`-scheme proxy URL at parse time (`docs/records/agent-verification.md`) —
but its single listener also peeks at the ClientHello, and Squid loads no signing context on a
peeking port without `tls-cert=`: it parses cleanly and then silently declines to bump, at which
point the SNI control enforces nothing. The certificate is never presented on an allowed path
(peek+splice hands the origin's own chain through untouched) and `codex` neither trusts nor
validates it. The mediator refuses to start without it. See the feature plan's Deviation 5.

**2. Bring the pod up with the profile override layered on.**

```bash
docker compose --env-file compose/pins.env \
  -f compose/compose.yaml -f compose/overrides/default.yaml up -d --build
```

### The project mount must not be this solution tree

**This is a security property, not a style note.** The default profile binds a dedicated,
git-ignored `workspace/` directory at `/workspace`, and a real profile should bind the operator's
own project directory. It must not bind this checkout.

This tree holds the control plane — `policy/`, `mediator/config/`, `mediator/identity/` — and the
project mount is read-write. An agent that could write to it could rewrite `allowlist.base.yaml` or
the mediator's configuration templates, and the next `docker compose build` would compile
agent-authored policy into the enforcement point. The running mediator is not exposed to this: it
reads its policy from its own image layer and its Compose secrets, never from a path any agent can
write. The exposure is the *next build*, which is why the fix is the default binding rather than a
warning, and why the acceptance harness asserts no agent's mount set contains a control-plane path.

### First-run authentication

`AUTH_MODE` is set per agent from the profile's `auth_mode` block. It has **no default in the
image** — an unset value is an error, not a fallback, because a default would pick an
authentication mode on your behalf and could pick a less safe one than R4.12 mandates.

**Headless means no browser inside the container**, not "no terminal". R4.9 defines the headless
path by enumeration — paste-back code, device code, or a pre-minted token — and two of those three
need a terminal by construction. See the T24 amendment in `REQUIREMENTS.md`.

Seven cells are supported, and the agents are **not** symmetric:

| Agent | `apikey` | `oauth-interactive` | `oauth-token` | `oauth-mount` |
|---|---|---|---|---|
| `claude` | `ANTHROPIC_API_KEY` | **default** — paste-back | `CLAUDE_CODE_OAUTH_TOKEN` (one-year) | unsupported (Keychain-resident) |
| `codex` | `OPENAI_API_KEY` | **default** — device code | unsupported (no env equivalent) | `auth.json` copy-in |
| `agy` | **default** — `GEMINI_API_KEY` | not offered (D9) | unsupported | not offered (D9) |

An unsupported cell **exits 2 and names the supported set**. It never quietly falls back to a
different mode — that would defeat "the default is the safest mode that agent supports".

Containers **start unauthenticated** rather than failing: the start-time pass warns and continues.
Authenticate with an explicit one-shot invocation, which is where the strict exit codes apply:

```bash
docker compose --env-file compose/pins.env \
  -f compose/compose.yaml -f compose/overrides/default.yaml \
  run --rm claude bash /usr/local/bin/bootstrap-auth claude
```

Open the printed URL **on the host** and paste the code back. Exit codes: `0` authenticated (or
already was — re-running is a no-op), `2` unsupported cell or unset `AUTH_MODE`, `3` credential
absent, `4` a provider endpoint the mediator refuses — the message names the FQDN.

**Codex uses device code, and must.** `bootstrap-auth` runs `codex login --device-auth`. Plain
`codex login` starts a callback server on `localhost:1455` *inside* the container and hands your
browser `redirect_uri=http://localhost:1455/auth/callback` — but your browser is on the host, where
nothing is listening: the pod publishes no ports and the agent networks are `internal: true`. The
provider authorizes and the flow then strands on a callback that can never arrive. Device code
needs no port at all, and is one of the three paths R4.9 counts as headless.

The **callback forward** is the documented alternative for operators who want it: publish
`127.0.0.1:1455:1455` (fallback 1457) via a layerable fragment. It is not the default — opening a
host port the headless path does not need is the wrong default under R2.8.

**On exit 4:** the OAuth endpoints must be in the allowlist, and an allowlist edit is **inert until
the policy is recompiled and the mediator image rebuilt** — the mediator reads its policy from its
own image layer, not from a bind mount:

```bash
# add the FQDN to policy/allowlist.base.yaml, then BOTH of:
bash scripts/compile-policy-build.sh    # recompile through the build stage; review the diff, commit it
docker compose --env-file compose/pins.env -f compose/compose.yaml build egress-mediator
```

Skipping the first step does not silently ship stale policy — since 01.5 SF-4 the second step
**fails** with `compile-stage: DRIFT`, because the build compiles the policy itself and refuses to
produce an image whose policy differs from the committed, reviewed artifact.

**Revocation (R12.6).** `docs/records/credential-inventory.md` carries every credential an agent can
obtain, its lifetime and its documented revocation path. The `oauth-token` cell mints a **one-year**
token — record it there and revoke it when it is no longer needed.

### Codex `oauth-mount` (optional, one-shot)

`oauth-mount` copies your **host** Codex OAuth credential into the pod's state volume, once. It
is codex's only host-credential mode and no other agent has one: claude's credential is
macOS-Keychain-resident and not portable to a Linux container, and `agy` is API-key-only by
decision.

**Read this before you use it.** Codex **rolls** its refresh token — measured, not assumed
(`docs/records/agent-verification.md`, 01.4 SF-3). The container's first refresh mints a new token
onto the volume and leaves your host `~/.codex/auth.json` holding the previous one. Treat it as a
**one-shot bootstrap that costs you your host codex login**: expect to run `codex login` on the
host again. The cost is deferred, not immediate — the refresh trigger is the access token's own
10-day expiry, so a pod you bootstrap and then leave alone may never pay it.

```bash
# 1. Stage. HOST-SIDE, and required first -- like the git-config scrub, the filtering happens
#    before the material crosses the boundary.
bash scripts/stage-oauth-mount.sh --profile oauth-mount

# 2. Bootstrap. ONE-SHOT: `run --rm`, never `up`.
docker compose --env-file compose/pins.env \
  -f compose/compose.yaml \
  -f compose/overrides/default.yaml \
  -f compose/overrides/oauth-mount.bootstrap.yaml \
  run --rm codex bash /usr/local/bin/bootstrap-auth codex

# 3. Steady state. The bootstrap fragment is NOT layered -- the credential source is absent
#    from the running pod entirely.
CODEX_AUTH_MODE=oauth-mount docker compose --env-file compose/pins.env \
  -f compose/compose.yaml -f compose/overrides/default.yaml up -d
```

What is mounted is `compose/generated/oauth-src/` — a **dedicated directory** holding exactly two
staged files — and never your `~/.codex`, which is a 54-entry directory of sessions, archived
sessions and global state. The staging script strips `OPENAI_API_KEY` from the credential on the
way through. That is a **test-validity control before it is a security one**: your host
`auth.json` carries both an OAuth token set and a raw API key, and mounted as-is codex could
authenticate off the key while the OAuth path was broken. `bootstrap-auth` refuses a source that
still carries it.

The mount is `:ro`, which is the only real control — Docker Desktop's VirtioFS fakes file
ownership, so `0600` means nothing inside the container. `bootstrap-auth` reads the actual mount
options from `/proc/self/mountinfo` and refuses anything but read-only.

**The risk record is not paperwork.** `profiles/oauth-mount.yaml` carries
`oauth_mount.codex.accepted_risk` with five fields — `file`, `mount_mode`, `revocation_path`,
`blast_radius`, `rotation` (R4.17). The staging script validates them and writes them into the
staged directory as `accepted-risk.yaml`; `bootstrap-auth` **exits 3 if that record is absent or
incomplete**. So a host credential can only cross the boundary from a directory whose operator
recorded what crossing costs. Feature 01.5 moves the same refusal to build time.

**Why "one-shot" is structural, not advice.** Steady state never layers the bootstrap fragment, so
there is no source to copy from. Two failures stop being possible rather than being guarded
against: a re-copy on every start clobbering the token the container just refreshed, and an agent
**deleting its own credential** to force a re-copy — where the guard's condition would be exactly
what the agent controls. On an emptied volume at steady state, `bootstrap-auth` exits `3` naming
the bootstrap command, and because the entrypoint runs under `set -e` that **fails the container
start**. Re-bootstrapping is a deliberate act.

Skipping step 1 is fail-closed rather than silent: Compose creates the missing source directory
empty, and `bootstrap-auth` exits `3` — at the *risk record*, which is the first thing it checks
after the mount mode, saying the directory carries no `accepted-risk.yaml`.

**The browser-redirect alternative.** If you want plain `codex login` (callback on `localhost:1455`)
instead of device code, layer `compose/overrides/codex-callback.yaml` and invoke the CLI directly —
`bootstrap-auth` hard-codes `--device-auth` on purpose:

```bash
docker compose --env-file compose/pins.env \
  -f compose/compose.yaml -f compose/overrides/default.yaml \
  -f compose/overrides/codex-callback.yaml \
  run --rm --service-ports codex codex login
```

**Not exercised.** The fragment was verified only as far as `docker compose config` renders it at
SF-4 — the flow itself has not been run, and the device-code path is what SF-2 actually measured.
`--service-ports` is required because `run` publishes nothing without it.

That publishes `127.0.0.1:1455:1455` — a host-side publish so your browser can reach *into* the
container. It gives the container no route *out*: `internal: true` is untouched and egress still
goes through the mediator or nowhere.

### Host git configuration (optional, default off)

`profiles/default.yaml` sets `mounts.host_git_config: false`, so nothing below happens unless you
opt in. When you do, **the scrub runs on the host, before `up`** — that ordering is R2.9's, not a
convenience:

```bash
bash scripts/scrub-gitconfig.sh          # writes compose/generated/gitconfig.d/.gitconfig
docker compose --env-file compose/pins.env \
  -f compose/compose.yaml \
  -f compose/overrides/default.yaml \
  -f compose/overrides/host-gitconfig.yaml up -d
```

What gets mounted is the **scrubbed artifact**, never your own `~/.gitconfig`. The scrub removes
`credential.helper` (in every subsection), `include.path` and every `includeIf` section. The
includes go because an include is a *pointer*: removing only the literal helper key would satisfy
R2.9 in letter and defeat it in fact, since the included file could re-introduce a helper from a
path this solution never mounted. Because the filtering happens before the mount, there is no
unfiltered copy inside the container for a compromised agent to read — the control is that the
material is not there, not that something declines to use it.

Re-run the scrub whenever your gitconfig changes; the artifact is a snapshot, and
`compose/generated/` is git-ignored.

**Behaviour change you will see:** the mount is `:ro` and `GIT_CONFIG_GLOBAL` points into it, so
**`git config --global` writes fail inside the container.** That is correct under R2.3 and R2.9,
and it is stated here rather than left to be discovered. Without the fragment, `GIT_CONFIG_GLOBAL`
is unset and git behaves normally, reading `~/.gitconfig` on the state volume like any container.

### Language toolchains, and the installers that are not there

The agent images carry Node, Python and Go, installed at **build time** from the pack the profile
selects (`packs/language-runtimes/pack.yaml`). They carry **no package manager at all** — not
`apt`, not `npm`, not `pip`, not `yarn` or `corepack`. That is R7.19, and it is deliberate.

```bash
node --version     # v22.23.2
python3 --version  # Python 3.11.2
go version         # go1.23.4
git --version      # git version 2.39.5
npm --version      # command not found -- by design
```

**Two consequences you will hit, and neither is a bug:**

- `python3 -m venv <dir>` fails. Use `python3 -m venv --without-pip <dir>`.
- A `package.json` cannot be installed inside the container. Vendor dependencies into the project
  mount from the host.

Even where an installer survives — one you vendor in, or `go install` using the toolchain that has
to stay for `go build` — it has nowhere to reach: the reference pack grants **no registry egress**,
so the attempt is denied at the mediator and the denial lands in the audit log. See
`packs/README.md` for which layer refuses what, and why a filesystem refusal leaves no audit line
while a mediator denial does.

### Adding or removing a pack

A pack is a directory under `packs/` holding a `pack.yaml`; a profile selects packs by name. Both
the egress policy and the installed package set are derived from that selection, by two separate
readers — the policy compiler in the mediator's build, and `images/pack-plan.sh` in the agents'.

```bash
# 1. Edit the profile's `packs:` list.
$EDITOR profiles/default.yaml

# 2. Recompile the resolved policy and COMMIT it. The build refuses to proceed on a
#    committed artifact that disagrees with its inputs (exit 4), so this is not optional.
bash scripts/compile-policy-build.sh
git diff policy/resolved/default.yaml     # review before committing
git add policy/resolved/default.yaml && git commit

# 3. Rebuild. `--build` is required, not decorative -- see "Bring-Up".
docker compose --env-file compose/pins.env   -f compose/compose.yaml -f compose/overrides/default.yaml up -d --build
```

Removing a pack is the same three steps with the name deleted. **The rebuild is what removes the
packages** — recompiling the policy alone leaves the previous image in place, with the removed
pack's binaries still in it. Editing any file under `packs/` or `profiles/` invalidates the
agent build's `COPY` layer, so a changed pack set always produces a different image.

Every `apt` item a manifest declares is verified against its recorded SHA-256 before installation,
and the snapshot repository's `InRelease` is checked with `gpgv` against the full key fingerprint
the profile pins. `packs/README.md` records precisely what that covers and what it does not.

### The image build pipeline, and the profile that selects it

`AGENT_PROFILE` is the single selector for the whole pod (01.5 SF-6). It picks the pack set the
three agent images are built with **and** the resolved policy the mediator enforces at runtime.
Unset, both are `default`.

```bash
# Build one profile's images and record what was built.
bash scripts/build.sh --profile default
```

`scripts/build.sh` drives the same Compose files the entry point drives — a second build path
would eventually record identity for images nobody runs — then tags the agent images
`sandboxed-agent/<agent>:<profile>` and writes `.build-scratch/build/<profile>.images.txt`.
Compose's own `:local` tag is reused by every profile, so without the second tag a build for one
profile silently replaces another's — and `:local` is left pointing at whichever profile was built
last. The documented entry point carries `--build`, which re-establishes it for the profile being
started; a bare `up -d` after building a different profile would run the other profile's images.
That is the same class of mismatch `AGENT_PROFILE` closes for policy, and `--build` is what closes
it here.

**What it records is an image ID, not a registry digest.** A locally built image that was never
pushed has no manifest digest — the recorded value is the sha256 of its config blob. It is stable
and comparable across rebuilds on the same host, which is what a per-profile artifact needs to be,
but it is not the same kind of identifier as `MEDIATOR_BASE_DIGEST`.

**No local SBOM, and the reason is measured rather than assumed.** Docker Desktop's default
`docker` driver cannot carry a build attestation:

```
ERROR: failed to build: Attestation is not supported for the docker driver.
```

The two ways around it both cost more than they buy: a `docker-container` builder drops the
attestation again on `--load`, and exporting an OCI tarball instead would produce an SBOM for an
image Compose could not then run. Adding a third-party scanner would mean more supply chain, not
less. So SBOM emission stays with the CI-published base image, and `scripts/build.sh` records
identity only. Turning on the containerd image store makes `--sbom=true` available and is the one
change that would revisit this.

#### CI: `.github/workflows/agent-sandbox-image.yml`

The repository's first workflow, at the **repository root** rather than in this directory. Two
independent jobs:

- **`policy-drift`** — rebuilds the resolved policy from its committed inputs through the
  mediator's `drift` build stage and fails if the result differs from the committed
  `policy/resolved/*.yaml`. One build covers every committed artifact, not one per profile. Runs
  on every push and pull request. This is the CI half of a gate that already fails the *local*
  build; it is a second net, not the first one.
- **`publish-base`** — builds the profile-independent `agent-base` stage and pushes it to
  `ghcr.io/ottawacloudconsulting/agentic-ai/agent-sandbox-base` with an SBOM and a provenance
  attestation. Never runs on a pull request: `packages: write` on a fork PR is a registry write
  granted to an untrusted contributor.

`publish-base` does not depend on `policy-drift` — the base image is profile-independent and
carries no policy, so a drifted artifact says nothing about its correctness.

**It builds `linux/arm64` only.** `compose/pins.env` carries one `GIT_SHA256`, and
`images/apt-pinned.sh` hashes the `.deb` that `apt-get download` fetches for the container's own
architecture. That hash is the arm64 one, because the pod's target is Docker Desktop on Apple
silicon. An amd64 runner does not fail subtly — it fails at the checksum comparison. Publishing a
second architecture would mean inventing a pin nothing has verified.

Branch builds are tagged by branch name and by full commit SHA; **nothing is tagged `latest`**, so
there is no mutable tag for a consumer to drift onto. The published digest is reported in the run
summary. Consuming it by digest — `AGENT_BASE_DIGEST` in `compose/pins.env` — lands with the next
sub-feature; today the agent images still build their own base locally, and the workflow publishes
without anything yet consuming it.

The workflow pins its actions by commit SHA rather than by tag. Every other supply-chain input
here is pinned by digest or checksum, and `publish-base` holds `packages: write`: an action
consumed by a movable tag would be a write path into the registry that no pin covers.

### Per-agent build cache (optional, default off)

`profiles/default.yaml` sets `mounts.build_cache: false`. To give each agent a dedicated cache
volume at `/build-cache`, layer the fragment:

```bash
docker compose --env-file compose/pins.env \
  -f compose/compose.yaml \
  -f compose/overrides/default.yaml \
  -f compose/overrides/build-cache.yaml up -d
```

One volume **per agent**, never shared — a shared cache is a write channel between two containers
that the mediator never sees, which is what R2.10 forbids. The profile schema cannot express a
shared cache at all, and `verify-pod-topology.sh` asserts that the volumes backing `/build-cache`
are distinct across agents. To enable it for only some agents, delete the others from the fragment.

### Backing up the state volumes

The per-agent state volumes hold OAuth refresh tokens once an agent authenticates. R8.7 says that
material stays out of version control *and* out of backups. This solution enforces the first half
(`.gitignore`, plus the absence of any export path it creates) and **cannot enforce the second**:
Docker Desktop stores every named volume inside one VM disk image, so there is no per-volume
exclusion to make. The exclusion is therefore a host procedure, and it is yours to run:

```bash
tmutil addexclusion ~/Library/Containers/com.docker.docker/Data
tmutil isexcluded  ~/Library/Containers/com.docker.docker/Data   # expect: [Excluded]
```

**Recorded residual:** an operator who does not run this has agent refresh tokens inside a Time
Machine backup, and nothing in this solution can detect that. Note also that the exclusion is
all-or-nothing — it covers *every* Docker volume on the machine, not only this pod's.

### When an agent's egress is refused

Every attempt that reaches the mediator produces one JSON line on the audit trail, allow and deny
alike (R9.1). That line is the **authoritative** denial record — the operator surface R12.2 asks
for — and it is where diagnosis starts:

```bash
docker compose --env-file compose/pins.env -f compose/compose.yaml \
  -f compose/overrides/default.yaml logs egress-mediator | grep '"verdict":"deny"' | jq .
```

```json
{"ts":"2026-09-07T15:55:53.392Z","agent":"codex","identity_source":"listener",
 "dest_host":"collector.example.com","dest_port":443,"resolved_ip":null,"verdict":"deny",
 "control":"allowlist","reason":"host_not_allowlisted",
 "policy":"policy/resolved/default.yaml","sni":null,"method":"CONNECT","http_status":200}
```

`control` names the refusing control and `reason` says which of its cases fired:

| `control` | `reason` | What to do |
|---|---|---|
| `allowlist` | `host_not_allowlisted` / `port_not_allowlisted` | Add the host to `policy/allowlist.base.yaml` under that agent, then `bash scripts/compile-policy-build.sh`, commit the refreshed artifact, and rebuild the mediator image |
| `allowlist` | `sni_does_not_match_connect_host` | The ClientHello named a different host than the CONNECT line. This is the domain-fronting refusal — investigate before allowlisting anything |
| `allowlist` | `agent_has_no_allowlist` | That agent has no allowed names at all in the compiled artifact |
| `denylist` | `fqdn_on_denylist` / `resolved_address_on_denylist` | Deny wins. Edit `policy/denylist.base.yaml` only if the range is genuinely not the one R5.6 requires |
| `ratelimit` | `concurrency_ceiling_exceeded` | Raise `rate_limits.<agent>.max_concurrent` in `profiles/default.yaml` — but a ceiling hit repeatedly is a signal first |
| `method` | `method_not_connect` | Something spoke plain HTTP through the proxy. The mediator tunnels TLS and never handles a plaintext request |

`identity_source` is `listener` on every line at this feature: the agent was identified by the
network its connection arrived on, not by a credential it presented. Feature 01.6 is what changes
that, and the field is there so a network-derived attribution is never read later as a
cryptographic one.

**What the agent itself sees depends on which listener refused it.** `claude` and `agy` reach a
non-bumping front listener, so a verdict decided before the CONNECT is accepted comes back as a
403 whose body names the destination, the control and the policy path. `codex`'s listener peeks at
the ClientHello and therefore accepts the CONNECT first, so *every* refusal reaches it as a
terminated connection with no body — as does any post-ClientHello refusal on the other two. The
mediator never mints a certificate for the destination to deliver an error through, which is the
capability the architecture rules out. **Diagnosis of which destination was refused is the audit
line, always.**

### The startup self-check

The mediator refuses to start on a policy that does not validate (stage 1, not skippable) and, by
default, proves the enforcement path before serving (stage 2): one allowed and one denied
destination driven through the rendered proxy from a loopback listener. Both stages record their
result:

```bash
docker compose --env-file compose/pins.env -f compose/compose.yaml \
  -f compose/overrides/default.yaml logs egress-mediator | grep startup_check
```

On a host with no working internet, stage 2 will fail a pod that is otherwise correct. Set
`startup_check.offline: true` in `profiles/default.yaml` and recompile — the skip is written to the
audit trail at every start, so a pod running without a proven path out says so in its own record.

## What Now Exists, and What's Still Out of Scope

`prd.md` and `progress.txt` exist at this directory's root. The architecture document exists at
`.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md` — **not** at
`docs/ARCHITECTURE_AND_DESIGN.md` as an earlier version of this note (and the architecture
document's own file tree) stated; the path discrepancy itself is recorded as a finding for
`/project`, not fixed here. Dockerfiles (`images/`) and Compose files (`compose/`) exist as of
Feature 01.2.

Feature 01.3 is **complete**: the three agent-facing listeners and the three egress controls, the
closed DNS forwarder, the audit writer, the denial surface and the two-stage startup self-check.
Its acceptance harness is `tests/acceptance/verify-egress-mediator.sh` — 77 assertions across
phases A–G, driven against fixtures the harness owns and reaching no third-party host:

```bash
bash tests/acceptance/verify-egress-mediator.sh
```

Feature 01.4 is **complete**: the `AUTH_MODE` dispatcher and its seven supported cells, the
pre-mount git-config scrub, the `oauth-mount` bootstrap boundary, the refresh-token rotation
record and the credential inventory. Its acceptance harness is
`tests/acceptance/verify-auth-state.sh` — phases A–E covering T24, T22, T25 and T9. Unlike
01.3's harness it iterates **live provider credentials**, so read its header before running it:
it seeds its own state volumes from the operator's, and its phase D forces a codex refresh,
which rolls the refresh token and costs the host `codex login`.

The feature's test command is composite — the two earlier harnesses must still pass, and only
one Compose project can hold the agent subnets at a time, so bring any running pod down
(**without** `-v`) first:

```bash
bash tests/acceptance/verify-auth-state.sh \
  && bash tests/acceptance/verify-pod-topology.sh \
  && bash tests/acceptance/verify-egress-mediator.sh
```

Still not produced:

- Tool-pack manifests and pack composition in the policy compiler — Feature 01.5
- Per-agent workload identity (client certificates, R8.8, T34) — Feature 01.6
- AWS access (R6) — Milestone 03

Note that requirements R6 (AWS access) and R7 (loadable tool packs) were added after the options analysis was written. The three options remain valid — both requirements are orthogonal to the choice of enforcement architecture — but the options analysis does not yet evaluate them per option.
