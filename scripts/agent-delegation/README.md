# Agent Delegation Installer

Installs the `agent-delegation` rule and its companion `UserPromptSubmit` hook into a target Claude Code project. The hook is the load-bearing piece — it injects a one-line reminder when the user's prompt matches bulk-work keywords, forcing the agent to consult the delegation matrix before its first tool call. Without the hook, the rule is passive context and consultation is unreliable.

---

## Quick Start

```bash
bash scripts/agent-delegation/install.sh <target-repo-path>
```

The installer:

1. Copies `rules/agent-delegation.md` to `<target>/.claude/rules/agent-delegation.md` (added | updated | unchanged).
2. Merges a `UserPromptSubmit` hook into `<target>/.claude/settings.json` (added | already installed). Existing keys are preserved; the file is created with `{}` if missing.
3. Is idempotent — re-running does not duplicate the hook entry. Idempotency is keyed off the marker `# agent-delegation-hook v1` on the first line of the hook command.

Restart Claude Code in the target repo after install — settings are loaded once per session.

---

## Dependencies

- `jq` — required for safe JSON merging. Install with `brew install jq` (macOS) or `apt install jq` (Debian/Ubuntu). The installer exits with a clear error if `jq` is missing.

---

## Hook Behaviour

The installed hook reads the user's prompt from stdin (Claude Code delivers a JSON payload with `.prompt`), checks it case-insensitively against the keyword set `audit|categorize|review all|find every|across the docs|enumerate|inventory|sweep`, and on match emits a single reminder line. On no match it exits silently.

To change the keyword set, edit the heredoc in `install.sh`, bump the marker (`v1` → `v2`), then re-run the installer. The bumped marker forces a re-install even if a `v1` entry already exists. Editing the rule file does **not** affect the installed hook — the hook command is a static string captured at install time.

---

## Safety

- Validates that `<target>/.claude/settings.json` is valid JSON before merging — bails with a clear error if not.
- Uses `mktemp` + `trap` to ensure no stale `.tmp` files are left behind on partial writes or jq failures.
- Atomic `mv` of the merged settings file into place.
- No executable bit on the script (per repo convention) — always invoke with an explicit `bash` interpreter.

---

## Documentation

For the full rule, hook contract, manual install, verification commands, uninstall procedure, and troubleshooting, see [docs/rules/agent-delegation.md](../../docs/rules/agent-delegation.md).

For the rule source (what gets copied to consumers), see [rules/agent-delegation.md](../../rules/agent-delegation.md).
