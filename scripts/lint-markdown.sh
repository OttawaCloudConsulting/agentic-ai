set -euo pipefail

# Lint markdown files using markdownlint-cli2.
# Installs markdownlint-cli2 via npx if not available.
#
# Three-tier rule handling:
#   1. Ignored rules   — disabled in .markdownlint.jsonc (never checked)
#   2. Auto-fix rules  — enabled in .markdownlint-fix.markdownlint.jsonc (fixed silently)
#   3. Error rules     — everything else enforced in .markdownlint.jsonc (reported)
#
# Usage:
#   bash scripts/lint-markdown.sh                    # lint *.md in current directory
#   bash scripts/lint-markdown.sh -r                 # lint *.md recursively
#   bash scripts/lint-markdown.sh --recursive        # lint *.md recursively
#   bash scripts/lint-markdown.sh README.md          # lint a single file
#   bash scripts/lint-markdown.sh --no-fix           # skip auto-fix, report everything

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RECURSIVE=false
NO_FIX=false
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--recursive) RECURSIVE=true; shift ;;
    --no-fix)       NO_FIX=true; shift ;;
    *.md)           TARGET_FILE="$1"; shift ;;
    *)              echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if command -v markdownlint-cli2 &>/dev/null; then
  LINT_CMD="markdownlint-cli2"
else
  LINT_CMD="npx --yes markdownlint-cli2"
fi

if [[ -n "$TARGET_FILE" ]]; then
  PATTERN="$TARGET_FILE"
elif [[ "$RECURSIVE" == true ]]; then
  PATTERN="**/*.md"
else
  PATTERN="*.md"
fi

# Pass 1: auto-fix safe rules (unless --no-fix)
if [[ "$NO_FIX" == false ]]; then
  echo "==> Auto-fixing: ${PATTERN}"
  # shellcheck disable=SC2086
  $LINT_CMD --config "${REPO_ROOT}/.markdownlint-fix.markdownlint.jsonc" --fix "$PATTERN" || true
fi

# Pass 2: lint all enforced rules, report errors
echo "==> Linting: ${PATTERN}"
# shellcheck disable=SC2086
$LINT_CMD --config "${REPO_ROOT}/.markdownlint.jsonc" "$PATTERN"

echo "==> Markdown lint passed"
