#!/usr/bin/env bash
#
# Trading-window reconciler: during the trading window on US market days,
# keep the trading apps RUNNING and the displays AWAKE; outside it, keep the
# apps QUIT and let the displays sleep on the normal `pmset displaysleep`
# timer.
#
# This is a RECONCILER, not a pair of open/close events, on purpose. A
# launchd user agent runs it every 5 minutes and each run asserts the desired
# state, so every failure self-heals within one tick: a reboot at 08:05 still
# gets its apps, a crashed app relaunches mid-session, a missed close still
# quits. Calendar-fired events get exactly one chance at each of those.
# Stateless too: it never touches pmset, so no toggled global state can be
# left stuck by a crash.
#
# Inside the window each run holds a user-activity assertion (caffeinate -u)
# slightly shorter than the launchd interval, which both wakes sleeping
# displays and keeps them lit. Apps are launched only when absent (no focus
# churn) and quit only when present (a bare AppleScript quit would LAUNCH a
# stopped app just to quit it).
#
# Market days come from nyse-holidays.txt next to this script. When the
# calendar's coverage runs out it fails OPEN (assumes every weekday trades)
# and says so via syslog - a lit monitor on a holiday costs pennies, a dark
# one mid-session costs trades.
#
# Usage:
#   trading-window.sh                            # launchd entry point
#   trading-window.sh --check "2026-11-27 12:59" # print the decision
#
set -euo pipefail

HOLIDAYS="$(cd "$(dirname "$0")" && pwd)/nyse-holidays.txt"
APPS=("TradingView" "thinkorswim")   # must match /Applications names
OPEN=0800          # window start (all times America/New_York)
CLOSE=1630         # window end: 30 min past the 16:00 close
HALF_CLOSE=1330    # early-close sessions (13:00 close + 30 min)
HOLD=290           # assertion seconds; must stay below the launchd interval

# args: "YYYY-MM-DD" "HHMM" "day-of-week 1-7"; all in America/New_York
window_is_open() {
  local day="$1" hhmm="$2" dow="$3"

  [ "$dow" -ge 6 ] && return 1                        # weekend

  local close="$CLOSE" entry=""
  entry="$(grep -E "^$day( |\$)" "$HOLIDAYS" || true)"
  if [ -n "$entry" ]; then
    case "$entry" in
      *half*) close="$HALF_CLOSE" ;;                  # early close
      *)      return 1 ;;                             # full holiday
    esac
  fi

  local coverage
  coverage="$(sed -n 's/^# coverage-through //p' "$HOLIDAYS")"
  if [ -n "$coverage" ] && [[ "$day" > "$coverage" ]]; then
    logger -t trading-window \
      "nyse-holidays.txt coverage ended $coverage - assuming market day; update the calendar"
  fi

  [ "$hhmm" -ge "$OPEN" ] && [ "$hhmm" -lt "$close" ]
}

app_running() { pgrep -fq "/Applications/$1" ; }

if [ "${1:-}" = "--check" ]; then
  d="${2%% *}"; t="${2##* }"; t="${t/:/}"
  dow="$(TZ=America/New_York date -j -f "%Y-%m-%d" "$d" "+%u")"
  if window_is_open "$d" "$t" "$dow"; then
    echo "OPEN   $2 (apps running, displays held awake)"
  else
    echo "closed $2 (apps quit, normal displaysleep)"
  fi
  exit 0
fi

read -r day hhmm dow <<< "$(TZ=America/New_York date '+%Y-%m-%d %H%M %u')"

if window_is_open "$day" "$hhmm" "$dow"; then
  for app in "${APPS[@]}"; do
    app_running "$app" || open -a "$app" \
      || logger -t trading-window "could not launch $app"
  done
  exec caffeinate -u -t "$HOLD"
else
  for app in "${APPS[@]}"; do
    if app_running "$app"; then
      osascript -e "tell application \"$app\" to quit" >/dev/null 2>&1 \
        || logger -t trading-window "could not quit $app"
    fi
  done
fi
