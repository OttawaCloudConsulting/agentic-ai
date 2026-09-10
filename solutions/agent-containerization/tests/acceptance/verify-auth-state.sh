#!/usr/bin/env bash
# Acceptance test for Feature 01.4 (Agent authentication and state persistence).
# Phases A-E; see the feature plan's Test Strategy for what each phase maps to.
#
# Requires: docker, docker compose, jq. Invoked as `bash tests/acceptance/verify-auth-state.sh`.
#
# WHAT THIS HARNESS IS AND IS NOT. Unlike 01.3's harness, which reaches only fixtures it owns,
# this one iterates LIVE PROVIDER CREDENTIALS -- the operator's real Anthropic and ChatGPT
# accounts, by decision at Gate 4 (2026-09-07), superseding the plan's original
# "throwaway credentials only". Two consequences are structural rather than advisory:
#
#   * IT NEVER PRINTS CREDENTIAL MATERIAL. Every assertion is on presence, shape or exit
#     status. Diagnostics name a variable or a path, never a value. A SHA-256 prefix is used
#     where a before/after comparison is needed, exactly as 01.4 SF-3's record did.
#   * PHASE D COSTS THE OPERATOR THEIR HOST CODEX LOGIN. Forcing the refresh T25 requires
#     rolls codex's refresh token (SF-3, measured), superseding whatever copy the seed came
#     from. The phase says so before it runs.
#
# NOT COVERED HERE, BY DESIGN -- so a reader does not mistake a scope boundary for a gap:
#
#   T27  the policy compiler's build-time refusal of an oauth_mount block with no
#        accepted_risk record .......................................... Feature 01.5
#   T26  measured detection-to-revocation time for a leaked credential .. Feature 02.5
#        (the INVENTORY half of T26 is 01.4's and lands in
#        docs/records/credential-inventory.md, not in a test)
#   T21  default-off mount enumeration ................................. Feature 01.2
#        (unaffected: 01.4 adds nothing to the default profile)
#   adversarial acceptance of any of the above ........................ Feature 02.2
#
# TWO CONVENTIONS DIFFER FROM THE PLAN'S TEST STRATEGY, both recorded as deviations on the
# feature plan:
#
#   * `set -uo pipefail`, not `-euo`. This harness must report every phase's failures rather
#     than abort at the first, which is 01.3's precedent for a multi-phase harness
#     (verify-egress-mediator.sh) rather than 01.2's for a single-pass one.
#   * Phase D runs LAST, after E. D forces a refresh and then deletes the volume credential;
#     running it before E would leave E asserting persistence of a credential D had just
#     destroyed.
#
# It runs under its OWN Compose project name and tears down with `down -v`, so the operator's
# containers and audit volume are never touched. Its state volumes are SEEDED from the
# operator's (see SEED_* below) because four of the seven supported cells need a real OAuth
# credential and no test can mint one unattended.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

PROJECT="sf5-auth-$$"
AGENTS=(claude codex agy)
FAILED=0
PHASE=""

# Where the OAuth credentials come from. These are the volumes 01.4 SF-3 left holding the
# CURRENT refresh token for each provider (see milestone-status.txt, "VOLUME HAZARD" -- the
# sf2bd_* and sf3-*-pristine volumes hold SUPERSEDED tokens and must not be used).
SEED_CLAUDE_VOLUME="${SEED_CLAUDE_VOLUME:-sf3_claude-state}"
SEED_CODEX_VOLUME="${SEED_CODEX_VOLUME:-sf3_codex-state}"

# Phase E's live half: one real model invocation per agent, which costs provider quota and can
# itself trigger a refresh. Off by default -- the credential-shape and marker-file assertions
# are what T9 actually needs, and the live path was exercised at SF-2b and again in phase D.
AUTH_LIVE_RUN="${AUTH_LIVE_RUN:-0}"

SEED_IMAGE=sandboxed-agent/codex:local
BOOTSTRAP=/usr/local/bin/bootstrap-auth

COMPOSE_BASE=(docker compose --env-file compose/pins.env -f compose/compose.yaml)
COMPOSE=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml -p "$PROJECT")
COMPOSE_GIT=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml
             -f compose/overrides/host-gitconfig.yaml -p "$PROJECT")
COMPOSE_OAUTH=("${COMPOSE_BASE[@]}" -f compose/overrides/default.yaml
               -f compose/overrides/oauth-mount.bootstrap.yaml -p "$PROJECT")

pass() { echo "PASS: [$PHASE] $1"; }
fail() { echo "FAIL: [$PHASE] $1"; FAILED=1; }
note() { echo "      $*"; }
phase() { PHASE="$1"; echo; echo "=== Phase $1 ================================================"; }

# Scratch that must not survive the run, and the operator artifacts this harness overwrites.
# compose/generated/ is the scrub's and the staging script's output directory; an operator who
# has staged their own credential there gets it back.
SCRATCH="$(mktemp -d)"
GEN_BACKUP="$SCRATCH/generated-backup"

cleanup() {
  echo
  echo "--- tearing down $PROJECT ---"
  "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  docker rm -f "${PROJECT}-seed" >/dev/null 2>&1 || true
  if [ -d "$GEN_BACKUP" ]; then
    rm -rf compose/generated/gitconfig.d compose/generated/oauth-src
    [ -d "$GEN_BACKUP/gitconfig.d" ] && cp -a "$GEN_BACKUP/gitconfig.d" compose/generated/
    [ -d "$GEN_BACKUP/oauth-src" ]   && cp -a "$GEN_BACKUP/oauth-src"   compose/generated/
    echo "      restored compose/generated/ from the pre-run backup"
  fi
  rm -rf "$SCRATCH"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Run one command in a throwaway agent container. Prints combined output; the caller reads $?.
# `run --rm` runs the ENTRYPOINT first, so every invocation here also exercises the start-time
# bootstrap-auth pass -- which is why an unsupported AUTH_MODE fails these calls at start.
agent_run() { # <base|git|oauth> <agent> <env-assignments...> -- <command...>
  local variant="$1"; shift
  local agent="$1"; shift
  local cmp=()
  case "$variant" in
    base)  cmp=("${COMPOSE[@]}") ;;
    git)   cmp=("${COMPOSE_GIT[@]}") ;;
    oauth) cmp=("${COMPOSE_OAUTH[@]}") ;;
  esac
  local envs=()
  while [ "$1" != "--" ]; do envs+=(-e "$1"); shift; done
  shift
  "${cmp[@]}" run --rm --no-deps "${envs[@]}" "$agent" "$@" 2>&1
}

