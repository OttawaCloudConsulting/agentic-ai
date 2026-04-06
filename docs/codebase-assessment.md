# Codebase Assessment: Deprecated MCP Servers (PROBLEM-12)

**Gate:** 0 — Codebase Alignment  
**Date:** 2026-04-04 (refreshed 2026-04-06 for Feature 01.1)  
**Project:** Deprecated MCP Servers  
**Status:** Brownfield — existing multi-module library with mature patterns

---

## 1. Project Overview

**Language & Framework:** Markdown + POSIX shell (bash). No runtime code.

**Purpose:** A library of reusable AI engineering patterns for Claude Code and Kiro. Consumers copy files from the source directories (`commands/`, `skills/`, `rules/`) into their own project's `.claude/` directory.

**Distribution types:**
- **Skills** — multi-file workflow bundles (`SKILL.md` + `references/` + `assets/`)
- **Commands** — single-file workflow definitions (markdown with YAML frontmatter in `commands/`)
- **Rules** — always-on behavioral guidelines in `rules/`, auto-loaded from `.claude/rules/`
- **Solutions** — orchestrated multi-skill kits (e.g., `solutions/well-architected-review/`)
- **MCP Management** — `mcp/install_mcp.sh`, a ~1,030-line POSIX-compatible MCP server installer managing 18 servers across 13 named patterns

**Maturity level:** High. Established patterns, comprehensive documentation, active maintenance (1–2 commits/week as of March–April 2026).

---

## 2. File Organization

```
agentic-ai/
├── .claude/                    ← Claude Code harness (excluded from git; working copy)
│   ├── commands/               ← 10 installed commands
│   ├── rules/                  ← 9 installed behavioral rules
│   └── skills/                 ← 13+ installed skill bundles
├── commands/                   ← Command source (distributed to consumers)
├── skills/                     ← Skill source bundles (distributed to consumers)
├── rules/                      ← Rule source files (distributed to consumers)
├── docs/                       ← Consumer-facing documentation catalogs
│   ├── ARCHITECTURE_AND_DESIGN.md  ← PROBLEM-12 project design document
│   ├── COMMANDS.md             ← Command reference catalog
│   ├── SKILLS.md               ← Skill reference catalog
│   ├── codebase-assessment.md  ← This document (Gate 0 artifact)
│   ├── reviews/                ← Gate review checklists
│   └── skills/                 ← Per-skill detail docs
├── mcp/                        ← MCP server management
│   ├── install_mcp.sh          ← Primary MCP installer script (~1,030 lines)
│   ├── README.md               ← User guide and pattern reference
│   └── docs/ARCHITECTURE_AND_DESIGN.md  ← MCP subsystem design doc
├── solutions/                  ← Multi-construct solution kits
├── kiro/                       ← Kiro-specific equivalent patterns
├── scripts/                    ← Benchmark and CI/CD utilities
├── external_sources/           ← Reference documentation (Claude Guide)
├── cicd/                       ← Markdown linting helpers
├── agents/                     ← Agent definition stubs (empty)
├── milestones/                 ← Milestone tracking directories
├── .mcp.json                   ← Empty MCP config (managed by install_mcp.sh)
├── CLAUDE.md                   ← Minimal tool-specific guidance
├── README.md                   ← Project overview and consumption guide
├── PROBLEM-12.md               ← Issue tracker for this project
└── progress.txt                ← Project gate and milestone state
```

**Key naming conventions:**
- Commands: kebab-case (`start-feature`, `update-docs-cdk`)
- Skills: kebab-case (`itsg-assessment`, `nist-fedramp-assessment`)
- Rules: kebab-case with domain prefix (`cdk-best-practices`, `defensive-protocol-v2-anti-slop`)
- Shell functions: snake_case

---

## 3. Detected Patterns

**Markdown-first design:** All user-facing content is markdown with YAML frontmatter. No Python, JavaScript, or compiled code. Shell scripts are limited to the MCP installer and CI/CD helpers.

**YAML frontmatter convention:**
```yaml
---
name: skill-or-command-name
description: "One-liner plus trigger phrases"
disable-model-invocation: true  # Optional — prevents auto-trigger
---
```

**Keyword-driven activation:** Skills and commands embed trigger phrases in the `description` field. Claude's parser uses these to route natural language ("project status" → `/project`, "goals changed" → `/define` in revision mode).

**Rule-based behavioral guidance:** Rules in `.claude/rules/` are auto-loaded on every turn with no explicit invocation. No frontmatter required.

**Distributed source model:** Source files in root `commands/`, `skills/`, `rules/` are consumed by copying into target projects' `.claude/` directories.

**Human-in-the-loop gates:** No automated tests. Correctness is verified via user checkpoints at each gate (produce-then-review cycle). Benchmark scripts in `scripts/benchmark/` exist but have not been run recently (last recorded: 2024-11-20).

**Pre-install hook pattern (new in Feature 01.1):** `install_mcp.sh` now supports an optional `get_server_preinstall_cmd()` function that runs a setup command before `claude mcp add`. Currently used by `notebooklm-mcp` to run `uv tool install notebooklm-mcp-cli --upgrade` before registration. This pattern allows servers with separate CLI dependencies to be fully set up in a single installer pass.

