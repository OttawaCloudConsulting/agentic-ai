#!/usr/bin/env bash
# Resolve one profile's pack set into a flat, checked install plan (Feature 01.5 SF-5).
#
# WHY THIS IS A SEPARATE STAGE FROM THE INSTALL. This script is the only thing in
# the agent build that needs a YAML parser, and Contract 5's own rule is that being
# in the context is not being in the image. Running it in a stage that carries `yq`
# and emitting plain text keeps `yq` -- and the manifests themselves -- out of every
# shipped agent layer. It is the same split the mediator's Dockerfile makes between
# its `compile` and `runtime` stages, for the same reason.
#
# THE SECOND READER. Contract 5: "Two consumers read the pack manifests, and only one
# of them is the policy compiler." The compiler composes the resolved *egress policy*
# in the mediator's build; this resolves the *package set* in the agent's. They read
# the same files and must not disagree about their shape, so a manifest-schema change
# in Contract 1 touches both.
#
# OUTPUT (all under $OUT, all plain text, one record per line, no YAML downstream):
#   repo.env       APT_URL / APT_SUITE / APT_SIGNED_BY / APT_FINGERPRINT
#   apt-items.txt  "<name> <version> <sha256>"
#   archives.txt   "<name> <version> <url> <sha256>"
#   packs.txt      "<name> <sha256-of-manifest>"   -- provenance, for the build log
#
# SF-3's LESSON IS APPLIED HERE DELIBERATELY. Every traversal is TAG-checked, not
# text-checked. `yq` renders a missing key, an empty sequence and an empty map in ways
# that a `-n`/length test reads as "fine", which is how a malformed manifest becomes a
# SILENT zero-package install that passes every later step. An empty plan is a refusal
# here, never an outcome.

set -euo pipefail

PROFILE="${1:?usage: pack-plan.sh <profile> <src-root> <out-dir>}"
SRC="${2:?usage: pack-plan.sh <profile> <src-root> <out-dir>}"
OUT="${3:?usage: pack-plan.sh <profile> <src-root> <out-dir>}"

die() { echo "pack-plan: $*" >&2; exit 2; }

PROFILE_FILE="$SRC/profiles/${PROFILE}.yaml"
[ -f "$PROFILE_FILE" ] || die "profile '$PROFILE' not found at profiles/${PROFILE}.yaml"

# --- helpers -------------------------------------------------------------------
# tag_of prints yq's TYPE tag for a path, so a check can ask what a value IS rather
# than what it PRINTS. `!!null` covers both a missing key and an explicit null.
tag_of() { yq -r "$1 | tag" "$2"; }

require_tag() {
  local path="$1" file="$2" want="$3" what="$4" got
  got="$(tag_of "$path" "$file")"
  [ "$got" = "$want" ] || die "$what must be $want in ${file#"$SRC"/}, found $got"
}

# A scalar that is present, non-null and not blank-only. `-n` alone accepts the
# two-character strings yq renders for [] and {} -- the SF-2 finding.
require_scalar() {
  local path="$1" file="$2" what="$3" tag val
  tag="$(tag_of "$path" "$file")"
  case "$tag" in
    '!!str'|'!!int'|'!!float') ;;
    *) die "$what must be a non-empty scalar in ${file#"$SRC"/}, found $tag" ;;
  esac
  val="$(yq -r "$path" "$file")"
  [ -n "${val//[[:space:]]/}" ] || die "$what is blank in ${file#"$SRC"/}"
  printf '%s' "$val"
}

# EVERY FIELD THAT BECOMES PART OF A WHITESPACE-DELIMITED RECORD GOES THROUGH THIS.
# A Codex adversarial pass broke the previous form: the plan files are space-delimited
# and pack-install.sh re-splits them with `read -r name version sha`, but nothing stopped
# a scalar from CONTAINING whitespace or a newline. A single YAML block scalar in one
# `version` or `url` therefore emitted a SECOND well-formed record that the writer never
# intended -- and that injected record was never seen by require_https or by the
# archive-name allowlist, because those ran against the original field. Reproduced before
# fixing: a manifest declaring one archive emitted
# `totally-unknown-archive 0.0.1 http://plaintext.evil.example.com/payload.tar.gz <sha>`,
# past BOTH checks. With the name `node` or `go` and a matching checksum that is arbitrary
# code in every agent image, from a manifest that reads as declaring one entry.
#
# This is the SF-3 lesson repeating a second time in this feature: introducing an internal
# encoding retroactively makes every value flowing into it security-relevant, including
# values that were harmless under the previous representation.
require_token() {
  local v="$1" what="$2"
  case "$v" in
    *[[:space:]]*) die "$what must not contain whitespace or newlines (got '$(printf '%s' "$v" | tr '\n' '~')')" ;;
  esac
  if printf '%s' "$v" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    die "$what must not contain control characters"
  fi
  [ -n "$v" ] || die "$what is empty"
  printf '%s' "$v"
}

