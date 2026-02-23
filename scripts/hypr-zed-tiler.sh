#!/usr/bin/env bash
# Hyprland IPC watcher that tiles Zed windows when they open
# Uses socat to listen to Hyprland's event socket for instant response
#
# Zed opens as floating by default and ignores windowrule tile directives.
# This script listens for window open events and tiles Zed windows immediately.

set -euo pipefail

SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

if [[ ! -S "$SOCKET_PATH" ]]; then
    echo "Error: Hyprland socket not found at $SOCKET_PATH" >&2
    exit 1
fi

if ! command -v socat &>/dev/null; then
    echo "Error: socat is required but not installed" >&2
    exit 1
fi

echo "Listening for Zed windows on Hyprland socket..."

socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while IFS= read -r event; do
    # Event format: openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE
    if [[ "$event" == openwindow\>\>* && "$event" == *"dev.zed.Zed"* ]]; then
        # Extract window address from event
        window_addr=$(echo "$event" | cut -d'>' -f3 | cut -d',' -f1)

        # Small delay to ensure window is fully initialized
        sleep 0.1

        # Toggle floating to tile the window
        hyprctl dispatch togglefloating "address:0x$window_addr" >/dev/null 2>&1 || \
        hyprctl dispatch togglefloating "class:dev.zed.Zed" >/dev/null 2>&1

        echo "Tiled Zed window: $window_addr"
    fi
done
