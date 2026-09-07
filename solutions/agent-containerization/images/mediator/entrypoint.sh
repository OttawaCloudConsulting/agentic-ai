#!/usr/bin/env bash
# Mediator entrypoint (01.3, SF-4 + SF-5 + SF-6).
#
# SF-4 brought the container up hardened and holding. SF-5 replaced the holding
# resolver with the pod's real DNS authority. SF-6 replaces the holding proxy with
# the real enforcement point. Both are RENDERED from the resolved policy artifact,
# so the mediator's configuration is generated and never hand-edited (SC-6), and
# both are rendered in ONE pass over ONE agent list -- the proxy and the resolver
# must allow exactly the same names, and a second pass is a second chance for them
# to disagree.
#
# What runs here now:
#
#   * dnsdist  -- the DNS policy engine, on the mediator's static address on each
#                 agent network, port 53. Exact-match allowlist per agent, QTYPE
#                 restricted to A/AAAA, non-canonical QNAMEs refused, everything
#                 else REFUSED and forwarded nowhere, every decision audited.
#   * unbound  -- the re-originating resolver, on loopback. No policy. It exists
#                 because dnsdist proxies the client's packet and criterion 4
#                 requires a fresh query with the client's EDNS options dropped.
#   * squid    -- the L7 CONNECT/SNI policy engine. Five listeners for three agents
#                 (the self-cascade -- see mediator/config/proxy.conf.tmpl), the
#                 three controls of D5 evaluated in order, and CONNECT-only.
#
# The two-daemon resolver and the five-listener proxy are both verified necessities
# rather than preferences; the evidence, including what each stage fails to do
# alone, is in docs/records/resolver-verification.md and
# docs/records/mediator-selection.md.
set -euo pipefail

RUN_DIR=/run/mediator
AUDIT_DIR=/var/log/mediator
AUDIT_LOG="$AUDIT_DIR/egress-audit.log"
CACHE_LOG="$AUDIT_DIR/squid-cache.log"
DNS_AUDIT_LOG="$AUDIT_DIR/dns-audit.log"
SQUID_CONF="$RUN_DIR/squid.conf"
POLICY_CONF="$RUN_DIR/dnsdist.conf"
REORIGIN_CONF="$RUN_DIR/unbound.conf"
ERROR_DIR="$RUN_DIR/errors"

TMPL_DIR=/etc/mediator/config
POLICY_DIR=/etc/mediator/policy

# The re-originating resolver's loopback port. Not 53: that belongs to the policy
# engine on the agent networks, and this stage must never be the pod's front door.
REORIGIN_PORT=5353

MEDIATOR_PROFILE="${MEDIATOR_PROFILE:-default}"
RESOLVED_POLICY="$POLICY_DIR/${MEDIATOR_PROFILE}.yaml"

# Where allowlisted names are actually resolved. Docker's embedded resolver in this
# container's own namespace by default, which forwards to the daemon's configured
# upstreams -- so the pod inherits the operator's DNS rather than this repository
# hardcoding a third-party resolver, and the query leaves over `egress-net`, the
# mediator's only external interface.
#
# Criterion 4 says "forwarded to a named upstream on egress-net". Read as naming the
# path rather than requiring a container on that bridge: the traffic leaves through
# egress-net either way, and pointing at Docker's resolver keeps the mediator's
# resolution path identical to the one SF-1 verified Squid against, so control 2 and
# the resolver cannot disagree about what an allowlisted name resolves to.
#
# The acceptance harness overrides this to aim at its own controlled authoritative
# server (T4).
MEDIATOR_DNS_UPSTREAM="${MEDIATOR_DNS_UPSTREAM:-127.0.0.11}"

fail() { echo "mediator: FATAL: $*" >&2; exit 1; }
note() { echo "mediator: $*" >&2; }

# --------------------------------------------------------------- writable paths
# The rootfs is read-only (D15) and /run arrives as an empty tmpfs, so every
# writable path is created here. A missing one is a start failure, which is the
# intended failure mode: a mediator that silently could not open its audit log
# would be an enforcement point running without R9.1.
mkdir -p "$RUN_DIR" "$ERROR_DIR" /run/squid

[ -d "$AUDIT_DIR" ] || fail "$AUDIT_DIR is absent -- the audit volume is not mounted"
touch "$AUDIT_LOG" "$CACHE_LOG" "$DNS_AUDIT_LOG" 2>/dev/null \
  || fail "cannot write the audit sink at $AUDIT_DIR (uid $(id -u)). The named volume must be owned by the runtime uid; it inherits that from the image."

# ------------------------------------------------------------- error_directory
# `error_directory` REPLACES the packaged error set rather than overlaying it
# (docs/records/mediator-selection.md, operational findings), so the directory has
# to be composed: the packaged English pages first, then the mediator's own pages
# on top. SF-7 adds ERR_MEDIATOR_DENIED here.
if [ -d /usr/share/squid/errors/English ]; then
  cp -R /usr/share/squid/errors/English/. "$ERROR_DIR/"
else
  fail "packaged Squid error pages not found -- error_directory cannot be composed"
fi

