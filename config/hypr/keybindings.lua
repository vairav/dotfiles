local mainMod = "SUPER"
local HOME = os.getenv("HOME")

-- Launcher
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/launcher.sh"), { description = "Open launcher" })

-- 1Password Quick Access (Wayland can't grab global hotkeys natively)
hl.bind("CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("1password --quick-access"), { description = "1Password Quick Access" })

-- Screenshots (mac-like shortcuts, uses ml4w's grim/slurp script)
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/screenshot.sh --instant"), { description = "Screenshot full screen" })
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/screenshot.sh --instant-area"), { description = "Screenshot area" })
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/screenshot.sh"), { description = "Screenshot menu" })
