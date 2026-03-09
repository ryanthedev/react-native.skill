# iOS Simulator Troubleshooting

## Prerequisites

- **macOS only** — these scripts use `xcrun simctl` and `idb` which are macOS-specific
- **Xcode** installed with iOS simulators
- **Facebook IDB** installed for UI interactions (tap, type, swipe, describe)

## Installing IDB

### Homebrew + pip

```sh
brew install python
pip3 install --user fb-idb
export PATH="$HOME/.local/bin:$PATH"  # Add to ~/.zshrc
idb -h  # verify
```

### Using asdf

```sh
brew install asdf
asdf plugin add python
asdf install python latest
asdf global python latest
python -m pip install --user fb-idb
export PATH="$HOME/.local/bin:$PATH"
idb -h  # verify
```

## Common Issues

### "No booted simulator found"
- Open Xcode and boot a simulator, or run: `xcrun simctl boot <device-name>`
- Verify with: `xcrun simctl list devices | grep Booted`

### "idb: command not found"
- Install IDB using the steps above
- Check PATH: `which idb` or `echo $PATH`
- Set custom path: `export IOS_SIMULATOR_MCP_IDB_PATH=/path/to/idb`

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
| `IOS_SIMULATOR_MCP_IDB_PATH` | `idb` | Custom path to IDB executable |
| `IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR` | `~/Downloads` | Default directory for screenshots/recordings |
