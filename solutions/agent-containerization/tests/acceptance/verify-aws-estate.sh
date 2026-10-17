#!/usr/bin/env bash
# Acceptance test for Feature 03.1 (AWS estate provisioning, entitlement design, third-party record).
#
# STATIC ONLY. Every assertion is about what two records SAY. Nothing here calls AWS, uses a
# credential, starts a container or spends a model token, and it runs on a machine with no AWS
# access. A green run is NOT a proven perimeter: it cannot see whether the estate does what the
# records say. T10, T12, T13, T19 and T20 are Feature 03.4's, measured from inside a container
# against a live broker.
#
# Phase A: docs/records/aws-estate-entitlement.md -- required sections, numeric durations, the data
#          perimeter (no GAP: marker accepted -- criterion 4 blocks), the criterion-5 cells (GAP:
#          accepted only with a non-empty consequence), Q1's answer and consequence.
# Phase B: the AWS R14.1 record in docs/records/third-party-assessments.md -- every field, status
#          and constraint consistency, Summary Table row, T42 row, provisional traffic path.
# Phase C: publishability, scoped to the two AWS records only (a repo-wide 12-digit scan is red on
#          arrival: policy/allowlist.base.yaml carries a GCP project number).
# Phase D: standing guards for R6.4.2 / R6.2.2. BOTH PASS TRIVIALLY TODAY, because no AWS pack
#          exists yet; they become load-bearing at 03.3. A trivial pass is not a proven control.
# Phase E: the anchor's real consumer. scripts/lint-policy.sh accepts a probe pack citing
#          #r141-aws and refuses one citing an anchor that does not exist.
#
# No skip variable, following retry_cold_peer's reasoning.
#
# Requires: yq (mikefarah/yq), used by lint-policy.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PASSED=0
FAILED=0
pass() { echo "PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL: $1"; FAILED=$((FAILED + 1)); }
note() { echo "      $*"; }
phase() { echo; echo "=== Phase $1 -- $2"; }

ENT="docs/records/aws-estate-entitlement.md"
TPA="docs/records/third-party-assessments.md"

[ -f "$ENT" ] || { echo "verify-aws-estate: $ENT is missing" >&2; exit 1; }
[ -f "$TPA" ] || { echo "verify-aws-estate: $TPA is missing" >&2; exit 1; }

filled() { # <cell> -- non-empty, and not a placeholder
  local c="${1#"${1%%[![:space:]]*}"}"
  c="${c%"${c##*[![:space:]]}"}"
  case "$c" in
    ""|"—"|"-"|"TBD"|"n/a") return 1 ;;
    *pending*|*PENDING*)    return 1 ;;
    *)                      return 0 ;;
  esac
}

# sec <file> <heading-prefix> -- the body of the `## ` section whose heading starts with the prefix.
sec() {
  awk -v h="## $2" '
    /^## / { on = (index($0, h) == 1); next }
    on { print }
  ' "$1"
}

# fv <section-body> <field> -- the value cell of a `| Field | Value |` row, empty if absent.
fv() {
  printf '%s\n' "$1" | awk -v f="$2" '
    /^\|/ {
      line = $0
      sub(/^\| */, "", line); sub(/ *\|[ \t]*$/, "", line)
      i = index(line, " | ")
      if (i == 0) next
      k = substr(line, 1, i - 1); v = substr(line, i + 3)
      if (k == f) { print v; exit }
    }'
}

# table_rows <section-body> -- every `|` line that is not a separator.
table_rows() { printf '%s\n' "$1" | grep -E '^\|' | grep -vE '^\|[ -]*\|[ |-]*$' || true; }

# ---------------------------------------------------------------------------
phase A "the entitlement record ($ENT)"

REQUIRED_HEADINGS=(
  "Principal and permission set"
  "Write grants per profile"
  "Data perimeter"
  "Permission boundary"
  "Destructive-action denies"
  "CloudTrail attribution"
  "CloudTrail read access evidence"
  "Q1 — accounts and services, and the consequence"
  "What this record does not prove"
  "Criterion-to-evidence table"
)
for h in "${REQUIRED_HEADINGS[@]}"; do
  if grep -q "^## $h" "$ENT"; then
    pass "A1: section present: $h"
  else
    fail "A1: section missing: $h"
  fi
