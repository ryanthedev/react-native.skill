# Discovery: Phase 2c - Integration

## Files Found

| File | Path | Exists |
|------|------|--------|
| rn-diagnose SKILL.md | `skills/rn-diagnose/SKILL.md` | Yes |
| error-patterns.md | `skills/rn-diagnose/references/error-patterns.md` | Yes |
| settings.local.json | `.claude/settings.local.json` | Yes |
| plugin.json | `.claude-plugin/plugin.json` | Yes (plan says `plugin.json` but actual path includes `.claude-plugin/`) |
| rn-debug SKILL.md | `skills/rn-debug/SKILL.md` | Yes (Phase 2b artifact) |
| rn-coding SKILL.md | `skills/rn-coding/SKILL.md` | Yes (Phase 2b artifact) |
| _shared/scripts/ | `skills/_shared/scripts/` | Yes (Phase 2a artifacts: metro.sh, logs.sh, cdp-bridge.js) |

## Current State

### rn-diagnose/SKILL.md
- Has Steps 1-5 (Obtain Error Text, Match Patterns, Search Docs, Check Config, Process Logs)
- No Step 0 for Metro health check
- References `${CLAUDE_SKILL_DIR}/references/error-patterns.md` for patterns
- References `${CLAUDE_SKILL_DIR}/../ios-sim/scripts/capture.sh` for screenshots
- Does NOT reference `_shared/scripts/metro.sh`

### error-patterns.md
- 18 patterns across 5 categories: Metro Bundler (4), iOS Build (3), Android Build (3), Runtime (4), Dependency (4)
- Metro Bundler section covers: port conflicts, cache corruption, module resolution, syntax/transform errors
- Does NOT have Metro connectivity patterns (cannot reach Metro, connection refused, timeout)

### settings.local.json
- 7 skill permissions (rn-docs, ios-sim, rn-diagnose, rn-layout-check, rn-deeplink-test, rn-clean, rn-a11y-audit)
- Missing: `rn-debug` and `rn-coding` skill permissions
- Has `Bash(*/skills/*/scripts/*)` which technically matches `_shared/scripts/*` but plan wants explicit `Bash(*/skills/_shared/scripts/*)`
- Has Read, Grep, Glob permissions

### plugin.json (.claude-plugin/plugin.json)
- Version 0.1.0
- Description: "React Native foundation skills -- documentation search, API reference, and development patterns"
- Does not mention debug, coding, or new Phase 2 capabilities

## Gaps

1. **Plan path mismatch:** Plan says `plugin.json` but file is at `.claude-plugin/plugin.json`. Minor -- just need correct path in implementation.
2. **No Metro connectivity patterns:** error-patterns.md has Metro bundler errors but lacks patterns for "Metro not reachable" / "connection refused" scenarios that Step 0 would catch.
3. **rn-diagnose has no reference to _shared/scripts/metro.sh:** Step 0 needs to call `metro.sh status` and `metro.sh bundle-check`.
4. **Existing Bash glob may already cover _shared/scripts:** `*/skills/*/scripts/*` matches `_shared` as a wildcard. The explicit addition is for clarity/documentation.

## Prerequisites
- [x] Phase 2a complete (shared scripts exist)
- [x] Phase 2b complete (rn-debug, rn-coding skills exist)
- [x] All target files exist and are readable
- [x] No blocking dependencies

## Recommendation
BUILD -- All 4 integration tasks are ready for implementation.
