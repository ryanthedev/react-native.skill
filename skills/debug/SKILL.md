---
name: debug
description: Debug React Native apps — view console logs, JS errors, Metro status, evaluate expressions, inspect React component tree, monitor network requests. Use for runtime debugging of JavaScript and React layers. Triggers on "console logs", "JS errors", "Metro status", "evaluate expression", "React component tree", "network requests", "debug".
allowed-tools: Bash, Read, Agent
---

# Skill: debug

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `debug v{version}` before proceeding.

Debug React Native apps through Metro, console log streams, CDP evaluation, component tree inspection, and network monitoring.

```
IMPORTANT: Console streams, component trees, and network logs can be large.
Always dispatch a subagent for streaming and tree operations.
```

---

## Dependencies

| Skill / Resource | Why |
|------------------|-----|
| `_shared` (metro.sh, logs.sh, cdp-bridge.js, hmr.sh) | All debug operations — Metro health, log capture, JS eval, component tree, network monitor, HMR events |

---

## Step 0: Pre-Flight Check

Before any debug operation, run all three checks to understand what's available. Run once per session, not per command.

```bash
# 1. Metro running?
${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status

# 2. Simulator booted?
xcrun simctl list devices booted

# 3. App connected to Metro? (only if Metro is up)
${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh targets
```

`metro.sh targets` returns a JSON array of debuggable CDP pages. Each entry has `appId`, `title`, and `deviceName`. An empty array `[]` means Metro is running but no app has connected to it.

### Pre-Flight Decision Table

| Metro | Simulator | Targets | Action |
|-------|-----------|---------|--------|
| Up | Booted | Has entries | Proceed with CDP operations |
| Up | Booted | Empty `[]` | Tell user: "Metro is running but no app is connected. Open your app in the simulator." |
| Up | Not booted | — | Tell user: "Metro is running but no simulator is booted." |
| Down | Booted | — | Fall back to `logs.sh` for console logs. Report "Metro not running" for CDP operations. |
| Down | Not booted | — | Tell user: "Neither Metro nor a simulator is running." |

**Never return empty results without diagnosing why.** If a CDP operation returns nothing, re-run `metro.sh targets` to check whether the app disconnected mid-session.

## Prerequisites

- Metro bundler must be running for CDP features (console via CDP, eval, tree, network)
- `logs.sh` works without Metro (OS-level log capture)
- Node 22+ required for `cdp-bridge.js` and `hmr.sh` (native WebSocket)
- Works with both vanilla React Native and Expo projects (Expo SDK 54+ tested)
- See `${CLAUDE_SKILL_DIR}/references/metro-endpoints.md` for Metro HTTP API details

## Scripts

All shared scripts live at `${CLAUDE_SKILL_DIR}/../_shared/scripts/`. Run them with Bash.

| Script | Purpose |
|--------|---------|
| `metro.sh` | Metro health checks, bundle validation, stack symbolication |
| `logs.sh` | OS-level JS console log capture (iOS and Android) |
| `cdp-bridge.js` | CDP WebSocket bridge: console, eval, tree, network |
| `hmr.sh` | HMR WebSocket event monitor |

## Routing Table

| Intent | Script | Subagent? |
|--------|--------|-----------|
| Check Metro health | `metro.sh status` | No |
| View console output | `logs.sh` or `cdp-bridge.js console` | Yes |
| Evaluate JS expression | `cdp-bridge.js eval "expr"` | No |
| Inspect React tree | `cdp-bridge.js tree [--depth N]` | Yes |
| Monitor network | `cdp-bridge.js network` | Yes |
| Monitor HMR | `hmr.sh monitor` | Yes (streaming) |
| Check bundle health | `metro.sh bundle-check` | No |
| Symbolicate stack | `metro.sh symbolicate` | No |

---

## Fallback Logic

Before any CDP operation (`eval`, `tree`, `network`, `cdp-bridge.js console`), verify the full chain from the Pre-Flight Decision Table. If pre-flight already ran this session, at minimum re-check `metro.sh targets` to confirm the app is still connected.

1. **Metro not running:**
   - Console logs requested → fall back to `logs.sh` (OS-level capture). Note the fallback to the user.
   - CDP required (eval, tree, network) → report: "Metro is not running. Start it with `npx react-native start`."
