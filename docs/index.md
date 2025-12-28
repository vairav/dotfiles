# Dotfiles

My dotfiles, managed with [rcm](https://github.com/thoughtbot/rcm).

## Quick Links

- [Repository Structure](rcm-layout.md)
- [Package Management](packages.md)
- [Shell Setup](shell.md)
- [Keybindings](keybindings.md)
- [Arch Linux Notes](arch.md)

## Setup

```bash
# One-liner
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/dotfiles/master/install.sh | bash

# With options
curl ... | bash -s -- --work      # Work machine
curl ... | bash -s -- --personal  # Personal machine
curl ... | bash -s -- --server    # Server (minimal)
```

See [README](../README.md) for manual setup steps.

## Daily Use

```bash
# Edit directly - it's a symlink
vim ~/.zshrc

# Commit
cd ~/workspace/dotfiles
git add -A && git commit -m "update" && git push

# Sync another machine
cd ~/workspace/dotfiles && git pull && rcup
```

## rcm Commands

| Command     | What it does     |
| ----------- | ---------------- |
| `lsrc`      | Preview symlinks |
| `rcup`      | Create symlinks  |
| `rcup -v`   | Verbose          |
| `mkrc FILE` | Adopt a file     |
| `rcdn`      | Remove symlinks  |

## Tags

| Machine       | Tags          | What gets added |
| ------------- | ------------- | --------------- |
| macOS Desktop | desktop macos | Karabiner       |
| Linux Desktop | desktop linux | i3              |
| Server        | server        | Minimal configs |

## Secrets

Not in git:

- `~/.zshrc.local` - API keys, tokens
- `~/.gitconfig.local` - name, email, signing key
