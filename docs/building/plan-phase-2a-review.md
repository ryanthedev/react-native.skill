# Review: Phase 2a - Foundation Scripts

## Verdict: PASS

## Spec Match

- [x] All pseudocode sections implemented
- [x] No unplanned additions
- [x] Test coverage verified (plan specifies manual smoke tests only; no automated tests required)

### metro.sh

| Pseudocode Section | Implemented | Notes |
|---|---|---|
| Shebang + safety options | Yes, line 1-2 | `#!/usr/bin/env bash` + `set -euo pipefail` |
| Header comment | Yes, line 4-5 | Matches spec |
| `resolve_port` | Yes, lines 8-12 | Correct priority: `$PORT` (from --port) > `$RCT_METRO_PORT` > 8081 |
| `usage` | Yes, lines 14-26 | All four commands + --port option documented |
| `require_metro_running` helper | Yes, lines 29-40 | Extracted as recommended in pseudocode design notes |
| `cmd_status` | Yes, lines 42-53 | Checks `packager-status:running`, correct exit codes, correct timeouts (2s connect, 5s max) |
| `cmd_targets` | Yes, lines 55-58 | Calls `require_metro_running`, then curls `/json/list` |
| `cmd_bundle_check` | Yes, lines 60-90 | Parses `--platform`, uses `mktemp` + `trap` cleanup, correct timeouts (5s connect, 30s max), prints error body on failure |
| `cmd_symbolicate` | Yes, lines 92-112 | Checks stdin is not terminal (`-t 0`), validates non-empty input, POSTs with Content-Type |
| Main: global `--port` extraction | Yes, lines 116-131 | Scans all args, extracts `--port` before dispatch |
| Main: command dispatch | Yes, lines 133-143 | All four commands + error/usage fallback |

### logs.sh

| Pseudocode Section | Implemented | Notes |
|---|---|---|
| Shebang + safety options | Yes, line 1-2 | |
| Header comment | Yes, line 4-5 | |
| `usage` | Yes, lines 7-19 | All flags documented |
| `run_with_timeout` helper | Yes, lines 24-41 | Background process + sleep + kill pattern per design notes; trap for INT/TERM cleanup |
| `cmd_ios` | Yes, lines 43-77 | Parses `--timeout`, `--json`, `--native`; correct predicates; `--style ndjson`/`compact`; uses `exec` for no-timeout case |
| `cmd_android` | Yes, lines 79-104 | Parses `--timeout`, `--json`; `-v brief`/`json`; correct logcat filter `'*:S' ReactNativeJS:V` |
| Signal handling | Yes, lines 32, 74, 101 | Traps INT/TERM in both timeout and non-timeout paths |
| Main dispatch | Yes, lines 108-119 | `ios`/`android` + error fallback |
| No port resolution needed | Correct | Not present (logs.sh uses OS-level tools) |
| `--native` iOS only | Correct | Only parsed in `cmd_ios`, not in `cmd_android` |

### cdp-bridge.js

| Pseudocode Section | Implemented | Notes |
|---|---|---|
| Shebang | Yes, line 1 | `#!/usr/bin/env node` |
| Node version check | Yes, lines 10-17 | Parses major version, exits with specified message if < 22 |
| `resolvePort` | Yes, lines 21-29 | Correct priority: args.port > env > 8081 |
| `discoverWebSocketUrl` | Yes, lines 33-47 | Fetches `/json/list`, validates array, extracts `webSocketDebuggerUrl` |
| `connectCDP` (deep module) | Yes, lines 53-134 | `send(method, params) -> Promise`, `on(event, callback)`, `close()`; hides ID tracking, message correlation, JSON parsing |
| `modeConsole` | Yes, lines 139-169 | Enables `Runtime`, listens for `consoleAPICalled`, NDJSON output, timeout support, SIGINT/SIGTERM handling |
| `modeEval` | Yes, lines 174-199 | Validates expression, `awaitPromise: true`, `returnByValue: true`, exception handling to stderr |
| `modeTree` | Yes, lines 204-294 | Self-contained walker expression, `__REACT_DEVTOOLS_GLOBAL_HOOK__` check, `--find` filter, stable fiber properties, `__noHook` sentinel for error |
| `modeNetwork` | Yes, lines 299-323 | Enables `Network`, listens for `requestWillBeSent`, NDJSON output with url/method/headers/timestamp |
| `parseArgs` | Yes, lines 327-366 | Handles `--port`, `--timeout`, `--find`, positional mode + expression |
| `printUsage` | Yes, lines 368-384 | Documents all modes and options |
| Main: discovery + dispatch | Yes, lines 388-431 | Discovery error produces "Cannot connect to Metro" + suggestion; WebSocket error handled separately; dispatch to all 4 modes + unknown fallback |
| Global error handler | Yes, lines 434-442 | `unhandledRejection` handler + `main().catch()` |
| Error model (timeout = exit 0) | Yes | Timeout triggers `client.close()`, streaming modes exit 0 on close |
| No npm dependencies | Yes | Uses built-in `WebSocket` and `fetch` |

