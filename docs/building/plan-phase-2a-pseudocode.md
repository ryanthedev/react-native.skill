# Pseudocode: Phase 2a - Foundation Scripts

## Files to Create

1. `skills/_shared/scripts/metro.sh` (new file, new directory)
2. `skills/_shared/scripts/logs.sh` (new file)
3. `skills/_shared/scripts/cdp-bridge.js` (new file)

---

## Design: Port Resolution

All three scripts share the same port resolution logic. Define it once per script
(no shared sourcing -- each script is self-contained).

Port resolution order: `--port` flag > `RCT_METRO_PORT` env var > default 8081.

---

## Pseudocode

### metro.sh

```
shebang, set safety options

Header comment: metro.sh -- Metro health/status/symbolication
Commands: status, targets, bundle-check, symbolicate

Define resolve_port:
  If PORT variable is already set (from --port flag), use it
  Else if RCT_METRO_PORT env var is set, use it
  Else default to 8081

Define usage:
  Print usage with all four commands and --port option
  Exit 1

Define cmd_status:
  Resolve port
  Curl http://localhost:$PORT/status with short timeout (2s connect, 5s max)
  If curl succeeds and response contains "packager-status:running"
    Print "Metro is running on port $PORT"
    Exit 0
  Else
    Print to stderr "Metro is not running on port $PORT"
    Exit 1

Define cmd_targets:
  Resolve port
  First check status (curl /status with short timeout)
  If Metro not running, print error to stderr, exit 1
  Curl http://localhost:$PORT/json/list
  Print the JSON response to stdout

Define cmd_bundle_check:
  Parse --platform flag (default: ios)
  Resolve port
  First check status; if not running, error and exit
  Curl http://localhost:$PORT/index.bundle?platform=$PLATFORM&dev=true&minify=false
    Use --write-out to capture HTTP status code
    Use --output to capture body to temp file
    Use connect timeout of 5s, max time of 30s (bundles can be slow)
  If HTTP status is 200
    Print "Bundle builds successfully (platform: $PLATFORM)"
    Exit 0
  Else
    Print to stderr "Bundle build failed (HTTP $STATUS, platform: $PLATFORM)"
    Print error body from temp file to stderr
    Exit 1
  Clean up temp file

Define cmd_symbolicate:
  Resolve port
  First check status; if not running, error and exit
  Read JSON stack trace from stdin
  If stdin is empty, print error and exit
  POST the JSON to http://localhost:$PORT/symbolicate
    Content-Type: application/json
  Print response to stdout

Main:
  If no arguments, print usage
  Parse global --port flag from anywhere in args (extract it before subcommand dispatch)
  Dispatch first non-flag argument as command:
    status -> cmd_status
    targets -> cmd_targets
    bundle-check -> cmd_bundle_check
    symbolicate -> cmd_symbolicate
    * -> error, usage
```

**Design notes for metro.sh:**
- Port parsing: scan all args first, extract `--port` into a global, then dispatch. This matches the plan spec where `--port` appears after the subcommand.
- Status check reuse: `cmd_targets`, `cmd_bundle_check`, and `cmd_symbolicate` all verify Metro is running first. Extract a helper `require_metro_running` that calls the status endpoint and exits 1 with message if not running.
- curl timeouts: Use `--connect-timeout 2 --max-time 5` for status checks. Use longer `--max-time 30` for bundle-check since bundling can be slow.
- Temp file for bundle-check: Use `mktemp` and trap for cleanup.

---

### logs.sh

