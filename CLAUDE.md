# CLAUDE.md

## Tool-Specific Guidance

### Mermaid Diagrams (mcp__mermaid-mcp)

- Use `<br/>` for line breaks inside node labels. `\n` is rendered as literal text, not a newline.

<!-- BEGIN DEFENSIVE-PROTOCOL-V2 -->
## Active Rules — Defensive Protocol v2

Loaded rules: `.claude/rules/defensive-protocol-v2-anti-slop.md`, `.claude/rules/defensive-protocol-v2-epistemology.md`, `.claude/rules/defensive-protocol-v2-session-management.md`

### Hard Behaviors (enforced by hooks)

- **Destructive Bash commands** (`rm -rf`, `git push --force`, `git reset --hard`, `git rebase`, `git branch -D`, `git commit --amend`, `DROP`, `migrate`) — paused for user confirmation before execution.
- **`chmod +x` / executable-bit modes** — hard-blocked (`exit 2`). Always invoke scripts with `bash script.sh`, never `./script.sh`.
- **Write / Edit / MCP tool calls** — advisory reminder fires before any overwrite or delete.
- **Tool failures** — FAILED/THEORY/PROPOSE reminder injected after the failure.

### Soft Behaviors (rule text — self-applied)

- **Autonomy check** — before significant decisions, evaluate blast radius and reversibility; ask when wrong costs more than waiting.
- **Contradiction handling** — when instructions conflict, surface the conflict explicitly rather than silently picking one.
- **Pushing back** — state concern concretely, share missing information, propose alternative, defer to user.
- **Chesterton's Fence** — before removing or changing anything, articulate why it exists. Prove it's unused before touching.

### State File Paths

- Investigations: `agents/investigations/`
- Session memory / handoffs: `agents/memory/`
- Scratch / disposable analysis: `scratch/`
<!-- END DEFENSIVE-PROTOCOL-V2 -->

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