# =============================================================== resolver render
# The agent networks. One `<agent>=<mediator address>/<prefix>` per agent, and it
# is the SAME fact as compose.yaml's `ipam` blocks, the agents' `dns:` literals and
# the listener certificates' iPAddress SANs. Those were already three copies with a
# guard between them (verify-pod-topology.sh); this is the fourth, and it is checked
# against the container's own interfaces below rather than trusted, so a renumber
# that misses one fails at start naming the field instead of silently serving the
# wrong agent's allowlist.
[ -n "${MEDIATOR_AGENT_NETWORKS:-}" ] \
  || fail "MEDIATOR_AGENT_NETWORKS is unset -- expected '<agent>=<addr>/<prefix>,...' (compose.yaml, egress-mediator). Refusing to serve DNS without knowing which network is which agent."

[ -f "$RESOLVED_POLICY" ] \
  || fail "resolved policy $RESOLVED_POLICY not found (profile '$MEDIATOR_PROFILE'). It is baked into the image from policy/resolved/ -- recompile with scripts/compile-policy.sh and rebuild."

# ipv4_network <addr> <prefix> -> the network address, so the rendered configuration
# reads as the subnet it actually matches rather than a host address with a mask
# hanging off it.
ipv4_network() {
  local a="$1" p="$2" o1 o2 o3 o4 ip mask net
  IFS=. read -r o1 o2 o3 o4 <<< "$a"
  ip=$(( (o1 << 24) | (o2 << 16) | (o3 << 8) | o4 ))
  mask=$(( (0xFFFFFFFF << (32 - p)) & 0xFFFFFFFF ))
  net=$(( ip & mask ))
  printf '%d.%d.%d.%d/%d' $(( (net >> 24) & 255 )) $(( (net >> 16) & 255 )) \
                          $(( (net >> 8) & 255 ))  $(( net & 255 )) "$p"
}

# Every value below is interpolated into a Lua configuration that IS the pod's DNS
# policy. Policy data becoming executable policy code is the whole risk, so the
# shapes are enforced here as well as in the compiler: the compiler is one producer
# today, and 01.5 adds pack composition, which makes the artifact a channel from
# third-party content into this render. Guarding only at the producer would put the
# check on the wrong side of that boundary -- the same argument the wildcard
# rejection already makes.
#
# A hostname label is letters, digits and hyphens, not leading or trailing a hyphen,
# 63 bytes at most; the name is 253 bytes at most. Nothing here can close a Lua
# string.
FQDN_RE='^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$'
# An agent name becomes part of a Lua VARIABLE name (`NAMES_<agent>`), so it must be
# an identifier and not merely quotable.
AGENT_RE='^[a-z][a-z0-9_]{0,31}$'

ACL_ENTRIES=""
LISTENERS=""
AGENT_NETS=""
AGENT_NAMESETS=""
AGENT_ALLOW_RULES=""
ALLOW_RULE_NAMES=""

# --- the proxy's half, accumulated in the SAME pass over the same agent list.
# One loop rather than two because the resolver and the proxy must allow exactly
# the same set of names: a second pass over the same artifact is a second chance
# for the two enforcement surfaces to disagree about what is allowed, and that
# disagreement is invisible until an operator hits it.
P_LISTENERS=""
P_LISTENER_ACLS=""
P_IDENTITY_RULES=""
P_PEERS=""
P_AGENT_ACLS=""
P_GATE_RULES=""
P_DENY_RULES=""
P_MAXCONN_RULES=""
P_ALLOW_RULES=""
P_DELAY_POOLS=""
P_FRONT_ALLOW=""
P_FRONTED=""          # port names of the TLS front listeners, for `never_direct`
P_INNER_NAMES=""      # port names of every peeking listener -- where deny_cidrs runs
P_DELAY_N=0
# Loopback ports for the inner (peeking) listeners of the TLS-fronted agents. They
# all share 127.0.0.1, so unlike the front listeners they cannot share a port.
P_INNER_PORT=3200

