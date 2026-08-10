#!/usr/bin/env bash
#
# Set this machine's hostname. Cross-OS.
#
# Hostname is machine IDENTITY, not a preference, which is why this does not
# live in macos/defaults.sh (that file is macOS-only `defaults write` settings).
# install.sh calls this for every OS.
#
# macOS and Linux disagree about what "the hostname" even is:
#
#   macOS   three separate values, and setting only one leaves the machine
#           inconsistent (a Mac can show up as "Vairav's MacBook Air" on the
#           network while the shell prompt says something else):
#             ComputerName   - the friendly name in System Settings / AirDrop
#             HostName       - the network hostname
#             LocalHostName  - the Bonjour/mDNS name (<name>.local)
#           plus the SMB NetBIOS name, which is separate again.
#
#   Linux   one value via systemd, but /etc/hosts also needs the 127.0.1.1
#           entry or sudo gets slow and some tools fail to resolve the host.
#           Arch and Debian/Ubuntu both use systemd-hostnamed, so they share a
#           path here; the non-systemd fallback writes /etc/hostname directly.
#
# Usage: ./set-hostname.sh <name>
# Idempotent - a no-op when the name already matches.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

NAME="${1:-}"

if [[ -z "$NAME" ]]; then
    error "Usage: $(basename "$0") <name>"
    exit 1
fi

# Hostnames: letters, digits and hyphens; no leading/trailing hyphen.
if ! [[ "$NAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
    error "Invalid hostname: '$NAME' (letters, digits, hyphens; no leading/trailing hyphen)"
    exit 1
fi

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

have_sudo() {
    sudo -n true 2>/dev/null && return 0
    [[ -t 0 ]] && return 0
    return 1
}

current_name() {
    case "$(detect_os)" in
        macos) scutil --get LocalHostName 2>/dev/null || echo "" ;;
        *)     hostname 2>/dev/null || echo "" ;;
    esac
}

set_macos() {
    info "Setting macOS hostname to: $NAME"
    sudo scutil --set ComputerName "$NAME"
    sudo scutil --set HostName "$NAME"
    sudo scutil --set LocalHostName "$NAME"

    # SMB/NetBIOS name is stored separately from all three of the above.
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server \
        NetBIOSName -string "$NAME" 2>/dev/null || warn "Could not set NetBIOS name"

    info "Set ComputerName, HostName, LocalHostName and NetBIOSName"
}

set_linux() {
    if command -v hostnamectl &>/dev/null; then
        # Arch and Debian/Ubuntu both run systemd-hostnamed.
        info "Setting Linux hostname to: $NAME (hostnamectl)"
        sudo hostnamectl set-hostname "$NAME"
    else
        info "Setting Linux hostname to: $NAME (/etc/hostname)"
        echo "$NAME" | sudo tee /etc/hostname >/dev/null
        sudo hostname "$NAME"
    fi

    # /etc/hosts needs the 127.0.1.1 entry or sudo stalls on name lookup.
    if grep -qE '^127\.0\.1\.1[[:space:]]' /etc/hosts; then
        sudo sed -i.bak -E "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$NAME/" /etc/hosts
        info "Updated 127.0.1.1 entry in /etc/hosts"
    else
        echo -e "127.0.1.1\t$NAME" | sudo tee -a /etc/hosts >/dev/null
        info "Added 127.0.1.1 entry to /etc/hosts"
    fi
}

main() {
    local os
    os="$(detect_os)"

    # Check BEFORE asking about sudo: a machine already named correctly needs
    # no privileges at all, and warning about sudo there is just noise.
    if [[ "$(current_name)" == "$NAME" ]]; then
        info "Hostname already set to: $NAME"
        exit 0
    fi

    if ! have_sudo; then
        warn "No administrator access - skipping hostname change (wanted: $NAME)"
        exit 0
    fi

    case "$os" in
        macos)        set_macos ;;
        arch|debian)  set_linux ;;
        *)
            warn "Unknown OS - not changing the hostname"
            exit 0
            ;;
    esac
}

main
