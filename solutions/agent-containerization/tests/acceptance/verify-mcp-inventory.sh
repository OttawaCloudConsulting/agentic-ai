#!/usr/bin/env bash
# Acceptance test for Feature 02.3 SF-6 (MCP measurement, inventory schema and
# compile-time enforcement).
#
# Phase A: the mcp: profile schema -- required block, registry/servers/plugins/skills
# shape, T30's transport/enforcement_point pairing, and the compiler's composition of an
# http/sse server's egress into the listed agents' allowlists. Host-only: no docker.
#
# Phase B: T31, re-verified -- no npm/yarn/PyPI/Go-proxy FQDN appears in any committed
# resolved artifact, and `npx` is absent from every built `:local` agent image. Requires
# the three `sandboxed-agent/{claude,codex,agy}:local` images to be built already; skips
# with a note (not a failure) if they are not.
#
# Requires: yq (mikefarah/yq), git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
phase() { echo; echo "=== Phase $1 -- $2"; }

command -v yq  >/dev/null 2>&1 || { echo "verify-mcp-inventory: yq is required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "verify-mcp-inventory: git is required" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Scaffolding -- a probe PROFILE only. mcp: schema and T30 do not depend on packs.
# ---------------------------------------------------------------------------

PROBE_PROFILE="profiles/sf6-probe.yaml"

[ ! -e "$PROBE_PROFILE" ] || {
  echo "verify-mcp-inventory: $PROBE_PROFILE already exists; remove it before running" >&2
  exit 1
}

cleanup() { rm -f "$PROBE_PROFILE"; }
trap cleanup EXIT

expect() {
  local want="$1" frag="$2" label="$3"; shift 3
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: expected exit $want, got $rc"
    printf '%s\n' "$out" | head -5 | sed 's/^/      /'
    return
  fi
  if [ -n "$frag" ] && ! printf '%s' "$out" | grep -qF -- "$frag"; then
    fail "$label: exit $want as expected, but the message did not name '$frag'"
    printf '%s\n' "$out" | head -5 | sed 's/^/      /'
    return
  fi
  pass "$label"
}

make_probe_profile() {
  local expr="$1"
  yq eval "$expr" "profiles/default.yaml" > "$PROBE_PROFILE"
}

compile_probe() {
  bash scripts/compile-policy.sh --profile sf6-probe --out "$(mktemp)" "$@"
}

FIXTURE_SERVER_STDIO='{
  "name": "sf6-fixture-stdio", "agents": ["claude"], "version": "1.0.0",
  "artifact": "n/a: fixture",
  "transport": "stdio", "enforcement_point": "none",
  "egress": {"allow_fqdns": [], "allow_cidrs": []},
  "mounts": [], "env": [], "credentials": [],
  "needs_write_access": false, "risk_tier": "read-only",
  "capability_baseline": {"config_sha256": "'"$(printf 'sf6-stdio' | sha256sum | cut -d' ' -f1)"'", "tools": []}
}'

FIXTURE_SERVER_HTTP='{
  "name": "sf6-fixture-http", "agents": ["claude"], "version": "1.0.0",
  "artifact": "n/a: remote server, nothing installed",
  "transport": "http", "enforcement_point": "mediator",
  "egress": {"allow_fqdns": [{"fqdn": "mcp.sf6-fixture.lab", "port": 443}], "allow_cidrs": []},
  "mounts": [], "env": [], "credentials": [],
  "needs_write_access": false, "risk_tier": "read-only",
  "capability_baseline": {"config_sha256": "'"$(printf 'sf6-http' | sha256sum | cut -d' ' -f1)"'", "tools": ["search"]}
}'

# ---------------------------------------------------------------------------
# Phase A -- SF-6: mcp: schema, registry/R7.16, T30 pairing, egress composition
# ---------------------------------------------------------------------------
phase A "mcp: schema, R7.16 registry gate, T30 transport/enforcement_point pairing"

expect 0 "" "A: lint-policy.sh accepts the tree as shipped (every profile carries mcp:)" \
  bash scripts/lint-policy.sh

