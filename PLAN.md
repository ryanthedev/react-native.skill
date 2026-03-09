# react-native-foundations — Phase 2 Plan

## Current State (v0.1.0) — 7 Skills

| Skill | Purpose | Scripts |
|-------|---------|---------|
| `rn-docs` | Grep-first search of 234 official RN doc files | — |
| `ios-sim` | Simulator control (screenshots, a11y tree, tap/swipe/type, video) | device.sh, ui.sh, capture.sh, app.sh |
| `rn-diagnose` | Error diagnosis with 18 patterns + docs cross-reference | — |
| `rn-layout-check` | Visual layout verification (screenshot + a11y tree + docs) | — |
| `rn-deeplink-test` | Deep link test-verify loop | openurl.sh |
| `rn-clean` | Intelligent environment reset | diagnose.sh, clean.sh |
| `rn-a11y-audit` | Accessibility audit via tree inspection + docs | — |

---

## Phase 2 Target Structure

```
skills/
├── _shared/scripts/           ← NEW: scripts used by multiple skills
│   ├── metro.sh               (Metro health/status/symbolication — pure bash)
│   ├── logs.sh                (iOS + Android JS console capture — pure bash)
│   └── cdp-bridge.js          (CDP WebSocket: console, eval, tree, network — Node 22+)
├── rn-debug/                  ← NEW: wraps all debug tool access
│   ├── SKILL.md
│   └── references/metro-endpoints.md
├── rn-coding/                 ← NEW: lightweight dev guidance
│   ├── SKILL.md
│   └── references/workflow-checklist.md
├── rn-diagnose/               ← ENHANCED: add Metro health as Step 0
├── ios-sim/                   (unchanged)
├── rn-docs/                   (unchanged)
├── rn-layout-check/           (unchanged — CDP deferred)
├── rn-deeplink-test/          (unchanged)
├── rn-clean/                  (unchanged)
└── rn-a11y-audit/             (unchanged — CDP deferred)
```

---

## Key Architectural Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Where do shared scripts live? | `_shared/scripts/` | Used by rn-debug + rn-diagnose; `_` prefix = partial/shared convention |
| Is cdp-bridge.js persistent? | No — connect, do one thing, exit | No persistent server processes; timeout for streaming modes |
| How does rn-coding work? | Inline guidance, not a router | Tells Claude to consult docs before writing, suggest verification after |
| What if Metro isn't running? | Graceful fallback | `logs.sh` works without Metro (OS-level); CDP features report error + suggest starting Metro |
| CDP in layout-check/a11y-audit? | Deferred | Native a11y tree works well; CDP adds fragile Metro dependency |
| rn-debug vs expanding ios-sim? | Separate skill | Debug tools are JS-layer, cross-platform; ios-sim is native UI layer |

---

## New Scripts

### `_shared/scripts/metro.sh` (pure bash + curl)

Port resolution order: `--port` flag > `RCT_METRO_PORT` env var > default `8081`.

| Command | What It Does | Backend |
|---------|-------------|---------|
| `metro.sh status [--port PORT]` | Check if Metro is running | `curl http://localhost:$PORT/status` |
| `metro.sh targets [--port PORT]` | List debuggable CDP targets | `curl http://localhost:$PORT/json/list` |
| `metro.sh bundle-check [--platform ios] [--port PORT]` | Check if bundle builds (200=OK, 500=error) | `curl http://localhost:$PORT/index.bundle?...` |
| `metro.sh symbolicate [--port PORT]` | Symbolicate stack trace (stdin JSON) | `POST http://localhost:$PORT/symbolicate` |

### `_shared/scripts/logs.sh` (pure bash)

