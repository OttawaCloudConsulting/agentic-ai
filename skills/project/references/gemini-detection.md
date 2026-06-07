# Feature Request: Gemini-Delegated Codebase Assessment

> **Status:** Proposed (feature request — not yet implemented)
> **Affects:** `define/references/gate-0-codebase.md` (DEF-02), `build/references/codebase-refresh.md` (BUILD-02)
> **Type:** Optional capability with automatic detection and graceful fallback

This document defines the contract for delegating the codebase-assessment scan to the
Gemini CLI as an alternative to the in-session Claude `Agent` sub-agent. It specifies
detection, invocation, output handling, fallback, and integration points. An executor
reading only this file can implement and verify the feature.

---

## Motivation

The codebase-assessment scan (Gate 0 initial scan; `/build` incremental refresh) reads
20-40 files and synthesises structured findings. This is read-heavy and context-heavy.
Delegating the scan to Gemini provides:

- **Larger context window** — survey more files in a single pass than file-by-file Claude reads.
- **Context isolation** — scan tokens never enter the Claude session window (stronger isolation than the in-process `Agent` sub-agent).
- **Cost offload** — the heaviest read phase runs on a separate model/quota.

This aligns with the existing delegation rule (`.claude/rules/agent-delegation.md`): repository-wide discovery and long-context scans route to Gemini.

---

## Design Principle: Gemini scans, Claude writes

Gemini runs **read-only** and emits structured findings to **stdout**. Claude (the parent
skill) writes the assessment artifact and owns the produce-then-review gate.

This mirrors the existing architecture (sub-agent writes scratch → parent synthesises) and
keeps the integration low-risk:

- No write permissions granted to Gemini (no `--yolo`, no `--approval-mode auto_edit`, no write-trust).
- Claude retains ownership of `codebase-assessment.md` and the DEF-05 review cycle.
- Swap point is narrow: replace the `Agent` tool call with a Bash `gemini` call; synthesis (DEF-03) is unchanged.

---

## Justification & Risk-Management Decision

**Justification:** Codebase assessment is a read-only, descriptive task — exactly the repository-wide-discovery workload `agent-delegation.md` designates Gemini for. The output is human-reviewed at Gate 0 (DD-7), Claude-validated (DEF-04 cited-path pre-check), and self-correcting (refreshed each `/build`), so accuracy errors are caught, not propagated.

**Risk-management decision:** The only material risk is **data egress** — scanned files reach Google's API in addition to Anthropic's. This is managed by: (1) running Gemini **read-only** (no write/exec, no injection action surface); (2) **detection-gating** so the path only activates when the CLI is present; (3) an **explicit user consent prompt** (GEM-08) before any files are sent, making the second-vendor egress an informed choice; and (4) a **portable fallback** (GEM-06/07) so declining or unavailability costs nothing. Decision: **acceptable for this scope, gated on user consent.**

---

## Verified Environment Facts

These were confirmed empirically against the installed CLI (do not assume; re-verify if the CLI version changes):

| Fact | Value | Source |
|---|---|---|
| Binary | `gemini` on `PATH` | `command -v gemini` |
| Version tested | `0.45.2` | `gemini --version` |
| Headless flag | `-p` / `--prompt` | `gemini --help` |
| Read-only mode | `--approval-mode plan` | `gemini --help` |
| Structured output | `-o json` → stdout; `.response` = text, `.stats.tools` = tool audit | live run |
| Autonomous tool use | headless Gemini calls `list_directory`, `glob`, `read` unprompted and auto-accepts read-only tools in plan mode | live run (3 tool calls, accurate result) |
| Trust gate | headless **blocks** in untrusted dirs unless overridden | live run |
| Default model | `gemini-3.1-flash-lite` when `-m` omitted (floats forward with CLI) | live run |
| Model aliases | none — `-m` is a literal server-validated ID; `*-pro`, `-latest`, `gemini-pro` all hard-fail | live run |

**Known noise:** stderr carries extension-load errors and skill-conflict warnings (local
config artifacts). JSON output on **stdout is clean** — always discard stderr (`2>/dev/null`)
and parse stdout.

---

## Requirements

### GEM-01 — Detection (binary presence)

Before delegating, detect Gemini availability:

```bash
command -v gemini >/dev/null 2>&1
```

- **Present** → eligible for delegation (proceed to GEM-02 invocation, optionally GEM-05 liveness probe).
- **Absent** → fall back to the Claude `Agent` sub-agent (GEM-06). No warning required; this is the supported default.

### GEM-02 — Invocation contract

The verified, canonical invocation:

```bash
gemini -p "<scan-prompt>" \
  --approval-mode plan \
  --skip-trust \
  -o json \
  2>/dev/null \
  | jq -r '.response'
```

Flag rationale:

- `-p` — headless (non-interactive). Required; interactive mode hangs an automated skill.
- `--approval-mode plan` — read-only. Gemini cannot modify the working tree.
- `--skip-trust` — bypass the headless trust gate for the project root. **Mandatory** — without it, headless runs in an untrusted dir abort. Equivalent: export `GEMINI_CLI_TRUST_WORKSPACE=true`.
- `-o json` — machine-parseable; `.response` field holds the model text.
- `2>/dev/null` — discard stderr noise; JSON is on stdout.
- `jq -r '.response'` — extract the findings text.

