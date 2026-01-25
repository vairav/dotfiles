# Dotfiles

My personal dotfiles which I use across multiple machines (Mac, Arch and Debian) managed with [rcm](https://github.com/thoughtbot/rcm).

## Why this approach and rcm?

- Same config everywhere, minimal per-machine tweaks
- Edit files directly (they're symlinks)
- Dotfiles and package installations are separate concerns
- Easy to switch zsh frameworks (Zim, Oh-My-Zsh, plain)

## Setup

One command to install everything:

```bash
curl -fsSL https://raw.githubusercontent.com/vairav/dotfiles/main/install.sh | bash
```

The script will ask a few questions:
- Work or personal machine (for package selection)
- Using ml4w for Hyprland (Linux only, to avoid config conflicts)

Options:

```bash
# Work machine (adds MS Office)
curl ... | bash -s -- --work

# Personal machine (adds Rogue Amoeba apps)
curl ... | bash -s -- --personal

# Server (minimal, no GUI)
curl ... | bash -s -- --server

# Linux with ml4w
curl ... | bash -s -- --ml4w

# Skip parts if needed
curl ... | bash -s -- --skip-packages --skip-macos --skip-rcup
```

The script handles everything: Homebrew, rcm, cloning, symlinking, packages, and macOS defaults.

### Manual setup

Above single script pretty much does what is shown below in a step-by-step manner.

```bash
# macOS
brew install rcm
git clone https://github.com/vairav/dotfiles.git ~/workspace/dotfiles
echo 'TAGS="desktop macos"' > ~/.rcrc.local
RCRC=~/workspace/dotfiles/rcrc rcup -v
~/workspace/dotfiles/packages/install.sh
~/workspace/dotfiles/macos/setup.sh
~/workspace/dotfiles/macos/defaults.sh

# Arch Linux
yay -S rcm
git clone https://github.com/vairav/dotfiles.git ~/workspace/dotfiles
echo 'TAGS="desktop linux"' > ~/.rcrc.local
RCRC=~/workspace/dotfiles/rcrc rcup -v
~/workspace/dotfiles/packages/install.sh

# Arch Linux with ml4w
yay -S rcm
git clone https://github.com/vairav/dotfiles.git ~/workspace/dotfiles
cat > ~/.rcrc.local << 'EOF'
TAGS="desktop linux"
EXCLUDES="config/kitty config/hypr"
EOF
RCRC=~/workspace/dotfiles/rcrc rcup -v

# Server (Debian)
sudo apt-get install rcm
git clone https://github.com/vairav/dotfiles.git ~/workspace/dotfiles
echo 'TAGS="server"' > ~/.rcrc.local
RCRC=~/workspace/dotfiles/rcrc rcup -v
~/workspace/dotfiles/packages/install.sh server
```

## Daily workflow

```bash
vim ~/.zshrc                                    # Edit directly
cd ~/workspace/dotfiles && git add -A && git commit -m "update" && git push
cd ~/workspace/dotfiles && git pull && rcup     # On another machine
```

## Structure

```text
dotfiles/
├── zshrc, tmux.conf, gitconfig, etc.    # -> ~/.*
├── config/                              # -> ~/.config/
│   ├── nvim/
│   ├── kitty/
│   ├── alacritty/
│   └── starship.toml
├── zsh/, tmux/, git/                    # Support files (sourced, not symlinked)
├── prompt/starship/                     # Alternative starship themes
│   └── powerline/                       # Two-line powerline style
├── tag-macos/                           # macOS-specific (Karabiner)
├── tag-linux/                           # Linux-specific (i3, hypr reference)
├── tag-server/                          # Minimal server configs
├── macos/                               # Setup scripts
│   ├── setup.sh
│   └── defaults.sh
├── packages/                            # Brew/apt packages
│   ├── install.sh
│   └── macos/, arch/, debian/
└── docs/                                # Documentation
    ├── ml4w-hyprland-customization.md
    └── ...
```

## Linux with ml4w

If you're using [ml4w](https://github.com/mylinuxforwork/dotfiles) for Hyprland, the install script will exclude kitty and hyprland configs from rcm. ml4w manages these itself.

For customization:

- **kitty:** Create `~/.config/kitty/custom.conf` and include our modular configs
- **hyprland:** Use ml4w's variation system, documented in [ml4w-hyprland-customization.md](docs/ml4w-hyprland-customization.md)

Example `~/.config/kitty/custom.conf`:
```bash
# Include our cursor settings (no blinking)
include ~/workspace/dotfiles/config/kitty/configs/cursor.conf
include ~/workspace/dotfiles/config/kitty/configs/scrollback.conf
```

## Starship prompt

Default theme is in `config/starship.toml` (symlinked to `~/.config/`).

To use powerline theme:

```bash
# In ~/.zshrc.local
export STARSHIP_CONFIG=~/workspace/dotfiles/prompt/starship/powerline/starship.toml
```

## Packages

```bash
./packages/install.sh              # Desktop
./packages/install.sh --work       # + MS Office
./packages/install.sh --personal   # + Rogue Amoeba
./packages/install.sh --playground # + Testing tools
./packages/install.sh --cleanup    # Remove unlisted
```

Note: Sometimes I do go overboard and install too many tools/packages using brew or apt. In that case, I clean up unused packages using the `--cleanup` flag. This compares the installed packages with the Brewfiles and removes any that are not listed.

Brewfiles:

- **core** - CLI essentials (eza, bat, fd, ripgrep, fzf, zoxide, atuin)
- **dev** - languages and tools (neovim, tmux, mise, docker, k8s)
- **ai** - AI tools (Claude, ChatGPT, Cursor, Windsurf, Zed)
- **apps** - GUI apps (browsers, Obsidian, Alfred, BTT, Affinity)
- **apps.work** - MS Office (work machines only)
- **apps.personal** - Rogue Amoeba (personal machines only)
- **font** - Nerd Fonts
- **devops** - Terraform, AWS, Ansible
- **playground** - Testing/evaluation tools

## Zsh frameworks

Set in `~/.zshrc.local`:

```bash
ZSH_FRAMEWORK=zim    # My current default; Fast and minimal
ZSH_FRAMEWORK=omz    # oh-my-zsh
ZSH_FRAMEWORK=plain  # No framework
```

## Tags

| Machine     | TAGS          | Adds                  | Notes                  |
| ----------- | ------------- | --------------------- | ---------------------- |
| macOS       | desktop macos | Karabiner             |                        |
| Linux       | desktop linux | i3, hypr (optional)   |                        |
| Linux+ml4w  | desktop linux | (excludes kitty/hypr) | ml4w manages these     |
| Server      | server        | Minimal configs       |                        |

## Atuin (history sync)

```bash
brew install atuin
atuin import auto
atuin register -u <user> -e <email>
atuin login -u <user>
```

All history syncs encrypted across machines.

## Secrets

Remember to never save secrets, API keys, or other sensitive information in any of the files.
Create the below files in every machine to add your API keys, tokens, etc.

- `~/.zshrc.local` - API keys, ZSH_FRAMEWORK
- `~/.gitconfig.local` - name, email

## rcm commands

```bash
lsrc        # Preview
rcup        # Symlink
rcup -v     # Verbose
mkrc FILE   # Adopt file
rcdn        # Remove
```
