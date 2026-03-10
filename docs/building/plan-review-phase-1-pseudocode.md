# Pseudocode: Phase 1 - Fix 6 PLAN.md Issues

## File to Modify
- `/Users/r/repos/react-native.skill/PLAN.md`

## Pseudocode (Exact Edits)

### Fix 1: Port 8081 hardcoded -- metro.sh command table

**Location:** Lines 57-64 (metro.sh section header and command table)

**Find:**
```
### `_shared/scripts/metro.sh` (pure bash + curl)

| Command | What It Does | Backend |
|---------|-------------|---------|
| `metro.sh status` | Check if Metro is running | `curl http://localhost:8081/status` |
| `metro.sh targets` | List debuggable CDP targets | `curl http://localhost:8081/json/list` |
| `metro.sh bundle-check [--platform ios]` | Check if bundle builds (200=OK, 500=error) | `curl http://localhost:8081/index.bundle?...` |
| `metro.sh symbolicate` | Symbolicate stack trace (stdin JSON) | `POST http://localhost:8081/symbolicate` |
```

**Replace with:**
```
### `_shared/scripts/metro.sh` (pure bash + curl)

Port resolution order: `--port` flag > `RCT_METRO_PORT` env var > default `8081`.

| Command | What It Does | Backend |
|---------|-------------|---------|
| `metro.sh status [--port PORT]` | Check if Metro is running | `curl http://localhost:$PORT/status` |
| `metro.sh targets [--port PORT]` | List debuggable CDP targets | `curl http://localhost:$PORT/json/list` |
| `metro.sh bundle-check [--platform ios] [--port PORT]` | Check if bundle builds (200=OK, 500=error) | `curl http://localhost:$PORT/index.bundle?...` |
| `metro.sh symbolicate [--port PORT]` | Symbolicate stack trace (stdin JSON) | `POST http://localhost:$PORT/symbolicate` |
```

### Fix 1 (continued): Port 8081 hardcoded -- cdp-bridge.js auto-discovery line

**Location:** Line 84

**Find:**
```
Auto-discovers WebSocket URL via `GET http://localhost:8081/json/list`.
```

**Replace with:**
```
Auto-discovers WebSocket URL via `GET http://localhost:$PORT/json/list`. Port resolution: `--port` flag > `RCT_METRO_PORT` env var > default `8081`.
```

### Fix 1 (continued): Port 8081 hardcoded -- error handling table

**Location:** Line 238 in the Error Handling table

**Find:**
```
| `metro.sh status` | Exit 1, stderr: "Metro is not running on port 8081" |
```

**Replace with:**
```
| `metro.sh status` | Exit 1, stderr: "Metro is not running on port $PORT" |
```

### Fix 2: DevTools hook caveat -- cdp-bridge.js tree mode

**Location:** Line 80 (tree mode row in cdp-bridge.js table)

**Find:**
```
| `cdp-bridge.js tree` | Walk `__REACT_DEVTOOLS_GLOBAL_HOOK__` fiber tree | JSON component tree (names, props, state) |
```

**Replace with:**
```
| `cdp-bridge.js tree` | Walk `__REACT_DEVTOOLS_GLOBAL_HOOK__` fiber tree | JSON component tree (names, props, state) |

> **`tree` mode caveat:** Requires the app to be running in dev mode with `__REACT_DEVTOOLS_GLOBAL_HOOK__` present. If the hook is not found, exit 1 with stderr: "React DevTools hook not found — ensure app is running in dev mode." Non-dev builds strip the hook entirely.
```

### Fix 3: Node 22+ guard -- cdp-bridge.js description

**Location:** Line 74 (cdp-bridge.js section header)

**Find:**
```
### `_shared/scripts/cdp-bridge.js` (Node 22+, zero npm deps)
```

**Replace with:**
```
### `_shared/scripts/cdp-bridge.js` (Node 22+, zero npm deps)

On startup, checks `process.version` and exits with message "cdp-bridge.js requires Node 22+, found vX.Y.Z" if version is below 22.
```

### Fix 4: Script testing strategy -- Smoke Tests section

**Location:** After line 216 (end of Phase 2d deferred list), before the `---` separator on line 218.

**Find:**
```
- Callstack best-practices cross-reference in rn-coding

---

## Context Efficiency Rules
```

**Replace with:**
```
- Callstack best-practices cross-reference in rn-coding

### Smoke Tests

Manual verification steps for each script. Run with a React Native app in the iOS Simulator.

**metro.sh**
1. Start Metro (`npx react-native start`), run `metro.sh status` -- expect exit 0, "running"
2. Stop Metro, run `metro.sh status` -- expect exit 1, stderr message
3. Run `metro.sh status --port 9090` with Metro on 9090 -- expect exit 0
4. Run `metro.sh targets` -- expect JSON array with at least one entry
5. Run `metro.sh bundle-check --platform ios` -- expect exit 0

**logs.sh**
1. Run `logs.sh ios --timeout 5` with app open -- expect log lines within 5s
2. Trigger a `console.log("test")` in app -- expect "test" in output
3. Run `logs.sh ios --json --timeout 5` -- expect valid JSON per line
4. Run `logs.sh android --timeout 5` on Android emulator -- expect log output

**cdp-bridge.js**
1. Run `cdp-bridge.js console --timeout 5` -- expect NDJSON console events
2. Run `cdp-bridge.js eval "1+1"` -- expect `{"result":2}`
3. Run `cdp-bridge.js tree` -- expect JSON component tree (dev mode only)
4. Run `cdp-bridge.js tree --find "App"` -- expect match with props/state
5. Run with Node < 22 -- expect version error and exit 1
6. Stop Metro, run `cdp-bridge.js eval "1"` -- expect connection error, exit 1

---

## Context Efficiency Rules
```

### Fix 5: rn-coding path resolution

**Location:** Line 185 in Cross-Skill Script References

**Find:**
```
rn-coding   → refs/react-native-docs/docs/     (grep, same as rn-docs)
```

**Replace with:**
```
rn-coding   → refs/react-native-docs/docs/     (grep, same as rn-docs; path resolves relative to plugin install dir)
```

### Fix 6: Doc count discrepancy

**Location:** Line 7

**NOTE:** Discovery found that 234 is actually correct (it matches the `.md` file count exactly). The requested change to 218 does not match any count derivable from the actual files. Applying as instructed but flagging for review.

**Find:**
```
| `rn-docs` | Grep-first search of 234 official RN doc files | — |
```

**Replace with:**
```
| `rn-docs` | Grep-first search of 218 official RN doc files | — |
```

## Design Notes
- All fixes are additive or replacement text edits to a single Markdown file.
- Fix 1 is the most spread out (3 separate locations in the file).
- Fix 4 is the largest insertion (a new section with ~25 lines).
- Fix 6 has a data discrepancy: the actual `.md` count is 234, not 218. The user should verify which count is intended.

## PRE-GATE Status
- [x] Discovery complete
- [x] Pseudocode complete
- [x] Design reviewed (straightforward text edits, no module design needed)
- [x] Ready for implementation
