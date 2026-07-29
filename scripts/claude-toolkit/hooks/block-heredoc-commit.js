#!/usr/bin/env node
// PreToolUse hook (matcher: Bash) — deny `git commit` commands that use heredocs
// or multi-line -m arguments, the root cause of the recurring commit failures.
// Redirects the model to the file-based flow: git commit -F <file> (or `gcommit`).
//
// Install in .claude/settings.json (project-relative, matches the checked-in config):
//   "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [
//     { "type": "command", "command": "node \"$CLAUDE_PROJECT_DIR/.claude/hooks/block-heredoc-commit.js\"", "timeout": 5 }
//   ] } ] }

let input = '';
process.stdin.on('data', (d) => (input += d));
process.stdin.on('end', () => {
  let cmd = '';
  try {
    const payload = JSON.parse(input);
    cmd = (payload.tool_input && payload.tool_input.command) || '';
  } catch {
    process.exit(0); // unparseable — do not block
  }

  const isCommit = /git\s+([^\n;|&]*\s)?commit/.test(cmd);
  if (!isCommit) process.exit(0);

  // Covers `<<EOF`, `<<-EOF`, `<< EOF`, `<<'EOF'`, `<<"EOF"`, `<<\EOF` and
  // digit-leading delimiters like `<<1EOF`. Excludes `<<<` (herestring) and
  // bare-numeric `<< 2` (left-shift) so arithmetic in a commit command is not
  // mistaken for a heredoc.
  const usesHeredoc = /(?<!<)<<(?!<)-?\s*\\?['"]?(?:[A-Za-z_]|[0-9]+[A-Za-z_])/.test(cmd);
  const multilineDashM = /(^|\s)-m\b/.test(cmd) && cmd.includes('\n');

  if (usesHeredoc || multilineDashM) {
    console.log(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason:
            'Heredoc / multi-line -m commit messages break quoting (recurring failure). ' +
            'Write the message to a file and run: git commit -F <file> ' +
            '(or use the gcommit helper).',
        },
      })
    );
  }
  process.exit(0);
});
