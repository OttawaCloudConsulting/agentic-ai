#!/usr/bin/env bash
# Proxy-hop trust anchors: offline CA and mediator listener certificates (01.3 SF-3).
#
# Creates the mediator CA on the OPERATOR HOST and issues the two listener server certificates
# the TLS proxy hops need -- one for `claude-net`, one for `agy-net`. `codex-net` is a plain
# HTTP CONNECT listener (01.1 SF-2: `codex` rejects an `https://`-scheme proxy URL at parse
# time) and gets no certificate.
#
# The CA private key never enters the mediator, never enters an image layer and never lands on
# an agent-reachable volume (criterion 9). Issuance is offline, here, by hand.
#
# Each listener certificate carries an `iPAddress` SAN for the mediator's static address on that
# agent's network, because Interface Contract 2 points the agent at
# `https://<mediator addr>:3128` -- an IP literal. A dNSName SAN or a CN alone is not honoured by
# modern TLS stacks, and the tempting repair for the resulting handshake failure is to disable
# verification at the agent, which would give up the server authentication the TLS hop exists
# for. Issuance therefore verifies its own output before it reports success.
#
# The static addresses are SF-4's (`ipam` blocks in compose/compose.yaml). They are INPUTS here,
# never hardcoded. The address used at issuance is recorded next to the certificate so the
# renewal form needs no arguments.
#
# 01.6 extends this script with per-agent CLIENT certificates (`CN=<agent>`) issued by this same
# CA and turns on client-certificate verification. It does not create a second CA and does not
# define a second lifecycle -- see mediator/identity/README.md.
#
# Modes:
#   bash scripts/issue-identity.sh ca [--force]
#       Create the CA key pair. Refuses to overwrite an existing CA without --force, because
#       replacing the CA invalidates every certificate under it (that is the revocation path).
#
#   bash scripts/issue-identity.sh listener <claude|agy> --ip <addr> [--force]
#       Issue that network's listener certificate against <addr>. Records <addr>.
#
#   bash scripts/issue-identity.sh <claude|agy>
#       Renewal. Re-issues against the recorded address. Followed by a mediator restart.
#
#   bash scripts/issue-identity.sh status
#       Show what exists, its subject, SAN and expiry. Reads nothing secret.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDENTITY_DIR="$REPO_ROOT/mediator/identity"
CA_DIR="$IDENTITY_DIR/ca"
LISTENER_DIR="$IDENTITY_DIR/listeners"

CA_KEY="$CA_DIR/mediator-ca.key"
CA_CRT="$CA_DIR/mediator-ca.crt"
CA_SRL="$CA_DIR/mediator-ca.srl"

# Bounded validity (R8.8's "defined lifecycle", defined here because 01.3 issues first).
CA_DAYS=730
LISTENER_DAYS=365

CA_SUBJECT="/CN=agent-pod mediator CA"
# Listener subjects are deliberately NOT `CN=<agent>`: that form is 01.6's CLIENT certificate
# subject, and T34 is a refusal to accept one agent's client subject on another agent's
# listener. Two certificate roles sharing a subject form would make that check ambiguous.
listener_subject() { printf '/CN=mediator-listener-%s' "$1"; }

# `codex` is absent by construction, not by omission.
TLS_AGENTS=(claude agy)

fail() { echo "issue-identity: FAIL: $*" >&2; exit 1; }
note() { echo "issue-identity: $*" >&2; }

require_openssl() {
  command -v openssl >/dev/null 2>&1 || fail "openssl not found on PATH"
}

is_tls_agent() {
  local a="$1" x
  for x in "${TLS_AGENTS[@]}"; do [[ "$x" == "$a" ]] && return 0; done
  return 1
}

check_agent() {
  local a="$1"
  if [[ "$a" == "codex" ]]; then
    fail "codex has no TLS proxy hop and needs no listener certificate (01.1 SF-2: it rejects an https:// proxy URL at parse time). Its listener is plain HTTP CONNECT."
  fi
  is_tls_agent "$a" || fail "unknown agent: $a (expected one of: ${TLS_AGENTS[*]})"
}

check_ipv4() {
  local ip="$1" o
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || fail "not an IPv4 address: $ip"
  IFS='.' read -r -a _octets <<< "$ip"
  for o in "${_octets[@]}"; do
    (( o >= 0 && o <= 255 )) || fail "not an IPv4 address: $ip"
  done
}

# ---------------------------------------------------------------------------- CA

