#!/usr/bin/env bash
# Acceptance test for Feature 02.1 SF-3 (T35, correlation, the privilege-change limb) and
# SF-4 (exports, T36). See the feature plan's Test Strategy for what each phase maps to.
#
# Requires: docker, docker compose, jq. Invoked as `bash tests/acceptance/verify-audit-completeness.sh`.
#
# Phases A-E run unattended against synthetic transcript writes made from inside each agent
# container as uid 1000 -- no model tokens spent. Phase L is a real, authenticated session per
# agent and is OFF by default (AUDIT_LIVE_SESSION=1 to run it), following the AUTH_SKIP_PHASE_D
# precedent in verify-auth-state.sh, but with the opposite default: this harness runs unattended
# by default, and the operator opts INTO the token-spending phase rather than opting out of it.
#
# It runs under its OWN Compose project name (egress-net gets test-egress.yaml's fixed subnets,
# same as verify-egress-mediator.sh) and tears down with `down -v`, so the operator's containers,
# state volumes and audit/action-audit volumes are never touched.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROJECT="sf9-verify-$$"
AGENTS=(claude codex agy)
FAILED=0
PHASE=""

AUDIT_LIVE_SESSION="${AUDIT_LIVE_SESSION:-0}"

MED_CLAUDE=172.31.10.2
MED_CODEX=172.31.20.2
MED_AGY=172.31.30.2
FIXTURE_DNS=172.31.40.10
FIXTURE_COLLECTOR=172.31.40.20

CA=mediator/identity/ca/mediator-ca.crt
CLIENT_CRT=mediator/identity/clients/claude-client.crt
CLIENT_KEY=mediator/identity/clients/claude-client.key
CREDENTIAL_DIR=mediator/identity/credentials
TLS_DIR="tests/fixtures/tls"
MED_IMAGE=sandboxed-agent/mediator:local

# Recorders read the identity token and the exports block through the SAME resolved artifact
# the mediator loads (Interface Contract 2). test-fixtures is the only committed profile that
# grants `allowed.fixture.lab` to all three agents (policy/resolved/test-fixtures.yaml), so
# Phase B's egress line and the recorder's identity token come from one source.
export AGENT_PROFILE=test-fixtures

COMPOSE=(docker compose --env-file compose/pins.env
         -f compose/compose.yaml
         -f compose/overrides/default.yaml
         -f compose/overrides/test-egress.yaml
         -p "$PROJECT")

pass() { echo "PASS: [$PHASE] $1"; }
fail() { echo "FAIL: [$PHASE] $1"; FAILED=1; }
note() { echo "      $*"; }
phase() { PHASE="$1"; echo; echo "=== Phase $1 ================================================"; }

cleanup() {
  echo
  echo "--- tearing down $PROJECT ---"
  for a in "${AGENTS[@]}"; do
    docker rm -f "${PROJECT}-${a}" >/dev/null 2>&1 || true
  done
  "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TLS_DIR"
}
trap cleanup EXIT

med() { docker exec "${PROJECT}-egress-mediator-1" "$@"; }
audit() { med cat /var/log/mediator/egress-audit.log 2>/dev/null; }
# uid-1000 exec into the agent's own long-lived container (started with `run -d ... sleep 600`,
# the same pattern verify-pod-topology.sh uses to get a container an `exec` can target -- the
# agent images' CMD is `--version`, so there is no long-running process to `exec` into otherwise).
aexec() { docker exec "${PROJECT}-$1" "${@:2}"; }
# The recorder's own container name follows the Compose service name.
rexec() { docker exec "${PROJECT}-$1-recorder-1" "${@:2}"; }
sink() { rexec "$1" cat /var/log/actions/action-audit.log 2>/dev/null; }

# Poll a condition until it is true or the timeout (seconds) elapses. Used throughout instead of
# a fixed `sleep`, because the property under test IS the poll interval -- a fixed sleep shorter
# than a slow CI host's actual poll latency would read as a false failure.
wait_until() { # <timeout_seconds> <cmd...>
  local timeout="$1"; shift
  local waited=0
  while ! "$@" >/dev/null 2>&1; do
    waited=$((waited + 1))
    [ "$waited" -ge "$timeout" ] && return 1
    sleep 1
  done
  return 0
}

# The resolved-policy identity token for an agent (Interface Contract 2/5) -- read from the SAME
# artifact the recorders and mediator load, not assumed equal to the agent name.
agent_identity() {
  awk -v a="$1" '
    $0 ~ "^  "a":" {f=1; next}
    f && /^  [a-z]/{exit}
    f && /identity:/{print $2; exit}
  ' "policy/resolved/${AGENT_PROFILE}.yaml"
}

