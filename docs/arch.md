---
title: Arch Linux
nav_order: 6
---

# Arch Linux

Notes for Arch/EndeavourOS setup.

## Nerd Fonts

Install via pacman (each font is a separate package now):

```shell
sudo pacman -S ttf-sourcecodepro-nerd
```

Fonts go to `/usr/share/fonts`. Run `fc-list` to verify.

Alternative: download manually to `~/.local/share/fonts` for single-user install.

## LM Studio (AppImage)

Installed as the official AppImage, not the AUR `lmstudio-bin` package. The AUR
package wraps the same AppImage but lags upstream, so the in-app updater keeps
offering versions `yay` can't install yet.

`packages/install.sh` runs `scripts/install-lmstudio-appimage.sh` for the
workstation role. Safe to re-run by hand.

| Path | What |
| ---- | ---- |
| `~/Applications/LM-Studio-<ver>-x64.AppImage` | The app |
| `~/Applications/LM-Studio.AppImage` | Stable symlink - launcher points here |
| `~/.local/bin/lm-studio` | CLI launcher |
| `~/.local/share/applications/lm-studio.desktop` | Launcher entry + `lmstudio://` handler |

- Downloads only if `~/Applications/LM-Studio.AppImage` is missing. After that,
  update from inside LM Studio.
- Manual version swap: `ln -sfn ~/Applications/LM-Studio-<ver>-x64.AppImage ~/Applications/LM-Studio.AppImage`
- Needs `fuse2` (in `ai.workstation.txt`).
- Refuses to run while `lmstudio-bin` is installed. Remove it with
  `sudo pacman -R lmstudio-bin`.
- Models and settings live in `~/.cache/lm-studio` and `~/.config/LM Studio`,
  untouched by either install method.

Why not an rcm `post-up` hook: `post-up` runs on every `rcup`, and a 1 GB
download doesn't belong in a symlink refresh. Role selection already lives in
`packages/install.sh`.

## Hyprland window rules

Workspace rules are in `config/hypr/windowrules.lua` (and the older
`windowrules.conf`). Matching is on the window class (Wayland app id) and is
case-sensitive. Launcher `.desktop` files and X11 names often differ from it.

Find the real class by launching the app and checking:

```shell
hyprctl clients -j | jq -r '.[] | "\(.class)\t\(.workspace.name)"'
```

Verified classes (2026-10):

| App | Class | Workspace |
| --- | ----- | --------- |
| kitty | `kitty` | 1 |
| VS Code | `com.microsoft.VSCode` | 2 |
| Zed | `dev.zed.Zed` | 2 |
| Firefox | `firefox` | 3 |
| Ferdium | `ferdium` | 4 |
| Slack | `slack` (was `Slack` on X11) | 4 |
| Telegram | `org.telegram.desktop` (`TelegramDesktop` on X11) | 4 |
| LM Studio (AppImage) | `ai.elementlabs.lmstudio` (AUR build was `LM Studio`) | 5 |
| ChatGPT | `Chatgpt` (runs under XWayland) | 5 |

Reload with `hyprctl reload`. Rules apply to newly opened windows only.

### New windows going fullscreen

Two separate causes, both fixed:

- **kitty restoring a maximized state.** `config/kitty/configs/window.conf`
  sets `remember_window_size yes` (wanted on macOS). Under Hyprland, kitty saves
  `"window-state": "maximized"` in `~/.cache/kitty/main.json` and every new
  window maximizes itself right after tiling. `ml4w/kitty-custom.conf` sets
  `remember_window_size no` for ml4w machines.
- **Opening a window over a fullscreen one.** ml4w's
  `~/.config/hypr/conf/misc.lua` ships `on_focus_under_fullscreen = 1`, so the
  new window took over fullscreen. `config/hypr/misc.lua` (and `misc.conf`)
  sets `2` (drop fullscreen, then tile). ml4w loads `custom.lua` after its own
  `misc.lua`, so ours wins, and an ml4w update that resets its file changes
  nothing.
