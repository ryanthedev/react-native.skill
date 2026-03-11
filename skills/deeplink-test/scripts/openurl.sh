#!/usr/bin/env bash
# openurl.sh — Open a URL in the booted iOS Simulator with validation
# Usage: openurl.sh <url>

set -euo pipefail

URL="${1:-}"

if [ -z "$URL" ]; then
  echo "ERROR: No URL provided" >&2
  echo "Usage: openurl.sh <url>" >&2
  exit 1
fi

# Validate URL has a scheme
if ! echo "$URL" | grep -qE '^[a-zA-Z][a-zA-Z0-9+.-]*://'; then
  echo "ERROR: Invalid URL — must start with a scheme (e.g., myapp:// or https://)" >&2
  exit 1
fi

# Check for a booted simulator
BOOTED=$(xcrun simctl list devices booted -j 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
devices = [d for runtime in data.get('devices', {}).values() for d in runtime if d.get('state') == 'Booted']
if devices:
    print(devices[0]['udid'])
" 2>/dev/null || true)

if [ -z "$BOOTED" ]; then
  echo "ERROR: No booted simulator found" >&2
  echo "Start one with: xcrun simctl boot <device-udid>" >&2
  exit 1
fi

echo "Opening URL in simulator ($BOOTED):"
echo "  $URL"

if xcrun simctl openurl booted "$URL"; then
  echo "URL opened successfully"
else
  echo "ERROR: Failed to open URL" >&2
  exit 1
fi