# The value of ONE expression read from inside a container, isolated from the entrypoint's own
# output. `run --rm` runs the entrypoint first and bootstrap-auth reports its state on STDOUT
# ("already authenticated -- no-op"), so a bare capture returns that line CONCATENATED with the
# value being read. Found by running: the first pass of this harness reported
# GIT_CONFIG_GLOBAL as bootstrap-auth's status line. Every read is therefore delimited.
extract() { # <output-of-agent_run>
  echo "$1" | sed -n 's/.*<<<\(.*\)>>>.*/\1/p' | tail -1
}
DELIM_PRINT='printf "<<<%s>>>"'

# SHA-256 of a file's contents, 16-hex prefix. The comparison unit SF-3's record used, and the
# only thing this harness ever derives from credential material.
sha16() { shasum -a 256 "$1" 2>/dev/null | cut -c1-16; }

# SHA-256 prefix of one JSON field, computed INSIDE a throwaway container so the value never
# reaches this script. Used only for before/after comparison, exactly as SF-3's record did.
# Writes nothing but 16 hex characters; exits 9 if the file or the field is absent.
cat > "$SCRATCH/field-sha.js" <<'JS'
const fs = require('fs'), crypto = require('crypto');
const [file, path] = process.argv.slice(2);
let j; try { j = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { process.exit(9); }
const v = path.split('.').reduce((o, k) => (o == null ? o : o[k]), j);
if (typeof v !== 'string' || !v.length) process.exit(9);
process.stdout.write(crypto.createHash('sha256').update(v).digest('hex').slice(0, 16));
JS

field_sha() { # <volume> <file-path-in-volume-rooted-at-/state> <dotted.field.path>
  docker run --rm -v "$1:/state:ro" -v "$SCRATCH/field-sha.js:/tmp/field-sha.js:ro" \
    --entrypoint node "$SEED_IMAGE" /tmp/field-sha.js "/state/$2" "$3" 2>/dev/null
}

# Presence-and-shape test on a credential inside a state volume, with no value leaving it.
volume_has() { # <volume> <test-expression-for-sh>
  docker run --rm -v "$1:/state:ro" --entrypoint sh "$SEED_IMAGE" -c "$2" >/dev/null 2>&1
}

# The mount set of a container, as `docker inspect` sees it. Criterion 4's assertion is
# EQUALITY, not containment -- an extra mount is exactly what it exists to catch.
mount_set() { docker inspect "$1" | jq -r '[.[0].Mounts[] | .Destination] | sort | join(",")'; }

expected_mounts() { # <agent> [extra destinations...]
  local agent="$1"; shift
  local list
  # 01.6 SF-2 split `claude` off from `agy`. `claude`'s listener declares `client_auth: mtls`,
  # so it alone mounts a client key pair as a Compose secret (Interface Contract 5); `agy`
  # keeps the CA it anchors its proxy hop with and presents nothing; `codex` keeps neither.
  # The same asymmetry verify-pod-topology.sh carries, and it lives in both files because
  # each harness asserts EQUALITY against its own containers rather than sharing a constant.
  case "$agent" in
    claude) list="/home/agent /run/secrets/claude-client.crt /run/secrets/claude-client.key /run/secrets/mediator-ca.crt /workspace" ;;
    agy)    list="/home/agent /run/secrets/mediator-ca.crt /workspace" ;;
    codex)  list="/home/agent /workspace" ;;
  esac
  # Word splitting is how the list becomes one path per line.
  # shellcheck disable=SC2086
  printf '%s\n' $list "$@" | sort | paste -sd, -
}

# ---------------------------------------------------------------------------
# Preconditions -- every one of these is a hard exit, not a FAIL. A missing
# precondition makes every later assertion meaningless rather than failed.
# ---------------------------------------------------------------------------

phase "0 (preconditions)"

for tool in docker jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FAIL: $tool is required"; exit 1; }
done

# The static agent subnets are the reason only ONE Compose project can be up at a time: each
# listener certificate carries an iPAddress SAN for a fixed address, so a second project fails
# at network creation with "Pool overlaps with other one on this address space". SF-3 hit this
# and recorded it. Detected here, with the fix named, rather than surfacing as a Docker error.
conflicting="$(docker network ls --format '{{.Name}}' | grep -E '_(claude|codex|agy)-net$' \
               | grep -v "^${PROJECT}_" || true)"
if [ -n "$conflicting" ]; then
  echo "FAIL: another Compose project holds the agent subnets:"
  printf '      %s\n' $conflicting
  echo "      Bring it down WITHOUT -v (its state volumes must survive), then re-run:"
  echo "        docker compose --env-file compose/pins.env -f compose/compose.yaml \\"
  echo "          -f compose/overrides/default.yaml -p <that-project> down"
  exit 1
fi

for f in mediator/identity/ca/mediator-ca.crt \
         mediator/identity/listeners/claude-listener.crt \
         mediator/identity/listeners/claude-listener.key \
         mediator/identity/listeners/codex-listener.crt \
         mediator/identity/listeners/codex-listener.key \
         mediator/identity/listeners/agy-listener.crt \
         mediator/identity/listeners/agy-listener.key; do
  [ -f "$f" ] || { echo "FAIL: proxy-hop trust material missing: $f"; \
                   echo "      see mediator/identity/README.md"; exit 1; }
done

# The credential environment. references/.env_keys is git-ignored and holds the three API keys
# under short names; CLAUDE_CODE_OAUTH_TOKEN is minted on the HOST with `claude setup-token`
# and is valid for ONE YEAR (R4.16) -- the feature closes by revoking it.
KEYS_FILE=references/.env_keys
[ -f "$KEYS_FILE" ] || { echo "FAIL: $KEYS_FILE is absent; the apikey cells cannot run"; exit 1; }

# The file is PARSED, never sourced, and this is a control rather than a style choice. Sourcing
# an operator-edited credential file executes it: one malformed line -- a missing `=` in a
# pasted token, say -- makes bash treat the whole line as a command and ECHO IT, credential
# included, into the terminal and any log the run is piped to. Observed exactly once, on the
# first run of this harness, which is why the reader below matches a KEY=VALUE line and ignores
# everything that is not one. A malformed line therefore reads as an ABSENT variable, and the
# diagnostic names it without ever holding its value.
read_key() { # <name> -- prints the value, or nothing
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$KEYS_FILE" 2>/dev/null \
    | tail -1 | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//"
}