done

PS="$(sec "$ENT" "Principal and permission set")"
DUR="$(fv "$PS" "Session duration")"
if filled "$DUR" && printf '%s' "$DUR" | grep -qE '[0-9]+ *(minute|minutes|min|hour|hours|h|m)\b'; then
  pass "A2: session duration is a number ($DUR)"
else
  fail "A2: session duration is not stated as a number: '${DUR:-<absent>}'"
fi

# filled() on every Field|Value row of every Field|Value table, in every section.
BAD_CELLS=""
while IFS= read -r line; do
  inner="${line#\|}"; inner="${inner%\|}"
  k="${inner%% | *}"; v="${inner#* | }"
  k="${k#"${k%%[![:space:]]*}"}"; k="${k%"${k##*[![:space:]]}"}"
  case "$k" in Field|---*|"") continue ;; esac
  filled "$v" || BAD_CELLS="${BAD_CELLS} [$k]"
done < <(awk '
  /^\| *Field *\| *Value *\|/ { t = 1; next }
  /^\|/ { if (t) print; next }
  { t = 0 }
' "$ENT")
if [ -z "$BAD_CELLS" ]; then
  pass "A3: every Field|Value cell is filled"
else
  fail "A3: unfilled Field|Value cells:$BAD_CELLS"
fi

WG="$(sec "$ENT" "Write grants per profile")"
if printf '%s\n' "$WG" | grep -qE '^\| *Profile *\| *Permission *\|'; then
  pass "A4: the write-grant table is present (empty is valid, absent is not)"
else
  fail "A4: the write-grant table header is absent"
fi

DP="$(sec "$ENT" "Data perimeter")"
DP_ROWS="$(table_rows "$DP")"
for f in Mechanism Scope "Condition keys"; do
  v="$(fv "$DP" "$f")"
  if filled "$v"; then pass "A5: data perimeter '$f' is filled"; else fail "A5: data perimeter '$f' is not filled"; fi
done
if printf '%s\n' "$DP_ROWS" | grep -q 'GAP'; then
  fail "A6: the data perimeter carries a GAP marker -- criterion 4 blocks, a gap is a feature failure"
else
  pass "A6: the data perimeter carries no GAP marker"
fi
if printf '%s' "$(fv "$DP" "Condition keys")" | grep -qE 'aws:ResourceOrgID|aws:PrincipalOrgID'; then
  pass "A7: the data perimeter names aws:ResourceOrgID and/or aws:PrincipalOrgID"
else
  fail "A7: the data perimeter names neither aws:ResourceOrgID nor aws:PrincipalOrgID"
fi

for s in "Permission boundary" "Destructive-action denies"; do
  body="$(sec "$ENT" "$s")"
  rows="$(table_rows "$body")"
  bad=""
  while IFS= read -r line; do
    case "$line" in *GAP*) ;; *) continue ;; esac
    conseq="$(printf '%s' "$line" | sed -nE 's/.*GAP:[[:space:]]*([^|]*).*/\1/p')"
    filled "$conseq" || bad="yes"
  done <<< "$rows"
  if [ -z "$bad" ]; then
    pass "A8: '$s' -- any GAP carries a non-empty consequence"
  else
    fail "A8: '$s' -- a bare GAP with no consequence"
  fi
  [ -n "$(fv "$body" "Mechanism")" ] && pass "A8: '$s' names a mechanism" || fail "A8: '$s' names no mechanism"
done

# GAP is accepted nowhere else in the tables (the criterion-to-evidence table only describes the rule).
OTHER_GAP="$(awk '
  /^## / { keep = ($0 !~ /^## (Permission boundary|Destructive-action denies|Criterion-to-evidence table)/) }
  keep && /^\|/ && /GAP/ { print }