require_sha256() {
  local v="$1" what="$2"
  printf '%s' "$v" | grep -Eq '^[0-9a-f]{64}$' \
    || die "$what must be 64 lowercase hex characters, got '$v'"
}

require_https() {
  local v="$1" what="$2"
  case "$v" in
    https://*) ;;
    *) die "$what must be an https:// URL, got '$v'" ;;
  esac
}

mkdir -p "$OUT"
: > "$OUT/apt-items.txt"
: > "$OUT/archives.txt"
: > "$OUT/packs.txt"

# --- the pack list -------------------------------------------------------------
# Read FIRST, because whether a repository is required depends on it.
require_tag '.packs' "$PROFILE_FILE" '!!seq' 'packs'

# EACH ENTRY IS TAG-CHECKED, not only the sequence. yq renders the YAML scalars `true`,
# `null` and `0755` as the plain text "true", "null" and "0755", every one of which
# satisfies the name regex below -- so a boolean or an all-digit entry would be used to
# build a directory path. scripts/compile-policy.sh already refuses YAML-ambiguous pack
# names at the producer; this is the second reader catching up with it.
pack_count="$(yq -r '.packs | length' "$PROFILE_FILE")"
i=0
while [ "$i" -lt "$pack_count" ]; do
  require_tag ".packs[$i]" "$PROFILE_FILE" '!!str' "packs[$i]"
  i=$((i + 1))
done

mapfile -t PACK_NAMES < <(yq -r '.packs[]' "$PROFILE_FILE")

# A ZERO-PACK PROFILE NEEDS NO REPOSITORY, and demanding one contradicted the schema's
# own contract. profiles/default.yaml states it in as many words -- "Required only when
# `packs` above is non-empty" -- but this script asserted the block unconditionally, so
# `--build-arg PROFILE=test-selfcheck` died at "package_repository.apt must be !!map,
# found !!null" on a profile that is CORRECT as written and deliberately omits it. Found
# by a Codex adversarial pass and reproduced before fixing.
if [ "${#PACK_NAMES[@]}" -eq 0 ]; then
  : > "$OUT/repo.env"
  echo "pack-plan: profile '$PROFILE' selects no packs; no package repository required"
  exit 0
fi

# --- the repository the apt items come from (R7.18, Contract 2) ----------------
# Reached only when the profile selects at least one pack. A snapshot, not a suite: the
# timestamped URL is stable in time where `suite: bookworm` plus name=version
# resolves today and fails after the next archive rotation (Edge Case 8).
require_tag '.package_repository.apt' "$PROFILE_FILE" '!!map' 'package_repository.apt'

APT_URL="$(require_token "$(require_scalar '.package_repository.apt.url' "$PROFILE_FILE" 'package_repository.apt.url')" 'package_repository.apt.url')"
APT_SUITE="$(require_token "$(require_scalar '.package_repository.apt.suite' "$PROFILE_FILE" 'package_repository.apt.suite')" 'package_repository.apt.suite')"
APT_SIGNED_BY="$(require_token "$(require_scalar '.package_repository.apt.signed_by' "$PROFILE_FILE" 'package_repository.apt.signed_by')" 'package_repository.apt.signed_by')"
APT_FPR="$(require_token "$(require_scalar '.package_repository.apt.fingerprint' "$PROFILE_FILE" 'package_repository.apt.fingerprint')" 'package_repository.apt.fingerprint')"

require_https "$APT_URL" 'package_repository.apt.url'
printf '%s' "$APT_FPR" | grep -Eq '^[0-9A-F]{40}$' \
  || die "package_repository.apt.fingerprint must be 40 uppercase hex characters, got '$APT_FPR'"

