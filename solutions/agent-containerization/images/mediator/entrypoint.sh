#!/usr/bin/env bash
# Mediator entrypoint (01.3, SF-4 + SF-5).
#
# SF-4 brought the container up hardened and holding. SF-5 replaces the holding
# resolver with the real one: the pod's DNS authority, RENDERED from the resolved
# policy artifact so the configuration is generated and never hand-edited (SC-6).
#
# What runs here now:
#
#   * dnsdist  -- the DNS policy engine, on the mediator's static address on each
#                 agent network, port 53. Exact-match allowlist per agent, QTYPE
#                 restricted to A/AAAA, non-canonical QNAMEs refused, everything
#                 else REFUSED and forwarded nowhere, every decision audited.
#   * unbound  -- the re-originating resolver, on loopback. No policy. It exists
#                 because dnsdist proxies the client's packet and criterion 4
#                 requires a fresh query with the client's EDNS options dropped.
#   * squid    -- STILL HOLDING. Loopback only, `http_access deny all`. SF-6 owns
#                 the three agent-facing listeners and renders the real one from
#                 mediator/config/proxy.conf.tmpl.
#
# The two-daemon resolver is a verified necessity rather than a preference; the
# evidence, including what each stage fails to do alone, is in
# docs/records/resolver-verification.md.
set -euo pipefail

RUN_DIR=/run/mediator
AUDIT_DIR=/var/log/mediator
AUDIT_LOG="$AUDIT_DIR/egress-audit.log"
CACHE_LOG="$AUDIT_DIR/squid-cache.log"
DNS_AUDIT_LOG="$AUDIT_DIR/dns-audit.log"
SQUID_CONF="$RUN_DIR/squid.conf"
POLICY_CONF="$RUN_DIR/dnsdist.conf"
REORIGIN_CONF="$RUN_DIR/unbound.conf"
ERROR_DIR="$RUN_DIR/errors"

TMPL_DIR=/etc/mediator/config
POLICY_DIR=/etc/mediator/policy

# The re-originating resolver's loopback port. Not 53: that belongs to the policy
# engine on the agent networks, and this stage must never be the pod's front door.
REORIGIN_PORT=5353

MEDIATOR_PROFILE="${MEDIATOR_PROFILE:-default}"
RESOLVED_POLICY="$POLICY_DIR/${MEDIATOR_PROFILE}.yaml"

# Where allowlisted names are actually resolved. Docker's embedded resolver in this
# container's own namespace by default, which forwards to the daemon's configured
# upstreams -- so the pod inherits the operator's DNS rather than this repository
# hardcoding a third-party resolver, and the query leaves over `egress-net`, the
# mediator's only external interface.
#
# Criterion 4 says "forwarded to a named upstream on egress-net". Read as naming the
# path rather than requiring a container on that bridge: the traffic leaves through
# egress-net either way, and pointing at Docker's resolver keeps the mediator's
# resolution path identical to the one SF-1 verified Squid against, so control 2 and
# the resolver cannot disagree about what an allowlisted name resolves to.
#
# The acceptance harness overrides this to aim at its own controlled authoritative
# server (T4).
MEDIATOR_DNS_UPSTREAM="${MEDIATOR_DNS_UPSTREAM:-127.0.0.11}"

fail() { echo "mediator: FATAL: $*" >&2; exit 1; }
note() { echo "mediator: $*" >&2; }

# --------------------------------------------------------------- writable paths
# The rootfs is read-only (D15) and /run arrives as an empty tmpfs, so every
# writable path is created here. A missing one is a start failure, which is the
# intended failure mode: a mediator that silently could not open its audit log
# would be an enforcement point running without R9.1.
mkdir -p "$RUN_DIR" "$ERROR_DIR" /run/squid

[ -d "$AUDIT_DIR" ] || fail "$AUDIT_DIR is absent -- the audit volume is not mounted"
touch "$AUDIT_LOG" "$CACHE_LOG" "$DNS_AUDIT_LOG" 2>/dev/null \
  || fail "cannot write the audit sink at $AUDIT_DIR (uid $(id -u)). The named volume must be owned by the runtime uid; it inherits that from the image."

