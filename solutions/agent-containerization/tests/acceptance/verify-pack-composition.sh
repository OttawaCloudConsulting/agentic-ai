#!/usr/bin/env bash
# Acceptance test for Feature 01.5 (Pack composition, policy compiler and build
# pipeline). See the feature plan's Test Strategy for the phase-to-requirement map.
#
# EIGHT PHASES, A-H. A-C are the host-side half -- manifest and profile validation, the
# refusal gates, determinism and the drift check, plus the build-context and built-image
# assertions that need no pod (01.5 SF-7a). D-H bring the pod up, rebuild images, and
# assert mounts, package-manager reach and registry reach (SF-7b).
#
# EXECUTION ORDER IS NOT LETTER ORDER, AND THAT IS MECHANISM RATHER THAN PREFERENCE.
# F, G and H need a pod running the LOADED default profile -- go and python3 present, the
# default mount set, the reference pack's package set. D and E then REMOVE the pack from
# that profile and rebuild, which is the only way to observe R7.5's no-residue property on
# the profile that actually carries the pack. Running D/E first would leave the pod in the
# unloaded state and force a third full bring-up to get back. So the run is: bring up ->
# F -> G -> H -> D -> E -> restore. Each phase is still labelled by its plan letter.
#
# WHAT D AND E MUTATE, AND HOW IT IS PUT BACK. profiles/default.yaml and
# policy/resolved/default.yaml are both edited in the working tree: the drift gate compares
# the compile stage's output against the copy in the BUILD CONTEXT, so a refresh that the
# build can see has to happen on disk. Both files are saved before the first edit and
# restored from the EXIT trap, so an interrupt mid-build still restores. The run REFUSES to
# start if either is dirty.
#
# The pack list is emptied with `yq '.packs = [] | ... comments=""'`. The comment strip is
# not cosmetic: `.packs = []` alone renders the flow scalar on the line AFTER the key's
# trailing comment and produces a file yq itself will not parse. Stripping every comment
# was measured to be INERT on the emitter -- the same inputs with and without comments
# compiled byte-identically -- so it changes what the file looks like for the duration and
# nothing about what is built from it.
#
# WHAT THIS REPLACES. SF-2, SF-3 and SF-4 each probed their gates and then REMOVED the
# probes -- 58, 53 and 30 of them, counting the reproductions their Codex passes added.
# SF-5 probed too and recorded no total. This is where the surviving half becomes
# permanent: every assertion below was a throwaway probe in one of those sub-features,
# re-expressed so it runs on every invocation.
#
# HOW THE NEGATIVE PROBES WORK, AND WHAT THEY TOUCH. The compiler resolves its inputs
# relative to the repository root (`REPO_ROOT` from `BASH_SOURCE`), so a malformed
# manifest has to exist at `packs/<name>/pack.yaml` to be read at all. This script
# therefore CREATES a throwaway pack and throwaway profiles in the working tree and
# removes them in an EXIT trap. It refuses to start if any of those paths already
# exists, and it never writes to a committed artifact except in the one check that
# requires it (C6), which restores from a saved copy in the same trap.
#
# Requires: docker, yq (mikefarah/yq), git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
note() { echo "      $1"; }
phase() { echo; echo "=== Phase $1 -- $2"; }

command -v yq     >/dev/null 2>&1 || { echo "verify-pack-composition: yq is required" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "verify-pack-composition: docker is required" >&2; exit 1; }
command -v git    >/dev/null 2>&1 || { echo "verify-pack-composition: git is required" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Scaffolding
# ---------------------------------------------------------------------------

PACK_SRC="packs/language-runtimes/pack.yaml"
PROBE_PACK_DIR="packs/sf7-probe"
PROBE_PACK="${PROBE_PACK_DIR}/pack.yaml"
PROBE_PROFILE="profiles/sf7-probe.yaml"
COMMITTED_DEFAULT="policy/resolved/default.yaml"
DEFAULT_PROFILE="profiles/default.yaml"
CA="mediator/identity/ca/mediator-ca.crt"

PROJECT="sf7-verify-$$"
AGENTS=(claude codex agy)
COMPOSE_BASE=(docker compose --env-file compose/pins.env -f compose/compose.yaml)
COMPOSE_A=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml -p "$PROJECT")
COMPOSE_BC=("${COMPOSE_A[@]}" -f compose/overrides/build-cache.yaml)
IMAGES_DIRTY=0

TMP="$(mktemp -d)"
SAVED_DEFAULT="${TMP}/default.yaml.saved"
DEFAULT_WAS_SAVED=0
PROBE_SIBLING="${TMP}/project"
PROBE_SIBLING_PREFIX="${ROOT}-sf7-prefix-probe"

# Refuse rather than clobber. Both probe paths are this script's own namespace, so one
# that already exists is either a previous run that died before its trap ran or a real
# file someone added under a name this script destroys.
for p in "$PROBE_PACK_DIR" "$PROBE_PROFILE" "$PROBE_SIBLING_PREFIX"; do
  [ ! -e "$p" ] || {
    echo "verify-pack-composition: $p already exists; remove it before running" >&2
    exit 1
  }
done

# C6 perturbs the committed artifact in place, because the build's drift gate compares
# the compile stage's output against the copy in the BUILD CONTEXT and there is no way
# to point it elsewhere. A dirty file here means the restore would put back something
# that was already modified, so the run refuses instead.
for f in "$COMMITTED_DEFAULT" "$DEFAULT_PROFILE"; do
  if ! git diff --quiet -- "$f" 2>/dev/null || ! git diff --cached --quiet -- "$f" 2>/dev/null; then
    echo "verify-pack-composition: $f has uncommitted changes." >&2
    echo "  Phases C, D and E edit it in place and restore it from a saved copy; this will not" >&2
    echo "  run against a file whose pre-existing state it cannot distinguish from its own." >&2
    exit 1
  fi
done

