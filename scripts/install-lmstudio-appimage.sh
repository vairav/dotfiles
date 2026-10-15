#!/usr/bin/env bash
#
# Install LM Studio on Linux as the official AppImage, not the AUR package.
#
# Why not AUR: lmstudio-bin repackages the same AppImage and lags upstream by
# days, while LM Studio's in-app updater keeps nagging. Running the AppImage
# from ~/Applications lets the updater work. See docs/arch.md.
#
# Called by packages/install.sh for the workstation role on Arch. Also safe to
# run directly:
#   ~/workspace/dotfiles/scripts/install-lmstudio-appimage.sh
#
# Idempotent: downloads only when ~/Applications/LM-Studio.AppImage is missing
# (after that LM Studio updates itself), but always refreshes the launcher entry
# and the lm-studio command.
#
# Never exits non-zero - a failed download must not fail the whole install.

set -uo pipefail

APP_DIR="$HOME/Applications"
APP_LINK="$APP_DIR/LM-Studio.AppImage"
LATEST_URL="https://lmstudio.ai/download/latest/linux/x64"
BIN_LINK="$HOME/.local/bin/lm-studio"
DESKTOP_FILE="$HOME/.local/share/applications/lm-studio.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_FILE="$ICON_DIR/lm-studio.png"
ICON_IN_APPIMAGE="usr/share/icons/hicolor/512x512/apps/lm-studio.png"

info() { echo "[lmstudio] $1"; }
warn() { echo "[lmstudio] WARNING: $1" >&2; }

[[ "$(uname -s)" == "Linux" ]] || { info "Not Linux - skipping."; exit 0; }
[[ "$(uname -m)" == "x86_64" ]] || { info "Only x86_64 is set up here - skipping."; exit 0; }

# The AUR package installs its own launcher and /usr/bin/lm-studio; two copies
# fight over the same config dir. Leave removal to a human (needs sudo).
if command -v pacman &>/dev/null && pacman -Q lmstudio-bin &>/dev/null; then
  warn "lmstudio-bin (AUR) is installed. Remove it first: sudo pacman -R lmstudio-bin"
  exit 0
fi

# AppImages mount themselves with FUSE 2. No grep -q: it exits on the first
# match, ldconfig dies of SIGPIPE, and pipefail turns that into "missing".
if ! ldconfig -p 2>/dev/null | grep 'libfuse\.so\.2' >/dev/null; then
  warn "libfuse.so.2 not found - the AppImage will not start. Install fuse2."
fi

mkdir -p "$APP_DIR" "$ICON_DIR" "$(dirname "$BIN_LINK")" "$(dirname "$DESKTOP_FILE")"

# --- download (first install only) ---
if [[ -x "$APP_LINK" ]]; then
  info "Already installed: $(readlink -f "$APP_LINK")"
else
  # The latest URL redirects to a versioned file; keep that name on disk.
  url="$(curl -fsIL -o /dev/null -w '%{url_effective}' "$LATEST_URL")" || url=""
  if [[ "$url" != *.AppImage ]]; then
    warn "Could not resolve the latest AppImage from $LATEST_URL - skipping."
    exit 0
  fi
  target="$APP_DIR/$(basename "$url")"
  info "Downloading $(basename "$url") (~1 GB)..."
  if ! curl -fL --retry 3 --progress-bar -o "$target.part" "$url"; then
    rm -f "$target.part"
    warn "Download failed - LM Studio NOT installed."
    exit 0
  fi
  mv "$target.part" "$target"
  chmod +x "$target"
  # Stable name, so the launcher survives a manual version swap.
  ln -sfn "$target" "$APP_LINK"
  info "Installed $target"
fi

# --- desktop integration (every run) ---
ln -sfn "$APP_LINK" "$BIN_LINK"

if [[ ! -f "$ICON_FILE" ]]; then
  tmp="$(mktemp -d)"
  if (cd "$tmp" && "$APP_LINK" --appimage-extract "$ICON_IN_APPIMAGE" >/dev/null 2>&1) \
     && [[ -f "$tmp/squashfs-root/$ICON_IN_APPIMAGE" ]]; then
    cp "$tmp/squashfs-root/$ICON_IN_APPIMAGE" "$ICON_FILE"
  else
    warn "Could not extract the icon - launcher will use a generic one."
  fi
  rm -rf "$tmp"
fi

# StartupWMClass matches the Wayland app id, which is also what the Hyprland
# workspace rule in config/hypr/windowrules.lua keys on.
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=LM Studio
GenericName=Large Language Model Studio
Comment=A desktop app for exploring and running large language models locally
Exec=$APP_LINK %U
Icon=lm-studio
Type=Application
Categories=Development;ArtificialIntelligence;
Terminal=false
StartupNotify=true
StartupWMClass=ai.elementlabs.lmstudio
MimeType=x-scheme-handler/lmstudio;
EOF

command -v update-desktop-database &>/dev/null \
  && update-desktop-database "$(dirname "$DESKTOP_FILE")" &>/dev/null

info "Launcher, icon and 'lm-studio' command are in place."
exit 0
