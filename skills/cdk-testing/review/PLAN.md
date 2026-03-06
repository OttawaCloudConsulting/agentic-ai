# Implementation Plan: cdk-testing

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | SKILL.md | Add staging/production negative trigger to description frontmatter | P1 |
| 2 | SKILL.md | Remove Gate 2 WARNING block (duplicate of Critical Rules line 18) | P1 |
| 3 | SKILL.md | Replace trivial Prerequisites bullets with concrete project structure check | P2 |
| 4 | SKILL.md | Add git-secrets auto-skip note to Failure Handling section | P2 |

Note: Change 5 from FEEDBACK.md (moving `review/` out of the skill bundle) is a repo-level file operation, not an edit to SKILL.md. It is out of scope for this plan and should be handled as a separate task.

---

## Detailed Changes

### SKILL.md

#### Change 1 — Add staging/production negative trigger to description [P1]

**Location**: Line 3, frontmatter `description` field — end of sentence beginning "Do NOT use for..."

**Current**:
```
Do NOT use for CDK synth-only workflows, Python CDK projects, or non-CDK TypeScript testing.
```

**Replace with**:
```
Do NOT use for CDK synth-only workflows, Python CDK projects, non-CDK TypeScript testing, or staging/production deployments.
```

**Reason**: Closes the triggering boundary gap — a user who asks "deploy CDK to staging" could still activate the skill; the negative trigger prevents this at the description layer before the body's Critical Rules are ever loaded.

---

#### Change 2 — Remove Gate 2 WARNING block [P1]

**Location**: Lines 70-72, Gate 2 section

**Current**:
```
**WARNING:** The `--require-approval never` flag bypasses CloudFormation change review. Use this only for dev/sandbox environments. For staging or production, remove the flag or set `--require-approval broadening`.

```bash
npx cdk deploy --all --profile dev-account --require-approval never
```

**Replace with** (WARNING block removed; command block and pass/failure criteria unchanged):
```
```bash
npx cdk deploy --all --profile dev-account --require-approval never
```

**Reason**: The WARNING duplicates Critical Rules line 18 ("Dev environment only: The CDK deploy step uses `--require-approval never`. Never use this against production or shared environments."); two copies with slightly different wording create a maintenance risk and add context bloat with no new information.

---

#### Change 3 — Replace trivial Prerequisites bullets with project structure check [P2]

**Location**: Lines 22-27, Prerequisites section

**Current**:
```
Before running, ensure:

- Feature code and tests are complete
- You know which feature you are completing

Adapt the items below to your project's conventions. The defaults reference a `progress.txt` tracking file and `X.Y` feature numbering scheme. Replace these with whatever tracking mechanism your project uses.
```

**Replace with**:
```
Before running, confirm:

- `cdk.json` exists at the project root
- `package.json` exists at the project root and defines `build`, `test`, and (optionally) `format:check` and `lint` scripts

Adapt the commit workflow references to your project's conventions. The defaults reference a `progress.txt` tracking file and `X.Y` feature numbering scheme. Replace these with whatever tracking mechanism your project uses.
```

**Reason**: The original bullets ("Feature code is complete", "You know which feature you are completing") state things any developer already knows; replacing them with concrete file checks gives Claude something actionable to verify before running the pipeline.

---

#### Change 4 — Add git-secrets auto-skip note to Failure Handling [P2]

**Location**: Lines 107-112, Failure Handling section — insert after the first bullet

**Current**:
```
- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **npm audit findings:** Reported as warnings. Review with `npm audit`.
```

**Replace with**:
```
- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **git-secrets not installed:** Secrets scanning is skipped automatically; the pipeline continues without it. If secrets scanning is required, install git-secrets before running.
- **npm audit findings:** Reported as warnings. Review with `npm audit`.
```

**Reason**: The script silently skips git-secrets when it is not installed; a developer who relies on secrets scanning coverage would not notice it was skipped without this explicit callout in the skill.

---

## Implementation Order

1. Change 2 (remove Gate 2 WARNING) — no dependencies; simplest edit, reduces content before other edits are applied.
2. Change 1 (add negative trigger to description) — frontmatter edit; independent of body changes.
3. Change 3 (replace Prerequisites bullets) — body edit; independent of other body changes.
4. Change 4 (add git-secrets auto-skip to Failure Handling) — body edit; independent of other changes, applied last as it is lowest priority.

---

## Verification

After applying changes:

- [ ] Frontmatter `description` ends with "...or staging/production deployments." and remains under 1024 characters
- [ ] Gate 2 section contains no WARNING block; deploy command and pass/failure criteria are intact
- [ ] Prerequisites section contains no mention of "Feature code and tests are complete" or "You know which feature you are completing"
- [ ] Prerequisites section references `cdk.json` and `package.json` as concrete checks
- [ ] Failure Handling section contains a bullet for "git-secrets not installed" between the critical-step and npm-audit bullets
- [ ] Critical Rules line 18 (dev environment only) is unchanged
- [ ] Total line count remains well under 500 lines
