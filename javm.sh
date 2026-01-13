#!/usr/bin/env bash
# shellcheck shell=bash

# JAVM: Lightweight Java version manager for Bash/MSYS/Cygwin
#
# Manages multiple Java installations and allows switching between them.
# Stores registered Java versions in versions.map and tracks the current version.
# Supports cross-platform path conversion (Windows/Unix) for MSYS/Cygwin environments.
#
# Features:
#   - Register multiple Java installations with aliases
#   - Switch between versions with environment variable updates
#   - Auto-load default version on shell startup
#   - Optional automatic version switching based on .java-version files
#   - Path conversion for Windows/Unix compatibility
#
# Commands:
#   javm list              - List all registered Java versions
#   javm add <alias> <dir> - Register a new Java installation
#   javm use <alias>       - Switch to a registered Java version
#   javm default [alias]   - View or set the default Java version
#   javm rm <alias>        - Unregister a Java version
#   javm clear             - Restore PATH and unset JAVA_HOME
#   javm current           - Display the currently active Java version
#
# Environment variables:
#   JAVM_HOME              - Base directory for javm (defaults to script location)
#   JAVM_PATH_BASE         - Original PATH before javm modifications
#   JAVM_CURRENT           - Currently active Java version alias
#   JAVM_AUTO              - Set to 1 to enable automatic .java-version support
#   JAVA_HOME              - Set to the active Java installation path
#   JAVA_HOME_UNIX         - Unix-style path for the active Java installation

if [ -z "${JAVM_HOME+x}" ] || [ ! -d "$JAVM_HOME" ]; then
  JAVM_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

JAVM_REGISTRY="$JAVM_HOME/versions.map"
JAVM_DEFAULT_FILE="$JAVM_HOME/default"

mkdir -p "$JAVM_HOME"
touch "$JAVM_REGISTRY"
[ -f "$JAVM_DEFAULT_FILE" ] || : >"$JAVM_DEFAULT_FILE"

if [ -z "${JAVM_PATH_BASE+x}" ]; then
  JAVM_PATH_BASE="$PATH"
fi

# Removes leading/trailing whitespace from a string
__javm_trim() { printf '%s' "$1" | tr -d '\r\n \t'; }

# Converts Unix paths to Windows format (uses cygpath if available)
__javm_to_windows() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

# Converts Windows paths to Unix format (uses cygpath if available)
__javm_to_unix() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s\n' "$1"
  fi
}

