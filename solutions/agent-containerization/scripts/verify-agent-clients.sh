#!/usr/bin/env bash
# SF-2 harness: verifies whether claude, codex and agy honour HTTPS_PROXY
# (plain and TLS-terminated), can present a client certificate to a TLS
# proxy listener, and — for agy — whether the GEMINI_API_KEY route and
# CA-trust env var actually work. Throwaway fixture only; not the 01.3
# mediator. Requires Docker Desktop and the three CLIs' throwaway API keys
# in the environment: ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY.
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

cleanup() {
  if [[ -d "$COMPOSE" ]]; then
    (cd "$COMPOSE" && docker compose down -v >/dev/null 2>&1 || true)
  fi
  docker images --filter "reference=sf2verify-*" -q | xargs -r docker rmi -f >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== generating throwaway PKI =="
if [[ ! -f "$PKI/ca.crt" ]]; then
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

echo "== writing fixture (CONNECT proxy, plain + client-cert-required TLS) =="
cat > "$FIXTURE/go.mod" <<'EOF'
module sf2fixture

go 1.24
EOF
cat > "$FIXTURE/main.go" <<'EOF'
package main

import (
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"time"
)

var logFile *os.File

func logLine(mode, target, certInfo, outcome string) {
	fmt.Fprintf(logFile, "%s mode=%s target=%s cert=%s outcome=%s\n",
		time.Now().UTC().Format(time.RFC3339Nano), mode, target, certInfo, outcome)
	logFile.Sync()
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
	certFile := flag.String("cert", "", "server cert (PEM)")
	keyFile := flag.String("key", "", "server key (PEM)")
	caFile := flag.String("ca", "", "client CA for verification (PEM)")
	logPath := flag.String("log", "proxy.log", "log file path")
	flag.Parse()

	var err error
	logFile, err = os.OpenFile(*logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		log.Fatal(err)
	}

	errCh := make(chan error, 2)

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
    command: ["-plain", ":18080", "-tls", ":18443", "-cert", "/pki/server.crt", "-key", "/pki/server.key", "-ca", "/pki/ca.crt", "-log", "/logs/proxy.log"]
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
EOF

echo "== building images =="
(cd "$COMPOSE" && docker compose build)

echo "== starting fixture =="
(cd "$COMPOSE" && docker compose up -d fixture)
sleep 2

echo "== running probes =="
for svc in claude-plain claude-mtls codex-plain codex-mtls agy-plain agy-mtls; do
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
