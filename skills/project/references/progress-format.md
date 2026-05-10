# Progress File Format Specification

## Overview

The project pipeline uses plain-text checkbox notation across two tiers of state files: a project-level `progress.txt` at the project root (tracking gate approvals, milestone summaries, and spike entries) and milestone-level `milestone-status.txt` files at `milestones/<NN>-<name>/milestone-status.txt` (tracking per-feature details, sub-feature checklists, and notes). Both files use the same four-marker status notation defined below. This format was chosen over YAML for superior write-safety, token efficiency (~53% fewer tokens), and human editability (see DESIGN.md DD-3, progress-file/TEXT_vs_YAML_REPORT.md).

## Status Notation

The four canonical status markers used in all progress and milestone-status files:

- `[x]` = complete
- `[~]` = in progress
- `[ ]` = pending
- `[-]` = skipped / not applicable

These four markers are the ONLY permitted status markers. No other bracket notation is allowed -- `[in-progress]`, `[done]`, `[complete]`, or any other variation MUST NOT be used. This constraint prevents the inconsistency risk identified in TEXT_vs_YAML_REPORT.md (two coexisting notation systems) and ensures reliable parsing by all skills (DESIGN.md DD-3).

## Bootstrap Template

The exact `progress.txt` content created by `/project` on first run (the only time `/project` writes to disk -- PROJ-10, DD-3):

```
# Progress: <Project Name>
# Created: <ISO date>
# Project-ID: <slug>
# Status: [ ] pending  [~] in progress  [x] complete  [-] skipped

## Gates

[ ] Gate 0: Codebase Alignment
[ ] Gate WB: Working Backwards
[ ] Gate 1: Scope Review
[ ] Gate 2: Design Review
[ ] Gate 3: Milestone Review

## Milestones

(none yet)

## Spikes

(none yet)
```

Notes:

- `<Project Name>` is derived from the project directory name or user input at bootstrap time.
- `<slug>` is the slugified form of the project name — see Slug Derivation Rules below.
- `<ISO date>` is the current date in YYYY-MM-DD format.
- The `# Status:` header line serves as an inline legend for anyone reading the file.

## Slug Derivation Rules

The `# Project-ID:` value is a URL-safe slug derived from the project name. All skills read this value to compute the artifact base path (`.project/<slug>/`).

Derivation steps (apply in order):

1. Lowercase the entire string.
2. Replace any character that is not a letter, digit, or space with a space.
3. Collapse consecutive spaces into a single space and trim leading/trailing spaces.
4. Replace spaces with hyphens.
5. If the result is empty (e.g., the name was entirely punctuation), use `untitled-project` as the fallback slug.

The final slug must match `^[a-z0-9]+(-[a-z0-9]+)*$`. Note: hyphens are separators produced by the derivation process, not characters preserved from the original name directly (though a hyphen in the original becomes a space in step 2 and a hyphen again in step 4).

Examples:

| Project Name | Slug |
|---|---|
| My Web App | `my-web-app` |
| OCC Agentic AI | `occ-agentic-ai` |
| E-Commerce Platform! | `e-commerce-platform` |
| `api_v2 (internal)` | `api-v2-internal` |
| `!!!` | `untitled-project` |

Parsing instruction for skills: find the line starting with `# Project-ID:`, split on the first `:`, take everything after it, and trim whitespace to get the slug. Construct the artifact base path as `.project/<slug>/`.

## Greenfield Bootstrap Variant

When the project is greenfield (empty directory or boilerplate-only, per DD-10), Gate 0 is recorded as skipped in the bootstrap template instead of pending:

```
# Progress: <Project Name>
# Created: <ISO date>
# Project-ID: <slug>
# Status: [ ] pending  [~] in progress  [x] complete  [-] skipped

## Gates

[-] Gate 0: Codebase Alignment  Skipped (greenfield)
```

All other gates remain `[ ]`. This is Claude's discretion per the phase context decisions -- there is no existing codebase to assess, so Gate 0 adds no value. The gate line is preserved (not omitted) so that every `progress.txt` has the same gate structure regardless of project type.

## Gate Entry Format

Gate entries appear in the `## Gates` section, one per line. The format varies by state:

**Approved:**

