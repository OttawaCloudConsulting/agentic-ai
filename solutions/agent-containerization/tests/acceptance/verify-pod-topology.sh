#!/usr/bin/env bash
# Acceptance test for Feature 01.2 (Pod topology, hardened runtime and
# minimal profile). See the feature plan's Test Strategy for what each check
# maps to and what is deliberately NOT tested here (egress, DNS,
# authentication, adversarial acceptance -- 01.3, 01.4, 02.2 respectively).
#
# Requires: docker, docker compose, jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROJECT="sf4-verify-$$"
AGENTS=(claude codex agy)
FAILED=0

COMPOSE_BASE=(docker compose --env-file compose/pins.env -f compose/compose.yaml)
COMPOSE_A=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml -p "$PROJECT")
COMPOSE_B=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml -f compose/overrides/test-readonly.yaml -p "$PROJECT")

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

cleanup() {
  "${COMPOSE_A[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  docker rm -f "${PROJECT}-ro-claude" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Static checks -- no bring-up needed
# ---------------------------------------------------------------------------

check_pin_agreement() {
  local record="docs/records/agent-verification.md"
  local ok=1
  for v in "$CLAUDE_VERSION" "$CODEX_VERSION" "$AGY_VERSION" "$AGY_SHA512"; do
    grep -qF -- "$v" "$record" || { echo "  missing from $record: $v"; ok=0; }
  done
  [ "$ok" -eq 1 ] && pass "pin agreement (pins.env vs $record)" \
                  || fail "pin agreement (pins.env vs $record)"
}

check_sandbox_record() {
  local record="docs/records/agent-verification.md"
  local ok=1
  for agent in "${AGENTS[@]}"; do
    awk '/^## Per-agent native-sandbox verdicts/,/^## [^P]/' "$record" \
      | grep -qi "| $agent " || { echo "  no verdict row for $agent"; ok=0; }
  done
  [ "$ok" -eq 1 ] && pass "sandbox record carries a verdict for all three agents" \
                  || fail "sandbox record carries a verdict for all three agents"
}

# The Compose project's secrets have `file:` sources pointing into
# mediator/identity/, which is generated and git-ignored (01.3 SF-3). Every
# compose invocation below fails on a missing source, and the daemon's error names
# a path rather than the step that was skipped -- so check it here and say so.
check_trust_material() {
  local missing=()
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
  if [ "${#missing[@]}" -eq 0 ]; then
    pass "proxy-hop trust material present"
    return 0
  fi
  echo "FAIL: proxy-hop trust material is missing:"
  printf '  %s\n' "${missing[@]}"
  echo "  Issue it first (see mediator/identity/README.md):"
  echo "    bash scripts/issue-identity.sh ca"
  echo "    bash scripts/issue-identity.sh listener claude --ip 172.31.10.2"
  echo "    bash scripts/issue-identity.sh listener agy    --ip 172.31.30.2"
  echo "    bash scripts/issue-identity.sh listener codex  --ip 172.31.20.2"
  echo "    bash scripts/issue-identity.sh client   claude"
  exit 1
}

# The mediator's pins are asserted against docs/records/mediator-selection.md the
# same way the agents' are asserted against agent-verification.md: SF-1 verified
# P1-P8 against exactly this Squid build and this base image, and both supersede in
# place upstream. UNBOUND_VERSION is deliberately not asserted -- SF-1's properties
# are the proxy's, and the record makes no claim about the resolver.
check_mediator_pin_agreement() {
  local record="docs/records/mediator-selection.md"
  local ok=1
  for v in "$SQUID_VERSION" "$MEDIATOR_BASE_DIGEST"; do
    grep -qF -- "$v" "$record" || { echo "  missing from $record: $v"; ok=0; }
  done
  [ "$ok" -eq 1 ] && pass "mediator pin agreement (pins.env vs $record)" \
                  || fail "mediator pin agreement (pins.env vs $record)"
}

# 01.4 SF-1, criterion 3 (R4.7, R8.7, D7): state volumes are secret material.
#
# D7 was "no state volume is shared between two services", checked by ENUMERATION over the
# rendered config rather than by reading compose.yaml -- a shared volume introduced by an
# override fragment would be invisible to the second reading. 02.1 SF-2 narrows it to two
# rules instead of one, because the recorder sidecars now legitimately mount a state volume
# too (Decision 1): sharing a state volume between two AGENTS still puts one agent's OAuth
# refresh token inside another's blast radius; sharing it between an agent and ANY recorder
# but its own would do the same to the recorder, which is exactly the concentration D7's own
# original comment named as the thing it prevents.
check_volume_exclusivity() {
  local config owners dupes
  config="$("${COMPOSE_A[@]}" config --format json 2>/dev/null)" || {
    fail "volume exclusivity: could not render compose config"
    return
  }
  local agents=(claude codex agy)

  # Rule 1: no state volume is mounted by two AGENT services.
  owners="$(echo "$config" | jq -r --argjson agents '["claude","codex","agy"]' '
    .services | to_entries[] as $s
    | select(.key as $k | $agents | index($k) != null)
    | ($s.value.volumes // [])[]
    | select(.type == "volume")
    | "\(.source) \($s.key)"' | sort -u)"
  dupes="$(echo "$owners" | awk 'NF {c[$1]=c[$1]" "$2; n[$1]++} END {for (v in n) if (n[v] > 1) print v ":" c[v]}')"
  if [ -z "$dupes" ]; then
    pass "volume exclusivity: no state volume is mounted by two agent services (D7, R4.7)"
  else
    echo "$dupes" | while IFS= read -r d; do echo "  shared volume $d"; done
    fail "volume exclusivity: a state volume is shared between agent services"
  fi

  # Rule 2: recorder posture. Each <agent>-recorder mounts exactly {<agent>-state (ro),
  # <agent>-action-audit}, network_mode none, and no OTHER service mounts <agent>-state.
  local a ok=1 got want
  for a in "${agents[@]}"; do
    got="$(echo "$config" | jq -r --arg a "$a" '
      .services[$a + "-recorder"].volumes // [] | map("\(.source):\(.read_only // false)") | sort | join(",")')"
    want="${a}-action-audit:false,${a}-state:true"
    if [ "$got" != "$want" ]; then
      echo "  ${a}-recorder mounts {$got}, expected {$want}"; ok=0
    fi
    netmode="$(echo "$config" | jq -r --arg a "$a" '.services[$a + "-recorder"].network_mode // "unset"')"
    if [ "$netmode" != "none" ]; then
      echo "  ${a}-recorder network_mode is '$netmode', expected 'none'"; ok=0
    fi
    other="$(echo "$config" | jq -r --arg a "$a" --arg rec "${a}-recorder" '
      .services | to_entries[] as $s
      | select($s.key != $rec)
      | ($s.value.volumes // [])[] | select(.source == ($a + "-state")) | $s.key' | sort -u)"
    if [ -n "$other" ]; then
      echo "  ${a}-state is also mounted by: $other"; ok=0
    fi
  done
  [ "$ok" -eq 1 ] && pass "recorder posture: each <agent>-recorder mounts only <agent>-state (ro) and <agent>-action-audit, network_mode none" \
                  || fail "recorder posture: an <agent>-recorder deviates from the required mount set or network_mode"

  # Rule 3: action sink exclusivity. No <agent>-action-audit volume is mounted by any
  # service other than its own recorder (D12's reading extended to the action trail).
  ok=1
  for a in "${agents[@]}"; do
    other="$(echo "$config" | jq -r --arg vol "${a}-action-audit" --arg rec "${a}-recorder" '
      .services | to_entries[] as $s
      | select($s.key != $rec)
      | ($s.value.volumes // [])[] | select(.source == $vol) | $s.key' | sort -u)"
    if [ -n "$other" ]; then
      echo "  ${a}-action-audit is also mounted by: $other"; ok=0
    fi
  done
  [ "$ok" -eq 1 ] && pass "action sink: no <agent>-action-audit volume is mounted by any other service" \
                  || fail "action sink: an <agent>-action-audit volume is shared beyond its own recorder"
}

# The version-control half of R8.7. The backup half is NOT enforceable from inside a
# container -- Docker Desktop keeps every named volume in one VM disk image, so there is no
# per-volume exclusion to make -- and is carried by the documented `tmutil` procedure in
# README.md with its residual recorded. This asserts only what this solution controls.
check_credential_gitignore() {
  local ok=1 p
  for p in references/.env_keys compose/generated/gitconfig.d/x auth.json .credentials.json; do
    git check-ignore -q "$p" 2>/dev/null || { echo "  not git-ignored: $p"; ok=0; }
  done
  # The scrubbed artifact must be ignored by compose/generated/'s own deny-all too, so the
  # rule survives someone deleting the root .gitignore block.
  [ -f compose/generated/.gitignore ] || { echo "  compose/generated/.gitignore is missing"; ok=0; }
  [ "$ok" -eq 1 ] && pass "credential material is non-committable (R8.7, version-control half)" \
                  || fail "credential material is non-committable (R8.7, version-control half)"
}

# shellcheck disable=SC1091
set -a; source compose/pins.env; set +a
check_trust_material
check_pin_agreement
check_mediator_pin_agreement
check_sandbox_record
check_volume_exclusivity
check_credential_gitignore

# ---------------------------------------------------------------------------
# Check 1: Compose validity
# ---------------------------------------------------------------------------

if "${COMPOSE_A[@]}" config >/dev/null 2>&1; then
  pass "docker compose config (base + default override) is valid"
else
  fail "docker compose config (base + default override) is valid"
fi

echo "--- building images (cold-cache-safe multi-stage build) ---"
"${COMPOSE_A[@]}" build

# ---------------------------------------------------------------------------
# Phase A: default profile only -- every per-container check plus mount
# equality (criterion 4)
# ---------------------------------------------------------------------------

echo "--- Phase A: bringing up held containers ---"
declare -A CID
for agent in "${AGENTS[@]}"; do
  CID[$agent]="$("${COMPOSE_A[@]}" run -d --name "${PROJECT}-${agent}" --rm "$agent" sleep 600)"
done

DOCKER_SOCK_FOUND=0
DEFAULT_NET_FOUND=0
EGRESS_NET_ATTACHED=0

# R2.10/T23 accumulator: "<agent> <volume-name>" per agent that mounts /build-cache.
# Collected in the loop, judged after it -- the property is a relationship BETWEEN
# agents and no per-agent check can see it.
BUILD_CACHE_SOURCES=""

for agent in "${AGENTS[@]}"; do
  cid="${CID[$agent]}"
  inspect="$(docker inspect "$cid")"

  # Check 2/10: exactly one network, and it is internal
  nets="$(echo "$inspect" | jq -r '.[0].NetworkSettings.Networks | keys | .[]')"
  net_count="$(echo "$nets" | grep -c . || true)"
  if [ "$net_count" -eq 1 ] && echo "$nets" | grep -q "${agent}-net"; then
    is_internal="$(docker network inspect "$(echo "$nets")" | jq -r '.[0].Internal')"
    if [ "$is_internal" = "true" ]; then
      pass "$agent: attached to exactly one network (${agent}-net, internal)"
    else
      fail "$agent: ${agent}-net is not internal:true"
    fi
  else
    fail "$agent: network attachment set is not exactly {${agent}-net} (got: $nets)"
  fi
  echo "$nets" | grep -q "default" && { DEFAULT_NET_FOUND=1; fail "$agent: attached to Compose's implicit default network"; }
  echo "$nets" | grep -q "egress-net" && { EGRESS_NET_ATTACHED=1; fail "$agent: attached to egress-net"; }

  # Check 5: no default route; WAN connect fails
  route_out="$(docker exec "$cid" ip route show default 2>/dev/null || true)"
  if [ -z "$route_out" ]; then
    pass "$agent: no default route"
  else
    fail "$agent: has a default route: $route_out"
  fi
  if docker exec "$cid" bash -c "timeout 3 bash -c 'echo > /dev/tcp/1.1.1.1/443'" >/dev/null 2>&1; then
    fail "$agent: WAN TCP connect succeeded (should be blocked)"
  else
    pass "$agent: WAN TCP connect fails"
  fi

  # Check 6/7/8/9/10: hardening flags from docker inspect
  cap_drop="$(echo "$inspect" | jq -r '.[0].HostConfig.CapDrop | join(",")')"
  cap_add="$(echo "$inspect" | jq -r '.[0].HostConfig.CapAdd | length')"
  [ "$cap_drop" = "ALL" ] && [ "$cap_add" -eq 0 ] \
    && pass "$agent: CapDrop=ALL, CapAdd empty" \
    || fail "$agent: CapDrop=$cap_drop CapAdd count=$cap_add"

  nnp="$(echo "$inspect" | jq -r '.[0].HostConfig.SecurityOpt | any(. == "no-new-privileges:true")')"
  privileged="$(echo "$inspect" | jq -r '.[0].HostConfig.Privileged')"
  [ "$nnp" = "true" ] && [ "$privileged" = "false" ] \
    && pass "$agent: no-new-privileges set, not privileged" \
    || fail "$agent: no-new-privileges=$nnp privileged=$privileged"

  ro="$(echo "$inspect" | jq -r '.[0].HostConfig.ReadonlyRootfs')"
  tmpfs_keys="$(echo "$inspect" | jq -r '.[0].HostConfig.Tmpfs | keys | sort | join(",")')"
  [ "$ro" = "true" ] && [ "$tmpfs_keys" = "/run,/tmp" ] \
    && pass "$agent: read-only rootfs; tmpfs /tmp and /run present" \
    || fail "$agent: ReadonlyRootfs=$ro Tmpfs keys=$tmpfs_keys"

  uid="$(docker exec "$cid" id -u)"
  [ "$uid" != "0" ] && pass "$agent: effective uid is non-zero ($uid)" \
                     || fail "$agent: running as root"

  nano_cpus="$(echo "$inspect" | jq -r '.[0].HostConfig.NanoCpus')"
  memory="$(echo "$inspect" | jq -r '.[0].HostConfig.Memory')"
  pids_limit="$(echo "$inspect" | jq -r '.[0].HostConfig.PidsLimit')"
  [ "$nano_cpus" != "0" ] && [ "$memory" != "0" ] && [ "$pids_limit" != "0" ] \
    && pass "$agent: resource ceilings set (cpus,mem,pids all non-zero)" \
    || fail "$agent: NanoCpus=$nano_cpus Memory=$memory PidsLimit=$pids_limit"

  # Check 11: no docker socket mount, over all mounts
  if echo "$inspect" | jq -e '.[0].Mounts[] | select(.Source == "/var/run/docker.sock")' >/dev/null 2>&1; then
    DOCKER_SOCK_FOUND=1
    fail "$agent: host Docker socket is mounted"
  fi

  # Check 13: no NET_ADMIN / NET_RAW
  cap_add_list="$(echo "$inspect" | jq -r '.[0].HostConfig.CapAdd // [] | join(",")')"
  if echo "$cap_add_list" | grep -qE "NET_ADMIN|NET_RAW"; then
    fail "$agent: grants NET_ADMIN or NET_RAW"
  else
    pass "$agent: no NET_ADMIN/NET_RAW granted"
  fi

  # Check 4 (criterion 4): mount set equals exactly the set this agent should have.
  # No longer one shared constant -- 01.3 SF-4 mounts the mediator CA into `claude`
  # and `agy` as a Compose secret, and deliberately NOT into `codex`, which opens no
  # TLS to the mediator and has nothing to validate. A single expected set would now
  # fail on all three: on two for missing the secret, on codex for having it.
  # 01.6 SF-2 extends it a THIRD time, and asymmetrically again: `claude` alone mounts a client
  # key pair, because it is the only agent whose listener declares `client_auth: mtls`. `agy`
  # keeps the CA and nothing more -- it anchors the proxy hop and presents nothing -- and
  # `codex` keeps neither. A single expected set would now fail on all three.
  # 01.6 SF-3 extends it again, and to the two agents SF-2 did not touch: `codex` and `agy`
  # now declare `client_auth: proxy_auth`, so each mounts its OWN proxy credential -- and only
  # its own. The htpasswd those credentials are verified against goes to the MEDIATOR alone and
  # appears in no agent's set, which is the property that keeps one agent from reading another's.
  case "$agent" in
    claude) expected_list="/home/agent /run/secrets/claude-client.crt /run/secrets/claude-client.key /run/secrets/mediator-ca.crt /workspace" ;;
    agy)    expected_list="/home/agent /run/secrets/agy-proxy-credential /run/secrets/mediator-ca.crt /workspace" ;;
    codex)  expected_list="/home/agent /run/secrets/codex-proxy-credential /workspace" ;;
  esac

  # 01.4 SF-1: the two OPTIONAL mounts that feature introduced -- /run/gitconfig
  # (mounts.host_git_config) and /run/oauth-src (the one-shot oauth-mount bootstrap).
  # 01.5 SF-5 adds the THIRD, /build-cache (mounts.build_cache, compose/overrides/
  # build-cache.yaml) -- this assertion's FOURTH extension, after 01.3's /run/secrets
  # and 01.4's two. It travels the same EXPECT_EXTRA_MOUNTS route, and the check that
  # actually gives T23 its content is the distinctness assertion after the loop: the
  # mount set alone would pass equally well if all three agents shared one volume.
  # Neither is present under profiles/default.yaml, so Phase A below still asserts the
  # 01.2 set unchanged and T21 is unaffected. A caller that layers one of those override
  # fragments sets EXPECT_EXTRA_MOUNTS to the destinations it added, and the assertion
  # stays EQUALITY rather than being relaxed to containment -- which is the whole point of
  # the check. verify-auth-state.sh (01.4 SF-5) is that caller.
  if [ -n "${EXPECT_EXTRA_MOUNTS:-}" ]; then
    expected_list="$expected_list $(echo "$EXPECT_EXTRA_MOUNTS" | tr ',' ' ')"
  fi
  # shellcheck disable=SC2086 -- word splitting is how the list becomes one path per line
  expected_mounts="$(printf '%s\n' $expected_list | sort | paste -sd, -)"

  mount_set="$(echo "$inspect" | jq -r '[.[0].Mounts[] | .Destination] | sort | join(",")')"
  if [ "$mount_set" = "$expected_mounts" ]; then
    pass "$agent: mount set equals exactly {$expected_mounts}"
  else
    fail "$agent: mount set is {$mount_set}, expected {$expected_mounts}"
  fi

  # R2.10: record which named volume backs this agent's build cache, if it has one.
  bc_src="$(echo "$inspect" | jq -r '.[0].Mounts[] | select(.Destination == "/build-cache") | .Name // .Source')"
  if [ -n "$bc_src" ]; then
    BUILD_CACHE_SOURCES="$BUILD_CACHE_SOURCES$agent $bc_src
"
  fi

  # Check 4d (01.4 criterion 2): the authentication surface sits on the state volume.
  # 01.4 ASSERTS 01.2's environment contract rather than re-deciding it -- these values are
  # 01.2 Interface Contract 2's, and the reason they are checked here is that every
  # AUTH_MODE in 01.4 writes its credential relative to one of them. A container whose
  # CODEX_HOME pointed off the volume would authenticate once and lose it at restart.
  auth_surface_ok=1
  got_home="$(docker exec "$cid" printenv HOME 2>/dev/null || true)"
  [ "$got_home" = "/home/agent" ] || { echo "  HOME=$got_home, expected /home/agent"; auth_surface_ok=0; }

  case "$agent" in
    claude)
      got="$(docker exec "$cid" printenv CLAUDE_CONFIG_DIR 2>/dev/null || true)"
      [ "$got" = "/home/agent/.claude" ] \
        || { echo "  CLAUDE_CONFIG_DIR=$got, expected /home/agent/.claude"; auth_surface_ok=0; }
      # R4.4 singles out ~/.claude.json as living OUTSIDE CLAUDE_CONFIG_DIR and holding the
      # OAuth account. Under 01.2's read_only root filesystem, a $HOME that was not the
      # volume would make this path unwritable -- so writability here is a pass/fail
      # property of the wiring, not an incidental one. Probe and remove; never read it.
      if docker exec "$cid" sh -c 'touch /home/agent/.claude.json.probe && rm -f /home/agent/.claude.json.probe' 2>/dev/null; then
        :
      else
        echo "  /home/agent/.claude.json is not writable (R4.4 account record has nowhere to land)"
        auth_surface_ok=0
      fi
      ;;
    codex)
      got="$(docker exec "$cid" printenv CODEX_HOME 2>/dev/null || true)"
      [ "$got" = "/home/agent/.codex" ] \
        || { echo "  CODEX_HOME=$got, expected /home/agent/.codex"; auth_surface_ok=0; }
      # R4.5, and read as the EFFECTIVE value inside the container rather than from the
      # Dockerfile (criterion 2 requires exactly that distinction). The `keyring` store
      # hard-fails with no D-Bus and there is no D-Bus here under any mode, so this must
      # hold in every AUTH_MODE -- verify-auth-state.sh re-checks it per mode.
      store="$(docker exec "$cid" sh -c 'grep -E "^[[:space:]]*cli_auth_credentials_store[[:space:]]*=" "$CODEX_HOME/config.toml" 2>/dev/null | head -1' || true)"
      if echo "$store" | grep -qE '=[[:space:]]*"file"[[:space:]]*$'; then
        :
      else
        echo "  \$CODEX_HOME/config.toml does not set cli_auth_credentials_store = \"file\" (got: ${store:-<absent>})"
        auth_surface_ok=0
      fi
      ;;
    agy)
      # agy has no HOME-override variable (01.2: absent from --help and from `strings`);
      # it resolves ~/.gemini from $HOME, so the volume assertion above is what carries it.
      # Asserted explicitly anyway, because "it follows from HOME" is exactly the kind of
      # inference that stops being true when someone adds an env var.
      if docker exec "$cid" sh -c 'test -d /home/agent/.gemini' 2>/dev/null; then
        :
      else
        echo "  /home/agent/.gemini is absent (agy state has nowhere to persist)"
        auth_surface_ok=0
      fi
      ;;
  esac
  [ "$auth_surface_ok" -eq 1 ] && pass "$agent: auth surface on the state volume (01.4 criterion 2)" \
                               || fail "$agent: auth surface is not correctly rooted on the state volume"

  # Check 4b (01.3 Interface Contract 2): the proxy hop's scheme is per agent, and
  # the asymmetry is a finding rather than a preference -- 01.1 SF-2 established
  # that codex rejects an `https://`-scheme proxy URL at URL-parse time. A uniform
  # scheme here would take codex's route away silently, so it is asserted.
  case "$agent" in
    claude) expected_proxy="https://172.31.10.2:3128"; expected_dns="172.31.10.2"; expected_trust="NODE_EXTRA_CA_CERTS=/run/secrets/mediator-ca.crt" ;;
    codex)  expected_proxy="http://172.31.20.2:3128";  expected_dns="172.31.20.2"; expected_trust="" ;;
    agy)    expected_proxy="https://172.31.30.2:3128"; expected_dns="172.31.30.2"; expected_trust="SSL_CERT_FILE=/run/secrets/mediator-ca.crt" ;;
  esac
  env_ok=1
  for var in HTTPS_PROXY https_proxy HTTP_PROXY http_proxy; do
    got="$(docker exec "$cid" printenv "$var" 2>/dev/null || true)"
    [ "$got" = "$expected_proxy" ] || { echo "  $var=$got, expected $expected_proxy"; env_ok=0; }
  done
  for var in NO_PROXY no_proxy; do
    got="$(docker exec "$cid" printenv "$var" 2>/dev/null || true)"
    [ "$got" = "localhost,127.0.0.1" ] || { echo "  $var=$got, expected localhost,127.0.0.1"; env_ok=0; }
  done
  if [ -n "$expected_trust" ]; then
    var="${expected_trust%%=*}"; want="${expected_trust#*=}"
    got="$(docker exec "$cid" printenv "$var" 2>/dev/null || true)"
    [ "$got" = "$want" ] || { echo "  $var=$got, expected $want"; env_ok=0; }
  else
    # codex must have NEITHER trust variable: it has no TLS hop to anchor, and a
    # CA it cannot use is a mount it should not have.
    for var in NODE_EXTRA_CA_CERTS SSL_CERT_FILE CODEX_CA_CERTIFICATE; do
      got="$(docker exec "$cid" printenv "$var" 2>/dev/null || true)"
      [ -z "$got" ] || { echo "  codex carries $var=$got; it has no TLS hop to the mediator"; env_ok=0; }
    done
  fi
  # Check 4b-ii (01.6 Interface Contract 5): the client-certificate variables, and their
  # ABSENCE where the agent has no client certificate. Asserted both ways for the reason the
  # trust variables are: a variable pointing at a secret an agent does not mount is a
  # handshake failure whose symptom names neither the variable nor the mount.
  case "$agent" in
    claude)
      for pair in "CLAUDE_CODE_CLIENT_CERT=/run/secrets/claude-client.crt" \
                  "CLAUDE_CODE_CLIENT_KEY=/run/secrets/claude-client.key"; do
        var="${pair%%=*}"; want="${pair#*=}"
        got="$(docker exec "$cid" printenv "$var" 2>/dev/null || true)"
        [ "$got" = "$want" ] || { echo "  $var=$got, expected $want"; env_ok=0; }
      done ;;
    codex|agy)
      for var in CLAUDE_CODE_CLIENT_CERT CLAUDE_CODE_CLIENT_KEY; do
        got="$(docker exec "$cid" printenv "$var" 2>/dev/null || true)"
        [ -z "$got" ] || { echo "  $agent carries $var=$got; it presents a proxy credential, not a certificate"; env_ok=0; }
      done ;;
  esac

  # Check 4b-iii (01.6 SF-3). The proxy CREDENTIAL's delivery, and it is asserted on the RUNNING
  # PROCESS rather than on the container's configured environment, because those are two
  # different things here and the difference is the mechanism.
  #
  # SF-1 measured that neither codex nor agy exposes any knob for supplying a proxy credential,
  # and that both construct `Proxy-Authorization: Basic` themselves from userinfo in the proxy
  # URL. So images/entrypoint.sh splices the credential into HTTPS_PROXY/HTTP_PROXY at start,
  # from a Compose secret. The URL in compose.yaml -- which is what `docker exec printenv` and
  # `docker inspect` both report -- therefore stays credential-free, and check 4b above asserts
  # exactly that, unchanged. What the CLIENT sees is PID 1's environment, and that is where the
  # credential has to be, or the agent talks to an authenticating listener with nothing to say.
  #
  # Asserting both halves is the point: the clean URL alone would also pass if the splice never
  # happened, and the spliced URL alone would not catch the credential leaking into the
  # committed Compose file.
  case "$agent" in
    codex|agy)
      # `/proc/1/environ` is NUL-separated. The username is asserted; the password is compared
      # without being printed, so a failure here names the variable and not the secret.
      penv="$(docker exec "$cid" sh -c "tr '\\0' '\\n' < /proc/1/environ" 2>/dev/null | grep '^HTTPS_PROXY=' | head -1 || true)"
      want_user="$(tr -d '\r\n' < "mediator/identity/credentials/${agent}.cred" 2>/dev/null | cut -d: -f1)"
      if [ -z "$penv" ]; then
        echo "  $agent: PID 1 carries no HTTPS_PROXY at all"; env_ok=0
      elif ! printf '%s' "$penv" | grep -q "://${want_user}:[0-9a-f][0-9a-f]*@"; then
        echo "  $agent: PID 1's HTTPS_PROXY carries no '${want_user}:<credential>@' userinfo -- the entrypoint did not splice the credential"; env_ok=0
      elif [ "$(printf '%s' "$penv" | sed "s/:[0-9a-f]*@/:<redacted>@/")" != "HTTPS_PROXY=${expected_proxy%%://*}://${want_user}:<redacted>@${expected_proxy#*://}" ]; then
        echo "  $agent: PID 1's HTTPS_PROXY is $(printf '%s' "$penv" | sed "s/:[0-9a-f]*@/:<redacted>@/"), which is not ${expected_proxy} with ${want_user}'s credential spliced in"; env_ok=0
      fi ;;
    claude)
      # claude presents a certificate, so nothing may be spliced into its URL. Asserted, because
      # a credential appearing here would mean the entrypoint's per-agent scoping had failed.
      penv="$(docker exec "$cid" sh -c "tr '\\0' '\\n' < /proc/1/environ" 2>/dev/null | grep '^HTTPS_PROXY=' | head -1 || true)"
      case "$penv" in
        *@*) echo "  claude: PID 1's HTTPS_PROXY carries userinfo; its identity is a client certificate and it holds no credential"; env_ok=0 ;;
      esac ;;
  esac

  [ "$env_ok" -eq 1 ] && pass "$agent: proxy env matches Interface Contract 2 ($expected_proxy)" \
                      || fail "$agent: proxy env does not match Interface Contract 2"

  # Check 4c (R5.4, D3): the embedded resolver's upstream is the mediator, not the
  # daemon's. `internal: true` withholds the default route but leaves 127.0.0.11
  # forwarding to the host's upstreams -- a path out that does not traverse the
  # container's routing table. Docker records the override in resolv.conf's
  # ExtServers comment; the live capture that the redirect actually carries the
  # query is docs/records/mediator-runtime-verification.md, and SF-8 re-runs it.
  if docker exec "$cid" grep -qF "ExtServers: [$expected_dns]" /etc/resolv.conf; then
    pass "$agent: embedded resolver forwards to the mediator ($expected_dns)"
  else
    fail "$agent: resolv.conf ExtServers is not [$expected_dns]"
  fi

  # Check 14/15: agent starts, reports its pinned version, offline, non-root, read-only
  version_var="$(echo "${agent}_VERSION" | tr '[:lower:]' '[:upper:]')"
  expected_version="${!version_var}"
  case "$agent" in
    claude) reported="$(docker exec "$cid" claude --version 2>&1)" ;;
    codex)  reported="$(docker exec "$cid" codex --version 2>&1)" ;;
    agy)    reported="$(docker exec "$cid" agy --version 2>&1)" ;;
  esac
  if echo "$reported" | grep -qF -- "$expected_version"; then
    pass "$agent: reports pinned version ($expected_version)"
  else
    fail "$agent: reported '$reported', expected to contain $expected_version"
  fi

  # T1: reads of paths outside declared mounts fail (prerequisite-level, not
  # adversarial -- see criterion 8 and Test Strategy "what is not tested")
  t1_ok=1
  for p in /etc/shadow /root/.ssh/id_rsa /mnt/other-agent-state; do
    if docker exec "$cid" cat "$p" >/dev/null 2>&1; then
      t1_ok=0
      echo "  T1: read of $p unexpectedly succeeded"
    fi
  done
  [ "$t1_ok" -eq 1 ] && pass "$agent: T1 -- reads outside declared mounts fail" \
                     || fail "$agent: T1 -- a read outside declared mounts succeeded"
