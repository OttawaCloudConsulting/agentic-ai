# Architecture and Design: Project Skill Path Refactor

## Overview

This document covers the design of a refactor to the `skills/project/` suite. The suite consists of seven skill files (`/project`, `/define`, `/design`, `/milestone`, `/plan-feature`, `/build`, `/spike`) and their associated reference files. Each skill currently writes generated artifacts directly to `docs/` and `milestones/` at the project root.

The refactor moves all generated docs and milestone artifacts under a `.project/{project-id}/` subdirectory while leaving `prd.md` and `progress.txt` at the project root. A slugified project identifier is stored as a new header line in `progress.txt`, giving every skill a single place to read it at runtime. No shared runtime or library is involved — each skill is a standalone markdown prompt that operates independently.

## Component Diagram

```
skills/project/
├── SKILL.md                     (/project orchestrator — bootstrap + routing)
├── references/
│   ├── progress-format.md       ← ADD Project-ID header spec
│   ├── routing-logic.md         ← UPDATE path examples
│   └── status-report-format.md  ← UPDATE path examples
├── define/
│   ├── SKILL.md                 ← UPDATE output paths
│   └── references/
│       └── progress-format.md   ← UPDATE path examples
├── design/
│   ├── SKILL.md                 ← UPDATE output paths
│   └── references/
│       └── progress-format.md   ← UPDATE path examples
├── milestone/
│   ├── SKILL.md                 ← UPDATE output paths
│   └── references/
│       └── progress-format.md   ← UPDATE path examples
├── plan-feature/
│   ├── SKILL.md                 ← UPDATE output paths
│   └── references/
│       └── progress-format.md   ← UPDATE path examples
├── build/
│   ├── SKILL.md                 ← UPDATE output paths
│   └── references/
│       └── progress-format.md   ← UPDATE path examples
└── spike/
    ├── SKILL.md                 ← UPDATE output paths
    └── references/
        └── progress-format.md   ← UPDATE path examples
```

## Data Flow

Path derivation at skill invocation (applies to all 7 skills):

1. Skill reads `progress.txt` from project root.
2. Skill parses `# Project-ID: <slug>` from the header section.
3. Skill constructs base path: `.project/<slug>/`.
4. All artifact reads and writes resolve against the base path.
5. Completion report displays paths using the computed base.

Bootstrap flow (`/project`, first run only):

1. `/project` detects no `progress.txt` exists.
2. Derives a candidate slug from the directory name or user input.
3. Presents candidate slug via `AskUserQuestion` — user confirms or overrides.
4. Writes `progress.txt` with the new `# Project-ID:` header line.

## Component Inventory

| # | Component | Type | Purpose |
|---|-----------|------|---------|
| 1 | `skills/project/SKILL.md` | Skill prompt | Orchestrator — bootstrap, routing, Gate 3 closure |
| 2 | `skills/project/references/progress-format.md` | Reference doc | Specifies `progress.txt` format including new Project-ID header |
| 3 | `skills/project/references/routing-logic.md` | Reference doc | Routing table — path examples updated |
| 4 | `skills/project/references/status-report-format.md` | Reference doc | Status display format — path examples updated |
| 5 | `skills/project/define/SKILL.md` | Skill prompt | Gates 0, WB, 1 — docs path updated |
| 6 | `skills/project/define/references/progress-format.md` | Reference doc | Path examples for define outputs |
| 7 | `skills/project/design/SKILL.md` | Skill prompt | Gate 2 — docs path updated |
| 8 | `skills/project/design/references/progress-format.md` | Reference doc | Path examples for design outputs |
| 9 | `skills/project/milestone/SKILL.md` | Skill prompt | Gate 3 — milestones path updated |
| 10 | `skills/project/milestone/references/progress-format.md` | Reference doc | Path examples for milestone outputs |
| 11 | `skills/project/plan-feature/SKILL.md` | Skill prompt | Gate 4 — plans path updated |
| 12 | `skills/project/plan-feature/references/progress-format.md` | Reference doc | Path examples for plan outputs |
| 13 | `skills/project/build/SKILL.md` | Skill prompt | Implementation — all artifact paths updated |
| 14 | `skills/project/build/references/progress-format.md` | Reference doc | Path examples for build outputs |
| 15 | `skills/project/spike/SKILL.md` | Skill prompt | Spike research — spikes path updated |
| 16 | `skills/project/spike/references/progress-format.md` | Reference doc | Path examples for spike outputs |
| 17 | `docs/skills/project.md` | Catalog doc | Suite documentation — output paths updated |

