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
# SF-2. verify-egress-mediator.sh's own fixture topology (mediator + fixture-dns/collector/
# neighbour under the test-fixtures policy) -- reused rather than duplicated, so a fixture or
# policy change is measured once.
COMPOSE_EGRESS=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml \
                -f compose/overrides/test-egress.yaml -p "$PROJECT")

MED_CLAUDE=172.31.10.2
MED_CODEX=172.31.20.2
MED_AGY=172.31.30.2
FIXTURE_COLLECTOR=172.31.40.20
# The agent whose listener requires a client certificate (mTLS), vs. the two whose listener
# requires a proxy credential (proxy_auth). Same lists verify-egress-mediator.sh keeps, needed
# here to pick the right curl flags and to know which agents' proxy URL carries a credential.
MTLS_AGENTS=" claude "
PROXY_AUTH_AGENTS=" codex agy "

med() { docker exec "${PROJECT}-egress-mediator-1" "$@"; }
audit() { med cat /var/log/mediator/egress-audit.log 2>/dev/null; }
last_verdict() { audit | jq -c --arg h "$1" 'select(.verdict != null and .dest_host == $h)' | tail -1; }
verdict_count() { audit | jq -c --arg h "$1" 'select(.verdict != null and .dest_host == $h)' | wc -l | tr -d ' '; }

# A working-path probe against a cold cascade peer (or, measured live 2026-09-11, a cold FRONT
# listener on the very first request after mediator start-up -- claude's mTLS listener showed the
# same symptom codex/agy's proxy_auth cascade peer does at verify-egress-mediator.sh Deviation 1)
# can be answered before the ACL ever runs, producing NO audit line at all. `last_verdict` alone
# cannot tell "no new line because this attempt was blocked pre-ACL" from "no new line because
# THIS agent's attempt never landed and a PRIOR agent's line is still the most recent" -- so this
# always compares the verdict COUNT for the destination before/after, and retries (same 2s/3x
# shape as Deviation 1) until the count moves or the retries are spent.
mediator_probe() { # <agent> <dest_host> <probe-sh-script>
  local agent="$1" dest="$2" script="$3" before after attempt=1 out
  before="$(verdict_count "$dest")"
  while :; do
    out="$(in_agent_authed "$agent" "$script")"
    after="$(verdict_count "$dest")"
    [ "$after" -gt "$before" ] && break
    [ "$attempt" -lt 3 ] || break
    note "$agent -> $dest: attempt $attempt produced no new audit line (http_code=$out) -- cold listener/peer, retrying"
    attempt=$(( attempt + 1 ))
    sleep 2
  done
  last_verdict "$dest"
}

# SF-2 Decision (deviation, recorded 2026-09-11): a fresh `docker exec` session does NOT inherit
# the proxy credential `inject_proxy_credential` splices into HTTPS_PROXY/HTTP_PROXY -- that
# splice is an `export` in the entrypoint's OWN process (PID 1), which exec does not attach to.
# Verified live: `docker exec <codex> env` shows the credential-free URL from compose
# `environment:`; `/proc/1/environ` inside the same container shows the real spliced one. A curl
# run under plain `in_agent` for codex/agy would be answered 407 and misread a credential-
# delivery gap as a network-level block. `in_agent_authed` re-sources PID1's OWN live proxy env
# before running the command, so the exec'd curl presents the SAME credential the real agent
# process does -- not a test-reconstructed one. Harmless for claude, whose listener authenticates
# by client certificate rather than a proxy credential.
in_agent_authed() { # <agent> <sh-script>
  docker exec "$(agent_ctr "$1")" sh -c '
    for kv in $(tr "\0" "\n" < /proc/1/environ | grep -E "^(HTTPS?_PROXY|https?_proxy)="); do
      export "$kv"
    done
    eval "$1"
  ' _ "$2" 2>&1
}
# The curl flags claude's listener needs (mTLS) and no other agent does. The cert/key paths
# are static secret mounts (Interface Contract 5), so plain exec already sees them.
curl_client_flags() { # <agent>
  case " $MTLS_AGENTS " in
    # `--proxy-cert`/`--proxy-key`, not `--cert`/`--key`: claude's proxy URL is https://, so the
    # client certificate is presented on the TLS session to the PROXY itself, not on the (also
    # TLS, but separate) session to the destination through the CONNECT tunnel. Measured live
    # 2026-09-11: `--cert`/`--key` here produced "tlsv13 alert certificate required" -- the
    # front listener's mTLS requirement is on the proxy leg.
    *" $1 "*) printf -- '--proxy-cert "$CLAUDE_CODE_CLIENT_CERT" --proxy-key "$CLAUDE_CODE_CLIENT_KEY"' ;;
  esac
}
# The identity_source a verdict line for this agent SHOULD carry, derived the same way
# verify-egress-mediator.sh derives it.
expected_idsrc() { # <agent>
  case " $MTLS_AGENTS " in *" $1 "*) printf 'listener+mtls'; return ;; esac
  case " $PROXY_AUTH_AGENTS " in *" $1 "*) printf 'listener+proxy_auth'; return ;; esac
  printf 'listener'
}

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
  "${COMPOSE_EGRESS[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
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

