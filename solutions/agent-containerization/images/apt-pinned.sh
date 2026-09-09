#!/usr/bin/env bash
# Install a pinned, checksum-verified set of .deb packages from the snapshot
# repository, and leave that repository as the image's ONLY apt source
# (Feature 01.5 SF-5, R7.18, Edge Case 8).
#
# Usage:
#   apt-pinned.sh <keyring> <url> <suite> <fingerprint> [<name>=<version>=<sha256> ...]
#
# Called twice in images/Dockerfile with the same contract:
#   * `agent-base`  -- for `git` (Deviation 2), from pins.env-supplied build args,
#     because agent-base is profile-INDEPENDENT and must not read a profile.
#   * `agent-packs` -- for the profile's pack items, from the plan pack-plan.sh
#     emitted, where the profile IS the authority.
# The two are reconciled mechanically rather than by convention: agent-base records
# the URL it used and agent-packs refuses to proceed if the profile names a different
# one. A silent divergence would take `git` from one archive and the packs from
# another, with nothing to show for it.
#
# WHAT IS VERIFIED, AND WHAT RIDES THE CHAIN (Deviation 13). Every package named on
# the command line has its .deb hashed and compared before anything is installed.
# Their transitive dependencies do not carry manifest hashes; they are covered by the
# chain this script asserts at the top -- `gpgv` over `InRelease` with the FULL
# 40-character primary fingerprint, and the per-.deb SHA-256 values in the `Packages`
# index that signature covers. R7.3 is met for declared packages and met by a
# different mechanism for their closure; packs/README.md records the distinction.
#
# BOUNDED RETRIES ARE NOT DECORATION HERE, they were added to a MEASURED failure.
# snapshot.debian.org serves over HTTP/2 and drops streams mid-transfer: fetching the
# 7,152,820-byte git .deb by hand truncated at ~1.7 MB on two of three attempts with
# `PROTOCOL_ERROR` (measured 2026-09-08). The fetch is idempotent, the attempts are
# bounded, and a genuine failure still fails the build -- what is retried is the
# transfer, never the verification. `APT::Sandbox::User=root` silences a separate,
# benign warning: apt drops to the `_apt` user for downloads and cannot read the
# root-owned temporary directory this script downloads into.
APT_OPTS=(-o Acquire::Retries=5 -o APT::Sandbox::User=root)

# NO `Acquire::Check-Valid-Until=false` HERE, and its absence is deliberate. That flag
# is the usual snapshot.debian.org workaround, but this snapshot's InRelease carries no
# `Valid-Until` field at all (measured, 2026-09-08), so apt has nothing to reject.
# Setting it anyway would disable a real check to solve a problem this repository does
# not have.

set -euo pipefail

KEYRING="${1:?usage: apt-pinned.sh <keyring> <url> <suite> <fingerprint> [pkg=ver=sha256 ...]}"
URL="${2:?missing url}"
SUITE="${3:?missing suite}"
FPR="${4:?missing fingerprint}"
shift 4

die() { echo "apt-pinned: $*" >&2; exit 2; }

[ -f "$KEYRING" ] || die "keyring '$KEYRING' not found"
printf '%s' "$FPR" | grep -Eq '^[0-9A-F]{40}$' || die "fingerprint must be 40 uppercase hex characters"
case "$URL" in https://*) ;; *) die "url must be https://, got '$URL'" ;; esac

export DEBIAN_FRONTEND=noninteractive

# --- 1. the trust anchor, asserted before the repository is trusted --------------
# gpgv, not gpg: the base image ships gpgv and no gnupg, and one `--status-fd`
# invocation proves the signature AND names the primary key in a single step. The
# last field of VALIDSIG is the primary key's fingerprint, which is what the profile
# pins -- so a key substitution fails here rather than silently signing the index.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/InRelease" "${URL%/}/dists/${SUITE}/InRelease" \
  || die "cannot fetch InRelease from ${URL%/}/dists/${SUITE}/"

status="$(gpgv --status-fd 1 --keyring "$KEYRING" "$tmp/InRelease" 2>/dev/null)" || true
case "$status" in
  *"VALIDSIG "*" ${FPR}"*) : ;;
  *) die "InRelease is not signed by ${FPR} (gpgv reported: $(printf '%s' "$status" | tr '\n' ';'))" ;;
esac
echo "apt-pinned: InRelease signature verified against ${FPR}"

# --- 2. make the snapshot the ONLY source ---------------------------------------
# The defaults are removed rather than left alongside: with both configured, apt is
# free to satisfy a dependency from the rolling archive, and the pin would bound only
# the packages named here. Every later apt call in every stage inherits this.
install -m 0644 "$KEYRING" /etc/apt/trusted.gpg.d/pinned-snapshot.gpg
rm -f /etc/apt/sources.list
rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true
mkdir -p /etc/apt/sources.list.d
printf 'deb [signed-by=/etc/apt/trusted.gpg.d/pinned-snapshot.gpg] %s %s main\n' \
  "${URL%/}" "$SUITE" > /etc/apt/sources.list.d/pinned-snapshot.list

# Recorded so a later stage can prove it is using the same archive rather than
# assuming it (see the agent-packs reconciliation in images/Dockerfile).
printf '%s\n' "${URL%/}" > /etc/agent-apt-snapshot-url

apt-get update -qq "${APT_OPTS[@]}"

# --- 3. download, verify, then install -------------------------------------------
if [ "$#" -eq 0 ]; then
  echo "apt-pinned: repository configured; no packages requested"
  exit 0
fi

debs="$tmp/debs"
mkdir -p "$debs"

for spec in "$@"; do
  name="${spec%%=*}"
  rest="${spec#*=}"
  version="${rest%%=*}"
  want="${rest#*=}"
  [ -n "$name" ] && [ -n "$version" ] && [ -n "$want" ] \
    || die "malformed spec '$spec' (expected name=version=sha256)"
  printf '%s' "$want" | grep -Eq '^[0-9a-f]{64}$' \
    || die "sha256 for '$name' must be 64 lowercase hex characters, got '$want'"

  # One package per directory, because `apt-get download` names the file itself
  # (the version is URL-encoded) and guessing that name is how the wrong file gets
  # hashed. The directory holds exactly one .deb, so there is nothing to guess.
  one="$tmp/one"
  rm -rf "$one"; mkdir -p "$one"
  ( cd "$one" && apt-get download -qq "${APT_OPTS[@]}" "${name}=${version}" ) \
    || die "'${name}=${version}' is not available from the pinned snapshot"

  file="$(find "$one" -maxdepth 1 -name '*.deb' -print -quit)"
  [ -n "$file" ] || die "apt-get download produced no .deb for '${name}=${version}'"

  got="$(sha256sum "$file" | cut -d' ' -f1)"
  [ "$got" = "$want" ] \
    || die "checksum mismatch for ${name}=${version}: manifest says ${want}, archive gave ${got}"
  echo "apt-pinned: verified ${name}=${version} (${got})"

  mv "$file" "$debs/"
done

# Installing the verified local files pulls their dependency closure from the pinned
# snapshot. The declared packages are installed from the bytes this script hashed --
# not re-fetched afterwards.
apt-get install -y -qq --no-install-recommends "${APT_OPTS[@]}" "$debs"/*.deb

apt-get clean
rm -rf /var/lib/apt/lists/*
