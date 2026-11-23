#!/usr/bin/env bash
#
# Arch auto-upgrade for the EndeavourOS desks (plutus, elite). The Linux
# counterpart of macos/brew-autoupgrade.sh. Plan and decisions:
# labs notes/architecture/arch-autoupgrade-plan.md.
#
# A root systemd timer runs this every day at 04:30 Eastern. It may wake a
# sleeping machine, and it holds off sleep while it works.
#
# Daily run (--run):
#   1. Arch news gate. A news item newer than the last one acknowledged can mean
#      a manual step, so the repo upgrade waits and a notification names the
#      item. `arch-autoupgrade --ack-news` releases it.
#   2. pacman -Syu. Packages in IgnorePkg (/etc/pacman.conf) stay where they are.
#   3. Installed AUR apps, through yay as the desktop user (passwordless sudo).
#   4. Report: new .pacnew files, a kernel that needs a reboot, and held
#      packages that have a newer version waiting.
#
# Held packages (the kernel and NVIDIA set on plutus) move only with --promote,
# run by hand. It upgrades them, reboots, and a boot-time health check decides:
# driver loaded, no flip timeouts, Hyprland shows as many monitors as before.
# Pass: the hold stays in place on the new versions. Fail: the previous
# versions come back from the pacman cache and the machine reboots again.
#
# Usage:
#   arch-autoupgrade --run        timer entry point
#   arch-autoupgrade --now        same as --run, from a terminal
#   arch-autoupgrade --check      what is pending, timer state, last result
#   arch-autoupgrade --ack-news   accept the current Arch news, then upgrade
#   arch-autoupgrade --promote    upgrade the held set, reboot, health check
#   arch-autoupgrade --health     boot-time check after --promote (systemd)
#   arch-autoupgrade --install    copy to /usr/local/sbin, write units, enable
#   arch-autoupgrade --uninstall  disable and remove units
#
set -uo pipefail

SELF_INSTALLED=/usr/local/sbin/arch-autoupgrade
STATE=/var/lib/arch-autoupgrade
UNIT_DIR=/etc/systemd/system
NEWS_URL=https://archlinux.org/feeds/news/
DESK_USER="$(id -nu 1000 2>/dev/null || echo vairav)"
DESK_UID=1000

log() { echo "[arch-autoupgrade] $*"; }

need_root() {
  if [[ $EUID -ne 0 ]]; then exec sudo "$0" "$@"; fi
}

# A desktop notification in the desk user's session, if one is running.
notify() {
  local urgency="$1" title="$2" body="$3"
  log "$title: $body"
  [[ -S /run/user/$DESK_UID/bus ]] || return 0
  runuser -u "$DESK_USER" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$DESK_UID/bus" \
    notify-send -a arch-autoupgrade -u "$urgency" "$title" "$body" 2>/dev/null || true
}

hypr_env() {
  local sig
  sig="$(ls -t /run/user/$DESK_UID/hypr 2>/dev/null | head -1)"
  [[ -n "$sig" ]] || return 1
  echo "XDG_RUNTIME_DIR=/run/user/$DESK_UID HYPRLAND_INSTANCE_SIGNATURE=$sig"
}

monitor_count() {
  local envs
  envs="$(hypr_env)" || { echo 0; return; }
  runuser -u "$DESK_USER" -- env $envs hyprctl -j monitors 2>/dev/null | jq 'length' 2>/dev/null || echo 0
}

ignored_pkgs() {
  sed -n 's/^IgnorePkg *= *//p' /etc/pacman.conf | tr ' ' '\n' | sed '/^$/d'
}

# --- Arch news gate ----------------------------------------------------------

# Prints "epoch<TAB>title" for each item in the feed, newest first.
news_items() {
  curl -fsS -m 30 "$NEWS_URL" | tr -d '\n' | grep -o '<item>.*' | sed 's#</item>#&\n#g' |
    while IFS= read -r item; do
      local title date
      title="$(sed -n 's#.*<title>\([^<]*\)</title>.*#\1#p' <<<"$item")"
      date="$(sed -n 's#.*<pubDate>\([^<]*\)</pubDate>.*#\1#p' <<<"$item")"
      if [[ -n "$title" && -n "$date" ]]; then
        printf '%s\t%s\n' "$(date -d "$date" +%s)" "$title"
      fi
    done
}

# Prints the titles of news items newer than the last acknowledged one.
# Fails when the feed cannot be read.
unread_news() {
  local items acked
  items="$(news_items)" && [[ -n "$items" ]] || return 1
  acked="$(cat "$STATE/news-ack" 2>/dev/null || echo 0)"
  awk -F'\t' -v a="$acked" '$1 > a {print $2}' <<<"$items" | sed 's/&gt;/>/g; s/&lt;/</g; s/&amp;/\&/g'
}

# Returns 0 when the upgrade may go ahead.
news_gate() {
  local unread
  if ! unread="$(unread_news)"; then
    log "news feed unreachable, going ahead without the news check"
    return 0
  fi
  [[ -z "$unread" ]] && return 0
  notify critical "Arch news before upgrading" \
    "$(head -3 <<<"$unread" | tr '\n' ' ')Read it, then run: arch-autoupgrade --ack-news"
  return 1
}

