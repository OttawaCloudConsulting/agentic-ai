# Progress File Format Specification

## Overview

The project pipeline uses plain-text checkbox notation across two tiers of state files: a project-level `progress.txt` at the project root (tracking gate approvals, milestone summaries, and spike entries) and milestone-level `milestone-status.txt` files at `milestones/<NN>-<name>/milestone-status.txt` (tracking per-feature details, sub-feature checklists, and notes). Both files use the same four-marker status notation defined below. This format was chosen over YAML for superior write-safety, token efficiency (~53% fewer tokens), and human editability (see original Project DESIGN.md DD-3, progress-file/TEXT_vs_YAML_REPORT.md).

## Status Notation

The four canonical status markers used in all progress and milestone-status files:

- `[x]` = complete
- `[~]` = in progress
- `[ ]` = pending
- `[-]` = skipped / not applicable

These four markers are the ONLY permitted status markers. No other bracket notation is allowed -- `[in-progress]`, `[done]`, `[complete]`, or any other variation MUST NOT be used. This constraint prevents the inconsistency risk identified in TEXT_vs_YAML_REPORT.md (two coexisting notation systems) and ensures reliable parsing by all skills (DESIGN.md DD-3).

## Bootstrap Template

The exact `progress.txt` content created by `$project` on first run (bootstrap exception; PROJ-10, DD-3):

```
# Progress: <Project Name>
# Created: <ISO date>
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
- `<ISO date>` is the current date in YYYY-MM-DD format.
- The `# Status:` header line serves as an inline legend for anyone reading the file.

## Greenfield Bootstrap Variant

When the project is greenfield (empty directory or boilerplate-only, per DD-10), Gate 0 is recorded as skipped in the bootstrap template instead of pending:

```
[-] Gate 0: Codebase Alignment  Skipped (greenfield)
```

All other gates remain `[ ]`. This is Codex's discretion per the phase context decisions -- there is no existing codebase to assess, so Gate 0 adds no value. The gate line is preserved (not omitted) so that every `progress.txt` has the same gate structure regardless of project type.

## Gate Entry Format

Gate entries appear in the `## Gates` section, one per line. The format varies by state:

**Approved:**

```
[x] Gate 0: Codebase Alignment  Approved: 2026-03-15  docs/codebase-assessment.md
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

The artifact path on approved entries is the primary deliverable of that gate. `$project` validates these paths exist on disk (PROJ-04).

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

Per STATE-04: When both `milestone-status.txt` and `progress.txt` need updates, `milestone-status.txt` MUST be written first (source-of-truth-first ordering). This ensures that if a crash occurs mid-write, the more detailed file is already updated and `$project` can detect the divergence on next read.

Note: `$project` writes only for bootstrap (PROJ-10, DD-3), Gate WB state decisions (D-08, DD-11), and Gate 3 closure (D-01 through D-05, PROJ-10 exception). The multi-file ordering contract applies to downstream skills (`$project-build`, `$project-milestone`, `$project-plan-feature`). `$project` must document this contract so downstream skills follow it. The contract is enforced by convention -- each downstream skill's SKILL.md must reference this specification.

## Parsing Notes

Instructions for the LLM reading these files:

- Lines starting with `#` are headers or comments (the `# Status:` line is a legend, not data)
- Status is determined by the bracket marker at the start of each entry line (`[x]`, `[~]`, `[ ]`, `[-]`)
- Artifact paths follow the date on approved gate entries
- Feature counts in milestone summaries are `N/M` format where N=complete, M=total
- The `Notes:` line on a feature entry is optional
- Blank lines separate feature blocks in `milestone-status.txt` for readability but are not semantically significant
- Indented lines (starting with spaces) belong to the most recent non-indented entry above them
