#!/bin/bash
# Compare pseudocode sections against PLAN.md implementation

echo "=== Phase 2e section in PLAN.md (lines 224-243) ==="
sed -n '224,243p' /Users/r/repos/react-native.skill/PLAN.md

echo ""
echo "=== Smoke tests section - new entries (lines 270-284) ==="
sed -n '270,284p' /Users/r/repos/react-native.skill/PLAN.md

echo ""
echo "=== Verify Phase 2e appears AFTER Phase 2d and BEFORE Smoke Tests ==="
grep -n "Phase 2d\|Phase 2e\|Smoke Tests" /Users/r/repos/react-native.skill/PLAN.md

echo ""
echo "=== Check for dead code / debug artifacts in PLAN.md ==="
grep -n "TODO\|FIXME\|HACK\|XXX\|TEMP\|DEBUG" /Users/r/repos/react-native.skill/PLAN.md || echo "None found"

echo ""
echo "=== Verify no duplicate sections ==="
echo "Phase 2e count: $(grep -c 'Phase 2e' /Users/r/repos/react-native.skill/PLAN.md)"
echo "Smoke Tests count: $(grep -c '### Smoke Tests' /Users/r/repos/react-native.skill/PLAN.md)"