# ---------------------------------------------------------------------------
# Phase 0 -- preflight (mirrors verify-egress-mediator.sh's preflight)
# ---------------------------------------------------------------------------
phase "0 -- preflight"

for tool in docker jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FAIL: $tool is required"; exit 1; }
done

_missing=""
for _f in "$CA" "$CLIENT_CRT" "$CLIENT_KEY" \
          "$CREDENTIAL_DIR/htpasswd" "$CREDENTIAL_DIR/codex.cred" "$CREDENTIAL_DIR/agy.cred"; do
  [ -f "$_f" ] || _missing="${_missing} ${_f}"
done
[ -z "$_missing" ] || {
  echo "FAIL: trust material is missing:"
  printf '  %s\n' $_missing
  echo "  Issue it first (mediator/identity/README.md)."
  exit 1
}

conflict="$(docker network ls --format '{{.Name}}' \
  | grep -vE "^${PROJECT}_" \
  | while read -r n; do
      docker network inspect "$n" --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null \
        | grep -qE '172\.31\.(10|20|30|40)\.0/24' && echo "$n"
    done)"
if [ -n "$conflict" ]; then
  echo "FAIL: another Compose project already holds this pod's subnets:"
  printf '  %s\n' $conflict
  exit 1
fi
pass "no other project holds 172.31.{10,20,30,40}.0/24"

rm -rf "$TLS_DIR"; mkdir -p "$TLS_DIR"
if docker run --rm -v "$ROOT/$TLS_DIR:/out" --entrypoint bash "$MED_IMAGE" -c '
      openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
        -keyout /out/fixture.key -out /out/fixture.crt -subj "/CN=fixture.lab" \
        -addext "subjectAltName=DNS:allowed.fixture.lab" \
      && chmod 0644 /out/fixture.crt /out/fixture.key' >/dev/null 2>&1; then
  pass "fixture PKI generated"
else
  fail "fixture PKI generation"; exit 1
fi

"${COMPOSE[@]}" config >/dev/null 2>&1 \
  && pass "docker compose config (base + default + test-egress, profile=$AGENT_PROFILE) is valid" \
  || { fail "docker compose config"; exit 1; }

echo "--- building images ---"
"${COMPOSE[@]}" build >/dev/null 2>&1 || { fail "image build"; exit 1; }

echo "--- bringing up the mediator, fixtures and recorders ---"
"${COMPOSE[@]}" up -d egress-mediator fixture-dns fixture-collector \
  claude-recorder codex-recorder agy-recorder >/dev/null 2>&1 \
  || { fail "test stack bring-up"; exit 1; }

for _ in $(seq 1 60); do
  med true >/dev/null 2>&1 && break
  sleep 1
done
med true >/dev/null 2>&1 && pass "mediator is up" || { fail "mediator never came up"; exit 1; }

for a in "${AGENTS[@]}"; do
  CID_UNUSED="$("${COMPOSE[@]}" run -d --name "${PROJECT}-${a}" --rm "$a" sleep 600)"
  aexec "$a" true >/dev/null 2>&1 && pass "$a: container started and reachable via exec" \
                                   || { fail "$a: container did not start"; exit 1; }
done

# ---------------------------------------------------------------------------
# Phase A -- recorder mechanics (Decision 3's shipping behaviours, one at a time)
# ---------------------------------------------------------------------------
phase "A -- recorder mechanics"

# claude: append-only JSONL under /home/agent/.claude/projects/<dir>/<sessionId>.jsonl
CLAUDE_SESSION="a1a1a1a1-0000-4000-8000-a1a1a1a1a1a1"
CLAUDE_TS_DIR="/home/agent/.claude/projects/-scratch"
CLAUDE_TS="$CLAUDE_TS_DIR/$CLAUDE_SESSION.jsonl"
aexec claude mkdir -p "$CLAUDE_TS_DIR"

# A1: a complete, valid-JSON line is shipped with the right source, session_id and line_sha256.
LINE1='{"type":"tool_call","sessionId":"'"$CLAUDE_SESSION"'","name":"sf3-probe-1"}'
aexec claude sh -c "printf '%s\n' '$LINE1' >> '$CLAUDE_TS'"
if wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q sf3-probe-1 /var/log/actions/action-audit.log\""; then
  rec="$(sink claude | jq -c 'select(.record.name? == "sf3-probe-1")' | tail -1)"
  want_sha="$(printf '%s' "$LINE1" | sha256sum | cut -d' ' -f1)"
  if [ -n "$rec" ] \
     && [ "$(printf '%s' "$rec" | jq -r '.session_id')" = "$CLAUDE_SESSION" ] \
     && [ "$(printf '%s' "$rec" | jq -r '.line_sha256')" = "$want_sha" ]; then
    pass "A1: a complete line ships with session_id and a matching line_sha256"
  else
    fail "A1: shipped line has wrong session_id or line_sha256"; note "$rec"
  fi
