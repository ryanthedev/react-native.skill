---
name: coding
description: React Native coding guidance — consults official docs before writing code and suggests verification after. Use when writing components, implementing features, building screens, fixing queries, or adding views. Triggers on "write a component", "implement this feature", "build this screen", "add a view", "React Native code", "fix this query", "use best practices".
allowed-tools: Read, Grep, Glob, Skill
---

# Skill: coding

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `coding v{version}` before proceeding.

React Native coding guidance that ensures docs are consulted before writing code and verification is suggested after.

---

## Step 1: Load Docs

Load the docs skill immediately:

```
Skill(react-native-foundations:docs)
```

---

## Step 2: Search Docs First

Before writing any code:

1. Identify which RN APIs and components the task involves
2. Grep `${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/` for those APIs
3. Read relevant doc files (max 3 most relevant)
4. Note platform differences, deprecation warnings, or required props

---

## Step 3: Write Code

1. Follow patterns from the docs, not from memory or guessing
2. Use correct prop types and required props
3. Note platform-specific behavior inline with `Platform.OS` checks where needed
4. Follow New Architecture patterns if the project uses new arch (check for Fabric/Turbo Module config)

---

## Step 4: Verify

After implementation, suggest verification:

- "`/react-native-foundations:layout-check` to verify visual layout"
- "`/react-native-foundations:a11y-audit` to check accessibility"
- "`/react-native-foundations:debug` to check for console errors"
- If errors: "`/react-native-foundations:diagnose` to diagnose"

---

## Common Gotchas

- FlatList requires `keyExtractor` or `key` prop on items
- ScrollView inside FlatList causes performance issues
- Absolute positioning works differently than web CSS
- StatusBar behavior differs iOS vs Android
- SafeAreaView only works on iOS (use `react-native-safe-area-context` for cross-platform)
- Dimensions API returns points not pixels on iOS (3x on Retina)
- TextInput `onChangeText` gives string, `onChange` gives event object
- Prefer Pressable over TouchableOpacity (newer, more flexible)
- `flex: 1` in RN is `flexGrow: 1, flexShrink: 1, flexBasis: 0` — not the same as CSS
- `overflow` defaults to `hidden` on Android, `visible` on iOS
- `fetch(fileUri).blob()` produces 0-byte blobs on RN — use FormData with `{ uri, type, name }` for file uploads