IFS=',' read -r -a _agent_specs <<< "$MEDIATOR_AGENT_NETWORKS"
for spec in "${_agent_specs[@]}"; do
  agent="${spec%%=*}"
  cidr="${spec#*=}"
  addr="${cidr%%/*}"
  prefix="${cidr##*/}"

  [ -n "$agent" ] && [ "$agent" != "$spec" ] \
    || fail "MEDIATOR_AGENT_NETWORKS entry '$spec' is malformed -- expected '<agent>=<addr>/<prefix>'"
  [[ "$agent" =~ $AGENT_RE ]] \
    || fail "MEDIATOR_AGENT_NETWORKS names agent '$agent', which is not a valid identifier. It is interpolated into the Lua policy as a variable name, so it must match ${AGENT_RE}."
  [[ "$prefix" =~ ^[0-9]+$ ]] && [ "$prefix" -ge 8 ] && [ "$prefix" -le 32 ] \
    || fail "MEDIATOR_AGENT_NETWORKS entry '$spec' has no usable prefix length"

  # The declared address must actually be ours. Without this a renumber in
  # compose.yaml that misses this variable would leave dnsdist trying to bind an
  # address it does not hold -- or, worse, binding fine while attributing queries to
  # the wrong agent and applying the wrong allowlist.
  # `hostname -I` rather than `ip addr`: iproute2 is not installed, and adding it
  # to the enforcement point to read one list of addresses is not a trade worth
  # making.
  case " $(hostname -I 2>/dev/null) " in
    *" $addr "*) : ;;
    *) fail "MEDIATOR_AGENT_NETWORKS declares $addr for '$agent', but this container holds no such address (has: $(hostname -I 2>/dev/null)). The ipam block in compose.yaml and this variable are one fact; fix them together." ;;
  esac

  # The agent must exist in the resolved policy, or its allowlist would render empty
  # and every one of its names would be refused with nothing saying why.
  [ "$(yq eval ".agents | has(\"$agent\")" "$RESOLVED_POLICY")" = "true" ] \
    || fail "$RESOLVED_POLICY has no agents.$agent, but MEDIATOR_AGENT_NETWORKS declares a network for it"

  network="$(ipv4_network "$addr" "$prefix")"

  ACL_ENTRIES="${ACL_ENTRIES}${ACL_ENTRIES:+, }\"${network}\""
  LISTENERS="${LISTENERS}addLocal(\"${addr}:53\")   -- ${agent}"$'\n'
  AGENT_NETS="${AGENT_NETS}AGENT_NETS[\"${agent}\"] = newNMG(); AGENT_NETS[\"${agent}\"]:addMask(\"${network}\")"$'\n'

  # ------------------------------------------------------------ proxy listeners
  # Which transport this agent's hop uses. Not a preference: 01.1 SF-2 established
  # that `codex` rejects an `https://`-scheme proxy URL at URL-PARSE time, before
  # any handshake, while `claude` and `agy` both reach an `https://` listener. The
  # artifact carries `scheme` and `tls` as two spellings of one fact and the
  # compiler already refuses them if they disagree; `tls` is read here.
  ltls="$(yq eval ".agents.${agent}.listener.tls" "$RESOLVED_POLICY")"
  lport="$(yq eval ".agents.${agent}.listener.port // .agents.${agent}.listener_port" "$RESOLVED_POLICY")"
  [[ "$lport" =~ ^[0-9]+$ ]] && [ "$lport" -ge 1 ] && [ "$lport" -le 65535 ] \
    || fail "$RESOLVED_POLICY: agents.${agent} has no usable listener port (found '$lport')"

  # A CIDR allow entry cannot be paired with an SNI check -- there is no name to
  # compare the ClientHello against -- so honouring one would punch a hole straight
  # through control 1b for that agent. The field is empty in every shipped profile;
  # 01.5 composes pack-supplied entries into the same artifact, which is why this
  # refuses at the boundary instead of trusting the producer.
  ncidr="$(yq eval ".agents.${agent}.allow_cidrs | length" "$RESOLVED_POLICY")"
  [ "$ncidr" = "0" ] \
    || fail "$RESOLVED_POLICY: agents.${agent}.allow_cidrs has ${ncidr} entr(y|ies). SF-6 implements hostname allowlisting only: a CIDR allow has no name for the SNI equality control (control 1b) to compare against, so honouring it would bypass that control silently. Express the destination as an allow_fqdns entry, or extend this render deliberately."

  # `max_concurrent` is control 3's concurrency ceiling; `bytes_per_second` is its
  # byte-rate ceiling. `connections_per_minute` is deliberately absent from the
  # schema -- Squid 6.13 has no per-client connection-rate directive at all
  # (docs/records/mediator-selection.md, P3) and a policy key that enforces nothing
  # is worse than an absent one. Recorded as a deviation on the feature plan.
  maxconn="$(yq eval ".agents.${agent}.limits.max_concurrent" "$RESOLVED_POLICY")"
  bps="$(yq eval ".agents.${agent}.limits.bytes_per_second" "$RESOLVED_POLICY")"
  [[ "$maxconn" =~ ^[0-9]+$ ]] && [[ "$bps" =~ ^[0-9]+$ ]] \
    || fail "$RESOLVED_POLICY: agents.${agent}.limits must carry integer max_concurrent and bytes_per_second (found '$maxconn' and '$bps')"

  if [ "$ltls" = "true" ]; then
    # Two listeners. The front terminates the proxy hop and can never peek
    # (`https_port` refuses `ssl-bump`); the inner peeks and can never terminate a
    # proxy hop. SF-1's P6/P7.
    inner="$P_INNER_PORT"
    P_INNER_PORT=$(( P_INNER_PORT + 1 ))
    crt="/run/secrets/${agent}-listener.crt"
    key="/run/secrets/${agent}-listener.key"
    [ -r "$crt" ] && [ -r "$key" ] \
      || fail "agent '${agent}' has a TLS proxy hop but $crt / $key is not readable. The listener key pair arrives as a Compose secret (compose.yaml) and is issued by scripts/issue-identity.sh with an iPAddress SAN for ${addr}."
    P_LISTENERS="${P_LISTENERS}https_port ${addr}:${lport} name=${agent} tls-cert=${crt} tls-key=${key}"$'\n'
    P_LISTENERS="${P_LISTENERS}http_port 127.0.0.1:${inner} name=${agent}in ssl-bump generate-host-certificates=off tls-cert=${crt} tls-key=${key}"$'\n'
    P_LISTENER_ACLS="${P_LISTENER_ACLS}acl p_${agent}_front myportname ${agent}"$'\n'
    P_LISTENER_ACLS="${P_LISTENER_ACLS}acl p_${agent}_inner myportname ${agent}in"$'\n'
    P_LISTENER_ACLS="${P_LISTENER_ACLS}acl p_${agent}       myportname ${agent} ${agent}in"$'\n'
    P_PEERS="${P_PEERS}cache_peer 127.0.0.1 parent ${inner} 0 no-query no-digest no-netdb-exchange name=${agent}peer"$'\n'
    P_PEERS="${P_PEERS}cache_peer_access ${agent}peer allow p_${agent}_front"$'\n'
    P_PEERS="${P_PEERS}cache_peer_access ${agent}peer deny all"$'\n'
    P_FRONTED="${P_FRONTED} ${agent}"
    P_INNER_NAMES="${P_INNER_NAMES} ${agent}in"
  else
    # One listener doing both jobs. `codex`'s hop is plain HTTP CONNECT, so there
    # is no proxy-hop TLS to terminate and the single port can carry `ssl-bump`.
    #
    # It still needs a `tls-cert=`, and that is a Squid requirement rather than a
    # hop: without one the port loads no signing certificate and Squid reports
    # "Requiring client certificates". The certificate is never presented on an
    # allowed path -- peek+splice hands the origin's own chain through untouched --
    # and `codex` neither trusts nor validates it. Recorded as a deviation against
    # Interface Contract 3, which says codex's listener gets no certificate.
    crt="/run/secrets/${agent}-listener.crt"
    key="/run/secrets/${agent}-listener.key"
    [ -r "$crt" ] && [ -r "$key" ] \
      || fail "agent '${agent}' has a plain-HTTP proxy hop but still needs a BUMPING certificate at $crt / $key for its peek stage -- without one Squid loads no signing certificate on that port. It is never presented on an allowed path and ${agent} never validates it. Issue it with: bash scripts/issue-identity.sh listener ${agent} --ip ${addr}"
    P_LISTENERS="${P_LISTENERS}http_port ${addr}:${lport} name=${agent} ssl-bump generate-host-certificates=off tls-cert=${crt} tls-key=${key}"$'\n'
    P_LISTENER_ACLS="${P_LISTENER_ACLS}acl p_${agent}_front myportname ${agent}"$'\n'
    P_LISTENER_ACLS="${P_LISTENER_ACLS}acl p_${agent}_inner myportname ${agent}"$'\n'
    P_LISTENER_ACLS="${P_LISTENER_ACLS}acl p_${agent}       myportname ${agent}"$'\n'
    P_INNER_NAMES="${P_INNER_NAMES} ${agent}"
  fi

  P_IDENTITY_RULES="${P_IDENTITY_RULES}acl tag_${agent} annotate_transaction agent=${agent}"$'\n'
  P_IDENTITY_RULES="${P_IDENTITY_RULES}http_access deny p_${agent} tag_${agent} !all"$'\n'

  P_DELAY_N=$(( P_DELAY_N + 1 ))
  P_DELAY_POOLS="${P_DELAY_POOLS}delay_class ${P_DELAY_N} 1"$'\n'
  P_DELAY_POOLS="${P_DELAY_POOLS}delay_parameters ${P_DELAY_N} ${bps}/${bps}"$'\n'
  P_DELAY_POOLS="${P_DELAY_POOLS}delay_access ${P_DELAY_N} allow p_${agent}_inner"$'\n'
  P_DELAY_POOLS="${P_DELAY_POOLS}delay_access ${P_DELAY_N} deny all"$'\n'

  P_MAXCONN_RULES="${P_MAXCONN_RULES}acl maxconn_${agent} maxconn ${maxconn}"$'\n'
  P_MAXCONN_RULES="${P_MAXCONN_RULES}http_access deny p_${agent}_front maxconn_${agent}"$'\n'

  # Exact names only. The compiler already refuses a wildcard entry at compile time
  # (scripts/compile-policy.sh) because the resolver matches exactly and a wildcard
  # would reopen DNS exfiltration; this stage is what makes that refusal meaningful.
  names="$(yq eval ".agents.${agent}.allow_fqdns[] | .fqdn + \" \" + (.port | tostring)" "$RESOLVED_POLICY" 2>/dev/null || true)"

  set_lua="NAMES_${agent} = newDNSNameSet()"$'\n'
  agent_hosts=""
  agent_ports=""
  count=0
  while IFS=' ' read -r fqdn fport; do
    [ -n "$fqdn" ] && [ "$fqdn" != "null" ] || continue
    case "$fqdn" in
      *'*'*) fail "$RESOLVED_POLICY: agents.${agent} allows the wildcard '$fqdn'. The resolver matches exactly; a wildcard here would forward every name beneath it (R5.4)." ;;
    esac
    # The name is about to become Lua source. Anything that is not a hostname is
    # refused here, at the boundary, rather than trusted from the artifact.
    [ "${#fqdn}" -le 253 ] && [[ "$fqdn" =~ $FQDN_RE ]] \
      || fail "$RESOLVED_POLICY: agents.${agent} allows '$fqdn', which is not a valid hostname. It is interpolated into the mediator's Lua policy, so a name carrying quotes, escapes or newlines would become policy CODE rather than policy data. Refusing to start."
    # Canonicalised at render time as well as at query time, so a base file written
    # with capitals cannot produce an entry no canonical query can ever match.
    lower="$(printf '%s' "$fqdn" | tr '[:upper:]' '[:lower:]')"
    set_lua="${set_lua}NAMES_${agent}:add(newDNSName(\"${lower}.\"))"$'\n'

    # The destination port is about to become squid.conf source in exactly the way
    # the name is, and it is validated at the same boundary and for the same reason.
    [[ "$fport" =~ ^[0-9]+$ ]] && [ "$fport" -ge 1 ] && [ "$fport" -le 65535 ] \
      || fail "$RESOLVED_POLICY: agents.${agent} allows '${fqdn}' on port '${fport}', which is not a port number."

    # One PAIRED rule per name. `dstdomain` matches the CONNECT host and
    # `ssl::server_name --client-requested` matches the ClientHello's SNI; requiring
    # both on one line is how SNI-equals-CONNECT-host is expressed in a Squid that
    # has no mismatch predicate at all (SF-1, P6). N entries produce N rules.
    #
    # The `.` prefix Squid uses for subdomain matching is NOT used: `dstdomain
    # api.anthropic.com` matches that name exactly, and a leading dot would match
    # every host beneath it -- the same hole the resolver's exact matching closes.
    #
    # `-n` disables the REVERSE lookup, and it is a control rather than a tuning
    # flag. Without it a CONNECT to a bare IP literal makes Squid issue a PTR query
    # through its own upstream just to obtain a name for this ACL to compare --
    # measured at the SF-6 build: `CONNECT 169.254.169.254:443` produced
    # `254.169.254.169.in-addr.arpa. PTR IN` at the controlled resolver. That is
    # mediator-originated, agent-triggered, unaudited DNS egress on a destination the
    # policy is in the middle of refusing: the same leak the allowlist-gate-first
    # ordering closes for forward names, one query type over. With `-n` an IP literal
    # matches no name and falls through to default-deny, resolving nothing.
    P_AGENT_ACLS="${P_AGENT_ACLS}acl h_${agent}_${count} dstdomain -n ${lower}"$'\n'
    P_AGENT_ACLS="${P_AGENT_ACLS}acl s_${agent}_${count} ssl::server_name --client-requested ${lower}"$'\n'
    P_AGENT_ACLS="${P_AGENT_ACLS}acl t_${agent}_${count} port ${fport}"$'\n'
    P_ALLOW_RULES="${P_ALLOW_RULES}http_access allow p_${agent}_inner h_${agent}_${count} s_${agent}_${count} t_${agent}_${count}"$'\n'

    agent_hosts="${agent_hosts} ${lower}"
    agent_ports="${agent_ports} ${fport}"
    count=$(( count + 1 ))
  done <<< "$names"

  AGENT_NAMESETS="${AGENT_NAMESETS}-- ${agent}: ${count} exact name(s) from ${RESOLVED_POLICY}"$'\n'"${set_lua}"$'\n'

  # Control 1a's gate: the UNION of this agent's names and ports, matched on the
  # CONNECT line alone. It exists so that a name absent from this agent's allowlist
  # is refused BEFORE `deny_cidrs` (a `dst` ACL) forces Squid to resolve it. Without
  # it the mediator would resolve every attacker-chosen CONNECT host through its own
  # upstream, on no audit line and outside the pod resolver entirely -- the DNS
  # exfiltration channel criterion 4 closes, reopened at the proxy.
  if [ "$count" -eq 0 ]; then
    # Not an error: an agent with no allowlisted name resolves nothing and reaches
    # nothing, which is the correct default-deny outcome. An empty `dstdomain` ACL
    # is a parse error, so the gate degenerates to an unconditional refusal rather
    # than being omitted -- omitting it would let the agent fall through to the
    # `dst` deny and get its destinations resolved on the way to being refused.
    note "resolver: agent '$agent' has no allowlisted names -- every DNS query from ${network} will be REFUSED"
    note "proxy: agent '$agent' has no allowlisted names -- every CONNECT from ${network} will be refused"
    P_GATE_RULES="${P_GATE_RULES}http_access deny p_${agent}"$'\n'
  else
    P_AGENT_ACLS="${P_AGENT_ACLS}acl hany_${agent} dstdomain -n${agent_hosts}"$'\n'
    P_AGENT_ACLS="${P_AGENT_ACLS}acl tany_${agent} port$(printf '%s\n' $agent_ports | sort -un | tr '\n' ' ' | sed 's/ $//;s/^/ /')"$'\n'
    P_GATE_RULES="${P_GATE_RULES}http_access deny p_${agent} !hany_${agent}"$'\n'
    P_GATE_RULES="${P_GATE_RULES}http_access deny p_${agent} !tany_${agent}"$'\n'
  fi

  rule="allow_${agent}"
  AGENT_ALLOW_RULES="${AGENT_ALLOW_RULES}${rule} = AndRule({NetmaskGroupRule(AGENT_NETS[\"${agent}\"]), QNameSetRule(NAMES_${agent}), ClassIN, AorAAAA})"$'\n'
  ALLOW_RULE_NAMES="${ALLOW_RULE_NAMES}${ALLOW_RULE_NAMES:+, }${rule}"
