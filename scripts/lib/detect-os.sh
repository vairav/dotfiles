#!/usr/bin/env bash
# OS detection functions
# Source this after common.sh

# Detect OS type
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  elif [[ -f /etc/fedora-release ]]; then
    echo "fedora"
  else
    echo "unknown"
  fi
}

# Boolean checks
is_macos() { [[ "$OSTYPE" == "darwin"* ]]; }
is_linux() { [[ "$OSTYPE" == "linux-gnu"* ]]; }
is_arch() { [[ -f /etc/arch-release ]]; }
is_debian() { [[ -f /etc/debian_version ]]; }

# Check if ml4w is installed
is_ml4w_installed() {
  [[ -d "$HOME/.mydotfiles/com.ml4w.dotfiles.stable" ]] || \
  flatpak list 2>/dev/null | grep -q "com.ml4w"
}

# Check if running under Hyprland
is_hyprland() {
  [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]
}

# Get appropriate tags for this machine
get_default_tags() {
  local os=$(detect_os)

  case $os in
    macos)
      echo "desktop macos"
      ;;
    arch|debian|fedora)
      echo "desktop linux"
      ;;
    *)
      echo "desktop"
      ;;
  esac
}
