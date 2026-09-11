#!/usr/bin/env bash
# SF-2 harness: verifies whether claude, codex and agy honour HTTPS_PROXY
# (plain and TLS-terminated), can present a client certificate to a TLS
# proxy listener, and — for agy — whether the GEMINI_API_KEY route and
# CA-trust env var actually work. Throwaway fixture only; not the 01.3
# mediator. Requires Docker Desktop and the three CLIs' throwaway API keys
# in the environment: ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY.
#
# 01.6 SF-1 extension: two further listeners require a *proxy credential*
# (`Proxy-Authorization: Basic`), one on each transport, and the matrix gains
# {codex, agy} × {userinfo-in-proxy-URL, no-credential-407-challenge}. The
# TLS credential listener is deliberately `NoClientCert` — the shipped
# `-tls :18443` listener is `RequireAndVerifyClientCert`, where agy dies at
# CertificateRequest and the proxy-credential question is never reached.
# Results are observations recorded in docs/records/agent-verification.md;
# there is no pass/fail helper here, by design.
#
#   SF1_ONLY=1 bash scripts/verify-agent-clients.sh
#     runs the five 01.6 SF-1 proxy-credential cells alone, leaving the six
#     already-recorded 01.1 cells unrun.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$REPO_ROOT/.build-scratch/sf2"
PKI="$SCRATCH/pki"
FIXTURE="$SCRATCH/fixture"
AGENTS="$SCRATCH/agents"
COMPOSE="$SCRATCH/compose"
LOGS="$SCRATCH/logs"

for v in ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_API_KEY; do
  if [[ -z "${!v:-}" ]]; then
    echo "verify-agent-clients: $v is not set. Export the throwaway keys before running." >&2
    exit 64
  fi
done

mkdir -p "$PKI" "$FIXTURE" "$AGENTS" "$COMPOSE" "$LOGS"

