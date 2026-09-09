#!/usr/bin/env bash
# Acceptance test for Feature 01.5 (Pack composition, policy compiler and build
# pipeline). See the feature plan's Test Strategy for the phase-to-requirement map.
#
# SF-7a SHIPS PHASES A-C. The plan defines eight phases, A-H. A-C are the host-side
# half: manifest and profile validation, the refusal gates, determinism and the drift
# check, plus the build-context and built-image assertions that need no pod. D-H bring
# the pod up, rebuild images and assert mounts and registry reach; they land at SF-7b
# and this script announces them as not-yet-built rather than silently omitting them.
# A harness that reports "ALL PHASES PASSED" while five phases do not exist would be
# the same silent-in-the-permissive-direction shape this feature's Codex passes found
# three times.
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
if ! git diff --quiet -- "$COMMITTED_DEFAULT" 2>/dev/null \
   || ! git diff --cached --quiet -- "$COMMITTED_DEFAULT" 2>/dev/null; then
  echo "verify-pack-composition: $COMMITTED_DEFAULT has uncommitted changes." >&2
  echo "  Phase C perturbs it in place and restores it from a saved copy; it will not" >&2
  echo "  run against a file whose pre-existing state it cannot distinguish from its own." >&2
  exit 1
fi

cleanup() {
  rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE" "$PROBE_SIBLING_PREFIX"
  if [ "$DEFAULT_WAS_SAVED" -eq 1 ] && [ -f "$SAVED_DEFAULT" ]; then
    cp "$SAVED_DEFAULT" "$COMMITTED_DEFAULT"
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
expect 3 "R7.6 requires it declared" \
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
make_probe_pack '.egress.runtime.allow_fqdns = [{"fqdn": "*.npmjs.org", "port": 443}] | .runtime_install = true | .runtime_install_reason = "probe"'
make_probe_profile default '.packs = ["sf7-probe"]'
expect 2 "'*.npmjs.org' is a wildcard" \
  "C: a pack-supplied wildcard FQDN is rejected at the manifest reader (R5.4)" \
  compile_probe

# A pack-supplied non-443 port is FLAGGED, not refused -- criterion 3 calls it a design
# question, and the operator may legitimately need one. The assertion is that the warning
# is emitted, because a composed entry that changes the port silently is the failure.
make_probe_pack '.egress.runtime.allow_fqdns = [{"fqdn": "probe.example.com", "port": 8443}] | .runtime_install = true | .runtime_install_reason = "probe"'
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
# Report
# ---------------------------------------------------------------------------
echo
echo "NOT RUN HERE -- phases D-H land at SF-7b:"
echo "  D  rebuild on the documented command (image identity, not PACK_SET_HASH -- Deviation 12)"
echo "  E  load/unload, T14 (packs toggled on the same base; rides D's mutation window)"
echo "  F  build-time only, T33 and T15, including the vendored-installer residual"
echo "  G  mounts, T21 and T23 -- and the SC-3 project mount asserted against docker inspect"
echo "  H  registry reach, T31"
echo
echo "${PASSED} PASS ${FAILED} FAIL"
if [ "$FAILED" -eq 0 ]; then
  echo "PHASES A-C PASSED"
  exit 0
fi
echo "PHASES A-C FAILED"
exit 1
