# Architecture and Design: Dynamic MCP Installation Script

## Overview

A POSIX-compatible shell script that manages MCP server lifecycle for Claude Code projects. The script maps named patterns (AWS, CDK, Terraform, etc.) to groups of MCP servers. Users specify one or more patterns and the script installs, removes, or lists the associated servers. All installations are project-scoped.

The script contains no external dependencies beyond the tools it installs servers with (claude, uvx, npx, docker). Pattern definitions are self-contained in the script.

## Component Diagram

```
install_mcp.sh
├── Argument Parser
│   ├── detect action: add (default) | remove (--remove) | list
│   ├── collect pattern names (case-insensitive)
│   └── validate pattern names against registry
│
├── Pattern Registry (hardcoded data)
│   ├── PATTERN → SERVER_NAME mappings
│   └── SERVER_NAME → {install_cmd, prereq_tool, transport, env_vars}
│
├── Prerequisite Checker (add only)
│   ├── claude CLI check (hard fail)
│   ├── uvx/npx check (hard fail if needed by resolved servers)
│   └── docker check (soft warn, skip docker-based servers)
│
├── Installed Server Detector
│   └── parse `claude mcp list` output → set of installed server names
│
├── Operations
│   ├── Add: resolve → dedupe → skip installed → install → report
│   ├── Remove: resolve → dedupe → remove → report
│   └── List: show patterns or show servers in pattern
│
└── Output / Reporting
    ├── per-server status lines
    └── summary counts
```

## Data Flow

### Add Operation

```
1. Parse args → extract pattern names + flags
2. Validate pattern names against registry
3. Resolve patterns → flat list of server names
4. Deduplicate server names (preserve first occurrence)
5. Check prerequisites for resolved servers
   - Hard fail: claude, uvx, npx missing
   - Soft warn: docker not running → remove docker-based servers from list
6. Query installed servers: `claude mcp list` → parse output
7. Filter out already-installed servers
8. For each remaining server:
   a. Execute `claude mcp add -s project ...`
   b. Report success/failure
9. Print summary
```

### Remove Operation

```
1. Parse args → extract pattern names + --remove flag
2. Validate pattern names against registry
3. Resolve patterns → flat list of server names
4. Deduplicate server names
5. For each server:
   a. Execute `claude mcp remove -s project <name>`
   b. Report success/warning
6. Print summary
```

### List Operation

```
1. Parse args → detect `list` action + optional pattern name
2. If no pattern: display all patterns with server counts
3. If pattern given: display servers in that pattern with details
```

## Code Quality Requirements

- **Google Shell Style Guide** compliant: https://google.github.io/styleguide/shellguide.html
- **ShellCheck** clean: `shellcheck install_mcp.sh` must produce zero warnings/errors
- Naming: `snake_case` for all functions and variables
- Constants: `readonly` for all constants (color codes, pattern lists, etc.)
- Variables: `local` for all function-scoped variables
- Quoting: all variable expansions quoted (`"${var}"` not `$var`)
- Return codes: explicit `return` values from functions
- Error output: errors and warnings to stderr (`>&2`)

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | POSIX-compatible shell (no bash 4+ features) | macOS ships bash 3.2. Avoid requiring `brew install bash`. Use functions and case statements instead of associative arrays. |
| 2 | Pattern registry hardcoded in script | Single-file distribution. No external config files to manage. Easy to read and modify. |
| 3 | `claude mcp list` for installed-server detection | Official CLI API. More reliable than parsing `.mcp.json` directly. Format may change but the CLI abstracts that. |
| 4 | Project scope only (`-s project`) | MCP servers are project-specific. User-scope would pollute other projects. |
| 5 | `@latest` for all versions | Reduces maintenance burden. Supply chain risk accepted — all servers are from official publishers (AWS, HashiCorp, Red Hat, Anthropic, Upbound). |
| 6 | Docker as soft prerequisite | Docker is needed for HashiCorp Terraform and Crossplane servers. Not all users have Docker running. Warn and skip rather than fail entirely. |
| 7 | Case-insensitive pattern names | User convenience. `AWS` = `aws` = `Aws`. Convert to uppercase internally for matching. |
| 8 | Deduplication across patterns | Servers like `aws-documentation-mcp-server` appear in both AWS and Documentation patterns. Install once, skip duplicates. |
| 9 | No dry-run mode | `list` command serves the preview purpose. Keeps the script simple. |
| 10 | Hardcoded environment variables | Sensible defaults (FASTMCP_LOG_LEVEL=warning). No user configuration needed. If users need different values, they can modify the script. |
| 11 | Google Shell Style Guide + ShellCheck | Ensures consistent, maintainable, and correct shell code. ShellCheck catches common pitfalls (unquoted variables, missing error handling, POSIX compatibility issues). |