---

## 4. Dependency Graph

**No code dependencies.** All dependencies are workflow-level:

```
progress.txt  ←consumed by: /project, /start-feature, /catchup, /handoff
              ←updated by: /define, /milestone, /build, /handoff

prd.md        ←consumed by: /start-feature, /design, /plan, /build

docs/codebase-assessment.md  ←consumed by: /define (Gate 1 context)
                              ←refreshed by: /build (incremental, via sub-agent)
```

**Typical project skill call chain:**
```
/project → /define (Gates 0/WB/1) → /design (Gate 2)
  → /milestone (Gate 3) → /plan → /build → [/spike optional]
```

**External tool dependencies for `mcp/install_mcp.sh`:**
- `claude` CLI — hard requirement
- `uvx` — for AWS/CDK/Security/Pricing/Serverless servers
- `uv` — for NotebookLM server (pre-install step: `uv tool install`)
- `npx` — for Documentation (Context7)/Architecture (Mermaid)/Kubernetes/Git/GitHub servers
- `docker` — soft requirement for Terraform (HashiCorp) and Crossplane servers
- `trivy` — soft requirement for Security pattern

---

## 5. Assumptions

1. **Claude Code availability:** All skills assume the `claude` CLI binary is on PATH. No fallback for other Claude interfaces (web, API).
2. **Markdown as executable spec:** Skills are treated as executable specifications interpreted directly by Claude's instruction-following, not as static documentation.
3. **Single MCP server isolation:** Each MCP server is project-scoped (`-s project`). Projects manage their own server sets independently.
4. **Docker optional:** The installer warns and skips docker-based servers rather than failing entirely.
5. **POSIX compatibility:** `install_mcp.sh` targets bash 3.2 (macOS default). No bash 4+ features are used.
6. **`.mcp.json` is managed automatically:** Users are not expected to edit `.mcp.json` directly; `install_mcp.sh` manages it via `claude mcp add`.
7. **Git as VCS:** All commands and skills assume Git is available. All state is file-based.
8. **Defensive protocol is always loaded:** Project workflow skills implicitly assume v2 defensive protocol rules (anti-slop, epistemology, session-management) are loaded in the consuming project.
9. **No runtime state:** All state is file-based (`progress.txt`, `milestone-status.txt`). No database, no APIs, no persistent agent memory outside of the file system.

---

## 6. Patterns to Deviate From

### ~~Deprecated MCP Servers in install_mcp.sh (PROBLEM-12 — resolved)~~

**Resolved in Feature 01.1.** Both deprecated servers have been removed from `mcp/install_mcp.sh`:

| Server | Action Taken |
|--------|-------------|
| `awslabs-terraform-mcp-server` | Replaced with `terraform-mcp-server` (HashiCorp official, `docker run -i --rm hashicorp/terraform-mcp-server`) |
| `awslabs-code-doc-gen-mcp-server` | Removed with no replacement (Claude handles doc generation natively) |

Users who previously installed either server must manually remove them:
- `claude mcp remove awslabs-code-doc-gen-mcp-server`
- `claude mcp remove awslabs-terraform-mcp-server`

### Benchmark Suite Maintenance

`scripts/benchmark/` infrastructure exists but has no recorded runs since 2024-11-20. Not part of PROBLEM-12 scope.

---

## 7. Open Questions

1. **`agentic-engineering/` purpose:** Directory exists but has no documentation or consumer-facing reference. Is it active? Should it be in `.gitignore`?
2. **`agents/` directory:** Root `agents/` exists as an empty stub. Purpose unclear — is it reserved for a future agent definition pattern?
3. **Kiro parity:** Are the Kiro equivalents in `kiro/` actively maintained? What is the process when a fix is applied to the Claude Code version?
4. **MCP version pinning:** `install_mcp.sh` installs `@latest`. Is there a strategy for pinning versions if a breaking change happens upstream?

---

## 8. Recent Changes

| Commit | Topic | Nature |
|--------|-------|--------|
| (Feature 01.1) | Remove `awslabs-code-doc-gen-mcp-server`, replace `awslabs-terraform-mcp-server` with HashiCorp `terraform-mcp-server` | bugfix/maintenance (PROBLEM-12 primary scope) |
| 250ffb7 | Exclude working directory (`working/` added to .gitignore) | chore/config |
| 3a1ae42 | Cleanup | maintenance |
| 02879fe | Project skill with 11-phase GSD workflow | feature (major) |
| 2b361a0 | `/start-feature` improvements + `/start-feature-auto` | feature |
| 057b497 | `/dream` memory consolidation command | feature |
| 225e9af | Simplify CLAUDE.md | docs |
| a345c5d | AWS Well-Architected Review solution kit | feature |
| b45cedd | NotebookLM MCP pattern + command invocability fix | feature + bugfix |
| 47a80e9 | Skills refactor, benchmark tooling, docs overhaul | large refactor |

**Activity level:** 1–2 commits/week (March–April 2026). Focused on skills expansion, command improvements, and MCP server cleanup (PROBLEM-12). No emergency fixes or security patches in recent history.
