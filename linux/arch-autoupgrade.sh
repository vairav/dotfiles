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
#      An app whose PKGBUILD now downloads from a site it never used before is
#      held back (a hijacked AUR package usually shows up this way) until
#      `arch-autoupgrade --approve-aur <name>`.
#   4. Report: new .pacnew files, a kernel that needs a reboot, programs that
#      need a restart, and held packages that have a newer version waiting.
#
# Alerts: one line per event to ntfy (topic in /etc/arch-autoupgrade/ntfy-topic,
# from the 1Password item bank-sync-ntfy-topic), the same path the home-lab
# health checks use. Desktop notifications carry the details.
#
# Held packages (the kernel and NVIDIA set on plutus) move only with --promote,
# run by hand. It upgrades them and reboots. A boot-time health check reads the
# kernel log a minute after boot (no login needed, because a broken driver can
# leave the login screen black): driver loaded, no flip timeouts or Xid errors.
# When Vairav logs in within 30 minutes, it also checks that Hyprland shows as
# many monitors as before. Pass: the hold stays in place on the new versions.
# Fail: the previous versions come back from the pacman cache, an alert goes
# out, and the machine reboots again.
#
# Usage:
#   arch-autoupgrade --run        timer entry point
#   arch-autoupgrade --now        same as --run, from a terminal
#   arch-autoupgrade --check      what is pending, timer state, last result
#   arch-autoupgrade --ack-news   accept the current Arch news, then upgrade
#   arch-autoupgrade --promote    upgrade the held set, reboot, health check
#   arch-autoupgrade --health     boot-time check after --promote (systemd)
#   arch-autoupgrade --approve-aur <name>  accept an AUR app's new download site
#   arch-autoupgrade --install    copy to /usr/local/sbin, write units, enable
#   arch-autoupgrade --uninstall  disable and remove units
#
# Drill switches for --health: ARCH_AUTOUPGRADE_DRYRUN=1 prints the rollback
# steps instead of running them, ARCH_AUTOUPGRADE_NOREBOOT=1 runs them but does
# not reboot.
#
set -uo pipefail

SELF_INSTALLED=/usr/local/sbin/arch-autoupgrade
STATE=/var/lib/arch-autoupgrade
UNIT_DIR=/etc/systemd/system
NEWS_URL=https://archlinux.org/feeds/news/
DESK_USER="$(id -nu 1000 2>/dev/null || echo vairav)"
DESK_UID=1000
CONF_DIR=/etc/arch-autoupgrade
TOPIC_FILE=$CONF_DIR/ntfy-topic
NTFY_URL=https://ntfy.sh
AUR_HOSTS=$STATE/aur-hosts
DRYRUN="${ARCH_AUTOUPGRADE_DRYRUN:-}"
NOREBOOT="${ARCH_AUTOUPGRADE_NOREBOOT:-}"

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

# One short line to ntfy, for anything that needs Vairav. Level is WARN or INFO.
alert() {
  local line
  line="$1 arch-autoupgrade $(hostname): $2"
  log "alert: $line"
  [[ -z "$DRYRUN" ]] || return 0
  [[ -r "$TOPIC_FILE" ]] || { log "no ntfy topic in $TOPIC_FILE, alert not sent"; return 0; }
  curl -fsS -m 15 -d "$line" "$NTFY_URL/$(cat "$TOPIC_FILE")" >/dev/null || log "ntfy push failed"
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
  alert WARN "upgrade waits for Arch news: $(head -1 <<<"$unread")"
  return 1
}

ack_news() {
  local newest
  newest="$(news_items | head -1 | cut -f1)"
  [[ -n "$newest" ]] || { log "news feed unreachable, news not acknowledged"; return 1; }
  echo "$newest" >"$STATE/news-ack"
  log "news acknowledged up to $(date -d "@$newest" '+%Y-%m-%d %H:%M')"
}

# --- AUR download sites -------------------------------------------------------