# Every compose invocation below has `file:` secret sources pointing into mediator/identity/,
# which is generated and git-ignored (01.3 SF-3). Without it the daemon's error names a path
# rather than the step that was skipped -- pod-topology's precedent, copied for the same reason.
missing=()
for f in mediator/identity/ca/mediator-ca.crt \
         mediator/identity/listeners/claude-listener.crt \
         mediator/identity/listeners/claude-listener.key \
         mediator/identity/listeners/agy-listener.crt \
         mediator/identity/listeners/agy-listener.key \
         mediator/identity/clients/claude-client.crt \
         mediator/identity/clients/claude-client.key \
         mediator/identity/credentials/htpasswd \
         mediator/identity/credentials/codex.cred \
         mediator/identity/credentials/agy.cred; do
  [ -f "$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -ne 0 ]; then
  echo "verify-pack-composition: proxy-hop trust material is missing:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo "  Issue it first (see mediator/identity/README.md):" >&2
  echo "    bash scripts/issue-identity.sh ca" >&2
  echo "    bash scripts/issue-identity.sh listener claude --ip 172.31.10.2" >&2
  echo "    bash scripts/issue-identity.sh listener agy    --ip 172.31.30.2" >&2
  echo "    bash scripts/issue-identity.sh client   claude" >&2
  exit 1
fi

SAVED_PROFILE="${TMP}/default.profile.saved"
PROFILE_WAS_SAVED=0

cleanup() {
  rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE" "$PROBE_SIBLING_PREFIX"
  # RESTORE IN THE TRAP, not on the happy path. D and E leave the tree mutated for the
  # duration of a build that can fail, be interrupted, or hang; a restore written only after
  # the last assertion would not run in any of those cases.
  if [ "$DEFAULT_WAS_SAVED" -eq 1 ] && [ -f "$SAVED_DEFAULT" ]; then
    cp "$SAVED_DEFAULT" "$COMMITTED_DEFAULT"
  fi
  if [ "$PROFILE_WAS_SAVED" -eq 1 ] && [ -f "$SAVED_PROFILE" ]; then
    cp "$SAVED_PROFILE" "$DEFAULT_PROFILE"
  fi
  # COMPOSE_BC, not COMPOSE_A: the build-cache fragment declares three named volumes, and a
  # `down -v` that does not layer it leaves them behind.
  "${COMPOSE_BC[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  for a in "${AGENTS[@]}"; do docker rm -f "${PROJECT}-bc-${a}" "${PROJECT}-run-${a}" >/dev/null 2>&1 || true; done
  # A rebuild is slow and can itself fail, so it does not belong in a trap. Say so instead.
  if [ "$IMAGES_DIRTY" -eq 1 ]; then
    echo
    echo "WARNING: the :local image tags were last built from a MUTATED profile."
    echo "  Rebuild them before using the pod:"
    echo "    docker compose --env-file compose/pins.env -f compose/compose.yaml \\"
    echo "                   -f compose/overrides/default.yaml build"
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$PROBE_SIBLING"

# Runs a command, compares its exit code, and requires its combined output to contain a
# fragment. Both halves matter: SF-4's Codex pass found a gate that exited with the right
# code from inside yq, "wearing the USAGE code and none of this script's error format".
expect() {
  local want="$1" frag="$2" label="$3"; shift 3
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: expected exit $want, got $rc"
    printf '%s\n' "$out" | head -3 | sed 's/^/      /'
    return
  fi
  if [ -n "$frag" ] && ! printf '%s' "$out" | grep -qF -- "$frag"; then
    fail "$label: exit $want as expected, but the message did not name '$frag'"
    printf '%s\n' "$out" | head -3 | sed 's/^/      /'
    return
  fi
  pass "$label"
}

# A probe pack derived from the reference manifest, with one yq expression applied.
# `name` is rewritten to the probe directory because the validator requires the two to
# agree and a mismatch would mask whatever the probe is actually testing.
make_probe_pack() {
  local expr="$1"
  mkdir -p "$PROBE_PACK_DIR"
  yq eval "$expr" "$PACK_SRC" > "$PROBE_PACK"
  # Applied second so a probe that deletes `.name` still deletes it.
  if [ "$(yq eval 'has("name")' "$PROBE_PACK")" = "true" ]; then
    yq eval -i '.name = "sf7-probe"' "$PROBE_PACK"
  fi
}

# A probe profile derived from a shipped one. `packs` is rewritten so the probe pack is
# what gets composed, unless the caller's expression says otherwise -- SF-5's Codex pass
# recorded a probe defect of exactly this shape, where both packs stayed selected and the
# duplicate-package gate fired first and masked the finding.
make_probe_profile() {
  local src="$1" expr="$2"
  yq eval "$expr" "profiles/${src}.yaml" > "$PROBE_PROFILE"
}

compile_probe() {
  bash scripts/compile-policy.sh --profile sf7-probe --out "${TMP}/probe.out.yaml" "$@"
}

# ---------------------------------------------------------------------------
# Phase A -- Manifest and profile validation (R7.3, R7.11), the build context,
#            and what the built images actually carry
# ---------------------------------------------------------------------------
phase A "manifest and profile validation, build context, image contents"

# The two validators are DIFFERENT and their exit codes are not interchangeable. Manifest
# WELL-FORMEDNESS is scripts/lint-policy.sh's (01.5 SF-1, 01.1's test command host) and
# exits 1; the compiler's composition-time input validation exits 2 and its refusal gates
# exit 3. The plan's Phase A row says "exit 2 naming the field", which is the compiler's
# code -- each assertion below is made against the validator that actually owns the field.
expect 0 "" "A: lint-policy.sh accepts the tree as shipped" \
  bash scripts/lint-policy.sh

# Acceptance Criterion 1: a manifest missing any mandatory field fails validation with the
# FILE and the FAILING FIELD named. Eleven fields, each removed in turn -- R7.3's seven
# (packages, egress, mounts, env, credentials, needs_write_access, runtime_install) plus
# R7.11's blast_radius and the manifest's own identity fields.
for field in name description schema blast_radius needs_write_access packages egress \
             runtime_install mounts env credentials; do
  make_probe_pack "del(.${field})"
  expect 1 "packs/sf7-probe/pack.yaml: mandatory field '${field}' is missing" \
    "A: manifest without '${field}' is refused, naming file and field" \
    bash scripts/lint-policy.sh
done
rm -rf "$PROBE_PACK_DIR"

# Every DECLARED package entry carries a SHA-256, apt items included (R7.3, Edge Case 8).
# DECLARED is the honest scope and Deviation 13 is why: `apt-get install` of the three
# declared names resolves to 40 packages, and the other 37 ride the signed chain one link
# earlier -- gpgv over InRelease against the pinned 40-character fingerprint, and the
# per-.deb hashes in the index that signature covers. Asserting "every installed package
# carries a manifest hash" would be false. This asserts the manifest.
sha_bad=""
for path in '.packages.apt.items[]' '.packages.archives[]'; do
  while IFS= read -r s; do
    [[ "$s" =~ ^[0-9a-f]{64}$ ]] || sha_bad="${sha_bad}${path}: '${s}'"$'\n'
  done < <(yq eval "${path}.sha256" "$PACK_SRC")
done
declared_n="$(( $(yq eval '.packages.apt.items | length' "$PACK_SRC") \
              + $(yq eval '.packages.archives | length' "$PACK_SRC") ))"
if [ -z "$sha_bad" ] && [ "$declared_n" -gt 0 ]; then
  pass "A: all ${declared_n} declared package entries carry a 64-hex SHA-256 (R7.3, apt included)"
  note "declared only, by Deviation 13 -- the transitive closure rides the signed index"
else
  fail "A: a declared package entry has no valid SHA-256"
  printf '%s' "$sha_bad" | sed 's/^/      /'
fi

# The negative for the same field: a truncated digest is refused rather than accepted as
# "present". The shape check is the point -- a 63-character hash is a typo that would
# otherwise fail at build time, deep inside apt, naming the package and not the manifest.
make_probe_pack '.packages.apt.items[0].sha256 = "d31a6f8bdea49711f221baee0e27197c314d0cbe748c020262d32650aca5f01"'
expect 1 "is not 64 lowercase hex characters" \
  "A: a truncated apt sha256 is refused" \
  bash scripts/lint-policy.sh
rm -rf "$PROBE_PACK_DIR"

# A pack may not contribute a deny entry ANYWHERE in the manifest. SF-3's probing found
# this gate reading the document root and `egress` only, so a `deny_cidrs` nested under
# `egress.runtime` sailed through -- the recursive form is what is asserted here, at the
# nested position that was the actual defect.
make_probe_pack '.egress.runtime.deny_cidrs = ["10.0.0.0/8"]'
make_probe_profile default '.packs = ["sf7-probe"]'
expect 2 "Deny entries come from the denylist base" \
  "A: a deny_cidrs nested under egress.runtime is refused (recursive, not root-only)" \
  compile_probe
rm -rf "$PROBE_PACK_DIR"

# A selected pack name that resolves to nothing. The compiler refuses rather than
# composing an empty contribution, so a typo in a profile is a build failure and not a
# silently smaller policy.
make_probe_profile default '.packs = ["no-such-pack"]'
expect 2 "does not resolve to packs/no-such-pack/pack.yaml" \
  "A: a profile selecting an unresolvable pack is refused" \
  compile_probe

# A pack name YAML does not read as a string. The emitter writes names UNQUOTED into
# compiled_from.packs, so a name that round-trips out as a boolean would make the
# provenance record unreadable by the consumer that checks it.
make_probe_profile default '.packs = [true]'
expect 2 "is a YAML boolean or null literal" \
  "A: a boolean pack name is refused at the producer" \
  compile_probe
rm -f "$PROBE_PROFILE"

# --- The build context -------------------------------------------------------
#
# GATE 4 OPERATOR DECISION, 2026-09-07: assert the CA private key is absent BY NAME, not
# merely that the context is small. Edge Case 1 sizes the context; a size ceiling cannot
# catch a 1.7 KB private key, which is the exact failure the solution-root .dockerignore's
# own comment warns about when a future `!` entry lands below its trailing-deny block.
#
# The context is enumerated by exporting it: a `FROM scratch` stage that COPYs the whole
# context, extracted with `--output type=local`. That is the same mechanism SF-4 verified
# on the pinned Docker Desktop before building the artifact stage on it, and it applies
# the real .dockerignore rather than this script's reading of it.
CTX_OUT="${TMP}/context"
mkdir -p "$CTX_OUT"
if docker build -f - --output "type=local,dest=${CTX_OUT}" . >"${TMP}/ctx.log" 2>&1 <<'DOCKERFILE'
FROM scratch
COPY . /
DOCKERFILE
then
  # The assertion is only worth anything if the file it looks for exists on the host --
  # otherwise it passes on a machine that never issued a CA. Checked, not assumed.
  if [ -f "mediator/identity/ca/mediator-ca.key" ]; then
    if [ -e "${CTX_OUT}/mediator/identity/ca/mediator-ca.key" ]; then
      fail "A: the CA private key IS in the build context (criterion 9, SC-2)"
    else
      pass "A: mediator/identity/ca/mediator-ca.key is absent from the build context, by name"
    fi
  else
    fail "A: mediator/identity/ca/mediator-ca.key does not exist on the host, so its absence from the context proves nothing"
    note "issue it first: bash scripts/issue-identity.sh ca"
  fi

  if [ -e "${CTX_OUT}/references" ]; then
    fail "A: references/ IS in the build context (it holds live credentials)"
  else
    pass "A: references/ is absent from the build context, by name"
  fi

  # No identity material of any kind, and no private key by extension anywhere.
  stray="$(find "$CTX_OUT" \( -name '*.key' -o -path '*/mediator/identity/*' \) -type f 2>/dev/null || true)"
  if [ -z "$stray" ]; then
    pass "A: no *.key and no mediator/identity/ path anywhere in the build context"
  else
    fail "A: private-key material in the build context"
    printf '%s\n' "$stray" | sed 's/^/      /'
  fi

  # Edge Case 1's size half. The ceiling is loose on purpose -- it exists to catch
  # `docs/artifacts/` or `.project/` being re-admitted wholesale, which is a
  # tens-of-megabytes event, not to police a few kilobytes.
  ctx_kb="$(du -sk "$CTX_OUT" | awk '{print $1}')"
  if [ "$ctx_kb" -lt 20480 ]; then
    pass "A: build context is ${ctx_kb} KB, under the 20 MB ceiling (Edge Case 1)"
  else
    fail "A: build context is ${ctx_kb} KB -- something large was re-admitted (Edge Case 1)"
  fi

  # The context must still contain what both builds need. A deny-all .dockerignore whose
  # allowlist someone trimmed would pass every absence check above and fail nothing until
  # a build broke.
  ctx_missing=""
  for want in images/Dockerfile images/mediator/Dockerfile policy/resolved/default.yaml \
              policy/allowlist.base.yaml policy/denylist.base.yaml mediator/config \
              scripts/compile-policy.sh profiles/default.yaml packs/language-runtimes/pack.yaml; do
    [ -e "${CTX_OUT}/${want}" ] || ctx_missing="${ctx_missing}${want}"$'\n'
  done
  if [ -z "$ctx_missing" ]; then
    pass "A: the build context carries every input both builds read"
  else
    fail "A: the build context is missing a build input"
    printf '%s' "$ctx_missing" | sed 's/^/      /'
  fi

  # The two test-scoped BASES are excluded by name while profiles/ is admitted wholesale.
  # That asymmetry is what makes SF-4 Deviation 9's carry-through necessary, so it is
  # asserted rather than left as a comment in .dockerignore.
  if [ -e "${CTX_OUT}/policy/allowlist.test.yaml" ] || [ -e "${CTX_OUT}/policy/denylist.test.yaml" ]; then
    fail "A: a .test.yaml base is in the build context -- SF-4 Deviation 9's carry-through premise is broken"
  else
    pass "A: policy/allowlist.test.yaml and denylist.test.yaml are absent from the context (Deviation 9's premise)"
  fi
else
  fail "A: could not export the build context"
  tail -5 "${TMP}/ctx.log" | sed 's/^/      /'
fi

# --- What the built images carry ---------------------------------------------
#
# SF-4 DEVIATION 9 (2): Contract 5's "the mediator image copies policy/, profiles/, packs/"
# is STALE for the runtime stage. Only the COMPILE stage sees profiles/ and packs/ now, and
# the runtime stage copies `--from=drift /out/`, which is the compile stage's *.yaml output
# and not the whole directory -- so policy/resolved/README.md is not in the image either.
# This assertion is written to that shape; written to Contract 5's text it would fail on a
# correct image.
if docker image inspect sandboxed-agent/mediator:local >/dev/null 2>&1; then
  # `--user 0` ON EVERY ONE OF THESE, AND IT IS LOAD-BEARING. All four images declare a
  # non-root USER (the agents `agent`, the mediator `13:13`), so an unprivileged `find /`
  # gets Permission denied on every root-only directory, the errors go to 2>/dev/null and
  # `exit 0` forces success -- a control-plane file under a 0700 path would be INVISIBLE and
  # the assertion would pass. Reproduced before fixing: a planted
  # /root/hidden/allowlist.base.yaml was found as root and not found as `agent`. Inspecting
  # an image's contents is not the same question as what the runtime user can reach, and
  # only the first one is being asked here.
  med_policy="$(docker run --rm --user 0 --entrypoint sh sandboxed-agent/mediator:local \
                  -c 'ls -1 /etc/mediator/policy' 2>/dev/null | sort || true)"
  expected_policy="$(ls -1 policy/resolved/*.yaml | xargs -n1 basename | sort)"
  if [ "$med_policy" = "$expected_policy" ]; then
    pass "A: the mediator image carries exactly the committed resolved artifacts, and no README.md"
  else
    fail "A: /etc/mediator/policy does not match the committed *.yaml set"
    note "image:     $(echo "$med_policy" | tr '\n' ' ')"
    note "committed: $(echo "$expected_policy" | tr '\n' ' ')"
  fi

  med_stray="$(docker run --rm --user 0 --entrypoint sh sandboxed-agent/mediator:local -c '
      for p in /src /profiles /packs /etc/mediator/policy/README.md; do
        [ -e "$p" ] && echo "$p"
      done
      find / -xdev -name pack.yaml -o -xdev -name allowlist.base.yaml 2>/dev/null
      exit 0' 2>/dev/null || true)"
  if [ -z "$med_stray" ]; then
    pass "A: the mediator RUNTIME stage carries no compile-stage input (no /src, profiles/, packs/ or base policy)"
  else
    fail "A: compile-stage inputs survived into the mediator runtime stage"
    printf '%s\n' "$med_stray" | sed 's/^/      /'
  fi
else
  fail "A: sandboxed-agent/mediator:local is not built -- run 'bash scripts/build.sh' first"
fi

# SF-5 DEVIATION 11's CORRECTION. The agent build context is now the solution root and
# LEGITIMATELY contains images/mediator/, mediator/config/, policy/ and
# scripts/compile-policy.sh, because the mediator build needs them from the same context.
# So Contract 5's "the agent images never copy policy/, mediator/ or any identity path" is
# no longer separable at the CONTEXT level and is asserted against the built IMAGE. The
# tempting wrong reading, written down because it was true before that deviation and is
# false after it: "the context no longer holds control-plane paths, so the images cannot".
for agent in claude codex agy; do
  img="sandboxed-agent/${agent}:local"
  if ! docker image inspect "$img" >/dev/null 2>&1; then
    fail "A: ${img} is not built -- run 'bash scripts/build.sh' first"
    continue
  fi
  cp_found="$(docker run --rm --user 0 --entrypoint sh "$img" -c '
      for p in /etc/mediator /src/policy /policy /profiles; do
        [ -e "$p" ] && echo "$p"
      done
      find / -xdev \( -name allowlist.base.yaml -o -name denylist.base.yaml \
                   -o -name mediator-ca.key -o -name compile-policy.sh \) 2>/dev/null
      exit 0' 2>/dev/null || true)"
  if [ -z "$cp_found" ]; then
    pass "A: the ${agent} image carries no control-plane path (Contract 5, asserted against the image)"
  else
    fail "A: the ${agent} image carries a control-plane path"
    printf '%s\n' "$cp_found" | sed 's/^/      /'
  fi
done

# ---------------------------------------------------------------------------
# Phase B -- Refusal gates (R4.17/T27, R2.8/T21, R7.6, SC-3)
# ---------------------------------------------------------------------------
phase B "refusal gates -- every one exits 3, and the positive controls still pass"

# Positive controls FIRST. A refusal suite that has never seen an accepted input cannot
# tell "the gate works" from "the compiler refuses everything", which is the failure mode
# SF-2's own probing was ordered to avoid.
for p in default oauth-mount; do
  expect 0 "" "B: the shipped ${p} profile compiles (positive control)" \
    bash scripts/compile-policy.sh --profile "$p" --out "${TMP}/${p}.control.yaml"
done

# R4.17 / T27: oauth-mount without a COMPLETE five-field accepted_risk record refuses to
# build. Five fields, each deleted in turn. 01.4 IC3 adds `rotation` to T27's four, and
# Edge Case 7 records why all five are required rather than four: a record whose central
# unknown is still unknown is the opposite of what R4.17 makes the operator accept.
oauth_agent="$(yq eval '.oauth_mount | keys | .[0]' profiles/oauth-mount.yaml)"
for field in file mount_mode revocation_path blast_radius rotation; do
  make_probe_profile oauth-mount "del(.oauth_mount.${oauth_agent}.accepted_risk.${field})"
  expect 3 "accepted_risk.${field}" \
    "B: oauth-mount without accepted_risk.${field} is refused (R4.17, T27)" \
    compile_probe
done

# The hollow-record case, and it is the one yq's rendering hid: `[]` and `{}` print as
# two-character STRINGS, so a `-n` test accepted a record of five empty lists. SF-2's
# Codex pass found it; this is the reproduction, kept.
make_probe_profile oauth-mount ".oauth_mount.${oauth_agent}.accepted_risk.blast_radius = []"
expect 3 "yq renders '[]' and '{}' as text" \
  "B: an accepted_risk field holding an empty list is refused, not read as present" \
  compile_probe

# R4.13: the bootstrap fragment mounts :ro regardless, so a profile recording `rw` records
# a risk the system does not take.
make_probe_profile oauth-mount ".oauth_mount.${oauth_agent}.accepted_risk.mount_mode = \"rw\""
expect 3 "'ro' is the only permitted value" \
  "B: accepted_risk.mount_mode 'rw' is refused (R4.13)" \
  compile_probe

# R2.8 / T21, Edge Case 10: an unknown mounts.* key is exit 3, NOT a warning. A profile
# asking for `ssh_auth_sock: true` that is silently ignored is indistinguishable from one
# correctly refused -- until the day the key is implemented.
make_probe_profile default '.mounts.ssh_auth_sock = true'
expect 3 "forwarded sockets are not among them" \
  "B: an unknown mounts key (ssh_auth_sock) is refused, fail-closed (R2.8, T21)" \
  compile_probe

# The same closed set applies to a PACK-supplied mount key. SF-2's Codex pass deferred the
# pack-manifest mount-entry shape to SF-3 rather than inventing one at SF-2; this asserts
# the gate SF-3 built.
make_probe_pack '.mounts = ["ssh_auth_sock"]'
make_probe_profile default '.packs = ["sf7-probe"]'
expect 3 "which is not a mount this system offers" \
  "B: a PACK requesting ssh_auth_sock is refused (R2.8, T21)" \
  compile_probe
rm -rf "$PROBE_PACK_DIR"

# R7.6, both directions. Runtime egress without the declaration, and the declaration
# without the egress it claims. The gate runs BEFORE the zero-pack refusal, or it would be
# unreachable on the only input it exists for.
make_probe_pack '.egress.runtime.allow_fqdns = [{"fqdn": "registry.npmjs.org", "port": 443}]'
make_probe_profile default '.packs = ["sf7-probe"]'
expect 3 "R7.6 requires the widening declared" \
  "B: a pack with runtime egress and runtime_install: false is refused (R7.6)" \
  compile_probe

make_probe_pack '.runtime_install = true'
expect 3 "without 'runtime_install_reason'" \
  "B: runtime_install: true with no recorded reason is refused (R7.6)" \
  compile_probe

make_probe_pack '.runtime_install = true | .runtime_install_reason = "probe"'
expect 3 "declares no egress.runtime entries" \
  "B: runtime_install: true with no runtime egress is refused (R7.6, the other direction)" \
  compile_probe
rm -rf "$PROBE_PACK_DIR"

# SC-3 / R5.14: the project-mount containment gate. Deviation 3 puts it in the compiler at
# exit 3 and writes it LEXICALLY -- normalising `.`, `..` and `//` without realpath -- so it
# behaves identically in the compile stage and on the host. The four normalisation forms are
# SF-2's Codex finding 1, reproduced: each of them walked past the string comparison the gate
# had before that pass.
make_probe_profile default ".mounts.project.path = \"${ROOT}\""
expect 3 "is the solution root" \
  "B: mounts.project.path = the solution root is refused (SC-3)" \
  compile_probe

make_probe_profile default ".mounts.project.path = \"$(dirname "$ROOT")\""
expect 3 "is an ancestor of the solution root" \
  "B: mounts.project.path = an ancestor of the solution root is refused (SC-3)" \
  compile_probe

for sub in policy packs profiles mediator scripts images compose; do
  make_probe_profile default ".mounts.project.path = \"${ROOT}/${sub}\""
  expect 3 "exposes the control-plane directory '${sub}'" \
    "B: mounts.project.path = <root>/${sub} is refused (SC-3)" \
    compile_probe
done

for form in "${ROOT}/./policy" "${ROOT}/../$(basename "$ROOT")/policy" "${ROOT}//policy" "${ROOT}/workspace/../scripts"; do
  make_probe_profile default ".mounts.project.path = \"${form}\""
  expect 3 "exposes the control-plane directory" \
    "B: the normalisation form '${form#$ROOT}' does not walk past SC-3" \
    compile_probe
done

# The two that must PASS. A gate that refuses everything under the root's PREFIX would
# also refuse a legitimate sibling whose name merely starts with the root's -- the naive
# string test that SF-2 probed for explicitly.
make_probe_profile default ".mounts.project.path = \"${PROBE_SIBLING}\""
expect 0 "" "B: a sibling project path is ACCEPTED (SC-3 positive control)" \
  compile_probe

mkdir -p "$PROBE_SIBLING_PREFIX"
make_probe_profile default ".mounts.project.path = \"${PROBE_SIBLING_PREFIX}\""
expect 0 "" "B: a name-prefix sibling is ACCEPTED, not read as a descendant (SC-3 positive control)" \
  compile_probe
rm -f "$PROBE_PROFILE"

# THE LIMIT OF THE GATE, STATED RATHER THAN IMPLIED. Every shipped profile carries the
# literal placeholder `<host path>` and the real bind comes from
# compose/overrides/<profile>.yaml, so on today's profiles this gate has no absolute path
# to judge and warns instead. That is asserted here so the warning cannot disappear
# silently, and the mount that ACTUALLY exists is asserted against `docker inspect` on a
# running container -- which needs the pod up and is therefore SF-7b's Phase G, not this
# script's. Phase B's exit 3 is not SC-3 coverage on its own and is not presented as such.
placeholder_ok=1
for p in default oauth-mount test-fixtures test-selfcheck; do
  pp="$(yq eval '.mounts.project.path' "profiles/${p}.yaml")"
  [[ "$pp" != /* ]] || placeholder_ok=0
done
if [ "$placeholder_ok" -eq 1 ]; then
  pass "B: every shipped profile carries a non-absolute project path, so the SC-3 gate warns rather than judging"
  note "the real mount is asserted against docker inspect at SF-7b Phase G"
else
  fail "B: a shipped profile now carries an absolute project path -- the SC-3 gate judges it, and Phase G's assertion must be re-read against that"
fi

# ---------------------------------------------------------------------------
# Phase C -- Composition and determinism (R7.4, Edge Case 2)
# ---------------------------------------------------------------------------
phase C "composition, determinism and the drift check"

# Edge Case 2: the drift check is a BYTE comparison, so an emitter whose output depends on
# the order its inputs happened to be written in makes the check fire on identical policy.
# COMPILED_AT is fixed because it is the one line that legitimately differs between two runs.
COMPILED_AT=2026-01-01T00:00:00Z bash scripts/compile-policy.sh \
  --profile default --out "${TMP}/det.1.yaml" >/dev/null 2>&1
COMPILED_AT=2026-01-01T00:00:00Z bash scripts/compile-policy.sh \
  --profile default --out "${TMP}/det.2.yaml" >/dev/null 2>&1
if cmp -s "${TMP}/det.1.yaml" "${TMP}/det.2.yaml"; then
  pass "C: two consecutive compiles are byte-identical (Edge Case 2)"
else
  fail "C: two consecutive compiles differ -- the drift check is meaningless"
  diff "${TMP}/det.1.yaml" "${TMP}/det.2.yaml" | head -5 | sed 's/^/      /'
fi

# Every emitted list is LC_ALL=C sorted (Deviation 7). Asserted on the artifact rather than
# on the emitter, because that is what the drift check compares.
unsorted=""
for agent in claude codex agy; do
  got="$(yq eval ".agents.${agent}.allow_fqdns[].fqdn" "$COMMITTED_DEFAULT")"
  want="$(LC_ALL=C sort <<< "$got")"
  [ "$got" = "$want" ] || unsorted="${unsorted}${agent}"$'\n'
done
if [ -z "$unsorted" ]; then
  pass "C: every per-agent allow_fqdns list is LC_ALL=C sorted in the committed artifact (Deviation 7)"
else
  fail "C: an emitted list is not sorted: $(echo "$unsorted" | tr '\n' ' ')"
fi

# Per-agent keying is PRESERVED, not flattened. Composition adds a pack's entries to each
# agent; a bug that merged the three agents into one list would still produce a valid
# artifact and would silently grant every agent every other agent's destinations.
keyed="$(yq eval '.agents | keys | .[]' "$COMMITTED_DEFAULT" | LC_ALL=C sort | tr '\n' ' ')"
if [ "$keyed" = "agy claude codex " ]; then
  pass "C: the resolved artifact keys all three agents separately (no flattening)"
else
  fail "C: agent keying is wrong: '${keyed}'"
fi

# Criterion 4 / T14's ZERO, asserted on the shipped artifact rather than re-measured: the
# reference pack is build-time only, so the provenance record names it while the resolved
# allowlist gains nothing. The load/unload MEASUREMENT of that zero is Phase E's (SF-7b);
# this is the standing assertion that the shipped state still holds it.
if [ "$(yq eval '.compiled_from.packs | length' "$COMMITTED_DEFAULT")" = "1" ] \
   && [ "$(yq eval '.compiled_from.packs[0].name' "$COMMITTED_DEFAULT")" = "language-runtimes" ]; then
  pass "C: the committed default artifact records language-runtimes in compiled_from.packs"
else
  fail "C: compiled_from.packs does not record the selected pack"
fi

# The provenance entry carries the manifest's sha256, which is what makes compiled_from a
# RECORD rather than a list of names -- and it must still match the manifest on disk.
manifest_sha="$(shasum -a 256 "$PACK_SRC" | awk '{print $1}')"
recorded_sha="$(yq eval '.compiled_from.packs[0].sha256' "$COMMITTED_DEFAULT")"
if [ "$manifest_sha" = "$recorded_sha" ]; then
  pass "C: compiled_from.packs records the manifest's real sha256"
else
  fail "C: the recorded manifest sha256 does not match packs/language-runtimes/pack.yaml"
  note "manifest ${manifest_sha}"
  note "recorded ${recorded_sha}"
fi

# A pack-supplied wildcard is REJECTED. SF-3 extended 01.3's wildcard rejection to
# pack-supplied entries; a wildcard in the resolved allowlist would be interpolated into
# the mediator's Lua policy as a name that matches more than it says.
#
# The message asserted is the MANIFEST reader's (R5.4), not validate_resolved's "exact
# names only" -- the entry is refused at the PRODUCER, before composition, so it never
# reaches the artifact the second reader checks. Written against the wrong reader this
# probe passed on the exit code and failed on the message, which is the whole reason
# `expect` requires both.
# Both probes below add runtime egress, which R14.1 (02.3) requires a third_parties
# anchor for -- a placeholder entry against the already-recorded HashiCorp record keeps
# these two R5.4/port assertions isolated from R14.1's own coverage (probed separately
# in Phase C's third_parties block).
PROBE_THIRD_PARTY='.third_parties = [{"party": "HashiCorp", "record": "docs/records/third-party-assessments.md#r141-hashicorp"}]'

make_probe_pack ".egress.runtime.allow_fqdns = [{\"fqdn\": \"*.npmjs.org\", \"port\": 443}] | .runtime_install = true | .runtime_install_reason = \"probe\" | ${PROBE_THIRD_PARTY}"
make_probe_profile default '.packs = ["sf7-probe"]'
expect 2 "'*.npmjs.org' is a wildcard" \
  "C: a pack-supplied wildcard FQDN is rejected at the manifest reader (R5.4)" \
  compile_probe

# A pack-supplied non-443 port is FLAGGED, not refused -- criterion 3 calls it a design
# question, and the operator may legitimately need one. The assertion is that the warning
# is emitted, because a composed entry that changes the port silently is the failure.
make_probe_pack ".egress.runtime.allow_fqdns = [{\"fqdn\": \"probe.example.com\", \"port\": 8443}] | .runtime_install = true | .runtime_install_reason = \"probe\" | ${PROBE_THIRD_PARTY}"
expect 0 "uses port 8443, not 443" \
  "C: a pack-supplied non-443 port is flagged and the compile still succeeds" \
  compile_probe
rm -rf "$PROBE_PACK_DIR"
rm -f "$PROBE_PROFILE"

# --- The drift check ---------------------------------------------------------
#
# SF-4 DEVIATION 9, OBLIGATION 1. Fixture drift is host-side `--check` ONLY. The build's
# gate compares the CARRIED-THROUGH artifacts against the copy they were made from, so it
# is trivially satisfied for the two test-scoped profiles, and neither sibling harness nor
# lint-policy runs `--check` on them. This is where that hole is closed -- and it has to
# pass the `.test.yaml` BASES, or the check compiles the wrong inputs and reports drift on
# a correct artifact.
expect 0 "is current" "C: --check finds policy/resolved/default.yaml current" \
  bash scripts/compile-policy.sh --check --profile default

for p in test-fixtures test-selfcheck; do
  expect 0 "is current" "C: --check finds policy/resolved/${p}.yaml current (with its .test bases)" \
    bash scripts/compile-policy.sh --check --profile "$p" \
      --allowlist policy/allowlist.test.yaml --denylist policy/denylist.test.yaml
done

# `--check` exits 4 on drift, and 4 on a MISSING artifact -- absent is the limiting case of
# different, and the drift stage of the mediator build must fail on it. Both are probed
# against a COPY via --out, so nothing committed moves.
cp "$COMMITTED_DEFAULT" "${TMP}/drift.yaml"
printf '\n# hand-edited\n' >> "${TMP}/drift.yaml"
expect 4 "does not match a fresh compile of its inputs" \
  "C: --check exits 4 on a hand-edited artifact" \
  bash scripts/compile-policy.sh --check --profile default --out "${TMP}/drift.yaml"

expect 4 "does not exist" \
  "C: --check exits 4 on a missing artifact (absent is the limiting case of different)" \
  bash scripts/compile-policy.sh --check --profile default --out "${TMP}/never-written.yaml"

# THE LOCAL BUILD FAILS ON DRIFT, NOT ONLY CI. This is the assertion that makes
# fail-on-drift mechanical: the runtime stage copies its policy OUT OF the drift stage
# (Deviation 10), so a drifted committed artifact cannot produce an image. SF-4 and SF-6
# each probed this by hand and removed the probe; here it is permanent.
#
# It is the one check that perturbs the committed file in place -- the drift stage reads
# the copy in the BUILD CONTEXT and there is nowhere else to point it. The file was saved
# before the run and is restored by the EXIT trap, so an interrupt mid-build still restores.
#
# ONLY MEDIATOR_BASE_DIGEST IS PASSED, and the dependency that creates is recorded rather
# than left to be discovered: YQ_VERSION and YQ_SHA256_* fall through to the Dockerfile's
# ARG defaults. SF-4 measured those defaults as agreeing with pins.env -- the absent-pins
# run produced byte-identical output -- so this builds the same yq the Compose build does.
# If they ever diverge, this check would exercise a different emitter than the pod does and
# could not tell. Read with sed, never sourced: compose/pins.env is Compose data, and SF-4's
# Codex pass found `set -a; . file` turning an appended line into shell on the host.
cp "$COMMITTED_DEFAULT" "$SAVED_DEFAULT"
DEFAULT_WAS_SAVED=1
printf '\n# drift probe -- verify-pack-composition.sh\n' >> "$COMMITTED_DEFAULT"
if docker build -f images/mediator/Dockerfile --target drift \
     --build-arg "MEDIATOR_BASE_DIGEST=$(grep '^MEDIATOR_BASE_DIGEST=' compose/pins.env | cut -d= -f2-)" \
     . >"${TMP}/drift-build.log" 2>&1; then
  fail "C: a drifted committed artifact did NOT fail the local build (Contract 4 is not mechanical)"
else
  if grep -q "DRIFT" "${TMP}/drift-build.log"; then
    pass "C: a drifted committed artifact fails the LOCAL build at the drift stage (Contract 4, Deviation 10)"
  else
    fail "C: the drifted build failed, but not at the drift gate -- attribute it before accepting"
    tail -5 "${TMP}/drift-build.log" | sed 's/^/      /'
  fi
fi
cp "$SAVED_DEFAULT" "$COMMITTED_DEFAULT"

# The positive control for the same build: with the tree restored, the drift stage passes.
# Without it, "the build failed" would be equally consistent with a build that always fails.
if docker build -f images/mediator/Dockerfile --target drift \
     --build-arg "MEDIATOR_BASE_DIGEST=$(grep '^MEDIATOR_BASE_DIGEST=' compose/pins.env | cut -d= -f2-)" \
     . >"${TMP}/clean-build.log" 2>&1; then
  pass "C: with the tree restored, the drift stage passes (positive control)"
else
  fail "C: the drift stage fails on a clean tree"
  tail -5 "${TMP}/clean-build.log" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Bring-up -- the LOADED default profile. F, G and H all read this pod.
# ---------------------------------------------------------------------------
echo
echo "--- bringing up ${PROJECT} on the loaded default profile ---"

# The pod's subnets are fixed by `ipam`, so two Compose projects cannot both be up and
# Docker's error for that names neither project. egress-mediator.sh checks this for the same
# reason; a harness that says which container to stop beats one that says "pool overlaps".
conflict="$(docker network ls --format '{{.Name}}' \
  | grep -vE "^${PROJECT}_" \
  | while read -r n; do
      docker network inspect "$n" --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null \
        | grep -qE '172\.31\.(10|20|30|40)\.0/24' && echo "$n" || true
    done || true)"
if [ -n "$conflict" ]; then
  echo "FAIL: another Compose project already holds this pod's subnets:"
  printf '  %s\n' $conflict
  exit 1
fi

"${COMPOSE_A[@]}" up --build -d --force-recreate >"${TMP}/up.log" 2>&1 || {
  fail "bring-up on the documented command (up --build) failed"
  tail -20 "${TMP}/up.log" | sed 's/^/      /'
  exit 1
}
pass "D: the documented entry point (up --build --force-recreate) brings the pod up on a clean tree"

MED_CTR="${PROJECT}-egress-mediator-1"
for _ in $(seq 1 60); do
  docker exec "$MED_CTR" true >/dev/null 2>&1 && break
  sleep 1
done
docker exec "$MED_CTR" true >/dev/null 2>&1 || {
  fail "the mediator did not come up"
  "${COMPOSE_A[@]}" logs egress-mediator 2>&1 | tail -20 | sed 's/^/      /'
  exit 1
}

live_policy() { docker exec "$MED_CTR" cat /etc/mediator/policy/default.yaml 2>/dev/null; }

# THE AGENTS DO NOT STAY UP, and that is by design rather than a fault: their command is
# `<agent> --version` (01.2), so `up` starts them, they print, and they exit 0. Every
# assertion below that needs a live agent therefore runs in a long-lived container started
# from the SAME service definition -- `compose run -d ... sleep`, which is how
# verify-pod-topology.sh and verify-egress-mediator.sh both get one. The service definition
# is what is under test; the command is not.
agent_ctr() { echo "${PROJECT}-run-$1"; }
start_agents() {
  local a
  for a in "${AGENTS[@]}"; do
    docker rm -f "$(agent_ctr "$a")" >/dev/null 2>&1 || true
    "${COMPOSE_A[@]}" run -d --rm --name "$(agent_ctr "$a")" "$a" sleep 900 >/dev/null 2>&1 \
      || { fail "could not start a long-lived ${a} container"; return 1; }
  done
}
stop_agents() {
  local a
  for a in "${AGENTS[@]}"; do docker rm -f "$(agent_ctr "$a")" >/dev/null 2>&1 || true; done
}
in_agent() { docker exec "$(agent_ctr "$1")" sh -c "$2" 2>&1; }

start_agents || exit 1

# Image identity BEFORE anything is mutated. Deviation 12: PACK_SET_HASH was never shipped --
# it has no producer, and a hand-maintained hash reports "unchanged" exactly when it has
# changed. The `COPY packs/ profiles/` layer carries the cache-invalidation property instead,
# keyed by BuildKit on file content, so a rebuild is observed by IMAGE ID.
declare -a ID_BEFORE
for a in "${AGENTS[@]}"; do
  ID_BEFORE+=("$(docker image inspect --format '{{.Id}}' "sandboxed-agent/${a}:local")")
done

if [ "$(live_policy | yq eval '.compiled_from.packs | length' -)" = "1" ]; then
  pass "D: the running mediator's policy records one pack (the loaded state)"
else
  fail "D: the running mediator's policy does not record the loaded pack"
fi

# ---------------------------------------------------------------------------
# Phase F -- Build-time only, both manager classes (R7.18, R7.19/T33, T15)
# ---------------------------------------------------------------------------
phase F "build-time only -- T33 (OS managers) and T15 (language managers)"

# Every pin is READ from the manifest and pins.env, never hardcoded here. A hardcoded version
# is a second place to update and a test that passes because both copies are stale.
WANT_NODE="$(yq eval '.packages.archives[] | select(.name == "node") | .version' "$PACK_SRC")"
WANT_GO="$(yq eval '.packages.archives[] | select(.name == "go") | .version' "$PACK_SRC")"
WANT_PY="$(yq eval '.packages.apt.items[] | select(.name == "python3") | .version' "$PACK_SRC" | cut -d- -f1)"
WANT_GIT="$(grep '^GIT_VERSION=' compose/pins.env | cut -d= -f2- | sed -e 's/^[0-9]*://' -e 's/-.*//')"

ver_out="$(in_agent claude 'node --version; go version; python3 --version; git --version')"
ver_bad=""
printf '%s' "$ver_out" | grep -qF "v${WANT_NODE}"      || ver_bad="${ver_bad}node ${WANT_NODE}; "
printf '%s' "$ver_out" | grep -qF "go${WANT_GO}"       || ver_bad="${ver_bad}go ${WANT_GO}; "
printf '%s' "$ver_out" | grep -qF "Python ${WANT_PY}"  || ver_bad="${ver_bad}python ${WANT_PY}; "
printf '%s' "$ver_out" | grep -qF "version ${WANT_GIT}" || ver_bad="${ver_bad}git ${WANT_GIT}; "
if [ -z "$ver_bad" ]; then
  pass "F: installed versions match the manifest and pins.env (node ${WANT_NODE}, go ${WANT_GO}, python ${WANT_PY}, git ${WANT_GIT})"
else
  fail "F: an installed version does not match its pin: ${ver_bad}"
  printf '%s\n' "$ver_out" | sed 's/^/      /'
fi

# "...and the snapshot repository the profile declares". agent-base records the archive it
# installed from at /etc/agent-apt-snapshot-url, and images/pack-install.sh refuses a build
# whose profile names a different one -- so the two agreeing is what makes that refusal
# meaningful rather than a comparison of a value against itself.
# COMPARED THE WAY THE REFUSAL COMPARES THEM. images/pack-install.sh:50 tests
# `[ "$base_url" = "${APT_URL%/}" ]` -- it strips one trailing slash, because the profile
# declares the archive with a trailing `/` and agent-base records it without. Comparing the
# raw strings here fails on a CORRECT pair, which is what the first draft did.
img_snap="$(in_agent claude 'cat /etc/agent-apt-snapshot-url 2>/dev/null' | tr -d '\r\n')"
profile_snap="$(yq eval '.package_repository.apt.url' "$DEFAULT_PROFILE")"
if [ -n "$img_snap" ] && [ "$img_snap" = "${profile_snap%/}" ]; then
  pass "F: the image's recorded apt snapshot is the one the profile declares"
else
  fail "F: snapshot mismatch -- image '${img_snap}' vs profile '${profile_snap}'"
fi

# T33, the OS managers. These run at the image's DEFAULT user (`agent`) and deliberately NOT
# with --user 0: Phase A asks what the image CONTAINS and needs root to see all of it, this
# asks what the agent process can DO, which is only meaningful as the agent.
for a in "${AGENTS[@]}"; do
  found="$(in_agent "$a" 'for b in apt apt-get dpkg dpkg-query aptitude; do command -v $b 2>/dev/null; done; exit 0')"
  if [ -z "$(printf '%s' "$found" | tr -d '[:space:]')" ]; then
    pass "F: T33 -- no OS package manager is on ${a}'s PATH"
  else
    fail "F: T33 -- ${a} still has an OS package manager"
    printf '%s\n' "$found" | sed 's/^/      /'
  fi
done

# The install ATTEMPT, not just the absence. R7.19's claim is that the agent cannot install,
# and a missing binary plus a read-only system directory are two different reasons.
attempt="$(in_agent claude 'apt-get install -y cowsay 2>&1; echo "rc=$?"')"
if printf '%s' "$attempt" | grep -qE 'not found|No such file|permission denied|Permission denied'; then
  pass "F: T33 -- an install attempt fails as the agent user"
else
  fail "F: T33 -- an install attempt did not fail the way R7.19 claims"
  printf '%s\n' "$attempt" | head -3 | sed 's/^/      /'
fi

# /var/lib/dpkg/status IS KEPT ON PURPOSE (SF-5). Condition 3 says "no binary", not "no
# database", and SF-6's SBOM attestation reads it. Asserted so a future broadening of the
# removal list cannot take it out silently.
if in_agent claude 'test -s /var/lib/dpkg/status' >/dev/null 2>&1; then
  pass "F: the dpkg DATABASE is retained (no binary is not no database -- SF-5, SBOM input)"
else
  fail "F: /var/lib/dpkg/status was removed -- SF-6's SBOM attestation reads it"
fi

# T15, the LANGUAGE managers. R7.19 says packages, not OS packages, and the reference pack
# ships Node, Python and Go, so the language-level installers are in scope. SF-5 removed the
# PACKAGES rather than the bin symlinks, and widened the list past the plan's three after
# inspecting a built image: corepack, yarn, and the venv wheels that are HOW `python3 -m venv`
# bootstraps a working pip.
for a in "${AGENTS[@]}"; do
  lang="$(in_agent "$a" '
      for b in npm npx corepack yarn yarnpkg pnpm pip pip3 pipx easy_install; do command -v $b 2>/dev/null; done
      for f in /usr/local/lib/node_modules/npm/bin/npm-cli.js \
               /usr/local/lib/node_modules/npm/bin/npx-cli.js \
               /usr/local/lib/node_modules/corepack/dist/corepack.js; do [ -e "$f" ] && echo "$f"; done
      python3 -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec(\"pip\") else 1)" 2>/dev/null && echo "python:pip-importable"
      python3 -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec(\"ensurepip\") else 1)" 2>/dev/null && echo "python:ensurepip-importable"
      exit 0')"
  if [ -z "$(printf '%s' "$lang" | tr -d '[:space:]')" ]; then
    pass "F: T15 -- no language-level installer is reachable in ${a} (binaries, direct paths, or importable)"
  else
    fail "F: T15 -- ${a} retains a language-level installer"
    printf '%s\n' "$lang" | sed 's/^/      /'
  fi
done

# THE RESIDUAL, PROVED RATHER THAN CLAIMED AWAY (Edge Case 9). The filesystem controls cannot
# reach every installer: `go install` uses the toolchain the pack must KEEP for `go build`.
# So the second layer is what refuses it, and the assertion is on the AUDIT LINE rather than
# on the exit code -- Interface Contract 6 makes the audit trail the surface that always
# exists, and a client-side transcript of a refused fetch is ambiguous.
#
# Run on CODEX deliberately: its proxy hop is plain-http CONNECT (compose.yaml), so this
# probes egress denial and not Go's https-proxy plus CA plumbing, which is 01.3's subject.
if in_agent codex 'env | grep -qi "^https_proxy="'; then
  in_agent codex 'GOFLAGS=-mod=mod GOPROXY=https://proxy.golang.org timeout 45 go install example.com/nonexistent/pkg@latest' >/dev/null 2>&1 || true
  gov="$(docker exec "$MED_CTR" cat /var/log/mediator/egress-audit.log 2>/dev/null \
         | jq -c 'select(.verdict != null and .dest_host == "proxy.golang.org")' | tail -1)"
  # The literal is `deny`, read off the mediator's own audit trail rather than guessed --
  # the first draft asserted `denied` and failed on a correct refusal.
  if [ -n "$gov" ] && [ "$(printf '%s' "$gov" | jq -r '.verdict')" = "deny" ]; then
    pass "F: T15 residual -- a surviving installer (go install) reaches the network and is DENIED at the mediator, with the denial audited"
  elif [ -n "$gov" ]; then
    fail "F: T15 residual -- proxy.golang.org was audited with verdict $(printf '%s' "$gov" | jq -r '.verdict'), expected deny"
  else
    fail "F: T15 residual -- no audit line for proxy.golang.org; the attempt did not reach the mediator"
  fi
else
  fail "F: codex has no https_proxy set, so go install would bypass the mediator -- the residual cannot be probed this way"
fi

# ---------------------------------------------------------------------------
# Phase G -- Mounts (R2.8/T21, R2.10/T23), and the SC-3 mount that actually exists
# ---------------------------------------------------------------------------
phase G "mounts -- T21, T23, and SC-3 against a running container"

# SF-2's RECORDED OBLIGATION, RE-HOMED HERE FROM PHASE A AND DISCHARGED. The compiler's SC-3
# gate is LEXICAL and, on every shipped profile, has nothing to judge -- the profiles carry
# the placeholder `<host path>` and the real bind comes from compose/overrides/<profile>.yaml.
# Phase B's exit 3 is therefore NOT SC-3 coverage on its own. This is: the mount that actually
# exists, read off `docker inspect` on a running container, with the host path resolved
# through `realpath` -- which is the SYMLINK half the compiler's lexical gate cannot reach and
# that SF-2's Codex pass explicitly left to SF-7.
ROOT_REAL="$(cd "$ROOT" && pwd -P)"
for a in "${AGENTS[@]}"; do
  srcs="$(docker inspect "$(agent_ctr "$a")" | jq -r '.[0].Mounts[] | select(.Type == "bind") | .Source')"
  bad=""
  while IFS= read -r src; do
    [ -n "$src" ] || continue
    # The mediator CA's PUBLIC certificate is mounted into claude and agy on purpose
    # (01.3 Interface Contract 3) -- it anchors the proxy hop. A public key, read-only,
    # and codex does not get it. egress-mediator.sh carries the same exception.
    case "$src" in */mediator-ca.crt) continue ;; esac
    # 01.6 SF-2: claude's own client key pair, mounted into claude alone as a Compose secret
    # (Interface Contract 5). It lives under mediator/identity/clients/ -- inside the solution
    # root -- for the same reason the CA does: it is generated, git-ignored trust material with
    # nowhere else to live. It is this agent's workload identity, arrives read-only, and holding
    # it is the point. Scoped to the agent's OWN pair by name, so claude binding agy's would
    # still fail SC-3. verify-egress-mediator.sh carries the matching exception.
    case "$src" in */clients/"${a}"-client.crt|*/clients/"${a}"-client.key) continue ;; esac
    # 01.6 SF-3: the same exception for the OTHER identity form. `codex` and `agy` each mount
    # their own proxy credential, generated under mediator/identity/credentials/ for the same
    # reason the CA and the client pair live under mediator/ -- git-ignored trust material with
    # nowhere else to go. Scoped to the agent's OWN credential by name, so codex binding agy's
    # still fails SC-3, and the htpasswd (the mediator's) is not exempted for any agent at all.
    case "$src" in */credentials/"${a}".cred) continue ;; esac
    # Docker Desktop reports a bind source EITHER as the host path or with a `/host_mnt`
    # prefix, non-deterministically across runs of an unchanged tree (01.6 SF-3 saw both
    # forms on four runs). The prefixed form does not exist in this namespace, so the `cd`
    # below fails on it -- and the old `|| real="$src"` never fired to catch that, because
    # the assignment's exit status is the trailing `basename`'s and is always 0. `real`
    # became `/<basename>`, which matched no branch, and the check passed VACUOUSLY. Both
    # halves are fixed here: the prefix is stripped before resolution, and the fallback is
    # a statement rather than a `||` on an assignment that cannot fail.
    case "$src" in /host_mnt/*) src_h="/${src#/host_mnt/}" ;; *) src_h="$src" ;; esac
    real="$src_h"
    dir_real="$(cd "$(dirname "$src_h")" 2>/dev/null && pwd -P || true)"
    [ -z "$dir_real" ] || real="${dir_real%/}/$(basename "$src_h")"
    # SC-3 reads "a fully compromised agent cannot modify the egress policy, the mount set,
    # or the enforcement point" (REQUIREMENTS.md:61). It does NOT read "no bind inside the
    # solution root", and the difference is not academic: the default profile binds
    # `../workspace` BY DESIGN (01.3 SF-4, compose/overrides/default.yaml), which is inside
    # the root and holds no policy, no compose file and no mediator config. Writing to it
    # modifies none of the three things SC-3 names.
    #
    # So the predicate is the ENUMERATED control plane, which is the one
    # verify-egress-mediator.sh has always used and which passes: the tree itself, an
    # ancestor of it, `policy/`, `mediator/`, `profiles/`, `packs/`, and any private key.
    # Narrowed at 01.6 SF-4 after the over-broad form was found to contradict the shipped
    # default override -- the contradiction was masked by the `/host_mnt` accident above
    # since Phase G landed at 01.5 SF-7b. Same root cause SF-2's Deviation 5 named: three
    # harnesses each carried their own "is this mount control plane" predicate. This is now
    # the same predicate in two of them.
    if [ "$real" = "$ROOT_REAL" ]; then
      bad="${bad}${src} -> ${real} (IS the solution root)"$'\n'
    elif [ "${ROOT_REAL#${real}/}" != "$ROOT_REAL" ]; then
      bad="${bad}${src} -> ${real} (an ancestor of the solution root)"$'\n'
    else
      case "$real" in
        "$ROOT_REAL"/policy|"$ROOT_REAL"/policy/*|\
        "$ROOT_REAL"/mediator|"$ROOT_REAL"/mediator/*|\
        "$ROOT_REAL"/profiles|"$ROOT_REAL"/profiles/*|\
        "$ROOT_REAL"/packs|"$ROOT_REAL"/packs/*|\
        *.key)
          bad="${bad}${src} -> ${real} (control plane)"$'\n' ;;
      esac
    fi
  done <<< "$srcs"
  if [ -z "$bad" ]; then
    pass "G: SC-3 -- ${a} binds no control-plane path (the tree, an ancestor, policy/, mediator/, profiles/, packs/, any private key), with the source resolved through realpath so a symlink cannot walk in"
  else
    fail "G: SC-3 -- ${a} binds the control plane"
    printf '%s' "$bad" | sed 's/^/      /'
  fi
done

# R2.8 / T21: no socket is forwarded. SSH_AUTH_SOCK above all -- it is named in R2.8 as the
# one that must never be available, and Docker Desktop's own agent-forwarding path is a
# second spelling of the same thing.
sock_bad=""
for a in "${AGENTS[@]}"; do
  socks="$(docker inspect "$(agent_ctr "$a")" \
    | jq -r '.[0].Mounts[] | .Source + " " + .Destination' \
    | grep -E '\.sock|/run/host-services|ssh-auth' || true)"
  [ -z "$socks" ] || sock_bad="${sock_bad}${a}: ${socks}"$'\n'
  env_sock="$(in_agent "$a" 'echo "${SSH_AUTH_SOCK:-}"' | tr -d '\r\n')"
  [ -z "$env_sock" ] || sock_bad="${sock_bad}${a}: SSH_AUTH_SOCK=${env_sock}"$'\n'
done
if [ -z "$sock_bad" ]; then
  pass "G: T21 -- no agent forwards a socket, and SSH_AUTH_SOCK is unset in all three"
else
  fail "G: T21 -- a socket is forwarded"
  printf '%s' "$sock_bad" | sed 's/^/      /'
fi

# Under profiles/default.yaml `mounts.build_cache` is false and no agent mounts /build-cache.
# Asserted, because T21's "only the project directory and that agent's state volume" is a
# claim about the DEFAULT profile and the fragment below is what would break it.
bc_default="$(docker inspect "$(agent_ctr claude)" | jq -r '.[0].Mounts[] | select(.Destination == "/build-cache") | .Name' || true)"
if [ -z "$bc_default" ]; then
  pass "G: T21 -- no agent mounts /build-cache under the default profile (the fragment is not layered)"
else
  fail "G: T21 -- /build-cache is mounted under the default profile, which never selects it"
fi

# R2.10 / T23: with the cache enabled, it is PER AGENT. Edge Case 14 names the trap -- 01.2
# already puts /home/agent/.cache on the per-agent state volume, so T23 would pass trivially
# against that. This is asserted against the DEDICATED volume, and the assertion that matters
# is not the mount entry but the ISOLATION: a marker written by one agent is unreadable by the
# other. verify-pod-topology.sh checks distinctness; the write half is new here.
bc_ok=1
for a in claude codex; do
  "${COMPOSE_BC[@]}" run -d --rm --name "${PROJECT}-bc-${a}" "$a" sleep 120 >/dev/null 2>&1 \
    || { bc_ok=0; note "could not start ${PROJECT}-bc-${a}"; }
done
if [ "$bc_ok" -eq 1 ]; then
  bc_claude="$(docker inspect "${PROJECT}-bc-claude" | jq -r '.[0].Mounts[] | select(.Destination == "/build-cache") | .Name')"
  bc_codex="$(docker inspect "${PROJECT}-bc-codex"  | jq -r '.[0].Mounts[] | select(.Destination == "/build-cache") | .Name')"
  if [ -n "$bc_claude" ] && [ -n "$bc_codex" ] && [ "$bc_claude" != "$bc_codex" ]; then
    pass "G: T23 -- claude and codex resolve to DISTINCT build-cache volumes (${bc_claude} vs ${bc_codex})"
  else
    fail "G: T23 -- build-cache volumes are '${bc_claude}' and '${bc_codex}'; R2.10 forbids a shared cache"
  fi

  # The write must SUCCEED -- /build-cache is created in the image as agent:agent precisely so
  # a fresh named volume inherits that ownership (SF-5). A cache the agent cannot write is a
  # different bug that would make the isolation check pass vacuously.
  if docker exec "${PROJECT}-bc-claude" sh -c 'echo sf7-marker > /build-cache/marker' >/dev/null 2>&1; then
    pass "G: T23 -- the agent user can WRITE its own build cache (agent:agent ownership seeded from the image)"
    if docker exec "${PROJECT}-bc-codex" sh -c 'test -e /build-cache/marker' >/dev/null 2>&1; then
      fail "G: T23 -- claude's marker is visible in codex's cache; the caches are a cross-agent write channel"
    else
      pass "G: T23 -- claude's marker is NOT visible in codex's cache (R2.10, no unaudited channel between agents)"
    fi
  else
    fail "G: T23 -- the agent user cannot write /build-cache"
  fi
fi
for a in claude codex; do docker rm -f "${PROJECT}-bc-${a}" >/dev/null 2>&1 || true; done

# ---------------------------------------------------------------------------
# Phase H -- Registry reach (T31)
# ---------------------------------------------------------------------------
phase H "registry reach -- T31"

# `npx <server>` fails, and the reason is the FILESYSTEM, not the network: SF-5 removed the
# bundled npm tree outright. Labelled, because "npx fails" read as a network result would
# credit the mediator with a refusal it never made.
npx_out="$(in_agent claude 'npx some-mcp-server 2>&1; echo "rc=$?"')"
if printf '%s' "$npx_out" | grep -qE 'not found|No such file'; then
  pass "H: T31 -- npx is absent, so 'npx <server>' fails at the FILESYSTEM before any network attempt"
else
  fail "H: T31 -- npx did not fail the way SF-5's removal claims"
  printf '%s\n' "$npx_out" | head -3 | sed 's/^/      /'
fi

# Edge Case 5's negative proof, and it is the half that outlives the removal: even if an
# installer survived, there is no registry entry for it to use. Checked over the COMMITTED
# artifacts and over the policy the running mediator actually loaded -- an artifact on disk
# and the policy in force are two different claims.
REGISTRIES=(registry.npmjs.org registry.yarnpkg.com pypi.org files.pythonhosted.org proxy.golang.org sum.golang.org)
reg_bad=""
for f in policy/resolved/*.yaml; do
  names="$(yq eval '.agents.[].allow_fqdns[].fqdn' "$f" 2>/dev/null || true)"
  for r in "${REGISTRIES[@]}"; do
    printf '%s\n' "$names" | grep -qx "$r" && reg_bad="${reg_bad}${f}: ${r}"$'\n'
  done
done
live_names="$(live_policy | yq eval '.agents.[].allow_fqdns[].fqdn' - 2>/dev/null || true)"
for r in "${REGISTRIES[@]}"; do
  printf '%s\n' "$live_names" | grep -qx "$r" && reg_bad="${reg_bad}the RUNNING mediator: ${r}"$'\n'
done
if [ -z "$reg_bad" ]; then
  pass "H: T31 -- no package-registry entry in any committed artifact or in the running mediator's policy"
else
  fail "H: T31 -- a package registry is allowed"
  printf '%s' "$reg_bad" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Phase D -- Rebuild on the documented command (SC-6, R12.1, D10)
# Phase E -- Load/unload (R7.5/T14)
#
# ONE MUTATION WINDOW, SHARED. Deviation 18: Phase E cannot use test-fixtures for the loaded
# state -- it is packs: [] as built and compiles from a DIFFERENT base, so "byte-identical
# allow_fqdns" is unreachable that way because the INPUTS differ. The zero is proved the way
# SF-3 proved it: the same profile, the same bases, packs toggled, COMPILED_AT fixed.
# ---------------------------------------------------------------------------
phase D "rebuild on the documented command, and the drift refusal that makes it non-optional"

# THE DOCUMENTED COMMAND CARRIES --force-recreate AS OF SF-7b (Deviation 20), and this phase is
# why. `up --build` alone rebuilds the mediator image and then reports the container "Running":
# the pod keeps enforcing the policy compiled into the PREVIOUS image. Measured -- image ID
# changed, live compiled_from.packs still 1 against a committed artifact of 0. The resolved
# policy is baked into the image (Dockerfile `COPY --from=drift`), never mounted, so a rebuilt
# image that does not replace the running container is not a policy change at all.

# E's LOADED compile, taken before anything is mutated.
COMPILED_AT=2026-01-01T00:00:00Z bash scripts/compile-policy.sh \
  --profile default --out "${TMP}/loaded.yaml" >/dev/null 2>&1 \
  || fail "E: could not compile the loaded state"

cp "$DEFAULT_PROFILE" "$SAVED_PROFILE"; PROFILE_WAS_SAVED=1
cp "$COMMITTED_DEFAULT" "$SAVED_DEFAULT"; DEFAULT_WAS_SAVED=1

# Empty the pack list. The comment strip is required, not cosmetic -- see the header.
yq eval '.packs = [] | ... comments=""' "$SAVED_PROFILE" > "$DEFAULT_PROFILE"
if [ "$(yq eval '.packs | length' "$DEFAULT_PROFILE")" = "0" ] \
   && [ "$(yq eval 'has("package_repository")' "$DEFAULT_PROFILE")" = "true" ]; then
  pass "D: the profile's pack set is now empty, with package_repository still declared"
else
  fail "D: the profile mutation did not produce the intended shape"
fi

# THE NEGATIVE FIRST: omitting the recompile must FAIL the build rather than silently running
# stale policy. This is NOT the case SF-4 and SF-6 probed -- they perturbed the ARTIFACT. Here
# the INPUTS changed and the artifact is untouched, which is the row's actual claim and the
# condition an operator actually creates by editing a profile and running the documented
# command. It fails at the BUILD, before any container is recreated, so --force-recreate
# changes nothing about this direction -- the flag is carried only so the negative and the
# positive exercise the same command.
IMAGES_DIRTY=1
if "${COMPOSE_A[@]}" up --build -d --force-recreate >"${TMP}/stale.log" 2>&1; then
  fail "D: changing the profile without recompiling did NOT fail the build -- the pod would run stale policy"
else
  if grep -q "DRIFT" "${TMP}/stale.log"; then
    pass "D: a changed profile with a stale committed artifact FAILS the build at the drift gate"
  else
    fail "D: the build failed, but not at the drift gate -- attribute before accepting"
    tail -5 "${TMP}/stale.log" | sed 's/^/      /'
  fi
fi

# The refresh is scripts/compile-policy-build.sh, SF-4's ONE-EMITTER wrapper, and not the
# direct compiler invocation the plan's row names -- SF-4 moved the authoritative compile into
# the build stage so host and stage cannot skew (Edge Case 17).
if bash scripts/compile-policy-build.sh >"${TMP}/refresh.log" 2>&1; then
  pass "D: scripts/compile-policy-build.sh refreshes the artifact through the build stage"
else
  fail "D: the documented refresh failed"
  tail -5 "${TMP}/refresh.log" | sed 's/^/      /'
fi

if ! git diff --quiet -- "$COMMITTED_DEFAULT" && \
   [ "$(yq eval '.compiled_from.packs | length' "$COMMITTED_DEFAULT")" = "0" ]; then
  pass "D: the refreshed artifact changed on disk and now records zero packs"
else
  fail "D: the refresh did not produce a changed, zero-pack artifact"
fi

if "${COMPOSE_A[@]}" up --build -d --force-recreate >"${TMP}/up2.log" 2>&1; then
  pass "D: with the artifact refreshed, the same documented command succeeds"
else
  fail "D: the build still fails after a correct refresh"
  tail -10 "${TMP}/up2.log" | sed 's/^/      /'
fi

for _ in $(seq 1 60); do docker exec "$MED_CTR" true >/dev/null 2>&1 && break; sleep 1; done
# The long-lived containers were started from the PREVIOUS image. Recycle them, or Phase E's
# residue check would inspect the loaded image and report no change -- a false PASS in the
# permissive direction, which is the shape this feature keeps finding.
stop_agents
start_agents || true

# Deviation 12's observable: the agent images REBUILT because their pack set changed. Keyed by
# BuildKit on the content of the COPYed packs/ and profiles/, not on a hash anyone maintains.
id_changed=1
for i in "${!AGENTS[@]}"; do
  now="$(docker image inspect --format '{{.Id}}' "sandboxed-agent/${AGENTS[$i]}:local")"
  [ "$now" != "${ID_BEFORE[$i]}" ] || { id_changed=0; note "${AGENTS[$i]} image ID did not change"; }
done
if [ "$id_changed" -eq 1 ]; then
  pass "D: all three agent images rebuilt -- observed by image ID, since PACK_SET_HASH has no producer (Deviation 12)"
else
  fail "D: an agent image did not rebuild after the pack set changed (Edge Case 4's stale-cache failure)"
fi

if [ "$(live_policy | yq eval '.compiled_from.packs | length' -)" = "0" ]; then
  pass "D: the RUNNING mediator's policy reflects the change (zero packs)"
else
  fail "D: the running mediator still carries the old policy"
fi

phase E "load and unload -- T14, and the zero that criterion 4 makes explicit"

COMPILED_AT=2026-01-01T00:00:00Z bash scripts/compile-policy.sh \
  --profile default --out "${TMP}/unloaded.yaml" >/dev/null 2>&1 \
  || fail "E: could not compile the unloaded state"

# CRITERION 4 / T14's ZERO. Everything outside compiled_from must be byte-identical across the
# two states: the reference pack is build-time only and declares no runtime egress, so loading
# and unloading it moves no allow_fqdns and no allow_cidrs entry. Edge Case 5 calls this the
# honest exercise, and it doubles as T31's negative proof.
if cmp -s <(yq eval 'del(.compiled_from)' "${TMP}/loaded.yaml") \
          <(yq eval 'del(.compiled_from)' "${TMP}/unloaded.yaml"); then
  pass "E: T14 -- loaded and unloaded policy are byte-identical outside compiled_from (the egress delta is ZERO)"
else
  fail "E: T14 -- the resolved policy changed outside compiled_from"
  diff <(yq eval 'del(.compiled_from)' "${TMP}/loaded.yaml") \
       <(yq eval 'del(.compiled_from)' "${TMP}/unloaded.yaml") | head -8 | sed 's/^/      /'
fi

# ...and the provenance DID move, or the comparison above would be satisfied by a mutation
# that never happened.
if [ "$(yq eval '.compiled_from.packs | length' "${TMP}/loaded.yaml")" = "1" ] \
   && [ "$(yq eval '.compiled_from.packs | length' "${TMP}/unloaded.yaml")" = "0" ]; then
  pass "E: T14 -- compiled_from.packs is the ONLY thing that changed (1 -> 0)"
else
  fail "E: T14 -- the pack provenance did not change, so the zero above proves nothing"
fi

# R7.5's other half, and the one Edge Case 4 exists for: recomposing the policy is NOT enough,
# because a previously built image still carries the removed pack's binaries and Compose would
# reuse it. Asserted on the container that is running RIGHT NOW, rebuilt from the profile with
# the pack removed -- not on a different profile's image, which would only show that a
# zero-pack profile yields no binaries and says nothing about residue.
residue="$(in_agent claude '
    for b in go python3; do command -v $b >/dev/null 2>&1 && echo "still present: $b"; done
    [ -d /usr/local/go ] && echo "still present: /usr/local/go"
    exit 0')"
kept="$(in_agent claude '
    for b in node git; do command -v $b >/dev/null 2>&1 || echo "missing: $b"; done
    exit 0')"
if [ -z "$(printf '%s' "$residue" | tr -d '[:space:]')" ]; then
  pass "E: T14/R7.5 -- the unloaded pack leaves NO residue in the rebuilt container (go, python3, /usr/local/go all gone)"
else
  fail "E: T14/R7.5 -- the removed pack left residue"
  printf '%s\n' "$residue" | sed 's/^/      /'
fi
if [ -z "$(printf '%s' "$kept" | tr -d '[:space:]')" ]; then
  pass "E: node and git SURVIVE the unload -- they come from agent-base, not from the pack (control)"
else
  fail "E: the unload removed something the pack never supplied"
  printf '%s\n' "$kept" | sed 's/^/      /'
fi
# Deliberately NOT asserted: a mount delta. Deviation 5 refuses pack-supplied mounts, so the
# Test Strategy's "package set and mounts change" is moot on its mounts half -- only the
# package set can change, and asserting a delta that cannot exist would be a test of nothing.

# --- Restore -----------------------------------------------------------------
cp "$SAVED_PROFILE" "$DEFAULT_PROFILE"
cp "$SAVED_DEFAULT" "$COMMITTED_DEFAULT"

expect 0 "is current" "E: after restore, --check finds the committed artifact current again" \
  bash scripts/compile-policy.sh --check --profile default

if [ -z "$(git status --porcelain -- "$DEFAULT_PROFILE" "$COMMITTED_DEFAULT")" ]; then
  pass "E: both mutated files are byte-restored -- git reports no change"
else
  fail "E: a mutated file was not restored"
  git status --porcelain -- "$DEFAULT_PROFILE" "$COMMITTED_DEFAULT" | sed 's/^/      /'
fi

# Leave the operator's :local tags built from the COMMITTED inputs. compose.yaml pins fixed
# image names, so every build above wrote them -- verify-pod-topology.sh's SKEL_MARKER rebuild
# has the same effect and the convention is pre-existing. This is `build`, not `up --build`:
# the pod is torn down by the trap and there is no reason to start it again.
stop_agents
if "${COMPOSE_A[@]}" build >"${TMP}/final.log" 2>&1; then
  IMAGES_DIRTY=0
  final="$(docker run --rm --entrypoint sh sandboxed-agent/claude:local -c 'command -v go >/dev/null && command -v python3 >/dev/null && echo ok' 2>/dev/null)"
  if [ "$final" = "ok" ]; then
    pass "E: the :local images are rebuilt from the committed profile -- go and python3 are back (positive control)"
  else
    fail "E: the final rebuild did not restore the loaded pack's binaries"
  fi
else
  fail "E: the final rebuild from committed inputs failed"
  tail -5 "${TMP}/final.log" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo
echo "${PASSED} PASS ${FAILED} FAIL"
if [ "$FAILED" -eq 0 ]; then
  echo "ALL PHASES PASSED"
  exit 0
fi
echo "PHASES FAILED"
exit 1
