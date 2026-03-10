# Review: Phase 3 - idb detect-and-warn + simctl fallback

## Verdict: PASS

## Spec Match
- [x] All pseudocode sections implemented
- [x] No unplanned additions
- [x] Test coverage verified (manual smoke tests per plan)

### capture.sh -- Phase 3a
- Pseudocode: initialize width/height as empty, guard idb with `command -v`, extract dimensions on failure via sips, divide by 3. Implementation at lines 89-114 matches exactly.
- `command -v "$IDB" >/dev/null 2>&1` guard at line 91 -- matches pseudocode.
- idb call uses `|| true` (line 93) so failure inside the guard does not abort under `set -e` -- correct.
- Width/height extraction with `|| echo ""` fallback (lines 94-95) -- matches pseudocode "or empty on failure".
- sips fallback block at lines 104-114 placed AFTER screenshot capture (line 102) -- matches pseudocode and design notes about reading the captured PNG.
- `$(( pixel_w / 3 ))` integer arithmetic at lines 111-112 -- matches pseudocode.
- Existing resize/compress if-else at lines 116-122 unchanged -- matches pseudocode.

### ui.sh -- Phase 3b
- Pseudocode: top-level guard after line 10, `command -v "$IDB"` check, stderr messages with install instructions, exit 1. Implementation at lines 12-19 matches exactly.
- Guard is at top level (not inside functions) -- matches pseudocode design note about single check at boundary.
- Four stderr lines: error message, blank line, install instruction, env var mention -- matches pseudocode lines for line.
- Exit 1 on line 18 -- matches pseudocode.

### ios-sim/SKILL.md -- Phase 3c
- Pseudocode: update prerequisites line to clarify idb required for ui.sh only, capture.sh view works without. Implementation at line 24 matches the pseudocode replacement text verbatim.

### rn-layout-check/SKILL.md -- Phase 3c
- Pseudocode: add fallback instruction after `ui.sh describe-all` in subagent prompt. Implementation at lines 33-35 matches the pseudocode text: "If this fails (e.g., 'idb is not installed' error), skip the accessibility tree and proceed with screenshot-only analysis. Note in your report..."

### rn-a11y-audit/SKILL.md -- Phase 3c
- Pseudocode: add Pre-check section before Step 1 with `command -v` check and user-facing message. Implementation at lines 27-38 matches: section heading "Pre-check", the command to run, the failure message with install instruction, and the "Do not dispatch" instruction.

## Dead Code
None found. No unused imports, unreachable code, debug statements, or commented-out blocks in any of the five modified files.

## Correctness Verification

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirements | PASS | All 6 plan checklist items (3a: guard + sips fallback, 3b: idb guard, 3c: 3 SKILL.md updates) have corresponding implementations mapped above |
| Concurrency | N/A | No shared mutable state; scripts are single-process sequential execution |
| Error Handling | PASS | capture.sh: idb failure handled via `|| true` and `|| echo ""`, sips failure results in empty dimensions triggering existing compress-only fallback (line 119-121); ui.sh: early exit with actionable error message; a11y-audit: pre-check prevents dispatching a subagent that would fail |
| Resource Mgmt | PASS | capture.sh: existing `trap 'rm -rf "$TMP_DIR"' EXIT` at line 22 covers all temp files including new sips reads; no new resources acquired in ui.sh guard or SKILL.md changes |
| Boundaries | PASS | sips returning empty output: handled by `-z` check at line 105; pixel dimensions of 0: integer division `0/3 = 0`, which yields empty-looking dimensions but `[[ -n "0" ]]` is true so resize would attempt `sips -z 0 0` -- however sips returning 0 for a valid PNG is not a real scenario (no zero-pixel PNGs from simctl); idb returning malformed JSON: python3 `2>/dev/null || echo ""` catches this |
| Security | N/A | No untrusted user input; all inputs are from simctl/idb (controlled tools) or env vars set by the user themselves |

## Defensive Programming
- **No empty catch blocks:** All error suppression (`2>/dev/null`, `|| true`, `|| echo ""`) is intentional and paired with fallback logic. No errors are silently swallowed without alternative handling.
- **No executable code in assertions:** N/A (bash scripts, no assertion mechanism).
- **External input validated:** The idb and sips outputs are validated before use (empty-string checks at lines 105 and 109 of capture.sh). The `command -v` check validates tool availability before invocation.
- **Broad exception types:** The `|| true` on line 93 of capture.sh is scoped to a single command inside a guarded block, not a broad catch-all. The `2>/dev/null || echo ""` pattern on lines 94-95 is similarly scoped to individual extraction commands.
- **Error strategy consistency:** All three scripts follow the same pattern: check for tool availability with `command -v`, provide actionable error messages on stderr, and either degrade gracefully (capture.sh) or fail early (ui.sh). This matches the existing codebase error handling pattern.
