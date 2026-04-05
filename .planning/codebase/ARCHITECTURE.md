# Architecture

**Analysis Date:** 2026-04-02

## Pattern Overview

**Overall:** Content Library with Embedded Orchestration Engine

**Key Characteristics:**
- No runtime application code — all content is prompt templates, markdown workflows, and shell scripts
- Two distinct layers: a **library** (reusable drop-in components) and an **engine** (GSD workflow system that runs inside Claude Code)
- Drop-in deployment model: consumers copy directories into their own repos; the library itself is never imported or required
- Agent-orchestrated execution: Claude Code spawns typed subagents for parallel or sequential plan execution
- File-based state machine: all project state lives in `.planning/` markdown files, managed by a Node.js CLI utility

## Layers

**Library Layer (public-facing content):**
- Purpose: Reusable agentic AI components that users copy into target repositories
- Contains: Skills (`skills/`), Commands (`commands/`), Rules (`rules/`), Agents (`agents/`), Solutions (`solutions/`), Kiro equivalents (`kiro/`)
- Depends on: Nothing — these are inert prompt files until dropped into a consumer repo
- Used by: Developers copying components to their own projects

**GSD Engine Layer (self-contained orchestration system):**
- Purpose: Full project planning and execution workflow system for Claude Code
- Contains: Workflows (`.claude/get-shit-done/workflows/`), CLI binary (`.claude/get-shit-done/bin/gsd-tools.cjs`), Agent definitions (`.claude/agents/`), Command shims (`.claude/commands/gsd/`), References (`.claude/get-shit-done/references/`), Templates (`.claude/get-shit-done/templates/`)
- Depends on: Node.js runtime for `gsd-tools.cjs`; Claude Code for agent spawning via `Task()` tool
- Used by: The owner of this repository via Claude Code slash commands

**Documentation Layer:**
- Purpose: Catalog and reference documentation for all library components
- Contains: `docs/SKILLS.md`, `docs/COMMANDS.md`, `docs/RULES.md`, `docs/SOLUTIONS.md`, `docs/SCRIPTS.md`
- Depends on: Library content (documents what exists)
- Used by: Developers discovering and selecting components

**Utility/Scripts Layer:**
- Purpose: Shell scripts for benchmarking and CI operations
- Contains: `scripts/benchmark/`, `cicd/lint-markdown.sh`
- Depends on: Bash runtime, library content being tested
- Used by: Maintainers of this repository

## Data Flow

**GSD Workflow Execution (primary engine flow):**

1. User invokes a slash command (e.g., `/gsd:execute-phase 3`)
2. Command shim at `.claude/commands/gsd/execute-phase.md` loads workflow via `@execution_context` reference
3. Orchestrator workflow (`.claude/get-shit-done/workflows/execute-phase.md`) initializes via `gsd-tools.cjs init execute-phase "3"` — returns JSON with phase dir, plans list, model assignments, config
4. Orchestrator analyzes plan dependencies, groups into parallel waves
5. Orchestrator spawns typed subagents via `Task(subagent_type="gsd-executor", ...)` for each wave
6. Each subagent (`gsd-executor`) executes its PLAN.md file, writes code, commits per-task, creates SUMMARY.md
7. Orchestrator collects completion signals, advances to next wave
8. `gsd-tools.cjs commit` writes state updates to `.planning/STATE.md`

**New Project Initialization Flow:**

1. User invokes `/gsd:new-project`
2. `gsd-tools.cjs init new-project` checks for existing `.planning/`, git repo, brownfield signals
3. Orchestrator runs questioning rounds via `AskUserQuestion` tool
4. Spawns `gsd-project-researcher` agents for parallel research (optional)
5. Spawns `gsd-research-synthesizer` to merge findings
6. Spawns `gsd-roadmapper` to produce `.planning/ROADMAP.md`
7. Commits all planning artifacts to git via `gsd-tools.cjs commit`

**Plan-Phase Flow:**

1. User invokes `/gsd:plan-phase <N>`
2. Orchestrator spawns `gsd-phase-researcher` → `gsd-planner` → `gsd-plan-checker` in sequence (with revision loop, max 3 iterations)
3. Each subagent writes its artifact (`RESEARCH.md`, `PLAN.md`, review output) directly to `.planning/phases/<padded-phase>-<slug>/`
4. Orchestrator only receives confirmation from each subagent, not document content

**Library Component Deployment (consumer flow):**

1. Developer browses `docs/SKILLS.md` or `docs/COMMANDS.md` to find a component
2. Copies directory (for skills) or single file (for commands/rules) into their own `.claude/` structure
3. Invokes via slash command or uses as always-on rule — no installation step required

**State Management:**
- All GSD project state in `.planning/STATE.md` (frontmatter-based key-value store)
- Config in `.planning/config.json` (JSON)
- Phase artifacts in `.planning/phases/<padded-phase>-<slug>/` (PLAN.md, SUMMARY.md, RESEARCH.md)
- Roadmap in `.planning/ROADMAP.md`
- `gsd-tools.cjs` is the sole writer of structured state; workflows read via its `init` commands

## Key Abstractions

