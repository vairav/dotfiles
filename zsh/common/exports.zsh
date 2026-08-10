# Environment variables

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

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

# PATH
[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:$PATH"
[[ -d $HOME/.local/bin ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d $HOME/.lmstudio/bin ]] && export PATH="$PATH:$HOME/.lmstudio/bin"
[[ -d $HOME/.codeium/windsurf/bin ]] && export PATH="$HOME/.codeium/windsurf/bin:$PATH"
[[ -d $HOME/.cargo/bin ]] && export PATH="$HOME/.cargo/bin:$PATH"
