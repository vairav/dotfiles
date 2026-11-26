#!/usr/bin/env bash
#
# Lets sessions on titan log in to the EndeavourOS desks (plutus, elite) as
# vairav with the home-lab app key, without the 1Password SSH agent, which
# locks overnight. Vairav chose this on 2026-11-26 over a separate app user.
#
# It writes one line to ~/.ssh/authorized_keys of the user who runs it:
#
#   from="<addresses>",no-agent-forwarding,no-X11-forwarding <app key> homelab-app@titan
#
# The from= limit means only the listed source addresses can use the key.
# The comment homelab-app@titan marks the line. A run replaces that one line
# when its content changed and leaves every other line as it was. A second run
# with the same arguments changes nothing.
#
# It refuses when the same key already sits on an unmarked line, because that
# line would let the key in from anywhere and make the from= limit pointless.
#
# Run it on the desk as vairav. The desk has no 1Password access, so titan
# reads the public key and passes it in (labs/homelab bin/desk-ssh shows how):
#
#   ssh vairav@<desk> bash -s -- --from 192.168.4.31 --key "'$PUB'" < linux/desk-app-key.sh
#
# Usage:
#   desk-app-key.sh --from <addr[,addr...]> --key "<type> <base64>"
#   desk-app-key.sh --remove      delete the marked line
#
set -euo pipefail

MARK=homelab-app@titan
AK="$HOME/.ssh/authorized_keys"
FROM="" KEY="" REMOVE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM=${2:?--from needs a value}; shift 2 ;;
    --key) KEY=${2:?--key needs a value}; shift 2 ;;
    --remove) REMOVE=1; shift ;;
    *) echo "desk-app-key: unknown argument $1" >&2; exit 2 ;;
  esac
done

# Builds the new file in a temp file in ~/.ssh and moves it over the real one
# only when every step succeeded, so a failed read never leaves an empty or
# cut-off authorized_keys. Lines come from the command given as arguments.
TMP=""
trap '[ -n "$TMP" ] && rm -f "$TMP"' EXIT
replace_file() {
  TMP=$(mktemp "$HOME/.ssh/.authorized_keys.XXXXXX")
  "$@" > "$TMP" || { echo "desk-app-key: could not build the new file; $AK left as it was" >&2; exit 1; }
  chmod 600 "$TMP"
  mv "$TMP" "$AK"
  TMP=""
}

# Every line except the marked one, in the original order.
other_lines() {
  [ -f "$AK" ] || return 0
  awk -v m="$MARK" '$NF != m' "$AK"
}

new_file() {
  other_lines && printf '%s\n' "$LINE"
}

# mv would replace a link with a plain file and leave the real target as it was.
if [ -L "$AK" ]; then
  echo "desk-app-key: $AK is a symlink; edit its target by hand instead" >&2; exit 1
fi

if [ "$REMOVE" = 1 ]; then
  if [ -f "$AK" ] && awk -v m="$MARK" '$NF == m {f=1} END {exit !f}' "$AK"; then
    replace_file other_lines
    echo "desk-app-key: removed the $MARK line"
  else
    echo "desk-app-key: no $MARK line, nothing to remove"
  fi
  exit 0
fi

[ -n "$FROM" ] && [ -n "$KEY" ] || { echo "desk-app-key: --from and --key are required" >&2; exit 2; }

# Plain addresses and CIDR ranges only. No ssh wildcards, because "*" would
# lift the limit, and anything else could break out of the quoted from= value.
case "$FROM" in
  *[!0-9A-Fa-f.:/,]*|*/0|*/0,*|"") echo "desk-app-key: bad --from value: $FROM" >&2; exit 2 ;;
esac

# Exactly a key type and a base64 body, and ssh-keygen must accept it.
read -r KTYPE KBODY KREST <<<"$KEY"
if [ -z "$KTYPE" ] || [ -z "$KBODY" ] || [ -n "${KREST:-}" ] \
   || [[ ! "$KTYPE" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))$ ]] \
   || [[ ! "$KBODY" =~ ^[A-Za-z0-9+/]+=*$ ]] \
   || ! ssh-keygen -lf /dev/stdin <<<"$KTYPE $KBODY" >/dev/null 2>&1; then
  echo "desk-app-key: --key is not a single public key (type and base64 only)" >&2; exit 2
fi

LINE="from=\"$FROM\",no-agent-forwarding,no-X11-forwarding $KTYPE $KBODY $MARK"

install -d -m 700 "$HOME/.ssh"

if [ -f "$AK" ] && awk -v k="$KBODY" -v m="$MARK" '$NF != m && index($0, k) {f=1} END {exit !f}' "$AK"; then
  echo "desk-app-key: this key is already on an unmarked line in $AK; refusing" >&2
  exit 1
fi

if [ -f "$AK" ] && grep -qxF -- "$LINE" "$AK" \
   && [ "$(awk -v m="$MARK" '$NF == m' "$AK" | wc -l)" -eq 1 ]; then
  echo "desk-app-key: unchanged"
  exit 0
fi

replace_file new_file
echo "desk-app-key: wrote the $MARK line (from=$FROM)"