# Short names in the file, the agents' own variable names in the environment.
read_either() { # <preferred-name> <fallback-name> -- prints the first that is set
  local v
  v="$(read_key "$1")"
  [ -n "$v" ] || v="$(read_key "$2")"
  printf '%s' "$v"
}
ANTHROPIC_API_KEY="$(read_either ANTHROPIC_API_KEY ANTHROPIC)"
OPENAI_API_KEY="$(read_either OPENAI_API_KEY OPENAI)"
GEMINI_API_KEY="$(read_either GEMINI_API_KEY GOOGLE)"
CLAUDE_CODE_OAUTH_TOKEN="$(read_key CLAUDE_CODE_OAUTH_TOKEN)"
export ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY CLAUDE_CODE_OAUTH_TOKEN

missing=()
for v in ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY CLAUDE_CODE_OAUTH_TOKEN; do
  [ -n "${!v}" ] || missing+=("$v")
done
if [ "${#missing[@]}" -ne 0 ]; then
  echo "FAIL: absent from $KEYS_FILE, or present on a line that is not NAME=VALUE:"
  printf '      %s\n' "${missing[@]}"
  echo "      CLAUDE_CODE_OAUTH_TOKEN is minted on the host with: claude setup-token"
  exit 1
fi
pass "credential environment present (4 variables, values never read)"

for v in "$SEED_CLAUDE_VOLUME" "$SEED_CODEX_VOLUME"; do
  docker volume inspect "$v" >/dev/null 2>&1 \
    || { echo "FAIL: seed volume '$v' does not exist."; \
         echo "      Four of the seven supported cells need a real OAuth credential and no test"; \
         echo "      can mint one unattended. Point SEED_CLAUDE_VOLUME / SEED_CODEX_VOLUME at the"; \
         echo "      volumes holding the CURRENT refresh tokens -- never at a superseded copy."; \
         exit 1; }
done
pass "seed volumes present ($SEED_CLAUDE_VOLUME, $SEED_CODEX_VOLUME)"

mkdir -p "$GEN_BACKUP"
[ -d compose/generated/gitconfig.d ] && cp -a compose/generated/gitconfig.d "$GEN_BACKUP/"
[ -d compose/generated/oauth-src ]   && cp -a compose/generated/oauth-src   "$GEN_BACKUP/"
note "compose/generated/ backed up; it is restored at teardown"

echo "--- building images ---"
"${COMPOSE[@]}" build >/dev/null || { echo "FAIL: image build"; exit 1; }

# Create the containers (and therefore the volumes) without starting anything, so the seed
# lands before any entrypoint runs. Starting first would run bootstrap-auth against an empty
# volume and, under oauth-mount, fail the start -- which is phase D's assertion, not a
# precondition.
"${COMPOSE[@]}" up --no-start >/dev/null 2>&1

seed_volume() { # <source-volume> <dest-volume>
  docker run --rm -u 0:0 -v "$1:/from:ro" -v "$2:/to" --entrypoint sh "$SEED_IMAGE" \
    -c 'cp -a /from/. /to/ && chown -R 1000:1000 /to' >/dev/null 2>&1
}
seed_volume "$SEED_CLAUDE_VOLUME" "${PROJECT}_claude-state" \
  && pass "seeded ${PROJECT}_claude-state from $SEED_CLAUDE_VOLUME" \
  || { echo "FAIL: could not seed the claude state volume"; exit 1; }
seed_volume "$SEED_CODEX_VOLUME" "${PROJECT}_codex-state" \
  && pass "seeded ${PROJECT}_codex-state from $SEED_CODEX_VOLUME" \
  || { echo "FAIL: could not seed the codex state volume"; exit 1; }

volume_has "${PROJECT}_claude-state" \
  'test -s /state/.claude/.credentials.json || test -s /state/.claude.json' \
  && pass "seeded claude credential present (shape only)" \
  || fail "seeded claude state carries no credential -- every claude OAuth cell will be vacuous"
volume_has "${PROJECT}_codex-state" \
  'grep -q "\"refresh_token\"" /state/.codex/auth.json' \
  && pass "seeded codex credential carries a refresh_token (shape only)" \
  || fail "seeded codex state carries no OAuth credential -- codex OAuth cells will be vacuous"

# ---------------------------------------------------------------------------
# Phase A -- surface assertions (criteria 2 and 3). Default profile.
#
# 01.4 ASSERTS 01.2's environment contract rather than re-deciding it: every AUTH_MODE writes
# its credential relative to one of these values, so a container whose CODEX_HOME pointed off
# the volume would authenticate once and lose it at restart. The per-mode half of criterion 2
# -- cli_auth_credentials_store read in EVERY Codex mode -- is phase B's, because that is where
# the modes are iterated.
# ---------------------------------------------------------------------------

phase "A (authentication surface, criteria 2 and 3)"

declare -A CID
for agent in "${AGENTS[@]}"; do
  CID[$agent]="$("${COMPOSE[@]}" run -d --name "${PROJECT}-${agent}" --rm "$agent" sleep 900)"
  [ -n "${CID[$agent]}" ] || { echo "FAIL: could not start $agent"; exit 1; }
done

for agent in "${AGENTS[@]}"; do
  cid="${CID[$agent]}"
  ok=1

  got="$(docker exec "$cid" printenv HOME 2>/dev/null || true)"
  [ "$got" = "/home/agent" ] || { note "HOME=$got, expected /home/agent"; ok=0; }

  case "$agent" in
    claude)
      got="$(docker exec "$cid" printenv CLAUDE_CONFIG_DIR 2>/dev/null || true)"
      [ "$got" = "/home/agent/.claude" ] \
        || { note "CLAUDE_CONFIG_DIR=$got, expected /home/agent/.claude"; ok=0; }
      # R4.4: the OAuth account record lives OUTSIDE CLAUDE_CONFIG_DIR. Under 01.2's read-only
      # root filesystem a $HOME that was not the volume would make this unwritable, so
      # writability is a pass/fail property of the wiring. Probed and removed; never read.
      docker exec "$cid" sh -c \
        'test -f /home/agent/.claude.json || (touch /home/agent/.claude.json.probe && rm -f /home/agent/.claude.json.probe)' \
        >/dev/null 2>&1 || { note "/home/agent/.claude.json has nowhere writable to land (R4.4)"; ok=0; }
      ;;
    codex)
      got="$(docker exec "$cid" printenv CODEX_HOME 2>/dev/null || true)"
      [ "$got" = "/home/agent/.codex" ] \
        || { note "CODEX_HOME=$got, expected /home/agent/.codex"; ok=0; }
      ;;
    agy)
      # agy has no HOME-override variable (01.1 SF-2: absent from --help and from `strings`),
      # so it resolves ~/.gemini from $HOME. Asserted explicitly anyway -- "it follows from
      # HOME" is the kind of inference that stops being true when someone adds an env var.
      docker exec "$cid" sh -c 'test -d /home/agent/.gemini' >/dev/null 2>&1 \
        || { note "/home/agent/.gemini is absent (agy state has nowhere to persist)"; ok=0; }
      ;;
  esac

  [ "$ok" -eq 1 ] && pass "$agent: authentication surface is on the state volume" \
                  || fail "$agent: authentication surface is not correctly rooted"

  # Criterion 4 as it stands under the DEFAULT profile: neither optional mount is present.
  # Phases C and D re-assert the same equality with the mount each of them adds.
  got_mounts="$(mount_set "$cid")"
  want_mounts="$(expected_mounts "$agent")"
  [ "$got_mounts" = "$want_mounts" ] \
    && pass "$agent: mount set equals exactly {$want_mounts}" \
    || fail "$agent: mount set is {$got_mounts}, expected {$want_mounts}"
