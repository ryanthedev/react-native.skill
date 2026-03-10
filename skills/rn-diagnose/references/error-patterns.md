# React Native Error Pattern Database

Quick-reference for `rn-diagnose`. Each pattern includes: regex/string match, root cause, and fix.

---

## Metro Bundler Errors

### 1. Port 8081 Already in Use

**Match:** `port 8081`, `EADDRINUSE`, `already running on port`
**Cause:** Another process (Metro, other dev server, McAfee agent) is bound to port 8081.
**Fix:**
```bash
# Find and kill the process
lsof -i :8081 | grep LISTEN
kill -9 <PID>
# Or start Metro on a different port
npx react-native start --port 8082
```

### 2. Metro Cache Corruption

**Match:** `Loading dependency graph...error`, `jest-haste-map`, `DuplicateError`, `SHA-1`
**Cause:** Stale or corrupted Metro cache after branch switch, node_modules change, or crash.
**Fix:**
```bash
npx react-native start --reset-cache
# Or manually clear
rm -rf $TMPDIR/metro-* $TMPDIR/haste-map-*
```

### 3. Unable to Resolve Module

**Match:** `Unable to resolve module`, `Module not found`, `None of these files exist`
**Cause:** Missing dependency, wrong import path, or Metro not watching the directory.
**Fix:**
```bash
# If the module is a dependency
npm install <module-name>
# If path issue, check casing (case-sensitive on CI/Linux)
# If monorepo, add watchFolders to metro.config.js
# Then reset cache
npx react-native start --reset-cache
```

### 4. Metro Syntax/Transform Error

**Match:** `SyntaxError in`, `TransformError`, `Unexpected token`
**Cause:** Unsupported syntax (e.g., optional chaining in older Metro), or a file outside Babel transform scope.
**Fix:**
- Check `babel.config.js` has required presets/plugins
- Ensure the file is within Metro's `projectRoot` or `watchFolders`
- For node_modules syntax issues, add to `transformIgnorePatterns` exception list

---

## iOS Build Errors

### 5. Pod Install Failures

**Match:** `pod install failed`, `CocoaPods could not find compatible versions`, `CDN: trunk`, `Specs satisfying`
**Cause:** Outdated Podfile.lock, incompatible pod versions, CDN issues, or corrupted pod cache.
**Fix:**
```bash
cd ios
bundle exec pod deintegrate
rm -rf Pods Podfile.lock
bundle exec pod install --repo-update
```

### 6. Xcode Signing Errors

**Match:** `Signing for .* requires a development team`, `No signing certificate`, `provisioning profile`
**Cause:** No Apple Developer team configured in Xcode or expired certificate.
**Fix:**
- Open `ios/*.xcworkspace` in Xcode
- Select the target, go to Signing & Capabilities
- Select a valid Development Team
- For CI: set `CODE_SIGN_IDENTITY=""` and `CODE_SIGNING_ALLOWED=NO`

### 7. Native Module Linking Errors (iOS)

**Match:** `Undefined symbols for architecture`, `ld: symbol(s) not found`, `linker command failed`
**Cause:** Native module not linked. Common after adding a library with native code.
**Fix:**
```bash
cd ios && bundle exec pod install
# If still failing, clean build
cd ios && rm -rf build/
xcodebuild clean -workspace *.xcworkspace -scheme *
```

---

## Android Build Errors

### 8. Gradle Heap / Out of Memory

**Match:** `java.lang.OutOfMemoryError`, `GC overhead limit exceeded`, `Gradle build daemon disappeared`
**Cause:** Default JVM heap too small for the project.
**Fix:**
Add to `android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m
```

### 9. Gradle Build Failure — SDK / NDK Missing

**Match:** `SDK location not found`, `NDK not configured`, `ANDROID_HOME`, `Failed to install.*SDK`
**Cause:** Android SDK/NDK path not set or required version not installed.
**Fix:**
```bash
# Set ANDROID_HOME in shell profile
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools
# Install required SDK via sdkmanager
sdkmanager "platforms;android-34" "build-tools;34.0.0"
```

### 10. Duplicate Class / Multidex