**Model selection — accept the CLI default; do NOT pin `-m`.** Omitting `-m` inherits whatever
model the installed CLI ships as default (currently `gemini-3.1-flash-lite`), which floats forward
as the CLI updates — zero maintenance, no deprecation risk. Pinning a literal (`-m gemini-2.5-pro`)
is a **deprecation timebomb**: `-m` takes a server-validated literal ID with **no wildcard and no
`-latest`/`*-pro` alias** (verified — every alias-style name hard-fails with an API error and empty
`.response`). When a pinned model is retired the call hard-fails silently and the path degrades to
Claude (GEM-06) until a human edits the string. Decision: **unpinned default.** If a future operator
wants a quality tier, expose `-m` as a documented, opt-in override — never a hardcoded value — and
pair it with a detection-time validation probe (GEM-05) so a dead pin falls back cleanly up front
instead of per-scan.

Optional:

- `--include-directories` — add dirs outside the cwd to the scan workspace if needed.

The skill MUST run `gemini` from the project root (the directory under assessment) so the
scan targets the correct tree.

### GEM-03 — Scan prompt (Gate 0 initial)

The prompt instructs Gemini to perform the DEF-02 survey and emit findings to stdout in the
exact section structure DEF-03 expects, so Claude can synthesise without reformatting. The
prompt MUST instruct Gemini to:

1. Survey structure: list top-level directories (2 levels), inspect recent git history.
2. Select and read 20-40 files by the DEF-02 heuristics (entry points, configs, test samples, largest/most-imported modules, CI/Docker).
3. Emit findings as plain markdown with these headed sections:
   - `## Project Overview` — language, framework, purpose, maturity
   - `## File Organization` — directory structure, naming conventions
   - `## Detected Patterns` — code style, architecture, testing, error handling
   - `## Dependency Graph` — key external deps (with versions), internal module relationships
   - `## Assumptions` — inferred-but-unverifiable items
   - `## Patterns That May Need Change` — anti-patterns, inconsistencies
   - `## Open Questions` — items needing user clarification
   - `## Recent Changes` — patterns from git history
4. Cite file paths, line counts, and dependency versions. No vague statements.
5. Output findings only — do not attempt to write files.

The emitted text is the substitute for the `/tmp/codebase-scan-findings.md` scratch file in
the current DEF-02/DEF-03 flow. Claude reads it from stdout instead of from disk.

### GEM-04 — Scan prompt (`/build` incremental refresh)

For the `codebase-refresh.md` flow, Gemini receives the changed-files list (from the git
diff in that spec) plus the current assessment content, and emits only the **delta** updates
per affected section. Claude reads the current assessment, applies the delta, and writes the
file (Gemini does not write). The incremental rule still holds: read only changed files, not
a full re-scan.

### GEM-05 — Liveness probe (optional)

Binary presence does not guarantee a working call (auth expiry, quota exhaustion, network).
An optional cheap probe before the real scan:

```bash
gemini -p "ok" --approval-mode plan --skip-trust -o json 2>/dev/null \
  | jq -e '.response' >/dev/null 2>&1
```

- Exit 0 → Gemini live; proceed with delegation.
- Non-zero → fall back to Claude `Agent` (GEM-06).

If an operator opts into a pinned `-m` model (against the GEM-02 default-model recommendation),
run the probe **with that same `-m`** so a retired/invalid model is caught at detection time and
falls back cleanly (GEM-06) instead of hard-failing per-scan.

**Tradeoff:** the probe costs one Gemini call per Gate 0 / refresh. The skill MAY skip the
probe and instead detect failure from the real scan call (GEM-06 covers both paths). Default:
skip the probe; rely on runtime-failure fallback to avoid the extra call.

### GEM-06 — Fallback contract

Fall back to the existing Claude `Agent` sub-agent (current DEF-02 / BUILD-02 behaviour) when
ANY of the following:

- `gemini` not on `PATH` (GEM-01 absent)
- liveness probe fails (GEM-05, if enabled)
- the scan call exits non-zero, or
- stdout produces no parseable `.response`, or
- `.response` is empty / missing required sections

Fallback MUST be silent and automatic — the assessment is produced either way. When Gemini
is unavailable, behaviour is byte-for-byte the current implementation. The skill states which
path it took in one line (e.g. `Scan via Gemini CLI` or `Scan via Claude sub-agent`) for
transparency, but does not prompt the user.

### GEM-07 — No new hard dependency

Gemini is an **optional accelerator**. The package MUST remain fully functional with Gemini
absent. No skill may require Gemini to complete an assessment. This keeps the package portable
across environments without the CLI.

### GEM-08 — User consent prompt and persistence

When Gemini is detected (GEM-01 passes), the skill MUST ask the user whether to use it **before
any files are sent** to Gemini. This is the consent point for second-vendor data egress (see
Justification & Risk-Management Decision).

