#!/usr/bin/env bash
#
# Install Alacritty on macOS from the upstream GitHub release.
#
# Homebrew disabled the alacritty cask on 2026-09-01 (`fails_gatekeeper_check`).
# Upstream ships ad-hoc-signed, un-notarized builds and has said it will not
# join Apple's developer program to change that (alacritty/alacritty#8749,
# #8958, #9046), so Homebrew will never deliver another alacritty release on
# macOS. A `cask "alacritty"` line now FAILS outright on a fresh machine, and on
# a machine that already has it, `brew upgrade` nags on every run and never
# upgrades. This script replaces the cask: it downloads the pinned universal
# DMG (one build for Intel and Apple Silicon), verifies its checksum, installs
# the app, and links the same artifacts the cask used to link.
#
# Gatekeeper: curl does not set the com.apple.quarantine attribute, so the
# copied app never triggers the "Apple could not verify" dialog. The attribute
# is stripped anyway in case a future macOS starts tagging it.
#
# Upgrading: bump ALACRITTY_VERSION and ALACRITTY_SHA256 below - the script
# prints a notice when upstream has a newer release - then re-run setup.
#   curl -fsSLO https://github.com/alacritty/alacritty/releases/download/v<V>/Alacritty-v<V>.dmg
#   shasum -a 256 Alacritty-v<V>.dmg
#
# Idempotent - safe to run on every setup. A running Alacritty keeps working
# through a reinstall (the binary is already mapped); quit and relaunch it to
# pick up the new version.

set -euo pipefail

ALACRITTY_VERSION="0.17.0"
ALACRITTY_SHA256="ad8d7de35fb38e43184776cac6dfee05ca325caa0b6639a06a55e54e4b026620"

APP="/Applications/Alacritty.app"
RES="$APP/Contents/Resources"
DMG_URL="https://github.com/alacritty/alacritty/releases/download/v${ALACRITTY_VERSION}/Alacritty-v${ALACRITTY_VERSION}.dmg"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || { info "Not macOS - alacritty comes from the package manager here"; exit 0; }

# Homebrew's prefix is arch-dependent; probe rather than shell out, so an
# absent brew cannot abort us under `set -e`.
brew_prefix() {
    local p
    for p in "${HOMEBREW_PREFIX:-}" /opt/homebrew /usr/local; do
        [[ -n "$p" && -x "$p/bin/brew" ]] && { echo "$p"; return 0; }
    done
    return 1
}

installed_version() {
    [[ -f "$APP/Contents/Info.plist" ]] || return 1
    /usr/bin/defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null
}

brew_owns_it() {
    command -v brew >/dev/null 2>&1 && brew list --cask alacritty >/dev/null 2>&1
}

# Mention a newer upstream release so the pin does not rot silently. Best
# effort: no network, no API, no problem.
check_upstream() {
    local latest
    latest="$(curl -fsSL --max-time 10 \
        https://api.github.com/repos/alacritty/alacritty/releases/latest 2>/dev/null \
        | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1 || true)"
    if [[ -n "$latest" && "$latest" != "$ALACRITTY_VERSION" ]]; then
        warn "Upstream alacritty is v$latest, this script pins v$ALACRITTY_VERSION"
        warn "  Bump ALACRITTY_VERSION/ALACRITTY_SHA256 in $0"
    fi
}

