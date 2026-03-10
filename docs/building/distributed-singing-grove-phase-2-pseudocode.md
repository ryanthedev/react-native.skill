# Pseudocode: Phase 2 - Adaptive temp file for large tree output

## Files to Create/Modify
- `skills/_shared/scripts/cdp-bridge.js` (modify)

## Pseudocode

### cdp-bridge.js

#### Change 1: Add fs import near top of file (after "use strict", before node version check)

```
Import the fs module from Node built-ins
```

#### Change 2: New function `emitTreeOutput(output, format)` -- place after formatTreeAsText, before modeNetwork

```
Define emitTreeOutput(output, format):
    Set SIZE_LIMIT to 60 * 1024  (60KB in bytes)
    Measure byteSize as the UTF-8 byte length of output

    If byteSize is greater than SIZE_LIMIT:
        Determine extension: ".json" if format is "json", otherwise ".txt"
        Build temp file path: "/tmp/cdp-tree-" + current timestamp in ms + extension
        Write output to temp file path (synchronous, utf8)
        Compute sizeKB as byteSize / 1024, rounded to nearest integer
        Print to stdout: the temp file path (with newline)
        Print to stderr: "Tree output is <sizeKB>KB -- written to <path>"
        Print to stderr: "Use --depth or --find to reduce output size"
    Otherwise:
        Write output to stdout as before
```

Note: `writeFileSync` is appropriate here because the process is about to exit immediately after this call. There is no concurrency concern.

#### Change 3: Replace direct stdout write in modeTree with call to emitTreeOutput

In modeTree, replace lines 355-358 (the format + stdout.write):

```
Keep the existing format conditional that builds the output string (line 355-357)
Replace process.stdout.write(output) with emitTreeOutput(output, args.format)
```

The rest of modeTree (client.close, process.exit) remains unchanged.

## Design Notes

**Why a separate function instead of inline:**
- modeTree is already 150 lines; adding branching logic inline increases its complexity
- emitTreeOutput has a single responsibility: "decide how to deliver output based on size"
- The threshold, temp path naming, and stderr messaging are implementation details hidden from modeTree
- If other modes ever need adaptive output, the function is reusable

**Why writeFileSync, not writeFile:**
- The process calls `process.exit(0)` immediately after emitting output
- Async write could be interrupted by process.exit
- No concurrency benefit since this is a CLI tool at end of execution

**Why 60KB threshold (not 64KB):**
- Plan specifies 60KB. The actual pipe buffer limit is 64KB on macOS, but 60KB provides margin for the caller's own stdout buffering and avoids cutting it close.

**Temp file not cleaned up:**
- Intentional per plan. The caller (subagent) needs to read the file after cdp-bridge.js exits. OS cleans /tmp periodically.

**Backward compatibility:**
- Output <= 60KB: stdout behavior is identical to before
- Output > 60KB: stdout now contains a file path instead of the raw tree. Callers that pipe stdout to `python3 -m json.tool` will see a path instead of JSON -- this is the intended behavior change (they should read the file).

## PRE-GATE Status
- [x] Discovery complete
- [x] Pseudocode complete
- [x] Design reviewed
- [x] Ready for implementation
