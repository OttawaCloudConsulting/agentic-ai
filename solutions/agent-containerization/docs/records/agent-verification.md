# Agent Client Verification — SF-2

**Feature:** 01.1 Pre-build verification, provider governance and egress discovery, SF-2
**Date:** 2026-09-04
**Method:** `scripts/verify-agent-clients.sh` — a throwaway CONNECT-proxy fixture (Go, `net/http`
hijacked tunneling) on an isolated `docker compose` network (`internal: true`; the fixture
container is the only member also attached to an egress network). Two listeners: a plain HTTP
CONNECT proxy (`:18080`, no TLS to the proxy hop) and a TLS CONNECT proxy (`:18443`,
`tls.RequireAndVerifyClientCert`) signed by a throwaway CA. Each agent ran in its own container on
the internal network only, so the fixture is its sole egress path. Fixture behaviour was calibrated
with `curl` before any agent touched it (plain proxy: 200; mTLS proxy with a calibration client
cert: 200; mTLS proxy with no cert: connection refused, `tls: client didn't provide a certificate`
on the server side) — see **Method note** at the end for the full calibration transcript.
Credentials: operator-supplied throwaway API keys (`references/.env_keys`, git-ignored, disabled by
the operator except when a test is running).

**Deviation from the plan's Approach section:** none. The plan specifies a Docker `internal: true`
network as the isolation mechanism and that is what this fixture uses — agent containers have no
route to the internet except through the fixture. (An earlier host-based alternative that would have
skipped Docker network isolation entirely was proposed and rejected by the operator in favour of
this containerized approach.)

---

## Version pins (criterion 7)

| Agent | Version | Install source | Version-pinning capability | Date pinned |
|---|---|---|---|---|
| claude | 2.1.260 | Native installer, versioned builds at `~/.local/share/claude/versions/<version>`; `claude install <version>` accepts `stable`, `latest`, or an exact version. npm mirror `@anthropic-ai/claude-code@2.1.260` also available and is what the container image installs. | **Yes** | 2026-09-04 |
| codex | 0.152.1 | npm `@openai/codex@0.152.1`; exact version pin, package integrity verified by npm (`dist.integrity: sha512-dSwQzl6JgsFe8L9i8xUnwRz9Vy8gn4UvXFU9xq2IJ1eC7zsSttqQ2SGq49ZZIjEyZQ0LZjCs6Bvtxort2Iyebg==`). | **Yes** | 2026-09-04 |
| agy | 1.1.23 on the host; the container image (built same day from the official install script) resolved to **1.1.26** | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` — no version flag, no channel selection. Fetched a JSON manifest is fetched from a fixed `DOWNLOAD_BASE_URL` and always installs the version in the manifest at run time. The script's own text: *"The Antigravity CLI automatically self-updates in the background during regular runs."* | **No.** Confirmed empirically: a build run minutes apart from the host install pulled a newer version (1.1.26 vs 1.1.23) from the identical install command. There is no `-v`/`--version`/channel flag (`install.sh --help` lists only `-d/--dir` and `-h/--help`). | 2026-09-04 (best-effort only — not a real pin) |

**Consequence for 01.2 and R10.6.** `agy`'s Dockerfile cannot pin a version the way `codex`'s
(`npm ci`-style exact version) or `claude`'s (`claude install <version>`) can. 01.2 has two options,
neither exercised here (out of SF-2 scope): (a) vendor/cache a specific downloaded binary at build
time and skip the installer's live manifest fetch entirely, or (b) accept that `agy`'s pin is
"whatever the manifest served on build day" and re-verify after every image rebuild per R10.6.
Recorded as a build-blocking open item for 01.2, not resolved here.

---

## `agy` HTTPS_PROXY, GEMINI_API_KEY route, and CA-trust (criterion 4)

All three sub-questions are **resolved**, superseding the RESEARCH_FINDINGS UNVERIFIED markers at
lines 288, 353 and 354.

**4(a) — Does `agy` honour `HTTPS_PROXY`? Yes, for both `http://` and `https://` proxy URL
schemes.**

Evidence (`agy-plain`, `HTTPS_PROXY=http://fixture:18080`):
```
=== probe ===
OK
=== exit code: 0 ===
```
Fixture log for the same run:
```
mode=plain target=generativelanguage.googleapis.com:443 cert=none outcome=tunnel-established
mode=plain target=play.googleapis.com:443 cert=none outcome=tunnel-established
```
Evidence (`agy-mtls`, `HTTPS_PROXY=https://fixture:18443`, no client cert configured): `agy`
attempted a full TLS handshake to the proxy itself (retried 8 times), which only the client-cert
requirement rejected (see 4(c) and the client-cert section below) — proof `agy` supports an
`https://`-scheme proxy URL, not just `http://`. Contrast with `codex` (below), which rejects an
`https://` proxy URL at parse time and never attempts a network call.

