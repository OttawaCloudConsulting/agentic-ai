# External Integrations

**Analysis Date:** 2026-04-02

## APIs & External Services

**AWS (via MCP servers, installed on demand):**
- AWS Core APIs — orchestration layer via `awslabs.core-mcp-server`; requires AWS credentials in environment
- AWS Documentation — read-only docs search via `awslabs.aws-documentation-mcp-server`
- AWS Knowledge MCP — HTTP transport at `https://knowledge-mcp.global.api.aws` (no local binary)
- AWS Pricing API — accessed via `awslabs.aws-pricing-mcp-server`
- AWS Well-Architected — security assessment via `awslabs.well-architected-security-mcp-server`
- AWS Serverless — Lambda, API Gateway, Step Functions via `awslabs.serverless-mcp-server`
- Auth: AWS credential chain (environment variables, `~/.aws/credentials`, IAM role)

**Google NotebookLM:**
- Accessed via `notebooklm-mcp-cli` Python package, registered in `.mcp.json`
- SDK/Client: `uvx --from notebooklm-mcp-cli@latest notebooklm-mcp` (stdio transport)
- Auth: `NOTEBOOKLM_COOKIES` environment variable; CSRF token and session ID auto-extracted
- Optional env vars: `NOTEBOOKLM_CSRF_TOKEN` (deprecated), `NOTEBOOKLM_SESSION_ID` (deprecated), `NOTEBOOKLM_BL`, `NOTEBOOKLM_HL`
- Credential storage: `~/.notebooklm-mcp-cli/profiles/<name>/auth.json`
- Reference: `temp/notebooklm-mcp-cli/pyproject.toml`

**GitHub:**
- Accessed via `@github/mcp-server@latest` (npx, MCP pattern `GITHUB`)
- Auth: `GITHUB_TOKEN` or `GH_TOKEN` environment variable (standard gh CLI credential)
- Also uses `gh` CLI for PR and issue operations within GSD commands

**Terraform / HashiCorp Registry:**
- `hashicorp/terraform-mcp-server` (Docker) — registry and module lookups
- `awslabs.terraform-mcp-server` (uvx) — AWS-specific Terraform with Checkov scanning

**Kubernetes / Crossplane:**
- `kubernetes-mcp-server@latest` (npx) — reads `~/.kube/config`
- `controlplane-mcp-server:v0.1.0` (Docker, HTTP transport) — Upbound/Crossplane control plane

**Documentation / Library Context:**
- Context7 (`@upstash/context7-mcp@latest` via npx) — fetches version-specific library docs from Upstash's service

**Diagram Generation:**
- Mermaid (`mcp-mermaid@latest` via npx) — renders Mermaid diagrams locally
- AWS Diagram (`awslabs.aws-diagram-mcp-server` via uvx) — architecture diagram generation

**Security Scanning:**
- Trivy (`trivy mcp`) — local binary; runs vulnerability and IaC scanning; requires `trivy` installed on host

**CDK / IaC:**
- `awslabs.iac-mcp-server` (uvx) — CDK and CloudFormation; also registered in `solutions/well-architected-review/mcp.json`

**Web Search (optional):**
- Brave Search API — accessed by `gsd-tools.cjs` `websearch` command if `BRAVE_API_KEY` is configured
- Auth: `BRAVE_API_KEY` environment variable

## Data Storage

**Databases:**
- None — no database in the repo

**File Storage:**
- Local filesystem only — all project state stored in `.planning/` directory tree within each project
- GSD state files: `.planning/config.json`, `.planning/STATE.md`, `.planning/ROADMAP.md`, `WAITING.json`
- GSD tools write to `.planning/codebase/` (these documents)

**Caching:**
- Local file cache only — GSD update check writes to `~/.claude/cache/gsd-update-check.json`
- NotebookLM MCP caches auth tokens at `~/.notebooklm-mcp-cli/profiles/<name>/auth.json`

## Authentication & Identity

**Auth Provider:**
- No centralized auth — each external service uses its own credentials
- Claude Code auth: managed by `@anthropic-ai/claude-code` directly (Anthropic API key)
- AWS: standard AWS credential chain; no explicit setup in this repo
- GitHub: `gh` CLI credential store or `GITHUB_TOKEN` env var
- NotebookLM: browser cookie extraction via Chrome DevTools

## Monitoring & Observability

**Error Tracking:**
- None — no error tracking service integrated

**Logs:**
- Claude Code hook output goes to Claude Code's session interface
- Hook scripts (`gsd-check-update.js`, `gsd-context-monitor.js`, etc.) write to stdout/stderr, captured by Claude Code
- GSD status line rendered via `gsd-statusline.js` on each tool use

## CI/CD & Deployment

**Hosting:**
- GitHub repository — `OCC-github/agentic-ai`; no server-side deployment
- Components distributed by copying files or via npm (`get-shit-done-cc`)

**CI Pipeline:**
- No GitHub Actions workflows in this repo (`.github/` not present at root)
- Local CI available via `bash cicd/lint-markdown.sh` using `markdownlint-cli2` (via npx or local install)
- Benchmark scripts at `scripts/benchmark/run-benchmark.sh` and `run-variance.sh` for manual performance testing

## Environment Configuration

**Required env vars (by integration):**
- `NOTEBOOKLM_COOKIES` — required for NotebookLM MCP
- `GITHUB_TOKEN` or `GH_TOKEN` — required for GitHub MCP server
- AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE`, or IAM role) — required for AWS MCP servers
- `BRAVE_API_KEY` — optional; enables web search in `gsd-tools.cjs`
- `CLAUDE_CONFIG_DIR` — optional override for Claude config directory location (devcontainer sets to `/home/node/.claude`)
- `NODE_OPTIONS` — set to `--max-old-space-size=4096` in devcontainer

**Secrets location:**
- `.env` files: not present in repo; managed per-project by users
- NotebookLM auth: `~/.notebooklm-mcp-cli/profiles/` (outside repo)
- AWS credentials: `~/.aws/` (outside repo) or environment variables
- MCP server env vars: configured in `.mcp.json` `env` block (currently empty in root `.mcp.json`)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None — all integrations are request-initiated via MCP tool calls from Claude Code

---

*Integration audit: 2026-04-02*
