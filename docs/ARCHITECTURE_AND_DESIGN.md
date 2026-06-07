# Architecture and Design: Gemini-Delegated Codebase Assessment

> Authoritative design reference for the optional Gemini-delegated codebase-assessment scan.
> Source spec: `skills/project/references/gemini-detection.md`.

## Overview

The `skills/project/` suite runs a codebase-assessment scan at two points: the Gate 0 initial scan in `/define` (DEF-02) and the incremental refresh in `/build` (BUILD-02). Gate 0 reads 20–40 representative files; the `/build` incremental refresh reads only changed files. Both synthesise structured findings — a read-heavy, context-heavy phase.

This design adds an **optional, read-only** alternative: delegate the scan to the Gemini CLI. Gemini surveys the tree and emits structured findings to stdout; Claude reads stdout, synthesises (DEF-03 unchanged), and writes the assessment artifact. Claude retains ownership of the artifact and the produce-then-review gate. The capability activates only when the `gemini` binary is present **and** the user consents to second-vendor data egress, and degrades silently to the existing Claude `Agent` sub-agent on any absence, decline, or runtime failure.

Core principle: **Gemini scans, Claude writes.** No write/exec permissions are granted to Gemini in any path. The integration swap point is deliberately narrow — replace the `Agent` tool call with a Bash `gemini` call; everything downstream (synthesis, review, checklist, approval, commit) is unchanged.

## Verified Environment Facts

Confirmed empirically against the installed CLI (`gemini 0.45.2`). Re-verify if the CLI version changes.

| Fact | Value | Source |
|---|---|---|
| Binary | `gemini` on `PATH` | `command -v gemini` |
| Version tested | `0.45.2` | `gemini --version` |
| Headless flag | `-p` / `--prompt` | `gemini --help` |
| Read-only mode | `--approval-mode plan` | `gemini --help` |
| Structured output | `-o json` → stdout; `.response` = text, `.stats.tools` = tool audit | live run |
| Autonomous tool use | headless Gemini calls `list_directory`, `glob`, `read` unprompted; auto-accepts read-only tools in plan mode | live run (3 tool calls, accurate result) |
| Trust gate | headless **blocks** in untrusted dirs unless overridden with `--skip-trust` or `GEMINI_CLI_TRUST_WORKSPACE=true` | live run |
| Default model | `gemini-3.1-flash-lite` when `-m` omitted; floats forward with CLI updates | live run |
| Model aliases | none — `-m` is a literal server-validated ID; `*-pro`, `-latest`, `gemini-pro` all hard-fail | live run |
| stderr noise | extension-load errors and skill-conflict warnings from local config; stdout JSON is clean | live run |

> **Noise handling:** JSON output on stdout is always clean. Discard stderr unconditionally (`2>/dev/null`) — it carries only non-fatal extension-load and skill-conflict warnings from local config artifacts.

## Component Diagram

```
                         ┌──────────────────────────────────────────────┐
                         │  /define Gate 0 (DEF-02)  │  /build (BUILD-02) │
                         └───────────────┬───────────┴─────────┬─────────┘
                                         │                      │
                              GEM-01 detect gemini      read engine marker
                              command -v gemini          from assessment
                                         │                front matter
                          ┌──────absent──┘                      │
                          ▼                          claude ────┤──── gemini
              ┌───────────────────────┐                  │             │
              │ Claude Agent sub-agent│◄─────────────────┘             │
              │ (fallback / default)  │◄───── any failure / decline ───┤
              └───────────┬───────────┘                                │
                          │                          present:          │
                          │                  GEM-08 consent prompt     │
                          │                  (AskUserQuestion)         │
                          │                          │                 │
                          │                   claude─┤─gemini          │
                          │                          ▼                 ▼
                          │              GEM-02 invocation     GEM-04 delta scan
                          │              gemini -p … plan      (changed files +
                          │              --skip-trust -o json   current assessment)
                          │              2>/dev/null|jq .response       │
                          │                          │                 │
                          │                          ▼                 ▼
                          │              findings to stdout    delta to stdout
                          │              (read-only)           (read-only)
                          └──────────────┬───────────┴─────────────────┘
                                         ▼
                          Claude synthesis (DEF-03) / apply delta
                                         ▼
                          Claude writes codebase-assessment.md
                          + engine marker  (Gemini never writes)
                                         ▼
                          DEF-05 review · DEF-04 checklist · DEF-07
                          approval · commit   (Claude + user, unchanged)
```

## Data Flow

**Gate 0 initial scan (`/define`, DEF-02):**

