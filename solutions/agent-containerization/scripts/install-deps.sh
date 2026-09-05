#!/usr/bin/env bash
# Checks for (and installs if missing) the host CLI tools this solution's scripts depend on:
# docker, openssl, curl, jq, yq, sbx. macOS and Linux only -- no Windows.
set -euo pipefail

OS="$(uname -s)"

log() { printf '%s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

case "$OS" in
  Darwin | Linux) ;;
  *) log "install-deps: unsupported OS '$OS' -- macOS and Linux only"; exit 1 ;;
esac

install_brew() {
  have brew || { log "install-deps: Homebrew not found -- install it from https://brew.sh first"; exit 1; }
  brew install "$1"
}

install_apt() {
  sudo apt-get update -qq
  sudo apt-get install -y "$1"
}

check_simple() {
  # $1 = command to check, $2 = brew formula, $3 = apt package (defaults to $2 when omitted)
  local cmd="$1" formula="$2" apt_pkg="${3:-$2}"
  if have "$cmd"; then
    log "$cmd: found"
    return
  fi
  log "$cmd: missing, installing..."
  if [[ "$OS" == "Darwin" ]]; then install_brew "$formula"; else install_apt "$apt_pkg"; fi
}

check_docker() {
  if have docker; then
    log "docker: found ($(docker --version))"
    return
  fi
  if [[ "$OS" == "Darwin" ]]; then
    log "docker: missing. Install Docker Desktop manually (not scriptable, needs interactive setup): https://www.docker.com/products/docker-desktop/"
  else
    log "docker: missing, installing via get.docker.com..."
    curl -fsSL https://get.docker.com | sudo sh
  fi
}

check_sbx() {
  if have sbx; then
    log "sbx: found ($(sbx version 2>&1))"
    return
  fi
  case "$OS" in
    Darwin)
      log "sbx: missing (macOS Sonoma 14+, Apple Silicon required). Installing via Homebrew tap..."
      brew install docker/tap/sbx
      ;;
    Linux)
      # https://docs.docker.com/ai/sandboxes/install/ -- Ubuntu 24.04+, KVM hardware virtualization.
      if ! lsmod | grep -q kvm; then
        log "sbx: KVM module not loaded (need kvm_intel/kvm_amd/kvm_arm64) -- see https://docs.docker.com/ai/sandboxes/install/"
        exit 1
      fi
      if have docker; then
        log "sbx: Docker Engine already present, installing sbx-only package..."
        curl -fsSL https://get.docker.com | sudo REPO_ONLY=1 sh
        sudo apt-get install -y docker-sbx
      else
        log "sbx: installing Docker Engine + sbx together..."
        curl -fsSL https://get.docker.com | sudo SBX=1 sh
      fi
      if ! id -nG "$USER" | grep -qw kvm; then
        log "sbx: adding $USER to the kvm group -- sign out/in (or run 'newgrp kvm') to activate"
        sudo usermod -aG kvm "$USER"
      fi
      ;;
  esac
}

check_docker
check_simple openssl openssl
check_simple curl curl
check_simple jq jq
check_simple yq yq
check_sbx

log ""
log "Dependency check complete. If sbx was just installed, authenticate with: sbx login"
