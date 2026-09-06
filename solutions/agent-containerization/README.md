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
bash scripts/issue-identity.sh listener agy    --ip 172.31.30.2
bash scripts/issue-identity.sh status
```

`codex` gets no certificate: it rejects an `https://`-scheme proxy URL at parse time and its hop is
plain HTTP CONNECT (`docs/records/agent-verification.md`).

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

## What Now Exists, and What's Still Out of Scope

`prd.md` and `progress.txt` exist at this directory's root. The architecture document exists at
`.project/sandboxed-agent-containerization/docs/ARCHITECTURE_AND_DESIGN.md` — **not** at
`docs/ARCHITECTURE_AND_DESIGN.md` as an earlier version of this note (and the architecture
document's own file tree) stated; the path discrepancy itself is recorded as a finding for
`/project`, not fixed here. Dockerfiles (`images/`) and Compose files (`compose/`) exist as of
Feature 01.2. Still not produced:

- The egress mediator's policy engine, pod resolver and audit writer — Feature 01.3, in progress.
  The mediator image, its place in the Compose topology and the per-agent proxy environment exist
  (SF-4); the three agent-facing listeners, the closed DNS forwarder and the audit sink's contents
  do not yet — the container comes up on a holding configuration that refuses everything.
- Tool-pack manifests and the policy compiler — Feature 01.5
- AWS access (R6) — Milestone 03

Note that requirements R6 (AWS access) and R7 (loadable tool packs) were added after the options analysis was written. The three options remain valid — both requirements are orthogonal to the choice of enforcement architecture — but the options analysis does not yet evaluate them per option.
