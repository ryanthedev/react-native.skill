---
name: deeplink-test
description: Test deep links and URL schemes in the iOS Simulator. Reads navigation/linking config, constructs test URLs, fires them via xcrun simctl, and verifies the resulting screen. Triggers on "test deep link", "test this URL scheme", "verify navigation to", "does deeplink work", "open URL in simulator", "test universal link".
allowed-tools: Bash, Read, Grep, Glob, Agent
---

# Skill: deeplink-test

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `deeplink-test v{version}` before proceeding.

Test deep links by reading the project's navigation config, constructing URLs, firing them into the iOS Simulator, and verifying the correct screen loads.

---

## Dependencies

| Skill / Resource | Why |
|------------------|-----|
| `ios-sim` | Step 5 — subagent uses `capture.sh view` (via `xcrun simctl screenshot` directly) to verify the screen after firing the deep link |
| `refs/react-native-docs` | Step 2 — docs search for deep linking patterns and universal link configuration |

---

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/openurl.sh <url>` — Validates and opens a URL in the booted simulator

## Workflow

### 1. Find the linking configuration

Search the user's project for navigation/linking config:

```
Glob: **/linking.{ts,js,tsx,jsx}
Glob: **/navigation/**/*.{ts,js,tsx,jsx}
Grep: "linking" or "prefixes" or "screens" in navigation files
```

Look for `linking` config objects containing `prefixes` and `screens` mapping.

### 2. Search docs for deep linking patterns

```
Grep the docs directory for deep linking reference:
  ${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/
  Search terms: "deep link", "linking", "URL scheme", "universal link"
```

### 3. Construct the test URL

From the linking config, build a URL: `{prefix}{path}`.
If the user provided a specific URL, use it directly.
If testing a screen name, map it through the `screens` config to find the path.

### 4. Fire the URL into the simulator

```bash
${CLAUDE_SKILL_DIR}/scripts/openurl.sh "scheme://path/to/screen"
```

This wraps `xcrun simctl openurl booted` with validation.

### 5. Verify the screen loaded

Dispatch a subagent to capture and verify the simulator screen.

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "deeplink-test: verify deep link screen"
  prompt: |
    A deep link was just fired into the iOS Simulator.
    Expected destination: [EXPECTED_SCREEN]
    URL fired: [URL]

    1. Wait 2 seconds for navigation to settle, then run:
       xcrun simctl io booted screenshot /tmp/deeplink-verify.jpg
    2. Read /tmp/deeplink-verify.jpg to see the screen.
    3. Analyze and return:
       - Screen loaded: What screen/view is currently visible
       - Match: Does it match the expected destination? (PASS / FAIL)
       - Navigation state: Tab, stack depth, header title if visible
       - Errors: Any error messages, crash screens, or "not found" states
       - Details: Notable UI elements confirming the correct screen
    Return text only. Be concise.
```

### 6. Return results

Report to the user:
- **Result:** PASS or FAIL
- **URL fired:** The full URL tested
- **Screen loaded:** What the subagent observed
- **Navigation state:** Stack/tab context
- **Errors:** Any issues encountered

---

## Example Scenarios

| Scenario | URL | Expected |
|----------|-----|----------|
| Home screen | `myapp://home` | Home tab active |
| Product detail | `myapp://product/123` | Product screen with ID 123 |
| Nested settings | `myapp://settings/profile` | Profile under settings stack |
| Universal link | `https://myapp.com/share/abc` | Share screen with ID abc |
| Invalid path | `myapp://nonexistent` | Fallback or error screen |

## Tips

- Run `xcrun simctl list devices booted` to confirm a simulator is running before testing
- If the app isn't in the foreground, the deep link will cold-launch it — allow extra time
- Universal links require Associated Domains entitlement and an `apple-app-site-association` file
- Test both cold-start (app killed) and warm (app backgrounded) deep link scenarios
- For parameterized routes like `/product/:id`, test with real IDs from the app's data
