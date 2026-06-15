# Rules Reference

Rules are always-on behavioral guidelines loaded automatically via `.claude/rules/`. They are not commands and cannot be invoked by the user. They provide persistent context that shapes how the agent writes code, handles failures, and makes decisions.

## Quick Reference

| Rule | File | Purpose | Details |
|---|---|---|---|
| Defensive Protocol v2 — Anti-Slop | `rules/defensive-protocol-v2-anti-slop.md` | Core guardrails: stop on failure, verification cadence, autonomy boundaries | [View](rules/defensive-protocol-v2-anti-slop.md) |
| Defensive Protocol v2 — Epistemology | `rules/defensive-protocol-v2-epistemology.md` | Reasoning framework: tiered prediction protocol, investigation methodology | [View](rules/defensive-protocol-v2-epistemology.md) |
| Defensive Protocol v2 — Session Management | `rules/defensive-protocol-v2-session-management.md` | Session continuity: checkpoints, handoffs, context window awareness | [View](rules/defensive-protocol-v2-session-management.md) |
| CDK Best Practices | `rules/cdk-best-practices.md` | AWS CDK guidelines: construct design, security, testing, deployment safety | [View](rules/cdk-best-practices.md) |
| Terraform Best Practices | `rules/terraform-best-practices.md` | Terraform guidelines: state management, module design, security, naming | [View](rules/terraform-best-practices.md) |
| Crossplane v1 Best Practices | `rules/crossplane-v1-best-practices.md` | Crossplane/Upbound guidelines: XR design, compositions, managed resources | [View](rules/crossplane-v1-best-practices.md) |
| Crossplane v2 Best Practices | `rules/crossplane-v2-best-practices.md` | Crossplane v2 specifics: namespaced XRs, spec.crossplane, Configuration packages | [View](rules/crossplane-v2-best-practices.md) |
| Kubernetes Best Practices | `rules/kubernetes-best-practices.md` | Kubernetes guidelines: resource management, security, RBAC, networking | [View](rules/kubernetes-best-practices.md) |
| Agent Delegation | `rules/agent-delegation.md` | Multi-agent delegation matrix with `UserPromptSubmit` hook to force consultation before bulk tasks | [View](rules/agent-delegation.md) |

## How Rules Work

- Rules live in `rules/` at the repository root (drop-in source)
- Consumers copy them to `.claude/rules/` in their target project
- Claude Code loads all `.md` files in `.claude/rules/` automatically on every conversation
- Rules have no YAML frontmatter — they are pure content
- One concern per file
- Some rules ship with companion hooks/scripts; install via the installer in `scripts/` rather than a bare `cp`

### Rules vs Skills vs Commands

| | Rules | Skills | Commands |
|---|---|---|---|
| Location | `.claude/rules/` | `.claude/skills/<name>/` | `.claude/commands/` |
| Activation | Automatic (always loaded) | Manual (`/skill-name`) | Manual (`/command-name`) |
| Purpose | Behavioral guidelines | Action workflows with supporting assets | Single-file action workflows |
| Frontmatter | None | Required (`name`, `description`) | Required (`name`, `description`) |
| User-facing | No | Yes | Yes |

### Defensive Protocol Evolution

v2 is the current generation, split into three independent focused files:

- **Anti-Slop** — critical guardrails (stop on failure, verify, autonomy checks)
- **Epistemology** — reasoning framework (prediction protocol, investigation methodology)
- **Session Management** — continuity (checkpoints, handoffs, context awareness)

v1 (`docs/rules/defensive-protocol.md`) was a single comprehensive file. It has been retired; the source file (`rules/defensive-protocol.md`) was deleted in commit `9e0a6e6`. The description is preserved at `docs/rules/defensive-protocol.md` for historical reference only.

Consumers should load all three v2 files.

## Consuming Rules

Copy rule files from `rules/` into `.claude/rules/` in the target repository:

```bash
# Copy individual rules
cp rules/defensive-protocol-v2-anti-slop.md         <target-repo>/.claude/rules/
cp rules/defensive-protocol-v2-epistemology.md       <target-repo>/.claude/rules/
cp rules/defensive-protocol-v2-session-management.md <target-repo>/.claude/rules/
cp rules/cdk-best-practices.md                       <target-repo>/.claude/rules/
cp rules/terraform-best-practices.md                 <target-repo>/.claude/rules/
cp rules/crossplane-v1-best-practices.md             <target-repo>/.claude/rules/
cp rules/crossplane-v2-best-practices.md             <target-repo>/.claude/rules/
cp rules/kubernetes-best-practices.md                <target-repo>/.claude/rules/
cp rules/agent-delegation.md                         <target-repo>/.claude/rules/   # or use installer (below)
```

**Note on the Defensive Protocol v2 trio:** The three v2 rules ship with a hook enforcement layer — `chmod +x` hard-block, destructive-command gate, native-tool overwrite reminder, and a post-failure reminder — wired into `.claude/settings.json`. The bare `cp` above installs the rule *text* only, leaving the guardrails self-applied with no hooks. To install the rules **and** the enforcing hooks, use the installer:

```bash
bash scripts/defensive-protocol/install.sh <target-repo-path>
```

It copies the trio and the hook scripts, merges the hook entries idempotently, appends the CLAUDE.md Active-Rules block, and creates the `agents/` state directories. See [scripts/defensive-protocol/README.md](scripts/defensive-protocol/README.md) and [SCRIPTS.md](SCRIPTS.md#defensive-protocol-v2).

**Note on `agent-delegation.md`:** This rule depends on a `UserPromptSubmit` hook in `.claude/settings.json` to be reliably consulted (see § Setup / Installation in the rule file). Prefer the installer over a bare `cp`:

```bash
bash scripts/agent-delegation/install.sh <target-repo-path>
```

The installer copies the rule and merges the hook idempotently.

Rules take effect immediately on the next Claude Code conversation in that repository.

### Choosing Rules

| Project Type | Recommended Rules |
|---|---|
| Any project | Defensive v2 (all 3) + `agent-delegation.md` (install via `scripts/agent-delegation/install.sh`) |
| AWS CDK projects | Defensive v2 (all 3) + `cdk-best-practices.md` |
| Terraform projects | Defensive v2 (all 3) + `terraform-best-practices.md` |
| Crossplane v1 projects | Defensive v2 (all 3) + `crossplane-v1-best-practices.md` + `kubernetes-best-practices.md` |
| Crossplane v2 projects | Defensive v2 (all 3) + `crossplane-v1-best-practices.md` + `crossplane-v2-best-practices.md` + `kubernetes-best-practices.md` |
| Kubernetes projects | Defensive v2 (all 3) + `kubernetes-best-practices.md` |
