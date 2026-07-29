#!/usr/bin/env bash
# codex-review.sh — blocking Codex review with timeout, safe stdin, read-only sandbox,
# and a machine-readable VERDICT line.
#
# Replaces the manually retyped pattern:
#   "Task a codex agent to review... codex exec [PROMPT] via stdin, no backticks"
# and fixes the recurring failure modes: hangs (stdin left open), no timeout,
# writable sandbox, verdicts inferred from tail-streamed output.
#
# Usage:
#   codex-review.sh [-t SECONDS] [-p "extra instructions"] MODE
#   MODE:
#     --diff            review unstaged+staged changes vs HEAD (default)
#     --staged          review staged changes only
#     --commits A..B    review a commit range (git log -p)
#     FILE [FILE...]    review specific files
#
# Output: findings on stdout, final line "VERDICT: PASS" or "VERDICT: FAIL".
# Exit codes: 0 = PASS, 1 = FAIL (or missing verdict), 2 = codex error/timeout.
set -uo pipefail

TIMEOUT_SECS=300
EXTRA=""
MODE="diff"
RANGE=""
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t) TIMEOUT_SECS="$2"; shift 2 ;;
    -p) EXTRA="$2"; shift 2 ;;
    --diff) MODE="diff"; shift ;;
    --staged) MODE="staged"; shift ;;
    --commits) MODE="commits"; RANGE="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) MODE="files"; FILES+=("$1"); shift ;;
  esac
done

for DEP in git jq codex; do
  command -v "$DEP" >/dev/null 2>&1 || { echo "codex-review: missing dependency: $DEP" >&2; exit 2; }
done

# macOS: coreutils installs gtimeout; gnubin may also provide timeout.
TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
if [[ -z "$TIMEOUT_BIN" ]]; then
  echo "codex-review: need GNU timeout (brew install coreutils)" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/codex-review.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
CTX="$WORK/context.txt"

case "$MODE" in
  diff)
    git diff --no-ext-diff --no-color HEAD > "$CTX"
    # `git diff` excludes untracked files — append them so brand-new files are
    # actually reviewed instead of silently omitted.
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      grep -Iq . "$f" 2>/dev/null || continue   # skip binaries
      printf '\n===== NEW (untracked): %s =====\n' "$f" >> "$CTX"
      cat "$f" >> "$CTX"
    done < <(git ls-files --others --exclude-standard)
    ;;
  staged)  git diff --no-ext-diff --no-color --staged > "$CTX" ;;
  commits) git log --patch --no-color "$RANGE" > "$CTX" ;;
  files)
    : > "$CTX"
    for f in "${FILES[@]}"; do
      printf '\n===== %s =====\n' "$f" >> "$CTX"
      cat "$f" >> "$CTX"
    done
    ;;
esac

if [[ ! -s "$CTX" ]]; then
  echo "codex-review: empty context — nothing to review" >&2
  exit 2
fi

CTX_BYTES="$(wc -c < "$CTX")"
if (( CTX_BYTES > 400000 )); then
  echo "codex-review: warning — context is $((CTX_BYTES / 1024))KB; consider narrowing scope" >&2
fi

read -r -d '' PROMPT <<'EOF' || true
You are a rigorous code reviewer. Review the context below (a diff, commit range, or files).
Report only verified findings, one line each, format:
  P1|P2|P3 file:line — problem — fix
P1 = breaks correctness/security, P2 = significant defect, P3 = minor.
No praise, no restating the diff. If a finding is speculative, mark it (unverified).
The FINAL line of your reply must be exactly "VERDICT: PASS" (zero P1/P2 findings)
or "VERDICT: FAIL" (one or more P1/P2 findings).
EOF

EVENTS="$WORK/events.jsonl"
ERRLOG="$WORK/stderr.log"

# Prompt + context piped on stdin ("-"); stdin is consumed and closed — no hang.
# -s read-only: review must never run with a writable sandbox.
{ printf '%s\n\n%s\n\n--- CONTEXT ---\n' "$PROMPT" "$EXTRA"; cat "$CTX"; } | \
  "$TIMEOUT_BIN" --kill-after=10 "$TIMEOUT_SECS" \
  codex exec --json -s read-only --skip-git-repo-check - \
  > "$EVENTS" 2> "$ERRLOG"
RC=$?

if [[ $RC -eq 124 || $RC -eq 137 ]]; then
  echo "codex-review: TIMEOUT after ${TIMEOUT_SECS}s (process killed)" >&2
  tail -n 5 "$ERRLOG" >&2 || true
  exit 2
elif [[ $RC -ne 0 ]]; then
  echo "codex-review: codex exec failed rc=$RC" >&2
  tail -n 20 "$ERRLOG" >&2 || true
  exit 2
fi

# Same event schema the triad-refine run-codex.sh parses (.item.text of agent messages).
TEXT="$(jq -rs '[.[] | select(.item.type? == "agent_message") | .item.text] | last // empty' "$EVENTS")"
if [[ -z "$TEXT" ]]; then
  echo "codex-review: no agent message found in codex output" >&2
  tail -n 5 "$ERRLOG" >&2 || true
  exit 2
fi

printf '%s\n' "$TEXT"

if grep -q '^VERDICT: PASS[[:space:]]*$' <<< "$TEXT"; then
  exit 0
elif grep -q '^VERDICT: FAIL[[:space:]]*$' <<< "$TEXT"; then
  exit 1
else
  echo "codex-review: missing VERDICT line — treating as FAIL" >&2
  exit 1
fi