# Every shipped profile carries the block (criterion 8).
for p in profiles/*.yaml; do
  base="$(basename "$p")"
  [ "$base" != "sf6-probe.yaml" ] || continue
  if [ "$(yq eval 'has("mcp")' "$p")" = "true" ]; then
    pass "A: $base carries an mcp: block"
  else
    fail "A: $base has no mcp: block"
  fi
done

# Criterion 8 -- an absent mcp: block is an input error (exit 2), the exports precedent.
make_probe_profile 'del(.mcp)'
expect 2 "field 'mcp' is missing" \
  "A: a profile with no mcp: block is refused at exit 2" \
  compile_probe
rm -f "$PROBE_PROFILE"

# R7.16 -- servers non-empty but registry: none is refused.
make_probe_profile ".mcp.servers = [${FIXTURE_SERVER_STDIO}] | .mcp.registry = \"none\""
expect 2 "R7.16 requires a declared, pinned registry" \
  "A: a non-empty mcp.servers with registry 'none' is refused (R7.16)" \
  compile_probe
rm -f "$PROBE_PROFILE"

# R7.16 -- a pinned registry with an empty servers list is the correct explicit "none",
# not an error -- every shipped profile already exercises this (positive control above).

# T30 -- a stdio server naming an enforcement_point other than 'none' is refused.
make_probe_profile ".mcp.servers = [(${FIXTURE_SERVER_STDIO} | .enforcement_point = \"mediator\")] | .mcp.registry = {\"type\": \"npm-tarball\", \"url\": \"https://example.test\", \"pinned\": \"1\"}"
expect 2 "reaches no network enforcement point" \
  "A: T30 -- a stdio server naming enforcement_point 'mediator' is refused" \
  compile_probe
rm -f "$PROBE_PROFILE"

# T30 -- an http server naming enforcement_point 'none' is refused.
make_probe_profile ".mcp.servers = [(${FIXTURE_SERVER_HTTP} | .enforcement_point = \"none\")] | .mcp.registry = {\"type\": \"npm-tarball\", \"url\": \"https://example.test\", \"pinned\": \"1\"}"
expect 2 "must cross the mediator to be covered" \
  "A: T30 -- an http server naming enforcement_point 'none' is refused" \
  compile_probe
rm -f "$PROBE_PROFILE"

# T30 -- a stdio server declaring its own egress.allow_fqdns is refused: its traffic
# inherits the agent's proxy environment and does not compose its own entries.
make_probe_profile ".mcp.servers = [(${FIXTURE_SERVER_STDIO} | .egress.allow_fqdns = [{\"fqdn\": \"should-not-compose.example\", \"port\": 443}])] | .mcp.registry = {\"type\": \"npm-tarball\", \"url\": \"https://example.test\", \"pinned\": \"1\"}"
expect 2 "does not compose its own egress entries" \
  "A: a stdio server declaring egress.allow_fqdns is refused" \
  compile_probe
rm -f "$PROBE_PROFILE"

# agents: a name outside the base allowlist's keys is refused.
make_probe_profile ".mcp.servers = [(${FIXTURE_SERVER_STDIO} | .agents = [\"not-a-real-agent\"])] | .mcp.registry = {\"type\": \"npm-tarball\", \"url\": \"https://example.test\", \"pinned\": \"1\"}"
expect 2 "is not an agent the base allowlist keys" \
  "A: mcp.servers[].agents naming an unknown agent is refused" \
  compile_probe
rm -f "$PROBE_PROFILE"

# risk_tier: an unrecognised value is refused.
make_probe_profile ".mcp.servers = [(${FIXTURE_SERVER_STDIO} | .risk_tier = \"catastrophic\")] | .mcp.registry = {\"type\": \"npm-tarball\", \"url\": \"https://example.test\", \"pinned\": \"1\"}"
expect 2 "risk_tier must be one of read-only, write or irreversible" \
  "A: an unrecognised risk_tier is refused" \
  compile_probe
rm -f "$PROBE_PROFILE"

# capability_baseline.config_sha256: not a 64-hex digest is refused.
make_probe_profile ".mcp.servers = [(${FIXTURE_SERVER_STDIO} | .capability_baseline.config_sha256 = \"not-a-digest\")] | .mcp.registry = {\"type\": \"npm-tarball\", \"url\": \"https://example.test\", \"pinned\": \"1\"}"
expect 2 "is not a 64-character lowercase hex digest" \
  "A: capability_baseline.config_sha256 that is not a 64-hex digest is refused" \
  compile_probe
rm -f "$PROBE_PROFILE"

# Positive control -- a well-formed http server composes its egress into the named
# agent's allowlist, exactly like a pack's runtime entry (D18, Decision 8).
A_OUT="$(mktemp)"
make_probe_profile ".mcp.servers = [${FIXTURE_SERVER_HTTP}] | .mcp.registry = {\"type\": \"npm-tarball\", \"url\": \"https://example.test\", \"pinned\": \"1\"}"
if bash scripts/compile-policy.sh --profile sf6-probe --out "$A_OUT" >/dev/null 2>&1; then
  A_FQDNS="$(yq eval '.agents.claude.allow_fqdns[].fqdn' "$A_OUT")"
  if grep -Fxq "mcp.sf6-fixture.lab" <<< "$A_FQDNS"; then
    pass "A: a well-formed http mcp server composes its egress into the listed agent's allowlist"
  else
    fail "A: mcp.sf6-fixture.lab did not appear in agents.claude.allow_fqdns after compiling an http server for claude"
  fi
  # And it stays OUT of a non-listed agent's allowlist (agents filter is honoured).
  A_CODEX_FQDNS="$(yq eval '.agents.codex.allow_fqdns[].fqdn' "$A_OUT")"
  if grep -Fxq "mcp.sf6-fixture.lab" <<< "$A_CODEX_FQDNS"; then
    fail "A: mcp.sf6-fixture.lab leaked into agents.codex.allow_fqdns, but the server names only claude"
  else
    pass "A: an mcp server's egress reaches only the agents it names"
  fi
  # The resolved schema is unchanged (Interface Contract 5): no 'mcp' key is emitted.
  if [ "$(yq eval 'has("mcp")' "$A_OUT")" = "true" ]; then
    fail "A: the resolved artifact carries an 'mcp' key -- Interface Contract 5 says the resolved schema is unchanged"
  else
    pass "A: the resolved artifact carries no 'mcp' key -- only the composed egress crosses into it"
  fi
else
  fail "A: a well-formed mcp: block with one http server failed to compile"
fi
rm -f "$PROBE_PROFILE" "$A_OUT"

# ---------------------------------------------------------------------------
# Phase B -- SF-6: T31, re-verified against every committed profile and image
# ---------------------------------------------------------------------------
phase B "T31 -- no package-registry proxy entry in any resolved artifact; npx absent from every image"

PROXY_FQDNS="registry.npmjs.org npmjs.org yarnpkg.com registry.yarnpkg.com pypi.org files.pythonhosted.org proxy.golang.org sum.golang.org"

for f in policy/resolved/*.yaml; do
  base="$(basename "$f")"
  bad=0
  ALL_FQDNS="$(yq eval '.agents.*.allow_fqdns[].fqdn' "$f" 2>/dev/null || true)"
  for proxy in $PROXY_FQDNS; do
    if grep -Fxq "$proxy" <<< "$ALL_FQDNS"; then
      fail "B: $base: package-registry proxy FQDN '$proxy' is present in a resolved artifact (T31)"
      bad=1
    fi
  done
  [ "$bad" -eq 1 ] || pass "B: $base: no npm/yarn/PyPI/Go-proxy FQDN present (T31)"
done

if command -v docker >/dev/null 2>&1; then
  for agent in claude codex agy; do
    img="sandboxed-agent/${agent}:local"
    if ! docker image inspect "$img" >/dev/null 2>&1; then
      echo "SKIP: B: ${img} is not built locally; run scripts/build.sh first to exercise this check"
      continue
    fi
    if docker run --rm --entrypoint sh "$img" -c 'command -v npx' >/dev/null 2>&1; then
      fail "B: ${img} carries npx -- R7.16 requires no wholesale package-registry install channel"
    else
      pass "B: ${img} has no npx binary"
    fi
  done
else
  echo "SKIP: B: docker is not available; image-level npx check not run"
fi

# The HashiCorp and GitHub R14.1 records exist and are anchor-resolvable (criterion 3,
# already built at SF-3/SF-4); re-asserted here because T31's scope is "re-verified
# against every committed profile", and both parties' packages are now on that path.
for anchor in r141-hashicorp r141-github; do
  if grep -q "id=\"${anchor}\"" docs/records/third-party-assessments.md; then
    pass "B: docs/records/third-party-assessments.md carries the '${anchor}' R14.1 record"
  else
    fail "B: docs/records/third-party-assessments.md has no '${anchor}' R14.1 record anchor"
  fi
done

echo
echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ]
