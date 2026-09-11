# The agent action recorder (02.1 SF-2, D20, Decision 1). One per agent. Reads that
# agent's own state volume read-only, ships completed transcript lines to its own
# sink volume, and has no network route anywhere -- it can read its agent's
# credential but has nowhere to send it.
#
# Built on the SAME pinned base digest as the mediator (MEDIATOR_BASE_DIGEST,
# compose/pins.env), so the recorder's provenance is asserted against the same
# record (docs/records/mediator-selection.md) without adding a second base to pin
# and verify. This is a single-stage build: there is no compile step and nothing
# here reads the resolved policy artifact at build time.
ARG MEDIATOR_BASE_DIGEST=sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
FROM debian:trixie-slim@${MEDIATOR_BASE_DIGEST}

# jq: parses each agent's native transcript line and assembles the action-log JSON
# (Interface Contract 1). Pinned exactly like the mediator's package installs --
# measured against this base with `apt-cache policy jq` rather than guessed, because
# an unpinned install moves silently off whatever was verified.
ARG JQ_VERSION=1.7.1-6+deb13u3
RUN apt-get update && apt-get install -y --no-install-recommends \
      "jq=${JQ_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

# yq: reads the ONE scalar Interface Contract 2 requires --
# `.agents.$RECORDER_AGENT.identity` -- from the resolved-policy `configs:` mount.
# NOT in the feature plan's "adding only pinned jq" -- recorded as an Architectural
# Deviation (this feature plan's Architectural Deviations section) rather than done
# silently. Same pinned build the mediator's compile stage uses (compose/pins.env
# YQ_VERSION / YQ_SHA256_*), so there is still exactly one pinned yq binary in this
# solution, not a second one to track.
ARG YQ_VERSION=v4.47.2
ARG YQ_SHA256_ARM64=05df1f6aed334f223bb3e6a967db259f7185e33650c3b6447625e16fea0ed31f
ARG YQ_SHA256_AMD64=1bb99e1019e23de33c7e6afc23e93dad72aad6cf2cb03c797f068ea79814ddb0
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

# Runtime uid/gid. 1000, the same numeric uid every agent home directory is owned
# by (images/Dockerfile) -- not because this container shares that identity (it is
# a distinct image with no agent user entry of its own), but because the recorder's
# read-only mount of an agent's mode-0700 home resolves on uid alone, exactly as
# docs/records/agent-action-log.md measured.
ARG RECORDER_UID=1000
ARG RECORDER_GID=1000

# The recorder's own sink volume. Mirrors the mediator Dockerfile's /var/log/mediator
# ownership fix: a fresh named volume is root-owned on first creation, and a
# read_only, uid-1000 container cannot chown it at start.
RUN mkdir -p /var/log/actions \
    && chown "${RECORDER_UID}:${RECORDER_GID}" /var/log/actions \
    && chmod 750 /var/log/actions

COPY --chmod=0755 images/recorder/recorder.sh /usr/local/bin/recorder-entrypoint

USER ${RECORDER_UID}:${RECORDER_GID}
ENTRYPOINT ["/usr/local/bin/recorder-entrypoint"]