# ------------------------------------------------------------- error_directory
# `error_directory` REPLACES the packaged error set rather than overlaying it
# (docs/records/mediator-selection.md, operational findings), so the directory has
# to be composed: the packaged English pages first, then the mediator's own pages
# on top. SF-7 adds ERR_MEDIATOR_DENIED here.
if [ -d /usr/share/squid/errors/English ]; then
  cp -R /usr/share/squid/errors/English/. "$ERROR_DIR/"
else
  fail "packaged Squid error pages not found -- error_directory cannot be composed"
fi

# =============================================================== resolver render
# The agent networks. One `<agent>=<mediator address>/<prefix>` per agent, and it
# is the SAME fact as compose.yaml's `ipam` blocks, the agents' `dns:` literals and
# the listener certificates' iPAddress SANs. Those were already three copies with a
# guard between them (verify-pod-topology.sh); this is the fourth, and it is checked
# against the container's own interfaces below rather than trusted, so a renumber
# that misses one fails at start naming the field instead of silently serving the
# wrong agent's allowlist.
[ -n "${MEDIATOR_AGENT_NETWORKS:-}" ] \
  || fail "MEDIATOR_AGENT_NETWORKS is unset -- expected '<agent>=<addr>/<prefix>,...' (compose.yaml, egress-mediator). Refusing to serve DNS without knowing which network is which agent."

[ -f "$RESOLVED_POLICY" ] \
  || fail "resolved policy $RESOLVED_POLICY not found (profile '$MEDIATOR_PROFILE'). It is baked into the image from policy/resolved/ -- recompile with scripts/compile-policy.sh and rebuild."

# ipv4_network <addr> <prefix> -> the network address, so the rendered configuration
# reads as the subnet it actually matches rather than a host address with a mask
# hanging off it.
ipv4_network() {
  local a="$1" p="$2" o1 o2 o3 o4 ip mask net
  IFS=. read -r o1 o2 o3 o4 <<< "$a"
  ip=$(( (o1 << 24) | (o2 << 16) | (o3 << 8) | o4 ))
  mask=$(( (0xFFFFFFFF << (32 - p)) & 0xFFFFFFFF ))
  net=$(( ip & mask ))
  printf '%d.%d.%d.%d/%d' $(( (net >> 24) & 255 )) $(( (net >> 16) & 255 )) \
                          $(( (net >> 8) & 255 ))  $(( net & 255 )) "$p"
}

# Every value below is interpolated into a Lua configuration that IS the pod's DNS
# policy. Policy data becoming executable policy code is the whole risk, so the
# shapes are enforced here as well as in the compiler: the compiler is one producer
# today, and 01.5 adds pack composition, which makes the artifact a channel from
# third-party content into this render. Guarding only at the producer would put the
# check on the wrong side of that boundary -- the same argument the wildcard
# rejection already makes.
#
# A hostname label is letters, digits and hyphens, not leading or trailing a hyphen,
# 63 bytes at most; the name is 253 bytes at most. Nothing here can close a Lua
# string.
FQDN_RE='^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$'
# An agent name becomes part of a Lua VARIABLE name (`NAMES_<agent>`), so it must be
# an identifier and not merely quotable.
AGENT_RE='^[a-z][a-z0-9_]{0,31}$'

ACL_ENTRIES=""
LISTENERS=""
AGENT_NETS=""
AGENT_NAMESETS=""
AGENT_ALLOW_RULES=""
ALLOW_RULE_NAMES=""

