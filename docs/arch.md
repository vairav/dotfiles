# Arch Linux

## EndeavourOS

## Installing Nerd Fonts

- To install nerd fonts, since Nerd Fonts team have changed the way to install the fonts, you need to install each font separately

```shell
sudo pacman -S ttf-sourcecodepro-nerd
```

- This installs the `SauceCode Pro` Nerd Font

- After installation, the fonts should be available in `/usr/share/fonts`

- Run `fc-list` to print the list of fonts

- Another option is to download the font manually and put them under `~/.local/share/fonts` folder and that should do the trick as well. This is more for a single user setting
