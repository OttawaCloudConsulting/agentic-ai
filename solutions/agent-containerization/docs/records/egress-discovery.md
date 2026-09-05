# Egress Discovery — SF-3

**Feature:** 01.1 Pre-build verification, provider governance and egress discovery, SF-3
**Date:** 2026-09-04/05
**Method:** `sbx` (Docker Sandboxes CLI, `docker/tap/sbx`, v0.39.0) run one agent at a time against
a throwaway synthetic repository (`.build-scratch/sf3/synthetic-repo/`, a trivial Node project with
one intentionally-failing test), under the global network policy `sbx policy init deny-all` and
throwaway operator-supplied credentials (`references/.env_keys`, git-ignored). Each agent's attempt
was cross-validated against a second, independent source per D17 (agent verbose logging, or static
review of installer source for `agy`'s update-check host).

## Correction — first-pass capture was not at the SF-2 pins

The first capture pass used `sbx run claude`/`sbx run codex` unmodified. Both of `sbx`'s first-party
templates (`docker/sandbox-templates:claude-code-docker`, `codex-docker`) bundle their **own**
agent version, independent of whatever version the operator's own host or Dockerfiles pin —
`claude --version` reported `2.1.246` and `codex --version` reported `0.149.1` inside the unmodified
sandboxes, against SF-2's pins of `2.1.260` and `0.152.1`. This was caught (not by this record's
first draft) before being reported as complete, and fixed by re-pinning **in place** before
re-running the capture:

- **claude**: the template's native installer supports exact-version pinning directly —
  `claude install 2.1.260` (downloads via `downloads.claude.ai`, already one of the six hosts the
  template's own kit bypasses regardless of policy — see below — so no temporary policy change was
  needed for this step).
- **codex**: no in-template pinning mechanism; reinstalled via `npm install -g
  @openai/codex@0.152.1`, which required a temporary per-sandbox allow for `registry.npmjs.org`
  (added, used, then removed before the discovery task ran, so it does not appear in the task-time
  capture below).

**The re-capture at the correct pins reproduced the first pass's results exactly** — identical
hosts, identical or near-identical request counts, for both agents. This is genuine signal: the
observed egress surface is stable across these two nearby versions, not an artifact of running the
wrong one. It also means the version mismatch does **not** explain claude's non-reproduction of
SF-2's incidental `datadoghq.com` sighting (see below) — that discrepancy remains open under the
"event-triggered, not every invocation" theory, now with the version-drift alternative ruled out
rather than merely unconsidered.

This is flagged here as a correction, not as an Architectural Deviation under D-11/D-12 — the
implementation did not choose a different approach than the plan specified; it executed the
specified approach against the wrong artifact (a template's bundled version) and corrected the
mistake before the sub-feature was reported complete, per this project's own "reality is the
arbiter" verification discipline. All data in this record and in `policy/allowlist.base.yaml`
reflects the corrected, pin-accurate captures.

## Method note — `sbx` was not installed; naming and access notes

`sbx` was not present on the host at SF-3 start (no binary, no `docker sandbox`/`docker sandboxes`
subcommand). Installed via `brew install docker/tap/sbx` (macOS, Apple Silicon — matches R11.1/A1),
authenticated via `sbx login` (Docker Hub OAuth, operator action). This is recorded here rather than
as a deviation because the plan's Dependencies section already names Docker Sandboxes as required
and this host as its target platform — installing a stated dependency is not a change to the
approach.

**Preset naming has drifted from `docs/RESEARCH_FINDINGS.md:308`'s research** (which named
`open`/`balanced`/`locked-down`). The installed CLI (v0.39.0) exposes `allow-all` / `balanced` /
`deny-all` via `sbx policy init`. `deny-all` is the operative equivalent of the plan's
"locked-down" — block everything by default, then observe what is attempted — and is what this
discovery run used throughout. `docs/RESEARCH_FINDINGS.md` is annotated with this correction.

## Finding: `agy` CAN run under `sbx` — the plan's open edge case is resolved

