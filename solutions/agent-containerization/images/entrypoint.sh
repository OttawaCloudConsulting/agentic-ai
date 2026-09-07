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

# R4.5 (criterion 2), Codex only, every AUTH_MODE. The skeleton seed above
# creates $CODEX_HOME/config.toml only when it is ABSENT -- correct for a fresh
# volume, insufficient for a volume that predates this setting or that Codex has
# since rewritten. This makes the setting hold on both, and it merges rather than
# replaces: every other key in the operator's file survives.
#
# `cli_auth_credentials_store` is a top-level TOML key, so a missing one is
# PREPENDED, never appended -- appending would place it after the first `[table]`
# header and silently make it that table's key instead.
#
# A present-but-different value is corrected to "file" with a notice on stderr.
# That is the one case where this is not purely additive, and it is deliberate:
# the only other store Codex offers is `keyring`, which hard-fails with no D-Bus,
# and no container here has one. Failing later at authentication with a keyring
# error is worse than being told here that the value was overridden.
ensure_codex_credentials_store() {
  [ -n "${CODEX_HOME:-}" ] || return 0

  cfg="$CODEX_HOME/config.toml"
  mkdir -p "$CODEX_HOME"
  [ -e "$cfg" ] || : > "$cfg"

  if grep -Eq '^[[:space:]]*cli_auth_credentials_store[[:space:]]*=[[:space:]]*"file"[[:space:]]*$' "$cfg"; then
    return 0
  fi

  tmp="$cfg.tmp.$$"
  if grep -Eq '^[[:space:]]*cli_auth_credentials_store[[:space:]]*=' "$cfg"; then
    echo "entrypoint: overriding cli_auth_credentials_store to \"file\" (R4.5: no D-Bus in this container)" >&2
    grep -Ev '^[[:space:]]*cli_auth_credentials_store[[:space:]]*=' "$cfg" > "$tmp"
  else
    cat "$cfg" > "$tmp"
  fi

  {
    printf '%s\n' 'cli_auth_credentials_store = "file"'
    cat "$tmp"
  } > "$cfg"
  rm -f "$tmp"
}

# The AUTH_MODE dispatcher (01.4 SF-2, Interface Contract 2). Invoked AFTER the skeleton seed
# and after the R4.5 merge -- the ordering is load-bearing in both directions: the seed must not
# overwrite a credential, and the dispatcher must see the config.toml the merge just fixed.
#
# --at-start marks this as the every-start pass, in which an absent credential WARNS rather than
# failing the container (operator decision, 2026-09-07; see the feature plan, Deviation 2). An
# unset or unsupported AUTH_MODE still exits 2 here, and oauth-mount still exits 3 on an emptied
# volume per criterion 5 -- so the fail-closed properties that matter are unchanged.
bootstrap_auth() {
  [ -n "${AGENT_NAME:-}" ] || return 0
  [ -x /usr/local/bin/bootstrap-auth ] || return 0
  bash /usr/local/bin/bootstrap-auth "$AGENT_NAME" --at-start
}

seed_home
ensure_codex_credentials_store
bootstrap_auth
exec "$@"
