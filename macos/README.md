# macOS Configuration

Scripts for setting up macOS the way I like it.

## Usage

```bash
# Initial setup (zsh, tpm, zim)
./macos/setup.sh

# Apply my preferred defaults
./macos/defaults.sh

# Set hostname
./macos/setup.sh --hostname mymac
```

## What defaults.sh does

### Keyboard
- Key repeat enabled (no accent popup) - essential for vim
- Fast repeat rate
- All "smart" typing disabled (auto-correct, smart quotes, etc.)
- Tab navigates all UI controls

### Trackpad
- Tap to click

### Finder
- Hidden files visible
- All extensions shown
- Path bar and status bar visible
- Full path in title
- Folders sort first
- Search current folder by default
- No .DS_Store on network/USB
- List view default

### Dock
- Auto-hide with no delay
- 36px icons
- Minimize to app icon
- Spaces don't rearrange
- No recent apps section

### Screenshots
- Save to ~/Pictures/Screenshots
- PNG format
- No window shadow

### Safari
- Developer menu enabled
- Don't auto-open downloads

### Code Editors
- Key repeat enabled for VS Code, Cursor, Zed

## Checking current values

```bash
defaults read com.apple.finder AppleShowAllFiles
```

## Finding app bundle IDs

```bash
osascript -e 'id of app "App Name"'
mdls -name kMDItemCFBundleIdentifier /Applications/AppName.app
```

## Reverting a setting

```bash
defaults delete com.apple.finder AppleShowAllFiles
# Then restart Finder
```
