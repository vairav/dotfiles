#!/usr/bin/env bash
#
# Trading-window agent: on US market days, give the trading apps a fresh
# start at the window open, keep them RUNNING and the displays AWAKE through
# the session, and quit them ONCE when the window closes. Outside market
# days it does NOTHING - manual app sessions (weekends, evenings, holidays)
# are never touched.
#
# Semantics per tick (launchd runs this every 5 minutes):
#   non-market day          -> no action, ever
#   market day, pre-open    -> no action (a pre-market manual session is
#                              replaced at the open, not before)
#   market day, open        -> FIRST tick: quit any already-running apps and
#                              relaunch fresh (stale overnight sessions get a
#                              clean login state); every tick: launch absent
#                              apps, hold a caffeinate -u user-activity
#                              assertion so displays wake and stay lit
#   market day, post-close  -> ONE quit at the close transition, then hands
#                              off; apps started manually later stay up
#
# Inside the window this is still a reconciler - a reboot at 08:05 gets its
# apps, a crashed app relaunches within one tick, a close missed while the
# agent was down is caught by the first later tick (still exactly one quit).
# The open/close transitions are one-shot, tracked in a state file under
# ~/.local/state/trading-window/ (regenerable; safe to delete).
#
# Market days come from nyse-holidays.txt next to this script. When the
# calendar's coverage runs out it fails OPEN (assumes every weekday trades)
# and says so via syslog - a lit monitor on a holiday costs pennies, a dark
# one mid-session costs trades.
#
# Usage:
#   trading-window.sh                            # launchd entry point
#   trading-window.sh --check "2026-11-27 12:59" # print the decision
#   TW_NOW="YYYY-MM-DD HHMM" trading-window.sh   # test hook: fake clock
#
set -euo pipefail

HOLIDAYS="$(cd "$(dirname "$0")" && pwd)/nyse-holidays.txt"
APPS=("TradingView" "thinkorswim")   # must match /Applications names
OPEN=0800          # window start (all times America/New_York)
CLOSE=1630         # window end: 30 min past the 16:00 close
HALF_CLOSE=1330    # early-close sessions (13:00 close + 30 min)
HOLD=290           # assertion seconds; must stay below the launchd interval
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/trading-window"
STATE_FILE="$STATE_DIR/last-transition"

# args: "YYYY-MM-DD" "day-of-week 1-7". Echoes the day's closing HHMM, or
# "none" when the market is closed all day (weekend / full holiday).
market_close() {
  local day="$1" dow="$2"
  [ "$dow" -ge 6 ] && { echo none; return 0; }        # weekend

  local close="$CLOSE" entry=""
  entry="$(grep -E "^$day( |\$)" "$HOLIDAYS" || true)"
  if [ -n "$entry" ]; then
    case "$entry" in
      *half*) close="$HALF_CLOSE" ;;                  # early close
      *)      echo none; return 0 ;;                  # full holiday
    esac
  fi

  local coverage
  coverage="$(sed -n 's/^# coverage-through //p' "$HOLIDAYS")"
  if [ -n "$coverage" ] && [[ "$day" > "$coverage" ]]; then
    logger -t trading-window \
      "nyse-holidays.txt coverage ended $coverage - assuming market day; update the calendar"
  fi

  echo "$close"
}

app_running() { pgrep -fq "/Applications/$1" ; }

# Graceful quit of any running app, then wait (bounded) for the processes to
# exit so a relaunch in the same tick starts a FRESH instance instead of
# racing the shutdown. A bare AppleScript quit would LAUNCH a stopped app
# just to quit it, hence the app_running guard.
quit_apps() {
  local app any=0
  for app in "${APPS[@]}"; do
    if app_running "$app"; then
      any=1
      osascript -e "tell application \"$app\" to quit" >/dev/null 2>&1 \
        || logger -t trading-window "could not quit $app"
    fi
  done
  [ "$any" = 1 ] || return 0
  local i still
  for i in $(seq 1 20); do
    still=0
    for app in "${APPS[@]}"; do app_running "$app" && still=1; done
    [ "$still" = 0 ] && return 0
    sleep 1
  done
  logger -t trading-window "app(s) still running 20s after quit - leaving to next tick"
}

phase_for() { # args: day hhmm dow -> open | pre-open | post-close | off
  local day="$1" hhmm="$2" dow="$3" close
  close="$(market_close "$day" "$dow")"
  if [ "$close" = none ]; then echo off
  elif [ "$hhmm" -ge "$OPEN" ] && [ "$hhmm" -lt "$close" ]; then echo open
  elif [ "$hhmm" -ge "$close" ]; then echo post-close
  else echo pre-open
  fi
}

if [ "${1:-}" = "--check" ]; then
  d="${2%% *}"; t="${2##* }"; t="${t/:/}"
  dow="$(TZ=America/New_York date -j -f "%Y-%m-%d" "$d" "+%u")"
  case "$(phase_for "$d" "$t" "$dow")" in
    open)       echo "OPEN       $2 (fresh start at open, then apps kept running, displays held awake)" ;;
    pre-open)   echo "pre-open   $2 (market day, window not started - no action)" ;;
    post-close) echo "post-close $2 (one-time quit at close, manual sessions untouched after)" ;;
    off)        echo "off        $2 (non-market day - agent does nothing)" ;;
  esac
  exit 0
fi

if [ -n "${TW_NOW:-}" ]; then
  read -r day hhmm <<< "$TW_NOW"
  dow="$(TZ=America/New_York date -j -f "%Y-%m-%d" "$day" "+%u")"
else
  read -r day hhmm dow <<< "$(TZ=America/New_York date '+%Y-%m-%d %H%M %u')"
fi

state=""
[ -f "$STATE_FILE" ] && state="$(cat "$STATE_FILE")"

case "$(phase_for "$day" "$hhmm" "$dow")" in
  off|pre-open)
    ;;                                                # not our hours - hands off
  open)
    if [ "$state" != "$day open" ] && [ "$state" != "$day closed" ]; then
      quit_apps                                       # fresh start at the open
      mkdir -p "$STATE_DIR"
      printf '%s open\n' "$day" > "$STATE_FILE"
      logger -t trading-window "market open $day - fresh app start"
    fi
    for app in "${APPS[@]}"; do
      app_running "$app" || open -a "$app" \
        || logger -t trading-window "could not launch $app"
    done
    exec caffeinate -u -t "$HOLD"
    ;;
  post-close)
    if [ "$state" != "$day closed" ]; then
      quit_apps                                       # the one quit of the day
      mkdir -p "$STATE_DIR"
      printf '%s closed\n' "$day" > "$STATE_FILE"
      logger -t trading-window "market closed $day - apps quit once, hands off now"
    fi
    ;;
esac
