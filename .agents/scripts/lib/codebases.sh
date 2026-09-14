#!/usr/bin/env bash
# .agents/scripts/lib/codebases.sh — Codebase Registry Accessor Library
# Consumes .agents/codebases.conf as the single source of truth.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
REGISTRY_FILE="${REPO_ROOT}/.agents/codebases.conf"

get_codebases() {
  if [ ! -f "$REGISTRY_FILE" ]; then
    echo "Error: Registry file not found at $REGISTRY_FILE" >&2
    return 1
  fi
  grep -v '^[[:space:]]*#' "$REGISTRY_FILE" | grep -v '^[[:space:]]*$' | cut -d'|' -f1
}

codebase_exists() {
  local target="$1"
  for cb in $(get_codebases); do
    if [ "$cb" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

get_codebase_entry() {
  local target="$1"
  grep -v '^[[:space:]]*#' "$REGISTRY_FILE" | grep -v '^[[:space:]]*$' | while IFS='|' read -r name root kind sources lint traits shared; do
    if [ "$name" = "$target" ]; then
      echo "$name|$root|$kind|$sources|$lint|$traits|$shared"
      return 0
    fi
  done
}

get_codebase_root() {
  local target="$1"
  local entry
  entry=$(get_codebase_entry "$target")
  [ -n "$entry" ] && echo "$entry" | cut -d'|' -f2
}

get_codebase_kind() {
  local target="$1"
  local entry
  entry=$(get_codebase_entry "$target")
  [ -n "$entry" ] && echo "$entry" | cut -d'|' -f3
}

get_codebase_sources() {
  local target="$1"
  local entry
  entry=$(get_codebase_entry "$target")
  [ -n "$entry" ] && echo "$entry" | cut -d'|' -f4
}

get_codebase_lint_config() {
  local target="$1"
  local entry
  entry=$(get_codebase_entry "$target")
  [ -n "$entry" ] && echo "$entry" | cut -d'|' -f5
}

get_codebase_traits() {
  local target="$1"
  local entry
  entry=$(get_codebase_entry "$target")
  [ -n "$entry" ] && echo "$entry" | cut -d'|' -f6
}

get_codebase_shared_libs() {
  local target="$1"
  local entry
  entry=$(get_codebase_entry "$target")
  [ -n "$entry" ] && echo "$entry" | cut -d'|' -f7
}

find_codebase_for_file() {
  local relpath="$1"
  # Clean leading ./
  relpath="${relpath#./}"

  # Check direct codebase matches first
  for cb in $(get_codebases); do
    local cb_root
    cb_root=$(get_codebase_root "$cb")
    if [ "$cb_root" = "." ]; then
      continue
    fi
    case "$relpath" in
      "$cb_root"/*|"$cb_root")
        echo "$cb"
        return 0
        ;;
      scripts/"$cb"/*)
        echo "$cb"
        return 0
        ;;
    esac
  done

  # Check root-level fallback
  for cb in $(get_codebases); do
    local cb_root
    cb_root=$(get_codebase_root "$cb")
    if [ "$cb_root" = "." ]; then
      echo "$cb"
      return 0
    fi
  done

  return 1
}
