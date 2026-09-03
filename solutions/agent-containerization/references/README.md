# Reference URL Directory

Every source consulted for the agent containerization research, organised by topic. Use this as the starting point for follow-up research rather than re-searching from scratch.

**All 107 URLs verified reachable on 2026-09-02**, except where marked bot-blocked. One further URL — the CIS MCP Companion Guide download — was added and verified on 2026-09-03, bringing the total to 108. Verification method:

```bash
curl -sSL -o /dev/null --max-time 20 -A "Mozilla/5.0" -w "%{http_code}|%{url_effective}" "<url>"
```

Entries marked **bot-blocked** return 403 to automated requests but load normally in a browser. Canonical redirect targets have been substituted where the original URL redirected.

## Contents

- [Docker Sandboxes (`sbx`)](#docker-sandboxes-sbx)
- [Claude Code — official documentation](#claude-code--official-documentation)
- [Claude Code — source and issues](#claude-code--source-and-issues)
- [OpenAI Codex — official documentation](#openai-codex--official-documentation)
- [OpenAI Codex — source and tooling](#openai-codex--source-and-tooling)
- [Google Antigravity — official](#google-antigravity--official)
- [Google Antigravity — issues, community, terms](#google-antigravity--issues-community-terms)
- [AWS — CLI and IAM Identity Center](#aws--cli-and-iam-identity-center)
- [Egress filtering and proxies](#egress-filtering-and-proxies)
- [Standards and security guidance](#standards-and-security-guidance)
- [Isolation and sandboxing strategy](#isolation-and-sandboxing-strategy)
- [Prior art — active projects](#prior-art--active-projects)
- [Prior art — stale, reference only](#prior-art--stale-reference-only)

## Docker Sandboxes (`sbx`)

| URL | Covers |
|---|---|
| <https://www.docker.com/products/docker-sandboxes/#credentials> | Product page, credentials section — how agent credentials are handled in a sandbox |
| <https://docs.docker.com/ai/sandboxes/> | Documentation entry point |
| <https://docs.docker.com/ai/sandboxes/install/> | Install prerequisites — Homebrew, Docker Hub account, macOS 14+ Apple silicon |
| <https://docs.docker.com/ai/sandboxes/agents/> | Supported agents list (Claude Code, Codex, Copilot, Cursor, Gemini, Kiro, OpenCode, Shell) |
| <https://docs.docker.com/ai/sandboxes/configuration/> | Credentials, environment files (`.sbxenv.yaml`), GPU passthrough, upstream proxy |
| <https://docs.docker.com/ai/sandboxes/governance/access-controls/local/> | **Local policy model** — presets, precedence, what is and is not intercepted |
| <https://docs.docker.com/reference/cli/sbx/policy/allow/network/> | `sbx policy allow network` CLI reference |
| <https://docs.docker.com/reference/cli/sbx/policy/deny/network/> | `sbx policy deny network` CLI reference |
| <https://docs.docker.com/ai/sandboxes/faq/> | FAQ |
| <https://github.com/docker/sbx-releases> | Release and issue tracker (the CLI itself is closed-source) |
| <https://learn.arm.com/install-guides/sbx/> | Third-party install guide with concrete platform requirements |
| <https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/> | Launch announcement — microVM isolation rationale |

## Claude Code — official documentation

| URL | Covers |
|---|---|
| <https://code.claude.com/docs/en/devcontainer> | Reference devcontainer, explicitly "a working example rather than a maintained base image" |
| <https://code.claude.com/docs/en/sandbox-environments> | Comparison of sandboxing approaches |
| <https://code.claude.com/docs/en/sandboxing> | Built-in Bash sandbox — Seatbelt, bubblewrap, scope limits |
| <https://code.claude.com/docs/en/settings-reference> | Complete `sandbox.*` key reference including `sandbox.network.*` |
| <https://code.claude.com/docs/en/authentication> | Credential storage per OS, auth precedence, `setup-token` |
| <https://code.claude.com/docs/en/claude-directory> | `~/.claude` layout, `CLAUDE_CONFIG_DIR`, the separate `~/.claude.json` |
| <https://code.claude.com/docs/en/env-vars> | Full environment variable reference |
| <https://code.claude.com/docs/en/network-config> | **Required egress domains**, proxy support, custom CA, mTLS |
| <https://code.claude.com/docs/en/permissions> | `permissions.allow` / `deny`, `WebFetch(domain:…)` wildcard rules |
| <https://code.claude.com/docs/en/data-usage> | Telemetry endpoints and how to disable them |
| <https://code.claude.com/docs/en/agent-sdk/secure-deployment> | Anthropic's own secure-deployment guidance |

## Claude Code — source and issues

| URL | Covers |
|---|---|
| <https://github.com/anthropics/claude-code/tree/main/.devcontainer> | Reference devcontainer directory |
| <https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh> | The iptables + ipset egress script — read this before writing your own |
| <https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile> | Base image, packages, sudoers drop-in |
| <https://github.com/anthropics/claude-code/blob/main/.devcontainer/devcontainer.json> | `runArgs` capabilities, named volumes, `CLAUDE_CONFIG_DIR` |
| <https://github.com/anthropics/sandbox-runtime> | `srt` — process-wide sandbox constraining every tool, hook and MCP server |
| <https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime> | `srt` package and version history — **bot-blocked** |
| <https://github.com/anthropics/devcontainer-features> | Devcontainer Feature — stale since 2025-06-25 |
| <https://github.com/anthropics/claude-code/issues/36907> | **DNS bypass** — firewall permits UDP/53 to any destination |
| <https://github.com/anthropics/claude-code/issues/32113> | Devcontainer Feature silently overwrites a custom `init-firewall.sh` |
| <https://github.com/anthropics/claude-code/issues/55623> | Startup abort when an allowlisted domain fails to resolve |

## OpenAI Codex — official documentation

| URL | Covers |
|---|---|
| <https://learn.chatgpt.com/docs/agent-approvals-security> | **The documented "already sandboxed, bypass the inner sandbox" container pattern** |
| <https://learn.chatgpt.com/docs/sandboxing> | Sandbox modes and host-side AppArmor caveats |
| <https://learn.chatgpt.com/docs/auth> | Authentication modes |
| <https://learn.chatgpt.com/docs/config-file/config-reference> | `config.toml` reference |
| <https://help.openai.com/en/articles/9247338-network-recommendations-for-chatgpt-errors-on-web-and-apps> | Network and WebSocket requirements — **bot-blocked** |

## OpenAI Codex — source and tooling

| URL | Covers |
|---|---|
| <https://github.com/openai/codex> | Main repository |
| <https://github.com/openai/codex/blob/main/docs/install.md> | Install methods, platform artifacts including static musl builds |
| <https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md> | **bubblewrap + seccomp** model; `--no-proc` for restrictive containers |
| <https://github.com/openai/codex/blob/main/codex-rs/network-proxy/README.md> | Built-in policy proxy — `features.network_proxy` allow/deny semantics |
| <https://github.com/openai/codex/blob/main/codex-rs/http-client/README.md> | Proxy policies, `respect_system_proxy` |
| <https://github.com/openai/codex/blob/main/codex-rs/http-client/src/custom_ca.rs> | `CODEX_CA_CERTIFICATE` / `SSL_CERT_FILE` handling |
| <https://github.com/openai/codex/blob/main/codex-rs/login/src/server.rs> | OAuth issuer, callback ports 1455/1457 |
| <https://github.com/openai/codex/blob/main/codex-rs/core/config.schema.json> | Authoritative config schema and defaults |
| <https://github.com/openai/codex/tree/main/.devcontainer> | Maintained container pattern including its `init-firewall.sh` |
| <https://github.com/openai/codex/blob/main/.devcontainer/Dockerfile.secure> | setuid `bwrap` plus the capability set needed to nest the inner sandbox |
| <https://github.com/openai/codex/blob/main/codex-rs/responses-api-proxy/README.md> | **Credential-broker primitive** — forwards only `POST /v1/responses` |
| <https://github.com/openai/codex/blob/main/codex-cli/scripts/run_in_container.sh> | Orphaned reference design — do not build on it |
| <https://github.com/openai/codex-action> | Official GitHub Action wiring the CLI to a secure proxy |
| <https://github.com/openai/codex-universal> | Codex Cloud base image — **does not contain the CLI** |
| <https://formulae.brew.sh/api/cask/codex.json> | Current shipping version via the Homebrew cask API |

## Google Antigravity — official

| URL | Covers |
|---|---|
| <https://antigravity.google/docs/cli/headless/> | **`agy` headless mode** — `-p`, output formats, stream-json, the soft-deny exit-0 behaviour |
| <https://antigravity.google/docs/cli/install/> | Install script, credential storage, `modelProvider` + `GEMINI_API_KEY` |
| <https://antigravity.google/docs/cli/troubleshooting/> | Keyring and D-Bus requirements for headless and SSH sessions |
| <https://antigravity.google/docs/sdk/overview/> | Python SDK — the maintainer-recommended CI path |
| <https://antigravity.google/docs/enterprise/> | Enterprise endpoints and regional routing |
| <https://antigravity.google/download/linux/> | Linux packaging and glibc requirements |
| <https://antigravity.google/terms/> | **Additional Terms of Service — Section 6.** Read before designing any proxy in front of Antigravity |
| <https://cloud.google.com/blog/topics/developers-practitioners/choosing-your-surface-antigravity-20-antigravity-cli-antigravity-ide-or-antigravity-sdk> | The four surfaces, and which are container-suitable |
| <https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/> | `gemini-cli` shutdown and migration to `agy` |
| <https://github.com/google-antigravity/antigravity-sdk-python> | SDK source |

## Google Antigravity — issues, community, terms

| URL | Covers |
|---|---|
| <https://github.com/google-antigravity/antigravity-cli/issues/632> | Headless/Docker env-var auth request — the documented container failure mode |
| <https://github.com/google-antigravity/antigravity-cli/issues/78> | Maintainer statement on API keys for headless use (conflicts with current docs) |
| <https://discuss.ai.google.dev/t/important-reminder-antigravity-terms-of-service-section-6-recent-gemini-access-suspensions/125193> | **Account suspensions for third-party tools and proxies** |
| <https://www.theregister.com/software/2026/02/23/google-antigravity-falls-to-earth-under-compute-burden/4676154> | Reporting on the suspensions and their stated driver |
| <https://github.com/mirusser/antigravity-docker> | GUI-in-container reference — documents why it needs `seccomp:unconfined` |
| <https://github.com/Shiritai/sanity-gravity> | Disposable sandbox container for agent confinement |

## AWS — CLI and IAM Identity Center

| URL | Covers |
|---|---|
| <https://docs.aws.amazon.com/cli/latest/reference/sso/login.html> | `aws sso login` — `--no-browser`, `--use-device-code` for headless containers |
| <https://docs.aws.amazon.com/cli/latest/reference/sso/list-accounts.html> | **Enumerates every entitled account from an access token alone** — why a trimmed config is not a boundary |
| <https://docs.aws.amazon.com/cli/latest/reference/sso/get-role-credentials.html> | Mints role credentials from an access token; does not consult the config file |
| <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html> | SSO configuration overview |
| <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso-tutorial.html> | Manual `[sso-session]` / `[profile]` config — the shape of the synthetic config to mount |
| <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html> | `sso_registration_scopes`, refresh-token behaviour, `~/.aws/sso/cache` |
| <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html> | `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE`, `AWS_PROFILE`, `AWS_CA_BUNDLE` |
| <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-proxy.html> | `HTTP_PROXY` / `HTTPS_PROXY` handling |
| <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sourcing-external.html> | `credential_process` — the mechanism for brokered credentials |
| <https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html> | Permission sets — the unit of agent privilege scoping |
| <https://docs.aws.amazon.com/whitepapers/latest/building-a-data-perimeter-on-aws/building-a-data-perimeter-on-aws.html> | Data perimeter controls preventing cross-account exfiltration through allowlisted AWS endpoints |

## Egress filtering and proxies

| URL | Covers |
|---|---|
| <https://github.com/paradigmxyz/iron-proxy> | Default-deny MITM egress proxy with built-in DNS, glob allowlist, post-resolution CIDR denylist. Also served at `github.com/ironsh/iron-proxy`, which redirects here |
| <https://wiki.squid-cache.org/Features/SslPeekAndSplice> | SNI peek-and-splice — domain filtering without decrypting, the safe option for Antigravity |
| <https://wiki.squid-cache.org/SquidFaq/SquidAcl> | Squid ACL semantics including `ssl::server_name` |
| <https://www.innoq.com/en/blog/2026/03/dev-sandbox-network/> | Working CONNECT-allowlist setup for coding agents, with nftables belt-and-braces |
| <https://slicervm.com/blog/intercepting-filtering-agent-traffic/> | Host-level enforcement plus CA injection for microVM agent sandboxes |
| <https://docs.docker.com/reference/compose-file/networks/> | `internal: true` networks — the basis of the Option 2 topology |

## Standards and security guidance

Published standards bearing on agentic AI and container hardening. Analysis in [`../docs/STANDARDS_MAPPING.md`](../docs/STANDARDS_MAPPING.md).

| URL | Covers |
|---|---|
| <https://www.cisecurity.org/cis-benchmarks> | Benchmarks catalogue — confirms there is **no** AI, LLM, agentic or MCP benchmark |
| <https://www.cisecurity.org/benchmark/docker> | CIS Docker Benchmark 1.8.0 — container runtime hardening, closest published checklist for R1 |
| <https://www.cisecurity.org/benchmark/kubernetes> | CIS Kubernetes Benchmark 2.0.1 plus EKS/AKS/GKE/OpenShift variants |
| <https://www.cisecurity.org/controls/v8-1> | CIS Controls v8.1 — the framework both AI companion guides extend |
| <https://www.cisecurity.org/insights/white-papers/controls-v8-1-ai-agents-companion-guide> | **AI Agents Companion Guide** (2026-04-20) — Controls v8.1 applied to the agent layer |
| <https://www.cisecurity.org/insights/white-papers/controls-v8-1-ai-llm-companion-guide> | **AI and LLM Companion Guide** (2026-04-20) — prompt injection, retrieval poisoning, context boundaries |
| <https://learn.cisecurity.org/controls-v8-1-ai-agent-companion-guide> | AI Agents guide download |
| <https://learn.cisecurity.org/controls-v8-1-ai-llm-companion-guide> | AI and LLM guide download |
| <https://learn.cisecurity.org/controls-v8-1-mcp-companion-guide> | **MCP Companion Guide** download — Controls v8.1 applied to the Model Context Protocol layer. Verified 2026-09-03. No `insights/white-papers/` landing page found for this guide |
| <https://learn.cisecurity.org/benchmarks> | Benchmark downloads |
| <https://www.cisa.gov/resources-tools/resources/careful-adoption-agentic-ai-services> | **Careful Adoption of Agentic AI Services** (2026-05-01, Five Eyes) — the most actionable published guidance for this project |
| <https://www.cisa.gov/news-events/news/cisa-us-and-international-partners-release-guide-secure-adoption-agentic-ai> | Release announcement with the full authoring agency list |
| <https://media.defense.gov/2026/Apr/30/2003922823/-1/-1/0/CAREFUL%20ADOPTION%20OF%20AGENTIC%20AI%20SERVICES_FINAL.PDF> | Primary PDF of the Five Eyes guidance — **bot-blocked** |
| <https://labs.cloudsecurityalliance.org/research/csa-research-note-cisa-agentic-ai-adoption-guide-20260513-cs/> | CSA analysis — source of the quoted technical control positions |

## Isolation and sandboxing strategy

| URL | Covers |
|---|---|
| <https://northflank.com/blog/how-to-sandbox-ai-agents> | Namespaces vs gVisor vs microVM trade-offs with overhead figures |
| <https://gist.github.com/wincent/2752d8d97727577050c043e4ff9e386e> | Comprehensive landscape survey of coding-agent sandboxes (2026-05) |
| <https://suraj.io/post/2026/using-osx-containerization/> | Apple `container` CLI — per-container VMs on macOS |

## Prior art — active projects

| URL | Covers |
|---|---|
| <https://github.com/trailofbits/claude-code-devcontainer> | Best-maintained hardened devcontainer; aimed at reviewing untrusted code |
| <https://github.com/imbue-ai/sculptor> | Parallel agents in isolated worktrees |

## Prior art — stale, reference only

Listed so they are recognised as dead ends rather than rediscovered.

| URL | Status |
|---|---|
| <https://github.com/textcortex/claude-code-sandbox> | Archived 2026-02-20; successor is `textcortex/spritz` |
| <https://github.com/RchGrav/claudebox> | Last commit 2025-08-31 |
| <https://github.com/dagger/container-use> | Self-labelled experimental; largely idle since March 2026 |
