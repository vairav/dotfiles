# Clipboard functions

# Detect clipboard command
if [[ "$OSTYPE" == "darwin"* ]]; then
  _clip_copy() { pbcopy; }
  _clip_paste() { pbpaste; }
elif [[ -n "$WAYLAND_DISPLAY" ]]; then
  _clip_copy() { wl-copy; }
  _clip_paste() { wl-paste; }
elif [[ -n "$DISPLAY" ]]; then
  _clip_copy() { xclip -selection clipboard; }
  _clip_paste() { xclip -selection clipboard -o; }
else
  _clip_copy() { echo "No clipboard available"; }
  _clip_paste() { echo "No clipboard available"; }
fi

# Ctrl+O copies current command line
copybuffer() {
  printf '%s' "$BUFFER" | _clip_copy
  zle -M "Copied to clipboard"
}
zle -N copybuffer
bindkey '^O' copybuffer

# Copy file contents
copyfile() {
  [[ -z "$1" ]] && { echo "Usage: copyfile <file>"; return 1; }
  [[ -f "$1" ]] && { _clip_copy < "$1"; echo "Copied: $1"; } || { echo "File not found: $1"; return 1; }
}

# Copy path
copypath() {
  local path="${1:-.}"
  [[ -e "$path" ]] && { realpath "$path" | tr -d '\n' | _clip_copy; echo "Copied: $(realpath "$path")"; } || { echo "Not found: $path"; return 1; }
}
