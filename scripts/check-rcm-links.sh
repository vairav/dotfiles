#!/usr/bin/env bash
#
# Prove that rcm delivered what the repos track.
#
# rcm drops a file without a word when any EXCLUDES pattern matches it, and a
# pattern matches at any depth: `*.md` matches claude/CLAUDE.md, and `zshrc`
# matches config/zshrc/. The file sits in the repo, reads correctly, and never
# reaches the machine. Reading the config cannot show that, so this script
# compares the outcome against the repos, and every tracked file must have a
# stated reason to exist:
#
#   1. Every path in the rcm plan (lsrc) is a symlink to its planned source.
#   2. Every tracked file is one of:
#        - linked, directly or inside a folder that is linked whole
#        - overridden by the same path in an earlier dotfiles directory
#        - in a tag or host folder this machine does not use
#        - listed in that repo's .rcm-not-linked
#      Anything else is a problem, so a new file has to be linked or declared.
#
# Exit status: 0 when clean, 1 when there is a problem or the check cannot run.
# Runs after every rcup (hooks/post-up/40-check-links).

set -uo pipefail

DOTFILES="${DOTFILES:-$HOME/workspace/dotfiles}"
export RCRC="${RCRC:-$DOTFILES/rcrc}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

problems=0
problem() {
  echo -e "${RED}[links] $1${NC}" >&2
  problems=$((problems + 1))
}

if ! command -v lsrc >/dev/null 2>&1; then
  echo -e "${RED}[links] lsrc not found, so nothing was checked${NC}" >&2
  exit 1
fi

# rcrc is a shell file, and this reads the values it ends up with.
eval "$(bash -c '. "$RCRC" >/dev/null 2>&1
  printf "DIRS=%q\nACTIVE_TAGS=%q\nHOST=%q\n" "${DOTFILES_DIRS:-}" "${TAGS:-}" "${HOSTNAME:-}"')"

plan="$(lsrc 2>/dev/null)"
# An empty plan means the tool failed. Treating it as "nothing to check" would
# report success on the exact failure this script exists to catch.
if [[ -z "$plan" ]]; then
  echo -e "${RED}[links] lsrc returned an empty plan, so nothing was checked${NC}" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Paths relative to a dotfiles directory, with any tag or host folder removed.
strip_tag_or_host() {
  case "$1" in
    tag-*/* | host-*/*) echo "${1#*/}" ;;
    *) echo "$1" ;;
  esac
}

: >"$tmp/sources"
: >"$tmp/relative"
: >"$tmp/whole"
while IFS=: read -r dest src _; do
  if [[ ! -L "$dest" ]]; then
    problem "not linked: $dest should link to $src"
  elif [[ "$(readlink "$dest")" != "$src" ]]; then
    problem "wrong link: $dest points to $(readlink "$dest"), expected $src"
  fi
  echo "$src" >>"$tmp/sources"
  [[ -d "$src" ]] && echo "$src" >>"$tmp/whole"
  for dir in $DIRS; do
    case "$src" in
      "$dir"/*) strip_tag_or_host "${src#"$dir"/}" >>"$tmp/relative" ;;
    esac
  done
done <<<"$plan"

declared_not_linked() {
  local rel="$1" list="$2" pattern
  [[ -f "$list" ]] || return 1
  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    case "$pattern" in '' | '#'*) continue ;; esac
    # Unquoted on purpose: the line is a shell pattern, and * matches / here.
    # shellcheck disable=SC2254
    case "$rel" in $pattern) return 0 ;; esac
  done <"$list"
  return 1
}

inside_whole_link() {
  local file="$1" whole
  while IFS= read -r whole; do
    case "$file" in "$whole"/*) return 0 ;; esac
  done <"$tmp/whole"
  return 1
}

for dir in $DIRS; do
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || continue
  while IFS= read -r path; do
    case "$path" in
      tag-*/*)
        tag="${path%%/*}"
        [[ " $ACTIVE_TAGS " == *" ${tag#tag-} "* ]] || continue
        ;;
      host-*/*)
        [[ "${path%%/*}" == "host-$HOST" ]] || continue
        ;;
    esac
    file="$dir/$path"
    rel="$(strip_tag_or_host "$path")"
    grep -Fxq "$file" "$tmp/sources" && continue
    inside_whole_link "$file" && continue
    grep -Fxq "$rel" "$tmp/relative" && continue
    declared_not_linked "$rel" "$dir/.rcm-not-linked" && continue
    problem "tracked but not delivered: $file (link it, or list it in .rcm-not-linked)"
  done < <(git -C "$dir" ls-files)
done

if [[ "$problems" -gt 0 ]]; then
  echo -e "${RED}[links] $problems problem(s): rcm did not deliver what the repos track${NC}" >&2
  exit 1
fi

echo -e "${GREEN}[links] Clean: $(wc -l <"$tmp/sources" | tr -d ' ') links verified, every tracked file accounted for${NC}"
exit 0