1. Detect Gemini: `command -v gemini >/dev/null 2>&1`.
2. Absent → spawn Claude `Agent` sub-agent (current behaviour); skip to step 7. No prompt.
3. Present → `AskUserQuestion` consent prompt (before any files sent). `Claude` → Agent path (step 7). `Gemini` → continue.
4. Run `gemini -p "<Gate-0 scan prompt>" --approval-mode plan --skip-trust -o json` from the project root, capturing the raw JSON and exit code separately, then extract findings via `jq -er '.response // empty'` (never pipe `gemini` directly into `jq` — that masks the exit code; see gate-0-codebase.md GEM-02 for the exact capture contract). The prompt instructs Gemini to: (a) survey structure — list top-level dirs 2 levels deep and inspect recent git history; (b) select and read 20–40 files by DEF-02 heuristics (entry points, configs, test samples, largest/most-imported modules, CI/Docker); (c) emit findings as plain markdown under the eight required headings: `## Project Overview`, `## File Organization`, `## Detected Patterns`, `## Dependency Graph`, `## Assumptions`, `## Patterns That May Need Change`, `## Open Questions`, `## Recent Changes`; (d) cite file paths, line counts, and dependency versions — no vague statements; (e) output findings only — do not write files. Gemini autonomously calls `list_directory`/`glob`/`read` (auto-accepted in plan mode).
5. On non-zero exit / empty / unparseable / missing-sections → silent fallback to Claude `Agent` (step 7).
6. Claude reads findings from stdout (substitute for `/tmp/codebase-scan-findings.md`).
7. Claude synthesises (DEF-03) and writes `codebase-assessment.md`, stamping the engine marker in front matter. The marker records the **actual engine used**: if the Gemini path fell back at runtime (GEM-06), the marker is stamped `claude` regardless of the consented choice.
8. DEF-05 review / DEF-04 checklist / DEF-07 approval / standalone commit — unchanged.

**Incremental refresh (`/build`, BUILD-02):**

1. Read the engine marker from the assessment front matter (fresh from disk, STATE-03).
2. `claude` → current sub-agent delta path.
3. `gemini` → run delta scan: Gemini receives the changed-files list (derived from the git diff in BUILD-02) plus the current assessment content, and emits only the per-section delta to stdout. Read only the changed files, not a full re-scan.
4. Any failure → silent fallback to Claude sub-agent.
5. Claude reads current assessment, applies delta, writes file, commits (unchanged).

## Integration Points

| Spec | Section | GEM Requirements | Change |
|---|---|---|---|
| `define/references/gate-0-codebase.md` | DEF-02 (Codebase Scan) | GEM-01, GEM-02, GEM-03, GEM-06, GEM-07, GEM-08 | Detect Gemini (GEM-01); if present, prompt for consent (GEM-08). On `Gemini`: run scan via GEM-02/GEM-03, capture stdout findings, write engine marker. On `Claude` or absent: spawn `Agent` as today (GEM-06). Package remains functional with Gemini absent (GEM-07). DEF-03 synthesis consumes findings from either source unchanged. |
| `build/references/codebase-refresh.md` | BUILD-02 (Sub-Agent Refresh) | GEM-02, GEM-04, GEM-06, GEM-07, GEM-08 | Read engine marker from assessment file (GEM-08); reuse without re-prompting. If `gemini`: run delta scan via GEM-02/GEM-04; Claude applies delta and writes file (GEM-06 fallback on any failure). Package remains functional with Gemini absent (GEM-07). Else: current sub-agent path. |

DEF-03 (synthesis), DEF-05 (review), DEF-04/06 (checklist), DEF-07 (approval), and the standalone-commit step are all **unchanged** — they operate on findings regardless of which engine produced them.

## Component Inventory

| # | Component | Type / Technology | Purpose |
|---|-----------|-------------------|---------|
| 1 | Detection check | Bash `command -v gemini` | Gate the whole path on binary presence (GEM-01). |
| 2 | Consent prompt | `AskUserQuestion` | Obtain informed consent for second-vendor egress before any files sent (GEM-08). Prompt text: "Gemini CLI detected. Use it for the codebase scan? It sends the scanned files to Google's API (larger context, lower cost). The Claude scan keeps the files within Anthropic." Options (headers ≤12 chars): `Gemini` (delegate) and `Claude` (in-session sub-agent). |
| 3 | Engine marker | Front-matter HTML comment in `codebase-assessment.md` | Persist engine choice; read by `/build` to avoid re-prompting (GEM-08). |
| 4 | Gemini invocation | Bash `gemini` CLI (`-p … --approval-mode plan --skip-trust -o json`) + `jq` | Read-only scan emitting findings to stdout (GEM-02). |
| 5 | Gate 0 scan prompt | Prompt template | Drive DEF-02 survey, output the eight DEF-03 sections (GEM-03). |
| 6 | Delta scan prompt | Prompt template | Drive incremental per-section delta for `/build` (GEM-04). |
| 7 | Liveness probe (optional) | Bash `gemini -p "ok" … \| jq -e` | Optional pre-scan validation; disabled by default (GEM-05). |
| 8 | Claude `Agent` sub-agent | In-session sub-agent | Default + fallback scanner; owns synthesis in all paths (GEM-06). |
| 9 | Synthesis (DEF-03) | Claude (parent skill) | Convert findings → `codebase-assessment.md`; engine-agnostic. |

