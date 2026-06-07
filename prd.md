# PRD: Gemini-Delegated Codebase Assessment

## Summary

Add an optional capability to the `skills/project/` suite that delegates the codebase-assessment scan (Gate 0 initial scan in `/define`; incremental refresh in `/build`) to the Gemini CLI as an alternative to the in-session Claude `Agent` sub-agent. Gemini runs **read-only** and emits structured findings to stdout; Claude synthesises and writes the artifact. The path activates only when the `gemini` binary is present and the user consents, and falls back silently to the existing Claude sub-agent in every failure or absence case.

## Goals

- Offer Gemini as a read-only accelerator for the read-heavy, context-heavy codebase scan (larger context window, scan-token isolation from the Claude session, cost offload to a separate model/quota).
- Keep Claude as the owner of the assessment artifact and the produce-then-review gate — "Gemini scans, Claude writes."
- Activate the path only on `gemini` presence **and** explicit user consent for second-vendor data egress.
- Fall back to the existing Claude `Agent` sub-agent silently and automatically on any absence, decline, or failure — byte-for-byte current behaviour when Gemini is unavailable.
- Persist the engine choice so `/build` refreshes do not re-prompt.
- Add **no new hard dependency**: the package stays fully functional with Gemini uninstalled.

## Non-Goals

| Item | Rationale |
|------|-----------|
| Gemini writing the assessment file directly | Requires `--yolo`/write-trust, larger blast radius, removes Claude's artifact ownership. Read-only-emit only. |
| Gemini performing the DEF-05 review or DEF-04 checklist | Review and checklist stay with Claude and the user. |
| Replacing the Claude `Agent` path | The in-session sub-agent remains the fallback and the default when Gemini is absent. |
| Pinning a specific Gemini model (`-m`) by default | A literal model ID is a deprecation timebomb (no wildcard/`-latest` alias; silent hard-fail on retirement). Accept the CLI default; `-m` is an opt-in documented override only. |
| Extending delegation to `/design`, `/milestone`, `/plan-feature` | Scoped to the codebase-assessment scan only. |
| Changing `progress.txt` format | Engine marker lives in the assessment file front matter, not `progress.txt`. |

## Architecture

```
/define Gate 0  (DEF-02)                         /build refresh (BUILD-02)
      │                                                   │
      ▼                                                   ▼
 GEM-01 detect `command -v gemini`                read engine marker from
      │                                            assessment front matter
 present? ──no──► Claude Agent sub-agent ◄───── claude ──┘
      │ yes              (fallback, GEM-06/07)            │ gemini
      ▼                          ▲                        ▼
 GEM-08 consent prompt           │                  GEM-02 + GEM-04
 (AskUserQuestion)               │                  delta scan call
      │                          │ any failure /          │
   Gemini? ──claude──────────────┤ empty / decline        │
      │ gemini                   │                         │
      ▼                          │                         ▼
 GEM-02 invocation ──────────────┘            Gemini emits delta to stdout
 `gemini -p … --approval-mode plan                        │
   --skip-trust -o json 2>/dev/null | jq -r '.response'`  │
      │                                                    │
      ▼                                                    ▼
 Gemini emits findings to stdout (read-only)      Claude reads current
      │                                            assessment, applies delta
      ▼                                                    │
 Claude synthesises (DEF-03), writes              Claude writes file
 codebase-assessment.md + engine marker                   │
      │                                                    ▼
      ▼                                            commit (unchanged)
 DEF-05 review / DEF-04 checklist / DEF-07 (Claude + user, unchanged)
```

Design principle: **Gemini scans, Claude writes.** No write permissions are granted to Gemini in any path. The swap point is narrow — replace the `Agent` tool call with a Bash `gemini` call; synthesis (DEF-03) is unchanged and consumes findings from either engine.

## Features

### Feature 1: Architecture and Design Document

Author `docs/ARCHITECTURE_AND_DESIGN.md` capturing the runtime contract, integration points, security/egress model, and design decisions for the delegated-scan capability. This is the authoritative design reference for Features 2–5.

**Acceptance Criteria:**