## Pattern-to-Server Mapping

### Data Structure Design

Since we need POSIX compatibility (no associative arrays), patterns and servers are defined using functions:

```sh
# Each pattern function outputs server names, one per line
pattern_aws() {
    echo "awslabs.core-mcp-server"
    echo "aws-knowledge-mcp"
    echo "awslabs.aws-documentation-mcp-server"
    echo "awslabs.diagram-mcp-server"
}

# Each server function outputs: prereq_tool|transport|install_args
server_info_awslabs_core_mcp_server() {
    echo "uvx|stdio|awslabs.core-mcp-server -s project -e FASTMCP_LOG_LEVEL=warning -- uvx awslabs.core-mcp-server@latest"
}
```

Alternative approach: use a flat lookup via `case` statements. Preferred for simplicity.

### Complete Server Inventory

| Server Name | Prereq | Transport | Install Command |
|-------------|--------|-----------|-----------------|
| awslabs.core-mcp-server | uvx | stdio | `claude mcp add awslabs.core-mcp-server -s project -e FASTMCP_LOG_LEVEL=warning -- uvx awslabs.core-mcp-server@latest` |
| aws-knowledge-mcp | none | http | `claude mcp add aws-knowledge-mcp -s project --transport http https://knowledge-mcp.global.api.aws` |
| awslabs.aws-documentation-mcp-server | uvx | stdio | `claude mcp add awslabs.aws-documentation-mcp-server -s project -- uvx awslabs.aws-documentation-mcp-server@latest` |
| awslabs.diagram-mcp-server | uvx | stdio | `claude mcp add awslabs.diagram-mcp-server -s project -- uvx awslabs.diagram-mcp-server@latest` |
| awslabs.iac-mcp-server | uvx | stdio | `claude mcp add awslabs.iac-mcp-server -s project -- uvx awslabs.iac-mcp-server@latest` |
| terraform-mcp-server | docker | stdio | `claude mcp add terraform-mcp-server -s project -- docker run -i --rm hashicorp/terraform-mcp-server` |
| awslabs.terraform-mcp-server | uvx | stdio | `claude mcp add awslabs.terraform-mcp-server -s project -- uvx awslabs.terraform-mcp-server@latest` |
| awslabs.code-doc-gen-mcp-server | uvx | stdio | `claude mcp add awslabs.code-doc-gen-mcp-server -s project -- uvx awslabs.code-doc-gen-mcp-server@latest` |
| context7 | npx | stdio | `claude mcp add context7 -s project -- npx -y @upstash/context7-mcp@latest` |
| mermaid-mcp | npx | stdio | `claude mcp add mermaid-mcp -s project -- npx -y mcp-mermaid@latest` |
| trivy-mcp | trivy | stdio | `trivy plugin install mcp && claude mcp add trivy-mcp -s project -- trivy mcp` |
| awslabs.well-architected-security-mcp-server | uvx | stdio | `claude mcp add awslabs.well-architected-security-mcp-server -s project -- uvx awslabs.well-architected-security-mcp-server@latest` |
| kubernetes-mcp-server | npx | stdio | `claude mcp add kubernetes-mcp-server -s project -- npx kubernetes-mcp-server@latest` |
| controlplane-mcp-server | docker | http-stream | `claude mcp add controlplane-mcp-server -s project --transport http -- docker run -i --rm xpkg.upbound.io/upbound/controlplane-mcp-server:v0.1.0` |
| awslabs.aws-pricing-mcp-server | uvx | stdio | `claude mcp add awslabs.aws-pricing-mcp-server -s project -- uvx awslabs.aws-pricing-mcp-server@latest` |
| awslabs.cost-analysis-mcp-server | uvx | stdio | `claude mcp add awslabs.cost-analysis-mcp-server -s project -- uvx awslabs.cost-analysis-mcp-server@latest` |
| mcp-server-git | npx | stdio | `claude mcp add mcp-server-git -s project -- npx -y @modelcontextprotocol/server-git@latest` |
| github-mcp-server | npx | stdio | `claude mcp add github-mcp-server -s project -- npx -y @github/mcp-server@latest` |
| awslabs.serverless-mcp-server | uvx | stdio | `claude mcp add awslabs.serverless-mcp-server -s project -- uvx awslabs.serverless-mcp-server@latest` |

