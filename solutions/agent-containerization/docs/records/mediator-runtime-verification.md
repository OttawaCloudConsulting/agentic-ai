# Mediator Runtime Verification — 01.3 SF-4

**Date:** 2026-09-06
**Host:** Docker Desktop 28.3.2, macOS 26, Apple silicon (R11.1, A1)
**Subject:** the two runtime properties SF-4's plan text says must be *verified, not assumed* —
that Compose `dns:` really redirects Docker's embedded resolver to a container address on an
`internal: true` bridge, and that a privileged port binds under `cap_drop: ALL`.

Both rest on behaviour of Docker Desktop's Linux VM rather than on anything this repository
controls, and both are load-bearing: the first is the whole of D3's mechanism, and the second is
what decides whether `cap_drop: ALL` survives on the enforcement point. Reading the Compose
documentation is not evidence for either.

Verified against the SF-4 holding configuration (Squid on loopback with `http_access deny all`;
unbound on `:53` with `local-zone "." refuse` and `log-queries`). The holding resolver is the
capture instrument, not the pod resolver — SF-5 replaces it with the closed forwarder.

---

## 1. `dns:` redirects the embedded resolver on an `internal: true` bridge — CONFIRMED BY CAPTURE

`internal: true` withholds the default route but leaves Docker's embedded resolver at `127.0.0.11`
forwarding to the daemon's configured upstreams — a path out of the pod that never traverses the
container's routing table, and therefore a DNS exfiltration channel the network mode does not close
(observed in 01.2, criterion 1). D3's answer is `dns:`, which replaces those upstreams.

**What Docker records.** Inside the `claude` container:

```
$ cat /etc/resolv.conf
nameserver 127.0.0.11
options ndots:0
# Based on host file: '/etc/resolv.conf' (internal resolver)
# ExtServers: [172.31.10.2]
# Overrides: [nameservers]
```

`nameserver` is still the embedded resolver — that is expected and is what keeps container-name
resolution working locally. The substituted upstream is in `ExtServers`.

**What actually arrived — and the first version of this evidence was overstated.** The original
capture was a *refusal*: `getent hosts example.com` in the agent returned exit 2 while the mediator
logged the query. An external review was right that this proves less than it claimed. A refusal
plus a log line does not establish the path — the same mediator-side log could come from a direct
query to `172.31.10.2:53` from that namespace rather than from the embedded resolver forwarding it,
and `getent` exit 2 does not distinguish REFUSED from unreachable or timed out. Re-done as a
**positive** answer with a nonce and a negative control, which is what the claim needed:

The resolver was given one nonce name it answers with a unique address
(`n17887428704549.sf4probe.test → 203.0.113.77`), through a throwaway override. Then, on the same
network, two containers differing only in `--dns`:

```
A)  --dns 172.31.10.2   (the mediator)
    203.0.113.77    n17887428704549.sf4probe.test
    exit=0
    mediator log: 172.31.10.3 n17887428704549.sf4probe.test. A IN   (and AAAA)

B)  --dns 172.31.10.9   (nothing listens there; same subnet)
    exit=2
    mediator log: nothing
```

The address returned in (A) exists nowhere but that resolver's configuration, so the answer can only
have come from it, and it arrived through the agent's normal NSS path rather than a hand-aimed
query. (B) is the control: change only the `dns:` target and the resolution fails and the mediator
sees nothing. Together these establish that the redirect carries real queries across an
`internal: true` bridge — which the refusal-based evidence did not.

Note for whoever repeats this: layering a `dns:` override in a second Compose file **appends**
rather than replaces (`ExtServers: [172.31.10.2 172.31.10.9]`), so a negative control written that
way silently still reaches the mediator and passes for the wrong reason. The controls above use
`docker run --dns` for that reason.

This is the assertion SF-8 Phase A re-runs. The topology test asserts the `ExtServers` half on all
three agents; the capture half needs a mediator with a resolver, so it belongs to the egress
harness.

---

## 2. Privileged bind under `cap_drop: ALL` — CONFIRMED, sysctl path, no capability added

`net.ipv4.ip_unprivileged_port_start` is namespaced and Docker Desktop's VM permits setting it per
container. With `sysctls: {net.ipv4.ip_unprivileged_port_start: "0"}` and no `cap_add`:

```
mediator$ id
uid=13(proxy) gid=13(proxy) groups=13(proxy)
mediator$ cat /proc/sys/net/ipv4/ip_unprivileged_port_start
0
mediator$ awk '$4=="0A"' /proc/net/tcp      # 00000000:0035  -> 0.0.0.0:53, LISTEN
mediator$ awk '$4=="07"' /proc/net/udp      # 00000000:0035  -> 0.0.0.0:53

$ docker inspect --format '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' <mediator>
[ALL] []
```

**What this does not establish.** The same review noted the bind evidence is sound but not
audit-grade: it reads the container's configuration and the listening sockets, not the live
process's capability set. Stronger evidence would be `CapEff`/`CapPrm` zero in
`/proc/<unbound-pid>/status`, the socket inode mapped back to that pid, `getcap` on the binary, and
a negative control showing the same container fails to bind `:53` with the sysctl removed. Recorded
as a known limit of this record rather than claimed.

**The recorded fallback was not needed and is not taken.** `cap_add: NET_BIND_SERVICE` stays
unused, which matters beyond tidiness: `cap_add` combined with a non-root `user:` does not reliably
produce an *effective* capability without ambient capabilities, so the fallback would have needed
its own bind verification rather than an inspection of the container's configuration.

