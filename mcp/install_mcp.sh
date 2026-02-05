#!/bin/bash
#
# install_mcp.sh — Dynamic MCP server installer for Claude Code projects.
#
# Installs and removes MCP servers in composable, pattern-based groups.
# All installations are project-scoped (-s project).
#
# Usage:
#   bash install_mcp.sh PATTERN [PATTERN...]          # Install servers
#   bash install_mcp.sh --remove PATTERN [PATTERN...] # Remove servers
#   bash install_mcp.sh list [PATTERN]                # List patterns/servers
#   bash install_mcp.sh --help                        # Show help

set -euo pipefail

#######################################
# Constants
#######################################

readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[0;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_BOLD=$'\033[1m'
readonly COLOR_RESET=$'\033[0m'

readonly VALID_PATTERNS="AWS CDK TERRAFORM DOCUMENTATION ARCHITECTURE SECURITY KUBERNETES CROSSPLANE PRICING GIT GITHUB SERVERLESS"

#######################################
# Logging
#######################################

log_info() {
  printf '%s%s%s\n' "${COLOR_BLUE}" "$1" "${COLOR_RESET}"
}

log_success() {
  printf '%s%s%s\n' "${COLOR_GREEN}" "$1" "${COLOR_RESET}"
}

log_warn() {
  printf '%s%s%s\n' "${COLOR_YELLOW}" "$1" "${COLOR_RESET}" >&2
}

log_error() {
  printf '%s%s%s\n' "${COLOR_RED}" "$1" "${COLOR_RESET}" >&2
}

#######################################
# Convert string to uppercase.
# Arguments:
#   $1 - string to convert
# Outputs:
#   Uppercase string to stdout
#######################################
to_upper() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

#######################################
# Check if a pattern name is valid.
# Arguments:
#   $1 - pattern name (uppercase)
# Returns:
#   0 if valid, 1 if invalid
#######################################
is_valid_pattern() {
  case " ${VALID_PATTERNS} " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

#######################################
# Pattern Registry
#######################################

#######################################
# Get server names for a pattern, one per line.
# Arguments:
#   $1 - pattern name (uppercase)
# Returns:
#   0 on success, 1 if pattern unknown
#######################################
get_pattern_servers() {
  case "$1" in
    AWS)
      printf '%s\n' \
        "awslabs-core-mcp-server" \
        "aws-knowledge-mcp" \
        "awslabs-aws-documentation-mcp-server" \
        "awslabs-diagram-mcp-server"
      ;;
    CDK)
      printf '%s\n' "awslabs-iac-mcp-server"
      ;;
    TERRAFORM)
      printf '%s\n' \
        "terraform-mcp-server" \
        "awslabs-terraform-mcp-server"
      ;;
    DOCUMENTATION)
      printf '%s\n' \
        "awslabs-aws-documentation-mcp-server" \
        "awslabs-code-doc-gen-mcp-server" \
        "context7"
      ;;
    ARCHITECTURE)
      printf '%s\n' \
        "awslabs-diagram-mcp-server" \
        "mermaid-mcp"
      ;;
    SECURITY)
      printf '%s\n' \
        "trivy-mcp" \
        "awslabs-well-architected-security-mcp-server"
      ;;
    KUBERNETES)
      printf '%s\n' "kubernetes-mcp-server"
      ;;
    CROSSPLANE)
      printf '%s\n' "controlplane-mcp-server"
      ;;
    PRICING)
      printf '%s\n' \
        "awslabs-aws-pricing-mcp-server" \
        "awslabs-cost-analysis-mcp-server"
      ;;
    GIT)
      printf '%s\n' "mcp-server-git"
      ;;
    GITHUB)
      printf '%s\n' \
        "github-mcp-server" \
        "mcp-server-git"
      ;;
    SERVERLESS)
      printf '%s\n' "awslabs-serverless-mcp-server"
      ;;
    *) return 1 ;;
  esac
}

