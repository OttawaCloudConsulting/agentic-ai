# Adding AWS MCP Servers to Claude Code

This guide explains how to add the AWS MCP servers to Claude Code CLI for enhanced AWS infrastructure-as-code capabilities.

## Prerequisites

- Claude Code CLI installed (`claude` command available)
- Python `uv`/`uvx` installed (for the IAC MCP server)

## MCP Servers to Add

| Server | Type | Purpose |
|--------|------|---------|
| `aws-knowledge-mcp` | HTTP | AWS documentation search, regional availability, best practices |
| `awslabs.aws-iac-mcp-server` | stdio | CDK best practices, CloudFormation validation, deployment troubleshooting |

---

## Installation Commands

### 1. AWS Knowledge MCP Server (HTTP)

```bash
claude mcp add aws-knowledge-mcp --transport http https://knowledge-mcp.global.api.aws
```

### 2. AWS IAC MCP Server (stdio via uvx)

```bash
claude mcp add awslabs-aws-iac-mcp-server -- uvx awslabs.aws-iac-mcp-server@latest
```

**With environment variable for reduced logging:**

```bash
claude mcp add awslabs-aws-iac-mcp-server -e FASTMCP_LOG_LEVEL=ERROR -- uvx awslabs.aws-iac-mcp-server@latest
```

---

## Verify Installation

List all configured MCP servers:

```bash
claude mcp list
```

You should see both servers listed:

```
aws-knowledge-mcp: https://knowledge-mcp.global.api.aws (http)
awslabs-aws-iac-mcp-server: uvx awslabs.aws-iac-mcp-server@latest (stdio)
```

---

## Configuration File Location

Claude Code stores MCP configuration in:

- **macOS**: `~/.claude/claude_desktop_config.json` or `~/.config/claude/settings.json`
- **Linux**: `~/.config/claude/settings.json`

You can also manually edit this file to add MCP servers.

### Manual Configuration Example

```json
{
  "mcpServers": {
    "aws-knowledge-mcp": {
      "type": "http",
      "url": "https://knowledge-mcp.global.api.aws"
    },
    "awslabs-aws-iac-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.aws-iac-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "type": "stdio"
    }
  }
}
```

---

## Testing the Servers

Start Claude Code and verify the servers are working:

```bash
claude
```

Then ask Claude to:

1. **Test AWS Knowledge MCP**: "Search AWS documentation for Fargate security best practices"
2. **Test AWS IAC MCP**: "Get CDK best practices for this project"

---

## Troubleshooting

### Server not connecting

1. Check if `uvx` is installed: `which uvx`
2. If missing, install with: `pip install uv` or `brew install uv`

### HTTP server errors

The AWS Knowledge MCP server requires internet access. Ensure you're not behind a proxy that blocks the connection.

### Remove a server

```bash
claude mcp remove aws-knowledge-mcp
claude mcp remove awslabs-aws-iac-mcp-server
```

---

## Capabilities Provided

### AWS Knowledge MCP Server

- `search_documentation` - Search AWS docs across multiple topics
- `read_documentation` - Fetch and convert AWS doc pages to markdown
- `get_regional_availability` - Check service/API availability by region
- `list_regions` - Get all AWS regions
- `recommend` - Get related documentation recommendations

### AWS IAC MCP Server

- `cdk_best_practices` - CDK security guidelines and patterns
- `search_cdk_documentation` - Search CDK constructs and APIs
- `validate_cloudformation_template` - Lint CloudFormation templates (cfn-lint)
- `check_cloudformation_template_compliance` - Security/compliance validation (cfn-guard)
- `troubleshoot_cloudformation_deployment` - Diagnose deployment failures
- `read_iac_documentation_page` - Read IaC documentation

---

## Reference

- [Claude Code MCP Documentation](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [AWS MCP Servers GitHub](https://github.com/awslabs/mcp)
