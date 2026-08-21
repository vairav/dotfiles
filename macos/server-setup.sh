#!/usr/bin/env bash
#
# Configure a Mac to run as an always-on server (e.g. an old M1 MacBook).
# Run once after ./install.sh --server. Requires sudo.
#
# What it does:
#   - Enables SSH (Remote Login)
#   - Prevents sleep while on power (lid can stay closed with power connected)
#   - Auto-restarts after power failure or freeze

set -e

info() { echo -e "\033[0;32m==>\033[0m $1"; }

# ${SUDO_ASKPASS:+-A}: when setup.sh holds a credential, sudo re-authenticates
# through it and this script runs unattended; standalone it prompts as normal.
info "Enabling SSH (Remote Login)..."
sudo ${SUDO_ASKPASS:+-A} systemsetup -setremotelogin on

info "Configuring power management for always-on use..."
sudo ${SUDO_ASKPASS:+-A} pmset -a sleep 0            # never sleep the system
sudo ${SUDO_ASKPASS:+-A} pmset -a disksleep 0        # never sleep disks
sudo ${SUDO_ASKPASS:+-A} pmset -a displaysleep 5     # display can sleep after 5 min
sudo ${SUDO_ASKPASS:+-A} pmset -a autorestart 1      # restart after power failure
sudo ${SUDO_ASKPASS:+-A} pmset -a womp 1             # wake on network access
sudo ${SUDO_ASKPASS:+-A} pmset -a powernap 0         # no dozing between wakes
# Clamshell: a MacBook driving external displays with the lid closed sleeps on
# lid-close without this. Only sane on AC power - servers always are.
sudo ${SUDO_ASKPASS:+-A} pmset -a disablesleep 1

info "Current power settings:"
pmset -g | grep -E "sleep|autorestart|womp"

echo ""
info "Done. Recommended next steps:"
echo "  - Sign in to Tailscale:  open the Tailscale app and log in"
echo "  - Verify SSH works:      ssh $(whoami)@$(hostname -s).local"
echo "  - Note: with the lid closed, a MacBook only stays awake while on AC power"
echo "  - Optional: System Settings > Users & Groups > enable automatic login,"
echo "    so the machine comes back up fully after a reboot"
