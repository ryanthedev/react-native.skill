# Discovery: Phase 3 - idb detect-and-warn + simctl fallback

## Files Found
- `skills/ios-sim/scripts/capture.sh` — exists, 225 lines
- `skills/ios-sim/scripts/ui.sh` — exists, 243 lines
- `skills/ios-sim/SKILL.md` — exists, 166 lines
- `skills/rn-layout-check/SKILL.md` — exists, 136 lines
- `skills/rn-a11y-audit/SKILL.md` — exists, 150 lines

## Current State

### capture.sh
- `$IDB` is used exactly once: line 91 in `cmd_view()` to call `idb ui describe-all` for screen dimensions (width/height)
- Screenshot capture itself uses `xcrun simctl io` (line 101) — does NOT require idb
- Lines 103-109: if dimensions are known, `sips -z` resizes to point dimensions + compresses; else compress-only fallback already exists
- The idb call at line 91 will crash (`set -e` + exit 127) if idb is not installed
- `sips` is available at `/usr/bin/sips` on macOS (ships with Xcode command line tools)

### ui.sh
- `$IDB` is used on 5 lines: tap (116), type (141), swipe (181), describe-all (196), describe-point (222)
- Every command in ui.sh requires idb — there is no simctl equivalent for UI interaction
- No existing idb guard anywhere in the script

### ios-sim/SKILL.md
- Prerequisites section (line 24) mentions "Facebook IDB installed for UI interactions" but does not distinguish which scripts need it
- No mention that `capture.sh view` can work without idb

### rn-layout-check/SKILL.md
- Step 1 subagent runs both `capture.sh view` (line 29) and `ui.sh describe-all` (line 31)
- No fallback if ui.sh fails — the subagent would get an error and stop
- The layout analysis would still be partially useful with screenshot-only (no accessibility tree)

### rn-a11y-audit/SKILL.md
- Step 1 subagent runs `ui.sh describe-all` (line 39) as its primary data source
- Without idb, this skill cannot function at all — accessibility auditing requires the accessibility tree
- No guard or error message currently exists

## Gaps

1. **Plan says "wrap idb call with `command -v "$IDB"` guard" at line 91** — Confirmed: line 91 is the exact idb call in `cmd_view()`. Plan matches reality.
2. **Plan says "sips fallback after screenshot capture"** — The sips fallback needs to go between the screenshot capture (line 101) and the resize conditional (line 103). Specifically, the fallback extracts dimensions from the raw PNG when idb was unavailable, so dimensions are populated before the existing if/else.
3. **Plan says "existing if/else at lines 103-109"** — Confirmed: lines 103-109 handle resize-if-dimensions-known vs compress-only. The sips dimension fallback should make the resize path reachable without idb.
4. **Plan says "Add `command -v "$IDB"` check after line 10"** in ui.sh — Line 10 is `IDB="${IOS_SIMULATOR_MCP_IDB_PATH:-idb}"`. The guard should go on line 11-15 (new lines). Confirmed.
5. **rn-layout-check fallback** — Plan says "proceed with screenshot-only analysis". This means modifying the subagent prompt to instruct it to try ui.sh but handle failure gracefully.
6. **rn-a11y-audit guard** — Plan says "if idb not installed, skill cannot run". This is a pre-check in the SKILL.md workflow, not a code change.

## Prerequisites
- [x] All 5 files exist
- [x] `sips` available on macOS at `/usr/bin/sips`
- [x] capture.sh already has compress-only fallback (lines 106-108)
- [x] Plan line numbers match current file state
- [x] No conflicting changes from Phase 1/2 (those touched cdp-bridge.js only)

## Recommendation
BUILD — All sub-phases (3a, 3b, 3c) are straightforward. Plan matches reality with no gaps.
