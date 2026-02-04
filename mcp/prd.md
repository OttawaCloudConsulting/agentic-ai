# PRD: Dynamic MCP Installation Script

## Summary

A shell script (`install_mcp.sh`) that installs and removes MCP servers for Claude Code projects in composable, pattern-based groups. Patterns map to use cases (AWS, CDK, Terraform, Kubernetes, etc.) and can be combined on a single invocation. The script manages the full lifecycle: add, remove, list, and prerequisite validation.

## Goals

- Install MCP servers in logical groups matching real workflows (e.g., `AWS CDK`, `AWS Terraform`)
- Remove MCP servers when no longer needed to reduce context and resource consumption
- Composable patterns — combine multiple on one command, with deduplication
- Prerequisite checking — fail early if required tools are missing
- Discoverability — list available patterns and their contents
- Project-scoped installation only (`-s project`)
- Check-and-skip — detect already-installed servers and skip them

## Architecture

### Invocation

```bash
# Add patterns (default action)
bash install_mcp.sh AWS CDK

# Remove patterns
bash install_mcp.sh --remove AWS CDK

# List all patterns
bash install_mcp.sh list

# List servers in a specific pattern
bash install_mcp.sh list AWS

# Help
bash install_mcp.sh --help
```

### Pattern Definitions

Each pattern is a named group of MCP servers. Patterns are composable — specifying multiple patterns unions their servers with deduplication. Pattern names are case-insensitive.

| Pattern | Servers | Use Case |
|---------|---------|----------|
| **AWS** | core-mcp-server, aws-knowledge-mcp, aws-documentation-mcp-server, diagram-mcp-server | Base AWS development |
| **CDK** | iac-mcp-server | AWS CDK projects |
| **Terraform** | terraform-mcp-server (HashiCorp), awslabs.terraform-mcp-server (AWS) | Terraform IaC projects |
| **Documentation** | aws-documentation-mcp-server, code-doc-gen-mcp-server, context7 | Documentation lookup and generation |
| **Architecture** | diagram-mcp-server, mermaid MCP | Architecture and design work |
| **Security** | trivy-mcp, well-architected-security-mcp-server | Security scanning and compliance |
| **Kubernetes** | kubernetes-mcp-server (Red Hat) | General Kubernetes management |
| **Crossplane** | controlplane-mcp-server (Upbound) | Crossplane and Upbound |
| **Pricing** | aws-pricing-mcp-server, cost-analysis-mcp-server | Cost modeling (temporary use) |
| **Git** | @modelcontextprotocol/server-git | Local Git repository operations |
| **GitHub** | @github/mcp-server, @modelcontextprotocol/server-git | GitHub API + local Git operations |
| **Serverless** | awslabs.serverless-mcp-server | Lambda, API Gateway, Step Functions |

### Server Registry

Each server entry defines:
- **Name**: MCP server name used with `claude mcp add/remove`
- **Install command**: Full `claude mcp add` command with arguments
- **Prerequisites**: Required tools (uvx, npx, docker, etc.)
- **Transport**: stdio, http, or sse
- **Environment variables**: Hardcoded sensible defaults (e.g., FASTMCP_LOG_LEVEL=warning)

### Operations

1. **Add** (default): Install all servers in the specified patterns. Check currently installed servers (via `claude mcp list` or `.mcp.json`) and skip those already present. Deduplicate across patterns.
2. **Remove** (`--remove`): Remove all servers in the specified patterns via `claude mcp remove`.
3. **List** (`list`): Display available patterns and their server contents. If a pattern name is given, show only that pattern's servers.

### Prerequisites

Before any add operation, validate:
- `claude` CLI is available
- Transport-specific tools exist (`uvx` for Python servers, `npx` for Node servers, `docker` for container-based servers)
- For Docker-based servers: check Docker daemon is running. If not, **warn and skip** those servers but continue with others.
- Report all missing prerequisites and exit non-zero (except Docker which is a soft warning)
- Skip prerequisite check for `list` and `--remove` operations

### Environment Variables

Hardcode sensible defaults for MCP server environment variables:
- `FASTMCP_LOG_LEVEL=warning` for servers that support it
- No user configuration of env vars — set reasonable defaults in the script

## Code Quality

- **Google Shell Style Guide** compliant: https://google.github.io/styleguide/shellguide.html
- **ShellCheck** clean: script must pass `shellcheck install_mcp.sh` with zero warnings
- Key style requirements: `snake_case` for functions and variables, `readonly` for constants, `local` for function variables, explicit return codes, quoting all variable expansions

## Non-Goals

- User-scope installation (always project scope)
- Version pinning (use `@latest` for all servers)
- Auto-updating MCP servers
- Custom pattern definition by users (patterns are hardcoded in the script)
- MCP server configuration beyond what `claude mcp add` provides
- Windows support (bash script, macOS/Linux only)
- Dry-run mode

## Features

### Feature 1: Script Foundation and Pattern Registry
Define the pattern-to-server mapping data structure, argument parsing (action detection: add/remove/list, pattern names, `--remove` flag), and usage/help output. Script must comply with Google Shell Style Guide and pass ShellCheck.

**Acceptance criteria:**
- Pattern registry using POSIX-compatible structures (case statements or functions, no bash 4+ associative arrays)
- Each server entry: name, install command, prerequisite tool, env vars
- Argument parser handles: no args (show help), `list`, `list PATTERN`, `PATTERN...`, `--remove PATTERN...`
- Pattern names are case-insensitive
- `--help` and no-argument invocation show usage with examples
- Unknown pattern names produce error with list of valid patterns
- Google Shell Style Guide: snake_case naming, readonly constants, local variables, quoted expansions
- ShellCheck clean (zero warnings/errors)

