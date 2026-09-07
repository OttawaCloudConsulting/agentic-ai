# Single multi-stage Dockerfile for the whole pod (see feature plan Deviation 1):
# one shared `agent-base` stage plus one final stage per agent, selected by
# compose's `target:`. This keeps `docker compose up` a working single entry
# point on a cold cache -- Compose does not resolve cross-service build order
# when one service's Dockerfile FROMs another service's image tag.

FROM node:22-slim AS agent-base

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl bubblewrap iproute2 \
    && rm -rf /var/lib/apt/lists/*

# node:22-slim ships a uid/gid-1000 `node` user. Rename it to `agent`
# (Interface Contract 2 requires the literal username `agent`) rather than
# creating a second uid-1000 identity. Do not carry over /home/node's default
# dotfiles into /home/agent: a state volume mounted there would mask them
# permanently after first run (see Approach, "Home seeding").
RUN usermod -l agent -d /home/agent node \
    && groupmod -n agent node \
    && rm -rf /home/node \
    && mkdir -p /home/agent \
    && chown agent:agent /home/agent \
    && chmod 700 /home/agent

ENV HOME=/home/agent

# Home skeleton: the image ships defaults here, never under /home/agent
# itself. The entrypoint seeds missing paths from here into the state volume
# on every start, idempotently.
RUN mkdir -p /opt/agent-home-skel && chown -R agent:agent /opt/agent-home-skel

# Test-only hook for the volume-upgrade smoke check (Edge Case 8): empty by
# default, so it changes nothing about a normal build. When set, adds one
# file to the skeleton so the test can rebuild with a "changed default" and
# assert it appears in an existing volume without disturbing agent-owned
# files already there.
ARG SKEL_MARKER=""
RUN if [ -n "$SKEL_MARKER" ]; then \
      echo "$SKEL_MARKER" > /opt/agent-home-skel/.upgrade-marker \
      && chown agent:agent /opt/agent-home-skel/.upgrade-marker; \
    fi

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# ---------------------------------------------------------------------------
FROM agent-base AS claude

ARG CLAUDE_VERSION
ARG CLAUDE_SOURCE
RUN test -n "$CLAUDE_VERSION" || (echo "CLAUDE_VERSION build arg is required (see compose/pins.env)" >&2 && exit 1)
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}"

ENV CLAUDE_CONFIG_DIR=/home/agent/.claude
ENV DISABLE_AUTOUPDATER=1
ENV CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# Skeleton entry only -- never write directly under /home/agent (the state
# volume mount point). The entrypoint seeds this into the volume on first run.
RUN mkdir -p /opt/agent-home-skel/.claude && chown -R agent:agent /opt/agent-home-skel

USER agent
CMD ["claude", "--version"]

# ---------------------------------------------------------------------------
FROM agent-base AS codex

ARG CODEX_VERSION
ARG CODEX_SOURCE
RUN test -n "$CODEX_VERSION" || (echo "CODEX_VERSION build arg is required (see compose/pins.env)" >&2 && exit 1)
RUN npm install -g "@openai/codex@${CODEX_VERSION}"

ENV CODEX_HOME=/home/agent/.codex

# R4.5, ALL modes -- not only oauth-mount. The `keyring` credential store
# hard-fails with no D-Bus, and there is no D-Bus in any of these containers
# under any mode, so the register's unconditional reading wins over the
# architecture component table's oauth-mount-only one (criterion 2).
#
# Seeded into the SKELETON, never directly under /home/agent: the state volume
# masks the image there. The entrypoint copies this in on first run and, on a
# pre-existing volume whose config.toml predates this setting, merges the key in
# without disturbing the operator's other keys.
RUN mkdir -p /opt/agent-home-skel/.codex \
    && printf '%s\n' \
         '# Seeded by the image (R4.5). Codex must not use the `keyring` credential' \
         '# store: it hard-fails without D-Bus, and no container here runs one.' \
         'cli_auth_credentials_store = "file"' \
         > /opt/agent-home-skel/.codex/config.toml \
    && chown -R agent:agent /opt/agent-home-skel

USER agent
CMD ["codex", "--version"]

# ---------------------------------------------------------------------------
FROM agent-base AS agy

ARG AGY_VERSION
ARG AGY_URL
ARG AGY_SHA512
RUN test -n "$AGY_VERSION" && test -n "$AGY_URL" && test -n "$AGY_SHA512" \
      || (echo "AGY_VERSION/AGY_URL/AGY_SHA512 build args are required (see compose/pins.env)" >&2 && exit 1)

# Direct, checksum-verified download -- no curl | bash (R7.7). See
# docs/records/agent-verification.md, "agy version pin -- resolved".
RUN curl -fsSL -o /tmp/agy.tar.gz "$AGY_URL" \
    && echo "${AGY_SHA512}  /tmp/agy.tar.gz" | sha512sum -c - \
    && mkdir -p /tmp/agy-extract \
    && tar -xzf /tmp/agy.tar.gz -C /tmp/agy-extract \
    && install -m 0755 -o root -g root /tmp/agy-extract/antigravity /usr/local/bin/agy \
    && rm -rf /tmp/agy.tar.gz /tmp/agy-extract

# agy has no HOME-override env var (confirmed: absent from `agy --help` and
# from `strings` on the binary) -- it resolves ~/.gemini from $HOME, already
# /home/agent per agent-base.
RUN mkdir -p /opt/agent-home-skel/.gemini && chown -R agent:agent /opt/agent-home-skel

# jq for agy-run.sh's JSON status-field gating (R3.6). Only agy needs it.
RUN apt-get update && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 agy/agy-run.sh /usr/local/bin/agy-run

USER agent
CMD ["agy", "--version"]