# ---------------------------------------------------------------------------
# Phase 3 -- T3 HTTP/HTTPS exfil, T7 metadata: from inside real agent containers, through the
# real mediator/fixture stack (test-fixtures policy), via each agent's OWN proxy env and identity.
# ---------------------------------------------------------------------------
phase 3 "T3 exfil + T7 metadata (test-fixtures policy, real agent proxy env, all agents)"

echo "--- bringing up the mediator + fixtures (test-fixtures policy) ---"
"${COMPOSE_EGRESS[@]}" build >/dev/null 2>&1 || { fail "egress stack image build"; exit 1; }
"${COMPOSE_EGRESS[@]}" up -d egress-mediator fixture-dns fixture-collector fixture-neighbour >/dev/null 2>&1 \
  || { fail "egress stack bring-up"; exit 1; }
for _ in $(seq 1 60); do med true >/dev/null 2>&1 && break; sleep 1; done
med true >/dev/null 2>&1 || { fail "mediator did not come up"; "${COMPOSE_EGRESS[@]}" logs egress-mediator | tail -30; exit 1; }
pass "mediator + fixtures up under test-fixtures policy"

start_agents COMPOSE_EGRESS || exit 1

for a in "${AGENTS[@]}"; do
  idsrc="$(expected_idsrc "$a")"
  cflags="$(curl_client_flags "$a")"

  # T3: HTTP/HTTPS exfil to a non-allowlisted collector, driven through the agent's own proxy
  # env (credential included for codex/agy -- Decision, in_agent_authed above).
  line="$(mediator_probe "$a" denied.fixture.lab "curl -sS -k --proxy-insecure -o /dev/null -w '%{http_code}' --max-time 8 $cflags https://denied.fixture.lab/")"
  verdict="$(printf '%s' "$line" | jq -r '.verdict // "missing"')"
  agent_ok="$(printf '%s' "$line" | jq -r --arg a "$a" '.agent == $a')"
  idsrc_ok="$(printf '%s' "$line" | jq -r --arg i "$idsrc" '.identity_source == $i')"
  if [ "$verdict" = "deny" ] && [ "$agent_ok" = "true" ] && [ "$idsrc_ok" = "true" ]; then
    pass "T3 [$a]: exfil to denied.fixture.lab refused, on the audit trail, attributable ($idsrc)"
    record http_exfiltration T3 "$a" true true null true "$idsrc" denied.fixture.lab \
      "$(printf '%s' "$line" | jq -r '.verdict')" "$(printf '%s' "$line" | jq -r '.control')" \
      "$(printf '%s' "$line" | jq -r '.reason')" ""
  else
    fail "T3 [$a]: expected deny/attributable($idsrc) for denied.fixture.lab, got: $line"
    record http_exfiltration T3 "$a" false false null false "$idsrc" denied.fixture.lab \
      "$verdict" unknown unexpected "SECURITY: $line"
  fi

  # T7: cloud metadata endpoint, via the proxy (169.254.0.0/16 denylisted, R5.6).
  line="$(mediator_probe "$a" 169.254.169.254 "curl -sS -k --proxy-insecure -o /dev/null -w '%{http_code}' --max-time 8 $cflags https://169.254.169.254/")"
  verdict="$(printf '%s' "$line" | jq -r '.verdict // "missing"')"
  agent_ok="$(printf '%s' "$line" | jq -r --arg a "$a" '.agent == $a')"
  if [ "$verdict" = "deny" ] && [ "$agent_ok" = "true" ]; then
    pass "T7 [$a]: metadata endpoint refused, on the audit trail"
    record metadata_endpoint_denial T7 "$a" true true null true "$idsrc" 169.254.169.254 \
      "$verdict" "$(printf '%s' "$line" | jq -r '.control')" "$(printf '%s' "$line" | jq -r '.reason')" ""
  else
    fail "T7 [$a]: expected deny for 169.254.169.254, got: $line"
    record metadata_endpoint_denial T7 "$a" false false null false "$idsrc" 169.254.169.254 \
      "$verdict" unknown unexpected "SECURITY: $line"
  fi
