# CDK Testing

**Source:** `skills/cdk-testing/`
**Command:** `/cdk-testing`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "test cdk", "validate my cdk", "run cdk checks", "deploy cdk to dev")

## Description

Portable CDK validation and deployment pipeline. Runs a gated sequence of security scanning, code formatting, linting, TypeScript build, Jest tests, dependency audit, CDK deployment, and a structured commit workflow. Designed for AWS CDK TypeScript projects that track features in a `progress.txt` file.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with pipeline overview, gate descriptions, and invocation examples |
| `scripts/cdk-validation.sh` | Shell script implementing the 6-step validation pipeline (Gate 1) |
| `references/commit-workflow.md` | Step-by-step commit procedure executed after all gates pass (Gate 3) |

## Usage

```
/cdk-testing
```

The skill expects to be run from the root of a CDK TypeScript project with a `package.json` containing build and test scripts.

### Script Invocations

```bash
# Default — run full validation pipeline
bash .claude/skills/cdk-testing/scripts/cdk-validation.sh

# With a specific AWS profile
AWS_PROFILE=dev-account bash .claude/skills/cdk-testing/scripts/cdk-validation.sh

# Skip npm audit step
bash .claude/skills/cdk-testing/scripts/cdk-validation.sh --skip-audit
```

### CDK Deploy (Gate 2)

```bash
npx cdk deploy --all --profile dev-account --require-approval never
```

## Workflow

The skill executes three sequential gates. Each gate must pass before the next begins.

### Gate 1 — Validation Script

Runs `cdk-validation.sh`, which executes these steps in order:

| Step | Tool | Critical | Purpose |
|---|---|---|---|
| 1 | git-secrets | Yes | Scan for hardcoded secrets |
| 2 | Prettier | Yes | Check code formatting (`format:check` script) |
| 3 | ESLint | Yes | Lint TypeScript for errors (`lint` script) |
| 4 | TypeScript | Yes | Compile the project (`npm run build`) |
| 5 | Jest | Yes | Run unit tests (`npm test`) |
| 6 | npm audit | No | Check dependency vulnerabilities (warnings only) |

The script auto-detects OS (macOS, Debian, RHEL) and gracefully skips tools that are not installed or not configured in `package.json`. It installs npm dependencies (`npm ci`) if `node_modules/` is missing.

**Pass criteria:** Exit code 0 ("All required checks passed").
**On failure:** Stop immediately. Report which check failed. Do not proceed to Gate 2.

### Gate 2 — CDK Deploy

Deploys all CDK stacks to the development environment using `npx cdk deploy --all`. Requires AWS credentials (via `AWS_PROFILE` or environment).

**Pass criteria:** All stacks deploy successfully (exit code 0).
**On failure:** Stop immediately. Report the deployment error. Do not proceed to Gate 3.

### Gate 3 — Commit Workflow

Executes only after Gates 1 and 2 both pass. Follows the procedure in `references/commit-workflow.md`:

1. Read `progress.txt` to identify the current in-progress feature (marked `[~]`)
2. Update `progress.txt` — change `[~]` to `[x]`, add completion date
3. Update `CHANGELOG.md` — add entry for the completed feature
4. Create feature documentation at `docs/FEATURE_X.Y.md` with sections adapted to the feature type (summary, files changed, configuration, tests added, decisions, verification)
5. Stage files individually (never `git add .` or `git add -A`)
6. Commit locally with format `feat: X.Y — [Brief description]` — never push

### Output Format

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

## When to Use

- After completing a feature in an AWS CDK TypeScript project
- When you need to validate CDK code before deployment
- When you want a single command to run the full validate-deploy-commit cycle
- When a feature is marked `[~]` in `progress.txt` and ready for completion

## When Not to Use

- For Terraform projects — use `/terraform-testing` instead
- For compliance assessments — use `/compliance-assess` instead
- When you only need to run individual checks (e.g., just linting) — run the tool directly
- When the project does not use CDK or TypeScript

## Configuration

| Option | Method | Purpose |
|---|---|---|
| `AWS_PROFILE` | Environment variable | AWS CLI profile for CDK deploy |
| `--skip-audit` | CLI flag to validation script | Skip the npm audit step |
| `format:check` | `package.json` script | Required for Prettier check (skipped if absent) |
| `lint` | `package.json` script | Required for ESLint check (skipped if absent) |

## Related Skills and Commands

- **terraform-testing** — equivalent pipeline for Terraform projects
- **compliance-assess** — ITSG-33 compliance assessment (can follow after deployment)
