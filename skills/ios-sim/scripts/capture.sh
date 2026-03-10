#!/usr/bin/env bash
set -euo pipefail

# capture.sh — iOS Simulator screenshots and video recording
# Commands: view, screenshot, record, stop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# AXe path: honor env var or default to "axe"
AXE="${IOS_SIMULATOR_MCP_AXE_PATH:-axe}"

# Default output directory
DEFAULT_OUTPUT_DIR="${IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR:-$HOME/Downloads}"

# Expand tilde in output dir
if [[ "$DEFAULT_OUTPUT_DIR" == "~/"* ]]; then
    DEFAULT_OUTPUT_DIR="$HOME/${DEFAULT_OUTPUT_DIR#\~/}"
fi

# Temp directory for intermediate files
TMP_DIR=$(mktemp -d /tmp/ios-sim-capture-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

# Validate UDID format
validate_udid() {
    local udid="$1"
    if [[ ! "$udid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
        echo "Error: Invalid UDID format: $udid" >&2
        exit 1
    fi
}

# Resolve path: absolute stays, relative goes to DEFAULT_OUTPUT_DIR
resolve_path() {
    local fpath="$1"
    if [[ "$fpath" == /* ]]; then
        echo "$fpath"
    elif [[ "$fpath" == "~/"* ]]; then
        echo "$HOME/${fpath#\~/}"
    else
        echo "${DEFAULT_OUTPUT_DIR}/${fpath}"
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
    echo "Usage: capture.sh <command> [args] [options]"
    echo ""
    echo "Commands:"
    echo "  view                                   Compressed screenshot (returns temp file path)"
    echo "  screenshot <output_path> [--type png|jpeg|tiff|bmp|gif] [--display internal|external] [--mask ignored|alpha|black]"
    echo "  record [output_path] [--codec h264|hevc] [--display internal|external] [--mask ignored|alpha|black] [--force]"
    echo "  stop                                   Stop active video recording"
    echo ""
    echo "Options:"
    echo "  --udid <UUID>    Target a specific device"
    exit 1
}

cmd_view() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local udid
    udid=$(get_udid)

    # Get screen dimensions from accessibility tree (if AXe is available)
    local width="" height=""
    if command -v "$AXE" >/dev/null 2>&1; then
        local ui_json
        ui_json=$("$AXE" describe-ui --udid "$udid" 2>/dev/null) || true
        width=$(echo "$ui_json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(Math.round(JSON.parse(d)[0].frame.width))}catch{}})" 2>/dev/null || echo "")
        height=$(echo "$ui_json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(Math.round(JSON.parse(d)[0].frame.height))}catch{}})" 2>/dev/null || echo "")
    fi

    local raw_png="$TMP_DIR/raw.png"
    local compressed_jpg="$TMP_DIR/compressed.jpg"

    # Capture PNG screenshot
    xcrun simctl io "$udid" screenshot --type=png -- "$raw_png" 2>/dev/null

    # Fallback: derive point dimensions from PNG pixel size when AXe is unavailable
    if [[ -z "$width" || -z "$height" ]]; then
        local pixel_w pixel_h
        pixel_w=$(sips -g pixelWidth "$raw_png" 2>/dev/null | awk '/pixelWidth/{print $2}')
        pixel_h=$(sips -g pixelHeight "$raw_png" 2>/dev/null | awk '/pixelHeight/{print $2}')
        if [[ -n "$pixel_w" && -n "$pixel_h" ]]; then
            # Divide by 3 for Retina point dimensions (all current iOS Simulator devices are 3x)
            width=$(( pixel_w / 3 ))
            height=$(( pixel_h / 3 ))
        fi
    fi

    if [[ -n "$width" && -n "$height" ]]; then
        # Resize to point dimensions and compress to JPEG
        sips -z "$height" "$width" -s format jpeg -s formatOptions 80 "$raw_png" --out "$compressed_jpg" >/dev/null 2>&1
    else
        # Fallback: just compress without resize
        sips -s format jpeg -s formatOptions 80 "$raw_png" --out "$compressed_jpg" >/dev/null 2>&1
    fi

    # Copy to a stable temp path (our TMP_DIR gets cleaned up on exit)
    local output_path="/tmp/ios-sim-view-$(date +%s).jpg"
    cp "$compressed_jpg" "$output_path"

    echo "$output_path"
}

cmd_screenshot() {
    local output_path="" img_type="" display="" mask=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)    img_type="$2"; shift 2 ;;
            --display) display="$2"; shift 2 ;;
            --mask)    mask="$2"; shift 2 ;;
            --udid)    OPT_UDID="$2"; shift 2 ;;
            *)         positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
        echo "Error: screenshot requires <output_path>" >&2; exit 1
    fi
    output_path=$(resolve_path "${positional[0]}")

    local udid
    udid=$(get_udid)

    local -a args=("simctl" "io" "$udid" "screenshot")
    [[ -n "$img_type" ]] && args+=("--type=${img_type}")
    [[ -n "$display" ]] && args+=("--display=${display}")
    [[ -n "$mask" ]] && args+=("--mask=${mask}")
    args+=("--" "$output_path")

    xcrun "${args[@]}" 2>&1
    echo "Wrote screenshot to: $output_path"
}

cmd_record() {
    local output_path="" codec="" display="" mask="" force=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --codec)   codec="$2"; shift 2 ;;
            --display) display="$2"; shift 2 ;;
            --mask)    mask="$2"; shift 2 ;;
            --force)   force="1"; shift ;;
            --udid)    OPT_UDID="$2"; shift 2 ;;
            *)         positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -ge 1 ]]; then
        output_path=$(resolve_path "${positional[0]}")
    else
        output_path=$(resolve_path "simulator_recording_$(date +%s).mp4")
    fi

    local udid
    udid=$(get_udid)

    local -a args=("simctl" "io" "$udid" "recordVideo")
    [[ -n "$codec" ]] && args+=("--codec=${codec}")
    [[ -n "$display" ]] && args+=("--display=${display}")
    [[ -n "$mask" ]] && args+=("--mask=${mask}")
    [[ -n "$force" ]] && args+=("--force")
    args+=("--" "$output_path")

    # Start recording in background
    xcrun "${args[@]}" &
    local pid=$!

    # Wait briefly for recording to start
    sleep 2

    if kill -0 "$pid" 2>/dev/null; then
        echo "Recording started. Video will be saved to: $output_path"
        echo "To stop recording, run: capture.sh stop"
    else
        echo "Error: Recording process terminated unexpectedly" >&2
        exit 1
    fi
}

cmd_stop() {
    if pkill -SIGINT -f "simctl.*recordVideo" 2>/dev/null; then
        sleep 1
        echo "Recording stopped successfully"
    else
        echo "Error: No active recording found" >&2
        exit 1
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
    view)       cmd_view "$@" ;;
    screenshot) cmd_screenshot "$@" ;;
    record)     cmd_record "$@" ;;
    stop)       cmd_stop "$@" ;;
    *)          echo "Error: Unknown command '$command'" >&2; usage ;;
esac
