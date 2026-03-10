# Pseudocode: Phase 2c - Integration

## Files to Modify
1. `skills/rn-diagnose/SKILL.md` -- add Step 0 (Metro health check)
2. `skills/rn-diagnose/references/error-patterns.md` -- add Metro connectivity patterns
3. `.claude/settings.local.json` -- add new skill permissions + shared scripts glob
4. `.claude-plugin/plugin.json` -- bump version to v0.2.0, update description

---

## Pseudocode

### 1. skills/rn-diagnose/SKILL.md

**Goal:** Insert a Step 0 before existing Step 1 that checks Metro health before deep diagnosis.

**Changes:**

A. In the Error Pattern Database section, add a note that metro.sh is available:
   - After the existing pattern DB reference line, add a line noting that Step 0 uses metro.sh for live health checks

B. Insert new section "Step 0: Metro Health Check" BEFORE "Step 1: Obtain Error Text":
   - Purpose comment: "Before deep diagnosis, check if the development environment is healthy"
   - Three substeps:
     1. Run metro.sh status to check if Metro is running
        - Script path: ${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status
        - If Metro is not running: note this as a potential root cause, suggest "npx react-native start"
        - If Metro is running: proceed to bundle check
     2. Run metro.sh bundle-check to test if the JS bundle compiles
        - Script path: ${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh bundle-check --platform ios
        - If exit code is non-zero (500 response): capture error body for pattern matching in Step 2
        - If bundle builds successfully: Metro environment is healthy, proceed
     3. If user provides a raw stack trace: run metro.sh symbolicate before pattern matching
        - Pipe the stack trace JSON to metro.sh symbolicate via stdin
        - Use symbolicated output for pattern matching instead of raw trace
   - Add a note: "If Step 0 finds Metro is down or bundle fails, this is often the root cause. Report it immediately rather than proceeding through all steps."

C. Renumber nothing -- keep existing steps as Step 1-5. Step 0 is intentionally numbered zero to indicate it runs first without renumbering existing steps.

D. In the Routing Table, add a row:
   - Error Category: "Metro / environment issue"
   - Source: "Any"
   - Workflow: "**Step 0** (metro health) -> pattern-match if bundle error"

E. In Context Efficiency table, add a row:
   - Item: "Metro health check"
   - Size: "~50 chars"
   - In Main Context?: "YES (small output)"

### 2. skills/rn-diagnose/references/error-patterns.md

**Goal:** Add Metro connectivity patterns that Step 0 would surface.

**Changes:**

Add a new subsection under "Metro Bundler Errors" after pattern 4 (Metro Syntax/Transform Error). This uses a numbering approach that slots new patterns in logically. Since there are 18 patterns already, number new ones starting at 19.

New patterns to add:

#### Pattern 19: Metro Not Reachable
- Match: "Could not connect to development server", "connection refused", "ECONNREFUSED", "Unable to load script", "Could not connect to the server"
- Cause: Metro bundler is not running, crashed, or listening on a different port. App cannot fetch JS bundle.
- Fix:
  - Check if Metro is running: metro.sh status
  - If not running: npx react-native start
  - If running on a different port: check RCT_METRO_PORT or pass --port to Metro
  - On physical device: ensure Metro host is set correctly (shake menu -> Dev Settings -> Debug server host)

#### Pattern 20: Metro Bundle Download Timeout
- Match: "Could not get BatchedBridge", "Running.*took too long", "Bundling failed", "Network request failed"
- Cause: Metro is running but bundle download timed out. Large bundle, slow machine, or incorrect network config.
- Fix:
  - Check bundle compiles: metro.sh bundle-check --platform ios
  - If bundle compiles but device cannot reach: check same-network connectivity
  - Clear Metro cache: npx react-native start --reset-cache
  - For slow builds: ensure Hermes bytecode precompilation is enabled

#### Pattern 21: Metro WebSocket Disconnected
- Match: "WebSocket connection.*closed", "HMR.*disconnected", "Lost connection to Metro"
- Cause: Hot Module Replacement WebSocket lost connection. Metro crashed, network changed, or device went to sleep.
- Fix:
  - Reload the app (Cmd+R in simulator, shake menu on device)
  - If Metro crashed: restart with npx react-native start
  - Check metro.sh status to confirm Metro is alive

### 3. .claude/settings.local.json

**Goal:** Add permissions for the two new skills and an explicit shared scripts glob.

**Changes:**

Add to the "allow" array:
- "Skill(react-native-foundations:rn-debug)" -- after the existing 7 skill entries
- "Skill(react-native-foundations:rn-coding)" -- after rn-debug
- "Bash(*/skills/_shared/scripts/*)" -- after the existing Bash glob entry

The existing "Bash(*/skills/*/scripts/*)" technically covers _shared already, but adding the explicit entry makes the permission discoverable and documents the intent.

Final allow array order:
1. Skill entries (9 total, alphabetical or grouped: existing 7 + rn-coding + rn-debug)
2. Read, Grep, Glob
3. Bash(*/skills/*/scripts/*) -- existing
4. Bash(*/skills/_shared/scripts/*) -- new, explicit

### 4. .claude-plugin/plugin.json

**Goal:** Bump version and update description to reflect Phase 2 additions.

**Changes:**

- "version": "0.1.0" -> "0.2.0"
- "description": Update to mention debug and coding skills alongside existing capabilities
  - New description: "React Native foundation skills -- documentation search, diagnosis, debugging, coding guidance, and development tooling"

No structural changes. Keep name, author, license, keywords unchanged.

---

## Design Notes

### Why Step 0 instead of modifying Step 1
The plan explicitly calls it "Step 0" which is intentional -- it runs before the existing diagnostic workflow. Inserting it as Step 0 avoids renumbering existing steps (which would break any external references to "Step 3: Search Official Docs" etc.).

### Why explicit _shared Bash glob
The existing `Bash(*/skills/*/scripts/*)` pattern technically matches `_shared/scripts/*`. However, `_shared` is a convention-breaking directory name (not a skill, starts with underscore). Making the permission explicit documents that shared scripts are intentionally permitted, not accidentally matched.

### Pattern numbering (19-21)
New patterns are numbered 19-21 to avoid renumbering existing 1-18. They slot into the Metro Bundler Errors category conceptually, but are placed at the end of the file to keep the diff clean and avoid disrupting existing pattern references.

### plugin.json version bump rationale
v0.1.0 -> v0.2.0 (minor bump) reflects new capabilities (2 new skills, shared scripts, enhanced diagnosis) without breaking changes to existing skills.

---

## PRE-GATE Status
- [x] Discovery complete
- [x] Pseudocode complete
- [x] Design reviewed (information hiding: metro.sh abstracts health checks; Step 0 hides Metro complexity from diagnosis flow)
- [x] Ready for implementation