done

# ---------------------------------------------------------------------------
# Phase 4 -- raw TCP (no proxy, no route) and network-isolation routability (no default route,
# WAN connect fails). Invisible to the egress log by construction -- the residual R12.8 asks to
# be recorded, not fixed (prd.md:209).
# ---------------------------------------------------------------------------
phase 4 "T5 raw TCP + routability residual (no mediator on the path, all agents)"

for a in "${AGENTS[@]}"; do
  idsrc="$(expected_idsrc "$a")"

  # T5: raw TCP straight to the fixture collector's egress-net address. The agent is not
  # attached to egress-net at all -- there is no route but the proxy, structurally (D2-adjacent).
  out="$(in_agent "$a" "timeout 5 bash -c 'echo > /dev/tcp/$FIXTURE_COLLECTOR/443' && echo reached")"
  if printf '%s' "$out" | grep -q reached; then
    fail "T5 [$a]: raw socket reached $FIXTURE_COLLECTOR directly -- SECURITY"
    record raw_tcp_egress T5 "$a" false false null true "$idsrc" "$FIXTURE_COLLECTOR" \
      allow none route_exists "SECURITY: raw TCP reached the fixture directly"
  else
    pass "T5 [$a]: raw TCP to $FIXTURE_COLLECTOR fails -- no route but the proxy"
    record raw_tcp_egress T5 "$a" true false null true "$idsrc" "$FIXTURE_COLLECTOR" \
      deny namespace no_route "raw-socket residual: blocked, not logged (prd.md:209)"
  fi

  # network-isolation routability: no default route, and a raw WAN connect attempt fails.
  routes="$(in_agent "$a" 'ip route 2>&1')"
  if printf '%s' "$routes" | grep -q '^default'; then
    fail "network_isolation_routability [$a]: a default route exists: $routes"
    record network_isolation_routability T38 "$a" false false null true "$idsrc" 1.1.1.1 \
      allow none default_route_present "SECURITY: $routes"
  else
    pass "network_isolation_routability [$a]: no default route ($routes)"
    wan="$(in_agent "$a" "timeout 5 bash -c 'echo > /dev/tcp/1.1.1.1/443' && echo reached")"
    if printf '%s' "$wan" | grep -q reached; then
      fail "network_isolation_routability [$a]: a raw WAN connect SUCCEEDED"
      record network_isolation_routability T38 "$a" false false null true "$idsrc" 1.1.1.1 \
        allow none wan_reachable "SECURITY"
    else
      pass "network_isolation_routability [$a]: raw WAN connect attempt fails"
      record network_isolation_routability T38 "$a" true false null true "$idsrc" 1.1.1.1 \
        deny namespace no_default_route "raw-socket residual: blocked, not logged"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Phase 5 -- ICMP: CAP_NET_RAW dropped, ping_group_range unset. Expected EPERM at socket()
# creation -- triply blocked (capability, no default route, mediator ip_forward=0), none logged.
# ---------------------------------------------------------------------------
phase 5 "ICMP raw socket (python3, all agents)"

