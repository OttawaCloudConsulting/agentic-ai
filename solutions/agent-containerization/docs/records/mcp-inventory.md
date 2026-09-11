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

## SF-7 — the gate, T29/T32

**The gate.** `images/mcp-gate.js`, invoked by `images/entrypoint.sh` after the home seed and the
R4.5 `config.toml` merge, before anything the agent itself runs. Reads
`/opt/agent-pack/mcp-inventory.json` (this agent's SF-6 output) and the fixed, per-agent file set
resolved above. Exit 0: every live `mcpServers`/`mcp_servers` entry it finds is inventoried and its
canonical (sorted-key JSON) hash matches `capability_baseline.config_sha256`. Exit 3: an
uninventoried entry, or a hash mismatch — one `mcp-gate: REFUSED ...` or `mcp-gate: DRIFT ...` line
per finding, both carrying `(R7.14, T29)`. Exit 2: the inventory or a capability-declaration file
exists but does not parse — fails closed rather than silently skipping a file it cannot read.

**Skill-bundle resolution (closing the item above).** The gate compares the existing bundle-level
marker (`codex`'s `.codex-system-skills.marker`, `agy`'s `.checksum`) against a single inventory
entry named for the whole bundle (`codex-system-skills`, `agy-builtin-skills`) — the coarser of the
two options, chosen because it is the only one with an image-side integrity anchor already in
place; a per-directory hash would have nothing on the agent's own side to compare against without
the gate computing and trusting its own first-seen value, which is not an integrity check. `claude`
carries no bundle marker (its plugin directory is empty in every observed volume), so absent a
marker the gate falls back to hashing the directory's own sorted file listing — the coarsest
available baseline, and a recorded limitation: a same-set file rewrite with no name change would
not drift.

**T29 — verified** (`tests/acceptance/verify-mcp-inventory.sh`, Phase C), against real `claude`,
`codex` and `agy` containers: an uninventoried server refuses the *next* start (not the one that
wrote it) at exit 3, naming both the file and the entry; a drifted `codex` `mcp_servers` entry
refuses with both hashes named; a matching entry passes across two consecutive starts, confirming
`codex`'s own per-start `config.toml` rewrite (`cli_auth_credentials_store`) produces no false
drift, because the gate hashes only the `[mcp_servers.<name>]` table's own keys; the skill-bundle
path is exercised for both `codex` and `agy`.

**T32 — verified, gap confirmed** (Phase D): writing an uninventoried `mcp_servers`/`mcpServers`
entry from inside a running container always succeeds — nothing in this design intercepts a
mid-session write to `~/.claude/.claude.json`, `~/.codex/config.toml` or
`~/.gemini/config/mcp_config.json`. This is the recorded gap: **a running session may already have
loaded an entry the gate would refuse.** The *next* start is refused, per agent, which is what
Phase D asserts as the closing half of T32.

**Proposed T32 amendment.** The gap above is a start-time-only enforcement boundary, accepted for
this feature (Edge Cases table: "Not blocked at write. Refused at the next start. The recorded
limitation is that a running session may already have loaded it"). Closing it in-session would need
either a filesystem watch inside each agent's container reacting to a write with a mid-session
refusal (a new component, and a race against whatever the agent already did with a newly loaded
server before the watch fires), or the agent CLI itself gating server load against the inventory
(upstream, out of this project's control for `claude` and `agy`; `codex` is the one candidate where
a wrapper could interpose, since its `config.toml` is already rewritten by this project's own
entrypoint). Proposed for a future milestone, not built here: route through `/milestone` revision
mode rather than adding an in-session watcher under this feature's scope, per the named-fallback
convention this feature's Sub-Features section already uses for scope growth.

## T31 assessment (re-verified, Feature 02.3 SF-8)

T31's scope is "no npm/yarn/PyPI/Go-proxy FQDN appears in any resolved artifact, and `npx` is
absent from every image" — the same npm-registry-widening property Milestone 01 established for
the base pod, re-verified here against every profile this feature adds (`tests/acceptance/verify-mcp-inventory.sh`
Phase B, run against `default`, `terraform`, `kubernetes` and `github`'s committed artifacts and
built images).

**Result: holds on every committed profile.** No `registry.npmjs.org`, `registry.yarnpkg.com`,
`pypi.org`/`files.pythonhosted.org` or `proxy.golang.org` entry appears in any of the six committed
resolved artifacts, and `npx` is absent from every built image (`claude`, `codex`, `agy`, across
all four profiles). None of the three packs this feature ships names a package-registry FQDN:
Terraform reaches HashiCorp's own release/registry infrastructure (assessed separately, R14.1),
`kubectl`/`helm` reach nothing at runtime, and `gh` reaches GitHub's API/web hosts, not a package
registry. Loading any of the three shipped profiles therefore does not reopen the `npx <server>`
arbitrary-install channel T31 exists to keep closed.

**Recorded residual: `github.com`.** The `github` profile's runtime egress includes `github.com`
itself (source hosting, not a package registry), which lets an agent `git clone`/`curl` arbitrary
source from GitHub and run it with `node` (already present in every image). This is **not new** --
`codex`'s 01.1 base already carries `github.com`/`api.github.com` with `upgrade: false` on every
profile including `default` (Decision 4's overlap case), so `codex` could already do this before
02.3 shipped. What `github` changes is scope: it extends the same reach to `claude` and `agy`,
which had no `github.com` entry under any profile before this feature. This is **not** T31's own
failure mode -- it is not `npx <server>` against an npm registry, and `lint-policy.sh`'s T31 check
(package-registry FQDNs specifically) correctly does not flag it -- but it is a real widening of
what a compromised `claude` or `agy` session can fetch and execute under the `github` profile, and
it is recorded here rather than left implicit. No stated requirement or acceptance criterion asks
this to be closed; `github.com`'s presence is inherent to what the GitHub CLI needs to reach for
API operations that redirect through git's smart-HTTP protocol on the same host.
