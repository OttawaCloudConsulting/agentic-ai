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

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
