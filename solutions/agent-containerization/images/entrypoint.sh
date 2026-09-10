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

# 01.6 SF-3. The proxy credential's ONLY delivery surface is userinfo in the proxy URL. SF-1
# measured that neither `codex` nor `agy` exposes any knob for supplying a proxy credential --
# `codex --help` has no proxy-auth flag and `agy --help` matches nothing for `proxy` or `auth` --
# and that both construct `Proxy-Authorization: Basic` themselves, preemptively, from the URL.
# So the credential is spliced in here rather than written into compose.yaml: the value arrives
# on the same Compose-secret seam as every other piece of trust material, stays out of the
# committed Compose file, and stays out of `docker inspect`.
#
# It does NOT stay out of this process's environment, and that is the accepted residual rather
# than an oversight: a basic credential is a bearer secret, readable here and in `/proc`, which
# is precisely why the Milestone 03 credential-brokering gate is `listener+mtls` alone (01.6
# Decision 4). For `codex` it also crosses a plain-HTTP proxy hop in the clear, on a two-member
# `internal: true` network. Both are recorded in mediator/identity/README.md, not mitigated.
#
# Absent secret: leave the URLs alone and say so. An agent whose listener declares `proxy_auth`
# will then be answered 407 on every request -- loudly, at the mediator, on an audit line reading
# `identity_source: listener` -- which is a better failure than a container that will not start.
# An EMPTY secret is different and does exit: it means the credential was delivered and is
# unusable, and splicing `user:@host` would send a credential that can never match.
inject_proxy_credential() {
  local f="/run/secrets/${AGENT_NAME:-none}-proxy-credential"
  [ -n "${AGENT_NAME:-}" ] || return 0
  if [ ! -r "$f" ]; then
    return 0
  fi
  # The secret holds the WHOLE userinfo string, `<username>:<password>`, and it is spliced in
  # verbatim. This container derives no username of its own: the username the mediator matches is
  # the resolved policy's `identity`, and the only token here that resembles it is the
  # image-baked AGENT_NAME. They agree in every shipped profile and nothing keeps them agreeing,
  # so deriving it here would put a silent wrong-username 407 one profile edit away.
  local userinfo; userinfo="$(tr -d '\r\n' < "$f")"
  if [ -z "$userinfo" ]; then
    echo "entrypoint: $f is empty. The mediator will answer 407 on every request from this agent." >&2
    exit 4
  fi
  case "$userinfo" in
    *:*) : ;;
    *) echo "entrypoint: $f is not '<username>:<password>'; refusing to splice it into a proxy URL" >&2; exit 4 ;;
  esac
  local var url proto rest
  for var in HTTPS_PROXY https_proxy HTTP_PROXY http_proxy; do
    eval "url=\${$var:-}"
    [ -n "$url" ] || continue
    case "$url" in
      *://*) : ;;
      *) echo "entrypoint: $var='$url' has no scheme; not splicing a credential into it" >&2; continue ;;
    esac
    proto="${url%%://*}"
    rest="${url#*://}"
    # Idempotent: a URL that already carries userinfo is left exactly as it is, so a re-exec or
    # an operator-supplied credential is never double-spliced into an unusable one.
    case "$rest" in
      *@*) continue ;;
    esac
    export "$var=${proto}://${userinfo}@${rest}"
  done
  # The password is never echoed. The username is, because it is the audit line's `agent` value
  # and an operator needs to be able to tell that the splice happened at all.
  echo "entrypoint: proxy credential spliced into the proxy URL as user '${userinfo%%:*}'" >&2
}

seed_home
ensure_codex_credentials_store
# BEFORE bootstrap_auth, not after. The splice reads a secret and exports four variables; it
# depends on nothing the seed or the R4.5 merge produce, so nothing is gained by running it later
# -- and bootstrap-auth's endpoint probe reaches the network THROUGH THE PROXY (`curl` at
# bootstrap-auth.sh:163). That probe is unreachable on the --at-start pass today (`AT_START` exits
# first), so this is not a live bug; ordering it first means a future at-start network call cannot
# become a silent 407 whose symptom names authentication rather than the credential.
inject_proxy_credential
bootstrap_auth
exec "$@"
