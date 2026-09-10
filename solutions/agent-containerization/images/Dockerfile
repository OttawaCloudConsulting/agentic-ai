# Single multi-stage Dockerfile for the whole pod (see feature plan Deviation 1):
# one shared `agent-base` stage plus one final stage per agent, selected by
# compose's `target:`. This keeps `docker compose up` a working single entry
# point on a cold cache -- Compose does not resolve cross-service build order
# when one service's Dockerfile FROMs another service's image tag.
#
# THE BUILD CONTEXT IS THE SOLUTION ROOT, not `images/` (01.5 SF-5, Deviation 11).
# The agent images resolve their own package set from `profiles/` and `packs/`, which
# sit outside `images/`, and a build stage can only read its own context. Every COPY
# below is therefore written from the solution root, and `images/.dockerignore` is
# gone -- Docker resolves .dockerignore at the context root, so the solution-root file
# governs both this build and the mediator's.

# ==================================================================================
# pack-plan -- resolve one profile's pack set into a flat, checked install plan.
#
# A SEPARATE STAGE SO `yq` AND THE MANIFESTS NEVER REACH A SHIPPED LAYER. This is the
# only step in the agent build that parses YAML; it emits plain text and the install
# stage consumes that. Same split, and the same reason, as the mediator Dockerfile's
# `compile` versus `runtime`.
# The GHCR-published agent-base, consumed BY DIGEST (D21, R10.2, 01.5 SF-6b).
#
# Declared here, above the first FROM, because only a global ARG is in scope in a FROM
# line. IT HAS NO DEFAULT, DELIBERATELY -- the same discipline 01.2 applies to the agent
# pins. Unset, this expands to `...@` and the build dies on an invalid reference instead
# of resolving to a mutable tag, which is the failure mode R10.2 exists to prevent. The
# value lives in compose/pins.env and is a REVIEWED edit: a human copies it from the
# workflow run summary (Edge Case 11's bootstrap).
#
# EVERY BUILD PRINTS A LINT WARNING ABOUT THIS, and it is expected:
#   WARN: InvalidDefaultArgInFrom: Default value for ARG
#   ghcr.io/...agent-sandbox-base@${AGENT_BASE_DIGEST} results in empty or invalid
#   base image name (line 176)
# BuildKit is describing the designed behaviour, not a defect -- an empty value MUST
# produce an invalid reference. It is not suppressed with `# check=skip=`, because that
# directive is file-wide and would also hide a future FROM where the same warning is a
# real one.
ARG AGENT_BASE_DIGEST

FROM node:22-slim AS pack-plan

ARG YQ_VERSION=v4.47.2
ARG YQ_SHA256_ARM64=05df1f6aed334f223bb3e6a967db259f7185e33650c3b6447625e16fea0ed31f
ARG YQ_SHA256_AMD64=1bb99e1019e23de33c7e6afc23e93dad72aad6cf2cb03c797f068ea79814ddb0

# Pinned identically to the mediator image's `base` stage, so the two readers of the
# pack manifests (Contract 5) parse them with the same tool at the same version.
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

# Which profile this image is built for (D10 -- the per-profile image digest). Runtime
# profile selection is MEDIATOR_PROFILE, an environment variable; this is its build-time
# counterpart and defaults to the same profile.
ARG PROFILE=default

COPY profiles /src/profiles
COPY packs /src/packs
COPY images/keyrings /src/images/keyrings
COPY images/pack-plan.sh /usr/local/bin/pack-plan

# The COPY layers above are what makes a changed pack set produce a different image
# (Edge Case 4). BuildKit keys them on file content, so editing a manifest invalidates
# this stage and every stage below it. Deviation 12 records why there is no
# PACK_SET_HASH build argument: it had no producer, and a hand-maintained hash that is
# not recomputed reports "unchanged" precisely when it has changed.
RUN bash /usr/local/bin/pack-plan "${PROFILE}" /src /out

# ==================================================================================
# agent-base -- profile-INDEPENDENT. This is the stage SF-6 publishes to GHCR.
FROM node:22-slim AS agent-base

# `xz-utils` is 01.5 SF-5's addition to this line: node:22-slim ships no `xz`, and the
# Node archive the reference pack pins is a .tar.xz. Found by building, not by reading.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl bubblewrap iproute2 xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY images/keyrings/debian-archive.gpg /usr/local/share/keyrings/debian-archive.gpg
COPY --chmod=0755 images/apt-pinned.sh /usr/local/bin/apt-pinned
COPY --chmod=0755 images/pack-install.sh /usr/local/bin/pack-install
COPY --chmod=0755 images/remove-package-managers.sh /usr/local/bin/remove-package-managers