#######################################
# Get human-readable description for a pattern.
# Arguments:
#   $1 - pattern name (uppercase)
# Outputs:
#   Description string to stdout
#######################################
get_pattern_description() {
  case "$1" in
    AWS)           printf '%s' "Base AWS development" ;;
    CDK)           printf '%s' "AWS CDK projects" ;;
    TERRAFORM)     printf '%s' "Terraform IaC projects" ;;
    DOCUMENTATION) printf '%s' "Documentation lookup and generation" ;;
    ARCHITECTURE)  printf '%s' "Architecture and design work" ;;
    SECURITY)      printf '%s' "Security scanning and compliance" ;;
    KUBERNETES)    printf '%s' "General Kubernetes management" ;;
    CROSSPLANE)    printf '%s' "Crossplane and Upbound" ;;
    PRICING)       printf '%s' "Cost modeling (temporary use)" ;;
    GIT)           printf '%s' "Local Git repository operations" ;;
    GITHUB)        printf '%s' "GitHub API + local Git operations" ;;
    SERVERLESS)    printf '%s' "Lambda, API Gateway, Step Functions" ;;
    *)             printf '%s' "Unknown pattern" ;;
  esac
}

#######################################
# Count the number of servers in a pattern.
# Arguments:
#   $1 - pattern name (uppercase)
# Outputs:
#   Count to stdout
#######################################
get_pattern_server_count() {
  local count=0
  local line
  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      count=$((count + 1))
    fi
  done <<< "$(get_pattern_servers "$1")"
  printf '%s' "${count}"
}

#######################################
# Server Registry
#######################################

#######################################
# Get the prerequisite tool for a server.
# Arguments:
#   $1 - server name
# Outputs:
#   Tool name to stdout (uvx, npx, docker, trivy, or none)
#######################################
get_server_prereq() {
  case "$1" in
    awslabs-core-mcp-server|\
    awslabs-aws-documentation-mcp-server|\
    awslabs-diagram-mcp-server|\
    awslabs-iac-mcp-server|\
    awslabs-terraform-mcp-server|\
    awslabs-code-doc-gen-mcp-server|\
    awslabs-well-architected-security-mcp-server|\
    awslabs-aws-pricing-mcp-server|\
    awslabs-cost-analysis-mcp-server|\
    awslabs-serverless-mcp-server)
      printf '%s' "uvx" ;;
    context7|\
    mermaid-mcp|\
    kubernetes-mcp-server|\
    mcp-server-git|\
    github-mcp-server)
      printf '%s' "npx" ;;
    terraform-mcp-server|\
    controlplane-mcp-server)
      printf '%s' "docker" ;;
    trivy-mcp)
      printf '%s' "trivy" ;;
    *)
      printf '%s' "none" ;;
  esac
}

#######################################
# Get the install arguments for `claude mcp add`.
# Arguments:
#   $1 - server name
# Outputs:
#   Full argument string to stdout
# Returns:
#   0 on success, 1 if server unknown
#######################################
get_server_install_cmd() {
  case "$1" in
    awslabs-core-mcp-server)
      printf '%s' "awslabs-core-mcp-server -s project -e FASTMCP_LOG_LEVEL=warning -- uvx awslabs.core-mcp-server@latest"
      ;;
    aws-knowledge-mcp)
      printf '%s' "aws-knowledge-mcp -s project --transport http https://knowledge-mcp.global.api.aws"
      ;;
    awslabs-aws-documentation-mcp-server)
      printf '%s' "awslabs-aws-documentation-mcp-server -s project -- uvx awslabs.aws-documentation-mcp-server@latest"
      ;;
    awslabs-diagram-mcp-server)
      printf '%s' "awslabs-diagram-mcp-server -s project -- uvx awslabs.diagram-mcp-server@latest"
      ;;
    awslabs-iac-mcp-server)
      printf '%s' "awslabs-iac-mcp-server -s project -- uvx awslabs.iac-mcp-server@latest"
      ;;
    terraform-mcp-server)
      printf '%s' "terraform-mcp-server -s project -- docker run -i --rm hashicorp/terraform-mcp-server"
      ;;
    awslabs-terraform-mcp-server)
      printf '%s' "awslabs-terraform-mcp-server -s project -- uvx awslabs.terraform-mcp-server@latest"
      ;;
    awslabs-code-doc-gen-mcp-server)
      printf '%s' "awslabs-code-doc-gen-mcp-server -s project -- uvx awslabs.code-doc-gen-mcp-server@latest"
      ;;
    context7)
      printf '%s' "context7 -s project -- npx -y @upstash/context7-mcp@latest"
      ;;
    mermaid-mcp)
      printf '%s' "mermaid-mcp -s project -- npx -y mcp-mermaid@latest"
      ;;
    trivy-mcp)
      printf '%s' "trivy-mcp -s project -- trivy mcp"
      ;;
    awslabs-well-architected-security-mcp-server)
      printf '%s' "awslabs-well-architected-security-mcp-server -s project -- uvx awslabs.well-architected-security-mcp-server@latest"
      ;;
    kubernetes-mcp-server)
      printf '%s' "kubernetes-mcp-server -s project -- npx -y kubernetes-mcp-server@latest"
      ;;
    controlplane-mcp-server)
      printf '%s' "controlplane-mcp-server -s project --transport http -- docker run -i --rm xpkg.upbound.io/upbound/controlplane-mcp-server:v0.1.0"
      ;;
    awslabs-aws-pricing-mcp-server)
      printf '%s' "awslabs-aws-pricing-mcp-server -s project -- uvx awslabs.aws-pricing-mcp-server@latest"
      ;;
    awslabs-cost-analysis-mcp-server)
      printf '%s' "awslabs-cost-analysis-mcp-server -s project -- uvx awslabs.cost-analysis-mcp-server@latest"
      ;;
    mcp-server-git)
      printf '%s' "mcp-server-git -s project -- npx -y @modelcontextprotocol/server-git@latest"
      ;;
    github-mcp-server)
      printf '%s' "github-mcp-server -s project -- npx -y @github/mcp-server@latest"
      ;;
    awslabs-serverless-mcp-server)
      printf '%s' "awslabs-serverless-mcp-server -s project -- uvx awslabs.serverless-mcp-server@latest"
      ;;
    *) return 1 ;;
  esac
}