2. **Metro running but targets empty:**
   - Report: "Metro is running but no app is connected. Open your app in the simulator."
   - Do NOT attempt the CDP operation — it will return nothing.
3. **CDP operation returns empty after passing pre-flight:**
   - Re-run `metro.sh targets`. If targets disappeared, the app crashed or was closed.
   - Report what changed rather than returning bare empty results.

---

## Workflows

### 1. Console Logs

**When:** "show console logs", "JS errors", "what's in the console"

Step 1: Run the Pre-Flight Check (or verify targets if pre-flight already ran this session).

**Step 2a (Metro running):**

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "debug: stream console logs via CDP"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js console --timeout 10
       This streams console events as NDJSON to stdout.
    2. Parse the NDJSON output.
    3. Summarize:
       - Error count
       - Warning count
       - Notable log entries (first few errors/warnings with messages)
    4. Return a concise text summary.
```

**Step 2b (Metro not running):**

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "debug: stream console logs via OS capture"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../_shared/scripts/logs.sh ios --timeout 10
       This streams JS console logs as NDJSON to stdout.
    2. Parse the NDJSON output.
    3. Summarize:
       - Error count
       - Warning count
       - Notable log entries (first few errors/warnings with messages)
    4. Return a concise text summary.
    5. Note: These logs were captured via OS-level logging (Metro was not running).
```

### 2. Evaluate Expression

**When:** "evaluate", "run this JS", "check state"

Direct (no subagent — output is small):

1. Verify pre-flight passed (Metro up + targets present)
2. Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js eval "expression"`
3. Return JSON result directly
4. If empty/error: re-check `metro.sh targets` before reporting

### 3. Component Tree

**When:** "React tree", "component tree", "find component"

Use `--find` when looking for a specific component (preferred — returns only matches).
Use `--depth N` to limit output size for overview (depth 5 is a good starting point).
Only use full tree (no flags) via subagent — output can be 10-100 KB.

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "debug: inspect React component tree"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js tree [--find "ComponentName" if specified] [--depth 5 for overview]
       This outputs the React component tree as JSON.
    2. Parse the JSON tree.
    3. Summarize:
       - Component hierarchy (top-level structure)
       - For matches (if --find was used): component name, props, state
       - Notable patterns (deeply nested components, error boundaries)
    4. Return a concise text summary.

    LOOKING FOR: [insert component name or "full tree overview"]
```

### 4. Network Monitor

**When:** "network requests", "API calls", "what's being fetched"

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "debug: monitor network requests"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js network --timeout 10
       This streams network events as NDJSON to stdout.
    2. Parse the NDJSON events.
    3. Summarize:
       - Total request count
       - URLs requested (grouped by domain if many)
       - Status codes
       - Notable failures (4xx, 5xx, timeouts)
    4. Return a concise text summary.
```

### 5. HMR Monitor

**When:** "HMR updates", "hot reload events", "module changes", "hot module replacement"

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "debug: monitor HMR update events"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../_shared/scripts/hmr.sh monitor --timeout 30
       This streams HMR events as NDJSON to stdout.
    2. Parse the NDJSON output.
    3. Summarize:
       - Total update count
       - Modules updated (list file paths)
       - Any errors reported
       - Timeline of update-start / update-done cycles
    4. Return a concise text summary.
```

---

## Tips

- Port resolution for Metro: `--port` flag > `RCT_METRO_PORT` env var > default `8081`
- Console logs via `logs.sh` capture OS-level output and work even without Metro
- `cdp-bridge.js tree` requires the app to be running in dev mode (non-dev builds strip the React DevTools hook)
- For the **evaluate** workflow, wrap expressions in `JSON.stringify()` for readable output of objects/arrays

## Context Efficiency

| Item | Size | In Main Context? |
|------|------|------------------|
| Metro status | ~20 chars | Yes |
| CDP targets check | ~200-500 chars | Yes |
| Simulator boot check | ~100 chars | Yes |
| JS eval result | ~100-1000 chars | Yes |
| Console log stream | ~1-50 KB | NEVER -- subagent only |
| React component tree | ~10-100 KB | NEVER -- subagent only |
| Network request log | ~5-50 KB | NEVER -- subagent only |
| HMR event stream | ~1-10 KB | NEVER -- subagent only |
