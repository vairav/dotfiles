---
title: Tmux
nav_order: 6
---

# Tmux Workflow

Replaces the "6-8 terminal windows arranged with Rectangle" habit: one terminal
window, all shells live inside tmux sessions you can detach from and reattach
to — locally or over SSH from another machine.

## The mental model

- **Session** = a project or context (what used to be "a group of terminals").
- **Window** = a tab inside a session (what used to be one terminal window).
- **Pane** = a split inside a window.

Sessions survive closing the terminal app. `tmux-resurrect` + `tmux-continuum`
also save them every 15 min and restore after a reboot.

## Keys (prefix is `Ctrl-b`, the tmux default)

The prefix is deliberately NOT `Ctrl-a`: readline's beginning-of-line
(`Ctrl-a`) is in heavy use, and `Ctrl-e` / `Ctrl-w` etc. are untouched by
tmux anyway. Every command below means: press `Ctrl-b`, release, then the key.

| Keys | Action |
|------|--------|
| `prefix s` | **Session picker** (sesh + fzf popup) — the main way to move around |
| `prefix S` | Native session tree (fallback if sesh is unavailable) |
| `prefix L` | Jump to previous session |
| `prefix c` | New window (in current path) |
| `prefix 1..9` | Go to window N |
| `prefix \|` / `prefix -` | Split pane right / down |
| `Ctrl-h/j/k/l` | **Move between panes — no prefix needed** (vim-tmux-navigator) |
| `Alt-o` (Option-o) | **Cycle to next pane — no prefix needed** |
| `prefix q` | Flash pane numbers; press a number to jump there |
| `prefix ;` | Toggle between current and last pane |
| `prefix h/j/k/l` | Move between panes (prefixed variant) |
| `prefix H/J/K/L` | Resize pane |
| `prefix z` | Zoom pane to full window (toggle) |
| `prefix x` | Kill pane |
| `prefix Space` | Cycle preset pane layouts (tiled, columns, rows, main+side) |
| `prefix d` | Detach (session keeps running) |
| `prefix [` | Copy mode (vi keys, `v` select, `y` yank) |
| `prefix r` | Reload config |
| `prefix I` | Install plugins (TPM) |

## sesh (session manager)

- `t` in any shell → fuzzy-pick a session. Lists running sessions, the
  predefined ones, and zoxide directories — picking a directory creates a
  session for it automatically.
- Predefined sessions live in `config/sesh/sesh.toml`:
  - `daily` — one `main` window in `~/workspace` (grow it over time in
    `tmux/layouts/daily.sh`)
  - `project-a` — windows: main, quake, iac, identity under
    `~/workspace/project-a` (`tmux/layouts/project-a.sh`)
  - `dotfiles` / `vault`

## Remote use (MacBook Air → servers / workstation)

Everything is on Tailscale, so:

```bash
# SSH straight into the machine's main session (creates it if needed)
ssh <host> -t 'tmux new -A -s main'

# Flaky Wi-Fi / moving around: mosh survives roaming and sleep
mosh <host> -- tmux new -A -s main
```

Detach with `prefix d`, walk to another machine, run the same command, and
you're exactly where you left off. The session (and whatever Claude Code runs
you left going) lives on the *remote* machine, not your laptop.

Tip: keep local and remote tmux from fighting — run tmux on the remote side
only (a plain local terminal, then `mosh host -- tmux new -A -s main`).

## Setup on a new machine

`install.sh` handles all of it: tmux + sesh from packages, `.tmux.conf`
symlinked by rcm, TPM cloned and plugins installed. On servers the minimal
plugin-free config from `tag-server/` is used instead.
