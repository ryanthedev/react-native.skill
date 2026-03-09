#!/usr/bin/env bash
set -euo pipefail

# ui.sh — iOS Simulator UI interaction via idb
# Commands: tap, type, swipe, describe-all, describe-point

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# IDB path: honor env var or default to "idb"
IDB="${IOS_SIMULATOR_MCP_IDB_PATH:-idb}"

# Guard: all ui.sh commands require idb
if ! command -v "$IDB" >/dev/null 2>&1; then
    echo "Error: idb is not installed. All ui.sh commands require Facebook IDB." >&2
    echo "" >&2
    echo "Install with:  pip3 install fb-idb" >&2
    echo "Or set IOS_SIMULATOR_MCP_IDB_PATH to your idb binary location." >&2
    exit 1
fi

# Validate UDID format (8-4-4-4-12 hex)
validate_udid() {
    local udid="$1"
    if [[ ! "$udid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
        echo "Error: Invalid UDID format: $udid" >&2
        exit 1
    fi
}

# Validate a number (integer or decimal)
validate_number() {
    local val="$1" label="$2"
    if [[ ! "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: $label must be a number, got: $val" >&2
        exit 1
    fi
}

# Validate duration (positive decimal)
validate_duration() {
    local val="$1"
    if [[ ! "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: Duration must be a positive number, got: $val" >&2
        exit 1
    fi
}

# Validate ASCII printable text (0x20-0x7E), max 500 chars
validate_text() {
    local text="$1"
    if [[ ${#text} -gt 500 ]]; then
        echo "Error: Text exceeds 500 character limit (got ${#text})" >&2
        exit 1
    fi
    if [[ ! "$text" =~ ^[[:print:]]+$ ]]; then
        echo "Error: Text must contain only ASCII printable characters" >&2
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
    echo "Usage: ui.sh <command> [args] [options]"
    echo ""
    echo "Commands:"
    echo "  tap <x> <y> [--duration <sec>]        Tap at coordinates"
    echo "  type <text>                            Input text"
    echo "  swipe <x1> <y1> <x2> <y2> [--duration <sec>] [--delta <n>]"
    echo "                                         Swipe gesture"
    echo "  describe-all                           Full accessibility tree (JSON)"
    echo "  describe-point <x> <y>                 Element at coordinates (JSON)"
    echo ""
    echo "Options:"
    echo "  --udid <UUID>    Target a specific device"
    exit 1
}

cmd_tap() {
    local x="" y="" duration=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --duration) duration="$2"; shift 2 ;;
            --udid)     OPT_UDID="$2"; shift 2 ;;
            *)          positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 2 ]]; then
        echo "Error: tap requires <x> <y>" >&2; exit 1
    fi
    x="${positional[0]}"
    y="${positional[1]}"

    validate_number "$x" "x"
    validate_number "$y" "y"
    [[ -n "$duration" ]] && validate_duration "$duration"

    local udid
    udid=$(get_udid)

    local -a args=("ui" "tap" "--udid" "$udid")
    [[ -n "$duration" ]] && args+=("--duration" "$duration")
    args+=("--json" "--" "$x" "$y")

    "$IDB" "${args[@]}" >/dev/null 2>&1
    echo "Tapped successfully at ($x, $y)"
}

cmd_type() {
    local text=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
        echo "Error: type requires <text>" >&2; exit 1
    fi
    text="${positional[0]}"

    validate_text "$text"

    local udid
    udid=$(get_udid)

    "$IDB" ui text --udid "$udid" -- "$text" >/dev/null 2>&1
    echo "Typed successfully: \"$text\""
}

cmd_swipe() {
    local x1="" y1="" x2="" y2="" duration="" delta=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --duration) duration="$2"; shift 2 ;;
            --delta)    delta="$2"; shift 2 ;;
            --udid)     OPT_UDID="$2"; shift 2 ;;
            *)          positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 4 ]]; then
        echo "Error: swipe requires <x_start> <y_start> <x_end> <y_end>" >&2; exit 1
    fi
    x1="${positional[0]}"
    y1="${positional[1]}"
    x2="${positional[2]}"
    y2="${positional[3]}"

    validate_number "$x1" "x_start"
    validate_number "$y1" "y_start"
    validate_number "$x2" "x_end"
    validate_number "$y2" "y_end"
    [[ -n "$duration" ]] && validate_duration "$duration"
    [[ -n "$delta" ]] && validate_number "$delta" "delta"

    local udid
    udid=$(get_udid)

    local -a args=("ui" "swipe" "--udid" "$udid")
    [[ -n "$duration" ]] && args+=("--duration" "$duration")
    [[ -n "$delta" ]] && args+=("--delta" "$delta")
    args+=("--json" "--" "$x1" "$y1" "$x2" "$y2")

    "$IDB" "${args[@]}" >/dev/null 2>&1
    echo "Swiped successfully from ($x1, $y1) to ($x2, $y2)"
}

cmd_describe_all() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local udid
    udid=$(get_udid)

    "$IDB" ui describe-all --udid "$udid" --json --nested
}

cmd_describe_point() {
    local x="" y=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 2 ]]; then
        echo "Error: describe-point requires <x> <y>" >&2; exit 1
    fi
    x="${positional[0]}"
    y="${positional[1]}"

    validate_number "$x" "x"
    validate_number "$y" "y"

    local udid
    udid=$(get_udid)

    "$IDB" ui describe-point --udid "$udid" --json -- "$x" "$y"
}

# --- Main ---

OPT_UDID=""

if [[ $# -lt 1 ]]; then
    usage
fi

command="$1"
shift

case "$command" in
    tap)            cmd_tap "$@" ;;
    type)           cmd_type "$@" ;;
    swipe)          cmd_swipe "$@" ;;
    describe-all)   cmd_describe_all "$@" ;;
    describe-point) cmd_describe_point "$@" ;;
    *)              echo "Error: Unknown command '$command'" >&2; usage ;;
esac
