---
description: "React Native coding guidance — consults docs before writing, diagnoses errors, verifies via simulator."
argument-hint: "[task — e.g. 'build a FlatList component', 'implement settings screen']"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Agent", "Skill"]
---

# /coding

**Dispatch the coding agent for autonomous React Native development support.**

---

## Invoke Agent

```
Agent tool:
- subagent_type: "react-native-foundations:coding-agent"
- description: "RN coding: [task summary]"
- prompt: |
    TASK: [user's request]

    Write React Native code for this task. You have access to:
    - Official RN docs (load via Skill)
    - Error diagnosis (load via Skill)
    - iOS Simulator control (load via Skill)

    Follow the coding agent workflow: search docs first, write code,
    diagnose any errors, verify on simulator.
```