- Document covers: detection, invocation contract, scan prompts (Gate 0 + delta), consent + persistence, fallback, portability, and the read-only egress model.
- Captures the verified environment facts (binary, flags, default model behaviour, trust gate, stderr noise) from the source spec.
- 10–20 design decisions recorded with rationale, including the unpinned-model and skip-probe-by-default choices.
- Integration-point table mapping GEM requirements onto DEF-02 and BUILD-02.

### Feature 2: Detection and Consent (GEM-01, GEM-08)

Detect Gemini availability and, only when present, obtain explicit user consent before any files are sent. Persist the choice as an engine marker in the assessment file front matter so `/build` does not re-prompt.

**Acceptance Criteria:**

- Detection uses `command -v gemini >/dev/null 2>&1`. Absent → fall back silently to the Claude `Agent`; **no prompt**.
- When present, the skill prompts via `AskUserQuestion` (option headers ≤12 chars) before any files reach Gemini, stating the second-vendor egress tradeoff.
- Options: `Gemini` (delegate) and `Claude` (in-session sub-agent).
- On creation, the chosen engine is written to the assessment front matter as `<!-- scan-engine: gemini -->` (or `claude`).
- `/build` reads the marker fresh from disk (per STATE-03) and reuses the recorded engine without re-prompting; explicit user request can override and update the marker.
- Never prompts when an answer cannot be honored (i.e., when Gemini is absent).

### Feature 3: Gate 0 Invocation and Scan Prompt (GEM-02, GEM-03)

On a `Gemini` choice at `/define` Gate 0, run the verified read-only invocation and feed Gemini a prompt that produces the exact DEF-03 section structure on stdout.

**Acceptance Criteria:**

- Invocation: `gemini -p "<scan-prompt>" --approval-mode plan --skip-trust -o json 2>/dev/null | jq -r '.response'`, run from the project root.
- `-m` is **omitted** by default (inherits CLI default model); no literal model is hardcoded.
- The scan prompt instructs Gemini to: survey structure (2-level dirs + recent git history), select and read 20–40 files by DEF-02 heuristics, and emit plain-markdown findings under the eight required headed sections (`## Project Overview`, `## File Organization`, `## Detected Patterns`, `## Dependency Graph`, `## Assumptions`, `## Patterns That May Need Change`, `## Open Questions`, `## Recent Changes`).
- Prompt requires cited file paths, line counts, and dependency versions; no vague statements; output findings only — do not write files.
- Claude reads findings from stdout (substitute for the `/tmp/codebase-scan-findings.md` scratch file) and synthesises via DEF-03 unchanged.
- Gemini makes **no** working-tree modifications.

### Feature 4: `/build` Incremental Refresh Delta (GEM-04)

On a persisted `gemini` engine at `/build`, delegate the incremental delta scan; Claude applies the delta and writes the file.

**Acceptance Criteria:**

- Gemini receives the changed-files list (from the BUILD-02 git diff) plus the current assessment content, and emits only the **delta** updates per affected section.
- The incremental rule holds: read only changed files, not a full re-scan.
- Claude reads the current assessment, applies the delta, writes the file, and commits (commit step unchanged). Gemini does not write.
- Reuses the engine marker from Feature 2 without re-prompting.

### Feature 5: Fallback, Portability, and Reporting (GEM-05, GEM-06, GEM-07)

Guarantee a silent, automatic fallback to the Claude sub-agent on any failure, keep Gemini a no-hard-dependency optional accelerator, and report which engine ran.

**Acceptance Criteria:**

- Fall back to the Claude `Agent` when ANY of: `gemini` absent; (optional) liveness probe fails; scan call exits non-zero; stdout yields no parseable `.response`; `.response` empty or missing required sections.
- Fallback is silent and automatic — the assessment is always produced. A `Gemini` consent choice is a preference, not a hard commit; runtime failure still falls back.
- The optional liveness probe (`gemini -p "ok" … | jq -e '.response'`) is **disabled by default**; failure is detected from the real scan call. If an operator opts into a pinned `-m`, the probe (when enabled) runs with that same `-m`.
- Package remains fully functional with Gemini uninstalled — no skill requires Gemini.
- The skill reports the scan engine used in one line (e.g. `Scan via Gemini CLI` / `Scan via Claude sub-agent`); it does not prompt for this.

