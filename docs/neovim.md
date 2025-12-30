---
title: Neovim
nav_order: 7
---

# Neovim

Multiple configs under `~/.config/nvim/`, switched via `NVIM_APPNAME`.

```
~/.config/nvim/
├── lazyvim/    # daily driver
└── nvchad/     # lighter alternative
```

## Switching configs

| Command | Config  |
| ------- | ------- |
| `nvim`  | LazyVim |
| `nvchad`| NvChad  |

LazyVim is default - set via `NVIM_APPNAME` in `zsh/common/exports.zsh`.

## LazyVim

Built on [LazyVim](https://lazyvim.org) with these additions:

- **codecompanion.nvim** - AI chat with Z.ai GLM
- **vim-tmux-navigator** - `C-h/j/k/l` moves between tmux and vim
- **windsurf.vim** - Codeium completions

### AI keybindings

```
<leader>ai  - inline prompt
<leader>ac  - toggle chat
<leader>aa  - actions menu
```

Needs `ZAI_API_KEY` for Z.ai (models: glm-4.7, glm-4.6v, glm-4.6v-flash).

### Codeium

```
Tab    - accept
M-]    - next suggestion
M-[    - prev suggestion
C-]    - clear
```

## NvChad

Minimal setup. Just overrides in `config/nvim/nvchad/`.
