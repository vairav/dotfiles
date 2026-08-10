#!/usr/bin/env bash
#
# Install the global mise-managed tools.
#
# These are tools Homebrew either cannot provide any more or should not:
#   - terraform / packer / tflint : HashiCorp's BUSL relicensing removed them
#     from homebrew-core, and consulting work needs per-project versions
#     rather than the single global copy brew installs.
#
# mise pins a global default here; a repo with its own mise.toml overrides it
# automatically, which is the whole point of using mise for these.
#
# Idempotent - safe to run on every setup.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Workstation-tier tools. Laptops do not do IaC work.
TOOLS=(
    "terraform@latest"
    "tflint@latest"
    "packer@latest"
)

if ! command -v mise &>/dev/null; then
    warn "mise not installed - skipping global tool setup"
    exit 0
fi

info "Installing global mise tools: ${TOOLS[*]}"
for tool in "${TOOLS[@]}"; do
    # Non-fatal: one unavailable tool must not abort the caller's setup.
    if mise use --global "$tool"; then
        info "  $tool"
    else
        warn "  $tool failed - continuing"
    fi
done

# Warn about brew-installed copies shadowing mise shims. Machines set up
# before this change have terraform/packer/tflint from Homebrew, and whichever
# comes first on PATH wins - which silently defeats per-project pinning.
for old in terraform tflint packer; do
    if brew list --formula 2>/dev/null | grep -qx "$old"; then
        warn "Homebrew still has '$old' installed and it may shadow mise."
        warn "  Remove it with: brew uninstall $old"
    fi
done

info "Done"