#######################################
# Get human-readable description for a server.
# Arguments:
#   $1 - server name
# Outputs:
#   Description string to stdout
#######################################
get_server_description() {
  case "$1" in
    awslabs-core-mcp-server)                      printf '%s' "Core AWS API orchestration" ;;
    aws-knowledge-mcp)                            printf '%s' "AWS knowledge base" ;;
    awslabs-aws-documentation-mcp-server)         printf '%s' "AWS documentation search" ;;
    awslabs-diagram-mcp-server)                   printf '%s' "Architecture diagrams" ;;
    awslabs-iac-mcp-server)                       printf '%s' "CDK and CloudFormation" ;;
    terraform-mcp-server)                         printf '%s' "HashiCorp Terraform registry" ;;
    awslabs-terraform-mcp-server)                 printf '%s' "AWS Terraform with Checkov" ;;
    awslabs-code-doc-gen-mcp-server)              printf '%s' "Code documentation generation" ;;
    context7)                                     printf '%s' "Version-specific library docs" ;;
    mermaid-mcp)                                  printf '%s' "Mermaid diagram generation" ;;
    trivy-mcp)                                    printf '%s' "Vulnerability and IaC scanning" ;;
    awslabs-well-architected-security-mcp-server) printf '%s' "AWS security assessment" ;;
    kubernetes-mcp-server)                        printf '%s' "Kubernetes cluster management" ;;
    controlplane-mcp-server)                      printf '%s' "Crossplane control plane" ;;
    awslabs-aws-pricing-mcp-server)               printf '%s' "AWS pricing data" ;;
    awslabs-cost-analysis-mcp-server)             printf '%s' "Pre-deployment cost estimation" ;;
    mcp-server-git)                               printf '%s' "Local Git repository operations" ;;
    github-mcp-server)                            printf '%s' "GitHub API access" ;;
    awslabs-serverless-mcp-server)                printf '%s' "Lambda, API Gateway, Step Functions" ;;
    *)                                            printf '%s' "Unknown server" ;;
  esac
}

#######################################
# Resolution and Validation
#######################################

#######################################
# Resolve patterns to a deduplicated list of server names.
# Arguments:
#   $@ - pattern names (uppercase)
# Outputs:
#   Server names to stdout, one per line, deduplicated
#######################################
resolve_patterns() {
  local seen=""
  local pattern
  local server
  for pattern in "$@"; do
    while IFS= read -r server; do
      if [[ -n "${server}" ]]; then
        case " ${seen} " in
          *" ${server} "*)
            ;;  # already seen
          *)
            printf '%s\n' "${server}"
            seen="${seen} ${server}"
            ;;
        esac
      fi
    done <<< "$(get_pattern_servers "${pattern}")"
  done
}

