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

### Interest stacks

A third axis, independent of BOTH role and ownership. Where a vendor stack
answers "which client is this machine for", a stack answers "what does this
machine actually get used for":

```bash
./packages/install.sh workstation --personal --stack finance
```

Each `--stack NAME` pulls in `Brewfile.stack.NAME` (or `stack.NAME.txt` on
Linux, none of which exist yet). Repeatable. Available:

| Stack      | Contents                                                     |
| ---------- | ------------------------------------------------------------ |
| `creative` | Affinity suite, Krita, Bloom, Rogue Amoeba audio, FreeCAD, GarageBand, iMovie |
| `finance`  | TradingView, thinkorswim, beancount, fava                    |
| `localai`  | Ollama, LM Studio, Msty, Cursor, Windsurf, Trae, Block Goose  |

**Why this axis exists.** These clusters used to live inside the shared
`*.workstation` files, which made them a function of screen size. They are not.
A workstation that wants Docker and BetterDisplay but not Affinity and Ollama
had no flag combination that expressed it - `--workstation` was all-or-nothing
on a `Brewfile.apps.workstation` that mixed window managers, cloud sync,
a creative suite and trading software into one file.

Local AI is the clearest case: it is a poor fit for an Intel Mac (no
Metal-class GPU, so inference is CPU-only), and that has nothing to do with
whether the machine sits on a desk.

Adding a stack means adding a file - no code change. Existing machines keep
whatever they already installed: `brew bundle` never uninstalls, so the carve-up
only changes what a FUTURE run installs. Pass the stacks you want on the next
run to keep them arriving.

## Quick Reference

```bash
# Any OS
./packages/install.sh laptop       # Light machine
./packages/install.sh workstation  # Everything
./packages/install.sh server       # Minimal always-on machine

# Extras
./packages/install.sh --work       # + work apps (tiered by role)
./packages/install.sh --personal   # + personal apps (tiered by role)
./packages/install.sh --stack finance   # + an interest stack (repeatable)
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
| Brewfile.apps             | Essential GUI apps                      | laptop, workstation |
| Brewfile.apps.workstation | Full GUI suite (browsers, cloud, autos) | workstation        |
| Brewfile.font             | Nerd Fonts                              | laptop, workstation |
| Brewfile.devops           | Terraform, AWS, Ansible                 | workstation        |
| Brewfile.server           | Minimal CLI set + Tailscale + AI CLIs   | server             |
| Brewfile.apps.work        | Vendor-neutral work apps                | --work             |
| Brewfile.apps.work.workstation | Heavy work apps (empty for now)    | --work + workstation |
| Brewfile.apps.work.microsoft | Office, Teams, Intune                | --vendor microsoft |
| Brewfile.apps.work.google | Drive, Chrome                           | --vendor google    |
| Brewfile.apps.work.apple  | iWork (Keynote, Numbers, Pages)         | --vendor apple     |
| Brewfile.apps.personal    | Light personal apps (SoundSource)       | --personal         |
| Brewfile.apps.personal.workstation | (deliberately empty)           | --personal + workstation |
| Brewfile.playground       | Testing/evaluation                      | --playground       |
| Brewfile.stack.creative   | Affinity, Krita, Rogue Amoeba, FreeCAD  | --stack creative   |
| Brewfile.stack.finance    | TradingView, thinkorswim, beancount     | --stack finance    |
| Brewfile.stack.localai    | Ollama, LM Studio, Cursor, Windsurf     | --stack localai    |
| manual-install.txt        | Not in brew                             | -                  |

## What's in each Brewfile

### core

CLI essentials: eza, bat, fd, ripgrep, fzf, zoxide, atuin, jq, yq, etc.

### dev / dev.workstation

Essentials: neovim, tmux, sesh, terminals (kitty/alacritty/ghostty), git tools,
lazygit, gh, mise, python, VS Code.
Workstation adds: docker, k8s tools, go/rust/ruby/lua, wireshark, postman,
dbeaver, figma, media tools.

### ai

claude-code, opencode, gemini-cli, codex, qwen-code, kimi-code, goose CLI, plus
Claude, ChatGPT, and Zed apps. Every machine gets these.
The heavy AI tier is now `--stack localai`, not a role tier.

### apps / apps.workstation

Essentials: Firefox, Zen, Slack, Zoom, Signal, WhatsApp, Obsidian, 1Password,
Alfred, Rectangle, Stats, Tailscale.
Workstation adds: Chrome, Comet, Discord, Notion, cloud sync clients,
automation utilities (BTT, Hazel, Keyboard Maestro), HandBrake, yt-dlp, Xcode.
The creative suite and the trading/accounting tools moved out to
`--stack creative` and `--stack finance`.

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
