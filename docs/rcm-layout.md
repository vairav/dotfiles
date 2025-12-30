---
title: Repository Layout
nav_order: 2
---

# Repository Layout

Dotfiles organization with rcm.

## Structure

```
dotfiles/
├── rcrc                      # -> ~/.rcrc
├── zshrc                     # -> ~/.zshrc
├── zimrc                     # -> ~/.zimrc
├── gitconfig                 # -> ~/.gitconfig
├── tmux.conf                 # -> ~/.tmux.conf
├── editorconfig              # -> ~/.editorconfig
│
├── config/                   # -> ~/.config/
│   ├── nvim/                 # Neovim configs (NVIM_APPNAME)
│   │   ├── lazyvim/          # nvim/lazyvim
│   │   └── nvchad/           # nvim/nvchad
│   ├── kitty/
│   ├── alacritty/
│   └── htop/
│
├── zsh/                      # Sourced by zshrc, not symlinked
│   ├── zimrc
│   └── functions/
│
├── tmux/                     # Sourced by tmux.conf
│   └── conf/
│
├── git/                      # Included by gitconfig
│   ├── aliases.gitconfig
│   ├── colors.gitconfig
│   └── delta.gitconfig
│
├── tag-macos/                # macOS-specific
│   └── config/karabiner/
│
├── tag-linux/                # Linux-specific
│   └── config/i3/
│
├── tag-server/               # Server overrides (minimal configs)
│   ├── zshrc
│   └── tmux.conf
│
├── macos/                    # Setup scripts (not symlinked)
│   ├── setup.sh
│   └── defaults.sh
│
└── packages/                 # Package management (not symlinked)
    ├── install.sh
    ├── macos/
    ├── arch/
    └── debian/
```

## How rcm works

Files at repo root get symlinked to `$HOME` with a dot prefix:

- `zshrc` -> `~/.zshrc`
- `gitconfig` -> `~/.gitconfig`

The `config/` directory becomes `~/.config/`:

- `config/nvim/lazyvim/` -> `~/.config/nvim/lazyvim/`
- `config/nvim/nvchad/` -> `~/.config/nvim/nvchad/`
- `config/kitty/` -> `~/.config/kitty/`

Use `NVIM_APPNAME=nvim/lazyvim` to switch neovim configs (see [Neovim](neovim.md)).

## Support directories

`zsh/`, `tmux/`, `git/` contain files that are sourced or included by the main configs. Not symlinked directly - referenced by full path:

```bash
# in ~/.zshrc
source ~/workspace/dotfiles/zsh/functions/utils.sh
```

## Tags

Tags add machine-specific configs:

| Machine | Tags          | What's added       |
| ------- | ------------- | ------------------ |
| macOS   | desktop macos | Karabiner          |
| Linux   | desktop linux | i3                 |
| Server  | server        | Minimal zshrc/tmux |

Set tags in `~/.rcrc.local`:

```bash
TAGS="desktop macos"
```

## Excluded from rcm

- `packages/` - Managed by install.sh
- `macos/` - Setup scripts
- `docs/` - Documentation
- `*.md` files

## Common tasks

```bash
# Edit directly
vim ~/.zshrc

# Add existing file to dotfiles
mkrc -o ~/.config/newapp/config.toml

# Sync on another machine
git pull && rcup
```
