#!/usr/bin/env bash
set -euo pipefail

# metro.sh -- Metro health/status/symbolication
# Commands: status, targets, bundle-check, symbolicate

# Resolve Metro port: --port flag > RCT_METRO_PORT env > 8081
resolve_port() {
    if [[ -z "${PORT:-}" ]]; then
        PORT="${RCT_METRO_PORT:-8081}"
    fi
}

usage() {
    echo "Usage: metro.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status          Check if Metro is running"
    echo "  targets         List debuggable CDP targets"
    echo "  bundle-check    Check if JS bundle builds successfully"
    echo "  symbolicate     Symbolicate a stack trace from stdin"
    echo "  detect-entry    Print the JS entry point (index or expo-router entry)"
    echo "  env             Print environment summary as JSON"
    echo ""
    echo "Options:"
    echo "  --port <PORT>   Metro port (default: \$RCT_METRO_PORT or 8081)"
    exit 1
}

# Verify Metro is running; exit 1 with message if not
require_metro_running() {
    resolve_port
    local response
    if ! response=$(curl -s --connect-timeout 2 --max-time 5 "http://localhost:${PORT}/status" 2>/dev/null); then
        echo "Error: Metro is not running on port ${PORT}" >&2
        exit 1
    fi
    if [[ "$response" != *"packager-status:running"* ]]; then
        echo "Error: Metro is not running on port ${PORT}" >&2
        exit 1
    fi
}

cmd_status() {
    resolve_port
    local response
    if response=$(curl -s --connect-timeout 2 --max-time 5 "http://localhost:${PORT}/status" 2>/dev/null) \
       && [[ "$response" == *"packager-status:running"* ]]; then
        echo "Metro is running on port ${PORT}"
        exit 0
    else
        echo "Error: Metro is not running on port ${PORT}" >&2
        exit 1
    fi
}

cmd_targets() {
    require_metro_running
    curl -s --connect-timeout 2 --max-time 5 "http://localhost:${PORT}/json/list"
}

# Detect JS entry point: expo-router > package.json main > "index"
# Reusable by other scripts: ENTRY=$(metro.sh detect-entry)
detect_entry() {
    if [[ -f "package.json" ]] && command -v node >/dev/null 2>&1; then
        local detected
        detected=$(node -e "
            try {
                const pkg = require('./package.json');
                const deps = {...(pkg.dependencies||{}), ...(pkg.devDependencies||{})};
                if (deps['expo-router']) {
                    console.log('node_modules/expo-router/entry');
                } else if (pkg.main) {
                    console.log(pkg.main.replace(/\.[jt]sx?$/, ''));
                }
            } catch {}
        " 2>/dev/null || true)
        if [[ -n "$detected" ]]; then
            echo "$detected"
            return
        fi
    fi
    echo "index"
}

cmd_detect_entry() {
    detect_entry
}

cmd_env() {
    resolve_port

    local metro="false"
    if response=$(curl -s --connect-timeout 2 --max-time 5 "http://localhost:${PORT}/status" 2>/dev/null) \
       && [[ "$response" == *"packager-status:running"* ]]; then
        metro="true"
    fi

    local expo="false"
    local new_arch="false"
    if command -v node >/dev/null 2>&1 && [[ -f "package.json" ]]; then
        local project_info
        project_info=$(node -e "
            try {
                const pkg = require('./package.json');
                const deps = {...(pkg.dependencies||{}), ...(pkg.devDependencies||{})};
                const expo = !!deps['expo'];
                let newArch = false;
                try { const app = require('./app.json'); newArch = !!app.expo?.newArchEnabled; } catch {}
                console.log(JSON.stringify({expo, newArch}));
            } catch { console.log('{}'); }
        " 2>/dev/null || true)
        if [[ -n "$project_info" ]]; then
            expo=$(echo "$project_info" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); console.log(d.expo||false)" 2>/dev/null || echo "false")
            new_arch=$(echo "$project_info" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); console.log(d.newArch||false)" 2>/dev/null || echo "false")
        fi
    fi

    local entry
    entry=$(detect_entry)

    local platform="ios"
    if ! xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
        if command -v adb >/dev/null 2>&1 && adb devices 2>/dev/null | grep -q "device$"; then
            platform="android"
        fi
    fi

    printf '{"metro":%s,"port":%s,"expo":%s,"newArch":%s,"entry":"%s","platform":"%s"}\n' \
        "$metro" "$PORT" "$expo" "$new_arch" "$entry" "$platform"
}

cmd_bundle_check() {
    local PLATFORM="ios"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform) PLATFORM="$2"; shift 2 ;;
            *) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
        esac
    done

    require_metro_running

    local ENTRY
    ENTRY=$(detect_entry)

    local tmpfile
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' EXIT

    local http_status
    http_status=$(curl -s --connect-timeout 5 --max-time 30 \
        --write-out "%{http_code}" \
        --output "$tmpfile" \
        "http://localhost:${PORT}/${ENTRY}.bundle?platform=${PLATFORM}&dev=true&minify=false")

    if [[ "$http_status" == "200" ]]; then
        echo "Bundle builds successfully (platform: ${PLATFORM})"
        exit 0
    else
        echo "Error: Bundle build failed (HTTP ${http_status}, platform: ${PLATFORM})" >&2
        cat "$tmpfile" >&2
        exit 1
    fi
}

cmd_symbolicate() {
    require_metro_running

    if [[ -t 0 ]]; then
        echo "Error: Expected JSON stack trace on stdin" >&2
        exit 1
    fi

    local input
    input=$(cat)
    if [[ -z "$input" ]]; then
        echo "Error: Empty input on stdin" >&2
        exit 1
    fi

    curl -s --connect-timeout 2 --max-time 10 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$input" \
        "http://localhost:${PORT}/symbolicate"
}

# --- Main ---

if [[ $# -lt 1 ]]; then
    usage
fi

# Extract --port from anywhere in args before dispatching
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        *)      ARGS+=("$1"); shift ;;
    esac
done

if [[ ${#ARGS[@]} -lt 1 ]]; then
    usage
fi

command="${ARGS[0]}"
# Remove the command from ARGS, pass remainder to subcommand
REMAINING_ARGS=("${ARGS[@]:1}")

case "$command" in
    status)       cmd_status "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}" ;;
    targets)      cmd_targets "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}" ;;
    bundle-check) cmd_bundle_check "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}" ;;
    symbolicate)  cmd_symbolicate "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}" ;;
    detect-entry) cmd_detect_entry ;;
    env)          cmd_env ;;
    *)            echo "Error: Unknown command '$command'" >&2; usage ;;
esac
