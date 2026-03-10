# Session Handoff — 2026-03-10

## What Was Done

### 1. Shell Escaping & Pipe Buffer Fixes (Plan: distributed-singing-grove)
Four-phase build via /code-foundations:building, all gates passed:
- **Phase 1**: `--format text` for cdp-bridge.js tree mode — eliminates ad-hoc `| node -e` piping
- **Phase 2**: Adaptive temp file — writes to `/tmp/cdp-tree-*` when output > 60KB
- **Phase 3**: idb detection guards + sips fallback in capture.sh/ui.sh
- **Phase 4**: PLAN.md Phase 2e documentation (PLAN.md later deleted — all phases complete)

### 2. idb → AXe Migration
- Replaced Facebook idb (broken on modern macOS) with AXe CLI
- Updated: ui.sh, capture.sh, all 3 SKILL.md files, troubleshooting.md
- AXe installed via `brew install cameroncooke/axe/axe` (v1.5.2)
- Env var: `IOS_SIMULATOR_MCP_AXE_PATH` (was `IOS_SIMULATOR_MCP_IDB_PATH`)

### 3. New ui.sh Commands (designed via /code-foundations:code)
- `tap-label <label>` — tap by accessibility label (native AXe --label)
- `tap-id <id>` — tap by accessibility ID (native AXe --id)
- `list` — compact table of on-screen elements, grouped Controls/Content by area
- `back` — heuristic back-button finder (scores by label/position, knows "←")
- `scroll top|bottom` — repeated swipes with stabilization detection (max 10)
- **Fixed** `describe-point` — depth tracking + ±1pt tolerance for sub-pixel frames

### 4. Plugin Structure Audit (via /obercreate review)
Audit completed, findings documented below in "What's Left."

## Commits on feature/plan-review-fixes

```
0f16417 Migrate from idb to AXe and add 5 new ui.sh commands
605c8d5 Add Phase 2e to PLAN.md documenting shell escaping and idb fixes
124aa68 Add idb detection guards and sips fallback for capture/ui scripts
875bd49 Add adaptive temp file output for large tree results in cdp-bridge.js
124b262 Add --format text option to cdp-bridge.js tree mode
```

## What's Left

### Priority 1 — Cleanup (do first next session)
1. **Delete `refs/ios-simulator-mcp/`** — 504K dead weight, nothing references it
2. **Delete `refs/.claude/settings.local.json`** — orphaned settings file inside refs
3. **Clean `.claude/settings.local.json`** — remove stale entries:
   - Remove: `idb describe`, `pip3 install`, `brew install`, `pipx install`, `pipx`, `command`, `EXIT=$?`, `echo "EXIT: $EXIT"`
   - Add: `ui.sh tap-label`, `ui.sh tap-id`, `ui.sh list`, `ui.sh back`, `ui.sh scroll`

### Priority 2 — Nice to Have
4. **Trim `refs/react-native-docs/`** — delete everything except `docs/` directory (yarn.lock, eslint config, etc. are unused)
5. ~~**Move `rn-docs/MANIFEST.md`** → `rn-docs/references/manifest.md` for consistency~~ ✓ DONE
6. **Update ios-sim/SKILL.md** — document the 5 new commands in the routing table and workflows

### Priority 3 — Future
7. Add dependency documentation (rn-layout-check→ios-sim, rn-a11y-audit→ios-sim, etc.)
8. Consider gitignoring `docs/building/` artifacts
9. Merge branch to main and bump version

## Test Results

All live-tested against "loopback" Expo app on iPhone 16e simulator:

| Feature | Status |
|---------|--------|
| `--format text` | PASS — indented tree, unnamed nodes skipped |
| `--format invalid` | PASS — rejected with error |
| Temp file > 60KB | PASS — 3954KB wrote to /tmp, valid JSON |
| capture.sh view (no idb) | PASS — sips fallback, 390x844 |
| ui.sh tap/type/swipe | PASS — all via AXe |
| ui.sh describe-all | PASS — full JSON tree |
| ui.sh describe-point | PASS — returns deepest element with tolerance |
| ui.sh list | PASS — Controls/Content tiers |
| ui.sh tap-label | PASS — tapped by label |
| ui.sh back | PASS — found "←" button |
| ui.sh scroll top/bottom | PASS — stabilization detection |
| ui.sh error handling | PASS — all error cases exit 1 |

## Known Issues
- AXe `describe-ui` returns everything as `GenericElement` in RN apps — `list` uses area-based sizing to classify controls vs content
- `back` command relies on heuristics — may misfire on screens without obvious back elements
- `network` mode in cdp-bridge.js fails on Expo/Hermes (`Unsupported method 'Network.enable'`) — pre-existing, not our bug
