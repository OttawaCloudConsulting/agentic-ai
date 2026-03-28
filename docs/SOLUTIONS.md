# Solutions Reference

Solutions are multi-construct kits that combine agents, skills, MCP configurations, and documentation into a complete workflow. Each solution ships as a self-contained directory under `solutions/` and installs by copying files to the consumer project.

Solutions differ from standalone skills and commands: they orchestrate multiple agents and skills across phases, produce sets of deliverable documents, and include their own MCP server configurations.

## Quick Reference

| Solution | Invocation | Purpose | Details |
|---|---|---|---|
| AWS Well-Architected Review | `@war-orchestrator` | 4-phase AWS WAF review producing 14 deliverable documents from code and documentation | [View](solutions/WELL_ARCHITECTED_REVIEW.md) |

## How Solutions Work

- Solutions live in `solutions/<name>/` at the repository root
- Each solution directory contains:
  - `README.md` — install guide, prerequisites, usage, troubleshooting
  - `agents/` — agent definition files (`.md` with frontmatter)
  - `skills/` — skill bundles (same format as top-level `skills/`)
  - `mcp.json` — MCP server definitions (project-scoped)
  - `docs/` — architecture and design documentation
  - `prd.md` — product requirements document
  - `progress.txt` — build progress tracker
- Consumers install by copying agents, skills, and MCP config to three targets in their project

### Solution Kit Structure

```
solutions/<name>/
├── README.md                    ← install guide, prerequisites, usage
├── mcp.json                     ← MCP server definitions
├── prd.md                       ← product requirements
├── progress.txt                 ← build progress
├── docs/
│   └── ARCHITECTURE_AND_DESIGN.md
├── agents/
│   └── *.md                     ← agent definitions with frontmatter
└── skills/
    └── <skill-name>/
        └── SKILL.md             ← skill definitions with frontmatter
```

### Install Pattern

```bash
TARGET=/path/to/project

# 1. Copy agents
cp solutions/<name>/agents/*.md  $TARGET/.claude/agents/

# 2. Copy skills
cp -r solutions/<name>/skills/*  $TARGET/.claude/skills/

# 3. Copy MCP config (merge if .mcp.json already exists)
cp solutions/<name>/mcp.json  $TARGET/.mcp.json
```

## Consuming Solutions

Copy agents, skills, and MCP config from the solution directory into the target project. Each solution's README documents specific install steps, prerequisites, and verification.

Solutions take effect immediately on the next Claude Code conversation in the target repository.
