# Feedback: terraform-testing

**Date**: 2026-03-06
**Reviewer**: skill-creator review protocol
**Reviewed path**: skills/terraform-testing/

---

## Critique Review — Internal Quality Standards

### Findings

- **Conciseness — Lines 18–19 (Prerequisites stub):** The section reads "Before running, ensure Terraform code is ready for validation." This is content-free filler. It adds no information Claude or the user doesn't already have. Remove it entirely or replace with actual prerequisites (e.g., Terraform installed, AWS credentials configured, AWS CLI present for deploy modes).
- **Conciseness — Lines 102–113 (Output Format section):** The sample output block duplicates what the script itself prints. This is borderline justified as orientation for the agent, but if the script already produces this output reliably, documenting it here is redundant. Consider removing or reducing to a one-line description.
- **Conciseness — Lines 115–127 (Example section):** The example is useful (trigger phrase → action → result), but the numbered steps largely repeat what is already stated in the Workflow section (lines 22–26). The value-add is showing the exact plan summary output format; the surrounding prose could be trimmed.
- **Degrees of Freedom — No issues.** CLI invocations are exact bash commands (low freedom, appropriate for a fragile sequential pipeline). Configuration and failure handling use medium-freedom prose. Specificity is well-matched to task fragility.
- **Progressive Disclosure — No issues.** Frontmatter is ~70 words. SKILL.md body is 128 lines — well within the 500-line limit. No references/ directory, which is appropriate given the skill's scope. No content is split incorrectly.
- **Structure — Lines 18–19 (Prerequisites):** Stub section disrupts the logical flow between the intro paragraph and the Workflow section. The section header signals content that isn't there.
- **Structure — Section order is otherwise sound:** Critical Rules appear at the top. Sections progress logically from setup through workflow through failure handling through output.
- **Forbidden files — No issues.** No README.md, CHANGELOG.md, LICENSE.txt, or INSTALLATION_GUIDE.md present.
- **Resource Appropriateness — No issues.** Deterministic pipeline logic lives in `scripts/test-terraform.sh`, which is exactly the right resource type for a fragile, sequential operation. No references/ directory is needed given the skill's focused scope.

### What Works Well

- SKILL.md body is lean at 128 lines — well under the 500-line ceiling, leaving ample headroom for future additions without triggering a split.
- Critical Rules section at the top with imperative form enforces the most important constraints before any workflow details.
- The pipeline table (lines 77–88) efficiently communicates step order, tooling, criticality, and purpose in a compact format — the right level of abstraction for a sequential workflow.
- Script-based execution for the deterministic pipeline is the correct low-freedom pattern. SKILL.md remains a navigation and configuration guide; the script handles execution.
- Configuration table with precedence order (`CLI > env > config file > defaults`) prevents misconfiguration and is high-value information not present elsewhere.

---

## Red-Team Review — Anthropic Best Practices

### Findings

- **Trigger Quality — OpenTofu gap:** The description does not mention OpenTofu (`tofu` CLI), which is the open-source Terraform fork with a functionally identical interface. Users asking to "test my opentofu config", "validate my tofu files", or "run tofu checks" would not trigger this skill despite OpenTofu being fully supported by the underlying pipeline. This is a growing use case. The negative trigger list is accurate but narrow ("CloudFormation, Pulumi, CDK") — OpenTofu should be added to the positive trigger side. This is a should-fix: the skill works but silently misses a meaningful user segment.
- **Instruction Quality — No `--help` or script-not-found handling:** Line 29 instructs the agent to run the script at `.claude/skills/terraform-testing/scripts/test-terraform.sh`. There is no guidance on what to do if the script is not present at that path (e.g., skill was installed without the scripts/ subdirectory, or path has been customized). A one-line fallback note would prevent silent failure.
- **Error Handling — `terraform init` connectivity failure not documented:** Line 93 states "Script exits immediately. Fix the error and re-run." for critical step failures. Step 3 (`terraform init`) can fail for reasons unrelated to the code itself — provider registry connectivity issues, corporate proxy environments, local mirror configurations. No guidance exists for this failure class, which is common in enterprise contexts.
- **Error Handling — Script path assumption:** The skill hardcodes `.claude/skills/terraform-testing/scripts/test-terraform.sh` as the invocation path. This is correct for Claude Code's default skill installation path, but there is no mention of what happens when a user has installed the skill to a custom path or is running from a different working directory.
- **Naming — No issues.** Folder name is `terraform-testing` (kebab-case, lowercase, no spaces, no underscores). `name` field matches exactly. `SKILL.md` is correctly cased. No forbidden prefixes.
- **Frontmatter — No issues.** Both required fields present and valid. No XML angle brackets. Description is 441 characters — within the 1024-character limit. YAML delimiters are correct.
- **Trigger Quality — Existing triggers are strong:** Explicit phrases ("test terraform", "validate my terraform", "/test-terraform"), file type mentions (.tf, .tfvars), and negative triggers (CloudFormation, Pulumi, CDK) create a precise description with 100% trigger accuracy across 20 test cases (see BENCHMARK.md).
- **Progressive Disclosure — No issues.** Three-tier model is correctly implemented. Frontmatter handles tier 1; SKILL.md body handles tier 2; scripts/ handles deterministic execution without being inlined into context.
- **File Structure — No issues.** No forbidden files present. Directory structure is `SKILL.md` + `scripts/` + `review/`, which is valid.
- **`compatibility` field — Absent.** The skill has meaningful environment requirements (Terraform CLI, AWS credentials for deploy modes, OS compatibility). The `compatibility` optional field is not used. This is a nice-to-have — the body partially covers this through the script's auto-detection note (line 89), but a `compatibility` field would surface the requirement at the metadata tier.

