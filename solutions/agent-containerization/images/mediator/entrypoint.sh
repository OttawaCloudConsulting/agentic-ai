#!/usr/bin/env bash
# Mediator entrypoint (01.3 SF-4).
#
# At this sub-feature the mediator's job is to come up hardened and hold: SF-4 owns
# the image, the Compose seam and the runtime, not the policy engine. So the two
# daemons start against HOLDING configurations rendered below --
#
#   * Squid on loopback only, `http_access deny all`. No agent network gets a
#     listener until SF-6 renders the real one from the resolved policy.
#   * unbound on :53 of every attached network, `local-zone "." refuse` with
#     query logging. Every query is refused and recorded. SF-5 replaces this with
#     the closed forwarder (exact-match allowlisted names re-originated upstream,
#     everything else REFUSED).
#
# -- and are replaced, not extended, when `mediator/config/*.tmpl` land. They exist
# so this sub-feature can VERIFY rather than assume the two runtime properties it is
# responsible for: that a privileged port binds under `cap_drop: ALL`, and that
# Compose `dns:` really does redirect Docker's embedded resolver to a container
# address on an `internal: true` bridge. Both are confirmed by capture on the
# mediator (docs/records/mediator-runtime-verification.md), because the second is
# the whole of D3's mechanism and reading the Compose documentation is not evidence.
set -euo pipefail

RUN_DIR=/run/mediator
AUDIT_DIR=/var/log/mediator
AUDIT_LOG="$AUDIT_DIR/egress-audit.log"
CACHE_LOG="$AUDIT_DIR/squid-cache.log"
SQUID_CONF="$RUN_DIR/squid.conf"
RESOLVER_CONF="$RUN_DIR/unbound.conf"
ERROR_DIR="$RUN_DIR/errors"

fail() { echo "mediator: FATAL: $*" >&2; exit 1; }
note() { echo "mediator: $*" >&2; }

# --------------------------------------------------------------- writable paths
# The rootfs is read-only (D15) and /run arrives as an empty tmpfs, so every
# writable path is created here. A missing one is a start failure, which is the
# intended failure mode: a mediator that silently could not open its audit log
# would be an enforcement point running without R9.1.
mkdir -p "$RUN_DIR" "$ERROR_DIR" /run/squid

[ -d "$AUDIT_DIR" ] || fail "$AUDIT_DIR is absent -- the audit volume is not mounted"
touch "$AUDIT_LOG" "$CACHE_LOG" 2>/dev/null \
  || fail "cannot write the audit sink at $AUDIT_DIR (uid $(id -u)). The named volume must be owned by the runtime uid; it inherits that from the image."

# ------------------------------------------------------------- error_directory
# `error_directory` REPLACES the packaged error set rather than overlaying it
# (docs/records/mediator-selection.md, operational findings), so the directory has
# to be composed: the packaged English pages first, then the mediator's own pages
# on top. SF-7 adds ERR_MEDIATOR_DENIED here; at SF-4 the composition itself is
# what is being established.
if [ -d /usr/share/squid/errors/English ]; then
  cp -R /usr/share/squid/errors/English/. "$ERROR_DIR/"
else
  fail "packaged Squid error pages not found -- error_directory cannot be composed"
fi

# ------------------------------------------------------------- holding configs
# Loopback only. Criterion 1's permitted listener set on each AGENT network is
# exactly {proxy, resolver}; a listener that binds no agent network at all is
# inside that bound, and SF-6 is what opens the three agent-facing ports.
cat > "$SQUID_CONF" <<CONF
# HOLDING configuration -- 01.3 SF-4. Replaced by SF-6's render of
# mediator/config/proxy.conf.tmpl from the resolved policy. Not the shipped policy.
pid_filename none
cache deny all
# The ICMP pinger is a helper Squid starts to measure peer RTTs. It needs a raw
# socket, which `cap_drop: ALL` does not grant, and it FATALs on every start --
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

# unbound runs as the container's uid, so it must not try to setuid or chroot:
# `cap_drop: ALL` leaves it no way to do either, and the failure would be at start
# rather than something to discover later. Binding :53 is the privileged-port case
# this sub-feature verifies -- see compose.yaml's `sysctls` and the record.
cat > "$RESOLVER_CONF" <<CONF
# HOLDING configuration -- 01.3 SF-4. Replaced by SF-5's render of
# mediator/config/resolver.conf.tmpl. Refuses everything and logs every query;
# it is the capture instrument for the \`dns:\` redirect, not the pod resolver.
server:
    verbosity: 1
    username: ""
    chroot: ""
    pidfile: ""
    directory: "${RUN_DIR}"
    logfile: ""
    use-syslog: no
    log-queries: yes
    do-daemonize: no
    interface: 0.0.0.0
    port: 53
    access-control: 0.0.0.0/0 allow
    local-zone: "." refuse
