#!/bin/bash
# =============================================================================
# macOS Initial Setup
# =============================================================================
# Run once on a fresh install after cloning dotfiles.
# =============================================================================

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/workspace/dotfiles}"
HOSTNAME=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Set Homebrew zsh as default
setup_zsh() {
    local brew_zsh="/opt/homebrew/bin/zsh"

    if [[ ! -x "$brew_zsh" ]]; then
        warn "Homebrew zsh not found. Run: brew install zsh"
        return 1
    fi

    if [[ "$SHELL" == "$brew_zsh" ]]; then
        info "Already using Homebrew zsh"
        return 0
    fi

    info "Setting Homebrew zsh as default shell..."
    if ! grep -q "$brew_zsh" /etc/shells; then
        echo "$brew_zsh" | sudo tee -a /etc/shells
    fi
    chsh -s "$brew_zsh"
    info "Done"
}

# Install tmux plugin manager
setup_tpm() {
    local tpm_path="$HOME/.tmux/plugins/tpm"

    if [[ -d "$tpm_path" ]]; then
        info "TPM already installed"
        return 0
    fi

    info "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_path"
    info "Done. Start tmux and press prefix + I to install plugins"
}

# Install Zim
setup_zim() {
    local zim_home="${ZIM_HOME:-$HOME/.zim}"

    if [[ -d "$zim_home" ]]; then
        info "Zim already installed"
        return 0
    fi

    info "Installing Zim..."
    curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
    info "Done"
}

# Set hostname
setup_hostname() {
    local name="$1"
    [[ -z "$name" ]] && return 0

    info "Setting hostname to: $name"
    sudo scutil --set ComputerName "$name"
    sudo scutil --set HostName "$name"
    sudo scutil --set LocalHostName "$name"
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$name"
}

print_next_steps() {
    echo ""
    echo "============================================================================="
    echo "Done! Next steps:"
    echo "============================================================================="
    echo ""
    echo "1. Restart terminal or: exec zsh"
    echo ""
    echo "2. Apply macOS defaults: ./macos/defaults.sh"
    echo ""
    echo "3. Open neovim to install plugins: nvim"
    echo ""
    echo "4. Start tmux and install plugins: prefix + I"
    echo ""
    echo "5. Create ~/.zshrc.local:"
    echo "   export GITHUB_TOKEN=xxx"
    echo "   export OPENAI_API_KEY=xxx"
    echo ""
    echo "6. Create ~/.gitconfig.local:"
    echo "   [user]"
    echo "       name = Name"
    echo "       email = email@example.com"
    echo ""
    echo "============================================================================="
}

main() {
    echo "============================================================================="
    echo "macOS Setup"
    echo "============================================================================="
    echo ""

    setup_zsh
    setup_tpm
    setup_zim

    [[ -n "$HOSTNAME" ]] && setup_hostname "$HOSTNAME"

    print_next_steps
}

main
