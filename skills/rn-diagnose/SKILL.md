---
name: rn-diagnose
description: Diagnose React Native errors by cross-referencing error text against docs, error pattern database, and project config. Use for build failures, red screens, runtime crashes, and dependency issues. Triggers on "diagnose this error", "why is my build failing", "what does this red screen mean", "Unable to resolve module", "null is not an object", "Invariant Violation", "pod install failed", "gradlew failed", "EACCES", "metro error".
allowed-tools: Bash, Read, Grep, Glob, Agent
---

# Skill: rn-diagnose

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `rn-diagnose v{version}` before proceeding.

Diagnose React Native errors by matching against known patterns, searching official docs, and inspecting project configuration.

```
IMPORTANT: Build logs and simulator screenshots can be enormous.
Always process them in a subagent to protect main context.
```

---

## Dependencies

| Skill / Resource | Why |
|------------------|-----|
| `ios-sim` | `capture.sh view` captures red screen error text when the user says "there's an error on screen"; also used in optional post-fix verification |
| `_shared` (metro.sh) | Step 0 — Metro health check, bundle validation, stack symbolication |
| `refs/react-native-docs` | Step 3 — doc search for error context and fix guidance |

---

## Error Pattern Database

Read `${CLAUDE_SKILL_DIR}/references/error-patterns.md` for the full pattern catalog (24 patterns covering Metro, build, runtime, and dependency errors).

Step 0 uses `${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh` for live Metro health checks before deep diagnosis.

## Docs Location

```
${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/docs/
```

---

## Routing Table

| Error Category | Source | Workflow |
|----------------|--------|----------|
| User pastes error text | Direct input | **pattern-match** → docs search |
| Error visible on simulator | Simulator screen | **capture** → pattern-match → docs search |
| Build log failure | Xcode / Gradle output | **log-parse** (subagent if large) → pattern-match |
| Config / dependency issue | Project files | **config-check** → pattern-match |
| Metro / environment issue | Any | **Step 0** (metro health) → pattern-match if bundle error |
| Unknown / unclear | Any | **full-diagnosis** (all steps) |

---

## Workflow

### Step 0: Environment + Metro Health Check

Before deep diagnosis, get the environment summary and check health.

0. **Get environment context** (run once, reuse throughout):
   ```bash
   ${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh env
   ```
   Returns JSON with `metro`, `expo`, `newArch`, `entry`, `platform`. Use this to inform diagnosis — Expo and vanilla RN have different error patterns.

1. **Check if Metro is running:**
   ```bash
   ${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh status
   ```
   - If Metro is **not running**: note this as a potential root cause. For Expo projects, suggest `npx expo start`. For vanilla RN, suggest `npx react-native start`.
   - If Metro is **running**: proceed to bundle check.

2. **Check if the JS bundle compiles:**
   ```bash
   ${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh bundle-check --platform ios
   ```
   - If exit code is non-zero (500 response): capture the error body for pattern matching in Step 2.
   - If bundle builds successfully: Metro environment is healthy, proceed.

3. **Symbolicate raw stack traces (if provided):**
   If the user provides a raw stack trace, pipe the stack trace JSON to symbolicate before pattern matching:
   ```bash
   echo '<stack-trace-json>' | ${CLAUDE_SKILL_DIR}/../_shared/scripts/metro.sh symbolicate
   ```
   Use the symbolicated output for pattern matching instead of the raw trace.

```
If Step 0 finds Metro is down or the bundle fails, this is often the root cause.
Report it immediately rather than proceeding through all steps.
```

### Step 1: Obtain Error Text

**If user provides error text:** Parse it directly — extract the core error message, stripping ANSI codes and noisy stack frames.

**If user says "there's an error on screen":** Dispatch ios-sim subagent to capture it:

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "rn-diagnose: capture error from simulator"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../ios-sim/scripts/capture.sh view
       This outputs a file path to a compressed JPEG.
    2. Read that file path with the Read tool to see the image.
    3. Extract all error text visible on screen:
       - Red screen error title and message
       - Stack trace lines (file names and line numbers)
       - Any component names mentioned
    4. Return the extracted error text only. Be precise — include exact
       error messages and module names. No image descriptions needed.
```

### Step 2: Match Against Known Patterns

Read `${CLAUDE_SKILL_DIR}/references/error-patterns.md` and match the error text against the patterns. Check for substring matches on the **Match** fields.

### Step 3: Search Official Docs

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "rn-diagnose: search docs for error context"
  prompt: |
    Search React Native docs for information related to this error.

    ERROR: [insert extracted error text]

    1. Grep ${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/docs/ for key
       terms from the error (component names, API names, error codes).
    2. Read any matching files (max 3 most relevant).
    3. Return:
       - Which doc files mention this topic
       - Relevant API usage notes or caveats
       - Any documented workarounds or migration notes
    Be concise. Quote doc filenames for citation.
```

### Step 4: Check Project Config (if build/dependency error)

For build and dependency errors, read the user's project files directly:

| File | Check For |
|------|-----------|
| `package.json` | RN version, dependency versions, scripts |
| `ios/Podfile` | Hermes flag, Flipper, platform version, use_frameworks |
| `android/gradle.properties` | newArchEnabled, hermesEnabled, JVM args |
| `android/app/build.gradle` | compileSdk, targetSdk, minSdk, dependencies |
| `metro.config.js` | watchFolders, transformer, resolver config |
| `babel.config.js` | Presets, plugins (reanimated, module-resolver) |

Only read files relevant to the error category. Use Glob to find them:
```
Glob pattern: {package.json,ios/Podfile,android/gradle.properties,android/app/build.gradle,metro.config.*,babel.config.*}
```

### Step 5: Process Large Build Logs (if needed)

If the user pastes or references a large build log (>100 lines), dispatch a subagent:

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "rn-diagnose: parse build log"
  prompt: |
    Parse this build log and extract the root error.

    BUILD LOG:
    [insert log content]

    1. Skip all successful build steps and warnings.
    2. Find the FIRST fatal error or failure line.
    3. Extract: error message, file path, line number if present.
    4. Note any "required by" or dependency chain info.
    5. Return just the essential error info (under 10 lines).
```

---

## Response Format

After diagnosis, return to the user:

1. **Error:** One-line summary of what went wrong
2. **Root Cause:** Why it happened (1-2 sentences)
3. **Fix:** Concrete commands or code changes to resolve it
4. **Doc Reference:** Filename from official docs if relevant
5. **Verify:** How to confirm the fix worked (rebuild command, or offer to check simulator)

---

## Optional: Verify Fix via Simulator

After the user applies the fix, offer to verify by dispatching ios-sim:

```
Dispatch Agent:
  subagent_type: general-purpose
  model: haiku
  description: "rn-diagnose: verify fix on simulator"
  prompt: |
    1. Run: ${CLAUDE_SKILL_DIR}/../ios-sim/scripts/capture.sh view
    2. Read the output file path to see the screenshot.
    3. Check if the error is still visible or if the app loaded successfully.
    4. Return: "FIXED — [what's now on screen]" or "STILL FAILING — [error text]"
```

---

## Context Efficiency

| Item | Size | In Main Context? |
|------|------|------------------|
| Metro health check | ~50 chars | YES (small output) |
| Error pattern DB | ~4 KB | YES (read once) |
| Simulator screenshot | ~100-300 KB | NEVER — subagent |
| Build log parsing | ~1-50 KB | Subagent if >100 lines |
| Doc search results | ~2-10 KB | Subagent |
| Project config files | ~1-3 KB each | YES (targeted reads) |
| Final diagnosis | ~200-500 chars | YES |
