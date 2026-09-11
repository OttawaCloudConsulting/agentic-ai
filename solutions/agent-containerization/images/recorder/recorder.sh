#!/usr/bin/env bash
# The agent action recorder (02.1 SF-2, R9.7, D20, Decision 3). One process per
# agent, read-only source, no network. Polls its agent's own transcript file(s)
# under the read-only /src mount and ships every newly completed line to its own
# sink volume, append-only, in the shape Interface Contract 1 fixes.
#
# WHY POLLING AND NOT inotify. The source is a Docker named-volume bind under a
# read_only rootfs with no extra capabilities; inotify on some volume drivers
# misses events entirely, and a missed event here is a silently incomplete audit
# trail rather than a cosmetic gap. A fixed poll interval has a STATED bound
# instead -- RECORDER_POLL_SECONDS -- and that bound is the tamper-evidence window
# this feature's documentation names.
#
# WHY BYTE OFFSETS PERSISTED ON THE SINK, NOT TMPFS (Decision 3). A recorder
# restart must not re-ship a range it already shipped -- that duplicates lines, and
# it would ship a retroactively edited file as if it were fresh content, which is
# exactly the property T35 tests. State lives under the sink volume's .state/
# directory, one file per source, so it survives a container restart.
#
# Two shipping modes, selected per agent by RECORDER_MODE (docs/records/agent-action-log.md):
#   append    claude, codex -- append-only JSONL. Ship each newly completed,
#             newline-terminated line, tracking (inode, offset) per file.
#   snapshot  agy -- whole-file rewrite (SQLite). Ship a `record_snapshot` line
#             whenever the file's sha256 changes; no byte offset applies.
set -uo pipefail

AGENT="${RECORDER_AGENT:?RECORDER_AGENT is required}"
SOURCE_GLOB="${RECORDER_SOURCE_GLOB:?RECORDER_SOURCE_GLOB is required}"
SESSION_ID_SPEC="${RECORDER_SESSION_ID:?RECORDER_SESSION_ID is required}"
MODE="${RECORDER_MODE:?RECORDER_MODE is required (append|snapshot)}"
POLL_SECONDS="${RECORDER_POLL_SECONDS:-1}"

SINK_LOG=/var/log/actions/action-audit.log
STATE_DIR=/var/log/actions/.state
RESOLVED=/etc/recorder/resolved.yaml

case "$MODE" in
  append|snapshot) ;;
  *) echo "recorder: RECORDER_MODE must be append or snapshot, got '$MODE'" >&2; exit 1 ;;
esac

case "$SESSION_ID_SPEC" in
  filename:*) SESSION_ID_REGEX="${SESSION_ID_SPEC#filename:}" ;;
  *) echo "recorder: RECORDER_SESSION_ID only supports the filename:<regex> form, got '$SESSION_ID_SPEC'" >&2; exit 1 ;;
esac

# Interface Contract 2: the identity token read from the SAME resolved artifact
# every other component in this pod reads it from -- one source, never a second
# copy the recorder could drift from the egress trail's `agent` field.
AGENT_IDENTITY="$(yq eval ".agents.${AGENT}.identity" "$RESOLVED" 2>/dev/null)"
if [ -z "$AGENT_IDENTITY" ] || [ "$AGENT_IDENTITY" = "null" ]; then
  echo "recorder: .agents.${AGENT}.identity is missing from ${RESOLVED}" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"

# 02.1 SF-4 (R9.9, D11, Decision 6): the `agent_action_log` export is this
# stdout relay alone. Recording is unaffected by construction -- the sink append
# two lines down does not read this value, so no profile setting can reach it.
EXPORT_AGENT_ACTION_LOG="$(yq eval '.exports.agent_action_log' "$RESOLVED" 2>/dev/null)"
[ "$EXPORT_AGENT_ACTION_LOG" = "true" ] || [ "$EXPORT_AGENT_ACTION_LOG" = "false" ] \
  || EXPORT_AGENT_ACTION_LOG="true"

jstr() { jq -Rn --arg v "$1" '$v'; }