### Feature 2: Prerequisite Checking
Validate required tools before executing any install commands.

**Acceptance criteria:**
- Check `claude` CLI exists
- For each server in the resolved pattern set, check its prerequisite tool (uvx, npx, docker)
- Collect all missing prerequisites and report them together
- Exit non-zero with clear message listing what to install
- Docker: check daemon running — warn and skip Docker-based servers if not running (soft failure)
- Skip prerequisite check for `list` and `--remove` operations

### Feature 3: Add Operation
Install MCP servers for the specified patterns.

**Acceptance criteria:**
- Resolve pattern names to server lists
- Deduplicate servers across multiple patterns
- Check currently installed servers and skip those already present
- Execute `claude mcp add` commands with `-s project` scope
- Report each server being installed (server name, pattern it came from)
- Report summary: N servers installed, N skipped (already installed), N skipped (duplicate)
- Handle unknown pattern names gracefully (error + list valid patterns)

### Feature 4: Remove Operation
Remove MCP servers for the specified patterns.

**Acceptance criteria:**
- `--remove` flag triggers remove mode
- Resolve pattern names to server lists
- Execute `claude mcp remove` for each server
- Deduplicate across patterns (don't try to remove same server twice)
- Report each server being removed
- Handle errors gracefully (server not installed = warning, not failure)

### Feature 5: List Operation
Display available patterns and their server contents.

**Acceptance criteria:**
- `list` with no pattern: show all patterns with server counts and brief description
- `list PATTERN`: show servers in that pattern with name and description
- Output is readable in terminal (aligned columns or similar)
- Unknown pattern name: error + show available patterns

### Feature 6: Server Inventory — AWS Pattern
Define all servers in the AWS base pattern.

**Acceptance criteria:**
- awslabs.core-mcp-server (uvx, stdio, env: FASTMCP_LOG_LEVEL=warning)
- aws-knowledge-mcp (http transport, no tool prerequisite)
- awslabs.aws-documentation-mcp-server (uvx, stdio)
- awslabs.diagram-mcp-server (uvx, stdio)
- Each server has correct `claude mcp add` command

### Feature 7: Server Inventory — CDK Pattern
Define CDK pattern servers.

**Acceptance criteria:**
- awslabs.iac-mcp-server (uvx, stdio) — replaces deprecated cdk-mcp-server
- Pattern designed to be combined with AWS pattern

### Feature 8: Server Inventory — Terraform Pattern
Define Terraform pattern servers.

**Acceptance criteria:**
- hashicorp/terraform-mcp-server (docker, stdio) — Docker prerequisite with soft warning
- awslabs.terraform-mcp-server (uvx, stdio) — AWS-specific Terraform with Checkov
- Pattern designed to be combined with AWS pattern

### Feature 9: Server Inventory — Documentation Pattern
Define Documentation pattern servers.

**Acceptance criteria:**
- awslabs.aws-documentation-mcp-server (uvx, stdio)
- awslabs.code-doc-gen-mcp-server (uvx, stdio)
- context7 via @upstash/context7-mcp (npx, stdio) — version-specific library docs

### Feature 10: Server Inventory — Architecture Pattern
Define Architecture and Design pattern servers.

**Acceptance criteria:**
- awslabs.diagram-mcp-server (uvx, stdio) — AWS architecture diagrams
- mcp-mermaid (npx, stdio) — general Mermaid diagram generation (hustcc/mcp-mermaid)

### Feature 11: Server Inventory — Security Pattern
Define Security and Compliance pattern servers.

**Acceptance criteria:**
- trivy-mcp (trivy CLI + plugin, stdio) — vulnerability and IaC scanning. Script auto-installs the Trivy MCP plugin (`trivy plugin install mcp`) before adding the server.
- awslabs.well-architected-security-mcp-server (uvx, stdio) — AWS security assessment

### Feature 12: Server Inventory — Kubernetes Pattern
Define Kubernetes pattern servers.

**Acceptance criteria:**
- kubernetes-mcp-server (npx, stdio) — Red Hat, general-purpose K8s
- Not EKS-specific (EKS available separately if needed)

### Feature 13: Server Inventory — Crossplane Pattern
Define Crossplane and Upbound pattern servers.

**Acceptance criteria:**
- controlplane-mcp-server (docker/OCI, http-stream) — Upbound official
- Note: early stage (v0.1.0), Docker prerequisite with soft warning

### Feature 14: Server Inventory — Pricing Pattern
Define Pricing pattern servers (designed for temporary use).

**Acceptance criteria:**
- awslabs.aws-pricing-mcp-server (uvx, stdio)
- awslabs.cost-analysis-mcp-server (uvx, stdio)
- Pattern designed for add-use-remove workflow

### Feature 15: Server Inventory — Git Pattern
Define Git pattern servers.

**Acceptance criteria:**
- @modelcontextprotocol/server-git (npx, stdio) — local Git repository operations
- Standalone pattern for local Git operations only

### Feature 16: Server Inventory — GitHub Pattern
Define GitHub pattern servers.

**Acceptance criteria:**
- @github/mcp-server (npx, stdio) — GitHub API access (issues, PRs, code search)
- @modelcontextprotocol/server-git (npx, stdio) — local Git repository operations
- Includes Git server for combined GitHub + local Git workflow

### Feature 17: Server Inventory — Serverless Pattern
Define Serverless pattern servers.

**Acceptance criteria:**
- awslabs.serverless-mcp-server (uvx, stdio) — Lambda, API Gateway, Step Functions
- Pattern designed to be combined with AWS pattern