IFS=',' read -r -a _agent_specs <<< "$MEDIATOR_AGENT_NETWORKS"
for spec in "${_agent_specs[@]}"; do
  agent="${spec%%=*}"
  cidr="${spec#*=}"
  addr="${cidr%%/*}"
  prefix="${cidr##*/}"

  [ -n "$agent" ] && [ "$agent" != "$spec" ] \
    || fail "MEDIATOR_AGENT_NETWORKS entry '$spec' is malformed -- expected '<agent>=<addr>/<prefix>'"
  [[ "$agent" =~ $AGENT_RE ]] \
    || fail "MEDIATOR_AGENT_NETWORKS names agent '$agent', which is not a valid identifier. It is interpolated into the Lua policy as a variable name, so it must match ${AGENT_RE}."
  [[ "$prefix" =~ ^[0-9]+$ ]] && [ "$prefix" -ge 8 ] && [ "$prefix" -le 32 ] \
    || fail "MEDIATOR_AGENT_NETWORKS entry '$spec' has no usable prefix length"

  # The declared address must actually be ours. Without this a renumber in
  # compose.yaml that misses this variable would leave dnsdist trying to bind an
  # address it does not hold -- or, worse, binding fine while attributing queries to
  # the wrong agent and applying the wrong allowlist.
  # `hostname -I` rather than `ip addr`: iproute2 is not installed, and adding it
  # to the enforcement point to read one list of addresses is not a trade worth
  # making.
  case " $(hostname -I 2>/dev/null) " in
    *" $addr "*) : ;;
    *) fail "MEDIATOR_AGENT_NETWORKS declares $addr for '$agent', but this container holds no such address (has: $(hostname -I 2>/dev/null)). The ipam block in compose.yaml and this variable are one fact; fix them together." ;;
  esac

  # The agent must exist in the resolved policy, or its allowlist would render empty
  # and every one of its names would be refused with nothing saying why.
  [ "$(yq eval ".agents | has(\"$agent\")" "$RESOLVED_POLICY")" = "true" ] \
    || fail "$RESOLVED_POLICY has no agents.$agent, but MEDIATOR_AGENT_NETWORKS declares a network for it"

  network="$(ipv4_network "$addr" "$prefix")"

  ACL_ENTRIES="${ACL_ENTRIES}${ACL_ENTRIES:+, }\"${network}\""
  LISTENERS="${LISTENERS}addLocal(\"${addr}:53\")   -- ${agent}"$'\n'
  AGENT_NETS="${AGENT_NETS}AGENT_NETS[\"${agent}\"] = newNMG(); AGENT_NETS[\"${agent}\"]:addMask(\"${network}\")"$'\n'

  # Exact names only. The compiler already refuses a wildcard entry at compile time
  # (scripts/compile-policy.sh) because the resolver matches exactly and a wildcard
  # would reopen DNS exfiltration; this stage is what makes that refusal meaningful.
  names="$(yq eval ".agents.${agent}.allow_fqdns[].fqdn" "$RESOLVED_POLICY" 2>/dev/null || true)"

  set_lua="NAMES_${agent} = newDNSNameSet()"$'\n'
  count=0
  while IFS= read -r fqdn; do
    [ -n "$fqdn" ] && [ "$fqdn" != "null" ] || continue
    case "$fqdn" in
      *'*'*) fail "$RESOLVED_POLICY: agents.${agent} allows the wildcard '$fqdn'. The resolver matches exactly; a wildcard here would forward every name beneath it (R5.4)." ;;
    esac
    # The name is about to become Lua source. Anything that is not a hostname is
    # refused here, at the boundary, rather than trusted from the artifact.
    [ "${#fqdn}" -le 253 ] && [[ "$fqdn" =~ $FQDN_RE ]] \
      || fail "$RESOLVED_POLICY: agents.${agent} allows '$fqdn', which is not a valid hostname. It is interpolated into the mediator's Lua policy, so a name carrying quotes, escapes or newlines would become policy CODE rather than policy data. Refusing to start."
    # Canonicalised at render time as well as at query time, so a base file written
    # with capitals cannot produce an entry no canonical query can ever match.
    lower="$(printf '%s' "$fqdn" | tr '[:upper:]' '[:lower:]')"
    set_lua="${set_lua}NAMES_${agent}:add(newDNSName(\"${lower}.\"))"$'\n'
    count=$(( count + 1 ))
  done <<< "$names"

  AGENT_NAMESETS="${AGENT_NAMESETS}-- ${agent}: ${count} exact name(s) from ${RESOLVED_POLICY}"$'\n'"${set_lua}"$'\n'

  if [ "$count" -eq 0 ]; then
    # Not an error: an agent with no allowlisted name resolves nothing, which is the
    # correct default-deny outcome. Said out loud because silent is how it would be
    # mistaken for a rendering bug.
    note "resolver: agent '$agent' has no allowlisted names -- every DNS query from ${network} will be REFUSED"
  fi

  rule="allow_${agent}"
  AGENT_ALLOW_RULES="${AGENT_ALLOW_RULES}${rule} = AndRule({NetmaskGroupRule(AGENT_NETS[\"${agent}\"]), QNameSetRule(NAMES_${agent}), ClassIN, AorAAAA})"$'\n'
  ALLOW_RULE_NAMES="${ALLOW_RULE_NAMES}${ALLOW_RULE_NAMES:+, }${rule}"
