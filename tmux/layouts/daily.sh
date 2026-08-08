#!/usr/bin/env bash
#
# Daily layout - starting simple: one "main" window in ~/workspace.
# Runs once when sesh creates the "daily" session (see config/sesh/sesh.toml).
# Iterate here: add windows as the tmux workflow settles in.

session="$(tmux display-message -p '#S')"

# Already built (more than one window)? Do nothing.
[[ "$(tmux list-windows -t "$session" | wc -l)" -gt 1 ]] && exit 0

tmux rename-window -t "$session:1" main

# To add more windows later, e.g.:
# tmux new-window -d -t "$session" -n code -c "$HOME/workspace"
# tmux new-window -d -t "$session" -n logs -c "$HOME"
