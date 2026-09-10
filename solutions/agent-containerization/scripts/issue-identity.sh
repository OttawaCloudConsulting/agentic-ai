#!/usr/bin/env bash
# Proxy-hop trust anchors: offline CA and mediator listener certificates (01.3 SF-3).
#
# Creates the mediator CA on the OPERATOR HOST and issues THREE listener certificates, and the
# third one is not a proxy hop. `claude-net` and `agy-net` get server certificates for their TLS
# hops. `codex-net` is a plain HTTP CONNECT listener (01.1 SF-2: `codex` rejects an `https://`
# -scheme proxy URL at parse time) and opens no TLS to the mediator -- but its listener still
# PEEKS the ClientHello, and Squid's peek stage needs a bumping certificate to exist at all.
# Verified at the 01.3 SF-6 build: without `tls-cert=` the port parses and then silently declines
# to bump ("Will not bump SSL ... due to TLS initialization failure"), the SNI control never runs,
# and even an allowlisted request fails. See the feature plan, Deviation 5.
#
# The codex certificate is never presented on an allowed path -- peek+splice hands the origin's
# own chain through untouched -- and `codex` neither trusts nor validates it. It is a Squid
# requirement, not a hop, and nothing about `codex` trusting no mediator CA changes.
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
# 01.6 SF-2 added per-agent CLIENT certificates (`CN=<agent>`) issued by this same CA, and
# turned on client-certificate verification for the agents whose listener declares it. There is
# no second CA and no second lifecycle -- see mediator/identity/README.md.
#
# A client certificate's subject is the RESOLVED POLICY's `identity` value for that agent, not a
# name chosen here, and the `client` mode validates against the resolved artifact's `client_auth`
# rather than against the agent arrays below: issuance and enforcement then cannot disagree about
# which agents present a certificate. The listener subject stays `CN=mediator-listener-<agent>`
# for the reason given above -- T34 is a refusal to accept one agent's client subject on another
# agent's listener, and two certificate roles sharing a subject form would make that ambiguous.
#
# Modes:
#   bash scripts/issue-identity.sh ca [--force]
#       Create the CA key pair. Refuses to overwrite an existing CA without --force, because
#       replacing the CA invalidates every certificate under it (that is the revocation path).
#
#   bash scripts/issue-identity.sh listener <claude|codex|agy> --ip <addr> [--force]
#       Issue that network's listener certificate against <addr>. Records <addr>.
#
#   bash scripts/issue-identity.sh client <claude|codex|agy> [--force]
#       Issue that agent's CLIENT certificate: subject `CN=<agent>` from the resolved policy's
#       `identity`, clientAuth EKU, no SAN. Refused unless that agent's resolved listener
#       declares `client_auth: mtls`. Followed by a mediator restart AND an agent restart --
#       the agent re-reads the key pair from its Compose secret at start.
#
#   bash scripts/issue-identity.sh credential <claude|codex|agy> [--force]
#       Issue that agent's PROXY CREDENTIAL: a random password for the username taken from the
#       resolved policy's `identity`. Refused unless that agent's resolved listener declares
#       `client_auth: proxy_auth`. Writes the plaintext for that agent alone and rebuilds the
#       shared htpasswd the mediator verifies against. Followed by a mediator restart AND that
#       agent's restart -- the agent reads the plaintext from its Compose secret at start and
#       splices it into its proxy URL.
#
#   bash scripts/issue-identity.sh credential --rebuild
#       Rebuild the htpasswd from the plaintexts still on disk, issuing nothing. This is the
#       REVOCATION path: delete an agent's `.cred`, rebuild, restart the mediator. Without it a
#       deleted plaintext would leave its htpasswd line standing and the credential would go on
#       working, which is a revocation that silently does not revoke.
#
#   bash scripts/issue-identity.sh <claude|codex|agy>
#       Renewal of that agent's LISTENER certificate. Re-issues against the recorded address.
#       Followed by a mediator restart. Client certificates renew through `client --force` and
#       proxy credentials through `credential --force`.
#
#   bash scripts/issue-identity.sh status
#       Show what exists, its subject, SAN and expiry -- listener and client certificates
#       alike, and which agents hold a proxy credential. Reads nothing secret: a credential is
#       reported as present or absent and by its username, never by its value.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDENTITY_DIR="$REPO_ROOT/mediator/identity"
CA_DIR="$IDENTITY_DIR/ca"
LISTENER_DIR="$IDENTITY_DIR/listeners"
CLIENT_DIR="$IDENTITY_DIR/clients"
# 01.6 SF-3. Proxy credentials for the agents whose clients cannot present a certificate but
# WILL send a credential (SF-1 measured both `codex` and `agy` do, from proxy-URL userinfo).
# Plaintext per agent -- the agent needs the value, not a hash -- plus the htpasswd the mediator
# verifies against. Covered by mediator/identity/.gitignore's deny-all like every sibling.
CREDENTIAL_DIR="$IDENTITY_DIR/credentials"

