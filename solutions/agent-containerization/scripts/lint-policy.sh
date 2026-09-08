#!/usr/bin/env bash
# Feature 01.1 test command. Checks policy/*.yaml and packs/*/pack.yaml for well-formedness
# only -- it does NOT validate governance records (docs/records/), which are inspection tests
# (T42, T43), not lint targets. Requires yq (mikefarah/yq).
#
# 01.5 SF-1 added the pack-manifest half. It is WELL-FORMEDNESS ONLY: mandatory fields present,
# every package pinned and checksummed, no `deny_*` key. The build-time REFUSAL GATES (T27
# accepted_risk, R2.8 mount keys, R7.6 runtime-install egress, SC-3 project-mount containment)
# are the compiler's, not this script's -- they are policy decisions with their own exit code
# (compile-policy.sh exit 3), and splitting them across two scripts would put half a gate on
# the wrong side of the build.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_DIR="$REPO_ROOT/policy"
ALLOWLIST="$POLICY_DIR/allowlist.base.yaml"
DENYLIST="$POLICY_DIR/denylist.base.yaml"
RECORDS_DIR="$REPO_ROOT/docs/records"
PACKS_DIR="$REPO_ROOT/packs"

fail() { echo "lint-policy: FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "yq is required (https://github.com/mikefarah/yq)"

# --- both policy YAML files parse ---
yq eval '.' "$ALLOWLIST" >/dev/null 2>&1 || fail "$ALLOWLIST does not parse as YAML"
yq eval '.' "$DENYLIST" >/dev/null 2>&1 || fail "$DENYLIST does not parse as YAML"

# --- denylist.base.yaml contains all five required ranges (R5.6) ---
for cidr in 169.254.0.0/16 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
  yq eval ".deny_cidrs[] | select(. == \"$cidr\")" "$DENYLIST" | grep -qx "$cidr" \
    || fail "$DENYLIST missing required range $cidr"
done

# --- allowlist.base.yaml carries provisional: true ---
[[ "$(yq eval '.provisional' "$ALLOWLIST")" == "true" ]] \
  || fail "$ALLOWLIST must carry provisional: true (D17)"

# --- keyed per agent; every agent key exposes both allow_fqdns and allow_cidrs ---
AGENTS="$(yq eval '.agents | keys | .[]' "$ALLOWLIST")"
[[ -n "$AGENTS" ]] || fail "$ALLOWLIST has no agents"
while IFS= read -r agent; do
  yq eval ".agents.${agent} | has(\"allow_fqdns\")" "$ALLOWLIST" | grep -qx "true" \
    || fail "agent '$agent' missing allow_fqdns"
  yq eval ".agents.${agent} | has(\"allow_cidrs\")" "$ALLOWLIST" | grep -qx "true" \
    || fail "agent '$agent' missing allow_cidrs"
done <<< "$AGENTS"

# --- every allowlist entry carries a source annotation ---
while IFS= read -r agent; do
  count="$(yq eval ".agents.${agent}.allow_fqdns | length" "$ALLOWLIST")"
  for ((i = 0; i < count; i++)); do
    src_len="$(yq eval ".agents.${agent}.allow_fqdns[$i].source | length" "$ALLOWLIST")"
    [[ "$src_len" =~ ^[0-9]+$ ]] && ((src_len > 0)) \
      || fail "agent '$agent' allow_fqdns[$i] missing a non-empty source list"
  done
done <<< "$AGENTS"

# --- the pins: reference resolves to the SF-2 record ---
PINS_REF="$(yq eval '.pins' "$ALLOWLIST")"
[[ -f "$RECORDS_DIR/$PINS_REF" ]] || fail "pins: '$PINS_REF' does not resolve under $RECORDS_DIR"

# --------------------------------------------------------------------------------------------
# Pack manifests -- packs/<name>/pack.yaml (01.5 Interface Contract 1)
#
# Mandatory fields are R7.3's seven (packages, egress, mounts, env, credentials,
# needs_write_access, and the write-access question's companion runtime_install) plus R7.11's
# blast_radius and the manifest's own identity fields. Acceptance Criterion 1 requires a
# missing field to name the FILE and the FAILING FIELD, so every message below carries both.
# --------------------------------------------------------------------------------------------
lint_pack_manifest() {
  local f="$1" rel="${1#$REPO_ROOT/}"
  yq eval '.' "$f" >/dev/null 2>&1 || fail "$rel does not parse as YAML"

  # has(), not `// "null"`: `needs_write_access: false` and `runtime_install: false` are the
  # reference pack's correct values, and yq's alternative operator reports a legitimate `false`
  # as absent. This is the same trap 01.3 documented for `provisional` and `tls`.
  local field
  for field in name description schema blast_radius needs_write_access packages egress \
               runtime_install mounts env credentials; do
    [[ "$(yq eval "has(\"$field\")" "$f")" == "true" ]] \
      || fail "$rel: mandatory field '$field' is missing"
  done

  [[ "$(yq eval '.schema' "$f")" == "1" ]] \
    || fail "$rel: field 'schema' must be 1, found '$(yq eval '.schema' "$f")'"

  local pack_name; pack_name="$(yq eval '.name' "$f")"
  local dir_name; dir_name="$(basename "$(dirname "$f")")"
  [[ "$pack_name" == "$dir_name" ]] \
    || fail "$rel: field 'name' is '$pack_name' but the pack directory is '$dir_name'; the profile selects packs by directory name"

  for field in needs_write_access runtime_install; do
    local v; v="$(yq eval ".$field" "$f")"
    [[ "$v" == "true" || "$v" == "false" ]] \
      || fail "$rel: field '$field' must be true or false, found '$v'"
  done

  # R7.6 is "off by default and explicitly declared when used", and "explicitly" is both halves:
  # the flag AND a recorded reason. The field is mandatory only when the flag is set, so the
  # reference pack -- and every pack that behaves like it -- carries neither. The compiler
  # REFUSES the same condition at exit 3 (a policy decision); this is the well-formedness half.
  if [[ "$(yq eval '.runtime_install' "$f")" == "true" ]]; then
    # The TAG, not the rendering: yq prints an empty list as the two-character string `[]`, which
    # satisfies a `-n` test while recording nothing. The question here is whether a human wrote a
    # reason (Codex adversarial pass, 2026-09-08).
    local reason_tag; reason_tag="$(yq eval '.runtime_install_reason | tag' "$f" 2>/dev/null || echo missing)"
    local reason; reason="$(yq eval '.runtime_install_reason' "$f" 2>/dev/null || echo "")"
    [[ "$reason_tag" == "!!str" && -n "${reason//[[:space:]]/}" ]] \
      || fail "$rel: field 'runtime_install_reason' is missing, blank or not text, but 'runtime_install' is true. R7.6 requires the exception to be declared, and a flag with no recorded reason is a default flipped rather than a decision taken"
  fi

  # A pack may not carry a deny entry. Deny wins POST-resolution and is copied from
  # denylist.base.yaml unmodified; a pack-supplied `deny_*` key would look like it narrows or
  # widens the denylist and would in fact do neither, which is worse than either.
  for field in deny_fqdns deny_cidrs; do
    [[ "$(yq eval "has(\"$field\")" "$f")" == "false" ]] \
      || fail "$rel: carries '$field'. A pack cannot contribute deny entries -- the denylist is copied unmodified from policy/denylist.base.yaml"
  done

  # Every package carries a pin AND a checksum, both kinds. R7.3 is a MUST and says "checksums"
  # without qualification, so the apt items are not exempt on the argument that the signed
  # Release already covers them: that is an argument for apt being safe, not for the manifest
  # being pinned, and SC-8 measures a rebuild months later.
  local n i
  if [[ "$(yq eval '.packages | has("apt")' "$f")" == "true" ]]; then
    [[ "$(yq eval '.packages.apt | has("repository")' "$f")" == "true" ]] \
      || fail "$rel: field 'packages.apt.repository' is missing"
    n="$(yq eval '.packages.apt.items | length' "$f")"
    for ((i = 0; i < n; i++)); do
      for field in name version sha256; do
        local v; v="$(yq eval ".packages.apt.items[$i].$field // \"\"" "$f")"
        [[ -n "$v" ]] || fail "$rel: field 'packages.apt.items[$i].$field' is missing or empty"
      done
      local sum; sum="$(yq eval ".packages.apt.items[$i].sha256" "$f")"
      [[ "$sum" =~ ^[0-9a-f]{64}$ ]] \
        || fail "$rel: packages.apt.items[$i].sha256 is not 64 lowercase hex characters, found '$sum'"
    done
  fi

  if [[ "$(yq eval '.packages | has("archives")' "$f")" == "true" ]]; then
    n="$(yq eval '.packages.archives | length' "$f")"
    for ((i = 0; i < n; i++)); do
      for field in name version url sha256; do
        local v; v="$(yq eval ".packages.archives[$i].$field // \"\"" "$f")"
        [[ -n "$v" ]] || fail "$rel: field 'packages.archives[$i].$field' is missing or empty"
      done
      local sum; sum="$(yq eval ".packages.archives[$i].sha256" "$f")"
      [[ "$sum" =~ ^[0-9a-f]{64}$ ]] \
        || fail "$rel: packages.archives[$i].sha256 is not 64 lowercase hex characters, found '$sum'"
      local url; url="$(yq eval ".packages.archives[$i].url" "$f")"
      [[ "$url" == https://* ]] \
        || fail "$rel: packages.archives[$i].url '$url' is not https; a checksummed download over plain HTTP still leaks which pin is being fetched"
    done
  fi

  for field in runtime build; do
    [[ "$(yq eval ".egress | has(\"$field\")" "$f")" == "true" ]] \
      || fail "$rel: field 'egress.$field' is missing (must be present, may be empty)"
    local sub
    for sub in allow_fqdns allow_cidrs; do
      # egress.build declares FQDNs only -- a build reaches named hosts, and a CIDR there would
      # be a policy entry with no enforcement point behind it.
      [[ "$field" == "build" && "$sub" == "allow_cidrs" ]] && continue
      [[ "$(yq eval ".egress.$field | has(\"$sub\")" "$f")" == "true" ]] \
        || fail "$rel: field 'egress.$field.$sub' is missing (must be present, may be empty)"
    done
  done

  echo "lint-policy: $rel is a well-formed pack manifest"
}

# `packs/` need not exist: a deployment may select no packs at all, and the compiler's zero-pack
# form stays valid. An EMPTY packs/ is likewise not an error. Only a malformed manifest is.
if [[ -d "$PACKS_DIR" ]]; then
  while IFS= read -r manifest; do
    lint_pack_manifest "$manifest"
  done < <(find "$PACKS_DIR" -mindepth 2 -maxdepth 2 -name pack.yaml | sort)
fi

echo "lint-policy: OK"
