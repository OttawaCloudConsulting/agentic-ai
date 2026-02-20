# Terraform Validation and Deploy Workflow

Execute the full validation and deployment pipeline for Terraform code. All gates must pass sequentially before committing.

## Prerequisites

Before running this workflow, ensure:
- Feature code is complete
- The feature is marked `[~]` (in progress) in `progress.txt`
- You know which feature number is being completed (e.g., 2.1)

## Gate 1 and 2 — Validation, Plan, and Apply

Run the automated test script that performs all validation checks, generates a plan, and deploys to the development environment.

The script lives at `tests/test-terraform.sh` or `scripts/test-terraform.sh`. Run it from the project root.

### Pipeline Steps

| Step | Tool | Purpose |
|------|------|---------|
| 1 | git-secrets | Scan for hardcoded secrets (AWS keys, passwords) |
| 2 | terraform fmt | Check HCL formatting consistency |
| 3 | terraform init | Ensure providers are initialized |
| 4 | terraform validate | Syntax and internal consistency check |
| 5 | tflint | Provider-aware linting (skip if not installed) |
| 6 | checkov | Security scanning |
| 7 | trivy | Security scanning |
| 8 | terraform plan | Generate deployment plan |
| 9 | terraform apply | Deploy to dev account |

### Script Behavior

- Auto-detects OS (macOS, Ubuntu/Debian, RHEL/CentOS/Fedora)
- Installs missing tools automatically using the appropriate package manager
- Stops on critical failures (steps 1-5, 8-9)
- Continues with warnings for security scan findings (steps 6-7) — security scans report findings but do not fail the pipeline

**Pass criteria:** All validation checks pass and deployment completes successfully (exit code 0).

**On failure:** Stop. Review the error output. Do not proceed to the commit gate.

### Suppressing Security Scan False Positives

If security findings are false positives or accepted risks, suppress specific rules:

- **Checkov**: Inline comment `# checkov:skip=CKV_AWS_XX:Reason for suppression`
- **Trivy**: `.trivyignore` file or inline comment `# trivy:ignore:AVD-AWS-XXXX`

Document suppression decisions in feature documentation or commit messages.

## Gate 3 — Commit

Only execute this gate if gates 1-2 passed.

1. **Read `progress.txt`** to identify the current in-progress feature (marked `[~]`)

2. **Update `progress.txt`:**
   - Change feature status from `[~]` to `[x]`
   - Add completion date (format: `Completed YYYY-MM-DD`)

3. **Update `CHANGELOG.md`:**
   - Add entry for the completed feature
   - Format: `## [Feature X.Y] — YYYY-MM-DD` with brief summary

4. **Create feature documentation** at `docs/FEATURE_X.Y.md` (if it doesn't exist). Adapt sections to the feature type — not every section applies to every feature:

   ```markdown
   # Feature X.Y — [Title]

   ## Summary
   [1-2 sentences: what was built and why]

   ## Files Changed
   | File | Change |
   |------|--------|
   | `path/to/file` | What changed |

   ## Configuration
   [If new variables were added — variable name, type, default, description]

   ## Validation
   [Plan output summary: resources added/changed/destroyed]

   ## Decisions
   [Architecture or implementation choices and rationale. Deviations from PRD.]

   ## Verification
   [Commands to verify the feature works in a deployed environment]
   ```

   Guidelines:
   - Infrastructure features: emphasize Decisions, Verification (AWS CLI commands)
   - Config features: emphasize Configuration table, Files Changed
   - Module features: emphasize module inputs/outputs, Validation (plan summary)
   - Keep it factual and concise — not a tutorial, just a record

5. **Stage files individually** (never use `git add .` or `git add -A`):
   - Feature code files (modules/, envs/)
   - Updated progress.txt
   - Updated CHANGELOG.md
   - Feature documentation (docs/FEATURE_X.Y.md)
   - Any other files explicitly modified for this feature

6. **Commit locally** with message format: `feat: X.Y — [Brief description from progress.txt]`

7. **Do not push** — commits are local only

## Output Format

Report results after each gate:

```text
GATE 1 & 2 — Validation, Plan & Apply: PASS
  - git-secrets: passed
  - terraform fmt: passed
  - terraform init: passed
  - terraform validate: passed
  - tflint: passed (or skipped — not installed)
  - checkov: completed with warnings (or passed)
  - trivy: completed with warnings (or passed)
  Plan: 3 to add, 0 to change, 0 to destroy
  Apply: completed successfully

GATE 3 — Commit: PASS (committed as feat: X.Y — ...)

All gates passed. Feature X.Y is complete.
```

On failure:

```text
GATE 1 & 2 — Validation, Plan & Apply: FAIL

Failed at: terraform validate
Error: [error message]

Stopping. Please fix the error and re-run.
```

## Rules

- **Sequential execution:** Never skip a gate or run gates in parallel
- **Stop on failure:** If any gate fails, stop immediately and report
- **No silent errors:** Always show the actual error output
- **Explicit staging:** Stage each file by name, never use wildcards
- **Local commits only:** Never push to remote
- **Feature documentation required:** Create docs/FEATURE_X.Y.md before committing
- **Plan before apply:** Never run `terraform apply` without reviewing `terraform plan` output first
