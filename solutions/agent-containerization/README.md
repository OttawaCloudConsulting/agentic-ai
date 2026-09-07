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
  -f compose/compose.yaml -f compose/overrides/default.yaml up
```

This is the only entry point — no wrapper script. `--env-file` is required: Compose interpolates
version pins from it into the image builds, and without it the build fails. The pod starts with no
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
  -f compose/compose.yaml -f compose/overrides/default.yaml up -d
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
| `allowlist` | `host_not_allowlisted` / `port_not_allowlisted` | Add the host to `policy/allowlist.base.yaml` under that agent, then `bash scripts/compile-policy.sh` and rebuild the mediator image |
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

Still not produced:

- Agent authentication and state persistence — Feature 01.4
- Tool-pack manifests and pack composition in the policy compiler — Feature 01.5
- Per-agent workload identity (client certificates, R8.8, T34) — Feature 01.6
- AWS access (R6) — Milestone 03

Note that requirements R6 (AWS access) and R7 (loadable tool packs) were added after the options analysis was written. The three options remain valid — both requirements are orthogonal to the choice of enforcement architecture — but the options analysis does not yet evaluate them per option.
