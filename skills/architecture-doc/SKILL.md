---
name: architecture-doc
description: >
  Produce or audit `docs/ARCHITECTURE_AND_DESIGN.md` for any codebase, standalone
  from the `/project` flow. Create mode reverse-engineers an architecture
  document from source for repos that lack one; Audit mode updates an existing
  document in place against the current code. Use when there is no architecture
  document and one is needed, when an existing architecture doc has drifted from
  the code, or when the user asks to "document this architecture", "reverse
  engineer the architecture", "create an architecture doc", or "audit the
  architecture doc against the current code". Operates on the current working
  directory by default; accepts an optional positional `target_path` argument.
disable-model-invocation: false
---

# /architecture-doc -- Standalone Architecture Documentation

Produces or maintains `docs/ARCHITECTURE_AND_DESIGN.md` for any codebase,
independent of the `/project → /define → /design` flow. Two modes:

- **Create** -- the document does not exist (or the user opted to overwrite).
  A scan sub-agent reads the code; a synthesis sub-agent writes a fresh
  document conforming to the canonical template at
  `skills/project/design/assets/architecture-template.md`.
- **Audit** -- the document already exists. The same scan runs, but the
  synthesis sub-agent preserves user-authored content by returning the full
  updated document inline for the orchestrator to write.

Both modes share the scan pipeline and diverge only in the synthesis
sub-agent. The skill opportunistically uses any MCP servers detected in the
session to enrich its scan and synthesis, and degrades gracefully when none
are present.

The authoritative design for this skill lives in
`docs/ARCHITECTURE_AND_DESIGN.md` **at the root of the `agentic-ai` repository
that hosts this skill** -- not the `docs/ARCHITECTURE_AND_DESIGN.md` this
skill produces at `target_path`. The two files share a filename but are
unrelated artifacts. Maintainers editing this orchestrator should read the
former.

## Rules

- **Read fresh every time.** Re-check the existing document on every
  invocation; never trust cached state from a prior run.
- **Mode is user-confirmed when ambiguous.** Existing-document detection must
  always go through `AskUserQuestion` before overwriting or editing an
  existing file. Absent files enter Create mode silently.