# Looks up a registered Java installation by alias
# Returns the path if found, exits with code 1 if not found
__javm_lookup() {
  local name="$1"
  while IFS='|' read -r alias path; do
    alias=$(__javm_trim "$alias")
    path=$(__javm_trim "$path")
    [ -z "$alias" ] && continue
    if [ "$alias" = "$name" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done <"$JAVM_REGISTRY"
  return 1
}

# Main javm command dispatcher
javm() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    list|ls)
      # Display all registered Java versions with a marker for the current one
      while IFS='|' read -r alias path; do
        alias=$(__javm_trim "$alias")
        [ -z "$alias" ] && continue
        path=$(__javm_trim "$path")
        local mark=" "
        [ "$alias" = "${JAVM_CURRENT:-}" ] && mark="*"
        printf "%s %-15s %s\n" "$mark" "$alias" "$path"
      done <"$JAVM_REGISTRY"
      ;;
    add)
      # Register a new Java installation
      # Validates that bin/java or bin/java.exe exists in the specified directory
      local alias="$1" raw="${2:-$PWD}"
      if [ -z "$alias" ]; then
        echo "Usage: javm add <alias> <JDK directory>" >&2
        return 1
      fi
      raw=$(cd "$raw" 2>/dev/null && pwd) || {
        echo "Error: Directory not accessible: $raw" >&2
        return 1
      }
      if [ ! -f "$raw/bin/java" ] && [ ! -f "$raw/bin/java.exe" ]; then
        echo "Error: Directory does not contain bin/java(.exe): $raw" >&2
        return 1
      }
      local win_path unix_path tmp
      unix_path="$raw"
      win_path=$(__javm_to_windows "$unix_path")
      tmp="$(mktemp "${TMPDIR:-/tmp}/javm.XXXXXX")"
      awk -F'|' -v n="$alias" 'NF && $1!=n' "$JAVM_REGISTRY" >"$tmp"
      printf "%s|%s\n" "$alias" "$win_path" >>"$tmp"
      mv "$tmp" "$JAVM_REGISTRY"
      echo "Registered: $alias -> $win_path"
      ;;
    use)
      # Switch to a registered Java installation
      # Updates JAVA_HOME, PATH, and JAVM_CURRENT
      local alias="$1"
      if [ -z "$alias" ]; then
        echo "Usage: javm use <alias>" >&2
        return 1
      fi
      local win_path unix_path
      win_path=$(__javm_lookup "$alias") || {
        echo "Error: Unknown alias: $alias" >&2
        return 1
      }
      unix_path=$(__javm_to_unix "$win_path")
      if [ ! -d "$unix_path/bin" ]; then
        echo "Error: Directory not accessible: $unix_path/bin" >&2
        return 1
      fi
      export JAVA_HOME="$win_path"
      export JAVA_HOME_UNIX="$unix_path"
      export PATH="$unix_path/bin:$JAVM_PATH_BASE"
      export JAVM_CURRENT="$alias"
      hash -r 2>/dev/null
      echo "Now using $alias ($win_path)"
      ;;
    default)
      # View or set the default Java version
      # The default version is automatically loaded on shell startup
      if [ $# -eq 0 ]; then
        if [ -s "$JAVM_DEFAULT_FILE" ]; then
          cat "$JAVM_DEFAULT_FILE"
        else
          echo "(not set)"
        fi
      else
        local alias="$1"
        __javm_lookup "$alias" >/dev/null || {
          echo "Error: Unknown alias: $alias" >&2
          return 1
        }
        printf '%s\n' "$alias" >"$JAVM_DEFAULT_FILE"
        javm use "$alias"
      fi
      ;;
    remove|rm)
      # Unregister a Java installation
      local alias="$1"
      if [ -z "$alias" ]; then
        echo "Usage: javm rm <alias>" >&2
        return 1
      fi
      local tmp
      tmp="$(mktemp "${TMPDIR:-/tmp}/javm.XXXXXX")"
      awk -F'|' -v n="$alias" 'NF && $1!=n' "$JAVM_REGISTRY" >"$tmp"
      mv "$tmp" "$JAVM_REGISTRY"
      if [ "${JAVM_CURRENT:-}" = "$alias" ]; then
        javm clear >/dev/null
      fi
      echo "Removed: $alias"
      ;;
    current)
      # Display the currently active Java version
      if [ -n "${JAVM_CURRENT:-}" ]; then
        echo "$JAVM_CURRENT -> $JAVA_HOME"
      elif [ -n "${JAVA_HOME:-}" ]; then
        echo "(external) -> $JAVA_HOME"
      else
        echo "(not selected)"
      fi
      ;;
    clear)
      # Restore original PATH and unset Java-related environment variables
      export PATH="$JAVM_PATH_BASE"
      unset JAVA_HOME JAVA_HOME_UNIX JAVM_CURRENT
      ;;
    help|-h|--help|"")
      # Display help information and available commands
      cat <<'EOF'
JAVM: Java Version Manager

Commands:
  javm list              - List all registered Java versions
  javm add <alias> <dir> - Register a new Java installation
  javm use <alias>       - Switch to a registered Java version
  javm default [alias]   - View or set the default Java version
  javm rm <alias>        - Unregister a Java version
  javm current           - Display the currently active Java version
  javm clear             - Restore original PATH and JAVA_HOME

Examples:
  javm add jdk11 /usr/lib/jvm/java-11
  javm use jdk11
  javm default jdk11
EOF
      ;;
    *)
      echo "Error: Unknown subcommand: $cmd" >&2
      return 1
      ;;
  esac
}

# Auto-load the default Java version on shell startup
if [ -z "${JAVM_CURRENT+x}" ] && [ -s "$JAVM_DEFAULT_FILE" ]; then
  def="$(__javm_trim "$(cat "$JAVM_DEFAULT_FILE")")"
  if [ -n "$def" ]; then
    javm use "$def" >/dev/null 2>&1 || true
  fi
fi

# Automatically switch Java versions based on .java-version files
# Enable with: export JAVM_AUTO=1
if [ "${JAVM_AUTO:-0}" = "1" ]; then
  __javm_auto_prev=""

  # Hook function that runs before each command
  # Looks for .java-version file in current directory tree
  __javm_auto_hook() {
    local dir="$PWD" file=""
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
      if [ -f "$dir/.java-version" ]; then
        file="$dir/.java-version"
        break
      fi
      dir=$(dirname "$dir")
    done
    local candidate=""
    if [ -n "$file" ]; then
      candidate="$(__javm_trim "$(cat "$file")")"
    elif [ -s "$JAVM_DEFAULT_FILE" ]; then
      candidate="$(__javm_trim "$(cat "$JAVM_DEFAULT_FILE")")"
    fi
    if [ "$candidate" != "$__javm_auto_prev" ]; then
      if [ -n "$candidate" ]; then
        javm use "$candidate" >/dev/null 2>&1 || true
      else
        javm clear >/dev/null 2>&1
      fi
      __javm_auto_prev="$candidate"
    fi
  }
  case ";$PROMPT_COMMAND;" in
    *";__javm_auto_hook;"*) ;;
    *) PROMPT_COMMAND="__javm_auto_hook${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
  esac
fi
