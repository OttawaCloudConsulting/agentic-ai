# `mediator/config/errors/` — the operator-facing denial surface (01.3 SF-7)

Squid error pages, RENDERED at start by `images/mediator/entrypoint.sh` into the container's
`error_directory` on top of the packaged English set. `@POLICY_PATH@` and `@PROFILE@` are
substituted there; every `%X` is a Squid error-page macro substituted per request when the page is
sent.

One page per refusing control, because `deny_info` keys on the LAST ACL of the matched
`http_access` line and each control's line ends with its own `ctl_*` annotation ACL. That single
ACL does double duty: it names the control on the audit line (`%note{control}`) and selects the
page here.

**These pages are the best-effort client half of Interface Contract 6, not the authoritative
record.** They are only reachable for verdicts decided BEFORE the CONNECT is accepted. A verdict
reached after the ClientHello (SNI disagreeing with the CONNECT host) terminates the connection
with no body, because writing one would mean minting a destination certificate — the MITM
capability D4 and criterion 5 forbid. The audit line is the surface that exists in both cases.

## Macros used

| Macro | Value | Why |
|---|---|---|
| `%H` | destination host from the CONNECT line | `%U` renders `https://host/*` for CONNECT and drops the port |
| `%p` | destination port | the port is the other half of "which destination was refused" |
| `%i` | client address | the agent's container address on a pre-CONNECT refusal at the front listener |

`%note{agent}` is NOT available in an error page — Squid substitutes note macros in log formats
only, and a page containing one emits the literal text (verified at the SF-7 build). The agent name
is therefore carried by the audit line, which is where Contract 4 puts it; the page names the
client address instead.