done

# Check 4e (R2.10, T23): the per-agent build cache is PER AGENT.
#
# Under profiles/default.yaml `mounts.build_cache` is false and no agent mounts
# /build-cache, so this reports the absence and moves on -- the mount-set equality above
# is what proves the absence. A caller that layers compose/overrides/build-cache.yaml
# gets the real assertion: every agent's cache is backed by a DISTINCT named volume.
#
# Edge Case 14 asks which volume T23 is asserted against, because 01.2 already puts
# /home/agent/.cache on the per-agent state volume and a test written against that would
# pass without the option existing at all. This is asserted against the DEDICATED volume,
# at /build-cache. Two agents sharing one would be an unaudited write channel between two
# containers that the mediator never sees, which is the whole of what R2.10 forbids.
if [ -z "$BUILD_CACHE_SOURCES" ]; then
  pass "no agent mounts /build-cache (mounts.build_cache is false under this profile)"
else
  bc_count="$(printf '%s' "$BUILD_CACHE_SOURCES" | grep -c .)"
  bc_uniq="$(printf '%s' "$BUILD_CACHE_SOURCES" | awk '{print $2}' | sort -u | grep -c .)"
  if [ "$bc_count" -eq "$bc_uniq" ]; then
    pass "build cache: $bc_count agent(s), $bc_uniq distinct volume(s) -- no shared cache"
  else
    printf '%s' "$BUILD_CACHE_SOURCES" | sed 's/^/  /'
    fail "build cache: $bc_count agent(s) share only $bc_uniq volume(s) -- R2.10 forbids a shared cache"
  fi
