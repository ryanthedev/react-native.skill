---
name: ios-sim
description: Control the iOS Simulator — tap, type, swipe, screenshot, record video, install and launch apps. Use when interacting with the iOS simulator during React Native development. Triggers on "simulator", "tap", "swipe", "screenshot of simulator", "install app", "launch app", "what's on screen", "record video", "accessibility tree", "tap by label", "tap by id", "list elements", "go back", "scroll to top", "scroll to bottom".
allowed-tools: Bash, Read, Agent
---

# Skill: ios-sim

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `ios-sim v{version}` before proceeding.

Control the iOS Simulator through shell scripts wrapping `xcrun simctl` and `AXe`.

```
IMPORTANT: Never load screenshots or accessibility trees in the main context.
Always dispatch a subagent for visual/inspection tasks.
```

---

## Used By

| Skill | What it uses |
|-------|-------------|
| `a11y-audit` | `ui.sh describe-all` for accessibility tree capture |
| `layout-check` | `capture.sh view` + `ui.sh describe-all` for screenshot and element positions |
| `diagnose` | `capture.sh view` to read error text from the simulator screen |
| `deeplink-test` | Screenshot capture to verify the screen after firing a deep link |

---

## Prerequisites

- macOS with Xcode installed
- A booted iOS simulator (`xcrun simctl list devices` to check)
- AXe (`brew install cameroncooke/axe/axe`) — required for all `ui.sh` commands (tap, tap-label, tap-id, type, swipe, describe-all, describe-point, list, back, scroll). `capture.sh view` works without AXe.
- See `${CLAUDE_SKILL_DIR}/references/troubleshooting.md` if anything is missing

## Scripts

All scripts live at `${CLAUDE_SKILL_DIR}/scripts/`. Run them with Bash.

## Routing Table

| Intent | Workflow | Why |
|--------|----------|-----|
| See what's on screen | **view** | Image stays in subagent |
| Find UI elements/coordinates | **inspect** | JSON tree stays in subagent |
| Multi-step UI interaction | **interact** | Entire loop stays in subagent |
| Simple one-shot command | **direct** | No image/tree involved |

### Direct Commands (safe for main context)

| Intent | Script | Example |
|--------|--------|---------|
| Get booted simulator ID | `device.sh booted` | `device.sh booted` |
| Open Simulator app | `device.sh open` | `device.sh open` |
| Save screenshot to file | `capture.sh screenshot <path>` | `capture.sh screenshot /tmp/shot.png` |
| Start video recording | `capture.sh record` | `capture.sh record` |
| Stop video recording | `capture.sh stop` | `capture.sh stop` |
| Install app bundle | `app.sh install <path>` | `app.sh install /path/to/App.app` |
| Launch app by bundle ID | `app.sh launch <id>` | `app.sh launch com.example.app` |
| Tap element by accessibility label | `ui.sh tap-label <label>` | `ui.sh tap-label "Login"` |
| Tap element by accessibility ID | `ui.sh tap-id <id>` | `ui.sh tap-id "submit-button"` |
| List on-screen elements (Controls/Content) | `ui.sh list` | `ui.sh list` |
| Tap the back/navigation button | `ui.sh back` | `ui.sh back` |
| Scroll to top or bottom of list | `ui.sh scroll top\|bottom` | `ui.sh scroll top` |

---

## Workflows

### 1. View (screenshot analysis)

**When:** "What's on the simulator screen?", "How does it look?", "Is there an error?"

Main agent never loads the image. Haiku does the analysis.

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "ios-sim: analyze screenshot"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/scripts/capture.sh view
       This outputs a file path to a compressed JPEG.
    2. Read that file path with the Read tool to see the image.
    3. Analyze and return:
       - Overview: What app/screen is visible (1-2 sentences)
       - Key elements: Buttons, text, inputs, navigation items
       - State: Errors, loading, forms filled, current tab
       - Coordinates: Notable interactive elements with approximate point positions
    4. If the user asked something specific, answer that directly.
    Return text only. Be concise.

    USER QUESTION: [insert user's question here]
```

### 2. Inspect (accessibility tree)

**When:** "What elements are on screen?", "Find the login button", "Where should I tap?"

The accessibility tree JSON can be massive. Parse it in a subagent.

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "ios-sim: inspect UI elements"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/scripts/ui.sh describe-all
       This outputs the full accessibility tree as JSON.
    2. Parse the JSON and return a structured summary:
       - Screen dimensions (from root frame)
       - Interactive elements: buttons, text fields, switches, links
         Format each as: "Label" [type] at (x, y) — size WxH
       - Current focus/selection state
       - Navigation structure (tabs, headers, back buttons)
    3. If looking for a specific element, report its exact coordinates.
    Return text only. Be concise.

    LOOKING FOR: [insert what the user needs to find]
```

### 3. Interact (multi-step UI automation)

**When:** "Tap the login button", "Fill in the form", "Navigate to settings"

Combines view + inspect + actions in a subagent loop. The entire interaction
stays isolated — main context only gets the final result.

```
Dispatch Agent:
  subagent_type: general-purpose
  description: "ios-sim: UI interaction"
  prompt: |
    You are automating the iOS Simulator. Scripts are at:
    ${CLAUDE_SKILL_DIR}/scripts/

    Available commands:
    - capture.sh view               → compressed screenshot (read the output path to see it)
    - ui.sh describe-all            → full accessibility tree JSON
    - ui.sh describe-point X Y      → element at coordinates
    - ui.sh tap X Y                 → tap at point coordinates
    - ui.sh tap X Y --duration S    → long press
    - ui.sh type "text"             → type ASCII text (max 500 chars)
    - ui.sh swipe X1 Y1 X2 Y2      → swipe gesture
    - ui.sh tap-label "label"       → tap element by accessibility label (no coordinate lookup needed)
    - ui.sh tap-id "id"             → tap element by accessibility ID (no coordinate lookup needed)
    - ui.sh list                    → compact table of on-screen elements grouped by Controls/Content
    - ui.sh back                    → heuristic back-button finder and tap (scores by label/position)
    - ui.sh scroll top|bottom       → repeated swipes with stabilization detection (max 10 swipes)

    TASK: [insert what the user wants to do]

    WORKFLOW:
    1. First capture.sh view to see current state
    2. Use ui.sh describe-all if you need exact coordinates
    3. Perform the requested actions
    4. capture.sh view again to verify the result
    5. Return a text summary of what you did and the final state

    RULES:
    - Use POINT coordinates from the accessibility tree, not pixel coordinates
    - After each action, verify the result before proceeding
    - If something fails, try describe-all to re-orient
    - Return text summary only — do not include base64 image data
```

---

## Tips

- All scripts auto-detect the booted simulator. Pass `--udid <UUID>` to target a specific device.
- Screenshots are 3x pixel resolution. The accessibility tree reports point coordinates. Always use point coordinates for tap/swipe.
- `ui.sh type` only accepts ASCII printable characters (max 500 chars).
- Video recording runs in the background. Use `capture.sh stop` to finish.
- For the **interact** workflow, omit `model` to use the user's current model (better reasoning for complex multi-step tasks).

## Context Efficiency

| Item | Size | In Main Context? |
|------|------|------------------|
| Screenshot JPEG | ~100-300 KB | NEVER — haiku subagent only |
| Accessibility tree JSON | ~10-100 KB | NEVER — subagent only |
| Subagent text summary | ~200-800 chars | YES |
| Direct commands (device, app) | ~50-200 chars | YES |
