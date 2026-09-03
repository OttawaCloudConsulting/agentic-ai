# Research Findings — Agent Containerization

Evidence base for [`OPTIONS_ANALYSIS.md`](OPTIONS_ANALYSIS.md). Verified 2026-09-02 against vendor documentation and source repositories.

Claims that could not be confirmed are marked **UNVERIFIED**. Version-pinned facts in this space go stale within weeks — re-check before building.

## Contents

- [Host Platform](#host-platform)
- [Claude Code](#claude-code)
- [OpenAI Codex](#openai-codex)
- [Google Antigravity (`agy`)](#google-antigravity-agy)
- [Egress Filtering Building Blocks](#egress-filtering-building-blocks)
- [Prior Art](#prior-art)
- [Unverified Items](#unverified-items)
- [Sources](#sources)

## Host Platform

Measured on the development machine, 2026-09-02:

| Fact | Value | Consequence |
|---|---|---|
| OS | macOS 26.6.1 (build 25G76) | Apple `container` CLI is viable (macOS 26 required for container-to-container networking) |
| Architecture | arm64 (Apple silicon) | `sbx` microVMs supported; Arm Linux guests |
| Docker Engine | 28.3.2 | Compose-based Option 2 is available today |
| Docker Desktop | 4.43.2 | Irrelevant to `sbx`, which is standalone |
| `sbx` | Not installed | `brew install` required |
| Apple `container` CLI | Not installed | Required for Option 3 on this host |
| Claude Code credentials | macOS **Keychain** — no `~/.claude/.credentials.json` | Host credentials are not portable into a Linux container |
| Codex credentials | `~/.codex/auth.json` present (4 KB) | Mountable, but see the size note below |
| `~/.codex` size | 1.5 GB | Do not bind-mount the host directory; use a fresh volume |
| Antigravity state | No `~/.antigravity` or `~/.config/Antigravity` | Not installed on this host |

Docker Desktop on macOS uses VirtioFS and fakes file ownership so reads and writes succeed regardless of the container UID. `chown` from inside a bind mount is a no-op on the host. Read-only (`:ro`) mounts are enforced correctly.

## Claude Code

Version at time of research: `@anthropic-ai/claude-code` **2.1.258** (npm, 2026-09-01).

### Reference devcontainer

`anthropics/claude-code/.devcontainer/` — `Dockerfile`, `devcontainer.json`, `init-firewall.sh`. Anthropic describes it as "a working example rather than a maintained base image." Last commit touching it: 2026-06-30.

- Base `node:20`, non-root user `node`, workdir `/workspace`.
- Installs `iptables ipset iproute2 dnsutils aggregate jq` — exactly what the firewall script needs.
- `runArgs: ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW"]`. No `--privileged`.
- Sudoers drop-in permits only `node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh`.
- Named volumes: `/commandhistory` and `/home/node/.claude`, with `CLAUDE_CONFIG_DIR=/home/node/.claude`.
- `postStartCommand: sudo /usr/local/bin/init-firewall.sh`, with `waitFor: postStartCommand`.

`init-firewall.sh` mechanism: saves and restores Docker's DNS NAT rules, creates an `allowed-domains` ipset (`hash:net`), pulls GitHub CIDRs from `api.github.com/meta` (`.web + .api + .git`, aggregated), resolves a hardcoded domain list with `dig +noall +answer A`, sets `INPUT/FORWARD/OUTPUT` policy to `DROP`, accepts `ESTABLISHED,RELATED` and the ipset, then `REJECT`s the remainder with `icmp-admin-prohibited` (REJECT rather than DROP, so failures are visible). It self-verifies: the container fails if `example.com` is reachable or `api.github.com/zen` is not.

**Known gaps in the reference firewall:**

- **DNS is unfiltered.** UDP/53 is permitted to any destination — issue #36907. DNS tunnelling bypasses the IP allowlist entirely.
- **IPv4 only.** GitHub IPv6 CIDRs fail the script's regex and cause `exit 1`. AAAA records are never resolved.
- **The allowlist is stale.** It permits `sentry.io` and `statsig.com` (retired — `statsig/` is now an explicitly legacy directory) and omits `claude.ai`, `platform.claude.com`, `downloads.claude.ai`, `mcp-proxy.anthropic.com`, `raw.githubusercontent.com`, and `code.claude.com`. Current telemetry lands on two Datadog intake hosts that the script does not allow.
- OAuth sign-in and token refresh require `claude.ai` and `platform.claude.com`, neither of which is allowlisted. The domain absence is verified; the breakage is inference — **UNVERIFIED** as an observed failure.
- The devcontainer *Feature* installs its own `/usr/local/bin/init-firewall.sh` and silently overwrites a custom one (issue #32113). Name any custom script differently.
- Anthropic's own warning: with `--dangerously-skip-permissions`, the devcontainer "does not prevent a malicious project from exfiltrating anything accessible inside the container, including the Claude Code credentials stored in `~/.claude`."

### Native sandboxing

Two distinct mechanisms — do not conflate them.

**(a) Built-in sandboxed Bash tool** — `sandbox.*` in `settings.json`.

- Scope is **only Bash commands and their children**. Read, Edit, WebFetch, MCP servers and hooks run unconstrained.
- macOS uses Seatbelt (built in). Linux/WSL2 requires `bubblewrap` and `socat`. Native Windows is unsupported.
- Network keys: `sandbox.network.{allowedDomains,deniedDomains,strictAllowlist,allowManagedDomainsOnly,allowLocalBinding,tlsTerminate,httpProxyPort,socksProxyPort}`. Enforced by a proxy running **outside** the sandbox; hostname-based; does not terminate TLS by default. Default is no domains pre-allowed, prompting on first use; `strictAllowlist: true` denies instead of prompting.
- Filesystem keys: `sandbox.filesystem.{disabled,allowRead,denyRead,allowWrite,denyWrite,allowManagedReadPathsOnly}`. Read is deny-then-allow; write is allow-only with deny winning.
- `permissions.deny` / `permissions.allow` entries of the form `WebFetch(domain:example.com)` gate the in-process WebFetch tool and feed the sandbox domain lists. Only leading `*.` and bare `*` wildcards are honoured.
- **Inside an unprivileged container**, bubblewrap cannot mount a fresh `/proc` (`bwrap: Can't mount proc on /newroot/proc`). The workaround is `sandbox.enableWeakerNestedSandbox: true`, which Anthropic states "considerably weakens security." `docker` commands are incompatible — add them to `sandbox.excludedCommands`.
- Organisation enforcement via `/etc/claude-code/managed-settings.json` on Linux.

**(b) `@anthropic-ai/sandbox-runtime` (`srt`)** — v0.0.75 (2026-09-01), Apache-2.0, ~5.1k stars, very active. Labelled "Beta Research Preview."

- Constrains **every tool, hook and MCP server** in the session, not just Bash. No container required.
- Launch: `npx @anthropic-ai/sandbox-runtime claude` or `srt <command>`.
- Config at `~/.srt-settings.json` (note: *not* under `~/.claude`). Network default is deny-all. On Linux the network namespace is removed entirely and proxies are reached over bind-mounted Unix sockets via `socat`.
- Hard-coded protections regardless of config: `denyWrite` beats `allowWrite`; `.git/hooks`, `.git/config`, `.mcp.json`, `.claude/commands`, `.claude/agents` and shell startup files are denied at the project root.
- **Failure mode worth knowing:** without a valid `~/.srt-settings.json` it starts anyway with network blocked and writes confined to a small default set. A clean start is not proof your settings loaded. Passing `--settings` explicitly makes it refuse to start on a load failure.
- On Linux, write grants apply only to paths that already exist — pre-create them (`mkdir -p ~/.claude && echo '{}' > ~/.claude.json`).

### Permission bypass

- Claude Code **refuses to start with `--dangerously-skip-permissions` as root** on Linux and macOS. The container must run as a non-root user.
- Anthropic's guidance is to use the flag only inside a container, VM, or `srt`; the Bash sandbox alone is insufficient for unattended runs because MCP servers, hooks and file tools sit outside it.
- Can be blocked organisation-wide with `permissions.disableBypassPermissionsMode: "disable"` in managed settings.

### State and auth paths

- `CLAUDE_CONFIG_DIR` overrides `~/.claude`. All settings, session history and plugins live under it.
- **`~/.claude.json` is a separate file outside `~/.claude`** — it holds app state, the OAuth account, personal MCP servers, and per-project trust. Mounting a volume at `~/.claude` alone does not keep you signed in. Setting `CLAUDE_CONFIG_DIR` to the volume path makes Claude Code write `.claude.json` inside the volume.
- Credentials: macOS Keychain (falling back to `~/.claude/.credentials.json` mode 0600 when the Keychain is locked, common over SSH); Linux `~/.claude/.credentials.json` mode 0600. With `CLAUDE_CONFIG_DIR` set, the file lives under that directory and the macOS Keychain entry is keyed to it.
- Runtime data under the config dir includes `projects/<project>/<session>.jsonl` (full transcripts, plaintext), `history.jsonl`, `file-history/`, `plans/`, `shell-snapshots/`. Retention via `cleanupPeriodDays` (default 30).
- Minimum to mount for a Linux container to persist login: the single directory `$CLAUDE_CONFIG_DIR`.

Headless authentication, three paths:

1. Browser flow with paste-code fallback — the browser displays a code to paste back when the localhost callback cannot reach the container.
2. `claude setup-token` → prints a **one-year OAuth token**, exported as `CLAUDE_CODE_OAUTH_TOKEN`. Requires Pro/Max/Team/Enterprise. Model requests only. Not read in `--bare` mode.
3. `ANTHROPIC_API_KEY`, or `ANTHROPIC_AUTH_TOKEN`, or an `apiKeyHelper` script.

Auth precedence, highest first: cloud provider vars (`CLAUDE_CODE_USE_BEDROCK` / `_VERTEX` / `_FOUNDRY`) → `ANTHROPIC_AUTH_TOKEN` → `ANTHROPIC_API_KEY` → `apiKeyHelper` → `CLAUDE_CODE_OAUTH_TOKEN` → subscription OAuth.

### Proxy and TLS

- `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY`. **SOCKS proxies are not supported.** Basic auth supported in the URL.
- `NODE_EXTRA_CA_CERTS` for a custom CA. `CLAUDE_CODE_CERT_STORE=bundled,system` selects trust sources. mTLS via `CLAUDE_CODE_CLIENT_CERT` / `_KEY` / `_KEY_PASSPHRASE`.
- Important for background agents in containers: set these in the `env` block of `settings.json` or managed settings, **not** as a shell export — the background-agent supervisor is one shared process that may inherit no shell environment.
- Egress reduction: `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` (also disables Remote Control), `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, `DISABLE_AUTOUPDATER=1`. `skipWebFetchPreflight: true` in settings is the only way to stop WebFetch calling `api.anthropic.com`.

### Required egress domains

| Domain | Purpose |
|---|---|
| `api.anthropic.com` | Model requests, WebFetch domain safety check, feature flags |
| `claude.ai` | claude.ai account authentication |
| `claude.com` | Sign-in redirect; pre-approved WebFetch docs lookups |
| `platform.claude.com` | Console auth, and OAuth token exchange/refresh/revocation |
| `mcp-proxy.anthropic.com` | claude.ai MCP connectors (on by default for claude.ai accounts) |
| `downloads.claude.ai` | Plugin executables, native installer, version checks |
| `storage.googleapis.com` | Plugin metadata |
| `registry.npmjs.org` | CLI install, plugin installs, `npx` MCP servers |
| `raw.githubusercontent.com` | Changelog for `/release-notes` |
| `code.claude.com` | Docs lookups by the built-in guide agent |
| `bridge.claudeusercontent.com`, `*.frame.claudeusercontent.com` | Claude in Chrome bridge; Artifact reads |
| `http-intake.logs.us5.datadoghq.com`, `browser-intake-us5-datadoghq.com` | Telemetry and error reports — optional, safe to block |

On Bedrock/Vertex/Foundry, telemetry and error reporting default off and model traffic goes to the provider — but the WebFetch preflight still reaches `api.anthropic.com`.

## OpenAI Codex

Version at time of research: **0.152.1** (npm `latest`, 2026-09-01; GitHub tag `rust-v0.152.1`).

### Runtime shape

- **Written in Rust.** The npm package is a thin Node shim over a vendored binary; the real artifact is a ~217 MB platform binary.
- Install: `npm i -g @openai/codex`; `brew install --cask codex` (**cask, not formula**); `curl -fsSL https://chatgpt.com/codex/install.sh | sh`; or direct binaries.
- **For containers:** `codex-{x86_64,aarch64}-unknown-linux-musl.tar.gz` — static musl, ideal for distroless or Alpine. Rename the archive entry to `codex`.
- Releases also ship `bwrap-*-unknown-linux-musl.tar.gz` — Codex bundles its own bubblewrap.

### Sandbox model

- Modes: `read-only` | `workspace-write` (default) | `danger-full-access`, via `-s/--sandbox`.
- macOS uses Seatbelt via `/usr/bin/sandbox-exec`.
- **Linux uses bubblewrap + seccomp, not Landlock.** This is the biggest change versus most published guidance. Landlock survives only as a deprecated opt-in (`features.use_legacy_landlock = true`), marked "deprecated and will be removed soon."
- `--no-proc` exists specifically for restrictive container environments (skips mounting a fresh `/proc`).
- Injects `CODEX_SANDBOX=seatbelt` and `CODEX_SANDBOX_NETWORK_DISABLED=1` into sandboxed children — useful for detection in your own scripts.
- **`--full-auto` has been removed** in 0.152.1. Current equivalents are `-s workspace-write -a never` or `--approve-for-me`. Most published guidance is stale on this point.

**Running inside a container** — OpenAI documents the pattern directly:

> "When running Linux in a containerized environment such as Docker, the sandbox may not work if the host or container configuration blocks the namespace, setuid `bwrap`, or `seccomp` operations that Codex needs. In that case, configure your Docker container to provide the isolation you need, then run `codex` with `--sandbox danger-full-access` (or the `--dangerously-bypass-approvals-and-sandbox` flag) inside the container."

Nesting *is* possible — OpenAI's own `Dockerfile.secure` makes the inner sandbox work by installing bubblewrap, setting `chmod u+s /usr/bin/bwrap`, and running with `--cap-add=SYS_ADMIN --cap-add=SYS_CHROOT --cap-add=SETUID --cap-add=SETGID --cap-add=SYS_PTRACE --security-opt=seccomp=unconfined --security-opt=apparmor=unconfined`.

**Trade-off to weigh:** that relaxes Docker's outer sandbox in order to enable Codex's inner one. `seccomp=unconfined` plus `SYS_ADMIN` materially weakens container isolation. Choosing `danger-full-access` inside a *hardened* container is often the stronger overall posture.

### Network configuration

Legacy switch, still supported:

```toml
sandbox_mode = "workspace-write"
[sandbox_workspace_write]
network_access = true          # default: false
```

Note, stated in-repo: `--ask-for-approval never` does **not** by itself enable network access.

Built-in policy proxy — the notable capability for this project:

```toml
[features.network_proxy]
enabled = true
domains = { "api.openai.com" = "allow", "example.com" = "deny" }
```

- Local HTTP proxy on `127.0.0.1:3128`, SOCKS5 on `127.0.0.1:8081`.
- Allowlist-first, exact hosts plus `*.example.com` / `**.example.com` scoped wildcards. A global `*` is **rejected**. **Deny overrides allow.**
- Blocks return HTTP 403 with `x-proxy-error: blocked-by-allowlist | blocked-by-denylist | blocked-by-method-policy | blocked-by-policy`.
- `mode = "limited"` restricts to GET/HEAD/OPTIONS. `allow_local_binding = false` by default — blocks loopback, link-local and private ranges, i.e. SSRF and metadata-endpoint defence.
- `allow_upstream_proxy = true` makes the managed proxy respect `HTTP(S)_PROXY` / `ALL_PROXY` for its own upstream hops.
- MITM hooks can strip or inject headers per host, method and path.

### Proxy and TLS

- Respects `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY` and lowercase variants.
- `respect_system_proxy` (platform settings and PAC/WPAD first) is **off by default**.
- **Uses rustls with `rustls-tls-native-roots`** — it *does* load the OS trust store. The usual "Rust binary ignores the system CA store" concern does not apply.
- Explicit custom-CA path: `CODEX_CA_CERTIFICATE`, falling back to `SSL_CERT_FILE`. Fails fast with a precise error rather than silently falling back.
- `NODE_EXTRA_CA_CERTS` is not read by Codex itself; it is one of the variables Codex *injects into spawned children* when its managed proxy is doing MITM (alongside `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`, `GIT_SSL_CAINFO`, `CARGO_HTTP_CAINFO`, `PIP_CERT`, `BUNDLE_SSL_CA_CERT`).

### State and auth paths

All under `CODEX_HOME` (default `~/.codex/`). The variable is honoured — verified by running `CODEX_HOME=/tmp/fakehome codex login status` on a logged-in machine, which returned "Not logged in".

| Path | Purpose | Mount? |
|---|---|---|
| `$CODEX_HOME/auth.json` | Credentials — `auth_mode`, API key, OAuth tokens | **Required** |
| `$CODEX_HOME/config.toml` | Main config | Required |
| `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-*.jsonl` | Session rollouts | For `codex resume` |
| `$CODEX_HOME/history.jsonl` | Prompt history | Optional |
| `$CODEX_HOME/proxy/` | Managed-proxy CA bundle | Only with MITM proxy |

- **Credential store defaults to `file`** (`cli_auth_credentials_store = "file" | "keyring" | "auto"`). In containers, leave it at `file` or set it explicitly — `keyring` will hard-fail with no D-Bus or Secret Service.
- Headless login: `printenv OPENAI_API_KEY | codex login --with-api-key` (reads from **stdin**, not argv); `codex login --device-auth`; bare `OPENAI_API_KEY`; SSH-forward the callback (`ssh -L 1455:localhost:1455`); or copy `auth.json` from a trusted machine.
- OAuth callback: issuer `https://auth.openai.com`, default port **1455**, fallback 1457, redirect `http://localhost:1455/auth/callback`.
- Refresh tokens are long-lived — treat the volume as a secret. `codex exec --ephemeral` runs without persisting session files, which suits CI.

### Official containers and headless mode

- **No official Docker image of the Codex CLI.** `ghcr.io/openai/codex-universal` is the Codex *Cloud* base image and **does not contain the CLI**.
- The maintained pattern is `openai/codex/.devcontainer/` — `devcontainer.secure.json`, `Dockerfile.secure`, `init-firewall.sh`, `post-start.sh`.
- `init-firewall.sh` is a proper iptables + ipset allowlist: resolves `/etc/codex/allowed_domains.txt` via `dig`, optionally pulls GitHub meta CIDRs, sets policies to DROP, **REJECTs rather than DROPs** so failures are visible, enforces **IPv6 default-deny** so AAAA cannot bypass the allowlist, and self-verifies. Requires `--cap-add=NET_ADMIN --cap-add=NET_RAW`.
- **OpenAI's stated limitation:** "The firewall does not apply its domain allowlist to DNS traffic, so code from an untrusted repository can exfiltrate data through DNS… Use it only with trusted repositories." Exfiltration also remains possible through allowed HTTPS destinations.
- `codex-cli/scripts/run_in_container.sh` still exists but is **orphaned** — it references a locally-built image whose Dockerfile no longer exists. Useful as reference design only.
- `codex exec` is the non-interactive mode: `--json` (JSONL events), `-o/--output-last-message`, `--output-schema`, `--skip-git-repo-check`, `--ephemeral`, `--add-dir`, `-C/--cd`. Prompt can come from stdin.
- `codex-responses-api-proxy` — a strict proxy that forwards **only** `POST /v1/responses` to `api.openai.com`, injecting `Authorization` from a key read on stdin, 403ing everything else. Run it as a privileged user so the unprivileged agent process never sees the key. This is a ready-made credential-broker primitive.
- Official GitHub Action `openai/codex-action@v1` exists and is active.

### Required egress domains

| Auth mode | Domains |
|---|---|
| API key | `api.openai.com` (443, HTTPS **and WSS**) |
| ChatGPT subscription | `auth.openai.com` + `chatgpt.com` (443, HTTPS and WSS), plus loopback 1455/1457 |
| Wildcards covering both | `*.openai.com` + `*.chatgpt.com` |

Optional: `ab.chatgpt.com` (Statsig OTLP metrics, **on by default in release builds**, safe to block), `api.github.com` (version check), `registry.npmjs.org` or `formulae.brew.sh` (install-method-specific).

**WebSockets are the default transport** (`wss://chatgpt.com/backend-api/codex/responses` or `wss://api.openai.com/v1/responses`). There is an automatic HTTP/SSE fallback, so a WebSocket-blocking proxy degrades rather than hard-fails — but allow `Upgrade: websocket` on TCP/443 or you lose streaming performance.

## Google Antigravity (`agy`)

**The premise that Antigravity is GUI-only is out of date.** Since Antigravity 2.0 (Google I/O, May 2026) there are four surfaces over one shared agent harness:

| Surface | Form | GUI | Container-suitable |
|---|---|---|---|
| Antigravity 2.0 | Standalone desktop app | Yes | No |
| Antigravity IDE | Desktop app with editor | Yes | No |
| **Antigravity CLI (`agy`)** | Single Go binary, TUI + headless | No | **Yes — designed for it** |
| **Antigravity SDK** | Python (`pip install google-antigravity`) | No | **Yes** |

Google Cloud's own surface-selection guide states the CLI supports "headless execution (such as working over SSH or inside remote containers)."

Correction to a common belief: the original Nov 2025 Antigravity was a VS Code fork. **Antigravity 2.0 is not** — it is a ground-up standalone app with no built-in editor, whose primary surface is "Agent Manager."

### Headless mode

Install: `curl -fsSL https://antigravity.google/cli/install.sh | bash` → binary at `~/.local/bin/agy`. Flags `--skip-aliases`, `--skip-path` for non-interactive installs.

- `agy -p "prompt"` — single-shot, streams to stdout, diagnostics to stderr.
- `--output-format text | json | stream-json`. The JSON envelope carries `conversation_id`, `status`, `response`, `duration_seconds`, `num_turns`, `usage`, `error`. `stream-json` emits NDJSON `init` / `step_update` / `result`.
- `--json-schema '{...}'` for constrained structured output.
- Multi-turn daemon mode: `agy --input-format stream-json --output-format stream-json`, feeding events on stdin.
- Session control: `--continue`, `--conversation <uuid>`. Model control: `--model`, `--effort`, `--agent`.
- `--print-timeout 15m` (default 5m). `--sandbox` restricts terminal access.
- **CI footgun:** tools requiring approval are soft-denied and the run still exits 0, with only a stderr notice. **Gate on the JSON `status` field, not the exit code.**

### State and auth

- Credentials go to the OS keyring via Secret Service / libsecret (GNOME Keyring, KWallet). **This is the main headless blocker in containers.** Official troubleshooting advises ensuring the keyring daemon runs and `export $(dbus-launch)`.
- The OAuth token also lands as a plain file at `~/.gemini/antigravity-cli/antigravity-oauth-token`. Several early write-ups claim `~/.config/agy/credentials.json` — that is wrong.
- Settings at `~/.gemini/antigravity-cli/settings.json`. MCP config, saved conversations and workflows also live under `~/.gemini`. **`~/.gemini` is the high-value path to mount.**

Auth options, ranked for containers:

1. **Gemini API key** — set `"modelProvider": "gemini"` in settings **and** `export GEMINI_API_KEY=...`. Documented as suiting "headless and CI runs, where no browser is available." **Gotcha the docs call out: setting `GEMINI_API_KEY` alone has no effect — the `modelProvider` key is mandatory.** Note this routes to the public Gemini API on your own billing, not the Antigravity account quota.
2. **SDK with Vertex AI ADC / service account** — `GOOGLE_GENAI_USE_VERTEXAI`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`. The cleanest fully non-interactive path, and what the maintainer recommends for CI.
3. **SSH flow** — `agy` detects remote sessions and prints a copy-paste authorization URL and code. Workable for one-time container bootstrap.
4. **Antigravity-account token via environment variable: not supported.** Issue #632 (open) requests it; container runs fail with "authentication required. Run 'agy' to log in, then retry."

**Conflict flagged:** a maintainer stated in June 2026 that Gemini API keys were not supported, which contradicts the current official install page. The docs most likely reflect a post-June addition, but treat option 1 as **UNVERIFIED** until tested on the pinned version. Blog posts variously claim `AV_API_KEY`, `ANTIGRAVITY_API_KEY`, `AGY_API_KEY` — all **UNVERIFIED**; only `GEMINI_API_KEY` appears in official documentation.

### Egress domains

- `daily-cloudcode-pa.sandbox.googleapis.com` — Antigravity's actual backend.
- **Antigravity does not use `generativelanguage.googleapis.com`** in account-auth mode; that host is relevant only in Gemini-API-key mode.
- `aiplatform.googleapis.com` — required for enterprise/project endpoints.
- `github.com` and `githubusercontent.com` — required for extensions.
- Full allowlist is **not published by Google** — **UNVERIFIED**; plan to capture traffic.
- `HTTPS_PROXY` support is **UNVERIFIED** — not in official documentation. Corporate-proxy failures are reported as ETIMEDOUT / 407 / 403 plus SSL-inspection certificate failures.

### GUI-in-container, if ever required

Viable but ugly. Community images (`mirusser/antigravity-docker`, `rawritude/antigravity-remote-docker`) use TigerVNC/noVNC and all report the same friction: `seccomp:unconfined` is required because Chromium needs namespace operations that Docker's default seccomp profile blocks; `shm_size: 2gb` and `--disable-dev-shm-usage` are needed or Google auth popups fail; launch must go through `dbus-run-session`. No hardware acceleration, and the container is materially less locked down than the default. **Not recommended** — it trades away the sandbox to run an interface an agent cannot use.

### Deprecation note

`gemini-cli` was shut down for Free/Pro/Ultra on **2026-06-18** with no grace period; the command returns HTTP 410. Gemini Code Assist IDE extensions were deprecated alongside it. Exception: Gemini Code Assist Standard/Enterprise licensees retain access. `agy` is the official replacement.

### Terms of Service

Section 6 of the Antigravity Additional Terms: "You must not abuse, harm, interfere with, or disrupt the Service. This includes, but is not limited to, using the Service in connection with products not provided by us," and "Using third party software, tools, or services to access the Service … is a breach of this Agreement."

This is actively enforced — Google has suspended paid subscribers, including AI Ultra, without warning for using third-party tools and proxies against Antigravity OAuth. Nothing in the terms prohibits containers, servers, or headless use per se; the prohibition targets third-party clients and proxies wrapping Antigravity credentials. **That reading is an interpretation, not an official position** — Google staff declined to clarify the boundary on the developer forum. See the warning section in [`OPTIONS_ANALYSIS.md`](OPTIONS_ANALYSIS.md).

## Egress Filtering Building Blocks

| Tool | Model | Notes |
|---|---|---|
| **Docker Sandboxes (`sbx`)** | Managed proxy + microVM | Domains, wildcards, IPs, CIDRs, ports. Deny beats allow. UDP/ICMP blocked at the network layer and not unblockable by policy. Presets `open` / `balanced` / `locked-down`. Closed-source CLI. |
| **iron-proxy** (Go, Apache-2.0) | MITM egress proxy with built-in DNS | Default-deny; glob domain allowlist plus CIDR; **upstream IP denylist applied after resolution** — refuses even an allowlisted domain if the resolved IP is in a blocked range. Metadata and loopback blocked by default. Three wiring modes: DNS-based, DNS + nftables, TPROXY. |
| **Squid (CONNECT allowlist)** | SNI peek-and-splice | Validates the destination at CONNECT before the TLS handshake — no decryption, so no CA distribution. Domain granularity only. Well-understood; `ssl::server_name` ACL. |
| **`iptables` + `ipset`** (vendor reference) | IP allowlist inside the container | Requires `NET_ADMIN`/`NET_RAW` **inside the blast radius**. IP-snapshot semantics break on CDN rotation. Does not filter DNS. Use REJECT not DROP so failures surface. |
| **Codex `features.network_proxy`** | Per-agent local policy proxy | Domains allow/deny, deny wins, private ranges blocked by default. Defence in depth, not a boundary. |
| **Claude Code `sandbox.network.*` / `srt`** | Per-agent proxy outside the sandbox | `allowedDomains` / `deniedDomains` / `strictAllowlist`. Defence in depth, not a boundary. |

Two structural points that recur across all of the above:

- **FQDN rules only work at Layer 7.** An IP-based firewall resolves names once and stores the result; CDN rotation, round-robin DNS and rebinding all defeat it. Only a CONNECT/SNI-aware proxy evaluates the hostname per connection.
- **DNS must be owned, not filtered.** The reliable fix is to give the agent no route to port 53 at all and serve DNS from the enforcement point. Filtering UDP/53 by destination does not stop tunnelling.

## Prior Art

Active and worth reading:

| Project | What it is | Status |
|---|---|---|
| `anthropics/sandbox-runtime` | OS-level process sandbox plus host proxy; no container | Active, v0.0.75, ~5.1k stars |
| `trailofbits/claude-code-devcontainer` | Hardened devcontainer for bypass-permissions work, optional iptables/ipset allowlist, aimed at reviewing untrusted code | Active 2026-08-28, ~933 stars. Best-maintained hardened devcontainer found |
| `docker/sbx` | Per-sandbox microVM with its own Docker daemon | Active, referenced from Anthropic's own sandbox docs |
| `ironsh/iron-proxy` | Egress firewall for untrusted workloads | Active, ~645 stars |
| `imbue-ai/sculptor` | Parallel Claude Code agents in isolated worktrees | Active 2026-09-01 |
| `openai/codex-action` | Official Action wiring the CLI to a secure Responses API proxy | Active, ~1.2k stars |

Stale or dead — do not build on these:

| Project | Status |
|---|---|
| `anthropics/devcontainer-features` | `main` last touched 2025-06-25 |
| `textcortex/claude-code-sandbox` | Archived 2026-02-20; successor is `textcortex/spritz` |
| `RchGrav/claudebox` | Last commit 2025-08-31 despite ~1.1k stars |
| `VishalJ99/claude-docker` | Last commit 2026-02-06 |
| `dagger/container-use` | ~4k stars but only 8 commits since March 2026; self-labelled experimental |
| `codex-cli/scripts/run_in_container.sh` | Orphaned in-repo; references a deleted Dockerfile |

**Trend worth noting:** the 2025 cohort of agent-specific Docker wrappers is largely dead. Anthropic's investment shifted from the devcontainer to the container-free `sandbox-runtime`, and Docker entered directly with microVM `sbx`. Building on a third-party wrapper is a maintenance liability; building on vendor primitives plus your own compose file is not.

## Unverified Items

Carried forward deliberately — do not treat these as established:

- Whether Anthropic's reference firewall actually breaks interactive OAuth. The domain absence is verified; the consequence is inference.
- Whether `agy` honours `HTTPS_PROXY`, and its CA-trust mechanism.
- Whether `agy` currently accepts `GEMINI_API_KEY` — official docs and a June 2026 maintainer statement conflict.
- Any Antigravity environment variable other than `GEMINI_API_KEY` (`AV_API_KEY`, `ANTIGRAVITY_API_KEY`, `AGY_API_KEY` all appear in blogs, none in official docs).
- The complete Antigravity egress allowlist — not published by Google.
- Whether Claude Code's container login is a true RFC 8628 device-code grant or a browser paste-back code.
- `IS_SANDBOX` and `CLAUDE_CODE_DONT_INHERIT_ENV` — absent from the current environment-variable reference; do not rely on them.
- Whether `api.openai.com` is contacted at all in Codex ChatGPT-subscription mode.
- Docker Sandboxes' credential-persistence mechanism — not documented at the level needed to design against.
- Exact per-version Antigravity Linux packaging (the download page lists .deb/.rpm/.tar.gz; community reports say tarball-only for some builds).

## Sources

### Claude Code

- [Devcontainer reference](https://code.claude.com/docs/en/devcontainer) · [Sandbox environments](https://code.claude.com/docs/en/sandbox-environments) · [Sandboxing](https://code.claude.com/docs/en/sandboxing) · [Settings reference](https://code.claude.com/docs/en/settings-reference#sandbox-settings)
- [Authentication](https://code.claude.com/docs/en/authentication) · [The .claude directory](https://code.claude.com/docs/en/claude-directory) · [Environment variables](https://code.claude.com/docs/en/env-vars) · [Network configuration](https://code.claude.com/docs/en/network-config) · [Permissions](https://code.claude.com/docs/en/permissions)
- [`init-firewall.sh`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh) · [`Dockerfile`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile) · [`devcontainer.json`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/devcontainer.json)
- [`anthropics/sandbox-runtime`](https://github.com/anthropics/sandbox-runtime) · [Issue #36907 — DNS bypass](https://github.com/anthropics/claude-code/issues/36907) · [Issue #32113 — Feature overwrites firewall](https://github.com/anthropics/claude-code/issues/32113)
- [Securely deploying AI agents](https://code.claude.com/docs/en/agent-sdk/secure-deployment)

### OpenAI Codex

- [`openai/codex`](https://github.com/openai/codex) · [Linux sandbox README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md) · [Network proxy README](https://github.com/openai/codex/blob/main/codex-rs/network-proxy/README.md) · [HTTP client README](https://github.com/openai/codex/blob/main/codex-rs/http-client/README.md)
- [`.devcontainer`](https://github.com/openai/codex/tree/main/.devcontainer) · [`responses-api-proxy`](https://github.com/openai/codex/blob/main/codex-rs/responses-api-proxy/README.md) · [`openai/codex-action`](https://github.com/openai/codex-action)
- [Agent approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security) · [Sandboxing](https://learn.chatgpt.com/docs/sandboxing) · [Config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Network recommendations](https://help.openai.com/en/articles/9247338-network-recommendations-for-chatgpt-errors-on-web-and-apps)

### Google Antigravity

- [CLI headless mode](https://antigravity.google/docs/cli/headless/) · [CLI install and auth](https://antigravity.google/docs/cli/install/) · [CLI troubleshooting](https://antigravity.google/docs/cli/troubleshooting/) · [SDK overview](https://antigravity.google/docs/sdk/overview/) · [Enterprise docs](https://antigravity.google/docs/enterprise/)
- [Additional Terms of Service](https://antigravity.google/terms/) · [Linux download](https://antigravity.google/download/linux/)
- [Choosing your surface — Google Cloud Blog](https://cloud.google.com/blog/topics/developers-practitioners/choosing-your-surface-antigravity-20-antigravity-cli-antigravity-ide-or-antigravity-sdk)
- [Transitioning Gemini CLI to Antigravity CLI](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/)
- [Issue #632 — headless/Docker env var auth](https://github.com/google-antigravity/antigravity-cli/issues/632) · [Issue #78 — Gemini API key for headless](https://github.com/google-antigravity/antigravity-cli/issues/78)
- [ToS Section 6 and account suspensions](https://discuss.ai.google.dev/t/important-reminder-antigravity-terms-of-service-section-6-recent-gemini-access-suspensions/125193) · [The Register — Antigravity compute burden](https://www.theregister.com/2026/02/23/google_antigravity_compute_burden/)

### Containerization and egress

- [Docker Sandboxes docs](https://docs.docker.com/ai/sandboxes/) · [Local policy](https://docs.docker.com/ai/sandboxes/security/policy/) · [`sbx policy deny network`](https://docs.docker.com/reference/cli/sbx/policy/deny/network/) · [Install guide](https://learn.arm.com/install-guides/sbx/)
- [`ironsh/iron-proxy`](https://github.com/ironsh/iron-proxy) · [Squid SSL peek and splice](https://wiki.squid-cache.org/Features/SslPeekAndSplice) · [Squid ACLs](https://wiki.squid-cache.org/SquidFaq/SquidAcl)
- [INNOQ — restricting network access for AI coding agents](https://www.innoq.com/en/blog/2026/03/dev-sandbox-network/) · [SlicerVM — intercepting and filtering agent traffic](https://slicervm.com/blog/intercepting-filtering-agent-traffic/)
- [Northflank — how to sandbox AI agents](https://northflank.com/blog/how-to-sandbox-ai-agents) · [List of coding agent sandboxes, 2026-05](https://gist.github.com/wincent/2752d8d97727577050c043e4ff9e386e)
- [Docker Compose networks reference](https://docs.docker.com/reference/compose-file/networks/) · [Apple container CLI on macOS](https://suraj.io/post/2026/using-osx-containerization/)
