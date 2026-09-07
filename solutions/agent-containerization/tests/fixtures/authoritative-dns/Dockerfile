# The T4 fixture (01.3 SF-5): a CONTROLLED authoritative DNS server.
#
# T4's assertion is an ABSENCE -- "a query encoding data in its labels, aimed at a
# controlled authoritative server, produces no query at that server". An absence can
# only be asserted against a server the harness owns and can read, which is the whole
# reason this exists rather than pointing the test at a public resolver.
#
# Two things run here, and both are needed:
#
#   * unbound, answering authoritatively for the fixture names and forwarding
#     NOWHERE, so anything that arrives is visibly something the mediator sent.
#   * tcpdump, capturing every query packet. The resolver's own log records what it
#     DECIDED; only the capture records what actually ARRIVED -- and criterion 4's
#     re-origination terms (QNAME case, EDNS options) are invisible in a log and
#     plain in a packet. SF-5's verification turned on exactly that distinction.
#
# Test-only. Never part of a shipped profile.
FROM debian:trixie-slim
ARG UNBOUND_VERSION=1.22.0-2+deb13u3
RUN apt-get update && apt-get install -y --no-install-recommends \
      "unbound=${UNBOUND_VERSION}" tcpdump \
    && rm -rf /var/lib/apt/lists/*
COPY unbound.conf /etc/authoritative.conf
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["bash", "/entrypoint.sh"]
