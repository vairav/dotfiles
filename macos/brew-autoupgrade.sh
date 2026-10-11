#!/usr/bin/env bash
#
# Homebrew auto-upgrade agent: keep formulae and casks current without touching
# working hours. launchd starts this every evening at 18:35 (the dinner window,
# when the Mac plays a show); it upgrades only when the last good run is 3 or
# more days old, so a missed or failed evening is retried the next evening.
#
# Per evening tick:
#   last good run under 3 days ago -> nothing, silently
#   fired outside 18:30-19:15      -> no upgrade (the Mac slept through 18:35 and
#                                     launchd fired on wake); notify and leave it
#                                     to the next evening
#   otherwise                      -> brew update, upgrade formulae and casks,
#                                     cleanup, one notification
#
# Never disturbs: a cask whose app is open is skipped (brew would quit it), tmux
# is skipped while a tmux server runs (a new client against an old server can
# refuse to talk to it), casks marked auto_updates are left to their own
# updaters (no --greedy), and nothing waits on a password (launchd has no
# terminal, so a cask that needs sudo fails fast and is listed as needing you).
# Pinned formulae (brew pin) are left alone by brew itself.
#
# A failed run (brew update or the formula upgrade failed) shows a dialog that
# stays until dismissed and does not count as a good run, so the next evening
# retries. `--now` runs it by hand at any time and counts as a good run.
#
# On screen: every run posts a notification when it starts (what it is about to
# upgrade) and when it ends. Run from a terminal, it also shows each step and
# brew's own output and progress bars live, and a cask that needs your password
# asks for it there instead of being skipped.
#
# Usage:
#   brew-autoupgrade.sh              # launchd entry point
#   brew-autoupgrade.sh --now        # run now, ignoring the interval and window
#   brew-autoupgrade.sh --check      # print what the next tick would do
#   brew-autoupgrade.sh --install    # write and load the LaunchAgent
#   brew-autoupgrade.sh --uninstall  # unload and remove the LaunchAgent
#   BAU_NOW="YYYY-MM-DD HH:MM" brew-autoupgrade.sh --check   # test hook: fake clock
#
set -euo pipefail

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALL_CLEANUP=1

LABEL="local.vairav.brew-autoupgrade"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
HOUR=18 MINUTE=35        # launchd start time (local time, America/New_York)
WINDOW_END=1915          # a tick that fires later than this does not upgrade
INTERVAL_HOURS=70        # 3 days, less slack so a few minutes of drift never costs a day
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/brew-autoupgrade"
LAST_GOOD="$STATE_DIR/last-good"
LOG="$HOME/Library/Logs/brew-autoupgrade.log"

if [[ -n "${BAU_NOW:-}" ]]; then
  NOW=$(date -j -f "%Y-%m-%d %H:%M" "$BAU_NOW" +%s)
else
  NOW=$(date +%s)
fi
HHMM=$(date -r "$NOW" +%H%M)

# True when a person started this from a terminal (launchd gives no terminal).
interactive() { [[ -t 1 ]]; }

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

# A step line: logged, and printed in bold when run from a terminal.
step() {
  log "$*"
  if interactive; then printf '\033[1m==> %s\033[0m\n' "$*"; fi
}

# Runs a brew command with its output in the log. From a terminal it runs under
# script(1), which keeps brew's terminal output (progress bars included) on screen
# while appending the same output to the log.
run() {
  if interactive; then
    script -q -a "$LOG" "$@"
  else
    "$@" </dev/null >>"$LOG" 2>&1
  fi
}

notify() {
  osascript -e "display notification \"$1\" with title \"Homebrew\"" >/dev/null 2>&1 || true
}

# A dialog stays on screen until dismissed, so a failure is not lost in
# Notification Center. Backgrounded so the script does not wait on the click.
alert() {
  notify "$1"
  osascript -e "display dialog \"$1\" with title \"Homebrew\" buttons {\"OK\"} default button 1 with icon caution" \
    >/dev/null 2>&1 &
}

hours_since_good() {
  [[ -f "$LAST_GOOD" ]] || { echo 9999; return; }
  echo $(( (NOW - $(cat "$LAST_GOOD")) / 3600 ))
}

