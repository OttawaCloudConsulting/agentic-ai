# Gate 0: Codebase Assessment

Scans the existing codebase and produces a structured assessment for use in subsequent gates. This reference contains the complete Gate 0 specification -- an executor reading only this file can run the full Gate 0 flow.

`{slug}` is read from the `# Project-ID: <slug>` header in `progress.txt` at session start. All artifact paths in this document use `.project/{slug}/` as the base path.

## Greenfield Detection (DEF-01)

Before running the codebase scan, check whether the project is greenfield. ALL of the following conditions must be true to classify as greenfield and skip Gate 0:

1. No `src/`, `app/`, or `lib/` directories exist
2. No dependency manifests exist: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`
3. Fewer than 5 non-config files (config files include: README, LICENSE, .gitignore, .editorconfig, .prettierrc, and similar dotfiles)
4. Only boilerplate files present (README + license + gitignore pattern)

**If ALL conditions are true:** Skip Gate 0 entirely. Record in progress.txt:

```
[-] Gate 0: Codebase Alignment  Skipped (greenfield)
```

Proceed directly to Gate WB.

**If ANY condition is false:** Proceed with the codebase scan below.

**Edge case:** Monorepos with sparse content should be treated as brownfield (conservative). If uncertain whether the project is greenfield, run Gate 0 -- it is cheaper to scan unnecessarily than to miss existing patterns.

## Codebase Scan (DEF-02)

### Gemini Detection and Consent (GEM-01, GEM-08)

Before spawning any sub-agent, detect whether the Gemini CLI is available:

```bash
command -v gemini >/dev/null 2>&1
```

**Absent:** Proceed directly to [Claude Sub-Agent Scan](#claude-sub-agent-scan) below. Do not prompt — never ask a question whose answer cannot be honored.

**Present:** Prompt for engine choice via `AskUserQuestion` before any files are sent:

- **Question:** "Gemini CLI detected. Use it for the codebase scan? It sends the scanned files to Google's API (larger context, lower cost). The Claude scan keeps the files within Anthropic."
- **Header:** `Scan engine`
- **Options:**
  - `Gemini` — delegate the scan to Gemini CLI
  - `Claude` — run via the Claude in-session sub-agent

Record the choice as `gemini` or `claude`. This value is written to the engine marker in DEF-03.

**If `Gemini` chosen:** Run the Gemini invocation (see [Gemini Invocation (GEM-02)](#gemini-invocation-gem-02) below). On any failure — non-zero exit, empty stdout, unparseable JSON, or missing required sections — fall back silently to the Claude sub-agent. The engine marker in DEF-03 reflects the **actual** engine used: a runtime fallback records `claude` regardless of the consented choice.

**If `Claude` chosen or Gemini absent:** Proceed to Claude sub-agent scan below.

### Optional Liveness Probe (GEM-05)

> **Disabled by default. Do not run a probe unless `-m <model-id>` is pinned.** When `-m` is pinned, run the probe with that same flag before the scan. The real scan call is sufficient for failure detection in all other cases.

When `-m <model-id>` is pinned, run the probe first:

```bash
PROBE_RAW=$(gemini -m <model-id> -p "ok" --approval-mode plan --skip-trust -o json 2>/dev/null)
PROBE_EXIT=$?
printf '%s' "$PROBE_RAW" | jq -e '.response' >/dev/null 2>&1 || PROBE_EXIT=1
```

**Probe failure (`$PROBE_EXIT` non-zero):** Fall back silently to the Claude sub-agent. Do not surface the failure to the user.

### Gemini Invocation (GEM-02)

Run the Gate 0 scan using the `Bash` tool, from the project root.

**Step 1 — Pre-collect git history.** Gemini plan mode provides only `list_directory`, `glob`, and `read` tools — no exec tools. Claude collects git history before the invocation and injects it into the prompt:

```bash
GIT_LOG=$(git log --oneline -20 2>/dev/null || echo "(no git history)")
```

**Step 2 — Build the scan prompt.** Take the verbatim prompt text from [Gate 0 Scan Prompt (GEM-03)](#gate-0-scan-prompt-gem-03) below and substitute the `{{GIT_LOG}}` placeholder with the output of Step 1. Assign to `SCAN_PROMPT`.

**Step 3 — Run Gemini.** Capture raw output and the exit code in separate steps to prevent pipeline exit-code masking:

```bash
GEMINI_RAW=$(gemini -p "$SCAN_PROMPT" --approval-mode plan --skip-trust -o json 2>/dev/null)
GEMINI_EXIT=$?
FINDINGS=$(printf '%s' "$GEMINI_RAW" | jq -er '.response // empty' 2>/dev/null)
```

When `-m <model-id>` is pinned, add it immediately after `gemini` in the same command:

```bash
GEMINI_RAW=$(gemini -m <model-id> -p "$SCAN_PROMPT" --approval-mode plan --skip-trust -o json 2>/dev/null)
```

**Flags — do not modify:**

| Flag | Purpose |
|------|---------|
| `--approval-mode plan` | Read-only mode. Restricts Gemini to `list_directory`, `glob`, and `read` tools; no write tools are offered. |
| `--skip-trust` | Bypasses the headless trust gate required for untrusted directories. Safe here because plan mode eliminates the write/exec surface. Equivalent: `GEMINI_CLI_TRUST_WORKSPACE=true`. |
| `-o json` | Structured output. Findings text is in the `.response` field of the JSON envelope. |
| `2>/dev/null` | Discard stderr unconditionally. stderr carries non-fatal extension-load and skill-conflict warnings from local config; stdout JSON is always clean. |
| `-m` omitted | **Do not set `-m` by default.** The CLI default model floats forward with updates. A hardcoded model ID silently hard-fails on retirement — no wildcard or `-latest` alias exists. `-m` is a documented opt-in override only. |

**Failure handling:** Check `$GEMINI_EXIT` first, then validate `$FINDINGS`. On any of the following conditions, fall back silently to [Claude Sub-Agent Scan](#claude-sub-agent-scan) below. Do not surface the error to the user.

- `$GEMINI_EXIT` is non-zero
- `$GEMINI_RAW` is empty
- `jq` parse error (unparseable JSON — `$FINDINGS` is empty or null from the `jq` call)
- `$FINDINGS` is empty or missing any of the eight GEM-03 section headings (`## Project Overview`, `## File Organization`, `## Detected Patterns`, `## Dependency Graph`, `## Assumptions`, `## Patterns That May Need Change`, `## Open Questions`, `## Recent Changes`)

