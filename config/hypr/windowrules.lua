-- Workspace assignment rules
local function ws(workspace, match)
    hl.window_rule({ match = match, workspace = workspace })
end

-- Workspace 1 - terminal
ws(1, { class = "kitty" })

-- Workspace 2 - dev
ws(2, { class = "code-oss" })
ws(2, { class = "code" })
ws(2, { class = "Code" })
ws(2, { class = [[dev\.zed\.Zed]] })
-- Zed tiling handled by hypr-zed-tiler.sh (IPC watcher)

-- Workspace 3 - web
ws(3, { class = "firefox" })

-- Workspace 4 - comms
ws(4, { class = "ferdium" })
ws(4, { class = "Slack" })
ws(4, { class = "org.telegram.desktop" })

-- Workspace 5 - ai
ws(5, { class = "LM Studio" })
ws(5, { class = "chatgpt" })

-- Workspace 6 - ai-dev

-- Workspace 7 - web-ext
-- Per-org Firefox profiles land here. Launch a profile with
-- `firefox -P <name> --class firefox-<name>` and add a rule to match it.
-- Org names are personal, so keep real ones in a private config rather than
-- here - this file is public.
-- ws(7, { initial_class = "firefox-myorg" })

-- Workspace 8 - ai-dev-ext

-- Workspace 9 - misc