## Dead Code

None found. Specifically checked:
- No unused imports (no `require`/`import` statements -- uses globals)
- No unreachable code after early returns
- No debug `console.log` statements (the one grep match is usage text)
- No commented-out code blocks
- No TODO/FIXME/HACK/XXX markers

## Correctness Verification

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirements | PASS | All plan requirements (4 metro.sh commands, 2 logs.sh commands, 4 cdp-bridge.js modes) implemented with specified flags, port resolution, error messages, and exit codes |
| Concurrency | N/A | No shared mutable state across threads; bash scripts use background processes with proper signal cleanup; cdp-bridge.js is single-threaded event-loop |
| Error Handling | PASS | See details below |
| Resource Mgmt | PASS | See details below |
| Boundaries | PASS | See details below |
| Security | N/A | Scripts operate on localhost only; no user-facing input beyond CLI args; no SQL/shell injection vectors (curl URLs use variable substitution in controlled format) |

### Error Handling Details

**metro.sh:**
- Connection failures: curl with `--connect-timeout` and `--max-time` prevents hangs; stderr messages on failure
- Empty stdin for symbolicate: checked with `-t 0` (is terminal?) and `-z` (empty string)
- Unknown commands/options: caught by `case` fallbacks

**logs.sh:**
- Background process cleanup: `trap` on INT/TERM kills background process
- Unknown options: caught by `case` fallbacks

**cdp-bridge.js:**
- Node version check: exits with clear message before any WebSocket usage
- Metro not running: `discoverWebSocketUrl` catch produces "Cannot connect" message
- WebSocket connection failure: separate try/catch with message
- CDP protocol errors: `msg.error` in response rejects the pending promise
- Evaluation exceptions: `result.exceptionDetails` checked in both eval and tree modes
- No targets found: explicit check in `discoverWebSocketUrl`
- Missing `webSocketDebuggerUrl`: explicit check
- JSON parse errors in WebSocket messages: caught with try/catch, silently skipped (appropriate for protocol resilience)
- Global unhandled rejection handler: catches any missed async errors

### Resource Management Details

- **metro.sh `bundle-check`**: temp file created with `mktemp`, cleaned up via `trap EXIT`
- **logs.sh**: background processes killed via `trap INT TERM`; `wait` called to reap zombies
- **cdp-bridge.js**: WebSocket closed explicitly in all exit paths; pending promises rejected on error/close to prevent leaks

### Boundary Conditions

- **Empty args**: all three scripts print usage and exit 1
- **No Metro running**: metro.sh exits 1 with message; cdp-bridge.js exits 1 with message and suggestion
- **No CDP targets**: cdp-bridge.js checks for empty array
- **Empty stdin for symbolicate**: checked explicitly
- **No expression for eval mode**: checked explicitly in `modeEval`
- **React DevTools hook not found**: checked via `__noHook` sentinel, exits 1 with specific message

## Defensive Programming

| Check | Status | Evidence |
|-------|--------|----------|
| No empty catch blocks | PASS | cdp-bridge.js line 93 `catch {}` on JSON parse is intentional protocol resilience (malformed WebSocket frame), not a swallowed error; walker expression `catch(e) {}` on lines 236, 241 protects against inaccessible fiber properties (defensive access on internal React data structures) |
| External input validated | PASS | CLI args validated in all three scripts; stdin validated in symbolicate; HTTP responses checked for expected content |
| Assertions for bugs only | N/A | No assertions used (appropriate for CLI scripts) |
| Error messages actionable | PASS | All error messages include context (port number, HTTP status, platform) and suggestions where appropriate ("npx react-native start") |
| Broad exception types | PASS | cdp-bridge.js catches specific scenarios; the `main().catch()` is a last-resort handler at the top level (appropriate) |
| Silent failures | PASS | No cases where errors are silently swallowed; the JSON parse `catch {}` in WebSocket message handler is the closest case but is correct behavior (skip malformed protocol frames rather than crash the stream) |

## Notes

Two minor observations (not blocking):

1. **modeConsole keep-alive pattern** (cdp-bridge.js lines 158-168): The `await new Promise()` with `setInterval` that does nothing is an unusual keep-alive pattern. The `setInterval` is unreffed, so it does not actually keep the process alive -- the WebSocket connection does. The empty callback and unreffed interval are harmless but could be simplified. The `modeNetwork` implementation (lines 319-322) uses a cleaner `await new Promise(() => {...})` without the interval. Minor inconsistency, not a defect.

2. **logs.sh `run_with_timeout` exit code**: The function always exits 0 after timeout (line 40), matching the plan spec that timeout is not an error. The killed process may produce a non-zero exit from `wait`, but `2>/dev/null` suppresses it. Correct behavior.
