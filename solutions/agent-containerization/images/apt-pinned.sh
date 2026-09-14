#!/usr/bin/env bash
# Install a pinned, checksum-verified set of .deb packages from the snapshot
# repository, and leave that repository as the image's ONLY apt source
# (Feature 01.5 SF-5, R7.18, Edge Case 8).
#
# Usage:
#   apt-pinned.sh [--security <keyring> <url> <suite> <fingerprint>] \
#     <keyring> <url> <suite> <fingerprint> [<name>=<version>=<sha256> ...]
#
# `--security` (feature 02.4 Deviation 1) adds the dated debian-security snapshot as a
# SECOND only-source beside the main one. Debian stable is the main archive plus
# debian-security, and a main-only snapshot never carries security uploads: measured at
# trixie 20260910T203409Z, main resolves openssl 3.5.6 where security has 3.5.7. Each
# source is verified against its OWN keyring and pinned primary fingerprint.
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
#
# The SECURITY snapshot is the exception, and it is scoped to that one source line
# (`check-valid-until=no`), never set globally. Its InRelease DOES carry a 7-day
# Valid-Until, so a dated snapshot is past it a week after its timestamp by
# construction; apt then refuses it (`E: Release file ... is expired`, measured against
# the trixie-security 20260801T000000Z snapshot, 2026-09-13). For a frozen snapshot the
# freshness check has nothing to protect -- the pin IS the freeze -- while the signature
# and fingerprint checks below still apply in full.

set -euo pipefail

die() { echo "apt-pinned: $*" >&2; exit 2; }

SEC_KEYRING="" SEC_URL="" SEC_SUITE="" SEC_FPR=""
if [ "${1:-}" = "--security" ]; then
  [ "$#" -ge 5 ] || die "usage: --security <keyring> <url> <suite> <fingerprint>"
  SEC_KEYRING="$2"; SEC_URL="$3"; SEC_SUITE="$4"; SEC_FPR="$5"
  shift 5
fi

KEYRING="${1:?usage: apt-pinned.sh [--security <keyring> <url> <suite> <fingerprint>] <keyring> <url> <suite> <fingerprint> [pkg=ver=sha256 ...]}"
URL="${2:?missing url}"
SUITE="${3:?missing suite}"
FPR="${4:?missing fingerprint}"
shift 4

# check_source <keyring> <url> <fingerprint>
check_source() {
  [ -f "$1" ] || die "keyring '$1' not found"
  printf '%s' "$3" | grep -Eq '^[0-9A-F]{40}$' || die "fingerprint must be 40 uppercase hex characters"
  case "$2" in https://*) ;; *) die "url must be https://, got '$2'" ;; esac
}
check_source "$KEYRING" "$URL" "$FPR"
[ -z "$SEC_KEYRING" ] || check_source "$SEC_KEYRING" "$SEC_URL" "$SEC_FPR"

export DEBIAN_FRONTEND=noninteractive