' "$ENT")"
if [ -z "$OTHER_GAP" ]; then
  pass "A9: no GAP marker in any table outside the two criterion-5 sections"
else
  fail "A9: GAP marker in a table outside the criterion-5 sections"
  note "$OTHER_GAP"
fi

CT="$(sec "$ENT" "CloudTrail read access evidence")"
for f in "Trail scope" "Query run" "Event observed"; do
  filled "$(fv "$CT" "$f")" && pass "A10: CloudTrail evidence '$f' is filled" || fail "A10: CloudTrail evidence '$f' is not filled"
done
DELAY="$(fv "$CT" "Event-to-visibility delay")"
if printf '%s' "$DELAY" | grep -qE '[0-9]+ *(second|seconds|s|minute|minutes|min)\b'; then
  pass "A11: event-to-visibility delay is a number ($DELAY)"
else
  fail "A11: event-to-visibility delay is not a number: '${DELAY:-<absent>}'"
fi

Q1="$(sec "$ENT" "Q1 — accounts and services")"
if printf '%s' "$Q1" | grep -q 'R6.4.3' && printf '%s' "$Q1" | grep -qi 'impractical' && printf '%s' "$Q1" | grep -q 'R6.3.6'; then
  pass "A12: Q1's answer and its consequence (R6.4.3 impractical, T13 rests on R6.3.6) are both present"
else
  fail "A12: Q1's consequence is incomplete"
fi

# ---------------------------------------------------------------------------
phase B "the AWS R14.1 record ($TPA)"

AWS_SEC="$(sec "$TPA" "R14.1 — Amazon Web Services")"
if [ -n "$AWS_SEC" ]; then pass "B1: the AWS R14.1 section is present"; else fail "B1: the AWS R14.1 section is absent"; fi

if grep -q '<a id="r141-aws"></a>' "$TPA"; then
  pass "B2: the explicit r141-aws anchor is present"
else
  fail "B2: the r141-aws anchor is absent"
fi

for f in "Party" "Role on the traffic path" "What it can observe" "Stated retention" "Deletion terms" \
         "Breach-notification path" "Assessment status" "Resulting constraint on use" "Date" "Source"; do
  filled "$(fv "$AWS_SEC" "$f")" && pass "B3: R14.1 field '$f' is filled" || fail "B3: R14.1 field '$f' is not filled"
done

STATUS="$(fv "$AWS_SEC" "Assessment status")"
CONSTRAINT="$(fv "$AWS_SEC" "Resulting constraint on use")"
if printf '%s' "$STATUS" | grep -qi 'incomplete'; then
  if filled "$CONSTRAINT" && [ "${#CONSTRAINT}" -ge 20 ]; then
    pass "B4: an Incomplete status carries a non-empty constraint on use"
  else
    fail "B4: an Incomplete status with an empty constraint on use"
  fi
else
  pass "B4: status is not Incomplete"
fi

ROLE="$(fv "$AWS_SEC" "Role on the traffic path")"
if printf '%s' "$ROLE" | grep -qi 'provisional' && printf '%s' "$ROLE" | grep -q '03.3'; then
  pass "B5: the traffic-path field is marked provisional and names 03.3 as the verifier"
else
  fail "B5: the traffic-path field is not marked provisional with 03.3 named"
fi

SUMMARY="$(sec "$TPA" "Summary Table")"
if printf '%s\n' "$SUMMARY" | grep -qE '^\| Amazon Web Services \|'; then
  pass "B6: the Summary Table has an AWS row"
else
  fail "B6: the Summary Table has no AWS row"
fi

T42="$(sec "$TPA" "T42 — Third-party traffic-path governance (re-inspection, Feature 03.1 SF-4)")"
if printf '%s\n' "$T42" | grep -qE '^\| Amazon Web Services \|'; then
  pass "B7: the 03.1 T42 section has an AWS row"
else
  fail "B7: the 03.1 T42 section is absent or has no AWS row"
fi

# ---------------------------------------------------------------------------
phase C "publishability (the two AWS records only)"

