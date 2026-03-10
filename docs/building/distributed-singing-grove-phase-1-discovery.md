# Discovery: Phase 1 - Add `--format text` to cdp-bridge.js tree mode

## Files Found
- `skills/_shared/scripts/cdp-bridge.js` (512 lines, exists)

## Current State
- `modeTree()` at lines 213-358 evaluates a walker expression via CDP, then writes the result as pretty-printed JSON to stdout (line 355).
- Args object at lines 393-400 has: mode, port, timeout, expression, find, depth. No `format` property.
- Arg parser switch at lines 404-429 handles: --port, --timeout, --find, --depth. No --format case.
- `printUsage()` at lines 436-453 documents current options. No mention of --format.
- The walker expression returns either `{ find, matches }` (when --find used) or a tree node `{ name, props, state, children }`.

## Gaps
- No gaps between plan assumptions and reality. All line numbers match exactly.
- The plan references "~line 358" for placement of `formatTreeAsText` -- confirmed modeTree ends at line 358, modeNetwork starts at line 360. The function should go between them (after line 358, before line 360).

## Prerequisites
- [x] Target file exists
- [x] Line numbers in plan match actual file
- [x] Tree output shape is understood (node object or find-result object)
- [x] No dependencies needed
- [x] JSON default preserves backward compatibility

## Recommendation
**BUILD** -- All plan assumptions hold. Proceed with pseudocode.
