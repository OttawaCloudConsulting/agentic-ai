#!/bin/bash
set -euo pipefail

# =============================================================================
# test-terraform.sh — Portable Terraform validation and deployment script
#
# Validates and optionally deploys Terraform configurations. Works in any
# AWS-focused Terraform repository without hardcoded paths or project-specific
# assumptions.
#
# Usage:
#   bash test-terraform.sh                          # validate all + plan
#   bash test-terraform.sh --target modules/vpc     # validate specific dir
#   bash test-terraform.sh --no-plan                # validate only, no plan
#   bash test-terraform.sh --deploy                 # validate + plan + apply
#   bash test-terraform.sh --deploy-destroy         # validate + plan + apply + destroy
#   bash test-terraform.sh --profile my-profile     # use specific AWS profile
#   bash test-terraform.sh --soft-fail              # security findings as warnings
#   bash test-terraform.sh --scanner trivy          # use trivy instead of checkov
#   bash test-terraform.sh --help
#
# Configuration:
#   Place a .test-terraform.conf file in the project root (CWD).
#   See --help output for all config variables.
#
# Precedence: CLI flags > environment variables > config file > defaults
# =============================================================================

# ---- Defaults ----------------------------------------------------------------

PROJECT_ROOT="$(pwd)"
DEFAULT_OUTPUT_DIR="./test-results"
DEFAULT_SCANNER="checkov"
DEFAULT_DESTROY_TIMEOUT=60
CONFIG_FILE=".test-terraform.conf"

# ---- Colors ------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---- Counters ----------------------------------------------------------------

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# ---- Output helpers ----------------------------------------------------------

