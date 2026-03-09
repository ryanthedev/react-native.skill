---
name: rn-a11y-audit
description: Audit accessibility of the running React Native app. Captures the accessibility tree from the iOS Simulator and checks it against React Native best practices. Triggers on "audit accessibility", "check a11y", "VoiceOver check", "accessibility issues", "screen reader test", "are labels correct".
allowed-tools: Bash, Read, Grep, Agent
---

# Skill: rn-a11y-audit

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `rn-a11y-audit v{version}` before proceeding.

Audit the accessibility tree of a running React Native app in the iOS Simulator against official React Native accessibility documentation.

---

## Severity Levels

| Level | Meaning | Examples |
|-------|---------|----------|
| **Critical** | Blocks screen reader users | Interactive element without `accessibilityLabel`; image without label |
| **Warning** | Degrades experience | Touch target < 44x44pt; missing `accessibilityRole` on button |
| **Info** | Improvement opportunity | Missing `accessibilityHint`; elements that could be grouped |

---

## Workflow

### Step 1 — Capture and audit the accessibility tree (subagent)

Never load the accessibility tree in main context. Dispatch a subagent.

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "rn-a11y-audit: capture and analyze accessibility tree"
  prompt: |
    You are auditing the accessibility of a React Native app running in the iOS Simulator.

    1. Run: ${CLAUDE_SKILL_DIR}/../ios-sim/scripts/ui.sh describe-all
       This outputs the full accessibility tree as JSON.

    2. Read the checklist: ${CLAUDE_SKILL_DIR}/references/a11y-checklist.md

    3. Walk every element in the tree. Check for these issues:

       CRITICAL:
       - Interactive elements (buttons, links, switches, text fields) without accessibilityLabel
       - Images without an accessibility label
       - Elements with an accessibilityLabel that is just a filename or empty string

       WARNING:
       - Interactive elements without accessibilityRole or role
       - Touch targets smaller than 44x44 points (check frame width/height)
       - Nested accessible elements (accessible parent containing accessible children)
       - Toggle/checkbox elements missing accessibilityState

       INFO:
       - Interactive elements missing accessibilityHint
       - Potential grouping opportunities (adjacent related elements)
       - Static text elements that could use a header role

    4. Return a structured text report in this exact format:

       ACCESSIBILITY AUDIT REPORT
       ==========================
       Total elements scanned: <N>
       Issues found: <N> critical, <N> warning, <N> info

       CRITICAL ISSUES
       ---------------
       1. [element description] at (x, y) — Missing accessibilityLabel
          Fix: Add accessibilityLabel="<suggested label>"
       ...

       WARNINGS
       --------
       1. [element description] at (x, y) — Touch target too small (WxH)
          Fix: Add hitSlop or increase padding to at least 44x44pt
       ...

       INFO
       ----
       1. [element description] — Missing accessibilityHint
          Suggestion: Add accessibilityHint="<suggested hint>"
       ...

       If no issues in a category, write "None found."
    Return text only. Be thorough but concise.
```

### Step 1.5 — React A11y Props (optional)

If Metro/Hermes debugger is available, extract React-declared accessibility props from the fiber tree and compare against the native accessibility tree from Step 1.

**Guard:** Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status`. If exit code is 1 (Metro not running), skip silently to Step 2.

**If Metro is running:**

Dispatch a subagent that:

1. Runs `${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js tree` (full fiber tree output)
2. Extracts a11y props from each component: `accessible`, `accessibilityLabel`, `accessibilityRole`, `accessibilityHint`, `accessibilityState`, `accessibilityValue`, `importantForAccessibility`, `role`, `aria-label`, `aria-hidden`
3. Compares React-declared a11y props against the native accessibility tree report from Step 1 (passed to subagent as context)
4. Returns a DISCREPANCIES report listing:
   - Components with React a11y props that don't appear in native tree
   - Components in native tree missing expected React a11y props
   - Mismatches between declared labels/roles and native values

> Why subagent: Full fiber tree is 10-100 KB, too large for main context. The subagent processes it and returns only the discrepancy report (~1-3 KB).

### Step 2 — Enrich with documentation references

After the subagent returns its report, grep the React Native docs for relevant best practices. If CDP data is available from Step 1.5, add a DISCREPANCIES section comparing React-declared props against native a11y tree values.

```
Grep "${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/docs/accessibility.md" for key terms
from the audit (e.g., accessibilityLabel, accessibilityRole, accessibilityHint).
```

Read specific sections only if needed to provide accurate fix guidance.

### Step 3 — Present final report

Combine the subagent audit report with doc references:
- Show the full issue list with counts by severity
- For each critical issue, include the fix with a citation to `accessibility.md`
- Summarize top 3 actions to improve accessibility
- If the app has zero critical issues, congratulate the developer

---

## Context Efficiency

| Item | Size | In Main Context? |
|------|------|------------------|
| Accessibility tree JSON | ~10-100 KB | NEVER — subagent only |
| Audit checklist | ~4 KB | Subagent only |
| Subagent text report | ~1-3 KB | YES |
| CDP a11y discrepancy report | ~1-3 KB | YES (from subagent) |
| Doc grep results | ~200-500 chars | YES |

---

## Tips

- The iOS Simulator must be booted with an app running. Use `ios-sim` skill to launch if needed.
- Point coordinates from the accessibility tree are in logical points, not pixels.
- Touch target audit uses the element's `frame` dimensions from the tree.
- For Android-specific audits (48x48dp), a physical device or emulator with `adb` is needed (not covered by this skill).
