---
name: rn-debug
description: Debug React Native apps — view console logs, JS errors, Metro status, evaluate expressions, inspect React component tree, monitor network requests. Use for runtime debugging of JavaScript and React layers. Triggers on "console logs", "JS errors", "Metro status", "evaluate expression", "React component tree", "network requests", "debug".
allowed-tools: Bash, Read, Agent
---

# Skill: rn-debug

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `rn-debug v{version}` before proceeding.

Debug React Native apps through Metro, console log streams, CDP evaluation, component tree inspection, and network monitoring.

```
IMPORTANT: Console streams, component trees, and network logs can be large.
Always dispatch a subagent for streaming and tree operations.
```

---

## Prerequisites

- Metro bundler must be running for CDP features (console via CDP, eval, tree, network)
- `logs.sh` works without Metro (OS-level log capture)
- Node 22+ required for `cdp-bridge.js` only
- See `${CLAUDE_SKILL_DIR}/references/metro-endpoints.md` for Metro HTTP API details

## Scripts

All shared scripts live at `${CLAUDE_SKILL_DIR}/../_shared/scripts/`. Run them with Bash.

| Script | Purpose |
|--------|---------|
| `metro.sh` | Metro health checks, bundle validation, stack symbolication |
| `logs.sh` | OS-level JS console log capture (iOS and Android) |
| `cdp-bridge.js` | CDP WebSocket bridge: console, eval, tree, network |

## Routing Table

| Intent | Script | Subagent? |
|--------|--------|-----------|
| Check Metro health | `metro.sh status` | No |
| View console output | `logs.sh` or `cdp-bridge.js console` | Yes |
| Evaluate JS expression | `cdp-bridge.js eval "expr"` | No |
| Inspect React tree | `cdp-bridge.js tree` | Yes |
| Monitor network | `cdp-bridge.js network` | Yes |
| Check bundle health | `metro.sh bundle-check` | No |
| Symbolicate stack | `metro.sh symbolicate` | No |

---

## Fallback Logic

Before any CDP operation (`eval`, `tree`, `network`, `cdp-bridge.js console`):

1. Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status` first
2. If Metro is **not running**:
   - **Console logs requested:** Fall back to `logs.sh` (works without Metro via OS-level capture). Note the fallback in output to the user.
   - **CDP required** (eval, tree, network): Report error: "Metro is not running. Start it with `npx react-native start`." Do NOT attempt the CDP operation.

---

## Workflows

### 1. Console Logs

**When:** "show console logs", "JS errors", "what's in the console"

Step 1: Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status` to check Metro.

**Step 2a (Metro running):**

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "rn-debug: stream console logs via CDP"
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
  description: "rn-debug: stream console logs via OS capture"
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

Direct (no subagent -- output is small):

1. Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status`
2. If running: Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js eval "expression"`
3. Return JSON result directly

### 3. Component Tree

**When:** "React tree", "component tree", "find component"

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "rn-debug: inspect React component tree"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js tree [--find "ComponentName" if specified]
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
  description: "rn-debug: monitor network requests"
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
| JS eval result | ~100-1000 chars | Yes |
| Console log stream | ~1-50 KB | NEVER -- subagent only |
| React component tree | ~10-100 KB | NEVER -- subagent only |
| Network request log | ~5-50 KB | NEVER -- subagent only |