**Skill:**
- Purpose: Multi-file drop-in workflow bundle for a specific domain task
- Examples: `skills/cdk-testing/`, `skills/create-prd/`, `skills/itsg-assessment/`
- Pattern: Directory containing `SKILL.md` (entry point, <500 lines) plus `references/` subdirectory for supporting content, optional `scripts/` and `review/` subdirectories

**Command:**
- Purpose: Single-file slash command workflow (simpler than skills)
- Examples: `commands/catchup.md`, `commands/investigate.md`, `commands/dream.md`
- Pattern: Markdown file with YAML frontmatter (`name`, `description`, optionally `allowed-tools`)

**Rule:**
- Purpose: Always-on behavioral guidance loaded automatically by Claude Code from `.claude/rules/`
- Examples: `rules/defensive-protocol-v2-anti-slop.md`, `rules/terraform-best-practices.md`
- Pattern: Markdown file; no frontmatter required; loaded on every turn automatically

**GSD Agent (subagent definition):**
- Purpose: Typed Claude Code subagent with defined role, tools, and model
- Examples: `.claude/agents/gsd-executor.md`, `.claude/agents/gsd-planner.md`
- Pattern: Markdown with YAML frontmatter (`name`, `description`, `tools`, `model`, `permissionMode`, optionally `color`, `maxTurns`)

**GSD Workflow:**
- Purpose: Orchestrator logic for a GSD slash command — spawns subagents, sequences steps
- Examples: `.claude/get-shit-done/workflows/execute-phase.md`, `.claude/get-shit-done/workflows/plan-phase.md`
- Pattern: Structured markdown with `<purpose>`, `<available_agent_types>`, `<process>` XML-like sections and numbered steps

**Solution:**
- Purpose: Multi-construct kit combining agents + skills + MCP config for a complete workflow
- Examples: `solutions/well-architected-review/`
- Pattern: Directory with `agents/` (subagent definitions), `skills/` (skill bundles), `mcp.json`, `docs/`

**gsd-tools.cjs:**
- Purpose: Node.js CLI utility centralizing all GSD state operations — eliminates repetitive inline bash across ~50 workflow files
- Location: `.claude/get-shit-done/bin/gsd-tools.cjs`
- Pattern: Single CJS module; lib files in `.claude/get-shit-done/bin/lib/` (core, state, config, phase, roadmap, milestone, model-profiles, etc.); invoked with `node gsd-tools.cjs <command> [args]`

**Kiro Power:**
- Purpose: Kiro IDE equivalent of a skill — keyword-activated workflow bundle
- Examples: `kiro/powers/terraform-workflow/`, `kiro/powers/compliance/`
- Pattern: Directory with `steering/` subdirectory containing markdown files; installed to `.kiro/powers/` in target repo

## Entry Points

**GSD Slash Commands (primary user entry):**
- Location: `.claude/commands/gsd/*.md` (shims referencing workflows)
- Triggers: User types `/gsd:<command>` in Claude Code
- Responsibilities: Load workflow via `@execution_context`, pass `$ARGUMENTS` through

**GSD Workflows (orchestration entry):**
- Location: `.claude/get-shit-done/workflows/*.md`
- Triggers: Referenced by command shims via `@` path syntax
- Responsibilities: Initialize via `gsd-tools.cjs init`, spawn typed subagents, coordinate phases

**Library Skill Entry:**
- Location: `skills/<name>/SKILL.md` (consumed in target repos as `.claude/skills/<name>/SKILL.md`)
- Triggers: User invokes `/<skill-name>` in Claude Code after copying to their project
- Responsibilities: Provide domain workflow instructions, reference supporting files as needed

**Standalone Commands (legacy/simpler pattern):**
- Location: `commands/*.md` (consumed as `.claude/commands/*.md`)
- Triggers: User invokes `/<command-name>` in Claude Code
- Responsibilities: Self-contained single-file workflows

## Error Handling

**Strategy:** Fail fast with explicit error messages; no silent fallbacks

**Patterns:**
- `gsd-tools.cjs` calls `process.exit(1)` with descriptive error text on failure
- Workflows check prerequisites via init JSON (`project_exists`, `planning_exists`, `phase_found`) and error out with user guidance before any state changes
- Subagents pause and surface deviations to the orchestrator rather than proceeding
- Hard gates in solutions (e.g., WAR pre-flight) stop entire workflow if prerequisites missing

## Cross-Cutting Concerns

**Logging:**
- No application logging — all output is Claude's conversational responses to the user
- `gsd-tools.cjs` writes JSON to stdout (parsed by workflows) and errors to stderr

**Validation:**
- `gsd-tools.cjs validate consistency` checks phase numbering and disk/roadmap sync
- `gsd-tools.cjs validate health [--repair]` checks `.planning/` integrity
- Plan checker agent (`gsd-plan-checker`) reviews PLAN.md quality before execution

**Authentication:**
- Not applicable — no runtime service; all execution is local Claude Code sessions

**Context Management:**
- Progressive disclosure: Skills load in three tiers (metadata → SKILL.md → references on demand)
- Subagents receive minimal context via `<files_to_read>` blocks rather than inline content
- Orchestrators receive confirmations only (not document content) from mapper/writer agents

---

*Architecture analysis: 2026-04-02*
*Update when major patterns change*
