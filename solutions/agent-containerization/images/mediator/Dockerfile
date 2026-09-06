# The egress mediator (01.3). One multi-homed container that is the pod's only
# route out: the L7 CONNECT/SNI policy engine (SF-6), the pod's authoritative
# resolver (SF-5) and the audit writer (SF-7).
#
# Build context is the SOLUTION ROOT, not `images/` -- the image must carry the
# resolved policy artifact (`policy/resolved/`) and, from SF-5/SF-6, the
# configuration templates under `mediator/config/`. See `.dockerignore` at the
# context root: it is deny-all plus an allowlist, so `references/.env_keys` and
# `mediator/identity/` (the CA private key) cannot reach the daemon.
#
#   docker build -f images/mediator/Dockerfile .
#
# Nothing secret is baked in (R8.1, criterion 9). The CA certificate and the two
# listener key pairs arrive at runtime as Compose secrets under /run/secrets.

# Both the package version AND the base image digest are pinned, because
# docs/records/mediator-selection.md verified P1-P8 against exactly this build and
# the Squid directives those properties rest on are version-scoped. Debian point
# releases supersede in place, so an unpinned `apt-get install squid-openssl` moves
# silently off the verified build. Pins are supplied from compose/pins.env; the
# defaults here keep a bare `docker build` reproducible.
ARG MEDIATOR_BASE_DIGEST=sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
FROM debian:trixie-slim@${MEDIATOR_BASE_DIGEST}

ARG SQUID_VERSION=6.13-2+deb13u2
ARG UNBOUND_VERSION=1.22.0-2+deb13u3

# `squid-openssl`, not `squid`: the OpenSSL-linked build is what supplies
# `ssl_bump peek`/`splice` and `https_port`, and it is the package SF-1 verified.
#
# `unbound` is the resolver binary the pod's DNS authority (SF-5) is expected to be
# built from -- installed here because SF-4 owns the image and because a real
# port-53 binder is what makes this sub-feature's `dns:`-redirect and privileged-bind
# verification a capture rather than a reading of the Compose documentation. The
# CHOICE is SF-5's to confirm: `local-zone "." refuse` matches the closed forwarder
# exactly, but the QTYPE restriction to A/AAAA and the EDNS-option stripping that
# criterion 4 requires are unverified in unbound and are SF-5's to establish. If SF-5
# finds it cannot express them, the package changes here and nothing else does.
RUN apt-get update && apt-get install -y --no-install-recommends \
      "squid-openssl=${SQUID_VERSION}" \
      "unbound=${UNBOUND_VERSION}" \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Runtime uid/gid. The `proxy` user (13:13) ships with the Squid package and owns
# its packaged directories, so using it avoids a second identity owning the same
# paths. Both daemons run as this uid -- unbound's own `unbound` user (100:101) is
# not used, because a single container process tree with `cap_drop: ALL` cannot
# setuid to it anyway (see the entrypoint's `username: ""`).
ARG MEDIATOR_UID=13
ARG MEDIATOR_GID=13

# The audit sink (D12, R9.2). A named volume mounts here and inherits this
# ownership on first creation, which is what lets the container write to it as
# uid 13 without a chown at start under `read_only: true`. No agent mounts it.
RUN mkdir -p /var/log/mediator \
    && chown "${MEDIATOR_UID}:${MEDIATOR_GID}" /var/log/mediator \
    && chmod 750 /var/log/mediator

# Configuration the mediator reads from its OWN image layer, never from a path any
# agent can write (see the feature plan's Edge Cases, "The control plane must not be
# inside the project mount"). A live agent compromise cannot reach the running
# enforcement point; the exposure was always the next build, which is why
# compose/overrides/default.yaml no longer binds this checkout into /workspace.
#
# SF-5 and SF-6 add `mediator/config/*.tmpl` here and render them at start.
COPY policy/resolved/ /etc/mediator/policy/

COPY --chmod=0755 images/mediator/entrypoint.sh /usr/local/bin/mediator-entrypoint

# Rootfs is read-only at runtime (D15). Everything written at start lands under the
# /run tmpfs or the audit volume; the entrypoint enumerates those paths and creates
# them, because a `tmpfs:` mount arrives empty.
USER ${MEDIATOR_UID}:${MEDIATOR_GID}
ENTRYPOINT ["/usr/local/bin/mediator-entrypoint"]
