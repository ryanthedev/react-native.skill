# Pseudocode: Phase 2b - New Skills

## Files to Create/Modify

1. `skills/rn-debug/SKILL.md` -- new file
2. `skills/rn-debug/references/metro-endpoints.md` -- new file
3. `skills/rn-coding/SKILL.md` -- new file
4. `skills/rn-coding/references/workflow-checklist.md` -- new file

## Design: rn-debug SKILL.md

### Approaches Considered

1. **Flat routing** -- Single routing table mapping intent to script+flags, with inline fallback notes per row. Similar to ios-sim's "Direct Commands" table.
2. **Tiered routing** -- Two-tier structure: first a "Metro check" gate, then routing table. Fallback logic in a dedicated section. Subagent dispatch blocks as named workflows (like ios-sim's view/inspect/interact).
3. **Decision-tree routing** -- Flowchart-style: "Is Metro running? -> Yes: CDP path / No: fallback path". Each branch has its own table.

### Comparison

| Criterion | Flat | Tiered | Decision-tree |
|-----------|------|--------|---------------|
| Interface simplicity | High -- one table | Medium -- two sections | Low -- branching |
| Fallback clarity | Low -- inline notes | High -- dedicated section | High -- visual |
| Consistency with existing skills | Medium | High (matches ios-sim) | Low (new pattern) |
| Caller ease of use | Medium | High | Medium |

### Choice: Tiered (Approach 2)

Rationale: Matches the ios-sim convention of named workflows + routing table. The Metro-check gate is a natural prerequisite step, not a branching decision. Sacrifices the compactness of flat routing, but gains clear fallback logic and consistency with existing skills.

### Depth Check
- Interface: ~7 routing entries (matching plan's 7 intents)
- Hidden details: Metro port resolution, WebSocket discovery, CDP protocol, log stream filtering
- Common case complexity: Simple -- user says "show console logs", skill checks Metro, dispatches appropriate script

## Pseudocode

### skills/rn-debug/SKILL.md

```
FRONTMATTER:
  name: rn-debug
  description: [include trigger words from plan: "console logs", "JS errors",
    "Metro status", "evaluate expression", "React component tree",
    "network requests", "debug"]
  allowed-tools: Bash, Read, Agent

ON-LOAD:
  Read plugin.json from ../../.claude-plugin/plugin.json
  Display "rn-debug v{version}"

CONTEXT WARNING:
  Bold block: console streams, component trees, and network logs
  can be large. Always use subagent for streaming/tree operations.

PREREQUISITES:
  - Metro bundler (for CDP features; logs.sh works without it)
  - Node 22+ (for cdp-bridge.js only)
  - Read references/metro-endpoints.md for Metro HTTP API details

SCRIPT PATHS:
  Define the shared scripts path: ${CLAUDE_SKILL_DIR}/../_shared/scripts/
  List all three scripts with their purposes

ROUTING TABLE (7 rows matching plan):
  | Intent               | Script                           | Subagent? |
  | Check Metro health   | metro.sh status                  | No        |
  | View console output  | logs.sh OR cdp-bridge.js console | Yes       |
  | Evaluate JS expr     | cdp-bridge.js eval "expr"        | No        |
  | Inspect React tree   | cdp-bridge.js tree               | Yes       |
  | Monitor network      | cdp-bridge.js network            | Yes       |
  | Check bundle health  | metro.sh bundle-check            | No        |
  | Symbolicate stack    | metro.sh symbolicate             | No        |

FALLBACK LOGIC SECTION:
  Before any CDP operation (eval, tree, network, cdp console):
    Run metro.sh status first
    If Metro is down:
      If intent is console logs:
        Fall back to logs.sh (works without Metro via OS-level capture)
        Note this in output to user
      If intent requires CDP (eval, tree, network):
        Report error: "Metro is not running"
        Suggest: "npx react-native start"
        Do NOT attempt the CDP operation

WORKFLOW: Console Logs
  When: "show console logs", "JS errors", "what's in the console"
  Step 1: Run metro.sh status to check Metro
  Step 2a (Metro running): Dispatch subagent with cdp-bridge.js console --timeout 10
  Step 2b (Metro not running): Dispatch subagent with logs.sh ios --timeout 10
  Subagent prompt template:
    Run the script
    Parse NDJSON output
    Summarize: error count, warning count, notable log entries
    Return concise text summary

WORKFLOW: Evaluate Expression
  When: "evaluate", "run this JS", "check state"
  Direct (no subagent -- output is small):
    Run metro.sh status
    If running: Run cdp-bridge.js eval "expression"
    Return JSON result directly

WORKFLOW: Component Tree
  When: "React tree", "component tree", "find component"
  Dispatch subagent:
    Run cdp-bridge.js tree [--find "ComponentName" if specified]
    Parse JSON tree
    Summarize: component hierarchy, props/state for matches
    Return concise text summary

WORKFLOW: Network Monitor
  When: "network requests", "API calls", "what's being fetched"
  Dispatch subagent:
    Run cdp-bridge.js network --timeout 10
    Parse NDJSON events
    Summarize: request count, URLs, status codes, notable failures
    Return concise text summary

CONTEXT EFFICIENCY TABLE:
  | Item                    | Size          | Main Context? |
  | Metro status            | ~20 chars     | Yes           |
  | JS eval result          | ~100-1000     | Yes           |
  | Console log stream      | ~1-50 KB      | NEVER         |
  | React component tree    | ~10-100 KB    | NEVER         |
  | Network request log     | ~5-50 KB      | NEVER         |
```

### skills/rn-debug/references/metro-endpoints.md

```
TITLE: Metro Bundler HTTP Endpoints

PURPOSE: Quick reference for Metro's HTTP API.
  Used by metro.sh and cdp-bridge.js under the hood.
  Useful for manual debugging when scripts don't cover a case.

PORT RESOLUTION:
  Document the three-tier priority: --port flag > RCT_METRO_PORT env > 8081

ENDPOINTS TABLE:
  | Endpoint                            | Method | Purpose                        |
  | /status                             | GET    | Health check ("packager-status:running") |
  | /json/list                          | GET    | List debuggable CDP WebSocket targets    |
  | /index.bundle?platform=ios&dev=true | GET    | Build JS bundle (200=OK, 500=error)      |
  | /symbolicate                        | POST   | Symbolicate stack trace (JSON body)      |

For each endpoint:
  - Example curl command
  - Example response (abbreviated)
  - Error case (what happens when Metro is down or bundle fails)

SYMBOLICATE REQUEST FORMAT:
  Document the JSON body structure: { "stack": [ { "file": "...", "lineNumber": N, "column": N } ] }

CDP WEBSOCKET:
  Explain that /json/list returns targets with webSocketDebuggerUrl
  This is how cdp-bridge.js auto-discovers the WebSocket connection
  Note: same protocol as Chrome DevTools -- standard CDP messages
```

### skills/rn-coding/SKILL.md

```
FRONTMATTER:
  name: rn-coding
  description: [include trigger words from plan: "write a component",
    "implement this feature", "build this screen", "add a view",
    "React Native code"]
  allowed-tools: Read, Grep, Glob
  NOTE: No Bash, no Agent -- this is a lightweight guidance skill

ON-LOAD:
  Read plugin.json from ../../.claude-plugin/plugin.json
  Display "rn-coding v{version}"

NATURE STATEMENT:
  This skill provides lightweight coding guidance -- it does NOT run code.
  It ensures docs are consulted before writing and verification is suggested after.

DOCS LOCATION:
  ${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/docs/
  (Same docs corpus as rn-docs)

WORKFLOW CHECKLIST REFERENCE:
  Read ${CLAUDE_SKILL_DIR}/references/workflow-checklist.md for the full checklist

WORKFLOW (3 phases from plan):

  BEFORE WRITING:
    1. Identify which RN APIs/components the task involves
    2. Grep docs directory for those APIs (component docs, layout props, platform behavior)
    3. Read relevant doc files (max 3 most relevant)
    4. Note any platform differences (iOS vs Android), deprecation warnings, or required props

  WHILE WRITING:
    1. Follow patterns from the docs, not from memory/guessing
    2. Use correct prop types and required props
    3. Note platform-specific behavior inline with Platform.OS checks where needed
    4. Follow New Architecture patterns if project uses new arch (check for fabric/turbo module config)

  AFTER WRITING:
    Suggest verification steps (text suggestions, not tool invocations):
    - "Run rn-layout-check to verify visual layout"
    - "Run rn-a11y-audit to check accessibility"
    - "Use rn-debug to check for console errors"
    If errors are reported: "Use rn-diagnose to diagnose the error"

TIPS:
  - This skill complements rn-docs: rn-docs is for answering questions,
    rn-coding is for guiding implementation
  - Always check if the component/API has platform-specific behavior
  - Prefer functional components with hooks over class components
  - Check for required vs optional props before using a component
```

### skills/rn-coding/references/workflow-checklist.md

```
TITLE: React Native Coding Workflow Checklist

PURPOSE: Step-by-step checklist for writing React Native code.
  Referenced by rn-coding SKILL.md.

BEFORE YOU CODE:
  [ ] Identified all RN APIs and components needed
  [ ] Searched docs for each API (grep refs/react-native-docs/docs/)
  [ ] Read relevant doc files for props, usage patterns, caveats
  [ ] Noted platform differences (iOS vs Android behavior)
  [ ] Checked if any APIs are deprecated or have migration notes
  [ ] Identified required vs optional props for each component

WHILE CODING:
  [ ] Using correct import paths (react-native vs platform-specific)
  [ ] Following patterns from official docs, not guessing at APIs
  [ ] Handling platform differences with Platform.OS or Platform.select
  [ ] Using proper TypeScript types for props and state (if TS project)
  [ ] Following project's existing patterns for navigation, state management, styling

AFTER CODING:
  [ ] Suggest: rn-layout-check for visual verification
  [ ] Suggest: rn-a11y-audit for accessibility check
  [ ] Suggest: rn-debug for console error monitoring
  [ ] If errors: direct to rn-diagnose

COMMON GOTCHAS:
  - FlatList requires keyExtractor or key prop on items
  - ScrollView inside FlatList causes performance issues
  - Absolute positioning works differently than web CSS
  - StatusBar behavior differs iOS vs Android
  - SafeAreaView only works on iOS (use react-native-safe-area-context for cross-platform)
  - Dimensions API returns points not pixels on iOS (3x on Retina)
  - TextInput onChangeText gives string, onChange gives event object
  - TouchableOpacity vs Pressable: prefer Pressable (newer, more flexible)
```

## Design Notes

### rn-debug: Deep Module Properties
- **Interface:** 7 intents in routing table (matches plan exactly)
- **Hidden complexity:** Metro port resolution, WebSocket discovery, CDP protocol, NDJSON parsing, OS-level log stream filtering, timeout management
- **Common case:** User says "show me console logs" -> skill checks Metro -> dispatches one script -> returns summary. One sentence from user, one summary back.

### rn-coding: Intentionally Shallow
- **By design:** This is a guidance skill, not a tool-routing skill. Its value is in the workflow discipline (check docs first, suggest verification after), not in hiding complexity.
- **No Bash/Agent:** Enforced by `allowed-tools: Read, Grep, Glob`. Cannot run scripts or dispatch subagents.
- **Relationship to rn-docs:** rn-coding is the "proactive" counterpart to rn-docs. rn-docs answers questions; rn-coding ensures questions get asked before writing code.

### Subagent Dispatch Consistency
- All subagent dispatch blocks follow the ios-sim convention: fenced code with `Dispatch Agent:` header
- haiku model for simple parsing tasks (console log summary, tree summary)
- No model specified for complex tasks (omit = use user's current model)

### Script Path Convention
- First skill to use `_shared/scripts/` path
- Convention: `${CLAUDE_SKILL_DIR}/../_shared/scripts/` from any skill directory
- This will be validated in Phase 2c when rn-diagnose also references shared scripts

## PRE-GATE Status
- [x] Discovery complete
- [x] Pseudocode complete
- [x] Design reviewed (tiered routing chosen over flat/decision-tree for rn-debug)
- [x] Ready for implementation
