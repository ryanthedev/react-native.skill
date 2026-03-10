---
name: rn-coding
description: Lightweight React Native coding guidance — ensures docs are consulted before writing code and verification is suggested after. Use when writing components, implementing features, building screens, or adding views. Triggers on "write a component", "implement this feature", "build this screen", "add a view", "React Native code".
allowed-tools: Read, Grep, Glob
---

# Skill: rn-coding

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `rn-coding v{version}` before proceeding.

Lightweight coding guidance for React Native development. This skill does NOT run code -- it ensures docs are consulted before writing and verification is suggested after.

---

## Docs Location

```
${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/docs/
```

Same docs corpus as rn-docs.

## Workflow Checklist

Read `${CLAUDE_SKILL_DIR}/references/workflow-checklist.md` for the full step-by-step checklist.

---

## Workflow

### Before Writing

1. Identify which RN APIs and components the task involves
2. Grep the docs directory for those APIs (component docs, layout props, platform behavior)
3. Read relevant doc files (max 3 most relevant)
4. Note any platform differences (iOS vs Android), deprecation warnings, or required props

### While Writing

1. Follow patterns from the docs, not from memory or guessing
2. Use correct prop types and required props
3. Note platform-specific behavior inline with `Platform.OS` checks where needed
4. Follow New Architecture patterns if the project uses new arch (check for Fabric/Turbo Module config)

### After Writing

Suggest verification steps (text suggestions, not tool invocations):

- "Run `rn-layout-check` to verify visual layout"
- "Run `rn-a11y-audit` to check accessibility"
- "Use `rn-debug` to check for console errors"

If errors are reported: "Use `rn-diagnose` to diagnose the error"

### When Errors Occur

When you encounter errors during development, these resources help interpret and resolve them:

- Read `${CLAUDE_SKILL_DIR}/references/callstack-guide.md` for how to read React Native stack traces
- Use `metro.sh symbolicate` for raw/numeric stack traces from crash logs or bundle output
- Use `rn-diagnose` for automated error diagnosis against 24 known patterns

---

## Tips

- This skill complements rn-docs: rn-docs is for answering questions, rn-coding is for guiding implementation
- Always check if the component or API has platform-specific behavior
- Prefer functional components with hooks over class components
- Check for required vs optional props before using a component
