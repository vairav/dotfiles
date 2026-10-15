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
#   --laptop         Light setup: essentials only (e.g. MacBook Air)
#   --workstation    Full setup: essentials + heavy workstation tiers
#   --server         Minimal server setup (no GUI apps)
#   --work           Work machine: shared essentials only, plus --vendor stacks
#   --personal       Personal machine (the personal tier is the default unless --work)
#   --ml4w           Linux: using ml4w for Hyprland (excludes kitty, hypr from rcm)
#   --skip-packages  Skip package installation
#   --skip-macos     Skip macOS defaults and setup
#   --skip-rcup      Skip rcup (just configure, don't symlink)
#   --non-interactive  Skip all prompts, use defaults
#   --private-repo URL  Clone a private overlay repo and hand off to its
#                       setup.sh. Installs Homebrew, git and gh first, and
#                       runs `gh auth login` if the clone needs credentials.
#   --private-dir DIR   Where to clone it (default: ~/workspace/<repo-name>)
#
# Bootstrapping a machine that uses a private overlay - note the download to a
# file, so the GitHub login prompt has a terminal to talk to:
#
#   curl -fsSL https://raw.githubusercontent.com/vairav/dotfiles/main/install.sh -o /tmp/install.sh
#   bash /tmp/install.sh --laptop --personal --private-repo <url>

set -e

# Non-login shells (ssh -t host 'cmd', CI) never run path_helper, so an
# installed Homebrew can be invisible here - which sent this script back into
# the Homebrew installer on a machine that already had it. Probe the known
# prefixes up front instead of shelling out to `brew --prefix` (under set -e
# a missing brew would abort the probe itself). Arch-dependent: /opt/homebrew
# on Apple Silicon, /usr/local on Intel.
for _p in "${HOMEBREW_PREFIX:-}" /opt/homebrew /usr/local; do
  if [[ -n "$_p" && -x "$_p/bin/brew" ]]; then
    export PATH="$_p/bin:$_p/sbin:$PATH"
    break
  fi
done
unset _p

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
MACHINE_NAME=""
VENDORS=()
STACKS=()
USE_ML4W=""
PRIVATE_REPO=""
PRIVATE_DIR=""
FORWARD_ARGS=()
SKIP_PACKAGES=false
SKIP_MACOS=false
SKIP_RCUP=false
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --server) PROFILE="server"; FORWARD_ARGS+=("$1"); shift ;;
    --laptop) PROFILE="laptop"; FORWARD_ARGS+=("$1"); shift ;;
    --workstation) PROFILE="workstation"; FORWARD_ARGS+=("$1"); shift ;;
    --work) MACHINE_TYPE="work"; FORWARD_ARGS+=("$1"); shift ;;
    --personal) MACHINE_TYPE="personal"; FORWARD_ARGS+=("$1"); shift ;;
    --vendor) VENDORS+=("$2"); FORWARD_ARGS+=("$1" "$2"); shift 2 ;;
    --stack) STACKS+=("$2"); FORWARD_ARGS+=("$1" "$2"); shift 2 ;;
    --name) MACHINE_NAME="$2"; FORWARD_ARGS+=("$1" "$2"); shift 2 ;;
    --private-repo) PRIVATE_REPO="$2"; shift 2 ;;
    --private-dir) PRIVATE_DIR="$2"; shift 2 ;;
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

# Acquire sudo ONCE, up front, and hold it for the whole run.
#
# Several later steps need root: the login shell change, macOS defaults, Mac
# App Store installs, and a few casks with pkg payloads. Asking once here is
# what makes this a single unattended command rather than a setup that stops
# halfway and hands you a list of commands to run by hand.
SUDO_OK=false
SUDO_KEEPALIVE_PID=""

request_sudo() {
  # The caller may already have set up a SUDO_ASKPASS helper.
  # If so, every sudo below re-authenticates through it and NOTHING here should
  # prompt - not even once - so take that path before anything else.
  if [[ -n "${SUDO_ASKPASS:-}" ]]; then
    SUDO_OK=true
    return 0
  fi

  if sudo -n true 2>/dev/null; then
    SUDO_OK=true
    return 0
  fi

  if [[ ! -t 0 ]]; then
    warn "No terminal attached - steps needing administrator access will be skipped."
    return 0
  fi

  echo ""
  prompt "Some steps need administrator access (login shell, macOS defaults,"
  prompt "App Store installs). You will be asked for your password once."
  echo ""

  if sudo -v; then
    SUDO_OK=true
    # Refresh the timestamp until this script exits, so nothing re-prompts.
    #
    # `|| true` is LOAD-BEARING: this subshell inherits `set -e`, so a single
    # transient failure used to kill the keepalive and every later step then
    # prompted again. `sudo -n -v` is the documented timestamp extension.
    while true; do
      sudo ${SUDO_ASKPASS:+-A} -n -v 2>/dev/null || true
      sleep 30
      kill -0 "$$" 2>/dev/null || exit
    done 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
  else
    warn "Could not obtain sudo - steps needing it will be skipped."
  fi
}

