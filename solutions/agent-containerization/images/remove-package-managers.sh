#!/usr/bin/env bash
# Remove every package manager from a finished agent image, then PROVE it
# (Feature 01.5 SF-5, R7.19, T33, T15).
#
# RUNS LAST IN EVERY AGENT STAGE, after the pack install, after the CLI install
# (`npm install -g` for claude and codex), and after agy's `jq`. Anything that needs
# a package manager must already have used it.
#
# TWO CLASSES, AND ONLY ONE THE FILESYSTEM CAN STOP -- see the feature plan's
# Approach, "R7.19: two classes of package manager".
#
#   OS manager (T33 is claimed): apt/dpkg are removed here, which is condition 3 of
#   three. Conditions 1 and 2 -- no privilege, no write access -- come from 01.2's
#   hardened runtime and hold at runtime, not here.
#
#   Language managers (T15 is claimed, R7.19 is NOT): removing these raises the cost
#   and does not close the class. /home/agent and /workspace are writable by SC-4, so
#   a vendored or self-written installer still has a target. What actually holds is
#   the absence of registry egress -- the reference pack declares none, so a surviving
#   installer fails at the mediator with an AUDITED denial, which is the half of T15
#   the filesystem controls cannot deliver.
#
# THE REMOVAL LIST IS WIDER THAN THE PLAN NAMES, and every addition was found by
# looking at the image rather than by reading (operator decision, 2026-09-08):
#   * `corepack` -- ships in node:22-slim and installs yarn and pnpm on demand.
#   * `yarn` / `yarnpkg` at /opt/yarn-v1.22.22 -- a complete second Node installer,
#     with symlinks on PATH.
#   * `python3-pip-whl` and `python3-setuptools-whl` -- pulled in by python3-venv and
#     the mechanism by which `python3 -m venv` bootstraps a working pip. Removing
#     `ensurepip` alone leaves the wheels and the capability.
# The cost is recorded in packs/README.md: `python3 -m venv` now needs --without-pip.
#
# WHAT IS DELIBERATELY KEPT: /var/lib/dpkg/status. Condition 3 says "no binary", not
# "no database", and SF-6's SBOM attestation reads that file to enumerate the image.
# Deleting it would buy nothing an attacker cares about and would cost the provenance
# R9.9 requires.

set -euo pipefail

echo "remove-package-managers: removing the OS package manager (R7.19 condition 3)"
rm -rf \
  /usr/bin/apt /usr/bin/apt-get /usr/bin/apt-cache /usr/bin/apt-config \
  /usr/bin/apt-key /usr/bin/apt-mark /usr/bin/apt-cdrom /usr/bin/apt-extracttemplates \
  /usr/bin/apt-ftparchive /usr/bin/apt-sortpkgs \
  /usr/bin/dpkg /usr/bin/dpkg-deb /usr/bin/dpkg-divert /usr/bin/dpkg-query \
  /usr/bin/dpkg-split /usr/bin/dpkg-statoverride /usr/bin/dpkg-trigger \
  /usr/bin/dpkg-maintscript-helper /usr/sbin/dpkg-preconfigure /usr/sbin/dpkg-reconfigure \
  /usr/lib/apt /usr/lib/dpkg \
  /var/cache/apt /var/lib/apt/lists /etc/apt/sources.list.d /etc/apt/sources.list

echo "remove-package-managers: removing Node-level installers (R7.19 condition 4)"
rm -rf \
  /usr/local/lib/node_modules/npm \
  /usr/local/lib/node_modules/corepack \
  /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
  /usr/local/bin/yarn /usr/local/bin/yarnpkg /usr/local/bin/pnpm /usr/local/bin/pnpx \
  /opt/yarn-v* /usr/local/lib/node_modules/yarn /usr/local/lib/node_modules/pnpm \
  /usr/bin/pnpm /usr/bin/yarn

echo "remove-package-managers: removing Python-level installers (R7.19 condition 4)"
rm -rf \
  /usr/lib/python3*/ensurepip \
  /usr/lib/python3/dist-packages/pip /usr/lib/python3/dist-packages/pip-*.dist-info \
  /usr/lib/python3/dist-packages/setuptools /usr/lib/python3/dist-packages/pkg_resources \
  /usr/share/python-wheels \
  /usr/bin/pip /usr/bin/pip3 /usr/local/bin/pip /usr/local/bin/pip3 \
  /usr/bin/pipx /usr/local/bin/pipx /usr/bin/easy_install /usr/local/bin/easy_install \
  /usr/lib/python3/dist-packages/pipx

# --- prove it --------------------------------------------------------------------
# The removals above are a list of PATHS, and a path that moved between base-image
# versions makes an `rm -rf` a silent no-op. So the end state is asserted rather than
# assumed: this block is what actually fails the build.
echo "remove-package-managers: verifying"

fail=0
note() { echo "remove-package-managers: STILL PRESENT -- $*" >&2; fail=1; }

# THE INVENTORY IS THE ASSERTION, so it must not be shorter than reality. A Codex
# adversarial pass showed the previous list passing a container in which `pnpm` and
# `pipx` had been planted -- the script reported "no package manager reachable" and
# exited 0 while both ran. That is this file's own failure mode: an allowlist of names
# presented as a reachability proof.
for cmd in apt apt-get apt-cache apt-config apt-key apt-mark dpkg dpkg-query dpkg-deb \
           npm npx corepack yarn yarnpkg pnpm pnpx \
           pip pip3 pipx easy_install easy_install3 conda; do
  if command -v "$cmd" >/dev/null 2>&1; then
    note "$cmd on PATH at $(command -v "$cmd")"
  fi
done

# The direct-path invocations, not only the PATH entries -- removing a bin symlink
# while leaving the tree behind is the failure this pair of checks exists to catch.
for p in /usr/local/lib/node_modules/npm/bin/npm-cli.js \
         /usr/local/lib/node_modules/npm/bin/npx-cli.js \
         /usr/local/lib/node_modules/corepack/dist/corepack.js \
         /usr/share/python-wheels; do
  if [ -e "$p" ]; then note "$p"; fi
done

if command -v python3 >/dev/null 2>&1; then
  # IMPORTABILITY, not exit status. `python3 -m pip --version` failing proves nothing on
  # its own -- a pip that is present but broken fails too, and would have passed this
  # check vacuously. `find_spec` answers the question actually being asked: is the module
  # reachable at all? Same for ensurepip, setuptools and pkg_resources, each of which can
  # rebuild an installer.
  for mod in pip ensurepip setuptools pkg_resources pipx; do
    if python3 -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('$mod') else 1)" >/dev/null 2>&1; then
      note "python3 can import the '$mod' module"
    fi
  done
fi

# The database is kept on purpose (SF-6's SBOM). Assert that too, so a future
# broadening of the removal list does not take it out silently.
[ -f /var/lib/dpkg/status ] \
  || { echo "remove-package-managers: /var/lib/dpkg/status is missing; SF-6's SBOM attestation reads it" >&2; fail=1; }

[ "$fail" -eq 0 ] || exit 3
echo "remove-package-managers: verified -- no package manager reachable, dpkg database retained"