done

# D7 / R4.7 by ENUMERATION over the rendered config rather than by reading compose.yaml -- a
# shared volume introduced by an override fragment would be invisible to the second reading.
# Sharing one state volume between two agents would put one agent's refresh token inside
# another's blast radius, which is the property R4.7 exists to protect.
config_json="$("${COMPOSE[@]}" config --format json 2>/dev/null)"
if [ -z "$config_json" ]; then
  fail "volume exclusivity: could not render the compose config"
else
  dupes="$(echo "$config_json" | jq -r '
    .services | to_entries[] as $s
    | ($s.value.volumes // [])[] | select(.type == "volume")
    | "\(.source) \($s.key)"' | sort -u \
    | awk 'NF {c[$1]=c[$1]" "$2; n[$1]++} END {for (v in n) if (n[v] > 1) print v ":" c[v]}')"
  [ -z "$dupes" ] && pass "no named volume is mounted by two services (D7, R4.7)" \
                  || { echo "$dupes" | while IFS= read -r d; do note "shared volume $d"; done
                       fail "a named volume is shared between services"; }
fi

# The version-control half of R8.7. The backup half is not enforceable from inside a container
# -- Docker Desktop keeps every named volume in one VM disk image, so there is no per-volume
# exclusion to make -- and is carried by README.md's `tmutil` procedure with its residual
# recorded. This asserts only what this solution controls.
gitignore_ok=1
for p in references/.env_keys compose/generated/gitconfig.d/x compose/generated/oauth-src/auth.json \
         auth.json .credentials.json; do
  git check-ignore -q "$p" 2>/dev/null || { note "not git-ignored: $p"; gitignore_ok=0; }
done
[ -f compose/generated/.gitignore ] || { note "compose/generated/.gitignore is missing"; gitignore_ok=0; }
[ "$gitignore_ok" -eq 1 ] && pass "credential material is non-committable (R8.7, version-control half)" \
                          || fail "credential material is committable"

for agent in "${AGENTS[@]}"; do docker rm -f "${PROJECT}-${agent}" >/dev/null 2>&1 || true; done

# ---------------------------------------------------------------------------
# Phase B -- the AUTH_MODE matrix, T24 (criteria 1 and 4).
#
# Interface Contract 1 has SEVEN supported cells across three agents, and criterion 1 is as
# much about what does NOT happen as what does: an unsupported cell must never degrade to a
# working-but-different mode. Both halves are asserted here.
#
# T24 AS AMENDED (criterion 4, operator decision 2026-09-04): the pass criterion is "no browser
# inside the container", R4.9's own definition of headless -- not "no interactive terminal",
# which two of the three modes R4.9 names as headless cannot meet by construction.
#
# Credential values are PASSED THROUGH from this shell (`-e NAME`, never `-e NAME=value`), so
# no credential ever appears on a command line or in `docker inspect`'s Config.Cmd.
# ---------------------------------------------------------------------------

phase "B (AUTH_MODE matrix, T24)"

# --- the seven supported cells ---------------------------------------------
run_cell() { # <agent> <mode> <env-var-to-pass-through-or-->
  local agent="$1" mode="$2" cred="$3" out rc
  local envs=("AUTH_MODE=$mode")
  [ "$cred" != "-" ] && envs+=("$cred")
  out="$(agent_run base "$agent" "${envs[@]}" -- bash "$BOOTSTRAP" "$agent")"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "($agent, $mode) supported cell authenticates -- exit 0"
  else
    fail "($agent, $mode) supported cell exited $rc"
    note "$(echo "$out" | tail -3)"
  fi
}

run_cell claude apikey            ANTHROPIC_API_KEY
run_cell claude oauth-interactive -
run_cell claude oauth-token       CLAUDE_CODE_OAUTH_TOKEN
run_cell codex  apikey            OPENAI_API_KEY
run_cell codex  oauth-interactive -
run_cell codex  oauth-mount       -
run_cell agy    apikey            GEMINI_API_KEY

# --- criterion 2's per-mode half: R4.5 in EVERY Codex mode ------------------
#
# Owed to this sub-feature by SF-1. verify-pod-topology.sh check 4d reads the effective value
# inside the container, but only ever on the DEFAULT profile -- which proves the property for
# oauth-interactive alone. R4.5 is unconditional (the `keyring` store hard-fails with no D-Bus,
# and no container here has one under any mode), so it is re-asserted per Codex cell. Read from
# inside the container, never from the Dockerfile, exactly as criterion 2 requires.
for mode in apikey oauth-interactive oauth-mount; do
  envs=("AUTH_MODE=$mode")
  [ "$mode" = "apikey" ] && envs+=("OPENAI_API_KEY")
  store="$(agent_run base codex "${envs[@]}" -- \
           sh -c 'grep -E "^[[:space:]]*cli_auth_credentials_store[[:space:]]*=" "$CODEX_HOME/config.toml" | head -1')"
  if echo "$store" | grep -qE '=[[:space:]]*"file"[[:space:]]*$'; then
    pass "(codex, $mode): cli_auth_credentials_store = \"file\" read inside the container (R4.5)"
  else
    fail "(codex, $mode): effective cli_auth_credentials_store is not \"file\""
    note "got: ${store:-<absent>}"
  fi
done

# --- T24's headless property, as amended: no browser in the container -------
#
# R4.9 requires only that NO BROWSER EXIST INSIDE the container; the operator opens the printed
# URL on the host. Asserted as the absence of a browser binary and of a BROWSER pointer that
# would name one, rather than by watching for a process -- a browser that is never launched
# during a passing run is still a browser the agent could launch.
for agent in "${AGENTS[@]}"; do
  found="$(agent_run base "$agent" "AUTH_MODE=apikey" -- sh -c \
    'for b in xdg-open sensible-browser x-www-browser firefox chromium chromium-browser \
              google-chrome google-chrome-stable www-browser links lynx w3m; do
       command -v "$b" 2>/dev/null; done; printf "BROWSER=%s" "${BROWSER-}"')"
  if echo "$found" | grep -qE '^/|BROWSER=.+'; then
    fail "$agent: a browser is reachable inside the container (T24 as amended, R4.9)"
    note "$(echo "$found" | tr '\n' ' ')"
  else
    pass "$agent: no browser inside the container (T24 as amended, R4.9)"
  fi
done

# --- criterion 1's other half: the fail-closed path -------------------------
#
# One representative unsupported cell per agent. Exit 2 and a message NAMING the cell -- an
# unsupported cell that degraded to a working mode would silently defeat "the default is the
# safest mode that agent supports" (R4.12), and a test that only checked the exit code would
# not distinguish that from any other refusal.
check_refused() { # <agent> <mode> <expected-fragment>
  local agent="$1" mode="$2" want="$3" out rc
  out="$(agent_run base "$agent" "AUTH_MODE=$mode" -- bash "$BOOTSTRAP" "$agent")"
  rc=$?
  if [ "$rc" -eq 2 ] && echo "$out" | grep -qF "$want"; then
    pass "($agent, $mode) unsupported cell fails closed -- exit 2, names the cell"
  else
    fail "($agent, $mode) unsupported cell: exit $rc, expected 2 with a message naming it"
    note "$(echo "$out" | tail -3)"
  fi
}
check_refused claude oauth-mount       "unsupported cell (claude, oauth-mount)"
check_refused codex  oauth-token       "unsupported cell (codex, oauth-token)"
check_refused agy    oauth-interactive "unsupported cell (agy, oauth-interactive)"

# AUTH_MODE unset is the same class of failure and is stated separately in Interface Contract 2:
# the image declares the variable with NO default, so an empty value must fail rather than pick
# a mode on the operator's behalf -- possibly a less safe one than R4.12 mandates.
out="$(agent_run base claude "AUTH_MODE=" -- bash "$BOOTSTRAP" claude)"; rc=$?
if [ "$rc" -eq 2 ] && echo "$out" | grep -qF "AUTH_MODE is unset"; then
  pass "(claude, <unset>) fails closed -- exit 2, no default mode is chosen"
else
  fail "(claude, <unset>): exit $rc, expected 2 naming the unset variable"
  note "$(echo "$out" | tail -3)"
fi

# ---------------------------------------------------------------------------
# Phase C -- the pre-mount git-config scrub, T22 (criterion 6).
#
# R2.9 says the credential.helper entry "is removed FIRST", and T22 inspects the MOUNTED FILE
# itself. So the scrub runs on the host against a fixture carrying exactly what it must strip,
# and the assertions are made on the artifact and then inside the container.
#
# Its own phase because it adds a mount: phase A's mount-set equality would fail with the
# fragment layered, and relaxing that assertion to containment would give up the property.
# ---------------------------------------------------------------------------

phase "C (git-config scrub, T22)"

FIXTURE="$SCRATCH/fixture.gitconfig"
cat > "$FIXTURE" <<'FIX'
[user]
	name = Fixture Operator
	email = fixture@example.invalid
[credential]
	helper = osxkeychain
[credential "https://github.com"]
	helper = !gh auth git-credential
[include]
	path = ~/.gitconfig.local
[includeIf "gitdir:~/work/"]
	path = ~/work/.gitconfig
FIX

rm -rf compose/generated/gitconfig.d
bash scripts/scrub-gitconfig.sh "$FIXTURE" >/dev/null 2>&1 \
  && pass "scrub-gitconfig.sh ran against the fixture" \
  || fail "scrub-gitconfig.sh failed against the fixture"

SCRUBBED=compose/generated/gitconfig.d/.gitconfig
if [ ! -f "$SCRUBBED" ]; then
  fail "the scrub produced no artifact at $SCRUBBED"
else
  artifact_ok=1
  grep -qiE '^[[:space:]]*helper[[:space:]]*=' "$SCRUBBED" \
    && { note "the artifact still carries a credential helper"; artifact_ok=0; }
  grep -qiE '^\[(include|includeIf)' "$SCRUBBED" \
    && { note "the artifact still carries an include directive"; artifact_ok=0; }
  # The control is that the material is not there. A scrub that also dropped the operator's
  # identity would be a different failure -- silently correct on R2.9, useless in practice.
  grep -qE '^[[:space:]]*name[[:space:]]*=' "$SCRUBBED" \
    || { note "the artifact lost [user] name -- the scrub removed more than R2.9 asks"; artifact_ok=0; }
  [ "$artifact_ok" -eq 1 ] \
    && pass "the scrubbed artifact carries no helper and no include, and keeps [user] (R2.9)" \
    || fail "the scrubbed artifact is wrong"
fi

# Without the fragment, GIT_CONFIG_GLOBAL must be UNSET -- set unconditionally it would point
# at an absent path under the default profile and every `git config --global` would fail or
# land on tmpfs and vanish at restart. The variable and its target appear together or not at all.
got="$(extract "$(agent_run base claude "AUTH_MODE=oauth-interactive" -- \
        sh -c "$DELIM_PRINT \"\${GIT_CONFIG_GLOBAL-}\"")")"
[ -z "$got" ] \
  && pass "default profile: GIT_CONFIG_GLOBAL is unset (no dangling pointer)" \
  || fail "default profile: GIT_CONFIG_GLOBAL=$got with no mount to back it"

git_cid="$("${COMPOSE_GIT[@]}" run -d --name "${PROJECT}-gitcfg" --rm claude sleep 300)"
if [ -z "$git_cid" ]; then
  fail "could not start claude with the host-gitconfig fragment layered"
else
  # :ro read from the kernel's own view, not trusted from the fragment. Field 5 of a mountinfo
  # line is the mount point, field 6 the per-mount option list.
  opts="$(docker exec "$git_cid" awk '$5 == "/run/gitconfig" {print $6}' /proc/self/mountinfo | tail -n1)"
  if [ -z "$opts" ]; then
    fail "/run/gitconfig is not a mount point"
  else
  case ",$opts," in
    *,ro,*) pass "/run/gitconfig is mounted read-only (mount options: $opts)" ;;
    *)      fail "/run/gitconfig is mounted '$opts', not read-only" ;;
  esac
  fi

  got="$(docker exec "$git_cid" printenv GIT_CONFIG_GLOBAL 2>/dev/null || true)"
  [ "$got" = "/run/gitconfig/.gitconfig" ] \
    && pass "GIT_CONFIG_GLOBAL points at the mounted artifact" \
    || fail "GIT_CONFIG_GLOBAL=$got, expected /run/gitconfig/.gitconfig"

  # T22 inspects the MOUNTED FILE, which is the assertion the scrub's ordering exists to make
  # true: there is no unfiltered copy inside the container for a compromised agent to read.
  mounted_ok=1
  docker exec "$git_cid" grep -qiE '^[[:space:]]*helper[[:space:]]*=' /run/gitconfig/.gitconfig \
    && { note "the MOUNTED file carries a credential helper"; mounted_ok=0; }
  docker exec "$git_cid" grep -qiE '^\[(include|includeIf)' /run/gitconfig/.gitconfig \
    && { note "the MOUNTED file carries an include directive"; mounted_ok=0; }
  [ "$mounted_ok" -eq 1 ] \
    && pass "the mounted file itself carries no helper and no include (T22)" \
    || fail "the mounted file still carries material R2.9 requires removed"

  # Criterion 6's third assertion, and the one that could not be made as written.
  #
  # FOUND BY RUNNING: there is NO `git` BINARY in any agent image. All three are built from
  # node:22-slim (01.2) and none installs git, so `git config --global --get-all
  # credential.helper` cannot be executed inside the container at all -- the first pass of this
  # harness failed with "git: executable file not found in $PATH".
  #
  # The PROPERTY R2.9 protects holds, and holds more strongly than the original assertion would
  # have shown: with no git binary, no credential helper is resolvable by anything, and the
  # mounted-file assertion above is what carries T22. The assertion is therefore made against
  # whichever is true, rather than being dropped.
  #
  # THE CONSEQUENCE IS NOT THIS TEST'S, AND IT IS RECORDED RATHER THAN FIXED HERE:
  # `mounts.host_git_config` currently mounts a configuration that nothing in the container can
  # read, and an agent asked to run git cannot. Whether git belongs in the images is a scope
  # question for 01.5's pack composition, not a change to make from inside an acceptance test.
  if docker exec "$git_cid" sh -c 'command -v git' >/dev/null 2>&1; then
    helpers="$(docker exec "$git_cid" git config --global --get-all credential.helper 2>/dev/null || true)"
    [ -z "$helpers" ] \
      && pass "git config --global --get-all credential.helper is empty inside the container" \
      || fail "git resolves a credential helper inside the container: $helpers"
  else
    pass "no git binary exists in the container, so no credential helper is resolvable (R2.9)"
    note "FINDING: mounts.host_git_config mounts a config nothing can read -- see 01.5 scope"
  fi

  got_mounts="$(mount_set "$git_cid")"
  want_mounts="$(expected_mounts claude /run/gitconfig)"
  [ "$got_mounts" = "$want_mounts" ] \
    && pass "claude+gitconfig: mount set equals exactly {$want_mounts}" \
    || fail "claude+gitconfig: mount set is {$got_mounts}, expected {$want_mounts}"

  docker rm -f "${PROJECT}-gitcfg" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# Phase E -- restart and rebuild persistence, T9 (criterion 9).