## Configuration

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| _(none)_ | — | No required configuration. The feature is auto-detected and consent-gated. |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| Scan engine choice | user consent (`AskUserQuestion`) | prompt on detection | `Gemini` or `Claude`; persisted in assessment front matter. |
| `-m <model-id>` | CLI flag (opt-in override) | unset (CLI default model) | Pin a specific Gemini model. Documented opt-in only; pair with the GEM-05 probe. |
| `--include-directories <dirs>` | CLI flag | unset | Add dirs outside cwd to the scan workspace if needed. |
| Liveness probe | behaviour toggle | disabled | Optional pre-scan probe; costs one extra Gemini call per Gate 0 / refresh. |
| `GEMINI_CLI_TRUST_WORKSPACE=true` | env var | unset | Equivalent to `--skip-trust` for bypassing the headless trust gate. |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `codebase-assessment.md` | markdown artifact | Written by Claude from findings (either engine); identical structure regardless of source. |
| Engine marker | front-matter comment | `<!-- scan-engine: gemini -->` or `<!-- scan-engine: claude -->` in the assessment file; read by `/build`. |
| Engine report line | stdout (one line) | States which scan engine ran, for transparency. |

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Data egress — scanned files reach Google's API in addition to Anthropic's | Read-only Gemini (no write/exec, no injection action surface); detection-gating; explicit consent prompt (GEM-08) before any files sent; portable fallback so declining costs nothing. Decision: acceptable for this scope, gated on consent. |
| Pinned model deprecation (if `-m` hardcoded) | Default is unpinned (CLI default model, floats forward). `-m` is opt-in only and paired with a detection-time validation probe. |
| Auth/quota/network failure mid-scan | Non-zero exit or empty `.response` → silent GEM-06 fallback to Claude. |
| Truncated / malformed JSON | `jq` failure treated as scan failure → GEM-06 fallback. |
| Headless trust gate aborts in untrusted dir | `--skip-trust` mandatory in the invocation (or `GEMINI_CLI_TRUST_WORKSPACE=true`). |
| stderr noise (extension/skill-conflict errors) | Always `2>/dev/null`; parse stdout only. Non-fatal. |
| Model returns prose outside the section template | DEF-03 synthesis normalises into required sections; the template prompt (GEM-03) minimises this. |
| Accuracy errors in scan output | Output is human-reviewed at Gate 0 (DD-7), Claude-validated (DEF-04 cited-path pre-check), self-correcting (refreshed each `/build`). |
| Hidden hard dependency on Gemini | GEM-07 — no skill may require Gemini; package fully functional uninstalled. |

## External Dependencies

| Dependency | Owner | Status |
|------------|-------|--------|
| `gemini` CLI (tested `0.45.2`) | Google | Optional — auto-detected; not required. |
| `jq` | system | Required only on the Gemini path (parses `.response`). |
| `define/references/gate-0-codebase.md` (DEF-02) | this project | Integration point — must accept findings from either engine. |
| `build/references/codebase-refresh.md` (BUILD-02) | this project | Integration point — must read engine marker and route. |

## Success Criteria

- With Gemini present and consented, a Gate 0 scan runs via the verified invocation and produces a valid assessment after Claude synthesis.
- With Gemini absent, Gate 0 produces an assessment via the Claude `Agent` with identical output structure.
- A `/build` refresh delegates the delta to Gemini when the marker says `gemini`, with Claude applying and committing.
- Any scan failure falls back silently to Claude; the assessment is always produced.
- Gemini makes no working-tree modifications in any path.
- Uninstalling Gemini leaves the package fully functional.

## Future Enhancements

| Enhancement | Description |
|-------------|-------------|
| Documented `-m` quality tier | Expose an opt-in pinned model with a detection-time validation probe for operators wanting a specific tier. |
| Delegation for other phase skills | Extend the read-only-scan pattern to `/design`, `/milestone`, or `/plan-feature` if a long-context need emerges. |
| Liveness-probe-by-default toggle | Make the GEM-05 probe a configurable default for environments with flaky auth/quota. |
