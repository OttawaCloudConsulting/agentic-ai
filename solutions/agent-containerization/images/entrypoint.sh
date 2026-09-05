#!/usr/bin/env bash
# Idempotent home seeding: copies /opt/agent-home-skel into $HOME, creating
# what's absent, never overwriting an existing (agent-owned) file. This is
# what makes the state volume upgradable across an image rebuild instead of
# requiring the operator to destroy it -- see the feature plan's Approach
# section, "Home seeding, because a named volume masks the image."
set -euo pipefail

SKEL="/opt/agent-home-skel"

seed_home() {
  [ -d "$SKEL" ] || return 0
  find "$SKEL" -mindepth 1 -print0 | while IFS= read -r -d '' src; do
    rel="${src#"$SKEL"/}"
    dest="$HOME/$rel"
    if [ -d "$src" ]; then
      mkdir -p "$dest"
    elif [ ! -e "$dest" ]; then
      mkdir -p "$(dirname "$dest")"
      cp -p "$src" "$dest"
    fi
  done
}

seed_home
exec "$@"