# 02.1 SF-5 (R8.6, Decision 8): the sink stays faithful -- these patterns run ONLY on the
# relayed copy that leaves the container via the agent_action_log export, never on $SINK_LOG.
# Four families: proxy-URL userinfo (the SF-1 P1/P2 finding -- codex and agy splice a plaintext
# password into HTTPS_PROXY, and a tool call that echoes it lands the value in the transcript),
# known model-provider API-key/token prefixes, (02.3 SF-4) GitHub token formats -- the
# `github-token` pack credential (packs/github-cli/pack.yaml) lands as GH_TOKEN in the
# environment the same way E1-E4 do, so it is exposed by the same P1/P2 class finding (P3,
# docs/records/credential-inventory.md) -- and (02.3 SF-5) kubeconfig material. The
# `kubeconfig` pack credential (packs/kubernetes/pack.yaml) is `path_env`, never `env`, so it
# never lands in the environment itself; the exposure is one layer down, at the FILE's content,
# when a tool call echoes a `cat`/`kubectl config view --raw` of it (P4,
# docs/records/credential-inventory.md).
redact_for_relay() {
  printf '%s' "$1" | sed -E \
    -e 's#(://[A-Za-z0-9_.%-]+:)[^@"[:space:]]+(@)#\1<redacted>\2#g' \
    -e 's#sk-ant-[A-Za-z0-9_-]{10,}#<redacted:sk-ant>#g' \
    -e 's#sk-proj-[A-Za-z0-9_-]{10,}#<redacted:sk-proj>#g' \
    -e 's#(^|[^-])sk-[A-Za-z0-9]{20,}#\1<redacted:sk>#g' \
    -e 's#AIza[A-Za-z0-9_-]{10,}#<redacted:AIza>#g' \
    -e 's#ghp_[A-Za-z0-9]{10,}#<redacted:ghp>#g' \
    -e 's#github_pat_[A-Za-z0-9_]{10,}#<redacted:github_pat>#g' \
    -e 's#gho_[A-Za-z0-9]{10,}#<redacted:gho>#g' \
    -e 's#client-key-data:[[:space:]]*[A-Za-z0-9+/=]{10,}#client-key-data: <redacted:kubeconfig>#g' \
    -e 's#client-certificate-data:[[:space:]]*[A-Za-z0-9+/=]{10,}#client-certificate-data: <redacted:kubeconfig>#g' \
    -e 's#token:[[:space:]]*[A-Za-z0-9_.-]{10,}#token: <redacted:kubeconfig>#g' \
    -e 's#-----BEGIN [A-Z ]*(PRIVATE KEY|CERTIFICATE)-----[A-Za-z0-9+/=\\n ]*-----END [A-Z ]*(PRIVATE KEY|CERTIFICATE)-----#<redacted:kubeconfig-pem>#g'
}

emit() {
  # $1: a jq object literal (already valid JSON) to merge onto the common envelope.
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
  local line
  line="$(jq -cn --arg ts "$ts" --arg agent "$AGENT_IDENTITY" --argjson rest "$1" \
    '{ts: $ts, agent: $agent, identity_source: "state_volume"} + $rest')"
  printf '%s\n' "$line" >> "$SINK_LOG"
  if [ "$EXPORT_AGENT_ACTION_LOG" = "true" ]; then
    local relay n
    relay="$(redact_for_relay "$line")"
    n="$(printf '%s' "$relay" | grep -o '<redacted[^>]*>' | wc -l | tr -d ' ')"
    [ "$n" -gt 0 ] && relay="$(printf '%s' "$relay" | jq -c --argjson n "$n" '. + {redacted: $n}')"
    printf '%s\n' "$relay"
  fi
  return 0
}

