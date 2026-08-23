#!/usr/bin/env bash
#
# Patches applied in place to ml4w-OWNED files.
#
# Most of the ml4w integration goes through ml4w's own extension points
# (hypr conf/custom.conf, kitty custom.conf, zshrc custom/) and is symlinked
# by setup. The files touched HERE are different: ml4w owns them, its
# settings app or an ml4w update can rewrite them, and they offer no include
# hook - so the only way to keep our values is to re-assert them in place.
#
# This script is the single place that answers "why does the dock / waybar
# behave differently from stock ml4w": one block per patch, each with its
# reason. Add new ml4w patches here, never inline in a setup script.
#
# Idempotent. Runs from the rcm post-up hook (hooks/post-up/20-ml4w-patches),
# so every rcup re-asserts the patches - including the setup re-run that is
# the documented step after an ml4w update. Safe everywhere else: exits
# immediately on machines without ml4w.

set -uo pipefail

info() { echo "[ml4w] $1"; }
warn() { echo "[ml4w] WARNING: $1" >&2; }

[[ -d "$HOME/.config/ml4w" ]] || exit 0

# --- Dock: auto-hide on every ml4w machine -----------------------------------
# Current ml4w renders the dock in quickshell and reads settings/dock.json.
# The ML4W settings app writes that same file and an ml4w update recreates it,
# which is how this setting kept reverting to always-visible - hence the
# re-assert here. Only the one key is patched: the pinned apps in the same
# file are machine-local state and must survive.
DOCK_JSON="$HOME/.config/ml4w/settings/dock.json"
if [[ -f "$DOCK_JSON" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found - dock.json not patched, dock stays always-visible"
  elif [[ "$(jq -r '.dock.autohide' "$DOCK_JSON")" == "true" ]]; then
    info "dock.json: autohide already true"
  else
    tmp="$(mktemp "$DOCK_JSON.XXXXXX")"
    jq '.dock.autohide = true' "$DOCK_JSON" > "$tmp" && mv "$tmp" "$DOCK_JSON"
    info "dock.json: set dock.autohide = true"
  fi
else
  # Pre-quickshell ml4w drives nwg-dock-hyprland instead:
  # nwg-dock-hyprland/launch.sh adds -d (auto-hide) when this flag file exists.
  mkdir -p "$HOME/.config/ml4w/settings"
  touch "$HOME/.config/ml4w/settings/dock-autohide"
  info "no dock.json (older ml4w): created dock-autohide flag for nwg-dock"
fi

# --- Waybar: workspace behavior ----------------------------------------------
# ml4w pins persistent workspace placeholders and mirrors every workspace on
# every monitor. We want only real workspaces, each shown on its own monitor.
# modules.json has no include mechanism, so patch it directly.
WAYBAR_MODULES="$HOME/.config/waybar/modules.json"
if [[ -f "$WAYBAR_MODULES" ]]; then
  sed -i '/"persistent-workspaces": {/{
    N; N; s/"persistent-workspaces": {[^}]*}/"persistent-workspaces": {}/
  }' "$WAYBAR_MODULES"
  sed -i 's/"all-outputs": true/"all-outputs": false/' "$WAYBAR_MODULES"
  info "waybar modules.json: workspace patches applied"
fi

exit 0