# Prints the decision for this tick: skip-recent, missed-window or run.
decide() {
  if (( $(hours_since_good) < INTERVAL_HOURS )); then
    echo skip-recent
  elif (( 10#$HHMM < 10#$(printf '%02d%02d' "$HOUR" "$MINUTE") - 5 || 10#$HHMM > 10#$WINDOW_END )); then
    echo missed-window
  else
    echo run
  fi
}

# True when the app of a cask is running, judged by its executable path.
cask_app_running() {
  local app
  while IFS= read -r app; do
    [[ -n "$app" ]] && pgrep -qf "/Applications/$app/Contents/MacOS/" && return 0
  done < <(brew info --cask --json=v2 "$1" 2>/dev/null | python3 -c '
import json, sys
for c in json.load(sys.stdin)["casks"]:
    for a in c["artifacts"]:
        for item in a.get("app", []):
            if isinstance(item, str):
                print(item)')
  return 1
}

upgrade() {
  mkdir -p "$STATE_DIR"
  step "Updating the Homebrew package lists"
  if ! run brew update; then
    log "brew update failed"
    alert "Upgrade did not run: brew update failed. Run brew-autoupgrade.sh --now, or it retries tomorrow at 18:35. Log: $LOG"
    return 1
  fi

  local formulae=() held=() needs_you=() done_count=0 f c
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ "${f##*/}" == tmux ]] && pgrep -qx tmux; then held+=("tmux"); continue; fi
    formulae+=("$f")
  done < <(brew outdated --formula --quiet)
  local casks=()
  while IFS= read -r c; do [[ -n "$c" ]] && casks+=("$c"); done < <(brew outdated --cask --quiet)

  local start_msg="Upgrading ${#formulae[@]} tools and checking ${#casks[@]} apps. This can take 10 minutes."
  (( ${#formulae[@]} + ${#casks[@]} )) || start_msg="Everything is current. Cleaning up."
  step "$start_msg"
  notify "$start_msg"

  if (( ${#formulae[@]} )); then
    step "Upgrading tools: ${formulae[*]}"
    if run brew upgrade --formula "${formulae[@]}"; then
      done_count=${#formulae[@]}
    else
      log "formula upgrade failed"
      alert "Upgrade failed while upgrading formulae. Run brew-autoupgrade.sh --now, or it retries tomorrow at 18:35. Log: $LOG"
      return 1
    fi
  fi

  for c in ${casks[@]+"${casks[@]}"}; do
    if cask_app_running "$c"; then step "Skipping $c: its app is open"; held+=("$c"); continue; fi
    step "Upgrading app: $c"
    if run brew upgrade --cask "$c"; then
      done_count=$((done_count + 1))
    else
      needs_you+=("$c")
    fi
  done

  step "Removing old versions"
  run brew cleanup --prune=30 || log "cleanup failed (not fatal)"
  echo "$NOW" >"$LAST_GOOD"

  local msg="$done_count upgraded"
  (( ${#held[@]} )) && msg+=", skipped while open: ${held[*]}"
  if (( ${#needs_you[@]} )); then
    msg+=". Needs you: brew upgrade --cask ${needs_you[*]}"
    step "Done: $msg"
    alert "$msg"
  else
    step "Done: $msg"
    notify "$msg"
  fi
}

install_agent() {
  mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
  cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SELF</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$HOUR</integer>
    <key>Minute</key>
    <integer>$MINUTE</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$LOG</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "loaded $LABEL: daily at $(printf '%02d:%02d' "$HOUR" "$MINUTE"), upgrades every 3 days"
}

case "${1:-}" in
  --now)       upgrade ;;
  --check)     echo "$(decide) (last good run $(hours_since_good)h ago, time $HHMM)" ;;
  --install)   install_agent ;;
  --uninstall) launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true; rm -f "$PLIST" ;;
  "")
    case "$(decide)" in
      skip-recent) ;;
      missed-window)
        log "fired at $HHMM, outside the evening window"
        alert "Upgrade skipped: the Mac was asleep at 18:35. Run brew-autoupgrade.sh --now, or it retries tomorrow at 18:35." ;;
      run) upgrade ;;
    esac ;;
  *) echo "usage: $(basename "$0") [--now|--check|--install|--uninstall]" >&2; exit 2 ;;
esac
