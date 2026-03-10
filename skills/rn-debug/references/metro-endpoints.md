# Metro Bundler HTTP Endpoints

Quick reference for Metro's HTTP API. Used by `metro.sh` and `cdp-bridge.js` under the hood. Useful for manual debugging when the scripts don't cover a case.

## Port Resolution

Metro port is resolved in this priority order:

1. `--port` flag (passed to script)
2. `RCT_METRO_PORT` environment variable
3. Default: `8081`

## Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/status` | GET | Health check |
| `/json/list` | GET | List debuggable CDP WebSocket targets |
| `/index.bundle?platform=ios&dev=true` | GET | Build JS bundle |
| `/symbolicate` | POST | Symbolicate stack trace |
| `/hot` | WebSocket | HMR event stream |

---

### GET /status

Health check -- returns a plain text response.

```bash
curl http://localhost:8081/status
```

**Response (running):**
```
packager-status:running
```

**Error (Metro not running):**
```
curl: (7) Failed to connect to localhost port 8081
```

---

### GET /json/list

List debuggable CDP WebSocket targets. Returns a JSON array of targets, each with a `webSocketDebuggerUrl`.

```bash
curl http://localhost:8081/json/list
```

**Response (new architecture / Bridgeless):**
```json
[
  {
    "id": "device-1",
    "title": "com.example.app (iPhone 16e)",
    "description": "React Native Bridgeless [C++ connection]",
    "type": "node",
    "webSocketDebuggerUrl": "ws://localhost:8081/inspector/debug?device=...&page=1",
    "reactNative": {
      "capabilities": { "nativePageReloads": true }
    }
  },
  {
    "id": "device-2",
    "title": "com.example.app (iPhone 16e)",
    "description": "UI [C++ connection]",
    "type": "node",
    "webSocketDebuggerUrl": "ws://localhost:8081/inspector/debug?device=...&page=2"
  }
]
```

With new architecture, multiple targets appear. The JS runtime target has `nativePageReloads: true`. The UI thread target cannot execute JS. `cdp-bridge.js` selects the correct target automatically.

**Error (no targets available):**
```json
[]
```

---

### GET /index.bundle?platform=ios&dev=true

Build the JS bundle. Returns 200 on success, 500 on build error.

```bash
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081/index.bundle?platform=ios&dev=true"
```

**Response (success):** HTTP 200 with the JS bundle content.

**Response (build error):** HTTP 500 with error body containing the build failure message (syntax errors, missing modules, etc.).

---

### POST /symbolicate

Symbolicate a stack trace. Accepts a JSON body with the stack frames and returns symbolicated output.

```bash
curl -X POST http://localhost:8081/symbolicate \
  -H "Content-Type: application/json" \
  -d '{"stack": [{"file": "index.bundle", "lineNumber": 1234, "column": 56}]}'
```

**Request body format:**
```json
{
  "stack": [
    {
      "file": "index.bundle",
      "lineNumber": 1234,
      "column": 56
    }
  ]
}
```

**Response:**
```json
{
  "stack": [
    {
      "file": "src/screens/HomeScreen.tsx",
      "lineNumber": 42,
      "column": 12,
      "methodName": "onPress"
    }
  ]
}
```

**Error (Metro not running):** Connection refused.

---

## CDP WebSocket

The `/json/list` endpoint returns targets with a `webSocketDebuggerUrl` field. This is how `cdp-bridge.js` auto-discovers the WebSocket connection for CDP operations (console, eval, tree, network).

The WebSocket uses the standard Chrome DevTools Protocol (CDP). Messages are JSON-RPC:

```json
{"id": 1, "method": "Runtime.evaluate", "params": {"expression": "1+1"}}
```

This is the same protocol used by Chrome DevTools -- any CDP reference documentation applies.

---

## HMR WebSocket

The `/hot` endpoint is a WebSocket used by Metro's Hot Module Replacement system. Unlike the CDP WebSocket (discovered via /json/list), this connects directly.

**Connection URL:** `ws://localhost:PORT/hot`

**Protocol:**

1. Client sends a register message after connecting. Entry points must be full bundle URLs (not bare module names):
   ```json
   {"type":"register-entrypoints","entryPoints":["http://localhost:8081/index.bundle?platform=ios&dev=true&minify=false&lazy=true&unstable_transformProfile=hermes-stable"]}
   ```
   The URL params must match how the bundle was originally built so Metro finds the existing graph. `hmr.sh` handles this automatically.
2. Server streams JSON messages with a `type` field:
   - `update-start` -- bundle rebuild beginning
   - `update` -- module(s) changed (body contains module info)
   - `update-done` -- bundle rebuild complete
   - `error` -- build error occurred (body contains error details)

**Note:** This is a Metro-internal protocol. The message format may vary across Metro versions. `hmr.sh` handles unexpected message shapes gracefully.

**Example usage:**
```bash
hmr.sh monitor --timeout 30
```