The plan named an edge case: "`agy` cannot run under `sbx` at all... if that means `agy` cannot
execute inside a sandbox rather than merely lacking a first-class template, its allowlist seed has
no capture source." Established first, before running claude or codex, per the plan's instruction.

`sbx run`'s built-in agent list is `claude, codex, copilot, cursor, docker-agent, droid, gemini,
kiro, opencode, shell` — no `agy` entry (Google's Gemini CLI, `gemini`, is a different tool from
Antigravity's `agy`, consistent with the architecture's three-agent set). This confirmed a
first-class template is genuinely absent. To determine whether the deeper claim also held (`agy`
cannot execute under `sbx`'s sandbox technology at all), a generic `shell` sandbox was created,
`agy`'s install script was downloaded and reviewed (not piped directly into `bash` — a
Claude-Code-side classifier declines direct `curl | bash`; downloading then executing the reviewed
file is the safe equivalent) and run inside the sandbox.

**Result: `agy` 1.1.26 installed and ran successfully inside `sbx`.** It is not structurally barred
— it only lacks a first-class template. `sbx`'s network mediation is sandbox-level, not
template-specific, so a `shell`-based sandbox is captured by `sbx policy log` exactly like a
first-class one. This is a better outcome than the plan's worst case: `agy` gets a real `sbx`
discovery capture, not a verbose-log-only fallback.

The install script's `DOWNLOAD_BASE_URL` is
`https://antigravity-cli-auto-updater-974169037036.us-central1.run.app` — a Cloud Run URL, not
`antigravity.google` as `docs/records/agent-verification.md` assumed by name alone. Confirmed by
reading the script (`curl -fsSL https://antigravity.google/cli/install.sh -o` a file, not piped)
and by two later occurrences in the policy log (once during install, once again during the
unrelated task run below — `agy` checks this host on every invocation, not only at install,
consistent with SF-2's "automatically self-updates in the background during regular runs").

## Finding: `sbx`'s own first-party kits bake in vendor allow rules that bypass the global policy

Two non-removable (`"editable": false`) per-sandbox rules were observed that `sbx policy ls
<sandbox> --wide --json` attributes to origin `"scoped"`, name `kit:<sandbox-name>` — i.e. baked
into the template/kit itself, not something this discovery run, or any operator policy, added:

- The generic **`shell` template** (`docker/sandbox-templates:shell-docker`, used for the `agy`
  capture) unconditionally allows **`openrouter.ai`** — a fourth AI provider outside this
  project's approved set (Anthropic, OpenAI, Google) — regardless of the global `deny-all` policy.
  Not exercised by either the install or task run (no traffic observed to it), so it is **not**
  included in `policy/allowlist.base.yaml` — but it is a real, present, non-removable allow rule on
  any sandbox built from this template, and is flagged here as a governance finding, not resolved.
- The **`claude-code-docker` template** unconditionally allows six hosts: `api.anthropic.com`,
  `platform.claude.com`, `downloads.claude.ai`, `claude.com`, `mcp-proxy.anthropic.com`,
  `bridge.claudeusercontent.com`. Only `api.anthropic.com` showed real traffic during the capture
  task (33 requests over ~5 minutes); the other five were not exercised.
- The **`codex-docker` template carries no equivalent kit rule** — `sbx policy ls sf3-codex-capture
  --wide --json` returned no sandbox-scoped rules at all. codex's capture is therefore a genuine
  deny-all discovery (real 403 rejections observed, see below), while claude's is not — the
  `deny-all` methodology does not apply uniformly across `sbx`'s own templates.

**Consequence for this record and for `policy/allowlist.base.yaml`:** only `api.anthropic.com` is
seeded for claude, and it is annotated `source: [sbx-discovery-capture]` without a second source —
its "capture" was kit-bypassed traffic, not a deny-then-observe result, so it does not meet D17's
cross-validation bar on its own (real traffic confirms it is *used*; it does not independently
confirm it is *sufficient and minimal*, since nothing else had the chance to be blocked-and-seen).
The other five kit-allowed Anthropic hosts are deliberately **not** seeded — no observed use, and
including them on the kit's authority alone would be the vendor-copied allowlist R5.8/D17 forbid.

This is a discovery-harness limitation, not a statement about 01.3's own mediator (a separate,
custom-built component per the architecture — this finding does not imply 01.3's real enforcement
point will have the same bypass; it means `sbx` cannot be relied on alone to prove a host is
*unneeded*, only to help observe what *is* used).