- **Path-bounded scan.** The scan sub-agent reads only paths inside the
  resolved `target_path`. Symlinks in `target_path` itself are tolerated;
  symlinks encountered during scan-time enumeration are never followed
  (Decision #9).
- **Never modify source code.** This skill is documentation-only. Output is
  restricted to `docs/ARCHITECTURE_AND_DESIGN.md` and the ephemeral scratch
  directory `docs/.architecture-doc/`.
- **Interactive prompts.** Use `AskUserQuestion` for all user-facing choices
  (max 2-4 options, ≤12-character headers).
- **No auto-dispatch.** Tell the user what to run next. Never auto-invoke
  another skill.

## Prerequisites

- A directory containing source code, supplied as `target_path` or defaulted
  to the current working directory.
- The canonical template at
  `skills/project/design/assets/architecture-template.md` and the canonical
  scan heuristics at
  `skills/project/design/references/gate-2-design.md` must be readable from
  the running session. The skill aborts with an explicit error if either is
  missing -- there is no vendored fallback (Decision #4, Decision #5).

## Step 1 -- Resolve and validate `target_path`

1. If the user supplied a positional argument to `/architecture-doc`, take
   that as `target_path`. Otherwise default to the current working directory.
2. Resolve `target_path` to its absolute, canonical form. Symlinks **in the
   path itself** are followed and tolerated (a user invoking the skill from a
   symlinked project root is supported -- Decision #9 relaxation, Data Flow
   step 2).
3. Confirm the resolved path:
   - exists, and
   - is a directory.
4. If either check fails, abort with a one-line error explaining which check
   failed and the resolved path. Do not create the scratch directory; do not
   proceed to Step 2.

The resolved absolute path is the working `target_path` for every later step
and is the prefix used by the scan sub-agent for path-boundary enforcement.

## Step 2 -- Existing-document detection and mode selection

This step runs **before** any other work -- before the MCP probe, before
scratch setup, before spawning any sub-agent.

1. Compute `doc_path = <target_path>/docs/ARCHITECTURE_AND_DESIGN.md`.
2. Test whether `doc_path` exists.
   - **Absent** → set `mode = Create` and proceed to Step 3. No prompt.
3. If present, attempt to read the file and apply the **plausibly Markdown**
   heuristic:
   - The file is readable as UTF-8 text, **and**
   - the file is non-empty, **and**
   - the first non-blank line begins with `#` (Markdown ATX heading).
4. Branch on the heuristic:
   - **Plausibly Markdown** → call `AskUserQuestion` with three options:
     - **Create** -- "Overwrite the existing document with a freshly produced one." (header: `Create`)
     - **Audit** -- "Update the existing document in place, preserving user-authored content." (header: `Audit`)
     - **Abort** -- "Stop without changing anything." (header: `Abort`)

     Set `mode` from the user's choice. On **Abort**, exit cleanly with a
     one-line message. On **Create**, the existing document will be
     overwritten by the synthesis sub-agent in a later step.
   - **Not plausibly Markdown** (unreadable, empty, or does not begin with a
     Markdown heading) → call `AskUserQuestion` with **only two** options:
     - **Overwrite** -- "Replace the existing file with a freshly produced architecture document." (header: `Overwrite`)
     - **Abort** -- "Stop without changing anything." (header: `Abort`)

     **Audit is not offered** in this branch because the file cannot be
     reliably parsed or extended. Set `mode = Create` if the user chose
     Overwrite; exit cleanly on Abort.
5. After Step 2 completes, `mode ∈ {Create, Audit}` and the orchestrator
   proceeds to Step 3.

Implementation notes:

- "Readable as UTF-8" is determined by attempting `Read` on the file. A
  failure or a binary-content indication counts as not plausibly Markdown.
- "First non-blank line" means the first line whose content, after stripping
  whitespace, is non-empty. Leading blank lines are ignored.
- **Known limitation -- YAML frontmatter is rejected.** A Markdown file that
  opens with a YAML frontmatter block (`---\ntitle: ...\n---\n\n# Heading`)
  fails the heuristic because its first non-blank line is `---`, not a
  Markdown ATX heading. Such files are routed to the **Not plausibly
  Markdown** branch and Audit is not offered. This is intentional: the
  canonical template at `skills/project/design/assets/architecture-template.md`
  does not use frontmatter, so the common case is unaffected. If a user needs
  Audit on a frontmatter-bearing doc, they can strip the frontmatter and
  re-run, or choose Overwrite.
- Mode selection is recorded only in the orchestrator's in-context state for
  this run. It is not written to disk in this step (`run.log` does not yet
  exist -- it is created in the scratch-setup step that belongs to a later
  feature).

## Step 3 -- MCP capability probe

This step runs after Step 2 (mode is set) and **before** Step 4 (scratch
setup). It does **not** write anything to disk because `run.log` has not yet
been created -- the deferred writes happen at the start of Step 4. Probe
results are held in orchestrator context throughout.

The probe discovers what enrichment tools are available in this session so
that Step 4.0 (language-server enrichment opt-in) and Step 8 (diagram
enrichment opt-in) can present accurate per-run opt-in prompts -- the
two halves of Feature 9. Per Decision #12, the probe is performed in
the orchestrator context with no probe sub-agent.

1. **Enumerate `mcp__`-prefixed tools.** Inspect the set of tools currently
   available to the orchestrator in this session. List every tool whose name
   begins with the prefix `mcp__`. Claude Code's MCP integration surfaces
   each MCP tool as a function named `mcp__<server>__<tool>`; the probe
   reads its own tool surface, not any external configuration file. The
   probe is intentionally **dynamic** -- it does not consult a hardcoded
   list of known servers, so new servers in the session are seen
   automatically and removed servers vanish from the result without code
   changes.
2. **If no `mcp__` tools are present**, set the in-context structure to
   `probe = { tools: [], categories: {} }`. The skill must continue to
   produce a full document with Read / Glob / Grep / Bash only; no warning
   is shown to the user, no degradation banner appears in the output.
   Proceed directly to Step 4.
3. **Categorise.** Read `references/mcp-probe.md` and apply its
   categorisation heuristics to each detected tool name. Each tool is
   assigned to **exactly one** category; the first matching category in the
   reference file's order wins; anything unmatched falls into `other`.
   Comparison is case-insensitive over the full `mcp__<server>__<tool>`
   name.
4. **Build the in-context probe structure** in the orchestrator:

   ```
   probe = {
     tools: ["mcp__mermaid-mcp__generate", ...],
     categories: {
       diagram:         ["mcp__mermaid-mcp__generate", ...],
       language_server: [...],
       code_search:     [...],
       repo_intel:      [...],
       other:           [...]
     }
   }
   ```

   Empty categories may be omitted from or kept in the structure -- both
   are acceptable. The categories that drive enrichment prompts in this
   iteration are `diagram` and `language_server`; the remaining categories
   are recorded for diagnostics only.
5. **Do not write to disk in this step.** The probe entries that belong in
   `run.log` are emitted by Step 4 immediately after the scratch directory
   and `run.log` are created. The exact `run.log` line format -- one entry
   per non-empty category plus a summary line, or a single
   `none-detected` summary line if `probe.tools` is empty -- is specified
   in `references/mcp-probe.md` under "Run-log lines emitted by Step 4".
6. Proceed to Step 4.

Implementation notes:

- Coupling risk (Decision #12): the probe relies on the
  `mcp__<server>__<tool>` naming convention. If that convention changes
  upstream, both the probe enumeration and the categorisation heuristics
  in `references/mcp-probe.md` break. This is the price of the
  cheapest-possible probe; the alternative -- a probe sub-agent making
  trial calls -- was rejected in Decision #12.
- The categories `code_search`, `repo_intel`, and `other` are recorded
  for diagnostics in `run.log` but **not** consumed by either enrichment
  opt-in -- only `diagram` (consumed by Step 8) and `language_server`
  (consumed by Step 4.0) drive enrichment prompts. This keeps the
  Feature 9 surface narrow without losing detection coverage; the
  unused categories remain available for future enrichments.

## Step 4 -- Scratch setup, run.log init, and scan sub-agent spawn

This step closes the Feature 3 deferred-write contract (writing the MCP
probe results to `run.log` once `run.log` exists), fires the
language-server enrichment opt-in (Feature 9, half of the Decision #17
opt-ins), spawns the scan sub-agent via the Agent tool, handles
preflight aborts and monorepo confirmation, runs a post-hoc
path-boundary check, and runs a secrets redaction pass over
`findings.md` before handing off to synthesis.

The scan sub-agent itself follows
`skills/architecture-doc/references/scan-agent-prompt.md`. The
orchestrator constructs the spawn prompt from that file and never
in-lines the scan logic itself.

### Step 4.0 -- Language-server enrichment opt-in (conditional)

This substep is the **scan-side half** of Feature 9. The diagram-side
half (Mermaid embedding) fires later in Step 9, after the review loop
has approved the textual content. Both opt-ins are governed by
Decision #17 (per-run opt-in) and use the canonical prompt copy in
`references/mcp-probe.md` (Per-run opt-in prompt text section).

The language-server opt-in MUST fire **here**, before Step 4.5
constructs the scan agent spawn prompt, because the opt-in result
gates whether language-server tool names are passed to the scan
agent via the `{{MCP_TOOLS_LIST}}` substitution marker.

1. Inspect `probe.categories.language_server` from Step 3.
2. If the list is empty (no language-server MCP detected), set
   `enrichment_choices.language_server = false` in orchestrator state
   and skip the rest of this substep -- proceed directly to Step 4.1.
   No prompt is shown to the user; this preserves the "baseline path
   unchanged when no enriching MCPs are present" guarantee from PRD
   Feature 8.
3. If the list is non-empty, read the canonical prompt copy from
   `references/mcp-probe.md` under the heading
   `### \`language_server\` enrichment prompt`. Use the question text
   and the two options (`Use LSP` / `Skip`) verbatim -- the
   reference file is the single source of truth for prompt wording so
   future copy edits land in one place.
4. Call `AskUserQuestion` with that question and those two options.
5. Branch on the user's choice:
   - **Use LSP**: set `enrichment_choices.language_server = true`.
     Hold the comma-separated list of detected language-server tool
     names in orchestrator state for Step 4.5's substitution.
   - **Skip**: set `enrichment_choices.language_server = false`. The
     scan agent will run with its baseline tool allowlist only.
6. The result is **not** written to `run.log` here -- `run.log` does
   not exist yet (Step 4.2 has not run). Hold the choice in
   orchestrator state and let Step 4.3 emit the deferred log line
   alongside the deferred probe writes. The deferred-write pattern is
   already established by the Feature 3 probe; reusing it keeps Step
   4 internally consistent.

Note that this substep does **not** depend on `<scratch_dir>` or
`run.log` existing. It runs cleanly even if Step 4.1 has not been
reached yet. The numbering (`4.0`) reflects "before everything else
in Step 4".

### Step 4.1 -- Create scratch directory

Create `<scratch_dir> = <target_path>/docs/.architecture-doc/`
(Decision #6).

- If `<target_path>/docs/` does not exist, create it (`mkdir -p`).
  Creating `docs/` here is harmless even in Audit mode -- the directory
  must exist for the existing document to have been detected in Step 2.
- If `<scratch_dir>` already exists from a prior aborted run, reuse
  it -- do not error. Cleanup at the end of Step 10 will remove it.
- If creation fails (e.g. `docs/` exists as a file, permissions denied),
  abort with the OS error and the resolved path. Do not proceed.

### Step 4.2 -- Initialise run.log

Create `<scratch_dir>/run.log` and write a session-start entry per
Decision #18 (`<ISO8601> <level> <phase> <message>` format):

```
<ISO8601> INFO session start target_path=<target_path> mode=<Create|Audit>
```

`<ISO8601>` is the current UTC time in `YYYY-MM-DDTHH:MM:SSZ` form.
`<Create|Audit>` is the mode resolved by Step 2.

### Step 4.3 -- Write deferred MCP probe results

Honour the Feature 3 contract from
`references/mcp-probe.md` ("Run-log lines emitted by Step 4"):

- For every non-empty category in the in-context `probe.categories`
  structure built by Step 3, append one line:
  ```
  <ISO8601> INFO probe <category>=<comma-separated tool names>
  ```
- Append one summary line listing the names of categories that had at
  least one detected tool:
  ```
  <ISO8601> INFO probe summary categories=<comma-separated category names>
  ```
- If `probe.tools` was empty, append a single line and skip the
  per-category lines:
  ```
  <ISO8601> INFO probe summary none-detected
  ```

These writes complete the Feature 3 deferred-write obligation. The
in-context `probe` structure is preserved in orchestrator state because
Step 8 (MCP-enriched synthesis) consumes `probe.categories.diagram` to
drive the diagram-enrichment opt-in.

Then append the **deferred Step 4.0 opt-in result** -- this completes
the Feature 9 language-server deferred-write obligation, the same
pattern Step 3 uses for the probe itself:

- If `probe.categories.language_server` was non-empty AND the user
  was prompted in Step 4.0, append:
  ```
  <ISO8601> INFO probe enrichment_optin language_server=<accepted|skipped>
  ```
  where `<accepted|skipped>` reflects the user's choice in Step 4.0.
- If `probe.categories.language_server` was empty (no prompt was
  shown), do not write any line for this enrichment. The
  `none-detected` summary line above already conveys the absence.

### Step 4.4 -- Read prompt template and canonical heuristics

Read both files:

1. `skills/architecture-doc/references/scan-agent-prompt.md` -- the
   scan sub-agent prompt template.
2. `skills/project/design/references/gate-2-design.md` -- the canonical
   scan heuristics referenced by the prompt (Decision #4 -- read in
   place, no vendored fallback).

If either read fails, abort with an explicit error naming the missing
file. The skill aborts with an explicit error if either canonical file
is missing -- there is no vendored fallback (Decisions #4 and #5).

### Step 4.5 -- Construct the scan agent spawn prompt

Take the contents of `scan-agent-prompt.md`, strip the preamble (the
"Substitution markers" section above the `--- BEGIN PROMPT ---`
marker), keep only the body between `--- BEGIN PROMPT ---` and
`--- END PROMPT ---`, and substitute these tokens:

| Marker | Value |
|--------|-------|
| `{{TARGET_PATH}}` | The absolute, canonical `target_path` resolved in Step 1. |
| `{{MCP_TOOLS_LIST}}` | Comma-separated names of the language-server MCP tools the user opted in to in Step 4.0 -- i.e. the contents of `probe.categories.language_server` IF `enrichment_choices.language_server == true`, otherwise the literal `none`. **Diagram MCPs and other categories are NEVER passed to the scan agent**, even if detected: scan-side enrichment is language-server-only by design (Decision #17, Feature 9 acceptance criteria). The diagram MCP is consumed later in Step 8, in the orchestrator context, after synthesis and before the review loop. |
| `{{MONOREPO_ACKNOWLEDGED}}` | The literal `false` on first spawn. On a re-spawn after the user confirmed the monorepo warning in Step 4.7, the literal `true`. |
| `{{SCRATCH_DIR}}` | `<target_path>/docs/.architecture-doc` (no trailing slash). |

After substitution, no marker may remain in the prompt body. Verify by
searching for the literal `{{` -- if any remain, abort with an
internal error.

### Step 4.6 -- Spawn the scan sub-agent

Spawn the scan sub-agent via the `Agent` tool:

- `subagent_type`: `general-purpose`. The Claude Code Agent tool does
  not expose per-spawn tool allowlists, so the scan agent's tool
  restrictions are enforced by **prompt-level discipline** -- the
  prompt forbids `Edit`, `Write` outside the scratch path, `Agent`,
  network tools, and any `Bash` command other than `ls -R` and
  `git log --oneline -20`. This matches the house pattern in
  `skills/project/design/`.
- `description`: `Architecture scan of <basename(target_path)>`.
- `prompt`: the constructed prompt body from Step 4.5.

Log the spawn to `run.log`:

```
<ISO8601> INFO scan spawn subagent_type=general-purpose monorepo_acknowledged=<true|false>
```

### Step 4.7 -- Handle agent return and write findings.md

The scan agent's return text begins with a `STATUS:` line. Parse the
first line of the return and branch:

- **`STATUS: success files_scanned=<N_arch>+<N_docs>`**
  - Parse the two integers separated by `+`. `<N_arch>` is the number
    of architecture files read by the scan agent in Steps 3-4 of its
    prompt (15-30 budget); `<N_docs>` is the number of doc files read
    by the harvest in Step 5 of its prompt (0-15 budget).
  - Log: `<ISO8601> INFO scan return status=success arch_files=<N_arch> doc_files=<N_docs>`.
  - **Extract findings content.** Parse the agent's return text for the
    literal markers `--- BEGIN FINDINGS ---` and `--- END FINDINGS ---`.
    Extract everything between these markers (excluding the markers
    themselves). If either marker is missing or malformed, treat this as
    an error (see error branch below).
  - **Write findings.md.** Use the `Write` tool to write the extracted
    content to `<scratch_dir>/findings.md`. Log:
    `<ISO8601> INFO scan findings_written path=<scratch_dir>/findings.md`.
  - Both counts are surfaced in the final session summary printed by
    Step 10 (cleanup) so the user knows how much architecture vs.
    documentation context fed the produced doc.
  - Proceed to Step 4.8 (path-boundary post-validation).

- **`STATUS: preflight_abort reason=<empty|binary_only>`**
  - Log: `<ISO8601> WARN scan return status=preflight_abort reason=<reason>`.
  - Print a one-line user-facing message:
    `Scan aborted: <reason>. No document was produced.`
  - Jump to Step 10 (cleanup) and exit.

- **`STATUS: monorepo_warning signal=<signal>`**
  - Log: `<ISO8601> WARN scan return status=monorepo_warning signal=<signal>`.
  - Call `AskUserQuestion` with two options:
    - **Continue** -- "Treat the monorepo root as a single project and scan it." (header: `Continue`)
    - **Abort** -- "Stop without producing a document." (header: `Abort`)
  - On **Abort**: log `<ISO8601> INFO scan monorepo abort`, jump to Step
    10 (cleanup), and exit.
  - On **Continue**: log `<ISO8601> INFO scan monorepo acknowledged`,
    re-spawn the scan agent by repeating Steps 4.5 through 4.7 with
    `{{MONOREPO_ACKNOWLEDGED}}` set to `true`. The re-spawned agent will
    skip the monorepo check and proceed.

- **`STATUS: error reason=<description>`** (or any unparseable return,
  or missing `--- BEGIN FINDINGS ---` / `--- END FINDINGS ---` markers)
  - Log: `<ISO8601> ERROR scan return status=error reason=<description>`.
  - Print: `Scan agent failed: <description>. No document was produced.`
  - Jump to Step 10 (cleanup) and exit.

### Step 4.8 -- Path-boundary post-validation

Read `<scratch_dir>/findings.md` (written by Step 4.7). Locate the
`## Files Cited` section
at the tail of the file (the scan agent's prompt requires every cited
file to appear there exactly once, one path per line, with no leading
bullet, backtick, or commentary). For each path in that section:

1. Resolve to its absolute, canonical form via `realpath` (using `Bash`,
   the one place the orchestrator uses `Bash` for filesystem operations
   outside the scan agent).
2. Verify the resolved absolute path begins with `<target_path>/`
   (with the trailing slash, to prevent prefix-matching escapes like
   `<target>foo/`).
3. If any cited path fails the check, log:
   ```
   <ISO8601> ERROR scan path_boundary_violation cited=<original> resolved=<absolute>
   ```
   then print `Path boundary violation in scan findings: <cited>`,
   jump to Step 10 (cleanup), and exit. Do **not** proceed to synthesis
   with a tainted findings file.

This is a defence-in-depth check on top of the prompt-level boundary
rule in `scan-agent-prompt.md`. Decision #9 makes path boundary a
security control; the cost of post-hoc validation is acceptable.

### Step 4.9 -- Secrets redaction pass

Read `skills/architecture-doc/references/redaction-patterns.md` for the
canonical pattern list and the application rules. For each pattern in
the listed order, apply a regex replace over `findings.md`, replacing
matches with the literal string `[REDACTED]`. Track the per-pattern hit
count.

Log the result to `run.log`:

```
<ISO8601> INFO scan redacted findings.md hits=<total>
```

If `<total>` is greater than zero, also log a list of the matched
pattern names so a post-mortem can identify what category of secret the
scan agent attempted to write:

```
<ISO8601> WARN scan redaction findings.md patterns=<name1,name2,...>
```

The pattern list, log-line format, application order, and known
limitations all live in `redaction-patterns.md` -- this step is the
caller, not the source of truth. Synthesis Steps 6 and 7 will run an
analogous redaction pass over the produced architecture document.

After Step 4.9 completes, control passes to Step 5.

## Step 5 -- Existing-documentation harvesting

Runs **inside the scan sub-agent**, not in the orchestrator. The
orchestrator does nothing extra for this step -- the harvest is
encoded in `references/scan-agent-prompt.md` under "Step 5 --
Existing documentation enumeration". Operationally, after the scan
agent finishes Step 4 (read selected source files) it enumerates
in-repo documentation -- `README*`, `ARCHITECTURE*`, `DESIGN*`,
`CONTRIBUTING*`, `CHANGELOG*`, `RUNBOOK*`, ADR directories,
`docs/**/*.md|.mdx|.rst`, and diagram source files (`.mmd`,
`.drawio`, `.puml`, `.plantuml`) -- caps the harvest at **15 doc
files** (a separate budget from the 15-30 architecture file scan in
Step 3), summarises each in 1-3 sentences, and writes the results to
`findings.md` under the `## Existing Documentation` section in a
parseable bullet format.

Synthesis (Steps 6 and 7) consumes the `## Existing Documentation`
section of `findings.md` and is expected to cite source doc files
(by relative path) when a Design Decision, Component, or Data Flow
entry is drawn from existing documentation rather than from source
code. The exact citation discipline lives in the synthesis prompt
template and the canonical architecture template; this step only
guarantees that the existing-doc inventory is present in
`findings.md` for synthesis to draw on.

Doc files cited in the harvest also appear in the `## Files Cited`
tail of `findings.md`, which means the orchestrator's Step 4.8
path-boundary post-validation already covers them -- no separate
boundary pass is needed. The Step 4.9 secrets redaction pass over
`findings.md` likewise applies to harvest output, so a doc file that
embeds an example credential is sanitised before synthesis sees it.

## Step 6 -- Synthesis sub-agent: Create mode

This step runs only when `mode = Create` (resolved by Step 2). When
`mode = Audit`, skip Step 6 entirely and proceed to Step 7.

Step 6 spawns a synthesis sub-agent that reads `findings.md` (the
Step 4 output, already redacted by Step 4.9) plus the canonical
template, and writes a fresh `docs/ARCHITECTURE_AND_DESIGN.md` from
scratch via a single `Write` call. The synthesis sub-agent prompt
template lives at
`skills/architecture-doc/references/synthesis-agent-prompt.md`; the
orchestrator selects the `BEGIN CREATE` / `END CREATE` block,
substitutes tokens, and passes the body to the Agent tool.

After the agent returns, the orchestrator runs the post-synthesis
secrets redaction pass (Decision #8) and a structural validation
pass (six required section headers must be present).

### Step 6.1 -- Verify the canonical template exists

Decision #5 makes the canonical template a hard runtime dependency
with no vendored fallback. Verify before paying any synthesis cost:

1. Resolve the absolute path to
   `skills/project/design/assets/architecture-template.md` relative
   to the running session's location of the `agentic-ai` repo
   hosting this skill.
2. `Read` the file. If the read fails for any reason, abort with
   the explicit error:
   `Canonical architecture template missing: <resolved path>. The architecture-doc skill requires skills/project/design/assets/architecture-template.md to be readable; there is no vendored fallback (Decision #5).`
3. Log to `run.log`:
   ```
   <ISO8601> INFO synthesis template_ok path=<resolved path>
   ```

The template's content is not held in orchestrator state -- the
synthesis sub-agent will Read it itself. The orchestrator only
verifies existence so the run fails fast rather than after the
scan.

### Step 6.2 -- Read the synthesis prompt template and select the CREATE block

1. `Read skills/architecture-doc/references/synthesis-agent-prompt.md`.
2. Locate the literal markers `## --- BEGIN CREATE ---` and
   `## --- END CREATE ---`. Keep only the body between them; discard
   everything before `## --- BEGIN CREATE ---` (the substitution-marker
   preamble) and everything from `## --- END CREATE ---` onward
   (which includes the Audit block stub).
3. If either marker is missing, abort with an internal error naming
   the missing marker.

### Step 6.3 -- Substitute tokens

Apply token replacement to the CREATE block body:

| Marker | Value |
|--------|-------|
| `{{TARGET_PATH}}` | The absolute, canonical `target_path` from Step 1. |
| `{{OUTPUT_DOC_PATH}}` | `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md`. |
| `{{FINDINGS_PATH}}` | `<scratch_dir>/findings.md`. |
| `{{TEMPLATE_PATH}}` | The absolute path resolved in Step 6.1. |
| `{{SCRATCH_DIR}}` | `<target_path>/docs/.architecture-doc` (no trailing slash). |

After substitution, search for the literal `{{` in the prompt body.
If any markers remain, abort with an internal error -- the spawn
prompt is malformed.

### Step 6.4 -- Spawn the synthesis sub-agent

Spawn via the `Agent` tool:

- `subagent_type`: `general-purpose`. Same rationale as Step 4.6 --
  Claude Code's Agent tool does not expose per-spawn tool allowlists,
  so the synthesis agent's tool restrictions are enforced by
  prompt-level discipline (the HARD RULE blocks in
  `synthesis-agent-prompt.md`).
- `description`: `Architecture synthesis (Create) for <basename(target_path)>`.
- `prompt`: the substituted CREATE block body from Step 6.3.

Log the spawn to `run.log`:

```
<ISO8601> INFO synthesis spawn mode=Create subagent_type=general-purpose
```

### Step 6.5 -- Handle agent return and write output document

The synthesis agent's return text begins with a `STATUS:` line.
Parse the first line and branch:

- **`STATUS: success decisions=<N_dec> components=<N_comp>`**
  - Parse the two integers. `<N_dec>` is the number of Design
    Decision rows produced; `<N_comp>` is the number of Component
    Inventory rows.
  - Log: `<ISO8601> INFO synthesis return status=success decisions=<N_dec> components=<N_comp>`.
  - **Extract document content.** Parse the agent's return text for the
    literal markers `--- BEGIN DOCUMENT ---` and `--- END DOCUMENT ---`.
    Extract everything between these markers (excluding the markers
    themselves). If either marker is missing or malformed, treat this as
    an error (see error branch below).
  - **Write the output document.** Use the `Write` tool to write the
    extracted content to `<output_doc_path>`. Log:
    `<ISO8601> INFO synthesis document_written path=<output_doc_path>`.
  - Both counts are surfaced in the final session summary printed
    by Step 10.
  - Proceed to Step 6.6 (output verification).

- **`STATUS: error reason=<description>`** (or any unparseable return,
  or missing `--- BEGIN DOCUMENT ---` / `--- END DOCUMENT ---` markers)
  - Log: `<ISO8601> ERROR synthesis return status=error reason=<description>`.
  - Print: `Synthesis agent failed: <description>. No document was produced.`
  - Jump to Step 10 (cleanup) and exit. Do not run Step 6.6 / 6.7
    / 6.8.

### Step 6.6 -- Verify the output document is non-empty

Read `<output_doc_path>` (written by Step 6.5). If the file is empty
(zero bytes or whitespace only), log
`<ISO8601> ERROR synthesis output_empty path=<output_doc_path>`,
print `Synthesis produced an empty document.`, and jump to Step 10.

### Step 6.7 -- Secrets redaction pass over the output document

Read `skills/architecture-doc/references/redaction-patterns.md` for
the canonical pattern list and the application rules (Step 4.9 of
this orchestrator already uses the same file). For each pattern in
the listed order, apply a regex replace over the output document,
replacing matches with the literal string `[REDACTED]`. Track the
per-pattern hit count.

Log the result to `run.log`:

```
<ISO8601> INFO synthesis redacted ARCHITECTURE_AND_DESIGN.md hits=<total>
```

If `<total>` is greater than zero, also log the matched pattern names
(Decision #8 -- post-mortem visibility into what category of secret
the synthesis agent attempted to write):

```
<ISO8601> WARN synthesis redaction ARCHITECTURE_AND_DESIGN.md patterns=<name1,name2,...>
```

The post-synthesis pass is the **second** of the two redaction passes
specified by Decision #8 -- the first was Step 4.9 over `findings.md`.
This pass is defence-in-depth: the synthesis agent works from the
already-redacted findings file, so secrets should not normally appear
in the output, but the agent has Read access to source files for
citation verification (Step 6.3 in the prompt) and could in principle
re-introduce a secret it observed there.

### Step 6.8 -- Structural validation

PRD Feature 5 acceptance criterion: "Populates all six required
sections". After redaction, verify the output document contains all
six required ATX section headers, exactly as written below, in any
order:

```
## Design Decisions
## Component Inventory
## Data Flow
## File Organization
## Deployment & Operations
## Security Considerations
```

Each header must appear as a top-level `##` ATX heading on its own
line. If any are missing, log:

```
<ISO8601> WARN synthesis structural_validation missing=<comma-separated section names>
```

Do **not** abort the run on a structural validation failure -- the
review loop in Step 9 gives the user the opportunity to surface and
fix the gap. Surface the missing section names in the Step 9 summary
so the user can address them in the first review pass. If the
validation passes, log:

```
<ISO8601> INFO synthesis structural_validation ok
```

After Step 6.8 completes, control passes to Step 8 (the diagram
enrichment opt-in -- conditional on a diagram MCP being detected --
then onward to Step 9 review). Audit-mode Step 7 is skipped because
`mode = Create`.

## Step 7 -- Synthesis sub-agent: Audit mode

This step runs only when `mode = Audit` (resolved by Step 2). When
`mode = Create`, Step 6 ran instead and Step 7 is skipped entirely.

Step 7 spawns a synthesis sub-agent that reads `findings.md` (the
Step 4 output, already redacted by Step 4.9), reads the existing
`docs/ARCHITECTURE_AND_DESIGN.md` in full, and updates that file
**in place** via `Edit` calls. The agent never uses `Write`. The
substance of every Audit-mode rule lives in
`skills/architecture-doc/references/audit-mode.md`; the synthesis
prompt's AUDIT block is a thin caller. The orchestrator selects the
`BEGIN AUDIT` / `END AUDIT` block, substitutes tokens, and passes
the body to the Agent tool.

After the agent returns, the orchestrator runs the post-synthesis
secrets redaction pass (Decision #8 -- defence-in-depth) and a
soft-warn structural validation pass.

### Step 7.1 -- Verify the canonical template and audit rules exist

Decision #5 makes the canonical template a hard runtime dependency
with no vendored fallback. The Audit-mode rules file is the same
class of dependency for Audit mode. Verify both before paying any
synthesis cost:

1. Resolve the absolute path to
   `skills/project/design/assets/architecture-template.md` relative
   to the running session's location of the `agentic-ai` repo
   hosting this skill.
2. `Read` the template. If the read fails for any reason, abort
   with the explicit error:
   `Canonical architecture template missing: <resolved path>. The architecture-doc skill requires skills/project/design/assets/architecture-template.md to be readable; there is no vendored fallback (Decision #5).`
3. Resolve the absolute path to
   `skills/architecture-doc/references/audit-mode.md`.
4. `Read` the audit-mode rules. If the read fails for any reason,
   abort with the explicit error:
   `Audit-mode rules file missing: <resolved path>. Audit mode requires skills/architecture-doc/references/audit-mode.md to be readable.`
5. Log to `run.log`:
   ```
   <ISO8601> INFO synthesis template_ok path=<resolved template path>
   <ISO8601> INFO synthesis audit_rules_ok path=<resolved audit-mode.md path>
   ```

Neither file's contents are held in orchestrator state -- the
synthesis sub-agent will Read them itself. The orchestrator only
verifies existence so the run fails fast rather than after the
scan.

### Step 7.2 -- Read the synthesis prompt template and select the AUDIT block

1. `Read skills/architecture-doc/references/synthesis-agent-prompt.md`.
2. Locate the literal markers `## --- BEGIN AUDIT ---` and
   `## --- END AUDIT ---`. Keep only the body between them; discard
   everything before `## --- BEGIN AUDIT ---` (the substitution-marker
   preamble plus the entire CREATE block) and everything from
   `## --- END AUDIT ---` onward.
3. If either marker is missing, abort with an internal error naming
   the missing marker.

This is the mirror of Step 6.2, which selects the CREATE block.

### Step 7.3 -- Substitute tokens

Apply token replacement to the AUDIT block body:

| Marker | Value |
|--------|-------|
| `{{TARGET_PATH}}` | The absolute, canonical `target_path` from Step 1. |
| `{{OUTPUT_DOC_PATH}}` | `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md` -- the existing doc (must already exist; mode = Audit was set in Step 2 because it does). |
| `{{FINDINGS_PATH}}` | `<scratch_dir>/findings.md`. |
| `{{TEMPLATE_PATH}}` | The absolute path resolved in Step 7.1. |
| `{{AUDIT_RULES_PATH}}` | The absolute path to `skills/architecture-doc/references/audit-mode.md` resolved in Step 7.1. |
| `{{SCRATCH_DIR}}` | `<target_path>/docs/.architecture-doc` (no trailing slash). |

After substitution, search for the literal `{{` in the prompt body.
If any markers remain, abort with an internal error -- the spawn
prompt is malformed.

### Step 7.4 -- Spawn the synthesis sub-agent

Spawn via the `Agent` tool:

- `subagent_type`: `general-purpose`. Same rationale as Step 6.4 --
  Claude Code's Agent tool does not expose per-spawn tool
  allowlists, so the synthesis agent's tool restrictions are
  enforced by prompt-level discipline (the HARD RULE blocks in
  the AUDIT block of `synthesis-agent-prompt.md` plus the rules in
  `audit-mode.md`).
- `description`: `Architecture synthesis (Audit) for <basename(target_path)>`.
- `prompt`: the substituted AUDIT block body from Step 7.3.

Log the spawn to `run.log`:

```
<ISO8601> INFO synthesis spawn mode=Audit subagent_type=general-purpose
```

### Step 7.5 -- Handle agent return and write output document

The synthesis agent's return text begins with a `STATUS:` line.
Parse the first line and branch:

- **`STATUS: success new_decisions=<N_new> findings=<N_findings> contradictions=<N_contra>`**
  - Parse the three integers. `<N_new>` is the number of new
    Design Decision rows appended to the existing table.
    `<N_findings>` is the total number of rows in the Audit
    Findings block (including `missing`-type rows for the
    appended decisions). `<N_contra>` is the subset of
    `<N_findings>` whose `Type` is `contradiction`. In the empty
    case all three are `0`.
  - Log: `<ISO8601> INFO synthesis return status=success mode=Audit new_decisions=<N_new> findings=<N_findings> contradictions=<N_contra>`.
  - **Extract document content.** Parse the agent's return text for the
    literal markers `--- BEGIN DOCUMENT ---` and `--- END DOCUMENT ---`.
    Extract everything between these markers (excluding the markers
    themselves). If either marker is missing or malformed, treat this as
    an error (see error branch below).
  - **Write the output document.** Use the `Write` tool to write the
    extracted content to `<output_doc_path>`. Log:
    `<ISO8601> INFO synthesis document_written path=<output_doc_path> mode=Audit`.
  - All three counts are surfaced in the final session summary
    printed by Step 10. The contradictions count is highlighted in
    the Step 9 review prompt because it is the most actionable
    signal for the user.
  - **Capture optional post-document summary text.** Per
    `references/audit-mode.md` ("After the document block, the agent
    MAY include a brief human-readable summary"), any text after
    the `--- END DOCUMENT ---` marker in the agent's return is held
    in orchestrator state as `audit_agent_summary` (capped at 200
    words; truncate silently if longer). Step 10.2 prints this
    verbatim under the fixed-shape summary block when it is
    non-empty. If the agent returned no text after the document
    block, leave `audit_agent_summary` unset.
  - Proceed to Step 7.6 (output verification).

- **`STATUS: error reason=<description>`** (or any unparseable return,
  or missing `--- BEGIN DOCUMENT ---` / `--- END DOCUMENT ---` markers)
  - Log: `<ISO8601> ERROR synthesis return status=error mode=Audit reason=<description>`.
  - Print: `Audit synthesis agent failed: <description>. No changes were made to the existing document.`
  - Jump to Step 10 (cleanup) and exit. Do not run Step 7.6 / 7.7
    / 7.8.

  Note: because the agent no longer writes directly, an error leaves
  the original document unchanged. The orchestrator only writes the
  new version if the agent returns successfully with valid markers.

### Step 7.6 -- Verify the output document is non-empty

Read `<output_doc_path>` (written by Step 7.5). If the file is empty
(zero bytes or whitespace only), log
`<ISO8601> ERROR synthesis output_empty path=<output_doc_path> mode=Audit`,
print `Audit synthesis produced an empty document.`, and jump to Step 10.

### Step 7.7 -- Secrets redaction pass over the output document

Read `skills/architecture-doc/references/redaction-patterns.md` for
the canonical pattern list and the application rules (Steps 4.9 and
6.7 of this orchestrator already use the same file). For each
pattern in the listed order, apply a regex replace over the output
document, replacing matches with the literal string `[REDACTED]`.
Track the per-pattern hit count.

Log the result to `run.log`:

```
<ISO8601> INFO synthesis redacted ARCHITECTURE_AND_DESIGN.md hits=<total> mode=Audit
```

If `<total>` is greater than zero, also log the matched pattern
names (Decision #8 -- post-mortem visibility into what category of
secret the synthesis agent attempted to write):

```
<ISO8601> WARN synthesis redaction ARCHITECTURE_AND_DESIGN.md patterns=<name1,name2,...> mode=Audit
```

The post-Audit pass is the **second** of the two redaction passes
specified by Decision #8 (the first was Step 4.9 over `findings.md`),
mirroring the Create-mode Step 6.7 contract. In Audit mode the
defence-in-depth case is even stronger than in Create mode, because
the agent's Edits are interleaved with user-authored content the
orchestrator did not see -- a secret the user happened to have
embedded in their prose, that the audit happened to leave alone,
would still slip through without this pass.

A redaction hit in Audit mode is a quiet but consequential edit to
user-authored content. The orchestrator does not abort or prompt
the user; the `WARN` line in `run.log` and the Step 10 session
summary are the disclosure surface. Step 9's review loop is the
recovery surface -- the user can inspect the redacted regions and
restore them by hand if a false positive occurred.

### Step 7.8 -- Soft structural validation

PRD Feature 6 does not require the audit to enforce the canonical
six sections (the user is preservation-first and may have
legitimately omitted one), but a missing canonical section is still
a useful signal for the Step 9 review loop. Mirror Step 6.8's soft-
fail philosophy:

After redaction, verify the output document contains all six
required ATX section headers, exactly as written below, in any
order:

```
## Design Decisions
## Component Inventory
## Data Flow
## File Organization
## Deployment & Operations
## Security Considerations
```

Each header must appear as a top-level `##` ATX heading on its own
line. If any are missing, log:

```
<ISO8601> WARN synthesis structural_validation missing=<comma-separated section names> mode=Audit
```

Do **not** abort the run on a structural validation failure -- the
review loop in Step 9 gives the user the opportunity to surface and
fix the gap. Surface the missing section names in the Step 9
summary so the user can address them in the first review pass. If
the validation passes, log:

```
<ISO8601> INFO synthesis structural_validation ok mode=Audit
```

**User-added sections that are not in the canonical six are never
flagged.** Audit mode is preservation-first; unknown sections are
features, not bugs. The orchestrator does not enumerate them, log
them, or warn about them.

After Step 7.8 completes, control passes to Step 8 (the diagram
enrichment opt-in -- conditional on a diagram MCP being detected --
then onward to Step 9 review).

## Step 8 -- MCP-enriched synthesis (diagram embedding, conditional)

Step 8 runs after the synthesis sub-agent has produced or updated
`docs/ARCHITECTURE_AND_DESIGN.md` (Step 6 in Create mode, Step 7 in
Audit mode) and is the diagram-side half of Feature 9. The scan-side
half (language-server enrichment) fired earlier in Step 4.0 -- by
the time Step 8 runs, language-server intelligence has already shaped
the file selection that fed synthesis.

Step 8's purpose is narrow: if the user has a Mermaid-class diagram
MCP available in this session AND wants diagrams embedded, generate
component and data-flow Mermaid blocks from the **just-produced** doc
and insert them via `Edit`, **before** the review loop in Step 9
begins. The user reviews the enriched doc (text plus diagrams) as a
single artifact, satisfying the design-doc Data Flow contract that
diagrams are part of what the user approves.

Per Decision #2 and Decision #13, this work runs in the
**orchestrator context** -- no third sub-agent spawn.

Per Decision #17 the enrichment is **per-run opt-in**: the user is
asked once per run, here, before any Mermaid generation work. The
prompt copy is the canonical text in `references/mcp-probe.md`
(`### \`diagram\` enrichment prompt`); Step 8 reads it from there
rather than hardcoding the wording.

Diagrams may go stale during the review loop if the user edits
Component Inventory or Data Flow via Revise/Partial. Step 9.7 and
Step 9.8 call back into Step 8.5, Step 8.6, Step 8.7, Step 8.8 (in
its **regeneration** branch), and Step 8.9 to refresh the diagrams
after each edit pass, so the user always sees fresh diagrams in
every iteration. The regeneration cost is bounded: at most one extra
Component-Inventory parse and one extra Data-Flow parse per
iteration, both in-orchestrator with no MCP call.

State Step 8 consumes from earlier steps:

- `mode` -- `Create` or `Audit` (Step 2). Step 8's behaviour does
  not branch on mode; both modes get the same enrichment offer.
- `output_doc_path` -- `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md`,
  the file that Step 6 or Step 7 just produced.
- `probe.categories.diagram` -- the list of `mcp__`-prefixed tool
  names from Step 3 categorised as `diagram`. Empty means no
  enrichment is offered.
- `enrichment_choices` -- the orchestrator-state dict; Step 8 writes
  `enrichment_choices.diagram` based on the user's response.

### Step 8.1 -- Probe-category gate

Inspect `probe.categories.diagram`:

- If empty, log:
  ```
  <ISO8601> INFO synthesis enrichment skipped category=diagram reason=no_mcp_detected
  ```
  set `enrichment_choices.diagram = false`, and proceed directly to
  Step 9 (review). **No prompt is shown to the user** -- this
  preserves the "baseline path unchanged when no enriching MCPs are
  present" guarantee from PRD Feature 8 and Decision #17.
- If non-empty, proceed to Step 8.2.

This gate is the same shape as Step 4.0's gate for the LS opt-in.
Both gates are necessary because Decision #17 only allows the opt-in
prompt to fire when the relevant MCP is actually present.

### Step 8.2 -- Read the canonical opt-in prompt copy

`Read skills/architecture-doc/references/mcp-probe.md` and locate the
heading `### \`diagram\` enrichment prompt`. Extract the question
text and the two listed options (`Embed` and `Skip`) verbatim. The
reference file is the **single source of truth** for prompt wording
(Decision #17 implementation pattern -- already used by Step 4.0 for
the language-server prompt).

If the heading is missing or the options cannot be located, abort
with an internal error naming the missing heading. The skill cannot
fall back to inlined wording -- the reference file is the only
authority.

### Step 8.3 -- Ask the user

Call `AskUserQuestion` with the question and options from Step 8.2.
Log:

```
<ISO8601> INFO synthesis enrichment prompted category=diagram tool_count=<N>
```

where `<N>` is the length of `probe.categories.diagram`.

### Step 8.4 -- Handle "Skip"

If the user selected `Skip`:

- Set `enrichment_choices.diagram = false` in orchestrator state.
- Log:
  ```
  <ISO8601> INFO synthesis enrichment skipped category=diagram reason=user_declined
  ```
- Proceed directly to Step 9 (review). The output document is
  unchanged from what Step 6 / Step 7 produced.

### Step 8.5 -- Handle "Embed": read the produced document

Set `enrichment_choices.diagram = true` in orchestrator state and
log:

```
<ISO8601> INFO synthesis enrichment accepted category=diagram phase=initial
```

(On a regeneration call from Step 9.7 / Step 9.8, the
`phase=initial` token is replaced with `phase=regen`; the rest of
this substep behaves identically.)

Then `Read <output_doc_path>` to load the **current** state of the
document. On the initial pass this is the post-synthesis,
pre-review state. On a regeneration call from Step 9.7 / Step 9.8
this is the post-edit state from the most recent review iteration
-- always re-read here rather than relying on any cached copy.

If the read fails (file missing, permissions changed, etc.), log
`<ISO8601> ERROR synthesis enrichment output_missing path=<output_doc_path> phase=<initial|regen>`,
print `Diagram enrichment failed: output document is no longer readable. Continuing without diagrams.`,
set `enrichment_choices.diagram = false`, and proceed to Step 9
(review). Do not fall through to the Mermaid generation substeps
with no source document; the review loop can still run on the
un-enriched doc.

### Step 8.6 -- Generate the component diagram (Mermaid `graph TD`)

Parse the `## Component Inventory` section of the in-context doc
text. The canonical template uses a three-column table
(`Component | Responsibility | Interfaces`) that the synthesis
sub-agent populated in Step 6 or Step 7.

For each table row (skipping the header and separator):

1. Extract the component name from column 1. Strip backticks and
   surrounding whitespace.
2. Extract the responsibility from column 2. Trim to the first
   sentence (everything up to and including the first period
   followed by a space, or the entire cell if shorter than ~80
   characters).
3. Build a Mermaid node with the component name as the node id
   (after sanitisation: replace `/`, `.`, `-`, and any non-alphanumeric
   character other than `_` with `_`; if the result starts with a
   digit, prefix with `n_`) and a node label that joins the component
   name and the trimmed responsibility with `<br/>` (per `CLAUDE.md`
   and Decision #17 -- literal `\n` renders as text and corrupts
   diagrams).

Edges between components are inferred best-effort from the
`Interfaces` column (column 3): if a component's Interfaces text
contains the literal name of another component listed in the table,
draw a directed edge from the source to the referenced component.
This is heuristic and intentionally conservative -- a missing edge
is better than a hallucinated one.

Wrap the result as a fenced Mermaid code block:

````
```mermaid
graph TD
    <node defs>
    <edges>
```
````

If the Component Inventory section is missing entirely, has no
parseable rows, or contains fewer than two rows, **skip the
component diagram only** -- log
`<ISO8601> WARN synthesis enrichment component_diagram_skipped reason=<empty|unparseable|too_few_rows>`,
do not insert anything for the component diagram, and continue to
Step 8.7. The data-flow diagram may still be generable.

### Step 8.7 -- Generate the data-flow diagram (Mermaid `flowchart LR`)

Parse the `## Data Flow` section of the in-context doc. The
canonical template uses a numbered list (`1.`, `2.`, ...) where each
list item describes a step. The synthesis agent populated this in
Step 6/7.

For each numbered list item at the top level of the section:

1. Extract the step number (the leading integer) and the step text.
2. Take the **first sentence** of the step text as the node label
   (everything up to and including the first period followed by a
   space). Strip Markdown bold/italic markers (`**`, `*`, `__`, `_`)
   from the label so the rendered diagram is clean.
3. Build a Mermaid node with id `s<step number>` and the trimmed
   first sentence as the label. Use `<br/>` for any line breaks
   needed to keep the label readable (split on a sentence-internal
   semicolon, or every ~40 characters at a word boundary if no
   semicolon is present).
4. Draw a directed edge from each node to the next step's node
   (`s1 --> s2 --> s3 --> ...`).

Wrap the result as a fenced Mermaid code block:

````
```mermaid
flowchart LR
    <node defs>
    <edges>
```
````

If the Data Flow section is missing, has no numbered list, or has
fewer than two steps, **skip the data-flow diagram only** -- log
`<ISO8601> WARN synthesis enrichment data_flow_diagram_skipped reason=<empty|unparseable|too_few_steps>`
and continue to Step 8.8.

If both diagrams were skipped (Steps 8.6 and 8.7 both produced
nothing), log
`<ISO8601> WARN synthesis enrichment all_diagrams_skipped`,
print `Diagram enrichment was offered and accepted, but neither Component Inventory nor Data Flow could be parsed into a diagram. Continuing without diagrams.`
to the user, and proceed to Step 9 (review). Do not run Step 8.8 /
8.9 / 8.10.

### Step 8.8 -- Insert (or replace) the diagrams via Edit

This substep runs in two modes depending on who called it:

- **Initial insertion** (called from Step 8.7 on the first pass
  through Step 8): the doc has no Mermaid blocks yet. Insert each
  generated block at its anchor point.
- **Regeneration** (called from Step 9.7 / Step 9.8 after a
  review-loop edit pass): the doc may already contain a Mermaid
  block (or two) from a prior Step 8.8 invocation. Locate and
  replace each one rather than inserting alongside.

The orchestrator distinguishes the two modes by inspecting whether
any fenced ```mermaid``` block already exists in the in-context doc
text held since Step 8.5.

**Initial insertion path:**

For each diagram that was generated (one or both):

1. **Component diagram**: locate the `## Component Inventory`
   header in the doc text, then locate the end of its table (the
   last line beginning with `|`, followed by a blank line or the
   next `##` heading). Use `Edit` with `old_string` set to the
   anchor (the last table line plus the trailing blank line, or
   the next `## ` boundary if no blank line) and `new_string` set
   to that anchor immediately followed by a blank line and the
   Mermaid block from Step 8.6, then another blank line.

2. **Data flow diagram**: locate the `## Data Flow` header in the
   doc text, then locate the end of its numbered list (the last
   line beginning with a digit followed by `.`, or its
   continuation). Use `Edit` similarly, with anchor and new_string
   such that the Mermaid block from Step 8.7 is inserted between
   the end of the numbered list and the next `## ` boundary.

**Regeneration path:**

1. For each fenced ```mermaid``` block already present in the
   in-context doc, identify whether it is a `graph TD` (component
   diagram) or a `flowchart LR` (data flow diagram) by inspecting
   the line immediately following the opening fence.
2. For each match, use `Edit` with `old_string` set to the entire
   existing Mermaid block (from the opening ```mermaid``` line
   through the closing ``` line, inclusive) and `new_string` set
   to the freshly generated block of the same type from Step 8.6
   / Step 8.7.
3. If a generated block has no existing counterpart in the doc
   (e.g. the user manually deleted the diagram during a Revise
   pass), do **not** re-insert it -- respect the user's edit. Log:
   ```
   <ISO8601> INFO synthesis enrichment regen_skipped diagram=<component|data_flow> reason=user_deleted
   ```
4. If an existing block has no fresh counterpart (Component
   Inventory or Data Flow now fails to parse), leave the existing
   block in place but log a warning:
   ```
   <ISO8601> WARN synthesis enrichment regen_stale diagram=<component|data_flow> reason=<unparseable|empty>
   ```

**Both paths:**

If a single `Edit` call cannot uniquely identify its anchor (the
chosen anchor string appears more than once in the doc), expand
the anchor with more surrounding context until it is unique. This
mirrors the same Edit-disambiguation policy used by Steps 9.7 and
9.8.

If an `Edit` call still fails after disambiguation (e.g. the
section heading is absent because the synthesis agent omitted it
and the user did not add it back during review), log
`<ISO8601> ERROR synthesis enrichment edit_failed diagram=<component|data_flow> reason=<short> phase=<initial|regen>`,
surface the failure to the user with the diagram name, and continue
with the other diagram. Do not abort Step 8 over a single failed
Edit -- partial enrichment is more useful than no enrichment.

After all Edits, log:

```
<ISO8601> INFO synthesis enrichment edits_applied component=<true|false> data_flow=<true|false> phase=<initial|regen>
```

### Step 8.9 -- Secrets redaction pass over the enriched document

Decision #8 (read-but-redact, defence-in-depth). Step 8 has just
inserted (or replaced) Mermaid content in the output doc -- new
content the orchestrator generated from in-context parsing of the
doc. The generated Mermaid labels are derived from Component
Inventory rows and Data Flow steps that already passed redaction
(Step 6.7 in Create mode, Step 7.7 in Audit mode), so the risk of a
fresh secret leak is low. The redaction pass is still run as a
defence-in-depth measure consistent with the existing pattern.

Read `references/redaction-patterns.md` for the canonical pattern
list. For each pattern in the listed order, apply a regex replace
over the output document, replacing matches with the literal
`[REDACTED]`. Track the per-pattern hit count.

Log:

```
<ISO8601> INFO synthesis redacted ARCHITECTURE_AND_DESIGN.md hits=<total> phase=enrichment
```

If `<total>` is greater than zero, also log the matched pattern
names (Decision #8 -- post-mortem visibility):

```
<ISO8601> WARN synthesis redaction ARCHITECTURE_AND_DESIGN.md patterns=<name1,name2,...> phase=enrichment
```

A redaction hit at this stage is genuinely surprising (the doc was
already double-redacted by Step 6.7 / 7.7) and is worth flagging in
the session summary.

### Step 8.10 -- Log completion and proceed

Log a final enrichment-complete entry:

```
<ISO8601> INFO synthesis enrichment complete diagrams_embedded=<N> phase=<initial|regen>
```

where `<N>` is `0`, `1`, or `2` depending on how many diagrams were
generated and successfully inserted (or replaced) on this pass.

- On an **initial** pass (called from synthesis exit at Step 6.8 /
  Step 7.8): proceed to Step 9 (review).
- On a **regeneration** pass (called from Step 9.7 / Step 9.8):
  return control to the calling substep, which then loops back to
  Step 9.1 with the freshly-regenerated diagrams in place.

The diagram-embedded count is surfaced in the Step 10 session
summary so the user has a one-line confirmation of what was added
on the final iteration.

### Implementation note: why the diagram MCP itself is not invoked

This iteration of Feature 9 uses the diagram MCP's **presence** as
the user-permission trigger but does **not** invoke any
`mcp__<diagram>__<tool>` directly. The orchestrator generates the
Mermaid source itself from in-context parsing of the doc, because:

1. Diagram-MCP tool surfaces vary widely (some validate, some
   render to PNG, some accept natural-language input). There is no
   single tool name or signature the orchestrator can rely on.
2. Mermaid embedded as a fenced code block is the canonical
   GitHub / GitLab / VS Code rendering form -- no PNG conversion
   is required for inline display.
3. The PRD wording ("offers to embed generated diagrams") and
   Decision #17 ("MCP-enriched features... opt-in per run") both
   describe the MCP as a permission/preference signal, not a
   mandatory call site.

A Future Enhancement could call the diagram MCP to **validate** the
generated Mermaid syntax before embedding, gating the Edit on a
successful parse. That requires standardising on at least one MCP
tool signature and is out of scope for this iteration.

## Step 9 -- Produce-then-review cycle

Step 9 runs after Step 8 has either generated and embedded diagrams
(if the user opted in) or skipped enrichment (if not). The doc the
user reviews is the **enriched** form when diagrams are present, or
the un-enriched synthesis output otherwise -- either way, the user
reviews exactly what will be the final artifact. Per Decision #13,
the entire review loop runs in the **orchestrator context** -- no
further sub-agent spawn -- so the orchestrator can hold the
`AskUserQuestion` interactive surface and apply per-section `Edit`
calls directly. The synthesis sub-agent is done.

The loop terminates **only** when the user selects **Approve**.
There is no iteration cap and no Abort branch in the prompt -- PRD
Feature 7 is explicit ("Loop terminates only when the user selects
Approve"). A user who wants to abandon the run uses `Ctrl+C` or
tells the orchestrator to stop in free text; that path skips ahead
to Step 10 cleanup as the final action when control returns.

State Step 9 consumes from earlier steps:

- `mode` -- `Create` or `Audit`, set in Step 2.
- `output_doc_path` -- `<target_path>/docs/ARCHITECTURE_AND_DESIGN.md`.
- `scratch_dir` -- `<target_path>/docs/.architecture-doc`.
- `enrichment_choices` -- the orchestrator-state dict from Steps
  4.0 and 8. `enrichment_choices.diagram` decides whether Step 9.7
  / Step 9.8 call back into Step 8 to regenerate Mermaid blocks
  after each edit pass.
- For Create mode: `decisions`, `components` from Step 6.5; the
  structural-validation result from Step 6.8.
- For Audit mode: `new_decisions`, `findings`, `contradictions` from
  Step 7.5; the structural-validation result from Step 7.8.

Substeps 9.1 and 9.2 run **at the top of every iteration** so that
edits applied by the previous iteration are reflected in the next
summary. Substeps 9.3 through 9.8 run once per iteration.

### Step 9.1 -- (Re)read the output document and initialise loop state

On the first entry to Step 9, set `iteration = 1`. Each subsequent
loop-back from Step 9.7 or Step 9.8 increments `iteration` by 1.

`Read <output_doc_path>` into orchestrator context. This is the
re-read cost that Decision #13 explicitly accepts. Hold the full
document text in context for substeps 9.2 through 9.8.

If the read fails (the user manually deleted the file mid-loop, the
filesystem went away, etc.), log
`<ISO8601> ERROR review output_missing path=<output_doc_path> iteration=<N>`,
print `Output document is no longer readable -- aborting review loop.`,
and jump to Step 10.

Log:

```
<ISO8601> INFO review iteration=<N> reread_doc bytes=<size>
```

### Step 9.2 -- Re-validate canonical sections

Earlier iterations may have added a missing canonical section via
Revise or Partial. Re-run the same six-header check Step 6.8 / Step 7.8
performed, against the current in-context doc text:

```
## Design Decisions
## Component Inventory
## Data Flow
## File Organization
## Deployment & Operations
## Security Considerations
```

Each header must appear as a top-level `##` ATX heading on its own
line. Compute `missing_sections` (possibly empty). This is the
**current** structural state, not the synthesis-time state -- the
synthesis-time result is only used to populate the very first
iteration's summary if no edits have been applied yet.

Log:

```
<ISO8601> INFO review iteration=<N> structural_validation missing=<comma-separated or "none">
```

The Audit-mode preservation rule from Step 7.8 still holds:
**user-added sections that are not in the canonical six are never
flagged**. The orchestrator does not enumerate them or mention them in
the summary.

### Step 9.3 -- Parse Design Decisions and select tradeoff callouts

PRD Feature 7 requires 2-4 tradeoff callouts using the heuristic from
`skills/project/design/references/gate-2-design.md` "Tradeoff Callouts"
section. The orchestrator parses the produced doc itself rather than
re-spawning the synthesis sub-agent (Decision #13's "orchestrator runs
the review" implies the orchestrator is the actor; re-spawning would
double the cost and duplicate context).

Procedure:

1. From the in-context doc, locate the `## Design Decisions` section
   and parse the Markdown table that follows. Each row has columns
   `# | Decision | Rationale | Tradeoff | Alternatives Considered`
   (the canonical schema in the architecture template). In Audit mode
   the table may have been appended to and may include rows from
   prior runs and from user-authored edits; treat all rows uniformly.
2. If the table is missing or empty, set `callouts = []` and continue
   -- the structural-validation gap from Step 9.2 is the user-facing
   signal in this case.
3. Apply the three-clause `gate-2-design.md` heuristic to each row:
   - **Viable alternatives.** The `Alternatives Considered` column
     names at least one alternative that is not obviously a strawman
     (i.e. not a single-word "do nothing" or an explicitly rejected
     non-option).
   - **Multi-component or long-term impact.** The `Rationale` or
     `Tradeoff` text references multiple components, the file
     organization, the deployment surface, the data flow, or
     long-term evolution / migration cost.
   - **Expensive reversal.** The `Tradeoff` text or the `Alternatives
     Considered` text describes rework, migration, schema change,
     wire-format change, or breaking-change risk.
4. Score each row by the count of clauses it satisfies (0-3). Sort
   by score descending, then by row number ascending (deterministic
   tie-break -- earlier table rows usually correspond to more
   foundational decisions).
5. Take the top **min(4, max(2, N_high))** rows where `N_high` is the
   count of rows scoring at least 2 of the 3 clauses. If fewer than 2
   rows score 2+, fall back to the top 2 rows by score regardless of
   threshold so the user always sees at least 2 callouts (the PRD
   floor). If the table has fewer than 2 rows total, surface
   whatever exists -- 1 row, or 0 rows -- and note the gap in the
   summary built by Step 9.4.

Log:

```
<ISO8601> INFO review iteration=<N> callouts selected=<comma-separated row #s>
```

### Step 9.4 -- Build the review summary

Assemble a single text block to present to the user. The block has
five fixed sections in this order:

1. **Header.** `# Architecture Document Review -- iteration <N>`
2. **Mode and counts.** One line: `Mode: Create` or `Mode: Audit`,
   followed on the next line by the counts surfaced from Step 6.5
   (Create: `Decisions: <N_dec>  Components: <N_comp>`) or Step 7.5
   (Audit: `New decisions: <N_new>  Audit findings: <N_findings>  Contradictions: <N_contra>`).
   In Audit mode, the **contradictions count is the most actionable
   signal** and is rendered in **bold** so the user's eye lands on it
   first. If `<N_contra>` is zero, render it without emphasis and
   add the literal phrase `(no contradictions detected)`.
   If `enrichment_choices.diagram` is `true`, append a third line:
   `Diagrams: embedded (Mermaid -- regenerated each iteration if Component Inventory or Data Flow changes).`
3. **Summary of the document.** Six short bullets, one per canonical
   section, derived from the in-context doc text:
   - **Design Decisions** -- "<N_rows> rows in the table" and the
     titles of the top 3 rows by row number.
   - **Component Inventory** -- "<N_rows> components" and the names
     of the top 3 components.
   - **Data Flow** -- the first sentence of the section.
   - **File Organization** -- "code-tree fence present" or "no
     code fence" depending on whether a fenced code block follows
     the heading.
   - **Deployment & Operations** -- the first sentence of the
     section.
   - **Security Considerations** -- the first sentence of the
     section.
   For any canonical section that is in `missing_sections` from
   Step 9.2, the bullet reads `**MISSING**` instead of a summary.
4. **Tradeoff callouts.** A numbered list of the 2-4 callouts
   selected by Step 9.3. Each callout is three lines:
   - `Decision #<row>: <decision text, truncated to 100 chars>`
   - `Tradeoff: <tradeoff text, truncated to 200 chars>`
   - `Most viable alternative: <first alternative from the row, truncated to 200 chars>`
   If Step 9.3 produced fewer than 2 callouts (small table), include
   the explicit note `Note: only <N> callouts could be surfaced --
   the Design Decisions table has fewer than 2 rows that meet the
   tradeoff heuristic.`
5. **Gaps.** A bulleted list of issues the user should address before
   approving:
   - One bullet per entry in `missing_sections` from Step 9.2:
     `Missing canonical section: <name>`
   - In Audit mode, one bullet per contradiction the synthesis
     surfaced: `Audit found <N_contra> contradiction(s) -- see the
     Audit Findings block at the top of the document.`
   - If the table has zero rows, one bullet:
     `Design Decisions table is empty.`
   - If the section list is empty, render the literal line
     `No structural gaps detected.`

The summary block is the single payload for the next AskUserQuestion;
it is rendered to the user verbatim before the question is posed.

### Step 9.5 -- Ask Approve / Revise / Partial

Print the summary block from Step 9.4 to the user. Then call
`AskUserQuestion`:

- **question:** `How would you like to proceed with the architecture document?`
- **options:**
  - `Approve` -- header `Approve`, description `The document is sound. Proceed to cleanup.`
  - `Revise` -- header `Revise`, description `Make changes to the document; I will tell you what.`
  - `Partial` -- header `Partial`, description `Some sections are fine, others need work; I will pick which.`

Log:

```
<ISO8601> INFO review iteration=<N> prompt presented options=Approve,Revise,Partial
<ISO8601> INFO review iteration=<N> user_choice=<approve|revise|partial>
```

Branch on the user's choice to Step 9.6, 9.7, or 9.8.

### Step 9.6 -- Handle Approve

The loop is done. Log:

```
<ISO8601> INFO review approved iterations=<N>
```

The total iteration count is held in orchestrator state and surfaced
in the Step 10 session summary. Proceed to Step 10 (cleanup). The
diagram enrichment, if any, has already been applied -- Step 8 ran
before Step 9 began and any subsequent regenerations were folded into
Step 9.7 / Step 9.8 -- so there is no further synthesis work after
Approve.

### Step 9.7 -- Handle Revise

Revise is the **whole-doc** revision path: the user has freeform
changes that may span multiple sections, or the changes are not
cleanly section-scoped (e.g. "fix the inconsistent terminology"
across the whole doc).

1. Ask the user, in free text (not via `AskUserQuestion`):
   `What should change in the architecture document?`
   The user responds with a description of the edits they want.
2. For each described change, apply an `Edit` call to
   `<output_doc_path>` in the orchestrator context. Use Edit (not
   Write) so the change is targeted and the surrounding content is
   not at risk. If a single Edit cannot express the change because
   the target string is not unique, apply multiple Edits with more
   surrounding context to disambiguate, the same way the orchestrator
   handles any other Edit-tool interaction.
3. If a requested change requires inserting a canonical section that
   is missing entirely (e.g. the user asks for `Security
   Considerations` to be added and Step 9.2 reported it missing),
   construct the section locally from the user's description and
   insert it via Edit anchored on the next H2 boundary or the end of
   file. Do not re-spawn the synthesis sub-agent.
4. If an Edit call fails (string not found, target not unique even
   after expansion, output_doc_path no longer writable), log
   `<ISO8601> ERROR review iteration=<N> edit_failed reason=<short description>`,
   surface the failure to the user with the failed change quoted
   verbatim, and continue with the next requested change. Do **not**
   abort the loop on a single failed edit -- the user can re-issue
   the change in the next iteration.
5. After all requested changes have been applied (or surfaced as
   failures), log:
   ```
   <ISO8601> INFO review iteration=<N> revise edits_applied=<N_ok> edits_failed=<N_err>
   ```
6. **Diagram regeneration.** If `enrichment_choices.diagram` is
   `true`, the just-applied edits may have changed the Component
   Inventory or Data Flow sections, leaving the embedded Mermaid
   blocks stale. Re-run Step 8.5 (re-read), Step 8.6 (component
   diagram regeneration), Step 8.7 (data-flow diagram regeneration),
   Step 8.8 in its **regeneration** branch (locate and replace
   existing Mermaid blocks via Edit), and Step 8.9 (secrets
   redaction) over the freshly-edited doc. Revise is whole-doc
   scoped so the orchestrator does not know which sections changed
   -- always regenerate when this branch fires. Log:
   ```
   <ISO8601> INFO review iteration=<N> revise diagram_regen invoked
   ```
   On error inside the regeneration call, log the failure but do
   **not** abort the review loop -- the user can still see the
   (now-stale) diagrams and address the issue in the next iteration.
   If `enrichment_choices.diagram` is `false`, skip this substep
   entirely.
7. Loop back to Step 9.1 (the re-read picks up the freshly-edited
   doc state including any regenerated Mermaid blocks). `iteration`
   increments.

### Step 9.8 -- Handle Partial

Partial is the **section-scoped** revision path: the user wants to
approve some sections and revise others.

1. Call `AskUserQuestion` with `multiSelect: true` and an option per
   canonical section:
   - `Design Decisions`
   - `Component Inventory`
   - `Data Flow`
   - `File Organization`
   - `Deployment & Operations`
   - `Security Considerations`

   Question: `Check the sections you approve as-is. Unchecked sections will need revision.`

   Per PRD Feature 7 and the gate-2-design.md review-phase wording,
   the user **checks the sections that are approved**, leaving the
   unchecked sections as the ones that need work. The orchestrator
   inverts the multiSelect result -- the sections **not** checked
   are the ones to revise. Log:
   ```
   <ISO8601> INFO review iteration=<N> partial sections_to_revise=<comma-separated section names or "none">
   ```

2. If every section was checked (no sections to revise), treat the
   choice as equivalent to **Approve** -- the user has effectively
   approved the whole document via the Partial path. Log
   `<ISO8601> INFO review iteration=<N> partial all_approved -- promoting to approve`
   and proceed to Step 9.6.

3. For each section in the to-revise list:
   1. Locate the section in the in-context doc text by its `##`
      ATX heading. The section spans from its heading to the next
      `##` heading at the same level (or end of file).
   2. Ask the user, in free text (not via `AskUserQuestion`):
      `What should change in <section name>?`
   3. Apply the user's described changes via one or more `Edit`
      calls to `<output_doc_path>`, scoping each Edit's `old_string`
      to text inside the section's boundaries to prevent accidental
      cross-section edits. The same Edit-failure policy as Step 9.7
      step 4 applies.
   4. If the section is in `missing_sections` (from Step 9.2),
      construct the section from the user's description and insert
      it via Edit anchored on the next H2 boundary or the end of
      file, the same way Step 9.7 step 3 handles missing sections.

4. After all to-revise sections have been processed, log:
   ```
   <ISO8601> INFO review iteration=<N> partial completed sections_revised=<N_done> edits_applied=<N_ok> edits_failed=<N_err>
   ```

5. **Diagram regeneration.** If `enrichment_choices.diagram` is
   `true` AND the to-revise list included `Component Inventory`
   or `Data Flow`, the embedded Mermaid blocks may now be stale.
   Re-run Step 8.5, Step 8.6, Step 8.7, Step 8.8 (regeneration
   branch), and Step 8.9 over the freshly-edited doc. If neither
   `Component Inventory` nor `Data Flow` was in the to-revise
   list, skip regeneration -- the diagrams remain valid. If
   `enrichment_choices.diagram` is `false`, skip regeneration
   regardless. Log:
   ```
   <ISO8601> INFO review iteration=<N> partial diagram_regen=<invoked|skipped> reason=<edited_sections_include_diagram_source|edited_sections_unrelated|enrichment_disabled>
   ```

6. Loop back to Step 9.1. `iteration` increments. The next iteration
   re-reads the doc and re-runs structural validation, so any
   newly-inserted sections clear out of `missing_sections`
   automatically.

## Step 10 -- Cleanup and session summary

Step 10 is the **last step in every code path** that reached Step 4 or
later -- the happy-path Approve from Step 9.6, every preflight abort
and error jump from Step 4, every synthesis failure jump from Steps 6
and 7, and the mid-loop output-missing failure from Step 9.1. The
early aborts in Step 1 (target_path invalid), Step 2 (user Abort, or
Overwrite-only branch Abort), and Step 4.1 (scratch dir creation
failed) exit before Step 10 because no scratch state has been
created yet -- there is nothing to clean up and no run.log to write
to.

By the time Step 10 runs, the scratch directory and `run.log` always
exist (they were created by Step 4.1 and Step 4.2 respectively, both
of which are unconditional once Step 4 starts). Step 10 does **not**
need defensive `if scratch_dir exists` branches; if it is reached at
all, the scratch dir is present.

Per Decision #18, every log line emitted by Step 10 uses
`phase=cleanup`. Per Decision #6 and the design doc Security
Considerations section, scratch cleanup runs **regardless** of
whether the run succeeded or aborted -- the directory is always
removed before the skill exits.

State Step 10 may consume from earlier steps. Each in-context value
listed below is set by exactly one upstream substep on the success
path that produces it; values not set on the actual code path that
led to Step 10 are treated as the literal token `na`:

| In-context value | Set by | Notes |
|---|---|---|
| `mode` | Step 2 | Always set; Step 2 runs before any path that reaches Step 10. |
| `arch_files`, `doc_files` | Step 4.7 success branch | Unset on preflight / monorepo / scan-error / boundary-violation paths. |
| `decisions`, `components` | Step 6.5 success branch | Create mode only. Unset in Audit mode and on every Create-mode failure path. |
| `new_decisions`, `findings`, `contradictions` | Step 7.5 success branch | Audit mode only. Unset in Create mode and on every Audit-mode failure path. |
| `enrichment_choices.language_server` | Step 4.0 | `true` / `false` if the user was prompted; `not_offered` if `probe.categories.language_server` was empty so no prompt was shown. |
| `enrichment_choices.diagram` | Step 8.1 / 8.4 / 8.5 | Same shape as the LS field. Unset on every code path that aborted before Step 8 (preflight, scan error, synthesis error, etc.). |
| `diagrams_embedded` | Step 8.10 | `0`, `1`, or `2`. Unset if Step 8 was never reached or if enrichment was declined / not offered. |
| `iteration` | Step 9.1 (incremented through 9.7 / 9.8) | Final loop count when Step 9.6 fired. Unset if Step 9 was never reached. |

### Step 10.1 -- Resolve `exit_reason`

Each upstream substep that jumps to Step 10 enters with a known
context that maps to exactly one of the `exit_reason` tokens listed
below. The orchestrator binds the token from the substep it just
left; this is a documentation contract, not a piece of state the
upstream substeps literally write -- they already log a
phase-specific status line and Step 10 derives the token from the
substep that fired.

| `exit_reason` | Set when entering Step 10 from | Outcome line |
|---|---|---|
| `approved` | Step 9.6 (user chose Approve) | `approved` |
| `preflight_abort` | Step 4.7 `STATUS: preflight_abort` branch | `aborted: preflight_abort` |
| `monorepo_abort` | Step 4.7 monorepo-warning Abort branch | `aborted: monorepo_abort` |
| `scan_error` | Step 4.7 `STATUS: error` (or unparseable) branch | `aborted: scan_error` |
| `path_boundary_violation` | Step 4.8 cited-path validation failure | `aborted: path_boundary_violation` |
| `synthesis_error` | Step 6.5 `STATUS: error` or Step 7.5 `STATUS: error` branch | `aborted: synthesis_error` |
| `output_missing` | Step 6.6 or Step 7.6 missing-output branch | `aborted: output_missing` |
| `output_empty` | Step 6.6 or Step 7.6 empty-output branch | `aborted: output_empty` |
| `review_output_missing` | Step 9.1 mid-loop read failure | `aborted: review_output_missing` |

Append the cleanup-start line to `run.log`:

```
<ISO8601> INFO cleanup start exit_reason=<token>
```

### Step 10.2 -- Print the user-facing session summary

Build a fixed-shape summary block and print it to the user via
stdout. Every line is rendered on every code path so two runs can be
diffed side-by-side; fields that were never populated render as the
literal `(n/a)`.

```
=== architecture-doc session summary ===
Outcome:       <approved | aborted: <exit_reason>>
Mode:          <Create|Audit>
target_path:   <resolved target_path>
Output doc:    <absolute output_doc_path | (not produced)>
Files scanned: arch=<N_arch> docs=<N_docs>
Synthesis:     <synthesis line per mode, see below>
Enrichments:   language_server=<accepted|skipped|not_offered>  diagram=<accepted|skipped|not_offered>
Diagrams:      embedded=<N> (component=<true|false>, data_flow=<true|false>)
Review:        <N> iteration(s)
Scratch dir:   <scratch_dir> (removed)
=========================================
```

Field rules:

- **Outcome**: `approved` on the happy path; otherwise the literal
  `aborted: <exit_reason>` from the Step 10.1 table.
- **Mode**: always set. The Step 2 contract guarantees `mode ∈
  {Create, Audit}` by the time any Step 4-or-later code runs.
- **Output doc**: prints the absolute `<output_doc_path>` if a
  document exists at that path at the moment Step 10 runs; otherwise
  the literal `(not produced)`. In Audit mode the file always exists
  here because Step 2 detected it; in Create mode it exists only if
  Step 6 succeeded (so a Create-mode synthesis_error /
  output_missing / output_empty exit prints `(not produced)`).
- **Files scanned**: `arch=<N_arch> docs=<N_docs>` on the scan-success
  path; the literal `(n/a)` on every preflight / monorepo / scan-error
  / boundary-violation path.
- **Synthesis line**:
  - Create mode success: `decisions=<N_dec> components=<N_comp>`
  - Audit mode success: `new_decisions=<N_new> audit_findings=<N_findings> contradictions=<N_contra>`
    -- the contradictions value is rendered in **bold** when
    non-zero (mirroring the Step 9.4 review-summary emphasis); when
    zero, render plain.
  - Synthesis was never reached, errored, or produced an empty / missing
    output: the literal `(n/a)`.
- **Enrichments**: each side renders as one of three tokens:
  - `accepted` -- the probe detected the relevant category, the user
    was prompted, and the user opted in.
  - `skipped` -- the probe detected the category, the user was
    prompted, and the user declined.
  - `not_offered` -- the probe found no MCP in the relevant category,
    so no prompt was shown (the baseline-unchanged guarantee from PRD
    Feature 8).
- **Diagrams**: rendered only if `enrichment_choices.diagram ==
  accepted` AND Step 8 ran to completion. Otherwise the literal
  `(n/a)`. The `component=<true|false>` and `data_flow=<true|false>`
  flags reflect the per-diagram outcomes from Step 8.10's
  `edits_applied` log line; an entry is `false` if Step 8.6 / 8.7
  skipped that diagram or Step 8.8 failed its Edit.
- **Review**: the final value of `iteration` from Step 9 if Step 9
  was reached; otherwise the literal `(n/a)`. On the happy path this
  is `≥ 1` (every Step-9 entry runs at least one summary).
- **Scratch dir**: the resolved `<scratch_dir>` path with the literal
  trailing `(removed)` token. Step 10.4 has not actually removed it
  yet at the moment this line is printed -- printing first means the
  user sees the path even if Step 10.4 fails to remove it.

After the closing `=========================================` line,
if `audit_agent_summary` is set in orchestrator state (Audit mode
only -- see Step 7.5), print a separator and the captured text
verbatim:

```
--- Audit agent summary ---
<audit_agent_summary verbatim>
```

This honours the contract in `references/audit-mode.md` that the
post-STATUS human-readable summary surfaces in the Step 10 session
summary. The block is omitted entirely when `audit_agent_summary`
is unset (Create mode, or Audit-mode runs where the agent returned
only the STATUS line).

### Step 10.3 -- Mirror the summary into run.log

Append one fixed-shape line to `run.log` so post-mortem inspection
of an aborted run can recover the same data the user saw on the
terminal:

```
<ISO8601> INFO cleanup summary outcome=<exit_reason> mode=<Create|Audit> arch_files=<N|na> doc_files=<N|na> decisions=<N|na> components=<N|na> new_decisions=<N|na> findings=<N|na> contradictions=<N|na> enrichment_ls=<accepted|skipped|not_offered> enrichment_diagram=<accepted|skipped|not_offered> diagrams_embedded=<N|na> iterations=<N|na>
```

Every field is present on every line (the line shape is invariant)
and unpopulated fields render as the literal token `na` so a
post-mortem `grep cleanup summary run.log` returns predictable
columns.

This write must complete **before** Step 10.4 runs, because Step
10.4 destroys `run.log` along with the rest of the scratch
directory.

### Step 10.4 -- Remove the scratch directory

The scratch directory (`<target_path>/docs/.architecture-doc/`) is
the only filesystem state the skill leaves behind on disk between
runs. PRD Outputs and the design doc Security Considerations section
(`Scratch cleanup`) both require it to be removed at end of run
regardless of success / abort.

1. Run `Bash` with `rm -rf <scratch_dir>`. This is the **only**
   `rm -rf` the orchestrator ever runs. The path is the absolute
   scratch dir resolved in Step 4.1, which is always strictly inside
   `<target_path>/docs/`; the path string is constructed once in Step
   4.1 and never mutated, so the operation cannot point anywhere
   outside the target tree.
2. Verify the directory is gone with `Bash test -e <scratch_dir> ||
   echo gone`. If the check returns `gone`, the cleanup succeeded.
3. If the directory survived (permissions, an open handle from a
   crashed sub-agent, anything else), print to the user:
   ```
   Warning: failed to remove scratch directory <scratch_dir>. Remove it manually before re-running.
   ```
   Do **not** attempt a second `rm`; the user is the authoritative
   voice on what to do next. No log line is written for this
   failure because `run.log` lives inside the scratch dir and is in
   an inconsistent state by definition. The user-facing warning is
   the only disclosure surface.

### Step 10.5 -- Exit

The skill is done.

Per the **No auto-dispatch** rule at the top of this file, do not
invoke any other skill or command from Step 10. If the user wants
to act on the produced document (commit it, share it, audit it
after future code changes), they re-invoke `/architecture-doc` or
use whatever other tooling they prefer. The session summary block
from Step 10.2 is the final user-facing output of the skill.

## Error Handling

- **`target_path` does not exist or is not a directory** -- abort with the
  resolved path in the error message. Do not create the scratch directory.
- **Existing document unreadable, empty, or non-Markdown** -- offered the
  user only Overwrite or Abort (Step 2). Audit is intentionally suppressed.
- **User chose Abort** -- exit cleanly with a one-line message; no scratch
  files are created.
