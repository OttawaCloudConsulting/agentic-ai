# Sandboxed Agent Containerization

Research and design options for running agentic coding agents (Claude Code, OpenAI Codex, Google Antigravity) inside a fully sandboxed container with a minimal blast radius.

**Status:** Gate 1 (Scope Review) in flight. Research complete; no architecture option ratified — that is Gate 2. See [`progress.txt`](progress.txt) for gate state and [`prd.md`](prd.md) for settled scope. No implementation yet.

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

## Out of Scope for This Directory

Deliberately not produced, because no option has been selected:

- `prd.md` / `progress.txt` — generate with `/create-prd` once an option is chosen
- `docs/ARCHITECTURE_AND_DESIGN.md` — there is no chosen architecture to document yet
- Dockerfiles, Compose files, firewall scripts, policy files, tool-pack manifests

Note that requirements R6 (AWS access) and R7 (loadable tool packs) were added after the options analysis was written. The three options remain valid — both requirements are orthogonal to the choice of enforcement architecture — but the options analysis does not yet evaluate them per option.