## Security Model

### Encryption

In transit: both engines use HTTPS to their respective vendor APIs (Anthropic for Claude, Google for Gemini). No at-rest storage introduced beyond the existing assessment artifact on the local working tree.

### Access Control

Gemini runs strictly **read-only** via `--approval-mode plan`: in plan mode the CLI restricts Gemini's available tool set to read-only file-system operations (`list_directory`, `glob`, `read`) — no exec or write tools are offered. The working tree cannot be modified. No `--yolo`, no `--approval-mode auto_edit`, no write-trust granted. The headless trust gate is bypassed with `--skip-trust` (or `GEMINI_CLI_TRUST_WORKSPACE=true`) — required for headless runs in untrusted dirs, and safe because the plan-mode tool restriction eliminates the write/exec surface entirely.

### Data Egress (primary security concern)

On the Gemini path, scanned file contents reach Google's API in addition to Anthropic's. Managed by four controls:

1. **Read-only** — no write/exec, no injection action surface.
2. **Detection-gating** — the path activates only when the CLI is present.
3. **Explicit consent** — `AskUserQuestion` (GEM-08) before any files are sent; the second-vendor egress is an informed choice. Never prompts when Gemini is absent (no unanswerable questions).
4. **Portable fallback** — declining or unavailability costs nothing (GEM-06/07).

Decision: acceptable for this scope, gated on user consent.

### Audit and Logging

`-o json` returns `.stats.tools` — an audit of the tools Gemini invoked during the scan (verified: headless Gemini reports its `list_directory`/`glob`/`read` calls). stderr carries extension-load and skill-conflict noise from local config artifacts; always discard with `2>/dev/null` and parse stdout only. The skill reports the engine used in one line for transparency.

## File Organization

```
skills/project/
├── references/
│   └── gemini-detection.md          # Canonical runtime contract (source spec)
├── define/
│   └── references/
│       └── gate-0-codebase.md        # DEF-02 — integrate detection/consent/invocation
└── build/
    └── references/
        └── codebase-refresh.md       # BUILD-02 — read marker, route delta scan
```

Distribution note: package convention duplicates shared references into each skill's `references/`. Either copy `gemini-detection.md` into `define/references/` and `build/references/`, or have DEF-02 / BUILD-02 link to the canonical copy under `references/`. Keep copies in sync if duplicated.

## Configuration

### Required

| Parameter | Type | Validation | Description |
|-----------|------|------------|-------------|
| _(none)_ | — | — | Auto-detected and consent-gated; no required configuration. |

### Optional — Engine selection

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| Scan engine | `AskUserQuestion` choice (option headers ≤12 chars) | prompt on detection | `Gemini` or `Claude`; persisted in assessment front matter; reused by `/build`. |

