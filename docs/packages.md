---
title: Packages
nav_order: 3
---

# Package Management

Packages are separate from dotfiles. `install.sh` handles everything.

## Quick Reference

```bash
# macOS
./packages/install.sh              # Desktop packages
./packages/install.sh --work       # + MS Office
./packages/install.sh --personal   # + Rogue Amoeba
./packages/install.sh --playground # + Testing tools
./packages/install.sh --dry-run    # Preview
./packages/install.sh --cleanup    # Remove unlisted packages

# Linux
./packages/install.sh desktop      # Full desktop
./packages/install.sh server       # Minimal
```

## Brewfile Structure

| File                   | What's in it         | Flag         |
| ---------------------- | -------------------- | ------------ |
| Brewfile.core          | CLI essentials       | Always       |
| Brewfile.dev           | Dev tools, languages | Always       |
| Brewfile.ai            | AI/LLM tools         | Always       |
| Brewfile.apps          | GUI apps             | Desktop      |
| Brewfile.apps.work     | MS Office            | --work       |
| Brewfile.apps.personal | Rogue Amoeba         | --personal   |
| Brewfile.font          | Nerd Fonts           | Desktop      |
| Brewfile.devops        | Terraform, AWS, etc  | Desktop      |
| Brewfile.playground    | Testing/evaluation   | --playground |
| manual-install.txt     | Not in brew          | -            |

## What's in each Brewfile

### core

CLI essentials: eza, bat, fd, ripgrep, fzf, zoxide, atuin, jq, yq, etc.

### dev

Languages and dev tools: neovim, tmux, git tools, mise, python, go, rust, lua, docker, k8s tools.

### ai

AI stuff: Claude, ChatGPT, Cursor, Windsurf, Zed, LM Studio, etc.

### apps

GUI apps: browsers, communication (Discord, Slack, Signal), notes (Obsidian, Logseq), utilities (Alfred, BTT, Hazel), creative (Affinity suite), etc.

### apps.work

MS Office suite. Only on work machines.

### apps.personal

Rogue Amoeba audio apps (Audio Hijack, Loopback, SoundSource, etc.). Only on personal machines.

### font

Nerd Fonts: Fira Code, JetBrains Mono, Iosevka, Meslo, Monaspace, etc.

### devops

Terraform, AWS CLI, Ansible, Packer, etc.

### playground

Tools under evaluation. Uncomment to test, then decide to keep or remove.

## Linux

Arch package lists mirror the Brewfile naming:

- `packages/arch/core.txt` - CLI essentials
- `packages/arch/dev.txt` - Dev tools, languages
- `packages/arch/ai.txt` - AI/LLM tools
- `packages/arch/apps.txt` - GUI apps
- `packages/arch/apps.work.txt` - Work-only
- `packages/arch/apps.personal.txt` - Personal-only
- `packages/arch/shell.txt` - Shell enhancements
- `packages/arch/font.txt` - Nerd Fonts
- `packages/arch/devops.txt` - Terraform, AWS, etc
- `packages/arch/server.txt` - Minimal server

Debian uses simpler lists:

- `packages/debian/desktop.txt`
- `packages/debian/server.txt`

## Cleanup

Remove packages not in any Brewfile (macOS only):

```bash
./packages/install.sh --cleanup --dry-run  # Preview
./packages/install.sh --cleanup            # Do it
```
