# Gate 0: Codebase Assessment

Scans the existing codebase and produces a structured assessment for use in subsequent gates. This reference contains the complete Gate 0 specification -- an executor reading only this file can run the full Gate 0 flow.

## Greenfield Detection (DEF-01)

Before running the codebase scan, check whether the project is greenfield. ALL of the following conditions must be true to classify as greenfield and skip Gate 0:

1. No `src/`, `app/`, or `lib/` directories exist
2. No dependency manifests exist: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`
3. Fewer than 5 non-config files (config files include: README, LICENSE, .gitignore, .editorconfig, .prettierrc, and similar dotfiles)
4. Only boilerplate files present (README + license + gitignore pattern)

**If ALL conditions are true:** Skip Gate 0 entirely. Record in progress.txt:

```
[-] Gate 0: Codebase Alignment  Skipped (greenfield)
```

Proceed directly to Gate WB.

**If ANY condition is false:** Proceed with the codebase scan below.

**Edge case:** Monorepos with sparse content should be treated as brownfield (conservative). If uncertain whether the project is greenfield, run Gate 0 -- it is cheaper to scan unnecessarily than to miss existing patterns.

## Codebase Scan (DEF-02)

Spawn a sub-agent using the `Agent` tool to perform a deep codebase scan. The agent reads 20-40 files and writes structured findings to a temporary scratch file.

### Agent Prompt

Instruct the agent to:

1. **Survey the project structure:**
   - Run `ls -R` (first 2 levels) for directory overview
   - Run `git log --oneline -20` for recent change patterns

2. **Select 20-40 files to read using these heuristics:**
   - Entry points: main files, index files, app entry points
   - Configuration files: package.json, tsconfig.json, webpack config, etc.
   - Test files: sample of test patterns and frameworks used
   - Key modules: largest files, most-imported files
   - Infrastructure: CI/CD configs, Dockerfiles, deployment scripts

3. **Read each selected file** using the Read tool.

4. **Write structured findings** to a temporary scratch file (e.g., `/tmp/codebase-scan-findings.md`) with these sections:
   - **Project Overview** -- language, framework, purpose
   - **File Organization** -- directory structure, naming patterns
   - **Detected Patterns** -- code style, architecture patterns, testing approach
   - **Dependency Graph** -- key dependencies, internal module relationships
   - **Assumptions** -- things the agent inferred but cannot verify
   - **Patterns That May Need Change** -- anti-patterns, inconsistencies
   - **Open Questions** -- things that need user clarification
   - **Recent Changes** -- patterns from git log

### Agent Tool Access

The agent uses only: `Read`, `Bash` (for `ls`, `git log`), and `Glob` tools.

## Assessment Production (DEF-03)

After the agent completes, synthesize its findings into the final assessment:

1. Read the agent's scratch file (e.g., `/tmp/codebase-scan-findings.md`)
2. Create `docs/` directory if it does not exist: `mkdir -p docs`
3. Write `docs/codebase-assessment.md` with these required sections:

### Required Assessment Sections

1. **Project Overview** -- language, framework, purpose, maturity level
2. **File Organization** -- directory structure, naming conventions, key locations
3. **Detected Patterns** -- code style, architecture patterns, testing approach, error handling
4. **Dependency Graph** -- key external dependencies (with versions), internal module relationships
5. **Assumptions** -- things inferred from code that cannot be verified without user input
6. **Patterns to Deviate From** -- anti-patterns, inconsistencies, or conventions that should not be carried forward
7. **Open Questions** -- ambiguities that need user clarification before proceeding
8. **Recent Changes** -- patterns from git history indicating current development focus

The assessment must be factual and specific -- cite file paths, line counts, dependency versions. Avoid vague statements.

4. Clean up the scratch file after synthesis: `rm /tmp/codebase-scan-findings.md`

## Review Phase (DEF-05)

Present the assessment to the user using the produce-then-review cycle:

1. **Present a summary** of the assessment to the user. Highlight:
   - Key findings (language, framework, architecture)
   - Detected patterns the model will follow
   - Patterns flagged for deviation
   - Open questions that need answers
   - Assumptions that need validation

2. **Use `AskUserQuestion`** with options:
   - **Approve** -- assessment is accurate, proceed to checklist validation
   - **Revise** -- assessment needs corrections

3. **If Revise:** Ask the user what needs changing. Apply edits to `docs/codebase-assessment.md`. Re-present the updated summary. Repeat until the user selects Approve.

4. **If Approve:** Proceed to Checklist Validation.

## Checklist Validation (DEF-04, DEF-06)

Generate and validate the review checklist:

1. Create `docs/reviews/` directory if needed: `mkdir -p docs/reviews`

2. Generate `docs/reviews/gate-0-review.md` using the Gate 0 section from `references/review-checklist-template.md`. Start with the file header:

   ```
   # Gate 0 Review -- Codebase Alignment

   **Artifact:** docs/codebase-assessment.md
   **Status:** [ ] Pending
   **Reviewer(s):**
   **Date:**
   ```

3. Include the Gate 0 static checklist items:
   - `[ ] Are the detected patterns accurate for the current codebase?`
   - `[ ] Are there patterns listed as "carry forward" that should be changed?`
   - `[ ] Are there existing patterns not detected that the model should follow?`
   - `[ ] Are the open questions answerable? Provide answers.`
   - `[ ] Are the assumptions stated in the assessment correct?`

4. Add content-specific `[Auto]` items based on actual assessment content. Examples:
   - `[ ] [Auto] Verify assumption: "{specific assumption from assessment}"`
   - `[ ] [Auto] Confirm pattern: "{specific pattern detected}"`
   - `[ ] [Auto] Review deviation: "{specific anti-pattern flagged}"`

5. **Claude pre-checks** items it can verify programmatically:
   - File `docs/codebase-assessment.md` exists
   - All required sections are present
   - File paths cited in the assessment exist on disk

6. **Present remaining unchecked items** to the user for resolution.

7. **All items must be `[x]` (verified) or `[-]` (N/A with reason)** before proceeding. No item may remain as `[ ]`.

8. Update the checklist `**Status:**` to `[x] Approved` with the current date.

## Gate Approval (DEF-07)

Record the gate approval in progress.txt:

1. Read `references/progress-format.md` for the exact gate entry format.

2. Update the Gate 0 line in progress.txt from:
   ```
   [ ] Gate 0: Codebase Alignment
   ```
   to:
   ```
   [x] Gate 0: Codebase Alignment  Approved: <YYYY-MM-DD>  docs/codebase-assessment.md
   ```
   where `<YYYY-MM-DD>` is the current date.

3. Only progress.txt is updated at this step -- no other state files are modified.

4. Proceed to Gate WB (read `references/gate-wb-working-backwards.md`).
