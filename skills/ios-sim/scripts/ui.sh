#!/usr/bin/env bash
set -euo pipefail

# ui.sh — iOS Simulator UI interaction via AXe
# Commands: tap, tap-label, tap-id, type, swipe, describe-all, describe-point, list, back, scroll

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# AXe path: honor env var or default to "axe"
AXE="${IOS_SIMULATOR_MCP_AXE_PATH:-axe}"

# Guard: all ui.sh commands require AXe
if ! command -v "$AXE" >/dev/null 2>&1; then
    echo "Error: AXe is not installed. All ui.sh commands require AXe." >&2
    echo "" >&2
    echo "Install with:  brew install cameroncooke/axe/axe" >&2
    echo "Or set IOS_SIMULATOR_MCP_AXE_PATH to your axe binary location." >&2
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
    echo "  swipe <x1> <y1> <x2> <y2> [--duration <sec>]"
    echo "                                         Swipe gesture"
    echo "  tap-label <label>                    Tap element by accessibility label"
    echo "  tap-id <id>                          Tap element by accessibility ID"
    echo "  describe-all                           Full accessibility tree (JSON)"
    echo "  describe-point <x> <y>                 Element at coordinates (JSON)"
    echo "  list                                 List on-screen interactive elements"
    echo "  back                                 Tap the back/navigation element"
    echo "  scroll <top|bottom>                  Scroll until content stabilizes"
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

    local -a args=("tap" "-x" "$x" "-y" "$y" "--udid" "$udid")
    [[ -n "$duration" ]] && args+=("--duration" "$duration")

    "$AXE" "${args[@]}" >/dev/null 2>&1
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

    "$AXE" type "$text" --udid "$udid" >/dev/null 2>&1
    echo "Typed successfully: \"$text\""
}

cmd_swipe() {
    local x1="" y1="" x2="" y2="" duration=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --duration) duration="$2"; shift 2 ;;
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

    local udid
    udid=$(get_udid)

    local -a args=("swipe" "--start-x" "$x1" "--start-y" "$y1" "--end-x" "$x2" "--end-y" "$y2" "--udid" "$udid")
    [[ -n "$duration" ]] && args+=("--duration" "$duration")

    "$AXE" "${args[@]}" >/dev/null 2>&1
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

    "$AXE" describe-ui --udid "$udid"
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

    # AXe has no point-based describe; filter the full tree for the deepest
    # leaf element whose frame contains the target point.
    "$AXE" describe-ui --udid "$udid" | node -e "
        const data = [];
        process.stdin.on('data', c => data.push(c));
        process.stdin.on('end', () => {
            const tree = JSON.parse(data.join(''));
            const tx = $x, ty = $y;
            let best = null, bestDepth = -1;
            function walk(nodes, depth) {
                for (const n of nodes) {
                    const f = n.frame;
                    if (f && tx >= f.x - 1 && tx <= f.x + f.width + 1 && ty >= f.y - 1 && ty <= f.y + f.height + 1 && depth >= bestDepth) {
                        best = n;
                        bestDepth = depth;
                    }
                    if (n.children) walk(n.children, depth + 1);
                }
            }
            walk(Array.isArray(tree) ? tree : [tree], 0);
            if (best) {
                const { children, ...rest } = best;
                console.log(JSON.stringify(rest, null, 2));
            } else {
                console.error('No element found at (' + tx + ', ' + ty + ')');
                process.exit(1);
            }
        });
    "
}

# Tap element by accessibility label
cmd_tap_label() {
    local label=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
        echo "Error: tap-label requires <label>" >&2; exit 1
    fi
    label="${positional[0]}"

    validate_text "$label"

    local udid
    udid=$(get_udid)

    "$AXE" tap --label "$label" --udid "$udid" >/dev/null
    echo "Tapped element with label: \"$label\""
}

# Tap element by accessibility identifier
cmd_tap_id() {
    local id=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
        echo "Error: tap-id requires <id>" >&2; exit 1
    fi
    id="${positional[0]}"

    validate_text "$id"

    local udid
    udid=$(get_udid)

    "$AXE" tap --id "$id" --udid "$udid" >/dev/null
    echo "Tapped element with id: \"$id\""
}

