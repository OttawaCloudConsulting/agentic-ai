---
name: test-terraform
description: Run all validation gates and commit. Only invoke when the user explicitly asks to run /test-terraform or says to test and commit a completed feature. Never invoke proactively.
---

# /test-terraform — Run All Gates and Commit

Execute the full testing workflow for the current feature. All gates must pass sequentially before committing.

## Prerequisites

Before running /test-terraform, ensure:
- You have completed the feature code
- The feature is marked `[~]` (in progress) in `progress.txt`
- You know which feature number you're completing (e.g., 2.1)

## Execution Steps

### Gate 1 & 2 — Validation, Plan & Apply

Run the automated test script that performs all validation checks, generates a plan, and deploys to the development environment.

**Command:**

```bash
bash tests/test-terraform.sh
```

The script automatically performs the following steps:

| Step | Tool | Purpose |
|------|------|---------|
| 1 | git-secrets | Scans for hardcoded secrets (AWS keys, passwords) |
| 2 | terraform fmt | Checks HCL formatting consistency |
| 3 | terraform init | Ensures providers are initialized |
| 4 | terraform validate | Syntax and internal consistency check |
| 5 | tflint | Provider-aware linting (skip if not installed) |
| 6 | checkov | Security scanning |
| 7 | trivy | Security scanning |
| 8 | terraform plan | Generate deployment plan |
| 9 | terraform apply | Deploy to dev account |

The script will:

- Auto-detect your OS (macOS, Ubuntu/Debian, RHEL/CentOS/Fedora)
- Install missing tools automatically using the appropriate package manager
- Stop on critical failures (Steps 1-5, 8-9)
- Continue with warnings for security scan findings (Steps 6-7) - security scans report findings but do NOT fail the pipeline

**Pass criteria:** All validation checks pass and deployment completes successfully (exit code 0)

**On failure:** STOP. Review the error output. Do not proceed to Gate 3.

**Note:** Checkov and Trivy security scans will report findings as warnings but will not stop the pipeline. Review security findings and address them as needed, but they do not block deployment. If security findings are false positives or accepted risks, it is acceptable to suppress specific rules:

- **Checkov**: Use inline comments in the terraform code `# checkov:skip=CKV_AWS_XX:Reason for suppression`
- **Trivy**: Use `.trivyignore` file or inline comments with `# trivy:ignore:AVD-AWS-XXXX`

Document suppression decisions in feature documentation or commit messages.

### Gate 3 — Commit

Only execute this gate if Gates 1–2 both passed.

1. **Read `progress.txt`** to identify the current in-progress feature (marked `[~]`)

2. **Update `progress.txt`:**
   - Change the feature status from `[~]` to `[x]`
   - Add completion date (format: `Completed YYYY-MM-DD`)

3. **Update `CHANGELOG.md`:**
   - Add entry for the completed feature
   - Format: `## [Feature X.Y] — YYYY-MM-DD` with brief summary

4. **Create feature documentation** at `docs/FEATURE_X.Y.md` (if it doesn't exist). Adapt sections to the feature type — not every section applies to every feature. Use this structure:

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

   **Guidelines:**
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

6. **Generate commit message** based on feature context:
   - Format: `feat: X.Y — [Brief description from progress.txt]`

7. **Commit locally:**

   ```bash
   git commit -m "$(cat <<'EOF'
   feat: X.Y — [Description]

   [Optional: 1-2 sentence summary of what changed]
   EOF
   )"
   ```

8. **Do NOT push** — commits are local only per project rules

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

If any gate fails:

```text
GATE 1 & 2 — Validation, Plan & Apply: FAIL

Failed at: terraform validate
Error: [error message]

Stopping. Please fix the error and run /test-terraform again.
```

## Important Rules

- **Sequential execution:** Never skip a gate or run gates in parallel
- **Stop on failure:** If any gate fails, stop immediately and report
- **No silent errors:** Always show the actual error output
- **Explicit staging:** Stage each file by name, never use wildcards
- **Local commits only:** Never push to remote
- **Feature documentation required:** Create docs/FEATURE_X.Y.md before committing
- **Plan before apply:** Never run `terraform apply` without reviewing `terraform plan` output first