#
# R4.1 says "container restart AND image rebuild"; T9 says restart. Both are exercised. The
# rebuild form is the one that catches state written into an image layer rather than onto the
# volume, and it is far cheaper to find here than in Milestone 02.
#
# RUNS BEFORE PHASE D (deviation, recorded on the plan): D forces a refresh and then deletes
# the volume credential, so running it first would leave this phase asserting the persistence
# of a credential D had just destroyed.
#
# "Still authenticated" is asserted as credential presence and SHAPE plus a local status
# command, not as a model call: a live invocation costs provider quota and can itself trigger a
# refresh, which would make this phase quietly destructive. Set AUTH_LIVE_RUN=1 for the live
# half; the flow that proves a credential actually works was run at SF-2b and is run again in
# phase D.
# ---------------------------------------------------------------------------

phase "E (restart and rebuild persistence, T9)"

MARKER=/home/agent/.sf5-persistence-marker
declare -A EMODE=([claude]=oauth-interactive [codex]=oauth-interactive [agy]=apikey)

credential_present() { # <agent>  -- shape only, never content
  case "$1" in
    claude) volume_has "${PROJECT}_claude-state" \
              'test -s /state/.claude/.credentials.json || test -s /state/.claude.json' ;;
    codex)  volume_has "${PROJECT}_codex-state" \
              'grep -q "\"refresh_token\"" /state/.codex/auth.json' ;;
    agy)    return 0 ;;  # apikey is env-delivered by design: nothing is persisted to assert
  esac
}