cleanup_sudo() {
  [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup_sudo EXIT

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

# Bootstrap a private overlay repo and hand off to its setup script.
#
# Solves a real chicken-and-egg problem: a PRIVATE overlay repo cannot be
# cloned (or curl'd) without GitHub credentials, but the credential tooling
# itself normally arrives with the dotfiles. So this installs just enough -
# Homebrew, git, gh - authenticates, clones, and hands over.
#
# The overlay URL is a parameter, never hardcoded here: this repo is public and
# has no business knowing what private repos exist.
#
# No recursion risk: the overlay's setup script calls this one WITHOUT
# --private-repo, so this path runs exactly once.
setup_private_overlay() {
  [[ -z "$PRIVATE_REPO" ]] && return 0

  local dir="$PRIVATE_DIR"
  if [[ -z "$dir" ]]; then
    local repo_name
    repo_name="$(basename "$PRIVATE_REPO" .git)"
    dir="$HOME/workspace/$repo_name"
  fi

  info "Bootstrapping private overlay: $PRIVATE_REPO"

  if [[ -d "$dir/.git" ]]; then
    info "Overlay already cloned at $dir"
  else
    # gh gives us a browser device-flow login, which beats hand-managing a PAT.
    if ! command -v gh &>/dev/null; then
      info "Installing GitHub CLI..."
      if command -v brew &>/dev/null; then
        brew install gh || warn "Could not install gh"
      fi
    fi

    # Try an unauthenticated clone first - credentials may already exist
    # (SSH agent, keychain, an existing gh login).
    if ! git clone "$PRIVATE_REPO" "$dir" 2>/dev/null; then
      if ! command -v gh &>/dev/null; then
        warn "Cannot clone the private overlay and gh is unavailable."
        echo "  Authenticate manually, then re-run:"
        echo "    git clone $PRIVATE_REPO $dir"
        exit 1
      fi

      if ! gh auth status &>/dev/null; then
        if [[ ! -t 0 ]]; then
          warn "GitHub authentication needed but there is no terminal to prompt on."
          echo ""
          echo "  This happens with 'curl ... | bash', which uses stdin for the script."
          echo "  Download it first so the login prompt has a terminal:"
          echo ""
          echo "    curl -fsSL <this-script-url> -o /tmp/install.sh"
          echo "    bash /tmp/install.sh $*"
          echo ""
          exit 1
        fi

        info "GitHub login required for the private overlay."
        gh auth login || error "GitHub authentication failed"
      fi

      # gh's credential helper makes the retry work over HTTPS.
      gh auth setup-git 2>/dev/null || true
      git clone "$PRIVATE_REPO" "$dir" || error "Could not clone $PRIVATE_REPO"
    fi
    info "Cloned overlay to $dir"
  fi

  local overlay_setup="$dir/setup.sh"
  if [[ ! -x "$overlay_setup" ]]; then
    error "No executable setup.sh in $dir - nothing to hand off to"
  fi

  info "Handing off to $overlay_setup"
  echo ""
  exec "$overlay_setup" ${FORWARD_ARGS[@]+"${FORWARD_ARGS[@]}"}
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
    # Non-fatal: a machine with local edits (or no network) must still be able
    # to run setup, and callers run under `set -e`.
    git -C "$DOTFILES_DIR" pull --rebase || warn "Could not update (offline or local changes) - continuing"
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
      if [[ "$PROFILE" == "server" ]]; then
        tags="server macos"
      else
        tags="desktop macos"
      fi
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

  # Client vendor stacks (repeatable). Length-guarded for bash 3.2.
  local vendor_args=""
  if [[ ${#VENDORS[@]} -gt 0 ]]; then
    for v in "${VENDORS[@]}"; do
      vendor_args="$vendor_args --vendor $v"
    done
  fi

  # Interest stacks (repeatable, independent of role and ownership).
  local stack_args=""
  if [[ ${#STACKS[@]} -gt 0 ]]; then
    for st in "${STACKS[@]}"; do
      stack_args="$stack_args --stack $st"
    done
  fi

  info "Installing packages..."
  "$DOTFILES_DIR/packages/install.sh" $PROFILE $extras $vendor_args $stack_args
}

# Note: tmux plugins are handled by the rcm post-up hook
# (hooks/post-up/10-tmux-plugins), not here. The hook runs after every rcup,
# so plugins stay in sync no matter who does the symlinking - this script, the
# private setup script, or a bare `rcup`.

# Hostname - cross-OS, so it lives outside setup_macos.
#
# macOS needs ComputerName/HostName/LocalHostName (+ NetBIOS) set together;
# Linux needs hostnamectl plus the /etc/hosts entry. scripts/set-hostname.sh
# owns both. Only runs when --name is passed - otherwise the machine keeps
# whatever it is already called.
setup_machine_name() {
  [[ -z "$MACHINE_NAME" ]] && return 0

  info "Setting machine name to: $MACHINE_NAME"
  "$DOTFILES_DIR/scripts/set-hostname.sh" "$MACHINE_NAME" || warn "Could not set hostname"
}

# macOS-specific setup
setup_macos() {
  if [[ "$OS" != "macos" ]] || [[ "$SKIP_MACOS" == true ]]; then
    return
  fi

  # Both of these want a password. Neither is worth aborting the run over -
  # the dotfile symlinking that matters has already happened by this point.
  info "Running macOS setup..."
  "$DOTFILES_DIR/macos/setup.sh" || warn "macOS setup incomplete (see above)"

  info "Applying macOS defaults..."
  "$DOTFILES_DIR/macos/defaults.sh" || warn "macOS defaults not applied (see above)"
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
  request_sudo             # Ask for the password once, up front
  install_git              # Only true bootstrap dependency
  [[ "$OS" == "macos" ]] && install_homebrew
  setup_private_overlay    # If --private-repo: clone it and exec its setup (no return)
  setup_dotfiles           # Clone/update repo (now we have package lists)
  install_packages         # Install packages (rcm comes from core.txt)
  setup_rcrc_local         # Configure rcm
  backup_existing          # Backup existing dotfiles
  link_dotfiles            # Run rcup (rcm now installed); post-up hook syncs tmux plugins
  setup_machine_name       # Cross-OS hostname, only when --name was passed
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
