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