When falling back, the engine marker written in DEF-03 records `claude` (the actual engine used), regardless of the consented choice.

**On success:** `$FINDINGS` is the findings text. Treat it as the equivalent of the `/tmp/codebase-scan-findings.md` scratch file produced by the Claude sub-agent path. Proceed to [Assessment Production (DEF-03)](#assessment-production-def-03) with this text as findings.

### Gate 0 Scan Prompt (GEM-03)

Pass the following prompt verbatim as the `-p` argument. It drives the DEF-02 survey and produces the eight DEF-03 section headings on stdout:

---

You are performing a read-only codebase assessment. Do not write or modify any files.

**Step 1 — Survey structure:**
- Use `list_directory` to list all directories 2 levels deep from the project root.
- Review the recent git history below (pre-collected by the parent skill — you have no exec tools):

{{GIT_LOG}}

**Step 2 — Select 20–40 files to read** using these heuristics:
- Entry points: main files, index files, application entry points
- Configuration files: package.json, pyproject.toml, tsconfig.json, webpack config, CI/CD configs, Dockerfiles
- Test files: a representative sample of test patterns and frameworks in use
- Key modules: largest files and most-imported or most-referenced modules
- Infrastructure: deployment scripts, environment configs

Read each selected file using your read tools.

**Step 3 — Output findings as plain markdown under exactly these eight headings. Do not write files. Do not add any preamble or summary after the final heading.**

## Project Overview
Language, framework, purpose, maturity level. Cite the entry-point file path and its line count.

## File Organization
Directory structure and naming patterns. Cite specific directory and file paths.

## Detected Patterns
Code style, architecture patterns, testing approach, error handling conventions. Cite file paths and line numbers for each pattern named.

## Dependency Graph
All key external dependencies with exact versions from manifest files (e.g., package.json, pyproject.toml). Cite the manifest file path. Include internal module relationships.

## Assumptions
Things inferred from code that cannot be verified without user input. Each assumption must cite the source file path.

## Patterns That May Need Change
Anti-patterns, inconsistencies, or conventions that should not be carried forward. Cite the file path and approximate line count.

## Open Questions
Specific ambiguities that require user clarification before proceeding.

## Recent Changes
Patterns from git history indicating current development focus. Cite commit hashes and affected file paths.

No vague statements. Every factual claim must cite a file path, line count, or dependency version. Output findings only — no preamble, no postscript, do not write files.

---

### Claude Sub-Agent Scan

Spawn a sub-agent using the `Agent` tool to perform a deep codebase scan. The agent reads 20-40 files and writes structured findings to a temporary scratch file.

### Agent Prompt

Instruct the agent to:

1. **Survey the project structure:**
   - Run `ls -R` (first 2 levels) for directory overview
   - Run `git log --oneline -20` for recent change patterns

2. **Select 20-40 files to read using these heuristics:**
   - Entry points: main files, index files, app entry points
   - Configuration files: package.json, tsconfig.json, webpack config, etc.
   - Test files: sample of test patterns and frameworks used
   - Key modules: largest files, most-imported files
   - Infrastructure: CI/CD configs, Dockerfiles, deployment scripts

3. **Read each selected file** using the Read tool.

4. **Write structured findings** to a temporary scratch file (e.g., `/tmp/codebase-scan-findings.md`) with these sections:
   - **Project Overview** -- language, framework, purpose
   - **File Organization** -- directory structure, naming patterns
   - **Detected Patterns** -- code style, architecture patterns, testing approach
   - **Dependency Graph** -- key dependencies, internal module relationships
   - **Assumptions** -- things the agent inferred but cannot verify
   - **Patterns That May Need Change** -- anti-patterns, inconsistencies
   - **Open Questions** -- things that need user clarification
   - **Recent Changes** -- patterns from git log

### Agent Tool Access

The agent uses only: `Read`, `Bash` (for `ls`, `git log`), and `Glob` tools.

## Assessment Production (DEF-03)

After the scan completes (either engine), synthesize findings into the final assessment:

1. Obtain findings from the completed scan:
   - **Gemini path:** Use the stdout text captured from the Gemini invocation (GEM-02) directly as findings. No file to read.
   - **Claude sub-agent path:** Read the agent's scratch file (e.g., `/tmp/codebase-scan-findings.md`).
2. Create `.project/{slug}/docs/` directory if it does not exist: `mkdir -p .project/{slug}/docs`
3. Write `.project/{slug}/docs/codebase-assessment.md`. Begin the file with the engine marker HTML comment on the very first line, followed by the required sections:

   ```
   <!-- scan-engine: gemini -->
   ```

   Use the **actual engine used** — if the Gemini path fell back at runtime, write `claude` regardless of the consented choice:

   ```
   <!-- scan-engine: claude -->
   ```

4. Write the required sections after the marker:

### Required Assessment Sections

1. **Project Overview** -- language, framework, purpose, maturity level
2. **File Organization** -- directory structure, naming conventions, key locations
3. **Detected Patterns** -- code style, architecture patterns, testing approach, error handling
4. **Dependency Graph** -- key external dependencies (with versions), internal module relationships
5. **Assumptions** -- things inferred from code that cannot be verified without user input
6. **Patterns That May Need Change** -- anti-patterns, inconsistencies, or conventions that should not be carried forward
7. **Open Questions** -- ambiguities that need user clarification before proceeding
8. **Recent Changes** -- patterns from git history indicating current development focus

The assessment must be factual and specific -- cite file paths, line counts, dependency versions. Avoid vague statements.

5. **Claude sub-agent path only:** Clean up the scratch file after synthesis: `rm /tmp/codebase-scan-findings.md`. Skip this step on the Gemini path (no scratch file was written).

6. Output one line reporting the scan engine used. Do not prompt:
   - Gemini path (no runtime fallback): `Scan via Gemini CLI`
   - Claude path (fallback or chosen): `Scan via Claude sub-agent`

## Review Phase (DEF-05)

Present the assessment to the user using the produce-then-review cycle:

1. **Present a summary** of the assessment to the user. Highlight:
   - Key findings (language, framework, architecture)
   - Detected patterns the model will follow
   - Patterns flagged for deviation
   - Open questions that need answers
   - Assumptions that need validation

2. **Use `AskUserQuestion`** with options:
   - **Approve** -- assessment is accurate, proceed to checklist validation
   - **Revise** -- assessment needs corrections

3. **If Revise:** Ask the user what needs changing. Apply edits to `.project/{slug}/docs/codebase-assessment.md`. Re-present the updated summary. Repeat until the user selects Approve.

4. **If Approve:** Proceed to Checklist Validation.

## Checklist Validation (DEF-04, DEF-06)

Generate and validate the review checklist:

1. Create `.project/{slug}/docs/reviews/` directory if needed: `mkdir -p .project/{slug}/docs/reviews`

2. Generate `.project/{slug}/docs/reviews/gate-0-review.md` using the Gate 0 section from `references/review-checklist-template.md`. Start with the file header:

   ```
   # Gate 0 Review -- Codebase Alignment

   **Artifact:** .project/{slug}/docs/codebase-assessment.md
   **Status:** [ ] Pending
   **Reviewer(s):**
   **Date:**
   ```

3. Include the Gate 0 static checklist items:
   - `[ ] Are the detected patterns accurate for the current codebase?`
   - `[ ] Are there patterns listed as "carry forward" that should be changed?`
   - `[ ] Are there existing patterns not detected that the model should follow?`
   - `[ ] Are the open questions answerable? Provide answers.`
   - `[ ] Are the assumptions stated in the assessment correct?`

4. Add content-specific `[Auto]` items based on actual assessment content. Examples:
   - `[ ] [Auto] Verify assumption: "{specific assumption from assessment}"`
   - `[ ] [Auto] Confirm pattern: "{specific pattern detected}"`
   - `[ ] [Auto] Review deviation: "{specific anti-pattern flagged}"`

5. **Claude pre-checks** items it can verify programmatically:
   - File `.project/{slug}/docs/codebase-assessment.md` exists
   - All required sections are present
   - File paths cited in the assessment exist on disk

6. **Present remaining unchecked items** to the user for resolution.

7. **All items must be `[x]` (verified) or `[-]` (N/A with reason)** before proceeding. No item may remain as `[ ]`.

8. Update the checklist `**Status:**` to `[x] Approved` with the current date.

## Gate Approval (DEF-07)

Record the gate approval in progress.txt:

1. Read `references/progress-format.md` for the exact gate entry format.

2. Update the Gate 0 line in progress.txt from:
   ```
   [ ] Gate 0: Codebase Alignment
   ```
   to:
   ```
   [x] Gate 0: Codebase Alignment  Approved: <YYYY-MM-DD>  .project/{slug}/docs/codebase-assessment.md
   ```
   where `<YYYY-MM-DD>` is the current date.

3. Only progress.txt is updated at this step -- no other state files are modified.

4. Proceed to Gate WB (read `references/gate-wb-working-backwards.md`).