**Gating:** Prompt ONLY when Gemini is detected. If absent, do not prompt — fall back silently
to the Claude `Agent` (GEM-06). Never ask a question whose answer cannot be honored.

**Prompt** — use `AskUserQuestion` (option headers ≤12 chars):

> Gemini CLI detected. Use it for the codebase scan? It sends the scanned files to Google's API
> (larger context, lower cost). The Claude scan keeps the files within Anthropic.

| Option (header) | Result |
|---|---|
| `Gemini` | Delegate the scan to the `gemini` CLI (GEM-02). |
| `Claude` | Use the in-session `Agent` sub-agent (current behaviour). |

**Persistence:** Persist the choice so `/build` refreshes do not re-prompt on every feature.
Write a marker into the assessment file front matter on creation:

```
<!-- scan-engine: gemini -->   (or: claude)
```

`/build` reads this marker (fresh from disk, per STATE-03) and reuses the recorded engine
without re-prompting. The user can override at any time by explicit request, which updates the
marker. This keeps `progress.txt` format unchanged.

**Runtime safety net:** A `Gemini` choice is a preference, not a hard commit. If the Gemini call
later fails (auth, quota, parse), fall back silently to Claude per GEM-06 — the consent prompt
does not block assessment production.

---

## Integration Points

| Spec | Section | Change |
|---|---|---|
| `define/references/gate-0-codebase.md` | DEF-02 (Codebase Scan) | Detect Gemini (GEM-01); if present, prompt for consent (GEM-08). On `Gemini`, run scan via GEM-02/GEM-03, capture stdout findings, and record the engine marker; on `Claude` or absent, spawn the `Agent` as today. DEF-03 synthesis consumes findings from either source unchanged. |
| `build/references/codebase-refresh.md` | BUILD-02 (Sub-Agent Refresh) | Read the engine marker from the assessment file (GEM-08); reuse without re-prompting. If `gemini`, run delta scan via GEM-02/GEM-04; Claude applies delta and writes file. Else current sub-agent path. |

DEF-03 (synthesis), DEF-05 (review), DEF-04/06 (checklist), DEF-07 (approval), and the
standalone-commit step are all **unchanged** — they operate on the findings regardless of
which engine produced them.

### Distribution note

Package convention duplicates shared references into each skill's `references/` directory
(e.g. `progress-format.md` is copied per skill). On implementation, this spec's runtime
contract is referenced by both `define` and `build`. Either copy this file into
`define/references/` and `build/references/`, or have DEF-02 / BUILD-02 link to this canonical
copy under `references/`. Keep copies in sync if duplicated.

---

## Edge Cases

| Case | Handling |
|---|---|
| Untrusted directory | `--skip-trust` is mandatory in the invocation; without it headless aborts. |
| stderr noise (extension/skill-conflict errors) | Always `2>/dev/null`; parse stdout only. Non-fatal. |
| Auth/quota failure mid-scan | Non-zero exit or empty `.response` → GEM-06 fallback. |
| Truncated / malformed JSON | `jq` fails → treat as scan failure → GEM-06 fallback. |
| Gemini writes no file | By design — Gemini is read-only; Claude writes. Not an error. |
| Very large repo | Gemini's larger context is an advantage here; still instruct 20-40 representative files for the initial scan to bound cost. |
| Model returns prose outside the section template | Claude's DEF-03 synthesis normalises into the required sections; the template prompt (GEM-03) minimises this. |

---

## Out of Scope

- **Gemini writing the assessment file directly** — rejected. Requires `--yolo` / write-trust, larger blast radius, and removes Claude's artifact ownership. Read-only-emit only.
- **Gemini performing the DEF-05 review or DEF-04 checklist** — stays with Claude and the user.
- **Replacing the Claude `Agent` path** — the in-session sub-agent remains the fallback and the default when Gemini is absent.
- **Other phase skills** (`/design`, `/milestone`, `/plan-feature`) — this feature is scoped to the codebase-assessment scan only.

---

## Acceptance Criteria

- [ ] Skill detects Gemini presence via `command -v gemini` (GEM-01).
- [ ] When Gemini is detected, the user is prompted for consent before any files are sent (GEM-08); no prompt when absent.
- [ ] The engine choice is persisted as a marker in the assessment file and reused by `/build` refresh without re-prompting (GEM-08).
- [ ] When present and consented, Gate 0 scan runs via the verified `gemini` invocation (GEM-02/GEM-03) and produces a valid assessment after Claude synthesis.
- [ ] When absent, Gate 0 scan runs via the Claude `Agent` sub-agent with identical output structure (GEM-06/GEM-07).
- [ ] `/build` refresh delegates the delta scan to Gemini when available, with Claude applying and committing the update (GEM-04).
- [ ] Gemini runs strictly read-only — no working-tree modifications by Gemini in any path.
- [ ] Scan failure (any cause) falls back silently to the Claude sub-agent; the assessment is always produced.
- [ ] The skill reports which scan engine was used in one line.
- [ ] Package remains fully functional with Gemini uninstalled (GEM-07).