#######################################
# Validate that all provided pattern names exist.
# Arguments:
#   $@ - pattern names (uppercase)
# Returns:
#   0 if all valid, 1 if any invalid
#######################################
validate_patterns() {
  local has_invalid=false
  local pattern
  for pattern in "$@"; do
    if ! is_valid_pattern "${pattern}"; then
      log_error "Unknown pattern: ${pattern}"
      has_invalid=true
    fi
  done
  if [[ "${has_invalid}" == "true" ]]; then
    log_error "Valid patterns: ${VALID_PATTERNS}"
    return 1
  fi
  return 0
}

#######################################
# Prerequisite Checking
#######################################

#######################################
# Collect unique prerequisite tools needed by a set of servers.
# Arguments:
#   Server names via stdin, one per line
# Outputs:
#   Unique prereq tool names to stdout, one per line
#######################################
collect_prereqs() {
  local seen=""
  local server prereq
  while IFS= read -r server; do
    [[ -z "${server}" ]] && continue
    prereq="$(get_server_prereq "${server}")"
    if [[ "${prereq}" != "none" ]]; then
      case " ${seen} " in
        *" ${prereq} "*)
          ;;  # already seen
        *)
          printf '%s\n' "${prereq}"
          seen="${seen} ${prereq}"
          ;;
      esac
    fi
  done
}

#######################################
# Check prerequisites for installing servers.
# Validates that required tools exist. Docker is a soft
# prerequisite — if missing or not running, docker-based
# servers are skipped rather than failing the operation.
#
# Sets global DOCKER_AVAILABLE (true/false).
#
# Arguments:
#   $1 - newline-separated list of server names
# Returns:
#   0 if all hard prerequisites met, 1 if any missing
#######################################
check_prerequisites() {
  local servers="$1"
  local missing=""
  local prereq

  DOCKER_AVAILABLE=true

  printf '\n%sChecking prerequisites...%s\n' \
    "${COLOR_BOLD}" "${COLOR_RESET}"

  # Always check claude CLI.
  if command -v claude >/dev/null 2>&1; then
    log_success "  ✓ claude CLI found"
  else
    log_error "  ✗ claude CLI not found"
    missing="${missing} claude"
  fi

  # Determine which prereqs are needed by resolved servers.
  local needed_prereqs
  needed_prereqs="$(collect_prereqs <<< "${servers}")"

  while IFS= read -r prereq; do
    [[ -z "${prereq}" ]] && continue
    case "${prereq}" in
      uvx)
        if command -v uvx >/dev/null 2>&1; then
          log_success "  ✓ uvx found"
        else
          log_error "  ✗ uvx not found (install: pip install uv)"
          missing="${missing} uvx"
        fi
        ;;
      npx)
        if command -v npx >/dev/null 2>&1; then
          log_success "  ✓ npx found"
        else
          log_error "  ✗ npx not found (install Node.js)"
          missing="${missing} npx"
        fi
        ;;
      trivy)
        if command -v trivy >/dev/null 2>&1; then
          log_success "  ✓ trivy found"
        else
          log_error "  ✗ trivy not found (install: brew install trivy)"
          missing="${missing} trivy"
        fi
        ;;
      docker)
        if command -v docker >/dev/null 2>&1; then
          if docker info >/dev/null 2>&1; then
            log_success "  ✓ docker found and running"
          else
            log_warn "  ⚠ docker not running — skipping docker-based servers"
            DOCKER_AVAILABLE=false
          fi
        else
          log_warn "  ⚠ docker not found — skipping docker-based servers"
          DOCKER_AVAILABLE=false
        fi
        ;;
    esac
  done <<< "${needed_prereqs}"

  # Report missing hard prerequisites.
  missing="${missing## }"
  if [[ -n "${missing}" ]]; then
    printf '\n'
    log_error "Missing required tools: ${missing}"
    log_error "Install missing tools and try again."
    return 1
  fi

  return 0
}

#######################################
# Installed Server Detection
#######################################

#######################################
# Get currently installed MCP server names.
# Parses `claude mcp list` output. Each server line has the
# format: "server-name: command - status". Extract the name
# before the first colon.
#
# If `claude mcp list` fails, output nothing (assume none
# installed).
#
# Outputs:
#   Installed server names to stdout, one per line
#######################################
get_installed_servers() {
  local output
  if ! output="$(claude mcp list 2>/dev/null)"; then
    return 0
  fi

  local line name
  while IFS= read -r line; do
    # Skip empty lines and header/status lines without a colon.
    [[ -z "${line}" ]] && continue
    case "${line}" in
      *:*)
        # Extract server name (everything before the first colon).
        name="${line%%:*}"
        # Trim leading/trailing whitespace.
        name="$(printf '%s' "${name}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [[ -n "${name}" ]]; then
          printf '%s\n' "${name}"
        fi
        ;;
    esac
  done <<< "${output}"
}

