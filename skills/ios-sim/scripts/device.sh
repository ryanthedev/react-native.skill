#!/usr/bin/env bash
set -euo pipefail

# device.sh — iOS Simulator device management
# Commands: booted, open

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: device.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  booted           Get the booted simulator name and UUID"
    echo "  open             Open the Simulator application"
    echo ""
    echo "Options:"
    echo "  --udid <UUID>    Target a specific device (optional)"
    exit 1
}

# Parse the booted device from xcrun simctl list
get_booted_device() {
    local output
    output=$(xcrun simctl list devices 2>&1)

    local line
    line=$(echo "$output" | grep "(Booted)" | head -1)

    if [[ -z "$line" ]]; then
        echo "Error: No booted simulator found" >&2
        echo "Run 'xcrun simctl list devices' to see available devices" >&2
        exit 1
    fi

    local uuid
    uuid=$(echo "$line" | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
    local name
    name=$(echo "$line" | sed 's/ (.*//;s/^[[:space:]]*//')

    echo "Booted Simulator: \"${name}\". UUID: \"${uuid}\""
}

cmd_booted() {
    get_booted_device
}

cmd_open() {
    open -a Simulator.app
    echo "Simulator.app opened successfully"
}

# --- Main ---

if [[ $# -lt 1 ]]; then
    usage
fi

command="$1"
shift

case "$command" in
    booted) cmd_booted "$@" ;;
    open)   cmd_open "$@" ;;
    *)      echo "Error: Unknown command '$command'" >&2; usage ;;
esac