# --- restart form ----------------------------------------------------------
for agent in claude codex; do
  "${COMPOSE[@]}" run -d --name "${PROJECT}-p-${agent}" \
                  -e "AUTH_MODE=${EMODE[$agent]}" "$agent" sleep 600 >/dev/null
  docker exec "${PROJECT}-p-${agent}" sh -c "echo session-state > $MARKER" >/dev/null 2>&1
done

for agent in claude codex; do
  docker restart "${PROJECT}-p-${agent}" >/dev/null 2>&1
  # A restart re-runs the entrypoint, and therefore bootstrap-auth's --at-start pass. A
  # container that came back up at all has already passed the fail-closed half.
  survived="$(docker exec "${PROJECT}-p-${agent}" cat "$MARKER" 2>/dev/null || true)"
  if [ "$survived" = "session-state" ] && credential_present "$agent"; then
    pass "$agent: credential and session state survive a container restart (T9)"
  else
    fail "$agent: state did not survive a restart (marker='$survived')"
  fi
done

if [ "$AUTH_LIVE_RUN" = "1" ]; then
  out="$(docker exec "${PROJECT}-p-codex" codex login status 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && pass "codex: codex login status reports an authenticated session" \
                  || { fail "codex: login status exited $rc after restart"; note "$(echo "$out" | tail -2)"; }
fi

for agent in claude codex; do docker rm -f "${PROJECT}-p-${agent}" >/dev/null 2>&1 || true; done

