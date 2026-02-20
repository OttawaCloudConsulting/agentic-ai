# Start Feature

**Source:** `commands/start-feature.md`
**Command:** `/start-feature`
**Activation:** Manual — invoked via slash command or trigger phrase matching (e.g., "start the next feature," "begin the next feature")

## Description

Starts work on the next feature in the project roadmap by reading `progress.txt` to identify what to work on, loading requirements from `prd.md`, marking the feature as in progress, and presenting a summary. This is a context-setting command — it does not begin implementation, only prepares the workspace and reports what needs to be built.

## Usage

```
/start-feature
```

No arguments. The command determines which feature to start from `progress.txt` automatically.

## Inputs

| Input | Source | Required |
|---|---|---|
| Feature status | `progress.txt` | Yes |
| Feature requirements and acceptance criteria | `prd.md` | Yes |
| Current codebase structure | File system scan | Yes (for determining affected files) |

## Outputs

| Output | Location | Description |
|---|---|---|
| Updated progress marker | `progress.txt` (in-place edit) | Target feature status changed from `[ ]` to `[~]` with start date in NOTES |
| Feature summary report | Console (stdout) | Requirements, likely affected files, and dependencies for the target feature |

## Workflow

### Step 1 — Read progress.txt

Reads `progress.txt` and identifies:

- Any feature currently marked `[~]` (in progress) — if found, resumes that feature instead of starting a new one.
- The next feature marked `[ ]` (pending) — selected if no `[~]` feature exists.

If all features are marked `[x]` (complete), reports that all planned features are complete and stops.

### Step 2 — Read requirements

Reads `prd.md` and locates the section for the identified feature. Extracts:

- What needs to be built
- Acceptance criteria
- Any dependencies on other features

### Step 3 — Mark feature as in progress

Updates `progress.txt`:

- Changes the feature status from `[ ]` to `[~]`
- Adds start date to NOTES (format: `Started YYYY-MM-DD`)

### Step 4 — Report

Presents a summary to the user:

```
STARTING: Feature X.Y — [Title from progress.txt]

REQUIREMENTS:
- [Key requirement 1]
- [Key requirement 2]
- [...]

FILES LIKELY AFFECTED:
- [Based on requirements and existing codebase structure]

DEPENDENCIES:
- [Any cross-stack or cross-feature dependencies]

Ready to begin implementation.
```

## When to Use

- After running `/create-prd` to begin implementing the first feature
- At the start of a session after `/catchup` when ready to continue building
- When the user explicitly asks to start or begin the next feature
- When a previous feature has been completed and it is time to move to the next one

## When Not to Use

- Do not invoke proactively — only when the user explicitly requests it
- If another feature is already marked `[~]` (in progress), the command will resume it rather than start a new one; if you need to skip or reorder features, update `progress.txt` manually first
- If there is no `progress.txt` or `prd.md` — run `/create-prd` first to generate them
- Not for resuming context — use `/catchup` to understand current state before starting

## Related Commands and Skills

- `/create-prd` — Creates the `prd.md` and `progress.txt` that this command reads from. Must be run first if these files do not exist.
- `/catchup` — Reads project state to orient at the start of a session. Often invoked before `/start-feature`.
- `/handoff` — Captures the in-progress feature state at the end of a session.
- `/update-docs` — Refreshes documentation after features have been completed.