# The resolved artifact the `client` mode reads its subject and its permission from. The DEFAULT
# profile's, named explicitly: it is the artifact the pod runs under, and the test profiles are
# compiled for harnesses that issue nothing. `mediator/identity/.gitignore` is `*` with two
# exceptions, so clients/ is already covered and needs no entry of its own.
RESOLVED_POLICY="$REPO_ROOT/policy/resolved/default.yaml"

CA_KEY="$CA_DIR/mediator-ca.key"
CA_CRT="$CA_DIR/mediator-ca.crt"
CA_SRL="$CA_DIR/mediator-ca.srl"

# Bounded validity (R8.8's "defined lifecycle", defined here because 01.3 issues first).
CA_DAYS=730
LISTENER_DAYS=365
# The same bound as a listener certificate, deliberately: one lifecycle, one renewal cadence,
# one expiry to watch. A client certificate expiring is a TOTAL outage for its agent rather than
# a degradation -- required-mode `clientca=` refuses at the handshake, before Squid has a request
# to log -- so `status` reports both kinds and the README says what the silence means.
CLIENT_DAYS=365

CA_SUBJECT="/CN=agent-pod mediator CA"
# Listener subjects are deliberately NOT `CN=<agent>`: that form is 01.6's CLIENT certificate
# subject, and T34 is a refusal to accept one agent's client subject on another agent's
# listener. Two certificate roles sharing a subject form would make that check ambiguous.
listener_subject() { printf '/CN=mediator-listener-%s' "$1"; }
# The client subject is NOT chosen here. It is the resolved policy's `identity` value for this
# agent -- the same token the `acl <name> user_cert CN <identity>` binding rule matches and the
# same token the audit line's `agent` field carries. One identity across issuance, policy,
# enforcement and audit, rather than four kept in step by hand (01.6 Decision 2).
client_subject() { printf '/CN=%s' "$1"; }

# Agents whose listener terminates a TLS PROXY HOP. `codex` is absent by construction: its hop
# is plain HTTP. It appears in BUMP_AGENTS below instead, which is a different role.
TLS_AGENTS=(claude agy)
# Agents whose listener PEEKS, and therefore needs a bumping certificate regardless of whether
# its hop is TLS. All three: claude and agy peek on their inner cascade listeners, codex on its
# single one. The two lists overlap because the two roles are independent.
BUMP_AGENTS=(claude agy codex)

fail() { echo "issue-identity: FAIL: $*" >&2; exit 1; }
note() { echo "issue-identity: $*" >&2; }

require_openssl() {
  command -v openssl >/dev/null 2>&1 || fail "openssl not found on PATH"
}