# The artifacts the cask used to link. The binary and man pages live under
# ~/.local (on PATH and manpath via zsh/common/exports.zsh); the zsh completion
# goes where Homebrew's zsh already looks; terminfo goes to ~/.terminfo because
# macOS ships no alacritty entry in /usr/share/terminfo.
link_artifacts() {
    local terminfo="${TERMINFO:-$HOME/.terminfo}"
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/man/man1" "$HOME/.local/share/man/man5" "$terminfo/61"

    ln -sfn "$APP/Contents/MacOS/alacritty" "$HOME/.local/bin/alacritty"
    ln -sfn "$RES/61/alacritty"        "$terminfo/61/alacritty"
    ln -sfn "$RES/61/alacritty-direct" "$terminfo/61/alacritty-direct"
    ln -sfn "$RES/alacritty.1.gz"          "$HOME/.local/share/man/man1/alacritty.1.gz"
    ln -sfn "$RES/alacritty-msg.1.gz"      "$HOME/.local/share/man/man1/alacritty-msg.1.gz"
    ln -sfn "$RES/alacritty.5.gz"          "$HOME/.local/share/man/man5/alacritty.5.gz"
    ln -sfn "$RES/alacritty-bindings.5.gz" "$HOME/.local/share/man/man5/alacritty-bindings.5.gz"

    local prefix
    if prefix="$(brew_prefix)"; then
        mkdir -p "$prefix/share/zsh/site-functions"
        ln -sfn "$RES/completions/_alacritty" "$prefix/share/zsh/site-functions/_alacritty"
    else
        warn "No Homebrew prefix found - zsh completion for alacritty not linked"
    fi
}

links_ok() {
    [[ -L "$HOME/.local/bin/alacritty" && -e "$HOME/.local/bin/alacritty" ]] \
        && [[ -e "${TERMINFO:-$HOME/.terminfo}/61/alacritty" ]]
}

current="$(installed_version || true)"
if [[ "$current" == "$ALACRITTY_VERSION" ]] && ! brew_owns_it && links_ok; then
    info "alacritty v$ALACRITTY_VERSION already installed"
    check_upstream
    exit 0
fi

tmp="$(mktemp -d)"
mnt="$tmp/mnt"
cleanup() {
    [[ -d "$mnt" ]] && hdiutil detach "$mnt" -quiet -force >/dev/null 2>&1 || true
    rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

info "Downloading alacritty v$ALACRITTY_VERSION..."
curl -fsSL -o "$tmp/alacritty.dmg" "$DMG_URL" || fail "download failed: $DMG_URL"
echo "$ALACRITTY_SHA256  $tmp/alacritty.dmg" | shasum -a 256 -c - >/dev/null \
    || fail "checksum mismatch on Alacritty-v${ALACRITTY_VERSION}.dmg - refusing to install"

# Stage the new bundle BEFORE removing the old one, so a failure here leaves
# the current install untouched.
hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$tmp/alacritty.dmg" -quiet </dev/null \
    || fail "could not mount the DMG"
[[ -d "$mnt/Alacritty.app" ]] || fail "DMG has no Alacritty.app"
ditto "$mnt/Alacritty.app" "$tmp/Alacritty.app"
hdiutil detach "$mnt" -quiet

# Hand over from the cask. `brew uninstall` removes the app and every link
# it made, which also ends the "Not upgrading alacritty, it is disabled" nag.
# HOMEBREW_NO_AUTOREMOVE: every brew uninstall otherwise sweeps out formulae
# nothing depends on any more, and the first run of this took a stale `usage`
# with it. Keep this script's footprint to alacritty alone.
if brew_owns_it; then
    info "Removing the disabled Homebrew cask record (app is reinstalled below)"
    HOMEBREW_NO_AUTOREMOVE=1 brew uninstall --cask alacritty </dev/null \
        || warn "brew uninstall failed - continuing"
fi
[[ -d "$APP" ]] && rm -rf "$APP"

ditto "$tmp/Alacritty.app" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
link_artifacts

# Read the version back from the installed bundle, never from the download.
current="$(installed_version || true)"
[[ "$current" == "$ALACRITTY_VERSION" ]] \
    || fail "installed bundle reports v${current:-none}, expected v$ALACRITTY_VERSION"
info "alacritty v$current installed at $APP"
if pgrep -qx alacritty; then
    warn "Alacritty is running - quit and relaunch it to use the new bundle"
fi
check_upstream