done

[ -n "$ACL_ENTRIES" ] || fail "MEDIATOR_AGENT_NETWORKS produced no agent networks"

# One audit call and one pool decision for the union of the per-agent rules, rather
# than a matching pair per agent: the verdict is the same on every allowed path, and
# duplicating it invites the two copies to drift.
AGENT_ALLOW_RULES="${AGENT_ALLOW_RULES}
anyAllow = OrRule({${ALLOW_RULE_NAMES}})
addAction(anyAllow, LuaAction(function(dq) return auditDNS(dq, \"allow\", nil) end))
addAction(anyAllow, PoolAction(\"reorigin\"))"

render() { # <template> <output>
  local tmpl="$1" out="$2"
  [ -f "$tmpl" ] || fail "template $tmpl not found in the image"
  AGENT_NETS="$AGENT_NETS" AGENT_NAMESETS="$AGENT_NAMESETS" \
  AGENT_ALLOW_RULES="$AGENT_ALLOW_RULES" ACL_ENTRIES="$ACL_ENTRIES" \
  LISTENERS="$LISTENERS" DNS_AUDIT_LOG="$DNS_AUDIT_LOG" \
  REORIGIN_PORT="$REORIGIN_PORT" FORWARD_ADDRS="$FORWARD_ADDRS" \
  awk '
    function emit(v) { printf "%s", ENVIRON[v]; if (ENVIRON[v] !~ /\n$/) printf "\n" }
    /^@ACL@$/                { next }
    $0 == "setACL({@ACL@})"  { printf "setACL({%s})\n", ENVIRON["ACL_ENTRIES"]; next }
    /^@LISTENERS@$/          { emit("LISTENERS");         next }
    /^@AGENT_NETS@$/         { emit("AGENT_NETS");        next }
    /^@AGENT_NAMESETS@$/     { emit("AGENT_NAMESETS");    next }
    /^@AGENT_ALLOW_RULES@$/  { emit("AGENT_ALLOW_RULES"); next }
    /^@FORWARD_ADDRS@$/      { emit("FORWARD_ADDRS");     next }
    {
      gsub(/@DNS_AUDIT_LOG@/, ENVIRON["DNS_AUDIT_LOG"])
      gsub(/@REORIGIN_PORT@/, ENVIRON["REORIGIN_PORT"])
      print
    }
  ' "$tmpl" > "$out"
  # A marker surviving the render means a placeholder was added to a template and
  # not to this function -- a silently half-configured enforcement point otherwise.
  if grep -qE '@[A-Z_]+@' "$out"; then
    grep -nE '@[A-Z_]+@' "$out" >&2
    fail "$out still contains unsubstituted markers (see above)"
  fi
}

FORWARD_ADDRS=""
for up in ${MEDIATOR_DNS_UPSTREAM//,/ }; do
  FORWARD_ADDRS="${FORWARD_ADDRS}    forward-addr: ${up}"$'\n'
done

render "$TMPL_DIR/resolver-policy.conf.tmpl"   "$POLICY_CONF"
render "$TMPL_DIR/resolver-reorigin.conf.tmpl" "$REORIGIN_CONF"

# ------------------------------------------------------------- holding configs
# Loopback only. Criterion 1's permitted listener set on each AGENT network is
# exactly {proxy, resolver}; a listener that binds no agent network at all is
# inside that bound, and SF-6 is what opens the three agent-facing proxy ports.
cat > "$SQUID_CONF" <<CONF
# HOLDING configuration -- 01.3 SF-4. Replaced by SF-6's render of
# mediator/config/proxy.conf.tmpl from the resolved policy. Not the shipped policy.
pid_filename none
cache deny all
# The ICMP pinger is a helper Squid starts to measure peer RTTs. It needs a raw
# socket, which \`cap_drop: ALL\` does not grant, and it FATALs on every start --
# noise in the log for a feature this mediator has no use for (it has no ICMP path
# out by construction, criterion 3). Off, rather than granting NET_RAW.
pinger_enable off
cache_log ${CACHE_LOG}
shutdown_lifetime 1 seconds

http_port 127.0.0.1:3128 name=holding

acl CONNECT method CONNECT
http_access deny all

logformat mediator %ts.%03tu agent=%note{agent} lport=%lp url=%ru status=%>Hs squid=%Ss bytes=%<st
access_log stdio:${AUDIT_LOG} mediator
error_directory ${ERROR_DIR}
CONF

# ------------------------------------------------------------------- pre-flight
# All three parsers fail hard on an unknown directive, which is how configuration
# correctness is established on an image that ships no reference config. A rendered
# file that does not parse is a start failure, never a daemon started against a
# configuration nobody checked.
squid -k parse -f "$SQUID_CONF" >/dev/null 2>&1 \
  || { squid -k parse -f "$SQUID_CONF" || true; fail "squid rejected $SQUID_CONF"; }
unbound-checkconf "$REORIGIN_CONF" >/dev/null 2>&1 \
  || { unbound-checkconf "$REORIGIN_CONF" || true; fail "unbound rejected $REORIGIN_CONF"; }
dnsdist --check-config -C "$POLICY_CONF" >/dev/null 2>&1 \
  || { dnsdist --check-config -C "$POLICY_CONF" || true; fail "dnsdist rejected $POLICY_CONF"; }

# ------------------------------------------------------------------------ start
# Squid cannot open /dev/stdout after dropping to the `proxy` user (the parent
# directory must be writable by it -- mediator-selection.md), so the logs are files
# on the audit volume and are relayed to the container's streams from here. That
# keeps D12's two sinks -- the volume and the container's stdout -- without giving a
# daemon a path it cannot open. The DNS audit sink is written by dnsdist's Lua and
# relayed the same way, so both trails reach both sinks.
CHILDREN=()

tail -n 0 -F "$AUDIT_LOG"     >&1 & CHILDREN+=($!); TAIL_AUDIT=$!
tail -n 0 -F "$CACHE_LOG"     >&2 & CHILDREN+=($!); TAIL_CACHE=$!
tail -n 0 -F "$DNS_AUDIT_LOG" >&1 & CHILDREN+=($!); TAIL_DNS=$!

unbound -d -c "$REORIGIN_CONF" & CHILDREN+=($!); UNBOUND_PID=$!
# The re-originating resolver must be answering before the policy engine starts, or
# dnsdist's first queries hit a backend that is not listening yet.
# Read from /proc rather than with `ss`, which is not installed. The UDP table
# lists the port in hex; 0100007F is 127.0.0.1 little-endian.
_reorigin_hex="$(printf '0100007F:%04X' "$REORIGIN_PORT")"
_reorigin_up=0
for _ in $(seq 1 100); do
  if grep -qi " ${_reorigin_hex} " /proc/net/udp 2>/dev/null; then _reorigin_up=1; break; fi
  kill -0 "$UNBOUND_PID" 2>/dev/null || fail "the re-originating resolver exited before it began listening -- see its output above"
  sleep 0.1
done
[ "$_reorigin_up" -eq 1 ] \
  || fail "the re-originating resolver did not bind 127.0.0.1:${REORIGIN_PORT} within 10s -- refusing to start the policy engine in front of a backend that is not answering"

dnsdist --supervised --disable-syslog -C "$POLICY_CONF" & CHILDREN+=($!); DNSDIST_PID=$!
squid -N -f "$SQUID_CONF" & CHILDREN+=($!); SQUID_PID=$!

# A half-dead mediator is worse than a dead one: a live proxy with a dead resolver is
# a pod whose DNS authority has silently gone, and a live resolver with a dead proxy
# is an enforcement point that is no longer enforcing. Either exit takes the
# container down so the restart policy and the operator both see it.
# Cleanup is bounded. TERM first, then KILL for anything still alive: a daemon that
# ignores TERM or wedges would otherwise leave PID 1 waiting forever and the
# container neither running nor gone. The relays are reaped here too rather than
# left to container teardown.
stop_children() {
  local pid alive
  for pid in "${CHILDREN[@]}"; do kill "$pid" 2>/dev/null || true; done
  for _ in $(seq 1 50); do
    alive=0
    for pid in "${CHILDREN[@]}"; do kill -0 "$pid" 2>/dev/null && alive=1; done
    [ "$alive" -eq 0 ] && break
    sleep 0.1
  done
  for pid in "${CHILDREN[@]}"; do
    kill -0 "$pid" 2>/dev/null && { note "child $pid ignored TERM -- sending KILL"; kill -9 "$pid" 2>/dev/null || true; }
  done
  wait "${CHILDREN[@]}" 2>/dev/null || true
}

# An asked-for stop (`docker stop`, `compose down`) is not an incident and exits 0.
# A child leaving on its own always is -- including when it leaves cleanly, which is
# the case that would otherwise be invisible: unbound exits 0 on SIGTERM, so a
# resolver killed inside the container would take the pod's DNS authority away and
# report success to anything reading the container's exit code.
on_signal() {
  trap - TERM INT
  note "stop requested -- shutting down"
  stop_children
  exit 0
}
trap on_signal TERM INT

note "up: squid $(squid -v 2>/dev/null | head -1 | sed 's/^Squid Cache: //') [HOLDING -- SF-6], dnsdist $(dnsdist --version 2>&1 | head -1), unbound $(unbound -V 2>/dev/null | head -1)"
note "resolver: profile '${MEDIATOR_PROFILE}', networks '${MEDIATOR_AGENT_NETWORKS}', upstream '${MEDIATOR_DNS_UPSTREAM}'"

# Six children, all watched. An unwatched relay is silent by construction: a daemon
# keeps writing to the volume, the mediator keeps enforcing, and the container's
# stdout -- one of D12's two sinks -- stops carrying audit lines with nothing to say
# so. R9.1 makes the audit trail a property of the enforcement point, not a
# convenience, so a lost sink fails closed like a lost daemon. SF-7 owns the audit
# writer and may soften this to a relay restart; it must not soften it to silence.
#
# `|| STATUS=$?` is load-bearing: under `set -e` a bare `wait -n` returning non-zero
# exits the shell AT THAT LINE, skipping the diagnostic, the cleanup and the
# controlled exit -- the whole reason this supervisor exists.
#
# `-p DIED` names the child whose status was returned. Identifying it by a `kill -0`
# probe afterwards instead would pair the wrong name with the status whenever a
# second child exits during the check, and "which one died" is the entire content of
# the message.
DIED=""
STATUS=0
wait -n -p DIED "${CHILDREN[@]}" || STATUS=$?

# Past this point a stop request must not overwrite a detected failure with exit 0.
trap - TERM INT

case "$DIED" in
  "$SQUID_PID")   note "squid exited (status $STATUS) -- taking the mediator down; the pod has no enforcement point" ;;
  "$DNSDIST_PID") note "dnsdist exited (status $STATUS) -- taking the mediator down; the pod has no DNS policy engine" ;;
  "$UNBOUND_PID") note "unbound exited (status $STATUS) -- taking the mediator down; the pod's resolver cannot re-originate" ;;
  "$TAIL_AUDIT"|"$TAIL_CACHE"|"$TAIL_DNS")
                  note "an audit relay exited (status $STATUS) -- taking the mediator down; stdout is no longer carrying the audit trail" ;;
  *)              note "a supervised child exited (pid ${DIED:-unknown}, status $STATUS) -- taking the mediator down" ;;
esac

stop_children
# Never 0 on this path. No child exiting is a normal outcome while the mediator is
# up, and reporting success would hide the incident from the restart policy and from
# anyone reading the exit code.
[ "$STATUS" -eq 0 ] && STATUS=1
exit "$STATUS"
