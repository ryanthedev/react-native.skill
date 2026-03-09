# Discovery: Phase 2a - Foundation Scripts

## Files Found

Existing scripts (convention reference):
- `skills/ios-sim/scripts/device.sh` -- subcommand routing, `set -euo pipefail`, `usage()`, `cmd_*()` pattern
- `skills/ios-sim/scripts/capture.sh` -- more complex: option parsing with `while/case/shift`, temp dirs, helper functions
- `skills/ios-sim/scripts/ui.sh` -- same patterns
- `skills/ios-sim/scripts/app.sh` -- same patterns
- `skills/rn-deeplink-test/scripts/openurl.sh` -- simpler single-command script
- `skills/rn-clean/scripts/clean.sh` -- flag-based parsing with `for arg in "$@"`
- `skills/rn-clean/scripts/diagnose.sh` -- diagnostic checks

Files to create (none exist yet):
- `skills/_shared/scripts/metro.sh` -- DOES NOT EXIST
- `skills/_shared/scripts/logs.sh` -- DOES NOT EXIST
- `skills/_shared/scripts/cdp-bridge.js` -- DOES NOT EXIST
- `skills/_shared/scripts/` directory -- DOES NOT EXIST

## Current State

The `_shared/scripts/` directory does not exist. All three scripts are new. The codebase has well-established conventions from existing bash scripts:

1. **Shebang and safety**: `#!/usr/bin/env bash` + `set -euo pipefail`
2. **Header comment**: Script name, purpose, commands list on line 2
3. **`usage()` function**: Prints help, exits 1
4. **Command dispatch**: `case "$command" in` at bottom of file
5. **Command functions**: Named `cmd_<subcommand>()`
6. **Option parsing**: `while [[ $# -gt 0 ]]; case "$1" in --flag) ...; shift 2 ;;` pattern
7. **Error output**: `echo "Error: ..." >&2` then `exit 1`
8. **SCRIPT_DIR**: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` (present in multi-file scripts)

No Node.js scripts exist yet in the codebase. `cdp-bridge.js` will be the first.

## Gaps

| Plan Assumption | Reality | Impact |
|-----------------|---------|--------|
| `_shared/scripts/` directory exists | Does not exist | Must create directory |
| Permission glob pattern for shared scripts | Current settings use `Bash(*/skills/*/scripts/*)` which would NOT match `_shared/scripts/*` | Phase 2c will add `Bash(*/skills/_shared/scripts/*)` -- not a blocker for Phase 2a |
| Node 22+ available | Not verified, but plan spec says to check at runtime | cdp-bridge.js handles this internally |
| `plugin.json` at root | Actually at `.claude-plugin/plugin.json` | No impact on Phase 2a |

## Conventions Extracted (for new scripts to follow)

### Bash scripts (metro.sh, logs.sh)
- `#!/usr/bin/env bash` + `set -euo pipefail`
- Header comment: `# scriptname.sh -- purpose`
- `usage()` function printing to stdout, exiting 1
- Subcommand dispatch via `case` at bottom
- `cmd_*()` functions for each subcommand
- Option parsing: `while [[ $# -gt 0 ]]` + `case/shift`
- Errors to stderr with `exit 1`
- No external dependencies beyond standard tools (curl, xcrun, adb)

### Node.js script (cdp-bridge.js) -- new convention
- `#!/usr/bin/env node` shebang
- Version check at startup (Node 22+ for native WebSocket)
- Zero npm dependencies (uses built-in `WebSocket` from Node 22)
- NDJSON output for streaming modes
- JSON output for one-shot modes
- Stderr for errors, stdout for data
- Exit codes: 0 = success, 1 = error

## Prerequisites

- [x] Plan file read and understood
- [x] Existing script conventions documented
- [x] Target directory identified (needs creation)
- [x] No blocking dependencies on other phases
- [x] All three scripts are independent of each other (can be built in any order)

## Recommendation

**BUILD** -- All three scripts need to be created from scratch. The plan spec is detailed enough (command signatures, flags, backends, error handling, port resolution) to proceed directly to pseudocode. Existing bash conventions are clear and should be followed for metro.sh and logs.sh. cdp-bridge.js establishes a new convention for Node scripts.