**Match:** `Duplicate class`, `Cannot fit requested classes in a single dex file`, `multidex`
**Cause:** Conflicting dependencies pulling in the same class, or method count exceeding 64K.
**Fix:**
- Add `multiDexEnabled true` to `android/app/build.gradle` `defaultConfig`
- For duplicate classes: run `./gradlew app:dependencies` and exclude the transitive dep

---

## Runtime Errors

### 11. null is not an object (evaluating ...)

**Match:** `null is not an object`, `undefined is not an object`, `TypeError`
**Cause:** Accessing a property on null/undefined. Common with: uninitialized state, missing native module, navigation params.
**Fix:**
- Add optional chaining: `obj?.property`
- Check if a native module is properly linked (pod install / rebuild)
- Verify navigation params exist before accessing

**Callstack hint:** Scan past React internals (`invokeGuardedCallbackImpl`, `performSyncWorkOnRoot`) to find the first frame in your source code. The offending property access is on that line. Check if the variable is initialized before this code path executes.

### 12. Invariant Violation

**Match:** `Invariant Violation`, `requireNativeComponent`, `TurboModuleRegistry`
**Cause:** A native component or module is not registered. Common after adding a native library without rebuilding.
**Fix:**
```bash
# Rebuild the native app
cd ios && bundle exec pod install && cd ..
npx react-native run-ios
# Or for Android
cd android && ./gradlew clean && cd ..
npx react-native run-android
```

**Callstack hint:** Look for frames containing `requireNativeComponent` or `TurboModuleRegistry.getEnforcing` -- these indicate which native module failed to load. The component or module name in the error message tells you which library needs pod install or rebuild.

### 13. VirtualizedList Warnings/Errors

**Match:** `VirtualizedLists should never be nested`, `Excessive number of pending callbacks`, `ScrollView`
**Cause:** Nesting a FlatList/SectionList inside a ScrollView, or not providing `keyExtractor`.
**Fix:**
- Remove the outer `<ScrollView>` and use `ListHeaderComponent`/`ListFooterComponent` on the FlatList instead
- Add `keyExtractor={(item) => item.id}` to suppress key warnings
- For horizontal lists inside vertical scroll, use `nestedScrollEnabled`

### 14. Bridge / TurboModule Not Found

**Match:** `Cannot read NativeModules`, `RCTBridge required dispatch_sync`, `TurboModule.*not found`, `Native module cannot be null`
**Cause:** New Architecture mismatch, or native module not registered in AppDelegate/MainApplication.
**Fix:**
- Verify `newArchEnabled` flag matches across `Podfile`, `gradle.properties`, and AppDelegate
- Ensure module is registered: check `RCTBridgeModule` export or TurboModule spec
- Full clean rebuild after toggling architecture

---

## Dependency Errors

### 15. Peer Dependency Conflicts

**Match:** `ERESOLVE`, `peer dep`, `Could not resolve dependency`, `legacy-peer-deps`
**Cause:** npm v7+ enforces strict peer dependencies. Common with React Native ecosystem packages lagging behind.
**Fix:**
```bash
# Option 1: Force install (usually safe for RN ecosystem)
npm install --legacy-peer-deps
# Option 2: Check compatible versions
npm ls react-native
# Option 3: Use resolutions/overrides in package.json
```

### 16. Version Mismatch (JS/Native)

**Match:** `React Native version mismatch`, `JavaScript version.*does not match native version`
**Cause:** Running JS bundle built for a different RN version than the installed native binary.
**Fix:**
```bash
# Clean everything and rebuild
watchman watch-del-all
rm -rf node_modules
npm install
cd ios && bundle exec pod install && cd ..
npx react-native start --reset-cache
```

### 17. EACCES Permission Denied

**Match:** `EACCES`, `permission denied`, `EPERM`
**Cause:** npm global install without proper permissions, or iOS build directory permission issue.
**Fix:**
```bash
# For npm globals
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
# Add to PATH: export PATH=~/.npm-global/bin:$PATH
# For iOS build dirs
sudo chown -R $(whoami) ios/build/
```

### 18. Flipper / Hermes Conflicts