## File Organization

```
<project-root>/
├── progress.txt                          # Gates, milestones, spikes (root — unchanged)
├── prd.md                                # Product requirements (root — unchanged)
└── .project/
    └── {project-id}/
        ├── docs/
        │   ├── codebase-assessment.md    # /define Gate 0
        │   ├── working-backwards.md      # /define Gate WB (optional)
        │   ├── ARCHITECTURE_AND_DESIGN.md # /design Gate 2
        │   ├── spikes/
        │   │   └── {slug}.md             # /spike
        │   └── reviews/
        │       ├── gate-0-review.md
        │       ├── gate-wb-review.md
        │       ├── gate-1-review.md
        │       └── gate-2-review.md
        └── milestones/
            └── {NN}-{name}/
                ├── README.md             # /milestone
                ├── milestone-status.txt  # /milestone, /build
                ├── plans/
                │   └── {feature-slug}.md # /plan-feature, /build
                └── reviews/
                    ├── gate-3-review.md
                    └── gate-4-{feature-slug}-review.md
```

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Store `Project-ID` as a header comment in `progress.txt`, not a separate file | All skills already read `progress.txt` at invocation. Adding one header line avoids a new file dependency with no additional complexity. |
| 2 | Use a dot-prefixed directory (`.project/`) | Hidden by default in most file browsers and `ls` output, reducing visual clutter. Conventional for tooling-owned metadata. |
| 3 | Use a slugified identifier for the directory name, not the raw project name | Avoids path issues with spaces and special characters. Slug is derived deterministically from the project name. |
| 4 | Propose slug to user via `AskUserQuestion` at bootstrap rather than inferring silently | The project-id is permanent once set (changing it would invalidate all stored paths in `progress.txt`). User confirmation prevents accidental misnames. |
| 5 | `prd.md` and `progress.txt` remain at the project root | These are the two entry points developers interact with directly. Hiding them under `.project/` would obscure them. |
| 6 | Each skill derives the base path independently; no shared resolution function | The skill suite has no shared runtime — each skill is a standalone prompt. A shared helper would require a new architectural layer out of scope for this refactor. |
| 7 | Slug format: lowercase, hyphens, alphanumeric only | Simple, unambiguous, safe for all OS file systems. Matches convention used in existing milestone directory names (`01-core-auth`). |
| 8 | `.project/` committed to version control, not gitignored | Project planning artifacts (PRDs, architecture docs, milestone plans) are meaningful team resources. They belong in the repo history alongside the code they describe. |
| 9 | No migration tooling for existing projects | This is a breaking change. In-place migration of an existing `docs/` + `milestones/` layout is complex and error-prone. Document the break; existing projects start fresh or migrate manually. |
| 10 | `references/progress-format.md` updated in each sub-skill independently | Each sub-skill directory has its own copy. Centralizing would require restructuring the reference directory layout — out of scope. |
| 11 | Artifact paths stored in `progress.txt` use the full `.project/{slug}/...` relative path | Absolute paths would break on repo clone. Paths relative to project root are portable and match the existing convention. |
| 12 | `.project/{slug}/docs/` and `.project/{slug}/milestones/` created on first write | No bootstrap step creates empty directories. Each skill creates its output directory as needed, same as the current behavior. |

## Dependency Graph

Feature execution order respects the dependency between bootstrap (Feature 1) and path routing (Feature 2), which must be complete before any skill-specific updates are made. Skill updates (Features 3–7) are independent of each other.

```
Feature 1: Bootstrap (progress.txt + Project-ID)
    └── Feature 2: Path Routing Infrastructure
            ├── Feature 3: /define paths
            ├── Feature 4: /design paths
            ├── Feature 5: /milestone + /plan-feature paths
            ├── Feature 6: /build paths
            └── Feature 7: /spike paths
                    └── Feature 8: Documentation Update
```

## Out of Scope

| Item | Rationale |
|------|-----------|
| Multi-project support (multiple `.project/` subdirectories in one repo) | Motivation is cleaner root, not concurrent projects. Multi-project use is a natural future extension. |
| Migration tooling for existing projects | Complexity exceeds value for a prompt-engineering refactor. Manual migration or fresh start is the documented path. |
| Shared path-resolution utility | No shared runtime exists in the skill suite architecture. Out of scope. |
| Skill renaming, new gates, or routing changes | Structural and behavioral changes are out of scope per PRD non-goals. |
