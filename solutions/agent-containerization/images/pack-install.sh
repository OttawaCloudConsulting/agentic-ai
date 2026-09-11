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
for f in apt-items.txt archives.txt packs.txt pack-env.txt pack-credentials.txt; do
  [ -f "$PLAN/$f" ] || die "no plan at $PLAN (expected $f)"
done

# --- pack env / credentials (02.3 Decision 1, Interface Contract 2) --------------
# Installed unconditionally, even for the zero-pack profile below -- an ABSENT file at
# /opt/agent-pack/env would make the entrypoint's export step distinguish "no pack env"
# from "the plan producer failed silently" by the file's mere existence, which is the
# exact class of defect Deviation 13's sibling finding (SF-6a) exists to avoid. Root-owned
# and read-only: this is image code on the read-only root filesystem, not agent-writable
# state.
mkdir -p /opt/agent-pack
install -m 0444 -o root -g root "$PLAN/pack-env.txt" /opt/agent-pack/env
install -m 0444 -o root -g root "$PLAN/pack-credentials.txt" /opt/agent-pack/credentials

# --- the zero-pack profile installs nothing, and that is a COMPLETE plan ----------
# profiles/test-fixtures.yaml and profiles/test-selfcheck.yaml select no packs, and the
# schema makes package_repository "required only when packs is non-empty" -- so an empty
# repo.env is correct input here, not missing input. Returning before the field check is
# what makes that true of the CONSUMER too: the check below is right for a plan that
# installs something and wrong for one that installs nothing, and running it first is how
# a correct profile got refused (01.5 SF-6a; SF-5 fixed the producer half only).
if [ ! -s "$PLAN/packs.txt" ]; then
  echo "pack-install: profile selects no packs; nothing to install"
  exit 0
fi

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
    node)      f="$tmp/node.tar.xz" ;;
    go)        f="$tmp/go.tar.gz" ;;
    terraform) f="$tmp/terraform.zip" ;;
    gh)        f="$tmp/gh.tar.gz" ;;
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
    terraform)
      # A single flat binary inside the zip. `unzip` (an apt item on the SAME pack)
      # has already installed at this point, because apt items run before archives
      # in this file.
      unzip -o "$f" -d /usr/local/bin terraform >/dev/null
      chmod 0755 /usr/local/bin/terraform
      # CHECKPOINT_DISABLE=1 here, NOT because the pack env plan applies at build
      # time (it does not -- Decision 1 exports it at container start), but because
      # `terraform version` would otherwise attempt checkpoint-api.hashicorp.com
      # from inside the build, which this stage's own network policy denies.
      installed="$(CHECKPOINT_DISABLE=1 /usr/local/bin/terraform version | head -1 | awk '{print $2}')"
      [ "$installed" = "v${version}" ] \
        || die "terraform reports ${installed} after installing the pin for ${version}"
      ;;
    gh)
      # The tarball's top level is `gh_<version>_linux_arm64/`, carrying `bin/gh` plus a
      # LICENSE and man pages this pack does not need. Extract the binary only.
      tar -xzf "$f" -C "$tmp" "gh_${version}_linux_arm64/bin/gh"
      install -m 0755 -o root -g root "$tmp/gh_${version}_linux_arm64/bin/gh" /usr/local/bin/gh
      installed="$(GH_NO_UPDATE_NOTIFIER=1 /usr/local/bin/gh --version | head -1 | awk '{print $3}')"
      [ "$installed" = "${version}" ] \
        || die "gh reports ${installed} after installing the pin for ${version}"
      ;;
  esac
  rm -rf "$tmp"
done < "$PLAN/archives.txt"

echo "pack-install: complete"
