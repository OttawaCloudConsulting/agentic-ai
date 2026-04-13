# MCP probe specification

> Read by `skills/architecture-doc/SKILL.md` Step 3 (the MCP capability
> probe). Defines (a) how detected `mcp__`-prefixed tool names are
> categorised, (b) the deferred `run.log` line format used by Step 4, and
> (c) the per-run opt-in prompt text used later by Step 4.0
> (language-server enrichment) and Step 8 (diagram enrichment).

## Why heuristic matching, not a named allowlist

MCP servers vary by environment and turn over as servers are introduced
and old ones deprecated. A hard-coded allowlist of known server names
would silently drop a new or renamed server and lock the skill to one
environment. Instead, this file specifies **keyword heuristics** over the
`mcp__<server>__<tool>` name surface. The probe sees every detected tool;
unmatched tools fall into `other` rather than disappearing.

Coupling note (Decision #12): the probe relies on Claude Code surfacing
MCP tools as functions named `mcp__<server>__<tool>`. If that convention
changes upstream, both the probe enumeration in SKILL.md Step 3 and the
heuristics below break.

## Categories

The probe assigns each detected `mcp__`-prefixed tool to **exactly one**
category. Heuristics are applied in the order listed below; the first
match wins. Anything that does not match falls into `other`.

Comparison is **case-insensitive** and operates over the full tool name
(`mcp__<server>__<tool>`). A substring hit anywhere in the name is enough
unless the rule explicitly requires a paired keyword.

### `diagram` -- diagram rendering and visualisation

A tool is `diagram` if its lowercased full name contains any of:

- `mermaid`
- `plantuml` or `puml`
- `drawio`
- `graphviz` or (the standalone token) `dot`
- `diagram`
- `chart`

Consumed by Step 8 (diagram enrichment opt-in): embedded component /
data-flow diagrams in the produced architecture document, generated
before the Step 9 review loop. Per `CLAUDE.md`, Mermaid node labels
MUST use `<br/>` for line breaks; literal `\n` renders as text and
corrupts diagrams.

### `language_server` -- symbol / reference / type intelligence

A tool is `language_server` if its lowercased full name contains any of:

- `lsp`, `language-server`, or `language_server`
- `pyright`, `tsserver`, `gopls`, `rust-analyzer`, `clangd`, `jdtls`
- `definition` or `definitions`
- `references` (only when paired with `find`, `goto`, or `workspace`)
- `symbols` or `workspace-symbols`
- `hover`

Consumed by Step 4.0 (language-server enrichment opt-in): scan-time
symbol and reference resolution in the scan sub-agent, gated by user
opt-in before the scan agent is spawned.

Note: generic IDE-diagnostics tools (e.g. `mcp__ide__getDiagnostics`) are
intentionally **not** routed here. Diagnostics are adjacent to but not
the same as symbol-resolution surface, and Feature 9's scan enrichment
needs the latter, not the former. Such tools fall into `other`.

### `code_search` -- content search across the codebase

A tool is `code_search` if its lowercased full name contains any of:

- `code-search` or `code_search`
- `sourcegraph`
- `grep` (when not part of a generic shell tool)
- `search` paired with `code` or `repo`

Recorded in `run.log` for diagnostics. Not yet consumed by either
enrichment opt-in -- no prompt is shown for this category in this
iteration.

### `repo_intel` -- repository / VCS metadata access

A tool is `repo_intel` if its lowercased full name contains any of:

- `github`, `gitlab`, or `bitbucket`
- `pull-request`, `pull_request`, or `pr-`
- `issue` or `issues`
- `commit` paired with `repo`

Recorded in `run.log` for diagnostics. Not yet consumed by either
enrichment opt-in.

### `other`

Any `mcp__`-prefixed tool that did not match a category above. Recorded
in `run.log` so the probe never silently drops a detected tool.

## Categorisation matching rules

- Each tool is assigned to **exactly one** category. The first matching
  category in the order above wins; this avoids double-counting tools
  whose name happens to mention multiple keywords.
- An MCP server is considered "detected" if any of its tools is
  detected, but the probe records and categorises **tools, not servers**.
  The granularity in `run.log` is per-tool.
- Empty categories are not written to `run.log`.

## Run-log lines emitted by Step 4

The probe itself does not write to disk -- `run.log` does not exist when
Step 3 runs. Once Step 4 has created
`<target_path>/docs/.architecture-doc/run.log`, the orchestrator writes
the deferred probe results in the standard format
`<ISO8601> <level> <phase> <message>` (Decision #18, phase `probe`):

- One line per non-empty category, listing tool names comma-separated:

  ```
  2026-04-10T14:23:45Z INFO probe diagram=mcp__mermaid-mcp__generate,mcp__mermaid-mcp__validate
  2026-04-10T14:23:45Z INFO probe language_server=mcp__pyright__find-references
  ```

- One summary line listing the names of categories that had at least
  one detected tool:

  ```
  2026-04-10T14:23:45Z INFO probe summary categories=diagram,language_server
  ```

- If `probe.tools` was empty (no `mcp__`-prefixed tools detected at
  all), only a single summary line is written:

  ```
  2026-04-10T14:23:45Z INFO probe summary none-detected
  ```

## Per-run opt-in prompt text (used by Step 4.0 and Step 8)

Feature 9 (MCP-enriched synthesis) is per-run opt-in via
`AskUserQuestion` (Decision #17). The prompt text below is the canonical
source -- Step 4.0 reads the language-server prompt from this file, and
Step 8 reads the diagram prompt, rather than hardcoding strings into
SKILL.md so that prompt wording lands in one place.

`AskUserQuestion` headers must be ≤ 12 characters and a question may
offer at most 4 options.

### `diagram` enrichment prompt

Question:

> Detected one or more diagram-rendering MCP tools (e.g. Mermaid). Embed
> generated component and data-flow diagrams in the produced architecture
> document?

Options:

- **Embed** -- "Render and embed component + data-flow diagrams." (header: `Embed`)
- **Skip**  -- "Produce the document without diagrams." (header: `Skip`)

### `language_server` enrichment prompt

Question:

> Detected one or more language-server MCP tools. Use them in the scan
> sub-agent for improved symbol and reference resolution during file
> selection?

Options:

- **Use LSP** -- "Let the scan sub-agent call the language-server MCP." (header: `Use LSP`)
- **Skip**    -- "Run the scan with Read / Glob / Grep only." (header: `Skip`)

### Other categories

`code_search`, `repo_intel`, and `other` do not yet have enrichment
prompts. They are recorded in `run.log` for diagnostics only and may be
promoted to enrichments in a future iteration.
