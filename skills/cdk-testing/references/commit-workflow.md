# Gate 3 -- Commit Workflow

Only execute after all validation and deployment gates pass.

**Customization note:** The steps below reference `progress.txt`, `CHANGELOG.md`, and `docs/FEATURE_X.Y.md`. These are example project conventions. Adapt file names, feature numbering, and tracking mechanisms to match your project.

## Steps

1. **Read `progress.txt`** to identify the current in-progress feature (marked `[~]`)

2. **Update `progress.txt`:**
   - Change the feature status from `[~]` to `[x]`
   - Add completion date (format: `Completed YYYY-MM-DD`)

3. **Update `CHANGELOG.md`:**
   - Add entry for the completed feature
   - Format: `## [Feature X.Y] -- YYYY-MM-DD` with brief summary

4. **Create feature documentation** at `docs/FEATURE_X.Y.md` (if it doesn't exist). Adapt sections to the feature type -- not every section applies:

   ```markdown
   # Feature X.Y -- [Title]

   ## Summary
   [1-2 sentences: what was built and why]

   ## Files Changed
   | File | Change |
   |------|--------|
   | `path/to/file` | What changed |

   ## Configuration
   [If new config params were added -- parameter name, default, description]

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
   - Refactoring features: minimal -- just Summary and Files Changed
   - Keep it factual and concise -- not a tutorial, just a record

5. **Stage files individually** (never use `git add .` or `git add -A`):
   - Feature code files (lib/, lambda/, bin/)
   - Test files (test/)
   - Updated progress.txt
   - Updated CHANGELOG.md
   - Feature documentation (docs/FEATURE_X.Y.md)
   - Any other files explicitly modified for this feature

6. **Commit locally:**
   - Format: `feat: X.Y -- [Brief description from progress.txt]`
   - Do NOT push -- commits are local only

## Output Format

```text
GATE 3 -- Commit: PASS (committed as feat: X.Y -- ...)
```
