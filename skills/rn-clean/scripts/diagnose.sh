#!/usr/bin/env bash
# diagnose.sh — Check React Native environment state and output a JSON report.
# Usage: bash diagnose.sh [project_root]
#
# If project_root is not provided, uses the current working directory.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# --- Helpers ---

json_escape() {
  printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
}

# --- Port 8081 ---

port_8081_pid=""
port_8081_process=""
port_8081_in_use=false

if lsof_out="$(lsof -ti :8081 2>/dev/null)"; then
  port_8081_in_use=true
  port_8081_pid="$(echo "$lsof_out" | head -1)"
  port_8081_process="$(ps -p "$port_8081_pid" -o comm= 2>/dev/null || echo "unknown")"
fi

# --- Watchman ---

watchman_running=false
watchman_watch_count=0

if command -v watchman &>/dev/null; then
  if watch_list="$(watchman watch-list 2>/dev/null)"; then
    watchman_running=true
    watchman_watch_count="$(echo "$watch_list" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("roots",[])))' 2>/dev/null || echo 0)"
  fi
fi

# --- node_modules ---

node_modules_exists=false
node_modules_stale=false

if [ -d "$PROJECT_ROOT/node_modules" ]; then
  node_modules_exists=true
  # Check if node_modules is out of sync with lockfile
  if [ -f "$PROJECT_ROOT/package-lock.json" ]; then
    lock_mtime="$(stat -f %m "$PROJECT_ROOT/package-lock.json" 2>/dev/null || stat -c %Y "$PROJECT_ROOT/package-lock.json" 2>/dev/null || echo 0)"
    nm_mtime="$(stat -f %m "$PROJECT_ROOT/node_modules/.package-lock.json" 2>/dev/null || stat -c %Y "$PROJECT_ROOT/node_modules/.package-lock.json" 2>/dev/null || echo 0)"
    if [ "$lock_mtime" -gt "$nm_mtime" ] 2>/dev/null; then
      node_modules_stale=true
    fi
  elif [ -f "$PROJECT_ROOT/yarn.lock" ]; then
    lock_mtime="$(stat -f %m "$PROJECT_ROOT/yarn.lock" 2>/dev/null || stat -c %Y "$PROJECT_ROOT/yarn.lock" 2>/dev/null || echo 0)"
    nm_mtime="$(stat -f %m "$PROJECT_ROOT/node_modules/.yarn-integrity" 2>/dev/null || stat -c %Y "$PROJECT_ROOT/node_modules/.yarn-integrity" 2>/dev/null || echo 0)"
    if [ "$lock_mtime" -gt "$nm_mtime" ] 2>/dev/null; then
      node_modules_stale=true
    fi
  fi
fi

# --- iOS Pods ---

pods_exist=false
pods_stale=false

if [ -d "$PROJECT_ROOT/ios/Pods" ]; then
  pods_exist=true
  if [ -f "$PROJECT_ROOT/ios/Podfile" ]; then
    podfile_mtime="$(stat -f %m "$PROJECT_ROOT/ios/Podfile" 2>/dev/null || stat -c %Y "$PROJECT_ROOT/ios/Podfile" 2>/dev/null || echo 0)"
    pods_mtime="$(stat -f %m "$PROJECT_ROOT/ios/Pods" 2>/dev/null || stat -c %Y "$PROJECT_ROOT/ios/Pods" 2>/dev/null || echo 0)"
    if [ "$podfile_mtime" -gt "$pods_mtime" ] 2>/dev/null; then
      pods_stale=true
    fi
  fi
fi

# --- DerivedData ---

derived_data_exists=false
derived_data_size="0B"

DD_PATH="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DD_PATH" ]; then
  derived_data_exists=true
  derived_data_size="$(du -sh "$DD_PATH" 2>/dev/null | awk '{print $1}' || echo "unknown")"
fi

# --- Android build state ---

gradle_cache_exists=false
android_build_exists=false

if [ -d "$PROJECT_ROOT/android/.gradle" ]; then
  gradle_cache_exists=true
fi
if [ -d "$PROJECT_ROOT/android/app/build" ]; then
  android_build_exists=true
fi

# --- Metro cache ---

metro_cache_exists=false
metro_cache_count=0

_TMPDIR="${TMPDIR:-/tmp}"
_TMPDIR="${_TMPDIR%/}"
metro_files="$(ls -d /tmp/metro-* /tmp/haste-* "${_TMPDIR}"/metro-* "${_TMPDIR}"/haste-* 2>/dev/null | sort -u || true)"
if [ -n "$metro_files" ]; then
  metro_cache_exists=true
  metro_cache_count="$(echo "$metro_files" | wc -l | tr -d ' ')"
fi

# --- Output JSON ---

cat <<ENDJSON
{
  "project_root": $(json_escape "$PROJECT_ROOT"),
  "port_8081": {
    "in_use": $port_8081_in_use,
    "pid": $(json_escape "$port_8081_pid"),
    "process": $(json_escape "$port_8081_process")
  },
  "watchman": {
    "running": $watchman_running,
    "watch_count": $watchman_watch_count
  },
  "node_modules": {
    "exists": $node_modules_exists,
    "stale": $node_modules_stale
  },
  "ios_pods": {
    "exists": $pods_exist,
    "stale": $pods_stale
  },
  "derived_data": {
    "exists": $derived_data_exists,
    "size": $(json_escape "$derived_data_size")
  },
  "android": {
    "gradle_cache": $gradle_cache_exists,
    "build_artifacts": $android_build_exists
  },
  "metro_cache": {
    "exists": $metro_cache_exists,
    "file_count": $metro_cache_count
  }
}
ENDJSON