#######################################
# Check if a server name is in a newline-separated list.
# Arguments:
#   $1 - server name to find
#   $2 - newline-separated list of server names
# Returns:
#   0 if found, 1 if not found
#######################################
is_server_installed() {
  local target="$1"
  local installed_list="$2"
  local name
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    if [[ "${name}" == "${target}" ]]; then
      return 0
    fi
  done <<< "${installed_list}"
  return 1
}

#######################################
# Usage
#######################################

usage() {
  cat <<'EOF'
Usage: bash install_mcp.sh [OPTIONS] PATTERN [PATTERN...]
       bash install_mcp.sh list [PATTERN]

Install or remove MCP servers for Claude Code in pattern-based groups.
All installations are project-scoped (-s project).

Actions:
  PATTERN [PATTERN...]          Install servers for the given patterns (default)
  --remove PATTERN [PATTERN...] Remove servers for the given patterns
  list                          List all available patterns
  list PATTERN                  List servers in a specific pattern

Options:
  --help, -h                    Show this help message

Patterns:
  AWS            Base AWS development (core, knowledge, docs, diagrams)
  CDK            AWS CDK and CloudFormation
  TERRAFORM      HashiCorp Terraform + AWS Terraform
  DOCUMENTATION  AWS docs, code doc gen, Context7
  ARCHITECTURE   AWS diagrams, Mermaid
  SECURITY       Trivy scanning, AWS Well-Architected security
  KUBERNETES     General Kubernetes management (Red Hat)
  CROSSPLANE     Crossplane and Upbound
  PRICING        AWS pricing and cost analysis (temporary use)
  GIT            Local Git repository operations
  GITHUB         GitHub API + local Git operations
  SERVERLESS     Lambda, API Gateway, Step Functions

Examples:
  bash install_mcp.sh AWS CDK              # Install AWS + CDK servers
  bash install_mcp.sh AWS TERRAFORM        # Install AWS + Terraform servers
  bash install_mcp.sh --remove PRICING     # Remove pricing servers
  bash install_mcp.sh list                 # Show all patterns
  bash install_mcp.sh list AWS             # Show servers in AWS pattern

Pattern names are case-insensitive (AWS = aws = Aws).
EOF
}

#######################################
# Operations
#######################################

