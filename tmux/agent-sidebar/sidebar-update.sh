#!/usr/bin/env bash
# sidebar-update.sh [--now|--check|--install|--uninstall]
#
# Keeps a local build of tmux-agent-sidebar (github.com/hiroppy/tmux-agent-sidebar, MIT) in step
# with upstream releases, with our 4-line patch that turns off its two GitHub calls (the release
# check against api.github.com and `gh pr view`). Vairav chose this over an upstream PR, 2026-11-27.
#
# Each run: fetch release tags; if the newest tag is not the one installed, copy that tag into
# releases/<tag>, apply local-no-network.patch with `git apply --3way`, build with
# `cargo build --release --locked`, check the binary prints the tag's version, then switch the
# `current` link and ~/.local/bin/tmux-agent-sidebar to it. If the patch or the build fails, the
# old binary stays and one memroute open item is filed for that tag.
#
#   (no flag)   what launchd runs weekly (Sunday 10:15 local time)
#   --now       the same, by hand
#   --check     print installed and newest tags, change nothing
#   --install   write the LaunchAgent local.vairav.sidebar-update
#   --uninstall remove the LaunchAgent
#
# Paths: source clone and builds in ~/.local/share/tmux-agent-sidebar, log in
# ~/Library/Logs/sidebar-update.log. TPM never manages this plugin: its update key would pull the
# unpatched upstream.
set -euo pipefail
export PATH="/opt/homebrew/opt/rustup/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

HERE=$(cd "$(dirname "$0")" && pwd)
PATCH=${SIDEBAR_PATCH:-$HERE/local-no-network.patch}
REPO_URL=https://github.com/hiroppy/tmux-agent-sidebar.git
ROOT=${SIDEBAR_ROOT:-$HOME/.local/share/tmux-agent-sidebar}
SRC=$ROOT/src
LABEL=local.vairav.sidebar-update
PLIST=$HOME/Library/LaunchAgents/$LABEL.plist
LOG=$HOME/Library/Logs/sidebar-update.log
BIN_LINK=${SIDEBAR_BIN_LINK:-$HOME/.local/bin/tmux-agent-sidebar}

say() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

installed_tag() { [[ -L $ROOT/current ]] && basename "$(readlink "$ROOT/current")" || echo none; }

newest_tag() {
  git -C "$SRC" fetch --quiet --tags --force origin
  git -C "$SRC" tag -l 'v[0-9]*' | sort -V | tail -1
}

file_failure() { # tag reason
  local marker=$ROOT/failed-$1
  [[ -e $marker ]] && return 0
  : >"$marker"
  if [[ -n ${SIDEBAR_NO_FILE:-} ]]; then say "would file an open item: $1: $2"; return 0; fi
  memroute add open-item --segment home --status open --stacks agent-comms --terminal sidebar-update \
    --title "tmux-agent-sidebar $1 not installed: $2 ($(date +%m-%d))" \
    "sidebar-update could not install upstream release $1 of tmux-agent-sidebar: $2. The previous build ($(installed_tag)) stays in use. Log: $LOG. Script: dotfiles tmux/agent-sidebar/sidebar-update.sh." \
    >/dev/null 2>&1 || say "memroute add failed; the failure is only in this log"
  memroute view write --segment home >/dev/null 2>&1 || true
}

update() {
  mkdir -p "$ROOT/releases"
  [[ -d $SRC/.git ]] || git clone --quiet "$REPO_URL" "$SRC"
  local tag cur dir
  tag=$(newest_tag); cur=$(installed_tag)
  [[ -n $tag ]] || { say "no release tags found"; return 1; }
  if [[ $tag == "$cur" ]]; then say "up to date at $tag"; return 0; fi
  say "installing $tag (was $cur)"
  dir=$ROOT/releases/$tag
  rm -rf "$dir"
  git -C "$SRC" worktree prune
  git -C "$SRC" worktree add --quiet --detach "$dir" "refs/tags/$tag"
  if ! git -C "$dir" apply --3way "$PATCH"; then
    say "patch does not apply to $tag"; git -C "$SRC" worktree remove --force "$dir"
    file_failure "$tag" "the local no-network patch does not apply"; return 1
  fi
  # The two GitHub calls must still be switched off after a 3-way merge.
  if ! grep -q 'Local build: no release check' "$dir/src/version.rs" || ! grep -q 'Local build: no gh pr view' "$dir/src/git.rs"; then
    say "patch applied but its markers are missing"; git -C "$SRC" worktree remove --force "$dir"
    file_failure "$tag" "the patched source lost its no-network markers"; return 1
  fi
  if ! (cd "$dir" && cargo build --release --locked --quiet); then
    say "build failed for $tag"; git -C "$SRC" worktree remove --force "$dir"
    file_failure "$tag" "cargo build --locked failed"; return 1
  fi
  local want got
  want=$(sed -n 's/^version *= *"\(.*\)"/\1/p' "$dir/Cargo.toml" | head -1)
  got=$("$dir/target/release/tmux-agent-sidebar" version 2>/dev/null || true)
  if [[ $got != *"$want"* ]]; then
    say "built binary reports '$got', expected $want"; file_failure "$tag" "the built binary reports the wrong version"; return 1
  fi
  ln -sfn "$dir" "$ROOT/current.new" && mv -fh "$ROOT/current.new" "$ROOT/current"
  mkdir -p "$(dirname "$BIN_LINK")"
  ln -sfn "$ROOT/current/target/release/tmux-agent-sidebar" "$BIN_LINK"
  say "installed $tag"
  # Keep the newest three releases.
  local old
  for old in $(ls -1 "$ROOT/releases" | sort -V | awk -v n="$(ls -1 "$ROOT/releases" | wc -l)" 'NR <= n - 3'); do
    [[ $ROOT/releases/$old == "$(readlink "$ROOT/current")" ]] || git -C "$SRC" worktree remove --force "$ROOT/releases/$old" 2>/dev/null || true
  done
}

case ${1:-} in
  "") exec >>"$LOG" 2>&1; update ;;
  --now) update 2>&1 | tee -a "$LOG" ;;
  --check)
    [[ -d $SRC/.git ]] || { echo "not installed yet (no clone at $SRC)"; exit 0; }
    echo "installed: $(installed_tag)   newest: $(newest_tag)" ;;
  --install)
    mkdir -p "$(dirname "$PLIST")"
    cat >"$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$HERE/sidebar-update.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>15</integer></dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PL
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    echo "installed $LABEL (Sunday 10:15). Trial now: launchctl kickstart gui/$(id -u)/$LABEL" ;;
  --uninstall)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"; echo "removed $LABEL" ;;
  *) sed -n 2,22p "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
