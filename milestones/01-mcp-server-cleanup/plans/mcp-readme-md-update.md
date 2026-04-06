# Feature Plan: mcp/README.md Update

**Milestone:** 01 - MCP Server Cleanup
**Feature:** 01.2: mcp/README.md Update
**Status:** Complete
**Date:** 2026-04-06

## Summary

Update the user-facing pattern reference in `mcp/README.md` to remove `awslabs-code-doc-gen-mcp-server` from the DOCUMENTATION pattern entry, update the TERRAFORM pattern entry to reference only HashiCorp's `terraform-mcp-server`, add a deprecation/migration notice for users who previously installed the deprecated servers, and update the prerequisites table to remove the stale Terraform (AWS) uvx reference. All changes already exist as unstaged working-directory edits — this feature's build task is to verify correctness and commit.

## Acceptance Criteria

- DOCUMENTATION pattern table entry does not list `awslabs-code-doc-gen-mcp-server`
- TERRAFORM pattern table entry references `terraform-mcp-server` (HashiCorp official) only
- A migration note or deprecation notice tells users how to remove the old servers (`claude mcp remove awslabs-code-doc-gen-mcp-server` and/or `claude mcp remove awslabs-terraform-mcp-server`)
- No other pattern entries are modified
- Prerequisites table no longer lists Terraform (AWS) under `uvx`
- `bash cicd/lint-markdown.sh` passes on `mcp/README.md` (zero errors/warnings)

## Approach

All edits are already applied in the working directory. The approach is:

1. **Read and verify** the changed sections against acceptance criteria — no code writes needed
2. **Run markdown lint** via `cicd/lint-markdown.sh` to confirm zero errors/warnings
3. **Confirm no other pattern entries changed** — grep for unchanged patterns (AWS, CDK, ARCHITECTURE, etc.) to verify no collateral edits
4. **Commit** the verified working-directory changes

Changes made (per git diff):
- Pattern overview table: TERRAFORM row updated ("HashiCorp Terraform, AWS Terraform" → "HashiCorp Terraform"); DOCUMENTATION row updated ("AWS docs, code doc gen, Context7" → "AWS docs, Context7")
- Deprecation blockquote added after the composability note, instructing users to run `claude mcp remove` for each deprecated server
- Prerequisites table: `uvx` row updated to remove "Terraform (AWS)" from the "Required By" list

## Sub-Features

- [x] **SF-1: Verify and commit README changes** -- Run markdown lint, confirm no collateral pattern changes, verify deprecation notice content, then stage and commit `mcp/README.md`

## Interface Contracts

No programmatic interface. User-facing markdown table columns are:

```
| Pattern | Servers included | Use case |
```

Deprecation notice format (blockquote):
```
> **Deprecated servers:** `awslabs-code-doc-gen-mcp-server` has been removed...
> `awslabs-terraform-mcp-server` has been replaced... `claude mcp remove <name>`
```

## Edge Cases

- **Users on old installs:** Deprecation notice provides explicit removal commands. No auto-removal behavior.
- **Markdown lint strictness:** `cicd/lint-markdown.sh` uses markdownlint-cli2. Blockquote syntax and table formatting must comply with configured rules.
- **Collateral damage:** Other pattern rows (AWS, CDK, ARCHITECTURE, SECURITY, KUBERNETES, CROSSPLANE, PRICING, GIT, GITHUB, SERVERLESS, NOTEBOOKLM) must remain unchanged.

## Test Command

```bash
bash cicd/lint-markdown.sh mcp/README.md
```

## Test Strategy

`cicd/lint-markdown.sh` is the primary automated check. Manual spot-checks:
- Read TERRAFORM and DOCUMENTATION rows in the pattern table — confirm correct values
- Confirm deprecation blockquote is present and includes both deprecated server names with removal commands
- `grep "awslabs-code-doc-gen-mcp-server\|awslabs-terraform-mcp-server" mcp/README.md` — must return only the deprecation notice lines (removal instructions), not any pattern table entries

## Documentation

This feature IS documentation. No additional files to create or update.

## Files to Create/Modify

| File | Action | Changes |
|------|--------|---------|
| `mcp/README.md` | Modify | Pattern table rows for TERRAFORM and DOCUMENTATION updated; deprecation notice added; prerequisites table updated |

## Dependencies

Feature 01.1 (install_mcp.sh Script Updates) — logically prior since docs describe what the script does, but the changes are independent and can be committed in any order.

## Architectural Deviations

(none)
