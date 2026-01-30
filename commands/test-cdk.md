---
name: test-cdk
description: Run all validation gates and commit. Only invoke when the user explicitly asks to run /test-cdk or says to test and commit a completed feature. Never invoke proactively.
---

# /test-cdk — Run All Gates and Commit

Execute the full testing workflow for the current feature. All gates must pass sequentially before committing.

## Prerequisites

Before running /test-cdk, ensure:
- You have completed the feature code and tests
- The feature is marked `[~]` (in progress) in `progress.txt`
- You know which feature number you're completing (e.g., 10.1)

## Execution Steps

### Gate 1 — Validation Script

Run the comprehensive pre-commit validation script:

```bash
AWS_PROFILE=developer-account bash scripts/cdk-validation.sh
```

**What it validates:**
| Step | Tool | Purpose |
|------|------|---------|
| 1 | git-secrets | Scans for hardcoded secrets (AWS keys, passwords) |
| 2 | Prettier | Checks code formatting consistency |
| 3 | ESLint | Lints TypeScript for errors and style issues |
| 4 | TypeScript | Compiles the project (`npm run build`) |
| 5 | npm audit | Checks for npm dependency vulnerabilities |
| 6 | Snyk | Security vulnerability scan (if installed) |

**Pass criteria:** Script exits with code 0 ("All required checks passed")
**On failure:** STOP. Report which check failed. Do not proceed to Gate 2.

### Gate 2 — CDK Deploy

Deploy all stacks to the development environment:

```bash
npx cdk deploy --all --profile developer-account --require-approval never
```

**Pass criteria:** All stacks deploy successfully (exit code 0)
**On failure:** STOP. Report the deployment error. Do not proceed to Gate 3.

### Gate 3 — Commit

Only execute this gate if Gates 1-2 both passed.

1. **Read `progress.txt`** to identify the current in-progress feature (marked `[~]`)

2. **Update `progress.txt`:**
   - Change the feature status from `[~]` to `[x]`
   - Add completion date to NOTES (format: `Completed YYYY-MM-DD`)

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
   [If new config params were added — parameter name, default, description]

   ## Tests Added
   [List new test names and what they verify. Include test count delta.]

   ## Decisions
   [Architecture or implementation choices and rationale. Deviations from PRD.]

   ## Verification
   [Commands to verify the feature works in a deployed environment]
   ```

   **Guidelines:**
   - Infrastructure features: emphasize Decisions, Verification (AWS CLI commands)
   - Config features: emphasize Configuration table, Files Changed
   - Refactoring features: minimal — just Summary and Files Changed
   - Keep it factual and concise — not a tutorial, just a record

5. **Stage files individually** (never use `git add .` or `git add -A`):
   - Feature code files (lib/, lambda/, bin/)
   - Test files (test/)
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
GATE 1 — Validation Script: PASS
  - git-secrets: passed (or skipped)
  - Prettier: passed (or skipped)
  - ESLint: passed (or skipped)
  - Build: passed
  - npm audit: passed
  - Snyk: passed (or skipped)

GATE 2 — CDK Deploy: PASS (4 stacks deployed)

GATE 3 — Commit: PASS (committed as feat: X.Y — ...)

All gates passed. Feature X.Y is complete.
```

If any gate fails:

```
GATE 1 — Validation Script: FAIL

Failed at: ESLint
Error: [error message]

Stopping at Gate 1. Please fix the error and run /test-cdk again.
```

## Important Rules

- **Sequential execution:** Never skip a gate or run gates in parallel
- **Stop on failure:** If any gate fails, stop immediately and report
- **No silent errors:** Always show the actual error output
- **Explicit staging:** Stage each file by name, never use wildcards
- **Local commits only:** Never push to remote
- **Feature documentation required:** Create docs/FEATURE_X.Y.md before committing
