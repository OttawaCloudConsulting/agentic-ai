# MCP Server Installer

Dynamic installer for Claude Code MCP servers. Manages servers in composable, pattern-based groups with project-scoped installation.

## Usage

```bash
bash install_mcp.sh PATTERN [PATTERN...]          # Install servers
bash install_mcp.sh --remove PATTERN [PATTERN...] # Remove servers
bash install_mcp.sh list [PATTERN]                # List patterns/servers
bash install_mcp.sh --help                        # Show help
```

Pattern names are case-insensitive.

## Patterns

| Pattern | Servers | Use Case |
|---------|---------|----------|
| **AWS** | core, knowledge, docs, diagrams | Base AWS development |
| **CDK** | iac (CDK + CloudFormation) | AWS CDK projects |
| **TERRAFORM** | HashiCorp Terraform, AWS Terraform | Terraform IaC projects |
| **DOCUMENTATION** | AWS docs, code doc gen, Context7 | Documentation lookup and generation |
| **ARCHITECTURE** | AWS diagrams, Mermaid | Architecture and design work |
| **SECURITY** | Trivy, AWS Well-Architected security | Security scanning and compliance |
| **KUBERNETES** | Red Hat kubernetes-mcp-server | General Kubernetes management |
| **CROSSPLANE** | Upbound controlplane-mcp-server | Crossplane and Upbound |
| **PRICING** | AWS pricing, cost analysis | Cost modeling (temporary use) |
| **GIT** | Anthropic server-git | Local Git repository operations |
| **GITHUB** | GitHub MCP + server-git | GitHub API + local Git operations |
| **SERVERLESS** | AWS serverless | Lambda, API Gateway, Step Functions |

Patterns are composable. Overlapping servers are deduplicated automatically.

## Examples

```bash
# Typical AWS CDK workflow
bash install_mcp.sh AWS CDK

# Terraform project
bash install_mcp.sh AWS TERRAFORM

# Add pricing for cost modeling, remove when done
bash install_mcp.sh PRICING
bash install_mcp.sh --remove PRICING

# See what a pattern includes
bash install_mcp.sh list SECURITY
```

## Prerequisites

The script checks for required tools before installing:

| Tool | Required By | Install |
|------|-------------|---------|
| `claude` | All operations | [Claude Code CLI](https://claude.ai/claude-code) |
| `uvx` | AWS, CDK, Terraform (AWS), Documentation, Security, Pricing, Serverless | `pip install uv` |
| `npx` | Documentation (Context7), Architecture (Mermaid), Kubernetes, Git, GitHub | Included with Node.js |
| `docker` | Terraform (HashiCorp), Crossplane | [Docker Desktop](https://www.docker.com/products/docker-desktop/) |
| `trivy` | Security (Trivy) | [Trivy install guide](https://aquasecurity.github.io/trivy/) |

Docker is a soft prerequisite — if not running, Docker-based servers are skipped with a warning.

## Design

- All installations use `-s project` scope (project-local, not global)
- Servers use `@latest` versions
- POSIX-compatible bash (no bash 4+ features required)
- ShellCheck clean, Google Shell Style Guide compliant
- Single self-contained script with no external config files