# List on-screen interactive elements, grouped by size
cmd_list() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local udid
    udid=$(get_udid)

    "$AXE" describe-ui --udid "$udid" | node -e '
        const data = [];
        process.stdin.on("data", c => data.push(c));
        process.stdin.on("end", () => {
            const tree = JSON.parse(data.join(""));
            const root = tree[0] || {};
            const screenW = (root.frame && root.frame.width) || 10000;
            const screenH = (root.frame && root.frame.height) || 10000;

            const found = [];
            function walk(nodes, depth) {
                for (const n of nodes) {
                    const f = n.frame;
                    const label = n.AXLabel;
                    if (label && label !== "" &&
                        n.type !== "StaticText" &&
                        n.type !== "Application" &&
                        f &&
                        f.x + f.width > 0 && f.x < screenW &&
                        f.y + f.height > 0 && f.y < screenH) {
                        found.push({ label, width: f.width, height: f.height,
                                     x: f.x, y: f.y, cx: f.x + f.width / 2,
                                     cy: f.y + f.height / 2, depth });
                    }
                    if (n.children) walk(n.children, depth + 1);
                }
            }
            walk(tree, 0);

            // Deduplicate: same label and center within 5pt, keep deepest
            const deduped = [];
            for (const el of found) {
                const dup = deduped.findIndex(d =>
                    d.label === el.label &&
                    Math.abs(d.cx - el.cx) < 5 &&
                    Math.abs(d.cy - el.cy) < 5);
                if (dup >= 0) {
                    if (el.depth > deduped[dup].depth) deduped[dup] = el;
                } else {
                    deduped.push(el);
                }
            }

            if (deduped.length === 0) {
                console.log("No labeled elements found on screen");
                return;
            }

            const controls = deduped.filter(e => e.width * e.height < 10000);
            const content = deduped.filter(e => e.width * e.height >= 10000);
            const sortFn = (a, b) => a.y - b.y || a.x - b.x;
            controls.sort(sortFn);
            content.sort(sortFn);

            function trunc(s) { return s.length > 60 ? s.slice(0, 57) + "..." : s; }
            function fmt(e) {
                return "  " + trunc(e.label) + "  (" + Math.round(e.width) + "x" + Math.round(e.height) + " at " + Math.round(e.x) + "," + Math.round(e.y) + ")";
            }

            if (controls.length) {
                console.log("== Controls ==");
                controls.forEach(e => console.log(fmt(e)));
                console.log("");
            }
            if (content.length) {
                console.log("== Content ==");
                content.forEach(e => console.log(fmt(e)));
                console.log("");
            }
            console.log(deduped.length + " elements on screen");
        });
    '
}

# Find and tap the back/navigation element
cmd_back() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local udid
    udid=$(get_udid)

    local result
    result=$("$AXE" describe-ui --udid "$udid" | node -e '
        const data = [];
        process.stdin.on("data", c => data.push(c));
        process.stdin.on("end", () => {
            const tree = JSON.parse(data.join(""));
            const candidates = [];

            function walk(nodes) {
                for (const n of nodes) {
                    const label = n.AXLabel || "";
                    const type = n.type || "";
                    const f = n.frame;
                    let score = 0;

                    if (/^back$/i.test(label)) score = 3;
                    else if (/^←$/.test(label)) score = 3;
                    else if (/back/i.test(label)) score = 2;
                    else if (/chevron\.left|arrow\.left|Navigate up/i.test(label)) score = 3;

                    if (score === 0 && type !== "Application" && type !== "StaticText" &&
                        f && f.x < 60 && f.y < 120) {
                        score = 1;
                    }

                    if (score > 0 && f) {
                        candidates.push({ score, label: n.AXLabel, frame: f });
                    }
                    if (n.children) walk(n.children);
                }
            }
            walk(tree);

            if (candidates.length === 0) {
                console.log(JSON.stringify({ error: "No back element found" }));
                return;
            }

            candidates.sort((a, b) => b.score - a.score);
            const best = candidates[0];
            const cx = Math.round(best.frame.x + best.frame.width / 2);
            const cy = Math.round(best.frame.y + best.frame.height / 2);
            console.log(JSON.stringify({ x: cx, y: cy, label: best.label }));
        });
    ')

    # Parse the result JSON
    local x y label error
    error=$(echo "$result" | node -e "const d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>{const j=JSON.parse(d.join(''));console.log(j.error||'')})")
    if [[ -n "$error" ]]; then
        echo "Error: No back element found on screen" >&2
        exit 1
    fi

    x=$(echo "$result" | node -e "const d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>{const j=JSON.parse(d.join(''));console.log(j.x)})")
    y=$(echo "$result" | node -e "const d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>{const j=JSON.parse(d.join(''));console.log(j.y)})")
    label=$(echo "$result" | node -e "const d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>{const j=JSON.parse(d.join(''));console.log(j.label||'')})")

    "$AXE" tap -x "$x" -y "$y" --udid "$udid" >/dev/null
    echo "Tapped back: \"$label\" at ($x, $y)"
}