**Match:** `Flipper`, `hermes-engine`, `could not find a suitable`, `use_flipper`, `use_hermes`
**Cause:** Flipper version incompatible with current Xcode/RN, or Hermes toggle mismatch.
**Fix:**
- In `Podfile`, comment out or remove `use_flipper!()` for RN 0.73+
- Ensure `:hermes_enabled` matches in Podfile and `gradle.properties`
- `pod install --repo-update` after changes

---

## Metro Connectivity Errors

### 19. Metro Not Reachable

**Match:** `Could not connect to development server`, `connection refused`, `ECONNREFUSED`, `Unable to load script`, `Could not connect to the server`
**Cause:** Metro bundler is not running, crashed, or listening on a different port. App cannot fetch JS bundle.
**Fix:**
- Check if Metro is running: `metro.sh status`
- If not running: `npx react-native start`
- If running on a different port: check `RCT_METRO_PORT` or pass `--port` to Metro
- On physical device: ensure Metro host is set correctly (shake menu → Dev Settings → Debug server host)

### 20. Metro Bundle Download Timeout

**Match:** `Could not get BatchedBridge`, `Running.*took too long`, `Bundling failed`, `Network request failed`
**Cause:** Metro is running but bundle download timed out. Large bundle, slow machine, or incorrect network config.
**Fix:**
- Check bundle compiles: `metro.sh bundle-check --platform ios`
- If bundle compiles but device cannot reach: check same-network connectivity
- Clear Metro cache: `npx react-native start --reset-cache`
- For slow builds: ensure Hermes bytecode precompilation is enabled

### 21. Metro WebSocket Disconnected

**Match:** `WebSocket connection.*closed`, `HMR.*disconnected`, `Lost connection to Metro`
**Cause:** Hot Module Replacement WebSocket lost connection. Metro crashed, network changed, or device went to sleep.
**Fix:**
- Reload the app (Cmd+R in simulator, shake menu on device)
- If Metro crashed: restart with `npx react-native start`
- Check `metro.sh status` to confirm Metro is alive

---

## Runtime Errors (Additional)

### 22. Maximum Call Stack Size Exceeded

**Match:** `Maximum call stack`, `stack size exceeded`, `RangeError`
**Cause:** Infinite recursion. Common triggers: useEffect without proper dependency array causing render loop, recursive function without base case, setState inside render without condition guard.
**Fix:**
- Check useEffect dependency arrays -- missing deps cause infinite loops
- Add base case to recursive functions
- Move setState calls into event handlers or effects with proper guards
- Search stack trace for repeating function name to find the loop

**Callstack hint:** The stack trace will show the same function name repeating many times. That function is the source of the recursion. If it is a React component name, check its render body and useEffect hooks.

### 23. Unhandled Promise Rejection

**Match:** `Unhandled promise rejection`, `Possible Unhandled Promise`, `WARN Possible Unhandled Promise Rejection`
**Cause:** An async operation threw an error that was not caught. Common with fetch calls, AsyncStorage, native module calls that return promises.
**Fix:**
- Wrap async calls in try/catch blocks
- Add .catch() to promise chains
- For fetch: handle both network errors and non-OK HTTP responses
- For React Native: LogBox may suppress the warning but the error persists

**Callstack hint:** The stack trace points to the async function that threw. Look for the first frame in your code -- that is where the uncaught promise originated. The actual error message (before "Unhandled promise rejection") describes what went wrong.

### 24. Cannot Read Properties of null/undefined

**Match:** `Cannot read properties of null`, `Cannot read properties of undefined`, `Cannot read property`, `TypeError: Cannot read`
**Cause:** Same root cause as pattern 11 (null is not an object) but different error message format from Hermes or V8 engine. Accessing .property on a null/undefined value.
**Fix:**
- Same fixes as pattern 11: optional chaining, null checks, verify initialization order
- Common in navigation: `params?.id` instead of `params.id`
- Common in API responses: `data?.results` instead of `data.results`

**Callstack hint:** Same as pattern 11. Scan past framework frames to find the first frame in your source code. The property access on that line is the one that failed.