# --- rebuild form ----------------------------------------------------------
#
# `down` WITHOUT -v. The volumes are the thing under test; destroying them would make this
# assertion vacuous rather than failing.
echo "--- down (no -v) -> build -> up ---"
"${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1
"${COMPOSE[@]}" build >/dev/null 2>&1 || fail "rebuild failed"

for agent in claude codex; do
  out="$(agent_run base "$agent" "AUTH_MODE=${EMODE[$agent]}" -- \
         sh -c "$DELIM_PRINT \"\$(cat $MARKER 2>/dev/null)\"")"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(extract "$out")" = "session-state" ] \
     && credential_present "$agent"; then
    pass "$agent: credential and session state survive down -> build -> up (R4.1)"
  else
    fail "$agent: state did not survive an image rebuild (exit $rc)"
    note "$(echo "$out" | tail -2)"
  fi
done

# ---------------------------------------------------------------------------
# Phase D -- oauth-mount shape and the bootstrap boundary, T25 (criterion 5).
#
# LAST, and destructive by design. D1 forces a real refresh, which ROLLS the codex refresh
# token (SF-3, measured) and therefore SUPERSEDES the copy the seed volume holds; D2 then
# deletes the volume credential to prove the steady-state failure. Both are the assertions
# T25 asks for; neither can be made without spending something.
#
# The two stages are the whole point of the phase. "Bootstrap only" (R4.15) is implemented as
# a separate INVOCATION, not as a guard inside a permanently-mounted path -- so at steady state
# there is no source to copy from, and edge case 2 (an agent deleting its own credential to
# force a re-copy) stops being possible rather than being guarded against.
# ---------------------------------------------------------------------------

phase "D (oauth-mount shape and bootstrap boundary, T25)"

echo "!!! This phase forces a codex OAuth refresh. codex ROLLS its refresh token, so the copy in"
echo "!!! $SEED_CODEX_VOLUME becomes SUPERSEDED and the operator's host 'codex login' should be"
echo "!!! re-run afterwards. See profiles/oauth-mount.yaml, accepted_risk.rotation."

"${COMPOSE[@]}" up -d egress-mediator >/dev/null 2>&1 \
  || fail "could not start the mediator; the forced refresh below has no route out"

# --- stage the credential source (host side) --------------------------------
#
# Staged from a COPY of the seed volume's credential, never from a path this harness invents:
# scripts/stage-oauth-mount.sh is the only supported way to build the directory, and it is what
# strips OPENAI_API_KEY and writes the R4.17 record. Extracted into $SCRATCH, which is removed
# at teardown.
docker run --rm -v "${SEED_CODEX_VOLUME}:/state:ro" -v "$SCRATCH:/out" -u 0:0 \
  --entrypoint sh "$SEED_IMAGE" -c 'cp /state/.codex/auth.json /out/host-auth.json' >/dev/null 2>&1
if [ ! -s "$SCRATCH/host-auth.json" ]; then
  fail "could not extract a credential from $SEED_CODEX_VOLUME to stage"
else
  rm -rf compose/generated/oauth-src
  bash scripts/stage-oauth-mount.sh --profile oauth-mount --source "$SCRATCH/host-auth.json" >/dev/null 2>&1 \
    && pass "stage-oauth-mount.sh staged the credential source" \
    || fail "stage-oauth-mount.sh refused to stage the credential source"
fi

SRC_DIR=compose/generated/oauth-src
if [ -f "$SRC_DIR/auth.json" ] && [ -f "$SRC_DIR/accepted-risk.yaml" ]; then
  staged_ok=1
  grep -q '"OPENAI_API_KEY"' "$SRC_DIR/auth.json" \
    && { note "the staged copy still carries OPENAI_API_KEY (test-validity control)"; staged_ok=0; }
  grep -q '"refresh_token"' "$SRC_DIR/auth.json" \
    || { note "the staged copy carries no refresh_token"; staged_ok=0; }
  for field in file mount_mode revocation_path blast_radius rotation; do
    grep -Eq "^[[:space:]]*${field}:" "$SRC_DIR/accepted-risk.yaml" \
      || { note "accepted-risk.yaml is missing the '$field' field (R4.17)"; staged_ok=0; }
  done
  [ "$staged_ok" -eq 1 ] \
    && pass "staged source: OAuth set with OPENAI_API_KEY absent, R4.17 record complete" \
    || fail "the staged source is not the shape R4.14/R4.17 require"
else
  fail "the staged source is missing auth.json or accepted-risk.yaml"
fi

HOST_SHA_BEFORE="$(sha16 "$SRC_DIR/auth.json")"

# --- D1: the bootstrap invocation -------------------------------------------
#
# The volume is EMPTIED first. With the seed still in place the branch short-circuits on
# "already authenticated" and the copy -- the thing under test -- never runs.
"${COMPOSE[@]}" rm -sf codex >/dev/null 2>&1
docker volume rm "${PROJECT}_codex-state" >/dev/null 2>&1 \
  && pass "codex state volume emptied for the bootstrap" \
  || fail "could not empty the codex state volume; the copy path cannot be exercised"

oa_cid="$("${COMPOSE_OAUTH[@]}" run -d --name "${PROJECT}-oauth" --rm codex sleep 300 2>/dev/null)"
if [ -z "$oa_cid" ]; then
  fail "the bootstrap invocation did not start (bootstrap-auth refused the copy)"