print_step() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Step $1: $2${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}  pass  $1${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_warning() {
    echo -e "${YELLOW}  warn  $1${NC}"
    WARN_COUNT=$((WARN_COUNT + 1))
}

print_error() {
    echo -e "${RED}  FAIL  $1${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_info() {
    echo -e "  ....  $1"
}

# ---- Usage -------------------------------------------------------------------

usage() {
    cat <<'USAGE'
Usage: bash test-terraform.sh [OPTIONS]

Options:
  --target <path>       Validate a specific directory (relative to project root)
  --no-plan             Stop after validation steps (no terraform plan)
  --deploy              Validate + plan + apply (resources left deployed)
  --deploy-destroy      Validate + plan + apply + pause + destroy
  --profile <name>      Use a specific AWS CLI profile
  --soft-fail           Security scan findings are warnings, not failures
  --scanner <name>      Security scanner: checkov (default) or trivy
  --output-dir <path>   Directory for reports and plan files (default: ./test-results/)
  --help                Show this help message

Configuration File (.test-terraform.conf):
  TF_TEST_DIRS          Space-separated directories to validate (relative paths)
  TF_DEPLOY_DIRS        Space-separated directories eligible for plan/apply
  AWS_PROFILE           AWS CLI profile name
  TFLINT_CONFIG         Path to .tflint.hcl (default: auto-detect in project root)
  TF_SCANNER            Security scanner: checkov or trivy
  TF_OUTPUT_DIR         Output directory for reports
  TF_DESTROY_TIMEOUT    Seconds to wait before auto-destroy in CI (default: 60)

Precedence: CLI flags > environment variables > config file > defaults

Examples:
  bash test-terraform.sh
  bash test-terraform.sh --target modules/vpc
  bash test-terraform.sh --deploy --profile dev-account
  bash test-terraform.sh --deploy-destroy --soft-fail
  bash test-terraform.sh --scanner trivy --output-dir ./reports
USAGE
    exit 0
}

# ---- Configuration loading ---------------------------------------------------

# Save caller's environment variables before sourcing config file.
# This ensures env vars set by the caller take precedence over config file values.
save_caller_env() {
    _CALLER_TF_TEST_DIRS="${TF_TEST_DIRS:-}"
    _CALLER_TF_DEPLOY_DIRS="${TF_DEPLOY_DIRS:-}"
    _CALLER_AWS_PROFILE="${AWS_PROFILE:-}"
    _CALLER_TFLINT_CONFIG="${TFLINT_CONFIG:-}"
    _CALLER_TF_SCANNER="${TF_SCANNER:-}"
    _CALLER_TF_OUTPUT_DIR="${TF_OUTPUT_DIR:-}"
    _CALLER_TF_DESTROY_TIMEOUT="${TF_DESTROY_TIMEOUT:-}"
}

# Restore caller's env vars over config file values (env > config).
restore_caller_env() {
    if [[ -n "$_CALLER_TF_TEST_DIRS" ]]; then TF_TEST_DIRS="$_CALLER_TF_TEST_DIRS"; fi
    if [[ -n "$_CALLER_TF_DEPLOY_DIRS" ]]; then TF_DEPLOY_DIRS="$_CALLER_TF_DEPLOY_DIRS"; fi
    if [[ -n "$_CALLER_AWS_PROFILE" ]]; then AWS_PROFILE="$_CALLER_AWS_PROFILE"; fi
    if [[ -n "$_CALLER_TFLINT_CONFIG" ]]; then TFLINT_CONFIG="$_CALLER_TFLINT_CONFIG"; fi
    if [[ -n "$_CALLER_TF_SCANNER" ]]; then TF_SCANNER="$_CALLER_TF_SCANNER"; fi
    if [[ -n "$_CALLER_TF_OUTPUT_DIR" ]]; then TF_OUTPUT_DIR="$_CALLER_TF_OUTPUT_DIR"; fi
    if [[ -n "$_CALLER_TF_DESTROY_TIMEOUT" ]]; then TF_DESTROY_TIMEOUT="$_CALLER_TF_DESTROY_TIMEOUT"; fi
}

load_config() {
    save_caller_env

    if [[ -f "$PROJECT_ROOT/$CONFIG_FILE" ]]; then
        print_info "Loading config: $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/$CONFIG_FILE"
    fi

    restore_caller_env

    # Apply defaults for anything still unset
    TF_TEST_DIRS="${TF_TEST_DIRS:-}"
    TF_DEPLOY_DIRS="${TF_DEPLOY_DIRS:-}"
    TFLINT_CONFIG="${TFLINT_CONFIG:-}"
    TF_SCANNER="${TF_SCANNER:-$DEFAULT_SCANNER}"
    TF_OUTPUT_DIR="${TF_OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"
    TF_DESTROY_TIMEOUT="${TF_DESTROY_TIMEOUT:-$DEFAULT_DESTROY_TIMEOUT}"
}

# ---- Argument parsing --------------------------------------------------------

# CLI flag variables — empty means "not set by CLI"
_CLI_TARGET=""
_CLI_NO_PLAN=""
_CLI_DEPLOY=""
_CLI_DEPLOY_DESTROY=""
_CLI_PROFILE=""
_CLI_SOFT_FAIL=""
_CLI_SCANNER=""
_CLI_OUTPUT_DIR=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target)
                [[ $# -lt 2 ]] && { echo -e "${RED}--target requires a path argument${NC}"; exit 1; }
                _CLI_TARGET="$2"
                shift 2
                ;;
            --no-plan)
                _CLI_NO_PLAN="true"
                shift
                ;;
            --deploy)
                _CLI_DEPLOY="true"
                shift
                ;;
            --deploy-destroy)
                _CLI_DEPLOY_DESTROY="true"
                shift
                ;;
            --profile)
                [[ $# -lt 2 ]] && { echo -e "${RED}--profile requires a name argument${NC}"; exit 1; }
                _CLI_PROFILE="$2"
                shift 2
                ;;
            --soft-fail)
                _CLI_SOFT_FAIL="true"
                shift
                ;;
            --scanner)
                [[ $# -lt 2 ]] && { echo -e "${RED}--scanner requires a name argument (checkov or trivy)${NC}"; exit 1; }
                _CLI_SCANNER="$2"
                shift 2
                ;;
            --output-dir)
                [[ $# -lt 2 ]] && { echo -e "${RED}--output-dir requires a path argument${NC}"; exit 1; }
                _CLI_OUTPUT_DIR="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Run with --help for usage information."
                exit 1
                ;;
        esac
    done

    # Validate mutually exclusive flags
    if [[ "$_CLI_NO_PLAN" == "true" && "$_CLI_DEPLOY" == "true" ]]; then
        echo -e "${RED}--no-plan and --deploy are mutually exclusive${NC}"
        exit 1
    fi
    if [[ "$_CLI_NO_PLAN" == "true" && "$_CLI_DEPLOY_DESTROY" == "true" ]]; then
        echo -e "${RED}--no-plan and --deploy-destroy are mutually exclusive${NC}"
        exit 1
    fi
    if [[ "$_CLI_DEPLOY" == "true" && "$_CLI_DEPLOY_DESTROY" == "true" ]]; then
        echo -e "${RED}--deploy and --deploy-destroy are mutually exclusive${NC}"
        exit 1
    fi

    # Validate scanner value
    if [[ -n "$_CLI_SCANNER" && "$_CLI_SCANNER" != "checkov" && "$_CLI_SCANNER" != "trivy" ]]; then
        echo -e "${RED}Invalid scanner: $_CLI_SCANNER (must be 'checkov' or 'trivy')${NC}"
        exit 1
    fi
}

# Apply CLI flags over config/env values (CLI > env > config)
apply_cli_overrides() {
    if [[ -n "$_CLI_PROFILE" ]]; then export AWS_PROFILE="$_CLI_PROFILE"; fi
    if [[ -n "$_CLI_SCANNER" ]]; then TF_SCANNER="$_CLI_SCANNER"; fi
    if [[ -n "$_CLI_OUTPUT_DIR" ]]; then TF_OUTPUT_DIR="$_CLI_OUTPUT_DIR"; fi

    # Resolve execution mode
    NO_PLAN="${_CLI_NO_PLAN:-false}"
    DEPLOY="${_CLI_DEPLOY:-false}"
    DEPLOY_DESTROY="${_CLI_DEPLOY_DESTROY:-false}"
    SOFT_FAIL="${_CLI_SOFT_FAIL:-false}"

    # Validate scanner value from config/env
    if [[ "$TF_SCANNER" != "checkov" && "$TF_SCANNER" != "trivy" ]]; then
        echo -e "${RED}Invalid TF_SCANNER value: $TF_SCANNER (must be 'checkov' or 'trivy')${NC}"
        exit 1
    fi
}

# ---- Directory resolution ----------------------------------------------------

resolve_directories() {
    # If --target is set, it becomes the only directory to validate
    if [[ -n "$_CLI_TARGET" ]]; then
        TF_TEST_DIRS="$_CLI_TARGET"
        # Target is also deploy-eligible if deploy was requested
        if [[ "$DEPLOY" == "true" || "$DEPLOY_DESTROY" == "true" ]]; then
            TF_DEPLOY_DIRS="$_CLI_TARGET"
        else
            TF_DEPLOY_DIRS=""
        fi
    fi

    # Fallback: no dirs configured and no target — use CWD
    if [[ -z "$TF_TEST_DIRS" ]]; then
        TF_TEST_DIRS="."
        print_info "No TF_TEST_DIRS configured and no --target given. Using current directory."
    fi

    # Convert space-separated strings to arrays
    read -ra VALIDATE_DIRS <<< "$TF_TEST_DIRS"
    if [[ -n "$TF_DEPLOY_DIRS" ]]; then
        read -ra PLAN_DIRS <<< "$TF_DEPLOY_DIRS"
    else
        PLAN_DIRS=()
    fi
}

# ---- Directory pre-validation ------------------------------------------------

validate_directories() {
    local errors=()

    for dir in "${VALIDATE_DIRS[@]}"; do
        local abs_dir="$PROJECT_ROOT/$dir"
        # Handle "." specially
        [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"

        if [[ ! -d "$abs_dir" ]]; then
            errors+=("Directory does not exist: $dir")
        elif ! ls "$abs_dir"/*.tf >/dev/null 2>&1; then
            errors+=("Directory contains no .tf files: $dir")
        fi
    done

    # Also validate deploy dirs
    for dir in "${PLAN_DIRS[@]+"${PLAN_DIRS[@]}"}"; do
        local abs_dir="$PROJECT_ROOT/$dir"
        [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"

        if [[ ! -d "$abs_dir" ]]; then
            errors+=("Deploy directory does not exist: $dir")
        elif ! ls "$abs_dir"/*.tf >/dev/null 2>&1; then
            errors+=("Deploy directory contains no .tf files: $dir")
        fi
    done

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo -e "${RED}Directory pre-validation failed:${NC}"
        for err in "${errors[@]}"; do
            echo -e "${RED}  - $err${NC}"
        done
        echo ""
        echo "Check TF_TEST_DIRS and TF_DEPLOY_DIRS in your .test-terraform.conf"
        echo "or use --target <path> to specify a directory."
        exit 1
    fi

    print_success "Directory pre-validation passed (${#VALIDATE_DIRS[@]} validate, ${#PLAN_DIRS[@]} deploy-eligible)"
}

# ---- Short label helper ------------------------------------------------------

label() {
    local dir="$1"
    [[ "$dir" == "." ]] && echo "." || echo "$dir"
}

# ---- Print resolved configuration -------------------------------------------

print_config() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Portable Terraform Test Runner${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "  Project root:  $PROJECT_ROOT"
    local config_label="none"
    if [[ -f "$PROJECT_ROOT/$CONFIG_FILE" ]]; then config_label="$CONFIG_FILE"; fi
    echo -e "  Config file:   $config_label"
    echo -e "  Validate dirs: ${TF_TEST_DIRS}"
    echo -e "  Deploy dirs:   ${TF_DEPLOY_DIRS:-none}"
    echo -e "  Scanner:       $TF_SCANNER"
    echo -e "  Output dir:    $TF_OUTPUT_DIR"
    echo -e "  Mode:          $(resolve_mode_label)"
    echo -e "  Soft-fail:     $SOFT_FAIL"
    if [[ -n "${AWS_PROFILE:-}" ]]; then echo -e "  AWS profile:   $AWS_PROFILE"; fi
}

resolve_mode_label() {
    if [[ "$DEPLOY_DESTROY" == "true" ]]; then
        echo "deploy-destroy"
    elif [[ "$DEPLOY" == "true" ]]; then
        echo "deploy"
    elif [[ "$NO_PLAN" == "true" ]]; then
        echo "validate-only"
    else
        echo "validate + plan"
    fi
}

# ---- OS detection -----------------------------------------------------------

detect_os() {
    case "$(uname -s)" in
        Darwin) DETECTED_OS="macos" ;;
        Linux)
            if [[ -f /etc/debian_version ]]; then
                DETECTED_OS="debian"
            elif [[ -f /etc/redhat-release ]]; then
                DETECTED_OS="rhel"
            else
                DETECTED_OS="linux-unknown"
            fi
            ;;
        *) DETECTED_OS="unknown" ;;
    esac
}

# ---- Tool detection and auto-install ----------------------------------------

DETECTED_OS=""
HAS_TERRAFORM=false
HAS_GIT_SECRETS=false
HAS_TFLINT=false
HAS_CHECKOV=false
HAS_TRIVY=false

tool_available() {
    command -v "$1" >/dev/null 2>&1
}

attempt_install() {
    local tool="$1"
    local rc=0

    print_info "Attempting to install $tool..."

    case "$tool" in
        terraform)
            case "$DETECTED_OS" in
                macos)
                    if tool_available brew; then
                        brew install terraform >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                debian)
                    if tool_available apt-get; then
                        (   sudo apt-get update -qq \
                         && sudo apt-get install -y -qq gnupg software-properties-common \
                         && wget -qO- https://apt.releases.hashicorp.com/gpg \
                              | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
                         && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
                              | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null \
                         && sudo apt-get update -qq \
                         && sudo apt-get install -y -qq terraform
                        ) >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                rhel)
                    if tool_available yum; then
                        (   sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo \
                         && sudo yum install -y terraform
                        ) >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                *) rc=1 ;;
            esac
            ;;
        git-secrets)
            case "$DETECTED_OS" in
                macos)
                    if tool_available brew; then
                        brew install git-secrets >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                debian)
                    if tool_available apt-get; then
                        sudo apt-get install -y -qq git-secrets >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                rhel)
                    if tool_available dnf; then
                        sudo dnf install -y git-secrets >/dev/null 2>&1 || rc=$?
                    elif tool_available yum; then
                        sudo yum install -y git-secrets >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                *) rc=1 ;;
            esac
            ;;
        tflint)
            case "$DETECTED_OS" in
                macos)
                    if tool_available brew; then
                        brew install tflint >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                debian|rhel)
                    if tool_available curl; then
                        (curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash) \
                            >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                *) rc=1 ;;
            esac
            ;;
        checkov)
            if tool_available pip3; then
                pip3 install checkov >/dev/null 2>&1 || rc=$?
            elif tool_available pip; then
                pip install checkov >/dev/null 2>&1 || rc=$?
            else
                rc=1
            fi
            ;;
        trivy)
            case "$DETECTED_OS" in
                macos)
                    if tool_available brew; then
                        brew install trivy >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                debian)
                    if tool_available apt-get; then
                        (   sudo apt-get install -y -qq wget apt-transport-https gnupg \
                         && wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
                              | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/trivy.gpg \
                         && echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
                              | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null \
                         && sudo apt-get update -qq \
                         && sudo apt-get install -y -qq trivy
                        ) >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                rhel)
                    if tool_available yum; then
                        (   printf '%s\n' \
                                '[trivy]' \
                                'name=Trivy repository' \
                                'baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/' \
                                'gpgcheck=0' \
                                'enabled=1' \
                              | sudo tee /etc/yum.repos.d/trivy.repo >/dev/null \
                         && sudo yum install -y trivy
                        ) >/dev/null 2>&1 || rc=$?
                    else
                        rc=1
                    fi
                    ;;
                *) rc=1 ;;
            esac
            ;;
        *)
            rc=1
            ;;
    esac

    return "$rc"
}

detect_tools() {
    print_step 0 "Tool detection and auto-install"

    detect_os
    print_info "Detected OS: $DETECTED_OS"

    # Required: terraform — fatal if unavailable
    if tool_available terraform; then
        print_success "terraform detected"
        HAS_TERRAFORM=true
    elif attempt_install terraform && tool_available terraform; then
        print_success "terraform installed"
        HAS_TERRAFORM=true
    else
        print_error "terraform is required but not available and could not be installed"
        exit 1
    fi

    # Optional: git-secrets
    if tool_available git-secrets; then
        print_success "git-secrets detected"
        HAS_GIT_SECRETS=true
    elif attempt_install git-secrets && tool_available git-secrets; then
        print_success "git-secrets installed"
        HAS_GIT_SECRETS=true
    else
        print_warning "git-secrets not available — skipping"
    fi

    # Optional: tflint
    if tool_available tflint; then
        print_success "tflint detected"
        HAS_TFLINT=true
    elif attempt_install tflint && tool_available tflint; then
        print_success "tflint installed"
        HAS_TFLINT=true
    else
        print_warning "tflint not available — skipping"
    fi

    # Only check the selected scanner
    if [[ "$TF_SCANNER" == "checkov" ]]; then
        if tool_available checkov; then
            print_success "checkov detected"
            HAS_CHECKOV=true
        elif attempt_install checkov && tool_available checkov; then
            print_success "checkov installed"
            HAS_CHECKOV=true
        else
            print_warning "checkov not available — skipping"
        fi
    else
        if tool_available trivy; then
            print_success "trivy detected"
            HAS_TRIVY=true
        elif attempt_install trivy && tool_available trivy; then
            print_success "trivy installed"
            HAS_TRIVY=true
        else
            print_warning "trivy not available — skipping"
        fi
    fi
}

# ---- AWS credential detection -----------------------------------------------

detect_aws_credentials() {
    print_step "—" "AWS credential detection"

    # --profile flag already applied via apply_cli_overrides (exports AWS_PROFILE)
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        print_success "Using AWS profile: $AWS_PROFILE"
        return 0
    fi

    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
        print_success "Using AWS access key credentials"
        return 0
    fi

    if [[ -n "${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI:-}" ]]; then
        print_success "Using ECS task role credentials"
        return 0
    fi

    if [[ -n "${AWS_WEB_IDENTITY_TOKEN_FILE:-}" ]]; then
        print_success "Using OIDC credentials"
        return 0
    fi

    # Check EC2 instance metadata (IMDSv1 fallback, 1s timeout)
    if curl -s --max-time 1 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        print_success "Using EC2 instance role credentials"
        return 0
    fi

    print_error "No AWS credentials detected"
    echo ""
    echo "Deploy steps require AWS credentials. Options:"
    echo "  --profile <name>    Use a named AWS CLI profile"
    echo "  AWS_PROFILE         Set via env var or .test-terraform.conf"
    echo "  AWS_ACCESS_KEY_ID   Set access key via env vars"
    echo "  IAM role            Run on EC2/ECS/Lambda with an attached role"
    return 1
}

# =============================================================================
# Main
# =============================================================================

main() {
    # 1. Parse CLI flags (saved to _CLI_* variables, not yet applied)
    parse_args "$@"

    # 2. Load config file and apply env var precedence
    load_config

    # 3. Apply CLI flag overrides (highest precedence)
    apply_cli_overrides

    # 4. Resolve directory lists
    resolve_directories

    # 5. Print resolved configuration
    print_config

    # 6. Pre-validate directories
    validate_directories

    # 7. Create output directory
    mkdir -p "$TF_OUTPUT_DIR"

    # 8. Detect and auto-install tools
    detect_tools

    # ---- Pipeline steps (Features 4-11) -------------------------------------

    # Step 1: git-secrets (Feature 4)
    print_step 1 "git-secrets — scanning for hardcoded secrets"
    if [[ "$HAS_GIT_SECRETS" == "true" ]]; then
        if git secrets --scan -r "$PROJECT_ROOT" 2>&1; then
            print_success "No secrets detected"
        else
            print_error "git-secrets found potential secrets"
            exit 1
        fi
    else
        print_warning "git-secrets not available — skipping"
    fi

    # Step 2: terraform fmt (Feature 5)
    print_step 2 "terraform fmt — checking HCL formatting"
    if terraform fmt -check -recursive "$PROJECT_ROOT" >/dev/null 2>&1; then
        print_success "All files formatted correctly"
    else
        print_error "Formatting issues detected"
        echo ""
        echo "Run the following to fix:"
        echo "  terraform fmt -recursive"
        exit 2
    fi

    # Step 3: terraform init + validate (Feature 6)
    print_step 3 "terraform init + validate — all target directories"
    for dir in "${VALIDATE_DIRS[@]}"; do
        local abs_dir="$PROJECT_ROOT/$dir"
        [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"
        local dir_label
        dir_label="$(label "$dir")"

        print_info "init: $dir_label"
        if ! terraform -chdir="$abs_dir" init -backend=false -input=false 2>&1; then
            print_error "terraform init failed: $dir_label"
            exit 3
        fi

        print_info "validate: $dir_label"
        if ! terraform -chdir="$abs_dir" validate 2>&1; then
            print_error "terraform validate failed: $dir_label"
            exit 3
        fi

        print_success "init + validate: $dir_label"
    done

    # Step 4: tflint (Feature 7)
    print_step 4 "tflint — provider-aware linting"
    if [[ "$HAS_TFLINT" == "true" ]]; then
        # Resolve tflint config: explicit config > auto-detect in project root > none
        local tflint_config_flag=""
        if [[ -n "$TFLINT_CONFIG" ]]; then
            tflint_config_flag="--config=$TFLINT_CONFIG"
        elif [[ -f "$PROJECT_ROOT/.tflint.hcl" ]]; then
            tflint_config_flag="--config=$PROJECT_ROOT/.tflint.hcl"
        fi

        # Initialize tflint (downloads plugins)
        print_info "tflint --init"
        if ! tflint --init ${tflint_config_flag:+"$tflint_config_flag"} 2>&1; then
            print_warning "tflint --init failed — skipping linting"
        else
            for dir in "${VALIDATE_DIRS[@]}"; do
                local abs_dir="$PROJECT_ROOT/$dir"
                [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"
                local dir_label
                dir_label="$(label "$dir")"

                if tflint --chdir="$abs_dir" ${tflint_config_flag:+"$tflint_config_flag"} 2>&1; then
                    print_success "tflint clean: $dir_label"
                else
                    print_warning "tflint findings: $dir_label"
                fi
            done
        fi
    else
        print_warning "tflint not available — skipping"
    fi

    # Step 5: security scan (Feature 8)
    print_step 5 "$TF_SCANNER — security scanning"
    local scanner_available=false
    if [[ "$TF_SCANNER" == "checkov" && "$HAS_CHECKOV" == "true" ]]; then
        scanner_available=true
    elif [[ "$TF_SCANNER" == "trivy" && "$HAS_TRIVY" == "true" ]]; then
        scanner_available=true
    fi

    if [[ "$scanner_available" == "true" ]]; then
        local scan_failed=false
        for dir in "${VALIDATE_DIRS[@]}"; do
            local abs_dir="$PROJECT_ROOT/$dir"
            [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"
            local dir_label
            dir_label="$(label "$dir")"
            local dirname
            dirname="$(basename "$abs_dir")"
            # Use dir path with slashes replaced for unique filenames
            [[ "$dir" == "." ]] && dirname="root" || dirname="${dir//\//-}"

            local scan_rc=0
            if [[ "$TF_SCANNER" == "checkov" ]]; then
                # JUnit XML
                checkov -d "$abs_dir" --framework terraform --output junitxml \
                    > "$TF_OUTPUT_DIR/${dirname}-security.xml" 2>&1 || scan_rc=$?
                # SARIF
                checkov -d "$abs_dir" --framework terraform --output sarif \
                    > "$TF_OUTPUT_DIR/${dirname}-security.sarif" 2>&1 || scan_rc=$?
            else
                # trivy — JUnit XML
                trivy fs "$abs_dir" --scanners misconfig --severity HIGH,CRITICAL --format template \
                    --template "@contrib/junit.tpl" -o "$TF_OUTPUT_DIR/${dirname}-security.xml" 2>&1 || scan_rc=$?
                # trivy — SARIF
                trivy fs "$abs_dir" --scanners misconfig --severity HIGH,CRITICAL --format sarif \
                    -o "$TF_OUTPUT_DIR/${dirname}-security.sarif" 2>&1 || scan_rc=$?
            fi

            if [[ $scan_rc -ne 0 ]]; then
                if [[ "$SOFT_FAIL" == "true" ]]; then
                    print_warning "Security findings: $dir_label (soft-fail)"
                else
                    print_error "Security findings: $dir_label"
                    scan_failed=true
                fi
            else
                print_success "Security scan clean: $dir_label"
            fi
        done

        if [[ "$scan_failed" == "true" ]]; then
            echo ""
            echo "Security reports saved to $TF_OUTPUT_DIR/"
            echo "Use --soft-fail to treat findings as warnings."
            exit 5
        fi
    else
        print_warning "$TF_SCANNER not available — skipping security scan"
    fi

    # AWS credential check — required before plan/deploy, not for validation-only
    if [[ "$NO_PLAN" == "false" && ${#PLAN_DIRS[@]} -gt 0 ]]; then
        if ! detect_aws_credentials; then
            exit 4
        fi
    fi

    # Step 6: terraform plan (Feature 9)
    if [[ "$NO_PLAN" == "true" ]]; then
        print_step 6 "terraform plan — skipped (--no-plan)"
    elif [[ ${#PLAN_DIRS[@]} -eq 0 ]]; then
        print_step 6 "terraform plan — no deploy-eligible directories configured"
    else
        print_step 6 "terraform plan — deploy-eligible directories"
        for dir in "${PLAN_DIRS[@]}"; do
            local abs_dir="$PROJECT_ROOT/$dir"
            [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"
            local dir_label
            dir_label="$(label "$dir")"
            local dirname
            [[ "$dir" == "." ]] && dirname="root" || dirname="${dir//\//-}"
            local abs_output_dir
            abs_output_dir="$(cd "$TF_OUTPUT_DIR" && pwd)"
            local plan_file="$abs_output_dir/${dirname}.tfplan"

            # Init with local backend (no -backend=false) for plan
            print_info "init (local state): $dir_label"
            if ! terraform -chdir="$abs_dir" init -input=false 2>&1; then
                print_error "terraform init failed: $dir_label"
                exit 6
            fi

            print_info "plan: $dir_label"
            if ! terraform -chdir="$abs_dir" plan -out="$plan_file" -input=false 2>&1; then
                print_error "terraform plan failed: $dir_label"
                exit 6
            fi

            print_success "plan saved: $plan_file"
        done
    fi

    # Step 7-8: deploy / destroy (Feature 10)
    if [[ "$DEPLOY" == "true" || "$DEPLOY_DESTROY" == "true" ]]; then
        print_step 7 "terraform apply"
        for dir in "${PLAN_DIRS[@]}"; do
            local abs_dir="$PROJECT_ROOT/$dir"
            [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"
            local dir_label
            dir_label="$(label "$dir")"
            local dirname
            [[ "$dir" == "." ]] && dirname="root" || dirname="${dir//\//-}"
            local abs_output_dir
            abs_output_dir="$(cd "$TF_OUTPUT_DIR" && pwd)"
            local plan_file="$abs_output_dir/${dirname}.tfplan"

            print_info "apply: $dir_label"
            if ! terraform -chdir="$abs_dir" apply "$plan_file" 2>&1; then
                print_error "terraform apply failed: $dir_label"
                exit 7
            fi
            print_success "apply complete: $dir_label"

            # Clean up plan file after successful apply
            rm -f "$plan_file"
        done

        if [[ "$DEPLOY_DESTROY" == "true" ]]; then
            print_step 8 "terraform destroy"

            # Pause before destroy — TTY gets interactive prompt, non-TTY gets timed wait
            if [[ -t 0 ]]; then
                echo ""
                echo "Resources deployed. Press Enter to destroy..."
                read -r
            else
                echo ""
                echo "Resources deployed. Auto-destroying in ${TF_DESTROY_TIMEOUT}s (no TTY detected)..."
                sleep "$TF_DESTROY_TIMEOUT"
            fi

            for dir in "${PLAN_DIRS[@]}"; do
                local abs_dir="$PROJECT_ROOT/$dir"
                [[ "$dir" == "." ]] && abs_dir="$PROJECT_ROOT"
                local dir_label
                dir_label="$(label "$dir")"

                print_info "destroy: $dir_label"
                if ! terraform -chdir="$abs_dir" destroy -auto-approve 2>&1; then
                    print_error "terraform destroy failed: $dir_label"
                    exit 7
                fi
                print_success "destroy complete: $dir_label"
            done
        fi
    else
        print_step 7 "terraform apply — skipped (use --deploy or --deploy-destroy)"
    fi

    # ---- Summary (Feature 11) -----------------------------------------------
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Results: ${PASS_COUNT} passed, ${WARN_COUNT} warnings, ${FAIL_COUNT} failed${NC}"
    echo -e "${GREEN}========================================${NC}"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
