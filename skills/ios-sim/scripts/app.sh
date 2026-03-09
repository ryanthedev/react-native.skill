#!/usr/bin/env bash
set -euo pipefail

# app.sh — iOS Simulator app management
# Commands: install, launch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate UDID format
validate_udid() {
    local udid="$1"
    if [[ ! "$udid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
        echo "Error: Invalid UDID format: $udid" >&2
        exit 1
    fi
}

# Get booted device UDID
get_udid() {
    local udid="${OPT_UDID:-}"
    if [[ -n "$udid" ]]; then
        validate_udid "$udid"
        echo "$udid"
        return
    fi
    local output
    output=$(xcrun simctl list devices 2>&1)
    local line
    line=$(echo "$output" | grep "(Booted)" | head -1)
    if [[ -z "$line" ]]; then
        echo "Error: No booted simulator found" >&2
        exit 1
    fi
    echo "$line" | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'
}

usage() {
    echo "Usage: app.sh <command> [args] [options]"
    echo ""
    echo "Commands:"
    echo "  install <path>                         Install .app or .ipa bundle"
    echo "  launch <bundle_id> [--terminate]       Launch app by bundle identifier"
    echo ""
    echo "Options:"
    echo "  --udid <UUID>    Target a specific device"
    exit 1
}

cmd_install() {
    local app_path=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
        echo "Error: install requires <app_path>" >&2; exit 1
    fi
    app_path="${positional[0]}"

    # Resolve to absolute path
    if [[ "$app_path" != /* ]]; then
        app_path="$(cd "$(dirname "$app_path")" && pwd)/$(basename "$app_path")"
    fi

    # Check existence
    if [[ ! -e "$app_path" ]]; then
        echo "Error: App bundle not found at: $app_path" >&2
        exit 1
    fi

    local udid
    udid=$(get_udid)

    xcrun simctl install "$udid" "$app_path"
    echo "App installed successfully from: $app_path"
}

cmd_launch() {
    local bundle_id="" terminate=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --terminate) terminate="1"; shift ;;
            --udid)      OPT_UDID="$2"; shift 2 ;;
            *)           positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
        echo "Error: launch requires <bundle_id>" >&2; exit 1
    fi
    bundle_id="${positional[0]}"

    # Validate bundle_id length
    if [[ ${#bundle_id} -gt 256 ]]; then
        echo "Error: Bundle ID exceeds 256 character limit" >&2
        exit 1
    fi

    local udid
    udid=$(get_udid)

    local -a args=("simctl" "launch")
    [[ -n "$terminate" ]] && args+=("--terminate-running-process")
    args+=("$udid" "$bundle_id")

    local output
    output=$(xcrun "${args[@]}" 2>&1)

    # Extract PID if available
    local pid
    pid=$(echo "$output" | grep -oE '^[0-9]+' || true)

    if [[ -n "$pid" ]]; then
        echo "App $bundle_id launched successfully with PID: $pid"
    else
        echo "App $bundle_id launched successfully"
    fi
}

# --- Main ---

OPT_UDID=""

if [[ $# -lt 1 ]]; then
    usage
fi

command="$1"
shift

case "$command" in
    install) cmd_install "$@" ;;
    launch)  cmd_launch "$@" ;;
    *)       echo "Error: Unknown command '$command'" >&2; usage ;;
esac
