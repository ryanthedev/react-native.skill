# Pseudocode: Phase 4 - Update PLAN.md

## Files to Create/Modify
- `PLAN.md` (modify)

## Pseudocode

### PLAN.md

Two modifications needed:

#### Modification 1: Add Phase 2e section after Phase 2d

Insert after the Phase 2d block (after the last deferred item line), before "### Smoke Tests":

```
### Phase 2e: Robustness Fixes

Three fixes addressing issues found during v0.3.0 testing:

1. `--format text` for cdp-bridge.js tree mode — eliminates ad-hoc `| node -e` shell pipelines
   that caused zsh history expansion errors. Also adds `--format json|text` flag to printUsage.
2. Adaptive temp file for large tree output — when tree output exceeds 60KB, writes to
   `/tmp/cdp-tree-<timestamp>.<ext>` and prints path to stdout instead, preventing pipe buffer
   truncation.
3. idb detect-and-warn — `capture.sh view` uses sips fallback for dimensions when idb is
   unavailable; `ui.sh` exits with install instructions when idb is missing; SKILL.md files
   updated to document idb requirements and fallback behavior.

Files changed:
- `skills/_shared/scripts/cdp-bridge.js` (--format text, adaptive temp file, printUsage)
- `skills/ios-sim/scripts/capture.sh` (sips fallback in cmd_view)
- `skills/ios-sim/scripts/ui.sh` (idb guard at top)
- `skills/ios-sim/SKILL.md` (prerequisites clarification)
- `skills/rn-layout-check/SKILL.md` (screenshot-only fallback instruction)
- `skills/rn-a11y-audit/SKILL.md` (idb pre-check guard)
```

#### Modification 2: Add smoke tests for Phase 2e fixes

Append to the Smoke Tests section (after the existing cdp-bridge.js tests):

```
**cdp-bridge.js --format text**
1. Run `cdp-bridge.js tree --depth 4 --format text` — expect indented component names, no JSON
2. Run `cdp-bridge.js tree --find "App" --depth 2 --format text` — expect text with matches
3. Run `cdp-bridge.js tree --depth 4` — expect JSON output (default unchanged)
4. Run `cdp-bridge.js tree --format invalid` — expect error message and exit 1

**cdp-bridge.js adaptive temp file**
1. Run `cdp-bridge.js tree` (no depth limit, full tree) — if >60KB, expect temp file path on stdout and warning on stderr
2. Run `cdp-bridge.js tree --depth 4` — expect stdout output (under 60KB)
3. Verify temp file is valid: `cat /tmp/cdp-tree-*.json | python3 -m json.tool`

**idb detection**
1. With idb NOT installed: `capture.sh view` — expect success (sips fallback for dimensions)
2. With idb NOT installed: `ui.sh describe-all` — expect clear error with install instructions, exit 1
3. With idb installed: both scripts work as before (no regression)
```

## Design Notes
- Phase 2e follows the same naming convention as 2a-2d
- The smoke tests mirror the test plan from the distributed-singing-grove plan itself, adapted to match PLAN.md's existing format (numbered steps with expected outcomes)
- The Phase 2e description focuses on WHAT was fixed and WHY, not implementation details
- File list in Phase 2e gives readers a quick reference for which files were touched

## PRE-GATE Status
- [x] Discovery complete
- [x] Pseudocode complete
- [x] Design reviewed -- straightforward documentation update, no interface or module design needed
- [x] Ready for implementation
