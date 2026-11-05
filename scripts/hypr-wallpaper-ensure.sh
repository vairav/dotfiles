#!/usr/bin/env bash
# Gives every output awww left blank the current wallpaper.
#
# awww-daemon restores from a cache keyed on output NAME, and ml4w's autostart
# skips setting the image when that cache holds any file at all. DP-N names are
# not stable, so after a rename the cache only knows the old names, nothing sets
# an image, and the outputs stay black. Outputs already showing an image are
# left alone, so this is safe to run on every start and monitor change.

set -uo pipefail

command -v awww >/dev/null 2>&1 || exit 0

# One run at a time: start-up fires this once per monitor.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-wallpaper-ensure.lock"
flock 9

for _ in {1..300}; do
    awww query >/dev/null 2>&1 && break
    sleep 0.1
done

# The daemon restores its cache after it starts answering queries.
sleep 2

wallpaper="$(cat "$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper" 2>/dev/null)"
[[ -f "$wallpaper" ]] || wallpaper="$HOME/.config/ml4w/wallpapers/default.jpg"
[[ -f "$wallpaper" ]] || exit 0

blank="$(awww query | awk -F': ' '/currently displaying: color:/ { print $2 }' | paste -sd, -)"
[[ -n "$blank" ]] || exit 0

awww img -o "$blank" --transition-type none "$wallpaper"
