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
curl -fsSL https://raw.githubusercontent.com/vairav/dotfiles/master/install.sh | bash
```

Options:

```bash
# Work machine (adds MS Office)
curl ... | bash -s -- --work

# Personal machine (adds Rogue Amoeba apps)
curl ... | bash -s -- --personal

# Server (minimal, no GUI)
curl ... | bash -s -- --server

# Skip parts if needed
curl ... | bash -s -- --skip-packages --skip-macos
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
│   └── alacritty/
├── zsh/, tmux/, git/                    # Support files (sourced, not symlinked)
├── tag-macos/                           # macOS-specific (Karabiner)
├── tag-linux/                           # Linux-specific (i3)
├── tag-server/                          # Minimal server configs
├── macos/                               # Setup scripts
│   ├── setup.sh
│   └── defaults.sh
└── packages/                            # Brew/apt packages
    ├── install.sh
    └── macos/, arch/, debian/
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

| Machine | TAGS          | Adds            |
| ------- | ------------- | --------------- |
| macOS   | desktop macos | Karabiner       |
| Linux   | desktop linux | Hyprland, i3    |
| Server  | server        | Minimal configs |

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
