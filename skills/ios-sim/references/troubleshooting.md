# iOS Simulator Troubleshooting

## Prerequisites

- **macOS only** — these scripts use `xcrun simctl` and `AXe` which are macOS-specific
- **Xcode** installed with iOS simulators
- **AXe** installed for UI interactions (tap, type, swipe, describe)

## Installing AXe

```sh
brew install cameroncooke/axe/axe
axe --version  # verify
```

## Common Issues

### "No booted simulator found"
- Open Xcode and boot a simulator, or run: `xcrun simctl boot <device-name>`
- Verify with: `xcrun simctl list devices | grep Booted`

### "AXe is not installed"
- Install AXe using the steps above
- Check PATH: `which axe` or `echo $PATH`
- Set custom path: `export IOS_SIMULATOR_MCP_AXE_PATH=/path/to/axe`

### Taps/swipes hitting wrong location
- Screenshots are captured at 3x pixel resolution
- The accessibility tree reports **point** coordinates
- Always use point coordinates (from `describe-all`) for tap/swipe targets
- If using screenshot coordinates, divide by the device scale factor (usually 3)

### Permission or file errors
- Check write permissions on the output directory
- Default output goes to `~/Downloads` (override with `IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR`)

### Simulator UI not responding
- Restart the simulator: `xcrun simctl shutdown booted && xcrun simctl boot <device>`
- Quit and relaunch Xcode if needed

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `IOS_SIMULATOR_MCP_AXE_PATH` | `axe` | Custom path to AXe executable |
| `IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR` | `~/Downloads` | Default directory for screenshots/recordings |