# signed_by resolves inside the BUILD CONTEXT, which is the solution root
# (Deviation 11). A path that escapes it is refused rather than resolved.
case "$APT_SIGNED_BY" in
  /*|*..*) die "package_repository.apt.signed_by must be a context-relative path without '..', got '$APT_SIGNED_BY'" ;;
esac
[ -f "$SRC/$APT_SIGNED_BY" ] || die "signing key '$APT_SIGNED_BY' is not in the build context"

{
  printf 'APT_URL=%s\n'         "$APT_URL"
  printf 'APT_SUITE=%s\n'       "$APT_SUITE"
  printf 'APT_SIGNED_BY=%s\n'   "$APT_SIGNED_BY"
  printf 'APT_FINGERPRINT=%s\n' "$APT_FPR"
} > "$OUT/repo.env"

seen_packs=""
seen_archives=""
seen_apt=""

for name in "${PACK_NAMES[@]+"${PACK_NAMES[@]}"}"; do
  [ -n "${name//[[:space:]]/}" ] || die "packs contains a blank entry"
  # A pack name is a single directory component. Anything else is refused before it
  # is used to build a path -- the SC-3 lesson, applied to a different input.
  printf '%s' "$name" | grep -Eq '^[a-z0-9][a-z0-9-]*$' \
    || die "pack name '$name' must match ^[a-z0-9][a-z0-9-]*$"
  case " $seen_packs " in *" $name "*) die "pack '$name' is selected twice" ;; esac
  seen_packs="$seen_packs $name"

  MF="$SRC/packs/$name/pack.yaml"
  [ -f "$MF" ] || die "pack '$name' does not resolve to packs/$name/pack.yaml"

  # The manifest must name itself, or a directory rename silently installs the
  # wrong set under the right name.
  mf_name="$(require_token "$(require_scalar '.name' "$MF" 'name')" "name in packs/$name/pack.yaml")"
  [ "$mf_name" = "$name" ] \
    || die "pack directory '$name' holds a manifest named '$mf_name'"

  printf '%s %s\n' "$name" "$(sha256sum "$MF" | cut -d' ' -f1)" >> "$OUT/packs.txt"

  # --- apt items ---------------------------------------------------------------
  # Absent is legitimate (a pack may ship archives only); malformed is not.
  apt_tag="$(tag_of '.packages.apt.items' "$MF")"
  if [ "$apt_tag" != '!!null' ]; then
    [ "$apt_tag" = '!!seq' ] || die "packages.apt.items must be !!seq in $name, found $apt_tag"
    n="$(yq -r '.packages.apt.items | length' "$MF")"
    i=0
    while [ "$i" -lt "$n" ]; do
      p=".packages.apt.items[$i]"
      require_tag "$p" "$MF" '!!map' "packages.apt.items[$i]"
      pn="$(require_token "$(require_scalar "$p.name"    "$MF" "packages.apt.items[$i].name")"    "packages.apt.items[$i].name in $name")"
      pv="$(require_token "$(require_scalar "$p.version" "$MF" "packages.apt.items[$i].version")" "packages.apt.items[$i].version in $name")"
      ps="$(require_token "$(require_scalar "$p.sha256"  "$MF" "packages.apt.items[$i].sha256")"  "packages.apt.items[$i].sha256 in $name")"
      require_sha256 "$ps" "packages.apt.items[$i].sha256 in $name"
      case " $seen_apt " in
        *" $pn "*) die "apt package '$pn' is declared by more than one selected pack" ;;
      esac
      seen_apt="$seen_apt $pn"
      printf '%s %s %s\n' "$pn" "$pv" "$ps" >> "$OUT/apt-items.txt"
      i=$((i + 1))
    done
  fi

  # --- archives ----------------------------------------------------------------
  arc_tag="$(tag_of '.packages.archives' "$MF")"
  if [ "$arc_tag" != '!!null' ]; then
    [ "$arc_tag" = '!!seq' ] || die "packages.archives must be !!seq in $name, found $arc_tag"
    n="$(yq -r '.packages.archives | length' "$MF")"
    i=0
    while [ "$i" -lt "$n" ]; do
      p=".packages.archives[$i]"
      require_tag "$p" "$MF" '!!map' "packages.archives[$i]"
      an="$(require_token "$(require_scalar "$p.name"    "$MF" "packages.archives[$i].name")"    "packages.archives[$i].name in $name")"
      av="$(require_token "$(require_scalar "$p.version" "$MF" "packages.archives[$i].version")" "packages.archives[$i].version in $name")"
      au="$(require_token "$(require_scalar "$p.url"     "$MF" "packages.archives[$i].url")"     "packages.archives[$i].url in $name")"
      as="$(require_token "$(require_scalar "$p.sha256"  "$MF" "packages.archives[$i].sha256")"  "packages.archives[$i].sha256 in $name")"
      require_https "$au" "packages.archives[$i].url in $name"
      require_sha256 "$as" "packages.archives[$i].sha256 in $name"
      # Two packs supplying the same archive at different versions would install
      # one over the other with no error and no record of which won.
      case " $seen_archives " in
        *" $an "*) die "archive '$an' is supplied by more than one selected pack" ;;
      esac
      seen_archives="$seen_archives $an"
      # Only the archives this build step knows how to unpack.
      case "$an" in
        node|go) ;;
        *) die "archive '$an' has no install rule in images/pack-install.sh; add one there before declaring it" ;;
      esac
      printf '%s %s %s %s\n' "$an" "$av" "$au" "$as" >> "$OUT/archives.txt"
      i=$((i + 1))
    done
  fi
done

# A profile with packs must produce a plan. Zero here means every manifest read
# returned nothing, which is the silent-permissive failure this script exists to
# refuse -- not a pack set that happens to be empty.
if [ "${#PACK_NAMES[@]}" -gt 0 ] \
   && [ ! -s "$OUT/apt-items.txt" ] && [ ! -s "$OUT/archives.txt" ]; then
  die "profile '$PROFILE' selects ${#PACK_NAMES[@]} pack(s) but the plan is empty"
fi

echo "pack-plan: profile '$PROFILE' -> $(wc -l < "$OUT/apt-items.txt" | tr -d ' ') apt item(s), $(wc -l < "$OUT/archives.txt" | tr -d ' ') archive(s) from ${#PACK_NAMES[@]} pack(s)"