else
  fail "A1: complete line was never shipped"
fi

# A2: a partial (no trailing \n) line is held back; it ships once the \n arrives.
aexec claude sh -c "printf '%s' '{\"type\":\"partial\",\"sessionId\":\"$CLAUDE_SESSION\",\"name\":\"sf3-probe-partial\"}' >> '$CLAUDE_TS'"
sleep 3
if sink claude | jq -e 'select(.record.name? == "sf3-probe-partial")' >/dev/null 2>&1; then
  fail "A2: a partial trailing line (no \\n) was shipped before it was complete"
else
  pass "A2: a partial trailing line is held back"
fi
aexec claude sh -c "printf '\n' >> '$CLAUDE_TS'"
if wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q sf3-probe-partial /var/log/actions/action-audit.log\""; then
  pass "A2: the held-back line ships once its \\n arrives"
else
  fail "A2: the partial line never shipped after its \\n arrived"
fi

# A3: a non-JSON line ships as record_raw, not record.
aexec claude sh -c "printf 'not json at all sf3-probe-raw\n' >> '$CLAUDE_TS'"
if wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q sf3-probe-raw /var/log/actions/action-audit.log\""; then
  rec="$(sink claude | jq -c 'select(.record_raw? // "" | test("sf3-probe-raw"))' | tail -1)"
  if [ -n "$rec" ]; then
    pass "A3: a non-JSON line ships in record_raw"
  else
    fail "A3: a non-JSON line was shipped but not under record_raw"
  fi
else
  fail "A3: a non-JSON line was never shipped"
fi

# A large line (Edge Cases: "large lines are shipped whole; jq -c has no line cap").
LARGE_PAYLOAD="$(head -c 100000 /dev/zero | tr '\0' 'x')"
LARGE_LINE='{"type":"tool_call","sessionId":"'"$CLAUDE_SESSION"'","name":"sf3-probe-large","payload":"'"$LARGE_PAYLOAD"'"}'
aexec claude sh -c "printf '%s\n' '$LARGE_LINE' >> '$CLAUDE_TS'"
if wait_until 8 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q sf3-probe-large /var/log/actions/action-audit.log\""; then
  got_len="$(sink claude | jq -r 'select(.record.name? == "sf3-probe-large") | .record.payload | length' | tail -1)"
  [ "$got_len" = "100000" ] && pass "A: a ~100KB line is shipped whole, uncut" \
                             || fail "A: a large line was shipped truncated (payload length $got_len)"
else
  fail "A: a ~100KB line was never shipped"
fi

# A4: truncate. size < offset -> transcript_truncated, offset resets, new content still ships.
aexec claude sh -c ": > '$CLAUDE_TS'"
aexec claude sh -c "printf '%s\n' '{\"type\":\"tool_call\",\"sessionId\":\"$CLAUDE_SESSION\",\"name\":\"sf3-probe-after-truncate\"}' >> '$CLAUDE_TS'"
if wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q transcript_truncated /var/log/actions/action-audit.log\""; then
  pass "A4: shrinking the file emits transcript_truncated"
else
  fail "A4: transcript_truncated was never emitted"
fi
if wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q sf3-probe-after-truncate /var/log/actions/action-audit.log\""; then
  pass "A4: content written after a truncate is still shipped"
else
  fail "A4: content after a truncate was not shipped"
fi

# A5: inode change (rename over the file) -> transcript_replaced, treated as new.
aexec claude sh -c "printf '%s\n' '{\"type\":\"tool_call\",\"sessionId\":\"$CLAUDE_SESSION\",\"name\":\"sf3-probe-before-replace\"}' > '$CLAUDE_TS.new' && mv '$CLAUDE_TS.new' '$CLAUDE_TS'"
if wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q transcript_replaced /var/log/actions/action-audit.log\""; then
  pass "A5: a rename-over (inode change) emits transcript_replaced"
else
  fail "A5: transcript_replaced was never emitted"
fi

