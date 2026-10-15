#!/usr/bin/env bash
#
# Install Claude Code with Anthropic's native installer.
#
# The native install updates itself and lands in ~/.local/bin/claude. It
# replaced the claude-code cask: a machine that had both ended up with two
# `claude` binaries on PATH, and whichever came first won.
#
# Skips when ANY claude is already present (native, the old cask, or a mise
# shim), so it never stacks a second copy on top of an existing one.
#
# Idempotent - safe to run on every setup. Never exits non-zero: a failed
# download must not abort the caller's setup.

set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

NATIVE="$HOME/.local/bin/claude"

# Checks the file as well as PATH: over `ssh -t host 'cmd'` the shell is
# non-login, so ~/.local/bin may not be on PATH even when claude is installed.
if [[ -x "$NATIVE" ]]; then
    info "Claude Code already installed (native): $NATIVE"
    exit 0
fi
if existing="$(command -v claude 2>/dev/null)"; then
    info "Claude Code already installed: $existing - leaving it alone"
    exit 0
fi

info "Installing Claude Code (native installer)..."
if ! curl -fsSL https://claude.ai/install.sh | bash; then
    warn "Claude Code install failed - re-run scripts/setup-claude-code.sh later"
    exit 0
fi

# Read the result back rather than trusting the installer's exit status.
if [[ -x "$NATIVE" ]] && "$NATIVE" --version >/dev/null 2>&1; then
    info "Claude Code $("$NATIVE" --version 2>/dev/null) at $NATIVE"
else
    warn "Installer finished but $NATIVE does not run - check its output above"
fi
exit 0
