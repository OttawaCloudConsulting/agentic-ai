#!/usr/bin/env bash
# PreToolUse hook: Write|Edit — overwrite/delete reminder (advisory)
# Spike version for Feature 2.1. Production version: Feature 3.1 component 3.

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"OVERWRITE REMINDER: Writing or editing a file. If overwriting uncommitted changes, state DOING/EXPECT/IF MISMATCH first (defensive-protocol-v2-epistemology rule)."}}'
exit 0