check_agent() {
  local a="$1" x
  for x in "${BUMP_AGENTS[@]}"; do [[ "$x" == "$a" ]] && return 0; done
  fail "unknown agent: $a (expected one of: ${BUMP_AGENTS[*]})"
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

# ------------------------------------------------------------------- client certificates

# The resolved policy is the authority on WHICH agents present a client certificate, and it is
# read here rather than matched against BUMP_AGENTS/TLS_AGENTS. `check_agent` validates against
# BUMP_AGENTS, which is every agent -- so `client codex` would be accepted on the strength of a
# list that exists for a different reason (edge case 5). Reading `client_auth` instead means
# issuance and enforcement cannot disagree: the mediator renders `clientca=` from the same field.
require_mtls_agent() {
  local agent="$1" mode
  command -v yq >/dev/null 2>&1 \
    || fail "yq is required to read $RESOLVED_POLICY (https://github.com/mikefarah/yq)"
  [[ -f "$RESOLVED_POLICY" ]] \
    || fail "no resolved policy at $RESOLVED_POLICY. Compile one first: bash scripts/compile-policy-build.sh"
  [[ "$(yq eval ".agents | has(\"$agent\")" "$RESOLVED_POLICY")" == "true" ]] \
    || fail "$RESOLVED_POLICY declares no agent '$agent'"
  mode="$(yq eval ".agents.${agent}.listener.client_auth" "$RESOLVED_POLICY")"
  [[ "$mode" == "mtls" ]] \
    || fail "agents.${agent}.listener.client_auth is '$mode' in $RESOLVED_POLICY, not 'mtls'. That agent's listener requests no client certificate, so one issued here would have no consumer. Change the profile and recompile if that is the intent."
}

# The subject is the policy's `identity`, not the agent key -- they are the same value in every
# shipped profile and the compiler emits `identity: <agent>`, but reading the field is what makes
# Decision 2 true rather than coincidental.
client_identity() {
  local agent="$1" id
  id="$(yq eval ".agents.${agent}.identity" "$RESOLVED_POLICY")"
  [[ -n "$id" && "$id" != "null" ]] \
    || fail "$RESOLVED_POLICY: agents.${agent} carries no 'identity' value to use as the certificate subject"
  # It becomes an X.509 subject and then an `acl ... user_cert CN <value>` term in squid.conf.
  # Refused at the boundary rather than trusted from the artifact, the same way the renderer
  # refuses a hostname that is not one.
  [[ "$id" =~ ^[A-Za-z0-9_-]+$ ]] \
    || fail "$RESOLVED_POLICY: agents.${agent}.identity '$id' is not a bare identifier; it becomes a certificate subject and a squid.conf ACL term"
  printf '%s' "$id"
}

issue_client() {
  local agent="$1" force="$2"
  check_agent "$agent"
  require_ca
  require_mtls_agent "$agent"
  mkdir -p "$CLIENT_DIR"

  local id; id="$(client_identity "$agent")"
  local key="$CLIENT_DIR/${agent}-client.key"
  local crt="$CLIENT_DIR/${agent}-client.crt"
  local csr ext

  # No `.ip` counterpart: a client certificate carries no SAN, so there is no address to record
  # and nothing for a bare-word renewal to reuse. Renewal is `client <agent> --force`.
  if [[ -e "$crt" && "$force" != "yes" ]]; then
    fail "$crt already exists. Re-issue it with: bash scripts/issue-identity.sh client $agent --force"
  fi

  csr="$(mktemp)"; ext="$(mktemp)"
  # `clientAuth` ONLY, and no `keyEncipherment`: the disjoint EKU is the second, independent bar
  # behind the subject check. A listener certificate must not pass as a client certificate and a
  # client certificate must not pass as a listener certificate, and the subject mismatch alone
  # already refuses both directions -- this refuses them again at the TLS stack rather than at
  # the ACL. No subjectAltName: there is no name or address being asserted, only an identity.
  cat > "$ext" <<EXT
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
EXT

  ( umask 077
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$key" 2>/dev/null )
  openssl req -new -key "$key" -subj "$(client_subject "$id")" -out "$csr"
  openssl x509 -req -in "$csr" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -CAserial "$CA_SRL" \
    -days "$CLIENT_DAYS" -sha256 -extfile "$ext" -out "$crt" 2>/dev/null
  rm -f "$csr" "$ext"

  verify_client "$agent" "$id"
  note "issued: $crt (subject $(client_subject "$id"), clientAuth, no SAN, ${CLIENT_DAYS}d)"
  note "restart the mediator AND the ${agent} container -- the agent re-reads the key pair from its Compose secret at start"
}

# The counterpart to verify_listener, asserting the three properties enforcement depends on:
# the chain (or `clientca=` refuses it), the subject (or the `user_cert CN` binding rule refuses
# it, which is T34's literal case pointed at the wrong agent), and the EKU (the second bar).
# Issuance verifies its own output before it reports success, for the reason SF-3 gave: the
# tempting repair for a handshake failure at the agent is to disable verification.
verify_client() {
  local agent="$1" id="$2"
  local crt="$CLIENT_DIR/${agent}-client.crt"

  openssl verify -CAfile "$CA_CRT" "$crt" >/dev/null 2>&1 \
    || fail "$crt does not verify against $CA_CRT"

  local subj eku san
  subj="$(openssl x509 -in "$crt" -noout -subject | sed 's/^subject= *//')"
  printf '%s' "$subj" | grep -qE "CN[[:space:]]*=[[:space:]]*${id}\$" \
    || fail "$crt subject is '$subj', expected CN=${id} -- the mediator's binding rule matches the resolved policy's identity value and would refuse this certificate on ${agent}'s own listener"

  eku="$(cert_extension_value "$crt" "X509v3 Extended Key Usage")"
  printf '%s' "$eku" | grep -qF "TLS Web Client Authentication" \
    || fail "$crt is missing clientAuth extended key usage (EKU: ${eku:-none})"
  printf '%s' "$eku" | grep -qF "TLS Web Server Authentication" \
    && fail "$crt also carries serverAuth. The two roles are deliberately disjoint: a client certificate that can serve is a listener certificate in disguise."

  san="$(cert_extension_value "$crt" "X509v3 Subject Alternative Name")"
  [[ -z "$san" ]] \
    || fail "$crt carries a subjectAltName ($san). A client certificate asserts an identity, not a name or an address."
}

# -------------------------------------------------------------------- proxy credentials (SF-3)

# The proxy_auth counterpart to require_mtls_agent, and it reads the same field for the same
# reason: the resolved policy is the authority on which agents authenticate and how, so issuance
# and enforcement cannot disagree. A credential issued for an agent whose listener does not ask
# for one has no consumer, and one NOT issued for an agent whose listener does ask is a total
# outage for that agent -- 407 on every request.
require_proxy_auth_agent() {
  local agent="$1" mode
  command -v yq >/dev/null 2>&1 \
    || fail "yq is required to read $RESOLVED_POLICY (https://github.com/mikefarah/yq)"
  [[ -f "$RESOLVED_POLICY" ]] \
    || fail "no resolved policy at $RESOLVED_POLICY. Compile one first: bash scripts/compile-policy-build.sh"
  [[ "$(yq eval ".agents | has(\"$agent\")" "$RESOLVED_POLICY")" == "true" ]] \
    || fail "$RESOLVED_POLICY declares no agent '$agent'"
  mode="$(yq eval ".agents.${agent}.listener.client_auth" "$RESOLVED_POLICY")"
  [[ "$mode" == "proxy_auth" ]] \
    || fail "agents.${agent}.listener.client_auth is '$mode' in $RESOLVED_POLICY, not 'proxy_auth'. That agent's listener asks for no proxy credential, so one issued here would have no consumer. Change the profile and recompile if that is the intent."
}

# The htpasswd the mediator verifies against, rebuilt from the plaintexts on disk EVERY time --
# never appended to. Append-only would make deletion of a plaintext a no-op at the enforcement
# point, so the documented revocation path (delete, rebuild, restart) would silently not revoke.
#
# `openssl passwd -apr1` and not bcrypt: glibc's crypt(3) has no bcrypt, and basic_ncsa_auth
# hashes through crypt(3). Measured against the shipped mediator image at the SF-3 build (P9,
# docs/records/mediator-selection.md) rather than assumed from the helper's documentation.
rebuild_htpasswd() {
  local out="$CREDENTIAL_DIR/htpasswd" agent cred userinfo n=0
  mkdir -p "$CREDENTIAL_DIR"
  local tmp; tmp="$(mktemp)"
  for agent in "${BUMP_AGENTS[@]}"; do
    cred="$CREDENTIAL_DIR/${agent}.cred"
    [[ -f "$cred" ]] || continue
    # The username comes from the file, not from the policy: the file IS the record of what was
    # issued, and hashing a policy-derived username against a file-derived password would let the
    # two halves of one credential disagree after a profile edit. `credential <agent>` is what
    # re-reconciles them, and it verifies the username against the policy when it does.
    userinfo="$(tr -d '\r\n' < "$cred")"
    [[ "$userinfo" == *:* ]] \
      || fail "$cred is not '<username>:<password>'. Re-issue it: bash scripts/issue-identity.sh credential $agent --force"
    printf '%s:%s\n' "${userinfo%%:*}" "$(openssl passwd -apr1 "${userinfo#*:}")" >> "$tmp"
    n=$(( n + 1 ))
  done
  ( umask 077; cp "$tmp" "$out" )
  rm -f "$tmp"
  note "htpasswd: $out rebuilt with ${n} credential(s)"
  note "restart the mediator for it to take effect -- basic_ncsa_auth reads the file at start and Squid caches accepted credentials (credentialsttl)"
}

issue_credential() {
  local agent="$1" force="$2"
  check_agent "$agent"
  require_proxy_auth_agent "$agent"
  mkdir -p "$CREDENTIAL_DIR"

  local id; id="$(client_identity "$agent")"
  local cred="$CREDENTIAL_DIR/${agent}.cred"

  if [[ -e "$cred" && "$force" != "yes" ]]; then
    fail "$cred already exists. Re-issue it with: bash scripts/issue-identity.sh credential $agent --force"
  fi

  # The file holds `<username>:<password>` -- the whole userinfo string, not just the secret half.
  # The agent's entrypoint splices this verbatim into its proxy URL, so it derives no username of
  # its own. That matters: the username is the RESOLVED POLICY's `identity`, and the only agent-
  # side token that resembles it is the image-baked `AGENT_NAME`. They are equal in every shipped
  # profile and nothing keeps them equal, so deriving it there would put a silent wrong-username
  # 407 one profile edit away. Issuance writes it; delivery does not guess it.
  #
  # Hex password, not base64 or a passphrase alphabet: the delivery surface is a URL, and any
  # character needing percent-encoding would produce a wrong-credential failure whose symptom
  # names neither the encoding nor the URL. 24 bytes of `openssl rand` is 192 bits.
  ( umask 077; printf '%s:%s\n' "$id" "$(openssl rand -hex 24)" > "$cred" )

  verify_credential "$agent" "$id"
  rebuild_htpasswd
  note "issued: $cred (username ${id}, 192-bit random, no expiry -- rotation is re-issue)"
  note "restart the mediator AND the ${agent} container -- the agent reads this value from its Compose secret at start and splices it into its proxy URL"
}

# Issuance verifies its own output, as the certificate paths do. The property is that the hash
# the mediator will verify against actually accepts the plaintext the agent will send -- a
# mismatch here is a 407 on every request from that agent, and the audit line for it says
# `identity_source: listener` rather than anything naming a credential.
verify_credential() {
  local agent="$1" id="$2"
  local cred="$CREDENTIAL_DIR/${agent}.cred" userinfo plain hash
  userinfo="$(tr -d '\r\n' < "$cred")"
  [[ -n "$userinfo" ]] || fail "$cred is empty"
  # `<username>:<hex password>`, and the username must be THIS agent's policy identity -- the
  # value the mediator's `acl <name> proxy_auth <identity>` term matches. A file naming another
  # agent would authenticate as that agent, which is the T34 case one credential form over.
  [[ "$userinfo" =~ ^[A-Za-z0-9_-]+:[0-9a-f]+$ ]] \
    || fail "$cred is not '<username>:<hex password>'. It is spliced into a proxy URL as userinfo, where any character needing percent-encoding becomes a wrong-credential failure."
  [[ "${userinfo%%:*}" == "$id" ]] \
    || fail "$cred names username '${userinfo%%:*}', but ${agent}'s identity in $RESOLVED_POLICY is '$id'. The mediator matches the policy value, so this credential would be refused."
  plain="${userinfo#*:}"
  hash="$(openssl passwd -apr1 "$plain")"
  [[ "$(openssl passwd -apr1 -salt "$(printf '%s' "$hash" | cut -d'$' -f3)" "$plain")" == "$hash" ]] \
    || fail "openssl passwd -apr1 is not reproducible on this host; the htpasswd would not accept ${id}'s credential"
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
  for agent in "${BUMP_AGENTS[@]}"; do
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
  # Client certificates, reported alongside the listener certificates and for a sharper reason:
  # an expired client certificate is a TOTAL outage for its agent, and it looks exactly like a
  # cert-less refusal -- the connection dies at the handshake, before Squid has a request to log,
  # so the audit trail is silent. Without an expiry visible here the 365-day bound is a trap
  # (01.6 edge case 3). The diagnostic surface that IS populated is the mediator's own cache_log.
  local ccrt
  for agent in "${BUMP_AGENTS[@]}"; do
    ccrt="$CLIENT_DIR/${agent}-client.crt"
    if [[ -f "$ccrt" ]]; then
      echo "client $agent: $ccrt"
      echo "     subject: $(openssl x509 -in "$ccrt" -noout -subject | sed 's/^subject= *//')"
      echo "     EKU:     $(cert_extension_value "$ccrt" "X509v3 Extended Key Usage")"
      echo "     expires: $(openssl x509 -in "$ccrt" -noout -enddate | sed 's/^notAfter=//')"
      if openssl verify -CAfile "$CA_CRT" "$ccrt" >/dev/null 2>&1; then
        echo "     chains to the current CA: yes"
      else
        echo "     chains to the current CA: NO -- re-issue it: bash scripts/issue-identity.sh client $agent --force"
      fi
    else
      echo "client $agent: none"
    fi
  done
  # Proxy credentials (01.6 SF-3). Reported by PRESENCE and USERNAME only -- the value never
  # reaches this output. There is no expiry to report: a basic credential has none, so rotation
  # is re-issue rather than renewal, which is why `status` reports whether the htpasswd the
  # mediator verifies against actually carries a line for this agent. A plaintext on disk with
  # no htpasswd line is an agent that will be answered 407 on every request.
  local cred hpw="$CREDENTIAL_DIR/htpasswd"
  for agent in "${BUMP_AGENTS[@]}"; do
    cred="$CREDENTIAL_DIR/${agent}.cred"
    if [[ -f "$cred" ]]; then
      echo "credential $agent: $cred"
      echo "     username: $(client_identity "$agent" 2>/dev/null || echo '(no identity in the resolved policy)')"
      if [[ -f "$hpw" ]] && grep -q "^$(client_identity "$agent" 2>/dev/null):" "$hpw" 2>/dev/null; then
        echo "     in the mediator htpasswd: yes"
      else
        echo "     in the mediator htpasswd: NO -- rebuild it: bash scripts/issue-identity.sh credential --rebuild"
      fi
    else
      echo "credential $agent: none"
    fi
  done
  echo "note: the codex certificate is a BUMPING certificate for its peek stage, not a proxy hop."
  echo "      codex opens no TLS to the mediator and validates nothing it presents (Deviation 5)."
  echo "      a client certificate is issued only for an agent whose resolved listener declares"
  echo "      client_auth: mtls, and a proxy credential only for one declaring client_auth:"
  echo "      proxy_auth. Only the certificate form is cryptographic; a credential is a bearer"
  echo "      secret, which is why the Milestone 03 brokering gate is mtls alone (01.6 D4)."
}

# ---------------------------------------------------------------------------- arguments

require_openssl

# The help text is the header comment, found by SHAPE rather than by a line range. The range was
# `2,36p`, and the mode list had already outgrown it: `status` and the bare-word renewal form
# were invisible, and a fifth mode would have been too. The same defect compile-policy-build.sh
# hit when its LIMIT paragraph fell below its own range, and the same repair.
usage() { awk 'NR>1 && /^#/ {print; next} NR>1 {exit}' "${BASH_SOURCE[0]}"; }

[[ $# -gt 0 ]] || { usage; exit 1; }

MODE="$1"; shift
FORCE="no"
IP=""
AGENT=""

case "$MODE" in
  -h|--help)
    usage; exit 0 ;;

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

  client)
    AGENT="${1:-}"; [[ -n "$AGENT" ]] || fail "client needs an agent name"
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --force) FORCE="yes"; shift ;;
        # No --ip: a client certificate carries no SAN, so there is no address to assert and
        # nothing to record. Rejected explicitly rather than ignored, because silently accepting
        # it would suggest the certificate is bound to an address, which is exactly the
        # misreading the SAN's absence exists to prevent.
        --ip)    fail "client takes no --ip: a client certificate carries no subjectAltName. The subject is the resolved policy's identity value for ${AGENT}." ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    issue_client "$AGENT" "$FORCE" ;;

  credential)
    # `--rebuild` takes no agent: it is the revocation path, and it acts on the whole file.
    if [[ "${1:-}" == "--rebuild" ]]; then
      shift
      [[ $# -eq 0 ]] || fail "credential --rebuild takes no further arguments"
      rebuild_htpasswd
      exit 0
    fi
    AGENT="${1:-}"; [[ -n "$AGENT" ]] || fail "credential needs an agent name, or --rebuild"
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --force) FORCE="yes"; shift ;;
        --ip)    fail "credential takes no --ip: a proxy credential asserts an identity, not an address." ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    issue_credential "$AGENT" "$FORCE" ;;

  *)
    # Renewal form: `issue-identity.sh <name>`
    [[ $# -eq 0 ]] || fail "unexpected arguments after '$MODE'"
    renew_listener "$MODE" ;;
esac
