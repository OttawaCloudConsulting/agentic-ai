---
name: compliance-auto-assess
description: Automated ITSG-33 / CCCS Medium compliance assessment. Dispatches a sub-agent to run all phases without user interaction.
---

# /compliance-auto-assess — Automated Compliance Assessment (Dispatcher)

This skill dispatches the ITSG-33 / CCCS Medium compliance assessment as a sub-agent via the Task tool. The assessment runs all phases (discovery, control mapping, gap analysis) end-to-end without user interaction, writing results to `docs/compliance/`.

## How to Invoke

- **Single repo:** `/compliance-auto-assess`
- **Mono-repo:** `/compliance-auto-assess @path/to/project/`

## Dispatch Steps

1. **Determine target path** from the command arguments:
   - If a path was provided (e.g., `@s3-static-website-with-cloudfront/terraform/`), resolve it to an absolute path
   - If no path was provided, use the repository root

2. **Read the instructions file** using the Read tool:
   - Path: `.claude/compliance-auto-assess-instructions.md` (relative to project root)

3. **Dispatch via Task tool** with these parameters:
   - `subagent_type`: `"general-purpose"`
   - `description`: `"ITSG-33 compliance assessment"`
   - `prompt`: The full contents of the instructions file, followed by:
     ```

     ---

     **Target directory:** <resolved absolute path>

     Run the full assessment against the target directory now. Execute all phases (0 through 3) without stopping.
     ```

4. **Return results**: When the sub-agent completes, relay its response to the user. The response will contain the executive summary and paths to all output files.

## Important

- **Always dispatch via Task tool** — do NOT execute the assessment instructions in the main conversation. This is the entire purpose of this skill.
- The instructions file contains all phase definitions, control tables, output templates, and assessment rules.
- The sub-agent writes all output to `docs/compliance/` within the project.