fi

[ "$DEFAULT_NET_FOUND" -eq 0 ] && pass "no agent attached to Compose's implicit default network"
[ "$EGRESS_NET_ATTACHED" -eq 0 ] && pass "no agent attached to egress-net"
[ "$DOCKER_SOCK_FOUND" -eq 0 ] && pass "no agent mounts the host Docker socket (all services)"

# Check 3: egress-net is declared with internal:false, Compose-managed.
# 01.2 could only check this statically -- Compose does not create a top-level
# network no service references, so egress-net was declared but never a live Docker
# resource (01.2 Deviation 3). 01.3 SF-4 attaches the mediator to it, which closes
# that deviation, so the static check is joined by the resolved-config check that
# the mediator is on all four networks and no agent is on egress-net.
if awk '/^  egress-net:/{f=1} f && /internal: false/{print; exit}' compose/compose.yaml | grep -q "internal: false"; then
  pass "egress-net declared in compose.yaml with internal:false"
else
  fail "egress-net not declared with internal:false in compose.yaml"
fi

# The ipam addresses, the agents' proxy/dns literals and the listener certificates'
# iPAddress SANs are three copies of one fact, and Compose enforces no coupling
# between them. A renumber that updates two of the three fails at runtime as a
# proxy-hop TLS verification error at the agent -- and the tempting repair for that
# is disabling verification, which gives up the server authentication the TLS hop
# exists for. Asserted here so drift is caught before bring-up, not diagnosed from
# a handshake failure.
#
# codex is included, and it was NOT before 01.3 SF-6. Its certificate is a BUMPING
# certificate rather than a proxy hop -- its listener peeks the ClientHello and Squid
# silently stops peeking without one (feature plan Deviation 5) -- but it carries the
# same iPAddress SAN and therefore the same coupling to the ipam block. A renumber
# that missed it would leave the mediator refusing to start, so it is guarded here
# with the other two rather than left as the one certificate nothing checks.
san_ok=1
for a in claude codex agy; do
  crt="mediator/identity/listeners/${a}-listener.crt"
  want="$("${COMPOSE_A[@]}" config --format json \
    | jq -r --arg a "${a}-net" '.services["egress-mediator"].networks[$a].ipv4_address')"
  got="$(openssl x509 -in "$crt" -noout -text \
    | awk '/X509v3 Subject Alternative Name/{getline; gsub(/^ +| +$/,""); print}' \
    | tr ',' '\n' | sed 's/^ *//' | grep '^IP Address:' | sed 's/^IP Address://')"
  if [ "$got" = "$want" ]; then
    echo "  $a: cert SAN $got matches ipam $want"
  else
    echo "  $a: cert SAN is '$got' but compose puts the mediator at '$want'"
    echo "     re-issue: bash scripts/issue-identity.sh listener $a --ip $want"
    san_ok=0
  fi
