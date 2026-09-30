#!/usr/bin/env bash
# Acceptance test for Feature 02.5 (Containment, response and the authorization gate).
#
# Phase A (SF-3): the static checks. Every named volume has a disposition, every credential
# inventory row has a procedure, a stated maximum, a measured value and a rebuild cell, the
# runbook carries its definitions and its five actions, the R14.3 record names an owner and
# triggers for all three provider routes, and `.dockerignore` admits nothing under `workspace/`.
#   **Phase A is RED BY DESIGN until the drills land**, in two separate parts, and neither is
#   skipped -- see `docs/records/containment-drills.md` § "Expected red":
#     * the inventory's Measured and Rebuild cells are placeholders until SF-6;
#     * the R14.3 three-route table is written by SF-7.
#
# Phase B (SF-3): T40, both forms, for each agent -- the stop form (agent first, then its
# recorder) and the disconnect form (`docker network disconnect` the agent, container kept).
# Phase C (SF-3): the pod-wide cut. The mediator is detached from `egress-net`; every agent's
# allowed request fails AND each attempt is still on the audit trail (Decision 3, Edge Case 8).
# Phase D (SF-3): R12.5. `down` without `-v` removes containers, tmpfs and networks and
# preserves every named volume, asserted with markers.
# Phase F (SF-2): T37. The authorization gate, proven in both directions -- one compile
# negative per row of the feature plan's Interface Contract 2, the Interface Contract 1 and 3
# shape rules, every shipped profile still compiling, and the runtime half under the `default`
# profile: the credentials a classified action would need are ABSENT from every agent, and a
# CONNECT to github.com from `claude` and `agy` is refused with an audit line carrying `agent`
# and `identity_source`.
#
# Phase E (T41's mechanical steps) arrives with SF-4, between D and F, on the same fixture
# stack. The teardown contract: `down -v --remove-orphans` runs ONLY in the trap, under this
# script's own project names, because the phases here assert what SURVIVES a `down` and a
# harness that volume-pruned between phases would destroy the evidence it is measuring.
# Phase D's own `down` is deliberately WITHOUT `-v` -- that is the assertion.
#
# TWO STACKS, RUN IN SEQUENCE, NEVER CONCURRENTLY. Phases B-D need the fixture topology, so
# nothing they do spends a model token or a login; phase F's runtime half needs the SHIPPED
# `default` topology, because the fixture allowlist would refuse github.com for every agent
# including `codex` and turn the measurement into a tautology. Both topologies claim
# 172.31.{10,20,30}.0/24, so the fixture stack is brought DOWN (without `-v`) before phase F
# brings the default stack up. The trap tears down both.
#
# There is no skip variable, following `retry_cold_peer`'s reasoning: a phase that can be turned
# off is a phase whose red state has an accepted excuse.
#
# Requires: yq (mikefarah/yq), docker, jq.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROJECT="containment-$$"
PROJECT_FX="containment-fx-$$"
AGENTS=(claude codex agy)
PASSED=0
FAILED=0

pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
note() { echo "      $*"; }
phase() { echo; echo "=== Phase $1 -- $2"; }

for c in yq docker jq; do
  command -v "$c" >/dev/null 2>&1 || { echo "verify-containment: $c is required" >&2; exit 1; }
done

# The `default` topology, for phase F (see the two-stacks note above).
COMPOSE=(docker compose --env-file compose/pins.env
         -f compose/compose.yaml
         -f compose/overrides/default.yaml
         -p "$PROJECT")

# The fixture topology, for phases B-D (and E when it lands). `test-containment.yaml` is the
# one thing beyond 02.2's fixture override these phases need: agents that are COMPOSE SERVICE
# containers and stay up, so that `docker compose stop claude`, `docker compose start claude`
# and `docker compose down` -- the literal commands the runbook hands the operator -- act on
# something. A one-off `compose run` container, which is how every other harness gets a
# long-lived agent, carries `com.docker.compose.oneoff=True` and every Compose subcommand
# ignores it.
FX_COMPOSE=(docker compose --env-file compose/pins.env
            -f compose/compose.yaml
            -f compose/overrides/default.yaml
            -f compose/overrides/test-egress.yaml
            -f compose/overrides/test-containment.yaml
            -p "$PROJECT_FX")
fx() { AGENT_PROFILE=test-fixtures "${FX_COMPOSE[@]}" "$@"; }

FIXTURES="tests/fixtures/authorization"
PROBE_PACK_DIR="packs/authz-probe"
TLS_DIR="tests/fixtures/tls"
MED_IMAGE=sandboxed-agent/mediator:local
RUNBOOK="docs/containment-runbook.md"
INVENTORY="docs/records/credential-inventory.md"
ASSESSMENTS="docs/records/third-party-assessments.md"
STACK_UP=0
FX_TOUCHED=0

