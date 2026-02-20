---
name: cdk-testing
description: Run CDK validation, security scanning, build, test, and deployment. Use when the user asks to test CDK code, validate CDK configurations, run CDK checks, or deploy CDK to a dev environment. Triggers on requests like "test cdk", "validate my cdk", "run cdk checks", "deploy cdk to dev", or "/test-cdk".
---

# CDK Testing

Portable CDK validation and deployment pipeline. Runs git-secrets, Prettier, ESLint, TypeScript build, Jest tests, npm audit, then optionally CDK deploy via a shell script plus CDK CLI.

## Prerequisites

Before running, ensure:
- Feature code and tests are complete
- Feature is marked `[~]` (in progress) in `progress.txt`
- You know which feature number you're completing (e.g., 10.1)

## Workflow

1. Run the validation script (Gate 1)
2. Run CDK deploy (Gate 2)
3. On success: run commit workflow (Gate 3) — see references/commit-workflow.md

## Gate 1 — Validation Script

The script is bundled with this skill at `.claude/skills/cdk-testing/scripts/cdk-validation.sh`.

```bash
# Default
bash .claude/skills/cdk-testing/scripts/cdk-validation.sh

# Specific AWS profile
AWS_PROFILE=dev-account bash .claude/skills/cdk-testing/scripts/cdk-validation.sh

# Skip npm audit
bash .claude/skills/cdk-testing/scripts/cdk-validation.sh --skip-audit
```

### Pipeline Steps

| Step | Tool | Critical | Purpose |
|---|---|---|---|
| 1 | git-secrets | Yes | Scan for hardcoded secrets |
| 2 | Prettier | Yes | Check code formatting |
| 3 | ESLint | Yes | Lint TypeScript for errors |
| 4 | TypeScript | Yes | Compile the project (`npm run build`) |
| 5 | Jest | Yes | Run unit tests |
| 6 | npm audit | No | Check dependency vulnerabilities |

The script auto-detects OS and skips tools not configured in `package.json` (format:check, lint).

**Pass criteria:** Script exits with code 0 ("All required checks passed")
**On failure:** STOP. Report which check failed. Do not proceed to Gate 2.

## Gate 2 — CDK Deploy

Deploy all stacks to the development environment:

```bash
npx cdk deploy --all --profile dev-account --require-approval never
```

**Pass criteria:** All stacks deploy successfully (exit code 0)
**On failure:** STOP. Report the deployment error. Do not proceed to Gate 3.

## Gate 3 — Commit

Only execute if Gates 1-2 both passed. Follow the commit workflow in `.claude/skills/cdk-testing/references/commit-workflow.md`.

## Output Format

```text
GATE 1 — Validation Script: PASS
  - git-secrets: passed (or skipped)
  - Prettier: passed (or skipped)
  - ESLint: passed (or skipped)
  - Build: passed
  - Tests: passed
  - npm audit: passed (or warn)

GATE 2 — CDK Deploy: PASS (4 stacks deployed)

GATE 3 — Commit: PASS (committed as feat: X.Y — ...)

All gates passed. Feature X.Y is complete.
```

## Failure Handling

- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **npm audit findings:** Reported as warnings. Review with `npm audit`.
- **CDK deploy failure:** Check CloudFormation events for the root cause.

## Important Rules

- **Sequential execution:** Never skip a gate or run gates in parallel
- **Stop on failure:** If any gate fails, stop immediately and report
- **No silent errors:** Always show the actual error output
- **Explicit staging:** Stage each file by name, never use wildcards
- **Local commits only:** Never push to remote
- **Feature documentation required:** Create docs/FEATURE_X.Y.md before committing
