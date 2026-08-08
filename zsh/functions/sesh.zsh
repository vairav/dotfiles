# t — fuzzy-pick (or create) a tmux session with sesh
# Lists running sessions, configured sessions (~/.config/sesh/sesh.toml),
# and zoxide dirs. Works inside or outside tmux.
t() {
  command -v sesh &>/dev/null || { echo "sesh not installed" >&2; return 1 }
  local session
  session=$(sesh list --icons | fzf --height 40% --reverse --ansi \
    --border --border-label ' sessions ' --prompt '⚡ ') || return
  sesh connect "$session"
}
