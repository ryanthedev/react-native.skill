---
name: layout-check
description: Verify visual layout against React Native Flexbox and style documentation. Captures the simulator screen in a subagent, analyzes element positions and spacing, and cross-references against official docs. Triggers on "does this look right", "check the layout", "why is this overflowing", "verify the spacing", "the UI looks wrong", "layout issue", "flexbox problem".
allowed-tools: Bash, Read, Grep, Agent
---

# Skill: layout-check

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `layout-check v{version}` before proceeding.

Verify visual layout against React Native's official Flexbox and style documentation.

---

## Dependencies

| Skill / Resource | Why |
|------------------|-----|
| `ios-sim` | `capture.sh view` captures the simulator screenshot; `ui.sh describe-all` provides element positions from the accessibility tree |
| `_shared` (metro.sh, cdp-bridge.js) | Optional Step 1.5 — reads computed style values from the React fiber tree via CDP when Metro is running |

---

## Workflow

### Step 1 — Capture and Analyze (subagent)

Dispatch a subagent to capture the screen and analyze layout. Never load screenshots or accessibility trees in main context.

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "layout-check: capture and analyze layout"
  prompt: |
    You are analyzing an iOS Simulator screen for React Native layout issues.

    1. Run: ${CLAUDE_SKILL_DIR}/../ios-sim/scripts/capture.sh view
       Read the output file path to see the screenshot.
    2. Run: ${CLAUDE_SKILL_DIR}/../ios-sim/scripts/ui.sh describe-all
       Parse the full accessibility tree JSON.
       If this fails (e.g., "AXe is not installed" error), skip the accessibility tree
       and proceed with screenshot-only analysis. Note in your report that element
       positions are estimated from visual inspection, not the accessibility tree.
    3. Analyze and return a structured report:

       ELEMENT POSITIONS:
       - List each visible element with its frame (x, y, width, height)
       - Note parent-child nesting where relevant

       SPACING ANALYSIS:
       - Gaps between sibling elements
       - Padding/margin indicators (distance from element edge to content)
       - Alignment within rows/columns

       POTENTIAL ISSUES:
       - Elements clipped or extending beyond parent bounds (overflow)
       - Unexpected sizing (zero-width, zero-height, stretched beyond screen)
       - Misaligned elements that should share an axis
       - Overlapping elements that likely should not overlap
       - Text truncation or elements pushed off-screen

    Return text only. Be concise but precise with coordinates.

    USER CONCERN: [insert user's layout question here]
```

### Step 1.5 — Computed Styles (optional)

If Metro/Hermes debugger is available, extract actual computed style values from the React fiber tree to compare against visual observations.

**Guard:** Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status`. If exit code is 1 (Metro not running), skip silently to Step 2.

**If Metro is running:**

Run `${CLAUDE_SKILL_DIR}/../_shared/scripts/cdp-bridge.js eval` with an inline JS expression that:

1. Accesses `__REACT_DEVTOOLS_GLOBAL_HOOK__`
2. Iterates `hook.renderers` to find all registered renderer IDs, then calls `hook.getFiberRoots(id)` for each (do NOT hardcode renderer ID 1 — it varies with new architecture)
3. Walks the fiber tree starting from `root.current`
4. For each fiber node:
   - Gets the component name (`type.displayName` or `type.name`)
   - Reads `memoizedProps.style`
   - Filters to target props only: `flexDirection`, `justifyContent`, `alignItems`, `flex`, `alignSelf`, `flexWrap`, `backgroundColor`, `borderWidth`, `borderColor`, `borderRadius`
   - Skips nodes with no style props or empty filtered result
5. Returns array of `{name, styles}` objects
6. Limits output by only including components with non-empty filtered styles

Save the output as "computed styles" for use in Step 2.

> The expression handles both resolved style objects and StyleSheet numeric IDs (fiber stores resolved values in dev mode). Output is compact (~1-3 KB) so it stays in main context (no subagent needed).

### Step 2 — Search docs for relevant properties

In the main context, grep the docs for layout properties related to the subagent's findings. If computed styles are available from Step 1.5, compare visual observations against actual flex/style values to confirm or refine the diagnosis.

```
Docs path: ${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/

Key files to check:
- flexbox.md        — flex, flexDirection, justifyContent, alignItems, flexWrap
- style.md          — style composition, transforms
- layout-props.md   — position, overflow, zIndex, aspect ratio, insets
- dimensions.md     — window vs screen, onLayout
```

Use Grep against the docs directory to find specific property docs relevant to the reported issue.

### Step 3 — Diagnose and recommend

Match the subagent findings against documentation to identify root cause. Return:

1. **Visual assessment** — what the subagent observed
2. **Suspected issue** — the layout property or combination causing the problem
3. **Fix** — concrete code change with cited Flexbox/style property from docs

---

## Context Efficiency

| Item | Size | Location |
|------|------|----------|
| Screenshot JPEG | ~100-300 KB | Subagent only |
| Accessibility tree JSON | ~10-100 KB | Subagent only |
| Subagent layout summary | ~500-1500 chars | Main context |
| Computed styles JSON | ~1-3 KB | Main context |
| Doc snippets from Grep | ~200-800 chars | Main context |

## Common Layout Issues Reference

| Symptom | Likely Cause | Key Property | Doc File |
|---------|-------------|-------------|----------|
| Children overflow container | Missing `overflow: 'hidden'` or unbounded flex | `overflow`, `flex` | layout-props.md, flexbox.md |
| Items won't wrap to next line | `flexWrap` defaults to `'nowrap'` | `flexWrap: 'wrap'` | flexbox.md |
| Item ignores width/height | Flex basis or flex overriding explicit size | `flex`, `flexBasis` | flexbox.md |
| Absolute element mispositioned | Wrong `position: 'absolute'` anchor or missing parent size | `position`, `top/left/right/bottom` | layout-props.md |
| Element has zero size | No children, no explicit dimensions, `flex: 0` | `width`, `height`, `flex` | layout-props.md, dimensions.md |
| Uneven spacing between items | Using margins vs `gap`; wrong `justifyContent` | `gap`, `justifyContent` | flexbox.md |
| Text truncated unexpectedly | Container has fixed width without `flexShrink` | `flexShrink`, `numberOfLines` | flexbox.md |
| Items not centering | Wrong axis — `justifyContent` vs `alignItems` | `justifyContent`, `alignItems` | flexbox.md |

## Tips

- RN defaults: `flexDirection: 'column'`, `alignItems: 'stretch'`, `position: 'relative'` — different from CSS defaults.
- `flex: 1` in RN is shorthand for `flexGrow: 1, flexShrink: 1, flexBasis: 0` — not the same as CSS `flex: 1`.
- `overflow` defaults to `'hidden'` on Android, `'visible'` on iOS.
- Percentage dimensions require the parent to have a defined size in that axis.
