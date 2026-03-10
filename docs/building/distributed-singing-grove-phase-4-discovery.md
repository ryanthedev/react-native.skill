# Discovery: Phase 4 - Update PLAN.md

## Files Found
- `PLAN.md` -- exists at repo root, contains Phase 2 plan with sections through Phase 2d

## Current State
PLAN.md documents Phase 2a (Foundation Scripts), 2b (New Skills), 2c (Integration), and 2d (Completed + Deferred). The Smoke Tests section covers metro.sh, logs.sh, and cdp-bridge.js only. There is no Phase 2e section and no smoke tests for the three fixes from this plan (shell escaping via `--format text`, pipe buffer via adaptive temp file, idb detection).

The three fixes implemented in Phases 1-3 of this plan are:
1. `--format text` flag added to `cdp-bridge.js tree` mode (eliminates ad-hoc `| node -e` pipelines)
2. Adaptive temp file output when tree exceeds 60KB (prevents pipe buffer truncation)
3. idb detect-and-warn in `capture.sh` (sips fallback), `ui.sh` (guard with install instructions), and three SKILL.md files

## Gaps
- No Phase 2e section exists in PLAN.md -- needs to be added after Phase 2d
- Smoke Tests section has no coverage for `--format text`, temp file behavior, or idb detection
- Phase 2d's completed list does not mention these fixes (correct -- they belong in a new Phase 2e)

## Prerequisites
- [x] PLAN.md exists and is readable
- [x] All three fixes are implemented and committed (Phases 1-3 complete)
- [x] Content for Phase 2e is clear from the plan and implementation

## Recommendation
BUILD -- Add Phase 2e section and new smoke test entries to PLAN.md.
