# Environment variables

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Editor
export NVIM_APPNAME="nvim/lazyvim"
export EDITOR=nvim
export VISUAL=nvim

# opencode: mise owns the binary (config/mise/conf.d/ai-clis.toml), so its
# own update check stays off.
export OPENCODE_DISABLE_AUTOUPDATE=1

# Ansible
export ANSIBLE_NOCOWS=1
export ANSIBLE_FORCE_COLOR=true

# tfenv
# tfenv installs per-architecture binaries; derive it from the machine so an
# Apple Silicon host never runs an x86_64 terraform ("Bad CPU type in executable"
# without Rosetta). uname says arm64 on Apple Silicon and x86_64 on Intel; tfenv
# wants amd64 for the latter.
export TFENV_ARCH=$([ "$(uname -m)" = "arm64" ] && echo arm64 || echo amd64)
export TFENV_CONFIG_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/tfenv/${TFENV_ARCH}

# PATH
# Homebrew's prefix is arch-dependent: /opt/homebrew on Apple Silicon,
# /usr/local on Intel. Probe for the brew BINARY, not just the directory -
# /usr/local/bin exists on machines with no Homebrew at all (and on Linux),
# and prepending it there would only duplicate a PATH entry.
[[ -x /opt/homebrew/bin/brew ]] && export PATH="/opt/homebrew/bin:$PATH"
[[ -x /usr/local/bin/brew ]] && export PATH="/usr/local/bin:$PATH"
[[ -d $HOME/.local/bin ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d $HOME/.lmstudio/bin ]] && export PATH="$PATH:$HOME/.lmstudio/bin"
[[ -d $HOME/.antigravity-ide/antigravity-ide/bin ]] && export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"
[[ -d $HOME/.cargo/bin ]] && export PATH="$HOME/.cargo/bin:$PATH"

# Completions
# Docker Desktop ships completions here and, left alone, appends a block to
# ~/.zshrc that re-runs compinit after the framework already has. Adding the
# dir before the framework loads lets its single compinit pick them up.
# Appended, not prepended: the dir also carries Docker's own _kubectl, which
# must not shadow the one from Homebrew's kubernetes-cli.
[[ -d $HOME/.docker/completions ]] && fpath+=($HOME/.docker/completions)
