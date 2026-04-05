# Technology Stack

**Analysis Date:** 2026-04-02

## Languages

**Primary:**
- Markdown - Skill definitions, command files, documentation, workflow prompts (`.claude/commands/`, `skills/`, `agents/`, `rules/`)
- Bash (shell) - Automation scripts, MCP installer, CI linting, CDK/Terraform test runners (`mcp/install_mcp.sh`, `cicd/lint-markdown.sh`, `scripts/benchmark/`, `skills/cdk-testing/scripts/cdk-validation.sh`, `skills/terraform-testing/scripts/test-terraform.sh`)
- JavaScript (CommonJS / Node.js) - Claude Code hooks and GSD workflow engine runtime (`.claude/hooks/*.js`, `.claude/get-shit-done/bin/gsd-tools.cjs`, `.claude/get-shit-done/bin/lib/*.cjs`)

**Secondary:**
- Python 3.11+ - Third-party MCP server dependency (`temp/notebooklm-mcp-cli/`) built with `hatchling`; not part of the primary codebase authored by this repo
- JSONC - Configuration files (`.markdownlint.jsonc`, `.markdownlint-fix.markdownlint.jsonc`)

## Runtime

**Environment:**
- Node.js v20 (pinned in `.devcontainer/Dockerfile` base image `node:20`)
- Node.js v25.8.2 detected on host machine

**Package Manager:**
- npm v11.11.1 (host)
- uv v0.9.16 — used to run Python-based MCP servers via `uvx` (not for this repo's own code)
- Lockfile: Not present — the repo contains no `package-lock.json` or `yarn.lock`; `.claude/package.json` and `.gemini/package.json` contain only `{"type":"commonjs"}` with no dependencies

## Frameworks

**Core:**
- Claude Code (`@anthropic-ai/claude-code@latest`) — the AI coding agent platform this repo targets; installed in devcontainer via `npm install -g @anthropic-ai/claude-code`
- GSD (get-shit-done-cc) v1.30.0 — workflow framework installed at `.claude/get-shit-done/`; provides slash commands, hooks, state management, and phase orchestration. Distributed as npm package `get-shit-done-cc`
- FastMCP — framework used by `notebooklm-mcp-cli` Python server (not this repo's own framework)

**Testing:**
- Not applicable — no automated test suite for this repo's own code

**Build/Dev:**
- markdownlint-cli2 v0.21.0 — Markdown linting via `npx` or local install; config in `.markdownlint.jsonc` and `.markdownlint-fix.markdownlint.jsonc`
- devcontainer (Docker, Node.js 20 base) — sandboxed Claude Code environment defined in `.devcontainer/`
- git-delta v0.18.2 — enhanced git diff display, installed in devcontainer

## Key Dependencies

**Critical:**
- `@anthropic-ai/claude-code@latest` — the agent runtime that executes all commands and hooks
- `get-shit-done-cc` (npm, version tracked in `.claude/get-shit-done/VERSION`) — GSD workflow engine; update checks run via `npm view get-shit-done-cc version` on SessionStart

**Infrastructure (MCP servers, installed via `mcp/install_mcp.sh`, not bundled):**
- `awslabs.core-mcp-server` (uvx) — AWS API orchestration
- `awslabs.aws-documentation-mcp-server` (uvx) — AWS documentation search
- `awslabs.diagram-mcp-server` (uvx) — Architecture diagram generation
- `awslabs.iac-mcp-server` (uvx) — CDK and CloudFormation
- `awslabs.terraform-mcp-server` (uvx) — AWS Terraform with Checkov
- `awslabs.well-architected-security-mcp-server` (uvx) — Security assessment
- `awslabs.aws-pricing-mcp-server` (uvx) — AWS pricing data
- `awslabs.cost-analysis-mcp-server` (uvx) — Pre-deployment cost estimation
- `awslabs.serverless-mcp-server` (uvx) — Lambda, API Gateway, Step Functions
- `awslabs.code-doc-gen-mcp-server` (uvx) — Code documentation generation
- `mcp-mermaid@latest` (npx) — Mermaid diagram rendering
- `@upstash/context7-mcp@latest` (npx) — Version-specific library docs
- `kubernetes-mcp-server@latest` (npx) — Kubernetes cluster management
- `@modelcontextprotocol/server-git@latest` (npx) — Local Git operations
- `@github/mcp-server@latest` (npx) — GitHub API access
- `hashicorp/terraform-mcp-server` (docker) — HashiCorp Terraform registry
- `xpkg.upbound.io/upbound/controlplane-mcp-server:v0.1.0` (docker) — Crossplane
- `trivy` (system binary) — Vulnerability and IaC scanning
- `notebooklm-mcp-cli@latest` (uvx) — Google NotebookLM MCP server

## Configuration

**Environment:**
- `.devcontainer/devcontainer.json` — devcontainer definition; sets `NODE_OPTIONS=--max-old-space-size=4096`, `CLAUDE_CONFIG_DIR=/home/node/.claude`
- `.mcp.json` — project-level MCP server config; currently registers `notebooklm-mcp` via `uvx`
- `solutions/well-architected-review/mcp.json` — solution-specific MCP config for `awslabs-aws-documentation` and `awslabs-iac` servers
- `.claude/settings.json` — Claude Code hooks configuration (SessionStart, PreToolUse, PostToolUse hooks)
- `.claude/settings.local.json` — local overrides (not committed; present in working tree)

**Build:**
- `.markdownlint.jsonc` — markdownlint rule overrides (MD013, MD024, MD036, MD040, MD060 disabled)
- `.markdownlint-fix.markdownlint.jsonc` — auto-fixable rule subset for CI two-pass linting
- `.devcontainer/Dockerfile` — Node.js 20 container with Claude Code, git-delta, zsh, gh CLI, jq, fzf

## Platform Requirements

**Development:**
- Node.js ≥20 (devcontainer uses Node.js 20 exactly)
- `uv` / `uvx` — required for Python-based MCP servers (AWS Labs suite, notebooklm)
- `npx` (Node.js) — required for npm-based MCP servers (mermaid, context7, kubernetes, git, github)
- Docker (optional) — required only for Terraform and Crossplane MCP servers
- `trivy` CLI — required for security scanning MCP server
- Claude Code CLI (`claude`) — required for MCP server installation via `mcp/install_mcp.sh`
- `gh` CLI — used within devcontainer and by some GSD commands

**Production:**
- No server-side deployment — this is a library repo of Claude Code components
- Components are consumed by copying into `~/.claude/` or project directories
- GSD framework distributed via npm (`get-shit-done-cc`)

---

*Stack analysis: 2026-04-02*
