#!/usr/bin/env bash
# .agents/scripts/codebase-policy.sh — Structural Policy Guard
# Usage: ./codebase-policy.sh <codebase> [diff_range]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/.agents/scripts/lib/codebases.sh"

CODEBASE="${1:-}"
DIFF_RANGE="${2:-}"

if [ -z "$CODEBASE" ]; then
  echo "Usage: $0 <codebase> [diff_range]" >&2
  exit 1
fi

if ! codebase_exists "$CODEBASE"; then
  echo "Error: Codebase '$CODEBASE' not found in registry" >&2
  exit 1
fi

CB_ROOT="$(get_codebase_root "$CODEBASE")"
CB_DIR="${REPO_ROOT}/${CB_ROOT}"

echo "==> [policy] Checking structural rules for '$CODEBASE' (${CB_ROOT})..."

# 1. Check for forbidden local standalone scripts or nested scripts directories
# By Sensio convention, component operational scripts belong in root scripts/<codebase>/, not inside product folders.
# We check if new .sh or .py scripts are placed directly in product codebase roots (excluding grandfathered ones).
LEGACY_SCRIPTS_ALLOWLIST=(
  "backend/run_stress_test.sh"
  "mobile/run_android.sh"
  "mobile/run_ios.sh"
)

is_legacy_script() {
  local path="$1"
  for allowed in "${LEGACY_SCRIPTS_ALLOWLIST[@]}"; do
    if [ "$path" = "$allowed" ]; then
      return 0
    fi
  done
  return 1
}

# Scan for un-grandfathered standalone scripts in codebase root
while IFS= read -r script_file; do
  [ -z "$script_file" ] && continue
  rel_script="${script_file#${REPO_ROOT}/}"
  if ! is_legacy_script "$rel_script"; then
    echo "ERROR: [policy] Standalone script found at '$rel_script'." >&2
    echo "       Component operational helpers must reside in 'scripts/${CODEBASE}/'." >&2
    exit 1
  fi
done < <(find "${CB_DIR}" -maxdepth 2 \( -name "*.sh" -o -name "*.py" \) -not -path "*/node_modules/*" -not -path "*/.dart_tool/*" 2>/dev/null || true)

# 2. Check for temporary unit-test artifacts left behind
TEMP_TEST_PATTERNS=(
  "*temp_test*"
  "*tmp_test*"
  "*.test.tmp"
)

for pat in "${TEMP_TEST_PATTERNS[@]}"; do
  matches=$(find "${CB_DIR}" -name "$pat" -not -path "*/node_modules/*" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "ERROR: [policy] Temporary test artifacts must be deleted before closure:" >&2
    echo "$matches" >&2
    exit 1
  fi
done

# 3. Check for component operational scripts reaching into sibling codebases
if [ -d "${REPO_ROOT}/scripts/${CODEBASE}" ]; then
  for sibling in $(get_codebases); do
    if [ "$sibling" != "$CODEBASE" ]; then
      sib_root="$(get_codebase_root "$sibling")"
      if grep -rq "${sib_root}/" "${REPO_ROOT}/scripts/${CODEBASE}/" 2>/dev/null; then
        echo "ERROR: [policy] Component helper in 'scripts/${CODEBASE}' references sibling '${sib_root}'." >&2
        echo "       Sibling isolation invariant violated." >&2
        exit 1
      fi
    fi
  done
fi

echo "==> [policy] Passed structural checks for '$CODEBASE'."