### What Works Well

- Description includes both WHAT (validation, security scanning, planning, deployment testing for .tf and .tfvars) and WHEN (specific trigger phrases plus negative triggers) — fully satisfying the trigger quality checklist.
- Negative triggers are accurate and well-targeted: CloudFormation, Pulumi, CDK are the three most common false-positive candidates for a Terraform testing skill.
- Instruction quality is high throughout: exact bash invocations, a configuration table with precedence rules, inline suppression syntax for both checkov and trivy, and a worked example. All steps are actionable without guesswork.
- Critical instructions are at the top under `## Critical Rules` — the correct placement per best practices.
- At least one concrete example is present (lines 115–127) showing trigger phrase → actions → result.

---

## Compiled Findings

### Critical Issues

None. No blockers that would prevent publishing or cause skill upload failure.

### Improvements

1. **Remove or replace the Prerequisites stub (lines 18–19).** Either delete the section or populate it with actual prerequisites: Terraform CLI installed, AWS credentials configured (for deploy modes), Git installed (for git-secrets step). A stub section signals content that isn't there and disrupts flow.
2. **Add OpenTofu to the trigger description.** Users of the `tofu` CLI are a growing segment running an identical workflow. The description should include trigger phrases like "test opentofu", "validate my tofu", and mention OpenTofu alongside Terraform in the what-it-does opening. Update the negative trigger list if needed to preserve precision.
3. **Add script-not-found handling guidance.** One line noting what to do if the script is not at the expected path (e.g., "If the script is not present, verify the skill was installed with its scripts/ directory, then re-run installation") prevents a silent failure class.
4. **Add `terraform init` connectivity failure guidance.** A brief note in the Failure Handling section covering provider registry connectivity issues, proxy environments, and local mirror alternatives covers a common enterprise failure class currently undocumented.

### Minor Notes

- **Output Format section (lines 102–113):** The sample output block is useful for agent orientation but partially redundant given the script produces the same output. Could be reduced to a one-line description if token economy is a priority.
- **Example section (lines 115–127):** Steps 1 and 4 duplicate content from the Workflow section. Trimming to just the script invocation and the output result would remove the redundancy while keeping the example value.
- **`compatibility` optional field:** Adding `compatibility: "Requires Terraform CLI. AWS credentials required for --deploy and --deploy-destroy modes. macOS, Debian, and RHEL supported."` would surface environment requirements at the metadata tier without any body changes.

---

## Prioritized Action Items

1. Replace the Prerequisites stub (lines 18–19) with actual prerequisite list, or remove the section entirely — it is content-free and signals a gap.
2. Add OpenTofu / `tofu` CLI trigger phrases to the frontmatter description — this is the most significant coverage gap for a skill that otherwise has 100% trigger accuracy.
3. Add script-not-found fallback note to the Running the Script section — one line prevents a silent failure class.
4. Add `terraform init` connectivity failure note to the Failure Handling section — covers a common enterprise failure currently undocumented.
5. Add `compatibility` optional field to frontmatter — low-effort, surfaces environment requirements at the metadata tier.
6. Trim the Example section to remove duplication with the Workflow section — minor polish.
