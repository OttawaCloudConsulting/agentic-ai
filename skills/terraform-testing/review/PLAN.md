# Implementation Plan: terraform-testing

**Based on**: review/FEEDBACK.md
**Date**: 2026-03-06

---

## Change Summary

| # | File | Change | Priority |
|---|---|---|---|
| 1 | SKILL.md | Add `compatibility` field to frontmatter | P2 |
| 2 | SKILL.md | Add OpenTofu trigger phrases to frontmatter description | P1 |
| 3 | SKILL.md | Replace Prerequisites stub with actual prerequisites list | P1 |
| 4 | SKILL.md | Add script-not-found fallback note to Running the Script section | P1 |
| 5 | SKILL.md | Add `terraform init` connectivity failure note to Failure Handling | P1 |
| 6 | SKILL.md | Trim Example section to remove workflow duplication | P3 |
| 7 | SKILL.md | Reduce Output Format section to one-line description | P3 |

---

## Detailed Changes

### SKILL.md

#### Change 1 — Add `compatibility` field to frontmatter [P2]

**Location**: Lines 1–4 (frontmatter block)

**Current**:
```
---
name: terraform-testing
description: Run Terraform validation, security scanning, planning, and deployment testing for .tf and .tfvars files. Use when the user asks to test Terraform code, validate Terraform configurations, run Terraform checks, or deploy Terraform to a dev environment. Triggers on requests like "test terraform", "validate my terraform", "run terraform checks", "deploy terraform to dev", or "/test-terraform". Do NOT use for CloudFormation, Pulumi, CDK, or non-Terraform infrastructure code.
---
```

**Replace with**:
```
---
name: terraform-testing
description: Run Terraform (and OpenTofu) validation, security scanning, planning, and deployment testing for .tf and .tfvars files. Use when the user asks to test Terraform or OpenTofu code, validate Terraform configurations, run Terraform checks, deploy Terraform to a dev environment, or test tofu configs. Triggers on requests like "test terraform", "validate my terraform", "run terraform checks", "deploy terraform to dev", "/test-terraform", "test opentofu", "validate my tofu", or "run tofu checks". Do NOT use for CloudFormation, Pulumi, CDK, or non-Terraform infrastructure code.
compatibility: "Requires Terraform CLI or OpenTofu (tofu) CLI. AWS credentials required for --deploy and --deploy-destroy modes. macOS, Debian, and RHEL supported."
---
```

**Reason**: Adds OpenTofu trigger coverage (Change 2 combined here for atomicity) and surfaces environment requirements at the metadata tier via the optional `compatibility` field.

---

#### Change 2 — Replace Prerequisites stub with actual prerequisites [P1]

**Location**: Lines 17–19 (Prerequisites section)

**Current**:
```
## Prerequisites

Before running, ensure Terraform code is ready for validation.
```

**Replace with**:
```
## Prerequisites

- Terraform CLI (`terraform`) or OpenTofu CLI (`tofu`) installed and on `PATH`
- Git installed (required for git-secrets step)
- AWS credentials configured (required for `--deploy` and `--deploy-destroy` modes only)
```

**Reason**: The stub is content-free filler; actual prerequisites prevent silent failures and align the section with its header.

---

#### Change 3 — Add script-not-found fallback note to Running the Script section [P1]

**Location**: Lines 27–29 (Running the Script section, after the script path line)

**Current**:
```
## Running the Script

The script is bundled with this skill at `.claude/skills/terraform-testing/scripts/test-terraform.sh`.
```

**Replace with**:
```
## Running the Script

The script is bundled with this skill at `.claude/skills/terraform-testing/scripts/test-terraform.sh`.

If the script is not present at that path, the skill was likely installed without its `scripts/` directory. Re-install the skill bundle or verify the installation path matches your Claude Code skills directory.
```

**Reason**: Prevents silent failure when the script is missing; gives the agent a concrete resolution path instead of a confusing "file not found" error.

---

#### Change 4 — Add `terraform init` connectivity failure note to Failure Handling [P1]

**Location**: Lines 91–99 (Failure Handling section), after the existing critical step failure bullet

