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
           mediator/identity/listeners/agy-listener.key; do
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

# shellcheck disable=SC1091
set -a; source compose/pins.env; set +a
check_trust_material
check_pin_agreement
check_mediator_pin_agreement
check_sandbox_record

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
  # 01.6 extends this again when per-agent client certificates land.
  case "$agent" in
    claude|agy) expected_mounts="/home/agent,/run/secrets/mediator-ca.crt,/workspace" ;;
    codex)      expected_mounts="/home/agent,/workspace" ;;
  esac
  mount_set="$(echo "$inspect" | jq -r '[.[0].Mounts[] | .Destination] | sort | join(",")')"
  if [ "$mount_set" = "$expected_mounts" ]; then
    pass "$agent: mount set equals exactly {$expected_mounts}"
  else
    fail "$agent: mount set is {$mount_set}, expected {$expected_mounts}"
  fi

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