# proxy.log is opened O_APPEND and $SCRATCH persists between runs, so a prior
# run's lines would be indistinguishable from this one's in the record's
# evidence. Archive rather than delete — an earlier run's log is the evidence
# behind an already-published record section.
if compgen -G "$LOGS/*.log" >/dev/null; then
  ARCHIVE="$LOGS/archive-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$ARCHIVE"
  mv "$LOGS"/*.log "$ARCHIVE"/
  echo "== archived previous run's logs to $ARCHIVE =="
fi

# Fixture proxy credentials. Throwaway, non-secret, and deliberately
# alphanumeric so the userinfo-in-URL form carries no percent-encoding
# confound: a negative result must mean "the client did not send one", not
# "the client mangled the encoding".
# Exported because the Compose file is written from a quoted heredoc and
# resolves ${FIXTURE_CREDS} from the environment at `docker compose` time.
export FIXTURE_CREDS="sf2codex:sf2pass,sf2agy:sf2pass"

cleanup() {
  if [[ -d "$COMPOSE" ]]; then
    (cd "$COMPOSE" && docker compose down -v >/dev/null 2>&1 || true)
  fi
  docker images --filter "reference=sf2verify-*" -q | xargs -r docker rmi -f >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== generating throwaway PKI =="
# The CA is reused across runs but is issued for 2 days, so "generate if absent"
# silently hands a re-run more than two days later an EXPIRED CA. Every TLS cell
# then fails client-side with `tls: bad certificate` — which reads exactly like
# an agent refusing the proxy's certificate, and is not that. Measured on
# 2026-09-09: a CA issued 2026-09-04 confounded both TLS proxy-credential cells.
# Regenerate when absent, unreadable, or not valid for the next hour.
if [[ ! -f "$PKI/ca.crt" ]] || ! openssl x509 -in "$PKI/ca.crt" -noout -checkend 3600 >/dev/null 2>&1; then
  [[ -f "$PKI/ca.crt" ]] && echo "   (existing CA is expired or unreadable — regenerating)"
  rm -f "$PKI/ca.srl"
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$PKI/ca.key" -out "$PKI/ca.crt" -days 2 -subj "/CN=sf2-verify-ca" >/dev/null 2>&1
fi
cat > "$PKI/server.ext" <<'EOF'
subjectAltName = IP:127.0.0.1, DNS:localhost, DNS:fixture
EOF
openssl req -newkey rsa:2048 -nodes -keyout "$PKI/server.key" -out "$PKI/server.csr" -subj "/CN=sf2-proxy-fixture" >/dev/null 2>&1
openssl x509 -req -in "$PKI/server.csr" -CA "$PKI/ca.crt" -CAkey "$PKI/ca.key" -CAcreateserial -out "$PKI/server.crt" -days 2 -extfile "$PKI/server.ext" >/dev/null 2>&1
for agent in claude codex agy; do
  openssl req -newkey rsa:2048 -nodes -keyout "$PKI/${agent}-client.key" -out "$PKI/${agent}-client.csr" -subj "/CN=sf2-${agent}-client" >/dev/null 2>&1
  openssl x509 -req -in "$PKI/${agent}-client.csr" -CA "$PKI/ca.crt" -CAkey "$PKI/ca.key" -CAcreateserial -out "$PKI/${agent}-client.crt" -days 2 >/dev/null 2>&1
done

echo "== writing fixture (CONNECT proxy: plain, client-cert-required TLS, plain+credential, TLS+credential) =="
cat > "$FIXTURE/go.mod" <<'EOF'
module sf2fixture

go 1.24
EOF
cat > "$FIXTURE/main.go" <<'EOF'
package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"
)

var logFile *os.File

// creds is the set of user:pass pairs the credential-requiring listeners accept.
var creds = map[string]string{}

// seq numbers every event on the credential listeners so that a second CONNECT
// following a 407 is visible as a retry rather than read as a single attempt.
var seq int64

func logLine(mode, target, certInfo, outcome string) {
	fmt.Fprintf(logFile, "%s mode=%s target=%s cert=%s outcome=%s\n",
		time.Now().UTC().Format(time.RFC3339Nano), mode, target, certInfo, outcome)
	logFile.Sync()
}

// logAuthLine is deliberately a separate line shape from logLine: the shipped
// `mode=/target=/cert=/outcome=` shape is quoted verbatim in
// docs/records/agent-verification.md criterion 5, and inserting a field into it
// would break that record's evidence.
func logAuthLine(mode, target, pauth, outcome string) {
	n := atomic.AddInt64(&seq, 1)
	fmt.Fprintf(logFile, "%s seq=%d mode=%s target=%s pauth=%s outcome=%s\n",
		time.Now().UTC().Format(time.RFC3339Nano), n, mode, target, pauth, outcome)
	logFile.Sync()
}

// loggingListener records every accepted TCP connection. This is what
// separates "the client rejected the proxy URL and never dialled" from "the
// client dialled, was challenged, and gave up" — edge case 8. Without it a
// negative result is an absence of evidence rather than evidence.
type loggingListener struct {
	net.Listener
	mode string
}

func (l *loggingListener) Accept() (net.Conn, error) {
	c, err := l.Listener.Accept()
	if err == nil {
		logAuthLine(l.mode, "-", "-", "tcp-accepted from="+c.RemoteAddr().String())
	}
	return c, err
}

// checkBasic returns the presented username and whether the pair is accepted.
// The password is never returned and never logged.
func checkBasic(hdr string) (string, bool) {
	const p = "Basic "
	if !strings.HasPrefix(hdr, p) {
		return "", false
	}
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(hdr[len(p):]))
	if err != nil {
		return "", false
	}
	user, pass, ok := strings.Cut(string(raw), ":")
	if !ok {
		return "", false
	}
	want, known := creds[user]
	return user, known && want == pass
}

func handleAuthConnect(mode string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		pauth := "absent"
		authOK := false
		if hdr := r.Header.Get("Proxy-Authorization"); hdr != "" {
			user, ok := checkBasic(hdr)
			switch {
			case ok:
				pauth, authOK = "user="+user, true
			case user != "":
				pauth = "rejected-user=" + user
			default:
				pauth = "unparseable"
			}
		}
		if r.Method != http.MethodConnect {
			logAuthLine(mode, r.Host, pauth, "rejected-non-connect method="+r.Method)
			http.Error(w, "only CONNECT supported", http.StatusMethodNotAllowed)
			return
		}
		if !authOK {
			w.Header().Set("Proxy-Authenticate", `Basic realm="sf2"`)
			w.WriteHeader(http.StatusProxyAuthRequired)
			logAuthLine(mode, r.Host, pauth, "407-challenged")
			return
		}
		destConn, err := net.DialTimeout("tcp", r.Host, 10*time.Second)
		if err != nil {
			logAuthLine(mode, r.Host, pauth, "dial-failed:"+err.Error())
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		hijacker, ok := w.(http.Hijacker)
		if !ok {
			logAuthLine(mode, r.Host, pauth, "hijack-unsupported")
			http.Error(w, "hijack not supported", http.StatusInternalServerError)
			return
		}
		clientConn, _, err := hijacker.Hijack()
		if err != nil {
			logAuthLine(mode, r.Host, pauth, "hijack-failed:"+err.Error())
			return
		}
		logAuthLine(mode, r.Host, pauth, "tunnel-established")
		clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
		go func() {
			io.Copy(destConn, clientConn)
			destConn.Close()
		}()
		io.Copy(clientConn, destConn)
		clientConn.Close()
	}
}

func handleConnect(mode string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		certInfo := "none"
		if r.TLS != nil && len(r.TLS.PeerCertificates) > 0 {
			certInfo = r.TLS.PeerCertificates[0].Subject.CommonName
		}
		if r.Method != http.MethodConnect {
			logLine(mode, r.Host, certInfo, "rejected-non-connect")
			http.Error(w, "only CONNECT supported", http.StatusMethodNotAllowed)
			return
		}
		destConn, err := net.DialTimeout("tcp", r.Host, 10*time.Second)
		if err != nil {
			logLine(mode, r.Host, certInfo, "dial-failed:"+err.Error())
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		hijacker, ok := w.(http.Hijacker)
		if !ok {
			logLine(mode, r.Host, certInfo, "hijack-unsupported")
			http.Error(w, "hijack not supported", http.StatusInternalServerError)
			return
		}
		clientConn, _, err := hijacker.Hijack()
		if err != nil {
			logLine(mode, r.Host, certInfo, "hijack-failed:"+err.Error())
			return
		}
		logLine(mode, r.Host, certInfo, "tunnel-established")
		clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
		go func() {
			io.Copy(destConn, clientConn)
			destConn.Close()
		}()
		io.Copy(clientConn, destConn)
		clientConn.Close()
	}
}

func main() {
	plainAddr := flag.String("plain", ":18080", "plain HTTP CONNECT proxy addr")
	tlsAddr := flag.String("tls", ":18443", "TLS CONNECT proxy addr, requires client cert")
	plainAuthAddr := flag.String("plainauth", ":18081", "plain HTTP CONNECT proxy addr, requires a proxy credential")
	tlsAuthAddr := flag.String("tlsauth", ":18444", "TLS CONNECT proxy addr, requires a proxy credential, NO client cert")
	credsFlag := flag.String("creds", "sf2user:sf2pass", "comma-separated user:pass list the credential listeners accept")
	certFile := flag.String("cert", "", "server cert (PEM)")
	keyFile := flag.String("key", "", "server key (PEM)")
	caFile := flag.String("ca", "", "client CA for verification (PEM)")
	logPath := flag.String("log", "proxy.log", "log file path")
	flag.Parse()

	for _, pair := range strings.Split(*credsFlag, ",") {
		if u, p, ok := strings.Cut(strings.TrimSpace(pair), ":"); ok && u != "" {
			creds[u] = p
		}
	}

	var err error
	logFile, err = os.OpenFile(*logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		log.Fatal(err)
	}

	errCh := make(chan error, 4)

	go func() {
		srv := &http.Server{Addr: *plainAddr, Handler: handleConnect("plain")}
		log.Printf("plain CONNECT proxy listening on %s", *plainAddr)
		errCh <- srv.ListenAndServe()
	}()

	go func() {
		caCert, err := os.ReadFile(*caFile)
		if err != nil {
			errCh <- err
			return
		}
		caPool := x509.NewCertPool()
		caPool.AppendCertsFromPEM(caCert)
		cert, err := tls.LoadX509KeyPair(*certFile, *keyFile)
		if err != nil {
			errCh <- err
			return
		}
		tlsCfg := &tls.Config{
			Certificates: []tls.Certificate{cert},
			ClientAuth:   tls.RequireAndVerifyClientCert,
			ClientCAs:    caPool,
		}
		srv := &http.Server{Addr: *tlsAddr, TLSConfig: tlsCfg, Handler: handleConnect("tls-mtls")}
		log.Printf("mTLS CONNECT proxy listening on %s (client cert required)", *tlsAddr)
		errCh <- srv.ListenAndServeTLS("", "")
	}()

	// plain HTTP CONNECT, proxy credential required. The transport shape codex
	// is restricted to (01.1 SF-2: it rejects an https:// proxy URL at parse time).
	go func() {
		ln, err := net.Listen("tcp", *plainAuthAddr)
		if err != nil {
			errCh <- err
			return
		}
		srv := &http.Server{
			Handler:  handleAuthConnect("plain-auth"),
			ErrorLog: log.New(logFile, "plain-auth-err ", log.LstdFlags),
		}
		log.Printf("plain CONNECT proxy listening on %s (proxy credential required)", *plainAuthAddr)
		errCh <- srv.Serve(&loggingListener{ln, "plain-auth"})
	}()

	// TLS CONNECT, proxy credential required, and NoClientCert on purpose: agy's
	// real hop to the mediator is TLS, and on the RequireAndVerifyClientCert
	// listener above it dies at CertificateRequest before the credential
	// question is ever put to it (01.1 SF-2, criterion 5).
	go func() {
		cert, err := tls.LoadX509KeyPair(*certFile, *keyFile)
		if err != nil {
			errCh <- err
			return
		}
		ln, err := net.Listen("tcp", *tlsAuthAddr)
		if err != nil {
			errCh <- err
			return
		}
		srv := &http.Server{
			Handler: handleAuthConnect("tls-auth"),
			TLSConfig: &tls.Config{
				Certificates: []tls.Certificate{cert},
				ClientAuth:   tls.NoClientCert,
				// http/1.1 ONLY. Go's ServeTLS otherwise advertises h2 over
				// ALPN; agy negotiates it and then writes an HTTP/1.1 CONNECT,
				// which the h2 server rejects as
				//   `bogus greeting "CONNECT generativelangua"`.
				// The proxy-credential question is never reached, and the
				// symptom reads like a client defect rather than a fixture
				// one. A CONNECT proxy has no h2 story; measured 2026-09-09.
				NextProtos: []string{"http/1.1"},
			},
			ErrorLog: log.New(logFile, "tls-auth-err ", log.LstdFlags),
		}
		log.Printf("TLS CONNECT proxy listening on %s (proxy credential required, no client cert)", *tlsAuthAddr)
		errCh <- srv.ServeTLS(&loggingListener{ln, "tls-auth"}, "", "")
	}()

	log.Fatal(<-errCh)
}
EOF
cat > "$FIXTURE/Dockerfile" <<'EOF'
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY main.go go.mod ./
RUN go build -o /out/proxy-fixture main.go

FROM alpine:3.20
COPY --from=build /out/proxy-fixture /usr/local/bin/proxy-fixture
ENTRYPOINT ["/usr/local/bin/proxy-fixture"]
EOF

echo "== writing agent probe images =="
cat > "$AGENTS/probe-claude.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
echo "=== env ==="
echo "HTTPS_PROXY=${HTTPS_PROXY:-unset}"
echo "NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS:-unset}"
echo "CLAUDE_CODE_CLIENT_CERT=${CLAUDE_CODE_CLIENT_CERT:-unset}"
echo "=== claude --version ==="
claude --version
echo "=== probe ==="
timeout 25s claude -p "Say OK and nothing else." 2>&1
echo "=== exit code: $? ==="
EOF
cat > "$AGENTS/Dockerfile.claude" <<'EOF'
FROM node:22-alpine
RUN apk add --no-cache ca-certificates bash
RUN npm install -g @anthropic-ai/claude-code@2.1.260
COPY probe-claude.sh /probe.sh
ENTRYPOINT ["bash", "/probe.sh"]
EOF

cat > "$AGENTS/probe-codex.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
echo "=== env ==="
echo "HTTPS_PROXY=${HTTPS_PROXY:-unset}"
echo "CODEX_CA_CERTIFICATE=${CODEX_CA_CERTIFICATE:-unset}"
echo "=== codex --version ==="
codex --version
echo "=== proxy-credential knob search ==="
# The userinfo-in-URL form is measured by the fixture. This answers the other
# half of the question: does the client expose any configuration surface for
# supplying a proxy credential directly? A negative here means the header form
# has no source other than the URL, which is itself the finding.
codex --help 2>&1 | grep -i -E "proxy|auth" || echo "(no proxy/auth match in --help)"
for d in /usr/local/lib/node_modules/@openai/codex; do
  [ -d "$d" ] || continue
  grep -ra -o -E 'Proxy-Authorization|proxy_auth[a-z_]*|proxy_(user|username|pass|password)' "$d" 2>/dev/null \
    | sed 's/^.*://' | sort -u | head -20 || true
done
echo "(end knob search)"
echo "=== login ==="
printf '%s' "$OPENAI_API_KEY" | codex login --with-api-key 2>&1
echo "=== probe ==="
timeout 25s codex exec --skip-git-repo-check "Say OK and nothing else." < /dev/null 2>&1
echo "=== exit code: $? ==="
EOF
cat > "$AGENTS/Dockerfile.codex" <<'EOF'
FROM node:22-alpine
RUN apk add --no-cache ca-certificates bash
RUN npm install -g @openai/codex@0.152.1
COPY probe-codex.sh /probe.sh
ENTRYPOINT ["bash", "/probe.sh"]
EOF

cat > "$AGENTS/agy-settings.json" <<'EOF'
{
  "modelProvider": "gemini"
}
EOF
cat > "$AGENTS/probe-agy.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
echo "=== env ==="
echo "HTTPS_PROXY=${HTTPS_PROXY:-unset}"
echo "GEMINI_API_KEY set: $([ -n "${GEMINI_API_KEY:-}" ] && echo yes || echo no)"
echo "SSL_CERT_FILE=${SSL_CERT_FILE:-unset}"
echo "CACERT_PATH=${CACERT_PATH:-unset}"
echo "=== agy --version ==="
agy --version
echo "=== proxy-credential knob search ==="
agy --help 2>&1 | grep -i -E "proxy|auth" || echo "(no proxy/auth match in --help)"
AGY_BIN="$(command -v agy || true)"
if [ -n "$AGY_BIN" ]; then
  AGY_REAL="$(readlink -f "$AGY_BIN" 2>/dev/null || echo "$AGY_BIN")"
  echo "agy bin: $AGY_REAL"
  grep -a -o -E 'Proxy-Authorization|proxy_auth[a-z_]*|proxy_(user|username|pass|password)' "$AGY_REAL" 2>/dev/null \
    | sort -u | head -20 || echo "(no match in binary)"
fi
echo "(end knob search)"
echo "=== probe ==="
timeout 25s agy --print "Say OK and nothing else." < /dev/null 2>&1
echo "=== exit code: $? ==="
EOF
# agy has no published Alpine/musl build (verified: 404 on linux_arm64_musl.json
# manifest) — Debian slim (glibc) is required, unlike the node:*-alpine images
# used for claude and codex.
cat > "$AGENTS/Dockerfile.agy" <<'EOF'
FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates bash curl && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"
COPY probe-agy.sh /probe.sh
COPY agy-settings.json /root/.gemini/antigravity-cli/settings.json
ENTRYPOINT ["bash", "/probe.sh"]
EOF

echo "== writing compose file =="
cat > "$COMPOSE/docker-compose.yml" <<'EOF'
name: sf2verify
networks:
  internal:
    internal: true
  egress:

services:
  fixture:
    build: ../fixture
    command: ["-plain", ":18080", "-tls", ":18443", "-plainauth", ":18081", "-tlsauth", ":18444", "-creds", "${FIXTURE_CREDS}", "-cert", "/pki/server.crt", "-key", "/pki/server.key", "-ca", "/pki/ca.crt", "-log", "/logs/proxy.log"]
    networks: [internal, egress]
    volumes:
      - ../pki:/pki:ro
      - ../logs:/logs

  claude-plain:
    build: {context: ../agents, dockerfile: Dockerfile.claude}
    networks: [internal]
    environment:
      HTTPS_PROXY: "http://fixture:18080"
      https_proxy: "http://fixture:18080"
      ANTHROPIC_API_KEY: "${ANTHROPIC_API_KEY}"
    depends_on: [fixture]
    volumes: ["../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/claude-plain.log 2>&1"]

  claude-mtls:
    build: {context: ../agents, dockerfile: Dockerfile.claude}
    networks: [internal]
    environment:
      HTTPS_PROXY: "https://fixture:18443"
      https_proxy: "https://fixture:18443"
      NODE_EXTRA_CA_CERTS: "/pki/ca.crt"
      CLAUDE_CODE_CLIENT_CERT: "/pki/claude-client.crt"
      CLAUDE_CODE_CLIENT_KEY: "/pki/claude-client.key"
      ANTHROPIC_API_KEY: "${ANTHROPIC_API_KEY}"
    depends_on: [fixture]
    volumes: ["../pki:/pki:ro", "../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/claude-mtls.log 2>&1"]

  codex-plain:
    build: {context: ../agents, dockerfile: Dockerfile.codex}
    networks: [internal]
    environment:
      HTTPS_PROXY: "http://fixture:18080"
      https_proxy: "http://fixture:18080"
      OPENAI_API_KEY: "${OPENAI_API_KEY}"
    depends_on: [fixture]
    volumes: ["../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/codex-plain.log 2>&1"]

  codex-mtls:
    build: {context: ../agents, dockerfile: Dockerfile.codex}
    networks: [internal]
    environment:
      HTTPS_PROXY: "https://fixture:18443"
      https_proxy: "https://fixture:18443"
      CODEX_CA_CERTIFICATE: "/pki/ca.crt"
      OPENAI_API_KEY: "${OPENAI_API_KEY}"
    depends_on: [fixture]
    volumes: ["../pki:/pki:ro", "../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/codex-mtls.log 2>&1"]

  agy-plain:
    build: {context: ../agents, dockerfile: Dockerfile.agy}
    networks: [internal]
    environment:
      HTTPS_PROXY: "http://fixture:18080"
      https_proxy: "http://fixture:18080"
      GEMINI_API_KEY: "${GOOGLE_API_KEY}"
    depends_on: [fixture]
    volumes: ["../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/agy-plain.log 2>&1"]

  agy-mtls:
    build: {context: ../agents, dockerfile: Dockerfile.agy}
    networks: [internal]
    environment:
      HTTPS_PROXY: "https://fixture:18443"
      https_proxy: "https://fixture:18443"
      SSL_CERT_FILE: "/pki/ca.crt"
      GEMINI_API_KEY: "${GOOGLE_API_KEY}"
    depends_on: [fixture]
    volumes: ["../pki:/pki:ro", "../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/agy-mtls.log 2>&1"]

  # ---- 01.6 SF-1: proxy-credential capability ----
  # codex is measured on the plain transport only: 01.1 SF-2 already measured
  # that it rejects an https:// proxy URL at parse time, and that cell is
  # inherited rather than re-run.

  codex-plainauth-userinfo:
    build: {context: ../agents, dockerfile: Dockerfile.codex}
    networks: [internal]
    environment:
      HTTPS_PROXY: "http://sf2codex:sf2pass@fixture:18081"
      https_proxy: "http://sf2codex:sf2pass@fixture:18081"
      OPENAI_API_KEY: "${OPENAI_API_KEY}"
    depends_on: [fixture]
    volumes: ["../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/codex-plainauth-userinfo.log 2>&1"]

  # No credential in the URL: measures what the client does with a 407
  # challenge, which is the only surface left for the header form if no
  # configuration knob exists.
  codex-plainauth-challenge:
    build: {context: ../agents, dockerfile: Dockerfile.codex}
    networks: [internal]
    environment:
      HTTPS_PROXY: "http://fixture:18081"
      https_proxy: "http://fixture:18081"
      OPENAI_API_KEY: "${OPENAI_API_KEY}"
    depends_on: [fixture]
    volumes: ["../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/codex-plainauth-challenge.log 2>&1"]

  # agy is measured on the TLS transport, which is its real hop to the
  # mediator, and additionally on plain — which separates "agy does no proxy
  # auth at all" from "agy does no proxy auth over a TLS proxy hop".
  agy-tlsauth-userinfo:
    build: {context: ../agents, dockerfile: Dockerfile.agy}
    networks: [internal]
    environment:
      HTTPS_PROXY: "https://sf2agy:sf2pass@fixture:18444"
      https_proxy: "https://sf2agy:sf2pass@fixture:18444"
      SSL_CERT_FILE: "/pki/ca.crt"
      GEMINI_API_KEY: "${GOOGLE_API_KEY}"
    depends_on: [fixture]
    volumes: ["../pki:/pki:ro", "../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/agy-tlsauth-userinfo.log 2>&1"]

  agy-tlsauth-challenge:
    build: {context: ../agents, dockerfile: Dockerfile.agy}
    networks: [internal]
    environment:
      HTTPS_PROXY: "https://fixture:18444"
      https_proxy: "https://fixture:18444"
      SSL_CERT_FILE: "/pki/ca.crt"
      GEMINI_API_KEY: "${GOOGLE_API_KEY}"
    depends_on: [fixture]
    volumes: ["../pki:/pki:ro", "../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/agy-tlsauth-challenge.log 2>&1"]

  agy-plainauth-userinfo:
    build: {context: ../agents, dockerfile: Dockerfile.agy}
    networks: [internal]
    environment:
      HTTPS_PROXY: "http://sf2agy:sf2pass@fixture:18081"
      https_proxy: "http://sf2agy:sf2pass@fixture:18081"
      GEMINI_API_KEY: "${GOOGLE_API_KEY}"
    depends_on: [fixture]
    volumes: ["../logs:/logs"]
    entrypoint: ["sh", "-c", "bash /probe.sh > /logs/agy-plainauth-userinfo.log 2>&1"]
EOF

# SF1_ONLY=1 runs the 01.6 SF-1 proxy-credential cells alone. The six original
# cells are already recorded under criteria 4 and 5, and re-running them bills a
# third API key to re-measure a settled question — as well as mixing their lines
# into the log that is this criterion's evidence.
PROBE_SVCS=(claude-plain claude-mtls codex-plain codex-mtls agy-plain agy-mtls
            codex-plainauth-userinfo codex-plainauth-challenge
            agy-tlsauth-userinfo agy-tlsauth-challenge agy-plainauth-userinfo)
if [[ -n "${SF1_ONLY:-}" ]]; then
  PROBE_SVCS=(codex-plainauth-userinfo codex-plainauth-challenge
              agy-tlsauth-userinfo agy-tlsauth-challenge agy-plainauth-userinfo)
  echo "== SF1_ONLY set — running the 01.6 SF-1 proxy-credential cells only =="
fi

echo "== building images =="
(cd "$COMPOSE" && docker compose build fixture "${PROBE_SVCS[@]}")

echo "== starting fixture =="
(cd "$COMPOSE" && docker compose up -d fixture)
sleep 2

echo "== running probes =="
for svc in "${PROBE_SVCS[@]}"; do
  echo "-- $svc --"
  (cd "$COMPOSE" && docker compose run --rm "$svc" >/dev/null 2>&1) || true
done

echo ""
echo "== proxy.log (CONNECT / tunnel evidence) =="
cat "$LOGS/proxy.log" 2>&1 || echo "(no proxy.log — fixture never received a CONNECT)"

echo ""
echo "== per-agent probe output =="
for f in "$LOGS"/*.log; do
  [[ "$(basename "$f")" == "proxy.log" ]] && continue
  echo "--- $(basename "$f") ---"
  cat "$f"
  echo ""
done

echo "Done. Results are observations, not pass/fail — see docs/records/agent-verification.md for the recorded conclusions."
