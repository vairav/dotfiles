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

