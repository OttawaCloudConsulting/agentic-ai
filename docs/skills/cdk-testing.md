# CDK Testing

**Source:** `skills/cdk-testing/`
**Command:** `/cdk-testing`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "test cdk", "validate my cdk", "run cdk checks", "deploy cdk to dev", "/test-cdk")
**Compatibility:** Requires Node.js, npm, AWS CDK CLI (`npx cdk`), git-secrets (optional), and configured AWS credentials (`AWS_PROFILE` or environment variables)

## Description

Portable CDK validation and deployment pipeline. Runs git-secrets, Prettier, ESLint, TypeScript build, Jest tests, npm audit, then optionally CDK deploy via a shell script plus CDK CLI. Handles TypeScript CDK projects with `cdk.json` and `package.json`. Not intended for CDK synth-only workflows, Python CDK projects, or non-CDK TypeScript testing.

## Bundle Contents

| File | Purpose |
|---|---|
| `SKILL.md` | Skill definition with pipeline overview, gate descriptions, and invocation examples |
| `scripts/cdk-validation.sh` | Shell script implementing the 6-step validation pipeline (Gate 1) |
| `references/commit-workflow.md` | Step-by-step commit procedure executed after all gates pass (Gate 3) |

## Critical Rules

- **Sequential execution:** Never skip a gate or run gates in parallel.
- **Stop on failure:** If any gate fails, stop immediately and report the error.
- **No silent errors:** Always show the actual error output.
- **Explicit staging:** Stage each file by name, never use wildcards.
- **Local commits only:** Never push to remote.
- **Dev environment only:** The CDK deploy step uses `--require-approval never`. Never use this against production or shared environments.

## Prerequisites

- Feature code and tests are complete.
- You know which feature you are completing.

The defaults reference a `progress.txt` tracking file and `X.Y` feature numbering scheme. Adapt these to your project's conventions.

## Usage

```text
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

**WARNING:** The `--require-approval never` flag bypasses CloudFormation change review. Use this only for dev/sandbox environments. For staging or production, remove the flag or set `--require-approval broadening`.

**Pass criteria:** All stacks deploy successfully (exit code 0).
**On failure:** Stop immediately. Report the deployment error. Do not proceed to Gate 3.

### Gate 3 — Commit Workflow

Executes only after Gates 1 and 2 both pass. Follows the procedure in `references/commit-workflow.md`.

The commit workflow references project-specific files (`progress.txt`, `CHANGELOG.md`, `docs/FEATURE_X.Y.md`). Adapt these to your project's conventions or remove steps that do not apply. Summary of steps:

1. Read `progress.txt` to identify the current in-progress feature (marked `[~]`)
2. Update `progress.txt` — change `[~]` to `[x]`, add completion date
3. Update `CHANGELOG.md` — add entry for the completed feature
4. Create feature documentation at `docs/FEATURE_X.Y.md` with sections adapted to the feature type (summary, files changed, configuration, tests added, decisions, verification)
5. Stage files individually (never `git add .` or `git add -A`)
6. Commit locally with format `feat: X.Y — [Brief description]` — never push

### Output Format

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
- For CDK synth-only workflows or Python CDK projects

## Failure Handling

- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **npm audit findings:** Reported as warnings. Review with `npm audit`.
- **CDK deploy — IAM permission error:** Check that the AWS profile has sufficient permissions. Run `aws sts get-caller-identity --profile <profile>` to verify the active role.
- **CDK deploy — bootstrap required:** Run `npx cdk bootstrap aws://<account>/<region> --profile <profile>` before deploying.
- **CDK deploy — stack dependency failure:** Check CloudFormation events for the failing stack. Dependencies between stacks may require deploying in a specific order — use `npx cdk deploy StackName` to deploy individually.
- **CDK deploy — region mismatch:** Ensure `AWS_DEFAULT_REGION` or the profile's default region matches the region specified in the CDK app.

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