CONF

# ------------------------------------------------------------------- pre-flight
# Both parsers fail hard on an unknown directive, which is how configuration
# correctness is established on an image that ships no squid.conf.documented.
squid -k parse -f "$SQUID_CONF" >/dev/null 2>&1 \
  || { squid -k parse -f "$SQUID_CONF" || true; fail "squid rejected $SQUID_CONF"; }
unbound-checkconf "$RESOLVER_CONF" >/dev/null 2>&1 \
  || { unbound-checkconf "$RESOLVER_CONF" || true; fail "unbound rejected $RESOLVER_CONF"; }

# ------------------------------------------------------------------------ start
# Squid cannot open /dev/stdout after dropping to the `proxy` user (the parent
# directory must be writable by it -- mediator-selection.md), so both logs are
# files on the audit volume and are relayed to the container's streams from here.
# That keeps D12's two sinks -- the volume and the container's stdout -- without
# giving Squid a path it cannot open.
tail -n 0 -F "$AUDIT_LOG" >&1 &
TAIL_AUDIT=$!
tail -n 0 -F "$CACHE_LOG" >&2 &
TAIL_CACHE=$!

unbound -d -c "$RESOLVER_CONF" &
UNBOUND_PID=$!
squid -N -f "$SQUID_CONF" &
SQUID_PID=$!

# A half-dead mediator is worse than a dead one: a live proxy with a dead resolver
# is a pod whose DNS authority has silently gone, and a live resolver with a dead
# proxy is an enforcement point that is no longer enforcing. Either exit takes the
# container down so the restart policy and the operator both see it.
# Cleanup is bounded. TERM first, then KILL for anything still alive: a daemon that
# ignores TERM or wedges would otherwise leave PID 1 waiting forever and the
# container neither running nor gone. The relays are reaped here too rather than
# left to container teardown.
stop_children() {
  local pid
  for pid in "$SQUID_PID" "$UNBOUND_PID" "$TAIL_AUDIT" "$TAIL_CACHE"; do
    kill "$pid" 2>/dev/null || true
  done
  local alive
  for _ in $(seq 1 50); do
    alive=0
    for pid in "$SQUID_PID" "$UNBOUND_PID" "$TAIL_AUDIT" "$TAIL_CACHE"; do
      kill -0 "$pid" 2>/dev/null && alive=1
    done
    [ "$alive" -eq 0 ] && break
    sleep 0.1
  done
  for pid in "$SQUID_PID" "$UNBOUND_PID" "$TAIL_AUDIT" "$TAIL_CACHE"; do
    kill -0 "$pid" 2>/dev/null && { note "child $pid ignored TERM -- sending KILL"; kill -9 "$pid" 2>/dev/null || true; }
  done
  wait "$SQUID_PID" "$UNBOUND_PID" "$TAIL_AUDIT" "$TAIL_CACHE" 2>/dev/null || true
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

note "up: squid $(squid -v 2>/dev/null | head -1 | sed 's/^Squid Cache: //'), unbound $(unbound -V 2>/dev/null | head -1) -- HOLDING configuration (SF-4)"

# Four children, all watched. An unwatched relay is silent by construction: squid
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
wait -n -p DIED "$SQUID_PID" "$UNBOUND_PID" "$TAIL_AUDIT" "$TAIL_CACHE" || STATUS=$?

# Past this point a stop request must not overwrite a detected failure with exit 0.
trap - TERM INT

case "$DIED" in
  "$SQUID_PID")   note "squid exited (status $STATUS) -- taking the mediator down; the pod has no enforcement point" ;;
  "$UNBOUND_PID") note "unbound exited (status $STATUS) -- taking the mediator down; the pod has no resolver" ;;
  "$TAIL_AUDIT"|"$TAIL_CACHE")
                  note "an audit relay exited (status $STATUS) -- taking the mediator down; stdout is no longer carrying the audit trail" ;;
  *)              note "a supervised child exited (pid ${DIED:-unknown}, status $STATUS) -- taking the mediator down" ;;
esac

stop_children
# Never 0 on this path. No child exiting is a normal outcome while the mediator is
# up, and reporting success would hide the incident from the restart policy and from
# anyone reading the exit code.
[ "$STATUS" -eq 0 ] && STATUS=1
exit "$STATUS"
