# Project Skill — Orchestrated Development Pipeline

## What This Is

A suite of Claude Code skills implementing a structured, gate-based pipeline for AI-assisted software development. The pipeline routes all work through `/project` (a stateless orchestrator) to phase-isolated skills — `/define`, `/design`, `/milestone`, `/plan`, `/build`, and `/spike` — each running in a clean context window with explicit human-approval gates between phases.

## Core Value

Every phase transition requires explicit human approval, preventing AI drift from user intent and catching misalignment at the cheapest possible moment.

## Requirements

### Validated

- [x] `/project` orchestrator — reads `progress.txt` and `milestone-status.txt`, reports current state, routes user to the right next skill, bootstraps state on first run — *Validated in Phase 1: project-router*
- [x] `/define` skill — runs Gates 0 (codebase alignment), optional WB (Working Backwards PR/FAQ), and Gate 1 (PRD creation) as a single continuous session — *Validated in Phase 2: define-gates-0-wb-1*
- [x] `/design` skill — Gate 2: produces `docs/ARCHITECTURE_AND_DESIGN.md` from approved PRD + codebase assessment, with refresh mode for deviation consolidation — *Validated in Phase 3: design-gate-2*

- [x] `/milestone` skill — Gate 3: breaks approved PRD + design into milestone breakdown with feature grouping, ordering, acceptance criteria, and sizing — *Validated in Phase 4: milestone-gate-3*

### Active
- [ ] `/plan` skill — Gate 4: produces per-feature implementation plans (one invocation per feature) including sub-feature breakdown, test command, and interface contracts
- [ ] `/build` skill — implements features sub-feature by sub-feature, tracks deviations, refreshes codebase assessment, updates `milestone-status.txt` on completion
- [ ] `/spike` skill — agent-based technical research with red-team validation, produces `docs/spikes/<topic>.md`
- [ ] Two-tier state files — project-level `progress.txt` (gate approvals, milestone summaries, spike entries) and milestone-level `milestone-status.txt` (feature details, sub-feature checklists)
- [ ] Gate review checklists — structured review artifacts per gate for offline reviewers, completeness validated before gate approval recorded
- [ ] Re-planning support — milestone re-planning via `/milestone` in revision mode; PRD revision via `/define` in revision mode
- [ ] Documentation — skill catalog entries and detail docs for all 6 skills + orchestrator

### Out of Scope

- Code review / PR review — handled by external processes (team review, CI/CD, GitHub PRs); DD-9
- Automatic cascade reset when PRD changes — user decides which downstream artifacts need re-review; DD-6
- CI/CD integration — external to this pipeline
- Test generation — skill invokes test commands, user writes/manages tests; DD-12
- Monolithic upfront spec — replaced by milestone-scoped PRDs; DD-1

## Context

This project lives in the `agentic-ai` repo — a curated library of reusable Claude Code components. The existing `create-prd` skill (`skills/create-prd/`) is the predecessor; `/define` forks from it and refines it for the milestone pipeline. `create-prd` remains as a standalone skill.

A codebase map exists at `.planning/codebase/`. Key existing patterns: skills are markdown prompt files in `skills/<name>/`, documentation goes in `docs/catalog/` (catalog entry) and `docs/skills/` or similar (detail docs), commands go in `.claude/commands/`.

**Design document:** `skills/project/DESIGN.md` — 13 detailed design decisions (DD-1 through DD-13) covering work hierarchy, state management, gate behavior, re-planning, testing, and review checklists.

**Problem being solved:** The current `create-prd` → `start-feature` pipeline has no planning phase, loosely coupled skills, monolithic PRDs that cause context rot, and no codebase alignment step. This pipeline addresses all five gaps.

## Constraints

- **Tech stack**: Markdown-only skills (no compiled code) — consistent with repo conventions
- **Compatibility**: Must coexist with `create-prd` and `start-feature` skills — no breaking changes to existing skills
- **Sizing**: Sub-features must fit within 60% of a 200k-token context window (~120k tokens) per DD-1
- **Scope**: 2–5 features per milestone, per DD-1 guidance
- **State**: Phase skills communicate only through files on disk — no shared conversation state; DD-5

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Three-level hierarchy: Milestone > Feature > Sub-Feature (DD-1) | Each level has concrete completion criteria preventing "done" ambiguity | — Pending |
| `/define` owns Gates 0, WB, 1 as single session (DD-2) | These gates are tightly coupled — codebase understanding feeds WB, WB feeds PRD; splitting forces costly re-ingestion | — Pending |
| `/project` is stateless and read-only (DD-3) | Survives `clear`, session gaps, machine switches, team handoffs | — Pending |
| Gate WB (Working Backwards) is optional (DD-11) | High leverage for greenfield/new verticals; overhead for small well-scoped work | — Pending |
| Test command planned in `/plan`, executed in `/build` (DD-12) | Skill invokes command, user manages test content — decouples from any specific test framework | — Pending |

---
*Last updated: 2026-04-03 — Phase 4 (milestone-gate-3) complete*

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state
