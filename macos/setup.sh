#!/bin/bash
#
# macOS Initial Setup
#
# Run once on a fresh install after cloning dotfiles.

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
#
# This step needs a password, so it must never be fatal: it runs before zim and
# TPM, and an abort here used to take the whole install chain down with it
# (the calling install scripts run under `set -e`).
setup_zsh() {
    # Homebrew's prefix is architecture-dependent: /opt/homebrew on Apple
    # Silicon, /usr/local on Intel. This used to hardcode the Apple Silicon
    # path, which made the whole step a SILENT NO-OP on an Intel Mac - it
    # warned "not found", returned 0, and left the login shell on macOS's own
    # /bin/zsh while setup still exited 0.
    #
    # Probed rather than shelled out to `brew --prefix`: under `set -euo
    # pipefail` a `command -v brew && ...` list returns 1 when brew is absent,
    # which aborts the caller.
    local brew_zsh=""
    local p
    for p in "${HOMEBREW_PREFIX:-}" /opt/homebrew /usr/local; do
        if [[ -n "$p" && -x "$p/bin/zsh" ]]; then
            brew_zsh="$p/bin/zsh"
            break
        fi
    done

    if [[ -z "$brew_zsh" ]]; then
        warn "Homebrew zsh not found. Run: brew install zsh"
        return 0
    fi

    # Ask the directory service what the LOGIN SHELL actually is - do not trust
    # $SHELL. $SHELL is inherited from the terminal that launched this, so on a
    # machine already configured it still reports the OLD shell until you open
    # a new terminal. That made every re-run try to chsh again, which prompted
    # for a password and then reported "chsh: no changes made".
    local current_shell
    current_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    [[ -z "$current_shell" ]] && current_shell="$SHELL"

    if [[ "$current_shell" == "$brew_zsh" ]]; then
        info "Already using Homebrew zsh"
        return 0
    fi

    # Prefer cached sudo: the caller acquires it once up front, so this runs
    # without a second password prompt. `sudo chsh -s <shell> <user>` avoids
    # chsh's own interactive prompt entirely.
    if [[ -n "${SUDO_ASKPASS:-}" ]] || sudo -n true 2>/dev/null; then
        info "Setting Homebrew zsh as default shell..."
        if ! grep -q "$brew_zsh" /etc/shells; then
            echo "$brew_zsh" | sudo ${SUDO_ASKPASS:+-A} tee -a /etc/shells >/dev/null \
                || { warn "Could not add $brew_zsh to /etc/shells"; return 0; }
        fi
        sudo ${SUDO_ASKPASS:+-A} chsh -s "$brew_zsh" "$USER" \
            || warn "chsh failed - login shell unchanged"
        info "Login shell set - takes effect in new terminals"
        return 0
    fi

    if [[ ! -t 0 ]]; then
        warn "No administrator access - skipping login shell change."
        warn "To do it later:"
        warn "  sudo sh -c 'echo $brew_zsh >> /etc/shells' && chsh -s $brew_zsh"
        return 0
    fi

    info "Setting Homebrew zsh as default shell..."
    if ! grep -q "$brew_zsh" /etc/shells; then
        echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null || { warn "Could not edit /etc/shells"; return 0; }
    fi
    chsh -s "$brew_zsh" || warn "chsh failed - login shell unchanged"
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
#
# Delegates to scripts/set-hostname.sh, which owns this for every OS - macOS
# needs ComputerName/HostName/LocalHostName/NetBIOS set together, Linux needs
# hostnamectl plus /etc/hosts. One implementation, not two.
#
# Only runs when --hostname is passed. Omitted means "keep whatever this
# machine is already called", which is the right default for a re-run.
setup_hostname() {
    local name="$1"
    [[ -z "$name" ]] && return 0

    local script
    script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/set-hostname.sh"

    if [[ ! -x "$script" ]]; then
        warn "scripts/set-hostname.sh not found - skipping hostname change"
        return 0
    fi

    "$script" "$name" || warn "Could not set hostname"
}

print_next_steps() {
    echo ""
    echo "Done! Next steps:"
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
}

main() {
    echo "macOS Setup"
    echo ""

    setup_zsh
    setup_tpm
    setup_zim

    [[ -n "$HOSTNAME" ]] && setup_hostname "$HOSTNAME"

    print_next_steps
}

main