session_id_for() {
  local base="$1"
  if [[ "$base" =~ $SESSION_ID_REGEX ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf ''
  fi
}

state_file_for() {
  local source="$1"
  printf '%s/%s.state' "$STATE_DIR" "$(printf '%s' "$source" | sha256sum | cut -d' ' -f1)"
}

# ---------------------------------------------------------------------------
# append mode -- Decision 3's byte-offset shipping
# ---------------------------------------------------------------------------
ship_append() {
  local file="$1" source="$2"
  local state sf inode size prev_inode prev_offset
  sf="$(state_file_for "$source")"
  inode="$(stat -c%i "$file" 2>/dev/null)" || return 0
  size="$(stat -c%s "$file" 2>/dev/null)" || return 0

  if [ -f "$sf" ]; then
    read -r prev_inode prev_offset < "$sf"
  else
    prev_inode="$inode"
    prev_offset=0
  fi

  if [ "$inode" != "$prev_inode" ]; then
    emit "$(jq -cn --arg source "$source" --arg old "$prev_inode" --arg new "$inode" \
      '{event: "transcript_replaced", source: $source, old_inode: $old, new_inode: $new}')"
    prev_inode="$inode"
    prev_offset=0
  fi

  if [ "$size" -lt "$prev_offset" ]; then
    emit "$(jq -cn --arg source "$source" --argjson old "$prev_offset" --argjson new "$size" \
      '{event: "transcript_truncated", source: $source, old_offset: $old, new_size: $new}')"
    prev_offset=0
  fi

  local session_id
  session_id="$(session_id_for "$(basename "$file")")"

  local offset="$prev_offset"
  if [ "$size" -gt "$offset" ]; then
    # Everything new, up to and including the last completed line. A trailing
    # partial line (no closing \n yet) is held back for the next poll.
    local chunk complete
    chunk="$(tail -c "+$((offset + 1))" "$file")"
    if [ -n "$chunk" ]; then
      # Only complete, \n-terminated lines are shipped; a trailing partial line
      # (no closing \n yet) is dropped here and re-read whole on the next poll.
      #
      # `$chunk` came out of a `$(...)` capture, which unconditionally strips
      # trailing newlines -- so `$chunk` itself NEVER ends in \n, even when the
      # file on disk does, and `${chunk: -1} = $'\n'` can never be true. Read
      # the file's actual last byte separately: `$(tail -c1 "$file")` is empty
      # iff that byte is \n (same stripping, applied to exactly one byte), which
      # is the signal `${chunk: -1}` was meant to give. The \n stripped off
      # `$chunk` is added back explicitly below.
      if [ -z "$(tail -c1 "$file")" ]; then
        complete="$chunk"$'\n'
      elif [[ "$chunk" == *$'\n'* ]]; then
        complete="${chunk%$'\n'*}"$'\n'
      else
        complete=""
      fi
      while IFS= read -r cline; do
        local blen line_sha256 record_json
        blen="$(printf '%s' "$cline" | wc -c)"
        line_sha256="$(printf '%s' "$cline" | sha256sum | cut -d' ' -f1)"
        if record_json="$(jq -c . <<<"$cline" 2>/dev/null)"; then
          emit "$(jq -cn --arg source "$source" --argjson offset "$offset" \
                    --argjson length "$blen" --arg sha "$line_sha256" \
                    --arg sid "$session_id" --argjson record "$record_json" \
                    '{session_id: (if $sid == "" then null else $sid end),
                      source: $source, offset: $offset, length: $length,
                      line_sha256: $sha, record: $record}')"
        else
          emit "$(jq -cn --arg source "$source" --argjson offset "$offset" \
                    --argjson length "$blen" --arg sha "$line_sha256" \
                    --arg sid "$session_id" --arg raw "$cline" \
                    '{session_id: (if $sid == "" then null else $sid end),
                      source: $source, offset: $offset, length: $length,
                      line_sha256: $sha, record_raw: $raw}')"
        fi
        offset=$((offset + blen + 1))
      done < <(printf '%s' "$complete")
    fi
  fi

  printf '%s %s\n' "$inode" "$offset" > "$sf"
}

# ---------------------------------------------------------------------------
# snapshot mode -- Decision 3's `agy` branch (whole-file rewrite)
# ---------------------------------------------------------------------------
ship_snapshot() {
  local file="$1" source="$2"
  local sf sha size prev_sha
  sf="$(state_file_for "$source")"
  sha="$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)" || return 0
  size="$(stat -c%s "$file" 2>/dev/null)" || return 0
  prev_sha=""
  [ -f "$sf" ] && prev_sha="$(cat "$sf")"

  if [ "$sha" != "$prev_sha" ]; then
    local session_id
    session_id="$(session_id_for "$(basename "$file")")"
    emit "$(jq -cn --arg source "$source" --argjson size "$size" --arg sha "$sha" \
              --arg sid "$session_id" \
              '{session_id: (if $sid == "" then null else $sid end),
                source: $source, record_snapshot: {sha256: $sha, size: $size}}')"
    printf '%s' "$sha" > "$sf"
  fi
}

matched_files() {
  local f
  shopt -s nullglob
  for f in $SOURCE_GLOB; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
  shopt -u nullglob
}

FIRST_RUN=1
[ -f "$STATE_DIR/.initialized" ] && FIRST_RUN=0

emit "$(jq -cn --argjson poll "$POLL_SECONDS" --argjson first "$([ "$FIRST_RUN" -eq 1 ] && echo true || echo false)" \
  '{event: "recorder_start", poll_seconds: $poll, first_run: $first}')"

if [ "$FIRST_RUN" -eq 1 ]; then
  files_json="[]"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    source="${f#/src/}"
    sz="$(stat -c%s "$f" 2>/dev/null || echo 0)"
    files_json="$(jq -cn --argjson prev "$files_json" --arg source "$source" --argjson size "$sz" \
      '$prev + [{source: $source, size: $size}]')"
  done < <(matched_files)
  emit "$(jq -cn --argjson files "$files_json" '{event: "backfill", files: $files}')"
  : > "$STATE_DIR/.initialized"
fi

# recorder is the ONE process in this container (network_mode: none, no other
# route), so `restart: on-failure` at the Compose level is the whole supervision
# story -- there is no second process to keep alive.
while true; do
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    source="${f#/src/}"
    if [ "$MODE" = append ]; then
      ship_append "$f" "$source"
    else
      ship_snapshot "$f" "$source"
    fi
  done < <(matched_files)
  sleep "$POLL_SECONDS"
done