cleanup() {
  rm -f "$FIXTURES"/probe-*.yaml
  rm -rf "$PROBE_PACK_DIR"
  rm -rf "$TLS_DIR"
  if [ "$FX_TOUCHED" = 1 ]; then
    echo
    echo "--- tearing down $PROJECT_FX ---"
    fx down -v --remove-orphans >/dev/null 2>&1 || true
  fi
  if [ "$STACK_UP" = 1 ]; then
    echo
    echo "--- tearing down $PROJECT ---"
    AGENT_PROFILE=default "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

[ ! -e "$PROBE_PACK_DIR" ] || {
  echo "verify-containment: $PROBE_PACK_DIR already exists; remove it before running" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Preflight -- the subnet claim, before anything is built
# ---------------------------------------------------------------------------
# Both stacks pin 172.31.{10,20,30}.0/24 and the fixture stack pins .40.0/24 as well. A
# "Pool overlaps" error discovered in the middle of phase B leaves a half-up stack behind,
# which is the worst failure mode this harness has; discovering it here costs one command.
phase preflight "no other Compose project holds this pod's subnets"

# The trailing `|| true` is load-bearing under `set -e`: the `while` body's last command is a
# `grep -q` that FAILS for every non-conflicting network, so the loop -- and with it the whole
# command substitution -- exits non-zero on the happy path. Without this, a clean machine would
# abort the harness here with no output at all.
conflict="$(docker network ls --format '{{.Name}}' \
  | grep -vE "^(${PROJECT}|${PROJECT_FX})_" \
  | while read -r n; do
      docker network inspect "$n" --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null \
        | grep -qE '172\.31\.(10|20|30|40)\.0/24' && echo "$n"
    done || true)"
if [ -n "$conflict" ]; then
  echo "FAIL: another Compose project already holds this pod's subnets:"
  printf '  %s\n' $conflict
  exit 1
fi
pass "preflight: no other project holds 172.31.{10,20,30,40}.0/24"

# ---------------------------------------------------------------------------
# Phase A -- the static checks
# ---------------------------------------------------------------------------
phase A "static -- dispositions, inventory completeness, the runbook, R14.3, .dockerignore"

# --- A1: every named volume has a disposition (Interface Contract 5) -----------------------
# The union of `volumes:` keys across every SHIPPED profile and every opt-in fragment, taken
# from `docker compose config` rather than by reading compose.yaml, so a volume introduced by
# a fragment cannot hide from the table. Names are compared after the Compose project prefix
# is stripped, which `config` has already done -- it prints the declaration keys.
#
# `-p` here names a throwaway project: `config` creates nothing, but a bare `docker compose`
# would inherit `name: sandboxed-agent-pod` from compose.yaml and the output would be keyed on
# the operator's own project.
compose_volumes() { # <profile> <override...> -- prints one volume name per line
  local prof="$1"; shift
  local args=()
  local f
  for f in "$@"; do args+=(-f "compose/overrides/$f"); done
  AGENT_PROFILE="$prof" docker compose --env-file compose/pins.env \
    -f compose/compose.yaml "${args[@]}" -p "${PROJECT}-cfg" config --format json 2>/dev/null \
    | jq -r '.volumes | keys[]'
}

# (profile, override set). `github`, `kubernetes` and `terraform` each REPLACE default.yaml
# (README: `-f compose/compose.yaml -f compose/overrides/github.yaml`); `oauth-mount` has no
# Compose counterpart of its own and runs on default.yaml; the three opt-in fragments layer on
# top of it.
DECLARED_VOLUMES="$( {
  compose_volumes default default.yaml
  compose_volumes github github.yaml
  compose_volumes kubernetes kubernetes.yaml
  compose_volumes terraform terraform.yaml
  compose_volumes oauth-mount default.yaml
  compose_volumes oauth-mount default.yaml oauth-mount.bootstrap.yaml
  compose_volumes default default.yaml build-cache.yaml
  compose_volumes default default.yaml codex-callback.yaml
  compose_volumes default default.yaml host-gitconfig.yaml
} | sort -u)"

if [ -z "$DECLARED_VOLUMES" ]; then
  fail "A1: could not enumerate any named volume from 'docker compose config'"
else
  note "A1: $(printf '%s\n' "$DECLARED_VOLUMES" | wc -l | tr -d ' ') declared volumes across the shipped profiles and fragments"
fi

