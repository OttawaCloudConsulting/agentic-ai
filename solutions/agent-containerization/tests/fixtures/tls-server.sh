#!/usr/bin/env bash
# TLS fixture server (01.3 SF-8). Runs in the mediator image -- it already carries a pinned
# OpenSSL, so the harness adds no image and no pin of its own.
#
# It must terminate TLS, not merely accept TCP. Every allowed-path assertion in the harness
# drives a real ClientHello through the mediator (control 1b pairs the SNI with the CONNECT
# host, so a probe without one proves nothing), peek+splice hands that handshake straight to
# this process, and a plain-HTTP listener on 443 would fail it. Phase F depends on the same
# property: the startup self-check's allowed target is this fixture.
#
# `-naccept 1` and the loop: s_server serves one connection and exits, so the loop is what
# makes it a server. One connection at a time is enough for the harness and keeps the failure
# mode obvious.
set -uo pipefail

MODE="${1:-www}"
CERT="${FIXTURE_CERT:-/fixture/tls/fixture.crt}"
KEY="${FIXTURE_KEY:-/fixture/tls/fixture.key}"

[ -r "$CERT" ] && [ -r "$KEY" ] || {
  echo "tls-server: $CERT / $KEY not readable -- the harness generates these before bring-up" >&2
  exit 1
}

echo "tls-server: mode=$MODE listening on :443" >&2
while :; do
  case "$MODE" in
    upgrade)
      # criterion 3's WebSocket path. Under splice the mediator sees an opaque tunnel, so the
      # only way to assert the transport works is to complete one: this answers the client's
      # request with a 101 inside the TLS session.
      printf 'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n' \
        | openssl s_server -quiet -naccept 1 -accept 443 -cert "$CERT" -key "$KEY" 2>/dev/null
      ;;
    *)
      openssl s_server -www -naccept 1 -accept 443 -cert "$CERT" -key "$KEY" >/dev/null 2>&1
      ;;
  esac
  # A tight spin would burn a core if the certificate is unreadable or the port is taken.
  sleep 0.2
done
