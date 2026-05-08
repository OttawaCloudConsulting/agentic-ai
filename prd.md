# PRD: Project Skill Path Refactor

## Summary

Refactor the `skills/project/` skill suite to group all generated documentation and milestone artifacts under a `.project/{project-name}/` directory in the project root, rather than placing them directly under `docs/` and `milestones/`. The `prd.md` and `progress.txt` files remain at the project root. This keeps the project root uncluttered for developers browsing the repo.

## Goals

- Move all generated docs and milestone artifacts under `.project/{project-name}/` to keep the project root clean.
- Store a machine-readable `Project-ID` slug in `progress.txt` so every skill can derive the base path at runtime without hardcoding it.
- Propose a name to the user at bootstrap and allow override via `AskUserQuestion`.
- Commit `.project/` to version control alongside the code.

## Non-Goals

| Item | Rationale |
|------|-----------|
| Skill renaming or re-routing | Out of scope — names, gates, and routing logic unchanged. |
| State file format changes | `progress.txt` and `milestone-status.txt` structure preserved; only one new header line added. |
| Multi-project support | Cleaner root is the goal. Multi-project is a natural side effect but is not designed for in this iteration. |
| Moving `prd.md` or `progress.txt` | Both remain at the project root. |

## Architecture

All skills read `Project-ID` from the `progress.txt` header at invocation time and use it to compute the artifact base path. No path is hardcoded in any skill.

```
progress.txt (project root)
prd.md       (project root)

.project/{project-id}/
  docs/
    codebase-assessment.md      (/define, Gate 0)
    working-backwards.md        (/define, Gate WB)
    ARCHITECTURE_AND_DESIGN.md  (/design, Gate 2)
    spikes/
      {slug}.md                 (/spike)
    reviews/
      gate-0-review.md
      gate-wb-review.md
      gate-1-review.md
      gate-2-review.md
  milestones/
    {NN}-{name}/
      README.md                 (/milestone)
      milestone-status.txt      (/milestone, /build)
      plans/
        {feature-slug}.md       (/plan-feature, /build)
      reviews/
        gate-3-review.md
        gate-4-{feature-slug}-review.md
```

Path derivation (all skills):
1. Read `progress.txt`.
2. Parse `# Project-ID: <slug>` from the header.
3. Construct base path: `.project/<slug>/`.
4. All artifact reads and writes are relative to that base path.

## Features

### Feature 1: Bootstrap — Add Project-ID to progress.txt

Update `/project` bootstrap to capture a slugified project name and write it as a new header line in `progress.txt`. Update `references/progress-format.md` to specify the new header line and slug derivation rules.

**Acceptance Criteria:**

- `progress.txt` bootstrap template gains a `# Project-ID: <slug>` header line between `# Created:` and `# Status:`.
- Slug is lowercase, hyphen-separated, alphanumeric only (e.g., `My Web App` → `my-web-app`).
- `/project` bootstrap proposes a derived slug and confirms via `AskUserQuestion` before writing.
- `references/progress-format.md` documents the new header line, slug format rules, and parsing instruction.

### Feature 2: Path Routing Infrastructure

Update `/project` SKILL.md and its `references/routing-logic.md` and `references/status-report-format.md` to derive and display artifact paths using the `.project/{slug}/` base. Update artifact existence validation to resolve paths against the base.

**Acceptance Criteria:**

- `/project` reads `Project-ID` from `progress.txt` and constructs the base path on every invocation.
- Status report displays artifact paths as `.project/{slug}/docs/...` and `.project/{slug}/milestones/...`.
- Artifact validation (PROJ-04) resolves paths from project root using the computed base.
- `references/routing-logic.md` updated: all path references use `.project/{slug}/` prefix.
- `references/status-report-format.md` updated: example paths reflect new structure.

### Feature 3: /define Skill Path Updates

Update `define/SKILL.md` and `define/references/progress-format.md` so all artifact writes go to `.project/{slug}/docs/` instead of `docs/`.

**Acceptance Criteria:**

- `docs/codebase-assessment.md` → `.project/{slug}/docs/codebase-assessment.md`.
- `docs/working-backwards.md` → `.project/{slug}/docs/working-backwards.md`.
- `docs/reviews/gate-0-review.md` → `.project/{slug}/docs/reviews/gate-0-review.md`.
- `docs/reviews/gate-wb-review.md` → `.project/{slug}/docs/reviews/gate-wb-review.md`.
- `docs/reviews/gate-1-review.md` → `.project/{slug}/docs/reviews/gate-1-review.md`.
- Completion report in `define/SKILL.md` shows `.project/{slug}/` paths.
- `define/references/progress-format.md` updated with new path examples.

