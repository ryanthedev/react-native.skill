#!/usr/bin/env bash
# clean.sh — Clean specific React Native caches and build artifacts.
# Usage: bash clean.sh [flags] [project_root]
#
# Flags:
#   --metro          Remove Metro bundler cache (/tmp/metro-*, /tmp/haste-*)
#   --watchman       Reset watchman watches
#   --node-modules   Remove node_modules and reinstall
#   --pods           Remove ios/Pods and reinstall
#   --derived-data   Remove Xcode DerivedData
#   --gradle         Remove Android Gradle cache and build artifacts
#   --all            All of the above
#
# If project_root is not provided as the last argument, uses current directory.

set -euo pipefail

# --- Parse flags ---

CLEAN_METRO=false
CLEAN_WATCHMAN=false
CLEAN_NODE_MODULES=false
CLEAN_PODS=false
CLEAN_DERIVED_DATA=false
CLEAN_GRADLE=false
PROJECT_ROOT=""

for arg in "$@"; do
  case "$arg" in
    --metro)         CLEAN_METRO=true ;;
    --watchman)      CLEAN_WATCHMAN=true ;;
    --node-modules)  CLEAN_NODE_MODULES=true ;;
    --pods)          CLEAN_PODS=true ;;
    --derived-data)  CLEAN_DERIVED_DATA=true ;;
    --gradle)        CLEAN_GRADLE=true ;;
    --all)
      CLEAN_METRO=true
      CLEAN_WATCHMAN=true
      CLEAN_NODE_MODULES=true
      CLEAN_PODS=true
      CLEAN_DERIVED_DATA=true
      CLEAN_GRADLE=true
      ;;
    -*)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
    *)
      PROJECT_ROOT="$arg"
      ;;
  esac
done

PROJECT_ROOT="${PROJECT_ROOT:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# Check that at least one flag was given
if ! $CLEAN_METRO && ! $CLEAN_WATCHMAN && ! $CLEAN_NODE_MODULES && \
   ! $CLEAN_PODS && ! $CLEAN_DERIVED_DATA && ! $CLEAN_GRADLE; then
  echo "Error: No clean target specified. Use one or more of:"
  echo "  --metro --watchman --node-modules --pods --derived-data --gradle --all"
  exit 1
fi

echo "Project root: $PROJECT_ROOT"
echo ""

# --- Detect package manager ---

detect_pm() {
  if [ -f "$PROJECT_ROOT/yarn.lock" ]; then
    echo "yarn"
  elif [ -f "$PROJECT_ROOT/pnpm-lock.yaml" ]; then
    echo "pnpm"
  else
    echo "npm"
  fi
}

# --- Metro cache ---

if $CLEAN_METRO; then
  echo "==> Cleaning Metro cache..."
  rm -rf /tmp/metro-* /tmp/haste-* 2>/dev/null || true

  # Also clear caches in macOS temp dir ($TMPDIR is typically /private/var/folders/.../T/)
  _TMPDIR="${TMPDIR:-/tmp}"
  _TMPDIR="${_TMPDIR%/}"
  rm -rf "${_TMPDIR}"/metro-* "${_TMPDIR}"/haste-* "${_TMPDIR}"/react-* 2>/dev/null || true

  echo "    Metro cache cleared."
  echo ""
fi

# --- Watchman ---

if $CLEAN_WATCHMAN; then
  echo "==> Resetting Watchman..."
  if command -v watchman &>/dev/null; then
    watchman watch-del-all 2>/dev/null || true
    echo "    Watchman watches removed."
  else
    echo "    Watchman not installed, skipping."
  fi
  echo ""
fi

# --- node_modules ---

if $CLEAN_NODE_MODULES; then
  echo "==> Removing node_modules..."
  rm -rf "$PROJECT_ROOT/node_modules"
  echo "    node_modules removed."

  PM="$(detect_pm)"
  echo "==> Reinstalling dependencies with $PM..."
  (cd "$PROJECT_ROOT" && $PM install)
  echo "    Dependencies reinstalled."
  echo ""
fi

# --- iOS Pods ---

if $CLEAN_PODS; then
  echo "==> Removing iOS Pods..."
  if [ -d "$PROJECT_ROOT/ios" ]; then
    rm -rf "$PROJECT_ROOT/ios/Pods"
    rm -f "$PROJECT_ROOT/ios/Podfile.lock"
    echo "    Pods removed."

    if command -v pod &>/dev/null; then
      echo "==> Reinstalling Pods..."
      if command -v bundle &>/dev/null && [ -f "$PROJECT_ROOT/Gemfile" ]; then
        (cd "$PROJECT_ROOT/ios" && bundle exec pod install)
      else
        (cd "$PROJECT_ROOT/ios" && pod install)
      fi
      echo "    Pods reinstalled."
    else
      echo "    CocoaPods not found — run 'pod install' manually in ios/."
    fi
  else
    echo "    No ios/ directory found, skipping."
  fi
  echo ""
fi

# --- DerivedData ---

if $CLEAN_DERIVED_DATA; then
  echo "==> Removing DerivedData..."
  DD_PATH="$HOME/Library/Developer/Xcode/DerivedData"
  if [ -d "$DD_PATH" ]; then
    rm -rf "$DD_PATH"
    echo "    DerivedData removed."
  else
    echo "    DerivedData directory not found, skipping."
  fi
  echo ""
fi

# --- Gradle ---

if $CLEAN_GRADLE; then
  echo "==> Cleaning Android Gradle cache and build artifacts..."
  if [ -d "$PROJECT_ROOT/android" ]; then
    rm -rf "$PROJECT_ROOT/android/.gradle" 2>/dev/null || true
    rm -rf "$PROJECT_ROOT/android/app/build" 2>/dev/null || true
    echo "    Android build artifacts removed."
  else
    echo "    No android/ directory found, skipping."
  fi
  echo ""
fi

# --- Kill Metro on port 8081 if metro was cleaned ---

if $CLEAN_METRO; then
  metro_pid="$(lsof -ti :8081 2>/dev/null || true)"
  if [ -n "$metro_pid" ]; then
    echo "==> Killing process on port 8081 (PID $metro_pid)..."
    kill -15 "$metro_pid" 2>/dev/null || true
    sleep 1
    kill -0 "$metro_pid" 2>/dev/null && kill -9 "$metro_pid" 2>/dev/null || true
    echo "    Process killed."
    echo ""
  fi
fi

echo "Done. Clean targets completed successfully."