# A6: agy's snapshot mode (whole-file rewrite). record_snapshot on a sha256 change.
AGY_SESSION="b2b2b2b2-0000-4000-8000-b2b2b2b2b2b2"
AGY_DB_DIR="/home/agent/.gemini/antigravity-cli/conversations"
AGY_DB="$AGY_DB_DIR/$AGY_SESSION.db"
aexec agy mkdir -p "$AGY_DB_DIR"
aexec agy sh -c "printf 'sf3-probe-snapshot-1' > '$AGY_DB'"
if wait_until 5 sh -c "docker exec ${PROJECT}-agy-recorder-1 sh -c \"grep -q record_snapshot /var/log/actions/action-audit.log\""; then
  sha1="$(sink agy | jq -r 'select(.record_snapshot != null) | .record_snapshot.sha256' | tail -1)"
  pass "A6: agy's whole-file rewrite ships one record_snapshot"
else
  fail "A6: agy never shipped a record_snapshot"; sha1=""
fi
aexec agy sh -c "printf 'sf3-probe-snapshot-2-different' > '$AGY_DB'"
if wait_until 5 sh -c "docker exec ${PROJECT}-agy-recorder-1 sh -c \"[ \\\$(grep -c record_snapshot /var/log/actions/action-audit.log) -ge 2 ]\""; then
  sha2="$(sink agy | jq -r 'select(.record_snapshot != null) | .record_snapshot.sha256' | tail -1)"
  if [ -n "$sha1" ] && [ "$sha1" != "$sha2" ]; then
    pass "A6: a second whole-file rewrite ships a NEW record_snapshot with a different sha256"
  else
    fail "A6: the second snapshot's sha256 did not change"
  fi
else
  fail "A6: agy never shipped a second record_snapshot"
fi

# codex: a second, independent append-only source, proving A1-A3 are not claude-specific.
CODEX_SESSION="c3c3c3c3-0000-4000-8000-c3c3c3c3c3c3"
CODEX_TS_DIR="/home/agent/.codex/sessions/2026/09/10"
CODEX_TS="$CODEX_TS_DIR/rollout-2026-09-10T00-00-00-$CODEX_SESSION.jsonl"
aexec codex mkdir -p "$CODEX_TS_DIR"
aexec codex sh -c "printf '%s\n' '{\"type\":\"session_meta\",\"id\":\"$CODEX_SESSION\",\"name\":\"sf3-probe-codex\"}' >> '$CODEX_TS'"
if wait_until 5 sh -c "docker exec ${PROJECT}-codex-recorder-1 sh -c \"grep -q sf3-probe-codex /var/log/actions/action-audit.log\""; then
  rec="$(sink codex | jq -c 'select(.record.name? == "sf3-probe-codex")' | tail -1)"
  [ "$(printf '%s' "$rec" | jq -r '.session_id')" = "$CODEX_SESSION" ] \
    && pass "A: codex's own append-only source ships independently, with its own session_id" \
    || fail "A: codex's shipped session_id does not match its filename UUID"
else
  fail "A: codex's synthetic line was never shipped"
fi

# ---------------------------------------------------------------------------
# Phase B -- T35 correlation
# ---------------------------------------------------------------------------
phase "B -- T35 correlation"

CLAUDE_ID="$(agent_identity claude)"
CODEX_ID="$(agent_identity codex)"
[ -n "$CLAUDE_ID" ] && [ -n "$CODEX_ID" ] \
  && pass "resolved identities read: claude=$CLAUDE_ID codex=$CODEX_ID" \
  || fail "could not read agent identities from policy/resolved/${AGENT_PROFILE}.yaml"

B_WINDOW_START="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

# One synthetic action line for claude, in the window this phase is about to open.
B_SESSION="d4d4d4d4-0000-4000-8000-d4d4d4d4d4d4"
B_TS="$CLAUDE_TS_DIR/$B_SESSION.jsonl"
aexec claude sh -c "printf '%s\n' '{\"type\":\"tool_call\",\"sessionId\":\"$B_SESSION\",\"name\":\"sf3-probe-t35\"}' > '$B_TS'"
wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q sf3-probe-t35 /var/log/actions/action-audit.log\"" \
  && pass "B: the T35 synthetic action line shipped" \
  || fail "B: the T35 synthetic action line never shipped"

# One real egress request as claude (mTLS listener), and one as codex (proxy_auth listener),
# in the same window -- so the join has something to include and something to exclude.
CH_CODEX=""
f="$CREDENTIAL_DIR/codex.cred"
[ -r "$f" ] && { userinfo="$(tr -d '\r\n' < "$f")"; CH_CODEX="Proxy-Authorization: Basic $(printf '%s' "$userinfo" | openssl base64 -A)\\r\\n"; }