| Command | What It Does | Backend |
|---------|-------------|---------|
| `logs.sh ios [--timeout 10] [--json]` | Stream iOS JS console logs | `xcrun simctl spawn booted log stream --predicate 'subsystem == "com.facebook.react.log" AND category == "javascript"'` |
| `logs.sh android [--timeout 10] [--json]` | Stream Android JS console logs | `adb logcat -v json '*:S' ReactNativeJS:V` |
| `logs.sh ios --native` | Include native RN logs | Same with broader predicate |

### `_shared/scripts/cdp-bridge.js` (Node 22+, zero npm deps)

On startup, checks `process.version` and exits with message "cdp-bridge.js requires Node 22+, found vX.Y.Z" if version is below 22.

| Mode | What It Does | Output |
|------|-------------|--------|
| `cdp-bridge.js console [--timeout 10]` | Stream `Runtime.consoleAPICalled` events | NDJSON to stdout |
| `cdp-bridge.js eval "expression"` | `Runtime.evaluate`, print result, exit | JSON result |
| `cdp-bridge.js tree` | Walk `__REACT_DEVTOOLS_GLOBAL_HOOK__` fiber tree | JSON component tree (names, props, state) |
| `cdp-bridge.js tree --find "LoginScreen"` | Find specific component + its state | JSON match |
| `cdp-bridge.js network [--timeout 10]` | Stream `Network.requestWillBeSent` events | NDJSON to stdout |

> **`tree` mode caveat:** Requires the app to be running in dev mode with `__REACT_DEVTOOLS_GLOBAL_HOOK__` present. If the hook is not found, exit 1 with stderr: "React DevTools hook not found — ensure app is running in dev mode." Non-dev builds strip the hook entirely.

Auto-discovers WebSocket URL via `GET http://localhost:$PORT/json/list`. Port resolution: `--port` flag > `RCT_METRO_PORT` env var > default `8081`.

---

## New Skills

### `rn-debug`

**Triggers:** "console logs", "JS errors", "Metro status", "evaluate expression", "React component tree", "network requests", "debug"

**Routing:**

| Intent | Script | Subagent? |
|--------|--------|-----------|
| Check Metro health | `metro.sh status` | No |
| View console output | `logs.sh` or `cdp-bridge.js console` | Yes (large output) |
| Evaluate JS expression | `cdp-bridge.js eval "expr"` | No (small output) |
| Inspect React tree | `cdp-bridge.js tree` | Yes (tree can be large) |
| Monitor network | `cdp-bridge.js network` | Yes (streaming) |
| Check bundle health | `metro.sh bundle-check` | No |
| Symbolicate stack | `metro.sh symbolicate` | No |

**Fallback logic:**
- Before any CDP operation: run `metro.sh status`
- If Metro down + console requested: fall back to `logs.sh` (works without Metro)
- If Metro down + CDP required: report error, suggest `npx react-native start`

### `rn-coding`

**Triggers:** "write a component", "implement this feature", "build this screen", "add a view", "React Native code"

**Nature:** Lightweight guidance skill (no Bash, no Agent — just Read/Grep/Glob).

**Workflow:**
1. **Before writing:** Grep rn-docs for relevant APIs (component docs, layout props, platform behavior)
2. **While writing:** Follow patterns from docs, note platform differences
3. **After writing:** Suggest verification:
   - "Run `rn-layout-check` to verify layout"
   - "Run `rn-a11y-audit` to check accessibility"
   - "Use `rn-debug` to check for console errors"
4. **If errors:** Direct to `rn-diagnose`

---

## Enhancements to Existing Skills

### rn-diagnose — Add Metro Health as Step 0

Before deep diagnosis, check the development environment:

1. `metro.sh status` — Is Metro running?
2. `metro.sh bundle-check` — Does the bundle build? (500 = fetch error body for diagnosis)
3. If user provides a raw stack trace: `metro.sh symbolicate` before pattern matching

Add Metro connectivity patterns to `error-patterns.md`.

---

## Data Flow