done

[ -n "$ACL_ENTRIES" ] || fail "MEDIATOR_AGENT_NETWORKS produced no agent networks"

# One audit call and one pool decision for the union of the per-agent rules, rather
# than a matching pair per agent: the verdict is the same on every allowed path, and
# duplicating it invites the two copies to drift.
AGENT_ALLOW_RULES="${AGENT_ALLOW_RULES}
anyAllow = OrRule({${ALLOW_RULE_NAMES}})
addAction(anyAllow, LuaAction(function(dq) return auditDNS(dq, \"allow\", nil) end))
addAction(anyAllow, PoolAction(\"reorigin\"))"

# ================================================================= proxy render
# The two halves of control 2, applied to every agent (R5.3, R5.7 -- deny wins).
# They are global rather than per-agent because the artifact declares them once:
# `deny_cidrs` is the post-resolution address deny and `deny_fqdns` is R5.1's FQDN
# deny, which 01.1's approved contract omitted and criterion 10 restores.
P_DENY_ACLS=""
P_DENY_RULES=""

deny_fqdns="$(yq eval '.deny_fqdns[]' "$RESOLVED_POLICY" 2>/dev/null || true)"
_df=""
while IFS= read -r d; do
  [ -n "$d" ] && [ "$d" != "null" ] || continue
  [ "${#d}" -le 253 ] && [[ "$d" =~ $FQDN_RE ]] \
    || fail "$RESOLVED_POLICY: deny_fqdns carries '$d', which is not a valid hostname. It is interpolated into squid.conf."
  _df="${_df} $(printf '%s' "$d" | tr '[:upper:]' '[:lower:]')"
done <<< "$deny_fqdns"

deny_cidrs="$(yq eval '.deny_cidrs[]' "$RESOLVED_POLICY" 2>/dev/null || true)"
_dc=""
while IFS= read -r c; do
  [ -n "$c" ] && [ "$c" != "null" ] || continue
  # The compiler normalises a bare address to /32 or /128 (criterion 10), so a
  # prefix length is expected here. Anything else is refused rather than handed to
  # Squid, which would either reject the whole configuration or -- worse -- accept a
  # mis-sized mask and deny a wider range than the operator wrote.
  [[ "$c" =~ ^[0-9a-fA-F:.]+/[0-9]{1,3}$ ]] \
    || fail "$RESOLVED_POLICY: deny_cidrs carries '$c', which is not an address/prefix. scripts/compile-policy.sh normalises a bare address to /32 or /128; recompile."
  _dc="${_dc} ${c}"
done <<< "$deny_cidrs"

# An empty `dstdomain`/`dst` ACL is a parse error, so an empty list renders no ACL
# and no rule at all. That is correct and not a silent weakening: default-deny is
# carried by the allowlist gate above, and `deny_fqdns` is empty in every shipped
# profile precisely because criterion 10 asked for the field to be SUPPORTED, not
# populated.
if [ -n "$_df" ]; then
  P_DENY_ACLS="${P_DENY_ACLS}acl deny_fqdns dstdomain -n${_df}"$'\n'
  P_DENY_RULES="${P_DENY_RULES}http_access deny deny_fqdns"$'\n'
fi
if [ -n "$_dc" ]; then
  P_DENY_ACLS="${P_DENY_ACLS}acl deny_cidrs dst${_dc}"$'\n'
  P_DENY_ACLS="${P_DENY_ACLS}acl inner_layer myportname${P_INNER_NAMES}"$'\n'
  P_DENY_RULES="${P_DENY_RULES}http_access deny inner_layer deny_cidrs"$'\n'
fi

# `never_direct` on the fronted listeners. Without it a front whose peer is briefly
# unreachable falls back to connecting DIRECT -- which bypasses its own peek stage,
# and with it the entire SNI control. It is a fail-closed rule, not routing tidiness.
if [ -n "$P_FRONTED" ]; then
  P_PEERS="${P_PEERS}acl fronted myportname${P_FRONTED}"$'\n'
  P_PEERS="${P_PEERS}never_direct allow fronted"$'\n'
  P_FRONT_ALLOW="http_access allow fronted"$'\n'
else
  P_FRONT_ALLOW="# no TLS-fronted agent in this profile -- no cascade, no front allow"$'\n'
fi

P_DELAY_POOLS="delay_pools ${P_DELAY_N}"$'\n'"${P_DELAY_POOLS}"

render() { # <template> <output>
  local tmpl="$1" out="$2"
  [ -f "$tmpl" ] || fail "template $tmpl not found in the image"
  AGENT_NETS="$AGENT_NETS" AGENT_NAMESETS="$AGENT_NAMESETS" \
  AGENT_ALLOW_RULES="$AGENT_ALLOW_RULES" ACL_ENTRIES="$ACL_ENTRIES" \
  LISTENERS="$LISTENERS" DNS_AUDIT_LOG="$DNS_AUDIT_LOG" \
  REORIGIN_PORT="$REORIGIN_PORT" FORWARD_ADDRS="$FORWARD_ADDRS" \
  P_LISTENERS="$P_LISTENERS" P_LISTENER_ACLS="$P_LISTENER_ACLS" \
  P_IDENTITY_RULES="$P_IDENTITY_RULES" P_PEERS="$P_PEERS" \
  P_DENY_ACLS="$P_DENY_ACLS" P_AGENT_ACLS="$P_AGENT_ACLS" \
  P_GATE_RULES="$P_GATE_RULES" P_DENY_RULES="$P_DENY_RULES" \
  P_MAXCONN_RULES="$P_MAXCONN_RULES" P_FRONT_ALLOW="$P_FRONT_ALLOW" \
  P_ALLOW_RULES="$P_ALLOW_RULES" P_DELAY_POOLS="$P_DELAY_POOLS" \
  CACHE_LOG="$CACHE_LOG" AUDIT_LOG="$AUDIT_LOG" ERROR_DIR="$ERROR_DIR" \
  DNS_NAMESERVERS="$DNS_NAMESERVERS" \
  awk '
    function emit(v) { printf "%s", ENVIRON[v]; if (ENVIRON[v] !~ /\n$/) printf "\n" }
    /^@ACL@$/                { next }
    $0 == "setACL({@ACL@})"  { printf "setACL({%s})\n", ENVIRON["ACL_ENTRIES"]; next }
    /^@LISTENERS@$/          { emit("LISTENERS");         next }
    /^@AGENT_NETS@$/         { emit("AGENT_NETS");        next }
    /^@AGENT_NAMESETS@$/     { emit("AGENT_NAMESETS");    next }
    /^@AGENT_ALLOW_RULES@$/  { emit("AGENT_ALLOW_RULES"); next }
    /^@FORWARD_ADDRS@$/      { emit("FORWARD_ADDRS");     next }
    /^@PROXY_LISTENERS@$/    { emit("P_LISTENERS");       next }
    /^@LISTENER_ACLS@$/      { emit("P_LISTENER_ACLS");   next }
    /^@IDENTITY_RULES@$/     { emit("P_IDENTITY_RULES");  next }
    /^@PEERS@$/              { emit("P_PEERS");           next }
    /^@DENY_ACLS@$/          { emit("P_DENY_ACLS");       next }
    /^@AGENT_ACLS@$/         { emit("P_AGENT_ACLS");      next }
    /^@GATE_RULES@$/         { emit("P_GATE_RULES");      next }
    /^@DENY_RULES@$/         { emit("P_DENY_RULES");      next }
    /^@MAXCONN_RULES@$/      { emit("P_MAXCONN_RULES");   next }
    /^@FRONT_ALLOW@$/        { emit("P_FRONT_ALLOW");     next }
    /^@ALLOW_RULES@$/        { emit("P_ALLOW_RULES");     next }
    /^@DELAY_POOLS@$/        { emit("P_DELAY_POOLS");     next }
    {
      gsub(/@DNS_AUDIT_LOG@/, ENVIRON["DNS_AUDIT_LOG"])
      gsub(/@REORIGIN_PORT@/, ENVIRON["REORIGIN_PORT"])
      gsub(/@CACHE_LOG@/, ENVIRON["CACHE_LOG"])
      gsub(/@AUDIT_LOG@/, ENVIRON["AUDIT_LOG"])
      gsub(/@ERROR_DIR@/, ENVIRON["ERROR_DIR"])
      gsub(/@DNS_NAMESERVERS@/, ENVIRON["DNS_NAMESERVERS"])
      print
    }
  ' "$tmpl" > "$out"
  # A marker surviving the render means a placeholder was added to a template and
  # not to this function -- a silently half-configured enforcement point otherwise.
  if grep -qE '@[A-Z_]+@' "$out"; then
    grep -nE '@[A-Z_]+@' "$out" >&2
    fail "$out still contains unsubstituted markers (see above)"
  fi
}

# Both resolvers-of-last-resort, from one variable. unbound takes one
# `forward-addr:` line each; Squid takes them space-separated on `dns_nameservers`.
# Assigned before the first render because render() passes every marker's value on a
# single env prefix and `set -u` evaluates them all.
DNS_NAMESERVERS="${MEDIATOR_DNS_UPSTREAM//,/ }"

FORWARD_ADDRS=""
for up in ${MEDIATOR_DNS_UPSTREAM//,/ }; do
  FORWARD_ADDRS="${FORWARD_ADDRS}    forward-addr: ${up}"$'\n'
done

render "$TMPL_DIR/resolver-policy.conf.tmpl"   "$POLICY_CONF"
render "$TMPL_DIR/resolver-reorigin.conf.tmpl" "$REORIGIN_CONF"

# ================================================================= proxy render
# The three agent-facing listeners, the three controls and the CONNECT-only
# restriction, rendered from the same artifact and the same agent list the resolver
# above was rendered from. This replaces SF-4's HOLDING configuration: the mediator
# is an enforcement point from this sub-feature on.
#
render "$TMPL_DIR/proxy.conf.tmpl" "$SQUID_CONF"

# ------------------------------------------------------------------- pre-flight
# All three parsers fail hard on an unknown directive, which is how configuration
# correctness is established on an image that ships no reference config. A rendered
# file that does not parse is a start failure, never a daemon started against a
# configuration nobody checked.
squid -k parse -f "$SQUID_CONF" >/dev/null 2>&1 \
  || { squid -k parse -f "$SQUID_CONF" || true; fail "squid rejected $SQUID_CONF"; }
unbound-checkconf "$REORIGIN_CONF" >/dev/null 2>&1 \
  || { unbound-checkconf "$REORIGIN_CONF" || true; fail "unbound rejected $REORIGIN_CONF"; }
dnsdist --check-config -C "$POLICY_CONF" >/dev/null 2>&1 \
  || { dnsdist --check-config -C "$POLICY_CONF" || true; fail "dnsdist rejected $POLICY_CONF"; }

# ------------------------------------------------------------------------ start
# Squid cannot open /dev/stdout after dropping to the `proxy` user (the parent
# directory must be writable by it -- mediator-selection.md), so the logs are files
# on the audit volume and are relayed to the container's streams from here. That
# keeps D12's two sinks -- the volume and the container's stdout -- without giving a
# daemon a path it cannot open. The DNS audit sink is written by dnsdist's Lua and
# relayed the same way, so both trails reach both sinks.
CHILDREN=()

tail -n 0 -F "$AUDIT_LOG"     >&1 & CHILDREN+=($!); TAIL_AUDIT=$!
tail -n 0 -F "$CACHE_LOG"     >&2 & CHILDREN+=($!); TAIL_CACHE=$!
tail -n 0 -F "$DNS_AUDIT_LOG" >&1 & CHILDREN+=($!); TAIL_DNS=$!

unbound -d -c "$REORIGIN_CONF" & CHILDREN+=($!); UNBOUND_PID=$!
# The re-originating resolver must be answering before the policy engine starts, or
# dnsdist's first queries hit a backend that is not listening yet.
# Read from /proc rather than with `ss`, which is not installed. The UDP table
# lists the port in hex; 0100007F is 127.0.0.1 little-endian.
_reorigin_hex="$(printf '0100007F:%04X' "$REORIGIN_PORT")"
_reorigin_up=0
for _ in $(seq 1 100); do
  if grep -qi " ${_reorigin_hex} " /proc/net/udp 2>/dev/null; then _reorigin_up=1; break; fi
  kill -0 "$UNBOUND_PID" 2>/dev/null || fail "the re-originating resolver exited before it began listening -- see its output above"
  sleep 0.1
done
[ "$_reorigin_up" -eq 1 ] \
  || fail "the re-originating resolver did not bind 127.0.0.1:${REORIGIN_PORT} within 10s -- refusing to start the policy engine in front of a backend that is not answering"

dnsdist --supervised --disable-syslog -C "$POLICY_CONF" & CHILDREN+=($!); DNSDIST_PID=$!
squid -N -f "$SQUID_CONF" & CHILDREN+=($!); SQUID_PID=$!

# A half-dead mediator is worse than a dead one: a live proxy with a dead resolver is
# a pod whose DNS authority has silently gone, and a live resolver with a dead proxy
# is an enforcement point that is no longer enforcing. Either exit takes the
# container down so the restart policy and the operator both see it.
# Cleanup is bounded. TERM first, then KILL for anything still alive: a daemon that
# ignores TERM or wedges would otherwise leave PID 1 waiting forever and the
# container neither running nor gone. The relays are reaped here too rather than
# left to container teardown.
stop_children() {
  local pid alive
  for pid in "${CHILDREN[@]}"; do kill "$pid" 2>/dev/null || true; done
  for _ in $(seq 1 50); do
    alive=0
    for pid in "${CHILDREN[@]}"; do kill -0 "$pid" 2>/dev/null && alive=1; done
    [ "$alive" -eq 0 ] && break
    sleep 0.1
  done
  for pid in "${CHILDREN[@]}"; do
    kill -0 "$pid" 2>/dev/null && { note "child $pid ignored TERM -- sending KILL"; kill -9 "$pid" 2>/dev/null || true; }
  done
  wait "${CHILDREN[@]}" 2>/dev/null || true
}

# An asked-for stop (`docker stop`, `compose down`) is not an incident and exits 0.
# A child leaving on its own always is -- including when it leaves cleanly, which is
# the case that would otherwise be invisible: unbound exits 0 on SIGTERM, so a
# resolver killed inside the container would take the pod's DNS authority away and
# report success to anything reading the container's exit code.
on_signal() {
  trap - TERM INT
  note "stop requested -- shutting down"
  stop_children
  exit 0
}
trap on_signal TERM INT

note "up: squid $(squid -v 2>/dev/null | head -1 | sed 's/^Squid Cache: //'), dnsdist $(dnsdist --version 2>&1 | head -1), unbound $(unbound -V 2>/dev/null | head -1)"
note "policy: profile '${MEDIATOR_PROFILE}', networks '${MEDIATOR_AGENT_NETWORKS}', upstream '${MEDIATOR_DNS_UPSTREAM}'"

# Six children, all watched. An unwatched relay is silent by construction: a daemon
# keeps writing to the volume, the mediator keeps enforcing, and the container's
# stdout -- one of D12's two sinks -- stops carrying audit lines with nothing to say
# so. R9.1 makes the audit trail a property of the enforcement point, not a
# convenience, so a lost sink fails closed like a lost daemon. SF-7 owns the audit
# writer and may soften this to a relay restart; it must not soften it to silence.
#
# `|| STATUS=$?` is load-bearing: under `set -e` a bare `wait -n` returning non-zero
# exits the shell AT THAT LINE, skipping the diagnostic, the cleanup and the
# controlled exit -- the whole reason this supervisor exists.
#
# `-p DIED` names the child whose status was returned. Identifying it by a `kill -0`
# probe afterwards instead would pair the wrong name with the status whenever a
# second child exits during the check, and "which one died" is the entire content of
# the message.
DIED=""
STATUS=0
wait -n -p DIED "${CHILDREN[@]}" || STATUS=$?

# Past this point a stop request must not overwrite a detected failure with exit 0.
trap - TERM INT

case "$DIED" in
  "$SQUID_PID")   note "squid exited (status $STATUS) -- taking the mediator down; the pod has no enforcement point" ;;
  "$DNSDIST_PID") note "dnsdist exited (status $STATUS) -- taking the mediator down; the pod has no DNS policy engine" ;;
  "$UNBOUND_PID") note "unbound exited (status $STATUS) -- taking the mediator down; the pod's resolver cannot re-originate" ;;
  "$TAIL_AUDIT"|"$TAIL_CACHE"|"$TAIL_DNS")
                  note "an audit relay exited (status $STATUS) -- taking the mediator down; stdout is no longer carrying the audit trail" ;;
  *)              note "a supervised child exited (pid ${DIED:-unknown}, status $STATUS) -- taking the mediator down" ;;
esac

stop_children
# Never 0 on this path. No child exiting is a normal outcome while the mediator is
# up, and reporting success would hide the incident from the restart policy and from
# anyone reading the exit code.
[ "$STATUS" -eq 0 ] && STATUS=1
exit "$STATUS"