### Pattern → Server Mapping

| Pattern | Servers (by name) |
|---------|-------------------|
| AWS | awslabs.core-mcp-server, aws-knowledge-mcp, awslabs.aws-documentation-mcp-server, awslabs.diagram-mcp-server |
| CDK | awslabs.iac-mcp-server |
| TERRAFORM | terraform-mcp-server, awslabs.terraform-mcp-server |
| DOCUMENTATION | awslabs.aws-documentation-mcp-server, awslabs.code-doc-gen-mcp-server, context7 |
| ARCHITECTURE | awslabs.diagram-mcp-server, mermaid-mcp |
| SECURITY | trivy-mcp, awslabs.well-architected-security-mcp-server |
| KUBERNETES | kubernetes-mcp-server |
| CROSSPLANE | controlplane-mcp-server |
| PRICING | awslabs.aws-pricing-mcp-server, awslabs.cost-analysis-mcp-server |
| GIT | mcp-server-git |
| GITHUB | github-mcp-server, mcp-server-git |
| SERVERLESS | awslabs.serverless-mcp-server |

### Overlap Matrix (servers shared across patterns)

| Server | Patterns |
|--------|----------|
| awslabs.aws-documentation-mcp-server | AWS, DOCUMENTATION |
| awslabs.diagram-mcp-server | AWS, ARCHITECTURE |
| mcp-server-git | GIT, GITHUB |

These overlaps are handled by deduplication during resolution.

## Script Structure

```
install_mcp.sh
│
├── Constants / Configuration
│   ├── Color codes for output
│   └── VALID_PATTERNS list
│
├── Helper Functions
│   ├── usage()                    — print help text
│   ├── log_info()                 — blue info message
│   ├── log_success()              — green success message
│   ├── log_warn()                 — yellow warning message
│   ├── log_error()                — red error message
│   ├── to_upper()                 — case normalization
│   └── contains()                 — check if value in list
│
├── Registry Functions
│   ├── get_pattern_servers()      — pattern name → server names
│   ├── get_server_install_cmd()   — server name → full claude mcp add command
│   ├── get_server_prereq()        — server name → prerequisite tool name
│   └── get_pattern_description()  — pattern name → human description
│
├── Core Functions
│   ├── check_prerequisites()      — validate tools exist
│   ├── get_installed_servers()    — parse `claude mcp list` output
│   ├── resolve_patterns()         — pattern names → deduplicated server list
│   ├── do_add()                   — install operation
│   ├── do_remove()                — remove operation
│   └── do_list()                  — list operation
│
└── Main
    ├── Parse arguments
    ├── Route to operation
    └── Exit with appropriate code
```