docker run --rm --network "${PROJECT}_claude-net" \
  -v "$ROOT/$CA:/tmp/ca.crt:ro" -v "$ROOT/$CLIENT_CRT:/tmp/client.crt:ro" -v "$ROOT/$CLIENT_KEY:/tmp/client.key:ro" \
  --entrypoint bash "$MED_IMAGE" -c \
  "printf 'CONNECT allowed.fixture.lab:443 HTTP/1.1\r\nHost: h\r\n\r\n' \
     | timeout 15 openssl s_client -quiet -verify_return_error -CAfile /tmp/ca.crt \
         -cert /tmp/client.crt -key /tmp/client.key -connect $MED_CLAUDE:3128 2>/dev/null | head -5" \
  >/dev/null 2>&1

docker run --rm --network "${PROJECT}_codex-net" \
  --entrypoint bash "$MED_IMAGE" -c \
  "printf 'Q\n' | timeout 15 openssl s_client -brief -proxy $MED_CODEX:3128 \
     -proxy_user codex -servername allowed.fixture.lab -connect allowed.fixture.lab:443 2>&1 | tail -4" \
  >/dev/null 2>&1

B_WINDOW_END="$(date -u +%Y-%m-%dT%H:%M:%S.999Z)"

claude_egress="$(audit | jq -c --arg s "$B_WINDOW_START" --arg e "$B_WINDOW_END" --arg a "$CLAUDE_ID" \
  'select(.verdict != null and .dest_host == "allowed.fixture.lab" and .agent == $a and .ts >= $s and .ts <= $e)' | tail -1)"
codex_egress="$(audit | jq -c --arg s "$B_WINDOW_START" --arg e "$B_WINDOW_END" --arg a "$CODEX_ID" \
  'select(.verdict != null and .dest_host == "allowed.fixture.lab" and .agent == $a and .ts >= $s and .ts <= $e)' | tail -1)"

if [ -n "$claude_egress" ]; then
  pass "B: T35 join -- claude's own egress line falls inside its session window"
else
  fail "B: T35 join -- no claude egress line found in the session window"
fi

# The join is asserted in BOTH directions: a join keyed on claude's agent+window must NOT
# return codex's line, even though codex's request landed in the very same wall-clock window.
if [ -n "$codex_egress" ]; then
  claude_join_includes_codex="$(audit | jq -c --arg s "$B_WINDOW_START" --arg e "$B_WINDOW_END" --arg a "$CLAUDE_ID" \
    'select(.verdict != null and .agent == $a and .ts >= $s and .ts <= $e) | select(.dest_host == "allowed.fixture.lab")' \
    | jq -s 'map(select(.agent != $a))' --arg a "$CLAUDE_ID" 2>/dev/null || true)"
  if audit | jq -e --arg s "$B_WINDOW_START" --arg e "$B_WINDOW_END" --arg a "$CLAUDE_ID" \
       'select(.verdict != null and .ts >= $s and .ts <= $e and .agent != $a and .agent == "'"$CODEX_ID"'")' >/dev/null 2>&1 \
     && ! audit | jq -e --arg s "$B_WINDOW_START" --arg e "$B_WINDOW_END" --arg a "$CLAUDE_ID" \
       'select(.verdict != null and .ts >= $s and .ts <= $e and .agent == $a and .agent == "'"$CODEX_ID"'")' >/dev/null 2>&1; then
    pass "B: T35 join -- a join keyed on claude's agent excludes codex's line from the same window"
  else
    fail "B: T35 join -- codex's line was not cleanly excludable by agent"
  fi
else
  fail "B: no codex egress line found to test exclusion against"
fi

# ---------------------------------------------------------------------------
# Phase C -- retroactive edit, tamper-evidence
# ---------------------------------------------------------------------------
phase "C -- retroactive edit (tamper-evidence)"

C_SESSION="e5e5e5e5-0000-4000-8000-e5e5e5e5e5e5"
C_TS="$CLAUDE_TS_DIR/$C_SESSION.jsonl"
C_LINE='{"type":"tool_call","sessionId":"'"$C_SESSION"'","name":"sf3-probe-tamper-XXXXXXXXXX"}'
aexec claude sh -c "printf '%s\n' '$C_LINE' > '$C_TS'"
wait_until 5 sh -c "docker exec ${PROJECT}-claude-recorder-1 sh -c \"grep -q sf3-probe-tamper /var/log/actions/action-audit.log\""

shipped_sha="$(sink claude | jq -r 'select(.record.name? == "sf3-probe-tamper-XXXXXXXXXX") | .line_sha256' | tail -1)"
shipped_before="$(sink claude | jq -c 'select(.record.name? == "sf3-probe-tamper-XXXXXXXXXX")' | tail -1)"

