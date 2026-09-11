#!/usr/bin/env bash
# Starts the capture first, then the resolver: a query that arrives before tcpdump
# is listening is a query the T4 assertion cannot see, and an unseen query reads as
# a pass.
set -euo pipefail
CAP_DIR=${CAP_DIR:-/cap}
mkdir -p "$CAP_DIR"
tcpdump -n -i any -s 0 -U -w "$CAP_DIR/queries.pcap" 'udp port 53 or tcp port 53' >/dev/null 2>&1 &
# -U is packet-buffered: without it the harness can read an empty file while queries
# sit in tcpdump's buffer, which would make every T4 assertion pass for free.
sleep 0.5
exec unbound -d -c /etc/authoritative.conf