```
shebang, set safety options

Header comment: logs.sh -- iOS + Android JS console log capture
Commands: ios, android

Define usage:
  Print usage with both commands, --timeout, --json, --native flags
  Exit 1

Define cmd_ios:
  Parse flags: --timeout (default: none/unlimited), --json, --native

  Build log stream predicate:
    If --native flag:
      predicate = 'subsystem == "com.facebook.react.log"'
    Else:
      predicate = 'subsystem == "com.facebook.react.log" AND category == "javascript"'

  Build command array:
    xcrun simctl spawn booted log stream
      --predicate "$predicate"
      --style ndjson   (if --json flag, use ndjson style)

  If --timeout is set:
    Run command with timeout:
      Use "timeout" command if available (GNU coreutils)
      Else use bash background + sleep + kill pattern:
        Start log stream in background
        Sleep for timeout seconds
        Kill background process
        Wait for it
  Else:
    Run command directly (streaming until interrupted)

Define cmd_android:
  Parse flags: --timeout (default: none/unlimited), --json

  Build command:
    adb logcat -v brief '*:S' ReactNativeJS:V
    (If --json: adb logcat -v json '*:S' ReactNativeJS:V)

  If --timeout is set:
    Same timeout pattern as iOS
  Else:
    Run directly

Main:
  If no arguments, print usage
  Dispatch first argument as command:
    ios -> cmd_ios (pass remaining args)
    android -> cmd_android (pass remaining args)
    * -> error, usage
```

**Design notes for logs.sh:**
- Timeout implementation: macOS does not have GNU `timeout` by default. Use a portable pattern: run in background, sleep, kill. Wrap in a helper function `run_with_timeout`.
- No port resolution needed: logs.sh works at the OS level (simctl log stream, adb logcat), not through Metro.
- `--json` for iOS: `xcrun simctl spawn booted log stream` supports `--style ndjson` which gives JSON output. For non-JSON mode, use `--style compact` for readable output.
- `--json` for Android: `adb logcat -v json` gives JSON output per line. Default uses `-v brief`.
- The `--native` flag only applies to iOS (broadens the subsystem predicate). Not applicable to Android since `ReactNativeJS:V` already filters appropriately.
- Signal handling: trap SIGINT/SIGTERM to clean up background processes.

---

### cdp-bridge.js

```
shebang: #!/usr/bin/env node

Check Node version:
  Parse major version from process.version
  If < 22, print error to stderr and exit 1

Define resolvePort:
  Check args for --port, then RCT_METRO_PORT env, then default 8081
  Return port number

Define discoverWebSocketUrl:
  Fetch http://localhost:$PORT/json/list
  Parse JSON response (array of targets)
  If no targets found, throw error
  Return webSocketDebuggerUrl from first target

Define connectCDP:
  Given wsUrl, create WebSocket connection (built-in Node 22 WebSocket)
  Return a wrapper with:
    send(method, params) -> Promise that resolves with result
    on(event, callback) -> register event listener
    close() -> close connection

  Internal:
    Maintain message ID counter
    Maintain map of pending requests (id -> {resolve, reject})
    On message received:
      Parse JSON
      If has "id" field -> resolve corresponding pending request
      If has "method" field -> emit to event listeners
    On error -> reject all pending, print to stderr
    On close -> clean up

Define modeConsole:
  Parse --timeout flag
  Connect via CDP
  Enable Runtime domain (send Runtime.enable)
  Listen for Runtime.consoleAPICalled events
  On each event:
    Format as NDJSON line: { type, args (serialized), timestamp }
    Write to stdout
  If timeout: set timer to close connection and exit after N seconds
  On connection close: exit 0

Define modeEval:
  Get expression from args
  If no expression, print error, exit 1
  Connect via CDP
  Send Runtime.evaluate with expression, awaitPromise: true, returnByValue: true
  Print result as JSON to stdout
  Close connection, exit 0
  If exception in result:
    Print exception details to stderr
    Exit 1

Define modeTree:
  Parse --find flag (optional component name filter)
  Connect via CDP

  Evaluate JS expression to walk the fiber tree:
    The expression checks for __REACT_DEVTOOLS_GLOBAL_HOOK__
    If hook not found:
      Return error indicator
    Walk the fiber tree starting from hook.getFiberRoots()
    For each fiber:
      Collect: component name (type.name or type.displayName), props, state
      Recurse into child and sibling fibers
    If --find specified:
      Filter tree to matching component name
    Return JSON tree structure

  Send via Runtime.evaluate with returnByValue: true

  If hook not found in result:
    Print to stderr "React DevTools hook not found -- ensure app is running in dev mode"
    Exit 1

  Print result JSON to stdout
  Close, exit 0

Define modeNetwork:
  Parse --timeout flag
  Connect via CDP
  Enable Network domain (send Network.enable)
  Listen for Network.requestWillBeSent events
  On each event:
    Format as NDJSON line: { url, method, headers, timestamp }
    Write to stdout
  If timeout: set timer to close and exit after N seconds
  On connection close: exit 0

Define parseArgs:
  Parse mode (first positional arg): console, eval, tree, network
  Parse global flags: --port, --timeout, --find
  Parse eval expression (second positional arg for eval mode)
  Return structured args object

Main:
  Parse args
  Resolve port

  Try:
    Discover WebSocket URL from Metro
  Catch (connection refused / no targets):
    Print to stderr "Cannot connect to Metro on port $PORT"
    Suggest "npx react-native start"
    Exit 1

  Dispatch based on mode:
    console -> modeConsole
    eval -> modeEval
    tree -> modeTree
    network -> modeNetwork
    no mode / unknown -> print usage, exit 1

  Global error handler:
    Catch unhandled rejections
    Print to stderr
    Exit 1
```