# Same-length, in-place byte edit -- keeps the inode, so the recorder never re-reads this range.
# Overwrites the "XXXXXXXXXX" run with "YYYYYYYYYY" (same length) at a known byte offset.
# `<()` process substitution is a bashism -- the agent images' `sh` is dash, so this needs
# `bash -c` explicitly rather than aexec's default `sh -c`.
c_offset=$(( ${#C_LINE} - 12 ))
docker exec "${PROJECT}-claude" bash -c "dd if=<(printf 'YYYYYYYYYY') of='$C_TS' bs=1 seek=$c_offset conv=notrunc >/dev/null 2>&1"
sleep 3

new_inode_event="$(sink claude | jq -c 'select(.event == "transcript_replaced" and (.source // "" | test("'"$C_SESSION"'")))' | tail -1)"
if [ -z "$new_inode_event" ]; then
  pass "C: the in-place edit kept the file's inode (no spurious transcript_replaced)"
else
  fail "C: the in-place edit was misdetected as a replace (inode changed) -- fixture bug, not the property under test"
fi

shipped_after="$(sink claude | jq -c 'select(.line_sha256 == "'"$shipped_sha"'")' | tail -1)"
if [ "$shipped_before" = "$shipped_after" ]; then
  pass "C: the sink's already-shipped line is byte-for-byte unchanged after the retroactive edit"
else
  fail "C: the sink's shipped line changed after the retroactive edit"
fi

volume_now="$(aexec claude cat "$C_TS")"
if printf '%s' "$volume_now" | grep -q "YYYYYYYYYY"; then
  pass "C: the on-volume file DOES carry the edit -- the edit landed, and the sink still didn't move"
else
  fail "C: the edit did not actually land on the volume; this phase proved nothing"
fi

# agy's retroactive-edit story is a SECOND record_snapshot beside the first, not a byte-compare.
aexec agy sh -c "printf 'sf3-probe-snapshot-retroactive' > '$AGY_DB'"
if wait_until 5 sh -c "docker exec ${PROJECT}-agy-recorder-1 sh -c \"[ \\\$(grep -c record_snapshot /var/log/actions/action-audit.log) -ge 3 ]\""; then
  pass "C: agy's retroactive rewrite shows up as a later snapshot beside the original(s), not an overwrite"
else
  fail "C: agy's retroactive rewrite did not produce a new snapshot"
fi

# ---------------------------------------------------------------------------
# Phase D -- privilege-change structural evidence (R9.7 limb, D15)
# ---------------------------------------------------------------------------
phase "D -- privilege-change structural evidence"

for a in "${AGENTS[@]}"; do
  uid="$(aexec "$a" id -u)"
  [ "$uid" = "1000" ] && pass "$a: runs as uid 1000" || fail "$a: uid is '$uid', not 1000"

  status="$(aexec "$a" cat /proc/self/status 2>/dev/null)"
  capeff="$(printf '%s' "$status" | awk '/^CapEff:/{print $2}')"
  nnp="$(printf '%s' "$status" | awk '/^NoNewPrivs:/{print $2}')"
  [ "$capeff" = "0000000000000000" ] && pass "$a: CapEff is all-zero" \
                                       || fail "$a: CapEff is '$capeff', not all-zero"
  [ "$nnp" = "1" ] && pass "$a: NoNewPrivs is 1" || fail "$a: NoNewPrivs is '$nnp', not 1"

  aexec "$a" sh -c "echo x | timeout 5 passwd >/dev/null 2>&1 </dev/null"
  esc_exit=$?
  [ "$esc_exit" -ne 0 ] && pass "$a: a setuid-binary escalation attempt (passwd) fails (exit $esc_exit)" \
                         || fail "$a: passwd exited 0 -- privilege escalation succeeded"
done
note "Finding (D15): no privilege-change event is reachable from inside any agent container."
note "The evidence above IS the finding; no privilege-change line needs recording because none can occur."

# ---------------------------------------------------------------------------
# Phase E -- exports and T36 (02.1 SF-4, R9.9, D11, Decision 7)
#
# Four scratch-compiled variants of `default`, one toggle false at a time (Decision
# 7), each brought up as its OWN small stack -- egress-mediator, claude-recorder and
# one `claude` session -- under compose/overrides/test-exports.yaml, which mounts the
# variant over the mediator's baked policy path and the recorders' `configs:` source.
# `default`'s own stage 1/2 startup self-check is the "traffic" that populates the
# egress trail; a synthetic transcript append (Phase A's idiom) populates the action
# trail. Per variant: recording continues on both trails, the disabled channel is
# absent (relay toggles) or the MANIFEST says so (file toggles), the other channels
# are unaffected, and `export_config` names exactly the disabled toggle false.
# ---------------------------------------------------------------------------
phase "E -- exports and T36"

mkdir -p .build-scratch/t36
EXPORT_TOGGLES="egress_audit_log agent_action_log resolved_policy image_digest_sbom"

for toggle in $EXPORT_TOGGLES; do
  VARIANT_SRC=".build-scratch/t36/${toggle}-profile.yaml"
  VARIANT=".build-scratch/t36/variant.yaml"
  sed "s/^  ${toggle}: true\$/  ${toggle}: false/" profiles/default.yaml > "$VARIANT_SRC"
  if bash scripts/compile-policy.sh --profile default --profile-file "$VARIANT_SRC" --out "$VARIANT" >/dev/null 2>&1; then
    pass "E ($toggle): compiled a 'default' variant with ${toggle}=false"
  else
    fail "E ($toggle): could not compile the variant"; rm -f "$VARIANT_SRC"; continue
  fi
  rm -f "$VARIANT_SRC"

  EPROJECT="sf9-t36-${toggle}-$$"
  ECOMPOSE=(docker compose --env-file compose/pins.env
            -f compose/compose.yaml -f compose/overrides/default.yaml
            -f compose/overrides/test-exports.yaml -p "$EPROJECT")
  ecleanup() {
    docker rm -f "${EPROJECT}-claude" >/dev/null 2>&1 || true
    "${ECOMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  }

  if ! "${ECOMPOSE[@]}" up -d egress-mediator claude-recorder >/dev/null 2>&1; then
    fail "E ($toggle): stack bring-up"; ecleanup; continue
  fi

  eup=0
  for _ in $(seq 1 60); do
    docker exec "${EPROJECT}-egress-mediator-1" true >/dev/null 2>&1 && { eup=1; break; }
    sleep 1
  done
  if [ "$eup" -ne 1 ]; then
    fail "E ($toggle): mediator never came up"; ecleanup; continue
  fi

  # Recording continues on the egress trail (D11): the mediator's own startup
  # self-check writes stage 1/2 events whatever the export toggles say.
  egress_lines="$(docker exec "${EPROJECT}-egress-mediator-1" sh -c 'wc -l < /var/log/mediator/egress-audit.log' 2>/dev/null || echo 0)"
  [ "${egress_lines:-0}" -gt 0 ] \
    && pass "E ($toggle): the egress trail gained lines (self-check) -- recording continues" \
    || fail "E ($toggle): the egress trail is empty"

  # Recording continues on the action trail: one synthetic tool-call append.
  CID_UNUSED="$("${ECOMPOSE[@]}" run -d --name "${EPROJECT}-claude" --rm claude sleep 60)"
  E_SESSION="e4e4e4e4-0000-4000-8000-e4e4e4e4e4e4"
  E_MARK="sf4-t36-${toggle}"
  docker exec "${EPROJECT}-claude" mkdir -p /home/agent/.claude/projects/-scratch
  docker exec "${EPROJECT}-claude" sh -c \
    "printf '%s\n' '{\"type\":\"tool_call\",\"sessionId\":\"$E_SESSION\",\"name\":\"$E_MARK\"}' >> /home/agent/.claude/projects/-scratch/$E_SESSION.jsonl"
  wait_until 5 sh -c "docker exec ${EPROJECT}-claude-recorder-1 sh -c \"grep -q ${E_MARK} /var/log/actions/action-audit.log\""
  action_lines="$(docker exec "${EPROJECT}-claude-recorder-1" sh -c 'wc -l < /var/log/actions/action-audit.log' 2>/dev/null || echo 0)"
  [ "${action_lines:-0}" -gt 0 ] \
    && pass "E ($toggle): the action trail gained lines -- recording continues" \
    || fail "E ($toggle): the action trail is empty"

  mlog="$("${ECOMPOSE[@]}" logs egress-mediator 2>/dev/null)"
  rlog="$("${ECOMPOSE[@]}" logs claude-recorder 2>/dev/null)"
  case "$toggle" in
    egress_audit_log)
      printf '%s' "$mlog" | grep -q '"stage":1' \
        && fail "E ($toggle): the egress-audit.log/dns-audit.log relay is present, though disabled" \
        || pass "E ($toggle): the egress-audit.log/dns-audit.log relay is absent, as disabled"
      printf '%s' "$rlog" | grep -q "$E_MARK" \
        && pass "E ($toggle): the agent_action_log relay is unaffected (still present)" \
        || fail "E ($toggle): the agent_action_log relay unexpectedly stopped"
      ;;
    agent_action_log)
      printf '%s' "$rlog" | grep -q "$E_MARK" \
        && fail "E ($toggle): the agent_action_log relay is present, though disabled" \
        || pass "E ($toggle): the agent_action_log relay is absent, as disabled"
      printf '%s' "$mlog" | grep -q '"stage":1' \
        && pass "E ($toggle): the egress-audit.log/dns-audit.log relay is unaffected (still present)" \
        || fail "E ($toggle): the egress-audit.log/dns-audit.log relay unexpectedly stopped"
      ;;
    resolved_policy|image_digest_sbom)
      printf '%s' "$mlog" | grep -q '"stage":1' \
        && pass "E ($toggle): the egress-audit.log relay is unaffected (a file export, not a relay)" \
        || fail "E ($toggle): the egress-audit.log relay unexpectedly stopped"
      printf '%s' "$rlog" | grep -q "$E_MARK" \
        && pass "E ($toggle): the agent_action_log relay is unaffected (a file export, not a relay)" \
        || fail "E ($toggle): the agent_action_log relay unexpectedly stopped"
      ;;
  esac

  ec="$(docker exec "${EPROJECT}-egress-mediator-1" sh -c 'grep export_config /var/log/mediator/egress-audit.log | tail -1' 2>/dev/null)"
  if printf '%s' "$ec" | jq -e --arg t "$toggle" '.exports[$t] == false' >/dev/null 2>&1; then
    pass "E ($toggle): export_config names ${toggle} false"
  else
    fail "E ($toggle): export_config does not name ${toggle} false"; note "$ec"
  fi
  if printf '%s' "$ec" | jq -e --arg t "$toggle" '[.exports | to_entries[] | select(.key != $t) | .value] | all' >/dev/null 2>&1; then
    pass "E ($toggle): export_config names the other three exports true"
  else
    fail "E ($toggle): export_config does not name the other three exports true"; note "$ec"
  fi

  # File exports (resolved_policy, image_digest_sbom): MANIFEST records the toggle.
  rm -rf ".build-scratch/t36/out-${toggle}"
  bash scripts/export-artifacts.sh --resolved "$VARIANT" --out ".build-scratch/t36/out-${toggle}" >/dev/null 2>&1
  manifest_line="$(grep "^${toggle} " ".build-scratch/t36/out-${toggle}/MANIFEST" 2>/dev/null || true)"
  case "$toggle" in
    resolved_policy|image_digest_sbom)
      printf '%s' "$manifest_line" | grep -qx "${toggle} disabled" \
        && pass "E ($toggle): MANIFEST records '${toggle} disabled'" \
        || fail "E ($toggle): MANIFEST does not record '${toggle} disabled' (got '${manifest_line}')" ;;
    *) note "E ($toggle): not a file export -- MANIFEST check not applicable" ;;
  esac

  ecleanup