**4(b) — Does the `GEMINI_API_KEY` route work?** **Yes, on `agy` 1.1.26, with `modelProvider:
"gemini"` set in `~/.gemini/antigravity-cli/settings.json` and `GEMINI_API_KEY` exported.** The
probe received a genuine model response ("OK") from `generativelanguage.googleapis.com` through the
plain proxy. This resolves the maintainer/official-docs conflict RESEARCH_FINDINGS:279 flagged as
UNVERIFIED — the June 2026 maintainer statement that Gemini API keys were unsupported is superseded
as of 1.1.26. (Billing tier of the operator-supplied key — free vs. paid — was not established by
this test and remains a separate open item from the SF-1 record.)

**4(c) — `agy`'s CA-trust mechanism: `SSL_CERT_FILE`. Not `CACERT_PATH`.** `strings` on the `agy`
binary surfaced both `SSL_CERT_FILE`-style symbols and a `CACERT_PATH` string; only one is actually
consulted. Discriminated with two otherwise-identical runs against the mTLS fixture (which uses a
throwaway CA `agy` has no reason to trust unless told to):

- `SSL_CERT_FILE=/pki/ca.crt`, `CACERT_PATH` unset: TLS handshake proceeded past server-certificate
  validation; failure was `tls: client didn't provide a certificate` (server-side, i.e. `agy`
  accepted the fixture's CA and only lacked a client cert to present).
- `CACERT_PATH=/pki/ca.crt`, `SSL_CERT_FILE` unset: failure was `remote error: tls: bad certificate`
  (client-side rejection — `agy` did **not** trust the fixture's CA).

`CACERT_PATH` is very likely an unrelated constant (a different subsystem or vendored dependency);
`SSL_CERT_FILE` is the operative variable, consistent with Go's `crypto/x509` default behaviour on
Linux when the binary hasn't overridden the system pool.

---

## Client-certificate presentation (criterion 5)

**Question:** is each agent's HTTP client capable of presenting a client certificate to a TLS proxy
listener at all?

| Agent | Result | Mechanism | Evidence |
|---|---|---|---|
| claude | **Yes** | `CLAUDE_CODE_CLIENT_CERT` / `CLAUDE_CODE_CLIENT_KEY` (documented). Confirmed empirically. | Fixture log: `mode=tls-mtls target=api.anthropic.com:443 cert=sf2-claude-client outcome=tunnel-established` (12 tunnels across the two runs). Probe output: `OK` — a genuine Anthropic API response was returned through the mTLS-terminated proxy hop. |
| codex | **No — structural, not just "no cert var".** codex's proxy client rejects an `https://`-scheme `HTTPS_PROXY` **at URL-parse time**, before any TLS handshake to the proxy is attempted. No client-cert variable exists (confirmed absent from `--help`, `config.toml` reference, and binary `strings`) but the more consequential finding is that codex cannot use a TLS-terminated proxy listener *at all*, only a plain `http://` CONNECT proxy. | No documented client-cert env var. Rejects `https://` proxy scheme outright. | Both codex's primary WebSocket transport and its HTTPS fallback produced the identical error: `URL error: Proxy URL scheme not supported, url: wss://api.openai.com/v1/responses` / `...stream disconnected before completion: URL error: Proxy URL scheme not supported`. Fixture log has **zero** `mode=tls-mtls` entries for codex across two independent runs — the proxy never received a TCP connection attempt on `:18443` from the codex container. |
| agy | **No — reaches the TLS layer but has no cert to offer.** | No documented or discovered client-cert variable. | Fixture stderr (handshake log, captured before container teardown): 8 handshake attempts, each `tls: client didn't provide a certificate`; the last: `read tcp ...:18443->...: read: connection reset by peer`. Probe output: `Error: Agent execution terminated due to error.` This is a materially different failure mode from codex: `agy` gets to the `CertificateRequest` stage of the TLS handshake (proving it trusts the proxy's CA per 4(c)) and only then has nothing to present. |

**Consequence for R8.8 / 01.3.** Not a uniform negative (the plan's worst-case edge case). One agent
(claude) can present a client certificate to an HTTPS-scheme mediator today. The other two cannot,
but via different mechanisms that matter for 01.3's design:
- **codex** needs a plain `http://` CONNECT proxy — an `https://`-scheme mediator listener is a
  non-starter for this agent regardless of certificate support. If mTLS-to-mediator becomes a hard
  requirement, codex is the forcing constraint, not a missing env var codex might grow later.
- **agy** already negotiates TLS to the proxy correctly (given CA trust via `SSL_CERT_FILE`); it is
  one unreleased feature (a client-cert env var) away from parity with claude, not a structural
  blocker.

R8.8's mechanism is **not** uniformly redesigned by this result — it can work for claude today; it
needs either a non-TLS fallback path or an alternative authentication mechanism (e.g. network-layer
identity, not TLS client-cert) for codex and agy. This is a design decision for 01.3, not resolved
here.

---

## Default MCP transport, per agent and per configured server (criterion 6)

| Agent | Transport options | What's configured on this host | Default when adding a server |
|---|---|---|---|
| claude | stdio (`command`) or HTTP/SSE (`url`, `type: "http"`) | 6 servers: 5 remote HTTP/SSE (`claude.ai` connectors, Google Drive/Calendar/Gmail, a Zoho MCP), 1 stdio (`context7` via `npx -y @upstash/context7-mcp@latest` at project scope; a conflicting user-scope entry for the same name is configured as HTTP) | No forced default — transport is whichever key (`command` vs `url`) the config entry uses. |
| codex | stdio (`command`) or HTTP (`type = "http"`, `[mcp_servers.<name>.http_headers]`) in `config.toml` | 4 servers: 1 explicit HTTP (`context7`), 3 stdio (`node_repl`, `computer-use` — disabled, `caveman-shrink`) | No forced default — same per-entry choice as claude. |
| agy | stdio (`command`) or SSE (`serverUrl`) per `~/.gemini/config/mcp_config.json` schema | **None configured** — the global config file exists and is empty on this host. | No forced default; schema requires one of `command` or `serverUrl` per entry, no fallback. |

**Enforcement-point statement (criterion 6's explicit requirement).** For every stdio-transport MCP
server on all three agents: **no application-layer enforcement point covers it.** stdio servers are
local subprocesses; whether their own outbound HTTP calls honour `HTTPS_PROXY` depends on that
subprocess's own runtime (e.g. `npx`-launched Node tools do not automatically respect proxy env vars
without an explicit proxy agent) and was not tested here — out of SF-2's scope. The egress of a
stdio MCP subprocess is covered only by **the pod's network-namespace-level enforcement** that 01.3
builds (all pod egress forced through the mediator regardless of what the subprocess's own HTTP
client does), not by any per-application proxy configuration. HTTP/SSE-transport MCP servers ride
the agent's own HTTP client and are subject to the same `HTTPS_PROXY` behaviour documented above for
each agent's main API traffic.

---

## Throwaway TLS listener and `internal: true` fixture

Delivered as `scripts/verify-agent-clients.sh`. Not the 01.3 mediator — no policy enforcement, no
allow/deny logic, torn down (containers, images, compose-managed networks) at the end of every run.
Re-running the script regenerates the PKI and rebuilds the fixture and agent images from scratch;
nothing about it is meant to persist between runs except the throwaway CA/cert material under
`.build-scratch/sf2/` (git-ignored).

---

## Incidental egress observations (handed off to SF-3, not owned here)

SF-2's probes are single authenticated prompts, not the constrained `locked-down` discovery run
SF-3 owns — but the CONNECT log incidentally captured real destinations worth flagging for that
capture, not treated as a seed here:

- **claude** also attempted `http-intake.logs.us5.datadoghq.com:443` (a telemetry/analytics beacon)
  alongside `api.anthropic.com`. The attempt failed in this fixture (DNS resolution issue inside the
  fixture container, not a client-side failure) but the attempt itself is the relevant fact for
  SF-3's allowlist scope.
- **codex** additionally reached `chatgpt.com`, `api.github.com`, and `codeload.github.com` beyond
  `api.openai.com` — plausibly telemetry, update checks, or extension/tool fetches.
- **agy** additionally reached `play.googleapis.com` beyond `generativelanguage.googleapis.com` —
  plausibly a Google Play Integrity or telemetry call.

None of these were cross-validated (single source, single run) and none should be treated as
allowlist-ready; SF-3's `locked-down` capture with cross-validation is the authoritative source.

---

## Method note — fixture calibration transcript

Before any agent touched the fixture, `curl` calibration confirmed the discriminator works in both
directions:

```
$ curl --proxy http://127.0.0.1:18080 https://example.com -o /dev/null -w "http_code=%{http_code}\n"
http_code=200

$ curl --proxy https://127.0.0.1:18443 --proxy-cacert ca.crt \
       --proxy-cert client.crt --proxy-key client.key \
       https://example.com -o /dev/null -w "http_code=%{http_code}\n"
http_code=200

$ curl --proxy https://127.0.0.1:18443 --proxy-cacert ca.crt \
       https://example.com -o /dev/null -w "http_code=%{http_code}\n"
http_code=000   # curl exit 56
```

Fixture log / stderr for the three calls, in order:
```
mode=plain target=example.com:443 cert=none outcome=tunnel-established
mode=tls-mtls target=example.com:443 cert=sf2-calibration-client outcome=tunnel-established
http: TLS handshake error from 127.0.0.1:50039: tls: client didn't provide a certificate
```

This confirms the three outcomes the record above distinguishes between (proxy honoured with a
cert, proxy honoured without a cert being available, proxy not reached at all) are actually
distinguishable by this fixture, not an artifact of how a given agent happens to fail.

---

## Base-posture bubblewrap nesting probe — 01.2 SF-2

**Feature:** 01.2 Pod topology, hardened runtime and minimal profile, SF-2
**Date:** 2026-09-04
**Question:** can bubblewrap create and use a fresh mount/user namespace (the primitive `srt` and
Codex's `features.network_proxy` nesting both depend on) inside a container running D15's hardened
posture — `cap_drop: ALL`, `no-new-privileges`, non-root, read-only rootfs?

**Method:** built the `agent-base` stage (`images/Dockerfile`, `node:22-slim` + `bubblewrap`
package) and ran `bwrap --ro-bind / / --proc /proc --dev /dev --unshare-all --die-with-parent
/bin/echo ok` inside `docker run` with progressively relaxed flags, isolating which restriction is
responsible.

**Result: fails under D15's posture, and fails for a reason D15's flags cannot fix.**

| Flags | Result |
|---|---|
| `--user 1000:1000` only | `bwrap: No permissions to create new namespace, likely because the kernel does not allow non-privileged user namespaces.` |
| `--user 1000:1000` + `--security-opt no-new-privileges` | Same error |
| `--user 1000:1000` + `--cap-drop=ALL` | Same error |
| `--cap-drop=ALL` + `--security-opt no-new-privileges`, **root** | Same error |
| `--security-opt seccomp=unconfined` **+ full D15 posture** (`cap_drop: ALL`, `no-new-privileges`, non-root) | `bwrap: Can't mount proc on /newroot/proc: Operation not permitted` — the exact failure `RESEARCH_FINDINGS.md:76` documents |

`/proc/sys/kernel/unprivileged_userns_clone` does not exist in the Docker Desktop VM kernel (that
sysctl is a Debian-only patch; upstream kernels allow unprivileged user namespaces by default), so
the first-row failure is **Docker's default seccomp profile** blocking `unshare(CLONE_NEWUSER)`
outright — not a kernel restriction and not anything D15's own flags (`cap_drop`,
`no-new-privileges`, non-root user) contribute to or could relax. Relaxing seccomp *specifically*
(and only that) reproduces the documented `/proc`-mount failure one layer in, confirming this is
the same failure mode Anthropic's own documentation names, not a Docker Desktop artifact.

**Consequence:** no combination of D15's hardening flags permits bubblewrap-based nesting
(`srt`, Codex's `features.network_proxy`, `agy --sandbox` if it uses the same primitive) on this
host. The only way to enable it would be an *additional* hardening exception — `security_opt:
seccomp=unconfined` or a custom seccomp profile allowlisting the relevant syscalls — which R1.4
requires to be individually justified, and none is currently justified for this milestone. Recorded
as a D14 amendment; see 01.2's feature plan, Architectural Deviations, Deviation 2. All three
agents' native sandboxes are disabled by default per R3.8 pending `/milestone` revision of D14.

---

## `agy` version pin — resolved (01.2 SF-2)

The pin-capability gap recorded above (**"No... build-blocking open item for 01.2"**) is resolved
via option (a): a direct, checksum-verified download, no installer script executed.

`agy`'s installer (`https://antigravity.google/cli/install.sh`, fetched and read, never piped to a
shell — R7.7) queries `https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/<platform>.json`,
which returns a **version-suffixed URL** plus a `sha512`:

```json
{
  "version": "1.1.26",
  "url": "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.1.26-5550154686791680/linux-arm/cli_linux_arm64.tar.gz",
  "sha512": "332dddb06ab4d901a44cfd4b9b358848230e64a64515a8e79b03822348adac9ce92d54cb4fc5119ef075edfba922820c926dfddf82d3a49f4ecdb6e6704dfc75"
}
```

The URL's path embeds the version (`1.1.26-5550154686791680`), so it is content-addressed in
practice: the same URL always serves the same bytes, verified against the manifest's own `sha512`
at build time. `compose/pins.env` records `AGY_VERSION`, `AGY_URL` and `AGY_SHA512` for the
`linux_arm64` platform (Docker Desktop on Apple silicon, A1). This is a real pin — rebuilding the
image next month with the same `pins.env` fetches the identical, hash-verified artifact regardless
of what the live manifest serves by then — unlike the manifest URL itself, which always resolves to
"latest." `linux_arm64_musl` returns 404 from this manifest endpoint, confirming the base image
must be glibc-based (`node:22-slim`, not an Alpine variant) for `agy` specifically.

---

## Per-agent native-sandbox verdicts — 01.2 SF-3 (criterion 7)

Per the base-posture result above (unprivileged user-namespace creation is blocked by Docker's
default seccomp profile, independent of which process requests it), all three agents' native
sandboxes are **disabled by default**, matching Deviation 2 (D14 amendment).

| Agent | Mechanism | Verdict | Basis |
|---|---|---|---|
| claude | `srt` (`@anthropic-ai/sandbox-runtime`) | **Disabled** | Depends on the same bwrap/user-namespace primitive the base-posture probe found blocked. Not independently re-probed — the blocking mechanism (seccomp on `unshare(CLONE_NEWUSER)`) is process-agnostic. |
| codex | `features.network_proxy` (bubblewrap-based) | **Disabled** | Same basis. Also pre-existing R3.8 finding independent of this probe. |
| agy | `--sandbox` ("terminal restrictions") | **Disabled** | Same basis. Mechanism not independently confirmed to use bubblewrap (agy's binary is closed-source), but no combination of D15's flags permits any unprivileged-namespace-based sandbox regardless of implementation, so the verdict is unaffected by that uncertainty. |

**Auto-update, per agent (R3.5, R10.3):**

| Agent | Mechanism | Disabled how |
|---|---|---|
| claude | Background auto-updater | `DISABLE_AUTOUPDATER=1` (documented env var, set in the `claude` image stage) |
| codex | `codex update` subcommand | Not automatic — confirmed via `codex --help`: `update` is a subcommand the pod never invokes. No separate disable flag exists or is needed. |
| agy | `agy update` subcommand, **plus** a documented background self-update check "during regular runs" (the install script's own text; corroborated by `docs/records/egress-discovery.md:180`, which shows the auto-updater host contacted on every invocation in the wider discovery run, not just at install) | The explicit `update` subcommand is never invoked. The background self-update check cannot be independently disabled — no env var or flag for it was found in `agy --help` or in the binary's strings. Not exercised here: 01.2 has no egress, so the check simply fails/times out silently, which is what the offline `--version` checks above already confirm doesn't affect `agy`'s own exit behavior. This is a residual, not-fully-closed R10.3 item for 01.3 to account for in the allowlist (the host is already seeded in `docs/records/egress-discovery.md`). |

**`agy-run.sh` JSON status-field gating (R3.6, Interface Contract 5): UNVERIFIED.** The wrapper at
`images/agy/agy-run.sh` parses `.status` from `agy`'s `--output-format json` output and fails
closed (non-zero exit) on anything other than `success`/`ok`/`completed`. The exact field name and
the values `agy` actually emits for a genuine tool denial have not been observed — 01.2 has no
egress and no credentials wired (01.4). Confirm against a live, authenticated run before relying on
this in production.

## OAuth authentication endpoints — 01.4 SF-2 (R5.8, D17)

**Method.** The `oauth-interactive` login was run against the live pod under the default profile,
with the mediator enforcing the resolved policy. Per R5.8 the flow itself is the observation: no
endpoint below comes from a vendor reference page. Cross-validation per D17 is the agent's own
error output against the mediator's independent audit line for the same attempt.

**A note on method that cost a correction.** `bootstrap-auth.sh`'s exit-4 precondition check is
*itself traffic*. Every host it probes produces an `allow` audit line whether or not the login ever
touches that host, and such a line is indistinguishable from evidence that the flow required it.
The first pass probed `claude.ai` and `console.anthropic.com`, logged `allow` for both, and would
have "corroborated" two hosts the flow never contacted. The probe list is now restricted to
endpoints already known to be required, and the corroboration below comes from measured byte
counts, not from the probe's own reachability test.

### claude 2.1.260 — measured

| FQDN | Verdict | Evidence | Disposition |
|---|---|---|---|
| `platform.claude.com` | allow | Two sessions carrying 6729/2138 and 6078/1778 bytes. Before allowlisting, Claude Code failed startup with `Failed to connect to platform.claude.com: Status 403` while the mediator logged `control=allowlist, reason=host_not_allowlisted` for the same attempt | **Added.** Required — startup fails closed without it |
| `api.anthropic.com` | allow | Multiple sessions, largest 8522 in / 46307 out | Already allowlisted since 01.1 |
| `claude.ai` | — | **No audit line at all** during the completed login | **Removed.** Candidate guess; never contacted |
| `console.anthropic.com` | — | **No audit line at all** during the completed login | **Removed.** Candidate guess; never contacted |
| `mcp-proxy.anthropic.com` | deny | 6 attempts, all `host_not_allowlisted`. **The login completed successfully regardless** | **Not added.** MCP transport, no part in authentication |
| `downloads.claude.ai` | deny | 1 attempt, `host_not_allowlisted`. **The login completed successfully regardless** | **Not added.** Update path; R10.3 makes disabling auto-updaters a MUST |

**Attempted is not required.** Two hosts were contacted during the flow and refused, and the
authentication still succeeded end to end. Adding a host because the agent reached for it would
widen the boundary to cover traffic the agent demonstrably does not need in order to authenticate.
Both stay denied, with the attempt counts recorded here so a future reader sees the decision rather
than an omission.

**Note on 01.1's kit-bypass finding.** `platform.claude.com` and `downloads.claude.ai` are two of
the six Anthropic-family hosts that 01.1's sbx capture saw only through the kit's non-removable
bypass rule, and which 01.1 deliberately excluded for want of real evidence (see
`docs/records/egress-discovery.md`). That exclusion was correct on the evidence then available, and
this run supplies the missing evidence for exactly one of them: `platform.claude.com` is required,
`downloads.claude.ai` is not. The other four remain unevidenced and stay out.

### codex 0.152.1 — measured

Run as `codex login --device-auth`, which completed and reported `Successfully logged in`.

| FQDN | Verdict | Evidence | Disposition |
|---|---|---|---|
| `auth.openai.com` | allow | Four sessions, largest 15548 in / 3132 out. The device page the operator opens is `auth.openai.com/codex/device` | **Added.** Required for the device-code flow |
| `chatgpt.com` | allow | 14505 in / 773 out | Already allowlisted since 01.1 |
| `api.openai.com` | allow | 4144 in / 775 out | Already allowlisted since 01.1 |
| `platform.openai.com` | — | **No audit line at all** during the completed login | **Removed.** Candidate guess; never contacted |

**Attribution caveat, stated rather than glossed.** The precondition probe names all three of
`auth.openai.com`, `chatgpt.com` and `api.openai.com`, so the smaller `chatgpt.com` and
`api.openai.com` sessions above cannot be cleanly separated from probe traffic. No decision rests
on it — both were independently evidenced by 01.1's discovery capture and neither is added or
removed here — but the byte counts for those two rows should not be read as flow-only measurements.
`auth.openai.com`'s four sessions are unambiguous: the probe issues one request, not four.

### The callback-forward path, and why it is not the default

`codex login` **without** `--device-auth` cannot work in this pod, and the failure is structural
rather than a misconfiguration. It starts a callback server on `localhost:1455` *inside* the
container and hands the browser `redirect_uri=http://localhost:1455/auth/callback`. The operator's
browser runs on the host, where nothing is listening: the pod publishes no ports (R2.8 default-off)
and the agent networks are `internal: true`. Observed — the provider side authorized and the
browser then reported `Unable to connect to localhost:1455`, while the CLI printed *"On a remote or
headless machine? Use `codex login --device-auth` instead."*

Device code is one of the three paths R4.9 enumerates as headless and needs no published port, so
it is the default. The callback forward (`127.0.0.1:1455:1455`, fallback 1457) remains documented
and ships as a layerable fragment for operators who want it; opening a host port the headless path
does not need is the wrong default under R2.8.

**This is the cell that caught the bug.** The `claude` cell passed while the dispatcher carried the
same class of error, because Claude Code's paste-back needs no callback port. Only running the
codex cell exposed it.

## Refresh-token rotation semantics — 01.4 SF-3 (criterion 8, R4.16, R4.17)

**Method.** SF-2b's live state volumes were cloned (`sf2bd_claude-state` → `sf3_claude-state`,
`sf2bd_codex-state` → `sf3_codex-state`, plus untouched `sf3-*-pristine` restore copies), a refresh
was forced inside the pod, and the credential files were compared before and after by SHA-256 of
each token field. Cross-validation is the mediator's own audit line for the same instant, on the
same D17 terms SF-2 used: the client's file change is one source, the mediator's independent record
of the token-endpoint session is the other.

**Two projects cannot run at once, and that is the topology working.** The agent networks carry
static subnets because each listener certificate holds a matching `iPAddress` SAN, so a second
Compose project fails at network creation with `Pool overlaps with other one on this address
space`. The `sf2bd` project was brought down **without `-v`** and `sf3` brought up in its place;
`sf2bd_claude-state`, `sf2bd_codex-state` and `sf2bd_audit` survive untouched.

**No token material was read, logged or recorded.** Every value below is a 16-hex prefix of the
field's SHA-256. Expiry claims and timestamps are not secret and are quoted directly.

### Scope: question 1 measured, question 2 deliberately not (operator decision, 2026-09-07)

Criterion 8 asks two questions. Only the first is answered here, and the second is left open on
purpose rather than by omission.

- **"Does a refresh roll the refresh token?"** — **measured, both providers.**
- **"Does a refresh in one client invalidate the token held by another?"** — **not measured.** The
  only test that answers it is replaying a rotated refresh token against a live provider account.
  A provider that treats refresh-token replay as evidence of compromise may revoke the whole session
  family, and the accounts here are the operator's own rather than the throwaways edge case 16
  assumed. The operator's decision at build was to stop short of the replay. Recorded as an open
  residual against R4.17, whose register text — "per-session refresh-token revocation is unverified
  for all three providers" — is therefore **narrowed but not closed** by this sub-feature.

### Result

| Provider | Client | Refresh rolls the refresh token | Refresh endpoint | Audit evidence (independent source) |
|---|---|---|---|---|
| Anthropic | `claude` 2.1.260 | **Yes** | `platform.claude.com:443` | `allow`, 6728 in / 2119 out at `21:32:58.593Z`, between the forced expiry and the first `api.anthropic.com` call |
| OpenAI | `codex` 0.152.1 | **Yes** | `auth.openai.com:443` | `allow`, 12492 in / 2168 out at `21:35:58.105Z`, immediately after the poke |
| Google | `agy` | **N/A** | — | `apikey` is `agy`'s only offered cell (D9); no OAuth credential and therefore no refresh token exists to roll |

Neither refresh endpoint required an allowlist change: `platform.claude.com` and `auth.openai.com`
were both added by SF-2 off the *login* flow, and this run is the first evidence that the same two
hosts carry the *refresh* flow. That the sets coincide was not guaranteed and is now measured.

**Token-field hashes (SHA-256, first 16 hex).**

| Field | Before | After | Changed |
|---|---|---|---|
| claude `accessToken` | `ac01f846cfc29ddc` | `841efe8f316a6ffe` | yes |
| claude `refreshToken` | `54fc0caebd6139c6` | `d087cad4c709bc1e` | **yes — rolls** |
| codex `tokens.access_token` | `97e60e29ca8f8cb9` | `b81a38b97d280bf3` | yes |
| codex `tokens.refresh_token` | `a99a5ca5a9d70c58` | `ae0afef4e42b1459` | **yes — rolls** |
| codex `tokens.id_token` | `2f410848d499e98c` | `e1bca6c0bee7e62e` | yes |

### Measured lifetimes (for the credential inventory's "stated lifetime" column)

| Credential | Lifetime | Source |
|---|---|---|
| claude access token | **8 h** | `expiresAt − issue` = 28 800 601 ms on the token this run minted |
| claude refresh token | **~28 days from the original login, not sliding** | `refreshTokenExpiresAt` was `1791253704285` before the refresh and `1791253703601` after — the same absolute instant. A refresh mints a new refresh token but does **not** extend the family's expiry |
| codex access token | **10 days** | JWT `exp − iat` = 864 000 s, on both the pre- and post-refresh token |
| codex `id_token` | **1 h** | JWT `exp − iat` = 3600 s |
| codex refresh token | **not stated** | `auth.json` carries no expiry field for it and the value is opaque |

The claude finding is the load-bearing one: refreshing does not buy more time. A container that
refreshes every 8 h for a month still loses the session ~28 days after the operator's original
login, which is the outer bound on how long a stolen volume stays useful without a further
compromise.

### How each refresh was forced, including what did not work

**claude — one lever, and it is client-side.** `expiresAt` in `.credentials.json` is the client's
own record of expiry. Backdating it by an hour and running `claude -p` produced the refresh. No
token material was touched.

**codex — three levers tried, one worked.** Recorded because the two negatives are findings about
0.152.1, not failed attempts:

| Lever | Result |
|---|---|
| `last_refresh` backdated 60 days | **Inert.** `codex login status` is local-only and produced no egress at all; a full `codex exec` then ran a complete `chatgpt.com` API session with no `auth.openai.com` line and no token change |
| `id_token` `exp` claim backdated | **Inert.** `codex exec` again completed with no refresh |
| `access_token` `exp` claim backdated | **Triggered the refresh** |

Two consequences worth carrying forward:

1. **The refresh trigger is the access token's own `exp`, so codex refreshes roughly every 10 days**
   under continuous use — not per session and not on the `last_refresh` interval the field name
   suggests. The field is written by a refresh; it does not appear to drive one.
2. **codex does not verify the access token's signature locally.** A token whose payload was
   re-encoded with a past `exp` — leaving the original signature in place and therefore invalid —
   was accepted as parseable and drove the expiry decision. This is unsurprising for a client
   holding a bearer token it cannot validate anyway, and it is what made the measurement possible in
   a build session rather than in ten days. It is recorded as an observation, not as a defect: a
   refresh request carries the refresh token, not the access token, so the tampered value should not
   have left the container. That last clause is reasoning about the grant type, **not** an
   observation — the audit log is tunnel-level and cannot see request bodies.

**A harness note, so the next reader does not chase it.** The final `codex exec` appeared to hang
for minutes. It was waiting on stdin EOF (`Reading additional input from stdin...`) because the
invocation had been backgrounded, not stalled on the network. The refresh had already completed at
startup, 12 s in.

### Consequence for SF-4 and `oauth-mount`

`codex` is the only agent with an `oauth-mount` cell, and codex rolls. So the container's first
refresh mints a new refresh token onto the state volume and leaves the operator's host
`~/.codex/auth.json` holding the **previous** one.

Stated precisely, because the difference matters and one half of it is unmeasured:

- **Measured:** after the container refreshes, the host copy is *superseded* — it is no longer the
  current refresh token for that session family.
- **Not measured:** whether the provider *rejects* the superseded token when the host CLI next
  presents it. One-time-use rotation is the common OAuth implementation and would mean rejection,
  but that is an expectation, not this run's evidence.

**The conservative reading is the one SF-4 must build against:** treat `oauth-mount` as a one-shot
bootstrap that costs the operator their host codex login, and record it in R4.17's
`accepted_risk.rotation` field on that basis. Being wrong in this direction costs a documented
re-login that was not strictly necessary; being wrong in the other direction breaks the operator's
host CLI without warning.

**The cost is deferred, not immediate.** Because the trigger is the 10-day access-token expiry, a
container bootstrapped from the host credential can run for up to ten days before its first refresh.
An operator who bootstraps and then stops using the pod may never pay the cost at all.

**Where the value lands.** SF-3 produces this result; it does not write it into `profiles/`. The
`rotation:` field in the feature plan's Interface Contract 3 profile schema and R4.17's
`accepted_risk.rotation` are both written by SF-4, which consumes the row above.

## Refresh-token replay — 01.4 SF-5 (criterion 8's second question, measured)

**SF-3 left this open on purpose; SF-5's acceptance harness answered it as a side effect of
running twice, and the answer is the less comfortable one.**

SF-3 measured that both providers *roll* the refresh token, and deliberately did not measure
whether a refresh in one client invalidates the token another client holds — the only test being
to replay a superseded refresh token against the operator's live account, which risks the provider
revoking the whole session family (Deviation 3 on the 01.4 feature plan). That replay then happened
without being planned as one: `tests/acceptance/verify-auth-state.sh` phase D stages a **copy** of
the seed volume's credential and forces a refresh, and the harness was run twice from the same
unchanged seed.

### Result — OpenAI / `codex` 0.152.1: a superseded refresh token still works

| Run | Parent refresh token staged | Refresh outcome | Child refresh token minted |
|---|---|---|---|
| 2 (2026-09-07) | `51ffa14430f309a6` | **succeeded** | `f0952196e402fac2` |
| 3 (2026-09-07, minutes later) | `51ffa14430f309a6` — **the same, now superseded, parent** | **succeeded** | `1ffe309a0f5ee23a` |

Both runs began from the byte-identical staged source (`c83f0763a44f7428`, asserted unchanged by
the `:ro` mount in both runs). Run 3 presented a refresh token that run 2 had already spent, and
the provider honoured it, minting a *second, different* child.

**What this measures:** for OpenAI, the refresh token is **not one-time-use**, and a refresh in one
client does **not** invalidate the copy another client holds — over a window of minutes, from a
second client instance, on the same account.

**What it does not measure**, stated so the claim is not read wider than the evidence:

- **Claude was not replayed.** This says nothing about Anthropic, whose refresh token also rolls.
- **The window was minutes, not days.** A provider that expires superseded tokens on a delay, or
  on a later heuristic, would look exactly like this at this timescale.
- **Both clients were the same `codex` build on the same account.** A genuinely different client
  or a different account may be treated differently.

### Consequence, and it cuts both ways

**Operationally cheaper than assumed.** SF-4 wrote `accepted_risk.rotation` on the conservative
reading — treat `oauth-mount` as a one-shot bootstrap that *costs the operator their host
`codex login`*. Measured, it does not: the host copy is superseded but still redeemable, so the
host CLI keeps working. That text is corrected in `profiles/oauth-mount.yaml` rather than left
standing, because a record that is now known to be wrong is worse than no record.

**Security consequence is the reverse, and it is the load-bearing half.** Rotation is not a
revocation mechanism here. A refresh token captured from a state volume stays valid after the
legitimate client has refreshed past it, so "the volume was copied a while ago" is not mitigation
and nothing about normal use retires the stolen copy. Explicit revocation at the provider — the
`revocation_path` field, not rotation — is the only control that ends it. Row V3 of
`docs/records/credential-inventory.md` states this in its blast-radius column.

**R4.17 is now closed for OpenAI and still open for Anthropic**, rather than open for both.
