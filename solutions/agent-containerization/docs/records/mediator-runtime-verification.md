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

**What actually arrived.** A resolution from the agent, and the mediator's resolver log:

```
claude$ getent hosts example.com     # exit 2 -- REFUSED by the mediator's resolver

mediator$ unbound[17:0] info: 172.31.10.3 example.com. A IN
          unbound[17:0] info: 172.31.10.3 example.com. AAAA IN
```

`172.31.10.3` is the `claude` container's address on `claude-net`. The query left the agent, was
re-originated by the embedded resolver to `172.31.10.2` — the mediator's static address on that
network — and was refused there. The redirect carries real queries across an `internal: true`
bridge to a container address, and the agent's resolution fails when the mediator refuses it.

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
- The proxy-hop TLS handshake. The listener certificates are mounted and re-issued against the
  `ipam` addresses (`172.31.10.2`, `172.31.30.2`), but nothing terminates TLS until SF-6, so
  SF-8 Phase B remains the assertion that the hop verifies with no insecure-TLS bypass.
