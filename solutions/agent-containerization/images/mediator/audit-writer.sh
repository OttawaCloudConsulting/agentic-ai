#!/usr/bin/env bash
# The mediator's audit writer (01.3 SF-7). Interface Contract 4: one JSON object per
# line, per connection attempt, allow and deny alike (R9.1).
#
# Reads Squid's intermediate line from a FIFO on stdin and writes the audit trail to
# stdout, which the entrypoint appends to the audit volume and relays to the
# container's stdout (D12's two sinks).
#
# WHY A SEPARATE WRITER AT ALL. Squid's `logformat` is a byte template with no
# structure, so a hostile SNI or CONNECT authority carrying a quote would corrupt a
# machine-parsed trail at exactly the moment it matters most. The shape that closes
# that: Squid URL-escapes every attacker-controlled field with its `%#` modifier and
# this writer assembles JSON from fields that can no longer contain a quote, a space
# or a newline. A valid hostname escapes to itself, so an operator still reads
# `api.anthropic.com`; a hostile one arrives as `ev%22il` and stays inside its string.
#
# WHY BASH AND NOT AWK. It was awk first. `mawk` -- Debian's default, and the only
# awk in this image -- reads a FIFO whose writer is still open and emits NOTHING:
# measured at the SF-7 build at 130 KB of input with zero bytes out, with `fflush()`
# in the script and with `stdbuf -oL` around it. It only produces output when the
# writer closes, which for a live proxy means "when the mediator is going down".
# An audit trail that appears only at shutdown is not an audit trail. `read` in bash
# is unbuffered and correct here; the volume is one line per connection attempt.
#
# WHY A FIFO AND NOT A FILE. An intermediate log on the /run tmpfs would grow without
# bound inside the enforcement point, and rotating it would be a second failure mode.
#
# This writer's death is fail-closed, and the mechanism is the entrypoint's supervisor
# rather than anything about the FIFO. Measured at the SF-7 build by killing this
# process on the running pod: `wait -n` returned it, the supervisor reported "the
# audit writer exited -- taking the mediator down; verdicts are no longer being
# recorded", and the container left with 143. Squid was still running and was reaped
# with the rest; it never reached a write. R9.1 makes the audit trail a property of
# the enforcement point, so a mediator that has stopped recording stops.
#
# Field order is fixed by `logformat mediator_raw` in mediator/config/proxy.conf.tmpl.
# The two files are ONE contract, and a short line is reported rather than dropped.
#
#   1 ts (ISO 8601, UTC, ms)        8 HTTP status (%>Hs)
#   2 idsrc note                    9 squid status (%Ss)
#   3 agent note                   10 bytes_out (%>st, agent -> destination)
#   4 layer note (front|inner)     11 bytes_in  (%<st, destination -> agent)
#   5 control note                 12 SNI (%#ssl::>sni)
#   6 reason note                  13 method (%#>rm)
#   7 authority (%#ru)             14 resolved address (%<a)
#
# `idsrc` (01.6 SF-2) is field 2 -- INSERTED, not appended. Appending it would land its value
# in the trailing `extra` variable of the `read` below and be discarded in silence: the
# short-line guard tests an empty `$server`, which an appended field leaves populated. It
# states the STRENGTH of the attribution `agent` carries, and it is rendered from the same
# policy field, in the same renderer pass, that renders the enforcement -- so the line cannot
# claim a listener authenticated when it did not.
#
#   listener            network-derived: the arriving `internal: true` network named the agent
#   listener+mtls       ... and a client certificate whose subject equals this listener's agent
#                       was verified against the mediator CA
#   listener+proxy_auth ... and a proxy credential bound to this agent was accepted
#
# Argument 1 is the policy source the denial record names (Contract 6).
set -uo pipefail

POLICY="${1:?the audit writer needs the policy source path as its first argument}"