# The disposition table's first column. Host-side stores in that column (`compose/generated/`,
# `mediator/identity/`, the project mount) are deliberately NOT volume names and are filtered
# out by the shape test -- a volume name is a single bare token.
DISPOSITION_STORES="$(awk '
  /^### 5\.2 /      {inside = 1; next}
  inside && /^### / {inside = 0}
  inside && /^\| / {
    n = split($0, cell, "|")
    if (n < 3) next
    print cell[2]
  }' "$RUNBOOK" \
  | tr ',' '\n' | tr -d '`' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | grep -E '^[a-z][a-z0-9-]*$' | sort -u)"

MISSING_DISPOSITION=""
for v in $DECLARED_VOLUMES; do
  printf '%s\n' "$DISPOSITION_STORES" | grep -qFx "$v" || MISSING_DISPOSITION="${MISSING_DISPOSITION} $v"
done
if [ -z "$MISSING_DISPOSITION" ]; then
  pass "A1: every declared named volume has a row in the runbook's disposition table (Contract 5)"
else
  fail "A1: named volumes with no disposition:${MISSING_DISPOSITION}"
  note "Edge Case 11: a new volume arrives with a recovery decision, or this phase fails."
fi

# The table must not name a volume that no longer exists either -- a stale row is a disposition
# the operator would look for and not find.
STALE_DISPOSITION=""
for s in $DISPOSITION_STORES; do
  printf '%s\n' "$DECLARED_VOLUMES" | grep -qFx "$s" || STALE_DISPOSITION="${STALE_DISPOSITION} $s"
done
[ -z "$STALE_DISPOSITION" ] \
  && pass "A1: the disposition table names no volume the topology no longer declares" \
  || fail "A1: disposition rows for volumes nothing declares:${STALE_DISPOSITION}"

# --- A2: the credential inventory is complete (Interface Contract 4) -----------------------
# Table A is identity/lifetime/blast-radius, Table B is controls/revocation/maxima/measurements.
# Every Table A row must have a Table B row, and every Table B row must carry four filled cells.
#
# "Filled" excludes the literal placeholder as well as the empty string. As of SF-1 the Measured
# and Rebuild cells read `*(pending -- 02.5 SF-5/SF-6 drill)*`, which is not empty; a parser that
# only tested for emptiness would go green and assert that drills had happened when none had.
# See `docs/records/containment-drills.md` § "Expected red", "Parser rule, binding on SF-3".
inventory_rows() { # <table heading prefix> -- prints "id<TAB>col3<TAB>col5<TAB>col6<TAB>col7"
  awk -v want="$1" -F'|' '
    $0 ~ ("^" want) {inside = 1; next}
    inside && /^#/  {inside = 0}
    inside && /^\| [EVS][0-9]+ \|/ {
      id = $2; gsub(/^[ \t]+|[ \t]+$/, "", id)
      c3 = $4; gsub(/^[ \t]+|[ \t]+$/, "", c3)
      c5 = $6; gsub(/^[ \t]+|[ \t]+$/, "", c5)
      c6 = $7; gsub(/^[ \t]+|[ \t]+$/, "", c6)
      c7 = $8; gsub(/^[ \t]+|[ \t]+$/, "", c7)
      printf "%s\t%s\t%s\t%s\t%s\n", id, c3, c5, c6, c7
    }' "$INVENTORY"
}

TABLE_A_IDS="$(inventory_rows '### Table A' | cut -f1 | sort -u)"
TABLE_B_ROWS="$(inventory_rows '### Table B')"
TABLE_B_IDS="$(printf '%s\n' "$TABLE_B_ROWS" | cut -f1 | sort -u)"

if [ -n "$TABLE_A_IDS" ] && [ "$TABLE_A_IDS" = "$TABLE_B_IDS" ]; then
  pass "A2: every Table A credential row has a Table B row ($(printf '%s\n' "$TABLE_B_IDS" | wc -l | tr -d ' ') rows)"
else
  fail "A2: Table A and Table B do not carry the same row ids"
  note "A: $(printf '%s' "$TABLE_A_IDS" | tr '\n' ' ')"
  note "B: $(printf '%s' "$TABLE_B_IDS" | tr '\n' ' ')"
fi

filled() { # <cell> -- non-empty, and not a placeholder
  case "$1" in
    ""|"—"|"-"|"TBD"|"n/a") return 1 ;;
    *pending*|*PENDING*)    return 1 ;;
    *)                      return 0 ;;
  esac
}

A2_PROCEDURE_BAD=""; A2_MAX_BAD=""; A2_MEASURED_BAD=""; A2_REBUILD_BAD=""
while IFS=$'\t' read -r id c3 c5 c6 c7; do
  [ -n "$id" ] || continue
  filled "$c3" || A2_PROCEDURE_BAD="${A2_PROCEDURE_BAD} $id"
  filled "$c5" || A2_MAX_BAD="${A2_MAX_BAD} $id"
  # Contract 4: `mm:ss` (or `h:mm:ss`), or `GAP: <reason>`. Nothing else counts as measured.
  if ! filled "$c6" || ! printf '%s' "$c6" | grep -qE '([0-9]+:)?[0-9]+:[0-9]{2}|GAP'; then
    A2_MEASURED_BAD="${A2_MEASURED_BAD} $id"
  fi
  # Contract 4: `no` (image IDs equal) or `GAP (R8.5): <reason>`.
  if ! filled "$c7" || ! printf '%s' "$c7" | grep -qE '^(no|GAP \(R8\.5\))'; then
    A2_REBUILD_BAD="${A2_REBUILD_BAD} $id"
  fi
done <<< "$TABLE_B_ROWS"

[ -z "$A2_PROCEDURE_BAD" ] \
  && pass "A2: every inventory row carries a documented revocation procedure" \
  || fail "A2: rows with no revocation procedure:${A2_PROCEDURE_BAD}"

[ -z "$A2_MAX_BAD" ] \
  && pass "A2: every inventory row carries an operator-confirmed stated maximum" \
  || fail "A2: rows with no stated maximum:${A2_MAX_BAD}"

if [ -z "$A2_MEASURED_BAD" ]; then
  pass "A2: every inventory row carries a measured detection-to-revocation time or a GAP"
else
  fail "A2: rows with no measured value and no GAP:${A2_MEASURED_BAD}"
  note "EXPECTED RED until SF-6 (Edge Case 17). Recorded in docs/records/containment-drills.md."
fi

if [ -z "$A2_REBUILD_BAD" ]; then
  pass "A2: every inventory row states whether a rebuild was required (R8.5)"
else
  fail "A2: rows with no rebuild cell:${A2_REBUILD_BAD}"
  note "EXPECTED RED until SF-6 (Edge Case 17). Recorded in docs/records/containment-drills.md."
fi

# --- A3: the runbook carries both definitions and the five action sections -----------------
grep -qE '^### An event is' "$RUNBOOK" \
  && pass "A3: the runbook defines an event" \
  || fail "A3: the runbook has no event definition"
grep -qE '^### An incident starts' "$RUNBOOK" \
  && pass "A3: the runbook defines an incident, and it is what starts t0" \
  || fail "A3: the runbook has no incident definition"

A3_MISSING=""
for s in 3.1 3.2 3.3 3.4 3.5; do
  grep -qE "^### ${s} " "$RUNBOOK" || A3_MISSING="${A3_MISSING} ${s}"
done
[ -z "$A3_MISSING" ] \
  && pass "A3: the runbook carries all five containment action sections (3.1-3.5)" \
  || fail "A3: the runbook is missing action sections:${A3_MISSING}"

grep -qE '^## 5\.|^### 5\.2 ' "$RUNBOOK" \
  && pass "A3: the runbook carries the return-to-known-good path and its disposition table" \
  || fail "A3: the runbook has no return-to-known-good section"

# --- A4: the R14.3 record covers all three provider routes --------------------------------
# Criterion 6: the record names the OWNER and the REVIEW TRIGGERS for the `claude`, `codex`
# and `agy` routes, not Antigravity alone, plus the monitoring cadence.
#
# The shape phase A reads, and the shape SF-7 therefore writes: a table inside the R14.3
# section whose header names Route, Owner and Review trigger, with one row per route. As of
# SF-1 that table does not exist -- only the single-route Antigravity block does -- so this is
# the SECOND part of phase A that is RED BY DESIGN, and it goes green at SF-7, not SF-6.
R14_SECTION="$(awk '/^## R14\.3/ {inside = 1} inside && /^## / && !/^## R14\.3/ {inside = 0} inside' "$ASSESSMENTS")"

R14_TABLE="$(printf '%s\n' "$R14_SECTION" | awk -F'|' '
  tolower($0) ~ /route/ && tolower($0) ~ /owner/ && tolower($0) ~ /review trigger/ {inside = 1; next}
  inside && !/^\|/ {inside = 0}
  inside')"

R14_MISSING=""
for route in claude codex agy; do
  printf '%s\n' "$R14_TABLE" | grep -qE "^\| *\`?${route}\`? *\|" || R14_MISSING="${R14_MISSING} ${route}"
done
if [ -z "$R14_MISSING" ] && [ -n "$R14_TABLE" ]; then
  pass "A4: the R14.3 record names an owner and review triggers for all three provider routes"
else
  fail "A4: the R14.3 record has no Route/Owner/Review-trigger row for:${R14_MISSING:- (the table itself is absent)}"
  note "EXPECTED RED until SF-7 (criterion 6). Recorded in docs/records/containment-drills.md."
fi

if printf '%s\n' "$R14_SECTION" | grep -qiE 'cadence'; then
  pass "A4: the R14.3 record states a monitoring cadence"
else
  fail "A4: the R14.3 record states no monitoring cadence"
  note "EXPECTED RED until SF-7 (criterion 6)."
fi

# --- A5: `.dockerignore` admits nothing under `workspace/` --------------------------------
# The build context is the solution root, and `workspace/` is the operator's own project mount
# -- agent-writable by design (R2.1). A `!workspace` line anywhere would put whatever an agent
# wrote there into an image layer.
grep -qE '^\*$' .dockerignore \
  && pass "A5: .dockerignore is deny-all plus an explicit allowlist" \
  || fail "A5: .dockerignore has no deny-all '*' line; it is not an allowlist"

if grep -nE '^!.*workspace' .dockerignore; then
  fail "A5: .dockerignore re-admits a path under workspace/"
else
  pass "A5: .dockerignore admits nothing under workspace/"
fi

# ---------------------------------------------------------------------------
# The fixture stack -- phases B, C and D (and E when SF-4 lands)
# ---------------------------------------------------------------------------
phase "B-D bring-up" "the fixture topology (no model token, no login)"

# The fixture PKI, generated from the mediator image's own pinned OpenSSL, exactly as
# verify-audit-completeness.sh does -- the harness introduces no new image and no new pin.
rm -rf "$TLS_DIR"; mkdir -p "$TLS_DIR"
if docker run --rm -v "$ROOT/$TLS_DIR:/out" --entrypoint bash "$MED_IMAGE" -c '
      openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
        -keyout /out/fixture.key -out /out/fixture.crt -subj "/CN=fixture.lab" \
        -addext "subjectAltName=DNS:allowed.fixture.lab" \
      && chmod 0644 /out/fixture.crt /out/fixture.key' >/dev/null 2>&1; then
  pass "fixture PKI generated from the mediator image's pinned OpenSSL"
else
  fail "fixture PKI generation failed -- phases B-D cannot run"
  echo; echo "=== verify-containment: $PASSED passed, $FAILED failed"; exit 1
fi

fx config >/dev/null 2>&1 \
  && pass "docker compose config (base + default + test-egress + test-containment) is valid" \
  || { fail "the fixture topology does not render"; echo; echo "=== verify-containment: $PASSED passed, $FAILED failed"; exit 1; }

FX_TOUCHED=1
echo "--- building the fixture stack ---"
fx build >"${TMPDIR:-/tmp}/containment-fx-build.$$.log" 2>&1 || {
  fail "the fixture stack failed to build"
  tail -20 "${TMPDIR:-/tmp}/containment-fx-build.$$.log" | sed 's/^/      /'
  echo; echo "=== verify-containment: $PASSED passed, $FAILED failed"; exit 1
}

fx_med() { docker exec "${PROJECT_FX}-egress-mediator-1" "$@"; }
fx_audit() { fx_med cat /var/log/mediator/egress-audit.log 2>/dev/null || true; }
fx_audit_lines() { fx_med sh -c 'wc -l < /var/log/mediator/egress-audit.log' 2>/dev/null | tr -d ' \n' || true; }
fx_state() { docker inspect -f '{{.State.Status}}' "${PROJECT_FX}-$1-1" 2>/dev/null || echo absent; }
fx_in() { docker exec "${PROJECT_FX}-$1-1" sh -c "$2" 2>&1 || true; }

# The allowed-path probe, run from INSIDE the agent container so that what is measured is the
# agent's own route out. It cannot lean on the entrypoint's spliced `HTTPS_PROXY`: the splice
# happens in the entrypoint's process environment, and `docker exec` gets the container's
# configured environment instead, which is deliberately credential-free. Each agent therefore
# presents its own material explicitly, from its own `/run/secrets`.
#
# `-k` is on the ORIGIN leg only. The fixture collector serves a self-signed certificate the
# pod has no reason to trust; the PROXY leg keeps `--proxy-cacert`, because the proxy hop's
# trust is part of what these phases are about.
fx_probe_script() { # <agent>
  case "$1" in
    claude) printf '%s' 'curl -sS -o /dev/null -w "%{http_code}" -k --proxy-cacert /run/secrets/mediator-ca.crt --proxy-cert /run/secrets/claude-client.crt --proxy-key /run/secrets/claude-client.key --max-time 25 https://allowed.fixture.lab/ 2>&1' ;;
    codex)  printf '%s' 'curl -sS -o /dev/null -w "%{http_code}" -k --proxy-user "$(cat /run/secrets/codex-proxy-credential)" --max-time 25 https://allowed.fixture.lab/ 2>&1' ;;
    agy)    printf '%s' 'curl -sS -o /dev/null -w "%{http_code}" -k --proxy-cacert /run/secrets/mediator-ca.crt --proxy-user "$(cat /run/secrets/agy-proxy-credential)" --max-time 25 https://allowed.fixture.lab/ 2>&1' ;;
  esac
}

# One attempt. The output is curl's own, so a refusal is as readable as a success.
fx_attempt() { fx_in "$1" "$(fx_probe_script "$1")"; }

# An attempt that is EXPECTED to succeed, retried. Two measured reasons, neither of them the
# property under test:
#   * the cascade peer is cold on the first request through an authenticating listener and is
#     answered 500 (`images/mediator/entrypoint.sh`, and `retry_cold_peer` in
#     verify-egress-mediator.sh -- this is the same retry, in this harness's idiom);
#   * `tests/fixtures/tls-server.sh` runs `openssl s_server -naccept 1` in a loop, so it serves
#     ONE connection and takes ~0.2s to come back. Two probes in quick succession put the second
#     in that window and it fails at the origin handshake, not at the mediator. Measured while
#     building this phase: three back-to-back probes gave 200, then two SSL_ERROR_SYSCALLs.
fx_allow() { # <agent> -- prints the last attempt's output
  local a="$1" out attempt=1
  while :; do
    out="$(fx_attempt "$a")"
    case "$out" in *200*) break ;; esac
    [ "$attempt" -lt 4 ] || break
    attempt=$((attempt + 1))
    sleep 2
  done
  printf '%s' "$out"
}

# Does the trail carry an attempt for this (agent, destination) at or after the given timestamp?
# Asserted on PRESENCE, not on a verdict value: during the pod-wide cut the policy decision is
# still `allow` and the attempt fails downstream of it (phase C measures exactly that), so a
# verdict-keyed assertion would be asserting the wrong thing.
fx_attempt_logged() { # <agent> <since-ts>
  [ -n "$(fx_audit | jq -c --arg a "$1" --arg s "$2" \
      'select(.agent == $a and .dest_host == "allowed.fixture.lab" and .ts >= $s)' | tail -1)" ]
}

fx_up_stack() { # bring the whole fixture stack up and wait for the mediator
  fx up -d >"${TMPDIR:-/tmp}/containment-fx-up.$$.log" 2>&1 || {
    fail "the fixture stack failed to come up"
    tail -20 "${TMPDIR:-/tmp}/containment-fx-up.$$.log" | sed 's/^/      /'
    return 1
  }
  local waited=0
  while ! fx_med true >/dev/null 2>&1; do
    waited=$((waited + 1))
    [ "$waited" -lt 60 ] || { fail "the fixture mediator never became reachable"; return 1; }
    sleep 1
  done
  return 0
}

echo "--- bringing up the fixture stack ---"
fx_up_stack || { echo; echo "=== verify-containment: $PASSED passed, $FAILED failed"; exit 1; }

FX_ALL_RUNNING=1
for a in "${AGENTS[@]}" egress-mediator; do
  [ "$(fx_state "$a")" = running ] || { FX_ALL_RUNNING=0; note "$a is $(fx_state "$a"), not running"; }
done
for a in "${AGENTS[@]}"; do
  [ "$(fx_state "${a}-recorder")" = running ] || { FX_ALL_RUNNING=0; note "${a}-recorder is not running"; }
done
[ "$FX_ALL_RUNNING" = 1 ] \
  && pass "the fixture stack is up: three agents, three recorders and the mediator all running" \
  || { fail "the fixture stack did not come up complete"; echo; echo "=== verify-containment: $PASSED passed, $FAILED failed"; exit 1; }

# A baseline allowed request per agent. Without it, a later "the other two are unaffected"
# assertion could pass against an agent that never worked in the first place.
for a in "${AGENTS[@]}"; do
  out="$(fx_allow "$a")"
  case "$out" in
    *200*) pass "baseline: '$a' completes an allowed fixture request through the mediator" ;;
    *)     fail "baseline: '$a' could not complete an allowed fixture request before any containment action"
           note "curl said: ${out:-<nothing>}" ;;
  esac
done

# ---------------------------------------------------------------------------
# Phase B -- T40: single-agent isolation, both forms, for each agent
# ---------------------------------------------------------------------------
phase B "T40 -- single-agent isolation (stop form and disconnect form, per agent)"

others_unaffected() { # <isolated agent> <label>
  local x="$1" label="$2" a out since
  for a in "${AGENTS[@]}"; do
    [ "$a" = "$x" ] && continue
    [ "$(fx_state "$a")" = running ] \
      && pass "B/$label($x): '$a' is still running" \
      || fail "B/$label($x): '$a' is not running"
    since="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
    out="$(fx_allow "$a")"
    case "$out" in
      *200*) pass "B/$label($x): '$a' still completes an allowed fixture request" ;;
      *)     fail "B/$label($x): '$a' could not complete an allowed fixture request"
             note "curl said: ${out:-<nothing>}" ;;
    esac
    if fx_attempt_logged "$a" "$since"; then
      pass "B/$label($x): '$a' produced a fresh egress line on the audit trail"
    else
      fail "B/$label($x): '$a' produced no fresh egress line"
    fi
  done
}

for X in "${AGENTS[@]}"; do
  # --- the stop form. The ORDER is the assertion (Edge Case 9): the agent first, then its
  # recorder once that recorder has had a chance to drain. Stopping the recorder first loses
  # the tail of the transcript.
  fx stop "$X" >/dev/null 2>&1 || true
  [ "$(fx_state "$X")" = exited ] \
    && pass "B/stop($X): the agent is exited" \
    || fail "B/stop($X): the agent did not stop (state: $(fx_state "$X"))"
  sleep 3   # the recorder's poll interval, so its last read lands before it is stopped
  fx stop "${X}-recorder" >/dev/null 2>&1 || true
  [ "$(fx_state "${X}-recorder")" = exited ] \
    && pass "B/stop($X): its recorder is exited, stopped after the agent it records" \
    || fail "B/stop($X): its recorder did not stop (state: $(fx_state "${X}-recorder"))"

  others_unaffected "$X" stop

  fx start "$X" "${X}-recorder" >/dev/null 2>&1 || true
  sleep 3
  if [ "$(fx_state "$X")" = running ] && [ "$(fx_state "${X}-recorder")" = running ]; then
    pass "B/stop($X): the agent and its recorder restart cleanly"
  else
    fail "B/stop($X): the agent or its recorder did not restart (agent: $(fx_state "$X"), recorder: $(fx_state "${X}-recorder"))"
  fi
  out="$(fx_allow "$X")"
  case "$out" in
    *200*) pass "B/stop($X): the restarted agent reaches the mediator again" ;;
    *)     fail "B/stop($X): the restarted agent cannot reach the mediator"; note "curl said: ${out:-<nothing>}" ;;
  esac

  # --- the disconnect form. The container is KEPT for forensics: still running, filesystem
  # and process state intact, and no route to anything because it is on that one network only.
  docker network disconnect "${PROJECT_FX}_${X}-net" "${PROJECT_FX}-${X}-1" >/dev/null 2>&1 \
    && pass "B/disconnect($X): detached from ${X}-net" \
    || fail "B/disconnect($X): docker network disconnect failed"

  [ "$(fx_state "$X")" = running ] \
    && pass "B/disconnect($X): the container is kept for forensics -- still running" \
    || fail "B/disconnect($X): the container is not running after the detach"

  out="$(fx_attempt "$X")"
  case "$out" in
    *200*) fail "B/disconnect($X): the detached agent still reached the mediator"; note "curl said: $out" ;;
    *)     pass "B/disconnect($X): the detached agent has no route to the mediator"
           note "curl said: $(printf '%s' "$out" | head -1)" ;;
  esac

  # The mediator reads MEDIATOR_AGENT_NETWORKS at start only, so detaching an AGENT should
  # leave it untouched. Measured, not assumed (criterion 2).
  [ "$(fx_state egress-mediator)" = running ] \
    && pass "B/disconnect($X): the mediator keeps serving -- an agent-side detach does not touch it" \
    || fail "B/disconnect($X): the mediator is no longer running after an agent-side detach"

  others_unaffected "$X" disconnect

  docker network connect "${PROJECT_FX}_${X}-net" "${PROJECT_FX}-${X}-1" >/dev/null 2>&1 || true
  sleep 2
  out="$(fx_allow "$X")"
  case "$out" in
    *200*) pass "B/disconnect($X): reconnecting restores the agent" ;;
    *)     fail "B/disconnect($X): the agent did not recover after reconnect"; note "curl said: ${out:-<nothing>}" ;;
  esac
done

# ---------------------------------------------------------------------------
# Phase C -- the pod-wide cut, with recording still running
# ---------------------------------------------------------------------------
phase C "the pod-wide cut -- every agent fails, every attempt is still audited"

docker network disconnect "${PROJECT_FX}_egress-net" "${PROJECT_FX}-egress-mediator-1" >/dev/null 2>&1 \
  && pass "C: the mediator is detached from egress-net" \
  || fail "C: docker network disconnect of the mediator from egress-net failed"

# The whole point of choosing this form over `stop egress-mediator` (Decision 3): the mediator
# is still running, so DNS still decides and the audit writer still writes.
[ "$(fx_state egress-mediator)" = running ] \
  && pass "C: the mediator is still running with its egress leg cut -- the detection signal is alive" \
  || fail "C: the mediator did not survive being detached from egress-net"

sleep 2
for a in "${AGENTS[@]}"; do
  C_SINCE="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  out="$(fx_attempt "$a")"
  case "$out" in
    *200*) fail "C: '$a' still completed an allowed request with the pod-wide cut in place"
           note "curl said: $out" ;;
    *)     pass "C: '$a''s allowed request fails with the pod-wide cut in place"
           note "curl said: $(printf '%s' "$out" | head -1)" ;;
  esac
  if fx_attempt_logged "$a" "$C_SINCE"; then
    pass "C: the attempt from '$a' still reached the audit sink during the cut"
  else
    fail "C: the attempt from '$a' left no line on the audit trail during the cut"
    note "Decision 3 and Edge Case 8: a blocked attempt IS the detection signal (R9.1)."
  fi
done

docker network connect "${PROJECT_FX}_egress-net" "${PROJECT_FX}-egress-mediator-1" >/dev/null 2>&1 || true
sleep 3
for a in "${AGENTS[@]}"; do
  out="$(fx_allow "$a")"
  case "$out" in
    *200*) pass "C: '$a' is allowed again once the mediator is reattached" ;;
    *)     fail "C: '$a' did not recover after the mediator was reattached"
           note "curl said: ${out:-<nothing>}" ;;
  esac
done

# ---------------------------------------------------------------------------
# Phase D -- R12.5: what a `down` without `-v` keeps
# ---------------------------------------------------------------------------
phase D "R12.5 -- 'down' without '-v' removes containers, tmpfs and networks and keeps volumes"

D_TMP_MARKER=/tmp/r12-5-tmp-marker
D_STATE_MARKER=/home/agent/.r12-5-state-marker

for a in "${AGENTS[@]}"; do
  fx_in "$a" "printf 'r12.5\n' > $D_TMP_MARKER && printf 'r12.5\n' > $D_STATE_MARKER" >/dev/null
  if [ "$(fx_in "$a" "[ -f $D_TMP_MARKER ] && [ -f $D_STATE_MARKER ] && echo both")" = both ]; then
    pass "D: markers placed in '$a''s /tmp (tmpfs) and /home/agent (state volume)"
  else
    fail "D: could not place both markers in '$a'"
  fi
done

D_AUDIT_BEFORE="$(fx_audit_lines)"
D_VOLUMES_BEFORE="$(docker volume ls --format '{{.Name}}' | grep "^${PROJECT_FX}_" | sort)"
note "D: audit trail holds ${D_AUDIT_BEFORE:-0} lines, and the project declares $(printf '%s\n' "$D_VOLUMES_BEFORE" | wc -l | tr -d ' ') named volumes"

# WITHOUT `-v`. That is the assertion, and it is the runbook's first rule (§ 2).
fx down --remove-orphans >/dev/null 2>&1 || fail "D: 'docker compose down' failed"

D_CONTAINERS="$(docker ps -a --format '{{.Names}}' | grep -c "^${PROJECT_FX}-" || true)"
[ "$D_CONTAINERS" = 0 ] \
  && pass "D: 'down' removed every container" \
  || fail "D: $D_CONTAINERS container(s) survived 'down'"

D_NETWORKS="$(docker network ls --format '{{.Name}}' | grep -c "^${PROJECT_FX}_" || true)"
[ "$D_NETWORKS" = 0 ] \
  && pass "D: 'down' removed every network" \
  || fail "D: $D_NETWORKS network(s) survived 'down'"

D_VOLUMES_AFTER="$(docker volume ls --format '{{.Name}}' | grep "^${PROJECT_FX}_" | sort)"
if [ -n "$D_VOLUMES_BEFORE" ] && [ "$D_VOLUMES_BEFORE" = "$D_VOLUMES_AFTER" ]; then
  pass "D: every named volume survived 'down', the audit volume included"
else
  fail "D: the named volume set changed across 'down'"
  note "before: $(printf '%s' "$D_VOLUMES_BEFORE" | tr '\n' ' ')"
  note "after:  $(printf '%s' "$D_VOLUMES_AFTER" | tr '\n' ' ')"
fi

fx_up_stack || fail "D: the stack did not come back up after 'down'"

for a in "${AGENTS[@]}"; do
  if [ "$(fx_in "$a" "[ -f $D_TMP_MARKER ] && echo present || echo absent")" = absent ]; then
    pass "D: '$a''s /tmp marker is gone -- the tmpfs did not survive"
  else
    fail "D: '$a''s /tmp marker survived 'down'; /tmp is not a tmpfs"
  fi
  if [ "$(fx_in "$a" "[ -f $D_STATE_MARKER ] && echo present || echo absent")" = present ]; then
    pass "D: '$a''s state-volume marker is still there -- the volume was preserved"
  else
    fail "D: '$a''s state-volume marker is gone; 'down' without '-v' destroyed state"
  fi
done

D_AUDIT_AFTER="$(fx_audit_lines)"
if [ -n "$D_AUDIT_AFTER" ] && [ "$D_AUDIT_AFTER" -ge "${D_AUDIT_BEFORE:-0}" ]; then
  pass "D: the audit line count did not decrease across 'down' (${D_AUDIT_BEFORE} -> ${D_AUDIT_AFTER})"
else
  fail "D: the audit trail lost lines across 'down' (${D_AUDIT_BEFORE} -> ${D_AUDIT_AFTER:-unreadable})"
fi

# ---------------------------------------------------------------------------
# Hand the subnets over to phase F
# ---------------------------------------------------------------------------
# Both topologies claim 172.31.{10,20,30}.0/24, so the fixture stack cannot still be up when
# phase F's `default` stack comes up. WITHOUT `-v`: the volumes go in the trap, under the
# teardown contract at the top of this file, not here.
echo
echo "--- releasing the fixture stack's subnets for phase F (down, no -v) ---"
fx down --remove-orphans >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Phase F -- T37: the authorization gate
# ---------------------------------------------------------------------------
phase F "T37 -- the authorization gate (compile negatives, then the runtime half)"

# expect <want-exit> <message fragment> <label> -- <command...>
# The exit code AND the message. A gate that fires for the wrong reason is a gate that will stop
# firing when that reason is fixed, so every negative names the token the operator has to read.
expect() {
  local want="$1" frag="$2" label="$3"; shift 3
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: expected exit $want, got $rc"
    printf '%s\n' "$out" | grep -v '^compile-policy: NOTE' | head -4 | sed 's/^/      /'
    return
  fi
  if [ -n "$frag" ] && ! printf '%s' "$out" | grep -qF -- "$frag"; then
    fail "$label: exit $want as expected, but the message did not name '$frag'"
    printf '%s\n' "$out" | grep -v '^compile-policy: NOTE' | head -4 | sed 's/^/      /'
    return
  fi
  pass "$label"
}

# A probe profile is a one-key mutation of a SHIPPED profile, generated here and compiled
# through --profile-file so nothing is written to profiles/ or policy/resolved/. See
# tests/fixtures/authorization/README.md for why these are not committed.
make_probe() { # <name> <source profile> <yq expression>
  yq eval "$3" "profiles/$2.yaml" > "$FIXTURES/probe-$1.yaml"
}
compile_probe() { # <name>
  bash scripts/compile-policy.sh --profile "authz-probe-$1" \
    --profile-file "$FIXTURES/probe-$1.yaml" --out "$(mktemp)"
}

# --- every shipped profile still compiles (the positive direction) -------------------------
for p in profiles/*.yaml; do
  base="$(basename "$p" .yaml)"
  expect 0 "" "F: shipped profile '$base' compiles under the T37 gate" \
    bash scripts/compile-policy.sh --profile "$base" --out "$(mktemp)"
done

# --- Interface Contract 2, row by row ------------------------------------------------------

# Row 1 -- the whole-profile waiver stands alone.
make_probe waiver-and-classify default '.authorization.waiver = "a reason"'
expect 2 "The whole-profile waiver stands alone" \
  "F: row 1 -- 'waiver' together with 'classify' is refused" \
  compile_probe waiver-and-classify

make_probe waiver-and-waive test-fixtures '.authorization.waive."git-push" = "a reason"'
expect 2 "The whole-profile waiver stands alone" \
  "F: row 1 -- 'waiver' together with 'waive' is refused" \
  compile_probe waiver-and-waive

# Row 2 -- an action no committed manifest declares.
make_probe unknown-action default '.authorization.classify += ["git-pusk"]'
expect 2 "no committed pack declares it" \
  "F: row 2 -- a classified action outside the vocabulary is refused, and the message says why" \
  compile_probe unknown-action

make_probe unknown-waive default '.authorization.waive."git-pusk" = "a reason"'
expect 2 "no committed pack declares it" \
  "F: row 2 -- a WAIVED action outside the vocabulary is refused too" \
  compile_probe unknown-waive

# Row 3 -- the same action classified and waived.
make_probe both default '.authorization.waive."git-push" = "a reason"'
expect 2 "both 'classify' and 'waive'" \
  "F: row 3 -- an action in both classify and waive is refused" \
  compile_probe both

# Row 4 -- a known action accounted for nowhere.
make_probe unaccounted default 'del(.authorization.classify[] | select(. == "infrastructure-apply"))'
expect 2 "neither classifies nor waives it" \
  "F: row 4 -- a known action in neither classify nor waive is refused" \
  compile_probe unaccounted
if grep -qF "packs/kubernetes/pack.yaml" <<< "$(compile_probe unaccounted 2>&1 || true)"; then
  pass "F: row 4 -- the message names the manifest that declares the action"
else
  fail "F: row 4 -- the message does not name packs/kubernetes/pack.yaml"
fi

# Row 5 -- a waiver with no reason, and a `waive` that is not a map.
make_probe empty-waive-reason github '.authorization.waive."git-push" = ""'
expect 2 "has no recorded reason" \
  "F: row 5 -- an empty waive reason is refused" \
  compile_probe empty-waive-reason

make_probe waive-not-map github '.authorization.waive = ["git-push"]'
expect 2 "must be a mapping of action -> recorded reason" \
  "F: row 5 -- a 'waive' list is refused; a waiver without a reason is not a waiver" \
  compile_probe waive-not-map

# Row 6 -- THE REFUSAL (exit 3). `github` loads packs/github-cli, which enables git-push.
# This is the negative control the Test Strategy names: move the action back to classify.
make_probe refusal github \
  'del(.authorization.waive."git-push") | .authorization.classify += ["git-push"]'
expect 3 "packs/github-cli/pack.yaml" \
  "F: row 6 -- classifying an action a LOADED pack enables is a refusal (exit 3)" \
  compile_probe refusal
REFUSAL_OUT="$(compile_probe refusal 2>&1 || true)"
if grep -qF "remove the pack" <<< "$REFUSAL_OUT" && grep -qF "'waive' with a recorded reason" <<< "$REFUSAL_OUT"; then
  pass "F: row 6 -- the refusal names both remedies"
else
  fail "F: row 6 -- the refusal does not name both remedies"
  printf '%s\n' "$REFUSAL_OUT" | grep -v '^compile-policy: NOTE' | head -3 | sed 's/^/      /'
fi

# A classified action enabled by a pack the profile does NOT load is allowed to stand: the
# classification is a statement about the profile, not about its pack list (Decision 1).
if bash scripts/compile-policy.sh --profile kubernetes --out "$(mktemp)" >/dev/null 2>&1; then
  pass "F: 'kubernetes' classifies git-push while loading no pack that enables it -- allowed"
else
  fail "F: 'kubernetes' should compile: it classifies an action none of its packs enables"
fi

# --- Interface Contract 3: MCP entries -----------------------------------------------------
MCP_SERVER_BASE='{
  "name": "authz-probe-srv", "agents": ["claude"], "version": "1.0.0",
  "artifact": "n/a: fixture",
  "transport": "stdio", "enforcement_point": "none",
  "egress": {"allow_fqdns": [], "allow_cidrs": []},
  "mounts": [], "env": [], "credentials": [],
  "needs_write_access": false, "risk_tier": "irreversible",
  "capability_baseline": {"config_sha256": "'"$(printf 'authz-probe' | shasum -a 256 | cut -d' ' -f1)"'", "tools": []}
}'

# R7.16: a non-empty mcp.servers needs a pinned registry, so every probe below sets one.
MCP_REG='.mcp.registry = {"type": "npm-tarball", "url": "https://example.test", "pinned": "1"}'

make_probe mcp-irreversible default ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG"
expect 2 "declares no enables_actions" \
  "F: Contract 3 -- an 'irreversible' server with no enables_actions is refused" \
  compile_probe mcp-irreversible

make_probe mcp-unaccounted default \
  ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG | .mcp.servers[0].enables_actions = [\"cluster-drain\"]"
expect 2 "neither classifies nor waives it" \
  "F: Contract 3 -- a server's action joins the vocabulary and must be accounted for" \
  compile_probe mcp-unaccounted

make_probe mcp-refusal default \
  ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG | .mcp.servers[0].enables_actions = [\"git-push\"]"
expect 3 "authz-probe-srv" \
  "F: Contract 3 -- classifying an action an INVENTORIED server enables is a refusal (exit 3)" \
  compile_probe mcp-refusal

make_probe mcp-bad-action default \
  ".mcp.servers = [$MCP_SERVER_BASE] | $MCP_REG | .mcp.servers[0].enables_actions = [\"Git-Push\"]"
expect 2 "is not a valid action name" \
  "F: Contract 3 -- a malformed action name on a server is refused" \
  compile_probe mcp-bad-action

# --- Interface Contract 1: pack manifests, INCLUDING ones no profile selects ----------------
# The vocabulary is the union over every committed manifest, so a malformed manifest nothing
# loads must still fail the compile rather than contribute a name silently.
mkdir -p "$PROBE_PACK_DIR"
probe_pack() { # <fixture suffix>
  cp "$FIXTURES/pack-$1.yaml" "$PROBE_PACK_DIR/pack.yaml"
}

probe_pack bad-name
expect 2 "is not a valid action name" \
  "F: Contract 1 -- a malformed action name in an UNSELECTED manifest fails the compile" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

probe_pack duplicate
expect 2 "more than once" \
  "F: Contract 1 -- a duplicated action in a manifest is refused" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

probe_pack not-list
expect 2 "must be a list of action names" \
  "F: Contract 1 -- a scalar enables_actions is refused" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

rm -rf "$PROBE_PACK_DIR"
expect 0 "" "F: the tree compiles again once the probe manifest is removed" \
  bash scripts/compile-policy.sh --profile default --out "$(mktemp)"

# --- R7.8: enables_actions is a KNOWN key, and the unknown-key gate still refuses others ----
if grep -qF 'enables_actions' <<< "$(grep '^KNOWN_PACK_KEYS=' scripts/compile-policy.sh)"; then
  pass "F: 'enables_actions' is in the compiler's known-pack-key set (R7.8)"
else
  fail "F: 'enables_actions' is not in KNOWN_PACK_KEYS; a manifest declaring it would be refused"
fi

# --- the runtime half: capability absence under `default` -----------------------------------
# Decision 1's claim is that a classified action is structurally unavailable, not merely written
# down. Under `default` that means: no GitHub credential and no `gh`, no kubeconfig and no
# `kubectl`/`helm`, in any agent -- and github.com refused at the mediator for the two agents
# whose base allowlist does not carry it.
phase F "T37 runtime -- capability absence and the refused CONNECT (profile 'default')"

# The generated probe profiles go BEFORE the build, not at EXIT: the solution root is the image
# build context, so leaving them in place churns the context hash for no reason.
rm -f "$FIXTURES"/probe-*.yaml


AGENT_PROFILE=default "${COMPOSE[@]}" build egress-mediator claude codex agy \
  >"${TMPDIR:-/tmp}/containment-build.$$.log" 2>&1 || {
  fail "F: image build failed under profile 'default'"
  tail -20 "${TMPDIR:-/tmp}/containment-build.$$.log" | sed 's/^/      /'
}
STACK_UP=1
AGENT_PROFILE=default "${COMPOSE[@]}" up -d --force-recreate egress-mediator \
  >"${TMPDIR:-/tmp}/containment-up.$$.log" 2>&1 || {
  fail "F: the mediator failed to start under profile 'default'"
  tail -20 "${TMPDIR:-/tmp}/containment-up.$$.log" | sed 's/^/      /'
}

in_agent() { # <agent> <sh -c script>
  AGENT_PROFILE=default "${COMPOSE[@]}" run --rm --no-deps "$1" sh -c "$2" 2>/dev/null || true
}

for a in claude codex agy; do
  ABSENT=1
  for probe in 'printf "%s" "${GH_TOKEN:-}${GITHUB_TOKEN:-}"' \
               'printf "%s" "${KUBECONFIG:-}"' \
               'command -v gh || true' \
               'command -v kubectl || true' \
               'command -v helm || true' \
               'cat "$HOME/.git-credentials" 2>/dev/null || true'; do
    OUT="$(in_agent "$a" "$probe")"
    if [ -n "${OUT//[[:space:]]/}" ]; then
      ABSENT=0
      note "$a: '$probe' produced: $OUT"
    fi
  done
  [ "$ABSENT" = 1 ] \
    && pass "F: '$a' under 'default' carries no push or apply capability (no token, no kubeconfig, no gh/kubectl/helm)" \
    || fail "F: '$a' under 'default' carries a capability a classified action needs"
done

# The CONNECT. `codex`'s base allowlist carries github.com for the reasons recorded at 01.1
# (Edge Case 16), so it is deliberately NOT asserted as refused -- its only barrier is the
# absent credential, which the block above measured.
med_audit() { docker exec "${PROJECT}-egress-mediator-1" cat /var/log/mediator/egress-audit.log 2>/dev/null; }

connect_probe='
ca=/run/secrets/mediator-ca.crt
args="--proxy-cacert $ca"
if [ -r /run/secrets/claude-client.crt ]; then
  args="$args --proxy-cert /run/secrets/claude-client.crt --proxy-key /run/secrets/claude-client.key"
fi
curl -sS -o /dev/null $args --max-time 20 https://github.com/ 2>&1 || true
'

for a in claude agy; do
  OUT="$(in_agent "$a" "$connect_probe")"
  case "$OUT" in
    *"response 403"*|*"code 403 from proxy"*)
      pass "F: '$a' is refused CONNECT github.com by the mediator under 'default'" ;;
    *)
      fail "F: '$a' was not refused CONNECT github.com under 'default'"
      note "curl said: ${OUT:-<nothing>}" ;;
  esac
  LINE="$(med_audit | jq -c --arg a "$a" \
    'select(.verdict == "deny" and .dest_host == "github.com" and .agent == $a)' | tail -1)"
  if [ -z "$LINE" ]; then
    fail "F: no deny line for ($a, github.com) on the audit trail"
  elif printf '%s' "$LINE" | jq -e '.agent != null and .identity_source != null and .ts != null' >/dev/null; then
    pass "F: the ($a, github.com) deny line carries agent and identity_source ($(printf '%s' "$LINE" | jq -r '.identity_source'))"
  else
    fail "F: the ($a, github.com) deny line is missing agent or identity_source"
    note "$LINE"
  fi
done

# ---------------------------------------------------------------------------
echo
echo "=== verify-containment: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] || exit 1
