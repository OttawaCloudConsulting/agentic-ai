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
ARG DNSDIST_VERSION=1.9.16-0+deb13u1
ARG YQ_VERSION=v4.47.2
ARG YQ_SHA256_ARM64=05df1f6aed334f223bb3e6a967db259f7185e33650c3b6447625e16fea0ed31f
ARG YQ_SHA256_AMD64=1bb99e1019e23de33c7e6afc23e93dad72aad6cf2cb03c797f068ea79814ddb0

# `squid-openssl`, not `squid`: the OpenSSL-linked build is what supplies
# `ssl_bump peek`/`splice` and `https_port`, and it is the package SF-1 verified.
#
# The pod resolver is TWO daemons, and SF-4's expectation that it would be one was
# tested rather than carried forward. SF-4 installed `unbound` and said the QTYPE
# restriction and EDNS-option stripping criterion 4 requires were unverified in it,
# adding: "If SF-5 finds it cannot express them, the package changes here and
# nothing else does." SF-5 found worse than that
# (docs/records/resolver-verification.md): unbound alone fails THREE of criterion
# 4's six properties -- it forwards subdomains of an allowlisted name (its
# `local-zone` is subtree-scoped, so "this exact name and nothing below it" has no
# expression), it has no QTYPE-based policy at all, and it forwards a mixed-case
# QNAME with the client's case intact.
#
#   * `dnsdist` is the POLICY half, on the three agent addresses. Exact names,
#     A/AAAA only, per-agent by arriving subnet, REFUSED default, audited.
#   * `unbound` stays as the RE-ORIGINATING half, on loopback. Tested and kept:
#     dnsdist proxies the client's packet, so with no resolver behind it the
#     client's EDNS client-subnet and cookie reach the upstream verbatim.
#
# Neither is redundant -- each closes exactly what the other cannot.
RUN apt-get update && apt-get install -y --no-install-recommends \
      "squid-openssl=${SQUID_VERSION}" \
      "unbound=${UNBOUND_VERSION}" \
      "dnsdist=${DNSDIST_VERSION}" \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# yq, so the mediator's configuration is GENERATED from the resolved policy
# artifact rather than hand-written (SC-6). The image carried no YAML parser before
# this sub-feature; SF-6's proxy render and SF-7's stage-1 schema check inherit it.
#
# Downloaded and checksum-verified rather than installed from apt, for the reason
# AGY_SHA512 exists: Debian's `yq` is a Python wrapper, and this is one static
# binary against an interpreter inside the enforcement point. TARGETARCH is supplied
# by BuildKit; both architectures are pinned so the image is not silently
# host-specific. An unknown architecture is a build failure, never an unverified
# download.
ARG TARGETARCH
ADD --chmod=0755 https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH} /usr/local/bin/yq
RUN set -eu; \
    case "${TARGETARCH}" in \
      arm64) want="${YQ_SHA256_ARM64}" ;; \
      amd64) want="${YQ_SHA256_AMD64}" ;; \
      *) echo "no pinned yq checksum for TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    echo "${want}  /usr/local/bin/yq" | sha256sum -c -; \
    yq --version

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
# SF-6 adds its proxy template alongside the two resolver templates SF-5 lands
# here; both are rendered at start from the policy artifact below.
# `--chmod` is load-bearing, not tidiness. COPY preserves the source mode, and
# scripts/compile-policy.sh writes the artifact through mktemp -- which creates
# 0600. The mediator runs as uid 13, so an image built from a tree where the
# compiler had just run could not read its own policy, while one built from a fresh
# clone could (git records only the executable bit, so a checkout is 0644). That is
# a build that succeeds or fails depending on whose machine it ran on. Fixed at both
# ends: the compiler now emits 0644, and the mode is pinned here regardless.
#
# Read-only for everyone: nothing in the running mediator ever writes these, and the
# rootfs is read-only anyway (D15).
COPY policy/resolved/ /etc/mediator/policy/
COPY mediator/config/ /etc/mediator/config/

# `a=rX` and not `--chmod` on the COPY above: a single `--chmod` mode applies to the
# copied DIRECTORIES as well, and a directory without the execute bit cannot be
# traversed -- 0444 makes the policy unreadable in a second, more confusing way than
# the one being fixed. The capital `X` is the whole point: read for everyone,
# execute only where it is a directory.
RUN chmod -R a=rX /etc/mediator

COPY --chmod=0755 images/mediator/entrypoint.sh /usr/local/bin/mediator-entrypoint

# Rootfs is read-only at runtime (D15). Everything written at start lands under the
# /run tmpfs or the audit volume; the entrypoint enumerates those paths and creates
# them, because a `tmpfs:` mount arrives empty.
USER ${MEDIATOR_UID}:${MEDIATOR_GID}
ENTRYPOINT ["/usr/local/bin/mediator-entrypoint"]
