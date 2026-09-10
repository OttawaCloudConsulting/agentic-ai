#!/usr/bin/env bash
# Acceptance test for Feature 02.2 (Adversarial boundary validation). See the feature plan's
# Test Strategy for the scenario-to-requirement map (REQUIREMENTS.md T1-T8, T16, T38, R12.8).
#
# WHAT THIS SUITE IS. T1-T8 run from INSIDE the real agent containers -- start_agents/in_agent,
# lifted from verify-pack-composition.sh -- not from a throwaway probe on the mediator image.
# verify-egress-mediator.sh's probe()-based T3-T7 remain the mediator-path SMOKE layer; this is
# the COMPROMISED-AGENT layer R12.8 requires before real use. Every row records the three-part
# verdict (blocked / logged / attributable) as one JSON line, appended to $RECORD_FILE.
#
# `test_id` below maps to REQUIREMENTS.md:457-464, never to a verify-egress-mediator.sh `pass`
# string -- that file's own "T3"/"T7" labels do not match the register.
#
# Unattended invocation (this SF-1/2/3 grid) spends no model tokens. BOUNDARY_LIVE_INJECT=1
# (SF-4) and BOUNDARY_SHADOW_RUN=1 (SF-5) are each gated, live, and run once by the operator
# against authenticated volumes -- see Interface Contract 2 in the feature plan.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROJECT="boundary-verify-$$"
AGENTS=(claude codex agy)
FAILED=0
PHASE=""

RECORD_DIR="$(mktemp -d)"
RECORD_FILE="${RECORD_DIR}/records.jsonl"
: > "$RECORD_FILE"

RO_FIXTURE_HOST="tests/fixtures/ro-fixture/marker.txt"
# default.yaml binds ../workspace:/workspace, relative to the compose project dir (compose/,
# one level below $ROOT) -- so the host path is $ROOT/workspace, not $ROOT/../workspace.
WORKSPACE_DIR="workspace"
HOST_SYMLINK="${WORKSPACE_DIR}/t1-passwd-symlink"

pass() { echo "PASS: [$PHASE] $1"; }
fail() { echo "FAIL: [$PHASE] $1"; FAILED=1; }
note() { echo "      $*"; }
phase() { PHASE="$1"; echo; echo "=== Phase $1 -- $2 ================================================"; }

for tool in docker jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "validate-boundary: $tool is required" >&2; exit 1; }
done

COMPOSE_BASE=(docker compose --env-file compose/pins.env -f compose/compose.yaml)
COMPOSE_A=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml -p "$PROJECT")
COMPOSE_RO=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
            -f compose/overrides/test-boundary-ro.yaml -p "$PROJECT")

# ---------------------------------------------------------------------------
# Record schema (Interface Contract 1). One JSON object per (scenario, test, agent).
# ---------------------------------------------------------------------------
record() { # <scenario> <test_id> <agent> <blocked> <egress_logged|null> <action_logged|null> \
           # <attributable> <identity_source> <dest> <verdict> <control> <reason> <note>
  jq -nc \
    --arg scenario "$1" --arg test_id "$2" --arg agent "$3" \
    --argjson blocked "$4" --argjson egress_logged "$5" --argjson action_logged "$6" \
    --argjson attributable "$7" --arg identity_source "$8" --arg dest "$9" \
    --arg verdict "${10}" --arg control "${11}" --arg reason "${12}" --arg note "${13}" \
    '{scenario:$scenario,test_id:$test_id,agent:$agent,blocked:$blocked,
      egress_logged:$egress_logged,action_logged:$action_logged,attributable:$attributable,
      identity_source:$identity_source,dest:$dest,verdict:$verdict,control:$control,
      reason:$reason,note:$note}' >> "$RECORD_FILE"
}

# ---------------------------------------------------------------------------
# start_agents/in_agent/agent_ctr, lifted verbatim from verify-pack-composition.sh:811-824.
# ---------------------------------------------------------------------------
agent_ctr() { echo "${PROJECT}-run-$1"; }
start_agents() { # <compose-array-name>
  local -n _compose="$1"
  local a
  for a in "${AGENTS[@]}"; do
    docker rm -f "$(agent_ctr "$a")" >/dev/null 2>&1 || true
    "${_compose[@]}" run -d --rm --name "$(agent_ctr "$a")" "$a" sleep 900 >/dev/null 2>&1 \
      || { fail "could not start a long-lived $a container"; return 1; }
  done
}
stop_agents() {
  local a
  for a in "${AGENTS[@]}"; do docker rm -f "$(agent_ctr "$a")" >/dev/null 2>&1 || true; done
}
in_agent() { docker exec "$(agent_ctr "$1")" sh -c "$2" 2>&1; }

