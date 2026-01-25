#!/usr/bin/env bash
# Shared functions for setup scripts
# Source this at the top of setup scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }
prompt() { echo -e "${BLUE}==>${NC} $1"; }

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Backup a file or directory before replacing
backup_if_exists() {
  local target="$1"
  local backup_dir="${BACKUP_DIR:-$HOME/.backup/dotfiles-$(date +'%d%b%Y-%I%M%p')}"

  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$backup_dir"
    local backup_path="$backup_dir${target#$HOME}"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target" "$backup_path"
    warn "Backed up $target"
  elif [[ -L "$target" ]]; then
    rm -f "$target"
  fi
}