#######################################
# List patterns and their servers.
# Arguments:
#   $@ - optional pattern names (shows all if empty)
#######################################
do_list() {
  if [[ $# -eq 0 ]]; then
    printf '%s%sAvailable Patterns:%s\n' \
      "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
    local pattern count desc server_word count_str
    # shellcheck disable=SC2086
    for pattern in ${VALID_PATTERNS}; do
      count="$(get_pattern_server_count "${pattern}")"
      desc="$(get_pattern_description "${pattern}")"
      if [[ "${count}" -eq 1 ]]; then
        count_str="(1 server) "
      else
        count_str="(${count} servers)"
      fi
      printf '  %-14s %-12s %s\n' "${pattern}" "${count_str}" "${desc}"
    done
    printf '\n'
    printf 'Usage: bash install_mcp.sh PATTERN [PATTERN...]\n'
    printf '       bash install_mcp.sh --remove PATTERN [PATTERN...]\n'
    printf '       bash install_mcp.sh list [PATTERN]\n'
  else
    local pattern
    for pattern in "$@"; do
      local count desc server_word
      count="$(get_pattern_server_count "${pattern}")"
      desc="$(get_pattern_description "${pattern}")"
      if [[ "${count}" -eq 1 ]]; then
        server_word="server"
      else
        server_word="servers"
      fi
      printf '%s%sPattern: %s%s (%s %s)\n' \
        "${COLOR_BOLD}" "${COLOR_BLUE}" "${pattern}" \
        "${COLOR_RESET}" "${count}" "${server_word}"
      printf '  %s\n\n' "${desc}"
      local server prereq server_desc
      while IFS= read -r server; do
        if [[ -n "${server}" ]]; then
          prereq="$(get_server_prereq "${server}")"
          server_desc="$(get_server_description "${server}")"
          printf '  %-45s %s (%s)\n' \
            "${server}" "${server_desc}" "${prereq}"
        fi
      done <<< "$(get_pattern_servers "${pattern}")"
      printf '\n'
    done
  fi
}

#######################################
# Install servers for the given patterns.
# Arguments:
#   $@ - pattern names (uppercase, validated)
#######################################
do_add() {
  local servers
  servers="$(resolve_patterns "$@")"

  # Count total resolved and deduplicated servers.
  local total_resolved=0
  local server
  while IFS= read -r server; do
    [[ -z "${server}" ]] && continue
    total_resolved=$((total_resolved + 1))
  done <<< "${servers}"

  printf '\n%s%sMCP Server Installer%s\n' \
    "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
  printf '====================\n\n'
  printf 'Patterns: %s\n' "$*"
  printf 'Resolved: %s servers\n' "${total_resolved}"

  if ! check_prerequisites "${servers}"; then
    return 1
  fi

  # Filter out docker-based servers if Docker is unavailable.
  local skipped_docker=0
  if [[ "${DOCKER_AVAILABLE}" != "true" ]]; then
    local filtered=""
    local prereq
    while IFS= read -r server; do
      [[ -z "${server}" ]] && continue
      prereq="$(get_server_prereq "${server}")"
      if [[ "${prereq}" == "docker" ]]; then
        skipped_docker=$((skipped_docker + 1))
      else
        if [[ -n "${filtered}" ]]; then
          filtered="${filtered}
${server}"
        else
          filtered="${server}"
        fi
      fi
    done <<< "${servers}"
    servers="${filtered}"
  fi

  # Detect already-installed servers.
  printf '\n%sChecking installed servers...%s\n' \
    "${COLOR_BOLD}" "${COLOR_RESET}"
  local installed
  installed="$(get_installed_servers)"

  local to_install=""
  local skipped_installed=0
  while IFS= read -r server; do
    [[ -z "${server}" ]] && continue
    if is_server_installed "${server}" "${installed}"; then
      log_info "  - ${server} (already installed, skipping)"
      skipped_installed=$((skipped_installed + 1))
    else
      if [[ -n "${to_install}" ]]; then
        to_install="${to_install}
${server}"
      else
        to_install="${server}"
      fi
    fi
  done <<< "${servers}"

  # Count servers to install.
  local install_count=0
  while IFS= read -r server; do
    [[ -z "${server}" ]] && continue
    install_count=$((install_count + 1))
  done <<< "${to_install}"

  if [[ "${install_count}" -eq 0 ]]; then
    printf '\n'
    log_success "All servers already installed. Nothing to do."
    print_add_summary 0 "${skipped_installed}" "${skipped_docker}"
    return 0
  fi

  # Install servers.
  printf '\n%sInstalling servers...%s\n' \
    "${COLOR_BOLD}" "${COLOR_RESET}"

  local current=0
  local installed_count=0
  local failed_count=0
  local install_cmd
  while IFS= read -r server; do
    [[ -z "${server}" ]] && continue
    current=$((current + 1))

    install_cmd="$(get_server_install_cmd "${server}")"
    if [[ -z "${install_cmd}" ]]; then
      log_error "  [${current}/${install_count}] ${server} — unknown server"
      failed_count=$((failed_count + 1))
      continue
    fi

    printf '  [%s/%s] %s ... ' "${current}" "${install_count}" "${server}"

    # Execute: claude mcp add <install_cmd>
    # shellcheck disable=SC2086
    if claude mcp add ${install_cmd} >/dev/null 2>&1; then
      log_success "✓"
      installed_count=$((installed_count + 1))
    else
      log_error "✗ failed"
      failed_count=$((failed_count + 1))
    fi
  done <<< "${to_install}"

  print_add_summary "${installed_count}" "${skipped_installed}" \
    "${skipped_docker}" "${failed_count}"

  if [[ "${failed_count}" -gt 0 ]]; then
    return 1
  fi
  return 0
}

#######################################
# Print summary line for add operation.
# Arguments:
#   $1 - number of servers installed
#   $2 - number skipped (already installed)
#   $3 - number skipped (docker unavailable)
#   $4 - number failed (optional, default 0)
#######################################
print_add_summary() {
  local installed="${1:-0}"
  local skipped="${2:-0}"
  local docker_skipped="${3:-0}"
  local failed="${4:-0}"

  printf '\n%sSummary:%s ' "${COLOR_BOLD}" "${COLOR_RESET}"

  local parts=""
  if [[ "${installed}" -gt 0 ]]; then
    parts="${installed} installed"
  fi
  if [[ "${skipped}" -gt 0 ]]; then
    if [[ -n "${parts}" ]]; then parts="${parts}, "; fi
    parts="${parts}${skipped} skipped (already installed)"
  fi
  if [[ "${docker_skipped}" -gt 0 ]]; then
    if [[ -n "${parts}" ]]; then parts="${parts}, "; fi
    parts="${parts}${docker_skipped} skipped (Docker unavailable)"
  fi
  if [[ "${failed}" -gt 0 ]]; then
    if [[ -n "${parts}" ]]; then parts="${parts}, "; fi
    parts="${parts}${failed} failed"
  fi

  if [[ -z "${parts}" ]]; then
    parts="nothing to do"
  fi

  printf '%s\n' "${parts}"
}

#######################################
# Remove servers for the given patterns.
# Arguments:
#   $@ - pattern names (uppercase, validated)
#######################################
do_remove() {
  local servers
  servers="$(resolve_patterns "$@")"

  # Count servers to remove.
  local total=0
  local server
  while IFS= read -r server; do
    [[ -z "${server}" ]] && continue
    total=$((total + 1))
  done <<< "${servers}"

  printf '\n%s%sMCP Server Remover%s\n' \
    "${COLOR_BOLD}" "${COLOR_BLUE}" "${COLOR_RESET}"
  printf '==================\n\n'
  printf 'Patterns: %s\n' "$*"
  printf 'Removing: %s servers\n\n' "${total}"

  local current=0
  local removed_count=0
  local warned_count=0
  while IFS= read -r server; do
    [[ -z "${server}" ]] && continue
    current=$((current + 1))

    printf '  [%s/%s] %s ... ' "${current}" "${total}" "${server}"

    if claude mcp remove -s project "${server}" >/dev/null 2>&1; then
      log_success "✓ removed"
      removed_count=$((removed_count + 1))
    else
      log_warn "⚠ not installed"
      warned_count=$((warned_count + 1))
    fi
  done <<< "${servers}"

  printf '\n%sSummary:%s ' "${COLOR_BOLD}" "${COLOR_RESET}"

  local parts=""
  if [[ "${removed_count}" -gt 0 ]]; then
    parts="${removed_count} removed"
  fi
  if [[ "${warned_count}" -gt 0 ]]; then
    if [[ -n "${parts}" ]]; then parts="${parts}, "; fi
    parts="${parts}${warned_count} not installed"
  fi
  if [[ -z "${parts}" ]]; then
    parts="nothing to do"
  fi

  printf '%s\n' "${parts}"
}

#######################################
# Main
#######################################

main() {
  if [[ $# -eq 0 ]]; then
    usage
    return 0
  fi

  # Handle list action (must be first argument).
  if [[ "$1" == "list" ]]; then
    shift
    local list_patterns=""
    local upper
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --help|-h)
          usage
          return 0
          ;;
        *)
          upper="$(to_upper "$1")"
          list_patterns="${list_patterns} ${upper}"
          ;;
      esac
      shift
    done
    list_patterns="${list_patterns## }"
    if [[ -n "${list_patterns}" ]]; then
      # shellcheck disable=SC2086
      validate_patterns ${list_patterns} || return 1
      # shellcheck disable=SC2086
      do_list ${list_patterns}
    else
      do_list
    fi
    return 0
  fi

  # Parse add/remove action and patterns.
  local action="add"
  local patterns=""
  local upper
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        return 0
        ;;
      --remove)
        action="remove"
        shift
        ;;
      -*)
        log_error "Unknown option: $1"
        usage >&2
        return 1
        ;;
      *)
        upper="$(to_upper "$1")"
        patterns="${patterns} ${upper}"
        shift
        ;;
    esac
  done

  patterns="${patterns## }"

  if [[ -z "${patterns}" ]]; then
    log_error "No patterns specified."
    usage >&2
    return 1
  fi

  # shellcheck disable=SC2086
  validate_patterns ${patterns} || return 1

  case "${action}" in
    add)
      # shellcheck disable=SC2086
      do_add ${patterns}
      ;;
    remove)
      # shellcheck disable=SC2086
      do_remove ${patterns}
      ;;
  esac
}

main "$@"
