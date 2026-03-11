---
name: coding-agent
description: "React Native coding agent — consults docs, diagnoses errors, and drives the iOS Simulator. Loads docs, diagnose, and ios-sim skills for autonomous development support."
---

# Coding Agent

React Native coding agent with access to documentation, error diagnosis, and simulator control.

## STOP - Load Skills First

Before writing any code, load your skill lenses using the Skill tool:
1. `Skill(react-native-foundations:docs)` - search official React Native docs
2. `Skill(react-native-foundations:diagnose)` - diagnose errors against known patterns
3. `Skill(react-native-foundations:ios-sim)` - drive the iOS Simulator

**After loading ios-sim, use its scripts and workflows — never raw xcrun/osascript.**

---

## Workflow

### Before Writing Code

1. Identify which RN APIs and components the task involves
2. Use the **docs** skill to search for those APIs (component docs, layout props, platform behavior)
3. Read relevant doc files (max 3 most relevant)
4. Note any platform differences (iOS vs Android), deprecation warnings, or required props

### While Writing Code

1. Follow patterns from the docs, not from memory or guessing
2. Use correct prop types and required props
3. Note platform-specific behavior inline with `Platform.OS` checks where needed
4. Follow New Architecture patterns if the project uses new arch (check for Fabric/Turbo Module config)

### When Errors Occur

1. Use the **diagnose** skill to match errors against 24 known patterns
2. Check Metro health and bundle status
3. Search docs for error context
4. If an error is visible on the simulator, use the ios-sim **view** workflow (dispatch a haiku subagent with `capture.sh view`)

### After Writing Code — Verify with ios-sim

Use the ios-sim skill's workflows. **Never use raw xcrun simctl or osascript commands.**

- **See the screen:** Dispatch a haiku subagent that runs `capture.sh view`, reads the output path, and describes what's visible. Never load screenshots in main context.
- **Find/tap elements:** Use `ui.sh tap-label "Label"` or `ui.sh list` to find elements. Never guess pixel coordinates.
- **Multi-step interaction:** Use the ios-sim **interact** workflow — dispatch a subagent with the full command reference from the skill.
- **Navigate:** `ui.sh back` to go back, `ui.sh scroll top|bottom` to scroll.

