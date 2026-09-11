# MCP Inventory — 02.3 SF-6 Measurement

**Requirement.** Feature plan `tool-pack-set-use-case-profiles-and-mcp-inventory.md`, SF-6:
"measure first, following 02.1 SF-1's pattern" — record each agent's capability-declaration files
and plugin/skill directories (path, write model, format, keying) before the schema and the T29 gate
(SF-7) are designed. Also resolves, by observation, the path disagreement the Approach section
flagged for `claude` (`.claude.json` vs `settings.json`) and `agy` (`~/.gemini/settings.json` vs
`~/.gemini/antigravity-cli/settings.json`).

**Method.** Read-only inspection (operator consent obtained) of the three real seed volumes —
`sandboxed-agent-pod_claude-state`, `_codex-state`, `_agy-state` — via a throwaway
`docker run --rm -v <volume>:/v:ro busybox`, no container started, no write. Volumes carry state
from real sessions since 01.4.

## Per-agent findings

| | `claude` | `codex` | `agy` |
|---|---|---|---|
| **Capability-declaration file** | `~/.claude/.claude.json` (`CLAUDE_CONFIG_DIR=/home/agent/.claude`, `Dockerfile:258`) | `~/.codex/config.toml` | `~/.gemini/config/mcp_config.json` |
| **Write model** | Whole-file rewrite by the agent on every session (`lastStartTime`, `lastDuration` etc. change each run) | Whole-file rewrite by our entrypoint on every start (`entrypoint.sh:26,43,68` merge/seed `config.toml`), then further rewritten by the agent during the session | Present but empty (0 bytes) in every observed volume — never yet written by a session that added a server |
| **Format** | JSON | TOML, `[mcp_servers.<name>]` tables | JSON |
| **Entry keying** | Per-project: `.projects["<cwd>"].mcpServers.<name>` (also `.projects["<cwd>"].enabledMcpjsonServers` / `disabledMcpjsonServers`, which track project-level `.mcp.json` approvals) | Table key `[mcp_servers.<name>]` | Not yet observed populated; `mcp_config.json` is the documented location for the CLI's `mcpServers` map, keyed by server name |
| **`settings.json` MCP content** | `~/.claude/settings.json` exists (`{"theme":"dark"}`) — **confirmed empty of MCP data.** Not the capability-declaration file | n/a | `~/.gemini/settings.json` and `~/.gemini/antigravity-cli/settings.json` are byte-identical (`{"modelProvider":"gemini"}`) — **confirmed empty of MCP data.** Neither is the capability-declaration file |
| **Plugin/skill directories** | `~/.claude/plugins/marketplaces/` — empty in every observed volume | `~/.codex/skills/.system/{skill-creator,plugin-creator,imagegen,skill-installer,review-agent,openai-docs}/`, each a directory (`SKILL.md`, `agents/`, `assets/`, `references/`, `scripts/`) | `~/.gemini/antigravity-cli/builtin/skills/{agy-customizations,antigravity_guide,migrate-workflows,permissioned-github,generative_ui}/` |
| **Skill-bundle integrity anchor observed** | none — directory is empty | `~/.codex/skills/.system/.codex-system-skills.marker` — **one hash for the whole bundle** (`bc5732fbeeda1d0c`), not per-skill | `~/.gemini/antigravity-cli/builtin/.checksum` — same shape: one bundle-level checksum, not per-skill |
| **Project-level file the gate always includes (claude only, per Contract 6)** | `/workspace/.mcp.json` — project-mount path, not in the state volume; not present in any of the observed sessions (no project defined one) | — | — |

## `.claude.json` vs `settings.json` — resolved

`settings.json` under `CLAUDE_CONFIG_DIR` carries only UI preference (`theme`). Every MCP field
(`mcpServers`, `enabledMcpjsonServers`, `disabledMcpjsonServers`, `mcpContextUris`) lives on
`.claude.json`, under the per-project key. The gate enumerates `.claude.json`, not `settings.json`.

## `agy` settings-file duplication — resolved

`~/.gemini/settings.json` and `~/.gemini/antigravity-cli/settings.json` are the same content
(`modelProvider` only) in every observed volume — neither carries MCP entries. The actual MCP
servers map is `~/.gemini/config/mcp_config.json`, confirmed by the CLI's own config layout
(`~/.gemini/config/` also holds `config.json` and `projects/default-cli-project.json`, siblings in
the same directory). The gate enumerates `mcp_config.json`.

## Live-volume inspection result: no entries to resolve

All three seed volumes carry **empty** MCP state at the time of this measurement:
`claude`'s `.projects."/".mcpServers` is `{}`, `codex`'s `config.toml` has no `[mcp_servers.*]`
table, and `agy`'s `mcp_config.json` is a zero-byte file. Per the operator consent obtained for this
inspection, no entry required resolution (inventory-or-remove) before SF-7's gate lands — the
first-start refusal edge case (no grandfathering) has nothing live to refuse today.

`claude`'s volume does carry `~/.cache/claude-cli-nodejs/-/mcp-logs-claude-ai-{Gmail,lastminute-com,
Google-Drive,ZOHO-OCC-Ottawa-Cloud-Consulting,Expedia,Google-Calendar}/` — these are **log residue**
from prior connector sessions run against this machine's own Claude account state, not live
capability declarations, and are not enumerated by the gate. Recorded so a future reviewer does not
mistake cached log directory names for configured servers.

## Recorded as still open

The skill-bundle integrity anchors for `codex` and `agy` are **one checksum per bundle**, not one
hash per skill entry — `capability_baseline.config_sha256` (Interface Contract 5) is specified per
server/skill *entry*. SF-7's gate design must decide whether a skill directory's baseline is the
existing bundle-level marker (coarser: any change to any skill in the bundle drifts together) or a
per-directory hash computed fresh (finer, but with no existing image-side precedent to anchor it
to). Not resolved here — SF-6 records the shape; SF-7 builds the gate.
