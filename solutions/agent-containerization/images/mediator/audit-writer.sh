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
# The FIFO also makes this writer's death loud: Squid takes SIGPIPE and exits, and
# the entrypoint's supervisor takes the mediator down. R9.1 makes the audit trail a
# property of the enforcement point, so a mediator that has stopped recording stops.
#
# Field order is fixed by `logformat mediator_raw` in mediator/config/proxy.conf.tmpl.
# The two files are ONE contract, and a short line is reported rather than dropped.
#
#   1 ts (ISO 8601, UTC, ms)        8 squid status (%Ss)
#   2 agent note                    9 bytes_out (%>st, agent -> destination)
#   3 layer note (front|inner)     10 bytes_in  (%<st, destination -> agent)
#   4 control note                 11 SNI (%#ssl::>sni)
#   5 reason note                  12 method (%#>rm)
#   6 authority (%#ru)             13 resolved address (%<a)
#   7 HTTP status (%>Hs)
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

while IFS=' ' read -r ts agent layer control reason authority status squid bout bin sni method server extra; do
  [ -n "${ts:-}" ] || continue
  if [ -z "${server:-}" ]; then
    # Not silently dropped: a short line means `logformat mediator_raw` and this
    # writer have diverged, and a broken audit trail is an incident rather than a
    # nuisance.
    printf '{"event":"audit_writer_error","detail":"unparseable line from squid","line":%s}\n' "$(jstr "$ts $agent $layer")"
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
      printf '{"ts":%s,"event":"proxy_internal","detail":%s}\n' "$(jstr "$ts")" "$(jstr "$authority")"
      continue ;;
  esac

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
    printf '{"ts":%s,"agent":%s,"identity_source":"listener","dest_host":%s,"dest_port":%s,"resolved_ip":%s,"verdict":"deny","control":%s,"reason":%s,"policy":%s,"sni":%s,"method":%s,"http_status":%s}\n' \
      "$(jstr "$ts")" "$(jnull "$agent")" "$(jnull "$host")" "$port" "$(jnull "$server")" \
      "$(jnull "$control")" "$(jnull "$reason")" "$(jstr "$POLICY")" "$(jnull "$sni")" \
      "$(jnull "$method")" "$(jnum "$status")"
  else
    # `http_status` is on the allow line as well as the deny line. Not decoration: a
    # front whose peer was still cold answers 500, which is not a refusal by policy
    # and so is not a deny -- but a line saying only "allow" would report it as a
    # connection that worked.
    printf '{"ts":%s,"agent":%s,"identity_source":"listener","dest_host":%s,"dest_port":%s,"resolved_ip":%s,"verdict":"allow","control":null,"bytes_out":%s,"bytes_in":%s,"sni":%s,"method":%s,"http_status":%s}\n' \
      "$(jstr "$ts")" "$(jnull "$agent")" "$(jnull "$host")" "$port" "$(jnull "$server")" \
      "$(jnum "$bout")" "$(jnum "$bin")" "$(jnull "$sni")" "$(jnull "$method")" "$(jnum "$status")"
  fi
done
