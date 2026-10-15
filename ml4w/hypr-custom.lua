-- ml4w Hyprland integration (ml4w 2.15+ / Hyprland Lua config)
-- This file is symlinked to ~/.config/hypr/custom.lua by setup.sh
-- ml4w's hyprland.lua requires custom.lua when it exists

local HOME = os.getenv("HOME")
local HYPR = HOME .. "/workspace/dotfiles/config/hypr/"

dofile(HYPR .. "autostart.lua")
dofile(HYPR .. "keybindings.lua")
dofile(HYPR .. "windowrules.lua")
dofile(HYPR .. "workspaces.lua")
dofile(HYPR .. "devices.lua")
dofile(HYPR .. "misc.lua")
