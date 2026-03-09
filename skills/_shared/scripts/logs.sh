#!/usr/bin/env bash
set -euo pipefail

# logs.sh -- iOS + Android JS console log capture
# Commands: ios, android

usage() {
    echo "Usage: logs.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  ios              Stream iOS JS console logs"
    echo "  android          Stream Android JS console logs"
    echo ""
    echo "Options:"
    echo "  --timeout <SEC>  Stop after SEC seconds (default: unlimited)"
    echo "  --json           Output in JSON format (NDJSON)"
    echo "  --native         Include native RN logs (iOS only)"
    exit 1
}

# Run a command with a timeout using background process + sleep + kill.
# macOS does not ship GNU coreutils timeout by default.
# Args: timeout_seconds command...
run_with_timeout() {
    local timeout_sec="$1"
    shift

    "$@" &
    local cmd_pid=$!

    # Clean up background process on script exit or interrupt
    trap 'kill "$cmd_pid" 2>/dev/null; wait "$cmd_pid" 2>/dev/null; exit 0' INT TERM

    sleep "$timeout_sec" &
    local sleep_pid=$!

    wait "$sleep_pid" 2>/dev/null
    kill "$cmd_pid" 2>/dev/null
    wait "$cmd_pid" 2>/dev/null
    exit 0
}

cmd_ios() {
    local timeout=""
    local json_flag=false
    local native_flag=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout) timeout="$2"; shift 2 ;;
            --json)    json_flag=true; shift ;;
            --native)  native_flag=true; shift ;;
            *)         echo "Error: Unknown option '$1'" >&2; exit 1 ;;
        esac
    done

    local predicate
    if [[ "$native_flag" == true ]]; then
        predicate='subsystem == "com.facebook.react.log"'
    else
        predicate='subsystem == "com.facebook.react.log" AND category == "javascript"'
    fi

    local style="compact"
    if [[ "$json_flag" == true ]]; then
        style="ndjson"
    fi

    local cmd=(xcrun simctl spawn booted log stream --predicate "$predicate" --style "$style")

    if [[ -n "$timeout" ]]; then
        run_with_timeout "$timeout" "${cmd[@]}"
    else
        trap 'exit 0' INT TERM
        exec "${cmd[@]}"
    fi
}

cmd_android() {
    local timeout=""
    local json_flag=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout) timeout="$2"; shift 2 ;;
            --json)    json_flag=true; shift ;;
            *)         echo "Error: Unknown option '$1'" >&2; exit 1 ;;
        esac
    done

    local format="brief"
    if [[ "$json_flag" == true ]]; then
        format="json"
    fi

    local cmd=(adb logcat -v "$format" '*:S' ReactNativeJS:V)

    if [[ -n "$timeout" ]]; then
        run_with_timeout "$timeout" "${cmd[@]}"
    else
        trap 'exit 0' INT TERM
        exec "${cmd[@]}"
    fi
}

# --- Main ---

if [[ $# -lt 1 ]]; then
    usage
fi

command="$1"
shift

case "$command" in
    ios)     cmd_ios "$@" ;;
    android) cmd_android "$@" ;;
    *)       echo "Error: Unknown command '$command'" >&2; usage ;;
esac
