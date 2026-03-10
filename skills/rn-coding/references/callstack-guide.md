# React Native Callstack Reading Guide

How to read and interpret React Native stack traces. Use this when you encounter a Red Box, crash log, or error output with a callstack.

---

## 1. Anatomy of a React Native Stack Trace

React Native bundles all JavaScript into a single file (e.g., `index.bundle`) before running it. When an error occurs, the stack trace references positions in this bundle, not your source files.

- **Line:column numbers** point into the bundle file, not your original source
- **Source maps** (`.map` files) translate bundle positions back to original file paths and line numbers
- Metro serves source maps automatically during development
- Production crashes need offline symbolication to map back to source

**Raw trace (before symbolication):**
```
TypeError: null is not an object (evaluating 'user.name')
    at index.bundle:loading:1234:56
    at index.bundle:loading:789:12
    at index.bundle:loading:345:78
```

**After symbolication:**
```
TypeError: null is not an object (evaluating 'user.name')
    at UserProfile (src/screens/UserProfile.tsx:42:18)
    at renderWithHooks (node_modules/react/cjs/react.development.js:1234:22)
    at performUnitOfWork (node_modules/react-dom/cjs/react-dom.development.js:789:5)
```

The symbolicated trace shows `src/screens/UserProfile.tsx:42` -- your actual source file and line number.

---

## 2. Synthetic Frames to Ignore

Many frames in a React Native stack trace are internal to React, Metro, or the bridge. These are not your code and can be skipped when looking for the root cause:

| Frame | What It Is |
|-------|------------|
| `__r` | Metro module require system |
| `__d` | Metro module define system |
| `MessageQueue` | Bridge message dispatch |
| `guardedCallbackAndCatchFirstError` | React error boundary internals |
| `invokeGuardedCallbackImpl` | React event system |
| `performSyncWorkOnRoot` / `performUnitOfWork` | React reconciler |
| `callFunctionReturnFlushedQueue` | Bridge JS-to-native call queue |

**How to use this:** Scan DOWN the stack trace past these framework frames. The first frame in YOUR code (`src/`, `components/`, `screens/`, `hooks/`, etc.) is where the error originated. Focus your investigation there.

---

## 3. Red Box vs Yellow Box

| Type | Severity | Meaning |
|------|----------|---------|
| **Red Box** | Fatal | App cannot continue. Crashes, invariant violations, uncaught exceptions. |
| **Yellow Box** | Warning | App still running, but something is wrong. Deprecations, performance issues. |

- **Red Box** displays the error message and a stack trace. Use Section 1 above to read it.
- **Yellow Box** warnings can be dismissed but should not be ignored during development. They often signal future breakage.
- **LogBox** (React Native 0.63+) replaced YellowBox with improved UI and filtering. Same concept: warnings that need attention.

---

## 4. Using metro.sh symbolicate

When you have a raw stack trace with numeric line:column positions from the bundle:

```bash
echo '<stack-trace-json>' | metro.sh symbolicate
```

**Input format:** JSON array of `{file, lineNumber, column}` objects.

**Output:** Symbolicated frames with original file paths and line numbers.

**When to use:**
- Crash logs from physical devices
- Raw Red Box traces with only bundle references
- CI crash reports without source mapping
- Any trace showing `index.bundle:loading:NNN:NNN` instead of source paths

---

## 5. Common Patterns -- Error Message to Root Cause

| Error Message | Where to Look in Stack | Typical Root Cause |
|---------------|------------------------|--------------------|
| `null is not an object` | First user-code frame | Accessing state/props before initialization, missing null check |
| `Invariant Violation` | Frame calling `requireNativeComponent` or `TurboModuleRegistry` | Native module not linked or not rebuilt after install |
| `Maximum call stack size exceeded` | Look for same function repeating in stack | Infinite recursion in render, useEffect, or event handler |
| `Unhandled promise rejection` | The async function in stack | Missing try/catch or .catch() on promise chain |
| `Cannot read properties of null/undefined` | First user-code frame after the TypeError | Same as "null is not an object" (Hermes/V8 engine variant) |

These patterns are covered in detail in the rn-diagnose error-patterns.md catalog.

---

## 6. Cross-Reference

- **Automated diagnosis:** Use the `rn-diagnose` skill for pattern-based error matching
- **Pattern catalog:** rn-diagnose `error-patterns.md` has 24 patterns with Match/Cause/Fix fields
- **Symbolication:** `metro.sh symbolicate` resolves raw traces before pattern matching
- **Live console:** `rn-debug` can capture live console errors for diagnosis
