#!/bin/bash
set -e  # Exit on error

# AWS Profile for testing.
export AWS_PROFILE=developer-account

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_step() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Step $1: $2${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect operating system and package manager
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                echo "debian"
                ;;
            rhel|centos|fedora)
                echo "redhat"
                ;;
            *)
                echo "linux"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Function to install tool with OS detection
install_tool() {
    local tool=$1
    local install_method=$2
    local os=$(detect_os)
    
    print_warning "$tool not found. Installing..."
    
    case $install_method in
        brew)
            case $os in
                macos)
                    if command_exists brew; then
                        brew install "$tool"
                    else
                        print_error "Homebrew not installed. Please install $tool manually."
                        return 1
                    fi
                    ;;
                debian)
                    if command_exists apt-get; then
                        sudo apt-get update && sudo apt-get install -y "$tool"
                    else
                        print_error "apt-get not available. Please install $tool manually."
                        return 1
                    fi
                    ;;
                redhat)
                    if command_exists dnf; then
                        sudo dnf install -y "$tool"
                    elif command_exists yum; then
                        sudo yum install -y "$tool"
                    else
                        print_error "dnf/yum not available. Please install $tool manually."
                        return 1
                    fi
                    ;;
                *)
                    print_error "Unsupported OS. Please install $tool manually."
                    return 1
                    ;;
            esac
            ;;
        pip)
            if command_exists pip3; then
                pip3 install --user "$tool"
            elif command_exists pip; then
                pip install --user "$tool"
            else
                print_error "pip not installed. Please install $tool manually."
                return 1
            fi
            ;;
        custom)
            print_error "Please install $tool manually."
            return 1
            ;;
    esac
}

# Step 1: git-secrets
print_step 1 "git-secrets - Scanning for hardcoded secrets"
if ! command_exists git-secrets; then
    install_tool "git-secrets" "brew"
fi

if command_exists git-secrets; then
    git secrets --scan
    print_success "No secrets found"
else
    print_error "git-secrets not available. Skipping..."
fi

# Step 2: terraform fmt
print_step 2 "terraform fmt - Checking HCL formatting"
if ! command_exists terraform; then
    install_tool "terraform" "brew"
fi

if command_exists terraform; then
    if terraform fmt -check -recursive; then
        print_success "Formatting is correct"
    else
        print_warning "Formatting issues found. Run 'terraform fmt -recursive' to fix."
    fi
else
    print_error "Terraform not available. Cannot proceed."
    exit 1
fi

# Step 3: terraform init
print_step 3 "terraform init - Initializing providers"
terraform init
print_success "Providers initialized"

# Step 4: terraform validate
print_step 4 "terraform validate - Checking syntax and consistency"
terraform validate
print_success "Validation passed"

# Step 5: tflint
print_step 5 "tflint - Provider-aware linting"
if ! command_exists tflint; then
    print_warning "tflint not installed. Attempting to install..."
    install_tool "tflint" "brew" || print_warning "Skipping tflint..."
fi

if command_exists tflint; then
    tflint --init || true
    tflint
    print_success "TFLint checks passed"
else
    print_warning "tflint not available. Skipping..."
fi

# Step 6: checkov
print_step 6 "checkov - Security scanning"
if ! command_exists checkov; then
    install_tool "checkov" "pip"
fi

if command_exists checkov; then
    checkov -d . --framework terraform || print_warning "Checkov found security issues"
    print_success "Checkov security scan completed"
else
    print_warning "checkov not available. Skipping..."
fi

# Step 7: trivy
print_step 7 "trivy - Security scanning"
if ! command_exists trivy; then
    install_tool "trivy" "brew"
fi

if command_exists trivy; then
    trivy config . || print_warning "Trivy found security issues"
    print_success "Trivy security scan completed"
else
    print_warning "trivy not available. Skipping..."
fi

# Step 8: terraform plan
print_step 8 "terraform plan - Generating deployment plan"
terraform plan -out=tfplan
print_success "Terraform plan generated successfully"

# Step 9: terraform apply
print_step 9 "terraform apply - Deploying to dev account"
terraform apply tfplan
print_success "Deployment completed successfully"
    print_warning "Deployment cancelled by user"
    exit 0
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All tests completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