ack_news() {
  local newest
  newest="$(news_items | head -1 | cut -f1)"
  [[ -n "$newest" ]] || { log "news feed unreachable, news not acknowledged"; return 1; }
  echo "$newest" >"$STATE/news-ack"
  log "news acknowledged up to $(date -d "@$newest" '+%Y-%m-%d %H:%M')"
}

# --- Daily run ----------------------------------------------------------------

run() {
  exec 9>/run/arch-autoupgrade.lock
  flock -n 9 || { log "another run is in progress"; exit 0; }
  mkdir -p "$STATE"
  touch "$STATE/run-start"
  local log_start problems=()
  log_start=$(($(wc -l </var/log/pacman.log) + 1))

  if [[ -f "$STATE/history" && "$STATE/history" -nt "$STATE/last-good" ]]; then
    notify critical "Held packages were rolled back" "$(tail -1 "$STATE/history")"
  fi

  if ! news_gate; then
    log "repo upgrade held for Arch news"
    exit 0
  fi

  log "pacman -Syu"
  if ! pacman -Syu --noconfirm; then
    notify critical "Upgrade failed" "pacman -Syu failed on $(hostname). Nothing after it ran. Check: journalctl -u arch-autoupgrade"
    exit 1
  fi

  log "AUR apps"
  if ! runuser -u "$DESK_USER" -- env HOME="/home/$DESK_USER" \
      yay -Sua --noconfirm --answerclean None --answerdiff None --answeredit None --removemake; then
    problems+=("an AUR app failed to build or install")
  fi

  local changed pacnew held new_held
  changed=$(tail -n +"$log_start" /var/log/pacman.log | grep -c -E '\[ALPM\] (upgraded|installed|downgraded)')
  pacnew="$(find /etc -name '*.pacnew' -newer "$STATE/run-start" 2>/dev/null | tr '\n' ' ')"
  [[ -n "$pacnew" ]] && problems+=("new config files to merge: $pacnew")
  [[ -d "/usr/lib/modules/$(uname -r)" ]] || problems+=("a new kernel is installed, reboot to use it")

  held="$(pacman -Qu 2>/dev/null | grep '\[ignored\]' | awk '{print $1, $4}' | sort)"
  new_held="$(comm -13 <(sort "$STATE/held-notified" 2>/dev/null) <(echo "$held") | sed '/^$/d')"
  if [[ -n "$new_held" ]]; then
    echo "$held" >"$STATE/held-notified"
    notify normal "Held packages have a new version" \
      "$(tr '\n' ',' <<<"$new_held" | sed 's/,$//'). Check the release notes, then at the desk: arch-autoupgrade --promote"
  fi

  date +%s >"$STATE/last-good"
  if ((${#problems[@]})); then
    notify normal "Upgrade done with notes" "$changed packages changed. $(printf '%s. ' "${problems[@]}")"
  else
    notify low "Upgrade done" "$changed packages changed on $(hostname)."
  fi
}

# --- Held set: promote and health check ---------------------------------------

promote() {
  mkdir -p "$STATE"
  local pkgs pkg ver file missing=()
  pkgs="$(ignored_pkgs)"
  [[ -n "$pkgs" ]] || { log "nothing is held in /etc/pacman.conf"; exit 0; }
  pacman -Sy >/dev/null
  if ! pacman -Qu $pkgs 2>/dev/null | grep -q .; then
    log "the held packages have no newer version"; exit 0
  fi

  : >"$STATE/promote-prev"
  for pkg in $pkgs; do
    ver="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')" || continue
    [[ -n "$ver" ]] || continue
    file="$(ls /var/cache/pacman/pkg/"$pkg-$ver"-*.pkg.tar.zst 2>/dev/null | head -1)"
    if [[ -z "$file" ]]; then missing+=("$pkg $ver"); else echo "$file" >>"$STATE/promote-prev"; fi
  done
  if ((${#missing[@]})); then
    log "not promoting: no cached copy to roll back to for: ${missing[*]}"; exit 1
  fi

  monitor_count >"$STATE/expect-monitors"
  grep '^IgnorePkg' /etc/pacman.conf >"$STATE/ignore-line"
  log "previous versions saved, expecting $(cat "$STATE/expect-monitors") monitors after reboot"
  sed -i 's/^IgnorePkg/#IgnorePkg-promoting/' /etc/pacman.conf
  if ! pacman -Syu --noconfirm; then
    sed -i 's/^#IgnorePkg-promoting/IgnorePkg/' /etc/pacman.conf
    log "upgrade failed, hold restored, nothing to roll back"; exit 1
  fi
  sed -i 's/^#IgnorePkg-promoting/IgnorePkg/' /etc/pacman.conf
  touch "$STATE/promote-pending"
  systemctl enable arch-autoupgrade-health.service
  log "rebooting for the health check"
  systemctl reboot
}

health() {
  [[ -f "$STATE/promote-pending" ]] || exit 0
  local expect waited=0 count reason=""
  expect="$(cat "$STATE/expect-monitors" 2>/dev/null || echo 1)"
  until hypr_env >/dev/null || ((waited >= 300)); do sleep 5; waited=$((waited + 5)); done
  sleep 30
  count="$(monitor_count)"

  if journalctl -b -k --no-pager | grep -q -E 'Flip event timeout|NVRM: Xid'; then
    reason="NVIDIA flip timeouts or Xid errors in the kernel log"
  elif ! hypr_env >/dev/null; then
    reason="Hyprland did not start within 5 minutes"
  elif ((count < expect)); then
    reason="Hyprland shows $count monitors, expected $expect"
  elif ignored_pkgs | grep -q '^nvidia' && [[ ! -e /proc/driver/nvidia/version ]]; then
    reason="the NVIDIA kernel module is not loaded"
  fi

  systemctl disable arch-autoupgrade-health.service
  rm -f "$STATE/promote-pending"
  if [[ -z "$reason" ]]; then
    rm -f "$STATE/held-notified"
    notify normal "Promotion passed" "Held packages are on their new versions and stay held there."
    return 0
  fi

  log "health check failed: $reason. Rolling back."
  ignored_pkgs | xargs pacman -Q 2>/dev/null >>"$STATE/known-bad"
  xargs pacman -U --noconfirm <"$STATE/promote-prev"
  echo "$(date '+%F %T') rolled back: $reason" >>"$STATE/history"
  systemctl reboot
}

# --- Install, check -------------------------------------------------------------

install_units() {
  install -m 0755 "$(readlink -f "$0")" "$SELF_INSTALLED"
  mkdir -p "$STATE"
  cat >"$UNIT_DIR/arch-autoupgrade.service" <<EOF
[Unit]
Description=Daily Arch upgrade (repo and AUR, held packages excluded)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Nice=10
TimeoutStartSec=2h
ExecStart=/usr/bin/systemd-inhibit --what=sleep:idle --who=arch-autoupgrade --why="Upgrading packages" $SELF_INSTALLED --run
EOF
  cat >"$UNIT_DIR/arch-autoupgrade.timer" <<EOF
[Unit]
Description=Daily Arch upgrade at 04:30 Eastern

[Timer]
OnCalendar=*-*-* 04:30:00 America/New_York
Persistent=true
WakeSystem=true

[Install]
WantedBy=timers.target
EOF
  cat >"$UNIT_DIR/arch-autoupgrade-health.service" <<EOF
[Unit]
Description=Health check after promoting held kernel and driver packages
After=multi-user.target graphical.target

[Service]
Type=oneshot
TimeoutStartSec=15min
ExecStart=$SELF_INSTALLED --health

[Install]
WantedBy=multi-user.target
EOF
  # Start from today's state: news read so far is acknowledged, and held
  # versions already known are not announced again.
  [[ -f "$STATE/news-ack" ]] || ack_news || true
  [[ -f "$STATE/held-notified" ]] ||
    pacman -Qu 2>/dev/null | grep '\[ignored\]' | awk '{print $1, $4}' | sort >"$STATE/held-notified"
  systemctl daemon-reload
  systemctl enable --now arch-autoupgrade.timer
  systemctl list-timers arch-autoupgrade.timer --no-pager
}

uninstall_units() {
  systemctl disable --now arch-autoupgrade.timer 2>/dev/null
  systemctl disable arch-autoupgrade-health.service 2>/dev/null
  rm -f "$UNIT_DIR"/arch-autoupgrade{.service,.timer,-health.service} "$SELF_INSTALLED"
  systemctl daemon-reload
  log "removed; state kept in $STATE"
}

check() {
  systemctl list-timers arch-autoupgrade.timer --no-pager 2>/dev/null
  if [[ -f "$STATE/last-good" ]]; then
    log "last good run: $(date -d "@$(cat "$STATE/last-good")" '+%F %H:%M %Z')"
  else
    log "no good run yet"
  fi
  log "held in pacman.conf: $(ignored_pkgs | tr '\n' ' ')"
  log "repo updates waiting: $(checkupdates 2>/dev/null | wc -l)"
  log "AUR updates waiting: $(runuser -u "$DESK_USER" -- yay -Qua 2>/dev/null | wc -l)"
  local unread
  if ! unread="$(unread_news)"; then log "Arch news: feed unreachable"
  elif [[ -z "$unread" ]]; then log "Arch news: nothing unread"
  else log "Arch news unread (run --ack-news after reading): $(tr '\n' ';' <<<"$unread")"; fi
  if [[ -f "$STATE/history" ]]; then tail -3 "$STATE/history"; fi
}

case "${1:-}" in
  --run | --now) need_root "$@"; run ;;
  --check) need_root "$@"; check ;;
  --ack-news) need_root "$@"; mkdir -p "$STATE"; ack_news && run ;;
  --promote) need_root "$@"; promote ;;
  --health) need_root "$@"; health ;;
  --install) need_root "$@"; install_units ;;
  --uninstall) need_root "$@"; uninstall_units ;;
  *) sed -n '2,/^set -uo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 2 ;;
esac
