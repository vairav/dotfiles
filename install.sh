#!/usr/bin/env bash
#
# Bootstrap script for my dotfiles
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/vairav/dotfiles/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --work
#   curl -fsSL ... | bash -s -- --server
#
# Options:
#   --server         Minimal server setup (no GUI apps)
#   --work           Include work packages (MS Office)
#   --personal       Include personal packages (Rogue Amoeba)
#   --ml4w           Linux: using ml4w for Hyprland (excludes kitty, hypr from rcm)
#   --skip-packages  Skip package installation
#   --skip-macos     Skip macOS defaults and setup
#   --skip-rcup      Skip rcup (just configure, don't symlink)
#   --non-interactive  Skip all prompts, use defaults

set -e

DOTFILES_REPO="https://github.com/vairav/dotfiles.git"
DOTFILES_DIR="$HOME/workspace/dotfiles"
BACKUP_DIR="$HOME/.backup/dotfiles-$(date +'%d%b%Y-%I%M%p')"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }
prompt() { echo -e "${BLUE}==>${NC} $1"; }

# Backup a file or directory before replacing
backup_if_exists() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    local backup_path="$BACKUP_DIR${target#$HOME}"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target" "$backup_path"
    warn "Backed up $target"
  elif [[ -L "$target" ]]; then
    rm -f "$target"
  fi
}

# Parse arguments
PROFILE="desktop"
MACHINE_TYPE=""
USE_ML4W=""
SKIP_PACKAGES=false
SKIP_MACOS=false
SKIP_RCUP=false
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --server) PROFILE="server"; shift ;;
    --work) MACHINE_TYPE="work"; shift ;;
    --personal) MACHINE_TYPE="personal"; shift ;;
    --ml4w) USE_ML4W="yes"; shift ;;
    --skip-packages) SKIP_PACKAGES=true; shift ;;
    --skip-macos) SKIP_MACOS=true; shift ;;
    --skip-rcup) SKIP_RCUP=true; shift ;;
    --non-interactive) NON_INTERACTIVE=true; shift ;;
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

# Interactive prompts
ask_questions() {
  if [[ "$NON_INTERACTIVE" == true ]]; then
    return
  fi

  echo ""

  # Ask about machine type if not specified
  if [[ -z "$MACHINE_TYPE" && "$PROFILE" != "server" ]]; then
    prompt "Is this a work or personal machine?"
    echo "  1) Work (adds MS Office)"
    echo "  2) Personal (adds Rogue Amoeba apps)"
    echo "  3) Neither (skip extras)"
    read -p "Choice [3]: " choice
    case $choice in
      1) MACHINE_TYPE="work" ;;
      2) MACHINE_TYPE="personal" ;;
      *) MACHINE_TYPE="" ;;
    esac
  fi

  # Ask about ml4w on Linux
  if [[ "$OS" == "arch" || "$OS" == "debian" ]] && [[ "$PROFILE" != "server" ]]; then
    if [[ -z "$USE_ML4W" ]]; then
      echo ""
      prompt "Are you using ml4w for Hyprland?"
      echo "  ml4w manages its own kitty and hyprland configs."
      echo "  If yes, we'll exclude those from rcm to avoid conflicts."
      echo ""
      echo "  1) Yes, using ml4w"
      echo "  2) No, use dotfiles configs"
      read -p "Choice [2]: " choice
      case $choice in
        1) USE_ML4W="yes" ;;
        *) USE_ML4W="no" ;;
      esac
    fi
  fi
}

# Install Homebrew (macOS only)
install_homebrew() {
  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    info "Homebrew already installed"
  fi
}

# Install git if needed
install_git() {
  if command -v git &>/dev/null; then
    return
  fi

  info "Installing git..."
  case $OS in
    macos)
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

# Set up rcrc.local based on OS, profile, and preferences
setup_rcrc_local() {
  local tags=""
  local excludes=""

  # Determine tags
  case $OS in
    macos)
      tags="desktop macos"
      ;;
    arch|debian)
      if [[ "$PROFILE" == "server" ]]; then
        tags="server"
      else
        tags="desktop linux"
      fi
      ;;
  esac

  # Determine excludes for ml4w
  if [[ "$USE_ML4W" == "yes" ]]; then
    excludes="config/kitty config/hypr"
  fi

  info "Creating ~/.rcrc.local..."

  # Build the file
  cat > ~/.rcrc.local << EOF
