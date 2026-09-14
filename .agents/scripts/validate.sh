#!/usr/bin/env bash
# .agents/scripts/validate.sh — Agent Workspace Structural & Secret Validation
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> [validate] Checking agent workspace structure..."

# 1. Root AGENTS.md existence
if [ ! -f "${REPO_ROOT}/AGENTS.md" ]; then
  echo "ERROR: Root AGENTS.md does not exist." >&2
  exit 1
fi

# 2. Required directories
REQUIRED_DIRS=(
  ".agents/maintainability"
  ".agents/plans"
  ".agents/memory"
  ".agents/knowledge"
  ".agents/skills"
  ".agents/templates"
  ".agents/scripts/lib"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "${REPO_ROOT}/${dir}" ]; then
    echo "ERROR: Required directory '${dir}' missing." >&2
    exit 1
  fi
done

# 3. Required templates
REQUIRED_TEMPLATES=(
  "plan.md"
  "worklog.md"
  "knowledge.md"
  "skill.md"
)

for tmpl in "${REQUIRED_TEMPLATES[@]}"; do
  if [ ! -f "${REPO_ROOT}/.agents/templates/${tmpl}" ]; then
    echo "ERROR: Required template '.agents/templates/${tmpl}' missing." >&2
    exit 1
  fi
done

# 4. Codebase registry existence
if [ ! -f "${REPO_ROOT}/.agents/codebases.conf" ]; then
  echo "ERROR: Codebase registry '.agents/codebases.conf' missing." >&2
  exit 1
fi

# 5. Check durable markdown files for obvious secret leaks
SECRET_PATTERNS=(
  "BEGIN RSA PRIVATE KEY"
  "BEGIN PRIVATE KEY"
  "BEGIN OPENSSH PRIVATE KEY"
  "ghp_[A-Za-z0-9]{36}"
  "eyJhbGciOi"
)

for pat in "${SECRET_PATTERNS[@]}"; do
  if grep -rEn "$pat" "${REPO_ROOT}/.agents/plans" "${REPO_ROOT}/.agents/memory" "${REPO_ROOT}/.agents/knowledge" "${REPO_ROOT}/.agents/skills" 2>/dev/null; then
    echo "ERROR: Secret pattern '$pat' found in durable agent files!" >&2
    exit 1
  fi
done

echo "==> [validate] Agent workspace structure and secret checks PASSED."
