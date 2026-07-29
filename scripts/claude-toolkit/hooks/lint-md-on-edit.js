#!/usr/bin/env node
// PostToolUse hook (matcher: Edit|Write) — auto-fix markdown on the edited file.
// Runs `markdownlint-cli2 --fix` only when the touched file is .md, so edit-time
// formatting matches the repo's pre-commit markdownlint hook (fewer autofix cycles).
// Non-blocking and silent: never fails a tool call.
let input = '';
process.stdin.on('data', (d) => (input += d));
process.stdin.on('end', () => {
  let fp = '';
  try {
    const p = JSON.parse(input);
    fp = (p.tool_input && (p.tool_input.file_path || p.tool_input.path)) || '';
  } catch {
    process.exit(0);
  }
  if (!/\.(md|markdown)$/i.test(fp)) process.exit(0);
  // Resolve to an absolute path so a leading '-' can never be parsed as a flag
  // by markdownlint-cli2. (Edit/Write paths are already absolute; this is belt-and-suspenders.)
  const abs = require('path').resolve(fp);
  try {
    require('child_process').spawnSync('markdownlint-cli2', ['--fix', abs], { stdio: 'ignore' });
  } catch {
    /* tool missing — do not block the edit */
  }
  process.exit(0);
});
