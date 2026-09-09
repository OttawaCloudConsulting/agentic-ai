#!/usr/bin/env bash
# Install the profile's composed pack package set, BUILD TIME ONLY (Feature 01.5
# SF-5, R7.18). Consumes the plain-text plan images/pack-plan.sh emitted in the
# `pack-plan` stage -- no YAML is parsed here and no YAML parser is present.
#
# Usage: pack-install.sh <plan-dir> <keyring>

set -euo pipefail

PLAN="${1:?usage: pack-install.sh <plan-dir> <keyring>}"
KEYRING="${2:?usage: pack-install.sh <plan-dir> <keyring>}"

die() { echo "pack-install: $*" >&2; exit 2; }

[ -f "$PLAN/repo.env" ] || die "no plan at $PLAN (expected repo.env)"

# shellcheck disable=SC1091
APT_URL=""; APT_SUITE=""; APT_FINGERPRINT=""
while IFS='=' read -r k v; do
  case "$k" in
    APT_URL) APT_URL="$v" ;;
    APT_SUITE) APT_SUITE="$v" ;;
    APT_FINGERPRINT) APT_FINGERPRINT="$v" ;;
  esac
done < "$PLAN/repo.env"
[ -n "$APT_URL" ] && [ -n "$APT_SUITE" ] && [ -n "$APT_FINGERPRINT" ] \
  || die "repo.env is incomplete"

# --- reconcile with the archive agent-base already used --------------------------
# agent-base is profile-independent and pins its own snapshot from build args; this
# stage takes the PROFILE's value. They must be the same archive, or `git` and the
# pack set come from two different points in time with nothing recording the split.
if [ -f /etc/agent-apt-snapshot-url ]; then
  base_url="$(cat /etc/agent-apt-snapshot-url)"
  [ "$base_url" = "${APT_URL%/}" ] || die \
    "profile pins ${APT_URL%/} but agent-base was built against ${base_url}. Align profiles/*.yaml package_repository.apt.url with SNAPSHOT_URL in compose/pins.env."
fi

echo "pack-install: $(wc -l < "$PLAN/packs.txt" | tr -d ' ') pack(s) selected:"
sed 's/^/pack-install:   /' "$PLAN/packs.txt"

# --- apt items -------------------------------------------------------------------
specs=()
while read -r name version sha; do
  [ -n "${name:-}" ] || continue
  specs+=("${name}=${version}=${sha}")
done < "$PLAN/apt-items.txt"

if [ "${#specs[@]}" -gt 0 ]; then
  bash /usr/local/bin/apt-pinned "$KEYRING" "$APT_URL" "$APT_SUITE" "$APT_FINGERPRINT" \
    "${specs[@]}"
else
  echo "pack-install: no apt items in the plan"
fi

# --- archives --------------------------------------------------------------------
# Direct, checksum-verified downloads -- never `curl | bash` (R7.7), the same shape
# the agy stage already uses for its CLI tarball.
while read -r name version url sha; do
  [ -n "${name:-}" ] || continue
  tmp="$(mktemp -d)"
  case "$name" in
    node) f="$tmp/node.tar.xz" ;;
    go)   f="$tmp/go.tar.gz" ;;
    *)    die "no install rule for archive '$name'" ;;
  esac

  curl -fsSL -o "$f" "$url" || die "cannot fetch $name from $url"
  echo "${sha}  ${f}" | sha256sum -c - >/dev/null \
    || die "checksum mismatch for archive '$name' from $url"
  echo "pack-install: verified ${name} ${version} (${sha})"

  case "$name" in
    node)
      # OVERWRITES /usr/local rather than adding a second runtime -- Deviation 1.
      # The pack pins Node to the version `agent-base` already carries, so this
      # replaces node:22-slim's moving-tag copy with the checksum-verified one at
      # the same version. Two Node installations on PATH would leave the winner to
      # decide what the agent CLIs execute against.
      #
      # This lands BEFORE the `npm install -g` in the claude and codex stages, so
      # those CLIs are installed by the npm this tarball brought.
      tar -xJf "$f" -C /usr/local --strip-components=1 --no-same-owner \
        --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md
      installed="$(node --version)"
      [ "$installed" = "v${version}" ] \
        || die "node reports ${installed} after installing the pin for ${version}"
      ;;
    go)
      # The tarball's top-level directory IS `go`, so this yields /usr/local/go.
      # PATH is set in the Dockerfile, not here: an ENV belongs to the image.
      rm -rf /usr/local/go
      tar -xzf "$f" -C /usr/local --no-same-owner
      installed="$(/usr/local/go/bin/go version | awk '{print $3}')"
      [ "$installed" = "go${version}" ] \
        || die "go reports ${installed} after installing the pin for ${version}"
      ;;
  esac
  rm -rf "$tmp"
done < "$PLAN/archives.txt"

echo "pack-install: complete"
