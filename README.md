# Dotfiles

Personal dotfiles for Mac, Arch, and Debian managed with [rcm](https://github.com/thoughtbot/rcm).

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/vairav/dotfiles/main/install.sh | bash
```

Options:
```bash
--server        # Minimal server setup (no GUI)
--laptop        # Linux: essential packages only
--workstation   # Linux: full packages (default)
--work          # Add work-specific apps
--personal      # Add personal apps
--ml4w          # Linux: using ml4w for Hyprland
--skip-packages # Skip package installation
--skip-macos    # Skip macOS defaults
--skip-rcup     # Skip symlinking
```

Examples:
```bash
# Arch laptop with ml4w
curl ... | bash -s -- --laptop --ml4w

# Arch workstation (full install)
curl ... | bash -s -- --workstation --personal

# macOS work machine
curl ... | bash -s -- --work

# Server
curl ... | bash -s -- --server
```

## Manual Setup

```bash
# macOS
brew install rcm
git clone https://github.com/vairav/dotfiles.git ~/workspace/dotfiles
echo 'TAGS="desktop macos"' > ~/.rcrc.local
RCRC=~/workspace/dotfiles/rcrc rcup -v

# Arch Linux
yay -S rcm
git clone https://github.com/vairav/dotfiles.git ~/workspace/dotfiles
echo 'TAGS="desktop linux"' > ~/.rcrc.local
RCRC=~/workspace/dotfiles/rcrc rcup -v

# Server
sudo apt-get install rcm
git clone https://github.com/vairav/dotfiles.git ~/workspace/dotfiles
echo 'TAGS="server"' > ~/.rcrc.local
RCRC=~/workspace/dotfiles/rcrc rcup -v
```

## Structure

```
dotfiles/
├── zshrc, tmux.conf, gitconfig    # -> ~/.*
├── config/                         # -> ~/.config/
│   ├── nvim/, kitty/, alacritty/
│   └── starship.toml
├── zsh/                            # Zsh config (sourced)
├── tag-macos/                      # macOS-specific
├── tag-linux/                      # Linux-specific
├── tag-server/                     # Server configs
├── ml4w/                           # ml4w integration files
├── packages/                       # Package lists
└── macos/                          # macOS setup scripts
```

## Packages (Arch)

```
packages/arch/
├── core.txt              # Always: rcm, git, zsh, fzf, ripgrep, bat, eza
├── shell.txt             # Always: starship, atuin, zoxide, tmux, mise
├── font.txt              # Always: Nerd fonts
├── dev.txt               # Essentials: neovim, lazygit, python, base-devel
├── dev.workstation.txt   # Full: docker, k8s, go, rust, java, network tools
├── apps.txt              # Essentials: kitty, firefox, slack, zoom, code, zed
├── apps.workstation.txt  # Full: chrome, discord, obsidian, cloud sync
├── ai.txt                # Essentials: claude-code, opencode
├── ai.workstation.txt    # Full: lmstudio, antigravity, ollama
├── devops.txt            # Essentials: tailscale
├── devops.workstation.txt# Full: aws, terraform, ansible
├── apps.personal.txt     # Personal machines only
├── apps.work.txt         # Work machines only
└── server.txt            # Server only
```

**Laptop** installs `*.txt` (essentials).
**Workstation** installs `*.txt` + `*.workstation.txt` (everything).

## Linux with ml4w

If using [ml4w](https://github.com/mylinuxforwork/dotfiles) for Hyprland, the installer excludes kitty and hyprland configs. ml4w manages these via its own system.

Customization hooks:
- **Hyprland**: `~/.config/hypr/conf/custom.conf` sources our configs
- **Kitty**: `~/.config/kitty/custom.conf` includes our settings

## Shell

- **Framework**: Zim (default), oh-my-zsh, or plain
- **Prompt**: Starship
- **History**: Atuin (synced)
- **Navigation**: Zoxide

Set framework in `~/.zshrc.local`:
```bash
ZSH_FRAMEWORK=zim    # default
ZSH_FRAMEWORK=omz    # oh-my-zsh
ZSH_FRAMEWORK=plain  # none
```

## Tags

| Machine    | TAGS          | Notes                |
|------------|---------------|----------------------|
| macOS      | desktop macos | Karabiner included   |
| Linux      | desktop linux |                      |
| Linux+ml4w | desktop linux | Excludes kitty/hypr  |
| Server     | server        | Minimal              |

## Secrets

Never commit secrets. Use local files:
- `~/.zshrc.local` - API keys, framework choice
- `~/.gitconfig.local` - name, email

## rcm Commands

```bash
lsrc        # Preview symlinks
rcup        # Create symlinks
rcup -v     # Verbose
mkrc FILE   # Adopt existing file
rcdn        # Remove symlinks
```
