# Pseudocode: Phase 3 - idb detect-and-warn + simctl fallback

## Files to Create/Modify
- `skills/ios-sim/scripts/capture.sh` (modify)
- `skills/ios-sim/scripts/ui.sh` (modify)
- `skills/ios-sim/SKILL.md` (modify)
- `skills/rn-layout-check/SKILL.md` (modify)
- `skills/rn-a11y-audit/SKILL.md` (modify)

## Pseudocode

### capture.sh — Phase 3a

**Change location:** `cmd_view()`, lines 89-101

Current flow:
```
call idb to get accessibility tree JSON         # line 91
extract width and height from JSON               # lines 94-95
capture PNG screenshot via simctl                 # line 101
if dimensions known, resize + compress           # lines 103-105
else compress-only                               # lines 107-108
```

New flow:
```
initialize width and height as empty

if idb command is available on PATH
    call idb to get accessibility tree JSON
    extract width from JSON (or empty on failure)
    extract height from JSON (or empty on failure)
end if

capture PNG screenshot via simctl

if dimensions still empty (idb unavailable or failed)
    use sips to read pixelWidth from raw PNG
    use sips to read pixelHeight from raw PNG
    if both pixel dimensions obtained
        divide each by 3 to get point dimensions (Retina heuristic)
    end if
end if

# existing logic unchanged from here:
if dimensions known, resize + compress
else compress-only
```

**Implementation notes:**
- `command -v "$IDB"` is the POSIX-portable way to check if a command exists. Use `>/dev/null 2>&1` to suppress output.
- `sips -g pixelWidth "$raw_png"` outputs a line like `  pixelWidth: 1170`. Parse with `awk '/pixelWidth/{print $2}'`.
- `sips -g pixelHeight "$raw_png"` similarly outputs `  pixelHeight: 2532`.
- Division by 3: use `$(( pixel_w / 3 ))` for integer arithmetic. This is correct for all current iOS Simulator devices (all 3x Retina).
- The sips fallback block goes AFTER the screenshot capture (line 101) because it reads the raw PNG file.
- The idb block moves to BEFORE the screenshot capture, same as current position.

### ui.sh — Phase 3b

**Change location:** After line 10 (IDB variable assignment), before line 12 (validate_udid function)

Current:
```
IDB="${IOS_SIMULATOR_MCP_IDB_PATH:-idb}"      # line 10
                                                # line 11 (blank)
# Validate UDID format                         # line 12
```

New (insert after line 10):
```
# Guard: all ui.sh commands require idb
if idb command is NOT available on PATH
    print to stderr: "Error: idb is not installed. All ui.sh commands require Facebook IDB."
    print to stderr: ""
    print to stderr: "Install with:  pip3 install fb-idb"
    print to stderr: "Or set IOS_SIMULATOR_MCP_IDB_PATH to your idb binary location."
    exit 1
end if
```

**Implementation notes:**
- Use `command -v "$IDB" >/dev/null 2>&1` for the check.
- This is a top-level guard, not inside any function — it runs on every ui.sh invocation.
- Exit 1 to indicate error. This is the correct behavior: no ui.sh command can succeed without idb, so failing early with clear instructions is better than a cryptic "command not found" from bash.

### ios-sim/SKILL.md — Phase 3c

**Change location:** Prerequisites section, line 24

Current:
```
- Facebook IDB installed for UI interactions (`idb --version` to check)
```

New:
```
- Facebook IDB (`pip3 install fb-idb`) — required for `ui.sh` commands (tap, type, swipe, describe-all, describe-point). `capture.sh view` works without idb using a sips fallback for dimensions.
```

**Implementation notes:**
- This clarifies that idb is NOT required for screenshot/record/view — only for UI interaction.
- Keeps the install instruction inline for quick reference.

### rn-layout-check/SKILL.md — Phase 3c

**Change location:** Step 1 subagent prompt, after the `ui.sh describe-all` instruction (around line 31-33)

Current subagent step 2:
```
2. Run: ${CLAUDE_SKILL_DIR}/../ios-sim/scripts/ui.sh describe-all
   Parse the full accessibility tree JSON.
```

New subagent step 2:
```
2. Run: ${CLAUDE_SKILL_DIR}/../ios-sim/scripts/ui.sh describe-all
   Parse the full accessibility tree JSON.
   If this fails (e.g., "idb is not installed" error), skip the accessibility tree
   and proceed with screenshot-only analysis. Note in your report that element
   positions are estimated from visual inspection, not the accessibility tree.
```

**Implementation notes:**
- This is a prompt change only — no code change.
- The subagent (haiku) will see the error output from ui.sh and follow the fallback instruction.
- The layout check is still useful without the accessibility tree: the screenshot provides visual layout information, and the doc-matching step (Step 2) still works.

### rn-a11y-audit/SKILL.md — Phase 3c

**Change location:** Before Step 1 (before line 27), add a guard step

New step (insert before Step 1):
```
### Pre-check

Before dispatching the subagent, verify idb is installed:

Run: command -v "${IOS_SIMULATOR_MCP_IDB_PATH:-idb}" >/dev/null 2>&1

If this fails, stop and tell the user:
"rn-a11y-audit requires Facebook IDB to read the accessibility tree.
Install with: pip3 install fb-idb
Then re-run this skill."

Do not dispatch the subagent if idb is missing — it will fail immediately.
```

**Implementation notes:**
- This is a SKILL.md workflow instruction, not a code change. The main agent checks for idb before dispatching the subagent.
- Unlike rn-layout-check, there is no fallback here: an accessibility audit without the accessibility tree is meaningless.
- The check uses the same env var pattern as ui.sh for consistency.

## Design Notes

**Design decision: sips fallback placement.** The sips dimension extraction is placed AFTER the screenshot capture, not before, because it reads the captured PNG file. The idb call stays before the screenshot (same position as current code) because it queries the live simulator, not a file.

**Design decision: guard location in ui.sh.** The guard is at the top level (module entry point), not inside each command function. This is the deep-module approach: a single check at the boundary eliminates the need for 5 separate guards in each command function. Every caller gets the same clear error.

**Design decision: rn-layout-check graceful degradation vs rn-a11y-audit hard stop.** Layout checking can still provide value from a screenshot alone (visual inspection of spacing, overflow, alignment). Accessibility auditing cannot — the accessibility tree IS the data. This justifies the different fallback strategies.

**Design decision: `/3` Retina heuristic.** All current iOS Simulator devices render at 3x. If a 2x device appears in the future, the JPEG will be slightly larger than optimal but still functional. This is acceptable because the compress-only fallback (no resize at all) already exists as the worst case.

## PRE-GATE Status
- [x] Discovery complete
- [x] Pseudocode complete
- [x] Design reviewed — information hiding (single guard point), graceful degradation decisions justified
- [x] Ready for implementation