# --- 1. the trust anchor, asserted before the repository is trusted --------------
# gpgv, not gpg: the base image ships gpgv and no gnupg, and one `--status-fd`
# invocation proves the signature AND names the primary key in a single step. The
# last field of VALIDSIG is the primary key's fingerprint, which is what the profile
# pins -- so a key substitution fails here rather than silently signing the index.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# verify_inrelease <keyring> <url> <suite> <fingerprint>. Run once per source.
verify_inrelease() {
  local keyring="$1" url="$2" suite="$3" fpr="$4" inrelease status bad
  inrelease="$tmp/InRelease-${suite}"

  curl -fsSL -o "$inrelease" "${url%/}/dists/${suite}/InRelease" \
    || die "cannot fetch InRelease from ${url%/}/dists/${suite}/"

  # PARSED BY FIELD, NOT BY SUBSTRING. An earlier form of this check was
  # `case "$status" in *"VALIDSIG "*" ${FPR}"*)`, which a Codex adversarial pass broke:
  # GOODSIG carries the key's USER ID as free text, so a substituted keyring whose UID
  # contains the literal string "VALIDSIG filler <pinned-fingerprint>" satisfied the glob
  # while the real VALIDSIG line named a completely different key. Reproduced before
  # fixing. The same glob also ignored EXPKEYSIG/REVKEYSIG, because those status lines are
  # ACCOMPANIED by a VALIDSIG rather than replacing it.
  #
  # VALIDSIG's field 12 is the PRIMARY key fingerprint, which is what the profile pins
  # (field 3 is the signing subkey). gpgv's own exit status is now honoured instead of
  # being swallowed with `|| true`.
  # GPGV'S EXIT STATUS IS DELIBERATELY NOT THE GATE, and that is not laziness. This
  # InRelease carries THREE signatures -- the bookworm archive key this profile pins, plus
  # two Debian keys that are intentionally NOT in our single-key keyring. gpgv therefore
  # exits 2 with ERRSIG/NO_PUBKEY for those two even when our key gives a clean
  # GOODSIG+VALIDSIG (measured, 2026-09-09). apt behaves the same way: a multi-signed index
  # is trusted when ANY held key validates it. A first draft of this fix gated on the exit
  # status and rejected on ERRSIG/NO_PUBKEY, and it refused a perfectly good index -- caught
  # by the build, and worth recording as the mirror image of the defect it was fixing.
  status="$(gpgv --status-fd 1 --keyring "$keyring" "$inrelease" 2>/dev/null)" || true

  # These DO impugn our own key, because the keyring holds exactly one. EXPKEYSIG and
  # REVKEYSIG are the subtle pair: they ACCOMPANY a VALIDSIG rather than replacing it, so a
  # check that only looked for VALIDSIG would accept an expired or revoked signing key.
  for bad in BADSIG EXPKEYSIG REVKEYSIG; do
    if printf '%s\n' "$status" | awk -v b="$bad" '$1=="[GNUPG:]" && $2==b {found=1} END{exit !found}'; then
      die "${suite} InRelease carries a $bad status for the pinned key; refusing the repository"
    fi
  done

  printf '%s\n' "$status" \
    | awk -v fpr="$fpr" '$1=="[GNUPG:]" && $2=="VALIDSIG" && $12==fpr {found=1} END{exit !found}' \
    || die "no VALIDSIG line in ${suite} InRelease names primary key ${fpr} (gpgv reported: $(printf '%s' "$status" | tr '\n' ';'))"

  echo "apt-pinned: ${suite} InRelease signature verified against ${fpr}"
}

verify_inrelease "$KEYRING" "$URL" "$SUITE" "$FPR"
[ -z "$SEC_KEYRING" ] || verify_inrelease "$SEC_KEYRING" "$SEC_URL" "$SEC_SUITE" "$SEC_FPR"

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
if [ -n "$SEC_KEYRING" ]; then
  install -m 0644 "$SEC_KEYRING" /etc/apt/trusted.gpg.d/pinned-snapshot-security.gpg
  printf 'deb [signed-by=/etc/apt/trusted.gpg.d/pinned-snapshot-security.gpg check-valid-until=no] %s %s main\n' \
    "${SEC_URL%/}" "$SEC_SUITE" >> /etc/apt/sources.list.d/pinned-snapshot.list
fi

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
#
# --allow-downgrades: a caller (e.g. TLS bootstrap) may have already installed a NEWER
# version of a package this call also pins, from whatever default sources were live at
# that moment (02.4 SF-1, ca-certificates measured newer than the 2026-09-01 bookworm
# snapshot). The pin is authoritative either direction -- apt's default refusal to
# downgrade would silently leave the bootstrap version in the image instead of failing
# loud, which is the one failure mode this script exists to prevent.
apt-get install -y -qq --no-install-recommends --allow-downgrades "${APT_OPTS[@]}" "$debs"/*.deb

apt-get clean
rm -rf /var/lib/apt/lists/*
