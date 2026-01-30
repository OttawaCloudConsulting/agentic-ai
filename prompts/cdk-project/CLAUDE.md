# Project Rules — cdk-zabbix

## Development Process

This project follows a strict **Feature > Test > Complete > Next Feature** workflow.
All features are tracked in `progress.txt`. Read it before starting any work.

### Rules

1. **Read `progress.txt` before doing anything.** Identify the current in-progress `[~]` feature or the next pending `[ ]` feature. Do NOT work on anything else.

2. **One feature at a time.** Never start the next feature until the current one is marked `[x]`.

3. **Every feature must have NEW assertion tests written before it can be marked complete.**
   - For CDK stacks/constructs: write assertion tests that verify the synthesized CloudFormation template contains the expected resources and properties.
   - For Lambda handlers: write unit tests with mocked dependencies.
   - For config changes: write tests that verify the new configuration is read correctly.
   - Tests go in the `test/` directory, matching the source file structure.
   - "Tests pass" is not sufficient — new tests must be written that specifically verify the feature's behavior.
   - Exception: pure refactoring (renames, moves) where existing tests cover the behavior — update tests to use new names/paths but no new assertions needed.

4. **Prove the feature works.** Run `/test-cdk` to execute all validation gates (validation script, CDK deploy, commit). Do NOT mark a feature `[x]` until `/test-cdk` passes. The `/test-cdk` skill handles validation, deployment, documentation, changelog, and git commit.

5. **Start a feature with `/start-feature`.** It reads `progress.txt`, identifies the next feature, marks it `[~]`, reads `prd.md` for requirements, and reports what needs to be built. Add any decisions or issues to NOTES in progress.txt as you work.

6. **Do NOT refactor, improve, or work on anything outside the current feature.** If you notice something that needs attention later, add it to NOTES in progress.txt under the relevant feature.

## AWS Environment

- **AWS CLI profile:** `developer-account`
- **All CDK and AWS commands must use `--profile developer-account`**
- **Region:** `ca-central-1` (set in cdk.json context, not via CLI flag)
- **Deploy target:** dev account only

## Tech Stack

- AWS CDK v2 (TypeScript)
- Runtime: Node.js
- Testing: Jest with `aws-cdk-lib/assertions` (Template.fromStack)
- Region: ca-central-1
- All architecture decisions are in `prd.md` — follow them exactly

## Test Expectations

### What counts as a real test

- Every CDK stack and construct must have assertion tests
- Use `Template.fromStack(stack)` to test synthesized output
- Test resource existence, properties, counts — not just that synth succeeds
- Snapshot tests are written in Phase 7, not during individual features
- `npm test` must pass with zero failures before any feature is marked complete

### Test validity rules

1. **package.json `scripts.test` must run jest** — never `echo`, `exit 0`, or `true`. The script must be: `jest` (with optional flags like `--verbose` or `--passWithNoTests` only during Phase 1 scaffolding).

2. **No empty tests.** Every `test()` or `it()` block must contain at least one `expect()` call with a meaningful matcher. `expect(true).toBe(true)` is not a valid test.

3. **CDK tests must use `aws-cdk-lib/assertions`.** Valid assertion methods:
   - `template.hasResourceProperties(...)` — resource exists with specific properties
   - `template.hasResource(...)` — resource exists with specific configuration
   - `template.resourceCountIs(...)` — exact number of a resource type
   - `template.hasOutput(...)` — stack output exists
   - `template.findResources(...)` — with follow-up assertions on results
   Just calling `Template.fromStack(stack)` without any assertions proves nothing.

4. **Test names must describe what they verify.** Use the pattern: `'creates/enables/configures [thing] with [property]'`. A test named `'works'` or `'test1'` is not acceptable.

5. **Run `npm test -- --verbose` to show individual test names.** This makes it visible whether tests are meaningful or hollow.

## Defensive Coding

Follow the defensive coding protocol when writing code, debugging, investigating issues, or performing multi-step tasks. The protocol is loaded automatically when relevant. Key principle: **when anything fails, STOP → THINK → REPORT → WAIT.**

## Git Discipline

`git add .` is forbidden. Add files individually. Know what you're committing.

## Terminal Discipline

**RULE:** Pipe JSON output to `jq` to prevent terminal hangs.

```bash
command --output json | jq
```

**RULE:** Never set executable permissions on shell scripts.

`chmod +x script.sh` is a security violation.

Execute scripts explicitly via interpreter:
```bash
bash ./script.sh
sh ./script.sh
```

## Skills

Development workflow and session management are handled by skills in `.claude/commands/`.

### Development Workflow

| Skill | When to use |
|---|---|
| `/start-feature` | Begin the next feature (reads progress.txt + prd.md, marks `[~]`) |
| `/test-cdk` | Complete a feature (validation, deploy, docs, changelog, commit) |
| `/update-docs` | Refresh README, ARCHITECTURE, TESTING after features accumulate |

### Session Lifecycle

| Skill | When to use |
|---|---|
| `/catchup` | Start of session — read project state from last handoff |
| `/handoff` | End of session — save state before `/clear` or closing terminal |
| `/investigate` | Debug unknowns — structured facts/theories/tests in `agents/investigations/` |

### Always Active

| Skill | Purpose |
|---|---|
| `defensive-protocol` | Loaded automatically when writing code, debugging, or investigating |

**Persistent learnings:** Use `/memory` to add permanent corrections to CLAUDE.md.

## Project Directories

- **`docs/`** — Project documentation (ARCHITECTURE, TESTING, FEATURE_*.md)
- **`agents/`** — Working memory for session state and investigations (not project docs)
  - `agents/memory/handoff.md` — last session's end state (written by `/handoff`, read by `/catchup`)
  - `agents/investigations/` — structured debugging files (created by `/investigate`)

## Process Constraints

- Never use `taskkill` on `node.exe` — Claude Code runs on Node
- Reference the user naturally (no special terminology required)
- When confused: stop, think, present plan, get signoff
