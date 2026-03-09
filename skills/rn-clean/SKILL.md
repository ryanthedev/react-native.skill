---
name: rn-clean
description: Intelligent environment reset for React Native projects — diagnoses stale caches before cleaning instead of blindly nuking everything. Triggers on "clean build", "reset caches", "fresh start", "metro won't start", "build is broken", "nuclear clean", "clear derived data".
allowed-tools: Bash, Read, Grep
---

# Skill: rn-clean

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `rn-clean v{version}` before proceeding.

Diagnose-first environment reset for React Native projects. Checks what is actually stale before cleaning, then executes only the necessary steps.

---

## Workflow

### 1. Diagnose

Run the diagnosis script to check environment state:

```
bash ${CLAUDE_SKILL_DIR}/scripts/diagnose.sh
```

This outputs a JSON report covering all cache/state checks. Review the report and summarize findings for the user.

### 2. Recommend

Based on the diagnosis, recommend targeted clean steps. Present only what is needed — do not suggest cleaning things that are healthy.

### 3. Clean

Run the clean script with flags for the necessary targets:

```
bash ${CLAUDE_SKILL_DIR}/scripts/clean.sh [flags]
```

```
WARNING: Always confirm with the user before running destructive clean operations.
Do not run --all or --node-modules without explicit user approval.
```

### 4. Verify (optional)

After cleaning, optionally verify the environment works:
- Start Metro: `npx react-native start`
- Launch app via `ios-sim` skill if available

---

## Clean Targets

| Flag | What it removes | When to use |
|------|----------------|-------------|
| `--metro` | `/tmp/metro-*`, `/tmp/haste-*`, React Native temp caches | Metro bundling errors, stale module resolution |
| `--watchman` | Watchman watches and internal state | File change detection broken, phantom "file not found" errors |
| `--node-modules` | `node_modules/` + reinstall | Dependency corruption, version mismatch after branch switch |
| `--pods` | `ios/Pods/`, `ios/Podfile.lock` re-install | iOS build errors after native dependency changes |
| `--derived-data` | `~/Library/Developer/Xcode/DerivedData` | Xcode build failures, stale Swift/ObjC caches |
| `--gradle` | `android/.gradle/`, `android/app/build/` | Android build failures, stale Gradle caches |
| `--all` | All of the above | True nuclear option — last resort |

## Diagnosis Checks

| Check | How | Indicates |
|-------|-----|-----------|
| Port 8081 | `lsof -i :8081` | Metro already running / port conflict |
| Watchman | `watchman watch-list` | Stale or broken file watches |
| node_modules integrity | Compare `.package-lock.json` mtime vs `package-lock.json` | Modules out of sync with lockfile |
| Pods staleness | Compare `ios/Pods` mtime vs `ios/Podfile` mtime | Pods need reinstall |
| DerivedData size | `du -sh ~/Library/Developer/Xcode/DerivedData` | Large DerivedData may cause issues |
| Android build state | Check `android/.gradle`, `android/app/build` existence | Stale Android build artifacts |
| Metro cache | Check `/tmp/metro-*` existence | Stale Metro bundler cache |

## Tips

- Start with diagnosis — most issues only need 1-2 targeted cleans, not a full nuke
- `--pods` will run `pod install` after removing Pods
- `--node-modules` will run `npm install` (or `yarn`) after removing node_modules
- If Metro won't start, check port 8081 first — often a zombie process is the cause
- Cross-reference build errors with the `rn-docs` skill for API/config guidance
