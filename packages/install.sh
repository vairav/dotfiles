#!/bin/bash
# =============================================================================
# Package Installation Script
# =============================================================================
# Installs packages based on OS and role.
# Does NOT manage dotfiles (use rcm for that).
#
# Usage:
#   ./install.sh              # Detect OS, install desktop packages
#   ./install.sh desktop      # Install desktop packages
#   ./install.sh server       # Install minimal server packages
#   ./install.sh --work       # Include work-specific apps (MS Office, etc.)
#   ./install.sh --personal   # Include personal-only apps (Rogue Amoeba, etc.)
#   ./install.sh --playground # Include testing/evaluation tools
#   ./install.sh --dry-run    # Show what would be installed
#   ./install.sh --cleanup    # Remove packages not in Brewfiles
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
ROLE="desktop"
INCLUDE_WORK=false
INCLUDE_PERSONAL=false
INCLUDE_PLAYGROUND=false
CLEANUP=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# -----------------------------------------------------------------------------
# OS Detection
# -----------------------------------------------------------------------------

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

# -----------------------------------------------------------------------------
# macOS (Homebrew)
# -----------------------------------------------------------------------------

install_macos() {
    local role="$1"

    if ! command -v brew &>/dev/null; then
        error "Homebrew not installed. Install it first:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi

    info "Updating Homebrew..."
    if [[ "$DRY_RUN" == "false" ]]; then
        brew update
    else
        debug "Would run: brew update"
    fi

    # Build list of Brewfiles to install
    local brewfiles=()
    brewfiles+=("$SCRIPT_DIR/macos/Brewfile.core")
    brewfiles+=("$SCRIPT_DIR/macos/Brewfile.dev")
    brewfiles+=("$SCRIPT_DIR/macos/Brewfile.ai")

    if [[ "$role" == "desktop" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.font")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.devops")
    fi

    if [[ "$INCLUDE_WORK" == "true" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps.work")
    fi

    if [[ "$INCLUDE_PERSONAL" == "true" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps.personal")
    fi

    if [[ "$INCLUDE_PLAYGROUND" == "true" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.playground")
    fi

    for brewfile in "${brewfiles[@]}"; do
        if [[ -f "$brewfile" ]]; then
            info "Installing from $(basename "$brewfile")..."
            if [[ "$DRY_RUN" == "false" ]]; then
                brew bundle --file="$brewfile" || true
            else
                debug "Would run: brew bundle --file=$brewfile"
            fi
        else
            warn "Brewfile not found: $brewfile"
        fi
    done

    # Show manual install instructions
    if [[ -f "$SCRIPT_DIR/macos/manual-install.txt" ]]; then
        echo ""
        info "Manual installation required for some apps:"
        grep -v '^#' "$SCRIPT_DIR/macos/manual-install.txt" | grep -v '^$' | head -10
        echo "  See: $SCRIPT_DIR/macos/manual-install.txt"
    fi
}

cleanup_macos() {
    info "Checking for packages not in Brewfiles..."

    # Create a combined Brewfile for cleanup
    local combined_brewfile="/tmp/Brewfile.combined"
    cat "$SCRIPT_DIR/macos/Brewfile."* > "$combined_brewfile" 2>/dev/null || true

    if [[ "$DRY_RUN" == "false" ]]; then
        info "Packages that would be removed:"
        brew bundle cleanup --file="$combined_brewfile"
        echo ""
        read -p "Remove these packages? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew bundle cleanup --file="$combined_brewfile" --force
        fi
    else
        debug "Would check: brew bundle cleanup --file=$combined_brewfile"
        brew bundle cleanup --file="$combined_brewfile" 2>/dev/null || true
    fi

    rm -f "$combined_brewfile"
}

# -----------------------------------------------------------------------------
# Linux (apt/pacman)
# -----------------------------------------------------------------------------

install_linux() {
    local role="$1"
    local distro
    distro="$(detect_distro)"

    info "Detected distro: $distro"

    case "$distro" in
        ubuntu|debian|pop|linuxmint)
            install_apt "$role"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            install_dnf "$role"
            ;;
        arch|manjaro|endeavouros)
            install_pacman "$role"
            ;;
        *)
            error "Unsupported distro: $distro"
            error "Supported: ubuntu, debian, fedora, arch (and derivatives)"
            exit 1
            ;;
    esac
}

install_apt() {
    local role="$1"
    local pkg_file

    if [[ "$role" == "server" ]]; then
        pkg_file="$SCRIPT_DIR/debian/server.txt"
    else
        pkg_file="$SCRIPT_DIR/debian/desktop.txt"
    fi

    if [[ ! -f "$pkg_file" ]]; then
        error "Package list not found: $pkg_file"
        exit 1
    fi

    local packages
    packages=$(grep -v '^#' "$pkg_file" | grep -v '^$' | tr '\n' ' ')

    info "Installing packages from $(basename "$pkg_file")..."

    if [[ "$DRY_RUN" == "false" ]]; then
        sudo apt-get update
        # shellcheck disable=SC2086
        sudo apt-get install -y $packages
    else
        debug "Would run: sudo apt-get update"
        debug "Would run: sudo apt-get install -y $packages"
    fi
}

install_dnf() {
    local role="$1"
    local pkg_file

    local distro_dir="$SCRIPT_DIR/fedora"
    if [[ ! -d "$distro_dir" ]]; then
        warn "No fedora/ directory found, falling back to debian/"
        distro_dir="$SCRIPT_DIR/debian"
    fi

    if [[ "$role" == "server" ]]; then
        pkg_file="$distro_dir/server.txt"
    else
        pkg_file="$distro_dir/desktop.txt"
    fi

    if [[ ! -f "$pkg_file" ]]; then
        error "Package list not found: $pkg_file"
        exit 1
    fi

    local packages
    packages=$(grep -v '^#' "$pkg_file" | grep -v '^$' | tr '\n' ' ')

    info "Installing packages from $(basename "$pkg_file")..."

    if [[ "$DRY_RUN" == "false" ]]; then
        # shellcheck disable=SC2086
        sudo dnf install -y $packages
    else
        debug "Would run: sudo dnf install -y $packages"
    fi
}

install_pacman() {
    local role="$1"
    local pkg_file

    if [[ "$role" == "server" ]]; then
        pkg_file="$SCRIPT_DIR/arch/server.txt"
    else
        pkg_file="$SCRIPT_DIR/arch/desktop.txt"
    fi

    if [[ ! -f "$pkg_file" ]]; then
        error "Package list not found: $pkg_file"
        exit 1
    fi

    local packages
    packages=$(grep -v '^#' "$pkg_file" | grep -v '^$' | tr '\n' ' ')

    info "Installing packages from $(basename "$pkg_file")..."

    if [[ "$DRY_RUN" == "false" ]]; then
        # shellcheck disable=SC2086
        sudo pacman -Syu --noconfirm $packages
    else
        debug "Would run: sudo pacman -Syu --noconfirm $packages"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [ROLE]

Install packages based on OS and role.

ROLE:
  desktop     Full desktop packages (default)
  server      Minimal server packages

OPTIONS:
  --work        Include work-specific apps (MS Office, etc.)
  --personal    Include personal-only apps (Rogue Amoeba, etc.)
  --playground  Include testing/evaluation tools
  --cleanup     Remove packages not in Brewfiles (macOS only)
  --dry-run     Show what would be installed without installing
  --check       Alias for --dry-run
  -h, --help    Show this help

BREWFILE STRUCTURE (macOS):
  Brewfile.core          Essential CLI tools
  Brewfile.dev           Development tools
  Brewfile.ai            AI and LLM tools
  Brewfile.apps          GUI applications
  Brewfile.font          Nerd Fonts
  Brewfile.devops        DevOps tools
  Brewfile.apps.work     Work-specific apps (--work flag)
  Brewfile.apps.personal Personal-only apps (--personal flag)
  Brewfile.playground    Testing/evaluation tools (--playground flag)

Examples:
  $(basename "$0")                  # Install desktop packages
  $(basename "$0") server           # Install server packages
  $(basename "$0") --work           # Include work apps (work machine)
  $(basename "$0") --personal       # Include personal apps (personal machine)
  $(basename "$0") --playground     # Include testing tools
  $(basename "$0") --dry-run        # Preview installation
  $(basename "$0") --cleanup        # Remove unlisted packages
EOF
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|--check)
                DRY_RUN=true
                shift
                ;;
            --work)
                INCLUDE_WORK=true
                shift
                ;;
            --personal)
                INCLUDE_PERSONAL=true
                shift
                ;;
            --playground)
                INCLUDE_PLAYGROUND=true
                shift
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            desktop|server)
                ROLE="$1"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    local os
    os="$(detect_os)"

    echo "============================================="
    echo "Package Installation"
    echo "============================================="
    echo "OS:               $os"
    echo "Role:             $ROLE"
    echo "Include work:     $INCLUDE_WORK"
    echo "Include personal: $INCLUDE_PERSONAL"
    echo "Include playground: $INCLUDE_PLAYGROUND"
    echo "Cleanup:          $CLEANUP"
    echo "Dry-run:          $DRY_RUN"
    echo "============================================="
    echo ""

    if [[ "$CLEANUP" == "true" ]]; then
        if [[ "$os" == "macos" ]]; then
            cleanup_macos
        else
            error "Cleanup only supported on macOS"
            exit 1
        fi
    else
        case "$os" in
            macos) install_macos "$ROLE" ;;
            linux) install_linux "$ROLE" ;;
        esac
    fi

    echo ""
    info "Done!"
}

main "$@"
