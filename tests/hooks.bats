#!/usr/bin/env bats
# tests/hooks.bats — Feature 3.1/3.2 mechanical hook tests
# Run: bats tests/hooks.bats  (from project root)
# Requires: bats-core, jq

HOOKS_DIR="$BATS_TEST_DIRNAME/../scripts/defensive-protocol/hooks"
CHMOD_BLOCK="$HOOKS_DIR/chmod-block.sh"
HIGH_RISK="$HOOKS_DIR/high-risk-gate.sh"
PRE_WRITE="$HOOKS_DIR/pre-write.sh"

# ── chmod-block.sh ────────────────────────────────────────────────────────────

@test "chmod +x is hard-blocked (exit 2)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod +x foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod u+x is hard-blocked (exit 2)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod u+x foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod a+x is hard-blocked (exit 2)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod a+x foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod g+x is hard-blocked (exit 2)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod g+x foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod +rx is hard-blocked (exit 2)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod +rx foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod 755 is hard-blocked (numeric exec bits)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod 755 foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod 777 is hard-blocked (numeric exec bits)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod 777 foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod 700 is hard-blocked (numeric exec bits)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod 700 foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod 711 is hard-blocked (numeric exec bits)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod 711 foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod 644 is allowed (no exec bit)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod 644 foo.sh"}}'
  [ "$status" -eq 0 ]
}

@test "chmod 600 is allowed (no exec bit)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod 600 foo.sh"}}'
  [ "$status" -eq 0 ]
}

@test "chmod 444 is allowed (no exec bit)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod 444 foo.sh"}}'
  [ "$status" -eq 0 ]
}

@test "chmod a-x is allowed (removing exec bit)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod a-x foo.sh"}}'
  [ "$status" -eq 0 ]
}

@test "chmod -R 644 is allowed (recursive, no exec)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod -R 644 dir/"}}'
  [ "$status" -eq 0 ]
}

@test "non-chmod Bash command is allowed by chmod-block" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [ "$status" -eq 0 ]
}

@test "empty command is allowed by chmod-block" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
}

@test "chmod u=rwx is hard-blocked (symbolic assignment with exec)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod u=rwx foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod a=rx is hard-blocked (symbolic assignment with exec)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod a=rx foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod ug=rx is hard-blocked (symbolic assignment with exec)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod ug=rx foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod o=x is hard-blocked (symbolic assignment with exec)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod o=x foo.sh"}}'
  [ "$status" -eq 2 ]
}

@test "chmod u=rw is allowed (symbolic assignment, no exec bit)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod u=rw foo.sh"}}'
  [ "$status" -eq 0 ]
}

@test "chmod a=r is allowed (symbolic assignment, no exec bit)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"chmod a=r foo.sh"}}'
  [ "$status" -eq 0 ]
}

# KNOWN MISS (documented coverage boundary): obfuscated chmod via variable indirection
# The hook matches the literal command string; env-indirected commands cannot be caught.
@test "obfuscated chmod via \$VAR is not caught (documented miss)" {
  run bash "$CHMOD_BLOCK" <<< '{"tool_name":"Bash","tool_input":{"command":"CMD=chmod; $CMD +x foo.sh"}}'
  [ "$status" -eq 0 ]
}

# ── high-risk-gate.sh ─────────────────────────────────────────────────────────

_assert_ask() {
  [[ "$output" == *'"permissionDecision":"ask"'* ]]
}

@test "rm -rf triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/test"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "rm -fr triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"rm -fr /tmp/test"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "rm -r -f triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"rm -r -f /tmp/test"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "rm -f -r triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"rm -f -r /tmp/test"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git push --force triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git push --force"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git push -f triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git push -f origin main"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git push +refspec triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git push origin +main:main"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git push --delete triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git push --delete origin branch"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git reset --hard triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git reset --hard HEAD~1"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git rebase triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git rebase main"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git rebase -i triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git rebase -i HEAD~3"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git branch -D triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git branch -D old-branch"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git commit --amend triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git commit --amend"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git commit --amend --no-edit triggers ask" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git commit --amend --no-edit"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git commit --no-edit --amend triggers ask (--amend not first arg)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git commit --no-edit --amend"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git commit -m msg --amend triggers ask (--amend after -m)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix typo\" --amend"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "git commit -m msg without --amend is not gated" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"add feature\""}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "DROP TABLE triggers ask (uppercase)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"psql -c \"DROP TABLE users;\""}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "drop table triggers ask (lowercase)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"psql -c \"drop table users;\""}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "migrate triggers ask (rake db:migrate)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"rake db:migrate"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "migrate triggers ask (standalone)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"migrate"}}'
  [ "$status" -eq 0 ]
  _assert_ask
}

@test "ls is not gated" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git status is not gated" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git push without force is not gated" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git branch -d (soft delete) is not gated" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"git branch -d old-branch"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty command is not gated" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# KNOWN MISS (documented): rm without recursive flag — non-recursive deletion not gated
@test "rm without recursive flag is not gated (documented miss)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"rm file.txt"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# KNOWN MISS (documented): obfuscated destructive command via env-indirection
@test "obfuscated rm via alias is not caught (documented miss)" {
  run bash "$HIGH_RISK" <<< '{"tool_name":"Bash","tool_input":{"command":"DEL=\"rm -rf\"; $DEL /tmp/test"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── pre-write.sh (native-tool reminder) ───────────────────────────────────────

@test "Write tool triggers overwrite reminder" {
  run bash "$PRE_WRITE" <<< '{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"bar"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"additionalContext"'* ]]
}

@test "Edit tool triggers overwrite reminder" {
  run bash "$PRE_WRITE" <<< '{"tool_name":"Edit","tool_input":{"file_path":"foo.txt"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"additionalContext"'* ]]
}

# ── failure-reminder.sh (Feature 3.2 production PostToolUseFailure hook) ──────

FAILURE_REMINDER="$HOOKS_DIR/failure-reminder.sh"

@test "F3.2: failing Bash payload emits additionalContext" {
  run bash "$FAILURE_REMINDER" <<< '{"tool_name":"Bash","tool_input":{"command":"cat /nonexistent"},"error":"cat: /nonexistent: No such file or directory"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"additionalContext"'* ]]
}

@test "F3.2: hookEventName is PostToolUseFailure" {
  run bash "$FAILURE_REMINDER" <<< '{"tool_name":"Bash","tool_input":{"command":"false"},"error":"exit 1"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"hookEventName":"PostToolUseFailure"'* ]]
}

@test "F3.2: short error emits STOP one-liner" {
  run bash "$FAILURE_REMINDER" <<< '{"tool_name":"Bash","tool_input":{"command":"false"},"error":"exit 1"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'STOP'* ]]
}

@test "F3.2: substantive error (>=80 chars) emits full FAILED/THEORY/PROPOSE template" {
  run bash "$FAILURE_REMINDER" <<< '{"tool_name":"Bash","tool_input":{"command":"npm install"},"error":"npm ERR! code ERESOLVE\nnpm ERR! ERESOLVE unable to resolve dependency tree\nnpm ERR! Found incompatible module in node_modules."}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'THEORY'* ]]
}

@test "F3.2: success payload (no error field) emits no reminder" {
  run bash "$FAILURE_REMINDER" <<< '{"tool_name":"Bash","tool_input":{"command":"echo hello"},"tool_response":"hello\n"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "F3.2: output is valid JSON" {
  run bash "$FAILURE_REMINDER" <<< '{"tool_name":"Bash","tool_input":{"command":"false"},"error":"exit 1"}'
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq . > /dev/null
}