---

## 3. Two findings the plan did not anticipate

**`net.ipv4.ip_forward` defaults to `1`, not `0`.** Criterion 3 and the Edge Cases entry "The
mediator must not become a router" both reason from "container network namespaces default to
`net.ipv4.ip_forward=0`". On this host they do not:

```
mediator$ cat /proc/sys/net/ipv4/ip_forward
1                                   # before the fix
```

The mediator is the one container holding an interface on both an agent network and the external
network, so this is exactly where the default matters. Agents still cannot route through it — they
have no default route, which is the structural half of the control — but the assertion the plan
intends to make was false about the runtime it was made against. `net.ipv4.ip_forward: "0"` is now
set explicitly in `compose.yaml` alongside the port sysctl, and reads `0` after the change. SF-8
asserts it rather than inheriting it.

**The `/run` tmpfs arrives root-owned and mode 0755.** Under `read_only: true` the mediator's
runtime directories can only live on a tmpfs, and a container running as uid 13 with `cap_drop:
ALL` cannot create anything in a root-owned one — the first bring-up failed with
`mkdir: cannot create directory '/run/mediator': Permission denied`. The tmpfs mounts carry
`uid=13,gid=13,mode=0750` (and `0700` for `/tmp`), which is narrower than the obvious repair of
making them world-writable. The agent services are unaffected: their entrypoint writes nothing to
`/run`.

---

## 4. Points confirmed rather than assumed, in passing

- **File-based Compose secrets are readable by the container's uid.** The listener private keys are
  `0600` on the operator host; inside the mediator they are `-rw------- proxy proxy` and readable.
  No `chmod` at issuance and no start-as-root-then-drop is needed.
- **`SSL_CERT_FILE` does not cost `agy` its destination trust.** The concern was that pointing it at
  the lone mediator CA would *replace* the system trust store, so `agy` would then fail to validate
  real origins on the spliced destination hop — which would have made Interface Contract 2 wrong.
  It does not: OpenSSL keeps its default CApath alongside the named file (checked directly:
  `SSL_CERT_FILE=<lone CA> openssl s_client -connect example.com:443` still verifies), and Go's
  `crypto/x509` loads both `SSL_CERT_FILE` and the default certificate *directories*, which
  `ca-certificates` populates in the agent image. Additive on both stacks.
- **The build context guard works.** The mediator's build context is the solution root, so the
  root `.dockerignore` is deny-all plus an allowlist. Build output reports
  `transferring context: 12.99kB` — `references/.env_keys` and `mediator/identity/` are not in it.

---

## 5. Not established here

- Anything about the *pod* resolver. SF-5 owns the closed forwarder, and the QTYPE restriction to
  `A`/`AAAA` and the EDNS-option stripping criterion 4 requires are unverified in unbound. The
  package is pinned in `compose/pins.env` and installed by SF-4 because the image is SF-4's; the
  choice is SF-5's to confirm.
- Anything about the three agent-facing listeners. The holding Squid configuration binds loopback
  only; SF-6 opens them. Criterion 1's per-network listener enumeration is therefore SF-8's, not
  this record's.
- **The audit sink's durability properties.** An external review of SF-4 raised six that this
  sub-feature does not close and SF-7 (audit writer) inherits. Recorded here so they are designed
  against rather than rediscovered:
  - **The audit volume is unbounded and agent-triggerable.** `touch` at start proves the files open;
    it proves nothing about capacity. An agent can generate outbound attempts until the volume
    fills. Squid may then fail on a log write, but the attempt that trips `ENOSPC` is not guaranteed
    recorded, and `cache_log` shares the same volume. R9.1 says every attempt is logged; that holds
    only while there is somewhere to log it.
  - **Rotation is undefined.** `tail -F` follows a pathname; Squid writes through an open descriptor
    until told to reopen. External rename or copytruncate rotation can split, lose or mis-relay
    records unless coordinated with Squid's own rotation path.
  - **Buffering is not pinned as an audit property.** Nothing currently establishes "connection
    accepted implies durable audit line" -- Squid, the file layer and the OS all buffer, there is no
    fsync, and the relay adds another buffered hop. A crash can lose records for attempts that
    already happened.
  - **`tail -n 0` favours loss over duplication across a restart.** Lines written to the volume but
    not yet relayed are skipped when the relay restarts. The durable file still holds them, so this
    is a stdout-sink gap rather than a data-loss bug -- but it means the two sinks are not
    interchangeable, and which one is canonical has to be stated.
  - **Cross-stream ordering is approximate.** The access and cache logs are relayed by separate
    processes to separate streams. Millisecond timestamps help; concurrent attempts can still
    collide and there is no sequence number.
  - **The `error_directory` copy into a 16MB `/run` tmpfs is an unmeasured startup assumption.**
    Sound for the pinned package today. If the packaged set or SF-7's overlay outgrows the headroom,
    `cp` fails under `set -e` and the mediator does not start -- fail-closed, and not an audit
    integrity problem, but it should be measured rather than assumed.

  Two of that review's findings were SF-4's own and are fixed rather than handed on: the relays are
  now supervised alongside the daemons (an unwatched relay stops the stdout sink silently), and the
  supervisor's failure path is reachable at all (see the fix commit).

- The proxy-hop TLS handshake. The listener certificates are mounted and re-issued against the
  `ipam` addresses (`172.31.10.2`, `172.31.30.2`), but nothing terminates TLS until SF-6, so
  SF-8 Phase B remains the assertion that the hop verifies with no insecure-TLS bypass.
