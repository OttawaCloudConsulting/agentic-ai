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

# shellcheck disable=SC1091
set -a; source compose/pins.env; set +a
check_pin_agreement
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

  # Check 4 (criterion 4): mount set equals exactly {state volume, workspace bind}
  mount_set="$(echo "$inspect" | jq -r '[.[0].Mounts[] | .Destination] | sort | join(",")')"
  if [ "$mount_set" = "/home/agent,/workspace" ]; then
    pass "$agent: mount set equals exactly {/home/agent, /workspace}"
  else
    fail "$agent: mount set is {$mount_set}, expected {/home/agent,/workspace}"
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
# Not a live Docker resource in 01.2 -- Compose does not create a top-level
# network no service references yet (verified: it is silently absent from
# `docker compose config`'s resolved output, even without any override
# layered on). It becomes real the moment 01.3 attaches the mediator
# service to it. This is a static check on the source YAML, not a runtime
# resource check. See Deviation 3.
if awk '/^  egress-net:/{f=1} f && /internal: false/{print; exit}' compose/compose.yaml | grep -q "internal: false"; then
  pass "egress-net declared in compose.yaml with internal:false"
else
  fail "egress-net not declared with internal:false in compose.yaml"
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
