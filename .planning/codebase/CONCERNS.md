# Codebase Concerns

## HIGH: .claude / .gemini Sync Drift

**Location:** `.claude/agents/`, `.gemini/agents/`

`.gemini/` is intended to mirror `.claude/` for multi-AI-runtime support. Sync is manual with no automation. Over time, agent definitions, hooks, and settings diverge between the two directories. Currently 18 agent files exist in `.claude/agents/` — any change to an agent must be manually duplicated in `.gemini/agents/`.

**Risk:** Gemini-runtime users get stale or inconsistent agent behaviour.
**Mitigation needed:** Automated sync script or symlink strategy.

## HIGH: No Automated Skill Tests

**Location:** Entire `skills/` directory

No automated test framework exists for skill correctness. Skills are validated manually via benchmark runs documented in `review/BENCHMARK.md`. There is no CI gate that catches regressions when a skill is modified.

**Risk:** Skill edits can break expected behaviour with no detection.
**Mitigation needed:** Even lightweight integration tests (run skill on known input, assert output file exists with expected sections) would improve confidence.

## MEDIUM: skills/project/ is In-Design

**Location:** `skills/project/`

The `/project` skill directory exists but contains only design documents (`DESIGN.md`, `design-decisions/`, `progress-file/`). No `SKILL.md` exists yet. This is intentional (design phase just completed) but represents a significant incomplete component.

**Risk:** The most complex skill in the repo has not been built.
**Status:** Active development — design fully resolved as of 2026-04-02.

## MEDIUM: No .gitignore Coverage for .planning/

**Location:** `.gitignore`

`.gitignore` only excludes `benchmark/runs/`. The `.planning/` directory (GSD workspace with PROJECT.md, REQUIREMENTS.md, ROADMAP.md, codebase maps) is not gitignored. If committed, planning artefacts will clutter the repo history.

**Risk:** Accidental commit of planning workspace to repo.
**Mitigation:** Add `.planning/` to `.gitignore`.

## MEDIUM: Docs Coverage Gap for New Components

**Location:** `docs/`

The documentation requirement (catalog entry + detail doc) exists as a convention but is not enforced. New components can be added to `skills/` or `commands/` without corresponding `docs/` entries. The `skills/project/` directory has no corresponding `docs/skills/project.md` or entry in `docs/SKILLS.md`.

**Risk:** Catalog becomes stale; discoverability degrades.
**Mitigation:** Linting or CI check for orphan skill directories.

## LOW: No README at Repo Root

**Location:** `/`

The repo has no `README.md`. Discovery, onboarding, and purpose are documented in `docs/SKILLS.md` and `docs/COMMANDS.md` but no top-level entry point exists for new contributors or GitHub visitors.

## LOW: .DS_Store Files in Repo

**Location:** `docs/.DS_Store`, root `.DS_Store`

macOS metadata files are present in the repo. Not harmful but should be gitignored.

**Fix:** Add `**/.DS_Store` to `.gitignore` and remove existing files.

## LOW: Single CI Script, No Pipeline Definition

**Location:** `cicd/lint-markdown.sh`

One CI script exists but there is no CI pipeline definition (GitHub Actions, etc.) to run it automatically on PRs. The lint check is only run when manually invoked.

**Risk:** Markdown errors merge without detection.
**Mitigation:** Add `.github/workflows/lint.yml`.
