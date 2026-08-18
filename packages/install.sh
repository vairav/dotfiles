#!/bin/bash
#
# Package Installation Script
#
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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
ROLE="desktop"
INCLUDE_WORK=false
INCLUDE_PERSONAL=false
INCLUDE_PLAYGROUND=false
CLEANUP=false
VENDORS=()
STACKS=()

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

# OS Detection

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

# macOS (Homebrew)

# Per-entry fallback for a Brewfile that `brew bundle` refused as a whole.
#
# WHY THIS EXISTS. `brew bundle` pre-fetches every download in a file BEFORE
# installing any of it. If one download fails, it aborts the entire file and
# installs NOTHING - while printing a green checkmark for each of the downloads
# that DID succeed. On an Intel Mac that cost 54 apps: a 500 on the whatsapp cask took
# down all of Brewfile.apps, and a 404 on cheatsheet took down all of
# Brewfile.apps.workstation. The log read like success.
#
# There is no brew flag for "keep going" (HOMEBREW_BUNDLE_CASK_SKIP only skips
# names you already know are broken). So when the batch fails, retry the file
# one entry at a time: a single dead upstream URL then costs exactly that one
# package instead of the other 36 in the file.
FAILED_PKGS=()

install_brewfile_individually() {
    local brewfile="$1"
    warn "brew bundle aborted on $(basename "$brewfile") - retrying entry by entry"
    warn "so one broken download cannot take the rest of the file with it"

    local kind name rest
    # Read the file rather than piping into the loop: a pipeline would run the
    # loop in a subshell and FAILED_PKGS would not survive it.
    while read -r kind name rest; do
        case "$kind" in
            brew) name="${name//\"/}"; brew install --formula "$name" >/dev/null 2>&1 \
                      || FAILED_PKGS+=("formula $name") ;;
            cask) name="${name//\"/}"; brew install --cask "$name" >/dev/null 2>&1 \
                      || FAILED_PKGS+=("cask $name") ;;
        esac
    done < <(grep -E '^[[:space:]]*(brew|cask) "' "$brewfile" | tr -d ',')

    # mas entries are handled separately: they need an Apple ID association and
    # fail for reasons no retry can fix (see CLAUDE.md).
}

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
    # laptop      = essentials of every category
    # workstation = essentials + *.workstation tiers (desktop is an alias)
    # server      = self-contained minimal set only
    local brewfiles=()

    if [[ "$role" == "server" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.server")
    else
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.core")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.dev")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.ai")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.font")
    fi

    if [[ "$role" == "workstation" || "$role" == "desktop" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.dev.workstation")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps.workstation")
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.devops")
    fi

    # Ownership tiers the same way roles do: the bare file is the essentials
    # set for any machine, *.workstation adds the heavy tier on a desk.
    local heavy=false
    [[ "$role" == "workstation" || "$role" == "desktop" ]] && heavy=true

    if [[ "$INCLUDE_WORK" == "true" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps.work")
        [[ "$heavy" == "true" ]] && brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps.work.workstation")

        # Vendor stacks: client-specific, opt-in per machine, work-only.
        # Length-guarded: /bin/bash on macOS is 3.2, where expanding an empty
        # array under `set -u` is a fatal "unbound variable".
        if [[ ${#VENDORS[@]} -gt 0 ]]; then
            for vendor in "${VENDORS[@]}"; do
                local vendor_file="$SCRIPT_DIR/macos/Brewfile.apps.work.$vendor"
                if [[ -f "$vendor_file" ]]; then
                    brewfiles+=("$vendor_file")
                else
                    warn "Unknown vendor '$vendor' (no $(basename "$vendor_file"))"
                fi
            done
        fi
    fi

    if [[ "$INCLUDE_PERSONAL" == "true" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps.personal")
        [[ "$heavy" == "true" ]] && brewfiles+=("$SCRIPT_DIR/macos/Brewfile.apps.personal.workstation")
    fi

    if [[ "$INCLUDE_PLAYGROUND" == "true" ]]; then
        brewfiles+=("$SCRIPT_DIR/macos/Brewfile.playground")
    fi

    # Interest stacks: opt-in per machine, independent of BOTH role and
    # ownership. Third axis alongside role and ownership, and a sibling of the
    # vendor axis - the difference is that vendors are work-only, while a stack
    # is a personal-interest cluster that any machine may want.
    #
    # These exist because clusters like the creative suite and local AI were
    # buried inside the shared *.workstation files, so a workstation that
    # wanted docker and betterdisplay but not Affinity and ollama had no flag
    # combination that expressed it.
    #
    # Length-guarded: /bin/bash on macOS is 3.2, where expanding an empty array
    # under `set -u` is a fatal "unbound variable".
    if [[ ${#STACKS[@]} -gt 0 ]]; then
        for stack in "${STACKS[@]}"; do
            local stack_file="$SCRIPT_DIR/macos/Brewfile.stack.$stack"
            if [[ -f "$stack_file" ]]; then
                brewfiles+=("$stack_file")
            else
                warn "Unknown stack '$stack' (no $(basename "$stack_file"))"
            fi
        done
    fi

    for brewfile in "${brewfiles[@]}"; do
        if [[ -f "$brewfile" ]]; then
            info "Installing from $(basename "$brewfile")..."
            if [[ "$DRY_RUN" == "false" ]]; then
                # `|| true` keeps a bad file from killing the run, but it is not
                # enough on its own - see install_brewfile_individually.
                brew bundle --file="$brewfile" || \
                    install_brewfile_individually "$brewfile"
            else
                debug "Would run: brew bundle --file=$brewfile"
            fi
        else
            warn "Brewfile not found: $brewfile"
        fi
    done

    if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
        echo ""
        warn "The following ${#FAILED_PKGS[@]} package(s) could NOT be installed:"
        printf '       %s\n' "${FAILED_PKGS[@]}"
        warn "Everything else in those files DID install (per-entry fallback)."
    fi

    # Show manual install instructions
    # Note: `|| true` is load-bearing. Under `set -o pipefail` a grep that
    # matches nothing returns 1 and aborts the whole run - which is exactly
    # what happened when this file held only comments.
    if [[ -f "$SCRIPT_DIR/macos/manual-install.txt" ]]; then
        local manual
        manual="$(grep -v '^#' "$SCRIPT_DIR/macos/manual-install.txt" | grep -v '^$' | head -10 || true)"
        if [[ -n "$manual" ]]; then
            echo ""
            info "Manual installation required for some apps:"
            echo "$manual"
            echo "  See: $SCRIPT_DIR/macos/manual-install.txt"
        fi
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

# Linux (apt/pacman)

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

    # Detect AUR helper first
    local aur_helper=""
    if command -v yay &>/dev/null; then
        aur_helper="yay"
    elif command -v paru &>/dev/null; then
        aur_helper="paru"
    fi

    # Use AUR helper for everything if available (can install both official and AUR)
    local pkg_manager="${aur_helper:-pacman}"

    if [[ -z "$aur_helper" ]]; then
        warn "No AUR helper (yay/paru) found. Some packages may fail."
    fi

    # Helper to install a package file
    install_pkg_file() {
        local pkg_file="$1"
        [[ -f "$pkg_file" ]] && install_packages_from_file "$pkg_file" "$pkg_manager"
    }

    # Core packages (always)
    install_pkg_file "$SCRIPT_DIR/arch/core.txt"

    # laptop      = essentials of every category
    # workstation = essentials + *.workstation tiers (desktop is an alias)
    # server      = core + server.txt only
    if [[ "$role" != "server" ]]; then
        install_pkg_file "$SCRIPT_DIR/arch/dev.txt"
        install_pkg_file "$SCRIPT_DIR/arch/apps.txt"
        install_pkg_file "$SCRIPT_DIR/arch/ai.txt"
        install_pkg_file "$SCRIPT_DIR/arch/font.txt"
        install_pkg_file "$SCRIPT_DIR/arch/devops.txt"
        install_pkg_file "$SCRIPT_DIR/arch/shell.txt"
    fi

    if [[ "$role" == "workstation" || "$role" == "desktop" ]]; then
        install_pkg_file "$SCRIPT_DIR/arch/dev.workstation.txt"
        install_pkg_file "$SCRIPT_DIR/arch/apps.workstation.txt"
        install_pkg_file "$SCRIPT_DIR/arch/ai.workstation.txt"
        install_pkg_file "$SCRIPT_DIR/arch/devops.workstation.txt"
    fi

    if [[ "$role" == "server" ]]; then
        install_pkg_file "$SCRIPT_DIR/arch/server.txt"
    fi

    # Ownership tiers like roles do - see the macOS branch for the rationale.
    local heavy=false
    [[ "$role" == "workstation" || "$role" == "desktop" ]] && heavy=true

    if [[ "$INCLUDE_WORK" == "true" ]]; then
        install_pkg_file "$SCRIPT_DIR/arch/apps.work.txt"
        [[ "$heavy" == "true" ]] && install_pkg_file "$SCRIPT_DIR/arch/apps.work.workstation.txt"

        # Vendor stacks - see the macOS branch for the bash 3.2 length guard.
        if [[ ${#VENDORS[@]} -gt 0 ]]; then
            for vendor in "${VENDORS[@]}"; do
                local vendor_file="$SCRIPT_DIR/arch/apps.work.$vendor.txt"
                if [[ -f "$vendor_file" ]]; then
                    install_pkg_file "$vendor_file"
                else
                    warn "Unknown vendor '$vendor' (no $(basename "$vendor_file"))"
                fi
            done
        fi
    fi

    if [[ "$INCLUDE_PERSONAL" == "true" ]]; then
        install_pkg_file "$SCRIPT_DIR/arch/apps.personal.txt"
        [[ "$heavy" == "true" ]] && install_pkg_file "$SCRIPT_DIR/arch/apps.personal.workstation.txt"
    fi

    if [[ "$INCLUDE_PLAYGROUND" == "true" ]]; then
        install_pkg_file "$SCRIPT_DIR/arch/playground.txt"
    fi

    # Interest stacks - see the macOS branch for the rationale and the bash 3.2
    # length guard. No arch stack lists exist yet; --stack on Linux warns
    # rather than silently installing nothing.
    if [[ ${#STACKS[@]} -gt 0 ]]; then
        for stack in "${STACKS[@]}"; do
            local stack_file="$SCRIPT_DIR/arch/stack.$stack.txt"
            if [[ -f "$stack_file" ]]; then
                install_pkg_file "$stack_file"
            else
                warn "Unknown stack '$stack' (no $(basename "$stack_file"))"
            fi
        done
    fi
}

# Install packages from a file with idempotent checks and nice output
install_packages_from_file() {
    local pkg_file="$1"
    local pkg_manager="$2"  # pacman, yay, or paru
    local file_name
    file_name=$(basename "$pkg_file" .txt)

    # Read packages from file (ignore comments and empty lines)
    local packages=()
    while IFS= read -r line; do
        # Remove comments (everything after #) and trim whitespace
        line=$(echo "$line" | sed 's/#.*//' | xargs)
        [[ -n "$line" ]] && packages+=("$line")
    done < "$pkg_file"

    if [[ ${#packages[@]} -eq 0 ]]; then
        return
    fi

    # Check which packages are already installed
    local installed=()
    local to_install=()

    for pkg in "${packages[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            installed+=("$pkg")
        else
            to_install+=("$pkg")
        fi
    done

    # Display status
    echo ""
    echo "=== ${file_name^} Packages ==="

    if [[ ${#installed[@]} -gt 0 ]]; then
        echo "Already installed:"
        for pkg in "${installed[@]}"; do
            echo "  • $pkg"
        done
    fi

    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo "Nothing to install."
        return
    fi

    echo ""
    echo "Installing:"
    for pkg in "${to_install[@]}"; do
        echo "  • $pkg"
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "(dry-run: would install ${#to_install[@]} packages)"
        return
    fi

    # Install missing packages
    echo ""
    case "$pkg_manager" in
        pacman)
            sudo pacman -S --noconfirm --needed "${to_install[@]}"
            ;;
        yay)
            yay -S --noconfirm --needed "${to_install[@]}"
            ;;
        paru)
            paru -S --noconfirm --needed "${to_install[@]}"
            ;;
    esac
}

# Main

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [ROLE]

Install packages based on OS and role.

ROLE:
  laptop      Essentials of every category (light machines, e.g. MacBook Air)
  workstation Essentials + heavy *.workstation tiers (docker, k8s, local AI, ...)
  desktop     Alias for workstation (default)
  server      Self-contained minimal set (headless / always-on machines)

OPTIONS:
  --work        Include work-specific apps
  --vendor NAME Include a client vendor stack (repeatable, implies --work):
                microsoft, google, apple
  --stack NAME  Include an interest stack (repeatable, any role/ownership):
                creative, finance, localai
  --personal    Include personal-only apps (SoundSource, etc.)
  --playground  Include testing/evaluation tools
  --cleanup     Remove packages not in Brewfiles (macOS only)
  --dry-run     Show what would be installed without installing
  --check       Alias for --dry-run
  -h, --help    Show this help

PACKAGE STRUCTURE:

  macOS (Brewfiles):
    Brewfile.core             Essential CLI tools
    Brewfile.dev              Development essentials
    Brewfile.dev.workstation  Heavy dev tools (docker, k8s, languages)
    Brewfile.ai               AI CLI agents + light apps
    Brewfile.apps             Essential GUI apps
    Brewfile.apps.workstation Full GUI app suite
    Brewfile.font             Nerd Fonts
    Brewfile.devops           DevOps tools (workstation only)
    Brewfile.server           Minimal server set (server role only)
    Brewfile.apps.work        Work-specific apps (--work flag)
    Brewfile.apps.work.workstation        Heavy work apps (--work on workstation)
    Brewfile.apps.personal    Personal-only apps (--personal flag)
    Brewfile.apps.personal.workstation    Heavy personal apps (--personal on workstation)
    Brewfile.playground       Testing/evaluation tools (--playground flag)
    Brewfile.stack.creative   Affinity/krita/audio/CAD (--stack creative)
    Brewfile.stack.finance    tradingview, thinkorswim, beancount (--stack finance)
    Brewfile.stack.localai    ollama, lm-studio, cursor, windsurf (--stack localai)

  Arch Linux:
    core.txt                  Essential CLI tools (always installed)
    dev.txt / *.workstation   Development tools (essentials / heavy)
    shell.txt                 Shell enhancements (AUR: starship, atuin, etc.)
    apps.txt / *.workstation  Desktop applications
    server.txt                Server-specific (minimal)
    playground.txt            Testing/evaluation tools (--playground flag)

Examples:
  $(basename "$0") laptop           # Essentials only (light machine)
  $(basename "$0") workstation      # Everything
  $(basename "$0") server           # Install server packages
  $(basename "$0") --work           # Include work apps (work machine)
  $(basename "$0") --personal       # Include personal apps (personal machine)
  $(basename "$0") --playground     # Include testing tools
  $(basename "$0") workstation --personal --stack finance   # No creative, no local AI
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
            --vendor)
                [[ -z "${2:-}" ]] && { error "--vendor needs a name (microsoft, google, apple)"; exit 1; }
                VENDORS+=("$2")
                shift 2
                ;;
            --stack)
                [[ -z "${2:-}" ]] && { error "--stack needs a name (creative, finance, localai)"; exit 1; }
                STACKS+=("$2")
                shift 2
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            desktop|laptop|workstation|server)
                ROLE="$1"
                shift
                ;;
            --laptop|--workstation|--server)
                ROLE="${1#--}"
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
    echo "Vendors:          ${VENDORS[*]:-none}"
    echo "Stacks:           ${STACKS[*]:-none}"
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

        # Global mise-managed tools (workstation only - laptops do no IaC work)
        if [[ "$ROLE" == "workstation" || "$ROLE" == "desktop" ]]; then
            if [[ "$DRY_RUN" == "false" ]]; then
                "$SCRIPT_DIR/../scripts/setup-mise-tools.sh" || warn "mise tool setup incomplete"
            else
                debug "Would run: scripts/setup-mise-tools.sh"
            fi
        fi
    fi

    echo ""
    info "Done!"
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
