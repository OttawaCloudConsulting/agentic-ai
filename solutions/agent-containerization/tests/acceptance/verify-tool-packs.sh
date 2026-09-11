#!/usr/bin/env bash
# Acceptance test for Feature 02.3 (Tool pack set, use-case profiles and MCP inventory).
#
# Phase A (this file, SF-1): the pack manifest schema additions -- `env`, `credentials`,
# `third_parties`, and the unknown-top-level-key refusal. Host-only: no docker, no pod.
# Later sub-features append Phases B-G to this same file, following 01.5's
# verify-pack-composition.sh idiom of one growing harness rather than one script per SF.
#
# Requires: yq (mikefarah/yq), git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
phase() { echo; echo "=== Phase $1 -- $2"; }

command -v yq  >/dev/null 2>&1 || { echo "verify-tool-packs: yq is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "verify-tool-packs: git is required" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Scaffolding -- the sf7-probe idiom from verify-pack-composition.sh (01.5)
# ---------------------------------------------------------------------------

PACK_SRC="packs/language-runtimes/pack.yaml"
PROBE_PACK_DIR="packs/sf7-probe"
PROBE_PACK="${PROBE_PACK_DIR}/pack.yaml"
PROBE_PACK2_DIR="packs/sf7-probe-2"
PROBE_PACK2="${PROBE_PACK2_DIR}/pack.yaml"
PROBE_PROFILE="profiles/sf7-probe.yaml"

for p in "$PROBE_PACK_DIR" "$PROBE_PACK2_DIR" "$PROBE_PROFILE"; do
  [ ! -e "$p" ] || {
    echo "verify-tool-packs: $p already exists; remove it before running" >&2
    exit 1
  }
done

cleanup() { rm -rf "$PROBE_PACK_DIR" "$PROBE_PACK2_DIR" "$PROBE_PROFILE"; }
trap cleanup EXIT

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

make_probe_pack() {
  local expr="$1" dir="${2:-$PROBE_PACK_DIR}" name="${3:-sf7-probe}"
  mkdir -p "$dir"
  yq eval "$expr" "$PACK_SRC" > "$dir/pack.yaml"
  if [ "$(yq eval 'has("name")' "$dir/pack.yaml")" = "true" ]; then
    yq eval -i ".name = \"$name\"" "$dir/pack.yaml"
  fi
}

make_probe_profile() {
  local expr="$1"
  yq eval "$expr" "profiles/default.yaml" > "$PROBE_PROFILE"
}

compile_probe() {
  bash scripts/compile-policy.sh --profile sf7-probe --out "$(mktemp)" "$@"
}

# ---------------------------------------------------------------------------
# Phase A -- SF-1: env, credentials, third_parties, unknown-key refusal
# ---------------------------------------------------------------------------
phase A "pack manifest schema: env, credentials, third_parties, unknown-key refusal"

expect 0 "" "A: lint-policy.sh accepts the tree as shipped (env/credentials/third_parties well-formed)" \
  bash scripts/lint-policy.sh

# Acceptance Criterion 1: `third_parties` joins the mandatory field set.
make_probe_pack 'del(.third_parties)'
expect 1 "packs/sf7-probe/pack.yaml: mandatory field 'third_parties' is missing" \
  "A: manifest without 'third_parties' is refused, naming file and field" \
  bash scripts/lint-policy.sh
rm -rf "$PROBE_PACK_DIR"

# Criterion 2 -- mounts: still refused, message corrected (no longer claims a stale
# "land at 01.5 SF-5"; now names the R2.8 review path).
make_probe_pack '.mounts = [{"project": null}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "is a design change reviewed against R2.8's enumeration" \
  "A: a populated 'mounts' is still refused, with the corrected message" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# Criterion 2 -- env: reserved name refused (Interface Contract 1).
make_probe_pack '.env = [{"name": "PATH", "value": "x", "reason": "probe"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "which the pod contract already sets" \
  "A: an env entry naming a reserved variable (PATH) is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# env: name not matching the schema regex is an input-validation failure (exit 2), not a
# policy refusal (exit 3) -- it is malformed, not a decision the operator made.
make_probe_pack '.env = [{"name": "not-a-valid-name", "value": "x", "reason": "probe"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "does not match" \
  "A: an env entry with a malformed name is an input-validation failure" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# env: missing 'reason' is refused.
make_probe_pack '.env = [{"name": "SF7_PROBE_VAR", "value": "x"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "env[0].reason is missing" \
  "A: an env entry with no 'reason' is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# env: the same variable declared by two selected packs is refused (Interface Contract 1's
# duplicate rule), not silently resolved by whichever pack composed last.
make_probe_pack '.env = [{"name": "SF7_DUP_VAR", "value": "a", "reason": "probe one"}]' "$PROBE_PACK_DIR" sf7-probe
make_probe_pack '.env = [{"name": "SF7_DUP_VAR", "value": "b", "reason": "probe two"}]' "$PROBE_PACK2_DIR" sf7-probe-2
make_probe_profile '.packs = ["sf7-probe", "sf7-probe-2"]'
expect 3 "already declared by packs/sf7-probe/pack.yaml" \
  "A: an env variable declared by two selected packs is refused, naming both sources" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PACK2_DIR" "$PROBE_PROFILE"

# credentials: both delivery forms at once is refused (exactly one of env|path_env).
make_probe_pack '.credentials = [{"name": "sf7-probe-cred", "delivery": {"env": "SF7_TOK", "path_env": "SF7_PATH"}, "description": "d", "blast_radius": "b", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "delivery must be exactly one of" \
  "A: a credential declaring both 'env' and 'path_env' delivery is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# credentials: a missing prose field (blast_radius) is refused.
make_probe_pack '.credentials = [{"name": "sf7-probe-cred", "delivery": {"env": "SF7_TOK"}, "description": "d", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "credentials[0].blast_radius is missing" \
  "A: a credential missing 'blast_radius' is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# credentials: a name duplicated within one pack is refused.
make_probe_pack '.credentials = [{"name": "dup", "delivery": {"env": "SF7_A"}, "description": "d", "blast_radius": "b", "revocation": "r"}, {"name": "dup", "delivery": {"env": "SF7_B"}, "description": "d", "blast_radius": "b", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "declares 'dup' twice" \
  "A: a credential name duplicated within a pack is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# third_parties: required non-empty iff egress.runtime is non-empty (R14.1).
make_probe_pack '.egress.runtime.allow_fqdns = [{"fqdn": "sf7-probe.example", "port": 443, "upgrade": false}] | .runtime_install = true | .runtime_install_reason = "probe"'
make_probe_profile '.packs = ["sf7-probe"]'
expect 3 "but an empty third_parties" \
  "A: non-empty egress.runtime with an empty third_parties is refused (R14.1)" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# third_parties: an unresolvable record anchor is refused by lint-policy.sh (well-formedness
# of the reference, not a compile-time policy decision).
make_probe_pack '.third_parties = [{"party": "Nobody", "record": "docs/records/third-party-assessments.md#sf7-nonexistent-anchor"}]'
expect 1 "does not resolve -- no id=\"sf7-nonexistent-anchor\" anchor" \
  "A: a third_parties record whose anchor does not exist is refused" \
  bash scripts/lint-policy.sh
rm -rf "$PROBE_PACK_DIR"

# Unknown top-level key (R7.8): a pack manifest cannot carry cap_add, privileged or devices
# by adding an unrecognised key, silently or otherwise.
make_probe_pack '.cap_add = ["NET_ADMIN"]'
make_probe_profile '.packs = ["sf7-probe"]'
expect 2 "unrecognised top-level key 'cap_add'" \
  "A: an unrecognised top-level manifest key (cap_add) is refused" \
  compile_probe
rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"


# ---------------------------------------------------------------------------
# Phase B -- SF-2: pack env/credential delivery (entrypoint export + map,
#            check-profile-compose.sh)
# ---------------------------------------------------------------------------
phase B "pack env/credential delivery -- entrypoint, check-profile-compose.sh"

command -v docker >/dev/null 2>&1 || { echo "verify-tool-packs: docker is required for Phase B" >&2; exit 1; }
grep -n '^AGENT_BASE_DIGEST=' compose/pins.env >/dev/null \
  || { echo "verify-tool-packs: AGENT_BASE_DIGEST not found in compose/pins.env" >&2; exit 1; }
AGENT_BASE_DIGEST="$(sed -n 's/^AGENT_BASE_DIGEST=//p' compose/pins.env | tail -n1)"
# NODE_BASE_DIGEST has no default either (02.4 SF-1) -- BuildKit parses every FROM in
# the file before pruning to --target, so pack-plan/agent-base's FROM lines still need
# it even though --target agent-packs never builds those stages.
grep -n '^NODE_BASE_DIGEST=' compose/pins.env >/dev/null \
  || { echo "verify-tool-packs: NODE_BASE_DIGEST not found in compose/pins.env" >&2; exit 1; }
NODE_BASE_DIGEST="$(sed -n 's/^NODE_BASE_DIGEST=//p' compose/pins.env | tail -n1)"

B_TMP="$(mktemp -d)"
B_CREDS_DIR="$B_TMP/credentials"
B_IMAGE="verify-tool-packs-sf7-probe:agent-packs"
mkdir -p "$B_CREDS_DIR/sf7-probe/sf7-probe"
printf 'probe-secret-value' > "$B_CREDS_DIR/sf7-probe/sf7-probe/probe-cred"

b_cleanup() {
  docker rmi -f "$B_IMAGE" >/dev/null 2>&1 || true
  rm -rf "$B_TMP"
}
trap 'cleanup; b_cleanup' EXIT

make_probe_pack '.env = [{"name": "SF7_PROBE_ENV", "value": "probe-value", "reason": "Phase B probe"}] | .credentials = [{"name": "probe-cred", "delivery": {"env": "SF7_PROBE_CRED"}, "description": "d", "blast_radius": "b", "revocation": "r"}]'
make_probe_profile '.packs = ["sf7-probe"]'

expect 1 "no compose/overrides/sf7-probe.yaml" \
  "B: check-profile-compose.sh refuses a profile with no same-named override" \
  bash scripts/check-profile-compose.sh --profile sf7-probe

expect 0 "ok -- secret set matches the manifests, no other drift from default" \
  "B: check-profile-compose.sh accepts 'default' against itself" \
  bash scripts/check-profile-compose.sh --profile default

if docker build -f images/Dockerfile --target agent-packs \
     --build-arg "AGENT_BASE_DIGEST=${AGENT_BASE_DIGEST}" \
     --build-arg "NODE_BASE_DIGEST=${NODE_BASE_DIGEST}" --build-arg PROFILE=sf7-probe \
     -t "$B_IMAGE" . > "$B_TMP/build.log" 2>&1; then
  pass "B: agent-packs image builds for a profile carrying a pack env + credential"
else
  fail "B: agent-packs image failed to build for the probe profile"
  tail -20 "$B_TMP/build.log" | sed 's/^/      /'
fi

# The variable is exported, and the credential's CONTENT lands in the delivery.env
# variable -- from a secret this run mounts, never from the plan file itself (the
# plan carries only the delivery FORM, never a value).
OUT="$(docker run --rm -v "$B_CREDS_DIR/sf7-probe/sf7-probe/probe-cred:/run/secrets/pack-sf7-probe-probe-cred:ro" "$B_IMAGE" env 2>&1)" || true
if grep -qF 'SF7_PROBE_ENV=probe-value' <<< "$OUT" && grep -qF 'SF7_PROBE_CRED=probe-secret-value' <<< "$OUT"; then
  pass "B: the pack env variable and the mapped credential are present under the loading profile"
else
  fail "B: expected SF7_PROBE_ENV and SF7_PROBE_CRED in the container environment"
  grep -E 'SF7_PROBE' <<< "$OUT" | sed 's/^/      found: /' || echo "      (neither found)"
fi

# The entrypoint asserts presence a second time, at the point of use: a declared
# credential with no mounted secret refuses the start rather than running without it.
RC=0
NO_SECRET_OUT="$(docker run --rm "$B_IMAGE" env 2>&1)" || RC=$?
if [ "$RC" -eq 3 ] && grep -qF "declared credential secret 'pack-sf7-probe-probe-cred' is absent" <<< "$NO_SECRET_OUT"; then
  pass "B: starting the profile with the declared secret unmounted refuses at exit 3, naming the secret"
else
  fail "B: expected exit 3 naming the absent secret, got exit $RC"
  printf '%s\n' "$NO_SECRET_OUT" | head -3 | sed 's/^/      /'
fi

# And under a profile that does not load the pack, neither name resolves at all --
# the reference pack (`default`) carries no env and no credential, so this is the
# `default` build already on disk, not a rebuild.
DEFAULT_OUT="$(docker run --rm sandboxed-agent/claude:local env 2>&1)" || true
if grep -qF 'SF7_PROBE_ENV' <<< "$DEFAULT_OUT" || grep -qF 'SF7_PROBE_CRED' <<< "$DEFAULT_OUT"; then
  fail "B: SF7_PROBE_ENV/SF7_PROBE_CRED leaked into the default profile's image, which loads no pack declaring them"
else
  pass "B: neither name resolves under 'default', which does not load the probe pack"
fi

# ---------------------------------------------------------------------------
# Phase C -- SF-3: T14 recorded acceptance, on Terraform (Decision 4)
# ---------------------------------------------------------------------------
phase C "Terraform pack, T14 recorded acceptance (Decision 4)"

C_TMP="$(mktemp -d)"
trap 'cleanup; b_cleanup 2>/dev/null || true; rm -rf "$C_TMP"' EXIT

C_AT="2026-01-01T00:00:00Z"
COMPILED_AT="$C_AT" bash scripts/compile-policy.sh --profile default   --out "$C_TMP/default.yaml"
COMPILED_AT="$C_AT" bash scripts/compile-policy.sh --profile terraform --out "$C_TMP/terraform.yaml"

# Decision 4's rule, per agent: entries(profile+P)[a] - entries(profile)[a] == P.runtime -
# base[a], and the reverse difference is empty. No base agent carries a HashiCorp host, so
# P.runtime - base[a] = P.runtime for all three -- the clean case the plan names.
TF_RUNTIME="$(yq eval '.egress.runtime.allow_fqdns[].fqdn' packs/terraform/pack.yaml | LC_ALL=C sort -u)"
t14_ok=1
for a in claude codex agy; do
  base_set="$(yq eval ".agents.${a}.allow_fqdns[].fqdn" "$C_TMP/default.yaml" | LC_ALL=C sort -u)"
  tf_set="$(yq eval ".agents.${a}.allow_fqdns[].fqdn" "$C_TMP/terraform.yaml" | LC_ALL=C sort -u)"
  gained="$(comm -13 <(printf '%s\n' "$base_set") <(printf '%s\n' "$tf_set") 2>/dev/null || true)"
  lost="$(comm -23 <(printf '%s\n' "$base_set") <(printf '%s\n' "$tf_set") 2>/dev/null || true)"
  if [ -n "$lost" ]; then
    t14_ok=0
    echo "      C: agent '${a}' lost entries loading terraform, expected none:" >&2
    sed 's/^/        /' <<< "$lost" >&2
  fi
  if [ "$gained" != "$TF_RUNTIME" ]; then
    t14_ok=0
    echo "      C: agent '${a}' gained set does not equal packs/terraform/pack.yaml's egress.runtime" >&2
    diff <(printf '%s\n' "$TF_RUNTIME") <(printf '%s\n' "$gained") | sed 's/^/        /' >&2
  fi
done
if [ "$t14_ok" = 1 ]; then
  pass "C: T14 -- terraform gains exactly its declared egress.runtime and loses nothing, per agent"
else
  fail "C: T14 -- gained/lost set does not match Decision 4's rule"
fi

# The no-residue check: remove the pack from a probe copy of `terraform` and recompile
# under the NAME 'default' (via --profile-file) -- byte-identical to `default` apart from
# `compiled_from` (which carries the scratch file's own path) and `compiled_at`, both
# already pinned above.
C_PROBE="$C_TMP/terraform-without-pack.yaml"
yq eval '.packs = ["language-runtimes"]' profiles/terraform.yaml > "$C_PROBE"
COMPILED_AT="$C_AT" bash scripts/compile-policy.sh --profile default --profile-file "$C_PROBE" --out "$C_TMP/terraform-removed.yaml"

# The header's generated "# Edit ... <profile>, then recompile." comment line also names
# the profile file -- excluded here for the same reason `compiled_from` is: it is
# provenance, not resolved policy, and the probe recompiles from a scratch path by
# construction.
if diff -u \
     <(yq eval 'del(.compiled_from)' "$C_TMP/default.yaml" | grep -v '^# Edit ') \
     <(yq eval 'del(.compiled_from)' "$C_TMP/terraform-removed.yaml" | grep -v '^# Edit ') > "$C_TMP/residue.diff"; then
  pass "C: T14 no-residue -- removing the pack from a probe copy of terraform recompiles byte-identical to default"
else
  fail "C: T14 no-residue -- probe-removed artifact differs from default apart from compiled_from"
  sed 's/^/      /' "$C_TMP/residue.diff" >&2
fi

rm -rf "$PROBE_PACK_DIR" "$PROBE_PROFILE"

# ---------------------------------------------------------------------------
# Phase D -- SF-3: SC-6, the live default -> terraform -> default switch
# ---------------------------------------------------------------------------
phase D "terraform profile, SC-6 live switch (default -> terraform -> default)"

D_PROJECT="sf3-sc6-$$"
D_COMPOSE_BASE=(docker compose --env-file compose/pins.env -f compose/compose.yaml -p "$D_PROJECT")

d_cleanup() {
  AGENT_PROFILE=default "${D_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml down -v --remove-orphans >/dev/null 2>&1 || true
}
trap 'cleanup; b_cleanup 2>/dev/null || true; rm -rf "$C_TMP"; d_cleanup' EXIT

med_d() { docker exec "${D_PROJECT}-egress-mediator-1" "$@"; }

live_packs() {
  local profile="$1"
  med_d yq eval ".compiled_from.packs[].name" "/etc/mediator/policy/${profile}.yaml" 2>/dev/null | LC_ALL=C sort -u | tr '\n' ' '
}

# --- default -> terraform ---------------------------------------------------
AGENT_PROFILE=terraform "${D_COMPOSE_BASE[@]}" -f compose/overrides/terraform.yaml \
  up -d --build --force-recreate egress-mediator >"$C_TMP/d-mediator-terraform.log" 2>&1 \
  || { fail "D: mediator failed to start under profile 'terraform'"; sed 's/^/      /' "$C_TMP/d-mediator-terraform.log" | tail -20; }

LIVE_TF="$(live_packs terraform)"
if [ "$LIVE_TF" = "language-runtimes terraform " ]; then
  pass "D: mediator's live policy under 'terraform' reports the pack set {language-runtimes, terraform}"
else
  fail "D: expected live pack set 'language-runtimes terraform', got '${LIVE_TF}'"
fi

TF_RUN_OUT="$(AGENT_PROFILE=terraform "${D_COMPOSE_BASE[@]}" -f compose/overrides/terraform.yaml \
  run --build --rm claude sh -c 'terraform version' 2>&1)" || true
if grep -qF 'Terraform v1.16.2' <<< "$TF_RUN_OUT"; then
  pass "D: terraform binary present and runs under profile 'terraform'"
else
  fail "D: expected 'Terraform v1.16.2' from the terraform profile's claude container"
  printf '%s\n' "$TF_RUN_OUT" | tail -5 | sed 's/^/      /'
fi

# --- terraform -> default (SC-6 requires the return leg measured too) ------
AGENT_PROFILE=default "${D_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  up -d --build --force-recreate egress-mediator >"$C_TMP/d-mediator-default.log" 2>&1 \
  || { fail "D: mediator failed to start under profile 'default'"; sed 's/^/      /' "$C_TMP/d-mediator-default.log" | tail -20; }

LIVE_DEF="$(live_packs default)"
if [ "$LIVE_DEF" = "language-runtimes " ]; then
  pass "D: mediator's live policy is back to {language-runtimes} after switching to 'default'"
else
  fail "D: expected live pack set 'language-runtimes' after the return leg, got '${LIVE_DEF}'"
fi

TF_GONE_OUT="$(AGENT_PROFILE=default "${D_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  run --build --rm claude sh -c 'command -v terraform' 2>&1)" || true
if [ -z "$TF_GONE_OUT" ] || ! grep -qF '/terraform' <<< "$TF_GONE_OUT"; then
  pass "D: terraform binary absent under 'default' after the switch back"
else
  fail "D: terraform binary still present under 'default': $TF_GONE_OUT"
fi

d_cleanup

# ---------------------------------------------------------------------------
# Phase E -- SF-4: GitHub CLI pack, R8.2 inspection, overlap case, R8.6 redaction
# ---------------------------------------------------------------------------
phase E "GitHub CLI pack -- overlap case, GH_TOKEN delivery, R8.6 redaction"

E_TMP="$(mktemp -d)"
E_CREDS_DIR="$E_TMP/credentials"
mkdir -p "$E_CREDS_DIR/github/github-cli"
E_TOKEN_VALUE="ghp_probeTokenValueNotReal0123456789"
printf '%s' "$E_TOKEN_VALUE" > "$E_CREDS_DIR/github/github-cli/github-token"

e_cleanup() { rm -rf "$E_TMP"; }
trap 'cleanup; b_cleanup 2>/dev/null || true; d_cleanup 2>/dev/null || true; e_cleanup' EXIT

# --- the overlap case (Decision 4): codex gains nothing, claude/agy gain both hosts --------
E_COMPILE_AT="2026-01-01T00:00:00Z"
COMPILED_AT="$E_COMPILE_AT" bash scripts/compile-policy.sh --profile default --out "$E_TMP/default.yaml"
COMPILED_AT="$E_COMPILE_AT" bash scripts/compile-policy.sh --profile github  --out "$E_TMP/github.yaml"

GH_RUNTIME="$(yq eval '.egress.runtime.allow_fqdns[].fqdn' packs/github-cli/pack.yaml | LC_ALL=C sort -u)"
overlap_ok=1
for a in claude codex agy; do
  base_set="$(yq eval ".agents.${a}.allow_fqdns[].fqdn" "$E_TMP/default.yaml" | LC_ALL=C sort -u)"
  gh_set="$(yq eval ".agents.${a}.allow_fqdns[].fqdn" "$E_TMP/github.yaml" | LC_ALL=C sort -u)"
  gained="$(comm -13 <(printf '%s\n' "$base_set") <(printf '%s\n' "$gh_set") 2>/dev/null || true)"
  lost="$(comm -23 <(printf '%s\n' "$base_set") <(printf '%s\n' "$gh_set") 2>/dev/null || true)"
  if [ -n "$lost" ]; then
    overlap_ok=0
    echo "      E: agent '${a}' lost entries loading github-cli, expected none:" >&2
    sed 's/^/        /' <<< "$lost" >&2
  fi
  if [ "$a" = "codex" ]; then
    # codex's base already carries both hosts (allowlist.base.yaml) -- Decision 4's overlap
    # case: the gained set is empty, not github-cli's full egress.runtime.
    if [ -n "$gained" ]; then
      overlap_ok=0
      echo "      E: agent 'codex' expected to gain nothing (base already carries both hosts), gained:" >&2
      sed 's/^/        /' <<< "$gained" >&2
    fi
  else
    if [ "$gained" != "$GH_RUNTIME" ]; then
      overlap_ok=0
      echo "      E: agent '${a}' gained set does not equal packs/github-cli/pack.yaml's egress.runtime" >&2
      diff <(printf '%s\n' "$GH_RUNTIME") <(printf '%s\n' "$gained") | sed 's/^/        /' >&2
    fi
  fi
done
if [ "$overlap_ok" = 1 ]; then
  pass "E: Decision 4 overlap case -- codex gains nothing, claude/agy gain both github-cli hosts"
else
  fail "E: overlap case -- gained/lost set does not match Decision 4's rule"
fi

# --- GH_TOKEN present under 'github', absent under 'default' and 'terraform' ---------------
E_PROJECT="sf4-github-$$"
E_COMPOSE_BASE=(docker compose --env-file compose/pins.env -f compose/compose.yaml -p "$E_PROJECT")

e_stack_down() {
  local profile="$1" override="$2"
  AGENT_PROFILE="$profile" "${E_COMPOSE_BASE[@]}" -f "compose/overrides/${override}.yaml" \
    down -v --remove-orphans >/dev/null 2>&1 || true
}
trap 'cleanup; b_cleanup 2>/dev/null || true; d_cleanup 2>/dev/null || true; e_cleanup; e_stack_down default default; e_stack_down terraform terraform; e_stack_down github github' EXIT

# Following Phase D's idiom: agent containers' default command is the interactive agent CLI,
# which exits immediately under `up -d` with no TTY/session -- only the mediator is brought up
# as a daemon, and each agent check runs as a one-shot `run --rm`.
#
# `build` runs as its OWN step, separate from `run`: this build driver writes its progress to
# STDOUT (not stderr), so a combined `run --build --rm ... | capture` would splice that progress
# into the captured value. Building first, then running without `--build`, keeps the captured
# stdout to exactly what the container printed.
PACK_CREDENTIALS_DIR="$E_CREDS_DIR" AGENT_PROFILE=github "${E_COMPOSE_BASE[@]}" -f compose/overrides/github.yaml \
  build egress-mediator claude codex agy >"$E_TMP/e-github-build.log" 2>&1 \
  || { fail "E: image build failed under profile 'github'"; tail -20 "$E_TMP/e-github-build.log" | sed 's/^/      /'; }
PACK_CREDENTIALS_DIR="$E_CREDS_DIR" AGENT_PROFILE=github "${E_COMPOSE_BASE[@]}" -f compose/overrides/github.yaml \
  up -d --force-recreate egress-mediator >"$E_TMP/e-github.log" 2>&1 \
  || { fail "E: mediator failed to start under profile 'github'"; sed 's/^/      /' "$E_TMP/e-github.log" | tail -20; }

e_gh_ok=1
for a in claude codex agy; do
  TOK_OUT="$(PACK_CREDENTIALS_DIR="$E_CREDS_DIR" AGENT_PROFILE=github "${E_COMPOSE_BASE[@]}" -f compose/overrides/github.yaml \
    run --rm "$a" sh -c 'printf "%s" "$GH_TOKEN"' 2>/dev/null)" || true
  if [ "$TOK_OUT" != "$E_TOKEN_VALUE" ]; then
    e_gh_ok=0
    fail "E: GH_TOKEN not present (or wrong) in '${a}' under profile 'github', got: ${TOK_OUT}"
  fi
done
[ "$e_gh_ok" = 1 ] && pass "E: GH_TOKEN present and correct in every agent under profile 'github'"

GH_VER_OUT="$(PACK_CREDENTIALS_DIR="$E_CREDS_DIR" AGENT_PROFILE=github "${E_COMPOSE_BASE[@]}" -f compose/overrides/github.yaml \
  run --rm claude sh -c 'GH_NO_UPDATE_NOTIFIER=1 gh --version' 2>/dev/null)" || true
if grep -qF 'gh version 2.100.0' <<< "$GH_VER_OUT"; then
  pass "E: gh binary present and reports the pinned version under profile 'github'"
else
  fail "E: expected 'gh version 2.100.0', got: ${GH_VER_OUT}"
fi

e_stack_down github github

AGENT_PROFILE=default "${E_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  build egress-mediator claude codex agy >"$E_TMP/e-default-build.log" 2>&1 \
  || { fail "E: image build failed under profile 'default'"; tail -20 "$E_TMP/e-default-build.log" | sed 's/^/      /'; }
AGENT_PROFILE=default "${E_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  up -d --force-recreate egress-mediator >"$E_TMP/e-default.log" 2>&1 \
  || { fail "E: mediator failed to start under profile 'default'"; sed 's/^/      /' "$E_TMP/e-default.log" | tail -20; }
DEF_TOK_OUT="$(AGENT_PROFILE=default "${E_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  run --rm claude sh -c 'printf "%s" "${GH_TOKEN:-}"' 2>/dev/null)" || true
[ -z "$DEF_TOK_OUT" ] \
  && pass "E: GH_TOKEN absent under profile 'default'" \
  || fail "E: GH_TOKEN unexpectedly present under 'default': ${DEF_TOK_OUT}"
e_stack_down default default

AGENT_PROFILE=terraform "${E_COMPOSE_BASE[@]}" -f compose/overrides/terraform.yaml \
  build egress-mediator claude codex agy >"$E_TMP/e-terraform-build.log" 2>&1 \
  || { fail "E: image build failed under profile 'terraform'"; tail -20 "$E_TMP/e-terraform-build.log" | sed 's/^/      /'; }
AGENT_PROFILE=terraform "${E_COMPOSE_BASE[@]}" -f compose/overrides/terraform.yaml \
  up -d --force-recreate egress-mediator >"$E_TMP/e-terraform.log" 2>&1 \
  || { fail "E: mediator failed to start under profile 'terraform'"; sed 's/^/      /' "$E_TMP/e-terraform.log" | tail -20; }
TF_TOK_OUT="$(AGENT_PROFILE=terraform "${E_COMPOSE_BASE[@]}" -f compose/overrides/terraform.yaml \
  run --rm claude sh -c 'printf "%s" "${GH_TOKEN:-}"' 2>/dev/null)" || true
[ -z "$TF_TOK_OUT" ] \
  && pass "E: GH_TOKEN absent under profile 'terraform'" \
  || fail "E: GH_TOKEN unexpectedly present under 'terraform': ${TF_TOK_OUT}"
e_stack_down terraform terraform

# --- R8.6: extend the redaction pattern set to GitHub token formats (Decision 8, SF-5's --
#     pattern), asserted against a synthetic transcript line, so no live session is spent ---
E_REDACT_FN="$(sed -n '/^redact_for_relay() {/,/^}/p' images/recorder/recorder.sh)"
if [ -z "$E_REDACT_FN" ]; then
  fail "E: could not extract redact_for_relay() from images/recorder/recorder.sh"
else
  eval "$E_REDACT_FN"
  e_redact_ok=1
  for prefix_line in \
    'ghp_probeTokenValueNotReal0123456789' \
    'github_pat_11ABCDEFG0probeTokenValueNotReal' \
    'gho_probeTokenValueNotReal0123456789'; do
    synth='{"type":"tool_call","proxy":"none","echo":"GH_TOKEN='"$prefix_line"'"}'
    out="$(redact_for_relay "$synth")"
    if grep -qF "$prefix_line" <<< "$out"; then
      e_redact_ok=0
      echo "      E: token '${prefix_line}' was NOT redacted: $out" >&2
    elif ! grep -q '<redacted:' <<< "$out"; then
      e_redact_ok=0
      echo "      E: token '${prefix_line}' vanished without a <redacted:...> marker: $out" >&2
    fi
  done
  [ "$e_redact_ok" = 1 ] \
    && pass "E: R8.6 -- ghp_/github_pat_/gho_ token formats are redacted on the relay" \
    || fail "E: R8.6 -- one or more GitHub token formats were not redacted correctly"
fi

# ---------------------------------------------------------------------------
# Phase F -- SF-5: Kubernetes pack, KUBECONFIG delivery, cluster-pack mechanism
# ---------------------------------------------------------------------------
phase F "Kubernetes pack -- kubectl/helm, KUBECONFIG delivery, cluster-pack mechanism"

F_TMP="$(mktemp -d)"
F_CREDS_DIR="$F_TMP/credentials"
mkdir -p "$F_CREDS_DIR/kubernetes/kubernetes"
F_KUBECONFIG_VALUE="apiVersion: v1
kind: Config
clusters: []
probe-marker: sf5-probe-not-a-real-kubeconfig"
printf '%s' "$F_KUBECONFIG_VALUE" > "$F_CREDS_DIR/kubernetes/kubernetes/kubeconfig"

f_cleanup() { rm -rf "$F_TMP"; }
trap 'cleanup; b_cleanup 2>/dev/null || true; d_cleanup 2>/dev/null || true; e_cleanup 2>/dev/null || true; f_cleanup' EXIT

F_PROJECT="sf5-kubernetes-$$"
F_COMPOSE_BASE=(docker compose --env-file compose/pins.env -f compose/compose.yaml -p "$F_PROJECT")

f_stack_down() {
  local profile="$1" override="$2"
  AGENT_PROFILE="$profile" "${F_COMPOSE_BASE[@]}" -f "compose/overrides/${override}.yaml" \
    down -v --remove-orphans >/dev/null 2>&1 || true
}
trap 'cleanup; b_cleanup 2>/dev/null || true; d_cleanup 2>/dev/null || true; e_cleanup 2>/dev/null || true; f_cleanup; f_stack_down kubernetes kubernetes; f_stack_down default default' EXIT

# --- KUBECONFIG resolves to the :ro secret path under 'kubernetes' only -------------------
PACK_CREDENTIALS_DIR="$F_CREDS_DIR" AGENT_PROFILE=kubernetes "${F_COMPOSE_BASE[@]}" -f compose/overrides/kubernetes.yaml \
  build egress-mediator claude codex agy >"$F_TMP/f-kubernetes-build.log" 2>&1 \
  || { fail "F: image build failed under profile 'kubernetes'"; tail -20 "$F_TMP/f-kubernetes-build.log" | sed 's/^/      /'; }
PACK_CREDENTIALS_DIR="$F_CREDS_DIR" AGENT_PROFILE=kubernetes "${F_COMPOSE_BASE[@]}" -f compose/overrides/kubernetes.yaml \
  up -d --force-recreate egress-mediator >"$F_TMP/f-kubernetes.log" 2>&1 \
  || { fail "F: mediator failed to start under profile 'kubernetes'"; sed 's/^/      /' "$F_TMP/f-kubernetes.log" | tail -20; }

f_kc_ok=1
for a in claude codex agy; do
  KC_PATH_OUT="$(PACK_CREDENTIALS_DIR="$F_CREDS_DIR" AGENT_PROFILE=kubernetes "${F_COMPOSE_BASE[@]}" -f compose/overrides/kubernetes.yaml \
    run --rm "$a" sh -c 'printf "%s" "$KUBECONFIG"' 2>/dev/null)" || true
  if [ "$KC_PATH_OUT" != "/run/secrets/pack-kubernetes-kubeconfig" ]; then
    f_kc_ok=0
    fail "F: KUBECONFIG not resolving to the expected secret path in '${a}', got: ${KC_PATH_OUT}"
    continue
  fi
  KC_CONTENT_OUT="$(PACK_CREDENTIALS_DIR="$F_CREDS_DIR" AGENT_PROFILE=kubernetes "${F_COMPOSE_BASE[@]}" -f compose/overrides/kubernetes.yaml \
    run --rm "$a" sh -c 'cat "$KUBECONFIG"' 2>/dev/null)" || true
  if [ "$KC_CONTENT_OUT" != "$F_KUBECONFIG_VALUE" ]; then
    f_kc_ok=0
    fail "F: KUBECONFIG path in '${a}' does not resolve to the staged content"
  fi
  KC_RO_OUT="$(PACK_CREDENTIALS_DIR="$F_CREDS_DIR" AGENT_PROFILE=kubernetes "${F_COMPOSE_BASE[@]}" -f compose/overrides/kubernetes.yaml \
    run --rm "$a" sh -c 'echo overwritten > "$KUBECONFIG" 2>&1; echo "rc=$?"' 2>/dev/null)" || true
  if ! grep -qE 'rc=([1-9][0-9]*)' <<< "$KC_RO_OUT"; then
    f_kc_ok=0
    fail "F: writing to the mounted kubeconfig secret in '${a}' did not fail as expected (:ro)"
  fi
done
[ "$f_kc_ok" = 1 ] && pass "F: KUBECONFIG resolves to the :ro secret path with the staged content in every agent under 'kubernetes'"

# --- kubectl and helm binaries present and pinned ------------------------------------------
KUBECTL_OUT="$(PACK_CREDENTIALS_DIR="$F_CREDS_DIR" AGENT_PROFILE=kubernetes "${F_COMPOSE_BASE[@]}" -f compose/overrides/kubernetes.yaml \
  run --rm claude sh -c 'kubectl version --client -o json' 2>/dev/null)" || true
if grep -qE '"gitVersion": *"v1\.31\.2"' <<< "$KUBECTL_OUT"; then
  pass "F: kubectl binary present and reports the pinned version under profile 'kubernetes'"
else
  fail "F: expected kubectl gitVersion v1.31.2, got: ${KUBECTL_OUT}"
fi

HELM_OUT="$(PACK_CREDENTIALS_DIR="$F_CREDS_DIR" AGENT_PROFILE=kubernetes "${F_COMPOSE_BASE[@]}" -f compose/overrides/kubernetes.yaml \
  run --rm claude sh -c 'helm version --template "{{.Version}}"' 2>/dev/null)" || true
if [ "$HELM_OUT" = "v3.16.2" ]; then
  pass "F: helm binary present and reports the pinned version under profile 'kubernetes'"
else
  fail "F: expected helm version v3.16.2, got: ${HELM_OUT}"
fi

f_stack_down kubernetes kubernetes

# --- KUBECONFIG absent under 'default' (which loads no pack declaring it) -----------------
AGENT_PROFILE=default "${F_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  build egress-mediator claude codex agy >"$F_TMP/f-default-build.log" 2>&1 \
  || { fail "F: image build failed under profile 'default'"; tail -20 "$F_TMP/f-default-build.log" | sed 's/^/      /'; }
AGENT_PROFILE=default "${F_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  up -d --force-recreate egress-mediator >"$F_TMP/f-default.log" 2>&1 \
  || { fail "F: mediator failed to start under profile 'default'"; sed 's/^/      /' "$F_TMP/f-default.log" | tail -20; }
DEF_KC_OUT="$(AGENT_PROFILE=default "${F_COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
  run --rm claude sh -c 'printf "%s" "${KUBECONFIG:-}"' 2>/dev/null)" || true
[ -z "$DEF_KC_OUT" ] \
  && pass "F: KUBECONFIG absent under profile 'default'" \
  || fail "F: KUBECONFIG unexpectedly present under 'default': ${DEF_KC_OUT}"
f_stack_down default default

# --- the cluster-pack mechanism (Decision 6): a per-cluster egress-only pack adds exactly
#     its FQDN, and is refused without a resolvable third_parties anchor -------------------
F_CLUSTER_PACK_DIR="packs/sf5-cluster-probe"
F_CLUSTER_PACK="$F_CLUSTER_PACK_DIR/pack.yaml"
F_CLUSTER_PROFILE="profiles/sf5-cluster-probe.yaml"
[ ! -e "$F_CLUSTER_PACK_DIR" ] && [ ! -e "$F_CLUSTER_PROFILE" ] \
  || { echo "verify-tool-packs: $F_CLUSTER_PACK_DIR or $F_CLUSTER_PROFILE already exists; remove before running" >&2; exit 1; }

f_cluster_cleanup() { rm -rf "$F_CLUSTER_PACK_DIR" "$F_CLUSTER_PROFILE"; }
trap 'cleanup; b_cleanup 2>/dev/null || true; d_cleanup 2>/dev/null || true; e_cleanup 2>/dev/null || true; f_cleanup; f_cluster_cleanup' EXIT

mkdir -p "$F_CLUSTER_PACK_DIR"
cat > "$F_CLUSTER_PACK" <<'EOF'
name: sf5-cluster-probe
description: probe -- per-cluster egress-only pack, no third_parties yet
schema: 1
blast_radius: "probe pack for Phase F's cluster-pack mechanism test"
needs_write_access: false
packages:
  apt: {repository: profile, items: []}
  archives: []
egress:
  runtime:
    allow_fqdns:
      - {fqdn: sf5-cluster-probe.example, port: 443, upgrade: false}
    allow_cidrs: []
  build: {allow_fqdns: []}
runtime_install: true
runtime_install_reason: "probe -- a cluster API can serve arbitrary bytes (Decision 6)"
mounts: []
env: []
credentials: []
third_parties: []
EOF
printf '%s' "$(yq eval '.packs = ["language-runtimes", "kubernetes", "sf5-cluster-probe"] | .name = "sf5-cluster-probe"' profiles/kubernetes.yaml)" > "$F_CLUSTER_PROFILE"

expect 3 "but an empty third_parties" \
  "F: a per-cluster egress pack with non-empty egress.runtime and empty third_parties is refused (R14.1)" \
  bash scripts/compile-policy.sh --profile sf5-cluster-probe --out "$(mktemp)"

yq eval -i '.third_parties = [{"party": "Nobody", "record": "docs/records/third-party-assessments.md#sf5-nonexistent-anchor"}]' "$F_CLUSTER_PACK"
expect 1 "does not resolve -- no id=\"sf5-nonexistent-anchor\" anchor" \
  "F: a per-cluster egress pack whose third_parties anchor does not resolve is refused by lint-policy.sh" \
  bash scripts/lint-policy.sh

yq eval -i '.third_parties = [{"party": "HashiCorp", "record": "docs/records/third-party-assessments.md#r141-hashicorp"}]' "$F_CLUSTER_PACK"
F_CLUSTER_OUT="$(mktemp)"
if bash scripts/compile-policy.sh --profile sf5-cluster-probe --out "$F_CLUSTER_OUT" >"$F_TMP/f-cluster-compile.log" 2>&1; then
  F_GAINED="$(yq eval '.agents.claude.allow_fqdns[].fqdn' "$F_CLUSTER_OUT" | LC_ALL=C sort -u)"
  F_BASE="$(yq eval '.agents.claude.allow_fqdns[].fqdn' policy/resolved/kubernetes.yaml | LC_ALL=C sort -u)"
  F_NEW="$(comm -13 <(printf '%s\n' "$F_BASE") <(printf '%s\n' "$F_GAINED") 2>/dev/null || true)"
  if [ "$F_NEW" = "sf5-cluster-probe.example" ]; then
    pass "F: a per-cluster egress pack with a resolvable third_parties anchor adds exactly its own FQDN"
  else
    fail "F: expected the cluster pack to add exactly 'sf5-cluster-probe.example', gained: '${F_NEW}'"
  fi
else
  fail "F: compile-policy.sh refused the cluster probe pack even with a resolvable third_parties anchor"
  cat "$F_TMP/f-cluster-compile.log" | sed 's/^/      /'
fi
rm -f "$F_CLUSTER_OUT"
f_cluster_cleanup

# ---------------------------------------------------------------------------
# Phase G -- SF-5: R7.8 hardening comparison across all four shipped profiles
# ---------------------------------------------------------------------------
phase G "R7.8 hardening comparison -- default, terraform, github, kubernetes"

# check-profile-compose.sh's (b) check IS the R7.8 hardening comparison (Decision 2):
# every rendered agent-service field other than `secrets` and the `PROFILE`/
# `MEDIATOR_PROFILE` build args must equal `default`'s, which covers cap_drop, cap_add,
# security_opt, read_only, user, privileged, devices, network_mode, pid, ipc and the
# resource limits named in criterion 7. Fixed at this sub-feature: `secrets_of()` was
# comparing multi-line yq output line-by-line rather than one secret name per line
# (Compose v2.38.2 normalizes every secret reference to the long {source, target} form),
# so a profile carrying any pack credential always reported a false secret-set mismatch
# and this comparison had never actually passed for 'github'.
for p in terraform github kubernetes; do
  if bash scripts/check-profile-compose.sh --profile "$p" >"$F_TMP/g-${p}.log" 2>&1; then
    pass "G: profile '${p}' -- R7.8 hardening fields and mount/limit shape match 'default' apart from secrets/PROFILE"
  else
    fail "G: profile '${p}' diverges from 'default' outside secrets/PROFILE (R7.8)"
    cat "$F_TMP/g-${p}.log" | sed 's/^/      /'
  fi
done

echo
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ]
