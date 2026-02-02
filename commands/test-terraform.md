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

### Gate 1 — Validation

Run each check sequentially. Stop on first failure.

| Step | Tool | Purpose |
|------|------|---------|
| 1 | git-secrets | Scans for hardcoded secrets (AWS keys, passwords) |
| 2 | terraform fmt | Checks HCL formatting consistency |
| 3 | terraform init | Ensures providers are initialized |
| 4 | terraform validate | Syntax and internal consistency check |
| 5 | tflint | Provider-aware linting (skip if not installed) |
| 6 | tfsec / checkov | Security scanning (skip if not installed) |

**Commands:**

```bash
# Step 1
git-secrets --scan

# Step 2 — Do NOT auto-fix; report and stop
terraform fmt -check -recursive

# Step 3
terraform init

# Step 4
terraform validate

# Step 5 (skip if not installed, note in output)
tflint

# Step 6 (skip if not installed, note in output)
tfsec . || checkov -d .
```

**Pass criteria:** All required checks pass (Steps 1–4). Steps 5–6 are advisory if the tool is not installed.
**On failure:** STOP. Report which check failed. Do not proceed to Gate 2.

### Gate 2 — Plan & Apply

Deploy to the development environment:

```bash
# Step 1 — Plan
AWS_PROFILE=<PROFILE_NAME> terraform plan -out=tfplan

# Step 2 — Review plan summary (resources to add/change/destroy)

# Step 3 — Apply from saved plan
AWS_PROFILE=<PROFILE_NAME> terraform apply tfplan
```

**Pass criteria:** Plan produces expected changes and apply completes successfully (exit code 0)
**On failure:** STOP. Report the error. Do not proceed to Gate 3.

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
   - Include `Co-Authored-By: Claude <noreply@anthropic.com>` footer

7. **Commit locally:**
   ```bash
   git commit -m "$(cat <<'EOF'
   feat: X.Y — [Description]

   [Optional: 1-2 sentence summary of what changed]

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

8. **Do NOT push** — commits are local only per project rules

## Output Format

Report results after each gate:

```
GATE 1 — Validation: PASS
  - git-secrets: passed
  - terraform fmt: passed
  - terraform init: passed
  - terraform validate: passed
  - tflint: passed (or skipped — not installed)
  - tfsec: passed (or skipped — not installed)

GATE 2 — Plan & Apply: PASS
  Plan: 3 to add, 0 to change, 0 to destroy
  Apply: completed successfully

GATE 3 — Commit: PASS (committed as feat: X.Y — ...)

All gates passed. Feature X.Y is complete.
```

If any gate fails:

```
GATE 1 — Validation: FAIL

Failed at: terraform validate
Error: [error message]

Stopping at Gate 1. Please fix the error and run /test-terraform again.
```

## Important Rules

- **Sequential execution:** Never skip a gate or run gates in parallel
- **Stop on failure:** If any gate fails, stop immediately and report
- **No silent errors:** Always show the actual error output
- **Explicit staging:** Stage each file by name, never use wildcards
- **Local commits only:** Never push to remote
- **Feature documentation required:** Create docs/FEATURE_X.Y.md before committing
- **Plan before apply:** Never run `terraform apply` without reviewing `terraform plan` output first