## Per-agent capture results

All three runs used the same task against the synthetic repo: *"Read TASK.md and fix the bug in
math.js"* (`math.js` has `add(2,2)` computing correctly; `test.js` asserts it equals 5 — an
intentionally wrong assertion the task is not supposed to touch). Task completion was not the goal
and none of the three completed it (each is blocked from reaching its model API to varying
degrees) — consistent with SF-2's framing that the criterion is that each result is recorded, not
that each passes.

### claude 2.1.260 (SF-2 pin, verified via `claude install 2.1.260` before this capture — see Correction above)

| Host | Port | Requests | Sources | Notes |
|---|---|---|---|---|
| `api.anthropic.com` | 443 | 11 (33 in the pre-correction run at 2.1.246) | sbx policy log only | Kit-bypassed (see above); real, repeated traffic confirms use, not sufficiency |

No other host reached the proxy, in either the 2.1.246 or the corrected 2.1.260 run. Notably, **no
telemetry/analytics host was observed** in either run — SF-2's earlier probe incidentally saw an
attempt at `http-intake.logs.us5.datadoghq.com` during a single authenticated prompt. Reproducing
this discrepancy at the exact SF-2 pin rules out version drift as the explanation: it is not that
2.1.246 lacked telemetry that 2.1.260 has. Left as an open discrepancy, now narrowed to
event-triggered behaviour (session-start only, not every `-p` invocation) or an environmental
difference between SF-2's Go-fixture probe and this run's `sbx` sandbox. Not included in the
allowlist on the strength of a non-reproduction; flagged for the next validation pass.

The task did not complete in either run (repeated internal retries with no error surfaced after
~30-45 seconds; killed rather than diagnosed further, since the egress signal — the only thing SF-3
owns — had already stopped changing well before that).

### codex 0.152.1 (SF-2 pin, verified via `npm install -g @openai/codex@0.152.1` before this capture — see Correction above)

| Host | Port | Requests | Sources | Notes |
|---|---|---|---|---|
| `api.openai.com` | 443 | 13 | sbx policy log + codex's own verbose stderr | Cross-validated. Real `403 Forbidden` / "Blocked by network policy" rejections confirm `deny-all` is genuinely enforced for this template |
| `chatgpt.com` | 443 | 2 | sbx policy log only | Single-source; matches SF-2's incidental sighting |
| `api.github.com` | 443 | 1 | sbx policy log only | Single-source; matches SF-2's incidental sighting |
| `github.com` | 443 | 1 | sbx policy log only | Single-source; matches SF-2's incidental sighting |

codex's own stderr named `api.openai.com` explicitly (`wss://api.openai.com/v1/responses`,
`Blocked by network policy: domain api.openai.com:443`) after 5 WebSocket reconnect attempts and 5
HTTPS-fallback attempts, then gave up. `chatgpt.com`/`api.github.com`/`github.com` were not narrated
in codex's own log text — visible only at the network layer — so they remain single-source,
consistent with D17's provisional bar. SF-2's `codeload.github.com` sighting did not recur in this
run.

### agy (no real pin; 1.1.26 observed, matching SF-2)

| Host | Port | Requests | Sources | Notes |
|---|---|---|---|---|
| `generativelanguage.googleapis.com` | 443 | 2 | sbx policy log + agy `--log-file` | Cross-validated. Primary model API |
| `antigravity-unleash.goog` | 443 | 2 | sbx policy log + agy `--log-file` | Cross-validated. Feature-flag/"unleash" service — not previously named in RESEARCH_FINDINGS |
| `playwright.azureedge.net` | 443 | 1 | sbx policy log + agy `--log-file` | Cross-validated. CDN mirror |
| `playwright-akamai.azureedge.net` | 443 | 1 | sbx policy log + agy `--log-file` | Cross-validated. CDN mirror |
| `playwright-verizon.azureedge.net` | 443 | 1 | sbx policy log + agy `--log-file` | Cross-validated. CDN mirror |
| `antigravity-cli-auto-updater-974169037036.us-central1.run.app` | 443 | 1 (this run) + install-time | sbx policy log + installer source | Self-update check, recurs on every invocation |