# `git`, in the BASE and not in a pack -- Deviation 2. R2.9's host_git_config mount and
# scripts/scrub-gitconfig.sh are profile-level features built in 01.4, and they are inert
# without a git binary; making them depend on which packs a profile happens to select
# would let a profile pass every gate and still mount a file nothing can read.
#
# The pins are build args rather than profile fields BECAUSE this stage is
# profile-independent: it is what CI publishes, and a stage that read a profile would
# make the published base vary per profile, contradicting D10. compose/pins.env carries
# the values and these defaults agree with it. The divergence that matters -- this
# archive versus the one the PROFILE names for its packs -- is caught mechanically in
# the agent-packs stage rather than left to convention.
ARG SNAPSHOT_URL=https://snapshot.debian.org/archive/debian/20260901T000000Z/
ARG SNAPSHOT_SUITE=bookworm
ARG SNAPSHOT_FINGERPRINT=B8B80B5B623EAB6AD8775C45B7C5D7D6350947F8
ARG GIT_VERSION=1:2.39.5-0+deb12u3
ARG GIT_SHA256=435176549a9f5c8bbadaa126b64a036b38ea34ad9f3eb128dc40b8407a5b5620
RUN bash /usr/local/bin/apt-pinned \
      /usr/local/share/keyrings/debian-archive.gpg \
      "${SNAPSHOT_URL}" "${SNAPSHOT_SUITE}" "${SNAPSHOT_FINGERPRINT}" \
      "git=${GIT_VERSION}=${GIT_SHA256}"

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

# The OPTIONAL dedicated build cache (R2.10, mounts.build_cache), layered by
# compose/overrides/build-cache.yaml and selected by no profile by default.
#
# TOP-LEVEL, deliberately not under /home/agent/.cache. 01.2 already puts
# /home/agent/.cache on the per-agent state volume, so a nested named volume would
# have to mount inside another volume and would be created root-owned, unwritable by
# the agent it exists for. Creating the directory here with agent ownership is also
# what seeds that ownership onto a fresh named volume. Edge Case 14 asks which of the
# two volumes T23 is asserted against: THIS one, the dedicated volume -- asserting
# against 01.2's state volume would restate the existing layout rather than test the
# option.
RUN mkdir -p /build-cache && chown agent:agent /build-cache

# Home skeleton: the image ships defaults here, never under /home/agent
# itself. The entrypoint seeds missing paths from here into the state volume
# on every start, idempotently.
RUN mkdir -p /opt/agent-home-skel && chown -R agent:agent /opt/agent-home-skel

# The entrypoint's COPY and the ENTRYPOINT instruction are NOT here. They moved down to
# agent-packs at 01.6 SF-3 -- see the note there. This stage still installs everything the
# entrypoint depends on; it just no longer carries the entrypoint itself.

# The AUTH_MODE dispatcher (01.4 SF-2, Interface Contract 2). Lives here rather than under
# scripts/ because the copy-to-volume it performs must run inside the container -- see
# this feature plan, Deviation 1.
#
# STILL IN THIS STAGE, and therefore still digest-pinned: nothing in 01.6 changes it, and moving
# a file that is not broken would be a change nothing asked for. It carries the SAME latent
# property the entrypoint had -- an edit to images/bootstrap-auth.sh does not reach a local build
# until CI republishes this stage and compose/pins.env is repinned. Recorded rather than fixed
# here; the next feature that needs to edit it will have to choose, with this note in front of it.
COPY --chmod=0755 images/bootstrap-auth.sh /usr/local/bin/bootstrap-auth

# AUTH_MODE is deliberately NOT declared with a value in any stage. Interface Contract 2:
# "No default in the image -- an unset value is an error, not a fallback." A default here would
# pick an authentication mode on the operator's behalf, and could pick a less safe one than the
# R4.12 default for that agent. Compose supplies it per agent from the profile's auth_mode block;
# bootstrap-auth exits 2 when it is unset.

# ==================================================================================
# agent-packs -- profile-DEPENDENT. The layer where the profile's pack OS packages and
# archives are installed, build time only (R7.18). Every agent stage passes through it,
# so nothing below depends on which packs were selected.
# NOT `FROM agent-base` -- from the PUBLISHED base, by digest.
#
# The `agent-base` stage above is still the definition of that image and is what CI
# builds and pushes (`--target agent-base`); it is simply no longer what the agent stages
# consume. BuildKit skips a stage nothing references, so a local build PULLS the attested
# base rather than rebuilding it, which is the whole point of D21: the image an operator
# runs is the image CI built, attested and published, not a local re-derivation of it.
#
# The repository is hardcoded rather than built from an ARG. It must agree with the
# workflow's `env.IMAGE`, and it is a supply-chain anchor: a value a caller could pass
# would let `--build-arg` redirect the base image of every agent in the pod.
FROM ghcr.io/ottawacloudconsulting/agentic-ai/agent-sandbox-base@${AGENT_BASE_DIGEST} AS agent-packs