AWS_ONLY="$(mktemp)"
trap 'rm -f "$AWS_ONLY"' EXIT
{ cat "$ENT"; printf '%s\n' "$AWS_SEC"; printf '%s\n' "$T42"; } > "$AWS_ONLY"

c_check() { # <label> <ERE>
  local hits
  hits="$(grep -nE "$2" "$AWS_ONLY" || true)"
  if [ -z "$hits" ]; then pass "C: no $1"; else fail "C: $1 found"; printf '%s\n' "$hits" | head -3 | sed 's/^/      /'; fi
}
c_check "arn:aws"                        'arn:aws'
c_check "AKIA/ASIA key prefix"           '(AKIA|ASIA)[0-9A-Z]{8,}'
c_check "SSO directory id (d-xxxxxxxxxx)" '(^|[^0-9A-Za-z-])d-[0-9a-f]{10}([^0-9A-Za-z]|$)'
c_check "awsapps.com start-URL host"     'awsapps\.com'
c_check "12-digit run"                   '(^|[^0-9])[0-9]{12}([^0-9]|$)'

# ---------------------------------------------------------------------------
phase D "standing guards (trivial today; load-bearing from 03.3)"

AMZ="$(grep -rn '\*\.amazonaws\.com' policy packs profiles 2>/dev/null || true)"
if [ -z "$AMZ" ]; then pass "D1: no *.amazonaws.com in policy/, packs/ or profiles/ (R6.4.2) -- trivially true until 03.3"; else fail "D1: *.amazonaws.com found"; printf '%s\n' "$AMZ" | head -3 | sed 's/^/      /'; fi

KEYS="$(grep -rnE '(AKIA|ASIA)[0-9A-Z]{16}' images compose 2>/dev/null || true)"
if [ -z "$KEYS" ]; then pass "D2: no AKIA/ASIA key material in images/ or compose/ (R6.2.2) -- trivially true until 03.2"; else fail "D2: key material found"; printf '%s\n' "$KEYS" | head -3 | sed 's/^/      /'; fi

# ---------------------------------------------------------------------------
phase E "the anchor's real consumer (scripts/lint-policy.sh)"

command -v yq >/dev/null 2>&1 || { echo "verify-aws-estate: yq is required" >&2; exit 1; }

PROBE_DIR="packs/zz-aws-probe"
[ ! -e "$PROBE_DIR" ] || { echo "verify-aws-estate: $PROBE_DIR already exists; remove it before running" >&2; exit 1; }
cleanup() { rm -rf "$PROBE_DIR"; rm -f "$AWS_ONLY"; }
trap cleanup EXIT

expect() { # <want-exit> <fragment> <label> <cmd...>
  local want="$1" frag="$2" label="$3"; shift 3
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$label: expected exit $want, got $rc"; printf '%s\n' "$out" | head -5 | sed 's/^/      /'; return
  fi
  if [ -n "$frag" ] && ! printf '%s' "$out" | grep -qF -- "$frag"; then
    fail "$label: exit $want as expected, but the message did not name '$frag'"; printf '%s\n' "$out" | head -5 | sed 's/^/      /'; return
  fi
  pass "$label"
}

write_probe() { # <record>
  mkdir -p "$PROBE_DIR"
  yq eval ".name = \"zz-aws-probe\" | .description = \"probe\" | .third_parties = [{\"party\": \"Amazon Web Services\", \"record\": \"$1\"}]" \
    packs/github-cli/pack.yaml > "$PROBE_DIR/pack.yaml"
}

write_probe "$TPA#r141-aws"
expect 0 "well-formed pack manifest" "E1: a probe pack citing #r141-aws passes lint-policy.sh" bash scripts/lint-policy.sh

write_probe "$TPA#r141-aws-does-not-exist"
expect 1 'does not resolve -- no id="r141-aws-does-not-exist" anchor' \
  "E2: a probe pack citing a nonexistent anchor is refused by lint-policy.sh" bash scripts/lint-policy.sh

# ---------------------------------------------------------------------------
echo
echo "=== Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] || exit 1