The three `playwright*.azureedge.net` hosts strongly suggest `agy` bundles a browser-automation
capability (Playwright) that attempts a CDN fetch even for a plain text-editing task — worth a
named line item for 01.2/01.3 rather than treating it as one host.

**Excluded, install-time only (not in the seed):** `antigravity.google` (443) and
`storage.googleapis.com` (443) — both allowed only during the install-script step (temporarily,
under a scoped per-sandbox allow this record added and then removed before the task run), with zero
repeat during the clean task-time capture. Current evidence treats them as install-time, not
ongoing-runtime, dependencies — relevant to 01.2's D9/R10.6 build-vs-live-install choice for `agy`,
not to the pod's steady-state allowlist.

## Cross-run noise, excluded from all three agents

Two hosts appeared as `blocked` in every sandbox regardless of agent — `ports.ubuntu.com:80` and
`download.docker.com:443` — with `count_since` accumulating from container boot, not from the task
invocation. These are `sbx` base-image-level checks (the underlying VM/container OS, not the
agent's own HTTP client) and are excluded from every agent's allowlist as sandbox infrastructure
noise, not agent-attributable egress. `mcp-gateway.docker.internal:80` (`<daemon-managed alias>`)
is `sbx`'s own internal MCP gateway — a local Docker-internal address, not a real internet
destination — likewise excluded.

## Denylist

`policy/denylist.base.yaml` is static per the plan's Interface Contract — link-local
(`169.254.0.0/16`, including the `169.254.169.254` metadata endpoint), loopback (`127.0.0.0/8`) and
RFC1918 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`). No discovery run informs this list; it is
required regardless of what any agent was observed to need (R5.6).

## Why the allowlist stays provisional

Per D17, `policy/allowlist.base.yaml` carries `provisional: true` and will until every entry has
two-source agreement. Currently:

- **agy**: fully cross-validated (policy log + agy's own `--log-file`, or installer source for the
  update-check host).
- **codex**: primary host cross-validated; three secondary hosts single-source.
- **claude**: primary host is single-source by construction (kit bypass prevented a genuine
  deny-then-observe capture) — the weakest evidentiary basis of the three, despite being the
  simplest-looking entry.

The sbx UDP/ICMP blind spot named in `docs/ARCHITECTURE_AND_DESIGN.md` D17 applies to all three
regardless of cross-validation status: a legitimate UDP dependency in any agent is invisible to
this capture method entirely and would surface later as a novel failure.

## Files produced by this discovery run (not committed — throwaway per D17)

- `.build-scratch/sf3/synthetic-repo/` — the synthetic repository (git-ignored via
  `.build-scratch/`)
- Five `sbx` sandboxes across the two capture passes (`sf3-agy-probe`, `sf3-claude-capture`,
  `sf3-codex-capture`, then `sf3-claude-repin`, `sf3-codex-repin` for the corrected pass) and their
  scoped secrets — created, captured, then removed (`sbx rm --force`, `sbx secret rm -f`) at the
  end of each pass, per D17's synthetic-repo/throwaway-credential constraint
- Two local Docker images (`sf3-claude-pinned:local`, `sf3-codex-pinned:local`) built as a first
  attempt at a custom `sbx --template` for exact-pin capture; abandoned (`sbx` pulls templates from
  a registry, not the local Docker image store — `403 Forbidden`) in favour of reinstalling the
  pinned version inside the first-party template instead. Removed (`docker rmi`)

## Operator note — host state left changed by this discovery run

`sbx policy init deny-all` was set as the **global** default and left in place — it is the safer
default for a host that will keep running sandbox discovery work, but it is a persistent change to
`sbx`'s behavior for *any* future sandbox on this host, not scoped to this discovery run. Reset with
`sbx policy init balanced` (or `allow-all`) if that is not the desired steady state.
