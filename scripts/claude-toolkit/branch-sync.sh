#!/usr/bin/env bash
# branch-sync.sh — after a PR squash-merge, make the local feature branch identical
# to the repo's integration branch. Replaces the 15× "squashed and merged — synch the
# changes back" manual prompt.
#
# Squash-merge means your local commits are already IN the integration branch (as one
# squashed commit); a plain merge/rebase produces conflicts. The correct move is a hard
# reset onto the integration branch.
#
# Integration (base) branch is resolved in this order — so repos that merge into a
# non-default branch (e.g. `migration`, not `main`) work correctly:
#   1. $CC_BASE_BRANCH environment variable
#   2. .cc-base-branch file at the repo top level (one line, the branch name)
#   3. the remote's default HEAD branch (git remote show origin)
#
# Usage: branch-sync.sh [feature-branch]   (defaults to current branch)
set -euo pipefail

TOP="$(git rev-parse --show-toplevel)"

resolve_base_branch() {
  if [[ -n "${CC_BASE_BRANCH:-}" ]]; then
    printf '%s\n' "$CC_BASE_BRANCH"; return
  fi
  if [[ -f "$TOP/.cc-base-branch" ]]; then
    head -n 1 "$TOP/.cc-base-branch" | tr -d '[:space:]'; return
  fi
  git remote show origin | sed -n 's/.*HEAD branch: //p'
}

BR="${1:-$(git branch --show-current)}"
BASE="$(resolve_base_branch)"

if [[ -z "$BASE" ]]; then
  echo "branch-sync: could not resolve an integration branch (set CC_BASE_BRANCH or .cc-base-branch)" >&2
  exit 1
fi
if [[ -z "$BR" || "$BR" == "$BASE" ]]; then
  echo "branch-sync: on the integration branch '$BASE' (or detached) — nothing to sync" >&2
  exit 1
fi

git show-ref --verify --quiet "refs/heads/$BR" \
  || { echo "branch-sync: no local branch named '$BR'" >&2; exit 1; }

if [[ -n "$(git status --porcelain)" ]]; then
  echo "branch-sync: working tree dirty — commit or stash first" >&2
  exit 1
fi

CURRENT="$(git branch --show-current)"
echo "Current branch: ${CURRENT:-<detached>}  |  Feature branch to reset: $BR  |  Integration branch: $BASE"

git fetch origin "$BASE"
git show-ref --verify --quiet "refs/remotes/origin/$BASE" \
  || { echo "branch-sync: origin/$BASE not found after fetch" >&2; exit 1; }

AHEAD="$(git rev-list --count "origin/${BASE}..${BR}")"
echo "Branch '$BR' has $AHEAD commit(s) not on origin/$BASE."
echo "These are assumed to be already squash-merged; they will be DISCARDED locally."
echo
echo "WARNING: this runs 'git reset --hard origin/$BASE' on '$BR' and cannot be"
echo "undone except via reflog. Only proceed if the PR from '$BR' was merged into '$BASE'."
read -r -p "Reset '$BR' to origin/$BASE? [y/N] " ANSWER
[[ "$ANSWER" == y* || "$ANSWER" == Y* ]] || { echo "aborted"; exit 1; }

git checkout "$BR"
git reset --hard "origin/$BASE"
echo "Done: '$BR' == origin/$BASE. (Recovery if needed: git reflog)"