# Every field arrived URL-escaped or is a Squid-generated token, so no quote,
# backslash or control byte can be present. Escaped anyway: this is the boundary
# where a log line becomes a JSON document, and the cost of being wrong about the
# upstream escaping is a corrupted trail rather than a cosmetic defect.
jstr() { local v="$1"; v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; printf '"%s"' "$v"; }
# `-` is Squid's "no value". It is not data, and emitting it as the string "-" would
# be indistinguishable from a destination literally named "-".
jnull() { case "$1" in ''|'-') printf 'null' ;; *) jstr "$1" ;; esac; }
jnum() { case "$1" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$1" ;; esac; }

while IFS=' ' read -r ts agent idsrc layer control reason authority status squid bout bin sni method server extra; do
  [ -n "${ts:-}" ] || continue
  if [ -z "${server:-}" ]; then
    # Not silently dropped: a short line means `logformat mediator_raw` and this
    # writer have diverged, and a broken audit trail is an incident rather than a
    # nuisance.
    printf '{"event":"audit_writer_error","detail":"unparseable line from squid","line":%s}\n' "$(jstr "$ts $agent $idsrc $layer")"
    continue
  fi

  # Squid logs its own internal transactions too -- the `cache_peer` probes at start
  # are three of them -- with no method, no client and `error:transaction-end-before-
  # headers` where the authority goes. They are not egress attempts and must not read
  # as three allow verdicts with a null agent at the head of every pod's trail. They
  # are not dropped either: an audit trail that quietly discards lines is one nobody
  # can reason about. They are emitted as events, which carry no `verdict` key.
  case "$authority" in
    error:*)
      # No `identity_source`: these are Squid's own internal transactions, with no client
      # connection behind them at all. A field naming the strength of an attribution that was
      # never made would be worse than its absence.
      printf '{"ts":%s,"event":"proxy_internal","detail":%s}\n' "$(jstr "$ts")" "$(jstr "$authority")"
      continue ;;
  esac

  # A bumping listener logs TWICE per attempt, and the first entry is not an outcome.
  # Squid records the client-side CONNECT as soon as it answers it -- `NONE_NONE`,
  # status 200, `bytes_out` the size of the CONNECT line itself and `bytes_in` zero --
  # because on a peeking port the CONNECT must be accepted before the ClientHello that
  # decides the verdict can arrive. The real outcome follows as `TCP_TUNNEL` or
  # `TCP_DENIED`. Measured at the SF-7 build: an SNI-mismatch refusal produced
  # `NONE_NONE/200` and then `TCP_DENIED/403` at the same millisecond.
  #
  # Emitted as an EVENT, not dropped and not recorded as a verdict. Recording it as
  # `verdict: allow` would say a refused attempt succeeded -- Deviation 1's failure
  # mode, one layer further in. Dropping it would lose the only trace of an agent that
  # opens CONNECTs and never sends a ClientHello, which is exactly the destination
  # probing R9.1 wants visible. It carries no `verdict` key, so nothing can misparse it.
  if [ "$squid" = "NONE_NONE" ] && [ "$status" = "200" ]; then
    printf '{"ts":%s,"event":"connect_accepted","agent":%s,"identity_source":%s,"layer":%s,"dest_host":%s,"dest_port":%s,"sni":%s}\n' \
      "$(jstr "$ts")" "$(jnull "$agent")" "$(jnull "$idsrc")" "$(jnull "$layer")" "$(jnull "${authority%:*}")" \
      "$(jnum "${authority##*:}")" "$(jnull "$sni")"
    continue
  fi

  # The verdict. A refusing rule always annotates its control (proxy.conf.tmpl), so
  # the note is the primary signal; the 403 and Squid's own DENIED result are kept as
  # corroboration, so a deny reached by a path that forgot to annotate still reads as
  # a deny rather than as an allow with a missing field.
  verdict=allow
  case "$control:$status:$squid" in
    -:200:*)      verdict=allow ;;
    -:*:*DENIED*) verdict=deny ;;
    -:403:*)      verdict=deny ;;
    -:*)          verdict=allow ;;
    *)            verdict=deny ;;
  esac

  # A fronted agent produces TWO lines for one attempt: the front reports the tunnel
  # to its own peer (200, TCP_TUNNEL) while the INNER listener reports the real
  # verdict. A front line read alone therefore says a denied connection succeeded, so
  # the front's SUCCESSFUL tunnel line is dropped -- the inner line covers the same
  # attempt with the verdict and the byte counts.
  #
  # Front lines carrying anything else are kept. Control 3's concurrency ceiling is
  # enforced on the front layer and exists nowhere else, and a front that answered
  # 500 because its peer was still being probed tunnelled nothing and has no inner
  # line behind it.
  if [ "$layer" = "front" ] && [ "$verdict" = "allow" ] && [ "$status" = "200" ]; then
    continue
  fi

  # host:port, split at the LAST colon so an IPv6 literal keeps its own.
  host="$authority"; port=null
  if [ "${authority##*:}" != "$authority" ]; then
    _p="${authority##*:}"
    case "$_p" in
      ''|*[!0-9]*) : ;;
      *) host="${authority%:*}"; port="$_p" ;;
    esac
  fi

  if [ "$verdict" = "deny" ]; then
    # Contract 6: the record names the refusing control, the reason and the policy
    # source. `bytes_*` are omitted -- nothing was carried.
    printf '{"ts":%s,"agent":%s,"identity_source":%s,"layer":%s,"dest_host":%s,"dest_port":%s,"resolved_ip":%s,"verdict":"deny","control":%s,"reason":%s,"policy":%s,"sni":%s,"method":%s,"http_status":%s,"squid":%s}\n' \
      "$(jstr "$ts")" "$(jnull "$agent")" "$(jnull "$idsrc")" "$(jnull "$layer")" "$(jnull "$host")" "$port" "$(jnull "$server")" \
      "$(jnull "$control")" "$(jnull "$reason")" "$(jstr "$POLICY")" "$(jnull "$sni")" \
      "$(jnull "$method")" "$(jnum "$status")" "$(jnull "$squid")"
  else
    # `http_status` is on the allow line as well as the deny line. Not decoration: a
    # front whose peer was still cold answers 500, which is not a refusal by policy
    # and so is not a deny -- but a line saying only "allow" would report it as a
    # connection that worked.
    printf '{"ts":%s,"agent":%s,"identity_source":%s,"layer":%s,"dest_host":%s,"dest_port":%s,"resolved_ip":%s,"verdict":"allow","control":null,"bytes_out":%s,"bytes_in":%s,"sni":%s,"method":%s,"http_status":%s,"squid":%s}\n' \
      "$(jstr "$ts")" "$(jnull "$agent")" "$(jnull "$idsrc")" "$(jnull "$layer")" "$(jnull "$host")" "$port" "$(jnull "$server")" \
      "$(jnum "$bout")" "$(jnum "$bin")" "$(jnull "$sni")" "$(jnull "$method")" "$(jnum "$status")" "$(jnull "$squid")"
  fi
done
