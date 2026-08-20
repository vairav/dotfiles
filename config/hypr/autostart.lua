-- Custom autostart commands

hl.on("hyprland.start", function()
    local HOME = os.getenv("HOME")

    -- Gnome Keyring - secret service for credential persistence
    -- Components: secrets (passwords), pkcs11 (certificates)
    -- Note: ssh component omitted as we may use 1Password SSH agent
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")

    -- Zed tiler - watches for Zed windows and tiles them
    -- (Zed ignores windowrule tile directives, so we use IPC)
    hl.exec_cmd(HOME .. "/workspace/dotfiles/scripts/hypr-zed-tiler.sh")
end)
