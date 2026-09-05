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
