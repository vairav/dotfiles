#!/usr/bin/env bash
#
# Install/sync tmux plugins via TPM.
#
# Runs from rcm's post-up hook, so it fires after EVERY rcup. That is the point:
# when a new `set -g @plugin` lands via a config pull, the plugin gets installed
# on that machine without anyone remembering to do it by hand.
#
# Also safe to run directly:
#   ~/.scripts/setup-tmux-plugins.sh
#
# Never exits non-zero - a plugin problem must not fail the whole rcup.

set -uo pipefail

TMUX_CONF="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"
DOTFILES="${DOTFILES:-$HOME/workspace/dotfiles}"

info() { echo "[tmux] $1"; }
warn() { echo "[tmux] WARNING: $1" >&2; }

# Nothing to do on machines without tmux (or without git to fetch TPM).
command -v tmux &>/dev/null || { info "tmux not installed - skipping plugin sync."; exit 0; }

if ! command -v git &>/dev/null; then
  warn "git not found - cannot install TPM. Skipping plugin sync."
  exit 0
fi

# Precondition: TPM reads ~/.tmux.conf. If rcm has not symlinked it yet, TPM
# fails with a message that says nothing about ordering, so be explicit here.
if [[ ! -f "$TMUX_CONF" ]]; then
  warn "$TMUX_CONF not found - tmux plugins were NOT synced."
  warn ""
  warn "This means rcup has not linked tmux.conf yet. To fix:"
  warn "  RCRC=$DOTFILES/rcrc rcup -f"
  warn "  $DOTFILES/scripts/setup-tmux-plugins.sh"
  exit 0
fi

# Does the config chain declare any plugins? The server profile
# (tag-server/tmux.conf) deliberately declares none, and there is no point
# cloning TPM onto a machine that will never use it. Follows `source-file`
# directives, since plugins live in a sourced conf/plugins.conf.
declares_plugins() {
  local conf="$1" depth="${2:-0}" line src
  [[ -f "$conf" && "$depth" -le 5 ]] || return 1

  grep -qE '^[[:space:]]*set(-option)?[[:space:]].*@plugin' "$conf" && return 0

  # Parsed in plain bash rather than sed: BSD (macOS) and GNU sed differ enough
  # on -E and capture groups that this is not worth the portability risk.
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"        # trim leading whitespace
    case "$line" in
      source-file[[:space:]]*) src="${line#source-file}" ;;
      source[[:space:]]*)      src="${line#source}" ;;
      *) continue ;;
    esac
    src="${src#"${src%%[![:space:]]*}"}"           # trim leading whitespace
    src="${src#-q}"                                # optional -q flag
    src="${src#"${src%%[![:space:]]*}"}"
    src="${src%"${src##*[![:space:]]}"}"           # trim trailing whitespace
    src="${src%\"}"; src="${src#\"}"
    src="${src%\'}"; src="${src#\'}"
    [[ -n "$src" ]] || continue
    src="${src/#\~/$HOME}"
    src="${src//\$HOME/$HOME}"
    [[ "$src" == /* ]] || src="$HOME/$src"
    declares_plugins "$src" $((depth + 1)) && return 0
  done < "$conf"

  return 1
}

if ! declares_plugins "$TMUX_CONF"; then
  info "tmux config declares no plugins - nothing to sync."
  exit 0
fi

if [[ ! -d "$TPM_DIR" ]]; then
  info "Installing TPM (tmux plugin manager)..."
  if ! git clone --depth 1 "$TPM_REPO" "$TPM_DIR"; then
    warn "Could not clone TPM from $TPM_REPO (offline?)."
    warn "Retry later with: $DOTFILES/scripts/setup-tmux-plugins.sh"
    exit 0
  fi
fi

output="$("$TPM_DIR/bin/install_plugins" 2>&1)"
status=$?

# The server profile (tag-server/tmux.conf) deliberately declares no plugins.
# TPM reports that as a FATAL, which is not an error for us.
if grep -qiE "not configured|TMUX_PLUGIN_MANAGER_PATH" <<<"$output"; then
  info "tmux config declares no plugins - nothing to sync."
  exit 0
fi

if [[ $status -ne 0 ]]; then
  warn "tmux plugin install failed:"
  echo "$output" >&2
  warn ""
  warn "Recovery options:"
  warn "  1. Re-run: $DOTFILES/scripts/setup-tmux-plugins.sh"
  warn "  2. From inside tmux, press: prefix + I"
  warn "  3. If TPM itself looks broken: rm -rf $TPM_DIR && re-run step 1"
  exit 0
fi

installed=$(grep -c "download success" <<<"$output" || true)
present=$(grep -c "Already installed" <<<"$output" || true)

if [[ "$installed" -gt 0 ]]; then
  echo "$output"
  info "Installed $installed new plugin(s), $present already present."
  info "Reload running sessions with: tmux source-file ~/.tmux.conf"
else
  info "Plugins already in sync ($present installed)."
fi

# Note: plugins removed from the config are left on disk on purpose. Clean them
# up deliberately with 'prefix + alt + u', or $TPM_DIR/bin/clean_plugins.
exit 0