### Feature 4: /design Skill Path Updates

Update `design/SKILL.md` and `design/references/progress-format.md` so all artifact writes go to `.project/{slug}/docs/` instead of `docs/`.

**Acceptance Criteria:**

- `docs/ARCHITECTURE_AND_DESIGN.md` → `.project/{slug}/docs/ARCHITECTURE_AND_DESIGN.md`.
- `docs/reviews/gate-2-review.md` → `.project/{slug}/docs/reviews/gate-2-review.md`.
- Refresh mode scans `milestones/*/plans/*.md` → `.project/{slug}/milestones/*/plans/*.md`.
- Completion report shows `.project/{slug}/` paths.
- `design/references/progress-format.md` updated.

### Feature 5: /milestone and /plan-feature Skill Path Updates

Update `milestone/SKILL.md`, `plan-feature/SKILL.md`, and their respective `references/progress-format.md` files so all milestone and plan artifacts write to `.project/{slug}/milestones/` instead of `milestones/`.

**Acceptance Criteria:**

- `milestones/<NN>-<name>/` → `.project/{slug}/milestones/<NN>-<name>/` for all files (README.md, milestone-status.txt, reviews/, plans/).
- Milestone summary line in `progress.txt` uses `.project/{slug}/milestones/<NN>-<name>/` path.
- `milestone/references/progress-format.md` and `plan-feature/references/progress-format.md` updated with new path examples.
- Completion reports in both skills show `.project/{slug}/` paths.

### Feature 6: /build Skill Path Updates

Update `build/SKILL.md` and `build/references/progress-format.md` to read and write artifacts under `.project/{slug}/`.

**Acceptance Criteria:**

- Codebase assessment refresh writes to `.project/{slug}/docs/codebase-assessment.md`.
- Feature plan files read from `.project/{slug}/milestones/.../plans/`.
- `milestone-status.txt` read/write uses `.project/{slug}/milestones/...`.
- `progress.txt` milestone summary line paths match new structure.
- `build/references/progress-format.md` updated.

### Feature 7: /spike Skill Path Updates

Update `spike/SKILL.md` and `spike/references/progress-format.md` so spike artifacts write to `.project/{slug}/docs/spikes/` instead of `docs/spikes/`.

**Acceptance Criteria:**

- `docs/spikes/{slug}.md` → `.project/{project-slug}/docs/spikes/{slug}.md`.
- Spike entry in `progress.txt` records the new path.
- `spike/references/progress-format.md` updated.
- Completion report shows new path.

### Feature 8: Documentation Update

Update catalog and detail documentation to reflect the new output structure.

**Acceptance Criteria:**

- `docs/skills/project.md` "Primary Outputs" column updated with `.project/{name}/` paths.
- File tree in documentation reflects new layout.
- Any other references to `docs/` or `milestones/` as project-skill output paths updated.

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| Updated `progress.txt` bootstrap | Template change | Gains `# Project-ID: <slug>` header line |
| `.project/{slug}/docs/` | Directory | Replaces `docs/` as destination for project skill artifacts |
| `.project/{slug}/milestones/` | Directory | Replaces `milestones/` as destination for milestone artifacts |

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Existing projects using old `docs/` and `milestones/` paths will break | This is a breaking change. No migration script is in scope. Users with existing projects need to move artifacts manually or start fresh. Document this in the refactor notes. |
| Path derivation logic duplicated across 7+ skill files | Each skill reads the same two lines from `progress.txt`. The derivation is simple and consistent; the duplication is intentional (no shared runtime). |
| Slug collision if two projects produce the same slug | Out of scope for single-project-per-root scenario. Future multi-project support can add collision detection. |
| `references/progress-format.md` exists independently in each sub-skill directory | Each sub-skill's copy must be updated independently. Feature-per-skill structure ensures none are missed. |

## Success Criteria

- All 8 features pass acceptance criteria.
- A new project bootstrapped with the refactored suite places all `docs/` and `milestones/` artifacts under `.project/{slug}/` with no artifacts at the old `docs/` or `milestones/` paths.
- `prd.md` and `progress.txt` remain at the project root.
- Running `/project` on an updated project correctly displays `.project/{slug}/` paths in the status report and validates artifact existence at those paths.
