# Automated Compliance Assessment Workflow

Dispatch the full ITSG-33 / CCCS Medium compliance assessment as a background task. Runs all phases (discovery, control mapping, gap analysis) end-to-end without user interaction, writing results to `docs/compliance/`.

## How to Invoke

- **Single repo:** Activate with no arguments to assess the repository root
- **Mono-repo:** Provide a path argument (e.g., `path/to/project/`) to target a specific project directory

## Dispatch Steps

1. **Determine target path** from the arguments:
   - If a path was provided, resolve it to an absolute path
   - If no path was provided, use the repository root

2. **Read the assessment instructions** from the interactive assessment steering file to understand the full phase definitions, control tables, output templates, and rules.

3. **Dispatch as a background task** with these parameters:
   - Target directory: the resolved absolute path
   - Instructions: Run the full assessment against the target directory, executing all phases (0 through 3) without stopping for user checkpoints

4. **Return results**: When the assessment completes, relay the response. The response will contain the executive summary and paths to all output files in `docs/compliance/`.

## Rules

- The assessment runs all phases without pausing for user checkpoints — this is the key difference from the interactive workflow
- All phase definitions, control tables, and rules from the interactive assessment apply
- Output files are written to `docs/compliance/` within the target project
- If previous assessment output exists, the automated run replaces it entirely (no smart re-run prompting)
