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
- Key repeat enabled for VS Code, Zed

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

## Homebrew auto-upgrade

`brew-autoupgrade.sh` keeps Homebrew formulae and casks current without touching working
hours. Install it once per Mac with `./macos/brew-autoupgrade.sh --install`, which writes the
LaunchAgent `local.vairav.brew-autoupgrade`.

- launchd starts it every evening at 18:35 ET. It upgrades only when the last good run is 3 or
  more days old, so a failed or missed evening is retried the next evening.
- It skips casks whose app is open, and tmux while a tmux server runs. Casks that update
  themselves (Homebrew's `auto_updates`) are left to their own updaters. Pinned formulae
  (`brew pin <name>`) are left alone.
- Nothing waits on a password. One tool or app that fails, for example a cask that needs your
  admin password or a formula whose link conflicts with another package, does not stop the rest.
  It is named under "Needs you" in a dialog at the end.
- Every run posts a notification when it starts, naming how many tools and apps it will
  upgrade. Run from a terminal, it also shows each step and Homebrew's own output and progress
  bars live, and a cask that needs your password asks for it there.
- A good run ends with one notification. A failure, or a tick that fired late because the Mac
  slept through 18:35, shows a dialog that stays until you click OK.
- `--now` runs it by hand and counts as a good run. `--check` prints what the next tick would
  do. `--uninstall` removes the LaunchAgent. The log is `~/Library/Logs/brew-autoupgrade.log`.
