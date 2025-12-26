#!/bin/bash
# =============================================================================
# macOS Defaults
# =============================================================================
# My preferred macOS settings. Run after a fresh install.
# Some changes need a logout/restart.
# =============================================================================

set -euo pipefail

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "Applying macOS defaults..."

# =============================================================================
# General UI/UX
# =============================================================================

# Skip the "Are you sure you want to open this?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Expanded save/print dialogs by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk by default, not iCloud
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Auto-quit printer app when done
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Keep apps running even when inactive
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

# =============================================================================
# Keyboard
# =============================================================================

# Key repeat instead of accent menu (essential for vim)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable all the "smart" typing features
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Tab through all UI controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# =============================================================================
# Trackpad
# =============================================================================

# Tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Three-finger drag (uncomment if wanted)
# defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

# =============================================================================
# Finder
# =============================================================================

# Show hidden files and extensions
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar and status bar
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Full path in title bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Folders on top
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Search current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# No warning when changing extensions
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# No .DS_Store on network/USB drives
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# List view by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show ~/Library and /Volumes
chflags nohidden ~/Library
sudo chflags nohidden /Volumes

# =============================================================================
# Dock
# =============================================================================

# Icon size
defaults write com.apple.dock tilesize -int 36

# Auto-hide with no delay
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.3

# Minimize to app icon
defaults write com.apple.dock minimize-to-application -bool true

# Don't rearrange spaces
defaults write com.apple.dock mru-spaces -bool false

# Fast Mission Control
defaults write com.apple.dock expose-animation-duration -float 0.1

# No recent apps
defaults write com.apple.dock show-recents -bool false

# =============================================================================
# Screenshots
# =============================================================================

mkdir -p "${HOME}/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# =============================================================================
# Safari
# =============================================================================

# Developer tools
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Don't auto-open downloads
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Do Not Track
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# =============================================================================
# Mail
# =============================================================================

# Copy email without name
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# Show attachment icons
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# =============================================================================
# Misc Apps
# =============================================================================

# Time Machine - don't prompt for new drives
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# TextEdit - plain text by default, UTF-8
defaults write com.apple.TextEdit RichText -int 0
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# Activity Monitor - show all processes, sort by CPU
defaults write com.apple.ActivityMonitor ShowCategory -int 0
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# App Store - debug menu, daily update checks
defaults write com.apple.appstore ShowDebugMenu -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# =============================================================================
# Code Editors - key repeat
# =============================================================================

defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
defaults write com.microsoft.VSCodeInsiders ApplePressAndHoldEnabled -bool false
defaults write com.todesktop.230313mzl4w4u92 ApplePressAndHoldEnabled -bool false
defaults write dev.zed.Zed ApplePressAndHoldEnabled -bool false

# =============================================================================
# Restart affected apps
# =============================================================================

echo "Restarting affected apps..."

for app in "Activity Monitor" "cfprefsd" "Dock" "Finder" "Mail" "Safari" "SystemUIServer"; do
    killall "${app}" &> /dev/null || true
done

echo "Done. Some changes need logout/restart."