### Optional — Gemini invocation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-m <model-id>` | CLI flag (opt-in) | unset → CLI default model | Pin a model. Documented opt-in only; pair with the GEM-05 probe at detection time. |
| `--include-directories <dirs>` | CLI flag | unset | Add dirs outside cwd to the scan workspace. |
| `--skip-trust` / `GEMINI_CLI_TRUST_WORKSPACE=true` | flag / env var | flag set in invocation | Bypass the headless trust gate (mandatory for headless untrusted-dir runs). |
| Liveness probe | toggle | disabled | Pre-scan validation; one extra Gemini call per Gate 0 / refresh. |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `codebase-assessment.md` | markdown artifact | Written by Claude from findings (either engine); identical structure regardless of source. |
| `<!-- scan-engine: gemini\|claude -->` | front-matter marker | Persisted engine choice; read by `/build`. |
| Engine report line | stdout | One line stating which engine ran. |

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Gemini scans, Claude writes — Gemini emits findings to stdout, never writes files | Keeps Claude's artifact ownership and the produce-then-review gate; mirrors the existing sub-agent-writes-scratch → parent-synthesises architecture; minimises blast radius (no write-trust needed). |
| 2 | Read-only via `--approval-mode plan`; no `--yolo` / `auto_edit` / write-trust | The scan is descriptive; granting write access adds risk with no benefit. Eliminates the injection action surface. |
| 3 | Detection-gate on `command -v gemini` | The path is an optional accelerator; absent binary must degrade to the supported default with no warning. |
| 4 | Explicit user consent before any files sent (GEM-08) | Second-vendor (Google) data egress is a material, informed choice; consent is the egress control point. |
| 5 | Prompt ONLY when Gemini is detected | Never ask a question whose answer cannot be honored — if Gemini is absent, fall back silently. |
| 6 | Persist engine choice as a front-matter marker in the assessment file | `/build` reuses the choice without re-prompting on every feature; keeps `progress.txt` format unchanged. |
| 7 | Marker read fresh from disk per refresh (STATE-03), overridable by explicit request | Honors single-source-of-truth state reads; lets the user switch engines deliberately. |
| 8 | Accept the CLI default model — do NOT pin `-m` by default | `-m` takes a server-validated literal ID with no wildcard / `-latest` / `*-pro` alias (verified — aliases hard-fail). A pinned model silently hard-fails on retirement and degrades to Claude until a human edits the string. Unpinned floats forward with the CLI: zero maintenance, no deprecation timebomb. |
| 9 | `-m` available only as a documented opt-in override, paired with a detection-time probe | Operators wanting a quality tier can pin one, but a dead pin is then caught up front (GEM-05) and falls back cleanly instead of per-scan. |
| 10 | Liveness probe disabled by default | The probe costs one Gemini call per Gate 0 / refresh; runtime-failure fallback (GEM-06) covers the same cases without the extra call. Enable only with a pinned `-m`. |
| 11 | Silent, automatic fallback on any failure (absent / probe fail / non-zero / empty / unparseable / missing sections) | The assessment must always be produced; a `Gemini` consent choice is a preference, not a hard commit. |
| 12 | `2>/dev/null`; parse stdout `.response` only | stderr carries non-fatal extension/skill-conflict noise; stdout JSON is clean. |
| 13 | `--skip-trust` mandatory in the invocation | Headless runs in untrusted dirs abort without it; equivalent env var `GEMINI_CLI_TRUST_WORKSPACE=true`. |
| 14 | Scan prompt enforces the eight DEF-03 section headings + cited paths/line-counts/versions | Lets Claude synthesise without reformatting; minimises out-of-template prose; bans vague statements. |
| 15 | `/build` delta scan reads only changed files, not a full re-scan | Preserves the existing incremental-refresh rule; bounds cost. |
| 16 | No new hard dependency (GEM-07) | Package must stay fully functional with Gemini uninstalled; portability across environments. |
| 17 | Scope limited to the codebase-assessment scan | `/design`, `/milestone`, `/plan-feature` are out of scope; bounds the change to one well-understood read-only workload. |
| 18 | Report the engine used in one line; do not prompt for it | Transparency without friction; the choice was already made at consent or via the marker. |

## Deployment Workflow

This is a skill-package change, not a deployed service. Rollout is documentation/contract edits validated by the produce-then-review gate:

1. Land the canonical runtime contract under `skills/project/references/gemini-detection.md` (source spec — present).
2. Integrate DEF-02 (`define/references/gate-0-codebase.md`): detection → consent → invocation → marker; synthesis unchanged.
3. Integrate BUILD-02 (`build/references/codebase-refresh.md`): read marker → route delta scan → apply/commit.
4. Sync duplicated reference copies if the distribution uses per-skill `references/` duplication.
5. Validate against the acceptance criteria: Gemini-present-consented, Gemini-absent, `/build` reuse, forced-failure fallback, read-only verification, uninstalled-package functionality.

## Dependency Graph

```
Feature 1: Architecture & Design doc
    └── Feature 2: Detection + Consent (GEM-01, GEM-08)
            ├── Feature 3: Gate 0 invocation + scan prompt (GEM-02, GEM-03)  [DEF-02]
            │       └── Feature 5: Fallback + portability + reporting (GEM-05/06/07)
            └── Feature 4: /build delta refresh (GEM-04)                      [BUILD-02]
                    └── Feature 5: Fallback + portability + reporting

Runtime call chain (per scan):
  detection (command -v gemini)
      └── consent / marker read
              └── gemini invocation  ──fail──► Claude Agent sub-agent (fallback)
                      └── stdout findings
                              └── Claude synthesis (DEF-03)
                                      └── Claude writes assessment + marker
```

## Out of Scope

| Item | Rationale |
|------|-----------|
| Gemini writing the assessment file directly | Requires `--yolo`/write-trust; larger blast radius; removes Claude artifact ownership. Read-only-emit only. |
| Gemini performing DEF-05 review or DEF-04 checklist | Review and checklist stay with Claude and the user. |
| Replacing the Claude `Agent` path | It remains the fallback and the default when Gemini is absent. |
| Hardcoding a Gemini model | Deprecation timebomb (see Decision #8); unpinned default only, `-m` opt-in. |
| Delegation for `/design`, `/milestone`, `/plan-feature` | Scoped to the codebase-assessment scan only. |
| Changing `progress.txt` format | Engine marker lives in the assessment front matter. |