# rcm local configuration
# Generated by dotfiles install.sh on $(date)
#
# OS: $OS
# Profile: $PROFILE
# Machine: ${MACHINE_TYPE:-none}
# ml4w: ${USE_ML4W:-no}

TAGS="$tags"
EOF

  # Add hostname
  echo "HOSTNAME=\"$(hostname -s)\"" >> ~/.rcrc.local

  # Add excludes if any
  if [[ -n "$excludes" ]]; then
    echo "" >> ~/.rcrc.local
    echo "# Excludes for ml4w compatibility" >> ~/.rcrc.local
    echo "# ml4w manages kitty and hyprland configs" >> ~/.rcrc.local
    echo "EXCLUDES=\"$excludes\"" >> ~/.rcrc.local
  fi

  echo ""
  info "Created ~/.rcrc.local:"
  cat ~/.rcrc.local
  echo ""
}

# Backup existing dotfiles before symlinking
backup_existing() {
  info "Checking for existing files to backup..."

  # ml4w manages its own zshrc, kitty, alacritty - don't touch them
  if [[ "$USE_ML4W" != "yes" ]]; then
    backup_if_exists "$HOME/.zshrc"
    backup_if_exists "$HOME/.config/kitty"
    backup_if_exists "$HOME/.config/alacritty"
  fi

  backup_if_exists "$HOME/.gitconfig"
  backup_if_exists "$HOME/.tmux.conf"
  backup_if_exists "$HOME/.vimrc"
  backup_if_exists "$HOME/.config/nvim"

  if [[ -d "$BACKUP_DIR" ]]; then
    info "Existing files backed up to $BACKUP_DIR"
  fi
}

# Symlink dotfiles
link_dotfiles() {
  if [[ "$SKIP_RCUP" == true ]]; then
    warn "Skipping rcup (--skip-rcup specified)"
    echo ""
    echo "To symlink manually, run:"
    echo "  RCRC=$DOTFILES_DIR/rcrc rcup -v"
    return
  fi

  # Ensure rcm is installed before trying to run rcup
  if ! command -v rcup &>/dev/null; then
    error "rcm is not installed. Cannot run rcup."
    echo ""
    echo "Either:"
    echo "  1. Run without --skip-packages (rcm is in core.txt)"
    echo "  2. Install rcm manually, then run again"
    exit 1
  fi

  info "Symlinking dotfiles..."
  RCRC="$DOTFILES_DIR/rcrc" rcup -f
}

# Install packages
install_packages() {
  if [[ "$SKIP_PACKAGES" == true ]]; then
    warn "Skipping package installation"
    return
  fi

  local extras=""
  if [[ "$MACHINE_TYPE" == "work" ]]; then
    extras="--work"
  elif [[ "$MACHINE_TYPE" == "personal" ]]; then
    extras="--personal"
  fi

  info "Installing packages..."
  "$DOTFILES_DIR/packages/install.sh" $PROFILE $extras
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

# Print next steps based on configuration
print_next_steps() {
  echo ""
  echo "Next steps:"
  echo "  - Edit ~/.zshrc.local for API keys and ZSH_FRAMEWORK"
  echo "  - Edit ~/.gitconfig.local for name and email"
  echo "  - Run 'atuin login' to sync shell history"

  if [[ "$USE_ML4W" == "yes" ]]; then
    echo ""
    echo "ml4w setup:"
    echo "  - kitty: Create ~/.config/kitty/custom.conf for your overrides"
    echo "  - hyprland: Use ml4w's variation system for customization"
    echo "  - See: $DOTFILES_DIR/docs/ml4w-hyprland-customization.md"
  fi

  echo ""
}

# Main
main() {
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║        Dotfiles Bootstrap Script       ║"
  echo "╚════════════════════════════════════════╝"
  echo ""

  info "Detected OS: $OS"

  ask_questions
  install_git              # Only true bootstrap dependency
  setup_dotfiles           # Clone/update repo (now we have package lists)
  install_packages         # Install packages (rcm comes from core.txt)
  setup_rcrc_local         # Configure rcm
  backup_existing          # Backup existing dotfiles
  link_dotfiles            # Run rcup (rcm now installed)
  setup_macos

  echo ""
  info "Done! Restart your terminal to apply changes."

  if [[ -d "$BACKUP_DIR" ]]; then
    echo ""
    warn "Your existing dotfiles were backed up to:"
    warn "  $BACKUP_DIR"
  fi

  print_next_steps
}

main "$@"