else
  # R4.14: a dedicated DIRECTORY, never the credential file itself.
  docker exec "$oa_cid" test -d /run/oauth-src >/dev/null 2>&1 \
    && pass "the credential source is a directory (R4.14)" \
    || fail "/run/oauth-src is not a directory"

  # R4.13: :ro is the ONLY real control -- Docker Desktop's VirtioFS fakes file ownership, so
  # 0600 means nothing inside the container. The MOUNT mode is asserted, not the file mode, and
  # it is read from the kernel's own view rather than trusted from the fragment.
  opts="$(docker exec "$oa_cid" awk '$5 == "/run/oauth-src" {print $6}' /proc/self/mountinfo | tail -n1)"
  if [ -z "$opts" ]; then
    fail "/run/oauth-src is not a mount point"
  else
  case ",$opts," in
    *,ro,*) pass "/run/oauth-src is mounted read-only (mount options: $opts)" ;;
    *)      fail "/run/oauth-src is mounted '$opts', not read-only (R4.13)" ;;
  esac
  fi

  got_mounts="$(mount_set "$oa_cid")"
  want_mounts="$(expected_mounts codex /run/oauth-src)"
  [ "$got_mounts" = "$want_mounts" ] \
    && pass "bootstrap invocation: mount set equals exactly {$want_mounts}" \
    || fail "bootstrap invocation: mount set is {$got_mounts}, expected {$want_mounts}"

  # The copy itself: one file, onto the state volume, and NOT accepted-risk.yaml -- that is the
  # operator's record and has no business persisting into the agent's home.
  copy_ok=1
  docker exec "$oa_cid" sh -c 'grep -q "\"refresh_token\"" "$CODEX_HOME/auth.json"' >/dev/null 2>&1 \
    || { note "no OAuth credential on the state volume after the bootstrap"; copy_ok=0; }
  docker exec "$oa_cid" sh -c 'grep -q "\"OPENAI_API_KEY\"" "$CODEX_HOME/auth.json"' >/dev/null 2>&1 \
    && { note "the copied credential carries OPENAI_API_KEY"; copy_ok=0; }
  docker exec "$oa_cid" sh -c 'test -e "$CODEX_HOME/accepted-risk.yaml"' >/dev/null 2>&1 \
    && { note "accepted-risk.yaml was copied onto the state volume"; copy_ok=0; }
  [ "$copy_ok" -eq 1 ] \
    && pass "the credential -- and only the credential -- is on the state volume (R4.15)" \
    || fail "the bootstrap copy is wrong"

  docker rm -f "${PROJECT}-oauth" >/dev/null 2>&1 || true
fi

# --- D1: force a refresh, then check both sides of the boundary -------------
#
# The lever is the ACCESS token's own `exp` claim, which is what SF-3 measured as the refresh
# trigger -- `last_refresh` and the id_token's exp were both inert. The payload is re-encoded
# with a past exp and the original signature left in place: codex does not verify that
# signature locally (SF-3, observed), which is what makes the measurement possible in a build
# session rather than in ten days.
cat > "$SCRATCH/expire.js" <<'JS'
const fs = require('fs');
const f = '/state/.codex/auth.json';
const j = JSON.parse(fs.readFileSync(f, 'utf8'));
const parts = j.tokens.access_token.split('.');
const p = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
p.exp = Math.floor(Date.now() / 1000) - 3600;
parts[1] = Buffer.from(JSON.stringify(p)).toString('base64url').replace(/=+$/, '');
j.tokens.access_token = parts.join('.');
fs.writeFileSync(f, JSON.stringify(j));
JS

REFRESH_SHA_BEFORE="$(field_sha "${PROJECT}_codex-state" ".codex/auth.json" "tokens.refresh_token")"
docker run --rm -u 1000:1000 -v "${PROJECT}_codex-state:/state" \
  -v "$SCRATCH/expire.js:/tmp/expire.js:ro" --entrypoint node "$SEED_IMAGE" /tmp/expire.js >/dev/null 2>&1 \
  && note "access-token exp backdated on the state volume (the SF-3 lever)" \
  || fail "could not backdate the access token; the refresh cannot be forced"

refresh_out="$(agent_run oauth codex -- codex exec --skip-git-repo-check 'reply with the single word ok' 2>&1)"
REFRESH_SHA_AFTER="$(field_sha "${PROJECT}_codex-state" ".codex/auth.json" "tokens.refresh_token")"
HOST_SHA_AFTER="$(sha16 "$SRC_DIR/auth.json")"

if [ -n "$REFRESH_SHA_BEFORE" ] && [ -n "$REFRESH_SHA_AFTER" ] \
   && [ "$REFRESH_SHA_BEFORE" != "$REFRESH_SHA_AFTER" ]; then
  pass "the refreshed credential is on the STATE VOLUME (refresh token rolled: $REFRESH_SHA_BEFORE -> $REFRESH_SHA_AFTER)"
else
  fail "no refresh was observed on the state volume (before=$REFRESH_SHA_BEFORE after=$REFRESH_SHA_AFTER)"
  note "$(echo "$refresh_out" | tail -3)"
fi

if [ -n "$HOST_SHA_BEFORE" ] && [ "$HOST_SHA_BEFORE" = "$HOST_SHA_AFTER" ]; then
  pass "the host credential source is UNCHANGED by the refresh (:ro held; sha $HOST_SHA_AFTER)"
else
  fail "the host credential source changed: $HOST_SHA_BEFORE -> $HOST_SHA_AFTER"
fi

# --- D2: steady state -------------------------------------------------------
#
# The assertion T25 as written does not reach. Steady state layers no bootstrap fragment, so
# the host mount is ABSENT ENTIRELY (R4.15) -- not present-and-ignored -- and an emptied volume
# therefore has nothing to re-copy from.
st_cid="$("${COMPOSE[@]}" run -d --name "${PROJECT}-steady" --rm -e AUTH_MODE=oauth-mount codex sleep 300 2>/dev/null)"
if [ -z "$st_cid" ]; then
  fail "the steady-state container did not start with a populated volume (should be a no-op)"
else
  pass "steady state with a populated volume: bootstrap-auth is an idempotent no-op"

  if docker exec "$st_cid" test -e /run/oauth-src >/dev/null 2>&1; then
    fail "steady state: /run/oauth-src is present -- R4.15 requires the host mount to be absent"
  else
    pass "steady state: no host credential mount is present at all (R4.15)"
  fi

  got_mounts="$(mount_set "$st_cid")"
  want_mounts="$(expected_mounts codex)"
  [ "$got_mounts" = "$want_mounts" ] \
    && pass "steady state: mount set equals exactly {$want_mounts}" \
    || fail "steady state: mount set is {$got_mounts}, expected {$want_mounts}"

  # Edge case 2: the agent deletes its own credential to force a re-copy. With no source to
  # copy from, the NEXT START fails rather than silently recovering -- and because the
  # entrypoint runs under `set -e`, exit 3 fails the container start, not just the dispatcher.
  docker exec "$st_cid" sh -c 'rm -f "$CODEX_HOME/auth.json"' >/dev/null 2>&1
  docker rm -f "${PROJECT}-steady" >/dev/null 2>&1 || true

  out="$(agent_run base codex "AUTH_MODE=oauth-mount" -- codex --version)"; rc=$?
  if [ "$rc" -eq 3 ] && echo "$out" | grep -qF "stage-oauth-mount.sh"; then
    pass "steady state with the credential deleted: exit 3, naming the bootstrap command (edge case 2)"
  else
    fail "steady state with the credential deleted: exit $rc, expected 3 naming the bootstrap command"
    note "$(echo "$out" | tail -3)"
  fi
fi

# ---------------------------------------------------------------------------

echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "ONE OR MORE CHECKS FAILED"
  exit 1
fi