done
[ "$san_ok" -eq 1 ] && pass "listener certificate SANs match the mediator's ipam addresses" \
                    || fail "listener certificate SANs do not match the mediator's ipam addresses"

mediator_nets="$("${COMPOSE_A[@]}" config --format json | jq -r '.services["egress-mediator"].networks | keys | sort | join(",")')"
if [ "$mediator_nets" = "agy-net,claude-net,codex-net,egress-net" ]; then
  pass "egress-mediator attaches to all four networks (Deviation 3 closed)"
else
  fail "egress-mediator networks are {$mediator_nets}, expected all four"
fi

# ---------------------------------------------------------------------------
# Edge Case 8 / criterion 2: volume upgrade -- rebuild with a changed
# skeleton file, assert the new file appears and an agent-written file
# survives untouched. Exercised against claude only (the mechanism is
# agent-agnostic -- it lives entirely in agent-base).
# ---------------------------------------------------------------------------

echo "--- volume upgrade check ---"
docker exec "${CID[claude]}" sh -c 'echo agent-owned > /home/agent/.claude/pre-existing.txt'
"${COMPOSE_A[@]}" stop claude >/dev/null 2>&1
"${COMPOSE_A[@]}" build --build-arg SKEL_MARKER=upgraded-01.2-sf4 claude >/dev/null
upgraded_cid="$("${COMPOSE_A[@]}" run -d --name "${PROJECT}-claude-upgraded" --rm claude sleep 60)"
new_file="$(docker exec "$upgraded_cid" cat /home/agent/.upgrade-marker 2>/dev/null || true)"
preserved="$(docker exec "$upgraded_cid" cat /home/agent/.claude/pre-existing.txt 2>/dev/null || true)"
docker rm -f "$upgraded_cid" >/dev/null 2>&1 || true
if [ "$new_file" = "upgraded-01.2-sf4" ] && [ "$preserved" = "agent-owned" ]; then
  pass "volume upgrade: new default appears, agent-owned file untouched"
else
  fail "volume upgrade: new_file='$new_file' preserved='$preserved'"
fi

# ---------------------------------------------------------------------------
# Phase B: T2 only -- read-only fixture mount, layered on top of Phase A
# ---------------------------------------------------------------------------

echo "--- Phase B: T2 (read-only fixture) ---"
ro_cid="$("${COMPOSE_B[@]}" run -d --name "${PROJECT}-ro-claude" --rm claude sleep 60)"
if docker exec "$ro_cid" sh -c 'echo x > /fixture-ro/should-fail.txt' >/dev/null 2>&1; then
  fail "T2: write to read-only fixture mount succeeded"
else
  pass "T2: write to read-only fixture mount fails"
fi
docker rm -f "$ro_cid" >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------

if [ "$FAILED" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "ONE OR MORE CHECKS FAILED"
  exit 1
fi