# Prints "name<TAB>host" for every download host in the AUR's current .SRCINFO
# of the given packages. The .SRCINFO has the variables already expanded.
aur_source_hosts() {
  (($#)) || return 0
  local query name base
  query="$(printf '&arg[]=%s' "$@" | sed 's/+/%2B/g')"
  curl -fsS -m 30 "https://aur.archlinux.org/rpc/v5/info?${query#&}" |
    jq -r '.results[] | "\(.Name) \(.PackageBase)"' |
    while read -r name base; do
      curl -fsS -m 30 "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=$base" |
        sed -n 's/^[[:space:]]*source\(_[a-z0-9_]*\)\{0,1\} = //p' | grep -o '://[^/]*' |
        sed 's#^://##; s#.*@##' | sort -u | sed "s/^/$name\t/"
    done
}

# Records today's download hosts for AUR packages that have no record yet.
seed_aur_hosts() {
  mkdir -p "$AUR_HOSTS"
  local missing=() name host
  for name in $(pacman -Qmq); do [[ -f "$AUR_HOSTS/$name" ]] || missing+=("$name"); done
  ((${#missing[@]})) || return 0
  aur_source_hosts "${missing[@]}" | while IFS=$'\t' read -r name host; do
    echo "$host" >>"$AUR_HOSTS/$name"
  done
  log "recorded AUR download sites for up to ${#missing[@]} packages"
}

# Fills AUR_SKIP with the given AUR packages whose download hosts include one
# that package never used before. Alerts once per package and new host set.
AUR_SKIP=()
check_aur_hosts() {
  (($#)) || return 0
  local name host new
  local -A newhosts=()
  mkdir -p "$AUR_HOSTS"
  while IFS=$'\t' read -r name host; do
    [[ -n "$name" && -f "$AUR_HOSTS/$name" ]] || continue   # first sight: recorded after the upgrade
    grep -qxF "$host" "$AUR_HOSTS/$name" || newhosts[$name]+="$host "
  done < <(aur_source_hosts "$@")
  for name in "${!newhosts[@]}"; do
    new="${newhosts[$name]% }"
    AUR_SKIP+=("$name")
    if [[ "$(cat "$AUR_HOSTS/$name.alerted" 2>/dev/null)" != "$new" ]]; then
      echo "$new" >"$AUR_HOSTS/$name.alerted"
      alert WARN "AUR $name held back, now downloads from $new. Approve: arch-autoupgrade --approve-aur $name"
    fi
  done
}

# After a good AUR step, adds the hosts of the packages that were upgraded.
record_aur_hosts() {
  local name host skip=" ${AUR_SKIP[*]} "
  mkdir -p "$AUR_HOSTS"
  aur_source_hosts "$@" | while IFS=$'\t' read -r name host; do
    [[ "$skip" == *" $name "* ]] && continue
    grep -qxF "$host" "$AUR_HOSTS/$name" 2>/dev/null || echo "$host" >>"$AUR_HOSTS/$name"
  done
}

approve_aur() {
  local name="$1" host
  [[ -n "$name" ]] || { log "usage: arch-autoupgrade --approve-aur <name>"; exit 2; }
  mkdir -p "$AUR_HOSTS"
  aur_source_hosts "$name" | while IFS=$'\t' read -r _ host; do
    grep -qxF "$host" "$AUR_HOSTS/$name" 2>/dev/null || { echo "$host" >>"$AUR_HOSTS/$name"; log "$name: approved $host"; }
  done
  rm -f "${AUR_HOSTS:?}/${name:?}.alerted"
}

# Desk-user programs still running files that an upgrade replaced.
needs_restart() {
  local maps pid
  for maps in $(grep -l -s -E ' /usr/.* \(deleted\)$' /proc/[0-9]*/maps); do
    pid="${maps#/proc/}"; pid="${pid%/maps}"
    [[ "$(stat -c %u "/proc/$pid" 2>/dev/null)" == "$DESK_UID" ]] && cat "/proc/$pid/comm" 2>/dev/null
  done | sort -u | tr '\n' ' ' | sed 's/ $//'
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
    alert WARN "pacman -Syu failed, nothing upgraded. journalctl -u arch-autoupgrade"
    exit 1
  fi

  log "AUR apps"
  local pending_aur=() ignore_arg=()
  mapfile -t pending_aur < <(runuser -u "$DESK_USER" -- env HOME="/home/$DESK_USER" yay -Qua 2>/dev/null | awk '{print $1}')
  check_aur_hosts "${pending_aur[@]}"
  if ((${#AUR_SKIP[@]})); then
    ignore_arg=(--ignore "$(IFS=,; echo "${AUR_SKIP[*]}")")
    problems+=("AUR apps held back for a new download site: ${AUR_SKIP[*]}")
  fi
  if runuser -u "$DESK_USER" -- env HOME="/home/$DESK_USER" \
      yay -Sua --noconfirm --answerclean None --answerdiff None --answeredit None --removemake "${ignore_arg[@]}"; then
    record_aur_hosts "${pending_aur[@]}"
  else
    problems+=("an AUR app failed to build or install")
    alert WARN "an AUR app failed to build or install. journalctl -u arch-autoupgrade"
  fi

  local changed pacnew held new_held
  changed=$(tail -n +"$log_start" /var/log/pacman.log | grep -c -E '\[ALPM\] (upgraded|installed|downgraded)')
  pacnew="$(find /etc -name '*.pacnew' -newer "$STATE/run-start" 2>/dev/null | tr '\n' ' ')"
  [[ -n "$pacnew" ]] && problems+=("new config files to merge: $pacnew")
  [[ -d "/usr/lib/modules/$(uname -r)" ]] || problems+=("a new kernel is installed, reboot to use it")
  local restart
  restart="$(needs_restart)"
  [[ -n "$restart" ]] && problems+=("restart to finish: $restart")

  held="$(pacman -Qu 2>/dev/null | grep '\[ignored\]' | awk '{print $1, $4}' | sort)"
  new_held="$(comm -13 <(sort "$STATE/held-notified" 2>/dev/null) <(echo "$held") | sed '/^$/d')"
  if [[ -n "$new_held" ]]; then
    echo "$held" >"$STATE/held-notified"
    notify normal "Held packages have a new version" \
      "$(tr '\n' ',' <<<"$new_held" | sed 's/,$//'). Check the release notes, then at the desk: arch-autoupgrade --promote"
    alert INFO "held packages have a new version: $(tr '\n' ',' <<<"$new_held" | sed 's/,$//')"
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

  # Kernel side first. It needs no login, and a broken driver can leave the
  # login screen black, so this check must not wait for Vairav.
  [[ -n "$DRYRUN" ]] || sleep 60
  reason="$(driver_problem)"

  if [[ -z "$reason" ]]; then
    until hypr_env >/dev/null || ((waited >= 1800)); do sleep 10; waited=$((waited + 10)); done
    if hypr_env >/dev/null; then
      [[ -n "$DRYRUN" ]] || sleep 20
      count="$(monitor_count)"
      reason="$(driver_problem)"
      if [[ -z "$reason" ]] && ((count < expect)); then
        reason="Hyprland shows $count monitors, expected $expect"
      fi
    else
      log "no login within 30 minutes, so the monitor count was not checked; kernel checks passed"
    fi
  fi

  if [[ -z "$DRYRUN" ]]; then
    systemctl disable arch-autoupgrade-health.service
    rm -f "${STATE:?}/promote-pending"
  fi
  if [[ -z "$reason" ]]; then
    [[ -n "$DRYRUN" ]] || rm -f "${STATE:?}/held-notified"
    notify normal "Promotion passed" "Held packages are on their new versions and stay held there."
    alert INFO "promotion passed, held packages now: $(ignored_pkgs | xargs pacman -Q 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
    return 0
  fi
  rollback "$reason"
}

# Prints why the driver looks broken in this boot, or nothing.
driver_problem() {
  if journalctl -b -k --no-pager | grep -q -E 'Flip event timeout|NVRM: Xid'; then
    echo "NVIDIA flip timeouts or Xid errors in the kernel log"
  elif ignored_pkgs | grep -q '^nvidia' && [[ ! -e /proc/driver/nvidia/version ]]; then
    echo "the NVIDIA kernel module is not loaded"
  fi
}

rollback() {
  local reason="$1" prev=()
  mapfile -t prev <"$STATE/promote-prev"
  log "health check failed: $reason"
  log "rolling back to: $(printf '%s\n' "${prev[@]}" | xargs -n1 basename | tr '\n' ' ')"
  if [[ -n "$DRYRUN" ]]; then
    log "[dry-run] would record as known bad: $(ignored_pkgs | xargs pacman -Q 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
    log "[dry-run] would run: pacman -U --noconfirm ${prev[*]}"
    log "[dry-run] would alert, then reboot"
    alert WARN "promotion failed ($reason), rolled back to the previous kernel and driver, rebooting"
    return 0
  fi
  ignored_pkgs | xargs pacman -Q 2>/dev/null >>"$STATE/known-bad"
  pacman -U --noconfirm "${prev[@]}"
  echo "$(date '+%F %T') rolled back: $reason" >>"$STATE/history"
  alert WARN "promotion failed ($reason), rolled back to the previous kernel and driver, rebooting"
  if [[ -n "$NOREBOOT" ]]; then log "reboot skipped (ARCH_AUTOUPGRADE_NOREBOOT)"; else systemctl reboot; fi
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
Type=simple
ExecStart=$SELF_INSTALLED --health

[Install]
WantedBy=multi-user.target
EOF
  # Start from today's state: news read so far is acknowledged, and held
  # versions already known are not announced again.
  install -d -m 0700 "$CONF_DIR"
  [[ -f "$STATE/news-ack" ]] || ack_news || true
  seed_aur_hosts
  [[ -f "$STATE/held-notified" ]] ||
    pacman -Qu 2>/dev/null | grep '\[ignored\]' | awk '{print $1, $4}' | sort >"$STATE/held-notified"
  systemctl daemon-reload
  systemctl enable --now arch-autoupgrade.timer
  systemctl list-timers arch-autoupgrade.timer --no-pager
}

uninstall_units() {
  systemctl disable --now arch-autoupgrade.timer 2>/dev/null
  systemctl disable arch-autoupgrade-health.service 2>/dev/null
  rm -f "${UNIT_DIR:?}"/arch-autoupgrade{.service,.timer,-health.service} "${SELF_INSTALLED:?}"
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
  if [[ -r "$TOPIC_FILE" ]]; then log "ntfy alerts: on"; else log "ntfy alerts: OFF, no $TOPIC_FILE"; fi
  log "AUR apps with recorded download sites: $(find "$AUR_HOSTS" -type f ! -name '*.alerted' 2>/dev/null | wc -l)"
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
  --approve-aur) need_root "$@"; approve_aur "${2:-}" ;;
  --install) need_root "$@"; install_units ;;
  --uninstall) need_root "$@"; uninstall_units ;;
  *) sed -n '2,/^set -uo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 2 ;;
esac