**Current**:
```
## Failure Handling

- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **Security scan findings:** Reported as warnings by default. Use `--soft-fail` to prevent blocking.
```

**Replace with**:
```
## Failure Handling

- **Critical step fails:** Script exits immediately. Fix the error and re-run.
- **`terraform init` connectivity failure:** If Step 3 fails with provider registry or download errors, the issue is network-level, not code-level. Check for corporate proxy requirements (`HTTPS_PROXY` env var), use a local provider mirror (`terraform init -plugin-dir`), or verify provider registry access. Re-run after resolving connectivity.
- **Security scan findings:** Reported as warnings by default. Use `--soft-fail` to prevent blocking.
```

**Reason**: `terraform init` failures from proxy/connectivity issues are common in enterprise environments and require different remediation than code errors — current guidance ("fix the error") is incorrect for this failure class.

---

#### Change 5 — Trim Example section to remove workflow duplication [P3]

**Location**: Lines 115–127 (Example section)

**Current**:
```
## Example

User says: "test my terraform"

1. Run the script in validate+plan mode:

   ```bash
   bash .claude/skills/terraform-testing/scripts/test-terraform.sh
   ```

2. Script executes steps 1-7 (git-secrets through terraform plan).
3. All steps pass. Output shows plan summary: `2 to add, 0 to change, 0 to destroy`.
4. Report results to user.
```

**Replace with**:
```
## Example

User says: "test my terraform"

```bash
bash .claude/skills/terraform-testing/scripts/test-terraform.sh
```

All steps pass. Output shows plan summary: `2 to add, 0 to change, 0 to destroy`. Report results to user.
```

**Reason**: Steps 1 and 4 duplicate the Workflow section; the example's unique value is showing the exact invocation and output format, which is preserved.

---

#### Change 6 — Reduce Output Format section to one-line description [P3]

**Location**: Lines 101–113 (Output Format section)

**Current**:
```
## Output Format

```text
Terraform Testing: PASS
  - git-secrets: passed
  - terraform fmt: passed
  - terraform init: passed
  - terraform validate: passed
  - tflint: passed (or skipped)
  - checkov: completed with warnings (or passed)
  Plan: 3 to add, 0 to change, 0 to destroy
  Apply: completed successfully
```
```

**Replace with**:
```
## Output Format

The script prints a per-step pass/fail summary followed by a plan summary line (`N to add, N to change, N to destroy`) and, if deployed, an apply status line.
```

**Reason**: The sample output block duplicates what the script already prints at runtime; a one-line description preserves agent orientation at lower token cost.

---

## Implementation Order

1. **Change 1 (frontmatter)** — frontmatter is the metadata anchor for the whole skill; update it first so OpenTofu triggers are live from the start.
2. **Change 2 (Prerequisites)** — standalone section replacement with no dependencies on other changes.
3. **Change 3 (script-not-found note)** — additive change to Running the Script section; no dependencies.
4. **Change 4 (`terraform init` connectivity note)** — additive change to Failure Handling; no dependencies.
5. **Change 5 (trim Example)** — reduction; verify Workflow section still covers the removed context before applying.
6. **Change 6 (trim Output Format)** — reduction; lowest risk, apply last.

---

## Verification

After applying changes:

- [ ] Frontmatter YAML is valid (no syntax errors, both `name` and `description` still present)
- [ ] `compatibility` field is on its own line within the frontmatter block
- [ ] OpenTofu trigger phrases appear in the description: "test opentofu", "validate my tofu", "run tofu checks"
- [ ] Prerequisites section lists three concrete items (Terraform/OpenTofu CLI, Git, AWS credentials)
- [ ] Script-not-found note appears directly after the script path line, before the Common Invocations block
- [ ] `terraform init` connectivity bullet appears in Failure Handling between the critical step bullet and the security scan bullet
- [ ] Example section no longer contains numbered steps 1 and 4 (workflow duplication removed)
- [ ] Output Format section no longer contains a fenced code block
- [ ] Total line count remains well under 500 lines
- [ ] Run `bash scripts/lint-markdown.sh skills/terraform-testing/SKILL.md` — zero errors