for a in "${AGENTS[@]}"; do
  idsrc="$(expected_idsrc "$a")"
  if ! in_agent "$a" 'command -v python3' >/dev/null 2>&1; then
    fail "ICMP [$a]: python3 not present in image -- cannot exercise the scenario"
    record icmp_egress ICMP "$a" true false null true "$idsrc" 1.1.1.1 \
      deny capability tool_absent "python3 absent"
    continue
  fi
  out="$(in_agent "$a" "python3 -c \"import socket; socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_ICMP)\" 2>&1")"
  if printf '%s' "$out" | grep -qi 'PermissionError\|Operation not permitted\|EPERM'; then
    pass "ICMP [$a]: raw socket creation fails with EPERM (CAP_NET_RAW dropped)"
    note "$out"
    record icmp_egress ICMP "$a" true false null true "$idsrc" 1.1.1.1 \
      deny capability eperm_at_socket_creation "$out"
  else
    fail "ICMP [$a]: raw socket creation did NOT fail with EPERM -- SECURITY"
    note "$out"
    record icmp_egress ICMP "$a" false false null true "$idsrc" 1.1.1.1 \
      allow none raw_socket_permitted "SECURITY: $out"
  fi
done

# ---------------------------------------------------------------------------
# Phase 6 -- agent-to-agent reachability. Direct: no route between per-agent internal networks
# (D2). Relay: the mediator's own allowlist default-deny refuses a CONNECT to another agent's
# subnet (Decision 4) -- the split is recorded, not collapsed.
# ---------------------------------------------------------------------------
phase 6 "agent-to-agent reachability (direct + relay, all agents)"

start_agents COMPOSE_EGRESS || exit 1

declare -A AGENT_IP
for a in "${AGENTS[@]}"; do
  AGENT_IP[$a]="$(docker inspect "$(agent_ctr "$a")" \
    --format "{{ (index .NetworkSettings.Networks \"${PROJECT}_${a}-net\").IPAddress }}" 2>/dev/null)"
done

for a in "${AGENTS[@]}"; do
  idsrc="$(expected_idsrc "$a")"
  for b in "${AGENTS[@]}"; do
    [ "$a" = "$b" ] && continue
    target="${AGENT_IP[$b]:-}"
    [ -n "$target" ] || { note "A2A [$a->$b]: no address recorded for $b, skipping"; continue; }

    # Direct: raw connect from $a's container straight to $b's container IP -- no route,
    # because the two agents sit on separate internal:true networks (D2).
    out="$(in_agent "$a" "timeout 5 bash -c 'echo > /dev/tcp/$target/443' && echo reached")"
    if printf '%s' "$out" | grep -q reached; then
      fail "A2A direct [$a->$b @ $target]: raw connect SUCCEEDED -- SECURITY"
      record agent_to_agent_reachability T38 "$a" false false null true "$idsrc" "$target" \
        allow none route_exists "SECURITY: direct A2A route"
    else
      pass "A2A direct [$a->$b @ $target]: no route"
      record agent_to_agent_reachability T38 "$a" true false null true "$idsrc" "$target" \
        deny namespace no_route "raw-socket residual: A2A has no route but the mediator relay"
    fi
  done

  # Relay: a proxied CONNECT to another agent's SUBNET (not container IP -- an arbitrary
  # unlisted host on it) is refused by the allowlist default-deny, not by a CIDR rule
  # (test-fixtures' denylist does not cover 172.31.x -- Decision 4).
  other="172.31.20.99"
  case "$a" in codex) other="172.31.10.99" ;; agy) other="172.31.10.98" ;; esac
  line="$(mediator_probe "$a" "$other" "curl -sS -k --proxy-insecure -o /dev/null -w '%{http_code}' --max-time 8 $(curl_client_flags "$a") https://$other/")"
  verdict="$(printf '%s' "$line" | jq -r '.verdict // "missing"')"
  if [ "$verdict" = "deny" ]; then
    pass "A2A relay [$a -> $other]: mediator refuses a CONNECT to another agent's subnet"
    record agent_to_agent_reachability T38 "$a" true true null true "$idsrc" "$other" \
      "$verdict" "$(printf '%s' "$line" | jq -r '.control')" "$(printf '%s' "$line" | jq -r '.reason')" ""
  else
    fail "A2A relay [$a -> $other]: expected deny, got: $line"
    record agent_to_agent_reachability T38 "$a" false false null true "$idsrc" "$other" \
      "$verdict" unknown unexpected "SECURITY: $line"
  fi
done

stop_agents

echo
echo "=== SF-1/SF-2 record file: $RECORD_FILE ==="
cat "$RECORD_FILE"

if [ "$FAILED" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "ONE OR MORE CHECKS FAILED"
  exit 1
fi