# Scroll repeatedly until content stabilizes
cmd_scroll() {
    local direction=""
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --udid) OPT_UDID="$2"; shift 2 ;;
            *)      positional+=("$1"); shift ;;
        esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
        echo "Error: scroll requires top|bottom" >&2; exit 1
    fi
    direction="${positional[0]}"

    if [[ "$direction" != "top" && "$direction" != "bottom" ]]; then
        echo "Error: scroll requires top|bottom" >&2; exit 1
    fi

    local udid
    udid=$(get_udid)

    # Get screen dimensions and initial content signature
    local init_json
    init_json=$("$AXE" describe-ui --udid "$udid")

    local init_info
    init_info=$(echo "$init_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));const r=d[0]?.frame||{};let cnt=0,first='';function w(ns){for(const n of ns){if(n.frame&&n.frame.x>=0&&n.frame.x<(r.width||400)&&n.frame.y>=0&&n.frame.y<(r.height||900)){cnt++;if(!first&&n.AXLabel)first=n.AXLabel}if(n.children)w(n.children)}}w(d);console.log(JSON.stringify({w:r.width||400,h:r.height||900,sig:cnt+'|'+first}))")

    local screen_w screen_h prev_sig
    screen_w=$(echo "$init_info" | node -e "const d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>console.log(JSON.parse(d.join('')).w))")
    screen_h=$(echo "$init_info" | node -e "const d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>console.log(JSON.parse(d.join('')).h))")
    prev_sig=$(echo "$init_info" | node -e "const d=[];process.stdin.on('data',c=>d.push(c));process.stdin.on('end',()=>console.log(JSON.parse(d.join('')).sig))")

    # Compute swipe geometry
    local mid_x mid_y swipe_dist start_y end_y
    mid_x=$((screen_w / 2))
    mid_y=$((screen_h / 2))
    swipe_dist=$(echo "$screen_h * 0.3" | bc)

    if [[ "$direction" == "top" ]]; then
        # Finger swipes DOWN so content moves down (reveals top)
        start_y=$(echo "$mid_y - $swipe_dist / 2" | bc)
        end_y=$(echo "$mid_y + $swipe_dist / 2" | bc)
    else
        # Finger swipes UP so content moves up (reveals bottom)
        start_y=$(echo "$mid_y + $swipe_dist / 2" | bc)
        end_y=$(echo "$mid_y - $swipe_dist / 2" | bc)
    fi

    local counter=0
    local max_swipes=10

    while [[ $counter -lt $max_swipes ]]; do
        "$AXE" swipe --start-x "$mid_x" --start-y "$start_y" --end-x "$mid_x" --end-y "$end_y" --udid "$udid" --duration 0.3 >/dev/null
        sleep 0.3

        local new_json new_sig
        new_json=$("$AXE" describe-ui --udid "$udid")
        new_sig=$(echo "$new_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));const r=d[0]?.frame||{};let cnt=0,first='';function w(ns){for(const n of ns){if(n.frame&&n.frame.x>=0&&n.frame.x<(r.width||400)&&n.frame.y>=0&&n.frame.y<(r.height||900)){cnt++;if(!first&&n.AXLabel)first=n.AXLabel}if(n.children)w(n.children)}}w(d);console.log(cnt+'|'+first)")

        counter=$((counter + 1))

        if [[ "$new_sig" == "$prev_sig" ]]; then
            break
        fi
        prev_sig="$new_sig"
    done

    echo "Scrolled to $direction ($counter swipes)"
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
    tap-label)      cmd_tap_label "$@" ;;
    tap-id)         cmd_tap_id "$@" ;;
    type)           cmd_type "$@" ;;
    swipe)          cmd_swipe "$@" ;;
    describe-all)   cmd_describe_all "$@" ;;
    describe-point) cmd_describe_point "$@" ;;
    list)           cmd_list "$@" ;;
    back)           cmd_back "$@" ;;
    scroll)         cmd_scroll "$@" ;;
    *)              echo "Error: Unknown command '$command'" >&2; usage ;;
esac
