# Discovery: Phase 2 - Adaptive temp file for large tree output

## Files Found
- `skills/_shared/scripts/cdp-bridge.js` -- exists, 573 lines, Phase 1 already applied

## Current State
Phase 1 is complete. The modeTree function (line 213-361) already:
- Formats output as JSON or text based on `args.format` (lines 355-357)
- Stores formatted output in a local `const output` variable
- Writes to stdout via `process.stdout.write(output)` at line 358
- Then calls `client.close()` and `process.exit(0)` at lines 359-360

The `formatTreeAsText` function exists at lines 368-408.

The `fs` module is NOT currently imported -- will need `require("fs")` for `writeFileSync`.

## Gaps
1. No size check exists on the output before writing to stdout.
2. No `fs` import at the top of the file.
3. No temp file writing logic exists.

## Prerequisites
- [x] Phase 1 complete (format text implemented, output stored in variable)
- [x] Output is already in a single `const output` variable (line 355-357) -- easy to measure
- [x] `args.format` available to determine file extension
- [x] Node.js `fs` and `Buffer` available (built-in, no new dependencies)

## Recommendation
BUILD -- straightforward addition. The output variable is already isolated on line 355-357, making the size check a clean wrap around the existing stdout write on line 358.
