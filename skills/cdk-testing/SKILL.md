---
name: cdk-testing
description: Run CDK validation, security scanning, build, test, and deployment. Use when the user asks to test CDK code, validate CDK configurations, run CDK checks, or deploy CDK to a dev environment. Triggers on requests like "test cdk", "validate my cdk", "run cdk checks", "deploy cdk to dev", or "/test-cdk". Handles TypeScript CDK projects with cdk.json and package.json. Do NOT use for CDK synth-only workflows, Python CDK projects, non-CDK TypeScript testing, or staging/production deployments.
compatibility: Requires Node.js, npm, AWS CDK CLI (npx cdk), git-secrets (optional), and configured AWS credentials (AWS_PROFILE or environment variables).
---

# CDK Testing

Portable CDK validation and deployment pipeline. Runs git-secrets, Prettier, ESLint, TypeScript build, Jest tests, npm audit, then optionally CDK deploy via a shell script plus CDK CLI.

## Critical Rules

- **Sequential execution:** Never skip a gate or run gates in parallel.
- **Stop on failure:** If any gate fails, stop immediately and report the error.
- **No silent errors:** Always show the actual error output.
- **Explicit staging:** Stage each file by name, never use wildcards.
- **Local commits only:** Never push to remote.
- **Dev environment only:** The CDK deploy step uses `--require-approval never`. Never use this against production or shared environments.

## Prerequisites

Before running, confirm:

- `cdk.json` exists at the project root
- `package.json` exists at the project root and defines `build`, `test`, and (optionally) `format:check` and `lint` scripts

Adapt the commit workflow references to your project's conventions. The defaults reference a `progress.txt` tracking file and `X.Y` feature numbering scheme. Replace these with whatever tracking mechanism your project uses.

## Workflow

1. Run the validation script (Gate 1)
2. Run CDK deploy (Gate 2)
3. On success: run commit workflow (Gate 3) -- after Gates 1-2 pass, read `references/commit-workflow.md` for the commit procedure

## Gate 1 -- Validation Script

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

## Gate 2 -- CDK Deploy

Deploy all stacks to the development environment.

```bash
npx cdk deploy --all --profile dev-account --require-approval never
```

**Pass criteria:** All stacks deploy successfully (exit code 0)
**On failure:** STOP. Report the deployment error. Do not proceed to Gate 3.

## Gate 3 -- Commit

Only execute if Gates 1-2 both passed. Follow the commit workflow in `references/commit-workflow.md`.

The commit workflow references project-specific files (`progress.txt`, `CHANGELOG.md`, `docs/FEATURE_X.Y.md`). Adapt these to your project's conventions or remove steps that do not apply.

## Example

User says: "test cdk and deploy to dev"

```text
GATE 1 -- Validation Script: PASS
  - git-secrets: passed
  - Prettier: passed
  - ESLint: passed
  - Build: passed
  - Tests: passed (14 tests, 3 suites)
  - npm audit: passed

GATE 2 -- CDK Deploy: PASS (4 stacks deployed)

GATE 3 -- Commit: PASS (committed as feat: 10.1 -- Add API Gateway throttling)

All gates passed. Feature complete.
```

## Failure Handling

- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **git-secrets not installed:** Secrets scanning is skipped automatically; the pipeline continues without it. If secrets scanning is required, install git-secrets before running.
- **npm audit findings:** Reported as warnings. Review with `npm audit`.
- **CDK deploy -- IAM permission error:** Check that the AWS profile has sufficient permissions. Run `aws sts get-caller-identity --profile <profile>` to verify the active role.
- **CDK deploy -- bootstrap required:** Run `npx cdk bootstrap aws://<account>/<region> --profile <profile>` before deploying.
- **CDK deploy -- stack dependency failure:** Check CloudFormation events for the failing stack. Dependencies between stacks may require deploying in a specific order -- use `npx cdk deploy StackName` to deploy individually.
- **CDK deploy -- region mismatch:** Ensure `AWS_DEFAULT_REGION` or the profile's default region matches the region specified in the CDK app.
