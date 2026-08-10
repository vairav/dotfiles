---
title: Packages
nav_order: 3
---

# Package Management

Packages are separate from dotfiles. `install.sh` handles everything.

## Roles

Every machine picks one role (macOS and Linux alike):

| Role | Meaning | Example machines |
| ------------- | -------------------------------------------------- | ---------------------- |
| `laptop` | Essentials of every category, nothing heavy | MacBook Air, elite |
| `workstation` | Essentials + heavy `.workstation` tiers | plutus, desktop Macs |
| `desktop` | Alias for `workstation` (default) | |
| `server` | Self-contained minimal set, CLI-focused | old M1 MacBooks |

## Ownership

Independent of role, a machine can also be personal or work. Ownership tiers
the same way roles do, so all four combinations are meaningful:

|                 | `--personal`                          | `--work`                     |
| --------------- | ------------------------------------- | ---------------------------- |
| **laptop**      | `apps.personal`                       | `apps.work`                  |
| **workstation** | `apps.personal` + `.workstation`      | `apps.work` + `.workstation` |

The bare file is the light set any such machine gets; `.workstation` adds the
heavy tier that only belongs on a desk. Some cells are legitimately near-empty -
that is a real answer, not a gap to pad out.

### Vendor stacks

Client environments differ, so vendor-specific software is opt-in and work-only:

```bash
./packages/install.sh laptop --work --vendor microsoft --vendor google
```

Each `--vendor NAME` pulls in `Brewfile.apps.work.NAME` (or
`apps.work.NAME.txt` on Linux). Available: `microsoft`, `google`, `apple`.
Adding a new one means adding a file - no code change.

Nothing vendor-specific belongs in a shared tier. A personal machine never
receives any of it.

## Quick Reference

```bash
# Any OS
./packages/install.sh laptop       # Light machine
./packages/install.sh workstation  # Everything
./packages/install.sh server       # Minimal always-on machine

# Extras
./packages/install.sh --work       # + work apps (tiered by role)
./packages/install.sh --personal   # + personal apps (tiered by role)
./packages/install.sh --playground # + Testing tools
./packages/install.sh --dry-run    # Preview
./packages/install.sh --cleanup    # Remove unlisted packages (macOS)
```

## Brewfile Structure

| File                      | What's in it                            | Installed for      |
| ------------------------- | --------------------------------------- | ------------------ |
| Brewfile.core             | CLI essentials                          | laptop, workstation |
| Brewfile.dev              | Dev essentials (nvim, tmux, git, mise)  | laptop, workstation |
| Brewfile.dev.workstation  | Docker, k8s, languages, debug proxies   | workstation        |
| Brewfile.ai               | AI CLI agents + Claude/ChatGPT/Zed      | laptop, workstation |
| Brewfile.ai.workstation   | Local models (Ollama, LM Studio), IDEs  | workstation        |
| Brewfile.apps             | Essential GUI apps                      | laptop, workstation |
| Brewfile.apps.workstation | Full GUI suite (creative, cloud, autos) | workstation        |
| Brewfile.font             | Nerd Fonts                              | laptop, workstation |
| Brewfile.devops           | Terraform, AWS, Ansible                 | workstation        |
| Brewfile.server           | Minimal CLI set + Tailscale + AI CLIs   | server             |
| Brewfile.apps.work        | Vendor-neutral work apps                | --work             |
| Brewfile.apps.work.workstation | Heavy work apps (empty for now)    | --work + workstation |
| Brewfile.apps.work.microsoft | Office, Teams, Intune                | --vendor microsoft |
| Brewfile.apps.work.google | Drive, Chrome                           | --vendor google    |
| Brewfile.apps.work.apple  | iWork (Keynote, Numbers, Pages)         | --vendor apple     |
| Brewfile.apps.personal    | Light personal apps (SoundSource)       | --personal         |
| Brewfile.apps.personal.workstation | Rogue Amoeba suite, FreeCAD    | --personal + workstation |
| Brewfile.playground       | Testing/evaluation                      | --playground       |
| manual-install.txt        | Not in brew                             | -                  |

## What's in each Brewfile

### core

CLI essentials: eza, bat, fd, ripgrep, fzf, zoxide, atuin, jq, yq, etc.

### dev / dev.workstation

Essentials: neovim, tmux, sesh, terminals (kitty/alacritty/ghostty), git tools,
lazygit, gh, mise, python, VS Code.
Workstation adds: docker, k8s tools, go/rust/ruby/lua, wireshark, postman,
dbeaver, figma, media tools.

### ai / ai.workstation

Essentials: claude-code, opencode, gemini-cli, codex, qwen-code, kimi-code,
goose CLI, plus Claude, ChatGPT, and Zed apps.
Workstation adds: Cursor, Windsurf, Trae, Ollama, LM Studio, Msty.

### apps / apps.workstation

Essentials: Firefox, Zen, Slack, Zoom, Signal, WhatsApp, Obsidian, 1Password,
Alfred, Rectangle, Stats, Tailscale, iWork.
Workstation adds: Chrome, Discord, Notion, cloud sync clients, Affinity suite,
automation utilities (BTT, Hazel, Keyboard Maestro), Xcode.

### server

One self-contained list: shell/CLI parity (eza, bat, fzf, zoxide, atuin,
starship), neovim, tmux + sesh + mosh, gh + lazygit, claude-code + opencode,
Tailscale. No other GUI apps. See also `macos/server-setup.sh` for enabling
SSH and always-on power settings.

### font

Nerd Fonts: Fira Code, JetBrains Mono, Iosevka, Meslo, Monaspace, etc.

### devops

Terraform, AWS CLI, Ansible, Packer, etc. Workstation only. Tailscale ships
as a cask in Brewfile.apps/Brewfile.server instead.

### playground

Tools under evaluation. Uncomment to test, then decide to keep or remove.

## Linux

Arch package lists mirror the Brewfile naming and the same role logic
(`*.workstation.txt` tiers install only for the workstation role):

- `packages/arch/core.txt` - CLI essentials
- `packages/arch/dev.txt` / `dev.workstation.txt`
- `packages/arch/ai.txt` / `ai.workstation.txt`
- `packages/arch/apps.txt` / `apps.workstation.txt`
- `packages/arch/devops.txt` / `devops.workstation.txt`
- `packages/arch/apps.work.txt` / `apps.personal.txt`
- `packages/arch/shell.txt` - Shell enhancements
- `packages/arch/font.txt` - Nerd Fonts
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
