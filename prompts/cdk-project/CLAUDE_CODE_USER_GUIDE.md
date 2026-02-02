# Claude Code User Guide — cdk-zabbix

Guide for developers using Claude Code with this project. Covers the development workflow, available skills, session lifecycle, and what to expect.

## Prerequisites

- [Claude Code CLI](https://code.claude.com) installed
- AWS CLI profile `developer-account` configured
- Node.js v18+ with project dependencies installed (`npm install`)
- Familiarity with the project: read `README.md` for architecture, `prd.md` for requirements

## How Skills Work

Skills are custom commands defined in `.claude/commands/`. They extend Claude's capabilities with project-specific workflows. You invoke them by typing `/skill-name` in the Claude Code session, or by asking Claude to run them (e.g., "run the tests and commit").

Some skills are invoked automatically by Claude when relevant (like the defensive coding protocol during debugging). Others are manual-only — you must explicitly invoke them.

### Available Skills

| Skill | Trigger | Description |
| --- | --- | --- |
| `/start-feature` | You or Claude | Begin the next feature from the roadmap |
| `/test-cdk` | You or Claude | Run validation gates, deploy, and commit |
| `/update-docs` | You only | Refresh README, ARCHITECTURE, TESTING docs |
| `/catchup` | You or Claude | Read project state at the start of a session |
| `/handoff` | You only | Save session state before ending |
| `/investigate` | You or Claude | Structured debugging for unknowns |
| `defensive-protocol` | Claude (automatic) | Loaded when writing code, debugging, or investigating |

## Development Workflow

The project follows a strict **Feature > Test > Complete > Next Feature** cycle. Every feature is tracked in `progress.txt`.

### 1. Start a feature

```
/start-feature
```

Claude reads `progress.txt`, identifies the next pending feature, reads `prd.md` for requirements, marks the feature as in-progress (`[~]`), and reports what needs to be built. It does **not** start implementation — it waits for your direction.

**What you see:**

```
STARTING: Feature 12.3 — NLB integration

REQUIREMENTS:
- Internal NLB on port 10051
- Cross-zone load balancing
- Health check on TCP 10051

FILES LIKELY AFFECTED:
- lib/constructs/internal-nlb.ts (new)
- lib/zabbix/ecs-stack.ts (modified)
- test/ecs-stack.test.ts (new tests)

Ready to begin implementation.
```

At this point, direct Claude on what to build. It follows `prd.md` for architecture decisions.

### 2. Implement and write tests

Work with Claude to build the feature. Claude writes code and assertion tests. You can review, ask questions, request changes. Every feature must have new tests that verify the synthesized CloudFormation template.

During implementation, Claude follows the defensive coding protocol automatically. If something fails, it stops and reports rather than silently retrying.

### 3. Complete the feature

```
/test-cdk
```

This runs three sequential gates. Each must pass before the next starts:

**Gate 1 — Validation Script**
Runs `scripts/cdk-validation.sh`: git-secrets scan, Prettier, ESLint, TypeScript build, npm audit, Snyk.

**Gate 2 — CDK Deploy**
Deploys all four stacks to the dev account: DatabaseStack > EcsStack > AdminPasswordStack > MonitoringStack.

**Gate 3 — Commit**
Updates `progress.txt` (`[~]` → `[x]`), writes `CHANGELOG.md` entry, creates `docs/FEATURE_X.Y.md`, stages files individually, and commits locally.

**What you see:**

```
GATE 1 — Validation Script: PASS
  - git-secrets: passed
  - Build: passed
  - npm audit: passed

GATE 2 — CDK Deploy: PASS (4 stacks deployed)

GATE 3 — Commit: PASS (committed as feat: 12.3 — NLB integration)

All gates passed. Feature 12.3 is complete.
```

If any gate fails, Claude stops immediately and reports the error. Fix the issue and run `/test-cdk` again.

### 4. Continue to next feature

After a successful `/test-cdk`, run `/compact` to free context, then `/start-feature` for the next one.

```
/compact
/start-feature
```

### 5. Refresh documentation (periodic)

After several features have been completed, documentation (README, ARCHITECTURE, TESTING) may have stale counts and tables.

```
/update-docs
```

Claude reads the codebase, runs tests for exact counts, and updates all three files. Run this before creating a pull request.

## Session Lifecycle

### Starting a session

If continuing from a previous session, run:

```
/catchup
```

Claude reads `agents/memory/handoff.md` (written by the last `/handoff`) and `progress.txt`, then reports current state, blockers, uncommitted changes, and next steps.

If this is a fresh start or there's no handoff file, Claude falls back to `progress.txt` only.

**What you see:**

```
SESSION CATCHUP

Last handoff: 2026-01-29

CURRENT FEATURE:
  Feature 12.3 — NLB integration
  Status: in progress
  Done: NLB construct created, security group rules added
  Remaining: Register server service as target, write tests

BLOCKERS: None

UNCOMMITTED CHANGES: Working tree clean

RECENT COMMITS:
  abc1234 feat: 12.2 — Cloud Map namespace
  def5678 feat: 12.1 — ECS cluster with Container Insights

NEXT STEPS:
  1. Register Zabbix Server as NLB target
  2. Write assertion tests for NLB resources

Ready to continue.
```

### Ending a session

Before closing the terminal or running `/clear`, save state:

```
/handoff
```

Claude reads `progress.txt`, `git status`, and recent commits, then writes a structured summary to `agents/memory/handoff.md`. The next session can pick up with `/catchup`.

**What you see:**

```
SESSION STATE SAVED to agents/memory/handoff.md

Current feature: 12.3 — NLB integration (in progress)
Uncommitted changes: none
Blockers: none
Next step: Register Zabbix Server as NLB target

Safe to /clear or close terminal.
```

If you forget to run `/handoff`, no data is lost — `progress.txt` and git history still exist. The handoff file adds context (what was in progress, decisions made, blockers) that helps the next session start faster.

### Debugging issues

When you hit a problem you don't immediately understand:

```
/investigate
```

Or say "investigate this" or "find the root cause" — Claude recognizes these triggers.

Claude creates a structured file at `agents/investigations/[slug].md` with:

- **Facts** — verified observations with evidence
- **Theories** — 3+ competing hypotheses
- **Tests Performed** — what was tried and what was observed
- **Resolution** — root cause, fix, and prevention

The investigation file persists across `/compact` and `/clear`, so long debugging sessions don't lose context.

## What to Expect from Claude

### Failure behavior

Claude follows a defensive coding protocol. When anything fails:

1. **Stops** — no silent retry
2. **Reports** — exact error, theory, proposed action
3. **Waits** — asks for confirmation before proceeding

You'll see structured output like:

```
FAILED: CDK deploy failed — EcsStack
THEORY: Security group circular dependency between stacks
PROPOSE: Use CfnSecurityGroupIngress to break the cycle
Proceed?
```

### What Claude won't do

- **Push to remote** — all commits are local only
- **Skip gates** — no feature is marked complete without validation + deploy + commit
- **Work outside the current feature** — if Claude notices something unrelated, it adds a note to `progress.txt` instead of fixing it
- **Use `git add .`** — files are staged individually
- **Set executable permissions** — scripts are run via `bash script.sh`

### Verifying test quality

When Claude shows test output, check for:

- `Test Suites: N passed` — Jest actually ran
- `Tests: N passed` — count should be proportional to the feature scope
- Individual test names visible (`--verbose`) — names describe real assertions, not "works" or "test1"

If anything looks suspicious, ask Claude to show the test file contents.

## Project Directories

| Directory | Purpose | Managed by |
| --- | --- | --- |
| `lib/` | CDK stack and construct source code | Developer + Claude |
| `test/` | Jest assertion tests | Developer + Claude |
| `lambda/` | Lambda handler source code | Developer + Claude |
| `docs/` | Project documentation (ARCHITECTURE, TESTING, FEATURE_*.md) | `/test-cdk`, `/update-docs` |
| `agents/memory/` | Session state (handoff between sessions) | `/handoff`, `/catchup` |
| `agents/investigations/` | Structured debugging files | `/investigate` |
| `.claude/commands/` | Skill definitions | Project maintainer |
| `scripts/` | Validation and utility shell scripts | Project maintainer |

## Key Files

| File | Purpose | Who updates it |
| --- | --- | --- |
| `progress.txt` | Feature roadmap and status tracking | `/start-feature`, `/test-cdk` |
| `prd.md` | Product requirements (architecture decisions) | Project maintainer |
| `CHANGELOG.md` | Per-feature changelog | `/test-cdk` |
| `cdk.json` | CDK configuration and deployment parameters | Developer |
| `lib/config.ts` | Typed configuration interface | Developer + Claude |
| `agents/memory/handoff.md` | Last session's end state | `/handoff` |

## Quick Reference

```
# Start of session
/catchup

# Begin a feature
/start-feature

# ... implement with Claude ...

# Complete and commit
/test-cdk

# Free context and continue
/compact
/start-feature

# Refresh docs before a PR
/update-docs

# End of session
/handoff
```
