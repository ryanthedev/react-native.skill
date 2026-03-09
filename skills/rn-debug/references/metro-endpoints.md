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

**Response:**
```json
[
  {
    "id": "1",
    "description": "com.example.app",
    "title": "React Native Bridge",
    "type": "node",
    "webSocketDebuggerUrl": "ws://localhost:8081/inspector/debug?device=0&page=1"
  }
]
```

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
