# Environment Variables and PATH
# Shared across all frameworks

# Editor
export NVIM_APPNAME="nvim/lazyvim"
export EDITOR=nvim
export VISUAL=nvim

# Ansible
export ANSIBLE_NOCOWS=1
export ANSIBLE_FORCE_COLOR=true

# tfenv
export TFENV_ARCH=amd64
export TFENV_CONFIG_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/tfenv/${TFENV_ARCH}

# -----------------------------------------------------------------------------
# PATH
# -----------------------------------------------------------------------------

# Homebrew (macOS)
if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

# Local binaries
[[ -d $HOME/.local/bin ]] && export PATH="$HOME/.local/bin:$PATH"

# LM Studio CLI
[[ -d $HOME/.lmstudio/bin ]] && export PATH="$PATH:$HOME/.lmstudio/bin"

# Windsurf/Codeium
[[ -d $HOME/.codeium/windsurf/bin ]] && export PATH="$HOME/.codeium/windsurf/bin:$PATH"