COPY --from=pack-plan /out /tmp/pack-plan
RUN bash /usr/local/bin/pack-install /tmp/pack-plan /usr/local/share/keyrings/debian-archive.gpg \
    && rm -rf /tmp/pack-plan

# Test-only hook for the volume-upgrade smoke check (Edge Case 8): empty by default, so
# it changes nothing about a normal build. When set, adds one file to the home skeleton so
# the test can rebuild with a "changed default" and assert it appears in an existing volume
# without disturbing agent-owned files already there.
#
# MOVED OUT OF agent-base AT 01.5 SF-6b, for two reasons that point the same way. It stopped
# WORKING there: agent-base is now pulled from GHCR by digest, BuildKit skips a stage nothing
# references, and a local `--build-arg SKEL_MARKER=...` therefore reached nothing --
# verify-pod-topology.sh failed with new_file='' the first time it ran against the pinned
# base. And it should not have been there anyway: agent-base is the CI-published
# supply-chain artifact, and a test-only affordance does not belong in an image whose whole
# purpose is to be attested and consumed by digest. agent-packs is built locally and is
# shared by all three agents, which is the property the hook needs.
ARG SKEL_MARKER=""
RUN if [ -n "$SKEL_MARKER" ]; then \
      echo "$SKEL_MARKER" > /opt/agent-home-skel/.upgrade-marker \
      && chown agent:agent /opt/agent-home-skel/.upgrade-marker; \
    fi

# The Go toolchain the pack installs lands at /usr/local/go. An ENV belongs to the
# image, not to the install script. Harmless when no pack supplies Go: the directory
# is simply absent from PATH lookups.
ENV PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# The entrypoint, MOVED HERE FROM agent-base AT 01.6 SF-3, for the reason SKEL_MARKER moved at
# 01.5 SF-6b and by the same evidence: agent-base is pulled from GHCR by digest, BuildKit skips a
# stage nothing references, so an edit to images/entrypoint.sh reached nothing. Found by building
# -- SF-3 added a credential splice to that file, rebuilt all three agents, and verify-pod-topology
# reported the splice had not happened, because the image still carried the PUBLISHED copy.
#
# The alternative was a push, a CI publish and a repin of compose/pins.env for every edit to a
# 145-line shell script. That is the right ceremony for the supply-chain base -- the OS packages,
# the pinned toolchains, the attestation -- and the wrong ceremony for the pod's own start-up
# logic, which is repository code that changes with the features that use it.
#
# D21 is not weakened by this. What D21 protects is that the BASE an operator runs is the base CI
# built and attested, rather than a local re-derivation of it; that is still exactly true. This
# stage already layers locally-derived content onto that attested base -- pack-install, the
# profile's OS packages and archives, SKEL_MARKER. The entrypoint joins them. It is MOVED rather
# than duplicated deliberately: a copy in both stages would leave the published one dead, the
# local one silently winning, and an operator with no way to tell which was running.
COPY --chmod=0755 images/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# ---------------------------------------------------------------------------
FROM agent-packs AS claude

# Which agent this stage is, for the entrypoint's bootstrap-auth invocation.
ENV AGENT_NAME=claude

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

# LAST, after every install in this stage (R7.19, T33, T15). The build-only helpers go
# with them: apt-pinned and pack-install drive a package manager that no longer exists.
RUN bash /usr/local/bin/remove-package-managers \
    && rm -f /usr/local/bin/apt-pinned /usr/local/bin/pack-install /usr/local/bin/remove-package-managers

USER agent
CMD ["claude", "--version"]

# ---------------------------------------------------------------------------
FROM agent-packs AS codex

# Which agent this stage is, for the entrypoint's bootstrap-auth invocation.
ENV AGENT_NAME=codex

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

RUN bash /usr/local/bin/remove-package-managers \
    && rm -f /usr/local/bin/apt-pinned /usr/local/bin/pack-install /usr/local/bin/remove-package-managers

USER agent
CMD ["codex", "--version"]

# ---------------------------------------------------------------------------
FROM agent-packs AS agy

# Which agent this stage is, for the entrypoint's bootstrap-auth invocation.
ENV AGENT_NAME=agy

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

# jq for agy-run.sh's JSON status-field gating (R3.6). Only agy needs it. It now comes
# from the pinned snapshot rather than the rolling archive, because apt-pinned made that
# the image's only source -- so this install is reproducible where it previously was not.
RUN apt-get update && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 images/agy/agy-run.sh /usr/local/bin/agy-run

RUN bash /usr/local/bin/remove-package-managers \
    && rm -f /usr/local/bin/apt-pinned /usr/local/bin/pack-install /usr/local/bin/remove-package-managers

USER agent
CMD ["agy", "--version"]
