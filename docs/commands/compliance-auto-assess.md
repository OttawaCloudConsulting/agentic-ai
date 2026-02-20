# Compliance Auto-Assess

**Source:** `commands/compliance-auto-assess.md`
**Command:** `/compliance-auto-assess`
**Activation:** Manual — invoked via slash command or trigger phrase matching

## Description

Dispatches an automated ITSG-33 / CCCS Medium compliance assessment as a sub-agent via the Task tool. The assessment runs all phases (discovery, control mapping, gap analysis) end-to-end without user interaction and writes results to `docs/compliance/`. This command is a dispatcher — it reads an instructions file and delegates all work to a sub-agent.

## Usage

```
/compliance-auto-assess
/compliance-auto-assess @path/to/project/
```

- **Single repo:** Invoke without arguments to assess the repository root.
- **Mono-repo:** Provide a path argument prefixed with `@` to target a specific project directory.

## Inputs

| Input | Source | Required |
|---|---|---|
| Target directory path | Command argument (`@path/to/project/`) | No (defaults to repository root) |
| Assessment instructions | `.claude/compliance-auto-assess-instructions.md` | Yes |
| Infrastructure source code | Target directory contents (Terraform, CDK, CloudFormation, etc.) | Yes |

## Outputs

| Output | Location | Description |
|---|---|---|
| Compliance assessment report | `docs/compliance/` (within the target project) | Full ITSG-33 / CCCS Medium compliance assessment including discovery results, control mappings, and gap analysis |
| Executive summary | Console (stdout) | Summary of findings relayed from the sub-agent upon completion |

## Workflow

### Step 1 — Determine target path

Resolves the target directory from the command arguments:

- If a path was provided (e.g., `@s3-static-website-with-cloudfront/terraform/`), resolves it to an absolute path.
- If no path was provided, uses the repository root.

### Step 2 — Read the instructions file

Reads `.claude/compliance-auto-assess-instructions.md` (relative to the project root) using the Read tool. This file contains all phase definitions, control tables, output templates, and assessment rules.

### Step 3 — Dispatch via Task tool

Creates a sub-agent with these parameters:

- **subagent_type:** `"general-purpose"`
- **description:** `"ITSG-33 compliance assessment"`
- **prompt:** The full contents of the instructions file, followed by the resolved target directory path and an instruction to execute all phases (0 through 3) without stopping.

### Step 4 — Return results

When the sub-agent completes, relays its response to the user. The response contains the executive summary and paths to all output files written to `docs/compliance/`.

## When to Use

- Before creating a pull request, to verify compliance posture of infrastructure code
- As part of a periodic compliance review cycle
- When onboarding new infrastructure to assess its compliance baseline
- In mono-repos, to assess individual projects independently

## When Not to Use

- Do not execute the assessment instructions directly in the main conversation — the entire purpose of this command is to dispatch to a sub-agent via the Task tool
- Not suitable for non-infrastructure projects that have no cloud resources to assess
- If you need a manual, interactive compliance review with user input at each phase, this automated command is not the right choice

## Related Commands and Skills

- The instructions file at `.claude/compliance-auto-assess-instructions.md` contains the full assessment logic and is the authoritative reference for what the sub-agent executes.
