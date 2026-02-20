#!/bin/bash

# CDK validation pipeline: secrets scanning, formatting, linting, build, test, audit
#
# Usage:
#   bash scripts/cdk-validation.sh                                # Default profile
#   AWS_PROFILE=dev-account bash scripts/cdk-validation.sh        # Specific profile
#   bash scripts/cdk-validation.sh --skip-audit                   # Skip npm audit
#
# Auto-detects OS and installs missing tools where possible.

set -e

# --- Argument parsing ---
SKIP_AUDIT=false
for arg in "$@"; do
    case $arg in
        --skip-audit) SKIP_AUDIT=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# --- OS detection ---
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif command -v apt-get &>/dev/null; then
        echo "debian"
    elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo ""
echo "========================================"
echo "  CDK Validation Pipeline"
echo "========================================"
echo "  OS: $OS"
[ -n "$AWS_PROFILE" ] && echo "  AWS Profile: $AWS_PROFILE"
echo ""

# --- Counters ---
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_SKIPPED=0

pass()  { echo "   PASS: $1"; ((CHECKS_PASSED++)) || true; }
fail()  { echo "   FAIL: $1"; echo "   $2"; ((CHECKS_FAILED++)) || true; exit 1; }
skip()  { echo "   SKIP: $1"; ((CHECKS_SKIPPED++)) || true; }
warn()  { echo "   WARN: $1"; ((CHECKS_SKIPPED++)) || true; }

# --- Ensure npm dependencies ---
if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm ci --silent
    echo ""
fi

# --- Step 1: Scan for secrets ---
echo "1. Scanning for secrets with git-secrets..."
if command -v git-secrets &>/dev/null; then
    if git secrets --scan 2>/dev/null; then
        pass "No secrets detected"
    else
        fail "Secrets detected" "Remove secrets and try again."
    fi
else
    skip "git-secrets not installed (brew install git-secrets)"
fi
echo ""

# --- Step 2: Prettier format check ---
echo "2. Checking code formatting with Prettier..."
if grep -q '"format:check"' package.json 2>/dev/null; then
    if npm run format:check --silent 2>/dev/null; then
        pass "Code formatting is consistent"
    else
        fail "Code formatting issues detected" "Run 'npm run format' to fix."
    fi
else
    skip "No format:check script in package.json"
fi
echo ""

# --- Step 3: ESLint ---
echo "3. Linting code with ESLint..."
if grep -q '"lint"' package.json 2>/dev/null; then
    if npm run lint --silent 2>/dev/null; then
        pass "No linting errors"
    else
        fail "ESLint errors detected" "Run 'npm run lint' to see details."
    fi
else
    skip "No lint script in package.json"
fi
echo ""

# --- Step 4: TypeScript build ---
echo "4. Building TypeScript code..."
if npm run build --silent 2>/dev/null; then
    pass "Build successful"
else
    fail "Build failed" "Run 'npm run build' to see the full error."
fi
echo ""

# --- Step 5: Jest tests ---
echo "5. Running Jest tests..."
if npm test 2>/dev/null; then
    pass "All tests passed"
else
    fail "Tests failed" "Run 'npm test' to see the full output."
fi
echo ""

# --- Step 6: npm audit ---
if [ "$SKIP_AUDIT" = true ]; then
    echo "6. npm audit..."
    skip "Skipped (--skip-audit)"
else
    echo "6. Running npm audit..."
    if npm audit --audit-level=moderate 2>/dev/null; then
        pass "No npm vulnerabilities detected"
    else
        warn "Vulnerabilities detected — review with 'npm audit'"
    fi
fi
echo ""

# --- Summary ---
echo "========================================"
echo "  Validation Complete"
echo "========================================"
echo ""
echo "  Passed:  $CHECKS_PASSED"
echo "  Skipped: $CHECKS_SKIPPED"
echo "  Failed:  $CHECKS_FAILED"
echo ""

if [ "$CHECKS_FAILED" -gt 0 ]; then
    echo "Validation FAILED"
    exit 1
fi

echo "All required checks passed"
exit 0
