#!/usr/bin/env bash
#
# Bootstrap script for my dotfiles
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/dotfiles/master/install.sh | bash
#   curl -fsSL ... | bash -s -- --work
#   curl -fsSL ... | bash -s -- --server
#
# Options:
#   --server      Minimal server setup (no GUI apps)
#   --work        Include work packages (MS Office)
#   --personal    Include personal packages (Rogue Amoeba)
#   --skip-packages  Skip package installation
#   --skip-macos     Skip macOS defaults and setup

set -e

DOTFILES_REPO="https://github.com/YOUR_USERNAME/dotfiles.git"
DOTFILES_DIR="$HOME/workspace/dotfiles"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }

# Parse arguments
PROFILE="desktop"
EXTRAS=""
SKIP_PACKAGES=false
SKIP_MACOS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --server) PROFILE="server"; shift ;;
    --work) EXTRAS="$EXTRAS --work"; shift ;;
    --personal) EXTRAS="$EXTRAS --personal"; shift ;;
    --skip-packages) SKIP_PACKAGES=true; shift ;;
    --skip-macos) SKIP_MACOS=true; shift ;;
    *) shift ;;
  esac
done

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
info "Detected OS: $OS"

# Install Homebrew (macOS only)
install_homebrew() {
  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to PATH for this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    info "Homebrew already installed"
  fi
}

# Install rcm
install_rcm() {
  if command -v rcup &>/dev/null; then
    info "rcm already installed"
    return
  fi

  info "Installing rcm..."
  case $OS in
    macos)
      install_homebrew
      brew install rcm
      ;;
    arch)
      if command -v yay &>/dev/null; then
        yay -S --noconfirm rcm
      elif command -v paru &>/dev/null; then
        paru -S --noconfirm rcm
      else
        error "Please install yay or paru first"
      fi
      ;;
    debian)
      sudo apt-get update
      sudo apt-get install -y rcm
      ;;
    *)
      error "Unsupported OS: $OS"
      ;;
  esac
}

# Install git if needed
install_git() {
  if command -v git &>/dev/null; then
    return
  fi

  info "Installing git..."
  case $OS in
    macos)
      # Xcode CLT includes git, or use brew
      xcode-select --install 2>/dev/null || brew install git
      ;;
    arch)
      sudo pacman -S --noconfirm git
      ;;
    debian)
      sudo apt-get update
      sudo apt-get install -y git
      ;;
  esac
}

# Clone or update dotfiles
setup_dotfiles() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    info "Updating dotfiles..."
    git -C "$DOTFILES_DIR" pull --rebase
  else
    info "Cloning dotfiles..."
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
}

# Set up tags based on OS and profile
setup_tags() {
  local tags=""

  case $OS in
    macos)
      tags="desktop macos"
      ;;
    arch)
      if [[ "$PROFILE" == "server" ]]; then
        tags="server"
      else
        tags="desktop linux"
      fi
      ;;
    debian)
      if [[ "$PROFILE" == "server" ]]; then
        tags="server"
      else
        tags="desktop linux"
      fi
      ;;
  esac

  info "Setting tags: $tags"
  echo "TAGS=\"$tags\"" > ~/.rcrc.local
}

# Symlink dotfiles
link_dotfiles() {
  info "Symlinking dotfiles..."
  RCRC="$DOTFILES_DIR/rcrc" rcup -v
}

# Install packages
install_packages() {
  if [[ "$SKIP_PACKAGES" == true ]]; then
    warn "Skipping package installation"
    return
  fi

  info "Installing packages..."
  "$DOTFILES_DIR/packages/install.sh" $PROFILE $EXTRAS
}

# macOS-specific setup
setup_macos() {
  if [[ "$OS" != "macos" ]] || [[ "$SKIP_MACOS" == true ]]; then
    return
  fi

  info "Running macOS setup..."
  "$DOTFILES_DIR/macos/setup.sh"

  info "Applying macOS defaults..."
  "$DOTFILES_DIR/macos/defaults.sh"
}

# Main
main() {
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║        Dotfiles Bootstrap Script       ║"
  echo "╚════════════════════════════════════════╝"
  echo ""

  install_git
  install_rcm
  setup_dotfiles
  setup_tags
  link_dotfiles
  install_packages
  setup_macos

  echo ""
  info "Done! Restart your terminal to apply changes."
  echo ""
  echo "Next steps:"
  echo "  - Edit ~/.zshrc.local for API keys and ZSH_FRAMEWORK"
  echo "  - Edit ~/.gitconfig.local for name and email"
  echo "  - Run 'atuin login' to sync shell history"
  echo ""
}

main "$@"