## Output Format

### Add Operation
```
MCP Server Installer
====================

Patterns: AWS, CDK
Resolved: 5 servers (1 duplicate removed)

Checking prerequisites...
  ✓ claude CLI found
  ✓ uvx found
  ⚠ docker not running — skipping docker-based servers

Checking installed servers...
  - awslabs.core-mcp-server (already installed, skipping)

Installing servers...
  [1/4] aws-knowledge-mcp .............. ✓
  [2/4] awslabs.aws-documentation-mcp-server  ✓
  [3/4] awslabs.diagram-mcp-server ..... ✓
  [4/4] awslabs.iac-mcp-server ......... ✓

Summary: 4 installed, 1 skipped (already installed), 1 deduplicated
```

### Remove Operation
```
MCP Server Remover
==================

Patterns: PRICING
Removing: 2 servers

  [1/2] awslabs.aws-pricing-mcp-server .. ✓ removed
  [2/2] awslabs.cost-analysis-mcp-server  ✓ removed

Summary: 2 removed
```

### List Operation (all patterns)
```
Available Patterns:
  AWS            (4 servers)  Base AWS development
  CDK            (1 server)   AWS CDK projects
  TERRAFORM      (2 servers)  Terraform IaC projects
  DOCUMENTATION  (3 servers)  Documentation lookup and generation
  ARCHITECTURE   (2 servers)  Architecture and design work
  SECURITY       (2 servers)  Security scanning and compliance
  KUBERNETES     (1 server)   General Kubernetes management
  CROSSPLANE     (1 server)   Crossplane and Upbound
  PRICING        (2 servers)  Cost modeling (temporary use)
  GIT            (1 server)   Local Git repository operations
  GITHUB         (2 servers)  GitHub API + local Git operations
  SERVERLESS     (1 server)   Lambda, API Gateway, Step Functions

Usage: bash install_mcp.sh PATTERN [PATTERN...]
       bash install_mcp.sh --remove PATTERN [PATTERN...]
       bash install_mcp.sh list [PATTERN]
```

### List Operation (specific pattern)
```
Pattern: AWS (4 servers)
  Base AWS development

  awslabs.core-mcp-server              Core AWS API orchestration (uvx, stdio)
  aws-knowledge-mcp                    AWS knowledge base (http)
  awslabs.aws-documentation-mcp-server AWS documentation search (uvx, stdio)
  awslabs.diagram-mcp-server           Architecture diagrams (uvx, stdio)
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No arguments | Show usage/help, exit 0 |
| Unknown pattern name | Error message + list valid patterns, exit 1 |
| `claude` CLI missing | Error message, exit 1 |
| `uvx`/`npx` missing (needed) | Error message listing missing tools, exit 1 |
| Docker not running (needed) | Warning, skip docker-based servers, continue |
| `claude mcp add` fails | Report error for that server, continue with remaining |
| `claude mcp remove` fails (not installed) | Warning, continue |
| `claude mcp list` fails | Assume no servers installed, proceed with install |

## File Organization

```
mcp/
├── install_mcp.sh                     ← the script (single file, self-contained)
├── prd.md                             ← this project's requirements
├── progress.txt                       ← feature tracking
└── docs/
    └── ARCHITECTURE_AND_DESIGN.md     ← this file
```

## Out of Scope

- **User-scope installation**: All installations are project-scoped. Users who want user-scope can manually run `claude mcp add -s user ...`.
- **Version pinning**: @latest is used for all servers. If a breaking change is introduced, users update the script.
- **Custom patterns**: Users who need custom groupings modify the script directly.
- **Server configuration**: The script installs servers with default config. Advanced config (API keys, custom endpoints) is done separately.
- **Windows**: Bash script. WSL users can run it, but no native Windows support.
- **MCP server health checks**: The script installs but does not verify servers are functional after installation.
