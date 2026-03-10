# Design Review: ui.sh New Commands

## Verdict: FAIL

Two issues must be resolved before implementation. The rest of the design is sound.

---

## Design Question Answers

### 1. Does AXe support --label and --id for tap?

**YES, confirmed.** `axe tap --help` shows both `--label <label>` and `--id <id>` flags. They are ignored if `-x` and `-y` are also provided. AXe exits with code 1 and prints to stderr when no element matches, which aligns with the "let stderr through" design.

Note: AXe uses `--pre-delay`/`--post-delay` instead of `--duration`. The existing `cmd_tap` uses `--duration` which does not exist in AXe's tap subcommand. This is a pre-existing bug (it would be silently ignored or error). The new commands correctly omit duration, which is fine.

### 2. Are the interactive type names correct?

**FAIL -- Type names are likely wrong.** Live AXe output from an actual app shows types like `Application`, `StaticText`, `GenericElement`. These are AXe's own type names. The design lists UIKit/SwiftUI-style names (`Button`, `TextField`, `SearchField`, `SegmentedControl`, etc.) that may not match what AXe actually emits.

Critically, `GenericElement` appears to be AXe's catch-all for many interactive elements. The design's filter list will exclude real interactive elements that AXe reports as `GenericElement`.

**Fix required:** Before implementation, run `axe describe-ui` against an app with buttons, text fields, switches, etc. and catalog the actual type values AXe produces. The filter list must be built from empirical data, not assumptions. If AXe uses `GenericElement` for most things, the filter strategy may need to shift to role-based filtering (checking the `role` field like `AXButton`, `AXTextField`) instead of type-based.

### 3. Is the describe-point fix correct?

**YES, with a minor note.** The current bug is real: `walk(nodes)` does DFS but unconditionally overwrites `best` when any ancestor/sibling matches the hit test. A shallower sibling visited after recursing into a deeper child will overwrite the deeper match.

The proposed fix (track `bestDepth`, only update when `depth >= bestDepth`) correctly solves this. The `>=` comparison is appropriate -- at equal depth, the later-visited sibling wins, which is correct behavior (later siblings are rendered on top in accessibility trees, matching visual z-order).

### 4. Is the scroll stabilization approach sound?

**Mostly sound, with edge cases to document:**

- **Stabilization signature** (element count + first on-screen leaf label) is a reasonable heuristic. It will correctly detect "reached end of scrollable content."
- **10 iteration cap** is appropriate for preventing infinite loops.
- **0.3s sleep** is reasonable for UI settle time.

Edge cases to be aware of (not blockers):
- **Animated content** (timers, progress indicators) could change leaf labels between snapshots, preventing stabilization detection. The 10-iteration cap handles this but the user gets no feedback about why it stopped.
- **Lazy-loading lists** that load new content on scroll will never stabilize until the data source is exhausted. Again, the cap handles this.
- **Direction naming is potentially confusing**: "top" means "scroll to top" which requires swiping down (pulling content down). The design correctly maps this but consider whether the user-facing command should be `scroll top`/`scroll bottom` or `scroll up`/`scroll down`. Document which convention is chosen.

### 5. Are there missing error cases or validation gaps?

**FAIL -- cmd_back has no error message on failure.**

- `cmd_back`: The design says "exit 1" when no candidate is found, but does not specify an error message. Following existing patterns in ui.sh, every failure path prints to stderr before exiting. Design should specify the message (e.g., `"Error: No back button found in current screen"`).

Other validation observations (not blockers):
- `cmd_tap_label` / `cmd_tap_id`: The design correctly reuses `validate_text` for label. For `--id`, `validate_text` is also appropriate since accessibility identifiers follow similar constraints.
- `cmd_scroll`: The positional arg should be validated as exactly "top" or "bottom" with a clear error for anything else.
- `cmd_list`: No user input beyond `--udid`, so no additional validation needed.

### 6. Does the back-finding heuristic handle React Native navigation patterns?

**Reasonable but not comprehensive.** The heuristic covers:
- React Navigation's default back button (label "Back" or custom label, chevron.left icon)
- Position-based fallback (top-left corner, x < 60, y < 120)

Missing patterns to consider (non-blocking, can be added later):
- React Navigation uses `accessibilityLabel` of "Back" on the header back button, which the AXLabel match covers.
- Some apps use "Close" (X button) in modals -- this is intentionally excluded, which is correct since "back" and "close" are semantically different.
- The scoring system (3/2/1) is reasonable for disambiguation.

---

## Spec Match

- [x] cmd_tap_label: Design is complete and feasible
- [x] cmd_tap_id: Design is complete and feasible
- [ ] cmd_list: **Type filter list needs empirical validation** (see finding #2)
- [x] cmd_back: Design is mostly complete (needs error message)
- [x] cmd_scroll: Design is complete and feasible
- [x] cmd_describe_point fix: Design is correct

## Correctness Verification

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirements | FAIL | Interactive type list not validated against actual AXe output |
| Concurrency | N/A | All commands are synchronous single-process |
| Error Handling | FAIL | cmd_back missing error message on no-candidate path |
| Resource Mgmt | PASS | Node scripts read stdin to completion, no leaks |
| Boundaries | PASS | Empty label validated, scroll capped at 10 iterations, direction validated |
| Security | N/A | No untrusted external input beyond validated CLI args |

## Defensive Programming

- **Silent failures**: The design for tap-label/tap-id correctly lets stderr through (unlike existing cmd_tap which suppresses both streams). This is good -- AXe's error messages are informative.
- **cmd_back silent exit 1**: Missing stderr message violates the pattern. Every other command in ui.sh prints an error message before exit 1.
- **Scroll stabilization**: The cap prevents infinite loops but does not report whether stabilization was achieved or the cap was hit. Consider printing different messages for each case.

## Issues (FAIL)

1. **Interactive type filter list is unvalidated**
   - Location: cmd_list design, type filter list
   - Problem: AXe appears to use `GenericElement` as a catch-all type for many interactive elements. The design assumes UIKit-style type names (Button, TextField, etc.) that may not exist in AXe output. Implementation would produce empty or misleading results.
   - Fix: Run `axe describe-ui` against an app with diverse UI elements. Catalog actual `type` and `role` values. Rebuild the filter list from empirical data. Consider filtering on `role` (e.g., `AXButton`) rather than `type`.

2. **cmd_back missing error message**
   - Location: cmd_back design, no-candidate path
   - Problem: Exits with code 1 but no stderr message, breaking the established pattern where every failure path in ui.sh prints a descriptive error.
   - Fix: Add error message specification: `echo "Error: No back button found on current screen" >&2`

## Observations (non-blocking)

- The existing `cmd_tap` has `--duration` which does not exist in AXe's tap subcommand (AXe uses `--pre-delay`/`--post-delay`). This is a pre-existing bug unrelated to the current design.
- The scroll command's "top"/"bottom" naming should be documented clearly -- "scroll top" means "scroll to the top" not "scroll the top of the screen."
- The `cmd_list` node script design is the most complex piece. Consider whether it should be extracted to a standalone .js file rather than an inline heredoc, for testability and readability.