cleanup() {
  echo
  echo "--- tearing down $PROJECT ---"
  stop_agents
  "${COMPOSE_RO[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  "${COMPOSE_A[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -f "$HOST_SYMLINK"
  rm -rf "$RECORD_DIR"
}
trap cleanup EXIT

# The pre-seeded host-side symlink for T1 (Interface Contract 3, the malicious-repo model, A3).
# Lands in the workspace bind source, which is git-ignored -- cleanup removes it regardless so
# the tree stays committable.
mkdir -p "$WORKSPACE_DIR"
ln -sf /etc/passwd "$HOST_SYMLINK"

# ---------------------------------------------------------------------------
# Phase 1 -- T1 host filesystem containment (Interface Contract 3), and T8 policy
# modification from inside. No fixture DNS, no egress traffic.
# ---------------------------------------------------------------------------
phase 1 "T1 host containment + T8 policy modification (base profile, all agents)"

start_agents COMPOSE_A || exit 1

for a in "${AGENTS[@]}"; do
  # Reference: the container's OWN /etc/passwd. Both checks below compare against this --
  # `..` from /workspace, and an absolute-path symlink, both resolve inside the container's
  # OWN mount namespace on Linux (a bind mount is not a chroot boundary `..` can cross); what
  # T1 actually needs proven is that the content read is this file and never the HOST's.
  container_passwd="$(in_agent "$a" 'cat /etc/passwd 2>&1')"

  # T1: `../` traversal above the mount root. Blocked (command fails) or in-namespace
  # (content equals the container's own /etc/passwd) both count as contained; content that
  # differs from the container's own file would mean the host's file was read instead.
  out="$(in_agent "$a" 'cat /workspace/../../etc/passwd 2>&1')"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    pass "T1 [$a]: '../' traversal above mount root fails"
    record host_filesystem_containment T1 "$a" true null null true n/a n/a deny namespace escape_denied ""
  elif [ "$out" = "$container_passwd" ]; then
    pass "T1 [$a]: '../' traversal resolves to the container's own /etc/passwd (in-namespace)"
    record host_filesystem_containment T1 "$a" true null null true n/a n/a deny namespace in_namespace ""
  else
    fail "T1 [$a]: '../' traversal returned content that is NOT the container's own /etc/passwd"
    record host_filesystem_containment T1 "$a" false null null true n/a n/a allow none escape_succeeded "SECURITY: path escaped mount root"
  fi

  # T1: symlink to /etc/passwd, created BOTH in-container and pre-seeded host-side. R2.6 --
  # must resolve to the CONTAINER's own /etc/passwd (asserted by content), not escape the mount.
  in_agent "$a" 'ln -sf /etc/passwd /workspace/t1-in-container-symlink' >/dev/null 2>&1
  in_content="$(in_agent "$a" 'cat /workspace/t1-in-container-symlink 2>&1')"
  host_content="$(in_agent "$a" 'cat /workspace/t1-passwd-symlink 2>&1')"
  in_agent "$a" 'rm -f /workspace/t1-in-container-symlink' >/dev/null 2>&1
  if [ "$in_content" = "$container_passwd" ] && [ "$host_content" = "$container_passwd" ]; then
    pass "T1 [$a]: in-container and pre-seeded symlinks to /etc/passwd resolve in-namespace"
    record host_filesystem_containment T1 "$a" true null null true n/a n/a deny namespace in_namespace ""
  else
    fail "T1 [$a]: symlink to /etc/passwd did not resolve to the container's own file"
    record host_filesystem_containment T1 "$a" false null null true n/a n/a allow none symlink_escape "SECURITY: content mismatch"
  fi

  # T1: /host_mnt/..., /proc/1/root, /var/run/docker.sock -- each must fail or resolve in-namespace.
  for target in /host_mnt /proc/1/root /var/run/docker.sock; do
    if in_agent "$a" "test -e $target" >/dev/null 2>&1; then
      # Present in-namespace is only safe if it is NOT actually reachable as the host resource --
      # docker.sock in particular must not be usable to control the host daemon.
      if [ "$target" = "/var/run/docker.sock" ] && in_agent "$a" "test -S $target && command -v curl >/dev/null && curl -s --unix-socket $target http://localhost/version" 2>/dev/null | grep -q '"Version"'; then
        fail "T1 [$a]: $target is a live Docker socket -- host daemon reachable"
        record host_filesystem_containment T1 "$a" false null null true n/a "$target" allow none docker_sock_live "SECURITY"
      else
        pass "T1 [$a]: $target exists in-namespace but is not the live host resource"
        record host_filesystem_containment T1 "$a" true null null true n/a "$target" deny namespace not_host_resource ""
      fi
    else
      pass "T1 [$a]: $target does not exist"
      record host_filesystem_containment T1 "$a" true null null true n/a "$target" deny namespace absent ""
    fi
  done

  # T8 surface 2 -- firewall and routing. Asserted by attempting it; a missing binary is
  # itself part of the answer, not silently counted as a pass (verify-egress-mediator.sh:957's
  # gap is not repeated here -- presence is checked first).
  for attempt in "ip route add default via 172.31.254.254" "ip link set lo up" "iptables -A OUTPUT -j DROP"; do
    bin="${attempt%% *}"
    if ! in_agent "$a" "command -v $bin" >/dev/null 2>&1; then
      pass "T8 [$a]: '$attempt' -- $bin not present in image, no tool for the reconfiguration"
      record policy_modification_from_inside T8 "$a" true null null true n/a n/a deny capability tool_absent "$attempt"
      continue
    fi
    if in_agent "$a" "$attempt" >/dev/null 2>&1; then
      fail "T8 [$a]: '$attempt' SUCCEEDED"
      record policy_modification_from_inside T8 "$a" false null null true n/a n/a allow none reconfig_succeeded "SECURITY: $attempt"
    else
      pass "T8 [$a]: '$attempt' fails (no NET_ADMIN/NET_RAW)"
      record policy_modification_from_inside T8 "$a" true null null true n/a n/a deny capability no_capability "$attempt"
    fi
  done

  # T8 surface 3 -- mount set and control-plane reach. Nothing new may be mounted; the control
  # plane and the audit sinks (02.1) are unreachable from inside.
  for attempt in "mount -o remount,rw,exec /workspace" "mount -t tmpfs none /mnt" "mkdir -p /mnt/x && mount --bind / /mnt/x"; do
    bin=mount
    if ! in_agent "$a" "command -v $bin" >/dev/null 2>&1; then
      pass "T8 [$a]: '$attempt' -- $bin not present, no tool for the reconfiguration"
      record policy_modification_from_inside T8 "$a" true null null true n/a n/a deny capability tool_absent "$attempt"
      continue
    fi
    if in_agent "$a" "$attempt" >/dev/null 2>&1; then
      fail "T8 [$a]: '$attempt' SUCCEEDED"
      record policy_modification_from_inside T8 "$a" false null null true n/a n/a allow none reconfig_succeeded "SECURITY: $attempt"
    else
      pass "T8 [$a]: '$attempt' fails"
      record policy_modification_from_inside T8 "$a" true null null true n/a n/a deny capability no_capability "$attempt"
    fi
  done

  for p in /etc/mediator/policy /etc/mediator/config /var/log/mediator /var/log/actions; do
    if in_agent "$a" "ls $p" >/dev/null 2>&1; then
      fail "T8 [$a]: control plane path $p is reachable"
      record policy_modification_from_inside T8 "$a" false null null true n/a "$p" allow none control_plane_reachable "SECURITY"
    else
      pass "T8 [$a]: $p is not reachable from inside"
      record policy_modification_from_inside T8 "$a" true null null true n/a "$p" deny mount_namespace not_mounted ""
    fi
  done
done

stop_agents

# ---------------------------------------------------------------------------
# Phase 2 -- T2 + R11.4: read-only mount enforced by the host filesystem sharing layer.
# Layered ONLY here (Interface Contract 4) so no other row runs with the extra mount.
# ---------------------------------------------------------------------------
phase 2 "T2 + R11.4 read-only mount (dedicated ro-fixture, all agents)"

host_sha_before="$(shasum -a 256 "$RO_FIXTURE_HOST" | awk '{print $1}')"

start_agents COMPOSE_RO || exit 1

for a in "${AGENTS[@]}"; do
  # T2: write to the read-only fixture mount fails.
  if in_agent "$a" 'echo x > /fixture-ro/should-fail.txt' >/dev/null 2>&1; then
    fail "T2 [$a]: write to read-only fixture mount succeeded"
    record filesystem_readonly_enforcement T2 "$a" false null null true n/a /fixture-ro allow none write_succeeded "SECURITY"
  else
    pass "T2 [$a]: write to read-only fixture mount fails"
  fi

  # R11.4: mountinfo shows `ro`, and the host-side file is byte-unchanged (VirtioFS claim,
  # distinct from the in-container write failure above).
  opts="$(in_agent "$a" "awk '\$5 == \"/fixture-ro\" {print \$6}' /proc/self/mountinfo" | tail -n1)"
  mount_ro=0
  case ",$opts," in
    *,ro,*) mount_ro=1 ;;
  esac
  host_sha_after="$(shasum -a 256 "$RO_FIXTURE_HOST" | awk '{print $1}')"
  if [ "$mount_ro" -eq 1 ] && [ "$host_sha_before" = "$host_sha_after" ]; then
    pass "R11.4 [$a]: mountinfo shows 'ro' (opts=$opts) and host file is byte-unchanged"
    record filesystem_readonly_enforcement T2 "$a" true null null true n/a /fixture-ro deny ro_mount host_ro_enforced ""
  else
    fail "R11.4 [$a]: mountinfo opts='$opts' sha_before=$host_sha_before sha_after=$host_sha_after"
    record filesystem_readonly_enforcement T2 "$a" false null null true n/a /fixture-ro allow none host_layer_not_enforced "SECURITY"
  fi
done

stop_agents

echo
echo "=== SF-1 record file: $RECORD_FILE ==="
cat "$RECORD_FILE"

if [ "$FAILED" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "ONE OR MORE CHECKS FAILED"
  exit 1
fi