```
"show me console errors"
  → rn-debug triggers
  → metro.sh status (check Metro)
  → if running: cdp-bridge.js console --timeout 10 (subagent)
  → if not running: logs.sh ios --timeout 10 (subagent, bash fallback)
  → subagent returns formatted log summary

"why is my build failing"
  → rn-diagnose triggers
  → Step 0: metro.sh status + metro.sh bundle-check
  → if bundle-check 500: fetch error body, pattern-match
  → normal rn-diagnose workflow (Steps 1-5)

"write a FlatList component"
  → rn-coding triggers
  → grep rn-docs for FlatList, read flatlist.md
  → write component with docs-informed patterns
  → suggest: "Run rn-layout-check to verify"

"evaluate someStore.getState()"
  → rn-debug triggers
  → cdp-bridge.js eval "JSON.stringify(someStore.getState())"
  → returns result directly (small output, no subagent)

"show React component tree"
  → rn-debug triggers
  → cdp-bridge.js tree (subagent, large output)
  → subagent returns structured summary
```

---

## Cross-Skill Script References

```
rn-debug    → _shared/scripts/logs.sh
rn-debug    → _shared/scripts/metro.sh
rn-debug    → _shared/scripts/cdp-bridge.js
rn-diagnose → _shared/scripts/metro.sh        (new Step 0)
rn-diagnose → ios-sim/scripts/capture.sh       (existing)
rn-coding   → refs/react-native-docs/docs/     (grep, same as rn-docs; path resolves relative to plugin install dir)
```

---

## Build Order

### Phase 2a: Foundation Scripts

1. `_shared/scripts/metro.sh` — simplest, pure curl, immediately testable
2. `_shared/scripts/logs.sh` — bash-only, testable with any running RN app
3. `_shared/scripts/cdp-bridge.js` — most complex, Node 22+, requires running app

### Phase 2b: New Skills

4. `rn-debug/SKILL.md` + `references/metro-endpoints.md`
5. `rn-coding/SKILL.md` + `references/workflow-checklist.md`

### Phase 2c: Integration

6. Update `rn-diagnose/SKILL.md` — add Step 0 (Metro health)
7. Update `rn-diagnose/references/error-patterns.md` — add Metro patterns
8. Update `.claude/settings.local.json` — new skill permissions + `Bash(*/skills/_shared/scripts/*)`
9. Update `plugin.json` — bump to v0.2.0

### Phase 2d: Completed + Deferred

- ~~CDP integration into rn-layout-check (computed styles via Runtime.evaluate)~~ (done — v0.3.0)
- ~~CDP integration into rn-a11y-audit (React-level a11y props via fiber tree)~~ (done — v0.3.0)
- Android emulator equivalent of ios-sim (adb-based UI automation) (deferred)
- ~~HMR WebSocket monitoring for live reload error detection~~ (done — v0.3.0)
- ~~Callstack best-practices cross-reference in rn-coding~~ (done — v0.3.0)

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

| Data Type | Size | Main Context? |
|-----------|------|---------------|
| Metro status check | ~20 chars | Yes |
| JS eval result | ~100-1000 chars | Yes |
| Console log stream | ~1-50 KB | NEVER — subagent |
| React component tree | ~10-100 KB | NEVER — subagent |
| Network request log | ~5-50 KB | NEVER — subagent |
| Screenshots | ~100-300 KB | NEVER — subagent |
| Accessibility tree | ~10-100 KB | NEVER — subagent |

---

## Error Handling: Metro Not Running

| Script | Behavior |
|--------|----------|
| `metro.sh status` | Exit 1, stderr: "Metro is not running on port $PORT" |
| `cdp-bridge.js` | Catches connection refused, stderr: "Cannot connect to Metro", exit 1 |
| `logs.sh ios` | Works regardless of Metro (OS-level log capture) |
| `logs.sh android` | Works regardless of Metro (adb logcat) |
| rn-debug SKILL.md | Check metro.sh status first; fall back to logs.sh for console; report error for CDP features |
