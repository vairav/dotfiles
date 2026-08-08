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

info "Enabling SSH (Remote Login)..."
sudo systemsetup -setremotelogin on

info "Configuring power management for always-on use..."
sudo pmset -a sleep 0            # never sleep the system
sudo pmset -a disksleep 0        # never sleep disks
sudo pmset -a displaysleep 5     # display can sleep after 5 min
sudo pmset -a autorestart 1      # restart after power failure
sudo pmset -a womp 1             # wake on network access

info "Current power settings:"
pmset -g | grep -E "sleep|autorestart|womp"

echo ""
info "Done. Recommended next steps:"
echo "  - Sign in to Tailscale:  open the Tailscale app and log in"
echo "  - Verify SSH works:      ssh $(whoami)@$(hostname -s).local"
echo "  - Note: with the lid closed, a MacBook only stays awake while on AC power"
echo "  - Optional: System Settings > Users & Groups > enable automatic login,"
echo "    so the machine comes back up fully after a reboot"