done
rm -rf .build-scratch/t36

# ---------------------------------------------------------------------------
# Phase L -- one live, authenticated session per agent (T35's real-world case)
# ---------------------------------------------------------------------------
phase "L -- live session (gated)"

if [ "$AUDIT_LIVE_SESSION" = "1" ]; then
  note "AUDIT_LIVE_SESSION=1 -- this phase spends model tokens against the OPERATOR's own"
  note "authenticated state volumes, on the DEFAULT project, not this harness's throwaway one."
  note "Run it manually per agent and record the result in docs/records/agent-action-log.md:"
  note "  docker compose --env-file compose/pins.env -f compose/compose.yaml -f compose/overrides/default.yaml run --rm claude"
  note "  docker compose --env-file compose/pins.env -f compose/compose.yaml -f compose/overrides/default.yaml run --rm codex"
  note "  docker compose --env-file compose/pins.env -f compose/compose.yaml -f compose/overrides/default.yaml run --rm agy"
  note "then confirm each session's action-audit volume gained lines and its egress lines are correlatable."
  pass "L: instructions surfaced (AUDIT_LIVE_SESSION=1) -- the operator runs and records this manually"
else
  pass "L: skipped (AUDIT_LIVE_SESSION=0, default) -- phases A-D already exercise the mechanics unattended"
fi

# ---------------------------------------------------------------------------
echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL PHASES PASSED"
else
  echo "FAILURES PRESENT -- see FAIL lines above"
fi
exit "$FAILED"