**Design notes for cdp-bridge.js:**

- **Deep module principle applied**: `connectCDP` hides all WebSocket protocol complexity (message ID tracking, request/response correlation, event dispatch) behind a simple `send(method, params) -> Promise` + `on(event, callback)` interface. Callers never see raw WebSocket frames.

- **Fiber tree walking expression**: The `modeTree` JS expression sent via `Runtime.evaluate` must be self-contained (runs in the app's JS context, not Node). It walks React's internal fiber tree. This is the most fragile part -- fiber internals change between React versions. Keep the walker expression focused on stable properties: `type.name`, `type.displayName`, `memoizedProps`, `memoizedState`, `child`, `sibling`.

- **Streaming modes (console, network)**: Use NDJSON (one JSON object per line) so callers can process line-by-line. Timeout triggers graceful close (not abrupt kill).

- **Error model**: Connection errors (Metro not running) produce a clear message and exit 1. CDP protocol errors (method not found, evaluation exception) produce structured error info on stderr and exit 1. Timeout is NOT an error (exit 0).

- **No npm dependencies**: Node 22+ provides `WebSocket` globally (via `globalThis.WebSocket` or `require('ws')` is NOT used). Also uses built-in `fetch` for the /json/list discovery endpoint (available since Node 18).

- **Process lifecycle**: For streaming modes, handle SIGINT gracefully (close WebSocket, flush output, exit 0). For one-shot modes (eval, tree), connect-send-receive-close-exit.

---

## Design: cdp-bridge.js connectCDP (Deep Module Analysis)

### Approaches Considered

1. **Raw WebSocket** -- Each mode function manages its own WebSocket, ID counter, message parsing. Simple but duplicative.
2. **CDP client wrapper** -- A `connectCDP(wsUrl)` function returns a high-level client with `send()` and `on()`. All protocol details hidden.
3. **Event emitter pattern** -- Full EventEmitter-based client with typed events, buffering, reconnection.

### Comparison

| Criterion | A: Raw | B: Wrapper | C: EventEmitter |
|-----------|--------|------------|-----------------|
| Interface simplicity | Low (each mode reimplements) | High (2 methods) | Medium (many methods) |
| Information hiding | None | High (IDs, correlation, parsing) | High |
| Code duplication | High | None | None |
| Complexity budget | Low | Low | Over-engineered for 4 modes |

### Choice: B (CDP client wrapper)

Rationale: Two methods (`send`, `on`) cover all four modes. ID tracking, message correlation, and JSON parsing are hidden. Approach C adds reconnection and buffering we do not need -- scripts are short-lived (connect, do one thing, exit). Approach A forces each mode to reimplement protocol boilerplate.

### Depth Check
- Interface methods: 3 (send, on, close)
- Hidden details: message ID generation, request/response correlation, JSON parse/stringify, WebSocket lifecycle
- Common case complexity: simple -- `await client.send("Runtime.evaluate", {expression})` returns result

---

## PRE-GATE Status

- [x] Discovery complete
- [x] Pseudocode complete for all 3 scripts
- [x] Design reviewed (cdp-bridge.js connectCDP module depth evaluated)
- [x] Conventions documented from existing codebase
- [x] Ready for implementation