```
[x] Gate 0: Codebase Alignment  Approved: 2026-03-15  .project/<slug>/docs/codebase-assessment.md
```

Format: `[x] Gate N: Name  Approved: <YYYY-MM-DD>  <artifact-path>`

**Skipped:**

```
[-] Gate WB: Working Backwards  Skipped
```

Or with a reason:

```
[-] Gate 0: Codebase Alignment  Skipped (greenfield)
```

**Pending (deferred decision):**

```
[ ] Gate WB: Working Backwards  Pending — offered, awaiting decision
```

**In progress:**

```
[~] Gate 3: Milestone Review  In progress
```

**Not yet started:**

```
[ ] Gate 2: Design Review
```

The artifact path on approved entries is the primary deliverable of that gate. `/project` validates these paths exist on disk (PROJ-04).

## Milestone Summary Line Format

One line per milestone in the `## Milestones` section:

```
[ ] Milestone 01: Core Auth  milestones/01-core-auth/  0/3 features complete
```

Format: `[status] Milestone NN: Name  milestones/<NN>-<name>/  N/M features complete`

Where:

- `status` is one of the four canonical markers
- `NN` is a zero-padded two-digit sequence number
- `N/M` is the count of completed features over total features
- The directory path points to the milestone's folder containing `milestone-status.txt` and `README.md`

## Spikes Section Format

All spikes (open and resolved) appear in the `## Spikes` section, per decision D-02. Spikes are never removed -- resolved spikes remain for reference.

**Open spike:**

```
[ ] WebSocket Auth Compatibility  docs/spikes/websocket-auth.md
```

**Resolved spike:**

```
[x] SQLite to Postgres Migration  docs/spikes/sqlite-postgres.md  Resolved: 2026-03-17
```

Format: `[status] Spike Name  <artifact-path>` with an optional `Resolved: <date>` suffix for completed spikes.

## milestone-status.txt Format

Per-milestone file located at `milestones/<NN>-<name>/milestone-status.txt`. Uses the same checkbox notation as `progress.txt` (per STATE-02). Contains detailed feature tracking for a single milestone.

```
# Milestone 01: Core Auth
# Status: [~] in progress  3 features, 1 complete

## Features

[x] Feature 01.1: User Registration
    Plan: milestones/01-core-auth/plans/user-registration.md
    Sub-features: 3/3 complete

[~] Feature 01.2: Session Management
    Plan: milestones/01-core-auth/plans/session-management.md
    Sub-features: 1/4 complete
    Notes: Switched from JWT to session cookies (see architectural deviation)

[ ] Feature 01.3: Password Reset
    Plan: (not yet planned)
```

Structure:

- Header line with milestone name
- Status line with marker, state description, and feature count summary
- `## Features` section with one block per feature
- Each feature block starts with `[status] Feature NN.N: Name` on its own line
- Indented lines below each feature contain `Plan:`, `Sub-features:`, and optional `Notes:`
- Feature blocks are separated by blank lines for readability

## Write-Ordering Contract

Per STATE-04: When both `milestone-status.txt` and `progress.txt` need updates, `milestone-status.txt` MUST be written first (source-of-truth-first ordering). This ensures that if a crash occurs mid-write, the more detailed file is already updated and `/project` can detect the divergence on next read.

Note: `/project` itself only writes at bootstrap (PROJ-10), so this contract applies to downstream skills (`/build`, `/milestone`, `/plan-feature`). `/project` must document this contract so downstream skills follow it. The contract is enforced by convention -- each downstream skill's SKILL.md must reference this specification.

## Parsing Notes

Instructions for the LLM reading these files:

- Lines starting with `#` are headers or comments (the `# Status:` line is a legend, not data)
- `# Project-ID:` is the third header line (after `# Progress:` and `# Created:`); its value is the slug used to construct `.project/<slug>/`
- Status is determined by the bracket marker at the start of each entry line (`[x]`, `[~]`, `[ ]`, `[-]`)
- Artifact paths follow the date on approved gate entries
- Feature counts in milestone summaries are `N/M` format where N=complete, M=total
- The `Notes:` line on a feature entry is optional
- Blank lines separate feature blocks in `milestone-status.txt` for readability but are not semantically significant
- Indented lines (starting with spaces) belong to the most recent non-indented entry above them
