# Discovery: Phase 1 - Fix 6 PLAN.md Issues

## File Found
- `/Users/r/repos/react-native.skill/PLAN.md` (243 lines)

## Current State
PLAN.md is a complete Phase 2 plan document covering new scripts (metro.sh, logs.sh, cdp-bridge.js), new skills (rn-debug, rn-coding), and enhancements to rn-diagnose. None of the Phase 2 items have been built yet (_shared/scripts/ and rn-coding/ do not exist).

## Fix-by-Fix Analysis

### Fix 1: Port 8081 hardcoded
- **Locations found:** Lines 61-64 (metro.sh command table has `localhost:8081` in 4 curl examples), line 84 (`GET http://localhost:8081/json/list`), line 238 (error handling: "Metro is not running on port 8081")
- **Gap:** Plan assumes port 8081 everywhere. No mention of `--port` flag or `RCT_METRO_PORT` env var.
- **Action needed:** Add `--port` flag to metro.sh and cdp-bridge.js command descriptions. Note `RCT_METRO_PORT` env var as fallback. Update error message.

### Fix 2: DevTools hook caveat
- **Location found:** Line 80 (`cdp-bridge.js tree` mode references `__REACT_DEVTOOLS_GLOBAL_HOOK__`)
- **Gap:** No mention that this hook requires dev mode to be present. No fallback behavior documented.
- **Action needed:** Add note to the tree mode row or below the table about dev mode requirement and fallback error message.

### Fix 3: Node 22+ guard
- **Location found:** Line 74 (header says "Node 22+, zero npm deps")
- **Gap:** No mention of a runtime version check at startup.
- **Action needed:** Add note that cdp-bridge.js should check `process.version` on startup and exit with clear message if Node < 22.

### Fix 4: Script testing strategy
- **Location found:** Build Order section ends at line 216 with deferred items. No smoke test section exists.
- **Gap:** No testing guidance anywhere in the plan.
- **Action needed:** Add a "Smoke Tests" section after Build Order (after line 216, before the `---` on line 218) with manual verification steps for each script.

### Fix 5: rn-coding path resolution
- **Location found:** Line 185 (`rn-coding   -> refs/react-native-docs/docs/     (grep, same as rn-docs)`)
- **Gap:** No note about how this path resolves. The rn-docs skill presumably resolves this relative to the plugin install directory.
- **Action needed:** Add parenthetical note about path resolving relative to plugin install dir.

### Fix 6: Doc count discrepancy
- **Location found:** Line 7 says "234 official RN doc files"
- **Reality check:** Actual counts in `refs/react-native-docs/docs/`:
  - `.md` files: **234** (matches current text exactly)
  - `.mdx` files: 5
  - `.jsx` files: 2
  - Total all files: 241
- **Gap:** The fix instructions say to change to "218" but 234 is actually correct for `.md` files. The number 218 does not match any count I can derive.
- **Recommendation:** KEEP "234" unless the fix requester has a different counting methodology. Flag this back to the user.

## Prerequisites
- [x] PLAN.md exists and is readable
- [x] File structure is understood
- [x] All 6 fix locations identified
- [ ] Fix 6 count discrepancy needs user clarification

## Recommendation
BUILD (with caveat on Fix 6)

Fixes 1-5 are clear and actionable. Fix 6 ("change 234 to 218") appears incorrect -- the actual `.md` file count is 234, matching the current text. I will apply the requested change to 218 as instructed, but flag this discrepancy for the user to review.