create_ca() {
  local force="$1"
  mkdir -p "$CA_DIR"
  if [[ -e "$CA_KEY" || -e "$CA_CRT" ]]; then
    [[ "$force" == "yes" ]] || fail "a CA already exists at $CA_DIR. Re-issuing it revokes every certificate under it (README.md, Revocation). Pass --force if that is what you mean."
    note "--force: replacing the existing CA. Every listener certificate under it is now invalid; re-issue each one."
    rm -f "$CA_SRL"
  fi

  ( umask 077
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$CA_KEY" 2>/dev/null )
  openssl req -x509 -new -key "$CA_KEY" -sha256 -days "$CA_DAYS" \
    -subj "$CA_SUBJECT" -extensions v3_ca -config <(cat <<CFG
[req]
distinguished_name = dn
prompt = no
[dn]
CN = agent-pod mediator CA
[v3_ca]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
CFG
) -out "$CA_CRT"

  note "CA created: $CA_CRT (subject $CA_SUBJECT, ${CA_DAYS}d)"
  note "The CA private key stays on this host. It is never mounted into the mediator, never a Compose secret, never in an image layer."
}

require_ca() {
  [[ -f "$CA_KEY" && -f "$CA_CRT" ]] || fail "no CA at $CA_DIR. Run: bash scripts/issue-identity.sh ca"
}

# ----------------------------------------------------------------- listener certificates

issue_listener() {
  local agent="$1" ip="$2" force="$3"
  check_agent "$agent"
  check_ipv4 "$ip"
  require_ca
  mkdir -p "$LISTENER_DIR"

  local key="$LISTENER_DIR/${agent}-listener.key"
  local crt="$LISTENER_DIR/${agent}-listener.crt"
  local ipfile="$LISTENER_DIR/${agent}-listener.ip"
  local csr ext

  # An existing certificate for a DIFFERENT address is not a conflict to refuse -- the mediator's
  # static address changed and the old certificate can no longer match it. Re-issue. Refusing here
  # and pointing at the renewal form would be a trap: renewal reuses the RECORDED address, so the
  # operator would get a certificate for the old address and a handshake failure at the agent.
  if [[ -e "$crt" && "$force" != "yes" && "$force" != "renew" ]]; then
    if [[ -f "$ipfile" && "$(cat "$ipfile")" == "$ip" ]]; then
      fail "$crt already exists for $ip. Renew it with: bash scripts/issue-identity.sh $agent"
    fi
    note "re-issuing $agent listener: recorded address $([[ -f "$ipfile" ]] && cat "$ipfile" || echo unknown) -> $ip"
  fi

  csr="$(mktemp)"; ext="$(mktemp)"
  cat > "$ext" <<EXT
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = IP:$ip
subjectKeyIdentifier = hash
EXT

  ( umask 077
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$key" 2>/dev/null )
  openssl req -new -key "$key" -subj "$(listener_subject "$agent")" -out "$csr"
  openssl x509 -req -in "$csr" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -CAserial "$CA_SRL" \
    -days "$LISTENER_DAYS" -sha256 -extfile "$ext" -out "$crt" 2>/dev/null
  rm -f "$csr" "$ext"

  printf '%s\n' "$ip" > "$ipfile"

  verify_listener "$agent" "$ip"
  note "issued: $crt (subject $(listener_subject "$agent"), SAN IP:$ip, ${LISTENER_DAYS}d)"
  note "restart the mediator for it to take effect"
}

# The assertion that catches the failure this sub-feature exists to prevent: a certificate that
# chains but whose SAN does not match the authority the agent's proxy URL names. The agent-side
# repair for that is disabling TLS verification, which silently gives up the server
# authentication the hop is for.
verify_listener() {
  local agent="$1" ip="$2"
  local crt="$LISTENER_DIR/${agent}-listener.crt"

  openssl verify -CAfile "$CA_CRT" "$crt" >/dev/null 2>&1 \
    || fail "$crt does not verify against $CA_CRT"

  # The SAN and EKU checks read `x509 -text` rather than `x509 -ext`: LibreSSL (which is
  # /usr/bin/openssl on macOS) has no -ext, and it fails silently enough that the check would
  # report a missing extension that is in fact present.
  local san eku
  san="$(cert_extension_value "$crt" "X509v3 Subject Alternative Name")"
  eku="$(cert_extension_value "$crt" "X509v3 Extended Key Usage")"

  printf '%s' "$san" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -qxF "IP Address:$ip" \
    || fail "$crt carries no iPAddress SAN for $ip (SAN: ${san:-none}) -- the agent's proxy URL is an IP literal and would fail verification"

  printf '%s' "$eku" | grep -qF "TLS Web Server Authentication" \
    || fail "$crt is missing serverAuth extended key usage"

  # Strongest available form of the same assertion: the TLS stack's own IP matcher. Present in
  # OpenSSL >= 1.1.0, absent in LibreSSL, so it is a bonus check and not the one relied on.
  if openssl verify -help 2>&1 | grep -qF -- "-verify_ip"; then
    openssl verify -CAfile "$CA_CRT" -verify_ip "$ip" "$crt" >/dev/null 2>&1 \
      || fail "$crt does not satisfy the TLS stack's IP match for $ip"
  fi
}

# Print one X.509 extension's value, portably. `openssl x509 -ext` does not exist in LibreSSL.
cert_extension_value() {
  local crt="$1" name="$2"
  openssl x509 -in "$crt" -noout -text | awk -v want="$name" '
    index($0, want) && index($0, ":") { found = 1; next }
    found { sub(/^ +/, ""); sub(/ +$/, ""); print; exit }
  '
}

renew_listener() {
  local agent="$1"
  check_agent "$agent"
  local ipfile="$LISTENER_DIR/${agent}-listener.ip"
  [[ -f "$ipfile" ]] || fail "no recorded address for $agent. Issue it first: bash scripts/issue-identity.sh listener $agent --ip <addr>"
  local ip; ip="$(cat "$ipfile")"
  note "renewing $agent listener against recorded address $ip"
  issue_listener "$agent" "$ip" renew
}

# ---------------------------------------------------------------------------- status

status() {
  if [[ -f "$CA_CRT" ]]; then
    echo "CA:  $CA_CRT"
    echo "     subject: $(openssl x509 -in "$CA_CRT" -noout -subject | sed 's/^subject= *//')"
    echo "     expires: $(openssl x509 -in "$CA_CRT" -noout -enddate | sed 's/^notAfter=//')"
    if [[ -f "$CA_KEY" ]]; then
      echo "     private key: present on this host (correct -- it must never leave it)"
    else
      echo "     private key: ABSENT -- no further certificates can be issued"
    fi
  else
    echo "CA:  none. Run: bash scripts/issue-identity.sh ca"
  fi

  local agent crt ipfile
  for agent in "${TLS_AGENTS[@]}"; do
    crt="$LISTENER_DIR/${agent}-listener.crt"
    ipfile="$LISTENER_DIR/${agent}-listener.ip"
    if [[ -f "$crt" ]]; then
      echo "listener $agent: $crt"
      echo "     subject: $(openssl x509 -in "$crt" -noout -subject | sed 's/^subject= *//')"
      echo "     SAN:     $(cert_extension_value "$crt" "X509v3 Subject Alternative Name")"
      echo "     expires: $(openssl x509 -in "$crt" -noout -enddate | sed 's/^notAfter=//')"
      [[ -f "$ipfile" ]] && echo "     issued against: $(cat "$ipfile")"
      # A certificate left over from a previous CA still looks well-formed. Mounting one gives the
      # mediator a certificate the agents' trust anchor cannot chain, which presents as a handshake
      # failure at the agent rather than as anything naming the real cause.
      if openssl verify -CAfile "$CA_CRT" "$crt" >/dev/null 2>&1; then
        echo "     chains to the current CA: yes"
      else
        echo "     chains to the current CA: NO -- re-issue it: bash scripts/issue-identity.sh $agent"
      fi
    else
      echo "listener $agent: none"
    fi
  done
  echo "listener codex: none by design -- plain HTTP CONNECT, no TLS hop (01.1 SF-2)"
}

# ---------------------------------------------------------------------------- arguments

require_openssl

[[ $# -gt 0 ]] || { sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 1; }

MODE="$1"; shift
FORCE="no"
IP=""
AGENT=""

case "$MODE" in
  -h|--help)
    sed -n '2,36p' "${BASH_SOURCE[0]}"; exit 0 ;;

  status)
    status; exit 0 ;;

  ca)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --force) FORCE="yes"; shift ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    create_ca "$FORCE" ;;

  listener)
    AGENT="${1:-}"; [[ -n "$AGENT" ]] || fail "listener needs an agent name"
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --ip)    IP="${2:?--ip needs a value}"; shift 2 ;;
        --force) FORCE="yes"; shift ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    [[ -n "$IP" ]] || fail "listener needs --ip <addr> -- the mediator's static address on ${AGENT}-net (compose/compose.yaml ipam, SF-4)"
    issue_listener "$AGENT" "$IP" "$FORCE" ;;

  *)
    # Renewal form: `issue-identity.sh <name>`
    [[ $# -eq 0 ]] || fail "unexpected arguments after '$MODE'"
    renew_listener "$MODE" ;;
esac
