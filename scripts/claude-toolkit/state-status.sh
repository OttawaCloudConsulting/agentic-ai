#!/usr/bin/env bash
# state-status.sh — compact digest of the gated-workflow state files, plus a
# buildable-precondition gate. Replaces the "read ALL state files fresh every
# invocation" pattern: skills read this ~15-line digest instead of 5 full documents.
#
# Usage:
#   state-status.sh [repo-root]                 # digest (default: cwd)
#   state-status.sh --check-buildable SLUG [repo-root]   # exit 0 iff SLUG buildable
#
# Milestone-status files are discovered across BOTH known skill-suite layouts:
#   flat layout        : <root>/milestones/<NN>-<name>/milestone-status.txt
#   namespaced layout  : <root>/.project/<slug>/milestones/<NN>-<name>/milestone-status.txt
#                        (the /project skill suite)
# Override with CC_MILESTONE_GLOB (space-separated globs, evaluated from <root>).
#
# Schema:
#   progress.txt          — "## Gates" / "## Milestones" sections; entries start [x]/[~]/[ ]
#   milestone-status.txt  — feature headers "^[~] Feature NN.M: name" + indented note lines;
#                           Gate-4 approval note contains the phrase "planned, awaiting build".
# A feature is buildable iff its header is [~] AND its block contains that phrase.
# Slugs are matched as fixed strings (never as regexes).
set -euo pipefail

CHECK=""
if [[ "${1:-}" == "--check-buildable" ]]; then
  CHECK="${2:?usage: state-status.sh --check-buildable SLUG}"
  ROOT="${3:-.}"
else
  ROOT="${1:-.}"
fi

P="$ROOT/progress.txt"
[[ -f "$P" ]] || { echo "state-status: no progress.txt at $ROOT" >&2; exit 1; }

# Collect milestone-status.txt files across supported layouts (or the override glob).
# Prints one path per line; nothing if none exist.
collect_ms_files() {
  local globs
  if [[ -n "${CC_MILESTONE_GLOB:-}" ]]; then
    globs="$CC_MILESTONE_GLOB"
  else
    globs="milestones/*/milestone-status.txt .project/*/milestones/*/milestone-status.txt"
  fi
  local g f
  for g in $globs; do
    for f in "$ROOT"/$g; do
      [[ -f "$f" ]] && printf '%s\n' "$f"
    done
  done
}

# Label a milestone-status file by its path relative to root (unambiguous across layouts).
ms_label() { local d; d="$(dirname "$1")"; printf '%s' "${d#"$ROOT"/}"; }

if [[ -n "$CHECK" ]]; then
  while IFS= read -r MS; do
    [[ -n "$MS" ]] || continue
    # Block scan: a [~] feature header containing the slug (fixed-string),
    # then require "planned, awaiting build" inside that feature's block.
    if awk -v slug="$CHECK" '
        /^\[/ { inblk = ($0 ~ /^\[~\]/ && index($0, slug) > 0) }
        inblk && /planned, awaiting build/ { found = 1; exit }
        END { exit found ? 0 : 1 }
      ' "$MS"; then
      echo "BUILDABLE: $CHECK ($(ms_label "$MS"))"
      exit 0
    fi
  done < <(collect_ms_files)
  echo "NOT BUILDABLE: '$CHECK' has no [~] feature entry with a 'planned, awaiting build' note — run the planning gate first." >&2
  exit 1
fi

echo "== Gates =="
sed -n '/^## Gates/,/^## /p' "$P" | grep -E '^\[' || echo "(none recorded)"

echo "== Milestones =="
sed -n '/^## Milestones/,/^## /p' "$P" | grep -E '^\[' || echo "(none recorded)"

while IFS= read -r MS; do
  [[ -n "$MS" ]] || continue
  echo "== $(ms_label "$MS") =="
  grep -E '^\[|^[[:space:]]*Plan:|^[[:space:]]*Sub-features:|^[[:space:]]*Notes:' "$MS" || true
done < <(collect_ms_files)

echo "== Awaiting build =="
AWAITING="$(
  while IFS= read -r MS; do
    [[ -n "$MS" ]] || continue
    awk -v ms="$(ms_label "$MS")" '
      /^\[~\] Feature/ {
        hdr = $0; inblk = 1; printed = 0
        if ($0 ~ /planned, awaiting build/) { print ms ": " hdr; printed = 1 }
        next
      }
      /^\[/ { inblk = 0 }
      inblk && /planned, awaiting build/ && !printed { print ms ": " hdr; printed = 1 }
    ' "$MS"
  done < <(collect_ms_files)
)"
if [[ -n "$AWAITING" ]]; then printf '%s\n' "$AWAITING"; else echo "(none)"; fi
